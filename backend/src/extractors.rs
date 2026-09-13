use axum::{
    extract::FromRequestParts,
    http::request::Parts,
};
use uuid::Uuid;

use crate::{error::AppError, jwt, models::Role, AppState};

/// Drop this as a handler parameter — `async fn handler(user: AuthenticatedUser, ...)` —
/// and you get a verified user for free. Reads `Authorization: Bearer <token>`, verifies
/// the JWT signature + expiry, and exposes the claims. This is the one boundary
/// documents.rs/audit.rs (Dev B) touch on the auth side — nothing else.
pub struct AuthenticatedUser {
    pub user_id: Uuid,
    pub role: Role,
}

#[axum::async_trait]
impl FromRequestParts<AppState> for AuthenticatedUser {
    type Rejection = AppError;

    async fn from_request_parts(parts: &mut Parts, state: &AppState) -> Result<Self, Self::Rejection> {
        let header = parts
            .headers
            .get(axum::http::header::AUTHORIZATION)
            .and_then(|v| v.to_str().ok())
            .ok_or(AppError::Unauthorized)?;

        let token = header
            .strip_prefix("Bearer ")
            .ok_or(AppError::Unauthorized)?;

        let claims = jwt::verify_access_token(token, &state.config.jwt_secret)
            .map_err(|_| AppError::Unauthorized)?;

        Ok(AuthenticatedUser {
            user_id: claims.sub,
            role: claims.role,
        })
    }
}

/// Helper for role-gated handlers, e.g. `require_role(&user, &[Role::Supervisor, Role::Admin])?`
/// Keep this dumb-simple — 3 fixed roles, no dynamic permission matrix.
pub fn require_role(user: &AuthenticatedUser, allowed: &[Role]) -> Result<(), AppError> {
    if allowed.iter().any(|r| *r == user.role) {
        Ok(())
    } else {
        Err(AppError::Forbidden)
    }
}
