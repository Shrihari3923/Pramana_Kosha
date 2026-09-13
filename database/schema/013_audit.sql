-- =============================================================================
-- 013_audit.sql
-- Tamper-evident audit trail with cryptographic hash chain
-- =============================================================================
-- Design:
--   Every sensitive action produces one AuditEvent row.
--   Each row contains:
--     hash = SHA-256( previous_hash || event_data )
--   This forms a linked chain. Tampering with any row breaks the chain,
--   detectable by verify_audit_chain().
--
--   The chain is PER-CASE for case-related events, and GLOBAL for system events.
--   Records are append-only — UPDATE and DELETE are blocked by trigger.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. AUDIT EVENT — primary tamper-evident audit record
-- ---------------------------------------------------------------------------
CREATE TABLE audit.audit_event (
    audit_id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Chain references
    chain_id              UUID         NOT NULL,
                          -- Case UUID for case events; a fixed GLOBAL_CHAIN UUID for system events
    previous_audit_id     UUID         REFERENCES audit.audit_event(audit_id),
    previous_hash         VARCHAR(64),  -- SHA-256 of the previous event in this chain
    event_hash            VARCHAR(64)  NOT NULL,
                          -- SHA-256( previous_hash || chain_id || action_code ||
                          --           officer_id || resource_type || resource_id ||
                          --           result || timestamp_iso )

    -- Event metadata
    action_code           VARCHAR(60)  NOT NULL REFERENCES reference.audit_action_type(action_code),
    event_timestamp       TIMESTAMPTZ  NOT NULL DEFAULT now(),
    severity              VARCHAR(20)  NOT NULL DEFAULT 'INFO'
                                       CHECK (severity IN ('INFO','WARN','CRITICAL')),

    -- Who
    officer_id            UUID         REFERENCES identity.officer(officer_id),
    officer_name          VARCHAR(200),   -- denormalised snapshot
    officer_rank          VARCHAR(40),    -- denormalised snapshot
    session_id            UUID         REFERENCES identity.officer_session(session_id),

    -- Where (organisational context at time of action)
    police_station_id     UUID         REFERENCES organisation.police_station(station_id),
    station_name          VARCHAR(200),   -- denormalised snapshot

    -- What
    case_id               UUID         REFERENCES case_mgmt.case(case_id),
    case_number           VARCHAR(60),    -- denormalised snapshot
    resource_type         VARCHAR(60),    -- CASE, FIR, EVIDENCE, DOCUMENT, OFFICER, etc.
    resource_id           UUID,
    resource_ref          VARCHAR(120),   -- human-readable ref (case_number, evidence_number, etc.)

    -- Result
    result                VARCHAR(20)  NOT NULL DEFAULT 'SUCCESS'
                                       CHECK (result IN ('SUCCESS','FAILURE','PARTIAL','BLOCKED')),
    failure_reason        TEXT,

    -- State snapshots (before/after for change events)
    previous_state        JSONB,
    new_state             JSONB,

    -- Network/device context
    ip_address            INET,
    user_agent            TEXT,
    device_fingerprint    VARCHAR(255),

    -- Additional context
    reason                TEXT,
    notes                 TEXT,
    metadata              JSONB        NOT NULL DEFAULT '{}',

    -- Immutability: no UPDATE or DELETE (trigger enforced)
    created_at            TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_audit_chain_id    ON audit.audit_event(chain_id);
CREATE INDEX idx_audit_action      ON audit.audit_event(action_code);
CREATE INDEX idx_audit_timestamp   ON audit.audit_event(event_timestamp);
CREATE INDEX idx_audit_officer     ON audit.audit_event(officer_id);
CREATE INDEX idx_audit_case        ON audit.audit_event(case_id);
CREATE INDEX idx_audit_resource    ON audit.audit_event(resource_type, resource_id);
CREATE INDEX idx_audit_severity    ON audit.audit_event(severity);
CREATE INDEX idx_audit_result      ON audit.audit_event(result);
-- Composite: most common query pattern — all events for a case ordered by time
CREATE INDEX idx_audit_case_time   ON audit.audit_event(case_id, event_timestamp DESC);
-- Composite: chain traversal
CREATE INDEX idx_audit_prev        ON audit.audit_event(previous_audit_id);

-- Add deferred FK from custody events to audit
ALTER TABLE custody.evidence_custody_event
    ADD CONSTRAINT fk_custody_audit
    FOREIGN KEY (audit_event_id)
    REFERENCES audit.audit_event(audit_id)
    DEFERRABLE INITIALLY DEFERRED;

-- ---------------------------------------------------------------------------
-- 2. AUDIT CHAIN — tracks the head of each hash chain
--    One row per chain_id. Updated atomically when a new event is appended.
--    GLOBAL_CHAIN_ID is a well-known constant UUID for non-case system events.
-- ---------------------------------------------------------------------------
CREATE TABLE audit.audit_chain (
    chain_id              UUID         PRIMARY KEY,
                          -- Equals case_id for case chains; GLOBAL_CHAIN_ID for system
    chain_type            VARCHAR(20)  NOT NULL DEFAULT 'CASE'
                                       CHECK (chain_type IN ('CASE','GLOBAL','STATION')),
    head_audit_id         UUID         REFERENCES audit.audit_event(audit_id),
    head_hash             VARCHAR(64),
    event_count           BIGINT       NOT NULL DEFAULT 0,
    last_event_at         TIMESTAMPTZ,
    chain_status          VARCHAR(20)  NOT NULL DEFAULT 'INTACT'
                                       CHECK (chain_status IN ('INTACT','BROKEN','UNVERIFIED')),
    last_verified_at      TIMESTAMPTZ,
    created_at            TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at            TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- The well-known global chain UUID — used for all non-case system events
INSERT INTO audit.audit_chain (chain_id, chain_type) VALUES
('00000000-0000-0000-0000-000000000001', 'GLOBAL');

CREATE INDEX idx_audit_chain_type   ON audit.audit_chain(chain_type);
CREATE INDEX idx_audit_chain_status ON audit.audit_chain(chain_status);

-- ---------------------------------------------------------------------------
-- 3. SECURITY ALERT — generated when suspicious patterns are detected
--    Different from integrity.integrity_alert (which is about file hashes).
--    This covers login anomalies, access pattern violations, etc.
-- ---------------------------------------------------------------------------
CREATE TABLE audit.security_alert (
    alert_id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    alert_type            VARCHAR(60)  NOT NULL
                                       CHECK (alert_type IN (
                                           'BRUTE_FORCE_LOGIN',
                                           'UNAUTHORIZED_ACCESS_ATTEMPT',
                                           'PRIVILEGE_ESCALATION',
                                           'AUDIT_CHAIN_TAMPER',
                                           'UNUSUAL_DOWNLOAD_VOLUME',
                                           'ACCESS_OUTSIDE_HOURS',
                                           'MULTIPLE_FAILED_ACTIONS',
                                           'SENSITIVE_DATA_EXPORT',
                                           'OTHER')),

    severity              VARCHAR(20)  NOT NULL DEFAULT 'HIGH'
                                       CHECK (severity IN ('LOW','MEDIUM','HIGH','CRITICAL')),

    officer_id            UUID         REFERENCES identity.officer(officer_id),
    case_id               UUID         REFERENCES case_mgmt.case(case_id),
    station_id            UUID         REFERENCES organisation.police_station(station_id),

    -- Triggering audit event
    trigger_audit_id      UUID         REFERENCES audit.audit_event(audit_id),

    title                 VARCHAR(300) NOT NULL,
    description           TEXT         NOT NULL,

    -- Evidence of the anomaly
    evidence_detail       JSONB        NOT NULL DEFAULT '{}',

    alert_status          VARCHAR(30)  NOT NULL DEFAULT 'OPEN'
                                       CHECK (alert_status IN (
                                           'OPEN','ACKNOWLEDGED','INVESTIGATING',
                                           'RESOLVED','FALSE_POSITIVE')),

    detected_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),
    detected_by           VARCHAR(60)  NOT NULL DEFAULT 'SYSTEM',  -- SYSTEM or officer_id

    acknowledged_by       UUID         REFERENCES identity.officer(officer_id),
    acknowledged_at       TIMESTAMPTZ,

    resolved_by           UUID         REFERENCES identity.officer(officer_id),
    resolved_at           TIMESTAMPTZ,
    resolution_notes      TEXT,

    created_at            TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at            TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_sec_alert_type     ON audit.security_alert(alert_type);
CREATE INDEX idx_sec_alert_officer  ON audit.security_alert(officer_id);
CREATE INDEX idx_sec_alert_case     ON audit.security_alert(case_id);
CREATE INDEX idx_sec_alert_severity ON audit.security_alert(severity);
CREATE INDEX idx_sec_alert_status   ON audit.security_alert(alert_status);
CREATE INDEX idx_sec_alert_time     ON audit.security_alert(detected_at);

-- ---------------------------------------------------------------------------
-- 4. AUDIT SUMMARY — materialised daily summary for dashboards
--    Populated by a scheduled job or trigger; not a materialised view
--    (to avoid pg_matview refresh complexity for the MVP).
-- ---------------------------------------------------------------------------
CREATE TABLE audit.audit_summary (
    summary_id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    summary_date          DATE         NOT NULL,
    station_id            UUID         REFERENCES organisation.police_station(station_id),
    case_id               UUID         REFERENCES case_mgmt.case(case_id),

    total_events          INTEGER      NOT NULL DEFAULT 0,
    critical_events       INTEGER      NOT NULL DEFAULT 0,
    failed_events         INTEGER      NOT NULL DEFAULT 0,
    login_events          INTEGER      NOT NULL DEFAULT 0,
    document_downloads    INTEGER      NOT NULL DEFAULT 0,
    evidence_transfers    INTEGER      NOT NULL DEFAULT 0,
    alerts_raised         INTEGER      NOT NULL DEFAULT 0,

    computed_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),

    UNIQUE (summary_date, station_id, case_id)
);

CREATE INDEX idx_audit_sum_date    ON audit.audit_summary(summary_date);
CREATE INDEX idx_audit_sum_station ON audit.audit_summary(station_id);

-- ---------------------------------------------------------------------------
-- 5. LOGIN ATTEMPT LOG — dedicated table for authentication audit
--    Kept separate from the main audit chain to allow high-volume inserts
--    without impacting the chain performance.
-- ---------------------------------------------------------------------------
CREATE TABLE audit.login_attempt (
    attempt_id        UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    username          VARCHAR(60)  NOT NULL,
    officer_id        UUID         REFERENCES identity.officer(officer_id),
    attempt_timestamp TIMESTAMPTZ  NOT NULL DEFAULT now(),
    result            VARCHAR(20)  NOT NULL CHECK (result IN ('SUCCESS','FAILED','LOCKED','MFA_REQUIRED','MFA_FAILED')),
    failure_reason    TEXT,
    ip_address        INET,
    user_agent        TEXT,
    session_id        UUID         REFERENCES identity.officer_session(session_id)
);

CREATE INDEX idx_login_officer   ON audit.login_attempt(officer_id);
CREATE INDEX idx_login_username  ON audit.login_attempt(username);
CREATE INDEX idx_login_timestamp ON audit.login_attempt(attempt_timestamp);
CREATE INDEX idx_login_result    ON audit.login_attempt(result);
-- Composite: brute-force detection — recent failures for a username
CREATE INDEX idx_login_bf_detect ON audit.login_attempt(username, result, attempt_timestamp DESC);
