-- =============================================================================
-- 002_functions_triggers.sql
-- All PL/pgSQL functions and triggers for the Police DMS
-- =============================================================================

-- =============================================================================
-- SECTION 1: UTILITY FUNCTIONS
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1.1 updated_at auto-update trigger function
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

-- Apply updated_at trigger to all relevant tables
DO $$
DECLARE
    t TEXT;
    tables TEXT[] := ARRAY[
        'organisation.organisation_unit',
        'organisation.police_station',
        'organisation.jurisdiction',
        'organisation.forensic_laboratory',
        'identity.person',
        'identity.officer',
        'identity.officer_posting',
        'case_mgmt.case',
        'case_mgmt.fir',
        'investigation.investigation',
        'evidence.evidence',
        'evidence.digital_evidence',
        'custody.seal',
        'custody.custody_transfer_request',
        'forensic.forensic_request',
        'forensic.forensic_examination',
        'forensic.forensic_report',
        'documents.document',
        'integrity.integrity_alert',
        'audit.security_alert',
        'workflow.workflow_instance',
        'workflow.deadline',
        'integration.external_reference',
        'integration.cctns_reference',
        'integration.icjs_reference',
        'integration.esakshya_reference',
        'integration.court_case_reference',
        'integration.prosecution_reference'
    ];
BEGIN
    FOREACH t IN ARRAY tables LOOP
        EXECUTE format(
            'CREATE TRIGGER trg_updated_at_%s
             BEFORE UPDATE ON %s
             FOR EACH ROW EXECUTE FUNCTION public.set_updated_at()',
            replace(replace(t, '.', '_'), ' ', '_'),
            t
        );
    END LOOP;
END $$;

-- =============================================================================
-- SECTION 2: HUMAN-READABLE NUMBER GENERATORS
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 2.1 generate_case_number(station_id, year)
--     Returns: CASE-KA-BLR-CEN-2026-00001247
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION case_mgmt.generate_case_number(
    p_station_id UUID,
    p_year       SMALLINT DEFAULT EXTRACT(YEAR FROM now())::SMALLINT
)
RETURNS VARCHAR(60) LANGUAGE plpgsql AS $$
DECLARE
    v_state_code   CHAR(2);
    v_station_code VARCHAR(60);
    v_seq          INTEGER;
    v_case_number  VARCHAR(60);
BEGIN
    -- Get station info
    SELECT ps.state_code, ps.station_code
    INTO v_state_code, v_station_code
    FROM organisation.police_station ps
    WHERE ps.station_id = p_station_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Station not found: %', p_station_id;
    END IF;

    -- Atomically increment sequence
    INSERT INTO case_mgmt.case_number_sequence (state_code, station_code, year, last_seq)
    VALUES (v_state_code, v_station_code, p_year, 1)
    ON CONFLICT (state_code, station_code, year)
    DO UPDATE SET last_seq = case_mgmt.case_number_sequence.last_seq + 1
    RETURNING last_seq INTO v_seq;

    -- Format: CASE-KA-BLR-CEN-2026-00001247
    v_case_number := 'CASE-' ||
                     UPPER(v_state_code) || '-' ||
                     UPPER(LEFT(v_station_code, 10)) || '-' ||
                     p_year::TEXT || '-' ||
                     LPAD(v_seq::TEXT, 8, '0');

    RETURN v_case_number;
END;
$$;

-- ---------------------------------------------------------------------------
-- 2.2 generate_fir_number(station_id, year)
--     Returns: FIR/001/2026
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION case_mgmt.generate_fir_number(
    p_station_id UUID,
    p_year       SMALLINT DEFAULT EXTRACT(YEAR FROM now())::SMALLINT
)
RETURNS VARCHAR(40) LANGUAGE plpgsql AS $$
DECLARE
    v_seq INTEGER;
BEGIN
    INSERT INTO case_mgmt.fir_number_sequence (station_id, year, last_seq)
    VALUES (p_station_id, p_year, 1)
    ON CONFLICT (station_id, year)
    DO UPDATE SET last_seq = case_mgmt.fir_number_sequence.last_seq + 1
    RETURNING last_seq INTO v_seq;

    RETURN 'FIR/' || LPAD(v_seq::TEXT, 3, '0') || '/' || p_year::TEXT;
END;
$$;

-- ---------------------------------------------------------------------------
-- 2.3 generate_officer_identity_code(officer_id)
--     Returns: IN-KA-BLR-CEN-PS042-SI-00127
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION identity.generate_officer_identity_code(
    p_state_code   CHAR(2),
    p_station_code VARCHAR(60),
    p_rank_code    VARCHAR(40),
    p_sequence     INTEGER
)
RETURNS VARCHAR(80) LANGUAGE plpgsql AS $$
BEGIN
    RETURN 'IN-' ||
           UPPER(p_state_code) || '-' ||
           UPPER(LEFT(p_station_code, 8)) || '-' ||
           UPPER(p_rank_code) || '-' ||
           LPAD(p_sequence::TEXT, 5, '0');
END;
$$;

-- ---------------------------------------------------------------------------
-- 2.4 generate_evidence_number(case_id)
--     Returns: E001, E002, ...
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION evidence.generate_evidence_number(p_case_id UUID)
RETURNS VARCHAR(20) LANGUAGE plpgsql AS $$
DECLARE
    v_seq INTEGER;
BEGIN
    INSERT INTO evidence.evidence_number_sequence (case_id, last_seq)
    VALUES (p_case_id, 1)
    ON CONFLICT (case_id)
    DO UPDATE SET last_seq = evidence.evidence_number_sequence.last_seq + 1
    RETURNING last_seq INTO v_seq;

    RETURN 'E' || LPAD(v_seq::TEXT, 3, '0');
END;
$$;

-- ---------------------------------------------------------------------------
-- 2.5 generate_document_ref(station_id, year)
--     Returns: DOC-KA-BLR-CEN-2026-000456
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION documents.generate_document_ref(
    p_station_id UUID,
    p_year       SMALLINT DEFAULT EXTRACT(YEAR FROM now())::SMALLINT
)
RETURNS VARCHAR(80) LANGUAGE plpgsql AS $$
DECLARE
    v_state_code   CHAR(2);
    v_station_code VARCHAR(60);
    v_seq          INTEGER;
