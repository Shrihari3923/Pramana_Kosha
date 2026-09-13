// =============================================================================
// queries.js — Example API query implementations for Police DMS
// =============================================================================

'use strict';

const { query, transaction, setOfficerContext } = require('./db');

// ---------------------------------------------------------------------------
// Q1: Get all officers currently posted at a police station
// Endpoint: GET /api/police-stations/:stationId/officers
// ---------------------------------------------------------------------------
async function getStationOfficers(stationId) {
  const sql = `
    SELECT
      officer_id, identity_code, officer_name,
      rank_name, rank_code, rank_level,
      designation_name, posting_start_date, posting_type
    FROM organisation.vw_station_officers
    WHERE station_id = $1
    ORDER BY rank_level DESC, officer_name ASC
  `;
  const result = await query(sql, [stationId]);
  return result.rows;
}

// ---------------------------------------------------------------------------
// Q2: Get all cases handled by a police station
// Endpoint: GET /api/police-stations/:stationId/cases
// ---------------------------------------------------------------------------
async function getStationCases(stationId) {
  const sql = `
    SELECT
      case_id, case_number, case_status, case_type,
      priority, opened_at, closed_at,
      is_zero_fir, primary_io_name, last_activity_at
    FROM organisation.vw_station_cases
    WHERE station_id = $1
    ORDER BY opened_at DESC
  `;
  const result = await query(sql, [stationId]);
  return result.rows;
}

// ---------------------------------------------------------------------------
// Q3: Get complete officer posting history
// Endpoint: GET /api/officers/:officerId/postings
// ---------------------------------------------------------------------------
async function getOfficerPostingHistory(officerId) {
  const sql = `
    SELECT
      posting_id, posting_start_date, posting_end_date,
      is_current, posting_type,
      rank_name, rank_code, designation_name,
      station_name, state_code, district_name,
      unit_name, unit_type_code, appointment_order_no,
      reporting_officer_name
    FROM identity.vw_officer_posting_history
    WHERE officer_id = $1
    ORDER BY posting_start_date DESC
  `;
  const result = await query(sql, [officerId]);
  return result.rows;
}

// ---------------------------------------------------------------------------
// Q4: Get complete case team (all officers assigned)
// Endpoint: GET /api/cases/:caseId/officers
// ---------------------------------------------------------------------------
async function getCaseTeam(caseId) {
  const sql = `
    SELECT
      assignment_id, officer_id, officer_name,
      identity_code, rank_name, rank_code,
      designation_name, current_station,
      case_role_code, case_role_name,
      is_active, start_date, end_date,
      assigned_at, assigned_by_name, scope, reason
    FROM case_mgmt.vw_case_officers
    WHERE case_id = $1
    ORDER BY is_active DESC, assigned_at ASC
  `;
  const result = await query(sql, [caseId]);
  return result.rows;
}

// ---------------------------------------------------------------------------
// Q5: Check what an officer can access in a case
// Endpoint: GET /api/cases/:caseId/access?officerId=...
// ---------------------------------------------------------------------------
async function checkOfficerCaseAccess(officerId, caseId, permissionCode) {
  const sql = `
    SELECT authorization.check_officer_case_access($1, $2, $3) AS has_access
  `;
  const result = await query(sql, [officerId, caseId, permissionCode]);
  return result.rows[0].has_access;
}

async function getOfficerCasePermissions(officerId, caseId) {
  const sql = `
    SELECT DISTINCT perm.permission_code, perm.description, perm.resource_type, perm.action
    FROM authorization.officer_case_assignment oca
    JOIN authorization.case_role_permission crp ON crp.case_role_id = oca.case_role_id
    JOIN reference.permission perm ON perm.permission_id = crp.permission_id
    WHERE oca.officer_id = $1
      AND oca.case_id    = $2
      AND oca.is_active  = TRUE
      AND crp.is_active  = TRUE
    ORDER BY perm.resource_type, perm.action
  `;
  const result = await query(sql, [officerId, caseId]);
  return result.rows;
}

