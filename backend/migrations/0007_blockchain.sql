-- Permissioned blockchain ledger stored in PostgreSQL.
-- Cryptographic block structure with Merkle roots and transaction hashing.
-- This is the immutable evidence ledger for ChainDock.

-- Each block in the chain
CREATE TABLE blockchain_blocks (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    block_index   BIGINT NOT NULL UNIQUE,   -- monotonic sequence; defines chain order
    prev_block_hash TEXT NOT NULL,           -- sha256 of previous block; genesis = 64 zeroes
    merkle_root   TEXT NOT NULL,             -- sha256 Merkle root of all transactions in this block
    block_hash    TEXT NOT NULL UNIQUE,      -- sha256(block_index || prev_block_hash || merkle_root || timestamp || nonce)
    nonce         BIGINT NOT NULL DEFAULT 0,
    timestamp     TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_blockchain_blocks_index ON blockchain_blocks(block_index);
CREATE INDEX idx_blockchain_blocks_hash  ON blockchain_blocks(block_hash);

-- Each transaction recorded in a block
CREATE TABLE blockchain_transactions (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    block_id         UUID NOT NULL REFERENCES blockchain_blocks(id),
    tx_index         INT NOT NULL DEFAULT 0,       -- position within its block
    actor_id         UUID NOT NULL REFERENCES users(id),
    case_id          UUID REFERENCES cases(id),
    document_id      UUID REFERENCES documents(id),
    action           TEXT NOT NULL,                -- e.g. DOCUMENT_UPLOAD, CASE_CREATE, SIGN_DOCUMENT
    payload_hash     TEXT NOT NULL,                -- sha256 of the action payload (metadata, not content)
    prev_tx_hash     TEXT NOT NULL,                -- sha256 of previous transaction (global chain); genesis = 64 zeroes
    tx_hash          TEXT NOT NULL UNIQUE,         -- sha256(actor_id || action || payload_hash || prev_tx_hash || timestamp)
    timestamp        TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_blockchain_tx_block_id    ON blockchain_transactions(block_id);
CREATE INDEX idx_blockchain_tx_document_id ON blockchain_transactions(document_id);
CREATE INDEX idx_blockchain_tx_case_id     ON blockchain_transactions(case_id);
CREATE INDEX idx_blockchain_tx_actor_id    ON blockchain_transactions(actor_id);
CREATE INDEX idx_blockchain_tx_hash        ON blockchain_transactions(tx_hash);

-- Seed genesis block immediately so the chain is never empty.
-- Genesis prev_block_hash = 64 zeroes; merkle_root = sha256('GENESIS'); block_hash computed deterministically.
INSERT INTO blockchain_blocks (
    id, block_index, prev_block_hash, merkle_root, block_hash, nonce, timestamp
) VALUES (
    '00000000-0000-0000-0000-000000000001',
    0,
    '0000000000000000000000000000000000000000000000000000000000000000',
    'b6e16d27ac5ab427a7f68900ac5559ce272dc6c37c82b3e052246c82244c50e4', -- sha256('GENESIS')
    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855', -- placeholder; will be recomputed at startup
    0,
    '2026-01-01 00:00:00+00'
);