BEGIN
    SELECT ps.state_code, ps.station_code
    INTO v_state_code, v_station_code
    FROM organisation.police_station ps
    WHERE ps.station_id = p_station_id;

    INSERT INTO documents.document_ref_sequence (state_code, station_code, year, last_seq)
    VALUES (v_state_code, v_station_code, p_year, 1)
    ON CONFLICT (state_code, station_code, year)
    DO UPDATE SET last_seq = documents.document_ref_sequence.last_seq + 1
    RETURNING last_seq INTO v_seq;

    RETURN 'DOC-' || UPPER(v_state_code) || '-' ||
           UPPER(LEFT(v_station_code, 8)) || '-' ||
           p_year::TEXT || '-' ||
           LPAD(v_seq::TEXT, 6, '0');
END;
$$;

-- ---------------------------------------------------------------------------
-- 2.6 generate_fsl_request_number(state_code, year)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION forensic.generate_fsl_request_number(
    p_state_code CHAR(2),
    p_year       SMALLINT DEFAULT EXTRACT(YEAR FROM now())::SMALLINT
)
RETURNS VARCHAR(60) LANGUAGE plpgsql AS $$
DECLARE
    v_seq INTEGER;
BEGIN
    INSERT INTO forensic.fsl_request_sequence (state_code, year, last_seq)
    VALUES (p_state_code, p_year, 1)
    ON CONFLICT (state_code, year)
    DO UPDATE SET last_seq = forensic.fsl_request_sequence.last_seq + 1
    RETURNING last_seq INTO v_seq;

    RETURN 'FSL-REQ-' || UPPER(p_state_code) || '-' ||
           p_year::TEXT || '-' ||
           LPAD(v_seq::TEXT, 6, '0');
END;
$$;

-- =============================================================================
-- SECTION 3: CASE MANAGEMENT TRIGGERS
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 3.1 Auto-generate case_number on INSERT into case_mgmt.case
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION case_mgmt.trg_fn_generate_case_number()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.case_number IS NULL OR NEW.case_number = '' THEN
        NEW.case_number := case_mgmt.generate_case_number(
            NEW.originating_station_id,
            EXTRACT(YEAR FROM NEW.opened_at)::SMALLINT
        );
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_case_number
    BEFORE INSERT ON case_mgmt.case
    FOR EACH ROW EXECUTE FUNCTION case_mgmt.trg_fn_generate_case_number();

-- ---------------------------------------------------------------------------
-- 3.2 Auto-create investigation record when case is inserted
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION case_mgmt.trg_fn_create_investigation()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO investigation.investigation (case_id, primary_io_id)
    VALUES (NEW.case_id, NEW.primary_io_id)
    ON CONFLICT (case_id) DO NOTHING;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_case_create_investigation
    AFTER INSERT ON case_mgmt.case
    FOR EACH ROW EXECUTE FUNCTION case_mgmt.trg_fn_create_investigation();

-- ---------------------------------------------------------------------------
-- 3.3 Prevent UPDATE/DELETE on case_event (append-only)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION case_mgmt.trg_fn_protect_case_event()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'case_event records are immutable. INSERT new records instead.';
END;
$$;

CREATE TRIGGER trg_protect_case_event_update
    BEFORE UPDATE ON case_mgmt.case_event
    FOR EACH ROW EXECUTE FUNCTION case_mgmt.trg_fn_protect_case_event();

CREATE TRIGGER trg_protect_case_event_delete
    BEFORE DELETE ON case_mgmt.case_event
    FOR EACH ROW EXECUTE FUNCTION case_mgmt.trg_fn_protect_case_event();

-- ---------------------------------------------------------------------------
-- 3.4 Auto-generate FIR number on INSERT
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION case_mgmt.trg_fn_generate_fir_number()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.fir_number IS NULL OR NEW.fir_number = '' THEN
        NEW.fir_number := case_mgmt.generate_fir_number(
            NEW.station_id, NEW.fir_year
        );
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_fir_number
    BEFORE INSERT ON case_mgmt.fir
    FOR EACH ROW EXECUTE FUNCTION case_mgmt.trg_fn_generate_fir_number();

-- ---------------------------------------------------------------------------
-- 3.5 Push event to case_timeline when case_event is inserted
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION case_mgmt.trg_fn_push_event_to_timeline()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_officer_name VARCHAR(200);
BEGIN
    SELECT p.full_name INTO v_officer_name
    FROM identity.officer o
    JOIN identity.person p ON p.person_id = o.person_id
    WHERE o.officer_id = NEW.recorded_by;

    INSERT INTO investigation.case_timeline (
        case_id, event_timestamp, event_category,
        title, description, officer_id, officer_name,
        source_table, source_id
    ) VALUES (
        NEW.case_id, NEW.event_timestamp, 'CASE_EVENT',
        COALESCE(NEW.title, NEW.event_type_code),
        NEW.description,
        NEW.recorded_by, v_officer_name,
        'case_mgmt.case_event', NEW.event_id
    );
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_case_event_to_timeline
    AFTER INSERT ON case_mgmt.case_event
    FOR EACH ROW EXECUTE FUNCTION case_mgmt.trg_fn_push_event_to_timeline();

-- =============================================================================
-- SECTION 4: EVIDENCE TRIGGERS
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 4.1 Auto-generate evidence_number on INSERT
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION evidence.trg_fn_generate_evidence_number()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.evidence_number IS NULL OR NEW.evidence_number = '' THEN
        NEW.evidence_number := evidence.generate_evidence_number(NEW.case_id);
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_evidence_number
    BEFORE INSERT ON evidence.evidence
    FOR EACH ROW EXECUTE FUNCTION evidence.trg_fn_generate_evidence_number();

-- ---------------------------------------------------------------------------
-- 4.2 Auto-initialise custody sequence on evidence INSERT
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION evidence.trg_fn_init_custody_sequence()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO custody.custody_sequence (evidence_id, last_seq)
    VALUES (NEW.evidence_id, 0)
    ON CONFLICT (evidence_id) DO NOTHING;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_evidence_init_custody_seq
    AFTER INSERT ON evidence.evidence
    FOR EACH ROW EXECUTE FUNCTION evidence.trg_fn_init_custody_sequence();

-- =============================================================================
-- SECTION 5: CUSTODY TRIGGERS
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 5.1 Prevent UPDATE/DELETE on custody events (append-only chain)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION custody.trg_fn_protect_custody_event()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'custody events are immutable. The chain of custody cannot be altered.';
END;
$$;

CREATE TRIGGER trg_protect_custody_update
    BEFORE UPDATE ON custody.evidence_custody_event
    FOR EACH ROW EXECUTE FUNCTION custody.trg_fn_protect_custody_event();

