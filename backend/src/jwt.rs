use chrono::{Duration, Utc};
use jsonwebtoken::{decode, encode, DecodingKey, EncodingKey, Header, Validation};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::models::Role;

/// Access tokens are short-lived on purpose — 15 min. If it leaks, the blast radius
/// is small. Long-lived sessions live in the refresh token (DB-backed, revocable),
/// not in the JWT itself.
const ACCESS_TOKEN_TTL_MINUTES: i64 = 15;

#[derive(Debug, Serialize, Deserialize)]
pub struct Claims {
    pub sub: Uuid,
    pub role: Role,
    pub exp: i64,
    pub iat: i64,
}

pub fn issue_access_token(user_id: Uuid, role: Role, secret: &str) -> Result<String, jsonwebtoken::errors::Error> {
    let now = Utc::now();
    let claims = Claims {
        sub: user_id,
        role,
        iat: now.timestamp(),
        exp: (now + Duration::minutes(ACCESS_TOKEN_TTL_MINUTES)).timestamp(),
    };

    encode(
        &Header::default(),
        &claims,
        &EncodingKey::from_secret(secret.as_bytes()),
    )
}

pub fn verify_access_token(token: &str, secret: &str) -> Result<Claims, jsonwebtoken::errors::Error> {
    let data = decode::<Claims>(
        token,
        &DecodingKey::from_secret(secret.as_bytes()),
        &Validation::default(),
    )?;
    Ok(data.claims)
}
