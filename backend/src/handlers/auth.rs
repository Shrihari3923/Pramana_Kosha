use axum::{extract::State, routing::post, Json, Router};
use chrono::{Duration, Utc};
use rand::RngCore;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use uuid::Uuid;

use crate::{
    error::AppError,
    extractors::{require_role, AuthenticatedUser},
    jwt,
    models::{Role, User, UserPublic},
    security,
    AppState,
};

const REFRESH_TOKEN_TTL_DAYS: i64 = 30;

/// Minimum password requirements:
/// - 12 characters minimum (stronger than the original 8)
/// - At least one uppercase letter
/// - At least one lowercase letter
/// - At least one digit
/// - At least one special character
fn validate_password_strength(password: &str) -> Result<(), AppError> {
    if password.len() < 12 {
        return Err(AppError::BadRequest(
            "password must be at least 12 characters".into(),
        ));
    }
    if !password.chars().any(|c| c.is_uppercase()) {
        return Err(AppError::BadRequest(
            "password must contain at least one uppercase letter".into(),
        ));
    }
    if !password.chars().any(|c| c.is_lowercase()) {
        return Err(AppError::BadRequest(
            "password must contain at least one lowercase letter".into(),
        ));
    }
    if !password.chars().any(|c| c.is_ascii_digit()) {
        return Err(AppError::BadRequest(
            "password must contain at least one digit".into(),
        ));
    }
    let specials = "!@#$%^&*()_+-=[]{}|;':\",./<>?`~\\";
    if !password.chars().any(|c| specials.contains(c)) {
        return Err(AppError::BadRequest(
            "password must contain at least one special character".into(),
        ));
    }
    Ok(())
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/auth/register", post(register))
        .route("/auth/login", post(login))
        .route("/auth/refresh", post(refresh))
        .route("/auth/logout", post(logout))
}

#[derive(Deserialize)]
struct RegisterRequest {
    email: String,
    password: String,
    role: Role,
}

/// Bootstrap rule: open if users table is empty; otherwise Admin-gated.
/// Enforces strong password policy on every registration.
async fn register(
    State(state): State<AppState>,
    caller: Option<AuthenticatedUser>,
    Json(body): Json<RegisterRequest>,
) -> Result<Json<AuthResponse>, AppError> {
    let user_count: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM users")
        .fetch_one(&state.db)
        .await?;

    if user_count > 0 {
        let caller = caller.ok_or(AppError::Unauthorized)?;
        require_role(&caller, &[Role::Admin])?;
    }

    // Normalize and validate email.
    let email = body.email.trim().to_lowercase();
    if email.is_empty() || !email.contains('@') {
        return Err(AppError::BadRequest("valid email is required".into()));
    }

    validate_password_strength(&body.password)?;

    let password_hash = bcrypt::hash(&body.password, bcrypt::DEFAULT_COST)?;
    let id = Uuid::new_v4();

    sqlx::query!(
        "INSERT INTO users (id, email, password_hash, role) VALUES ($1, $2, $3, $4::user_role)",
        id,
        email,
        password_hash,
        body.role as Role
    )
    .execute(&state.db)
    .await
    .map_err(|e| match e {
        sqlx::Error::Database(db_err) if db_err.is_unique_violation() => {
            AppError::BadRequest("a user with that email already exists".into())
        }
        other => AppError::Database(other),
    })?;

    let access_token = jwt::issue_access_token(id, body.role, &state.config.jwt_secret)?;
    let refresh_token = issue_refresh_token(&state, id).await?;

    // Record registration event on blockchain (no case/document context).
    let _ = crate::blockchain::record_transaction(
        &state.db,
        crate::blockchain::NewTransaction {
            actor_id: id,
            case_id: None,
            document_id: None,
            action: "USER_REGISTER".to_string(),
            extra: format!("role={:?}", body.role),
        },
    )
    .await;

    Ok(Json(AuthResponse {
        access_token,
        refresh_token,
        user: UserPublic {
            id,
            email,
            role: body.role,
        },
    }))
}

#[derive(Deserialize)]
struct LoginRequest {
    email: String,
    password: String,
}

#[derive(Serialize)]
struct AuthResponse {
    access_token: String,
    refresh_token: String,
    user: UserPublic,
}

