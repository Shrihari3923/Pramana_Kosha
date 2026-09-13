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
FROM authz.officer_case_assignment oca
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
    de.acquisition_hash AS digital_hash,
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
LEFT JOIN documents.digital_signature ds ON ds.document_version_id = dv.version_id
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
LEFT JOIN documents.digital_signature ds ON ds.document_version_id = dv.version_id
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
CREATE OR REPLACE VIEW authz.vw_officer_accessible_cases AS
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
FROM authz.officer_case_assignment oca
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
