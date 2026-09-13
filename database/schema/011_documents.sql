-- =============================================================================
-- 011_documents.sql
-- Documents, immutable versions, digital signatures, access control,
-- and polymorphic context-linking tables
-- =============================================================================
-- Design decisions:
--   • Document  = logical object (the FIR, the seizure memo, etc.)
--   • DocumentVersion = physical immutable version (the actual uploaded file)
--   • Files live in MinIO/S3 — the database stores metadata + hash only.
--   • Finalized versions are protected by trigger from further modification.
--   • Polymorphic linking is handled by explicit junction tables
--     (CaseDocument, EvidenceDocument, PersonDocument, ForensicDocument,
--      CourtDocument) rather than nullable FKs — this preserves referential
--     integrity while allowing a document to belong to multiple contexts.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. DOCUMENT — logical document object
-- ---------------------------------------------------------------------------
CREATE TABLE documents.document (
    document_id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Human-readable reference: DOC-KA-BLR-CEN-2026-000456
    document_ref          VARCHAR(80)  NOT NULL UNIQUE,

    document_type_id      UUID         NOT NULL REFERENCES reference.document_type(document_type_id),
    title                 VARCHAR(300) NOT NULL,
    description           TEXT,

    -- Primary case association (may also be linked via junction tables)
    case_id               UUID         REFERENCES case_mgmt.case(case_id),
    station_id            UUID         REFERENCES organisation.police_station(station_id),

    -- Classification
    classification_code   VARCHAR(30)  NOT NULL DEFAULT 'CONFIDENTIAL'
                                       REFERENCES reference.classification_level(level_code),
    retention_category    VARCHAR(40)  REFERENCES reference.retention_category(category_code),
    legal_hold            BOOLEAN      NOT NULL DEFAULT FALSE,

    -- Current version tracking (denormalised for quick access)
    current_version_id    UUID,        -- FK added after document_version table
    current_version_no    INTEGER      NOT NULL DEFAULT 0,

    -- Owner and lifecycle
    owner_officer_id      UUID         REFERENCES identity.officer(officer_id),
    created_by            UUID         NOT NULL REFERENCES identity.officer(officer_id),

    -- Soft delete — documents with legal hold cannot be deleted
    is_active             BOOLEAN      NOT NULL DEFAULT TRUE,
    deleted_at            TIMESTAMPTZ,
    deleted_by            UUID         REFERENCES identity.officer(officer_id),
    deletion_reason       TEXT,

    created_at            TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at            TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_by            UUID         REFERENCES identity.officer(officer_id),
    version_no            INTEGER      NOT NULL DEFAULT 1
);

CREATE INDEX idx_doc_case          ON documents.document(case_id);
CREATE INDEX idx_doc_type          ON documents.document(document_type_id);
CREATE INDEX idx_doc_station       ON documents.document(station_id);
CREATE INDEX idx_doc_classification ON documents.document(classification_code);
CREATE INDEX idx_doc_title_trgm    ON documents.document USING gin(title gin_trgm_ops);

-- Add deferred FK from fir.document_id to document
ALTER TABLE case_mgmt.fir
    ADD CONSTRAINT fk_fir_document
    FOREIGN KEY (document_id)
    REFERENCES documents.document(document_id)
    DEFERRABLE INITIALLY DEFERRED;

-- Add deferred FKs from forensic tables to document
ALTER TABLE forensic.forensic_request
    ADD CONSTRAINT fk_fsl_req_document
    FOREIGN KEY (request_document_id)
    REFERENCES documents.document(document_id)
    DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE forensic.forensic_report
    ADD CONSTRAINT fk_fsl_report_document
    FOREIGN KEY (document_id)
    REFERENCES documents.document(document_id)
    DEFERRABLE INITIALLY DEFERRED;

-- Add deferred FK from case_transfer to document
ALTER TABLE case_mgmt.case_transfer
    ADD CONSTRAINT fk_transfer_document
    FOREIGN KEY (transfer_order_document)
    REFERENCES documents.document(document_id)
    DEFERRABLE INITIALLY DEFERRED;

