use axum::{
    extract::{Path, State},
    routing::get,
    Json, Router,
};
use chrono::{DateTime, Utc};
use serde::Serialize;
use sha2::{Digest, Sha256};
use sqlx::{Postgres, Transaction};
use uuid::Uuid;

use crate::{
    error::AppError,
    extractors::{require_role, AuthenticatedUser},
    models::Role,
    AppState,
};

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/audit/verify-chain", get(verify_chain))
        .route("/cases/:id/audit-trail", get(audit_trail))
}

/// Genesis hash for the first row in the chain — 64 zero chars, same length as a
/// real sha256 hex digest so nothing downstream needs a special case for "no prior row".
fn genesis_hash() -> String {
    "0".repeat(64)
}

fn compute_entry_hash(
    prev_hash: &str,
    actor_id: Uuid,
    action: &str,
    document_id: Option<Uuid>,
    case_id: Option<Uuid>,
    created_at: DateTime<Utc>,
) -> String {
    // Truncate to microseconds before formatting. Postgres TIMESTAMPTZ stores
    // microsecond precision; Rust's Utc::now() carries nanoseconds. If we hash
    // the full nanosecond timestamp at write time but read back a microsecond-
    // truncated value at verify time, the RFC3339 strings differ and the chain
    // appears broken on every new entry. Truncating here ensures write and
    // verify always hash the same timestamp string.
    let us = created_at.timestamp_micros();
    let created_at_us = DateTime::<Utc>::from_timestamp_micros(us)
        .unwrap_or(created_at);

    let mut hasher = Sha256::new();
    hasher.update(prev_hash.as_bytes());
    hasher.update(actor_id.to_string().as_bytes());
    hasher.update(action.as_bytes());
    hasher.update(document_id.map(|d| d.to_string()).unwrap_or_default().as_bytes());
    hasher.update(case_id.map(|c| c.to_string()).unwrap_or_default().as_bytes());
    hasher.update(created_at_us.to_rfc3339().as_bytes());
    hex::encode(hasher.finalize())
}

/// Appends one row to the hash chain, inside the caller's transaction — every mutating
/// endpoint calls this as the last step before `tx.commit()`, so the write it's logging
/// and the audit row either both land or both roll back together.
///
/// `pg_advisory_xact_lock` serializes concurrent callers for the lifetime of the
/// transaction: without it, two simultaneous requests could both read the same "last
/// hash" and each append a row pointing at it, forking the chain.
pub async fn append_entry(
    tx: &mut Transaction<'_, Postgres>,
    actor_id: Uuid,
    action: &str,
    document_id: Option<Uuid>,
    case_id: Option<Uuid>,
) -> Result<(), AppError> {
    sqlx::query!("SELECT pg_advisory_xact_lock(hashtext('audit_log'))")
        .execute(&mut **tx)
        .await?;

    // Read from audit_log_bridge directly (seq < 1_000_000), NOT from the
    // audit_log view. The view also unions legacy audit.audit_event rows at
    // seq >= 1_000_000 which use a different hash scheme. If we read the
    // top-of-chain from the view we get a legacy hash as prev_hash, which
    // verify_chain (which filters seq < 1_000_000) never sees — breaking the
    // chain on every new entry.
    let last_hash: Option<String> =
        sqlx::query_scalar!(
            r#"SELECT entry_hash as "entry_hash!: String" FROM audit_log_bridge ORDER BY seq DESC LIMIT 1"#
        )
        .fetch_optional(&mut **tx)
        .await?;

    let prev_hash = last_hash.unwrap_or_else(genesis_hash);
    let created_at = Utc::now();
    let entry_hash = compute_entry_hash(&prev_hash, actor_id, action, document_id, case_id, created_at);

    sqlx::query!(
        r#"
        INSERT INTO audit_log (prev_hash, entry_hash, actor_id, action, document_id, case_id, created_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7)
        "#,
        prev_hash,
        entry_hash,
        actor_id,
        action,
        document_id,
        case_id,
        created_at
    )
    .execute(&mut **tx)
    .await?;

    Ok(())
}

struct AuditRow {
    seq: i64,
    id: Uuid,
    prev_hash: String,
    entry_hash: String,
    actor_id: Uuid,
    action: String,
    document_id: Option<Uuid>,
    case_id: Option<Uuid>,
    created_at: DateTime<Utc>,
}

#[derive(Serialize)]
struct VerifyChainResponse {
    valid: bool,
    total_entries: i64,
    broken_at_seq: Option<i64>,
    broken_at_id: Option<Uuid>,
}

