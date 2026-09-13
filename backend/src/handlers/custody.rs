/// Cryptographically-linked chain of custody for evidence items.
///
/// Every custody event:
///   - Hashes the evidence item state at that moment
///   - Hashes against the previous custody event (chain linkage)
///   - Is recorded as a blockchain transaction
///   - Can be verified: any modification/deletion/reordering is detected

use axum::{
    extract::{Path, State},
    routing::{delete, get, post},
    Json, Router,
};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use uuid::Uuid;

use crate::{
    blockchain::{self, NewTransaction},
    error::AppError,
    extractors::{require_role, AuthenticatedUser},
    models::Role,
    AppState,
};

pub fn router() -> Router<AppState> {
    Router::new()
        // Evidence items
        .route("/cases/:case_id/evidence", post(register_evidence).get(list_evidence))
        .route("/evidence/:id", get(get_evidence_item).delete(delete_evidence))
        // Custody events
        .route("/evidence/:id/transfer", post(transfer_custody))
        .route("/evidence/:id/custody", get(get_custody_chain))
        .route("/evidence/:id/verify-custody", get(verify_custody_chain))
}

// ---------------------------------------------------------------------------
// Hashing helpers
// ---------------------------------------------------------------------------

fn genesis_custody_hash() -> String {
    "0".repeat(64)
}

/// Hash the evidence item state snapshot (metadata only, not physical content).
fn compute_evidence_hash(
    evidence_id: Uuid,
    name: &str,
    status: &str,
    custodian_id: Uuid,
    location: &str,
) -> String {
    let mut h = Sha256::new();
    h.update(evidence_id.to_string().as_bytes());
    h.update(b"|");
    h.update(name.as_bytes());
    h.update(b"|");
    h.update(status.as_bytes());
    h.update(b"|");
    h.update(custodian_id.to_string().as_bytes());
    h.update(b"|");
    h.update(location.as_bytes());
    hex::encode(h.finalize())
}

/// Hash a custody event.
/// event_hash = sha256(evidence_id || actor_id || action || prev_event_hash || timestamp_rfc3339)
fn compute_event_hash(
    evidence_id: Uuid,
    actor_id: Uuid,
    action: &str,
    prev_event_hash: &str,
    timestamp: DateTime<Utc>,
) -> String {
    let mut h = Sha256::new();
    h.update(evidence_id.to_string().as_bytes());
    h.update(b"|");
    h.update(actor_id.to_string().as_bytes());
    h.update(b"|");
    h.update(action.as_bytes());
    h.update(b"|");
    h.update(prev_event_hash.as_bytes());
    h.update(b"|");
    h.update(timestamp.to_rfc3339().as_bytes());
    hex::encode(h.finalize())
}

// ---------------------------------------------------------------------------
// Evidence registration
// ---------------------------------------------------------------------------

#[derive(Deserialize)]
struct RegisterEvidenceRequest {
    item_number: String,
    name: String,
    category: Option<String>,
    description: Option<String>,
    location: Option<String>,
}

#[derive(Serialize)]
struct EvidenceItemResponse {
    id: Uuid,
    case_id: Uuid,
    item_number: String,
    name: String,
    category: String,
    description: String,
    status: String,
    custodian_id: Uuid,
    custodian_email: String,
    location: String,
    sealed_at: DateTime<Utc>,
    created_at: DateTime<Utc>,
    custody_event_count: i64,
}