CREATE TRIGGER trg_protect_custody_delete
    BEFORE DELETE ON custody.evidence_custody_event
    FOR EACH ROW EXECUTE FUNCTION custody.trg_fn_protect_custody_event();

-- ---------------------------------------------------------------------------
-- 5.2 Auto-assign event_sequence and update evidence status on custody INSERT
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION custody.trg_fn_custody_event_sequence()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_seq INTEGER;
BEGIN
    -- Get next sequence
    UPDATE custody.custody_sequence
    SET last_seq = last_seq + 1
    WHERE evidence_id = NEW.evidence_id
    RETURNING last_seq INTO v_seq;

    NEW.event_sequence := v_seq;

    -- Update evidence status based on event type
    UPDATE evidence.evidence
    SET current_status_code = CASE NEW.event_type_code
            WHEN 'SEIZED'            THEN 'COLLECTED'
            WHEN 'DEPOSITED'         THEN 'IN_MALKHANA'
            WHEN 'SENT_TO_FSL'       THEN 'SENT_TO_FSL'
            WHEN 'RECEIVED_BY_FSL'   THEN 'AT_FSL'
            WHEN 'RETURNED_FROM_FSL' THEN 'RETURNED_FROM_FSL'
            WHEN 'PRODUCED_IN_COURT' THEN 'PRODUCED_IN_COURT'
            WHEN 'RELEASED'          THEN 'RELEASED'
            WHEN 'DESTROYED'         THEN 'DESTROYED'
            WHEN 'ARCHIVED'          THEN 'ARCHIVED'
            ELSE current_status_code
        END,
        updated_at = now()
    WHERE evidence_id = NEW.evidence_id;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_custody_sequence
    BEFORE INSERT ON custody.evidence_custody_event
    FOR EACH ROW EXECUTE FUNCTION custody.trg_fn_custody_event_sequence();

-- ---------------------------------------------------------------------------
-- 5.3 Push custody event to case_timeline
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION custody.trg_fn_custody_to_timeline()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_officer_name VARCHAR(200);
    v_ev_number    VARCHAR(20);
    v_to_name      VARCHAR(200);
BEGIN
    SELECT p.full_name INTO v_officer_name
    FROM identity.officer o JOIN identity.person p ON p.person_id = o.person_id
    WHERE o.officer_id = NEW.recorded_by;

    SELECT ev.evidence_number INTO v_ev_number
    FROM evidence.evidence ev WHERE ev.evidence_id = NEW.evidence_id;

    SELECT c.display_name INTO v_to_name
    FROM custody.custodian c WHERE c.custodian_id = NEW.to_custodian_id;

    INSERT INTO investigation.case_timeline (
        case_id, event_timestamp, event_category,
        title, description, officer_id, officer_name,
        source_table, source_id
    ) VALUES (
        NEW.case_id, NEW.event_timestamp, 'CUSTODY_EVENT',
        'Custody: ' || NEW.event_type_code || ' — ' || COALESCE(v_ev_number,''),
        'Evidence ' || COALESCE(v_ev_number,'') || ' transferred to ' || COALESCE(v_to_name,''),
        NEW.recorded_by, v_officer_name,
        'custody.evidence_custody_event', NEW.custody_event_id
    );
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_custody_to_timeline
    AFTER INSERT ON custody.evidence_custody_event
    FOR EACH ROW EXECUTE FUNCTION custody.trg_fn_custody_to_timeline();

-- =============================================================================
-- SECTION 6: DOCUMENT TRIGGERS
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 6.1 Auto-generate document_ref on INSERT
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION documents.trg_fn_generate_document_ref()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_station_id UUID;
BEGIN
    IF NEW.document_ref IS NULL OR NEW.document_ref = '' THEN
        -- Use case station or document station
        v_station_id := COALESCE(NEW.station_id,
            (SELECT originating_station_id FROM case_mgmt.case WHERE case_id = NEW.case_id));
        IF v_station_id IS NOT NULL THEN
            NEW.document_ref := documents.generate_document_ref(
                v_station_id,
                EXTRACT(YEAR FROM now())::SMALLINT
            );
        ELSE
            NEW.document_ref := 'DOC-' || gen_random_uuid()::TEXT;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_document_ref
    BEFORE INSERT ON documents.document
    FOR EACH ROW EXECUTE FUNCTION documents.trg_fn_generate_document_ref();

-- ---------------------------------------------------------------------------
-- 6.2 Prevent modification of FINAL document versions (immutability)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION documents.trg_fn_protect_final_version()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    -- Allow update only to set digital_signature_id or verification fields on FINAL
    IF OLD.status_code = 'FINAL' THEN
        IF NEW.sha256_hash      <> OLD.sha256_hash      OR
           NEW.storage_path     <> OLD.storage_path     OR
           NEW.object_key       <> OLD.object_key       OR
           NEW.file_size_bytes  <> OLD.file_size_bytes  OR
           NEW.version_number   <> OLD.version_number   THEN
            RAISE EXCEPTION
                'Document version % is FINAL and cannot be modified. Create a new version instead.',
                OLD.version_id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_protect_final_version
    BEFORE UPDATE ON documents.document_version
    FOR EACH ROW EXECUTE FUNCTION documents.trg_fn_protect_final_version();

CREATE OR REPLACE FUNCTION documents.trg_fn_prevent_version_delete()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'Document versions cannot be deleted.';
END;
$$;

CREATE TRIGGER trg_prevent_version_delete
    BEFORE DELETE ON documents.document_version
    FOR EACH ROW EXECUTE FUNCTION documents.trg_fn_prevent_version_delete();

-- ---------------------------------------------------------------------------
-- 6.3 Update document.current_version_id when a new version is inserted
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION documents.trg_fn_update_current_version()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    UPDATE documents.document
    SET current_version_id = NEW.version_id,
        current_version_no = NEW.version_number,
        updated_at = now()
    WHERE document_id = NEW.document_id;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_update_current_version
    AFTER INSERT ON documents.document_version
    FOR EACH ROW EXECUTE FUNCTION documents.trg_fn_update_current_version();

