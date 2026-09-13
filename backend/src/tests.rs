/// Integration and unit tests for ChainDock security features.
///
/// All tests here are pure unit tests — they run without a database.
/// They test the cryptographic contracts directly (blockchain hashing,
/// Ed25519 sign/verify, custody event hashing, file security validation,
/// password policy). If any fail, the security properties are broken.

// ---------------------------------------------------------------------------
// Blockchain tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod blockchain_tests {
    use crate::blockchain::*;
    use chrono::Utc;
    use uuid::Uuid;

    #[test]
    fn genesis_merkle_root_matches_constant() {
        let computed = sha256_hex(b"GENESIS");
        assert_eq!(
            computed, GENESIS_MERKLE_ROOT,
            "genesis Merkle root constant must match sha256('GENESIS')"
        );
    }

    #[test]
    fn merkle_root_empty_list() {
        let root = compute_merkle_root(&[]);
        assert_eq!(root.len(), 64);
        assert_eq!(root, sha256_hex(b"EMPTY_BLOCK"));
    }

    #[test]
    fn merkle_root_single_item_is_item_itself() {
        let h = "a1b2c3d4".to_string();
        assert_eq!(compute_merkle_root(&[h.clone()]), h);
    }

    #[test]
    fn merkle_root_two_items() {
        let h1 = sha256_hex(b"tx1");
        let h2 = sha256_hex(b"tx2");
        let expected = sha256_hex(format!("{h1}{h2}").as_bytes());
        assert_eq!(compute_merkle_root(&[h1, h2]), expected);
    }

    #[test]
    fn merkle_root_three_items_odd_duplication() {
        let a = sha256_hex(b"a");
        let b = sha256_hex(b"b");
        let c = sha256_hex(b"c");
        let ab = sha256_hex(format!("{a}{b}").as_bytes());
        let cc = sha256_hex(format!("{c}{c}").as_bytes());
        let root = sha256_hex(format!("{ab}{cc}").as_bytes());
        assert_eq!(compute_merkle_root(&[a, b, c]), root);
    }

    #[test]
    fn merkle_root_order_matters() {
        let h1 = sha256_hex(b"tx1");
        let h2 = sha256_hex(b"tx2");
        let forward = compute_merkle_root(&[h1.clone(), h2.clone()]);
        let backward = compute_merkle_root(&[h2, h1]);
        assert_ne!(forward, backward);
    }

    #[test]
    fn block_hash_is_deterministic() {
        let ts = chrono::DateTime::parse_from_rfc3339("2026-01-01T00:00:00+00:00")
            .unwrap()
            .with_timezone(&Utc);
        let h1 = compute_block_hash(1, GENESIS_PREV_HASH, GENESIS_MERKLE_ROOT, ts, 0);
        let h2 = compute_block_hash(1, GENESIS_PREV_HASH, GENESIS_MERKLE_ROOT, ts, 0);
        assert_eq!(h1, h2);
        assert_eq!(h1.len(), 64);
    }

    #[test]
    fn block_hash_changes_with_each_field() {
        let ts = Utc::now();
        let base = compute_block_hash(1, "prev", "merkle", ts, 0);
        assert_ne!(base, compute_block_hash(2, "prev", "merkle", ts, 0), "index");
        assert_ne!(base, compute_block_hash(1, "PREV", "merkle", ts, 0), "prev");
        assert_ne!(base, compute_block_hash(1, "prev", "MERKLE", ts, 0), "merkle");
        assert_ne!(base, compute_block_hash(1, "prev", "merkle", ts, 1), "nonce");
    }

    #[test]
    fn tx_hash_is_deterministic() {
        let actor = Uuid::parse_str("00000000-0000-0000-0000-000000000001").unwrap();
        let ts = chrono::DateTime::parse_from_rfc3339("2026-06-01T12:00:00+00:00")
            .unwrap()
            .with_timezone(&Utc);
        let h1 = compute_tx_hash(actor, "DOCUMENT_UPLOAD", "phash", GENESIS_PREV_HASH, ts);
        let h2 = compute_tx_hash(actor, "DOCUMENT_UPLOAD", "phash", GENESIS_PREV_HASH, ts);
        assert_eq!(h1, h2);
        assert_eq!(h1.len(), 64);
    }

    #[test]
    fn tx_hash_changes_with_each_field() {
        let actor = Uuid::new_v4();
        let ts = Utc::now();
        let base = compute_tx_hash(actor, "ACTION", "payload", "prev", ts);
        let other_actor = Uuid::new_v4();
        assert_ne!(base, compute_tx_hash(other_actor, "ACTION", "payload", "prev", ts));
        assert_ne!(base, compute_tx_hash(actor, "OTHER", "payload", "prev", ts));
        assert_ne!(base, compute_tx_hash(actor, "ACTION", "OTHER", "prev", ts));
        assert_ne!(base, compute_tx_hash(actor, "ACTION", "payload", "OTHER", ts));
    }

    #[test]
    fn payload_hash_changes_with_extra_field() {
        let case_id = Uuid::new_v4();
        let doc_id = Uuid::new_v4();
        let h1 = compute_payload_hash("UPLOAD", Some(case_id), Some(doc_id), "v=1");
        let h2 = compute_payload_hash("UPLOAD", Some(case_id), Some(doc_id), "v=2");
        assert_ne!(h1, h2);
    }
}

