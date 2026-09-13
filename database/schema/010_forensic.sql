-- =============================================================================
-- 010_forensic.sql
-- Forensic Science Laboratory (FSL) requests, examinations, results, reports
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. FORENSIC REQUEST — formal request from IO/station to an FSL
-- ---------------------------------------------------------------------------
CREATE TABLE forensic.forensic_request (
    request_id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    case_id               UUID         NOT NULL REFERENCES case_mgmt.case(case_id),

    -- Human-readable request number: FSL-REQ-KA-2026-000123
    request_number        VARCHAR(60)  NOT NULL UNIQUE,

    lab_id                UUID         NOT NULL REFERENCES organisation.forensic_laboratory(lab_id),
    discipline_id         UUID         NOT NULL REFERENCES reference.forensic_discipline(discipline_id),

    -- Requesting officer
    requested_by          UUID         NOT NULL REFERENCES identity.officer(officer_id),
    requested_at          TIMESTAMPTZ  NOT NULL DEFAULT now(),

    -- Approving officer (SHO or supervisor)
    approved_by           UUID         REFERENCES identity.officer(officer_id),
    approved_at           TIMESTAMPTZ,

    -- Request details
    examination_required  TEXT         NOT NULL,
    purpose               TEXT         NOT NULL,
    priority              VARCHAR(20)  NOT NULL DEFAULT 'NORMAL'
                                       CHECK (priority IN ('LOW','NORMAL','HIGH','URGENT')),

    -- Submission
    submitted_at          TIMESTAMPTZ,
    submitted_by          UUID         REFERENCES identity.officer(officer_id),
    submission_ref        VARCHAR(80),   -- receipt/acknowledgement number from FSL

    -- Expected / actual return
    expected_return_date  DATE,
    actual_return_date    DATE,

    request_status        VARCHAR(30)  NOT NULL DEFAULT 'DRAFT'
                                       CHECK (request_status IN (
                                           'DRAFT','APPROVED','SUBMITTED',
                                           'ACKNOWLEDGED','IN_EXAMINATION',
                                           'REPORT_READY','RECEIVED','CANCELLED')),

    -- Supporting document (request letter)
    request_document_id   UUID,        -- FK to documents.document added after doc schema

    notes                 TEXT,
    metadata              JSONB        NOT NULL DEFAULT '{}',

    created_at            TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at            TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_by            UUID         REFERENCES identity.officer(officer_id)
);

CREATE INDEX idx_fsl_req_case   ON forensic.forensic_request(case_id);
CREATE INDEX idx_fsl_req_lab    ON forensic.forensic_request(lab_id);
CREATE INDEX idx_fsl_req_status ON forensic.forensic_request(request_status);
CREATE INDEX idx_fsl_req_number ON forensic.forensic_request(request_number);

-- ---------------------------------------------------------------------------
-- 2. FORENSIC REQUEST EVIDENCE — evidence items included in a request
--    One request may cover multiple evidence items.
-- ---------------------------------------------------------------------------
CREATE TABLE forensic.forensic_request_evidence (
    fre_id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id          UUID         NOT NULL REFERENCES forensic.forensic_request(request_id),
    evidence_id         UUID         NOT NULL REFERENCES evidence.evidence(evidence_id),
    case_id             UUID         NOT NULL REFERENCES case_mgmt.case(case_id),

    examination_required TEXT,        -- specific examination for this item
    item_condition_sent  TEXT,
    item_seal_number     VARCHAR(80),

    -- Result of this specific item (summary; full result in forensic_result)
    item_finding         TEXT,

    added_at            TIMESTAMPTZ  NOT NULL DEFAULT now(),
    UNIQUE (request_id, evidence_id)
);

CREATE INDEX idx_fre_request  ON forensic.forensic_request_evidence(request_id);
CREATE INDEX idx_fre_evidence ON forensic.forensic_request_evidence(evidence_id);