// ---------------------------------------------------------------------------
// Q6: Get all evidence connected to a case
// Endpoint: GET /api/cases/:caseId/evidence
// ---------------------------------------------------------------------------
async function getCaseEvidence(caseId) {
  const sql = `
    SELECT
      evidence_id, evidence_number, evidence_type_code, evidence_type,
      is_digital, description, source, discovery_method,
      collection_timestamp, collection_location,
      current_status_code, status_label, classification_code,
      seal_number, integrity_status, sha256_hash,
      quantity, unit_of_measure, make, model, serial_number,
      collected_by_name, collected_by_rank,
      current_custodian, has_digital_record,
      acquisition_method, digital_hash, created_at
    FROM case_mgmt.vw_case_evidence
    WHERE case_id = $1
    ORDER BY evidence_number ASC
  `;
  const result = await query(sql, [caseId]);
  return result.rows;
}

// ---------------------------------------------------------------------------
// Q7: Traverse evidence relationships recursively (full graph)
// Endpoint: GET /api/cases/:caseId/evidence/graph
// ---------------------------------------------------------------------------
async function getCaseEvidenceGraph(caseId) {
  const sql = `SELECT * FROM evidence.get_case_evidence_graph($1)`;
  const result = await query(sql, [caseId]);
  return result.rows;
}

// ---------------------------------------------------------------------------
// Q8: Find parent/source evidence of an item (upstream lineage)
// Endpoint: GET /api/evidence/:evidenceId/lineage
// ---------------------------------------------------------------------------
async function getEvidenceLineage(evidenceId) {
  const sql = `SELECT * FROM evidence.get_evidence_lineage($1)`;
  const result = await query(sql, [evidenceId]);
  return result.rows;
}

// ---------------------------------------------------------------------------
// Q9: Find all downstream evidence derived from an item
// Endpoint: GET /api/evidence/:evidenceId/descendants
// ---------------------------------------------------------------------------
async function getEvidenceDescendants(evidenceId) {
  const sql = `SELECT * FROM evidence.get_evidence_descendants($1)`;
  const result = await query(sql, [evidenceId]);
  return result.rows;
}

// ---------------------------------------------------------------------------
// Q10: Get complete chain of custody for an evidence item
// Endpoint: GET /api/evidence/:evidenceId/custody
// ---------------------------------------------------------------------------
async function getEvidenceCustodyChain(evidenceId) {
  const sql = `SELECT * FROM custody.get_evidence_custody_chain($1)`;
  const result = await query(sql, [evidenceId]);
  return result.rows;
}

// ---------------------------------------------------------------------------
// Q11: Get every document associated with an evidence item
// Endpoint: GET /api/evidence/:evidenceId/documents
// ---------------------------------------------------------------------------
async function getEvidenceDocuments(evidenceId) {
  const sql = `
    SELECT
      d.document_id, d.document_ref, d.title,
      dt.type_name AS document_type,
      d.classification_code,
      dv.version_number AS current_version,
      dv.status_code AS version_status,
      dv.sha256_hash, dv.finalized_at,
      ed.link_type
    FROM evidence.evidence_document ed
    JOIN documents.document d ON d.document_id = ed.document_id
    JOIN reference.document_type dt ON dt.document_type_id = d.document_type_id
    LEFT JOIN documents.document_version dv ON dv.version_id = d.current_version_id
    WHERE ed.evidence_id = $1
      AND d.is_active = TRUE
    ORDER BY d.created_at DESC
  `;
  const result = await query(sql, [evidenceId]);
  return result.rows;
}

// ---------------------------------------------------------------------------
// Q12: Get every version of a document
// Endpoint: GET /api/documents/:documentId/versions
// ---------------------------------------------------------------------------
async function getDocumentVersions(documentId) {
  const sql = `
    SELECT
      version_id, document_id, document_ref, title,
      document_type, version_number, version_label,
      status_code, status_label, is_terminal,
      file_name, mime_type, file_size_bytes,
      sha256_hash, hash_algorithm,
      storage_provider, storage_path, object_key,
      change_reason,
      created_by_name, created_at,
      finalized_at, finalized_by_name,
      signature_id, signer_name, signed_at, signature_status,
      integrity_id, verification_status, last_verified_at,
      classification_code, legal_hold
    FROM documents.vw_document_versions
    WHERE document_id = $1
    ORDER BY version_number ASC
  `;
  const result = await query(sql, [documentId]);
  return result.rows;
}

