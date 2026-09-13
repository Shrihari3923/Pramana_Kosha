/// Real Ed25519 digital signatures for ChainDock documents.
///
/// Uses ed25519-dalek 2.x (RFC 8032 strict verification).
///
/// Key storage strategy:
///   - Public keys are stored in the `signing_keys` table — always.
///   - Private keys in DEVELOPMENT MODE: encrypted with AES-256-GCM using a key
///     derived via PBKDF2-SHA256 from the server's KEY_ENCRYPTION_SECRET environment
///     variable. The plaintext private key is NEVER stored in the database.
///   - key_mode = 'DEV'  → encrypted_private_key column is populated
///   - key_mode = 'HSM'  → encrypted_private_key is NULL; server would call HSM API
///     (not implemented; labeled clearly as NOT CONFIGURED)
///
/// IMPORTANT: Ed25519 is NOT quantum-resistant. It provides classical cryptographic
/// security (128-bit). For post-quantum signatures, use CRYSTALS-Dilithium (ML-DSA)
/// when standardized Rust crates are production-ready.
///
/// What is signed: sha256(file_bytes) — the document hash, not the file itself.
/// This means the signature covers the document content hash recorded at signing time.

use aes_gcm::{
    aead::{Aead, KeyInit},
    Aes256Gcm, Nonce,
};
use axum::{
    extract::{Path, State},
    routing::{get, post},
    Json, Router,
};
use chrono::{DateTime, Utc};
use ed25519_dalek::{Signature, Signer, SigningKey, Verifier, VerifyingKey};
use hmac::Hmac;
use pbkdf2::pbkdf2;
use rand::RngCore;
use rand_core::OsRng;
use serde::Serialize;
use sha2::Sha256;
use uuid::Uuid;

use crate::{
    blockchain::{self, NewTransaction},
    error::AppError,
    extractors::{require_role, AuthenticatedUser},
    models::Role,
    AppState,
};

// ---------------------------------------------------------------------------
// Key encryption helpers (dev-mode only)
// ---------------------------------------------------------------------------

/// Derive a 32-byte AES key from the server secret and a per-key salt.
/// Uses PBKDF2-HMAC-SHA256 with 100_000 iterations.
fn derive_key(server_secret: &str, salt: &[u8]) -> [u8; 32] {
    let mut key = [0u8; 32];
    pbkdf2::<Hmac<Sha256>>(server_secret.as_bytes(), salt, 100_000, &mut key)
        .expect("PBKDF2 key derivation failed");
    key
}

/// Encrypt private key bytes with AES-256-GCM.
/// Returns hex(salt || nonce || ciphertext) — all concatenated, all required for decryption.
fn encrypt_private_key(private_key_bytes: &[u8], server_secret: &str) -> Result<String, AppError> {
    let mut salt = [0u8; 16];
    let mut nonce_bytes = [0u8; 12];
    rand::thread_rng().fill_bytes(&mut salt);
    rand::thread_rng().fill_bytes(&mut nonce_bytes);

    let aes_key = derive_key(server_secret, &salt);
    let cipher = Aes256Gcm::new_from_slice(&aes_key)
        .map_err(|_| AppError::BadRequest("key init failed".into()))?;
    let nonce = Nonce::from_slice(&nonce_bytes);

    let ciphertext = cipher
        .encrypt(nonce, private_key_bytes)
        .map_err(|_| AppError::BadRequest("private key encryption failed".into()))?;

    // Layout: 16 bytes salt | 12 bytes nonce | N bytes ciphertext
    let mut out = Vec::with_capacity(16 + 12 + ciphertext.len());
    out.extend_from_slice(&salt);
    out.extend_from_slice(&nonce_bytes);
    out.extend_from_slice(&ciphertext);
    Ok(hex::encode(out))
}

/// Decrypt private key bytes from the stored hex blob.
fn decrypt_private_key(
    encrypted_hex: &str,
    server_secret: &str,
) -> Result<[u8; 32], AppError> {
    let raw = hex::decode(encrypted_hex)
        .map_err(|_| AppError::BadRequest("corrupt encrypted key".into()))?;
    if raw.len() < 28 {
        return Err(AppError::BadRequest("encrypted key too short".into()));
    }
    let salt = &raw[..16];
    let nonce_bytes = &raw[16..28];
    let ciphertext = &raw[28..];

    let aes_key = derive_key(server_secret, salt);
    let cipher = Aes256Gcm::new_from_slice(&aes_key)
        .map_err(|_| AppError::BadRequest("key init failed".into()))?;
    let nonce = Nonce::from_slice(nonce_bytes);

    let plaintext = cipher
        .decrypt(nonce, ciphertext)
        .map_err(|_| AppError::BadRequest("private key decryption failed — wrong server secret or corrupted key".into()))?;

    plaintext
        .try_into()
        .map_err(|_| AppError::BadRequest("decrypted key is not 32 bytes".into()))
}