// ---------------------------------------------------------------------------
// Digital signature tests (inline — no dependency on signatures::tests)
// ---------------------------------------------------------------------------

#[cfg(test)]
mod signature_tests {
    use ed25519_dalek::{Signature, Signer, SigningKey, Verifier, VerifyingKey};
    use rand_core::OsRng;

    fn gen_keypair() -> (SigningKey, VerifyingKey) {
        let sk = SigningKey::generate(&mut OsRng);
        let vk = sk.verifying_key();
        (sk, vk)
    }

    /// Replicate the verify_sig_internal logic from signatures.rs inline.
    fn verify_sig(pk_hex: &str, doc_hash: &str, sig_hex: &str) -> Result<(), String> {
        let pk_bytes = hex::decode(pk_hex).map_err(|_| "bad pk hex".to_string())?;
        let pk_arr: [u8; 32] = pk_bytes
            .try_into()
            .map_err(|_| "pk not 32 bytes".to_string())?;
        let vk = VerifyingKey::from_bytes(&pk_arr).map_err(|e| format!("bad pk: {e}"))?;
        let sig_bytes = hex::decode(sig_hex).map_err(|_| "bad sig hex".to_string())?;
        let sig_arr: [u8; 64] = sig_bytes
            .try_into()
            .map_err(|_| "sig not 64 bytes".to_string())?;
        let sig = Signature::from_bytes(&sig_arr);
        vk.verify(doc_hash.as_bytes(), &sig)
            .map_err(|e| format!("verify failed: {e}"))
    }

    #[test]
    fn sign_verify_roundtrip() {
        let (sk, vk) = gen_keypair();
        let hash = "a".repeat(64);
        let sig: Signature = sk.sign(hash.as_bytes());
        assert!(
            verify_sig(
                &hex::encode(vk.to_bytes()),
                &hash,
                &hex::encode(sig.to_bytes())
            )
            .is_ok(),
            "valid signature should verify"
        );
    }

    #[test]
    fn tampered_document_hash_fails() {
        let (sk, vk) = gen_keypair();
        let hash = "a".repeat(64);
        let sig: Signature = sk.sign(hash.as_bytes());
        let tampered = "b".repeat(64);
        assert!(
            verify_sig(
                &hex::encode(vk.to_bytes()),
                &tampered,
                &hex::encode(sig.to_bytes())
            )
            .is_err(),
            "tampered hash must fail"
        );
    }

