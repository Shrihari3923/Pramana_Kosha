# Police DMS — PostgreSQL Database

**Secure Digital Document Management System for Legal and Investigation Documents**
*SIH Project — Police-Station-Centric Architecture*

---

## Quick Start

```bash
# 1. Create the database
createdb -U postgres police_dms

# 2. Import the complete schema + seed data (single command)
psql -U postgres -d police_dms -f police_dms.sql

# 3. Verify import
psql -U postgres -d police_dms -c "\dn"        # list schemas
psql -U postgres -d police_dms -c "SELECT case_number, case_status_code FROM case_mgmt.case;"
```

Or using pgAdmin: open Query Tool → load `police_dms.sql` → Execute.

---

## File Structure

```
database/
├── police_dms.sql               ← MASTER FILE (import this)
├── rollback.sql                 ← Development teardown (NEVER on production)
│
├── schema/                      ← Individual schema files (in order)
│   ├── 001_extensions.sql       ← pgcrypto, uuid-ossp, pg_trgm, btree_gist
│   ├── 002_reference.sql        ← 25 lookup/reference tables
│   ├── 003_organisation.sql     ← Org units, police stations, FSLs, courts
│   ├── 004_identity.sql         ← Officers, persons, postings
│   ├── 005_authorization.sql    ← Roles, permissions, case access control
│   ├── 006_case_management.sql  ← Cases, FIRs, case transfers
│   ├── 007_investigation.sql    ← Investigation, case diary, tasks, timeline
│   ├── 008_evidence.sql         ← Evidence + evidentiary relationship graph
│   ├── 009_custody.sql          ← Chain of custody (separate graph)
│   ├── 010_forensic.sql         ← FSL requests, examinations, reports
│   ├── 011_documents.sql        ← Documents, versions, signatures, links
│   ├── 012_integrity.sql        ← Hash verification, document passport, alerts
│   ├── 013_audit.sql            ← Tamper-evident SHA-256 hash-chained audit log
│   ├── 014_workflow.sql         ← Approvals, notifications, deadlines
│   └── 015_integration.sql      ← CCTNS, ICJS, eSakshya, NCRB references
│
├── functions/
│   └── 002_functions_triggers.sql  ← All PL/pgSQL functions + triggers
│
├── views/
│   └── 001_views.sql            ← 16 API-ready views
│
├── seed/
│   └── 003_seed_data.sql        ← SIH demo data (fictional)
│
├── migrations/
│   ├── 001_initial_schema.sql   ← Schema only
│   ├── 002_functions_triggers_views.sql
│   └── 003_seed_data.sql
│
└── backend/
    ├── db.js                    ← Node.js connection pool
    ├── queries.js               ← 20 example API queries
    └── .env.example
```

---

## Architecture Principles

| Principle | Implementation |
|-----------|---------------|
| Police Station is smallest unit | `organisation.police_station` linked to flexible `organisation_unit` hierarchy |
| Officer UUID is immutable | `identity.officer.officer_id` — never changes on transfer |
| Posting is historical | `identity.officer_posting` with partial unique index for current posting |
| Rank ≠ Designation ≠ Dept Role ≠ Case Role | Four separate tables in `reference` schema |
| Two separate evidence graphs | Graph 1: `evidence.evidence_relationship`; Graph 2: `custody.evidence_custody_event` |
| Documents have immutable versions | `documents.document_version` — FINAL status blocked from modification by trigger |
| Audit is tamper-evident | SHA-256 hash chain: `hash = digest(prev_hash + event_data)` |
| Access is context-aware | `authorization.check_officer_case_access()` checks officer + station + case role |
| No hard-coded hierarchies | `reference.unit_type` table — any Indian state structure supported |
| External systems are references | CCTNS/ICJS/eSakshya store IDs only — no invented schemas |

---

## Schemas (14 total)

| Schema | Purpose |
|--------|---------|
| `reference` | Lookup tables: ranks, roles, types, statuses |
| `organisation` | Org units, police stations, jurisdictions, FSLs, courts |
| `identity` | Officers, persons, postings, sessions |
| `authorization` | System roles, case roles, permissions, case assignments |
| `case_mgmt` | Cases, FIRs, events, transfers |
| `investigation` | Diary, tasks, timeline, scene of crime |
| `evidence` | Evidence items, relationship graph, digital evidence |
| `custody` | Chain of custody events (append-only) |
| `forensic` | FSL requests, examinations, results, reports |
| `documents` | Documents, versions, signatures, junction tables |
| `integrity` | Hash records, verification events, document passport |
| `audit` | Hash-chained audit events, security alerts |
| `workflow` | Approval workflows, notifications, deadlines |
| `integration` | External system reference tables |

