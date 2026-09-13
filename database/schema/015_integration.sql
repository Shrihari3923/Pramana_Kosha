-- =============================================================================
-- 015_integration.sql
-- External system references: CCTNS, ICJS, eSakshya, Court, FSL, other agencies
-- =============================================================================
-- Design principle:
--   These tables store REFERENCES to external systems, not replicas.
--   We do NOT invent undocumented APIs or field-level schemas for CCTNS/ICJS.
--   The metadata JSONB column absorbs any system-specific fields.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. EXTERNAL REFERENCE — generic table for any external system link
--    Covers CCTNS, ICJS, eSakshya, court, FSL, and any future system.
-- ---------------------------------------------------------------------------
CREATE TABLE integration.external_reference (
    ref_id               UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    system_name          VARCHAR(60)  NOT NULL
                                      CHECK (system_name IN (
                                          'CCTNS','ICJS','ESAKSHYA','FSL_PORTAL',
                                          'COURT_PORTAL','PROSECUTION_PORTAL',
                                          'NIC','NCRB','NAFIS','OTHER')),

    -- Local entity this reference belongs to
    local_entity_type    VARCHAR(60)  NOT NULL
                                      CHECK (local_entity_type IN (
                                          'CASE','FIR','OFFICER','EVIDENCE',
                                          'DOCUMENT','FORENSIC_REQUEST',
                                          'FORENSIC_REPORT','PERSON','OTHER')),
    local_entity_id      UUID         NOT NULL,

    -- External system identifier
    external_record_id   VARCHAR(200) NOT NULL,
    external_url         TEXT,

    -- Synchronisation status
    sync_status          VARCHAR(30)  NOT NULL DEFAULT 'PENDING'
                                      CHECK (sync_status IN (
                                          'PENDING','SYNCED','FAILED',
                                          'PARTIAL','NOT_APPLICABLE')),
    last_synced_at       TIMESTAMPTZ,
    sync_error           TEXT,
    sync_attempts        SMALLINT     NOT NULL DEFAULT 0,

    -- System-specific fields
    metadata             JSONB        NOT NULL DEFAULT '{}',

    created_by           UUID         REFERENCES identity.officer(officer_id),
    created_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),

    UNIQUE (system_name, local_entity_type, local_entity_id)
);

CREATE INDEX idx_extref_system       ON integration.external_reference(system_name);
CREATE INDEX idx_extref_local        ON integration.external_reference(local_entity_type, local_entity_id);
CREATE INDEX idx_extref_external_id  ON integration.external_reference(external_record_id);
CREATE INDEX idx_extref_sync_status  ON integration.external_reference(sync_status);
CREATE INDEX idx_extref_metadata     ON integration.external_reference USING gin(metadata);