-- =============================================================================
-- SECTION 7: AUDIT CHAIN FUNCTIONS AND TRIGGERS
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 7.1 create_audit_event — primary function for creating a chained audit record
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION audit.create_audit_event(
    p_action_code       VARCHAR(60),
    p_officer_id        UUID,
    p_station_id        UUID,
    p_case_id           UUID,
    p_resource_type     VARCHAR(60),
    p_resource_id       UUID,
    p_resource_ref      VARCHAR(120),
    p_result            VARCHAR(20),
    p_failure_reason    TEXT        DEFAULT NULL,
    p_previous_state    JSONB       DEFAULT NULL,
    p_new_state         JSONB       DEFAULT NULL,
    p_reason            TEXT        DEFAULT NULL,
    p_ip_address        INET        DEFAULT NULL,
    p_session_id        UUID        DEFAULT NULL,
    p_metadata          JSONB       DEFAULT '{}'
)
RETURNS UUID LANGUAGE plpgsql AS $$
DECLARE
    v_chain_id          UUID;
    v_prev_audit_id     UUID;
    v_prev_hash         VARCHAR(64);
    v_event_hash        VARCHAR(64);
    v_audit_id          UUID;
    v_officer_name      VARCHAR(200);
    v_officer_rank      VARCHAR(40);
    v_station_name      VARCHAR(200);
    v_case_number       VARCHAR(60);
    v_severity          VARCHAR(20);
    v_timestamp         TIMESTAMPTZ;
BEGIN
    v_timestamp := now();

    -- Determine chain: use case_id if available, else GLOBAL chain
    v_chain_id := COALESCE(p_case_id, '00000000-0000-0000-0000-000000000001'::UUID);

    -- Get current chain head
    SELECT head_audit_id, head_hash
    INTO v_prev_audit_id, v_prev_hash
    FROM audit.audit_chain
    WHERE chain_id = v_chain_id;

    -- If chain doesn't exist yet (new case), create it
    IF NOT FOUND THEN
        INSERT INTO audit.audit_chain (chain_id, chain_type)
        VALUES (v_chain_id, CASE WHEN p_case_id IS NOT NULL THEN 'CASE' ELSE 'GLOBAL' END)
        ON CONFLICT (chain_id) DO NOTHING;
        v_prev_hash := NULL;
    END IF;

    -- Compute event hash: SHA-256 of concatenated fields
    v_event_hash := encode(
        digest(
            COALESCE(v_prev_hash, 'GENESIS') ||
            '|' || v_chain_id::TEXT ||
            '|' || p_action_code ||
            '|' || COALESCE(p_officer_id::TEXT, 'NULL') ||
            '|' || COALESCE(p_resource_type, 'NULL') ||
            '|' || COALESCE(p_resource_id::TEXT, 'NULL') ||
            '|' || p_result ||
            '|' || to_char(v_timestamp, 'YYYY-MM-DD"T"HH24:MI:SS.USTZH:TZM'),
            'sha256'
        ),
        'hex'
    );

    -- Look up denormalised display fields
    SELECT p.full_name, o.current_rank_code
    INTO v_officer_name, v_officer_rank
    FROM identity.officer o
    JOIN identity.person p ON p.person_id = o.person_id
    WHERE o.officer_id = p_officer_id;

    SELECT ps.station_name INTO v_station_name
    FROM organisation.police_station ps
    WHERE ps.station_id = p_station_id;

    SELECT c.case_number INTO v_case_number
    FROM case_mgmt.case c
    WHERE c.case_id = p_case_id;

    -- Get severity from action type
    SELECT aat.severity INTO v_severity
    FROM reference.audit_action_type aat
    WHERE aat.action_code = p_action_code;

    -- Insert the audit event
    INSERT INTO audit.audit_event (
        chain_id, previous_audit_id, previous_hash, event_hash,
        action_code, event_timestamp, severity,
        officer_id, officer_name, officer_rank,
        session_id, police_station_id, station_name,
        case_id, case_number,
        resource_type, resource_id, resource_ref,
        result, failure_reason,
        previous_state, new_state,
        ip_address, reason, metadata
    ) VALUES (
        v_chain_id, v_prev_audit_id, v_prev_hash, v_event_hash,
        p_action_code, v_timestamp, COALESCE(v_severity, 'INFO'),
        p_officer_id, v_officer_name, v_officer_rank,
        p_session_id, p_station_id, v_station_name,
        p_case_id, v_case_number,
        p_resource_type, p_resource_id, p_resource_ref,
        p_result, p_failure_reason,
        p_previous_state, p_new_state,
        p_ip_address, p_reason, COALESCE(p_metadata, '{}')
    )
    RETURNING audit_id INTO v_audit_id;

    -- Update chain head
    UPDATE audit.audit_chain
    SET head_audit_id = v_audit_id,
        head_hash     = v_event_hash,
        event_count   = event_count + 1,
        last_event_at = v_timestamp,
        updated_at    = v_timestamp
    WHERE chain_id = v_chain_id;

    RETURN v_audit_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- 7.2 verify_audit_chain — checks hash integrity for a chain
--     Returns a table of broken links (empty = chain intact)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION audit.verify_audit_chain(p_chain_id UUID)
RETURNS TABLE (
    audit_id       UUID,
    event_order    BIGINT,
    stored_hash    VARCHAR(64),
    computed_hash  VARCHAR(64),
    is_valid       BOOLEAN,
    action_code    VARCHAR(60),
    event_timestamp TIMESTAMPTZ
) LANGUAGE plpgsql AS $$
DECLARE
    r               RECORD;
    v_prev_hash     VARCHAR(64) := NULL;
    v_expected_hash VARCHAR(64);
    v_row_num       BIGINT := 0;
    v_tamper_found  BOOLEAN := FALSE;
BEGIN
    FOR r IN
        SELECT ae.audit_id, ae.event_hash, ae.previous_hash,
               ae.action_code, ae.event_timestamp,
               ae.officer_id, ae.resource_type, ae.resource_id,
               ae.result
        FROM audit.audit_event ae
        WHERE ae.chain_id = p_chain_id
        ORDER BY ae.event_timestamp ASC, ae.audit_id ASC
    LOOP
        v_row_num := v_row_num + 1;

        -- Recompute hash
        v_expected_hash := encode(
            digest(
                COALESCE(v_prev_hash, 'GENESIS') ||
                '|' || p_chain_id::TEXT ||
                '|' || r.action_code ||
                '|' || COALESCE(r.officer_id::TEXT, 'NULL') ||
                '|' || COALESCE(r.resource_type, 'NULL') ||
                '|' || COALESCE(r.resource_id::TEXT, 'NULL') ||
                '|' || r.result ||
                '|' || to_char(r.event_timestamp, 'YYYY-MM-DD"T"HH24:MI:SS.USTZH:TZM'),
                'sha256'
            ),
            'hex'
        );

        audit_id        := r.audit_id;
        event_order     := v_row_num;
        stored_hash     := r.event_hash;
        computed_hash   := v_expected_hash;
        is_valid        := (r.event_hash = v_expected_hash);
        action_code     := r.action_code;
        event_timestamp := r.event_timestamp;

        IF NOT is_valid THEN
            v_tamper_found := TRUE;
        END IF;

        RETURN NEXT;
        v_prev_hash := r.event_hash;
    END LOOP;

    -- Update chain status
    UPDATE audit.audit_chain
    SET chain_status    = CASE WHEN v_tamper_found THEN 'BROKEN' ELSE 'INTACT' END,
        last_verified_at = now()
    WHERE chain_id = p_chain_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- 7.3 Prevent UPDATE/DELETE on audit events
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION audit.trg_fn_protect_audit_event()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'Audit records are immutable. Tampering with the audit chain is a security violation.';
END;
$$;