---

## Key Functions

```sql
-- Generate human-readable case number
SELECT case_mgmt.generate_case_number('station-uuid'::uuid);
-- → CASE-KA-BLR-CEN-2026-00000001

-- Create evidence relationship (with validation)
SELECT evidence.create_evidence_relationship(
    case_id, source_id, target_id, 'DERIVED_FROM', officer_id, 1.0, 'justification'
);

-- Recursively traverse evidence lineage (upstream)
SELECT * FROM evidence.get_evidence_lineage('evidence-uuid');

-- Full custody chain
SELECT * FROM custody.get_evidence_custody_chain('evidence-uuid');

-- Finalize a document version (creates integrity record + QR passport)
SELECT documents.finalize_document_version('version-uuid', 'officer-uuid');

-- Verify document hash (detects tampering)
SELECT * FROM documents.verify_document_version(
    'version-uuid', 'sha256-hash-to-check', 'officer-uuid'
);

-- Create chained audit event
SELECT audit.create_audit_event(
    'DOCUMENT_DOWNLOAD', officer_id, station_id, case_id,
    'DOCUMENT', document_id, 'DOC-REF', 'SUCCESS'
);

-- Verify audit chain integrity (returns broken rows)
SELECT * FROM audit.verify_audit_chain('case-uuid-as-chain-id');
-- Returns empty = intact. Returns rows = broken links detected.

-- Check officer access to a resource
SELECT authorization.check_officer_case_access(
    'officer-uuid', 'case-uuid', 'DOCUMENT_DOWNLOAD'
);

-- Get all cases accessible to an officer
SELECT * FROM authorization.get_officer_accessible_cases('officer-uuid');
```

---

## Key Views

| View | Use |
|------|-----|
| `identity.vw_officer_current_posting` | Current posting, rank, station for all active officers |
| `case_mgmt.vw_case_summary` | Case with evidence/document/person counts |
| `case_mgmt.vw_case_officers` | All officers assigned to a case |
| `case_mgmt.vw_case_evidence` | All evidence items for a case |
| `case_mgmt.vw_case_fir` | FIR with Zero FIR lineage |
| `custody.vw_evidence_custody` | Flat custody chain |
| `documents.vw_document_versions` | All versions with signature + integrity status |
| `documents.vw_document_integrity` | Latest version + `integrity_summary` field |
| `investigation.vw_case_timeline` | Chronological case events |
| `audit.vw_audit_summary` | Audit events with chain status |
| `evidence.vw_evidence_lineage` | Direct evidence relationships |
| `organisation.vw_station_officers` | Who is currently posted at each station |
| `identity.vw_officer_posting_history` | Complete posting history per officer |

---

## Demo Scenario (Seed Data)

The seed data models this complete lifecycle:

```
Women PS (Zero FIR) → Transfer → Central PS Bengaluru
                                        │
                              CASE-KA-BLR-CEN-2026-00000001
                                        │
                              SI Arjun Rao (PRIMARY_IO)
                                        │
                              FIR/001/2026 Registered
                                        │
                              E001: Samsung Galaxy A52 Seized
                                        │
                         ┌──────────────┴──────────────┐
                    Chain of Custody              Evidence Graph
                   (Graph 2 — custody)          (Graph 1 — relations)
                         │                            │
                  IO → Malkhana               E002 DERIVED_FROM E001
                  → FSL → Examiner            E003 EXTRACTED_FROM E002
                  → Malkhana                  E004 DERIVED_FROM E003
                                              E005 REPORTS_ON E002
                                        │
                              FSL Report Received
                                        │
                              FIR PDF: v1 (DRAFT) → v2 (FINAL)
                              SHA-256 stored → Signed by SHO
                              Document Passport issued (QR-ready)
                              Audit chain: 6 events, hash-linked
```

**Demo officers:**
- `arjun.rao` — SI, PRIMARY_IO on Case 1
- `suresh.patil` — Inspector / SHO, CASE_OWNER
- `vikram.singh` — Head Constable, EVIDENCE_CUSTODIAN (Malkhana)
- `meena.krishnan` — SI, DIGITAL_EVIDENCE_OFFICER (Cyber PS)
- `rajesh.kumar` — DCP, SYS_ADMIN

Password for all demo accounts: `Demo@1234!` (bcrypt hash stored — replace before any real use)

---

## Demo Queries