/// Admin only. Walks the whole chain in `seq` order, recomputes each entry_hash from
/// its own stored fields, and checks two things per row:
///   1. the recomputed hash matches the row's stored `entry_hash` (row content intact)
///   2. the row's stored `prev_hash` matches the previous row's `entry_hash` (link intact)
/// The first row to fail either check is the tamper point — everything from there on
/// is unverifiable, which is exactly the "aha" moment the demo needs.
async fn verify_chain(
    State(state): State<AppState>,
    user: AuthenticatedUser,
) -> Result<Json<VerifyChainResponse>, AppError> {
    require_role(&user, &[Role::Admin])?;

    // Only verify rows written by this backend (audit_log_bridge, seq < 1_000_000).
    // The legacy audit.audit_event rows (seq >= 1_000_000) use a different hash
    // scheme and form an independent chain — mixing them breaks the contiguous
    // prev_hash ↔ entry_hash link the verifier expects.
    let rows = sqlx::query_as!(
        AuditRow,
        r#"SELECT seq as "seq!: i64",
                  id as "id!: uuid::Uuid",
                  prev_hash as "prev_hash!: String",
                  entry_hash as "entry_hash!: String",
                  actor_id as "actor_id!: uuid::Uuid",
                  action as "action!: String",
                  document_id,
                  case_id,
                  created_at as "created_at!: chrono::DateTime<chrono::Utc>"
           FROM audit_log WHERE seq < 1000000 ORDER BY seq ASC"#
    )
    .fetch_all(&state.db)
    .await?;

    let mut expected_prev = genesis_hash();

    for row in &rows {
        if row.prev_hash != expected_prev {
            return Ok(Json(VerifyChainResponse {
                valid: false,
                total_entries: rows.len() as i64,
                broken_at_seq: Some(row.seq),
                broken_at_id: Some(row.id),
            }));
        }

        let recomputed = compute_entry_hash(
            &row.prev_hash,
            row.actor_id,
            &row.action,
            row.document_id,
            row.case_id,
            row.created_at,
        );

        if recomputed != row.entry_hash {
            return Ok(Json(VerifyChainResponse {
                valid: false,
                total_entries: rows.len() as i64,
                broken_at_seq: Some(row.seq),
                broken_at_id: Some(row.id),
            }));
        }

        expected_prev = row.entry_hash.clone();
    }

    Ok(Json(VerifyChainResponse {
        valid: true,
        total_entries: rows.len() as i64,
        broken_at_seq: None,
        broken_at_id: None,
    }))
}

#[derive(Serialize)]
struct AuditTrailEntry {
    id: Uuid,
    actor_id: Uuid,
    actor_email: String,
    action: String,
    document_id: Option<Uuid>,
    created_at: DateTime<Utc>,
}

/// Same access model as documents.rs::assert_case_access: supervisor/admin see every
/// case's trail; an investigator only sees the trail for a case they're assigned to
/// via case_assignments. This mirrors who can *see* a case at all in GET /cases —
/// an investigator viewing their own case's audit trail is not a privilege escalation,
/// it's the same data they already have access to via the case detail view.
async fn assert_case_access(
    state: &AppState,
    user: &AuthenticatedUser,
    case_id: Uuid,
) -> Result<(), AppError> {
    if matches!(user.role, Role::Supervisor | Role::Admin) {
        return Ok(());
    }

    let assigned = sqlx::query_scalar!(
        "SELECT 1 FROM case_assignments WHERE case_id = $1 AND user_id = $2",
        case_id,
        user.user_id
    )
    .fetch_optional(&state.db)
    .await?;

    if assigned.is_some() {
        Ok(())
    } else {
        Err(AppError::Forbidden)
    }
}

/// Open to all three roles, but scoped: investigators only get the trail for cases
/// they're assigned to (assert_case_access); supervisor/admin get any case's trail.
async fn audit_trail(
    State(state): State<AppState>,
    user: AuthenticatedUser,
    Path(case_id): Path<Uuid>,
) -> Result<Json<Vec<AuditTrailEntry>>, AppError> {
    assert_case_access(&state, &user, case_id).await?;

    let rows = sqlx::query!(
        r#"SELECT a.id as "id!: uuid::Uuid",
                  a.actor_id as "actor_id!: uuid::Uuid",
                  u.email as "actor_email!: String",
                  a.action as "action!: String",
                  a.document_id,
                  a.created_at as "created_at!: chrono::DateTime<chrono::Utc>"
           FROM audit_log a
           JOIN users u ON u.id = a.actor_id
           WHERE a.case_id = $1
           ORDER BY a.seq ASC"#,
        case_id
    )
    .fetch_all(&state.db)
    .await?
    .into_iter()
    .map(|r| AuditTrailEntry {
        id: r.id,
        actor_id: r.actor_id,
        actor_email: r.actor_email,
        action: r.action,
        document_id: r.document_id,
        created_at: r.created_at,
    })
    .collect();

    Ok(Json(rows))
}