-- Add deferred FK from investigation.case_diary to document_version
-- (resolved after document_version table is created below)

-- ---------------------------------------------------------------------------
-- 2. DOCUMENT VERSION — immutable physical version of a document
--    Once status = FINAL, no column may be changed (enforced by trigger).
--    Files are stored in MinIO/S3; only metadata lives here.
-- ---------------------------------------------------------------------------
CREATE TABLE documents.document_version (
    version_id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id           UUID         NOT NULL REFERENCES documents.document(document_id),

    version_number        INTEGER      NOT NULL,       -- 1, 2, 3, ...
    version_label         VARCHAR(40),                 -- e.g. "v1.0", "Draft", "Final"

    -- File metadata (actual file in object storage)
    storage_object_id     VARCHAR(255) NOT NULL,
    storage_provider      VARCHAR(60)  NOT NULL DEFAULT 'MINIO',
    storage_path          TEXT         NOT NULL,
    object_key            TEXT         NOT NULL,
    file_name             VARCHAR(300) NOT NULL,
    mime_type             VARCHAR(100) NOT NULL,
    file_size_bytes       BIGINT       NOT NULL,

    -- Cryptographic integrity
    sha256_hash           VARCHAR(64)  NOT NULL,
    sha512_hash           VARCHAR(128),
    hash_algorithm        VARCHAR(20)  NOT NULL DEFAULT 'SHA256'
                                       REFERENCES reference.hash_algorithm(algo_code),

    -- Lineage
    previous_version_id   UUID         REFERENCES documents.document_version(version_id),

    -- Status
    status_code           VARCHAR(30)  NOT NULL DEFAULT 'DRAFT'
                                       REFERENCES reference.version_status(status_code),

    -- Change tracking
    change_reason         TEXT,
    change_summary        TEXT,

    -- Authorship
    created_by            UUID         NOT NULL REFERENCES identity.officer(officer_id),
    created_at            TIMESTAMPTZ  NOT NULL DEFAULT now(),

    -- Finalization
    finalized_at          TIMESTAMPTZ,
    finalized_by          UUID         REFERENCES identity.officer(officer_id),

    -- Digital signature (set after signing)
    digital_signature_id  UUID,        -- FK added after digital_signature table

    -- Immutability: no UPDATE or DELETE once FINAL (enforced by trigger)

    UNIQUE (document_id, version_number)
);

CREATE INDEX idx_docver_document   ON documents.document_version(document_id);
CREATE INDEX idx_docver_status     ON documents.document_version(status_code);
CREATE INDEX idx_docver_sha256     ON documents.document_version(sha256_hash);
CREATE INDEX idx_docver_created_at ON documents.document_version(created_at);
CREATE INDEX idx_docver_prev       ON documents.document_version(previous_version_id);

-- Now add FK from document.current_version_id to document_version
ALTER TABLE documents.document
    ADD CONSTRAINT fk_doc_current_version
    FOREIGN KEY (current_version_id)
    REFERENCES documents.document_version(version_id)
    DEFERRABLE INITIALLY DEFERRED;

-- Add deferred FK from case_diary to document_version
ALTER TABLE investigation.case_diary
    ADD CONSTRAINT fk_diary_document_version
    FOREIGN KEY (document_version_id)
    REFERENCES documents.document_version(version_id)
    DEFERRABLE INITIALLY DEFERRED;