CREATE TRIGGER trg_protect_audit_update
    BEFORE UPDATE ON audit.audit_event
    FOR EACH ROW EXECUTE FUNCTION audit.trg_fn_protect_audit_event();

CREATE TRIGGER trg_protect_audit_delete
    BEFORE DELETE ON audit.audit_event
    FOR EACH ROW EXECUTE FUNCTION audit.trg_fn_protect_audit_event();

-- ---------------------------------------------------------------------------
-- 7.4 Prevent UPDATE/DELETE on integrity records
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION integrity.trg_fn_protect_integrity_record()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'Integrity records are append-only and cannot be modified.';
END;
$$;

CREATE TRIGGER trg_protect_integrity_update
    BEFORE UPDATE ON integrity.integrity_record
    FOR EACH ROW EXECUTE FUNCTION integrity.trg_fn_protect_integrity_record();

CREATE TRIGGER trg_protect_integrity_delete
    BEFORE DELETE ON integrity.integrity_record
    FOR EACH ROW EXECUTE FUNCTION integrity.trg_fn_protect_integrity_record();

-- =============================================================================
-- SECTION 8: EVIDENCE GRAPH FUNCTIONS
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 8.1 create_evidence_relationship — safely creates evidence relationships
--     with cross-case guard and duplicate prevention
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION evidence.create_evidence_relationship(
    p_case_id           UUID,
    p_source_id         UUID,
    p_target_id         UUID,
    p_rel_type_code     VARCHAR(40),
    p_created_by        UUID,
    p_confidence        NUMERIC(4,3) DEFAULT 1.0,
    p_justification     TEXT         DEFAULT NULL
)
RETURNS UUID LANGUAGE plpgsql AS $$
DECLARE
    v_source_case UUID;
    v_target_case UUID;
    v_rel_id      UUID;
BEGIN
    -- Validate source and target belong to the same case
    SELECT case_id INTO v_source_case FROM evidence.evidence WHERE evidence_id = p_source_id;
    SELECT case_id INTO v_target_case FROM evidence.evidence WHERE evidence_id = p_target_id;

    IF v_source_case IS NULL OR v_target_case IS NULL THEN
        RAISE EXCEPTION 'Evidence item not found';
    END IF;

    IF v_source_case <> v_target_case AND v_source_case <> p_case_id THEN
        RAISE EXCEPTION
            'Evidence items belong to different cases. Cross-case relationships require explicit case_id.';
    END IF;

    IF p_source_id = p_target_id THEN
        RAISE EXCEPTION 'An evidence item cannot be related to itself.';
    END IF;

    INSERT INTO evidence.evidence_relationship (
        case_id, source_evidence_id, target_evidence_id,
        rel_type_code, confidence, justification, created_by
    ) VALUES (
        p_case_id, p_source_id, p_target_id,
        p_rel_type_code, p_confidence, p_justification, p_created_by
    )
    ON CONFLICT (source_evidence_id, target_evidence_id, rel_type_code)
    DO NOTHING
    RETURNING relationship_id INTO v_rel_id;

    RETURN v_rel_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- 8.2 get_evidence_lineage — recursive upstream traversal
--     Returns all ancestors of an evidence item
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION evidence.get_evidence_lineage(p_evidence_id UUID)
RETURNS TABLE (
    evidence_id     UUID,
    evidence_number VARCHAR(20),
    description     TEXT,
    evidence_type   VARCHAR(120),
    rel_type_code   VARCHAR(40),
    depth           INTEGER,
    path            TEXT
) LANGUAGE sql AS $$
WITH RECURSIVE lineage AS (
    -- Seed: the starting evidence item
    SELECT
        e.evidence_id,
        e.evidence_number,
        e.description,
        et.type_name AS evidence_type,
        NULL::VARCHAR(40) AS rel_type_code,
        0 AS depth,
        e.evidence_number::TEXT AS path
    FROM evidence.evidence e
    JOIN reference.evidence_type et ON et.evidence_type_id = e.evidence_type_id
    WHERE e.evidence_id = p_evidence_id

    UNION ALL

    -- Recurse: follow source → target (upstream = find what this was derived from)
    SELECT
        e.evidence_id,
        e.evidence_number,
        e.description,
        et.type_name,
        er.rel_type_code,
        l.depth + 1,
        l.path || ' ← ' || e.evidence_number
    FROM lineage l
    JOIN evidence.evidence_relationship er ON er.target_evidence_id = l.evidence_id
    JOIN evidence.evidence e ON e.evidence_id = er.source_evidence_id
    JOIN reference.evidence_type et ON et.evidence_type_id = e.evidence_type_id
    WHERE l.depth < 20   -- guard against cycles
)
SELECT evidence_id, evidence_number, description, evidence_type,
       rel_type_code, depth, path
FROM lineage
ORDER BY depth;
$$;

-- ---------------------------------------------------------------------------
-- 8.3 get_evidence_descendants — downstream traversal
--     Returns all evidence derived from an evidence item
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION evidence.get_evidence_descendants(p_evidence_id UUID)
RETURNS TABLE (
    evidence_id     UUID,
    evidence_number VARCHAR(20),
    description     TEXT,
    evidence_type   VARCHAR(120),
    rel_type_code   VARCHAR(40),
    depth           INTEGER,
    path            TEXT
) LANGUAGE sql AS $$
WITH RECURSIVE descendants AS (
    SELECT
        e.evidence_id,
        e.evidence_number,
        e.description,
        et.type_name AS evidence_type,
        NULL::VARCHAR(40) AS rel_type_code,
        0 AS depth,
        e.evidence_number::TEXT AS path
    FROM evidence.evidence e
    JOIN reference.evidence_type et ON et.evidence_type_id = e.evidence_type_id
    WHERE e.evidence_id = p_evidence_id

    UNION ALL

    SELECT
        e.evidence_id,
        e.evidence_number,
        e.description,
        et.type_name,
        er.rel_type_code,
        d.depth + 1,
        d.path || ' → ' || e.evidence_number
    FROM descendants d
    JOIN evidence.evidence_relationship er ON er.source_evidence_id = d.evidence_id
    JOIN evidence.evidence e ON e.evidence_id = er.target_evidence_id
    JOIN reference.evidence_type et ON et.evidence_type_id = e.evidence_type_id
    WHERE d.depth < 20
)
SELECT evidence_id, evidence_number, description, evidence_type,
       rel_type_code, depth, path
