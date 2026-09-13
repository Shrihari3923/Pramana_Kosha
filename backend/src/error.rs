use axum::{
    http::StatusCode,
    response::{IntoResponse, Response},
    Json,
};
use serde_json::json;

#[derive(thiserror::Error, Debug)]
pub enum AppError {
    #[error("invalid credentials")]
    InvalidCredentials,

    #[error("unauthorized")]
    Unauthorized,

    #[error("forbidden")]
    Forbidden,

    #[error("not found")]
    NotFound,

    #[error("database error")]
    Database(#[from] sqlx::Error),

    #[error("password hashing error")]
    Hash(#[from] bcrypt::BcryptError),

    #[error("token error")]
    Token(#[from] jsonwebtoken::errors::Error),

    /// BadRequest carries the message through to the client — it is safe,
    /// user-facing text (never a raw DB error or stack trace).
    #[error("bad request: {0}")]
    BadRequest(String),

    #[error("OCR service error: {0}")]
    Ocr(String),
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        // Log the real error server-side always.
        tracing::error!(error = %self, "request failed");

        let (status, message) = match self {
            AppError::InvalidCredentials => (StatusCode::UNAUTHORIZED, "invalid credentials".to_string()),
            AppError::Unauthorized => (StatusCode::UNAUTHORIZED, "unauthorized".to_string()),
            AppError::Forbidden => (StatusCode::FORBIDDEN, "forbidden".to_string()),
            AppError::NotFound => (StatusCode::NOT_FOUND, "not found".to_string()),
            // Pass the BadRequest message through — it's always a safe, user-facing string.
            AppError::BadRequest(msg) => (StatusCode::BAD_REQUEST, msg),
            AppError::Database(_) | AppError::Hash(_) | AppError::Token(_) | AppError::Ocr(_) => {
                (StatusCode::INTERNAL_SERVER_ERROR, "internal server error".to_string())
            }
        };

        (status, Json(json!({ "error": message }))).into_response()
    }
}