// ---------------------------------------------------------------------------
// Q13: Verify whether the latest document version is finalized + check integrity
// Endpoint: POST /api/documents/:documentId/verify
// Body: { computedHash, officerId }
// ---------------------------------------------------------------------------
async function verifyDocumentIntegrity(documentId, computedHash, officerId, ipAddress) {
  // First get the current version id
  const docResult = await query(
    `SELECT current_version_id FROM documents.document WHERE document_id = $1`,
    [documentId]
  );
  if (!docResult.rows.length || !docResult.rows[0].current_version_id) {
    throw new Error('Document or current version not found');
  }
  const versionId = docResult.rows[0].current_version_id;

  const sql = `
    SELECT * FROM documents.verify_document_version($1, $2, $3, NULL, $4::inet)
  `;
  const result = await query(sql, [versionId, computedHash, officerId, ipAddress]);
  return result.rows[0];
}

// ---------------------------------------------------------------------------
// Q14: Show complete case timeline
// Endpoint: GET /api/cases/:caseId/timeline
// ---------------------------------------------------------------------------
async function getCaseTimeline(caseId) {
  const sql = `
    SELECT
      timeline_id, event_timestamp, event_category,
      title, description, officer_name,
      source_table, source_id
    FROM investigation.vw_case_timeline
    WHERE case_id = $1
    ORDER BY event_timestamp ASC
  `;
  const result = await query(sql, [caseId]);
  return result.rows;
}

// ---------------------------------------------------------------------------
// Q15: All actions performed by an officer on a case
// Endpoint: GET /api/cases/:caseId/audit?officerId=...
// ---------------------------------------------------------------------------
async function getCaseAuditByOfficer(caseId, officerId) {
  const sql = `
    SELECT
      audit_id, action_code, action_label, severity,
      event_timestamp, officer_name, officer_rank,
      resource_type, resource_ref, result,
      failure_reason, ip_address, chain_status
    FROM audit.vw_audit_summary
    WHERE case_id   = $1
      AND officer_id = $2
    ORDER BY event_timestamp DESC
  `;
  const result = await query(sql, [caseId, officerId]);
  return result.rows;
}

// ---------------------------------------------------------------------------
// Q16: Detect possible audit-chain tampering
// Endpoint: GET /api/cases/:caseId/audit/verify
// ---------------------------------------------------------------------------
async function verifyAuditChain(chainId) {
  const sql = `SELECT * FROM audit.verify_audit_chain($1)`;
  const result = await query(sql, [chainId]);
  const broken = result.rows.filter(r => !r.is_valid);
  return {
    total_events:  result.rows.length,
    broken_events: broken.length,
    chain_intact:  broken.length === 0,
    broken_details: broken,
    all_events:    result.rows,
  };
}

// ---------------------------------------------------------------------------
// Q17: Find all evidence currently held by a particular custodian
// Endpoint: GET /api/custodians/:custodianId/evidence
// ---------------------------------------------------------------------------
async function getEvidenceByCurrentCustodian(custodianId) {
  const sql = `
    SELECT
      e.evidence_id, e.evidence_number, e.description,
      et.type_name AS evidence_type,
      e.current_status_code, e.integrity_status,
      e.seal_number, e.case_id, c.case_number,
      last_event.event_timestamp AS received_at
    FROM evidence.evidence e
    JOIN reference.evidence_type et ON et.evidence_type_id = e.evidence_type_id
    JOIN case_mgmt.case c ON c.case_id = e.case_id
    JOIN LATERAL (
      SELECT ece.event_timestamp
      FROM custody.evidence_custody_event ece
      WHERE ece.evidence_id      = e.evidence_id
        AND ece.to_custodian_id  = $1
      ORDER BY ece.event_sequence DESC
      LIMIT 1
    ) last_event ON TRUE
    -- Only evidence where this custodian is the LAST receiver
    WHERE NOT EXISTS (
      SELECT 1 FROM custody.evidence_custody_event ece2
      WHERE ece2.evidence_id     = e.evidence_id
        AND ece2.event_sequence  > (
          SELECT MAX(event_sequence) FROM custody.evidence_custody_event
          WHERE evidence_id = e.evidence_id AND to_custodian_id = $1
        )
    )
    AND e.is_active = TRUE
    ORDER BY last_event.event_timestamp DESC
  `;
  const result = await query(sql, [custodianId]);
  return result.rows;
}

