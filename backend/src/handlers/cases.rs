use axum::{
    extract::{Path, State},
    routing::{delete, get, post},
    Json, Router,
};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::{
    blockchain::{self, NewTransaction},
    error::AppError,
    extractors::{require_role, AuthenticatedUser},
    handlers::audit,
    models::Role,
    AppState,
};

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/cases", post(create_case).get(list_cases))
        .route("/cases/:id", get(get_case))
        .route("/cases/:id/assign", post(assign_user))
        .route("/cases/:id/access", get(list_case_access))
        .route("/cases/:id/assign/:user_id", delete(remove_user))
}

#[derive(Deserialize)]
struct CreateCaseRequest {
    title: String,
    case_number: String,
}

#[derive(Serialize)]
struct CaseResponse {
    id: Uuid,
    title: String,
    case_number: String,
    created_by: Uuid,
}

async fn create_case(
    State(state): State<AppState>,
    user: AuthenticatedUser,
    Json(body): Json<CreateCaseRequest>,
) -> Result<Json<CaseResponse>, AppError> {
    require_role(&user, &[Role::Supervisor, Role::Admin])?;

    if body.title.trim().is_empty() || body.case_number.trim().is_empty() {
        return Err(AppError::BadRequest(
            "title and case_number are required".into(),
        ));
    }

    if body.title.len() > 500 {
        return Err(AppError::BadRequest("title exceeds 500 characters".into()));
    }
    if body.case_number.len() > 100 {
        return Err(AppError::BadRequest(
            "case_number exceeds 100 characters".into(),
        ));
    }

    let mut tx = state.db.begin().await?;

    let case_id = Uuid::new_v4();
    sqlx::query!(
        "INSERT INTO cases (id, title, case_number, created_by) VALUES ($1, $2, $3, $4)",
        case_id,
        body.title,
        body.case_number,
        user.user_id
    )
    .execute(&mut *tx)
    .await
    .map_err(|e| match e {
        sqlx::Error::Database(db_err) if db_err.is_unique_violation() => {
            AppError::BadRequest("a case with that case_number already exists".into())
        }
        other => AppError::Database(other),
    })?;

    sqlx::query!(
        "INSERT INTO case_assignments (case_id, user_id) VALUES ($1, $2)",
        case_id,
        user.user_id
    )
    .execute(&mut *tx)
    .await?;

    audit::append_entry(&mut tx, user.user_id, "CREATE_CASE", None, Some(case_id)).await?;

    // Record case creation on blockchain.
    blockchain::record_transaction_in_tx(
        &mut tx,
        NewTransaction {
            actor_id: user.user_id,
            case_id: Some(case_id),
            document_id: None,
            action: "CASE_CREATE".to_string(),
            extra: format!("case_number={}", body.case_number),
        },
    )
    .await?;

    tx.commit().await?;

    Ok(Json(CaseResponse {
        id: case_id,
        title: body.title,
        case_number: body.case_number,
        created_by: user.user_id,
    }))
}

async fn list_cases(
    State(state): State<AppState>,
    user: AuthenticatedUser,
) -> Result<Json<Vec<CaseResponse>>, AppError> {
    let rows = if matches!(user.role, Role::Supervisor | Role::Admin) {
        sqlx::query!(
            r#"SELECT id as "id!: uuid::Uuid",
                      title as "title!: String",
                      case_number as "case_number!: String",
                      created_by as "created_by!: uuid::Uuid"
               FROM cases ORDER BY created_at DESC"#
        )
        .fetch_all(&state.db)
        .await?
        .into_iter()
        .map(|r| CaseResponse {
            id: r.id,
            title: r.title,
            case_number: r.case_number,
            created_by: r.created_by,
        })
        .collect()
    } else {
        sqlx::query!(
            r#"SELECT c.id as "id!: uuid::Uuid",
                      c.title as "title!: String",
                      c.case_number as "case_number!: String",
                      c.created_by as "created_by!: uuid::Uuid"
               FROM cases c
               JOIN case_assignments ca ON ca.case_id = c.id
               WHERE ca.user_id = $1
               ORDER BY c.created_at DESC"#,
            user.user_id
        )
        .fetch_all(&state.db)
        .await?
        .into_iter()
        .map(|r| CaseResponse {
            id: r.id,
            title: r.title,
            case_number: r.case_number,
            created_by: r.created_by,
        })
        .collect()
    };

    Ok(Json(rows))
}

async fn get_case(
    State(state): State<AppState>,
    user: AuthenticatedUser,
    Path(case_id): Path<Uuid>,
) -> Result<Json<CaseResponse>, AppError> {
    let row = sqlx::query!(
        r#"SELECT id as "id!: uuid::Uuid",
                  title as "title!: String",
                  case_number as "case_number!: String",
                  created_by as "created_by!: uuid::Uuid"
           FROM cases WHERE id = $1"#,
        case_id
    )
    .fetch_optional(&state.db)
    .await?
    .ok_or(AppError::NotFound)?;

    if !matches!(user.role, Role::Supervisor | Role::Admin) {
        let assigned = sqlx::query_scalar!(
            "SELECT 1 FROM case_assignments WHERE case_id = $1 AND user_id = $2",
            case_id,
            user.user_id
        )
        .fetch_optional(&state.db)
        .await?;
        if assigned.is_none() {
            return Err(AppError::Forbidden);
        }
    }

    Ok(Json(CaseResponse {
        id: row.id,
        title: row.title,
        case_number: row.case_number,
        created_by: row.created_by,
    }))
}

#[derive(Deserialize)]
struct AssignRequest {
    user_id: Uuid,
}