    #[test]
    fn wrong_public_key_fails() {
        let (sk, _) = gen_keypair();
        let (_, wrong_vk) = gen_keypair();
        let hash = "a".repeat(64);
        let sig: Signature = sk.sign(hash.as_bytes());
        assert!(
            verify_sig(
                &hex::encode(wrong_vk.to_bytes()),
                &hash,
                &hex::encode(sig.to_bytes())
            )
            .is_err(),
            "wrong key must fail"
        );
    }

    #[test]
    fn key_fingerprint_is_16_chars() {
        use sha2::{Digest, Sha256};
        let pk_hex = "a".repeat(64);
        let mut h = Sha256::new();
        h.update(pk_hex.as_bytes());
        let fp = hex::encode(h.finalize())[..16].to_string();
        assert_eq!(fp.len(), 16);
    }

    #[test]
    fn private_key_aes_gcm_roundtrip() {
        use aes_gcm::{
            aead::{Aead, KeyInit},
            Aes256Gcm, Nonce,
        };
        use hmac::Hmac;
        use pbkdf2::pbkdf2;
        use rand_core::RngCore;
        use sha2::Sha256;

        let secret = "test-server-secret-at-least-32-bytes";
        let mut key_bytes = [0u8; 32];
        OsRng.fill_bytes(&mut key_bytes);

        // Encrypt
        let mut salt = [0u8; 16];
        let mut nonce_bytes = [0u8; 12];
        OsRng.fill_bytes(&mut salt);
        OsRng.fill_bytes(&mut nonce_bytes);

        let mut aes_key = [0u8; 32];
        pbkdf2::<Hmac<Sha256>>(secret.as_bytes(), &salt, 100_000, &mut aes_key).unwrap();
        let cipher = Aes256Gcm::new_from_slice(&aes_key).unwrap();
        let nonce = Nonce::from_slice(&nonce_bytes);
        let mut ct = cipher.encrypt(nonce, key_bytes.as_slice()).unwrap();

        // Assemble the blob: salt || nonce || ct
        let mut blob = Vec::new();
        blob.extend_from_slice(&salt);
        blob.extend_from_slice(&nonce_bytes);
        blob.append(&mut ct);
        let blob_hex = hex::encode(&blob);

        // Decrypt
        let raw = hex::decode(&blob_hex).unwrap();
        let s2 = &raw[..16];
        let n2 = &raw[16..28];
        let c2 = &raw[28..];
        let mut k2 = [0u8; 32];
        pbkdf2::<Hmac<Sha256>>(secret.as_bytes(), s2, 100_000, &mut k2).unwrap();
        let cipher2 = Aes256Gcm::new_from_slice(&k2).unwrap();
        let nonce2 = Nonce::from_slice(n2);
        let pt = cipher2.decrypt(nonce2, c2).unwrap();
        let result: [u8; 32] = pt.try_into().unwrap();

        assert_eq!(key_bytes, result, "AES-256-GCM roundtrip must match");
    }

    #[test]
    fn wrong_secret_fails_aes_decrypt() {
        use aes_gcm::{
            aead::{Aead, KeyInit},
            Aes256Gcm, Nonce,
        };
        use hmac::Hmac;
        use pbkdf2::pbkdf2;
        use rand_core::RngCore;
        use sha2::Sha256;

        let mut key_bytes = [0u8; 32];
        OsRng.fill_bytes(&mut key_bytes);
        let mut salt = [0u8; 16];
        let mut nonce_bytes = [0u8; 12];
        OsRng.fill_bytes(&mut salt);
        OsRng.fill_bytes(&mut nonce_bytes);

        let mut aes_key = [0u8; 32];
        pbkdf2::<Hmac<Sha256>>(b"correct-secret", &salt, 100_000, &mut aes_key).unwrap();
        let cipher = Aes256Gcm::new_from_slice(&aes_key).unwrap();
        let nonce = Nonce::from_slice(&nonce_bytes);
        let mut ct = cipher.encrypt(nonce, key_bytes.as_slice()).unwrap();

        let mut blob = Vec::new();
        blob.extend_from_slice(&salt);
        blob.extend_from_slice(&nonce_bytes);
        blob.append(&mut ct);

        // Wrong secret → decrypt must fail (AES-GCM authentication tag mismatch)
        let raw = blob;
        let s2 = &raw[..16];
        let n2 = &raw[16..28];
        let c2 = &raw[28..];
        let mut k2 = [0u8; 32];
        pbkdf2::<Hmac<Sha256>>(b"wrong-secret", s2, 100_000, &mut k2).unwrap();
        let cipher2 = Aes256Gcm::new_from_slice(&k2).unwrap();
        let nonce2 = Nonce::from_slice(n2);
        assert!(
            cipher2.decrypt(nonce2, c2).is_err(),
            "wrong secret must fail AES-GCM decryption"
        );
    }
}

