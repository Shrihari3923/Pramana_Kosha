-- =============================================================================
-- 008_evidence.sql
-- Evidence items, evidentiary relationship graph, digital evidence,
-- evidence-linked persons/locations/documents
-- =============================================================================
-- GRAPH 1 — Evidentiary Relationship Graph is implemented here.
-- GRAPH 2 — Chain of Custody is in 009_custody.sql.
-- These are deliberately kept separate.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. EVIDENCE — every physical or digital item collected for a case
-- ---------------------------------------------------------------------------
CREATE TABLE evidence.evidence (
    evidence_id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    case_id               UUID         NOT NULL REFERENCES case_mgmt.case(case_id),

    -- Human-readable evidence number: E001, E002, ... per case
    evidence_number       VARCHAR(20)  NOT NULL,

    evidence_type_id      UUID         NOT NULL REFERENCES reference.evidence_type(evidence_type_id),
    description           TEXT         NOT NULL,

    -- Discovery / collection
    source                TEXT,                    -- where it was found
    discovery_method      VARCHAR(80),             -- SEARCH, SEIZURE, VOLUNTARY_SURRENDER, etc.
    collection_timestamp  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    collection_location   TEXT,
    collection_latitude   NUMERIC(10,7),
    collection_longitude  NUMERIC(10,7),
    collected_by          UUID         NOT NULL REFERENCES identity.officer(officer_id),

    -- Scene reference
    scene_id              UUID         REFERENCES investigation.scene_of_crime(scene_id),

    -- Classification and status
    current_status_code   VARCHAR(40)  NOT NULL DEFAULT 'COLLECTED'
                                       REFERENCES reference.evidence_status(status_code),
    classification_code   VARCHAR(30)  NOT NULL DEFAULT 'CONFIDENTIAL'
                                       REFERENCES reference.classification_level(level_code),

    -- Physical description
    quantity              NUMERIC(12,4),
    unit_of_measure       VARCHAR(40),
    make                  VARCHAR(120),   -- brand / manufacturer
    model                 VARCHAR(120),
    serial_number         VARCHAR(120),
    colour                VARCHAR(60),
    condition_on_collection VARCHAR(200),

    -- Seal information
    seal_number           VARCHAR(80),
    seal_applied_by       UUID         REFERENCES identity.officer(officer_id),
    seal_applied_at       TIMESTAMPTZ,

    -- Integrity
    integrity_status      VARCHAR(30)  NOT NULL DEFAULT 'INTACT'
                                       CHECK (integrity_status IN (
                                           'INTACT','COMPROMISED','UNKNOWN','VERIFIED')),

    -- Storage reference in object store (for digital files attached at collection)
    storage_object_id     VARCHAR(255),
    storage_provider      VARCHAR(60),
    storage_path          TEXT,
    object_key            TEXT,
    mime_type             VARCHAR(100),
    file_size_bytes       BIGINT,
    sha256_hash           VARCHAR(64),

    -- Extensible metadata (varies by evidence type and state)
    metadata              JSONB        NOT NULL DEFAULT '{}',

    -- Soft delete — evidence cannot be physically deleted, only marked
    is_active             BOOLEAN      NOT NULL DEFAULT TRUE,
    deleted_at            TIMESTAMPTZ,
    deleted_by            UUID         REFERENCES identity.officer(officer_id),
    deletion_reason       TEXT,

    created_at            TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at            TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_by            UUID         REFERENCES identity.officer(officer_id),
    version_no            INTEGER      NOT NULL DEFAULT 1,

    UNIQUE (case_id, evidence_number)
);

CREATE INDEX idx_evidence_case         ON evidence.evidence(case_id);
CREATE INDEX idx_evidence_type         ON evidence.evidence(evidence_type_id);
CREATE INDEX idx_evidence_status       ON evidence.evidence(current_status_code);
CREATE INDEX idx_evidence_collected_by ON evidence.evidence(collected_by);
CREATE INDEX idx_evidence_sha256       ON evidence.evidence(sha256_hash);
CREATE INDEX idx_evidence_metadata     ON evidence.evidence USING gin(metadata);