// ---------------------------------------------------------------------------
// Key fingerprint
// ---------------------------------------------------------------------------

fn key_fingerprint(public_key_hex: &str) -> String {
    use sha2::{Digest, Sha256};
    let mut h = Sha256::new();
    h.update(public_key_hex.as_bytes());
    hex::encode(h.finalize())[..16].to_string()
}

// ---------------------------------------------------------------------------
// HTTP router
// ---------------------------------------------------------------------------

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/users/me/signing-key", post(generate_key).get(get_my_key))
        .route("/users/:user_id/signing-key", get(get_user_key))
        .route("/documents/:doc_id/sign", post(sign_document))
        .route("/documents/:doc_id/signature", get(get_signature))
        .route("/documents/:doc_id/verify-signature", get(verify_document_signature))
        .route("/documents/:doc_id/verify-integrity", get(verify_document_integrity))
}

// ---------------------------------------------------------------------------
// Keypair generation
// ---------------------------------------------------------------------------

#[derive(Serialize)]
struct KeyResponse {
    key_id: Uuid,
    user_id: Uuid,
    public_key_hex: String,
    fingerprint: String,
    key_mode: String,
    created_at: DateTime<Utc>,
    revoked_at: Option<DateTime<Utc>>,
}

/// Generate a new Ed25519 keypair for the authenticated user.
/// The private key is encrypted with AES-256-GCM and stored in dev mode.
/// Any existing active key is revoked first.
async fn generate_key(
    State(state): State<AppState>,
    user: AuthenticatedUser,
) -> Result<Json<KeyResponse>, AppError> {
    // Revoke any existing active key for this user.
    sqlx::query!(
        "UPDATE signing_keys SET revoked_at = now() WHERE user_id = $1 AND revoked_at IS NULL",
        user.user_id
    )
    .execute(&state.db)
    .await?;

    // Generate a fresh Ed25519 keypair.
    // Use OsRng (Send) and drop it before the first .await so the future stays Send.
    let (signing_key, verifying_key) = {
        let mut csprng = OsRng;
        let sk = SigningKey::generate(&mut csprng);
        let vk = sk.verifying_key();
        (sk, vk)
    };

    let private_key_bytes = signing_key.to_bytes(); // 32 bytes
    let public_key_hex = hex::encode(verifying_key.to_bytes()); // 32 bytes = 64 hex chars
    let fingerprint = key_fingerprint(&public_key_hex);

    let key_mode = if state.config.key_encryption_secret.is_empty() {
        "NOT_CONFIGURED"
    } else {
        "DEV"
    };

    let encrypted_private_key = if key_mode == "DEV" {
        Some(encrypt_private_key(&private_key_bytes, &state.config.key_encryption_secret)?)
    } else {
        None
    };

    let key_id = Uuid::new_v4();
    let now = Utc::now();

    sqlx::query!(
        r#"
        INSERT INTO signing_keys (id, user_id, public_key_hex, encrypted_private_key, key_mode, fingerprint, created_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7)
        "#,
        key_id,
        user.user_id,
        public_key_hex,
        encrypted_private_key,
        key_mode,
        fingerprint,
        now
    )
    .execute(&state.db)
    .await?;

    // Record key generation on blockchain.
    let _ = blockchain::record_transaction(
        &state.db,
        NewTransaction {
            actor_id: user.user_id,
            case_id: None,
            document_id: None,
            action: "KEY_GENERATE".to_string(),
            extra: format!("fingerprint={fingerprint},mode={key_mode}"),
        },
    )
    .await;

    Ok(Json(KeyResponse {
        key_id,
        user_id: user.user_id,
        public_key_hex,
        fingerprint,
        key_mode: key_mode.to_string(),
        created_at: now,
        revoked_at: None,
    }))
}

async fn get_my_key(
    State(state): State<AppState>,
    user: AuthenticatedUser,
) -> Result<Json<KeyResponse>, AppError> {
    get_active_key_response(&state, user.user_id).await
}