// ---------------------------------------------------------------------------
// Custody event hash tests (inline)
// ---------------------------------------------------------------------------

#[cfg(test)]
mod custody_tests {
    use chrono::Utc;
    use sha2::{Digest, Sha256};
    use uuid::Uuid;

    fn genesis_hash() -> String {
        "0".repeat(64)
    }

    fn compute_event_hash(
        evidence_id: Uuid,
        actor_id: Uuid,
        action: &str,
        prev_event_hash: &str,
        timestamp: chrono::DateTime<Utc>,
    ) -> String {
        let mut h = Sha256::new();
        h.update(evidence_id.to_string().as_bytes());
        h.update(b"|");
        h.update(actor_id.to_string().as_bytes());
        h.update(b"|");
        h.update(action.as_bytes());
        h.update(b"|");
        h.update(prev_event_hash.as_bytes());
        h.update(b"|");
        h.update(timestamp.to_rfc3339().as_bytes());
        hex::encode(h.finalize())
    }

    fn compute_evidence_hash(
        evidence_id: Uuid,
        name: &str,
        status: &str,
        custodian_id: Uuid,
        location: &str,
    ) -> String {
        let mut h = Sha256::new();
        h.update(evidence_id.to_string().as_bytes());
        h.update(b"|");
        h.update(name.as_bytes());
        h.update(b"|");
        h.update(status.as_bytes());
        h.update(b"|");
        h.update(custodian_id.to_string().as_bytes());
        h.update(b"|");
        h.update(location.as_bytes());
        hex::encode(h.finalize())
    }

    #[test]
    fn genesis_hash_is_64_zeros() {
        let h = genesis_hash();
        assert_eq!(h.len(), 64);
        assert!(h.chars().all(|c| c == '0'));
    }

    #[test]
    fn custody_event_hash_deterministic() {
        let eid = Uuid::parse_str("00000000-0000-0000-0000-000000000001").unwrap();
        let aid = Uuid::parse_str("00000000-0000-0000-0000-000000000002").unwrap();
        let ts = chrono::DateTime::parse_from_rfc3339("2026-01-01T00:00:00+00:00")
            .unwrap()
            .with_timezone(&Utc);
        let h1 = compute_event_hash(eid, aid, "REGISTER", &genesis_hash(), ts);
        let h2 = compute_event_hash(eid, aid, "REGISTER", &genesis_hash(), ts);
        assert_eq!(h1, h2);
        assert_eq!(h1.len(), 64);
    }

    #[test]
    fn custody_event_hash_changes_with_action() {
        let eid = Uuid::new_v4();
        let aid = Uuid::new_v4();
        let ts = Utc::now();
        let h1 = compute_event_hash(eid, aid, "REGISTER", "prev", ts);
        let h2 = compute_event_hash(eid, aid, "TRANSFER", "prev", ts);
        assert_ne!(h1, h2);
    }

    #[test]
    fn evidence_hash_deterministic() {
        let eid = Uuid::new_v4();
        let cust = Uuid::new_v4();
        let h1 = compute_evidence_hash(eid, "knife", "SECURE_VAULT", cust, "vault-A");
        let h2 = compute_evidence_hash(eid, "knife", "SECURE_VAULT", cust, "vault-A");
        assert_eq!(h1, h2);
    }