// ---------------------------------------------------------------------------
// Q18: Find all cases where a particular officer is PRIMARY_IO
// Endpoint: GET /api/officers/:officerId/cases
// ---------------------------------------------------------------------------
async function getOfficerCases(officerId) {
  const sql = `
    SELECT
      case_id, case_number, case_status, case_type,
      case_role_code, case_role_name,
      station_name, opened_at, is_active
    FROM authorization.vw_officer_accessible_cases
    WHERE officer_id = $1
    ORDER BY opened_at DESC
  `;
  const result = await query(sql, [officerId]);
  return result.rows;
}

// ---------------------------------------------------------------------------
// Q19: Find all forensic reports associated with a case
// Endpoint: GET /api/cases/:caseId/forensics
// ---------------------------------------------------------------------------
async function getCaseForensicReports(caseId) {
  const sql = `
    SELECT
      fr.report_id, fr.report_number, fr.report_date,
      fr.examiner_name, fr.examiner_designation,
      fl.lab_name, fl.lab_code,
      fr.summary, fr.conclusions, fr.limitations,
      fr.report_status, fr.received_at,
      req.request_number, req.examination_required,
      fd.discipline_name,
      fr.is_supplementary
    FROM forensic.forensic_report fr
    JOIN forensic.forensic_request req ON req.request_id = fr.request_id
    JOIN organisation.forensic_laboratory fl ON fl.lab_id = fr.lab_id
    JOIN reference.forensic_discipline fd ON fd.discipline_id = req.discipline_id
    WHERE fr.case_id = $1
    ORDER BY fr.report_date DESC
  `;
  const result = await query(sql, [caseId]);
  return result.rows;
}

// ---------------------------------------------------------------------------
// Q20: Case Digital Twin — full structured JSON of a case
// Endpoint: GET /api/cases/:caseId/digital-twin
// ---------------------------------------------------------------------------
async function getCaseDigitalTwin(caseId) {
  // Run all sub-queries in parallel
  const [
    caseInfo,
    firs,
    officers,
    persons,
    evidenceItems,
    evidenceGraph,
    documents,
    forensics,
    timeline,
    auditEvents,
  ] = await Promise.all([
    query(`SELECT * FROM case_mgmt.vw_case_summary WHERE case_id = $1`, [caseId]),
    query(`SELECT * FROM case_mgmt.vw_case_fir WHERE case_id = $1 ORDER BY registered_at`, [caseId]),
    getCaseTeam(caseId),
    query(
      `SELECT cp.case_person_id, p.full_name, p.phone_primary, cp.role_type_code, cp.is_protected
       FROM identity.case_person cp
       JOIN identity.person p ON p.person_id = cp.person_id
       WHERE cp.case_id = $1 AND cp.is_active = TRUE`, [caseId]
    ),
    getCaseEvidence(caseId),
    getCaseEvidenceGraph(caseId),
    query(
      `SELECT document_id, document_ref, title, document_type,
              classification_code, current_version_no, integrity_summary
       FROM documents.vw_document_integrity WHERE case_id = $1`, [caseId]
    ),
    getCaseForensicReports(caseId),
    getCaseTimeline(caseId),
    query(
      `SELECT action_code, action_label, event_timestamp, officer_name, result
       FROM audit.vw_audit_summary WHERE case_id = $1
       ORDER BY event_timestamp DESC LIMIT 50`, [caseId]
    ),
  ]);

  return {
    case:         caseInfo.rows[0] || null,
    firs:         firs.rows,
    officers:     officers,
    persons:      persons.rows,
    evidence:     evidenceItems,
    evidenceGraph: evidenceGraph,
    documents:    documents.rows,
    forensics:    forensics,
    timeline:     timeline,
    recentAudit:  auditEvents.rows,
  };
}

module.exports = {
  getStationOfficers,
  getStationCases,
  getOfficerPostingHistory,
  getCaseTeam,
  checkOfficerCaseAccess,
  getOfficerCasePermissions,
  getCaseEvidence,
  getCaseEvidenceGraph,
  getEvidenceLineage,
  getEvidenceDescendants,
  getEvidenceCustodyChain,
  getEvidenceDocuments,
  getDocumentVersions,
  verifyDocumentIntegrity,
  getCaseTimeline,
  getCaseAuditByOfficer,
  verifyAuditChain,
  getEvidenceByCurrentCustodian,
  getOfficerCases,
  getCaseForensicReports,
  getCaseDigitalTwin,
};