-- Add deferred FK from case_event to evidence
ALTER TABLE case_mgmt.case_event
    ADD CONSTRAINT fk_case_event_evidence
    FOREIGN KEY (related_evidence_id)
    REFERENCES evidence.evidence(evidence_id)
    DEFERRABLE INITIALLY DEFERRED;

-- Add deferred FK from investigation_task to evidence
ALTER TABLE investigation.investigation_task
    ADD CONSTRAINT fk_task_evidence
    FOREIGN KEY (related_evidence_id)
    REFERENCES evidence.evidence(evidence_id)
    DEFERRABLE INITIALLY DEFERRED;

-- ---------------------------------------------------------------------------
-- 2. EVIDENCE RELATIONSHIP — Graph 1 (Evidentiary Relationship Graph)
--    Models how evidence items are related to each other:
--    DERIVED_FROM, EXTRACTED_FROM, REPORTS_ON, SUPPORTS, etc.
--    Supports arbitrary-depth traversal via recursive CTE.
-- ---------------------------------------------------------------------------
CREATE TABLE evidence.evidence_relationship (
    relationship_id      UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    case_id              UUID         NOT NULL REFERENCES case_mgmt.case(case_id),

    source_evidence_id   UUID         NOT NULL REFERENCES evidence.evidence(evidence_id),
    target_evidence_id   UUID         NOT NULL REFERENCES evidence.evidence(evidence_id),

    rel_type_code        VARCHAR(40)  NOT NULL REFERENCES reference.evidence_relationship_type(rel_type_code),

    -- Confidence level: 0.0 – 1.0
    confidence           NUMERIC(4,3) CHECK (confidence BETWEEN 0 AND 1),
    justification        TEXT,

    -- Verification
    is_verified          BOOLEAN      NOT NULL DEFAULT FALSE,
    verified_by          UUID         REFERENCES identity.officer(officer_id),
    verified_at          TIMESTAMPTZ,

    created_by           UUID         NOT NULL REFERENCES identity.officer(officer_id),
    created_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),

    -- Prevent self-loops
    CONSTRAINT chk_no_self_relationship CHECK (source_evidence_id <> target_evidence_id),

    -- Prevent duplicate relationship of same type between same pair
    UNIQUE (source_evidence_id, target_evidence_id, rel_type_code)
);

CREATE INDEX idx_ev_rel_source     ON evidence.evidence_relationship(source_evidence_id);
CREATE INDEX idx_ev_rel_target     ON evidence.evidence_relationship(target_evidence_id);
CREATE INDEX idx_ev_rel_case       ON evidence.evidence_relationship(case_id);
CREATE INDEX idx_ev_rel_type       ON evidence.evidence_relationship(rel_type_code);

