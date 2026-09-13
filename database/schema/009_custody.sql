-- =============================================================================
-- 009_custody.sql
-- Chain of Custody — Graph 2 (separate from evidentiary relationship graph)
-- Models the physical/logical movement of evidence between custodians.
-- Records are append-only by design (trigger prevents UPDATE/DELETE).
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. CUSTODIAN — represents any entity that can hold evidence
--    This is a polymorphic reference resolved by custodian_type_code:
--    OFFICER     → identity.officer.officer_id
--    MALKHANA    → organisation.police_station.station_id
--    FSL         → organisation.forensic_laboratory.lab_id
--    COURT       → organisation.court.court_id
--    PROSECUTION → organisation.external_agency.agency_id
--    EXTERNAL_AGENCY → organisation.external_agency.agency_id
--    OWNER       → identity.person.person_id
-- ---------------------------------------------------------------------------
CREATE TABLE custody.custodian (
    custodian_id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    custodian_type_code   VARCHAR(40)  NOT NULL REFERENCES reference.custodian_type(custodian_type_code),

    -- Resolved entity reference (polymorphic — only one will be non-NULL)
    officer_id            UUID         REFERENCES identity.officer(officer_id),
    station_id            UUID         REFERENCES organisation.police_station(station_id),
    lab_id                UUID         REFERENCES organisation.forensic_laboratory(lab_id),
    court_id              UUID         REFERENCES organisation.court(court_id),
    agency_id             UUID         REFERENCES organisation.external_agency(agency_id),
    person_id             UUID         REFERENCES identity.person(person_id),

    display_name          VARCHAR(200) NOT NULL,   -- denormalised for display

    is_active             BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at            TIMESTAMPTZ  NOT NULL DEFAULT now(),

    -- Ensure exactly one entity FK is populated for known types
    CONSTRAINT chk_custodian_officer     CHECK (custodian_type_code <> 'OFFICER'     OR officer_id  IS NOT NULL),
    CONSTRAINT chk_custodian_malkhana    CHECK (custodian_type_code <> 'MALKHANA'    OR station_id  IS NOT NULL),
    CONSTRAINT chk_custodian_fsl         CHECK (custodian_type_code <> 'FSL'         OR lab_id      IS NOT NULL),
    CONSTRAINT chk_custodian_court       CHECK (custodian_type_code <> 'COURT'       OR court_id    IS NOT NULL),
    CONSTRAINT chk_custodian_owner       CHECK (custodian_type_code <> 'OWNER'       OR person_id   IS NOT NULL)
);

CREATE INDEX idx_custodian_type     ON custody.custodian(custodian_type_code);
CREATE INDEX idx_custodian_officer  ON custody.custodian(officer_id);
CREATE INDEX idx_custodian_station  ON custody.custodian(station_id);
CREATE INDEX idx_custodian_lab      ON custody.custodian(lab_id);
CREATE INDEX idx_custodian_court    ON custody.custodian(court_id);