-- ---------------------------------------------------------------------------
-- 3. FORENSIC EXAMINATION — the actual examination conducted at the FSL
--    One request may result in one or more examinations (e.g. fingerprint
--    examination AND DNA examination from the same request).
-- ---------------------------------------------------------------------------
CREATE TABLE forensic.forensic_examination (
    examination_id        UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id            UUID         NOT NULL REFERENCES forensic.forensic_request(request_id),
    case_id               UUID         NOT NULL REFERENCES case_mgmt.case(case_id),
    lab_id                UUID         NOT NULL REFERENCES organisation.forensic_laboratory(lab_id),
    discipline_id         UUID         NOT NULL REFERENCES reference.forensic_discipline(discipline_id),

    -- Examiner details
    examiner_name         VARCHAR(200) NOT NULL,    -- FSL examiner (may not be in officer table)
    examiner_designation  VARCHAR(120),
    examiner_employee_id  VARCHAR(60),

    -- Examination period
    started_at            TIMESTAMPTZ,
    completed_at          TIMESTAMPTZ,

    examination_status    VARCHAR(30)  NOT NULL DEFAULT 'PENDING'
                                       CHECK (examination_status IN (
                                           'PENDING','IN_PROGRESS','COMPLETED',
                                           'INCONCLUSIVE','FAILED')),

    -- Methodology
    methods_used          TEXT,
    instruments_used      TEXT,
    standards_followed    TEXT,        -- ISO/ASTM/NFS standards

    -- Lab reference
    lab_reference_number  VARCHAR(80),

    notes                 TEXT,
    metadata              JSONB        NOT NULL DEFAULT '{}',

    created_at            TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at            TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_fsl_exam_request ON forensic.forensic_examination(request_id);
CREATE INDEX idx_fsl_exam_case    ON forensic.forensic_examination(case_id);
CREATE INDEX idx_fsl_exam_lab     ON forensic.forensic_examination(lab_id);
CREATE INDEX idx_fsl_exam_status  ON forensic.forensic_examination(examination_status);

-- ---------------------------------------------------------------------------
-- 4. FORENSIC RESULT — individual finding from an examination
--    One examination may produce multiple results (one per evidence item
--    or per question asked in the request).
-- ---------------------------------------------------------------------------
CREATE TABLE forensic.forensic_result (
    result_id             UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    examination_id        UUID         NOT NULL REFERENCES forensic.forensic_examination(examination_id),
    request_id            UUID         NOT NULL REFERENCES forensic.forensic_request(request_id),
    case_id               UUID         NOT NULL REFERENCES case_mgmt.case(case_id),
    evidence_id           UUID         REFERENCES evidence.evidence(evidence_id),

    question_examined     TEXT         NOT NULL,   -- the specific question / exhibit examined
    finding               TEXT         NOT NULL,   -- the finding / result
    conclusion            TEXT,
    opinion               TEXT,                    -- expert opinion

    result_type           VARCHAR(40)  NOT NULL DEFAULT 'OPINION'
                                       CHECK (result_type IN (
                                           'POSITIVE','NEGATIVE','INCONCLUSIVE',
                                           'PARTIAL','OPINION','QUANTITATIVE','OTHER')),

    -- For quantitative results (e.g. drug weight, BAC)
    quantity_value        NUMERIC(16,6),
    quantity_unit         VARCHAR(40),

    recorded_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_at            TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_fsl_result_exam     ON forensic.forensic_result(examination_id);
CREATE INDEX idx_fsl_result_evidence ON forensic.forensic_result(evidence_id);
CREATE INDEX idx_fsl_result_case     ON forensic.forensic_result(case_id);

-- ---------------------------------------------------------------------------
-- 5. FORENSIC REPORT — the official FSL report document
--    Links back to the document management system.
--    A report may be for one or more examinations / request.
-- ---------------------------------------------------------------------------
CREATE TABLE forensic.forensic_report (
    report_id             UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id            UUID         NOT NULL REFERENCES forensic.forensic_request(request_id),
    case_id               UUID         NOT NULL REFERENCES case_mgmt.case(case_id),
    lab_id                UUID         NOT NULL REFERENCES organisation.forensic_laboratory(lab_id),

    -- Human-readable report number from FSL
    report_number         VARCHAR(80)  NOT NULL,
    report_date           DATE         NOT NULL,

    -- Examiner who authored the report
    examiner_name         VARCHAR(200) NOT NULL,
    examiner_designation  VARCHAR(120),

    -- Summary
    summary               TEXT,
    conclusions           TEXT         NOT NULL,
    limitations           TEXT,

    -- Report status
    report_status         VARCHAR(30)  NOT NULL DEFAULT 'DRAFT'
                                       CHECK (report_status IN (
                                           'DRAFT','SUBMITTED','RECEIVED',
                                           'ACCEPTED','SUPPLEMENTARY')),

    -- Received by police
    received_by           UUID         REFERENCES identity.officer(officer_id),
    received_at           TIMESTAMPTZ,

    -- Document reference (the uploaded PDF of the FSL report)
    document_id           UUID,        -- FK to documents.document added after doc schema

    -- Supplementary report
    is_supplementary      BOOLEAN      NOT NULL DEFAULT FALSE,
    supplements_report_id UUID         REFERENCES forensic.forensic_report(report_id),

    notes                 TEXT,
    created_at            TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at            TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_by            UUID         REFERENCES identity.officer(officer_id),

    UNIQUE (lab_id, report_number)
);

CREATE INDEX idx_fsl_report_request ON forensic.forensic_report(request_id);
CREATE INDEX idx_fsl_report_case    ON forensic.forensic_report(case_id);
CREATE INDEX idx_fsl_report_lab     ON forensic.forensic_report(lab_id);

-- ---------------------------------------------------------------------------
-- 6. FORENSIC IMAGE — specific to digital forensics
--    Tracks the forensic disk image created from a digital device.
--    Linked to both evidence (digital_evidence) and examination.
-- ---------------------------------------------------------------------------
CREATE TABLE forensic.forensic_image (
    image_id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    examination_id        UUID         NOT NULL REFERENCES forensic.forensic_examination(examination_id),
    evidence_id           UUID         NOT NULL REFERENCES evidence.evidence(evidence_id),
    case_id               UUID         NOT NULL REFERENCES case_mgmt.case(case_id),

    image_type            VARCHAR(40)  NOT NULL DEFAULT 'PHYSICAL'
                                       CHECK (image_type IN (
                                           'PHYSICAL','LOGICAL','FILE_SYSTEM',
                                           'MEMORY_DUMP','CHIP_OFF','CUSTOM')),

    image_format          VARCHAR(40),  -- E01, AFF4, DD, RAW, L01, etc.

    -- Storage in object store
    storage_object_id     VARCHAR(255),
    storage_provider      VARCHAR(60),
    storage_path          TEXT,
    image_file_size_bytes BIGINT,

    -- Cryptographic hashes
    md5_hash              VARCHAR(32),
    sha1_hash             VARCHAR(40),
    sha256_hash           VARCHAR(64)  NOT NULL,
    sha512_hash           VARCHAR(128),

    -- Acquisition details
    acquisition_tool      VARCHAR(120),
    acquisition_tool_version VARCHAR(40),
    acquired_by           VARCHAR(200),   -- FSL examiner name
    acquired_at           TIMESTAMPTZ,
    write_blocker_used    BOOLEAN       NOT NULL DEFAULT FALSE,
    write_blocker_model   VARCHAR(120),

    -- Verification
    is_verified           BOOLEAN       NOT NULL DEFAULT FALSE,
    verified_at           TIMESTAMPTZ,
    verified_by           VARCHAR(200),

    notes                 TEXT,
    created_at            TIMESTAMPTZ   NOT NULL DEFAULT now()
);

CREATE INDEX idx_fsl_image_examination ON forensic.forensic_image(examination_id);
CREATE INDEX idx_fsl_image_evidence    ON forensic.forensic_image(evidence_id);
CREATE INDEX idx_fsl_image_sha256      ON forensic.forensic_image(sha256_hash);

-- ---------------------------------------------------------------------------
-- 7. FORENSIC REQUEST NUMBER SEQUENCE
-- ---------------------------------------------------------------------------
CREATE TABLE forensic.fsl_request_sequence (
    seq_id        UUID     PRIMARY KEY DEFAULT gen_random_uuid(),
    state_code    CHAR(2)  NOT NULL,
    year          SMALLINT NOT NULL,
    last_seq      INTEGER  NOT NULL DEFAULT 0,
    UNIQUE (state_code, year)
);
