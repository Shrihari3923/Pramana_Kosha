mod blockchain;
mod config;
mod db;
mod error;
mod extractors;
mod handlers;
mod jwt;
mod models;
mod security;
mod signatures;
#[cfg(test)]
mod tests;

use axum::{
    http::{header, HeaderValue, Method},
    Router,
};
use sqlx::PgPool;
use tower_http::{
    cors::CorsLayer,
    set_header::SetResponseHeaderLayer,
    trace::TraceLayer,
};

use config::Config;

/// Shared state injected into every handler.
#[derive(Clone)]
pub struct AppState {
    pub db: PgPool,
    pub config: Config,
}

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "backend=debug,tower_http=debug".into()),
        )
        .init();

    let config = Config::from_env();
    let db = db::init_pool(&config.database_url).await;

    sqlx::migrate!("./migrations")
        .run(&db)
        .await
        .expect("failed to run migrations");

    let port = config.port;

    // Build CORS layer from configured allowed origins.
    let cors = build_cors(&config);

    let state = AppState { db, config };

    let app = Router::new()
        .merge(handlers::router())
        .layer(cors)
        .layer(TraceLayer::new_for_http())
        // Security headers on every response.
        .layer(SetResponseHeaderLayer::overriding(
            header::HeaderName::from_static("x-content-type-options"),
            HeaderValue::from_static("nosniff"),
        ))
        .layer(SetResponseHeaderLayer::overriding(
            header::HeaderName::from_static("x-frame-options"),
            HeaderValue::from_static("DENY"),
        ))
        .layer(SetResponseHeaderLayer::overriding(
            header::HeaderName::from_static("x-xss-protection"),
            HeaderValue::from_static("1; mode=block"),
        ))
        .layer(SetResponseHeaderLayer::overriding(
            header::HeaderName::from_static("referrer-policy"),
            HeaderValue::from_static("strict-origin-when-cross-origin"),
        ))
        .layer(SetResponseHeaderLayer::overriding(
            header::HeaderName::from_static("permissions-policy"),
            HeaderValue::from_static("camera=(), microphone=(), geolocation=()"),
        ))
        .with_state(state);

    let listener = tokio::net::TcpListener::bind(format!("0.0.0.0:{port}"))
        .await
        .expect("failed to bind port");

    tracing::info!("ChainDock backend running on http://127.0.0.1:{port}");
    axum::serve(listener, app).await.expect("server error");
}

fn build_cors(config: &Config) -> CorsLayer {
    let origins: Vec<HeaderValue> = config
        .allowed_origins
        .iter()
        .filter_map(|o| o.parse::<HeaderValue>().ok())
        .collect();

    if origins.is_empty() {
        tracing::warn!("No valid ALLOWED_ORIGINS configured — CORS disabled (no cross-origin requests will succeed)");
        return CorsLayer::new();
    }

    CorsLayer::new()
        .allow_origin(origins)
        .allow_methods([
            Method::GET,
            Method::POST,
            Method::PUT,
            Method::PATCH,
            Method::DELETE,
            Method::OPTIONS,
        ])
        .allow_headers([
            header::AUTHORIZATION,
            header::CONTENT_TYPE,
            header::ACCEPT,
        ])
        .allow_credentials(true)
}