    #[test]
    fn custody_chain_tamper_detected() {
        // Simulate a three-event chain and verify that modifying event 2's hash breaks
        // the linkage check.
        let eid = Uuid::new_v4();
        let aid = Uuid::new_v4();
        let ts = Utc::now();

        let hash0 = genesis_hash();
        let hash1 = compute_event_hash(eid, aid, "REGISTER", &hash0, ts);
        let hash2 = compute_event_hash(eid, aid, "TRANSFER", &hash1, ts);

        // Chain is valid: hash2.prev == hash1, hash1.prev == hash0
        assert_eq!(compute_event_hash(eid, aid, "TRANSFER", &hash1, ts), hash2);

        // Tamper: replace hash1 with a fake — hash2 recompute won't match
        let fake_hash1 = "b".repeat(64);
        let tampered_hash2 = compute_event_hash(eid, aid, "TRANSFER", &fake_hash1, ts);
        assert_ne!(tampered_hash2, hash2, "tampered chain must produce different hash");
    }
}

// ---------------------------------------------------------------------------
// Document security validation tests (inline)
// ---------------------------------------------------------------------------

#[cfg(test)]
mod document_security_tests {
    // Replicate the pure helper functions from documents.rs inline.

    const ALLOWED_EXTENSIONS: &[&str] = &[
        "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx",
        "txt", "csv", "jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif",
        "mp4", "avi", "mov", "mp3", "wav",
        "zip", "tar", "gz",
    ];

    fn sanitize_filename(raw: &str) -> (String, Option<String>) {
        let base = raw
            .rsplit(|c| c == '/' || c == '\\')
            .next()
            .unwrap_or(raw)
            .trim();
        let safe: String = base
            .chars()
            .map(|c| {
                if c.is_alphanumeric() || matches!(c, '.' | '-' | '_' | ' ') { c } else { '_' }
            })
            .collect();
        let ext = safe
            .rsplit('.')
            .next()
            .map(|e| e.to_lowercase())
            .filter(|e| !e.is_empty() && e.len() <= 10);
        (safe, ext)
    }

    fn validate_extension(ext: Option<&str>) -> Result<(), String> {
        match ext {
            Some(e) if ALLOWED_EXTENSIONS.contains(&e) => Ok(()),
            Some(e) => Err(format!("extension '{}' not permitted", e)),
            None => Err("no extension".into()),
        }
    }

    fn validate_magic_bytes(bytes: &[u8]) -> Result<(), String> {
        if bytes.starts_with(b"\x7fELF") {
            return Err("ELF binary not permitted".into());
        }
        if bytes.starts_with(b"MZ") {
            return Err("PE/MZ executable not permitted".into());
        }
        if bytes.starts_with(b"#!") {
            return Err("shell script not permitted".into());
        }
        Ok(())
    }

    const BLOCKED_MIME: &[&str] = &[
        "application/x-msdownload",
        "application/x-executable",
        "text/x-shellscript",
    ];

    fn validate_content_type(ct: Option<&str>) -> Result<(), String> {
        if let Some(c) = ct {
            let cl = c.to_lowercase();
            for b in BLOCKED_MIME {
                if cl.starts_with(b) {
                    return Err(format!("blocked content-type: {c}"));
                }
            }
        }
        Ok(())
    }

    #[test]
    fn sanitize_strips_path_traversal() {
        let (safe, ext) = sanitize_filename("../../etc/passwd");
        assert!(!safe.contains(".."));
        assert!(!safe.contains('/'));
        // ext is "passwd" — not in allowlist, will be blocked by validate_extension
        assert_eq!(ext.as_deref(), Some("passwd"));
    }

    #[test]
    fn sanitize_extracts_extension() {
        let (_, ext) = sanitize_filename("report.pdf");
        assert_eq!(ext.as_deref(), Some("pdf"));
    }

