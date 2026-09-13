pub mod auth;
pub mod users;
pub mod cases;
pub mod documents;
pub mod audit;
pub mod custody;

use axum::{routing::get, Json, Router};
use serde_json::{json, Value};

use crate::AppState;

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/health", get(health))
        .merge(auth::router())
        .merge(users::router())
        .merge(cases::router())
        .merge(documents::router())
        .merge(audit::router())
        .merge(custody::router())
        // Blockchain routes (defined in blockchain.rs, not a handler module)
        .merge(crate::blockchain::router())
        // Signatures routes (defined in signatures.rs)
        .merge(crate::signatures::router())
        // Security stats routes (defined in security.rs)
        .merge(crate::security::router())
}

async fn health() -> Json<Value> {
    Json(json!({ "status": "ok" }))
}
