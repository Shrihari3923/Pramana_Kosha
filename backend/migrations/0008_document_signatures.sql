-- Ed25519 digital signatures on documents.
-- Private keys are NEVER stored here. Only public keys and signatures.

-- Per-user Ed25519 signing key records.
-- The private key bytes are stored encrypted (XOR with a server key derived from JWT_SECRET)
-- as a development-mode key store. In production this would be replaced with an HSM.
-- The column is named clearly to indicate its nature.
CREATE TABLE signing_keys (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    public_key_hex  TEXT NOT NULL,              -- Ed25519 public key, hex-encoded (32 bytes = 64 hex chars)
    -- Development-mode encrypted private key. In production: remove this column, use HSM.
    -- Encrypted with AES-256-GCM using a key derived from server KEY_ENCRYPTION_SECRET.
    encrypted_private_key TEXT,                 -- NULL if HSM mode; non-null in dev mode only
    key_mode        TEXT NOT NULL DEFAULT 'DEV', -- 'DEV' or 'HSM'
    fingerprint     TEXT NOT NULL,              -- sha256(public_key_hex), first 16 hex chars
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    revoked_at      TIMESTAMPTZ,
    UNIQUE (user_id, public_key_hex)
);

CREATE INDEX idx_signing_keys_user_id ON signing_keys(user_id);

-- Per-document Ed25519 signatures
CREATE TABLE document_signatures (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id     UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    signing_key_id  UUID NOT NULL REFERENCES signing_keys(id),
    signer_id       UUID NOT NULL REFERENCES users(id),
    document_hash   TEXT NOT NULL,              -- sha256 of the file bytes at time of signing
    signature_hex   TEXT NOT NULL,              -- Ed25519 signature, hex-encoded (64 bytes = 128 hex chars)
    signed_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- Blockchain transaction recording this signature event
    blockchain_tx_id UUID REFERENCES blockchain_transactions(id),
    UNIQUE (document_id, signer_id)             -- one signature per (document, signer)
);

CREATE INDEX idx_document_signatures_document_id ON document_signatures(document_id);
CREATE INDEX idx_document_signatures_signer_id   ON document_signatures(signer_id);