-- ---------------------------------------------------------------------------
-- 3. DIGITAL SIGNATURE — cryptographic signature metadata
--    The actual signature operation is performed by the backend.
--    This table stores the reference/metadata to make it queryable.
-- ---------------------------------------------------------------------------
CREATE TABLE documents.digital_signature (
    signature_id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id           UUID         NOT NULL REFERENCES documents.document(document_id),
    document_version_id   UUID         NOT NULL REFERENCES documents.document_version(version_id),

    signer_officer_id     UUID         NOT NULL REFERENCES identity.officer(officer_id),
    signer_name           VARCHAR(200) NOT NULL,   -- denormalised at time of signing
    signer_role           VARCHAR(120),            -- designation at time of signing

    -- Signature details
    signature_algorithm   VARCHAR(40)  NOT NULL REFERENCES reference.signature_algorithm(algo_code),
    signed_hash           VARCHAR(128) NOT NULL,   -- hash of the document that was signed
    hash_algorithm        VARCHAR(20)  NOT NULL DEFAULT 'SHA256',

    -- Signature value stored as reference (actual bytes in secure storage)
    signature_value_ref   VARCHAR(255),            -- object key in secure store
    signature_value_b64   TEXT,                    -- base64 encoded signature (if small enough)

    -- Certificate details
    certificate_subject   VARCHAR(500),
    certificate_issuer    VARCHAR(500),
    certificate_serial    VARCHAR(80),
    certificate_valid_from TIMESTAMPTZ,
    certificate_valid_to  TIMESTAMPTZ,
    certificate_ref       VARCHAR(255),            -- object key of certificate in storage

    -- Timestamps
    signed_at             TIMESTAMPTZ  NOT NULL DEFAULT now(),

    -- Verification status
    signature_status      VARCHAR(30)  NOT NULL DEFAULT 'VALID'
                                       CHECK (signature_status IN (
                                           'VALID','INVALID','REVOKED',
                                           'EXPIRED','UNVERIFIED')),
    last_verified_at      TIMESTAMPTZ,
    verification_notes    TEXT,

    created_at            TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_sig_document        ON documents.digital_signature(document_id);
CREATE INDEX idx_sig_version         ON documents.digital_signature(document_version_id);
CREATE INDEX idx_sig_signer          ON documents.digital_signature(signer_officer_id);
CREATE INDEX idx_sig_signed_at       ON documents.digital_signature(signed_at);

-- Now add FK from document_version.digital_signature_id
ALTER TABLE documents.document_version
    ADD CONSTRAINT fk_docver_signature
    FOREIGN KEY (digital_signature_id)
    REFERENCES documents.digital_signature(signature_id)
    DEFERRABLE INITIALLY DEFERRED;

-- Add FK from custody tables to digital_signature
ALTER TABLE custody.evidence_custody_event
    ADD CONSTRAINT fk_custody_signature
    FOREIGN KEY (digital_signature_id)
    REFERENCES documents.digital_signature(signature_id)
    DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE custody.custody_acknowledgement
    ADD CONSTRAINT fk_ack_signature
    FOREIGN KEY (digital_signature_id)
    REFERENCES documents.digital_signature(signature_id)
    DEFERRABLE INITIALLY DEFERRED;

-- ---------------------------------------------------------------------------
-- 4. DOCUMENT METADATA — extensible key-value metadata for any document
--    Captures state-specific or document-type-specific fields without
--    schema changes.
-- ---------------------------------------------------------------------------
CREATE TABLE documents.document_metadata (
    metadata_id     UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id     UUID         NOT NULL REFERENCES documents.document(document_id),
    meta_key        VARCHAR(120) NOT NULL,
    meta_value      TEXT,
    meta_json       JSONB,       -- for structured values
    created_by      UUID         REFERENCES identity.officer(officer_id),
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    UNIQUE (document_id, meta_key)
);

CREATE INDEX idx_docmeta_document ON documents.document_metadata(document_id);
CREATE INDEX idx_docmeta_key      ON documents.document_metadata(meta_key);

-- ---------------------------------------------------------------------------
-- 5. DOCUMENT ACCESS LOG — who viewed/downloaded this document
--    Separate from the main audit trail; provides document-centric view.
-- ---------------------------------------------------------------------------
CREATE TABLE documents.document_access_log (
    access_id         UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id       UUID         NOT NULL REFERENCES documents.document(document_id),
    version_id        UUID         REFERENCES documents.document_version(version_id),
    officer_id        UUID         NOT NULL REFERENCES identity.officer(officer_id),
    action            VARCHAR(30)  NOT NULL CHECK (action IN (
                                       'VIEW','DOWNLOAD','PRINT','SHARE','SIGN','APPROVE')),
    accessed_at       TIMESTAMPTZ  NOT NULL DEFAULT now(),
    ip_address        INET,
    user_agent        TEXT,
    session_id        UUID         REFERENCES identity.officer_session(session_id)
);

CREATE INDEX idx_doclog_document  ON documents.document_access_log(document_id);
CREATE INDEX idx_doclog_officer   ON documents.document_access_log(officer_id);
CREATE INDEX idx_doclog_accessed  ON documents.document_access_log(accessed_at);

-- ---------------------------------------------------------------------------
-- 6. JUNCTION TABLES — polymorphic document linking with referential integrity
-- ---------------------------------------------------------------------------

-- 6a. CASE DOCUMENT
CREATE TABLE documents.case_document (
    cd_id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    case_id         UUID         NOT NULL REFERENCES case_mgmt.case(case_id),
    document_id     UUID         NOT NULL REFERENCES documents.document(document_id),
    link_type       VARCHAR(60)  NOT NULL DEFAULT 'RELATED',
    added_by        UUID         REFERENCES identity.officer(officer_id),
    added_at        TIMESTAMPTZ  NOT NULL DEFAULT now(),
    UNIQUE (case_id, document_id)
);
CREATE INDEX idx_casedoc_case ON documents.case_document(case_id);
CREATE INDEX idx_casedoc_doc  ON documents.case_document(document_id);

-- 6b. EVIDENCE DOCUMENT (resolve deferred FK declared in 008_evidence.sql)
ALTER TABLE evidence.evidence_document
    ADD CONSTRAINT fk_ev_doc_document
    FOREIGN KEY (document_id)
    REFERENCES documents.document(document_id)
    DEFERRABLE INITIALLY DEFERRED;

-- 6c. PERSON DOCUMENT
CREATE TABLE documents.person_document (
    pd_id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    person_id       UUID         NOT NULL REFERENCES identity.person(person_id),
    document_id     UUID         NOT NULL REFERENCES documents.document(document_id),
    case_id         UUID         REFERENCES case_mgmt.case(case_id),
    link_type       VARCHAR(60)  NOT NULL DEFAULT 'RELATED',
    added_by        UUID         REFERENCES identity.officer(officer_id),
    added_at        TIMESTAMPTZ  NOT NULL DEFAULT now(),
    UNIQUE (person_id, document_id, case_id)
);
CREATE INDEX idx_persondoc_person ON documents.person_document(person_id);
CREATE INDEX idx_persondoc_doc    ON documents.person_document(document_id);

-- 6d. FORENSIC DOCUMENT
CREATE TABLE documents.forensic_document (
    fd_id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id      UUID         REFERENCES forensic.forensic_request(request_id),
    report_id       UUID         REFERENCES forensic.forensic_report(report_id),
    document_id     UUID         NOT NULL REFERENCES documents.document(document_id),
    case_id         UUID         REFERENCES case_mgmt.case(case_id),
    link_type       VARCHAR(60)  NOT NULL DEFAULT 'RELATED',
    added_by        UUID         REFERENCES identity.officer(officer_id),
    added_at        TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX idx_forensic_doc_unique
    ON documents.forensic_document(document_id,
       COALESCE(request_id, '00000000-0000-0000-0000-000000000000'::uuid),
       COALESCE(report_id,  '00000000-0000-0000-0000-000000000000'::uuid));
CREATE INDEX idx_forecdoc_request ON documents.forensic_document(request_id);
CREATE INDEX idx_forecdoc_report  ON documents.forensic_document(report_id);
CREATE INDEX idx_forecdoc_doc     ON documents.forensic_document(document_id);

-- 6e. COURT DOCUMENT
CREATE TABLE documents.court_document (
    ctd_id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    court_id        UUID         NOT NULL REFERENCES organisation.court(court_id),
    document_id     UUID         NOT NULL REFERENCES documents.document(document_id),
    case_id         UUID         REFERENCES case_mgmt.case(case_id),
    court_case_no   VARCHAR(80),   -- external court case number
    submission_date DATE,
    link_type       VARCHAR(60)  NOT NULL DEFAULT 'SUBMITTED',
    submitted_by    UUID         REFERENCES identity.officer(officer_id),
    added_at        TIMESTAMPTZ  NOT NULL DEFAULT now(),
    UNIQUE (court_id, document_id)
);
CREATE INDEX idx_courtdoc_court ON documents.court_document(court_id);
CREATE INDEX idx_courtdoc_doc   ON documents.court_document(document_id);

-- ---------------------------------------------------------------------------
-- 7. COURT SUBMISSION — formal record of a court filing
-- ---------------------------------------------------------------------------
CREATE TABLE documents.court_submission (
    submission_id         UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    case_id               UUID         NOT NULL REFERENCES case_mgmt.case(case_id),
    court_id              UUID         NOT NULL REFERENCES organisation.court(court_id),

    submission_type       VARCHAR(60)  NOT NULL
                                       CHECK (submission_type IN (
                                           'CHARGE_SHEET','FINAL_REPORT','EVIDENCE_LIST',
                                           'WITNESS_LIST','BAIL_APPLICATION',
                                           'REMAND_APPLICATION','COURT_EXHIBIT',
                                           'SUPPLEMENTARY','OTHER')),

    court_case_number     VARCHAR(80),
    submission_date       DATE         NOT NULL DEFAULT CURRENT_DATE,
    submitted_by          UUID         NOT NULL REFERENCES identity.officer(officer_id),
    acknowledged_by_court BOOLEAN      NOT NULL DEFAULT FALSE,
    court_ack_ref         VARCHAR(80),
    court_ack_date        DATE,

    notes                 TEXT,
    created_at            TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at            TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_court_sub_case  ON documents.court_submission(case_id);
CREATE INDEX idx_court_sub_court ON documents.court_submission(court_id);

-- 7a. COURT EXHIBIT — individual exhibit produced in court
CREATE TABLE documents.court_exhibit (
    exhibit_id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    submission_id       UUID         NOT NULL REFERENCES documents.court_submission(submission_id),
    case_id             UUID         NOT NULL REFERENCES case_mgmt.case(case_id),
    evidence_id         UUID         REFERENCES evidence.evidence(evidence_id),
    document_id         UUID         REFERENCES documents.document(document_id),
    exhibit_number      VARCHAR(40)  NOT NULL,
    exhibit_description TEXT,
    produced_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),
    produced_by         UUID         REFERENCES identity.officer(officer_id),
    returned_at         TIMESTAMPTZ,
    notes               TEXT,
    UNIQUE (submission_id, exhibit_number)
);

CREATE INDEX idx_exhibit_submission ON documents.court_exhibit(submission_id);
CREATE INDEX idx_exhibit_evidence   ON documents.court_exhibit(evidence_id);

-- ---------------------------------------------------------------------------
-- 8. DOCUMENT REFERENCE SEQUENCE — for generating DOC-xxx reference numbers
-- ---------------------------------------------------------------------------
CREATE TABLE documents.document_ref_sequence (
    seq_id        UUID     PRIMARY KEY DEFAULT gen_random_uuid(),
    state_code    CHAR(2)  NOT NULL,
    station_code  VARCHAR(60) NOT NULL,
    year          SMALLINT NOT NULL,
    last_seq      INTEGER  NOT NULL DEFAULT 0,
    UNIQUE (state_code, station_code, year)
);

-- ---------------------------------------------------------------------------
-- 9. Resolve remaining deferred FKs from custody tables to documents
-- ---------------------------------------------------------------------------
ALTER TABLE custody.evidence_custody_event
    ADD CONSTRAINT fk_custody_document
    FOREIGN KEY (document_id)
    REFERENCES documents.document(document_id)
    DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE custody.custody_transfer_request
    ADD COLUMN document_id UUID REFERENCES documents.document(document_id);