FROM descendants
ORDER BY depth;
$$;

-- ---------------------------------------------------------------------------
-- 8.4 get_case_evidence_graph — full evidence relationship graph for a case
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION evidence.get_case_evidence_graph(p_case_id UUID)
RETURNS TABLE (
    source_evidence_id   UUID,
    source_number        VARCHAR(20),
    source_type          VARCHAR(120),
    rel_type_code        VARCHAR(40),
    target_evidence_id   UUID,
    target_number        VARCHAR(20),
    target_type          VARCHAR(120),
    confidence           NUMERIC(4,3)
) LANGUAGE sql AS $$
SELECT
    er.source_evidence_id,
    se.evidence_number,
    set_.type_name,
    er.rel_type_code,
    er.target_evidence_id,
    te.evidence_number,
    tet.type_name,
    er.confidence
FROM evidence.evidence_relationship er
JOIN evidence.evidence se ON se.evidence_id = er.source_evidence_id
JOIN evidence.evidence te ON te.evidence_id = er.target_evidence_id
JOIN reference.evidence_type set_ ON set_.evidence_type_id = se.evidence_type_id
JOIN reference.evidence_type tet  ON tet.evidence_type_id  = te.evidence_type_id
WHERE er.case_id = p_case_id
ORDER BY se.evidence_number, te.evidence_number;
$$;

-- =============================================================================
-- SECTION 9: CUSTODY CHAIN FUNCTIONS
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 9.1 record_custody_transfer — creates a custody event with all integrity checks
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION custody.record_custody_transfer(
    p_evidence_id          UUID,
    p_case_id              UUID,
    p_event_type_code      VARCHAR(40),
    p_from_custodian_id    UUID,
    p_to_custodian_id      UUID,
    p_recorded_by          UUID,
    p_purpose              TEXT         DEFAULT NULL,
    p_seal_number_before   VARCHAR(80)  DEFAULT NULL,
    p_seal_number_after    VARCHAR(80)  DEFAULT NULL,
    p_condition_before     TEXT         DEFAULT NULL,
    p_condition_after      TEXT         DEFAULT NULL,
    p_hash_before          VARCHAR(128) DEFAULT NULL,
    p_hash_after           VARCHAR(128) DEFAULT NULL,
    p_notes                TEXT         DEFAULT NULL
)
RETURNS UUID LANGUAGE plpgsql AS $$
DECLARE
    v_event_id UUID;
BEGIN
    -- Evidence must exist and belong to the case
    IF NOT EXISTS (
        SELECT 1 FROM evidence.evidence
        WHERE evidence_id = p_evidence_id AND case_id = p_case_id
    ) THEN
        RAISE EXCEPTION 'Evidence % does not belong to case %', p_evidence_id, p_case_id;
    END IF;

    INSERT INTO custody.evidence_custody_event (
        evidence_id, case_id, event_type_code,
        event_timestamp, recorded_by,
        from_custodian_id, to_custodian_id,
        purpose,
        seal_number_before, seal_number_after,
        condition_before, condition_after,
        hash_before, hash_after, hash_algorithm,
        notes
    ) VALUES (
        p_evidence_id, p_case_id, p_event_type_code,
        now(), p_recorded_by,
        p_from_custodian_id, p_to_custodian_id,
        p_purpose,
        p_seal_number_before, p_seal_number_after,
        p_condition_before, p_condition_after,
        p_hash_before, p_hash_after, 'SHA256',
        p_notes
    )
    RETURNING custody_event_id INTO v_event_id;

    RETURN v_event_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- 9.2 get_evidence_custody_chain — full custody history for an evidence item
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION custody.get_evidence_custody_chain(p_evidence_id UUID)
RETURNS TABLE (
    event_sequence    INTEGER,
    event_type        VARCHAR(40),
    event_timestamp   TIMESTAMPTZ,
    from_custodian    VARCHAR(200),
    from_type         VARCHAR(40),
    to_custodian      VARCHAR(200),
    to_type           VARCHAR(40),
    recorded_by_name  VARCHAR(200),
    seal_before       VARCHAR(80),
    seal_after        VARCHAR(80),
    hash_before       VARCHAR(128),
    hash_after        VARCHAR(128),
    purpose           TEXT
) LANGUAGE sql AS $$
SELECT
    ece.event_sequence,
    ece.event_type_code,
    ece.event_timestamp,
    fc.display_name,
    fc.custodian_type_code,
    tc.display_name,
    tc.custodian_type_code,
    p.full_name,
    ece.seal_number_before,
    ece.seal_number_after,
    ece.hash_before,
    ece.hash_after,
    ece.purpose
FROM custody.evidence_custody_event ece
LEFT JOIN custody.custodian fc ON fc.custodian_id = ece.from_custodian_id
JOIN custody.custodian tc ON tc.custodian_id = ece.to_custodian_id
JOIN identity.officer o ON o.officer_id = ece.recorded_by
JOIN identity.person p ON p.person_id = o.person_id
WHERE ece.evidence_id = p_evidence_id
ORDER BY ece.event_sequence ASC;
$$;

-- =============================================================================
-- SECTION 10: DOCUMENT INTEGRITY FUNCTIONS
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 10.1 finalize_document_version — marks version as FINAL, creates integrity record
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION documents.finalize_document_version(
    p_version_id UUID,
    p_officer_id UUID
)
RETURNS UUID LANGUAGE plpgsql AS $$
DECLARE
    v_doc_id     UUID;
    v_hash       VARCHAR(64);
    v_doc_ref    VARCHAR(80);
    v_ver_no     INTEGER;
    v_case_id    UUID;
    v_station_id UUID;
    v_integrity_id UUID;
    v_passport_id  UUID;
    v_passport_code VARCHAR(80);
    v_payload    JSONB;
