use axum::{extract::State, routing::get, Json, Router};

use crate::{
    error::AppError,
    extractors::{require_role, AuthenticatedUser},
    models::{Role, UserPublic},
    AppState,
};

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/users/me", get(me))
        .route("/users", get(list_users))
}

async fn me(
    State(state): State<AppState>,
    user: AuthenticatedUser,
) -> Result<Json<UserPublic>, AppError> {
    // Force non-null with "col!: Type" — view columns are inferred nullable by sqlx.
    let profile = sqlx::query!(
        r#"SELECT id as "id!: uuid::Uuid",
                  email as "email!: String",
                  role as "role!: crate::models::Role"
           FROM users WHERE id = $1"#,
        user.user_id
    )
    .fetch_optional(&state.db)
    .await?
    .ok_or(AppError::NotFound)?;

    Ok(Json(UserPublic {
        id: profile.id,
        email: profile.email,
        role: profile.role,
    }))
}

async fn list_users(
    State(state): State<AppState>,
    user: AuthenticatedUser,
) -> Result<Json<Vec<UserPublic>>, AppError> {
    require_role(&user, &[Role::Supervisor, Role::Admin])?;

    let rows = sqlx::query!(
        r#"SELECT id as "id!: uuid::Uuid",
                  email as "email!: String",
                  role as "role!: crate::models::Role"
           FROM users ORDER BY email"#
    )
    .fetch_all(&state.db)
    .await?;

    Ok(Json(
        rows.into_iter()
            .map(|r| UserPublic { id: r.id, email: r.email, role: r.role })
            .collect(),
    ))
}