-- ---------------------------------------------------------------------------
-- 2. EVIDENCE CUSTODY EVENT — the append-only custody chain record
--    Every physical movement of evidence creates one row here.
--    UPDATE and DELETE are prevented by trigger (see functions file).
-- ---------------------------------------------------------------------------
CREATE TABLE custody.evidence_custody_event (
    custody_event_id      UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    evidence_id           UUID         NOT NULL REFERENCES evidence.evidence(evidence_id),
    case_id               UUID         NOT NULL REFERENCES case_mgmt.case(case_id),

    event_type_code       VARCHAR(40)  NOT NULL REFERENCES reference.custody_event_type(event_type_code),
    event_sequence        INTEGER      NOT NULL,   -- sequential within evidence item; managed by trigger

    event_timestamp       TIMESTAMPTZ  NOT NULL DEFAULT now(),
    recorded_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),
    recorded_by           UUID         NOT NULL REFERENCES identity.officer(officer_id),

    -- From / To custodians
    from_custodian_id     UUID         REFERENCES custody.custodian(custodian_id),
    to_custodian_id       UUID         NOT NULL REFERENCES custody.custodian(custodian_id),

    -- Location of transfer
    transfer_location     TEXT,
    transfer_latitude     NUMERIC(10,7),
    transfer_longitude    NUMERIC(10,7),

    -- Purpose / reason
    purpose               TEXT,

    -- Physical seal
    seal_number_before    VARCHAR(80),
    seal_number_after     VARCHAR(80),
    seal_status           VARCHAR(30)  CHECK (seal_status IN (
                                           'INTACT','BROKEN','RESEALED','NEW','NOT_APPLICABLE')),

    -- Condition of evidence
    condition_before      TEXT,
    condition_after       TEXT,

    -- Cryptographic integrity at time of event
    hash_before           VARCHAR(128),
    hash_after            VARCHAR(128),
    hash_algorithm        VARCHAR(20)  DEFAULT 'SHA256',

    -- Officer who transferred the evidence
    transferred_by_officer_id UUID     REFERENCES identity.officer(officer_id),

    -- Officer/entity who received the evidence
    received_by_officer_id    UUID     REFERENCES identity.officer(officer_id),

    -- Acknowledgement reference number
    acknowledgement_ref   VARCHAR(80),

    -- Links to digital signature and audit event (set after those records are created)
    digital_signature_id  UUID,        -- FK to documents.digital_signature added later
    audit_event_id        UUID,        -- FK to audit.audit_event added later

    -- Supporting document (transfer memo, etc.)
    document_id           UUID,        -- FK to documents.document added later

    notes                 TEXT,

    -- Immutability: no UPDATE or DELETE (enforced by trigger)
    created_at            TIMESTAMPTZ  NOT NULL DEFAULT now(),

    UNIQUE (evidence_id, event_sequence)
);

CREATE INDEX idx_custody_evidence     ON custody.evidence_custody_event(evidence_id);
CREATE INDEX idx_custody_case         ON custody.evidence_custody_event(case_id);
CREATE INDEX idx_custody_event_type   ON custody.evidence_custody_event(event_type_code);
CREATE INDEX idx_custody_timestamp    ON custody.evidence_custody_event(event_timestamp);
CREATE INDEX idx_custody_from         ON custody.evidence_custody_event(from_custodian_id);
CREATE INDEX idx_custody_to           ON custody.evidence_custody_event(to_custodian_id);
CREATE INDEX idx_custody_transferred  ON custody.evidence_custody_event(transferred_by_officer_id);