async fn get_user_key(
    State(state): State<AppState>,
    caller: AuthenticatedUser,
    Path(user_id): Path<Uuid>,
) -> Result<Json<KeyResponse>, AppError> {
    // Investigators can only see their own key; supervisor/admin can see any.
    if caller.role == Role::Investigator && caller.user_id != user_id {
        return Err(AppError::Forbidden);
    }
    get_active_key_response(&state, user_id).await
}

async fn get_active_key_response(state: &AppState, user_id: Uuid) -> Result<Json<KeyResponse>, AppError> {
    let row = sqlx::query!(
        "SELECT id, user_id, public_key_hex, key_mode, fingerprint, created_at, revoked_at FROM signing_keys WHERE user_id = $1 AND revoked_at IS NULL ORDER BY created_at DESC LIMIT 1",
        user_id
    )
    .fetch_optional(&state.db)
    .await?
    .ok_or(AppError::NotFound)?;

    Ok(Json(KeyResponse {
        key_id: row.id,
        user_id: row.user_id,
        public_key_hex: row.public_key_hex,
        fingerprint: row.fingerprint,
        key_mode: row.key_mode,
        created_at: row.created_at,
        revoked_at: row.revoked_at,
    }))
}

// ---------------------------------------------------------------------------
// Document signing
// ---------------------------------------------------------------------------

#[derive(Serialize)]
struct SignatureResponse {
    signature_id: Uuid,
    document_id: Uuid,
    signer_id: Uuid,
    signer_email: String,
    document_hash: String,
    signature_hex: String,
    public_key_hex: String,
    fingerprint: String,
    signed_at: DateTime<Utc>,
    blockchain_tx_id: Option<Uuid>,
    blockchain_tx_hash: Option<String>,
    verification_status: String,
}

async fn sign_document(
    State(state): State<AppState>,
    user: AuthenticatedUser,
    Path(doc_id): Path<Uuid>,
) -> Result<Json<SignatureResponse>, AppError> {
    // Load the document — verify it exists and the user has access.
    let doc = sqlx::query!(
        r#"SELECT id as "id!: uuid::Uuid",
                  case_id as "case_id!: uuid::Uuid",
                  file_path as "file_path!: String",
                  file_hash as "file_hash!: String",
                  title as "title!: String"
           FROM documents WHERE id = $1"#,
        doc_id
    )
    .fetch_optional(&state.db)
    .await?
    .ok_or(AppError::NotFound)?;

    // Verify case access.
    crate::handlers::documents::assert_case_access_pub(&state, &user, doc.case_id).await?;

    // Only investigators can sign; admin/supervisor verify but do not sign.
    require_role(&user, &[Role::Investigator])?;

    // Check the document hasn't already been signed by this user.
    let existing = sqlx::query_scalar!(
        "SELECT id FROM document_signatures WHERE document_id = $1 AND signer_id = $2",
        doc_id,
        user.user_id
    )
    .fetch_optional(&state.db)
    .await?;
    if existing.is_some() {
        return Err(AppError::BadRequest(
            "document already signed by this user".into(),
        ));
    }

    // Load the user's active signing key.
    let key_row = sqlx::query!(
        "SELECT id, public_key_hex, encrypted_private_key, key_mode, fingerprint FROM signing_keys WHERE user_id = $1 AND revoked_at IS NULL ORDER BY created_at DESC LIMIT 1",
        user.user_id
    )
    .fetch_optional(&state.db)
    .await?
    .ok_or_else(|| AppError::BadRequest("no active signing key — generate one first via POST /users/me/signing-key".into()))?;

    if key_row.key_mode == "HSM" || key_row.encrypted_private_key.is_none() {
        return Err(AppError::BadRequest(
            "HSM signing is NOT CONFIGURED in this deployment — key_mode must be DEV".into(),
        ));
    }

    // Decrypt private key.
    let private_key_bytes = decrypt_private_key(
        key_row.encrypted_private_key.as_deref().unwrap(),
        &state.config.key_encryption_secret,
    )?;

    // Re-read the file to get current bytes — verify integrity before signing.
    let file_bytes = tokio::fs::read(&doc.file_path)
        .await
        .map_err(|_| AppError::NotFound)?;

    let current_hash = {
        use sha2::{Digest, Sha256};
        let mut h = Sha256::new();
        h.update(&file_bytes);
        hex::encode(h.finalize())
    };

    // Refuse to sign a tampered document.
    if current_hash != doc.file_hash {
        return Err(AppError::BadRequest(
            "document integrity check failed — file hash does not match stored hash; cannot sign a modified document".into(),
        ));
    }

    // Sign the document hash (NOT the raw file bytes — we sign the hex hash string).
    let signing_key = SigningKey::from_bytes(&private_key_bytes);
    let signature: Signature = signing_key.sign(doc.file_hash.as_bytes());
    let signature_hex = hex::encode(signature.to_bytes());

    let signer_email = sqlx::query_scalar!(
        r#"SELECT email as "email!: String" FROM users WHERE id = $1"#,
        user.user_id
    )
    .fetch_one(&state.db)
    .await?;

    let sig_id = Uuid::new_v4();
    let signed_at = Utc::now();

    // Record blockchain transaction.
    let (bc_tx_id, bc_tx_hash) = blockchain::record_transaction(
        &state.db,
        NewTransaction {
            actor_id: user.user_id,
            case_id: Some(doc.case_id),
            document_id: Some(doc_id),
            action: "SIGN_DOCUMENT".to_string(),
            extra: format!(
                "fingerprint={},doc_hash={}",
                key_row.fingerprint, doc.file_hash
            ),
        },
    )
    .await?;

    sqlx::query!(
        r#"
        INSERT INTO document_signatures
            (id, document_id, signing_key_id, signer_id, document_hash, signature_hex, signed_at, blockchain_tx_id)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        "#,
        sig_id,
        doc_id,
        key_row.id,
        user.user_id,
        doc.file_hash,
        signature_hex,
        signed_at,
        bc_tx_id,
    )
    .execute(&state.db)
    .await?;

    Ok(Json(SignatureResponse {
        signature_id: sig_id,
        document_id: doc_id,
        signer_id: user.user_id,
        signer_email,
        document_hash: doc.file_hash,
        signature_hex,
        public_key_hex: key_row.public_key_hex,
        fingerprint: key_row.fingerprint,
        signed_at,
        blockchain_tx_id: Some(bc_tx_id),
        blockchain_tx_hash: Some(bc_tx_hash),
        verification_status: "VALID".to_string(),
    }))
}