-- ---------------------------------------------------------------------------
-- 3. EVIDENCE EVENT — discrete events in the lifecycle of an evidence item
--    Different from custody events (009_custody.sql) — these track what
--    HAPPENED to the evidence (analysis, examination, verification, etc.)
-- ---------------------------------------------------------------------------
CREATE TABLE evidence.evidence_event (
    event_id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    evidence_id       UUID         NOT NULL REFERENCES evidence.evidence(evidence_id),
    case_id           UUID         NOT NULL REFERENCES case_mgmt.case(case_id),

    event_type        VARCHAR(60)  NOT NULL
                                   CHECK (event_type IN (
                                       'COLLECTED','SEALED','EXAMINED','PHOTOGRAPHED',
                                       'WEIGHED','MEASURED','SAMPLED','ANALYSED',
                                       'HASH_COMPUTED','HASH_VERIFIED','HASH_MISMATCH',
                                       'CONDITION_CHANGED','STATUS_UPDATED',
                                       'RELATIONSHIP_ADDED','NOTE_ADDED','OTHER')),

    event_timestamp   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    performed_by      UUID         REFERENCES identity.officer(officer_id),
    description       TEXT,
    result            TEXT,

    -- Hash snapshot at time of event
    hash_at_event     VARCHAR(64),
    hash_algorithm    VARCHAR(20)  DEFAULT 'SHA256',

    created_at        TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_ev_event_evidence  ON evidence.evidence_event(evidence_id);
CREATE INDEX idx_ev_event_case      ON evidence.evidence_event(case_id);
CREATE INDEX idx_ev_event_timestamp ON evidence.evidence_event(event_timestamp);

-- ---------------------------------------------------------------------------
-- 4. EVIDENCE PERSON LINK — connects evidence to persons (accused, witness, etc.)
-- ---------------------------------------------------------------------------
CREATE TABLE evidence.evidence_person (
    ep_id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    evidence_id     UUID         NOT NULL REFERENCES evidence.evidence(evidence_id),
    person_id       UUID         NOT NULL REFERENCES identity.person(person_id),
    case_id         UUID         NOT NULL REFERENCES case_mgmt.case(case_id),

    association_type VARCHAR(60) NOT NULL
                                 CHECK (association_type IN (
                                     'BELONGS_TO','FOUND_ON','LINKED_TO',
                                     'SUBMITTED_BY','IDENTIFIED_BY','OTHER')),
    notes           TEXT,
    added_by        UUID         REFERENCES identity.officer(officer_id),
    added_at        TIMESTAMPTZ  NOT NULL DEFAULT now(),

    UNIQUE (evidence_id, person_id, association_type)
);

CREATE INDEX idx_ev_person_evidence ON evidence.evidence_person(evidence_id);
CREATE INDEX idx_ev_person_person   ON evidence.evidence_person(person_id);

-- ---------------------------------------------------------------------------
-- 5. EVIDENCE LOCATION — geographic location data tied to an evidence item
-- ---------------------------------------------------------------------------
CREATE TABLE evidence.evidence_location (
    location_id       UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    evidence_id       UUID         NOT NULL REFERENCES evidence.evidence(evidence_id),
    case_id           UUID         NOT NULL REFERENCES case_mgmt.case(case_id),

    location_type     VARCHAR(40)  NOT NULL DEFAULT 'COLLECTION'
                                   CHECK (location_type IN (
                                       'COLLECTION','STORAGE','EXAMINATION',
                                       'LAST_KNOWN','OTHER')),

    address           TEXT,
    latitude          NUMERIC(10,7),
    longitude         NUMERIC(10,7),
    geom_wkt          TEXT,
    recorded_at       TIMESTAMPTZ  NOT NULL DEFAULT now(),
    recorded_by       UUID         REFERENCES identity.officer(officer_id),
    notes             TEXT
);

CREATE INDEX idx_ev_location_evidence ON evidence.evidence_location(evidence_id);

-- ---------------------------------------------------------------------------
-- 6. EVIDENCE DOCUMENT LINK — connects evidence to uploaded documents
--    (seizure memos, examination reports, photographs, etc.)
-- ---------------------------------------------------------------------------
CREATE TABLE evidence.evidence_document (
    ed_id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    evidence_id     UUID         NOT NULL REFERENCES evidence.evidence(evidence_id),
    document_id     UUID         NOT NULL,   -- FK to documents.document added after doc schema
    case_id         UUID         NOT NULL REFERENCES case_mgmt.case(case_id),
    link_type       VARCHAR(60)  NOT NULL DEFAULT 'RELATED'
                                 CHECK (link_type IN (
                                     'SEIZURE_MEMO','EXAMINATION_REPORT',
                                     'PHOTOGRAPH','FSL_REPORT','RELATED','OTHER')),
    added_by        UUID         REFERENCES identity.officer(officer_id),
    added_at        TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_ev_doc_evidence ON evidence.evidence_document(evidence_id);
CREATE INDEX idx_ev_doc_document ON evidence.evidence_document(document_id);

-- ---------------------------------------------------------------------------
-- 7. DIGITAL EVIDENCE — extended record for digital evidence items
--    Tracks the full digital forensics chain:
--    Original Device → Forensic Image → Hash → Analysis → Artifact → Report
-- ---------------------------------------------------------------------------
CREATE TABLE evidence.digital_evidence (
    digital_ev_id         UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    evidence_id           UUID         NOT NULL UNIQUE REFERENCES evidence.evidence(evidence_id),
    case_id               UUID         NOT NULL REFERENCES case_mgmt.case(case_id),

    -- Device details
    device_type           VARCHAR(80),   -- MOBILE, LAPTOP, DESKTOP, TABLET, USB, HDD, etc.
    device_make           VARCHAR(120),
    device_model          VARCHAR(120),
    device_serial         VARCHAR(120),
    device_imei           VARCHAR(20),   -- for mobile phones
    device_mac            MACADDR,       -- network MAC address if applicable
    device_os             VARCHAR(80),
    device_os_version     VARCHAR(40),

    -- Acquisition details
    acquisition_method    VARCHAR(80),   -- LOGICAL, PHYSICAL, CHIP_OFF, JTAG, etc.
    acquisition_tool      VARCHAR(120),  -- Cellebrite UFED, FTK Imager, dd, etc.
    acquisition_tool_version VARCHAR(40),
    acquired_by           UUID         REFERENCES identity.officer(officer_id),
    acquired_at           TIMESTAMPTZ,

    -- Hash chain — NEVER overwrite previous hashes
    original_hash         VARCHAR(128),
    original_hash_algo    VARCHAR(20)  REFERENCES reference.hash_algorithm(algo_code),
    acquisition_hash      VARCHAR(128),
    acquisition_hash_algo VARCHAR(20)  REFERENCES reference.hash_algorithm(algo_code),
    forensic_image_hash   VARCHAR(128),
    forensic_image_algo   VARCHAR(20)  REFERENCES reference.hash_algorithm(algo_code),
    current_hash          VARCHAR(128),
    current_hash_algo     VARCHAR(20)  REFERENCES reference.hash_algorithm(algo_code),

    -- Forensic image storage
    image_storage_object_id  VARCHAR(255),
    image_storage_provider   VARCHAR(60),
    image_storage_path       TEXT,
    image_file_size_bytes    BIGINT,

    -- Write-blocker used
    write_blocker_used    BOOLEAN      NOT NULL DEFAULT FALSE,
    write_blocker_model   VARCHAR(120),

    -- Analysis status
    analysis_status       VARCHAR(30)  NOT NULL DEFAULT 'PENDING'
                                       CHECK (analysis_status IN (
                                           'PENDING','IN_PROGRESS','COMPLETED','FAILED')),
    analysis_started_at   TIMESTAMPTZ,
    analysis_completed_at TIMESTAMPTZ,
    analyst_id            UUID         REFERENCES identity.officer(officer_id),

    -- Findings summary
    artifacts_found       TEXT,
    key_findings          TEXT,

    -- Extensible
    metadata              JSONB        NOT NULL DEFAULT '{}',

    created_at            TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at            TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_by            UUID         REFERENCES identity.officer(officer_id)
);

CREATE INDEX idx_digital_ev_evidence ON evidence.digital_evidence(evidence_id);
CREATE INDEX idx_digital_ev_case     ON evidence.digital_evidence(case_id);
CREATE INDEX idx_digital_ev_imei     ON evidence.digital_evidence(device_imei);
CREATE INDEX idx_digital_ev_serial   ON evidence.digital_evidence(device_serial);

-- ---------------------------------------------------------------------------
-- 8. EVIDENCE NUMBER SEQUENCE — for generating E001, E002, ... per case
-- ---------------------------------------------------------------------------
CREATE TABLE evidence.evidence_number_sequence (
    seq_id    UUID     PRIMARY KEY DEFAULT gen_random_uuid(),
    case_id   UUID     NOT NULL UNIQUE REFERENCES case_mgmt.case(case_id),
    last_seq  INTEGER  NOT NULL DEFAULT 0
);