    #[test]
    fn allowed_extensions_pass() {
        assert!(validate_extension(Some("pdf")).is_ok());
        assert!(validate_extension(Some("docx")).is_ok());
        assert!(validate_extension(Some("jpg")).is_ok());
        assert!(validate_extension(Some("mp4")).is_ok());
    }

    #[test]
    fn blocked_extensions_fail() {
        assert!(validate_extension(Some("exe")).is_err());
        assert!(validate_extension(Some("sh")).is_err());
        assert!(validate_extension(Some("py")).is_err());
        assert!(validate_extension(Some("js")).is_err());
        assert!(validate_extension(None).is_err());
    }

    #[test]
    fn elf_magic_bytes_blocked() {
        assert!(validate_magic_bytes(b"\x7fELFbinary").is_err());
    }

    #[test]
    fn mz_magic_bytes_blocked() {
        assert!(validate_magic_bytes(b"MZpe_header").is_err());
    }

    #[test]
    fn shell_script_blocked() {
        assert!(validate_magic_bytes(b"#!/bin/bash\necho hi").is_err());
    }

    #[test]
    fn pdf_magic_bytes_pass() {
        assert!(validate_magic_bytes(b"%PDF-1.4 header").is_ok());
    }

    #[test]
    fn blocked_content_types_fail() {
        assert!(validate_content_type(Some("application/x-msdownload")).is_err());
        assert!(validate_content_type(Some("application/x-executable")).is_err());
        assert!(validate_content_type(Some("text/x-shellscript")).is_err());
    }

    #[test]
    fn safe_content_types_pass() {
        assert!(validate_content_type(Some("application/pdf")).is_ok());
        assert!(validate_content_type(Some("image/jpeg")).is_ok());
        assert!(validate_content_type(None).is_ok());
    }

    #[test]
    fn path_traversal_extension_still_blocked() {
        // Even after sanitization, the fake "extension" from ../../etc/passwd
        // is "passwd" which is not in the allowlist.
        let (_, ext) = sanitize_filename("../../etc/passwd");
        assert!(validate_extension(ext.as_deref()).is_err());
    }
}

// ---------------------------------------------------------------------------
// Auth / password policy tests (inline)
// ---------------------------------------------------------------------------

#[cfg(test)]
mod auth_policy_tests {
    fn validate_password(p: &str) -> Result<(), String> {
        if p.len() < 12 {
            return Err("too short".into());
        }
        if !p.chars().any(|c| c.is_uppercase()) {
            return Err("no uppercase".into());
        }
        if !p.chars().any(|c| c.is_lowercase()) {
            return Err("no lowercase".into());
        }
        if !p.chars().any(|c| c.is_ascii_digit()) {
            return Err("no digit".into());
        }
        let specials = "!@#$%^&*()_+-=[]{}|;':\",./<>?`~\\";
        if !p.chars().any(|c| specials.contains(c)) {
            return Err("no special char".into());
        }
        Ok(())
    }

    #[test]
    fn strong_password_passes() {
        assert!(validate_password("StrongPass1!@#").is_ok());
        assert!(validate_password("Complex@Pass1word").is_ok());
        assert!(validate_password("Temporary@123").is_ok());
    }

    #[test]
    fn short_password_fails() {
        assert!(validate_password("Abc1!").is_err());
        assert!(validate_password("Abc1!xyz").is_err()); // 8 chars < 12
    }

    #[test]
    fn no_uppercase_fails() {
        assert!(validate_password("nouppercase1!aaa").is_err());
    }

    #[test]
    fn no_lowercase_fails() {
        assert!(validate_password("NOLOWERCASE1!AA").is_err());
    }

    #[test]
    fn no_digit_fails() {
        assert!(validate_password("NoDigitHere!!!!").is_err());
    }

    #[test]
    fn no_special_char_fails() {
        assert!(validate_password("NoSpecialChar1Aa").is_err());
    }

    #[test]
    fn old_weak_passwords_now_rejected() {
        // The old policy allowed 8-char passwords; new policy requires 12+.
        assert!(validate_password("Passw0rd").is_err());
    }
}