BEGIN
    -- Get version details
    SELECT dv.document_id, dv.sha256_hash, dv.version_number,
           d.document_ref, d.case_id, d.station_id
    INTO v_doc_id, v_hash, v_ver_no, v_doc_ref, v_case_id, v_station_id
    FROM documents.document_version dv
    JOIN documents.document d ON d.document_id = dv.document_id
    WHERE dv.version_id = p_version_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Document version not found: %', p_version_id;
    END IF;

    -- Check not already finalized
    IF EXISTS (
        SELECT 1 FROM documents.document_version
        WHERE version_id = p_version_id AND status_code = 'FINAL'
    ) THEN
        RAISE EXCEPTION 'Document version % is already FINAL', p_version_id;
    END IF;

    -- Mark as FINAL
    UPDATE documents.document_version
    SET status_code  = 'FINAL',
        finalized_at = now(),
        finalized_by = p_officer_id
    WHERE version_id = p_version_id;

    -- Build passport payload
    v_passport_code := 'PP-' || encode(gen_random_bytes(12), 'hex');
    v_payload := jsonb_build_object(
        'document_id',    v_doc_id,
        'version_id',     p_version_id,
        'document_ref',   v_doc_ref,
        'version_number', v_ver_no,
        'sha256_hash',    v_hash,
        'finalized_at',   now(),
        'finalized_by',   p_officer_id,
        'passport_code',  v_passport_code
    );

    -- Create integrity record
    INSERT INTO integrity.integrity_record (
        resource_type, resource_id, hash_value, hash_algorithm,
        recorded_by, case_id, station_id,
        verification_status, passport_payload
    ) VALUES (
        'DOCUMENT_VERSION', p_version_id, v_hash, 'SHA256',
        p_officer_id, v_case_id, v_station_id,
        'UNVERIFIED', v_payload
    )
    RETURNING integrity_id INTO v_integrity_id;

    -- Create document passport
    INSERT INTO integrity.document_passport (
        document_id, version_id, integrity_id,
        passport_code, qr_payload, issued_by
    ) VALUES (
        v_doc_id, p_version_id, v_integrity_id,
        v_passport_code, v_payload, p_officer_id
    )
    RETURNING passport_id INTO v_passport_id;

    RETURN v_integrity_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- 10.2 verify_document_version — checks stored hash against provided hash
--      Returns verification result and raises alert on mismatch
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION documents.verify_document_version(
    p_version_id    UUID,
    p_computed_hash VARCHAR(64),
    p_verified_by   UUID,
    p_session_id    UUID DEFAULT NULL,
    p_ip_address    INET DEFAULT NULL
)
RETURNS TABLE (
    result           VARCHAR(30),
    stored_hash      VARCHAR(64),
    computed_hash    VARCHAR(64),
    hashes_match     BOOLEAN,
    document_ref     VARCHAR(80),
    version_number   INTEGER,
    finalized_at     TIMESTAMPTZ,
    integrity_id     UUID
) LANGUAGE plpgsql AS $$
DECLARE
    v_stored_hash   VARCHAR(64);
    v_doc_ref       VARCHAR(80);
    v_ver_no        INTEGER;
    v_finalized_at  TIMESTAMPTZ;
    v_integrity_id  UUID;
    v_match         BOOLEAN;
    v_result        VARCHAR(30);
    v_alert_id      UUID;
    v_ver_id        UUID;
BEGIN
    -- Get stored hash and integrity record
    SELECT dv.sha256_hash, d.document_ref, dv.version_number, dv.finalized_at
    INTO v_stored_hash, v_doc_ref, v_ver_no, v_finalized_at
    FROM documents.document_version dv
    JOIN documents.document d ON d.document_id = dv.document_id
    WHERE dv.version_id = p_version_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Document version not found: %', p_version_id;
    END IF;

    SELECT ir.integrity_id INTO v_integrity_id
    FROM integrity.integrity_record ir
    WHERE ir.resource_type = 'DOCUMENT_VERSION' AND ir.resource_id = p_version_id;

    v_match  := (v_stored_hash = p_computed_hash);
    v_result := CASE WHEN v_match THEN 'INTACT' ELSE 'HASH_MISMATCH' END;

    -- Record verification event
    INSERT INTO integrity.verification_event (
        integrity_id, resource_type, resource_id,
        verification_method, computed_hash, stored_hash, hash_algorithm,
        result, verified_by, session_id, ip_address,
        alert_raised
    ) VALUES (
        v_integrity_id, 'DOCUMENT_VERSION', p_version_id,
        'HASH_COMPARISON', p_computed_hash, v_stored_hash, 'SHA256',
        v_result, p_verified_by, p_session_id, p_ip_address,
        NOT v_match
    )
    RETURNING verification_id INTO v_ver_id;

    -- Update integrity record status
    IF v_integrity_id IS NOT NULL THEN
        UPDATE integrity.integrity_record
        SET verification_status = CASE WHEN v_match THEN 'VERIFIED_INTACT' ELSE 'HASH_MISMATCH' END,
            last_verified_at    = now(),
            last_verified_by    = p_verified_by
        WHERE integrity_id = v_integrity_id;
    END IF;

    -- Raise integrity alert on mismatch
    IF NOT v_match THEN
        INSERT INTO integrity.integrity_alert (
            integrity_id, verification_id,
            resource_type, resource_id,
            alert_type, severity,
            alert_title, alert_description,
            expected_value, actual_value,
            detected_by, detected_at
        ) VALUES (
            v_integrity_id, v_ver_id,
            'DOCUMENT_VERSION', p_version_id,
            'HASH_MISMATCH', 'CRITICAL',
            'Document Hash Mismatch: ' || COALESCE(v_doc_ref, ''),
            'SHA-256 hash mismatch detected for document version ' || p_version_id::TEXT ||
            '. The file may have been tampered with.',
            v_stored_hash, p_computed_hash,
            p_verified_by, now()
        )
        RETURNING alert_id INTO v_alert_id;

        -- Update verification event with alert reference
        UPDATE integrity.verification_event
        SET alert_raised = TRUE, alert_id = v_alert_id
        WHERE verification_id = v_ver_id;
    END IF;

    -- Return result
    result         := v_result;
    stored_hash    := v_stored_hash;
    computed_hash  := p_computed_hash;
    hashes_match   := v_match;
    document_ref   := v_doc_ref;
    version_number := v_ver_no;
    finalized_at   := v_finalized_at;
    integrity_id   := v_integrity_id;
    RETURN NEXT;
END;
$$;