-- ---------------------------------------------------------------------------
-- 3. CUSTODY ACKNOWLEDGEMENT — formal acknowledgement of evidence receipt
--    Linked to a custody event; captured as a separate record to allow
--    digital signature attachment.
-- ---------------------------------------------------------------------------
CREATE TABLE custody.custody_acknowledgement (
    ack_id                UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    custody_event_id      UUID         NOT NULL UNIQUE REFERENCES custody.evidence_custody_event(custody_event_id),
    evidence_id           UUID         NOT NULL REFERENCES evidence.evidence(evidence_id),
    case_id               UUID         NOT NULL REFERENCES case_mgmt.case(case_id),

    ack_reference         VARCHAR(80)  NOT NULL UNIQUE,   -- generated reference number
    acknowledged_by       UUID         NOT NULL REFERENCES identity.officer(officer_id),
    acknowledged_at       TIMESTAMPTZ  NOT NULL DEFAULT now(),

    -- Optional digital signature on acknowledgement
    digital_signature_id  UUID,        -- FK added after doc schema

    remarks               TEXT,
    created_at            TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_ack_custody_event ON custody.custody_acknowledgement(custody_event_id);
CREATE INDEX idx_ack_evidence      ON custody.custody_acknowledgement(evidence_id);

-- ---------------------------------------------------------------------------
-- 4. SEAL — tracks physical seals applied to evidence parcels
-- ---------------------------------------------------------------------------
CREATE TABLE custody.seal (
    seal_id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    seal_number       VARCHAR(80)  NOT NULL UNIQUE,
    evidence_id       UUID         NOT NULL REFERENCES evidence.evidence(evidence_id),
    case_id           UUID         NOT NULL REFERENCES case_mgmt.case(case_id),

    seal_type         VARCHAR(40)  NOT NULL DEFAULT 'WAX'
                                   CHECK (seal_type IN ('WAX','PAPER','PLASTIC','NUMBERED_TAG','DIGITAL','OTHER')),

    applied_by        UUID         NOT NULL REFERENCES identity.officer(officer_id),
    applied_at        TIMESTAMPTZ  NOT NULL DEFAULT now(),
    applied_location  TEXT,

    broken_by         UUID         REFERENCES identity.officer(officer_id),
    broken_at         TIMESTAMPTZ,
    broken_reason     TEXT,
    broken_location   TEXT,

    seal_status       VARCHAR(20)  NOT NULL DEFAULT 'INTACT'
                                   CHECK (seal_status IN ('INTACT','BROKEN','REPLACED','EXPIRED')),

    -- Photo of seal stored in object storage
    seal_photo_object_id  VARCHAR(255),
    seal_photo_path       TEXT,

    notes             TEXT,
    created_at        TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_seal_evidence ON custody.seal(evidence_id);
CREATE INDEX idx_seal_status   ON custody.seal(seal_status);

-- ---------------------------------------------------------------------------
-- 5. CUSTODY TRANSFER REQUEST — formal request before physical transfer
--    Used when an IO requests to send evidence to FSL or court.
-- ---------------------------------------------------------------------------
CREATE TABLE custody.custody_transfer_request (
    request_id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    evidence_id          UUID         NOT NULL REFERENCES evidence.evidence(evidence_id),
    case_id              UUID         NOT NULL REFERENCES case_mgmt.case(case_id),

    requested_by         UUID         NOT NULL REFERENCES identity.officer(officer_id),
    requested_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),

    from_custodian_id    UUID         NOT NULL REFERENCES custody.custodian(custodian_id),
    to_custodian_id      UUID         NOT NULL REFERENCES custody.custodian(custodian_id),

    purpose              TEXT         NOT NULL,
    urgency              VARCHAR(20)  NOT NULL DEFAULT 'NORMAL'
                                      CHECK (urgency IN ('LOW','NORMAL','HIGH','URGENT')),

    request_status       VARCHAR(30)  NOT NULL DEFAULT 'PENDING'
                                      CHECK (request_status IN (
                                          'PENDING','APPROVED','REJECTED','COMPLETED','CANCELLED')),

    approved_by          UUID         REFERENCES identity.officer(officer_id),
    approved_at          TIMESTAMPTZ,
    rejection_reason     TEXT,

    -- Resulting custody event once transfer is done
    resulting_event_id   UUID         REFERENCES custody.evidence_custody_event(custody_event_id),

    created_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at           TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_ctr_evidence ON custody.custody_transfer_request(evidence_id);
CREATE INDEX idx_ctr_case     ON custody.custody_transfer_request(case_id);
CREATE INDEX idx_ctr_status   ON custody.custody_transfer_request(request_status);

-- ---------------------------------------------------------------------------
-- 6. CUSTODY EVENT SEQUENCE — counter for sequential event numbering per evidence
-- ---------------------------------------------------------------------------
CREATE TABLE custody.custody_sequence (
    seq_id       UUID     PRIMARY KEY DEFAULT gen_random_uuid(),
    evidence_id  UUID     NOT NULL UNIQUE REFERENCES evidence.evidence(evidence_id),
    last_seq     INTEGER  NOT NULL DEFAULT 0
);