-- ---------------------------------------------------------------------------
-- 2. CCTNS REFERENCE — specific CCTNS fields beyond the generic reference
--    CCTNS is the Crime and Criminal Tracking Network & Systems operated
--    by NCRB on behalf of MHA. This stores linkage IDs only.
-- ---------------------------------------------------------------------------
CREATE TABLE integration.cctns_reference (
    cctns_ref_id         UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    external_ref_id      UUID         NOT NULL UNIQUE REFERENCES integration.external_reference(ref_id),
    case_id              UUID         REFERENCES case_mgmt.case(case_id),
    fir_id               UUID         REFERENCES case_mgmt.fir(fir_id),

    -- CCTNS-assigned identifiers (opaque — we don't know the internal schema)
    cctns_case_id        VARCHAR(100),
    cctns_fir_id         VARCHAR(100),
    cctns_state_code     VARCHAR(10),
    cctns_district_code  VARCHAR(20),
    cctns_station_code   VARCHAR(40),

    -- Push/pull tracking
    last_pushed_at       TIMESTAMPTZ,
    last_pulled_at       TIMESTAMPTZ,
    push_status          VARCHAR(30)  DEFAULT 'PENDING',
    pull_status          VARCHAR(30)  DEFAULT 'PENDING',

    created_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at           TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_cctns_case    ON integration.cctns_reference(case_id);
CREATE INDEX idx_cctns_fir     ON integration.cctns_reference(fir_id);
CREATE INDEX idx_cctns_case_id ON integration.cctns_reference(cctns_case_id);

-- ---------------------------------------------------------------------------
-- 3. ICJS REFERENCE — Interoperable Criminal Justice System
--    Links police case data to prosecution, court, prison systems.
-- ---------------------------------------------------------------------------
CREATE TABLE integration.icjs_reference (
    icjs_ref_id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    external_ref_id      UUID         NOT NULL UNIQUE REFERENCES integration.external_reference(ref_id),
    case_id              UUID         REFERENCES case_mgmt.case(case_id),

    icjs_case_id         VARCHAR(100),
    icjs_prosecution_id  VARCHAR(100),
    icjs_court_id        VARCHAR(100),
    icjs_prison_id       VARCHAR(100),

    linked_at            TIMESTAMPTZ,
    last_synced_at       TIMESTAMPTZ,

    created_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at           TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_icjs_case ON integration.icjs_reference(case_id);

-- ---------------------------------------------------------------------------
-- 4. ESAKSHYA REFERENCE — MHA's e-Sakshya digital evidence management system
--    e-Sakshya handles court-admissible digital evidence.
--    We store the reference ID assigned by e-Sakshya, not its internal schema.
-- ---------------------------------------------------------------------------
CREATE TABLE integration.esakshya_reference (
    esakshya_ref_id      UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    external_ref_id      UUID         NOT NULL UNIQUE REFERENCES integration.external_reference(ref_id),
    evidence_id          UUID         REFERENCES evidence.evidence(evidence_id),
    case_id              UUID         REFERENCES case_mgmt.case(case_id),
    document_version_id  UUID         REFERENCES documents.document_version(version_id),

    esakshya_artifact_id VARCHAR(100),
    esakshya_case_ref    VARCHAR(100),
    upload_status        VARCHAR(30)  DEFAULT 'PENDING'
                                      CHECK (upload_status IN (
                                          'PENDING','UPLOADED','VERIFIED',
                                          'REJECTED','NOT_APPLICABLE')),
    uploaded_at          TIMESTAMPTZ,
    verified_at          TIMESTAMPTZ,

    -- Hash confirmed by e-Sakshya system
    esakshya_hash        VARCHAR(64),
    hash_matches_local   BOOLEAN,

    created_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at           TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_esakshya_evidence ON integration.esakshya_reference(evidence_id);
CREATE INDEX idx_esakshya_case     ON integration.esakshya_reference(case_id);

-- ---------------------------------------------------------------------------
-- 5. COURT CASE REFERENCE — links police case to court proceedings
-- ---------------------------------------------------------------------------
CREATE TABLE integration.court_case_reference (
    court_ref_id         UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    case_id              UUID         NOT NULL REFERENCES case_mgmt.case(case_id),
    court_id             UUID         NOT NULL REFERENCES organisation.court(court_id),

    court_case_number    VARCHAR(80)  NOT NULL,
    court_case_year      SMALLINT,
    case_type_in_court   VARCHAR(80),   -- Sessions Case, CC, SC, etc.

    -- Judge details (informational only)
    presiding_judge      VARCHAR(200),
    court_hall_no        VARCHAR(20),

    -- Key hearing dates
    first_hearing_date   DATE,
    next_hearing_date    DATE,
    verdict_date         DATE,
    verdict              TEXT,

    -- Status
    court_case_status    VARCHAR(40)  NOT NULL DEFAULT 'REGISTERED'
                                      CHECK (court_case_status IN (
                                          'REGISTERED','CHARGES_FRAMED',
                                          'TRIAL_ONGOING','VERDICT_DELIVERED',
                                          'APPEAL_FILED','CLOSED','STAYED')),

    created_by           UUID         REFERENCES identity.officer(officer_id),
    created_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),

    UNIQUE (court_id, court_case_number, court_case_year)
);

CREATE INDEX idx_court_ref_case  ON integration.court_case_reference(case_id);
CREATE INDEX idx_court_ref_court ON integration.court_case_reference(court_id);

-- ---------------------------------------------------------------------------
-- 6. PROSECUTION REFERENCE — links case to prosecution / public prosecutor
-- ---------------------------------------------------------------------------
CREATE TABLE integration.prosecution_reference (
    pros_ref_id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    case_id              UUID         NOT NULL REFERENCES case_mgmt.case(case_id),

    prosecution_office   VARCHAR(200) NOT NULL,
    public_prosecutor    VARCHAR(200),
    pp_reference_number  VARCHAR(80),

    charge_sheet_received_date DATE,
    charges_accepted     BOOLEAN,
    charges_modified     BOOLEAN      NOT NULL DEFAULT FALSE,
    charges_detail       TEXT,

    -- Contact
    pp_phone             VARCHAR(20),
    pp_email             VARCHAR(120),

    notes                TEXT,
    created_by           UUID         REFERENCES identity.officer(officer_id),
    created_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at           TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_pros_ref_case ON integration.prosecution_reference(case_id);

-- ---------------------------------------------------------------------------
-- 7. NCRB / NAFIS REFERENCE — National Crime Records Bureau / fingerprint links
-- ---------------------------------------------------------------------------
CREATE TABLE integration.ncrb_reference (
    ncrb_ref_id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    external_ref_id      UUID         NOT NULL UNIQUE REFERENCES integration.external_reference(ref_id),
    person_id            UUID         REFERENCES identity.person(person_id),
    case_id              UUID         REFERENCES case_mgmt.case(case_id),

    ncrb_record_id       VARCHAR(100),
    nafis_id             VARCHAR(100),   -- National Automated Fingerprint Identification System
    history_sheet_no     VARCHAR(60),

    sync_status          VARCHAR(30)  DEFAULT 'PENDING',
    last_synced_at       TIMESTAMPTZ,

    created_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at           TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_ncrb_person ON integration.ncrb_reference(person_id);
CREATE INDEX idx_ncrb_case   ON integration.ncrb_reference(case_id);

-- ---------------------------------------------------------------------------
-- 8. SYNC LOG — audit of all synchronisation attempts with external systems
-- ---------------------------------------------------------------------------
CREATE TABLE integration.sync_log (
    log_id               UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    system_name          VARCHAR(60)  NOT NULL,
    operation            VARCHAR(30)  NOT NULL CHECK (operation IN ('PUSH','PULL','VERIFY','DELETE')),
    local_entity_type    VARCHAR(60),
    local_entity_id      UUID,
    external_ref_id      UUID         REFERENCES integration.external_reference(ref_id),

    status               VARCHAR(20)  NOT NULL CHECK (status IN ('SUCCESS','FAILED','PARTIAL')),
    http_status_code     SMALLINT,
    error_message        TEXT,
    request_payload      JSONB,        -- sanitised (no secrets)
    response_summary     JSONB,

    initiated_by         UUID         REFERENCES identity.officer(officer_id),
    initiated_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),
    completed_at         TIMESTAMPTZ,
    duration_ms          INTEGER
);

CREATE INDEX idx_sync_log_system  ON integration.sync_log(system_name);
CREATE INDEX idx_sync_log_status  ON integration.sync_log(status);
CREATE INDEX idx_sync_log_entity  ON integration.sync_log(local_entity_type, local_entity_id);
CREATE INDEX idx_sync_log_time    ON integration.sync_log(initiated_at DESC);