// ---------------------------------------------------------------------------
// Signature retrieval and verification
// ---------------------------------------------------------------------------

async fn get_signature(
    State(state): State<AppState>,
    user: AuthenticatedUser,
    Path(doc_id): Path<Uuid>,
) -> Result<Json<serde_json::Value>, AppError> {
    let doc = sqlx::query!(
        r#"SELECT case_id as "case_id!: uuid::Uuid" FROM documents WHERE id = $1"#,
        doc_id
    )
    .fetch_optional(&state.db)
    .await?
    .ok_or(AppError::NotFound)?;
    crate::handlers::documents::assert_case_access_pub(&state, &user, doc.case_id).await?;

    let sigs = sqlx::query!(
        r#"SELECT ds.id, ds.document_id, ds.signer_id,
                  u.email as "signer_email!: String",
                  ds.document_hash, ds.signature_hex,
                  sk.public_key_hex, sk.fingerprint,
                  ds.signed_at, ds.blockchain_tx_id
           FROM document_signatures ds
           JOIN users u ON u.id = ds.signer_id
           JOIN signing_keys sk ON sk.id = ds.signing_key_id
           WHERE ds.document_id = $1
           ORDER BY ds.signed_at DESC"#,
        doc_id
    )
    .fetch_all(&state.db)
    .await?;

    let result: Vec<serde_json::Value> = sigs.into_iter().map(|s| serde_json::json!({
        "signature_id": s.id,
        "document_id": s.document_id,
        "signer_id": s.signer_id,
        "signer_email": s.signer_email,
        "document_hash": s.document_hash,
        "signature_hex": s.signature_hex,
        "public_key_hex": s.public_key_hex,
        "fingerprint": s.fingerprint,
        "signed_at": s.signed_at,
        "blockchain_tx_id": s.blockchain_tx_id,
    })).collect();

    Ok(Json(serde_json::json!({ "signatures": result })))
}

#[derive(Serialize)]
struct VerifyResponse {
    document_id: Uuid,
    document_hash_stored: String,
    document_hash_current: String,
    integrity_match: bool,
    integrity_status: String,
    signatures: Vec<SigVerifyDetail>,
    overall_valid: bool,
    verified_at: DateTime<Utc>,
}

#[derive(Serialize)]
struct SigVerifyDetail {
    signature_id: Uuid,
    signer_id: Uuid,
    signer_email: String,
    fingerprint: String,
    signed_at: DateTime<Utc>,
    verification_status: String,
    verification_detail: String,
}

