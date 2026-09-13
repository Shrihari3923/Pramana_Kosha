use std::time::Duration;
use sqlx::postgres::{PgPool, PgPoolOptions, PgConnectOptions, PgSslMode};
use std::str::FromStr;

/// Single shared pool, created once at startup and cloned (cheaply, it's an Arc internally)
/// into AppState. Every handler pulls a connection from this.
pub async fn init_pool(database_url: &str) -> PgPool {
    // Parse the URL into connect options, then override SSL mode to `require`
    // (encrypt the connection but do not verify the server certificate).
    // This is needed for Aiven-hosted databases whose CA is self-signed and not
    // in the system trust store used by rustls.
    let opts = PgConnectOptions::from_str(database_url)
        .expect("invalid DATABASE_URL")
        .ssl_mode(PgSslMode::Require);

    PgPoolOptions::new()
        .max_connections(10)
        .acquire_timeout(Duration::from_secs(30))
        .connect_with(opts)
        .await
        .expect("failed to connect to Postgres — is DATABASE_URL correct and the DB reachable?")
}
