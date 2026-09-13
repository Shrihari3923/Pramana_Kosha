use std::env;

/// All runtime config in one place. Loaded once at startup, cloned into AppState.
#[derive(Clone)]
pub struct Config {
    pub database_url: String,
    pub jwt_secret: String,
    pub port: u16,
    /// Used to encrypt Ed25519 private keys in dev mode.
    /// Set KEY_ENCRYPTION_SECRET to any long random string.
    /// If unset, key signing in dev mode is unavailable.
    pub key_encryption_secret: String,
    /// CORS allowed origins, comma-separated. Defaults to http://localhost:5173.
    pub allowed_origins: Vec<String>,
}

impl Config {
    pub fn from_env() -> Self {
        dotenvy::dotenv().ok();

        let database_url = env::var("DATABASE_URL")
            .expect("DATABASE_URL must be set (see .env.example)");
        let jwt_secret = env::var("JWT_SECRET")
            .expect("JWT_SECRET must be set (see .env.example)");
        let port = env::var("PORT")
            .unwrap_or_else(|_| "3000".to_string())
            .parse()
            .expect("PORT must be a valid u16");
        let key_encryption_secret = env::var("KEY_ENCRYPTION_SECRET")
            .unwrap_or_default();

        let allowed_origins = env::var("ALLOWED_ORIGINS")
            .unwrap_or_else(|_| "http://localhost:5173,http://127.0.0.1:5173".to_string())
            .split(',')
            .map(|s| s.trim().to_string())
            .filter(|s| !s.is_empty())
            .collect();

        Self {
            database_url,
            jwt_secret,
            port,
            key_encryption_secret,
            allowed_origins,
        }
    }
}