async fn verify_document_signature(
    State(state): State<AppState>,
    user: AuthenticatedUser,
    Path(doc_id): Path<Uuid>,
) -> Result<Json<VerifyResponse>, AppError> {
    let doc = sqlx::query!(
        r#"SELECT id as "id!: uuid::Uuid",
                  case_id as "case_id!: uuid::Uuid",
                  file_hash as "file_hash!: String",
                  file_path as "file_path!: String"
           FROM documents WHERE id = $1"#,
        doc_id
    )
    .fetch_optional(&state.db)
    .await?
    .ok_or(AppError::NotFound)?;

    crate::handlers::documents::assert_case_access_pub(&state, &user, doc.case_id).await?;

    // Compute current file hash.
    let file_bytes = tokio::fs::read(&doc.file_path).await.map_err(|_| AppError::NotFound)?;
    let current_hash = {
        use sha2::{Digest, Sha256};
        let mut h = Sha256::new();
        h.update(&file_bytes);
        hex::encode(h.finalize())
    };
    let integrity_match = current_hash == doc.file_hash;

    let sigs = sqlx::query!(
        r#"SELECT ds.id, ds.signer_id,
                  u.email as "signer_email!: String",
                  ds.document_hash, ds.signature_hex,
                  sk.public_key_hex, sk.fingerprint,
                  ds.signed_at
           FROM document_signatures ds
           JOIN users u ON u.id = ds.signer_id
           JOIN signing_keys sk ON sk.id = ds.signing_key_id
           WHERE ds.document_id = $1
           ORDER BY ds.signed_at DESC"#,
        doc_id
    )
    .fetch_all(&state.db)
    .await?;

    let mut sig_details = Vec::new();
    let mut all_sigs_valid = true;

    for sig in &sigs {
        // Verify the Ed25519 signature against the hash that was signed.
        let status = verify_sig_internal(
            &sig.public_key_hex,
            &sig.document_hash,
            &sig.signature_hex,
        );
        let (verification_status, detail) = match status {
            Ok(()) => ("VALID".to_string(), "Signature cryptographically verified".to_string()),
            Err(e) => {
                all_sigs_valid = false;
                ("INVALID".to_string(), e)
            }
        };
        sig_details.push(SigVerifyDetail {
            signature_id: sig.id,
            signer_id: sig.signer_id,
            signer_email: sig.signer_email.clone(),
            fingerprint: sig.fingerprint.clone(),
            signed_at: sig.signed_at,
            verification_status,
            verification_detail: detail,
        });
    }

    let overall_valid = integrity_match && all_sigs_valid && !sig_details.is_empty();

    Ok(Json(VerifyResponse {
        document_id: doc_id,
        document_hash_stored: doc.file_hash.clone(),
        document_hash_current: current_hash,
        integrity_match,
        integrity_status: if integrity_match {
            "VERIFIED".to_string()
        } else {
            "INTEGRITY_COMPROMISED".to_string()
        },
        signatures: sig_details,
        overall_valid,
        verified_at: Utc::now(),
    }))
}

/// Verify only file integrity (hash match), without checking signatures.
async fn verify_document_integrity(
    State(state): State<AppState>,
    user: AuthenticatedUser,
    Path(doc_id): Path<Uuid>,
) -> Result<Json<serde_json::Value>, AppError> {
    let doc = sqlx::query!(
        r#"SELECT id as "id!: uuid::Uuid",
                  case_id as "case_id!: uuid::Uuid",
                  file_hash as "file_hash!: String",
                  file_path as "file_path!: String",
                  title as "title!: String"
           FROM documents WHERE id = $1"#,
        doc_id
    )
    .fetch_optional(&state.db)
    .await?
    .ok_or(AppError::NotFound)?;

    crate::handlers::documents::assert_case_access_pub(&state, &user, doc.case_id).await?;

    let file_bytes = tokio::fs::read(&doc.file_path).await.map_err(|_| AppError::NotFound)?;
    let current_hash = {
        use sha2::{Digest, Sha256};
        let mut h = Sha256::new();
        h.update(&file_bytes);
        hex::encode(h.finalize())
    };
    let integrity_match = current_hash == doc.file_hash;

    Ok(Json(serde_json::json!({
        "document_id": doc_id,
        "title": doc.title,
        "original_hash": doc.file_hash,
        "current_hash": current_hash,
        "integrity_match": integrity_match,
        "integrity_status": if integrity_match { "VERIFIED" } else { "INTEGRITY_COMPROMISED" },
        "verified_at": Utc::now(),
    })))
}