async fn assign_user(
    State(state): State<AppState>,
    user: AuthenticatedUser,
    Path(case_id): Path<Uuid>,
    Json(body): Json<AssignRequest>,
) -> Result<Json<serde_json::Value>, AppError> {
    require_role(&user, &[Role::Supervisor, Role::Admin])?;

    // Verify IDOR: case must exist.
    let case_exists = sqlx::query_scalar!("SELECT id FROM cases WHERE id = $1", case_id)
        .fetch_optional(&state.db)
        .await?;
    if case_exists.is_none() {
        return Err(AppError::NotFound);
    }

    let mut tx = state.db.begin().await?;

    sqlx::query!(
        "INSERT INTO case_assignments (case_id, user_id) VALUES ($1, $2)",
        case_id,
        body.user_id
    )
    .execute(&mut *tx)
    .await
    .map_err(|e| match e {
        sqlx::Error::Database(db_err) if db_err.is_unique_violation() => {
            AppError::BadRequest("user is already assigned to this case".into())
        }
        sqlx::Error::Database(db_err) if db_err.is_foreign_key_violation() => {
            AppError::BadRequest("user_id does not exist".into())
        }
        other => AppError::Database(other),
    })?;

    audit::append_entry(&mut tx, user.user_id, "ASSIGN_USER", None, Some(case_id)).await?;

    blockchain::record_transaction_in_tx(
        &mut tx,
        NewTransaction {
            actor_id: user.user_id,
            case_id: Some(case_id),
            document_id: None,
            action: "CASE_ASSIGN_USER".to_string(),
            extra: format!("assigned_user={}", body.user_id),
        },
    )
    .await?;

    tx.commit().await?;

    Ok(Json(serde_json::json!({ "status": "assigned" })))
}

#[derive(Serialize)]
struct CaseAccessUser {
    id: Uuid,
    email: String,
    role: Role,
}

async fn list_case_access(
    State(state): State<AppState>,
    user: AuthenticatedUser,
    Path(case_id): Path<Uuid>,
) -> Result<Json<Vec<CaseAccessUser>>, AppError> {
    // Admin and Supervisor can view access for any case.
    // Investigators can only view access for cases they are assigned to.
    if !matches!(user.role, Role::Supervisor | Role::Admin) {
        let assigned = sqlx::query_scalar!(
            "SELECT 1 FROM case_assignments WHERE case_id = $1 AND user_id = $2",
            case_id,
            user.user_id
        )
        .fetch_optional(&state.db)
        .await?;

        if assigned.is_none() {
            return Err(AppError::Forbidden);
        }
    }

    let case_exists = sqlx::query_scalar!(
        "SELECT id FROM cases WHERE id = $1",
        case_id
    )
    .fetch_optional(&state.db)
    .await?;

    if case_exists.is_none() {
        return Err(AppError::NotFound);
    }

    let rows = sqlx::query!(
        r#"SELECT u.id as "id!: uuid::Uuid",
                  u.email as "email!: String",
                  u.role as "role!: crate::models::Role"
           FROM users u
           JOIN case_assignments ca ON ca.user_id = u.id
           WHERE ca.case_id = $1
           ORDER BY u.email"#,
        case_id
    )
    .fetch_all(&state.db)
    .await?;

    let users = rows
        .into_iter()
        .map(|r| CaseAccessUser {
            id: r.id,
            email: r.email,
            role: r.role,
        })
        .collect();

    Ok(Json(users))
}

async fn remove_user(
    State(state): State<AppState>,
    user: AuthenticatedUser,
    Path((case_id, target_user_id)): Path<(Uuid, Uuid)>,
) -> Result<Json<serde_json::Value>, AppError> {
    require_role(&user, &[Role::Supervisor, Role::Admin])?;

    // Find the case and its Case Head.
    let case = sqlx::query!(
        r#"SELECT created_by as "created_by!: uuid::Uuid"
           FROM cases
           WHERE id = $1"#,
        case_id
    )
    .fetch_optional(&state.db)
    .await?
    .ok_or(AppError::NotFound)?;

    // The Case Head cannot be removed.
    if case.created_by == target_user_id {
        return Err(AppError::BadRequest(
            "the Case Head cannot be removed from the case".into(),
        ));
    }

    let mut tx = state.db.begin().await?;

    // Check that the user is actually assigned.
    let assignment = sqlx::query_scalar!(
        "SELECT id FROM case_assignments WHERE case_id = $1 AND user_id = $2",
        case_id,
        target_user_id
    )
    .fetch_optional(&mut *tx)
    .await?;

    if assignment.is_none() {
        return Err(AppError::BadRequest(
            "user is not assigned to this case".into(),
        ));
    }

    // Remove case access.
    sqlx::query!(
        "DELETE FROM case_assignments WHERE case_id = $1 AND user_id = $2",
        case_id,
        target_user_id
    )
    .execute(&mut *tx)
    .await?;

    // Remove all document-level permissions for this user
    // within this case.
    sqlx::query!(
        r#"
        DELETE FROM document_access
        WHERE user_id = $1
          AND document_id IN (
              SELECT id
              FROM documents
              WHERE case_id = $2
          )
        "#,
        target_user_id,
        case_id
    )
    .execute(&mut *tx)
    .await?;

    audit::append_entry(
        &mut tx,
        user.user_id,
        "REMOVE_USER",
        None,
        Some(case_id),
    )
    .await?;

    blockchain::record_transaction_in_tx(
        &mut tx,
        NewTransaction {
            actor_id: user.user_id,
            case_id: Some(case_id),
            document_id: None,
            action: "CASE_REMOVE_USER".to_string(),
            extra: format!("removed_user={}", target_user_id),
        },
    )
    .await?;

    tx.commit().await?;

    Ok(Json(serde_json::json!({
        "status": "removed"
    })))
}