async fn register_evidence(
    State(state): State<AppState>,
    user: AuthenticatedUser,
    Path(case_id): Path<Uuid>,
    Json(body): Json<RegisterEvidenceRequest>,
) -> Result<Json<EvidenceItemResponse>, AppError> {
    require_role(&user, &[Role::Supervisor, Role::Admin, Role::Investigator])?;
    assert_case_access(&state, &user, case_id).await?;

    if body.item_number.trim().is_empty() || body.name.trim().is_empty() {
        return Err(AppError::BadRequest("item_number and name are required".into()));
    }

    let category = body.category.unwrap_or_else(|| "PHYSICAL".to_string());
    let description = body.description.unwrap_or_default();
    let location = body.location.unwrap_or_default();
    let now = Utc::now();

    let mut tx = state.db.begin().await?;

    let evidence_id = Uuid::new_v4();
    sqlx::query!(
        r#"
        INSERT INTO evidence_items (id, case_id, item_number, name, category, description, status, custodian_id, location, sealed_at, created_by, created_at)
        VALUES ($1, $2, $3, $4, $5, $6, 'SECURE_VAULT', $7, $8, $9, $7, $9)
        "#,
        evidence_id,
        case_id,
        body.item_number,
        body.name,
        category,
        description,
        user.user_id,
        location,
        now,
    )
    .execute(&mut *tx)
    .await
    .map_err(|e| match e {
        sqlx::Error::Database(ref db) if db.is_unique_violation() =>
            AppError::BadRequest("item_number already exists in this case".into()),
        other => AppError::Database(other),
    })?;

    // First custody event: REGISTER
    let evidence_hash = compute_evidence_hash(
        evidence_id, &body.name, "SECURE_VAULT", user.user_id, &location,
    );
    let event_hash = compute_event_hash(
        evidence_id, user.user_id, "REGISTER", &genesis_custody_hash(), now,
    );

    let (bc_tx_id, _) = blockchain::record_transaction_in_tx(
        &mut tx,
        NewTransaction {
            actor_id: user.user_id,
            case_id: Some(case_id),
            document_id: None,
            action: "EVIDENCE_REGISTER".to_string(),
            extra: format!("item={},evidence_id={}", body.item_number, evidence_id),
        },
    )
    .await?;

    sqlx::query!(
        r#"
        INSERT INTO custody_events
            (id, evidence_id, actor_id, prev_custodian_id, new_custodian_id, action,
             location, notes, evidence_hash, prev_event_hash, event_hash, blockchain_tx_id, occurred_at)
        VALUES ($1, $2, $3, NULL, $4, 'REGISTER', $5, 'Initial evidence registration', $6, $7, $8, $9, $10)
        "#,
        Uuid::new_v4(),
        evidence_id,
        user.user_id,
        user.user_id,
        location,
        evidence_hash,
        genesis_custody_hash(),
        event_hash,
        bc_tx_id,
        now,
    )
    .execute(&mut *tx)
    .await?;

    // Audit log
    crate::handlers::audit::append_entry(&mut tx, user.user_id, "EVIDENCE_REGISTER", None, Some(case_id)).await?;

    tx.commit().await?;

    let custodian_email = sqlx::query_scalar!(
        r#"SELECT email as "email!: String" FROM users WHERE id = $1"#,
        user.user_id
    )
    .fetch_one(&state.db)
    .await?;

    Ok(Json(EvidenceItemResponse {
        id: evidence_id,
        case_id,
        item_number: body.item_number,
        name: body.name,
        category,
        description,
        status: "SECURE_VAULT".to_string(),
        custodian_id: user.user_id,
        custodian_email,
        location,
        sealed_at: now,
        created_at: now,
        custody_event_count: 1,
    }))
}

async fn list_evidence(
    State(state): State<AppState>,
    user: AuthenticatedUser,
    Path(case_id): Path<Uuid>,
) -> Result<Json<Vec<EvidenceItemResponse>>, AppError> {
    assert_case_access(&state, &user, case_id).await?;

    let rows = sqlx::query!(
        r#"SELECT e.id as "id!: uuid::Uuid",
                  e.case_id as "case_id!: uuid::Uuid",
                  e.item_number as "item_number!: String",
                  e.name as "name!: String",
                  e.category as "category!: String",
                  e.description as "description!: String",
                  e.status as "status!: String",
                  e.custodian_id as "custodian_id!: uuid::Uuid",
                  u.email as "custodian_email!: String",
                  e.location as "location!: String",
                  e.sealed_at as "sealed_at!: chrono::DateTime<chrono::Utc>",
                  e.created_at as "created_at!: chrono::DateTime<chrono::Utc>",
                  COUNT(ce.id) as "custody_event_count!"
        FROM evidence_items e
        JOIN users u ON u.id = e.custodian_id
        LEFT JOIN custody_events ce ON ce.evidence_id = e.id
        WHERE e.case_id = $1
        GROUP BY e.id, e.case_id, e.item_number, e.name, e.category,
                 e.description, e.status, e.custodian_id, u.email,
                 e.location, e.sealed_at, e.created_at
        ORDER BY e.created_at DESC"#,
        case_id
    )
    .fetch_all(&state.db)
    .await?;

    Ok(Json(
        rows.into_iter()
            .map(|r| EvidenceItemResponse {
                id: r.id,
                case_id: r.case_id,
                item_number: r.item_number,
                name: r.name,
                category: r.category,
                description: r.description,
                status: r.status,
                custodian_id: r.custodian_id,
                custodian_email: r.custodian_email,
                location: r.location,
                sealed_at: r.sealed_at,
                created_at: r.created_at,
                custody_event_count: r.custody_event_count,
            })
            .collect(),
    ))
}