-- =============================================================================
-- SECTION 11: AUTHORIZATION FUNCTIONS
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 11.1 check_officer_case_access — returns TRUE if officer may perform action
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION authz.check_officer_case_access(
    p_officer_id    UUID,
    p_case_id       UUID,
    p_permission_code VARCHAR(80)
)
RETURNS BOOLEAN LANGUAGE plpgsql AS $$
DECLARE
    v_has_access BOOLEAN := FALSE;
BEGIN
    -- Check via case assignment + case role permissions
    SELECT EXISTS (
        SELECT 1
        FROM authz.officer_case_assignment oca
        JOIN authz.case_role_permission crp ON crp.case_role_id = oca.case_role_id
        JOIN reference.permission perm ON perm.permission_id = crp.permission_id
        WHERE oca.officer_id  = p_officer_id
          AND oca.case_id     = p_case_id
          AND oca.is_active   = TRUE
          AND crp.is_active   = TRUE
          AND perm.permission_code = p_permission_code
          AND perm.is_active  = TRUE
    ) INTO v_has_access;

    IF v_has_access THEN RETURN TRUE; END IF;

    -- Fallback: check system role permissions (station-scoped or global)
    SELECT EXISTS (
        SELECT 1
        FROM authz.officer_system_role osr
        JOIN authz.role_permission rp ON rp.role_id = osr.role_id
        JOIN reference.permission perm ON perm.permission_id = rp.permission_id
        JOIN case_mgmt.case c ON c.case_id = p_case_id
        WHERE osr.officer_id = p_officer_id
          AND osr.is_active  = TRUE
          AND rp.is_active   = TRUE
          AND perm.permission_code = p_permission_code
          AND (osr.station_id IS NULL OR osr.station_id = c.current_station_id)
    ) INTO v_has_access;

    RETURN v_has_access;
END;
$$;

-- ---------------------------------------------------------------------------
-- 11.2 get_officer_accessible_cases — returns all cases an officer can access
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION authz.get_officer_accessible_cases(
    p_officer_id UUID
)
RETURNS TABLE (
    case_id        UUID,
    case_number    VARCHAR(60),
    case_status    VARCHAR(40),
    case_role      VARCHAR(60),
    station_name   VARCHAR(200),
    opened_at      TIMESTAMPTZ
) LANGUAGE sql AS $$
SELECT DISTINCT
    c.case_id,
    c.case_number,
    c.case_status_code,
    cr.role_code,
    ps.station_name,
    c.opened_at
FROM case_mgmt.case c
JOIN authz.officer_case_assignment oca ON oca.case_id = c.case_id
JOIN reference.case_role cr ON cr.case_role_id = oca.case_role_id
JOIN organisation.police_station ps ON ps.station_id = c.current_station_id
WHERE oca.officer_id = p_officer_id
  AND oca.is_active  = TRUE
  AND c.deleted_at   IS NULL
ORDER BY c.opened_at DESC;
$$;

-- =============================================================================
-- SECTION 12: CASE DIARY IMMUTABILITY TRIGGER
-- =============================================================================

CREATE OR REPLACE FUNCTION investigation.trg_fn_protect_case_diary()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.is_finalized = TRUE THEN
        RAISE EXCEPTION
            'Case diary entry % is finalized and cannot be modified. '
            'Create a new correcting entry instead.', OLD.diary_id;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_protect_case_diary
    BEFORE UPDATE ON investigation.case_diary
    FOR EACH ROW EXECUTE FUNCTION investigation.trg_fn_protect_case_diary();

CREATE OR REPLACE FUNCTION investigation.trg_fn_prevent_diary_delete()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'Case diary entries cannot be deleted.';
END;
$$;

CREATE TRIGGER trg_prevent_diary_delete
    BEFORE DELETE ON investigation.case_diary
    FOR EACH ROW EXECUTE FUNCTION investigation.trg_fn_prevent_diary_delete();

-- Auto-assign sequential entry_number per case
CREATE OR REPLACE FUNCTION investigation.trg_fn_diary_entry_number()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_next_no INTEGER;
BEGIN
    SELECT COALESCE(MAX(entry_number), 0) + 1
    INTO v_next_no
    FROM investigation.case_diary
    WHERE case_id = NEW.case_id;

    NEW.entry_number := v_next_no;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_diary_entry_number
    BEFORE INSERT ON investigation.case_diary
    FOR EACH ROW EXECUTE FUNCTION investigation.trg_fn_diary_entry_number();

-- =============================================================================
-- SECTION 13: OFFICER POSTING TRIGGER
-- =============================================================================

-- Close previous current posting when a new one is inserted
CREATE OR REPLACE FUNCTION identity.trg_fn_close_previous_posting()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.is_current = TRUE THEN
        UPDATE identity.officer_posting
        SET is_current       = FALSE,
            posting_end_date = NEW.posting_start_date - INTERVAL '1 day',
            updated_at       = now()
        WHERE officer_id  = NEW.officer_id
          AND is_current  = TRUE
          AND posting_id <> NEW.posting_id;

        -- Also update officer.current_station_id
        UPDATE identity.officer
        SET current_station_id = NEW.police_station_id,
            current_rank_code  = (
                SELECT rank_code FROM reference.rank
                WHERE rank_id = NEW.rank_id
            ),
            updated_at = now()
        WHERE officer_id = NEW.officer_id;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_close_previous_posting
    AFTER INSERT ON identity.officer_posting
    FOR EACH ROW EXECUTE FUNCTION identity.trg_fn_close_previous_posting();

-- =============================================================================
-- SECTION 14: OPTIMISTIC LOCKING TRIGGER
-- =============================================================================

CREATE OR REPLACE FUNCTION public.check_version_no()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.version_no := OLD.version_no + 1;
    RETURN NEW;
END;
$$;

-- Apply to tables with version_no
CREATE TRIGGER trg_version_case
    BEFORE UPDATE ON case_mgmt.case
    FOR EACH ROW EXECUTE FUNCTION public.check_version_no();

CREATE TRIGGER trg_version_officer
    BEFORE UPDATE ON identity.officer
    FOR EACH ROW EXECUTE FUNCTION public.check_version_no();

CREATE TRIGGER trg_version_evidence
    BEFORE UPDATE ON evidence.evidence
    FOR EACH ROW EXECUTE FUNCTION public.check_version_no();

CREATE TRIGGER trg_version_investigation
    BEFORE UPDATE ON investigation.investigation
    FOR EACH ROW EXECUTE FUNCTION public.check_version_no();

CREATE TRIGGER trg_version_document
    BEFORE UPDATE ON documents.document
    FOR EACH ROW EXECUTE FUNCTION public.check_version_no();
