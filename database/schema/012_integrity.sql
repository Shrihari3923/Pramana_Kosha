-- =============================================================================
-- 012_integrity.sql
-- Document and evidence integrity verification, hash records, alerts
-- =============================================================================
-- Purpose:
--   This schema answers the two critical questions:
--     1. "Is this document the exact version that was finalized?"
--     2. "Has the file changed since finalization?"
--   It also supports the QR / document-passport concept and raises
--   integrity alerts when hash mismatches are detected.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. INTEGRITY RECORD — master hash record for any verifiable entity
--    Created at the moment of finalization/sealing.
--    One record per (resource_type, resource_id, version).
--    Records are append-only; never updated.
-- ---------------------------------------------------------------------------
CREATE TABLE integrity.integrity_record (
    integrity_id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),

    -- What is being protected
    resource_type         VARCHAR(40)  NOT NULL
                                       CHECK (resource_type IN (
                                           'DOCUMENT_VERSION','EVIDENCE',
                                           'DIGITAL_EVIDENCE','FORENSIC_IMAGE',
                                           'CUSTODY_EVENT','AUDIT_EVENT')),
    resource_id           UUID         NOT NULL,

    -- The hash at time of finalization
    hash_value            VARCHAR(128) NOT NULL,
    hash_algorithm        VARCHAR(20)  NOT NULL DEFAULT 'SHA256'
                                       REFERENCES reference.hash_algorithm(algo_code),

    -- Secondary hash for extra assurance
    secondary_hash        VARCHAR(128),
    secondary_algorithm   VARCHAR(20)  REFERENCES reference.hash_algorithm(algo_code),

    -- Who created this record and when
    recorded_by           UUID         NOT NULL REFERENCES identity.officer(officer_id),
    recorded_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),

    -- Case and station context
    case_id               UUID         REFERENCES case_mgmt.case(case_id),
    station_id            UUID         REFERENCES organisation.police_station(station_id),

    -- Current verification status
    verification_status   VARCHAR(30)  NOT NULL DEFAULT 'UNVERIFIED'
                                       CHECK (verification_status IN (
                                           'UNVERIFIED','VERIFIED_INTACT',
                                           'HASH_MISMATCH','SIGNATURE_INVALID',
                                           'COMPROMISED')),
    last_verified_at      TIMESTAMPTZ,
    last_verified_by      UUID         REFERENCES identity.officer(officer_id),

    -- QR / document passport payload stored as JSONB
    -- Allows offline verification: scan QR → get this JSON → verify hash
    passport_payload      JSONB        NOT NULL DEFAULT '{}',

    -- Immutability: no UPDATE or DELETE (trigger enforced)
    created_at            TIMESTAMPTZ  NOT NULL DEFAULT now(),

    UNIQUE (resource_type, resource_id)
);

CREATE INDEX idx_integrity_resource    ON integrity.integrity_record(resource_type, resource_id);
CREATE INDEX idx_integrity_case        ON integrity.integrity_record(case_id);
CREATE INDEX idx_integrity_hash        ON integrity.integrity_record(hash_value);
CREATE INDEX idx_integrity_status      ON integrity.integrity_record(verification_status);
CREATE INDEX idx_integrity_passport    ON integrity.integrity_record USING gin(passport_payload);

-- ---------------------------------------------------------------------------
-- 2. VERIFICATION EVENT — each time a document/evidence is verified
--    Captures the result of hash re-computation against stored hash.
-- ---------------------------------------------------------------------------
CREATE TABLE integrity.verification_event (
    verification_id       UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    integrity_id          UUID         NOT NULL REFERENCES integrity.integrity_record(integrity_id),

    resource_type         VARCHAR(40)  NOT NULL,
    resource_id           UUID         NOT NULL,

    -- Verification details
    verification_method   VARCHAR(40)  NOT NULL DEFAULT 'HASH_COMPARISON'
                                       CHECK (verification_method IN (
                                           'HASH_COMPARISON','SIGNATURE_VERIFICATION',
                                           'MANUAL','AUTOMATED')),

    -- Hash computed at time of this verification
    computed_hash         VARCHAR(128) NOT NULL,
    stored_hash           VARCHAR(128) NOT NULL,
    hash_algorithm        VARCHAR(20)  NOT NULL DEFAULT 'SHA256',

    -- Result
    result                VARCHAR(30)  NOT NULL
                                       CHECK (result IN (
                                           'INTACT','HASH_MISMATCH',
                                           'SIGNATURE_INVALID','ERROR')),
    result_detail         TEXT,

    -- Who verified
    verified_by           UUID         NOT NULL REFERENCES identity.officer(officer_id),
    verified_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),

    -- Session and device context
    session_id            UUID         REFERENCES identity.officer_session(session_id),
    ip_address            INET,

    -- Alert raised?
    alert_raised          BOOLEAN      NOT NULL DEFAULT FALSE,
    alert_id              UUID,        -- FK to integrity_alert added below

    created_at            TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_ver_event_integrity ON integrity.verification_event(integrity_id);