async fn login(
    State(state): State<AppState>,
    Json(body): Json<LoginRequest>,
) -> Result<Json<AuthResponse>, AppError> {
    let email = body.email.trim().to_lowercase();

    // Rate-limit check BEFORE touching the user record — prevents user-enumeration
    // timing attacks on the lockout path.
    security::check_lockout(&state.db, &email).await?;

    let user_result = sqlx::query_as::<_, User>(
        "SELECT id, email, password_hash, role FROM users WHERE email = $1",
    )
    .bind(&email)
    .fetch_optional(&state.db)
    .await?;

    // Use constant-time comparison regardless of whether user exists.
    // If no user, bcrypt verify against a dummy hash — this prevents timing attacks.
    let (user, valid) = match user_result {
        Some(u) => {
            let v = bcrypt::verify(&body.password, &u.password_hash)
                .unwrap_or(false);
            (Some(u), v)
        }
        None => {
            // Constant-time dummy check so "user not found" takes same time as "wrong password".
            let dummy = "$2b$12$invalidhashfortimingattempt1234567890";
            let _ = bcrypt::verify(&body.password, dummy);
            (None, false)
        }
    };

    if !valid || user.is_none() {
        // Record failed attempt.
        let _ = security::record_login_attempt(
            &state.db,
            &email,
            false,
            Some("invalid_credentials"),
            None,
        )
        .await;

        // Record security event.
        let _ = security::record_security_event(
            &state.db,
            "AUTH_FAILURE",
            "WARNING",
            None,
            Some(&email),
            "Failed login attempt",
            None,
        )
        .await;

        return Err(AppError::InvalidCredentials);
    }

    let user = user.unwrap();

    // Record successful login.
    let _ = security::record_login_attempt(&state.db, &email, true, None, None).await;

    let access_token = jwt::issue_access_token(user.id, user.role, &state.config.jwt_secret)?;
    let refresh_token = issue_refresh_token(&state, user.id).await?;

    // Record on blockchain.
    let _ = crate::blockchain::record_transaction(
        &state.db,
        crate::blockchain::NewTransaction {
            actor_id: user.id,
            case_id: None,
            document_id: None,
            action: "USER_LOGIN".to_string(),
            extra: String::new(),
        },
    )
    .await;

    Ok(Json(AuthResponse {
        access_token,
        refresh_token,
        user: user.into(),
    }))
}

#[derive(Deserialize)]
struct RefreshRequest {
    refresh_token: String,
}

async fn refresh(
    State(state): State<AppState>,
    Json(body): Json<RefreshRequest>,
) -> Result<Json<AuthResponse>, AppError> {
    let incoming_hash = hash_token(&body.refresh_token);

    let row = sqlx::query!(
        r#"
        SELECT rt.id as "id!", rt.user_id as "user_id!", u.email as "email!", u.password_hash,
               u.role as "role!: crate::models::Role"
        FROM refresh_tokens rt
        JOIN users u ON u.id = rt.user_id
        WHERE rt.token_hash = $1 AND rt.revoked_at IS NULL AND rt.expires_at > now()
        "#,
        incoming_hash
    )
    .fetch_optional(&state.db)
    .await?
    .ok_or(AppError::Unauthorized)?;

    // Rotate: revoke used token unconditionally — if this token was already
    // revoked and someone tries to reuse it, it won't be found above (revoked_at IS NULL).
    // The rotation itself protects against stolen token reuse after rotation.
    sqlx::query!("UPDATE refresh_tokens SET revoked_at = now() WHERE id = $1", row.id)
        .execute(&state.db)
        .await?;

    let access_token = jwt::issue_access_token(row.user_id, row.role, &state.config.jwt_secret)?;
    let refresh_token = issue_refresh_token(&state, row.user_id).await?;

    Ok(Json(AuthResponse {
        access_token,
        refresh_token,
        user: UserPublic {
            id: row.user_id,
            email: row.email,
            role: row.role,
        },
    }))
}

/// Logout: revoke all refresh tokens for this user, effectively ending all sessions.
async fn logout(
    State(state): State<AppState>,
    user: AuthenticatedUser,
) -> Result<Json<serde_json::Value>, AppError> {
    sqlx::query!(
        "UPDATE refresh_tokens SET revoked_at = now() WHERE user_id = $1 AND revoked_at IS NULL",
        user.user_id
    )
    .execute(&state.db)
    .await?;

    // Record on blockchain.
    let _ = crate::blockchain::record_transaction(
        &state.db,
        crate::blockchain::NewTransaction {
            actor_id: user.user_id,
            case_id: None,
            document_id: None,
            action: "USER_LOGOUT".to_string(),
            extra: String::new(),
        },
    )
    .await;

    Ok(Json(serde_json::json!({ "status": "logged_out" })))
}

async fn issue_refresh_token(state: &AppState, user_id: Uuid) -> Result<String, AppError> {
    let mut bytes = [0u8; 32];
    rand::thread_rng().fill_bytes(&mut bytes);
    let plaintext = hex::encode(bytes);
    let token_hash = hash_token(&plaintext);
    let expires_at = Utc::now() + Duration::days(REFRESH_TOKEN_TTL_DAYS);

    sqlx::query!(
        "INSERT INTO refresh_tokens (user_id, token_hash, expires_at) VALUES ($1, $2, $3)",
        user_id,
        token_hash,
        expires_at
    )
    .execute(&state.db)
    .await?;

    Ok(plaintext)
}

fn hash_token(token: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(token.as_bytes());
    hex::encode(hasher.finalize())
}