// ---------------------------------------------------------------------------
// Internal verification helper
// ---------------------------------------------------------------------------

fn verify_sig_internal(
    public_key_hex: &str,
    document_hash: &str,
    signature_hex: &str,
) -> Result<(), String> {
    let pk_bytes = hex::decode(public_key_hex)
        .map_err(|_| "invalid public key hex".to_string())?;
    let pk_array: [u8; 32] = pk_bytes
        .try_into()
        .map_err(|_| "public key must be 32 bytes".to_string())?;
    let verifying_key = VerifyingKey::from_bytes(&pk_array)
        .map_err(|e| format!("invalid public key: {e}"))?;

    let sig_bytes = hex::decode(signature_hex)
        .map_err(|_| "invalid signature hex".to_string())?;
    let sig_array: [u8; 64] = sig_bytes
        .try_into()
        .map_err(|_| "signature must be 64 bytes".to_string())?;
    let signature = Signature::from_bytes(&sig_array);

    verifying_key
        .verify(document_hash.as_bytes(), &signature)
        .map_err(|e| format!("signature verification failed: {e}"))
}

// ---------------------------------------------------------------------------
// Unit tests
// ---------------------------------------------------------------------------

#[cfg(test)]
pub mod tests {
    use super::*;
    use ed25519_dalek::Signer;

    fn generate_test_keypair() -> (SigningKey, VerifyingKey) {
        let mut csprng = rand::thread_rng();
        let sk = SigningKey::generate(&mut csprng);
        let vk = sk.verifying_key();
        (sk, vk)
    }

    #[test]
    fn test_sign_and_verify() {
        let (sk, vk) = generate_test_keypair();
        let doc_hash = "a".repeat(64); // fake sha256 hex
        let sig: Signature = sk.sign(doc_hash.as_bytes());
        let result = verify_sig_internal(
            &hex::encode(vk.to_bytes()),
            &doc_hash,
            &hex::encode(sig.to_bytes()),
        );
        assert!(result.is_ok(), "valid signature should verify: {:?}", result);
    }

    #[test]
    fn test_tampered_hash_fails_verification() {
        let (sk, vk) = generate_test_keypair();
        let doc_hash = "a".repeat(64);
        let sig: Signature = sk.sign(doc_hash.as_bytes());
        let tampered_hash = "b".repeat(64);
        let result = verify_sig_internal(
            &hex::encode(vk.to_bytes()),
            &tampered_hash,
            &hex::encode(sig.to_bytes()),
        );
        assert!(result.is_err(), "tampered hash should fail verification");
    }

    #[test]
    fn test_wrong_key_fails_verification() {
        let (sk, _) = generate_test_keypair();
        let (_, wrong_vk) = generate_test_keypair();
        let doc_hash = "a".repeat(64);
        let sig: Signature = sk.sign(doc_hash.as_bytes());
        let result = verify_sig_internal(
            &hex::encode(wrong_vk.to_bytes()),
            &doc_hash,
            &hex::encode(sig.to_bytes()),
        );
        assert!(result.is_err(), "wrong key should fail verification");
    }

    #[test]
    fn test_key_encrypt_decrypt_roundtrip() {
        let secret = "test-server-secret-at-least-32-bytes";
        let mut key_bytes = [0u8; 32];
        rand::thread_rng().fill_bytes(&mut key_bytes);
        let encrypted = encrypt_private_key(&key_bytes, secret).expect("encrypt ok");
        let decrypted = decrypt_private_key(&encrypted, secret).expect("decrypt ok");
        assert_eq!(key_bytes, decrypted, "roundtrip should produce same bytes");
    }

    #[test]
    fn test_wrong_secret_fails_decrypt() {
        let secret = "correct-secret";
        let mut key_bytes = [0u8; 32];
        rand::thread_rng().fill_bytes(&mut key_bytes);
        let encrypted = encrypt_private_key(&key_bytes, secret).expect("encrypt ok");
        let result = decrypt_private_key(&encrypted, "wrong-secret");
        assert!(result.is_err(), "wrong secret should fail decryption");
    }

    #[test]
    fn test_fingerprint_length() {
        let pk_hex = "a".repeat(64);
        let fp = key_fingerprint(&pk_hex);
        assert_eq!(fp.len(), 16);
    }
}