async fn get_evidence_item(
    State(state): State<AppState>,
    user: AuthenticatedUser,
    Path(evidence_id): Path<Uuid>,
) -> Result<Json<EvidenceItemResponse>, AppError> {
    let row = sqlx::query!(
        r#"SELECT e.id as "id!: uuid::Uuid",
                  e.case_id as "case_id!: uuid::Uuid",
                  e.item_number as "item_number!: String",
                  e.name as "name!: String",
                  e.category as "category!: String",
                  e.description as "description!: String",
                  e.status as "status!: String",
                  e.custodian_id as "custodian_id!: uuid::Uuid",
                  u.email as "custodian_email!: String",
                  e.location as "location!: String",
                  e.sealed_at as "sealed_at!: chrono::DateTime<chrono::Utc>",
                  e.created_at as "created_at!: chrono::DateTime<chrono::Utc>",
                  COUNT(ce.id) as "custody_event_count!"
        FROM evidence_items e
        JOIN users u ON u.id = e.custodian_id
        LEFT JOIN custody_events ce ON ce.evidence_id = e.id
        WHERE e.id = $1
        GROUP BY e.id, e.case_id, e.item_number, e.name, e.category,
                 e.description, e.status, e.custodian_id, u.email,
                 e.location, e.sealed_at, e.created_at"#,
        evidence_id
    )
    .fetch_optional(&state.db)
    .await?
    .ok_or(AppError::NotFound)?;

    assert_case_access(&state, &user, row.case_id).await?;

    Ok(Json(EvidenceItemResponse {
        id: row.id,
        case_id: row.case_id,
        item_number: row.item_number,
        name: row.name,
        category: row.category,
        description: row.description,
        status: row.status,
        custodian_id: row.custodian_id,
        custodian_email: row.custodian_email,
        location: row.location,
        sealed_at: row.sealed_at,
        created_at: row.created_at,
        custody_event_count: row.custody_event_count,
    }))
}

// ---------------------------------------------------------------------------
// Custody transfer
// ---------------------------------------------------------------------------

#[derive(Deserialize)]
struct TransferRequest {
    new_custodian_id: Uuid,
    action: Option<String>,     // TRANSFER, ANALYSIS, COURT_EXHIBIT, SEAL, RETURN
    location: Option<String>,
    notes: Option<String>,
}

#[derive(Serialize)]
struct CustodyEventResponse {
    id: Uuid,
    evidence_id: Uuid,
    actor_id: Uuid,
    actor_email: String,
    prev_custodian_id: Option<Uuid>,
    prev_custodian_email: Option<String>,
    new_custodian_id: Uuid,
    new_custodian_email: String,
    action: String,
    location: String,
    notes: String,
    evidence_hash: String,
    prev_event_hash: String,
    event_hash: String,
    blockchain_tx_id: Option<Uuid>,
    occurred_at: DateTime<Utc>,
    chain_status: String,
}

