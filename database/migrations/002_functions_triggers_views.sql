-- 002_functions_triggers_views.sql
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
CREATE OR REPLACE FUNCTION authorization.check_officer_case_access(
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
        FROM authorization.officer_case_assignment oca
        JOIN authorization.case_role_permission crp ON crp.case_role_id = oca.case_role_id
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
        FROM authorization.officer_system_role osr
        JOIN authorization.role_permission rp ON rp.role_id = osr.role_id
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
CREATE OR REPLACE FUNCTION authorization.get_officer_accessible_cases(
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
JOIN authorization.officer_case_assignment oca ON oca.case_id = c.case_id
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
-- =============================================================================
-- 001_views.sql
-- All database views for the Police DMS
-- Designed to back backend API endpoints directly.
-- =============================================================================

-- =============================================================================
-- 1. vw_officer_current_posting
--    Who is posted where right now, with full rank/designation detail
-- =============================================================================
CREATE OR REPLACE VIEW identity.vw_officer_current_posting AS
SELECT
    o.officer_id,
    o.identity_code,
    o.service_number,
    o.username,
    p.full_name                     AS officer_name,
    p.phone_primary,
    p.email,
    r.rank_code,
    r.rank_name,
    r.rank_level,
    r.is_gazetted,
    d.designation_code,
    d.designation_name,
    op.police_station_id,
    ps.station_code,
    ps.station_name,
    ps.state_code,
    ps.district_name,
    ou.unit_name                    AS unit_name,
    ou.unit_type_code,
    op.posting_start_date,
    op.posting_type,
    op.appointment_order_no,
    ro.officer_id                   AS reporting_officer_id,
    rp.full_name                    AS reporting_officer_name,
    o.is_active,
    o.current_station_id
FROM identity.officer o
JOIN identity.person p              ON p.person_id        = o.person_id
JOIN reference.rank r               ON r.rank_code        = o.current_rank_code
LEFT JOIN identity.officer_posting op ON op.officer_id   = o.officer_id
                                     AND op.is_current    = TRUE
LEFT JOIN reference.designation d   ON d.designation_id  = op.designation_id
LEFT JOIN organisation.police_station ps ON ps.station_id = op.police_station_id
LEFT JOIN organisation.organisation_unit ou ON ou.unit_id = op.organisation_unit_id
LEFT JOIN identity.officer ro       ON ro.officer_id      = op.reporting_officer_id
LEFT JOIN identity.person rp        ON rp.person_id       = ro.person_id
WHERE o.is_active = TRUE
  AND o.deleted_at IS NULL;

-- =============================================================================
-- 2. vw_case_summary
--    One row per case with station, IO, type and status info
-- =============================================================================
CREATE OR REPLACE VIEW case_mgmt.vw_case_summary AS
SELECT
    c.case_id,
    c.case_number,
    c.case_status_code,
    cs.label                        AS case_status_label,
    ct.type_name                    AS case_type,
    c.priority,
    c.confidentiality_code,
    c.opened_at,
    c.closed_at,
    c.incident_date,
    c.incident_location,
    c.is_zero_fir,
    c.is_transferred,
    c.is_sensitive,
    c.legal_hold,
    -- Originating station
    ops.station_id                  AS originating_station_id,
    ops.station_name                AS originating_station_name,
    ops.state_code                  AS originating_state,
    ops.district_name               AS originating_district,
    -- Current station
    cps.station_id                  AS current_station_id,
    cps.station_name                AS current_station_name,
    -- Primary IO
    io.officer_id                   AS primary_io_id,
    iop.full_name                   AS primary_io_name,
    ior.rank_name                   AS primary_io_rank,
    -- Supervising officer
    so.officer_id                   AS supervising_officer_id,
    sop.full_name                   AS supervising_officer_name,
    -- Counts (subqueries for quick API use)
    (SELECT COUNT(*) FROM evidence.evidence ev
     WHERE ev.case_id = c.case_id AND ev.is_active = TRUE)          AS evidence_count,
    (SELECT COUNT(*) FROM documents.document doc
     WHERE doc.case_id = c.case_id AND doc.is_active = TRUE)        AS document_count,
    (SELECT COUNT(*) FROM identity.case_person cp
     WHERE cp.case_id = c.case_id AND cp.is_active = TRUE)          AS person_count,
    c.last_activity_at,
    c.created_by,
    cbp.full_name                   AS created_by_name,
    c.version_no
FROM case_mgmt.case c
JOIN reference.case_status cs       ON cs.status_code     = c.case_status_code
JOIN reference.case_type ct         ON ct.case_type_id    = c.case_type_id
JOIN organisation.police_station ops ON ops.station_id    = c.originating_station_id
JOIN organisation.police_station cps ON cps.station_id    = c.current_station_id
LEFT JOIN identity.officer io       ON io.officer_id      = c.primary_io_id
LEFT JOIN identity.person iop       ON iop.person_id      = io.person_id
LEFT JOIN reference.rank ior        ON ior.rank_code      = io.current_rank_code
LEFT JOIN identity.officer so       ON so.officer_id      = c.supervising_officer_id
LEFT JOIN identity.person sop       ON sop.person_id      = so.person_id
JOIN identity.officer cbo           ON cbo.officer_id     = c.created_by
JOIN identity.person cbp            ON cbp.person_id      = cbo.person_id
WHERE c.deleted_at IS NULL;

-- =============================================================================
-- 3. vw_case_officers
--    All officers assigned to a case with their case roles
-- =============================================================================
CREATE OR REPLACE VIEW case_mgmt.vw_case_officers AS
SELECT
    oca.assignment_id,
    oca.case_id,
    c.case_number,
    oca.officer_id,
    p.full_name                     AS officer_name,
    o.identity_code,
    r.rank_name,
    r.rank_code,
    d.designation_name,
    ps.station_name                 AS current_station,
    cr.role_code                    AS case_role_code,
    cr.role_name                    AS case_role_name,
    oca.is_active,
    oca.start_date,
    oca.end_date,
    oca.assigned_at,
    ab.full_name                    AS assigned_by_name,
    oca.scope,
    oca.reason
FROM authorization.officer_case_assignment oca
JOIN case_mgmt.case c               ON c.case_id          = oca.case_id
JOIN identity.officer o             ON o.officer_id       = oca.officer_id
JOIN identity.person p              ON p.person_id        = o.person_id
JOIN reference.rank r               ON r.rank_code        = o.current_rank_code
LEFT JOIN identity.officer_posting opst ON opst.officer_id = o.officer_id
                                       AND opst.is_current  = TRUE
LEFT JOIN reference.designation d   ON d.designation_id   = opst.designation_id
LEFT JOIN organisation.police_station ps ON ps.station_id  = o.current_station_id
JOIN reference.case_role cr         ON cr.case_role_id    = oca.case_role_id
JOIN identity.officer abo           ON abo.officer_id     = oca.assigned_by
JOIN identity.person ab             ON ab.person_id       = abo.person_id
WHERE c.deleted_at IS NULL;

-- =============================================================================
-- 4. vw_case_evidence
--    All evidence for a case with type and current status
-- =============================================================================
CREATE OR REPLACE VIEW case_mgmt.vw_case_evidence AS
SELECT
    e.evidence_id,
    e.case_id,
    c.case_number,
    e.evidence_number,
    et.type_code                    AS evidence_type_code,
    et.type_name                    AS evidence_type,
    et.is_digital,
    e.description,
    e.source,
    e.discovery_method,
    e.collection_timestamp,
    e.collection_location,
    e.current_status_code,
    es.label                        AS status_label,
    e.classification_code,
    e.seal_number,
    e.integrity_status,
    e.sha256_hash,
    e.quantity,
    e.unit_of_measure,
    e.make,
    e.model,
    e.serial_number,
    col.full_name                   AS collected_by_name,
    colr.rank_name                  AS collected_by_rank,
    -- Current custodian (last custody event)
    (SELECT tc.display_name
     FROM custody.evidence_custody_event ece
     JOIN custody.custodian tc ON tc.custodian_id = ece.to_custodian_id
     WHERE ece.evidence_id = e.evidence_id
     ORDER BY ece.event_sequence DESC LIMIT 1)  AS current_custodian,
    -- Has digital evidence record
    (de.digital_ev_id IS NOT NULL)              AS has_digital_record,
    de.acquisition_method,
    de.sha256_hash AS digital_hash,
    e.is_active,
    e.created_at
FROM evidence.evidence e
JOIN case_mgmt.case c               ON c.case_id          = e.case_id
JOIN reference.evidence_type et     ON et.evidence_type_id = e.evidence_type_id
JOIN reference.evidence_status es   ON es.status_code     = e.current_status_code
JOIN identity.officer colo          ON colo.officer_id    = e.collected_by
JOIN identity.person col            ON col.person_id      = colo.person_id
JOIN reference.rank colr            ON colr.rank_code     = colo.current_rank_code
LEFT JOIN evidence.digital_evidence de ON de.evidence_id  = e.evidence_id
WHERE e.is_active = TRUE
  AND c.deleted_at IS NULL;

-- =============================================================================
-- 5. vw_evidence_custody
--    Complete custody chain per evidence item (flat view for API)
-- =============================================================================
CREATE OR REPLACE VIEW custody.vw_evidence_custody AS
SELECT
    ece.custody_event_id,
    ece.evidence_id,
    e.evidence_number,
    e.case_id,
    c.case_number,
    ece.event_sequence,
    ece.event_type_code,
    cet.label                       AS event_type_label,
    ece.event_timestamp,
    fc.display_name                 AS from_custodian,
    fc.custodian_type_code          AS from_custodian_type,
    tc.display_name                 AS to_custodian,
    tc.custodian_type_code          AS to_custodian_type,
    rp.full_name                    AS recorded_by_name,
    ece.seal_number_before,
    ece.seal_number_after,
    ece.seal_status,
    ece.condition_before,
    ece.condition_after,
    ece.hash_before,
    ece.hash_after,
    ece.purpose,
    ece.acknowledgement_ref,
    ece.notes,
    ece.created_at
FROM custody.evidence_custody_event ece
JOIN evidence.evidence e            ON e.evidence_id      = ece.evidence_id
JOIN case_mgmt.case c               ON c.case_id          = ece.case_id
JOIN reference.custody_event_type cet ON cet.event_type_code = ece.event_type_code
LEFT JOIN custody.custodian fc      ON fc.custodian_id    = ece.from_custodian_id
JOIN custody.custodian tc           ON tc.custodian_id    = ece.to_custodian_id
JOIN identity.officer ro            ON ro.officer_id      = ece.recorded_by
JOIN identity.person rp             ON rp.person_id       = ro.person_id
ORDER BY ece.evidence_id, ece.event_sequence;

-- =============================================================================
-- 6. vw_document_versions
--    All versions of every document with status and signature info
-- =============================================================================
CREATE OR REPLACE VIEW documents.vw_document_versions AS
SELECT
    dv.version_id,
    dv.document_id,
    d.document_ref,
    d.title,
    dt.type_name                    AS document_type,
    dv.version_number,
    dv.version_label,
    dv.status_code,
    vs.label                        AS status_label,
    vs.is_terminal,
    dv.file_name,
    dv.mime_type,
    dv.file_size_bytes,
    dv.sha256_hash,
    dv.hash_algorithm,
    dv.storage_provider,
    dv.storage_path,
    dv.object_key,
    dv.change_reason,
    -- Authorship
    cp.full_name                    AS created_by_name,
    dv.created_at,
    -- Finalisation
    dv.finalized_at,
    fp.full_name                    AS finalized_by_name,
    -- Signature
    ds.signature_id,
    ds.signer_name,
    ds.signed_at,
    ds.signature_status,
    ds.signature_algorithm,
    -- Integrity
    ir.integrity_id,
    ir.verification_status,
    ir.last_verified_at,
    -- Case context
    d.case_id,
    d.classification_code,
    d.legal_hold
FROM documents.document_version dv
JOIN documents.document d           ON d.document_id      = dv.document_id
JOIN reference.document_type dt     ON dt.document_type_id = d.document_type_id
JOIN reference.version_status vs    ON vs.status_code     = dv.status_code
JOIN identity.officer co            ON co.officer_id      = dv.created_by
JOIN identity.person cp             ON cp.person_id       = co.person_id
LEFT JOIN identity.officer fo       ON fo.officer_id      = dv.finalized_by
LEFT JOIN identity.person fp        ON fp.person_id       = fo.person_id
LEFT JOIN documents.digital_signature ds ON ds.version_id = dv.version_id
LEFT JOIN integrity.integrity_record ir  ON ir.resource_type = 'DOCUMENT_VERSION'
                                        AND ir.resource_id  = dv.version_id
WHERE d.is_active = TRUE
ORDER BY dv.document_id, dv.version_number;

-- =============================================================================
-- 7. vw_document_integrity
--    Latest version of each document with integrity status — for dashboard
-- =============================================================================
CREATE OR REPLACE VIEW documents.vw_document_integrity AS
SELECT
    d.document_id,
    d.document_ref,
    d.title,
    dt.type_name                    AS document_type,
    d.classification_code,
    d.case_id,
    c.case_number,
    d.current_version_no,
    dv.version_id                   AS current_version_id,
    dv.sha256_hash,
    dv.status_code                  AS version_status,
    dv.finalized_at,
    ds.signer_name,
    ds.signed_at,
    ds.signature_status,
    ir.verification_status,
    ir.last_verified_at,
    dp.passport_code,
    dp.is_active                    AS passport_active,
    CASE
        WHEN ir.verification_status = 'HASH_MISMATCH'  THEN 'COMPROMISED'
        WHEN ir.verification_status = 'VERIFIED_INTACT' THEN 'VERIFIED'
        WHEN dv.status_code         = 'FINAL'           THEN 'FINALIZED_UNVERIFIED'
        ELSE 'DRAFT'
    END                             AS integrity_summary
FROM documents.document d
JOIN reference.document_type dt     ON dt.document_type_id = d.document_type_id
LEFT JOIN case_mgmt.case c          ON c.case_id           = d.case_id
LEFT JOIN documents.document_version dv ON dv.version_id  = d.current_version_id
LEFT JOIN documents.digital_signature ds ON ds.version_id = dv.version_id
LEFT JOIN integrity.integrity_record ir  ON ir.resource_type = 'DOCUMENT_VERSION'
                                        AND ir.resource_id   = dv.version_id
LEFT JOIN integrity.document_passport dp ON dp.version_id  = dv.version_id
                                        AND dp.is_active    = TRUE
WHERE d.is_active = TRUE;

-- =============================================================================
-- 8. vw_case_timeline
--    Chronological timeline of all events for a case
-- =============================================================================
CREATE OR REPLACE VIEW investigation.vw_case_timeline AS
SELECT
    ct.timeline_id,
    ct.case_id,
    c.case_number,
    ct.event_timestamp,
    ct.event_category,
    ct.title,
    ct.description,
    ct.officer_id,
    ct.officer_name,
    ct.source_table,
    ct.source_id,
    ct.created_at
FROM investigation.case_timeline ct
JOIN case_mgmt.case c               ON c.case_id = ct.case_id
WHERE c.deleted_at IS NULL
ORDER BY ct.event_timestamp ASC;

-- =============================================================================
-- 9. vw_officer_accessible_cases
--    All cases an officer can access with their role on each
-- =============================================================================
CREATE OR REPLACE VIEW authorization.vw_officer_accessible_cases AS
SELECT
    oca.officer_id,
    op.full_name                    AS officer_name,
    oca.case_id,
    c.case_number,
    c.case_status_code,
    cs.label                        AS case_status,
    ct.type_name                    AS case_type,
    cr.role_code                    AS case_role_code,
    cr.role_name                    AS case_role,
    ps.station_name                 AS station_name,
    c.opened_at,
    c.primary_io_id,
    oca.is_active,
    oca.scope
FROM authorization.officer_case_assignment oca
JOIN identity.officer o             ON o.officer_id       = oca.officer_id
JOIN identity.person op             ON op.person_id       = o.person_id
JOIN case_mgmt.case c               ON c.case_id          = oca.case_id
JOIN reference.case_status cs       ON cs.status_code     = c.case_status_code
JOIN reference.case_type ct         ON ct.case_type_id    = c.case_type_id
JOIN reference.case_role cr         ON cr.case_role_id    = oca.case_role_id
JOIN organisation.police_station ps ON ps.station_id      = c.current_station_id
WHERE oca.is_active = TRUE
  AND c.deleted_at  IS NULL;

-- =============================================================================
-- 10. vw_audit_summary
--    Recent audit events with officer and case context — for audit viewer
-- =============================================================================
CREATE OR REPLACE VIEW audit.vw_audit_summary AS
SELECT
    ae.audit_id,
    ae.chain_id,
    ae.action_code,
    aat.label                       AS action_label,
    ae.severity,
    ae.event_timestamp,
    ae.officer_id,
    ae.officer_name,
    ae.officer_rank,
    ae.police_station_id,
    ae.station_name,
    ae.case_id,
    ae.case_number,
    ae.resource_type,
    ae.resource_id,
    ae.resource_ref,
    ae.result,
    ae.failure_reason,
    ae.ip_address,
    ae.previous_hash,
    ae.event_hash,
    -- Chain integrity indicator
    ac.chain_status
FROM audit.audit_event ae
JOIN reference.audit_action_type aat ON aat.action_code  = ae.action_code
LEFT JOIN audit.audit_chain ac       ON ac.chain_id      = ae.chain_id
ORDER BY ae.event_timestamp DESC;

-- =============================================================================
-- 11. vw_evidence_lineage (flat view — functions handle recursive traversal)
--     Direct parent-child relationships for quick display
-- =============================================================================
CREATE OR REPLACE VIEW evidence.vw_evidence_lineage AS
SELECT
    er.relationship_id,
    er.case_id,
    c.case_number,
    er.source_evidence_id,
    se.evidence_number              AS source_number,
    set_.type_name                  AS source_type,
    se.description                  AS source_description,
    er.rel_type_code,
    ert.label                       AS relationship_label,
    er.confidence,
    er.target_evidence_id,
    te.evidence_number              AS target_number,
    tet.type_name                   AS target_type,
    te.description                  AS target_description,
    er.is_verified,
    vp.full_name                    AS verified_by_name,
    er.verified_at,
    cp.full_name                    AS created_by_name,
    er.created_at
FROM evidence.evidence_relationship er
JOIN case_mgmt.case c               ON c.case_id           = er.case_id
JOIN evidence.evidence se           ON se.evidence_id      = er.source_evidence_id
JOIN evidence.evidence te           ON te.evidence_id      = er.target_evidence_id
JOIN reference.evidence_type set_   ON set_.evidence_type_id = se.evidence_type_id
JOIN reference.evidence_type tet    ON tet.evidence_type_id = te.evidence_type_id
JOIN reference.evidence_relationship_type ert ON ert.rel_type_code = er.rel_type_code
JOIN identity.officer cro           ON cro.officer_id      = er.created_by
JOIN identity.person cp             ON cp.person_id        = cro.person_id
LEFT JOIN identity.officer vro      ON vro.officer_id      = er.verified_by
LEFT JOIN identity.person vp        ON vp.person_id        = vro.person_id;

-- =============================================================================
-- 12. vw_station_officers
--    All active officers at each police station
-- =============================================================================
CREATE OR REPLACE VIEW organisation.vw_station_officers AS
SELECT
    ps.station_id,
    ps.station_code,
    ps.station_name,
    ps.state_code,
    ps.district_name,
    o.officer_id,
    o.identity_code,
    p.full_name                     AS officer_name,
    r.rank_name,
    r.rank_code,
    r.rank_level,
    d.designation_name,
    op.posting_start_date,
    op.posting_type,
    o.is_active
FROM organisation.police_station ps
JOIN identity.officer_posting op    ON op.police_station_id = ps.station_id
                                   AND op.is_current        = TRUE
JOIN identity.officer o             ON o.officer_id         = op.officer_id
JOIN identity.person p              ON p.person_id          = o.person_id
JOIN reference.rank r               ON r.rank_code          = o.current_rank_code
LEFT JOIN reference.designation d   ON d.designation_id     = op.designation_id
WHERE o.is_active  = TRUE
  AND ps.is_active = TRUE;

-- =============================================================================
-- 13. vw_officer_posting_history
--    Full posting history for every officer
-- =============================================================================
CREATE OR REPLACE VIEW identity.vw_officer_posting_history AS
SELECT
    o.officer_id,
    o.identity_code,
    p.full_name                     AS officer_name,
    op.posting_id,
    op.posting_start_date,
    op.posting_end_date,
    op.is_current,
    op.posting_type,
    r.rank_name,
    r.rank_code,
    d.designation_name,
    ps.station_name,
    ps.state_code,
    ps.district_name,
    ou.unit_name,
    ou.unit_type_code,
    op.appointment_order_no,
    rpo.full_name                   AS reporting_officer_name
FROM identity.officer o
JOIN identity.person p              ON p.person_id          = o.person_id
JOIN identity.officer_posting op    ON op.officer_id        = o.officer_id
JOIN reference.rank r               ON r.rank_id            = op.rank_id
LEFT JOIN reference.designation d   ON d.designation_id     = op.designation_id
LEFT JOIN organisation.police_station ps ON ps.station_id   = op.police_station_id
LEFT JOIN organisation.organisation_unit ou ON ou.unit_id   = op.organisation_unit_id
LEFT JOIN identity.officer roo      ON roo.officer_id       = op.reporting_officer_id
LEFT JOIN identity.person rpo       ON rpo.person_id        = roo.person_id
ORDER BY o.officer_id, op.posting_start_date DESC;

-- =============================================================================
-- 14. vw_case_fir
--    FIR details for each case, including Zero FIR lineage
-- =============================================================================
CREATE OR REPLACE VIEW case_mgmt.vw_case_fir AS
SELECT
    f.fir_id,
    f.case_id,
    c.case_number,
    f.fir_number,
    f.fir_year,
    f.fir_type,
    f.fir_status,
    ps.station_name                 AS station_name,
    ps.state_code,
    -- Zero FIR parent
    pf.fir_number                   AS parent_fir_number,
    pps.station_name                AS parent_station_name,
    f.is_anonymous,
    comp.full_name                  AS complainant_name,
    f.incident_date,
    f.incident_location,
    f.incident_description,
    f.ipc_sections,
    f.bnss_sections,
    reg.full_name                   AS registered_by_name,
    regr.rank_name                  AS registered_by_rank,
    f.registered_at,
    f.transferred_to_station_id,
    tps.station_name                AS transferred_to_station,
    f.transferred_at,
    f.is_active
FROM case_mgmt.fir f
JOIN case_mgmt.case c               ON c.case_id            = f.case_id
JOIN organisation.police_station ps ON ps.station_id        = f.station_id
LEFT JOIN case_mgmt.fir pf          ON pf.fir_id            = f.zero_fir_parent_id
LEFT JOIN organisation.police_station pps ON pps.station_id = pf.station_id
LEFT JOIN identity.person comp      ON comp.person_id       = f.complainant_person_id
JOIN identity.officer rego          ON rego.officer_id      = f.registered_by
JOIN identity.person reg            ON reg.person_id        = rego.person_id
JOIN reference.rank regr            ON regr.rank_code       = rego.current_rank_code
LEFT JOIN organisation.police_station tps ON tps.station_id = f.transferred_to_station_id;

-- =============================================================================
-- 15. vw_forensic_requests
--    All FSL requests with lab, status and evidence count
-- =============================================================================
CREATE OR REPLACE VIEW forensic.vw_forensic_requests AS
SELECT
    fr.request_id,
    fr.request_number,
    fr.case_id,
    c.case_number,
    fl.lab_name,
    fl.lab_code,
    fd.discipline_name,
    req.full_name                   AS requested_by_name,
    reqr.rank_name                  AS requested_by_rank,
    fr.requested_at,
    fr.request_status,
    fr.priority,
    fr.examination_required,
    fr.expected_return_date,
    fr.actual_return_date,
    fr.submission_ref,
    -- Evidence count
    (SELECT COUNT(*) FROM forensic.forensic_request_evidence fre
     WHERE fre.request_id = fr.request_id)          AS evidence_item_count,
    -- Report available?
    EXISTS (SELECT 1 FROM forensic.forensic_report rep
            WHERE rep.request_id = fr.request_id)   AS report_available,
    fr.created_at
FROM forensic.forensic_request fr
JOIN case_mgmt.case c               ON c.case_id            = fr.case_id
JOIN organisation.forensic_laboratory fl ON fl.lab_id       = fr.lab_id
JOIN reference.forensic_discipline fd ON fd.discipline_id   = fr.discipline_id
JOIN identity.officer reqo          ON reqo.officer_id      = fr.requested_by
JOIN identity.person req            ON req.person_id        = reqo.person_id
JOIN reference.rank reqr            ON reqr.rank_code       = reqo.current_rank_code;

-- =============================================================================
-- 16. vw_station_cases
--    All cases for each police station (current station)
-- =============================================================================
CREATE OR REPLACE VIEW organisation.vw_station_cases AS
SELECT
    ps.station_id,
    ps.station_code,
    ps.station_name,
    ps.state_code,
    c.case_id,
    c.case_number,
    c.case_status_code,
    cs.label                        AS case_status,
    ct.type_name                    AS case_type,
    c.priority,
    c.opened_at,
    c.closed_at,
    c.is_zero_fir,
    io_p.full_name                  AS primary_io_name,
    c.last_activity_at
FROM organisation.police_station ps
JOIN case_mgmt.case c               ON c.current_station_id = ps.station_id
                                   AND c.deleted_at         IS NULL
JOIN reference.case_status cs       ON cs.status_code       = c.case_status_code
JOIN reference.case_type ct         ON ct.case_type_id      = c.case_type_id
LEFT JOIN identity.officer io       ON io.officer_id        = c.primary_io_id
LEFT JOIN identity.person io_p      ON io_p.person_id       = io.person_id;
