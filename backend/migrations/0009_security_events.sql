-- Security event log: login attempts, authorization failures, suspicious activity.
-- Separate from the audit log (which is the business-logic hash-chain).
-- This table supports the Security Dashboard.

CREATE TABLE login_attempts (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email       TEXT NOT NULL,              -- the email attempted (not necessarily a real user)
    ip_address  TEXT,                       -- client IP if available (may be NULL behind proxy)
    success     BOOLEAN NOT NULL,
    failure_reason TEXT,                    -- 'invalid_credentials', 'account_locked', etc.
    attempted_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_login_attempts_email       ON login_attempts(email);
CREATE INDEX idx_login_attempts_attempted_at ON login_attempts(attempted_at);
CREATE INDEX idx_login_attempts_success      ON login_attempts(success, attempted_at);

-- General security event log (authorization denials, suspicious activity, etc.)
CREATE TABLE security_events (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type  TEXT NOT NULL,              -- 'AUTH_FAILURE', 'AUTHZ_DENIED', 'TAMPER_DETECTED', 'INTEGRITY_VIOLATION', etc.
    severity    TEXT NOT NULL DEFAULT 'INFO', -- 'INFO', 'WARNING', 'CRITICAL'
    actor_id    UUID REFERENCES users(id),  -- NULL for unauthenticated events
    resource    TEXT,                       -- what resource was being accessed
    detail      TEXT,                       -- human-readable detail (no secrets)
    ip_address  TEXT,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_security_events_type        ON security_events(event_type);
CREATE INDEX idx_security_events_occurred_at ON security_events(occurred_at);
CREATE INDEX idx_security_events_actor_id    ON security_events(actor_id);
CREATE INDEX idx_security_events_severity    ON security_events(severity, occurred_at);