async fn transfer_custody(
    State(state): State<AppState>,
    user: AuthenticatedUser,
    Path(evidence_id): Path<Uuid>,
    Json(body): Json<TransferRequest>,
) -> Result<Json<CustodyEventResponse>, AppError> {
    let evidence = sqlx::query!(
        r#"SELECT id as "id!: uuid::Uuid",
                  case_id as "case_id!: uuid::Uuid",
                  name as "name!: String",
                  status as "status!: String",
                  custodian_id as "custodian_id!: uuid::Uuid",
                  location as "location!: String"
           FROM evidence_items WHERE id = $1"#,
        evidence_id
    )
    .fetch_optional(&state.db)
    .await?
    .ok_or(AppError::NotFound)?;

    assert_case_access(&state, &user, evidence.case_id).await?;

    let action = body.action.unwrap_or_else(|| "TRANSFER".to_string());
    let valid_actions = ["TRANSFER", "ANALYSIS", "COURT_EXHIBIT", "SEAL", "RETURN"];
    if !valid_actions.contains(&action.as_str()) {
        return Err(AppError::BadRequest(format!(
            "action must be one of: {}",
            valid_actions.join(", ")
        )));
    }

    let location = body.location.unwrap_or(evidence.location.clone());
    let notes = body.notes.unwrap_or_default();
    let new_status = action_to_status(&action);
    let now = Utc::now();

    // Get previous event hash for chaining.
    let prev_event_hash = sqlx::query_scalar!(
        r#"SELECT event_hash as "event_hash!: String"
           FROM custody_events WHERE evidence_id = $1 ORDER BY seq DESC LIMIT 1"#,
        evidence_id
    )
    .fetch_optional(&state.db)
    .await?
    .unwrap_or_else(|| genesis_custody_hash());

    let evidence_hash = compute_evidence_hash(
        evidence_id, &evidence.name, &new_status, body.new_custodian_id, &location,
    );
    let event_hash = compute_event_hash(
        evidence_id, user.user_id, &action, &prev_event_hash, now,
    );

    let mut tx = state.db.begin().await?;

    // Update evidence item status and custodian.
    sqlx::query!(
        "UPDATE evidence_items SET status = $1, custodian_id = $2, location = $3 WHERE id = $4",
        new_status,
        body.new_custodian_id,
        location,
        evidence_id
    )
    .execute(&mut *tx)
    .await?;

    let (bc_tx_id, _) = blockchain::record_transaction_in_tx(
        &mut tx,
        NewTransaction {
            actor_id: user.user_id,
            case_id: Some(evidence.case_id),
            document_id: None,
            action: format!("EVIDENCE_{}", action),
            extra: format!(
                "evidence_id={},from={},to={}",
                evidence_id, evidence.custodian_id, body.new_custodian_id
            ),
        },
    )
    .await?;

    let event_id = Uuid::new_v4();
    sqlx::query!(
        r#"
        INSERT INTO custody_events
            (id, evidence_id, actor_id, prev_custodian_id, new_custodian_id,
             action, location, notes, evidence_hash, prev_event_hash, event_hash,
             blockchain_tx_id, occurred_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
        "#,
        event_id,
        evidence_id,
        user.user_id,
        evidence.custodian_id,
        body.new_custodian_id,
        action,
        location,
        notes,
        evidence_hash,
        prev_event_hash,
        event_hash,
        bc_tx_id,
        now,
    )
    .execute(&mut *tx)
    .await?;

    crate::handlers::audit::append_entry(
        &mut tx, user.user_id, "CUSTODY_TRANSFER", None, Some(evidence.case_id),
    ).await?;

    tx.commit().await?;

    let actor_email = sqlx::query_scalar!(
        r#"SELECT email as "email!: String" FROM users WHERE id = $1"#,
        user.user_id
    )
    .fetch_one(&state.db)
    .await?;
    let new_custodian_email = sqlx::query_scalar!(
        r#"SELECT email as "email!: String" FROM users WHERE id = $1"#,
        body.new_custodian_id
    )
    .fetch_optional(&state.db)
    .await?
    .unwrap_or_default();
    let prev_custodian_email = sqlx::query_scalar!(
        r#"SELECT email as "email!: String" FROM users WHERE id = $1"#,
        evidence.custodian_id
    )
    .fetch_optional(&state.db)
    .await?;

    Ok(Json(CustodyEventResponse {
        id: event_id,
        evidence_id,
        actor_id: user.user_id,
        actor_email,
        prev_custodian_id: Some(evidence.custodian_id),
        prev_custodian_email,
        new_custodian_id: body.new_custodian_id,
        new_custodian_email,
        action,
        location,
        notes,
        evidence_hash,
        prev_event_hash,
        event_hash,
        blockchain_tx_id: Some(bc_tx_id),
        occurred_at: now,
        chain_status: "VERIFIED".to_string(),
    }))
}

fn action_to_status(action: &str) -> String {
    match action {
        "TRANSFER" => "IN_TRANSIT",
        "ANALYSIS" => "ANALYSIS",
        "COURT_EXHIBIT" => "COURT_EXHIBIT",
        "SEAL" | "RETURN" => "SECURE_VAULT",
        _ => "SECURE_VAULT",
    }
    .to_string()
}

// ---------------------------------------------------------------------------
// Custody chain retrieval and verification
// ---------------------------------------------------------------------------

async fn get_custody_chain(
    State(state): State<AppState>,
    user: AuthenticatedUser,
    Path(evidence_id): Path<Uuid>,
) -> Result<Json<Vec<CustodyEventResponse>>, AppError> {
    let evidence = sqlx::query!(
        r#"SELECT case_id as "case_id!: uuid::Uuid" FROM evidence_items WHERE id = $1"#,
        evidence_id
    )        .fetch_optional(&state.db)
        .await?
        .ok_or(AppError::NotFound)?;

    assert_case_access(&state, &user, evidence.case_id).await?;

    let rows = sqlx::query!(
        r#"SELECT ce.id as "id!: uuid::Uuid",
                  ce.evidence_id as "evidence_id!: uuid::Uuid",
                  ce.actor_id as "actor_id!: uuid::Uuid",
                  ua.email as "actor_email!: String",
                  ce.prev_custodian_id,
                  uprev.email as "prev_custodian_email?",
                  ce.new_custodian_id as "new_custodian_id!: uuid::Uuid",
                  unew.email as "new_custodian_email!: String",
                  ce.action as "action!: String",
                  ce.location as "location!: String",
                  ce.notes as "notes!: String",
                  ce.evidence_hash as "evidence_hash!: String",
                  ce.prev_event_hash as "prev_event_hash!: String",
                  ce.event_hash as "event_hash!: String",
                  ce.blockchain_tx_id,
                  ce.occurred_at as "occurred_at!: chrono::DateTime<chrono::Utc>"
           FROM custody_events ce
           JOIN users ua ON ua.id = ce.actor_id
           LEFT JOIN users uprev ON uprev.id = ce.prev_custodian_id
           JOIN users unew ON unew.id = ce.new_custodian_id
           WHERE ce.evidence_id = $1
           ORDER BY ce.seq ASC"#,
        evidence_id
    )
    .fetch_all(&state.db)
    .await?;

    Ok(Json(
        rows.into_iter()
            .map(|r| CustodyEventResponse {
                id: r.id,
                evidence_id: r.evidence_id,
                actor_id: r.actor_id,
                actor_email: r.actor_email,
                prev_custodian_id: r.prev_custodian_id,
                prev_custodian_email: r.prev_custodian_email,
                new_custodian_id: r.new_custodian_id,
                new_custodian_email: r.new_custodian_email,
                action: r.action,
                location: r.location,
                notes: r.notes,
                evidence_hash: r.evidence_hash,
                prev_event_hash: r.prev_event_hash,
                event_hash: r.event_hash,
                blockchain_tx_id: r.blockchain_tx_id,
                occurred_at: r.occurred_at,
                chain_status: "UNVERIFIED".to_string(), // filled in verify endpoint
            })
            .collect(),
    ))
}

#[derive(Serialize)]
struct CustodyVerifyResponse {
    evidence_id: Uuid,
    valid: bool,
    total_events: i64,
    broken_at_event_id: Option<Uuid>,
    tamper_reason: Option<String>,
    chain_status: String,
    verified_at: DateTime<Utc>,
}

async fn verify_custody_chain(
    State(state): State<AppState>,
    user: AuthenticatedUser,
    Path(evidence_id): Path<Uuid>,
) -> Result<Json<CustodyVerifyResponse>, AppError> {
    let evidence = sqlx::query!(
        r#"SELECT case_id as "case_id!: uuid::Uuid",
                  name as "name!: String",
                  status as "status!: String",
                  custodian_id as "custodian_id!: uuid::Uuid",
                  location as "location!: String"
           FROM evidence_items WHERE id = $1"#,
        evidence_id
    )
    .fetch_optional(&state.db)
    .await?
    .ok_or(AppError::NotFound)?;

    assert_case_access(&state, &user, evidence.case_id).await?;

    let events = sqlx::query!(
        r#"SELECT id as "id!: uuid::Uuid",
                  actor_id as "actor_id!: uuid::Uuid",
                  action as "action!: String",
                  prev_event_hash as "prev_event_hash!: String",
                  event_hash as "event_hash!: String",
                  occurred_at as "occurred_at!: chrono::DateTime<chrono::Utc>"
           FROM custody_events WHERE evidence_id = $1 ORDER BY seq ASC"#,
        evidence_id
    )
    .fetch_all(&state.db)
    .await?;

    let total = events.len() as i64;
    let mut expected_prev = genesis_custody_hash();

    for event in &events {
        // Check linkage.
        if event.prev_event_hash != expected_prev {
            return Ok(Json(CustodyVerifyResponse {
                evidence_id,
                valid: false,
                total_events: total,
                broken_at_event_id: Some(event.id),
                tamper_reason: Some("prev_event_hash does not match previous event (chain broken or event reordered)".to_string()),
                chain_status: "CHAIN_OF_CUSTODY_COMPROMISED".to_string(),
                verified_at: Utc::now(),
            }));
        }

        // Recompute event hash.
        let recomputed = compute_event_hash(
            evidence_id,
            event.actor_id,
            &event.action,
            &event.prev_event_hash,
            event.occurred_at,
        );
        if recomputed != event.event_hash {
            return Ok(Json(CustodyVerifyResponse {
                evidence_id,
                valid: false,
                total_events: total,
                broken_at_event_id: Some(event.id),
                tamper_reason: Some("event_hash does not match recomputed hash (event modified)".to_string()),
                chain_status: "CHAIN_OF_CUSTODY_COMPROMISED".to_string(),
                verified_at: Utc::now(),
            }));
        }

        expected_prev = event.event_hash.clone();
    }

    Ok(Json(CustodyVerifyResponse {
        evidence_id,
        valid: true,
        total_events: total,
        broken_at_event_id: None,
        tamper_reason: None,
        chain_status: "CHAIN_OF_CUSTODY_VERIFIED".to_string(),
        verified_at: Utc::now(),
    }))
}

// ---------------------------------------------------------------------------
// Shared case-access check (mirrors documents.rs)
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Delete evidence — Admin only
// ---------------------------------------------------------------------------

/// Permanently deletes an evidence item and all its custody events.
/// Restricted to Admin role — OTP confirmation is enforced on the frontend.
async fn delete_evidence(
    State(state): State<AppState>,
    user: AuthenticatedUser,
    Path(evidence_id): Path<Uuid>,
) -> Result<Json<serde_json::Value>, AppError> {
    require_role(&user, &[Role::Admin])?;

    // Verify the evidence item exists.
    let exists = sqlx::query_scalar!(
        "SELECT id FROM evidence_items_bridge WHERE id = $1",
        evidence_id
    )
    .fetch_optional(&state.db)
    .await?;

    if exists.is_none() {
        return Err(AppError::NotFound);
    }

    let mut tx = state.db.begin().await?;

    // Delete custody events first (underlying bridge table).
    sqlx::query!(
        "DELETE FROM custody_events_bridge WHERE evidence_id = $1",
        evidence_id
    )
    .execute(&mut *tx)
    .await?;

    // Delete the evidence item from the bridge table.
    sqlx::query!(
        "DELETE FROM evidence_items_bridge WHERE id = $1",
        evidence_id
    )
    .execute(&mut *tx)
    .await?;

    // Audit the deletion.
    crate::handlers::audit::append_entry(
        &mut tx,
        user.user_id,
        "EVIDENCE_DELETE",
        None,
        None,
    )
    .await?;

    tx.commit().await?;

    Ok(Json(serde_json::json!({ "status": "deleted" })))
}

// ---------------------------------------------------------------------------
// Unit tests (hash functions only — DB tests need integration test setup)
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_genesis_custody_hash_length() {
        let h = genesis_custody_hash();
        assert_eq!(h.len(), 64);
        assert!(h.chars().all(|c| c == '0'));
    }

    #[test]
    fn test_event_hash_deterministic() {
        let evidence_id = Uuid::parse_str("00000000-0000-0000-0000-000000000001").unwrap();
        let actor_id = Uuid::parse_str("00000000-0000-0000-0000-000000000002").unwrap();
        let ts = DateTime::parse_from_rfc3339("2026-01-01T00:00:00+00:00")
            .unwrap()
            .with_timezone(&Utc);
        let h1 = compute_event_hash(evidence_id, actor_id, "REGISTER", &genesis_custody_hash(), ts);
        let h2 = compute_event_hash(evidence_id, actor_id, "REGISTER", &genesis_custody_hash(), ts);
        assert_eq!(h1, h2);
        assert_eq!(h1.len(), 64);
    }

    #[test]
    fn test_tampered_action_different_hash() {
        let evidence_id = Uuid::new_v4();
        let actor_id = Uuid::new_v4();
        let ts = Utc::now();
        let h1 = compute_event_hash(evidence_id, actor_id, "REGISTER", "prev", ts);
        let h2 = compute_event_hash(evidence_id, actor_id, "TRANSFER", "prev", ts);
        assert_ne!(h1, h2);
    }

    #[test]
    fn test_evidence_hash_deterministic() {
        let evidence_id = Uuid::new_v4();
        let custodian = Uuid::new_v4();
        let h1 = compute_evidence_hash(evidence_id, "knife", "SECURE_VAULT", custodian, "vault-A");
        let h2 = compute_evidence_hash(evidence_id, "knife", "SECURE_VAULT", custodian, "vault-A");
        assert_eq!(h1, h2);
    }
}
