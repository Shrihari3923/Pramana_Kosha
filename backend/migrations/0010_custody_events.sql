-- Cryptographically-linked chain of custody for evidence items.
-- Each custody event references the previous event's hash, forming a tamper-evident chain.

-- Evidence items table (was missing from backend; previously only a frontend concept)
CREATE TABLE evidence_items (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    case_id      UUID NOT NULL REFERENCES cases(id) ON DELETE CASCADE,
    item_number  TEXT NOT NULL,             -- human-facing identifier, e.g. "EV-2026-001"
    name         TEXT NOT NULL,
    category     TEXT NOT NULL DEFAULT 'PHYSICAL', -- 'PHYSICAL', 'DIGITAL', 'BIOLOGICAL', 'DOCUMENT'
    description  TEXT NOT NULL DEFAULT '',
    status       TEXT NOT NULL DEFAULT 'SECURE_VAULT', -- 'SECURE_VAULT','IN_TRANSIT','COURT_EXHIBIT','ANALYSIS'
    custodian_id UUID NOT NULL REFERENCES users(id),   -- current custodian
    location     TEXT NOT NULL DEFAULT '',
    sealed_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by   UUID NOT NULL REFERENCES users(id),
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (case_id, item_number)
);

CREATE INDEX idx_evidence_items_case_id     ON evidence_items(case_id);
CREATE INDEX idx_evidence_items_custodian_id ON evidence_items(custodian_id);

-- Hash-chained custody transfer events
CREATE TABLE custody_events (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    evidence_id       UUID NOT NULL REFERENCES evidence_items(id) ON DELETE CASCADE,
    seq               BIGSERIAL NOT NULL,              -- monotonic ordering within global chain
    actor_id          UUID NOT NULL REFERENCES users(id),
    prev_custodian_id UUID REFERENCES users(id),       -- NULL for initial custody
    new_custodian_id  UUID NOT NULL REFERENCES users(id),
    action            TEXT NOT NULL,                   -- 'REGISTER','TRANSFER','ANALYSIS','COURT_EXHIBIT','SEAL'
    location          TEXT NOT NULL DEFAULT '',
    notes             TEXT NOT NULL DEFAULT '',
    -- Cryptographic linking
    evidence_hash     TEXT NOT NULL,                   -- sha256 of evidence item state snapshot
    prev_event_hash   TEXT NOT NULL,                   -- sha256 of previous custody event; genesis = 64 zeroes
    event_hash        TEXT NOT NULL UNIQUE,            -- sha256(evidence_id || actor_id || action || prev_event_hash || timestamp)
    -- Blockchain integration
    blockchain_tx_id  UUID REFERENCES blockchain_transactions(id),
    occurred_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_custody_events_evidence_id ON custody_events(evidence_id);
CREATE INDEX idx_custody_events_seq         ON custody_events(seq);
CREATE INDEX idx_custody_events_actor_id    ON custody_events(actor_id);