```sql
-- 1. Officers at Central PS
SELECT officer_name, rank_name, designation_name
FROM organisation.vw_station_officers
WHERE station_code = 'BLR-CEN';

-- 2. Cases at Central PS
SELECT case_number, case_type, case_status, primary_io_name
FROM organisation.vw_station_cases
WHERE station_code = 'BLR-CEN';

-- 3. Arjun Rao's full posting history
SELECT posting_start_date, posting_end_date, station_name, rank_name, is_current
FROM identity.vw_officer_posting_history
WHERE officer_id = '40000000-0000-0000-0000-000000000002';

-- 4. Complete Case 1 team
SELECT officer_name, rank_name, case_role_name, is_active
FROM case_mgmt.vw_case_officers
WHERE case_id = '60000000-0000-0000-0000-000000000001';

-- 5. Case 1 evidence graph
SELECT source_number, rel_type_code, target_number, confidence
FROM evidence.vw_evidence_lineage
WHERE case_id = '60000000-0000-0000-0000-000000000001';

-- 6. E001 recursive lineage (all ancestors)
SELECT * FROM evidence.get_evidence_lineage('90000000-0000-0000-0000-000000000001');

-- 7. E001 descendants (everything derived from it)
SELECT * FROM evidence.get_evidence_descendants('90000000-0000-0000-0000-000000000001');

-- 8. E001 custody chain
SELECT * FROM custody.get_evidence_custody_chain('90000000-0000-0000-0000-000000000001');

-- 9. Document integrity dashboard
SELECT document_ref, title, version_status, integrity_summary, passport_code
FROM documents.vw_document_integrity
WHERE case_id = '60000000-0000-0000-0000-000000000001';

-- 10. Verify audit chain for Case 1 (should return empty = intact)
SELECT * FROM audit.verify_audit_chain('60000000-0000-0000-0000-000000000001')
WHERE NOT is_valid;

-- 11. Simulate hash mismatch detection
SELECT * FROM documents.verify_document_version(
    'B0000000-0000-0000-0002-000000000001',  -- version_id
    'TAMPERED_HASH_VALUE_THAT_DOES_NOT_MATCH', -- wrong hash
    '40000000-0000-0000-0000-000000000002',   -- officer_id
    NULL, '192.168.1.200'::inet
);
-- → result = 'HASH_MISMATCH', integrity alert raised

-- 12. Case 1 full timeline
SELECT event_timestamp, event_category, title, officer_name
FROM investigation.vw_case_timeline
WHERE case_id = '60000000-0000-0000-0000-000000000001'
ORDER BY event_timestamp;

-- 13. SI Arjun Rao accessible cases
SELECT * FROM authorization.get_officer_accessible_cases('40000000-0000-0000-0000-000000000002');

-- 14. Check if Vikram Singh (Malkhana) can download documents
SELECT authorization.check_officer_case_access(
    '40000000-0000-0000-0000-000000000006',  -- Vikram Singh
    '60000000-0000-0000-0000-000000000001',  -- Case 1
    'DOCUMENT_DOWNLOAD'
);
-- → false (Evidence Custodian role does not have DOCUMENT_DOWNLOAD)

-- 15. Zero FIR lineage for Case 3
SELECT fir_number, fir_type, station_name,
       parent_fir_number, parent_station_name
FROM case_mgmt.vw_case_fir
WHERE case_id = '60000000-0000-0000-0000-000000000003';
```

---

## PostgreSQL Requirements

- PostgreSQL 15 or higher
- Extensions: `pgcrypto`, `uuid-ossp`, `pg_trgm`, `btree_gist` (all included in standard PostgreSQL)
- PostGIS is **optional** — geometry fields use `TEXT` (WKT) fallback by default

---

## Next Implementation Steps

1. **Replace password hash placeholders** in seed data with real bcrypt hashes before any testing
2. **Configure MinIO / S3** object storage and update `storage_provider` / `storage_path` values in document uploads
3. **Wire backend API routes** to the query functions in `backend/queries.js`
4. **Enable RLS** in production by running the commented-out RLS block in `005_authorization.sql`
5. **Hash generation** — the backend must compute SHA-256 of uploaded files before inserting `document_version` rows; the database stores and verifies, not generates
6. **Audit integration** — every API action must call `audit.create_audit_event()` with the officer's session context
7. **Schedule audit chain verification** — run `audit.verify_audit_chain()` nightly and alert on `chain_status = 'BROKEN'`
8. **Replace demo UUIDs** in seed data with `gen_random_uuid()` calls in production seeding
9. **Set up CCTNS sync jobs** that populate `integration.external_reference` and log to `integration.sync_log`
10. **Document retention policy** — configure a job to enforce `reference.retention_category` rules on archived documents

---

*All data in seed files is fictional. No real police officer information is used.*
