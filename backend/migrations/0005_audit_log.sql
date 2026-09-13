-- The hash-chain: a single-writer append-only log. Every mutating action gets a row.
-- `seq` (not `id`) defines chain order — gen_random_uuid() isn't monotonic, so we
-- can't rely on UUID ordering to reconstruct "what happened before this row".
--
-- entry_hash = sha256(prev_hash + actor_id + action + document_id + case_id + created_at)
-- prev_hash of the first row in the chain is 64 zero chars (the "genesis" hash).
--
-- Verification (GET /audit/verify-chain) walks the chain in `seq` order, recomputes
-- each entry_hash from its stored fields, and checks it against both the stored
-- entry_hash and the previous row's entry_hash (via this row's prev_hash). Any
-- mismatch = everything from that point on is provably altered.
CREATE TABLE audit_log (
    seq         BIGSERIAL PRIMARY KEY,
    id          UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    prev_hash   TEXT NOT NULL,
    entry_hash  TEXT NOT NULL,
    actor_id    UUID NOT NULL REFERENCES users(id),
    action      TEXT NOT NULL,
    document_id UUID REFERENCES documents(id),
    case_id     UUID REFERENCES cases(id),
    created_at  TIMESTAMPTZ NOT NULL
);

CREATE INDEX idx_audit_log_case_id ON audit_log(case_id);
CREATE INDEX idx_audit_log_created_at ON audit_log(created_at);