CREATE INDEX idx_ver_event_resource  ON integrity.verification_event(resource_type, resource_id);
CREATE INDEX idx_ver_event_result    ON integrity.verification_event(result);
CREATE INDEX idx_ver_event_time      ON integrity.verification_event(verified_at);

-- ---------------------------------------------------------------------------
-- 3. INTEGRITY ALERT — raised when verification fails
--    Critical events that require immediate attention.
-- ---------------------------------------------------------------------------
CREATE TABLE integrity.integrity_alert (
    alert_id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    integrity_id          UUID         NOT NULL REFERENCES integrity.integrity_record(integrity_id),
    verification_id       UUID         REFERENCES integrity.verification_event(verification_id),

    resource_type         VARCHAR(40)  NOT NULL,
    resource_id           UUID         NOT NULL,
    case_id               UUID         REFERENCES case_mgmt.case(case_id),

    alert_type            VARCHAR(40)  NOT NULL
                                       CHECK (alert_type IN (
                                           'HASH_MISMATCH','SIGNATURE_INVALID',
                                           'UNEXPECTED_MODIFICATION',
                                           'UNAUTHORIZED_ACCESS',
                                           'AUDIT_CHAIN_BROKEN',
                                           'CUSTODY_SEAL_BROKEN',
                                           'OTHER')),
    severity              VARCHAR(20)  NOT NULL DEFAULT 'CRITICAL'
                                       CHECK (severity IN ('LOW','MEDIUM','HIGH','CRITICAL')),

    alert_title           VARCHAR(300) NOT NULL,
    alert_description     TEXT         NOT NULL,

    -- Expected vs actual values
    expected_value        TEXT,
    actual_value          TEXT,

    -- Who detected this
    detected_by           UUID         REFERENCES identity.officer(officer_id),
    detected_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),

    -- Resolution
    alert_status          VARCHAR(30)  NOT NULL DEFAULT 'OPEN'
                                       CHECK (alert_status IN (
                                           'OPEN','ACKNOWLEDGED','INVESTIGATING',
                                           'RESOLVED','FALSE_POSITIVE')),
    resolved_by           UUID         REFERENCES identity.officer(officer_id),
    resolved_at           TIMESTAMPTZ,
    resolution_notes      TEXT,

    -- Notification sent?
    notification_sent     BOOLEAN      NOT NULL DEFAULT FALSE,
    notified_officers     JSONB        NOT NULL DEFAULT '[]',

    created_at            TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at            TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_alert_integrity  ON integrity.integrity_alert(integrity_id);
CREATE INDEX idx_alert_case       ON integrity.integrity_alert(case_id);
CREATE INDEX idx_alert_type       ON integrity.integrity_alert(alert_type);
CREATE INDEX idx_alert_severity   ON integrity.integrity_alert(severity);
CREATE INDEX idx_alert_status     ON integrity.integrity_alert(alert_status);
CREATE INDEX idx_alert_detected   ON integrity.integrity_alert(detected_at);

-- Back-fill the alert FK on verification_event
ALTER TABLE integrity.verification_event
    ADD CONSTRAINT fk_ver_alert
    FOREIGN KEY (alert_id)
    REFERENCES integrity.integrity_alert(alert_id)
    DEFERRABLE INITIALLY DEFERRED;

-- ---------------------------------------------------------------------------
-- 4. DOCUMENT PASSPORT — QR-scannable verification passport for a document version
--    Generated when a document is finalized.
--    Contains enough data to verify the document offline.
-- ---------------------------------------------------------------------------
CREATE TABLE integrity.document_passport (
    passport_id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id           UUID         NOT NULL REFERENCES documents.document(document_id),
    version_id            UUID         NOT NULL UNIQUE REFERENCES documents.document_version(version_id),
    integrity_id          UUID         NOT NULL REFERENCES integrity.integrity_record(integrity_id),

    -- The unique passport code embedded in the QR
    passport_code         VARCHAR(80)  NOT NULL UNIQUE,

    -- Payload embedded in QR (JSON string, also stored in integrity_record.passport_payload)
    qr_payload            JSONB        NOT NULL,

    -- QR image stored in object storage
    qr_image_object_id    VARCHAR(255),
    qr_image_path         TEXT,

    issued_by             UUID         NOT NULL REFERENCES identity.officer(officer_id),
    issued_at             TIMESTAMPTZ  NOT NULL DEFAULT now(),

    is_active             BOOLEAN      NOT NULL DEFAULT TRUE,
    revoked_at            TIMESTAMPTZ,
    revoked_by            UUID         REFERENCES identity.officer(officer_id),
    revocation_reason     TEXT,

    created_at            TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_passport_document ON integrity.document_passport(document_id);
CREATE INDEX idx_passport_version  ON integrity.document_passport(version_id);
CREATE INDEX idx_passport_code     ON integrity.document_passport(passport_code);
