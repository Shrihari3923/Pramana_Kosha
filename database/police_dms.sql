-- police_dms.sql -- final Fri Sep 11 16:37:46 IST 2026
-- =============================================================================
-- 001_extensions.sql
-- PostgreSQL Extensions required by the Police DMS
-- =============================================================================

-- UUID generation
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Additional UUID functions (gen_random_uuid etc.)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Trigram indexing for full-text search on names/descriptions
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Optional: PostGIS for geographic boundaries. 
-- Uncomment ONLY if PostGIS is installed on your PostgreSQL server.
-- The rest of the schema uses geometry TEXT columns as a safe fallback.
-- CREATE EXTENSION IF NOT EXISTS "postgis";

-- btree_gist — needed for EXCLUDE constraints on ranges (e.g. non-overlapping postings)
CREATE EXTENSION IF NOT EXISTS "btree_gist";

-- =============================================================================
-- SCHEMAS
-- Organise the database into logical namespaces.
-- Each schema maps to one domain area.
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS reference;       -- lookup / enumeration tables
CREATE SCHEMA IF NOT EXISTS organisation;    -- org units, police stations, jurisdictions
CREATE SCHEMA IF NOT EXISTS identity;        -- officers, persons, postings
CREATE SCHEMA IF NOT EXISTS authz;   -- roles, permissions, policies
CREATE SCHEMA IF NOT EXISTS case_mgmt;       -- cases, FIRs, case events, transfers
CREATE SCHEMA IF NOT EXISTS investigation;   -- investigation tasks, case diary
CREATE SCHEMA IF NOT EXISTS evidence;        -- evidence, relationships, digital evidence
CREATE SCHEMA IF NOT EXISTS custody;         -- chain of custody events
CREATE SCHEMA IF NOT EXISTS forensic;        -- FSL, forensic requests, reports
CREATE SCHEMA IF NOT EXISTS documents;       -- documents, versions, signatures
CREATE SCHEMA IF NOT EXISTS integrity;       -- verification records, integrity alerts
CREATE SCHEMA IF NOT EXISTS audit;           -- audit events, audit chain
CREATE SCHEMA IF NOT EXISTS workflow;        -- workflow states, notifications
CREATE SCHEMA IF NOT EXISTS integration;     -- CCTNS, ICJS, eSakshya, court references

COMMENT ON SCHEMA reference    IS 'Lookup and reference tables (ranks, roles, types, statuses)';
COMMENT ON SCHEMA organisation IS 'Organisational units, police stations, jurisdictions';
COMMENT ON SCHEMA identity     IS 'Officer identity, person registry, postings';
COMMENT ON SCHEMA authz IS 'Roles, permissions, case access policies';
COMMENT ON SCHEMA case_mgmt    IS 'Cases, FIRs, case events, transfers';
COMMENT ON SCHEMA investigation IS 'Investigation tasks, case diary, timelines';
COMMENT ON SCHEMA evidence     IS 'Evidence items, relationships, digital evidence';
COMMENT ON SCHEMA custody      IS 'Chain of custody events and transfers';
COMMENT ON SCHEMA forensic     IS 'FSL labs, forensic requests and reports';
COMMENT ON SCHEMA documents    IS 'Documents, versions, digital signatures';
COMMENT ON SCHEMA integrity    IS 'Hash verification, integrity alerts';
COMMENT ON SCHEMA audit        IS 'Tamper-evident audit trail with hash chain';
COMMENT ON SCHEMA workflow     IS 'Workflow states, task tracking, notifications';
COMMENT ON SCHEMA integration  IS 'External system references (CCTNS, ICJS, eSakshya, Court)';
-- =============================================================================
-- 002_reference.sql
-- All reference / lookup tables.
-- These use reference tables (not ENUMs) so that values can evolve without
-- requiring ALTER TYPE operations.  ENUMs are reserved for genuinely stable
-- sets (e.g. gender, boolean-like flags).
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. UNIT TYPES — flexible hierarchy for any Indian state
-- ---------------------------------------------------------------------------
CREATE TABLE reference.unit_type (
    unit_type_code   VARCHAR(40)  PRIMARY KEY,
    label            VARCHAR(100) NOT NULL,
    description      TEXT,
    sort_order       SMALLINT     NOT NULL DEFAULT 0,
    is_active        BOOLEAN      NOT NULL DEFAULT TRUE
);

INSERT INTO reference.unit_type (unit_type_code, label, sort_order) VALUES
('CENTRAL_AGENCY',    'Central Agency / MHA',           10),
('STATE',             'State',                           20),
('STATE_POLICE_HQ',   'State Police Headquarters',       30),
('RANGE',             'Range',                           40),
('ZONE',              'Zone',                            50),
('COMMISSIONERATE',   'Commissionerate',                 60),
('DISTRICT',          'District',                        70),
('DIVISION',          'Division',                        80),
('SUBDIVISION',       'Sub-Division / SDPO Circle',      90),
('CIRCLE',            'Circle',                         100),
('POLICE_STATION',    'Police Station',                 110),
('OUTPOST',           'Outpost',                        120),
('CHOWKI',            'Chowki',                         130),
('BEAT',              'Beat',                           140),
('SPECIAL_UNIT',      'Special Unit',                   150),
('CYBER_CELL',        'Cyber Crime Cell',               160),
('CRIME_BRANCH',      'Crime Branch',                   170),
('FSL',               'Forensic Science Laboratory',    180),
('PROSECUTION',       'Prosecution / PP Office',        190),
('COURT',             'Court',                          200),
('OTHER',             'Other',                          999);

-- ---------------------------------------------------------------------------
-- 2. STATION TYPES
-- ---------------------------------------------------------------------------
CREATE TABLE reference.station_type (
    station_type_code  VARCHAR(40)  PRIMARY KEY,
    label              VARCHAR(100) NOT NULL,
    is_active          BOOLEAN      NOT NULL DEFAULT TRUE
);

INSERT INTO reference.station_type (station_type_code, label) VALUES
('POLICE_STATION',    'Police Station'),
('WOMEN_PS',          'Women Police Station'),
('CYBER_PS',          'Cyber Crime Police Station'),
('TRAFFIC_PS',        'Traffic Police Station'),
('RAILWAY_PS',        'Railway Police Station'),
('OUTPOST',           'Outpost'),
('CHOWKI',            'Chowki'),
('BEAT_POST',         'Beat Post'),
('SPECIAL_UNIT',      'Special Unit'),
('OTHER',             'Other');

-- ---------------------------------------------------------------------------
-- 3. POLICE RANKS
-- ---------------------------------------------------------------------------
CREATE TABLE reference.rank (
    rank_id       UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    rank_code     VARCHAR(40)  NOT NULL UNIQUE,
    rank_name     VARCHAR(100) NOT NULL,
    rank_level    SMALLINT     NOT NULL,   -- higher = more senior
    cadre         VARCHAR(40),             -- IPS, SPS, etc.
    is_gazetted   BOOLEAN      NOT NULL DEFAULT FALSE,
    is_active     BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now()
);

INSERT INTO reference.rank (rank_code, rank_name, rank_level, cadre, is_gazetted) VALUES
('DGP',          'Director General of Police',          100, 'IPS',  TRUE),
('ADGP',         'Additional Director General of Police', 90, 'IPS',  TRUE),
('IG',           'Inspector General of Police',          80, 'IPS',  TRUE),
('DIG',          'Deputy Inspector General of Police',   70, 'IPS',  TRUE),
('SSP',          'Senior Superintendent of Police',      65, 'SPS',  TRUE),
('SP',           'Superintendent of Police',             60, 'SPS',  TRUE),
('ADDITIONAL_SP','Additional Superintendent of Police',  58, 'SPS',  TRUE),
('ASP',          'Assistant Superintendent of Police',   55, 'SPS',  TRUE),
('COMMISSIONER', 'Commissioner of Police',               85, 'IPS',  TRUE),
('JT_COMMISSIONER','Joint Commissioner of Police',       75, 'IPS',  TRUE),
('ADDL_COMMISSIONER','Additional Commissioner of Police',72,'IPS',   TRUE),
('DCP',          'Deputy Commissioner of Police',        62, 'SPS',  TRUE),
('ACP',          'Assistant Commissioner of Police',     57, 'SPS',  TRUE),
('DSP',          'Deputy Superintendent of Police',      55, 'SPS',  TRUE),
('INSPECTOR',    'Inspector of Police',                  40, 'STATE', FALSE),
('SUB_INSPECTOR','Sub-Inspector of Police',              30, 'STATE', FALSE),
('ASI',          'Assistant Sub-Inspector of Police',    25, 'STATE', FALSE),
('HEAD_CONSTABLE','Head Constable',                      20, 'STATE', FALSE),
('CONSTABLE',    'Constable',                            10, 'STATE', FALSE),
('CIVILIAN',     'Civilian Staff',                        5, NULL,    FALSE);

-- ---------------------------------------------------------------------------
-- 4. DESIGNATIONS — functional position at a station or unit
-- ---------------------------------------------------------------------------
CREATE TABLE reference.designation (
    designation_id    UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    designation_code  VARCHAR(60) NOT NULL UNIQUE,
    designation_name  VARCHAR(120) NOT NULL,
    typical_rank_code VARCHAR(40),           -- guidance only, NOT enforced as FK here
    is_active         BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO reference.designation (designation_code, designation_name, typical_rank_code) VALUES
('SHO',                   'Station House Officer',                  'INSPECTOR'),
('DUTY_OFFICER',          'Duty Officer',                           'SUB_INSPECTOR'),
('STATION_WRITER',        'Station Writer',                         'ASI'),
('MALKHANA_INCHARGE',     'Malkhana In-Charge',                     'ASI'),
('LOCKUP_INCHARGE',       'Lockup In-Charge',                       'HEAD_CONSTABLE'),
('CYBER_LIAISON',         'Cyber Liaison Officer',                  'SUB_INSPECTOR'),
('CRIME_RECORDS_STAFF',   'Crime Records Staff',                    'HEAD_CONSTABLE'),
('WOMEN_HELP_DESK',       'Women Help Desk Officer',                'SUB_INSPECTOR'),
('IO',                    'Investigating Officer',                   'SUB_INSPECTOR'),
('BEAT_OFFICER',          'Beat Officer',                           'CONSTABLE'),
('SDPO',                  'Sub-Divisional Police Officer',          'DSP'),
('CIRCLE_INSPECTOR',      'Circle Inspector',                       'INSPECTOR'),
('DCP_INCHARGE',          'DCP In-Charge',                         'DCP'),
('SP_INCHARGE',           'SP In-Charge',                          'SP'),
('FSL_EXAMINER',          'Forensic Examiner',                      'INSPECTOR'),
('PROSECUTOR',            'Public Prosecutor Liaison',              'INSPECTOR'),
('GENERAL',               'General Posting',                        NULL);

-- ---------------------------------------------------------------------------
-- 5. DEPARTMENTAL ROLES — functional permissions within the department
-- ---------------------------------------------------------------------------
CREATE TABLE reference.departmental_role (
    dept_role_id    UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    role_code       VARCHAR(60) NOT NULL UNIQUE,
    role_name       VARCHAR(120) NOT NULL,
    description     TEXT,
    is_active       BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO reference.departmental_role (role_code, role_name) VALUES
('DEPT_ADMIN',             'Departmental Administrator'),
('DEPT_SHO',               'Station House Officer'),
('DEPT_IO',                'Investigating Officer'),
('DEPT_DUTY_OFFICER',      'Duty Officer'),
('DEPT_MALKHANA',          'Malkhana Custodian'),
('DEPT_DIGITAL_EV',        'Digital Evidence Officer'),
('DEPT_FORENSIC_COORD',    'Forensic Coordinator'),
('DEPT_CYBER',             'Cyber Crime Officer'),
('DEPT_RECORDS',           'Records Staff'),
('DEPT_COURT_LIAISON',     'Court Liaison Officer'),
('DEPT_AUDITOR',           'Internal Auditor'),
('DEPT_SUPERVISOR',        'Supervisory Officer'),
('DEPT_READ_ONLY',         'Read-Only Access');

-- ---------------------------------------------------------------------------
-- 6. CASE ROLES — role within a specific case
-- ---------------------------------------------------------------------------
CREATE TABLE reference.case_role (
    case_role_id   UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    role_code      VARCHAR(60) NOT NULL UNIQUE,
    role_name      VARCHAR(120) NOT NULL,
    description    TEXT,
    is_active      BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO reference.case_role (role_code, role_name) VALUES
('PRIMARY_IO',             'Primary Investigating Officer'),
('ASSISTANT_IO',           'Assistant Investigating Officer'),
('SUPERVISING_OFFICER',    'Supervising Officer'),
('CASE_OWNER',             'Case Owner (SHO)'),
('EVIDENCE_CUSTODIAN',     'Evidence Custodian'),
('DIGITAL_EVIDENCE_OFFICER','Digital Evidence Officer'),
('FORENSIC_COORDINATOR',   'Forensic Coordinator'),
('CASE_REVIEWER',          'Case Reviewer'),
('COURT_LIAISON',          'Court Liaison'),
('PROSECUTION_LIAISON',    'Prosecution Liaison'),
('AUDITOR',                'Case Auditor'),
('READ_ONLY',              'Read-Only Access');

-- ---------------------------------------------------------------------------
-- 7. PERMISSIONS
-- ---------------------------------------------------------------------------
CREATE TABLE reference.permission (
    permission_id   UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    permission_code VARCHAR(80) NOT NULL UNIQUE,
    description     TEXT,
    resource_type   VARCHAR(60),
    action          VARCHAR(40),
    is_active       BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO reference.permission (permission_code, description, resource_type, action) VALUES
('CASE_CREATE',                'Create a new case',                     'CASE',      'CREATE'),
('CASE_VIEW',                  'View case details',                     'CASE',      'VIEW'),
('CASE_EDIT',                  'Edit case details',                     'CASE',      'EDIT'),
('CASE_ASSIGN',                'Assign officers to a case',             'CASE',      'ASSIGN'),
('CASE_CLOSE',                 'Close a case',                          'CASE',      'CLOSE'),
('CASE_TRANSFER',              'Transfer a case',                       'CASE',      'TRANSFER'),
('CASE_EXPORT',                'Export case data',                      'CASE',      'EXPORT'),
('FIR_CREATE',                 'Register a FIR',                        'FIR',       'CREATE'),
('FIR_VIEW',                   'View FIR',                              'FIR',       'VIEW'),
('FIR_EDIT',                   'Edit FIR',                              'FIR',       'EDIT'),
('EVIDENCE_CREATE',            'Add evidence to a case',                'EVIDENCE',  'CREATE'),
('EVIDENCE_VIEW',              'View evidence',                         'EVIDENCE',  'VIEW'),
('EVIDENCE_EDIT',              'Edit evidence metadata',                'EVIDENCE',  'EDIT'),
('EVIDENCE_TRANSFER',          'Transfer evidence custody',             'EVIDENCE',  'TRANSFER'),
('EVIDENCE_VERIFY',            'Verify evidence integrity',             'EVIDENCE',  'VERIFY'),
('EVIDENCE_DELETE',            'Soft-delete evidence (restricted)',     'EVIDENCE',  'DELETE'),
('DOCUMENT_UPLOAD',            'Upload a document',                     'DOCUMENT',  'UPLOAD'),
('DOCUMENT_VIEW',              'View a document',                       'DOCUMENT',  'VIEW'),
('DOCUMENT_DOWNLOAD',          'Download a document',                   'DOCUMENT',  'DOWNLOAD'),
('DOCUMENT_SIGN',              'Digitally sign a document',             'DOCUMENT',  'SIGN'),
('DOCUMENT_APPROVE',           'Approve a document version',            'DOCUMENT',  'APPROVE'),
('DOCUMENT_VERSION_CREATE',    'Create a new document version',         'DOCUMENT',  'VERSION'),
('FORENSIC_REQUEST_CREATE',    'Create a forensic request',             'FORENSIC',  'CREATE'),
('FORENSIC_REPORT_VIEW',       'View forensic reports',                 'FORENSIC',  'VIEW'),
('AUDIT_VIEW',                 'View audit logs',                       'AUDIT',     'VIEW'),
('ADMIN_MANAGE_OFFICERS',      'Manage officer accounts',               'ADMIN',     'MANAGE'),
('ADMIN_MANAGE_ROLES',         'Manage roles and permissions',          'ADMIN',     'MANAGE'),
('CUSTODY_VIEW',               'View custody chain',                    'CUSTODY',   'VIEW'),
('CUSTODY_TRANSFER',           'Transfer custody of evidence',          'CUSTODY',   'TRANSFER');

-- ---------------------------------------------------------------------------
-- 8. CASE TYPES — configurable, not hard-coded
-- ---------------------------------------------------------------------------
CREATE TABLE reference.case_type (
    case_type_id    UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    type_code       VARCHAR(60) NOT NULL UNIQUE,
    type_name       VARCHAR(120) NOT NULL,
    ipc_sections    TEXT,         -- common IPC sections, comma-separated (informational)
    crpc_sections   TEXT,
    is_cognizable   BOOLEAN,
    is_bailable     BOOLEAN,
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now()
);

INSERT INTO reference.case_type (type_code, type_name, is_cognizable, is_bailable) VALUES
('MURDER',           'Murder',                              TRUE,  FALSE),
('CULPABLE_HOMICIDE','Culpable Homicide',                   TRUE,  FALSE),
('ROBBERY',          'Robbery',                             TRUE,  FALSE),
('THEFT',            'Theft',                               TRUE,  TRUE),
('BURGLARY',         'Burglary',                            TRUE,  FALSE),
('ASSAULT',          'Assault / Hurt',                      TRUE,  TRUE),
('KIDNAPPING',       'Kidnapping / Abduction',              TRUE,  FALSE),
('FRAUD',            'Cheating / Fraud',                    TRUE,  TRUE),
('CYBERCRIME',       'Cyber Crime',                         TRUE,  TRUE),
('SEXUAL_OFFENCE',   'Sexual Offence',                      TRUE,  FALSE),
('DOMESTIC_VIOLENCE','Domestic Violence',                   TRUE,  TRUE),
('DRUG_OFFENCE',     'Drug / NDPS Offence',                 TRUE,  FALSE),
('TERRORISM',        'Terrorism / UAPA',                    TRUE,  FALSE),
('FINANCIAL_CRIME',  'Financial Crime / Economic Offence',  TRUE,  FALSE),
('TRAFFIC',          'Traffic / MV Act Offence',            FALSE, TRUE),
('MISSING_PERSON',   'Missing Person',                      FALSE, TRUE),
('MISSING_CHILD',    'Missing Child',                       TRUE,  FALSE),
('OTHER',            'Other Offence',                       NULL,  NULL);

-- ---------------------------------------------------------------------------
-- 9. EVIDENCE TYPES
-- ---------------------------------------------------------------------------
CREATE TABLE reference.evidence_type (
    evidence_type_id   UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    type_code          VARCHAR(60) NOT NULL UNIQUE,
    type_name          VARCHAR(120) NOT NULL,
    requires_fsl       BOOLEAN     NOT NULL DEFAULT FALSE,
    is_digital         BOOLEAN     NOT NULL DEFAULT FALSE,
    is_active          BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO reference.evidence_type (type_code, type_name, requires_fsl, is_digital) VALUES
('MOBILE_PHONE',      'Mobile Phone / Smartphone',         TRUE,  TRUE),
('COMPUTER',          'Computer / Laptop',                 TRUE,  TRUE),
('STORAGE_MEDIA',     'Storage Media (USB/HDD/SSD)',       TRUE,  TRUE),
('FORENSIC_IMAGE',    'Forensic Disk Image',               FALSE, TRUE),
('DIGITAL_FILE',      'Digital File / Document',           FALSE, TRUE),
('DATABASE_EXTRACT',  'Extracted Database / Artifact',     FALSE, TRUE),
('SCREENSHOT',        'Screenshot / Screen Capture',       FALSE, TRUE),
('CCTV_FOOTAGE',      'CCTV / Video Recording',            FALSE, TRUE),
('AUDIO_RECORDING',   'Audio Recording',                   FALSE, TRUE),
('FINGERPRINT',       'Fingerprint',                       TRUE,  FALSE),
('DNA_SAMPLE',        'DNA Sample / Biological',           TRUE,  FALSE),
('FIREARM',           'Firearm / Weapon',                  TRUE,  FALSE),
('DOCUMENT_PHYSICAL', 'Physical Document / Paper',         FALSE, FALSE),
('CURRENCY',          'Currency / Valuables',              FALSE, FALSE),
('VEHICLE',           'Vehicle',                           FALSE, FALSE),
('NARCOTICS',         'Narcotic Substance',                TRUE,  FALSE),
('CLOTHING',          'Clothing / Fabric',                 TRUE,  FALSE),
('TOOL',              'Tool / Instrument',                 FALSE, FALSE),
('FORENSIC_REPORT',   'Forensic Report Document',          FALSE, FALSE),
('WITNESS_STATEMENT', 'Witness / Expert Statement',        FALSE, FALSE),
('OTHER',             'Other Evidence',                    FALSE, FALSE);

-- ---------------------------------------------------------------------------
-- 10. DOCUMENT TYPES
-- ---------------------------------------------------------------------------
CREATE TABLE reference.document_type (
    document_type_id   UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    type_code          VARCHAR(60) NOT NULL UNIQUE,
    type_name          VARCHAR(120) NOT NULL,
    requires_signature BOOLEAN     NOT NULL DEFAULT FALSE,
    retention_years    SMALLINT,             -- statutory retention period
    is_active          BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO reference.document_type (type_code, type_name, requires_signature, retention_years) VALUES
('FIR',                 'First Information Report',                    TRUE,  25),
('CASE_DIARY',          'Case Diary Entry',                            TRUE,  25),
('SEIZURE_MEMO',        'Seizure Memo / Panchanama',                   TRUE,  25),
('ARREST_MEMO',         'Arrest Memo',                                 TRUE,  25),
('REMAND_APPLICATION',  'Remand Application',                          TRUE,  25),
('WITNESS_STATEMENT',   'Witness Statement (Section 161/164 CrPC)',    TRUE,  25),
('FSL_REQUEST',         'Forensic Request Letter',                     TRUE,  15),
('FSL_REPORT',          'Forensic Science Laboratory Report',          TRUE,  25),
('CHARGE_SHEET',        'Charge Sheet (Final Report)',                 TRUE,  25),
('COURT_SUBMISSION',    'Court Submission',                            TRUE,  25),
('TRANSFER_ORDER',      'Transfer / Zero FIR Transfer Order',         TRUE,  25),
('SEARCH_WARRANT',      'Search Warrant',                              TRUE,  25),
('POSTMORTEM_REPORT',   'Post-Mortem Report',                          TRUE,  25),
('MEDICAL_REPORT',      'Medical / Injury Report',                     TRUE,  15),
('BAIL_ORDER',          'Bail Order',                                  TRUE,  25),
('JUDGMENT',            'Court Judgment',                              TRUE,  25),
('PHOTOGRAPH',          'Photograph / Image',                          FALSE, 25),
('SKETCH_MAP',          'Sketch Map / Scene Plan',                     FALSE, 25),
('GENERAL_CORRESPONDENCE','General Correspondence',                    FALSE, 10),
('OTHER',               'Other Document',                              FALSE, 10);

-- ---------------------------------------------------------------------------
-- 11. CLASSIFICATION LEVELS
-- ---------------------------------------------------------------------------
CREATE TABLE reference.classification_level (
    level_code    VARCHAR(30)  PRIMARY KEY,
    label         VARCHAR(80)  NOT NULL,
    numeric_level SMALLINT     NOT NULL UNIQUE,  -- higher = more restricted
    description   TEXT,
    is_active     BOOLEAN      NOT NULL DEFAULT TRUE
);

INSERT INTO reference.classification_level (level_code, label, numeric_level) VALUES
('PUBLIC',           'Public',            10),
('INTERNAL',         'Internal Use Only', 20),
('CONFIDENTIAL',     'Confidential',      30),
('RESTRICTED',       'Restricted',        40),
('HIGHLY_RESTRICTED','Highly Restricted', 50);

-- ---------------------------------------------------------------------------
-- 12. DOCUMENT VERSION STATUS
-- ---------------------------------------------------------------------------
CREATE TABLE reference.version_status (
    status_code  VARCHAR(30) PRIMARY KEY,
    label        VARCHAR(80) NOT NULL,
    is_terminal  BOOLEAN     NOT NULL DEFAULT FALSE,  -- no further transitions allowed
    is_active    BOOLEAN     NOT NULL DEFAULT TRUE
);

INSERT INTO reference.version_status (status_code, label, is_terminal) VALUES
('DRAFT',         'Draft',           FALSE),
('UNDER_REVIEW',  'Under Review',    FALSE),
('APPROVED',      'Approved',        FALSE),
('FINAL',         'Finalized',       TRUE),
('REVOKED',       'Revoked',         TRUE),
('ARCHIVED',      'Archived',        TRUE);

-- ---------------------------------------------------------------------------
-- 13. CASE STATUS
-- ---------------------------------------------------------------------------
CREATE TABLE reference.case_status (
    status_code  VARCHAR(40) PRIMARY KEY,
    label        VARCHAR(80) NOT NULL,
    is_active    BOOLEAN     NOT NULL DEFAULT TRUE
);

INSERT INTO reference.case_status (status_code, label) VALUES
('UNREGISTERED',       'Unregistered'),
('FIR_REGISTERED',     'FIR Registered'),
('UNDER_INVESTIGATION','Under Investigation'),
('CHARGE_SHEET_FILED', 'Charge Sheet Filed'),
('TRIAL_ONGOING',      'Trial Ongoing'),
('ACQUITTAL',          'Acquittal'),
('CONVICTION',         'Conviction'),
('CLOSED_UNDETECTED',  'Closed (Undetected)'),
('CLOSED_FALSE',       'Closed (False Case)'),
('TRANSFERRED',        'Transferred'),
('REFERRED',           'Referred to Other Agency'),
('STAYED',             'Stayed by Court');

-- ---------------------------------------------------------------------------
-- 14. EVIDENCE STATUS
-- ---------------------------------------------------------------------------
CREATE TABLE reference.evidence_status (
    status_code  VARCHAR(40) PRIMARY KEY,
    label        VARCHAR(80) NOT NULL,
    is_active    BOOLEAN     NOT NULL DEFAULT TRUE
);

INSERT INTO reference.evidence_status (status_code, label) VALUES
('COLLECTED',       'Collected'),
('IN_MALKHANA',     'In Malkhana Custody'),
('SENT_TO_FSL',     'Sent to FSL'),
('AT_FSL',          'At FSL'),
('RETURNED_FROM_FSL','Returned from FSL'),
('PRODUCED_IN_COURT','Produced in Court'),
('RELEASED',        'Released to Owner'),
('DESTROYED',       'Destroyed'),
('ARCHIVED',        'Archived'),
('MISSING',         'Missing / Tampered');

-- ---------------------------------------------------------------------------
-- 15. EVIDENCE RELATIONSHIP TYPES
-- ---------------------------------------------------------------------------
CREATE TABLE reference.evidence_relationship_type (
    rel_type_code  VARCHAR(40) PRIMARY KEY,
    label          VARCHAR(100) NOT NULL,
    description    TEXT,
    is_active      BOOLEAN      NOT NULL DEFAULT TRUE
);

INSERT INTO reference.evidence_relationship_type (rel_type_code, label) VALUES
('DERIVED_FROM',        'Derived From'),
('RELATED_TO',          'Related To'),
('SUPPORTS',            'Supports'),
('CONTRADICTS',         'Contradicts'),
('CORROBORATES',        'Corroborates'),
('GENERATED_FROM',      'Generated From'),
('EXTRACTED_FROM',      'Extracted From'),
('SAME_SOURCE',         'Same Source'),
('SAME_DEVICE',         'Same Device'),
('SAME_LOCATION',       'Same Location'),
('SAME_EVENT',          'Same Event'),
('PART_OF',             'Part Of'),
('DIGITIZED_FROM',      'Digitized From'),
('FORENSIC_ANALYSIS_OF','Forensic Analysis Of'),
('REPORTS_ON',          'Reports On');

-- ---------------------------------------------------------------------------
-- 16. CUSTODY EVENT TYPES
-- ---------------------------------------------------------------------------
CREATE TABLE reference.custody_event_type (
    event_type_code  VARCHAR(40) PRIMARY KEY,
    label            VARCHAR(100) NOT NULL,
    is_active        BOOLEAN      NOT NULL DEFAULT TRUE
);

INSERT INTO reference.custody_event_type (event_type_code, label) VALUES
('SEIZED',              'Seized / Collected'),
('SEALED',              'Sealed'),
('DEPOSITED',           'Deposited in Malkhana'),
('TRANSFERRED',         'Transferred'),
('RECEIVED',            'Received'),
('SENT_TO_FSL',         'Sent to FSL'),
('RECEIVED_BY_FSL',     'Received by FSL'),
('RETURNED_FROM_FSL',   'Returned from FSL'),
('PRODUCED_IN_COURT',   'Produced in Court'),
('RETURNED_FROM_COURT', 'Returned from Court'),
('RELEASED',            'Released to Owner'),
('DESTROYED',           'Destroyed'),
('ARCHIVED',            'Archived'),
('RESEALED',            'Resealed'),
('CONDITION_CHECKED',   'Condition Checked / Inspected');

-- ---------------------------------------------------------------------------
-- 17. CUSTODIAN TYPES
-- ---------------------------------------------------------------------------
CREATE TABLE reference.custodian_type (
    custodian_type_code  VARCHAR(40) PRIMARY KEY,
    label                VARCHAR(100) NOT NULL,
    is_active            BOOLEAN      NOT NULL DEFAULT TRUE
);

INSERT INTO reference.custodian_type (custodian_type_code, label) VALUES
('OFFICER',         'Police Officer'),
('MALKHANA',        'Malkhana (Police Station)'),
('FSL',             'Forensic Science Laboratory'),
('COURT',           'Court / Registrar'),
('PROSECUTION',     'Prosecution / PP Office'),
('EXTERNAL_AGENCY', 'External Agency'),
('OWNER',           'Original Owner / Claimant');

-- ---------------------------------------------------------------------------
-- 18. CASE EVENT TYPES
-- ---------------------------------------------------------------------------
CREATE TABLE reference.case_event_type (
    event_type_code  VARCHAR(60) PRIMARY KEY,
    label            VARCHAR(120) NOT NULL,
    is_active        BOOLEAN      NOT NULL DEFAULT TRUE
);

INSERT INTO reference.case_event_type (event_type_code, label) VALUES
('FIR_REGISTERED',            'FIR Registered'),
('ZERO_FIR_REGISTERED',       'Zero FIR Registered'),
('FIR_TRANSFERRED',           'FIR / Case Transferred'),
('OFFICER_ASSIGNED',          'Officer Assigned to Case'),
('OFFICER_REMOVED',           'Officer Removed from Case'),
('SCENE_VISITED',             'Scene of Crime Visited'),
('SEARCH_CONDUCTED',          'Search Conducted'),
('SEIZURE_MADE',              'Seizure Made'),
('ARREST_MADE',               'Arrest Made'),
('WITNESS_STATEMENT_RECORDED','Witness Statement Recorded'),
('EVIDENCE_DEPOSITED',        'Evidence Deposited'),
('EVIDENCE_TRANSFERRED',      'Evidence Transferred'),
('FSL_REQUESTED',             'FSL Request Submitted'),
('FSL_REPORT_RECEIVED',       'FSL Report Received'),
('CHARGE_SHEET_PREPARED',     'Charge Sheet Prepared'),
('CHARGE_SHEET_FILED',        'Charge Sheet Filed in Court'),
('COURT_SUBMISSION',          'Documents Submitted to Court'),
('CASE_CLOSED',               'Case Closed'),
('CASE_REOPENED',             'Case Reopened'),
('REMAND_OBTAINED',           'Remand Obtained'),
('BAIL_GRANTED',              'Bail Granted'),
('WITNESS_PRODUCED',          'Witness Produced in Court'),
('JUDGMENT_RECEIVED',         'Judgment Received'),
('NOTE_ADDED',                'Case Diary Note Added');

-- ---------------------------------------------------------------------------
-- 19. PERSON ROLE TYPES (in context of a case)
-- ---------------------------------------------------------------------------
CREATE TABLE reference.person_role_type (
    role_type_code  VARCHAR(40) PRIMARY KEY,
    label           VARCHAR(100) NOT NULL,
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE
);

INSERT INTO reference.person_role_type (role_type_code, label) VALUES
('COMPLAINANT',     'Complainant'),
('ACCUSED',         'Accused'),
('VICTIM',          'Victim'),
('WITNESS',         'Witness'),
('EXPERT_WITNESS',  'Expert Witness'),
('SUSPECT',         'Suspect'),
('INFORMANT',       'Informant / Informer'),
('OTHER',           'Other');

-- ---------------------------------------------------------------------------
-- 20. FORENSIC DISCIPLINES
-- ---------------------------------------------------------------------------
CREATE TABLE reference.forensic_discipline (
    discipline_id    UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    discipline_code  VARCHAR(60) NOT NULL UNIQUE,
    discipline_name  VARCHAR(120) NOT NULL,
    is_active        BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO reference.forensic_discipline (discipline_code, discipline_name) VALUES
('DIGITAL_FORENSICS',   'Digital Forensics / Cyber Forensics'),
('FINGERPRINT',         'Fingerprint Examination'),
('DNA',                 'DNA / Serology'),
('BALLISTICS',          'Ballistics / Firearms'),
('DOCUMENTS',           'Questioned Documents / Handwriting'),
('TOXICOLOGY',          'Toxicology / Chemical Analysis'),
('NARCOTICS',           'Narcotics Analysis'),
('BIOLOGY',             'Biology / Trace Evidence'),
('PHOTOGRAPHY',         'Photography / Video Analysis'),
('EXPLOSIVES',          'Explosives Analysis'),
('ACCIDENT_ANALYSIS',   'Accident / Vehicle Analysis'),
('OTHER',               'Other / General');

-- ---------------------------------------------------------------------------
-- 21. AUDIT ACTION TYPES
-- ---------------------------------------------------------------------------
CREATE TABLE reference.audit_action_type (
    action_code  VARCHAR(60) PRIMARY KEY,
    label        VARCHAR(120) NOT NULL,
    severity     VARCHAR(20)  NOT NULL DEFAULT 'INFO',   -- INFO, WARN, CRITICAL
    is_active    BOOLEAN      NOT NULL DEFAULT TRUE
);

INSERT INTO reference.audit_action_type (action_code, label, severity) VALUES
('LOGIN',                  'User Login',                       'INFO'),
('LOGIN_FAILED',           'Failed Login Attempt',             'WARN'),
('LOGOUT',                 'User Logout',                      'INFO'),
('SESSION_EXPIRED',        'Session Expired',                  'INFO'),
('CASE_VIEW',              'Case Viewed',                      'INFO'),
('CASE_CREATE',            'Case Created',                     'INFO'),
('CASE_UPDATE',            'Case Updated',                     'INFO'),
('CASE_CLOSE',             'Case Closed',                      'WARN'),
('CASE_ASSIGN',            'Officer Assigned to Case',         'INFO'),
('CASE_TRANSFER',          'Case Transferred',                 'WARN'),
('CASE_EXPORT',            'Case Exported',                    'WARN'),
('FIR_CREATE',             'FIR Registered',                   'INFO'),
('FIR_UPDATE',             'FIR Updated',                      'WARN'),
('DOCUMENT_VIEW',          'Document Viewed',                  'INFO'),
('DOCUMENT_DOWNLOAD',      'Document Downloaded',              'WARN'),
('DOCUMENT_UPLOAD',        'Document Uploaded',                'INFO'),
('DOCUMENT_SIGN',          'Document Signed',                  'INFO'),
('DOCUMENT_FINALIZE',      'Document Finalized',               'INFO'),
('DOCUMENT_DELETE_ATTEMPT','Document Delete Attempted',        'CRITICAL'),
('EVIDENCE_VIEW',          'Evidence Viewed',                  'INFO'),
('EVIDENCE_CREATE',        'Evidence Created',                 'INFO'),
('EVIDENCE_UPDATE',        'Evidence Updated',                 'WARN'),
('EVIDENCE_TRANSFER',      'Evidence Custody Transferred',     'WARN'),
('EVIDENCE_VERIFY',        'Evidence Integrity Verified',      'INFO'),
('EVIDENCE_DELETE_ATTEMPT','Evidence Delete Attempted',        'CRITICAL'),
('CUSTODY_TRANSFER',       'Custody Transfer Recorded',        'INFO'),
('FSL_REQUEST',            'FSL Request Created',              'INFO'),
('FSL_REPORT_RECEIVED',    'FSL Report Received',              'INFO'),
('COURT_SUBMISSION',       'Documents Submitted to Court',     'WARN'),
('PERMISSION_CHANGE',      'Permission / Role Changed',        'CRITICAL'),
('INTEGRITY_ALERT',        'Document Integrity Alert',         'CRITICAL'),
('AUDIT_CHAIN_VERIFIED',   'Audit Chain Verified',             'INFO'),
('AUDIT_CHAIN_TAMPER',     'Audit Chain Tampering Detected',   'CRITICAL'),
('OFFICER_CREATED',        'Officer Account Created',          'INFO'),
('OFFICER_UPDATED',        'Officer Account Updated',          'WARN'),
('POSTING_CHANGE',         'Officer Posting Changed',          'INFO');

-- ---------------------------------------------------------------------------
-- 22. SIGNATURE ALGORITHMS
-- ---------------------------------------------------------------------------
CREATE TABLE reference.signature_algorithm (
    algo_code   VARCHAR(40) PRIMARY KEY,
    label       VARCHAR(100) NOT NULL,
    is_active   BOOLEAN      NOT NULL DEFAULT TRUE
);

INSERT INTO reference.signature_algorithm (algo_code, label) VALUES
('RSA_SHA256',    'RSA with SHA-256'),
('RSA_SHA512',    'RSA with SHA-512'),
('ECDSA_SHA256',  'ECDSA with SHA-256'),
('DSA_SHA256',    'DSA with SHA-256'),
('ED25519',       'EdDSA / Ed25519'),
('OTHER',         'Other');

-- ---------------------------------------------------------------------------
-- 23. HASH ALGORITHMS
-- ---------------------------------------------------------------------------
CREATE TABLE reference.hash_algorithm (
    algo_code   VARCHAR(20) PRIMARY KEY,
    label       VARCHAR(60) NOT NULL,
    bit_length  SMALLINT,
    is_active   BOOLEAN     NOT NULL DEFAULT TRUE
);

INSERT INTO reference.hash_algorithm (algo_code, label, bit_length) VALUES
('MD5',      'MD5 (legacy, not recommended)',  128),
('SHA1',     'SHA-1 (legacy)',                 160),
('SHA256',   'SHA-256',                        256),
('SHA512',   'SHA-512',                        512),
('SHA3_256', 'SHA-3 / 256-bit',               256),
('BLAKE3',   'BLAKE3',                        256);

-- ---------------------------------------------------------------------------
-- 24. RETENTION CATEGORIES
-- ---------------------------------------------------------------------------
CREATE TABLE reference.retention_category (
    category_code   VARCHAR(40)  PRIMARY KEY,
    label           VARCHAR(100) NOT NULL,
    retention_years SMALLINT     NOT NULL,
    description     TEXT,
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE
);

INSERT INTO reference.retention_category (category_code, label, retention_years) VALUES
('PERMANENT',    'Permanent Record',                    999),
('LONG_TERM',    'Long-Term (25 years)',                25),
('MEDIUM_TERM',  'Medium-Term (10 years)',              10),
('SHORT_TERM',   'Short-Term (5 years)',                5),
('TEMPORARY',    'Temporary (1 year)',                  1);

-- ---------------------------------------------------------------------------
-- 25. TRANSFER REASONS
-- ---------------------------------------------------------------------------
CREATE TABLE reference.transfer_reason (
    reason_code  VARCHAR(60) PRIMARY KEY,
    label        VARCHAR(120) NOT NULL,
    is_active    BOOLEAN      NOT NULL DEFAULT TRUE
);

INSERT INTO reference.transfer_reason (reason_code, label) VALUES
('ZERO_FIR',           'Zero FIR – Jurisdictional Transfer'),
('JURISDICTION_CHANGE','Change of Jurisdiction'),
('SPECIALISED_UNIT',   'Referred to Specialised Unit (CID/CBI/etc.)'),
('COURT_DIRECTION',    'Court Direction'),
('OFFICER_TRANSFER',   'Investigating Officer Transferred'),
('WORKLOAD',           'Workload Redistribution'),
('OTHER',              'Other');
-- =============================================================================
-- 003_organisation.sql
-- Organisational hierarchy, police stations, jurisdictions
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. ORGANISATION UNIT — flexible self-referencing hierarchy
--    Supports both District system and Commissionerate system.
--    Different Indian states may have different depth/structure.
-- ---------------------------------------------------------------------------
CREATE TABLE organisation.organisation_unit (
    unit_id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    unit_code          VARCHAR(60)  NOT NULL UNIQUE,
    unit_name          VARCHAR(200) NOT NULL,
    unit_type_code     VARCHAR(40)  NOT NULL REFERENCES reference.unit_type(unit_type_code),
    parent_unit_id     UUID         REFERENCES organisation.organisation_unit(unit_id),
    state_code         CHAR(2),                    -- ISO 3166-2 state code, e.g. KA, MH, DL
    country_code       CHAR(2)      NOT NULL DEFAULT 'IN',
    address            TEXT,
    city               VARCHAR(100),
    district           VARCHAR(100),
    pincode            VARCHAR(10),
    phone              VARCHAR(20),
    email              VARCHAR(120),
    latitude           NUMERIC(10,7),
    longitude          NUMERIC(10,7),
    -- PostGIS-compatible geometry stored as text; replace with geometry(Point,4326)
    -- if PostGIS is available
    geom_wkt           TEXT,
    is_active          BOOLEAN      NOT NULL DEFAULT TRUE,
    established_on     DATE,
    notes              TEXT,
    created_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by         UUID,        -- officer_id; circular ref resolved by deferral
    updated_by         UUID
);

CREATE INDEX idx_org_unit_parent    ON organisation.organisation_unit(parent_unit_id);
CREATE INDEX idx_org_unit_type      ON organisation.organisation_unit(unit_type_code);
CREATE INDEX idx_org_unit_state     ON organisation.organisation_unit(state_code);
CREATE INDEX idx_org_unit_name_trgm ON organisation.organisation_unit USING gin(unit_name gin_trgm_ops);

-- ---------------------------------------------------------------------------
-- 2. POLICE STATION — dedicated entity linked to organisation unit
--    Every police station IS an organisation_unit but has its own richer record.
-- ---------------------------------------------------------------------------
CREATE TABLE organisation.police_station (
    station_id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    station_code            VARCHAR(60)  NOT NULL UNIQUE,
    station_name            VARCHAR(200) NOT NULL,
    station_type_code       VARCHAR(40)  NOT NULL REFERENCES reference.station_type(station_type_code),
    organisation_unit_id    UUID         NOT NULL UNIQUE REFERENCES organisation.organisation_unit(unit_id),

    -- Soft hierarchy references for quick lookup (all FKs into org unit)
    -- These are denormalised convenience columns — truth is in org_unit hierarchy
    parent_station_id       UUID         REFERENCES organisation.police_station(station_id),  -- for outpost → PS

    state_code              CHAR(2)      NOT NULL,
    district_name           VARCHAR(100),
    subdivision_name        VARCHAR(100),
    circle_name             VARCHAR(100),

    -- Address
    address_line1           VARCHAR(200),
    address_line2           VARCHAR(200),
    city                    VARCHAR(100),
    pincode                 VARCHAR(10),
    phone_primary           VARCHAR(20),
    phone_emergency         VARCHAR(20),
    email                   VARCHAR(120),
    fax                     VARCHAR(20),

    -- Location
    latitude                NUMERIC(10,7),
    longitude               NUMERIC(10,7),
    geom_wkt                TEXT,

    -- Identifiers used in external systems
    cctns_station_code      VARCHAR(60),   -- CCTNS assigned code
    state_station_code      VARCHAR(60),   -- State-assigned code

    -- Status
    is_active               BOOLEAN      NOT NULL DEFAULT TRUE,
    established_on          DATE,
    notes                   TEXT,

    created_at              TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by              UUID,
    updated_by              UUID
);

CREATE INDEX idx_ps_org_unit    ON organisation.police_station(organisation_unit_id);
CREATE INDEX idx_ps_state       ON organisation.police_station(state_code);
CREATE INDEX idx_ps_parent      ON organisation.police_station(parent_station_id);
CREATE INDEX idx_ps_name_trgm   ON organisation.police_station USING gin(station_name gin_trgm_ops);
CREATE INDEX idx_ps_cctns_code  ON organisation.police_station(cctns_station_code);

-- ---------------------------------------------------------------------------
-- 3. JURISDICTION — territorial jurisdiction of a police station
-- ---------------------------------------------------------------------------
CREATE TABLE organisation.jurisdiction (
    jurisdiction_id      UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    station_id           UUID         NOT NULL REFERENCES organisation.police_station(station_id),
    jurisdiction_name    VARCHAR(200) NOT NULL,
    jurisdiction_type    VARCHAR(40)  NOT NULL DEFAULT 'TERRITORIAL',
                                      -- TERRITORIAL, FUNCTIONAL, CONCURRENT
    description          TEXT,
    area_sq_km           NUMERIC(12,4),
    population_approx    BIGINT,

    -- Boundary as WKT polygon (PostGIS-compatible; store as text for portability)
    boundary_wkt         TEXT,

    -- Constituent localities / areas described textually when geometry unavailable
    localities_text      TEXT,

    is_active            BOOLEAN      NOT NULL DEFAULT TRUE,
    effective_from       DATE,
    effective_to         DATE,
    created_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by           UUID,
    updated_by           UUID
);

CREATE INDEX idx_jurisdiction_station ON organisation.jurisdiction(station_id);

-- ---------------------------------------------------------------------------
-- 4. JURISDICTION LOCALITY — specific named localities under a jurisdiction
--    Allows answering "which PS has jurisdiction over locality X?"
-- ---------------------------------------------------------------------------
CREATE TABLE organisation.jurisdiction_locality (
    locality_id      UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    jurisdiction_id  UUID         NOT NULL REFERENCES organisation.jurisdiction(jurisdiction_id),
    locality_name    VARCHAR(200) NOT NULL,
    locality_type    VARCHAR(60),   -- VILLAGE, WARD, MOHALLA, COLONY, ROAD, etc.
    pin_code         VARCHAR(10),
    notes            TEXT,
    is_active        BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_jlocality_jurisdiction ON organisation.jurisdiction_locality(jurisdiction_id);
CREATE INDEX idx_jlocality_name_trgm    ON organisation.jurisdiction_locality
    USING gin(locality_name gin_trgm_ops);

-- ---------------------------------------------------------------------------
-- 5. BEAT — smallest patrol unit under a police station
-- ---------------------------------------------------------------------------
CREATE TABLE organisation.beat (
    beat_id       UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    beat_code     VARCHAR(60)  NOT NULL,
    beat_name     VARCHAR(120) NOT NULL,
    station_id    UUID         NOT NULL REFERENCES organisation.police_station(station_id),
    beat_type     VARCHAR(40)  NOT NULL DEFAULT 'REGULAR',  -- REGULAR, MOBILE, CYBER
    area_sq_km    NUMERIC(10,4),
    boundary_wkt  TEXT,
    notes         TEXT,
    is_active     BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    UNIQUE (station_id, beat_code)
);

CREATE INDEX idx_beat_station ON organisation.beat(station_id);

-- ---------------------------------------------------------------------------
-- 6. EXTERNAL AGENCY — for referencing other agencies (CBI, CID, NCB, ED, etc.)
-- ---------------------------------------------------------------------------
CREATE TABLE organisation.external_agency (
    agency_id     UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    agency_code   VARCHAR(60)  NOT NULL UNIQUE,
    agency_name   VARCHAR(200) NOT NULL,
    agency_type   VARCHAR(60),   -- CENTRAL, STATE, JUDICIAL, FORENSIC, PROSECUTION
    parent_ministry VARCHAR(120),
    website       VARCHAR(200),
    contact_email VARCHAR(120),
    contact_phone VARCHAR(20),
    notes         TEXT,
    is_active     BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now()
);

INSERT INTO organisation.external_agency (agency_code, agency_name, agency_type) VALUES
('CBI',   'Central Bureau of Investigation',        'CENTRAL'),
('CID',   'Criminal Investigation Department',      'STATE'),
('NCB',   'Narcotics Control Bureau',               'CENTRAL'),
('ED',    'Enforcement Directorate',                'CENTRAL'),
('NIA',   'National Investigation Agency',          'CENTRAL'),
('SFIO',  'Serious Fraud Investigation Office',     'CENTRAL'),
('IT_DEPT','Income Tax Department',                 'CENTRAL'),
('CUSTOMS','Customs Department',                    'CENTRAL');

-- ---------------------------------------------------------------------------
-- 7. FSL / FORENSIC LABORATORY — may belong to state police or central body
-- ---------------------------------------------------------------------------
CREATE TABLE organisation.forensic_laboratory (
    lab_id             UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    lab_code           VARCHAR(60)  NOT NULL UNIQUE,
    lab_name           VARCHAR(200) NOT NULL,
    lab_type           VARCHAR(40)  NOT NULL DEFAULT 'STATE_FSL',
                                    -- STATE_FSL, CENTRAL_FSL, PRIVATE, UNIVERSITY
    organisation_unit_id UUID       REFERENCES organisation.organisation_unit(unit_id),
    address            TEXT,
    city               VARCHAR(100),
    state_code         CHAR(2),
    phone              VARCHAR(20),
    email              VARCHAR(120),
    accreditation_body VARCHAR(120),
    accreditation_no   VARCHAR(80),
    accreditation_valid_until DATE,
    is_active          BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by         UUID,
    updated_by         UUID
);

INSERT INTO organisation.forensic_laboratory (lab_code, lab_name, lab_type, state_code, city) VALUES
('FSL-KA-BLR',  'Forensic Science Laboratory Bengaluru',          'STATE_FSL', 'KA', 'Bengaluru'),
('FSL-KA-MYS',  'Forensic Science Laboratory Mysuru',             'STATE_FSL', 'KA', 'Mysuru'),
('FSL-MH-MUM',  'Forensic Science Laboratory Mumbai',             'STATE_FSL', 'MH', 'Mumbai'),
('FSL-DL-NEW',  'Forensic Science Laboratory New Delhi',          'STATE_FSL', 'DL', 'New Delhi'),
('CFSL-HYD',    'Central Forensic Science Laboratory Hyderabad',  'CENTRAL_FSL','TS','Hyderabad'),
('CFSL-CHN',    'Central Forensic Science Laboratory Chennai',    'CENTRAL_FSL','TN','Chennai');

-- ---------------------------------------------------------------------------
-- 8. COURT — for references when submitting documents / exhibits
-- ---------------------------------------------------------------------------
CREATE TABLE organisation.court (
    court_id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    court_code        VARCHAR(60)  NOT NULL UNIQUE,
    court_name        VARCHAR(200) NOT NULL,
    court_type        VARCHAR(60)  NOT NULL,
                      -- SUPREME, HIGH, SESSIONS, CJM, JMFC, SPECIAL, MAGISTRATE, OTHER
    state_code        CHAR(2),
    district          VARCHAR(100),
    city              VARCHAR(100),
    address           TEXT,
    phone             VARCHAR(20),
    email             VARCHAR(120),
    is_active         BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at        TIMESTAMPTZ  NOT NULL DEFAULT now()
);

INSERT INTO organisation.court (court_code, court_name, court_type, state_code, city) VALUES
('COURT-KA-BLR-01', 'City Civil and Sessions Court Bengaluru',  'SESSIONS',    'KA', 'Bengaluru'),
('COURT-KA-BLR-02', 'Chief Metropolitan Magistrate Bengaluru',  'CJM',         'KA', 'Bengaluru'),
('COURT-MH-MUM-01', 'City Civil and Sessions Court Mumbai',     'SESSIONS',    'MH', 'Mumbai'),
('COURT-DL-NEW-01', 'Sessions Court Delhi',                     'SESSIONS',    'DL', 'New Delhi');
-- =============================================================================
-- 004_identity.sql
-- Officer identity, person registry, postings, designations
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. PERSON — universal person registry
--    Every person in the system (officer, accused, witness, victim) starts here.
--    Sensitive personal data columns are present but access is controlled at
--    the application layer (and optionally via RLS).
-- ---------------------------------------------------------------------------
CREATE TABLE identity.person (
    person_id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    first_name           VARCHAR(80)  NOT NULL,
    middle_name          VARCHAR(80),
    last_name            VARCHAR(80),
    full_name            VARCHAR(200) GENERATED ALWAYS AS (
                             TRIM(COALESCE(first_name,'') || ' ' ||
                                  COALESCE(middle_name || ' ', '') ||
                                  COALESCE(last_name,''))
                         ) STORED,
    date_of_birth        DATE,
    gender               VARCHAR(20)  CHECK (gender IN ('MALE','FEMALE','TRANSGENDER','OTHER','NOT_SPECIFIED')),
    nationality          CHAR(2)      NOT NULL DEFAULT 'IN',

    -- Government IDs — stored as references, not validated here
    aadhaar_hash         VARCHAR(64),    -- SHA-256 of Aadhaar, NOT the number itself
    pan_number           VARCHAR(10),
    passport_number      VARCHAR(20),
    voter_id             VARCHAR(20),
    driving_license      VARCHAR(20),

    -- Contact
    phone_primary        VARCHAR(20),
    phone_secondary      VARCHAR(20),
    email                VARCHAR(120),

    -- Address
    address_current      TEXT,
    address_permanent    TEXT,
    city                 VARCHAR(100),
    state_code           CHAR(2),
    pincode              VARCHAR(10),

    -- Flags
    is_police_officer    BOOLEAN      NOT NULL DEFAULT FALSE,
    is_active            BOOLEAN      NOT NULL DEFAULT TRUE,

    -- Soft delete
    deleted_at           TIMESTAMPTZ,
    deleted_by           UUID,
    deletion_reason      TEXT,

    created_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by           UUID,
    updated_by           UUID
);

CREATE INDEX idx_person_name_trgm  ON identity.person USING gin(full_name gin_trgm_ops);
CREATE INDEX idx_person_phone      ON identity.person(phone_primary);
CREATE INDEX idx_person_is_officer ON identity.person(is_police_officer) WHERE is_police_officer = TRUE;

-- ---------------------------------------------------------------------------
-- 2. OFFICER — police officer; extends Person
--    officer_uuid is immutable even across transfers.
-- ---------------------------------------------------------------------------
CREATE TABLE identity.officer (
    officer_id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    person_id            UUID         NOT NULL UNIQUE REFERENCES identity.person(person_id),

    -- Human-readable identity code: IN-KA-BLR-CEN-PS042-SI-00127
    -- Generated by function generate_officer_identity_code(), stored here for display.
    -- Must be updated when rank changes but UUID never changes.
    identity_code        VARCHAR(80)  NOT NULL UNIQUE,

    -- Force / service number (state police service number, IPS allocation, etc.)
    service_number       VARCHAR(60)  UNIQUE,

    -- Rank and current assignment (convenience columns — canonical data in OfficerPosting)
    current_rank_code    VARCHAR(40)  NOT NULL REFERENCES reference.rank(rank_code),
    current_station_id   UUID         REFERENCES organisation.police_station(station_id),

    -- Authentication
    username             VARCHAR(60)  NOT NULL UNIQUE,
    password_hash        VARCHAR(255) NOT NULL,   -- bcrypt / argon2 hash
    last_login_at        TIMESTAMPTZ,
    failed_login_count   SMALLINT     NOT NULL DEFAULT 0,
    is_locked            BOOLEAN      NOT NULL DEFAULT FALSE,
    locked_until         TIMESTAMPTZ,
    mfa_enabled          BOOLEAN      NOT NULL DEFAULT FALSE,
    mfa_secret_ref       VARCHAR(120), -- reference to secret stored in secrets manager

    -- Service details
    date_of_joining      DATE,
    date_of_retirement   DATE,
    batch_year           SMALLINT,
    cadre                VARCHAR(40),  -- IPS, SPS, etc.
    home_state_code      CHAR(2),

    -- Status
    is_active            BOOLEAN      NOT NULL DEFAULT TRUE,
    suspended_at         TIMESTAMPTZ,
    suspension_reason    TEXT,

    -- Soft delete
    deleted_at           TIMESTAMPTZ,
    deleted_by           UUID,
    deletion_reason      TEXT,

    created_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by           UUID         REFERENCES identity.officer(officer_id),
    updated_by           UUID         REFERENCES identity.officer(officer_id),

    version_no           INTEGER      NOT NULL DEFAULT 1
);

CREATE INDEX idx_officer_person        ON identity.officer(person_id);
CREATE INDEX idx_officer_rank          ON identity.officer(current_rank_code);
CREATE INDEX idx_officer_station       ON identity.officer(current_station_id);
CREATE INDEX idx_officer_username      ON identity.officer(username);
CREATE INDEX idx_officer_service_no    ON identity.officer(service_number);

-- ---------------------------------------------------------------------------
-- 3. OFFICER POSTING — complete historical posting record
--    The canonical source of truth for "where was Officer X on date D?"
--    Enforces non-overlapping CURRENT postings via partial unique index.
-- ---------------------------------------------------------------------------
CREATE TABLE identity.officer_posting (
    posting_id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    officer_id              UUID         NOT NULL REFERENCES identity.officer(officer_id),
    organisation_unit_id    UUID         NOT NULL REFERENCES organisation.organisation_unit(unit_id),
    police_station_id       UUID         REFERENCES organisation.police_station(station_id),

    rank_id                 UUID         NOT NULL REFERENCES reference.rank(rank_id),
    designation_id          UUID         REFERENCES reference.designation(designation_id),

    posting_start_date      DATE         NOT NULL,
    posting_end_date        DATE,        -- NULL means current posting

    is_current              BOOLEAN      NOT NULL DEFAULT TRUE,

    reporting_officer_id    UUID         REFERENCES identity.officer(officer_id),

    -- Appointment reference
    appointment_order_no    VARCHAR(80),
    appointment_order_date  DATE,
    appointment_order_ref   TEXT,        -- URL or document reference in storage

    -- Nature of posting
    posting_type            VARCHAR(40)  NOT NULL DEFAULT 'REGULAR',
                            -- REGULAR, DEPUTATION, ATTACHMENT, ADDITIONAL_CHARGE, ACTING
    notes                   TEXT,

    created_at              TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by              UUID         REFERENCES identity.officer(officer_id),

    -- Business constraint: an officer cannot have two *current* postings
    CONSTRAINT chk_posting_dates CHECK (
        posting_end_date IS NULL OR posting_end_date >= posting_start_date
    )
);

-- Partial unique index: only one current posting per officer
CREATE UNIQUE INDEX idx_officer_posting_current
    ON identity.officer_posting(officer_id)
    WHERE is_current = TRUE;

CREATE INDEX idx_officer_posting_officer  ON identity.officer_posting(officer_id);
CREATE INDEX idx_officer_posting_station  ON identity.officer_posting(police_station_id);
CREATE INDEX idx_officer_posting_org_unit ON identity.officer_posting(organisation_unit_id);
CREATE INDEX idx_officer_posting_dates    ON identity.officer_posting(posting_start_date, posting_end_date);

-- ---------------------------------------------------------------------------
-- 4. OFFICER DEPARTMENTAL ROLE — many-to-many officer ↔ departmental role
--    An officer may hold multiple departmental roles simultaneously.
-- ---------------------------------------------------------------------------
CREATE TABLE identity.officer_departmental_role (
    assignment_id    UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    officer_id       UUID         NOT NULL REFERENCES identity.officer(officer_id),
    dept_role_id     UUID         NOT NULL REFERENCES reference.departmental_role(dept_role_id),
    granted_by       UUID         REFERENCES identity.officer(officer_id),
    granted_at       TIMESTAMPTZ  NOT NULL DEFAULT now(),
    revoked_at       TIMESTAMPTZ,
    revoked_by       UUID         REFERENCES identity.officer(officer_id),
    is_active        BOOLEAN      NOT NULL DEFAULT TRUE,
    notes            TEXT,
    UNIQUE (officer_id, dept_role_id)
);

CREATE INDEX idx_odr_officer ON identity.officer_departmental_role(officer_id);
CREATE INDEX idx_odr_role    ON identity.officer_departmental_role(dept_role_id);

-- ---------------------------------------------------------------------------
-- 5. OFFICER SESSION — track active sessions (for audit and MFA)
--    Sessions are managed by the application; this table enables audit queries.
-- ---------------------------------------------------------------------------
CREATE TABLE identity.officer_session (
    session_id        UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    officer_id        UUID         NOT NULL REFERENCES identity.officer(officer_id),
    created_at        TIMESTAMPTZ  NOT NULL DEFAULT now(),
    expires_at        TIMESTAMPTZ  NOT NULL,
    invalidated_at    TIMESTAMPTZ,
    ip_address        INET,
    user_agent        TEXT,
    device_fingerprint TEXT,
    is_valid          BOOLEAN      NOT NULL DEFAULT TRUE
);

CREATE INDEX idx_session_officer  ON identity.officer_session(officer_id);
CREATE INDEX idx_session_valid    ON identity.officer_session(is_valid, expires_at);

-- ---------------------------------------------------------------------------
-- 6. PERSON — case-related persons (accused, witnesses, victims, complainants)
--    Linked to identity.person but adds case-specific relationship context.
-- ---------------------------------------------------------------------------
CREATE TABLE identity.case_person (
    case_person_id    UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    case_id           UUID         NOT NULL,  -- FK added after case_mgmt schema
    person_id         UUID         NOT NULL REFERENCES identity.person(person_id),
    role_type_code    VARCHAR(40)  NOT NULL REFERENCES reference.person_role_type(role_type_code),
    added_by          UUID         REFERENCES identity.officer(officer_id),
    added_at          TIMESTAMPTZ  NOT NULL DEFAULT now(),
    removed_at        TIMESTAMPTZ,
    is_active         BOOLEAN      NOT NULL DEFAULT TRUE,
    notes             TEXT,
    -- Confidentiality: some witnesses need identity protection
    is_protected      BOOLEAN      NOT NULL DEFAULT FALSE,
    protection_reason TEXT
);

CREATE INDEX idx_case_person_case   ON identity.case_person(case_id);
CREATE INDEX idx_case_person_person ON identity.case_person(person_id);
CREATE INDEX idx_case_person_role   ON identity.case_person(role_type_code);

-- ---------------------------------------------------------------------------
-- 7. WITNESS — additional detail for witnesses beyond case_person
-- ---------------------------------------------------------------------------
CREATE TABLE identity.witness (
    witness_id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    case_person_id      UUID         NOT NULL UNIQUE REFERENCES identity.case_person(case_person_id),
    statement_recorded  BOOLEAN      NOT NULL DEFAULT FALSE,
    statement_date      DATE,
    statement_section   VARCHAR(20),  -- '161' or '164' CrPC
    is_hostile          BOOLEAN      NOT NULL DEFAULT FALSE,
    is_expert           BOOLEAN      NOT NULL DEFAULT FALSE,
    expertise_area      VARCHAR(120), -- for expert witnesses
    court_produced      BOOLEAN      NOT NULL DEFAULT FALSE,
    court_produced_date DATE,
    notes               TEXT,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- 8. ACCUSED — additional detail for accused persons
-- ---------------------------------------------------------------------------
CREATE TABLE identity.accused (
    accused_id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    case_person_id       UUID         NOT NULL REFERENCES identity.case_person(case_person_id),
    arrest_date          DATE,
    arrested_by          UUID         REFERENCES identity.officer(officer_id),
    is_arrested          BOOLEAN      NOT NULL DEFAULT FALSE,
    is_absconding        BOOLEAN      NOT NULL DEFAULT FALSE,
    is_juvenile          BOOLEAN      NOT NULL DEFAULT FALSE,
    bail_status          VARCHAR(40)  DEFAULT 'NOT_APPLICABLE',
                         -- NOT_APPLICABLE, APPLIED, GRANTED, REJECTED, CANCELLED
    bail_granted_date    DATE,
    bail_cancelled_date  DATE,
    custody_status       VARCHAR(40)  DEFAULT 'FREE',
                         -- FREE, POLICE_CUSTODY, JUDICIAL_CUSTODY, BAIL, ABSCONDING
    remand_count         SMALLINT     NOT NULL DEFAULT 0,
    prison_name          VARCHAR(120),
    prison_prisoner_no   VARCHAR(60),
    charge_sections      TEXT,        -- comma-separated IPC/BNS sections
    notes                TEXT,
    created_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at           TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_accused_case_person ON identity.accused(case_person_id);

-- ---------------------------------------------------------------------------
-- 9. VICTIM — additional detail for victims
-- ---------------------------------------------------------------------------
CREATE TABLE identity.victim (
    victim_id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    case_person_id       UUID         NOT NULL REFERENCES identity.case_person(case_person_id),
    injury_description   TEXT,
    medical_examined     BOOLEAN      NOT NULL DEFAULT FALSE,
    medical_examination_date DATE,
    medical_facility     VARCHAR(200),
    compensation_awarded BOOLEAN      NOT NULL DEFAULT FALSE,
    compensation_amount  NUMERIC(14,2),
    victim_support_ref   VARCHAR(120),
    notes                TEXT,
    created_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at           TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- 10. COMPLAINANT — additional detail for complainants
-- ---------------------------------------------------------------------------
CREATE TABLE identity.complainant (
    complainant_id        UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    case_person_id        UUID         NOT NULL REFERENCES identity.case_person(case_person_id),
    complaint_date        DATE,
    complaint_mode        VARCHAR(40)  DEFAULT 'IN_PERSON',
                          -- IN_PERSON, WRITTEN, PHONE, EMAIL, ONLINE, ZERO_FIR
    relation_to_victim    VARCHAR(80),
    is_self_complainant   BOOLEAN      NOT NULL DEFAULT FALSE,
    notes                 TEXT,
    created_at            TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at            TIMESTAMPTZ  NOT NULL DEFAULT now()
);
-- =============================================================================
-- 005_authz.sql
-- Authorization: roles, permissions, policies, case access, RLS groundwork
-- =============================================================================
-- Design principle:
--   Access is evaluated using the composite context:
--     Officer Identity
--     + Current Posting (station, rank, designation)
--     + Departmental Role
--     + Case Assignment + Case Role
--     + Document Classification
--     + Resource + Action
--   This file creates the tables that make that evaluation possible.
--   The application layer calls check_officer_case_access() (defined in
--   functions file) which queries these tables.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. SYSTEM ROLE — application-level roles (not case-specific)
--    e.g. SYSTEM_ADMIN, STATION_OFFICER, AUDITOR, READ_ONLY, etc.
--    These wrap sets of permissions for quick assignment.
-- ---------------------------------------------------------------------------
CREATE TABLE authz.system_role (
    role_id       UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    role_code     VARCHAR(60)  NOT NULL UNIQUE,
    role_name     VARCHAR(120) NOT NULL,
    description   TEXT,
    is_system     BOOLEAN      NOT NULL DEFAULT FALSE,  -- built-in, cannot be deleted
    is_active     BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by    UUID         REFERENCES identity.officer(officer_id)
);

INSERT INTO authz.system_role (role_code, role_name, description, is_system) VALUES
('SYS_ADMIN',        'System Administrator',    'Full system access',                           TRUE),
('SHO_ROLE',         'Station House Officer',   'Station-level supervisory access',             TRUE),
('IO_ROLE',          'Investigating Officer',   'Case investigation access',                    TRUE),
('MALKHANA_ROLE',    'Malkhana Custodian',       'Evidence custody management',                  TRUE),
('DUTY_OFFICER',     'Duty Officer',            'Duty officer access',                          TRUE),
('CYBER_OFFICER',    'Cyber Crime Officer',     'Digital evidence and cyber case access',       TRUE),
('FORENSIC_COORD',   'Forensic Coordinator',   'FSL request and report access',                TRUE),
('COURT_LIAISON',    'Court Liaison Officer',   'Court submission access',                      TRUE),
('AUDITOR_ROLE',     'Internal Auditor',        'Audit log access, no case modification',       TRUE),
('READ_ONLY_ROLE',   'Read Only',               'View-only access',                             TRUE),
('PROSECUTION',      'Prosecution Officer',     'Charge sheet and court submission access',     TRUE);

-- ---------------------------------------------------------------------------
-- 2. SYSTEM ROLE PERMISSION — many-to-many role ↔ permission
-- ---------------------------------------------------------------------------
CREATE TABLE authz.role_permission (
    role_permission_id  UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    role_id             UUID         NOT NULL REFERENCES authz.system_role(role_id),
    permission_id       UUID         NOT NULL REFERENCES reference.permission(permission_id),
    granted_by          UUID         REFERENCES identity.officer(officer_id),
    granted_at          TIMESTAMPTZ  NOT NULL DEFAULT now(),
    is_active           BOOLEAN      NOT NULL DEFAULT TRUE,
    UNIQUE (role_id, permission_id)
);

-- ---------------------------------------------------------------------------
-- 3. OFFICER SYSTEM ROLE — assign system roles to officers
-- ---------------------------------------------------------------------------
CREATE TABLE authz.officer_system_role (
    assignment_id   UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    officer_id      UUID         NOT NULL REFERENCES identity.officer(officer_id),
    role_id         UUID         NOT NULL REFERENCES authz.system_role(role_id),
    station_id      UUID         REFERENCES organisation.police_station(station_id),
                    -- NULL = global; non-NULL = scoped to that station
    granted_by      UUID         REFERENCES identity.officer(officer_id),
    granted_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    revoked_at      TIMESTAMPTZ,
    revoked_by      UUID         REFERENCES identity.officer(officer_id),
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    notes           TEXT,
    UNIQUE (officer_id, role_id, station_id)
);

CREATE INDEX idx_osr_officer  ON authz.officer_system_role(officer_id);
CREATE INDEX idx_osr_role     ON authz.officer_system_role(role_id);
CREATE INDEX idx_osr_station  ON authz.officer_system_role(station_id);

-- ---------------------------------------------------------------------------
-- 4. CASE ROLE PERMISSION — what each case role can do
--    This is the case-scoped permission set evaluated when an officer
--    accesses a specific case resource.
-- ---------------------------------------------------------------------------
CREATE TABLE authz.case_role_permission (
    crp_id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    case_role_id    UUID         NOT NULL REFERENCES reference.case_role(case_role_id),
    permission_id   UUID         NOT NULL REFERENCES reference.permission(permission_id),
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    UNIQUE (case_role_id, permission_id)
);

-- ---------------------------------------------------------------------------
-- 5. OFFICER CASE ASSIGNMENT — the single most important access control table.
--    An officer is explicitly assigned to a case with a specific case role.
--    Without an assignment record, an officer has NO case access (enforced
--    by the check_officer_case_access() function).
-- ---------------------------------------------------------------------------
CREATE TABLE authz.officer_case_assignment (
    assignment_id    UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    case_id          UUID         NOT NULL,  -- FK to case_mgmt.case added later
    officer_id       UUID         NOT NULL REFERENCES identity.officer(officer_id),
    case_role_id     UUID         NOT NULL REFERENCES reference.case_role(case_role_id),

    assigned_by      UUID         NOT NULL REFERENCES identity.officer(officer_id),
    assigned_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),

    start_date       DATE         NOT NULL DEFAULT CURRENT_DATE,
    end_date         DATE,        -- NULL = still active on case

    is_active        BOOLEAN      NOT NULL DEFAULT TRUE,

    -- Scope restricts access to a subset of resources within the case
    -- e.g. '{"resource_types": ["EVIDENCE","CUSTODY"]}' for Evidence Custodian
    scope            JSONB        NOT NULL DEFAULT '{}',

    reason           TEXT,
    notes            TEXT,

    -- Ensure a unique active assignment per officer per case per role
    CONSTRAINT chk_assignment_dates CHECK (end_date IS NULL OR end_date >= start_date)
);

CREATE UNIQUE INDEX idx_oca_unique_active
    ON authz.officer_case_assignment(case_id, officer_id, case_role_id)
    WHERE is_active = TRUE;

CREATE INDEX idx_oca_case     ON authz.officer_case_assignment(case_id);
CREATE INDEX idx_oca_officer  ON authz.officer_case_assignment(officer_id);
CREATE INDEX idx_oca_role     ON authz.officer_case_assignment(case_role_id);

-- ---------------------------------------------------------------------------
-- 6. ACCESS POLICY — named policies that can be applied to resources
--    Policies are evaluated server-side by the authorization service.
--    They reference permission codes and conditions as JSONB.
-- ---------------------------------------------------------------------------
CREATE TABLE authz.access_policy (
    policy_id        UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    policy_code      VARCHAR(80)  NOT NULL UNIQUE,
    policy_name      VARCHAR(150) NOT NULL,
    description      TEXT,
    effect           VARCHAR(10)  NOT NULL DEFAULT 'ALLOW' CHECK (effect IN ('ALLOW','DENY')),
    resource_type    VARCHAR(60),   -- CASE, EVIDENCE, DOCUMENT, etc.; NULL = all
    action           VARCHAR(60),   -- VIEW, EDIT, DOWNLOAD, etc.; NULL = all
    is_active        BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by       UUID         REFERENCES identity.officer(officer_id)
);

-- ---------------------------------------------------------------------------
-- 7. POLICY RULE — individual conditions within a policy
--    conditions JSONB allows flexible rule expression without schema changes.
--    Example: {"min_rank_level": 40, "requires_case_assignment": true}
-- ---------------------------------------------------------------------------
CREATE TABLE authz.policy_rule (
    rule_id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    policy_id        UUID         NOT NULL REFERENCES authz.access_policy(policy_id),
    rule_order       SMALLINT     NOT NULL DEFAULT 0,
    description      TEXT,
    conditions       JSONB        NOT NULL DEFAULT '{}',
    is_active        BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_policy_rule_policy ON authz.policy_rule(policy_id);

-- ---------------------------------------------------------------------------
-- 8. DOCUMENT ACCESS POLICY — classification-level access rules
--    Maps classification level to minimum required rank level or role.
-- ---------------------------------------------------------------------------
CREATE TABLE authz.document_access_policy (
    dap_id               UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    classification_code  VARCHAR(30)  NOT NULL REFERENCES reference.classification_level(level_code),
    min_rank_level       SMALLINT     NOT NULL DEFAULT 0,
    require_case_assignment BOOLEAN   NOT NULL DEFAULT FALSE,
    require_case_role    VARCHAR(60),  -- specific case role required, NULL = any
    allow_download       BOOLEAN      NOT NULL DEFAULT TRUE,
    require_audit_log    BOOLEAN      NOT NULL DEFAULT TRUE,
    notes                TEXT,
    is_active            BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at           TIMESTAMPTZ  NOT NULL DEFAULT now()
);

INSERT INTO authz.document_access_policy
    (classification_code, min_rank_level, require_case_assignment, require_case_role,
     allow_download, require_audit_log)
VALUES
('PUBLIC',           0,   FALSE, NULL,                    TRUE,  TRUE),
('INTERNAL',         10,  FALSE, NULL,                    TRUE,  TRUE),
('CONFIDENTIAL',     30,  TRUE,  NULL,                    TRUE,  TRUE),
('RESTRICTED',       40,  TRUE,  NULL,                    TRUE,  TRUE),
('HIGHLY_RESTRICTED',50,  TRUE,  'SUPERVISING_OFFICER',   FALSE, TRUE);

-- ---------------------------------------------------------------------------
-- 9. ROW-LEVEL SECURITY CONFIGURATION
--    We design RLS to be opt-in. To enable, run the statements in the
--    rls_enable section. The application must SET app.current_officer_id
--    before any query.
--
--    For the SIH MVP, RLS is prepared but not forced. The application-layer
--    authorization via check_officer_case_access() is the primary guard.
--    Enable RLS in production after thorough testing.
-- ---------------------------------------------------------------------------

-- Session variable used by RLS policies
-- SET app.current_officer_id = '<uuid>';
-- SET app.current_station_id  = '<uuid>';

-- RLS ENABLE SCRIPT (run separately in production):
-- ALTER TABLE case_mgmt.case              ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE evidence.evidence           ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE documents.document          ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE documents.document_version  ENABLE ROW LEVEL SECURITY;
--
-- CREATE POLICY case_access_policy ON case_mgmt.case
--     USING (
--         EXISTS (
--             SELECT 1 FROM authz.officer_case_assignment oca
--             WHERE oca.case_id = case_mgmt.case.case_id
--               AND oca.officer_id = current_setting('app.current_officer_id')::uuid
--               AND oca.is_active = TRUE
--         )
--         OR EXISTS (
--             SELECT 1 FROM identity.officer_posting op
--             JOIN organisation.police_station ps ON ps.station_id = op.police_station_id
--             WHERE op.officer_id = current_setting('app.current_officer_id')::uuid
--               AND op.is_current = TRUE
--               AND ps.station_id = case_mgmt.case.originating_station_id
--         )
--     );

-- ---------------------------------------------------------------------------
-- 10. PERMISSION SEED — assign permissions to case roles
--    PRIMARY_IO  → full investigation access
--    SUPERVISING_OFFICER → view all + close case
--    CASE_OWNER (SHO) → all permissions on case
--    EVIDENCE_CUSTODIAN → evidence + custody only
--    DIGITAL_EVIDENCE_OFFICER → digital evidence only
--    FORENSIC_COORDINATOR → FSL requests + reports
--    COURT_LIAISON → court submissions
--    CASE_REVIEWER → view only
--    AUDITOR → audit view
--    READ_ONLY → view only
-- ---------------------------------------------------------------------------

-- We use a DO block to resolve UUIDs at insert time
DO $$
DECLARE
    v_primary_io       UUID;
    v_asst_io          UUID;
    v_supervisor       UUID;
    v_case_owner       UUID;
    v_ev_custodian     UUID;
    v_dig_ev_officer   UUID;
    v_forensic_coord   UUID;
    v_court_liaison    UUID;
    v_case_reviewer    UUID;
    v_auditor          UUID;
    v_read_only        UUID;
BEGIN
    SELECT case_role_id INTO v_primary_io       FROM reference.case_role WHERE role_code = 'PRIMARY_IO';
    SELECT case_role_id INTO v_asst_io           FROM reference.case_role WHERE role_code = 'ASSISTANT_IO';
    SELECT case_role_id INTO v_supervisor        FROM reference.case_role WHERE role_code = 'SUPERVISING_OFFICER';
    SELECT case_role_id INTO v_case_owner        FROM reference.case_role WHERE role_code = 'CASE_OWNER';
    SELECT case_role_id INTO v_ev_custodian      FROM reference.case_role WHERE role_code = 'EVIDENCE_CUSTODIAN';
    SELECT case_role_id INTO v_dig_ev_officer    FROM reference.case_role WHERE role_code = 'DIGITAL_EVIDENCE_OFFICER';
    SELECT case_role_id INTO v_forensic_coord    FROM reference.case_role WHERE role_code = 'FORENSIC_COORDINATOR';
    SELECT case_role_id INTO v_court_liaison     FROM reference.case_role WHERE role_code = 'COURT_LIAISON';
    SELECT case_role_id INTO v_case_reviewer     FROM reference.case_role WHERE role_code = 'CASE_REVIEWER';
    SELECT case_role_id INTO v_auditor           FROM reference.case_role WHERE role_code = 'AUDITOR';
    SELECT case_role_id INTO v_read_only         FROM reference.case_role WHERE role_code = 'READ_ONLY';

    -- PRIMARY_IO — nearly full access
    INSERT INTO authz.case_role_permission (case_role_id, permission_id)
    SELECT v_primary_io, permission_id FROM reference.permission
    WHERE permission_code IN (
        'CASE_VIEW','CASE_EDIT','FIR_CREATE','FIR_VIEW','FIR_EDIT',
        'EVIDENCE_CREATE','EVIDENCE_VIEW','EVIDENCE_EDIT','EVIDENCE_TRANSFER','EVIDENCE_VERIFY',
        'DOCUMENT_UPLOAD','DOCUMENT_VIEW','DOCUMENT_DOWNLOAD','DOCUMENT_SIGN','DOCUMENT_VERSION_CREATE',
        'FORENSIC_REQUEST_CREATE','FORENSIC_REPORT_VIEW',
        'CUSTODY_VIEW','CUSTODY_TRANSFER','CASE_EXPORT'
    );

    -- ASSISTANT_IO
    INSERT INTO authz.case_role_permission (case_role_id, permission_id)
    SELECT v_asst_io, permission_id FROM reference.permission
    WHERE permission_code IN (
        'CASE_VIEW','FIR_VIEW',
        'EVIDENCE_CREATE','EVIDENCE_VIEW','EVIDENCE_EDIT','EVIDENCE_VERIFY',
        'DOCUMENT_UPLOAD','DOCUMENT_VIEW','DOCUMENT_DOWNLOAD','DOCUMENT_VERSION_CREATE',
        'FORENSIC_REPORT_VIEW','CUSTODY_VIEW','CUSTODY_TRANSFER'
    );

    -- SUPERVISING_OFFICER
    INSERT INTO authz.case_role_permission (case_role_id, permission_id)
    SELECT v_supervisor, permission_id FROM reference.permission
    WHERE permission_code IN (
        'CASE_VIEW','CASE_EDIT','CASE_CLOSE','CASE_ASSIGN','CASE_EXPORT',
        'FIR_VIEW','FIR_EDIT',
        'EVIDENCE_VIEW','EVIDENCE_VERIFY',
        'DOCUMENT_VIEW','DOCUMENT_DOWNLOAD','DOCUMENT_APPROVE','DOCUMENT_SIGN',
        'FORENSIC_REQUEST_CREATE','FORENSIC_REPORT_VIEW',
        'CUSTODY_VIEW','AUDIT_VIEW'
    );

    -- CASE_OWNER (SHO) — all permissions
    INSERT INTO authz.case_role_permission (case_role_id, permission_id)
    SELECT v_case_owner, permission_id FROM reference.permission;

    -- EVIDENCE_CUSTODIAN — evidence and custody only
    INSERT INTO authz.case_role_permission (case_role_id, permission_id)
    SELECT v_ev_custodian, permission_id FROM reference.permission
    WHERE permission_code IN (
        'CASE_VIEW','EVIDENCE_VIEW','EVIDENCE_EDIT','EVIDENCE_TRANSFER','EVIDENCE_VERIFY',
        'CUSTODY_VIEW','CUSTODY_TRANSFER','DOCUMENT_VIEW'
    );

    -- DIGITAL_EVIDENCE_OFFICER — digital evidence only
    INSERT INTO authz.case_role_permission (case_role_id, permission_id)
    SELECT v_dig_ev_officer, permission_id FROM reference.permission
    WHERE permission_code IN (
        'CASE_VIEW','EVIDENCE_VIEW','EVIDENCE_CREATE','EVIDENCE_EDIT','EVIDENCE_VERIFY',
        'FORENSIC_REQUEST_CREATE','FORENSIC_REPORT_VIEW',
        'DOCUMENT_UPLOAD','DOCUMENT_VIEW','DOCUMENT_DOWNLOAD','DOCUMENT_VERSION_CREATE',
        'CUSTODY_VIEW'
    );

    -- FORENSIC_COORDINATOR
    INSERT INTO authz.case_role_permission (case_role_id, permission_id)
    SELECT v_forensic_coord, permission_id FROM reference.permission
    WHERE permission_code IN (
        'CASE_VIEW','EVIDENCE_VIEW',
        'FORENSIC_REQUEST_CREATE','FORENSIC_REPORT_VIEW',
        'DOCUMENT_VIEW','DOCUMENT_DOWNLOAD','CUSTODY_VIEW'
    );

    -- COURT_LIAISON
    INSERT INTO authz.case_role_permission (case_role_id, permission_id)
    SELECT v_court_liaison, permission_id FROM reference.permission
    WHERE permission_code IN (
        'CASE_VIEW','FIR_VIEW',
        'EVIDENCE_VIEW','CUSTODY_VIEW',
        'DOCUMENT_VIEW','DOCUMENT_DOWNLOAD','DOCUMENT_SIGN',
        'FORENSIC_REPORT_VIEW','CASE_EXPORT'
    );

    -- CASE_REVIEWER — view only
    INSERT INTO authz.case_role_permission (case_role_id, permission_id)
    SELECT v_case_reviewer, permission_id FROM reference.permission
    WHERE permission_code IN (
        'CASE_VIEW','FIR_VIEW','EVIDENCE_VIEW','CUSTODY_VIEW',
        'DOCUMENT_VIEW','FORENSIC_REPORT_VIEW','AUDIT_VIEW'
    );

    -- AUDITOR — audit only
    INSERT INTO authz.case_role_permission (case_role_id, permission_id)
    SELECT v_auditor, permission_id FROM reference.permission
    WHERE permission_code IN (
        'CASE_VIEW','FIR_VIEW','EVIDENCE_VIEW','CUSTODY_VIEW',
        'DOCUMENT_VIEW','FORENSIC_REPORT_VIEW','AUDIT_VIEW'
    );

    -- READ_ONLY
    INSERT INTO authz.case_role_permission (case_role_id, permission_id)
    SELECT v_read_only, permission_id FROM reference.permission
    WHERE permission_code IN ('CASE_VIEW','FIR_VIEW','EVIDENCE_VIEW','DOCUMENT_VIEW');

END $$;

-- ---------------------------------------------------------------------------
-- 11. SYSTEM ROLE PERMISSION SEED — wire permissions to system roles
-- ---------------------------------------------------------------------------
DO $$
DECLARE
    v_admin     UUID;
    v_sho       UUID;
    v_io        UUID;
    v_malkhana  UUID;
    v_cyber     UUID;
    v_forensic  UUID;
    v_court     UUID;
    v_auditor   UUID;
    v_readonly  UUID;
    v_duty      UUID;
BEGIN
    SELECT role_id INTO v_admin    FROM authz.system_role WHERE role_code = 'SYS_ADMIN';
    SELECT role_id INTO v_sho      FROM authz.system_role WHERE role_code = 'SHO_ROLE';
    SELECT role_id INTO v_io       FROM authz.system_role WHERE role_code = 'IO_ROLE';
    SELECT role_id INTO v_malkhana FROM authz.system_role WHERE role_code = 'MALKHANA_ROLE';
    SELECT role_id INTO v_cyber    FROM authz.system_role WHERE role_code = 'CYBER_OFFICER';
    SELECT role_id INTO v_forensic FROM authz.system_role WHERE role_code = 'FORENSIC_COORD';
    SELECT role_id INTO v_court    FROM authz.system_role WHERE role_code = 'COURT_LIAISON';
    SELECT role_id INTO v_auditor  FROM authz.system_role WHERE role_code = 'AUDITOR_ROLE';
    SELECT role_id INTO v_readonly FROM authz.system_role WHERE role_code = 'READ_ONLY_ROLE';
    SELECT role_id INTO v_duty     FROM authz.system_role WHERE role_code = 'DUTY_OFFICER';

    -- SYS_ADMIN — all permissions
    INSERT INTO authz.role_permission (role_id, permission_id)
    SELECT v_admin, permission_id FROM reference.permission;

    -- SHO
    INSERT INTO authz.role_permission (role_id, permission_id)
    SELECT v_sho, permission_id FROM reference.permission
    WHERE permission_code IN (
        'CASE_CREATE','CASE_VIEW','CASE_EDIT','CASE_ASSIGN','CASE_CLOSE','CASE_TRANSFER','CASE_EXPORT',
        'FIR_CREATE','FIR_VIEW','FIR_EDIT',
        'EVIDENCE_CREATE','EVIDENCE_VIEW','EVIDENCE_EDIT','EVIDENCE_TRANSFER','EVIDENCE_VERIFY',
        'DOCUMENT_UPLOAD','DOCUMENT_VIEW','DOCUMENT_DOWNLOAD','DOCUMENT_SIGN','DOCUMENT_APPROVE',
        'DOCUMENT_VERSION_CREATE','FORENSIC_REQUEST_CREATE','FORENSIC_REPORT_VIEW',
        'CUSTODY_VIEW','CUSTODY_TRANSFER','AUDIT_VIEW'
    );

    -- IO_ROLE
    INSERT INTO authz.role_permission (role_id, permission_id)
    SELECT v_io, permission_id FROM reference.permission
    WHERE permission_code IN (
        'CASE_VIEW','CASE_EDIT','FIR_CREATE','FIR_VIEW','FIR_EDIT',
        'EVIDENCE_CREATE','EVIDENCE_VIEW','EVIDENCE_EDIT','EVIDENCE_TRANSFER','EVIDENCE_VERIFY',
        'DOCUMENT_UPLOAD','DOCUMENT_VIEW','DOCUMENT_DOWNLOAD','DOCUMENT_SIGN','DOCUMENT_VERSION_CREATE',
        'FORENSIC_REQUEST_CREATE','FORENSIC_REPORT_VIEW','CUSTODY_VIEW','CUSTODY_TRANSFER'
    );

    -- MALKHANA_ROLE
    INSERT INTO authz.role_permission (role_id, permission_id)
    SELECT v_malkhana, permission_id FROM reference.permission
    WHERE permission_code IN (
        'EVIDENCE_VIEW','EVIDENCE_EDIT','EVIDENCE_TRANSFER','EVIDENCE_VERIFY',
        'CUSTODY_VIEW','CUSTODY_TRANSFER','DOCUMENT_VIEW'
    );

    -- CYBER_OFFICER
    INSERT INTO authz.role_permission (role_id, permission_id)
    SELECT v_cyber, permission_id FROM reference.permission
    WHERE permission_code IN (
        'CASE_VIEW','CASE_EDIT',
        'EVIDENCE_CREATE','EVIDENCE_VIEW','EVIDENCE_EDIT','EVIDENCE_VERIFY',
        'FORENSIC_REQUEST_CREATE','FORENSIC_REPORT_VIEW',
        'DOCUMENT_UPLOAD','DOCUMENT_VIEW','DOCUMENT_DOWNLOAD','DOCUMENT_VERSION_CREATE',
        'CUSTODY_VIEW','CUSTODY_TRANSFER'
    );

    -- FORENSIC_COORD
    INSERT INTO authz.role_permission (role_id, permission_id)
    SELECT v_forensic, permission_id FROM reference.permission
    WHERE permission_code IN (
        'EVIDENCE_VIEW','FORENSIC_REQUEST_CREATE','FORENSIC_REPORT_VIEW',
        'DOCUMENT_VIEW','DOCUMENT_DOWNLOAD','CUSTODY_VIEW'
    );

    -- COURT_LIAISON
    INSERT INTO authz.role_permission (role_id, permission_id)
    SELECT v_court, permission_id FROM reference.permission
    WHERE permission_code IN (
        'CASE_VIEW','FIR_VIEW','EVIDENCE_VIEW','CUSTODY_VIEW',
        'DOCUMENT_VIEW','DOCUMENT_DOWNLOAD','DOCUMENT_SIGN','FORENSIC_REPORT_VIEW','CASE_EXPORT'
    );

    -- AUDITOR
    INSERT INTO authz.role_permission (role_id, permission_id)
    SELECT v_auditor, permission_id FROM reference.permission
    WHERE permission_code IN (
        'CASE_VIEW','FIR_VIEW','EVIDENCE_VIEW','DOCUMENT_VIEW',
        'FORENSIC_REPORT_VIEW','CUSTODY_VIEW','AUDIT_VIEW'
    );

    -- READ_ONLY
    INSERT INTO authz.role_permission (role_id, permission_id)
    SELECT v_readonly, permission_id FROM reference.permission
    WHERE permission_code IN ('CASE_VIEW','FIR_VIEW','EVIDENCE_VIEW','DOCUMENT_VIEW');

    -- DUTY_OFFICER
    INSERT INTO authz.role_permission (role_id, permission_id)
    SELECT v_duty, permission_id FROM reference.permission
    WHERE permission_code IN (
        'CASE_VIEW','CASE_CREATE','FIR_CREATE','FIR_VIEW',
        'EVIDENCE_VIEW','DOCUMENT_VIEW','CUSTODY_VIEW'
    );

END $$;
-- =============================================================================
-- 006_case_management.sql
-- Cases, FIRs, case transfers, case events, timeline
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. CASE — the central object of the entire system
--    case_id UUID is immutable.
--    case_number is human-readable and generated by generate_case_number().
-- ---------------------------------------------------------------------------
CREATE TABLE case_mgmt.case (
    case_id                  UUID         PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Human-readable case number: CASE-KA-BLR-CEN-2026-00001247
    -- Generated by trigger on INSERT via generate_case_number()
    case_number              VARCHAR(60)  NOT NULL UNIQUE,

    -- Station references
    originating_station_id   UUID         NOT NULL REFERENCES organisation.police_station(station_id),
    current_station_id       UUID         NOT NULL REFERENCES organisation.police_station(station_id),

    -- Classification
    case_type_id             UUID         NOT NULL REFERENCES reference.case_type(case_type_id),
    case_status_code         VARCHAR(40)  NOT NULL DEFAULT 'FIR_REGISTERED'
                                          REFERENCES reference.case_status(status_code),
    priority                 VARCHAR(20)  NOT NULL DEFAULT 'NORMAL'
                                          CHECK (priority IN ('LOW','NORMAL','HIGH','CRITICAL')),
    confidentiality_code     VARCHAR(30)  NOT NULL DEFAULT 'INTERNAL'
                                          REFERENCES reference.classification_level(level_code),

    -- Key dates
    incident_date            TIMESTAMPTZ,
    incident_end_date        TIMESTAMPTZ,
    opened_at                TIMESTAMPTZ  NOT NULL DEFAULT now(),
    closed_at                TIMESTAMPTZ,
    last_activity_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),

    -- Key officers (convenience denormalisation — canonical data in officer_case_assignment)
    primary_io_id            UUID         REFERENCES identity.officer(officer_id),
    supervising_officer_id   UUID         REFERENCES identity.officer(officer_id),
    created_by               UUID         NOT NULL REFERENCES identity.officer(officer_id),

    -- Incident details
    incident_description     TEXT,
    incident_location        TEXT,
    incident_latitude        NUMERIC(10,7),
    incident_longitude       NUMERIC(10,7),
    beat_id                  UUID         REFERENCES organisation.beat(beat_id),

    -- Legal references
    ipc_sections             TEXT,         -- comma-separated (informational)
    bnss_sections            TEXT,         -- Bharatiya Nagarik Suraksha Sanhita
    other_acts               TEXT,

    -- Court tracking
    court_case_number        VARCHAR(80),
    court_id                 UUID         REFERENCES organisation.court(court_id),

    -- Flags
    is_zero_fir              BOOLEAN      NOT NULL DEFAULT FALSE,
    is_transferred           BOOLEAN      NOT NULL DEFAULT FALSE,
    is_sensitive             BOOLEAN      NOT NULL DEFAULT FALSE,
    legal_hold               BOOLEAN      NOT NULL DEFAULT FALSE,

    -- Extensible metadata (state-specific fields, special scheme codes, etc.)
    metadata                 JSONB        NOT NULL DEFAULT '{}',

    -- Soft delete
    deleted_at               TIMESTAMPTZ,
    deleted_by               UUID         REFERENCES identity.officer(officer_id),
    deletion_reason          TEXT,

    updated_at               TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_by               UUID         REFERENCES identity.officer(officer_id),
    version_no               INTEGER      NOT NULL DEFAULT 1,

    CONSTRAINT chk_case_closed CHECK (
        closed_at IS NULL OR closed_at >= opened_at
    )
);

CREATE INDEX idx_case_originating_station ON case_mgmt.case(originating_station_id);
CREATE INDEX idx_case_current_station     ON case_mgmt.case(current_station_id);
CREATE INDEX idx_case_status              ON case_mgmt.case(case_status_code);
CREATE INDEX idx_case_type                ON case_mgmt.case(case_type_id);
CREATE INDEX idx_case_primary_io          ON case_mgmt.case(primary_io_id);
CREATE INDEX idx_case_opened_at           ON case_mgmt.case(opened_at);
CREATE INDEX idx_case_number_trgm         ON case_mgmt.case USING gin(case_number gin_trgm_ops);
CREATE INDEX idx_case_metadata            ON case_mgmt.case USING gin(metadata);

-- Add deferred FK from identity.case_person back to case
ALTER TABLE identity.case_person
    ADD CONSTRAINT fk_case_person_case
    FOREIGN KEY (case_id)
    REFERENCES case_mgmt.case(case_id)
    DEFERRABLE INITIALLY DEFERRED;

-- Add deferred FK from authz.officer_case_assignment back to case
ALTER TABLE authz.officer_case_assignment
    ADD CONSTRAINT fk_oca_case
    FOREIGN KEY (case_id)
    REFERENCES case_mgmt.case(case_id)
    DEFERRABLE INITIALLY DEFERRED;

-- ---------------------------------------------------------------------------
-- 2. FIR — First Information Report
--    A Case may have exactly one primary FIR (plus possibly a Zero FIR parent).
--    Zero FIR lineage is tracked via zero_fir_parent_id.
-- ---------------------------------------------------------------------------
CREATE TABLE case_mgmt.fir (
    fir_id                   UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    case_id                  UUID         NOT NULL REFERENCES case_mgmt.case(case_id),

    -- FIR number: station-assigned human-readable number
    fir_number               VARCHAR(40)  NOT NULL,
    fir_year                 SMALLINT     NOT NULL,
    station_id               UUID         NOT NULL REFERENCES organisation.police_station(station_id),

    fir_type                 VARCHAR(30)  NOT NULL DEFAULT 'REGULAR'
                                          CHECK (fir_type IN ('REGULAR','ZERO_FIR','RE_REGISTERED','TRANSFERRED')),

    -- Zero FIR lineage: if this FIR was born from a Zero FIR at another station
    zero_fir_parent_id       UUID         REFERENCES case_mgmt.fir(fir_id),

    -- Complainant (may be anonymous for suo motu)
    complainant_person_id    UUID         REFERENCES identity.person(person_id),
    is_anonymous             BOOLEAN      NOT NULL DEFAULT FALSE,

    -- Incident
    incident_date            TIMESTAMPTZ  NOT NULL,
    incident_end_date        TIMESTAMPTZ,
    incident_location        TEXT         NOT NULL,
    incident_description     TEXT         NOT NULL,

    -- Sections
    ipc_sections             TEXT,
    bnss_sections            TEXT,
    other_act_sections       TEXT,

    -- Registration
    registered_by            UUID         NOT NULL REFERENCES identity.officer(officer_id),
    registered_at            TIMESTAMPTZ  NOT NULL DEFAULT now(),

    -- Transfer details (used when fir_type = TRANSFERRED or ZERO_FIR)
    transferred_to_station_id UUID        REFERENCES organisation.police_station(station_id),
    transferred_at            TIMESTAMPTZ,
    transfer_reason_code      VARCHAR(60) REFERENCES reference.transfer_reason(reason_code),

    -- Status
    fir_status               VARCHAR(40)  NOT NULL DEFAULT 'REGISTERED'
                                          CHECK (fir_status IN (
                                              'REGISTERED','TRANSFERRED','RE_REGISTERED',
                                              'CHARGE_SHEET_FILED','CLOSED','STAYED')),

    -- Document reference (the uploaded FIR PDF)
    document_id              UUID,        -- FK to documents.document added after doc schema

    -- Soft delete protection — FIRs cannot be deleted, only marked
    is_active                BOOLEAN      NOT NULL DEFAULT TRUE,

    created_at               TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at               TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_by               UUID         REFERENCES identity.officer(officer_id),

    -- Unique FIR number per station per year
    UNIQUE (station_id, fir_number, fir_year)
);

CREATE INDEX idx_fir_case        ON case_mgmt.fir(case_id);
CREATE INDEX idx_fir_station     ON case_mgmt.fir(station_id);
CREATE INDEX idx_fir_registered  ON case_mgmt.fir(registered_at);
CREATE INDEX idx_fir_parent      ON case_mgmt.fir(zero_fir_parent_id);

-- ---------------------------------------------------------------------------
-- 3. CASE TRANSFER — captures every inter-station or inter-unit case transfer
-- ---------------------------------------------------------------------------
CREATE TABLE case_mgmt.case_transfer (
    transfer_id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    case_id                  UUID         NOT NULL REFERENCES case_mgmt.case(case_id),

    -- Source
    source_station_id        UUID         NOT NULL REFERENCES organisation.police_station(station_id),
    source_fir_id            UUID         REFERENCES case_mgmt.fir(fir_id),

    -- Destination
    dest_station_id          UUID         NOT NULL REFERENCES organisation.police_station(station_id),
    dest_fir_id              UUID         REFERENCES case_mgmt.fir(fir_id),  -- assigned after re-reg

    reason_code              VARCHAR(60)  REFERENCES reference.transfer_reason(reason_code),
    reason_detail            TEXT,

    transfer_order_no        VARCHAR(80),
    transfer_order_date      DATE,
    transfer_order_document  UUID,        -- FK to document after doc schema

    initiated_by             UUID         NOT NULL REFERENCES identity.officer(officer_id),
    approved_by              UUID         REFERENCES identity.officer(officer_id),
    approved_at              TIMESTAMPTZ,

    transfer_timestamp       TIMESTAMPTZ  NOT NULL DEFAULT now(),

    transfer_status          VARCHAR(30)  NOT NULL DEFAULT 'PENDING'
                                          CHECK (transfer_status IN (
                                              'PENDING','APPROVED','COMPLETED','REJECTED','CANCELLED')),

    notes                    TEXT,
    created_at               TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_transfer_case        ON case_mgmt.case_transfer(case_id);
CREATE INDEX idx_transfer_source_stn  ON case_mgmt.case_transfer(source_station_id);
CREATE INDEX idx_transfer_dest_stn    ON case_mgmt.case_transfer(dest_station_id);

-- ---------------------------------------------------------------------------
-- 4. CASE EVENT — immutable chronological event log for a case
--    Every significant event in a case lifecycle is recorded here.
--    Records are append-only (enforced by trigger — see functions file).
-- ---------------------------------------------------------------------------
CREATE TABLE case_mgmt.case_event (
    event_id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    case_id           UUID         NOT NULL REFERENCES case_mgmt.case(case_id),
    event_type_code   VARCHAR(60)  NOT NULL REFERENCES reference.case_event_type(event_type_code),

    event_timestamp   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    recorded_by       UUID         NOT NULL REFERENCES identity.officer(officer_id),

    title             VARCHAR(200),
    description       TEXT,

    -- Optional links to related entities
    related_fir_id        UUID    REFERENCES case_mgmt.fir(fir_id),
    related_evidence_id   UUID,   -- FK added after evidence schema
    related_document_id   UUID,   -- FK added after document schema
    related_person_id     UUID    REFERENCES identity.person(person_id),
    related_officer_id    UUID    REFERENCES identity.officer(officer_id),

    location          TEXT,
    latitude          NUMERIC(10,7),
    longitude         NUMERIC(10,7),

    -- Extensible fields
    metadata          JSONB        NOT NULL DEFAULT '{}',

    -- Immutability: no UPDATE or DELETE allowed (enforced by trigger)
    created_at        TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_case_event_case      ON case_mgmt.case_event(case_id);
CREATE INDEX idx_case_event_type      ON case_mgmt.case_event(event_type_code);
CREATE INDEX idx_case_event_timestamp ON case_mgmt.case_event(event_timestamp);
CREATE INDEX idx_case_event_officer   ON case_mgmt.case_event(recorded_by);

-- ---------------------------------------------------------------------------
-- 5. CASE SEQUENCE COUNTER — used by generate_case_number()
--    One row per (state_code, station_code, year).
-- ---------------------------------------------------------------------------
CREATE TABLE case_mgmt.case_number_sequence (
    seq_id        UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    state_code    CHAR(2)      NOT NULL,
    station_code  VARCHAR(60)  NOT NULL,
    year          SMALLINT     NOT NULL,
    last_seq      INTEGER      NOT NULL DEFAULT 0,
    UNIQUE (state_code, station_code, year)
);

-- ---------------------------------------------------------------------------
-- 6. FIR SEQUENCE COUNTER — FIR numbers per station per year
-- ---------------------------------------------------------------------------
CREATE TABLE case_mgmt.fir_number_sequence (
    seq_id        UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    station_id    UUID         NOT NULL REFERENCES organisation.police_station(station_id),
    year          SMALLINT     NOT NULL,
    last_seq      INTEGER      NOT NULL DEFAULT 0,
    UNIQUE (station_id, year)
);
-- =============================================================================
-- 007_investigation.sql
-- Investigation tasks, case diary, timeline, case notes
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. INVESTIGATION — one investigation record per case
--    Tracks overall investigation progress and IO assignment history.
-- ---------------------------------------------------------------------------
CREATE TABLE investigation.investigation (
    investigation_id      UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    case_id               UUID         NOT NULL UNIQUE REFERENCES case_mgmt.case(case_id),

    investigation_status  VARCHAR(40)  NOT NULL DEFAULT 'INITIATED'
                                       CHECK (investigation_status IN (
                                           'INITIATED','ONGOING','SUSPENDED',
                                           'COMPLETED','REFERRED','CLOSED')),

    -- Primary Investigating Officer (redundant with case assignment for quick access)
    primary_io_id         UUID         REFERENCES identity.officer(officer_id),

    started_at            TIMESTAMPTZ  NOT NULL DEFAULT now(),
    completed_at          TIMESTAMPTZ,
    deadline_date         DATE,

    -- Investigation summary / progress notes
    summary               TEXT,
    findings              TEXT,

    -- Charge sheet
    charge_sheet_prepared BOOLEAN      NOT NULL DEFAULT FALSE,
    charge_sheet_date     DATE,
    charge_sheet_document_id UUID,     -- FK to document added after doc schema

    created_at            TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at            TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_by            UUID         REFERENCES identity.officer(officer_id),
    version_no            INTEGER      NOT NULL DEFAULT 1
);

CREATE INDEX idx_investigation_case   ON investigation.investigation(case_id);
CREATE INDEX idx_investigation_io     ON investigation.investigation(primary_io_id);
CREATE INDEX idx_investigation_status ON investigation.investigation(investigation_status);

-- ---------------------------------------------------------------------------
-- 2. CASE DIARY — official investigation diary (henceforth "CD")
--    Each entry is immutable once created.
--    Modelled after CrPC Section 172 case diary entries.
--    New corrections must be new entries, not edits to existing ones.
-- ---------------------------------------------------------------------------
CREATE TABLE investigation.case_diary (
    diary_id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    case_id               UUID         NOT NULL REFERENCES case_mgmt.case(case_id),
    investigation_id      UUID         REFERENCES investigation.investigation(investigation_id),

    entry_number          INTEGER      NOT NULL,   -- sequential within case
    entry_date            DATE         NOT NULL DEFAULT CURRENT_DATE,
    entry_time            TIMETZ       NOT NULL DEFAULT now(),
    entry_timestamp       TIMESTAMPTZ  NOT NULL DEFAULT now(),

    officer_id            UUID         NOT NULL REFERENCES identity.officer(officer_id),

    -- Content
    subject               VARCHAR(300) NOT NULL,
    content               TEXT         NOT NULL,

    -- Was a previous entry corrected?
    corrects_entry_id     UUID         REFERENCES investigation.case_diary(diary_id),
    correction_reason     TEXT,

    -- Location of the investigation activity described
    location              TEXT,

    -- Reference to uploaded document version (scanned CD page)
    document_version_id   UUID,        -- FK to documents.document_version after doc schema

    -- Immutability flag — set TRUE by trigger on INSERT
    is_finalized          BOOLEAN      NOT NULL DEFAULT TRUE,

    created_at            TIMESTAMPTZ  NOT NULL DEFAULT now(),

    UNIQUE (case_id, entry_number)
);

CREATE INDEX idx_diary_case      ON investigation.case_diary(case_id);
CREATE INDEX idx_diary_officer   ON investigation.case_diary(officer_id);
CREATE INDEX idx_diary_date      ON investigation.case_diary(entry_date);

-- ---------------------------------------------------------------------------
-- 3. INVESTIGATION TASK — discrete tasks assigned during investigation
--    Examples: "Record statement of witness A",
--              "Collect CCTV footage from Mall B",
--              "Send mobile phone to FSL"
-- ---------------------------------------------------------------------------
CREATE TABLE investigation.investigation_task (
    task_id             UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    investigation_id    UUID         NOT NULL REFERENCES investigation.investigation(investigation_id),
    case_id             UUID         NOT NULL REFERENCES case_mgmt.case(case_id),

    task_title          VARCHAR(300) NOT NULL,
    task_description    TEXT,
    task_type           VARCHAR(60)  NOT NULL DEFAULT 'GENERAL'
                                     CHECK (task_type IN (
                                         'GENERAL','WITNESS_STATEMENT','SEARCH',
                                         'SEIZURE','ARREST','FSL_SUBMISSION',
                                         'CCTV_COLLECTION','DIGITAL_FORENSICS',
                                         'SURVEILLANCE','RAID','COURT_APPEARANCE',
                                         'DOCUMENT_FILING','OTHER')),

    assigned_to         UUID         REFERENCES identity.officer(officer_id),
    assigned_by         UUID         REFERENCES identity.officer(officer_id),
    assigned_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),

    due_date            DATE,
    priority            VARCHAR(20)  NOT NULL DEFAULT 'NORMAL'
                                     CHECK (priority IN ('LOW','NORMAL','HIGH','URGENT')),

    task_status         VARCHAR(30)  NOT NULL DEFAULT 'PENDING'
                                     CHECK (task_status IN (
                                         'PENDING','IN_PROGRESS','COMPLETED',
                                         'CANCELLED','DEFERRED')),

    completed_at        TIMESTAMPTZ,
    completed_by        UUID         REFERENCES identity.officer(officer_id),
    completion_notes    TEXT,

    -- Related entities
    related_evidence_id UUID,        -- FK added after evidence schema
    related_person_id   UUID         REFERENCES identity.person(person_id),

    created_at          TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_task_investigation ON investigation.investigation_task(investigation_id);
CREATE INDEX idx_task_case          ON investigation.investigation_task(case_id);
CREATE INDEX idx_task_assigned_to   ON investigation.investigation_task(assigned_to);
CREATE INDEX idx_task_status        ON investigation.investigation_task(task_status);
CREATE INDEX idx_task_due_date      ON investigation.investigation_task(due_date);

-- ---------------------------------------------------------------------------
-- 4. CASE TIMELINE — denormalised read model assembled from case_events,
--    diary entries and investigation tasks for fast API response.
--    Populated and kept fresh by triggers on the source tables.
-- ---------------------------------------------------------------------------
CREATE TABLE investigation.case_timeline (
    timeline_id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    case_id               UUID         NOT NULL REFERENCES case_mgmt.case(case_id),

    event_timestamp       TIMESTAMPTZ  NOT NULL,
    event_category        VARCHAR(40)  NOT NULL
                                       CHECK (event_category IN (
                                           'CASE_EVENT','DIARY_ENTRY','TASK',
                                           'EVIDENCE_EVENT','CUSTODY_EVENT',
                                           'DOCUMENT_EVENT','FSL_EVENT',
                                           'COURT_EVENT','AUDIT_EVENT')),

    title                 VARCHAR(300) NOT NULL,
    description           TEXT,
    officer_id            UUID         REFERENCES identity.officer(officer_id),
    officer_name          VARCHAR(200),   -- denormalised for display

    -- Polymorphic source reference
    source_table          VARCHAR(80),
    source_id             UUID,

    created_at            TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_timeline_case      ON investigation.case_timeline(case_id);
CREATE INDEX idx_timeline_timestamp ON investigation.case_timeline(case_id, event_timestamp DESC);
CREATE INDEX idx_timeline_category  ON investigation.case_timeline(event_category);

-- ---------------------------------------------------------------------------
-- 5. SCENE OF CRIME — record physical crime scene details
-- ---------------------------------------------------------------------------
CREATE TABLE investigation.scene_of_crime (
    scene_id             UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    case_id              UUID         NOT NULL REFERENCES case_mgmt.case(case_id),

    scene_name           VARCHAR(200) NOT NULL,
    address              TEXT,
    latitude             NUMERIC(10,7),
    longitude            NUMERIC(10,7),
    geom_wkt             TEXT,

    scene_type           VARCHAR(60)  DEFAULT 'PRIMARY',
                         -- PRIMARY, SECONDARY, DISPOSAL, APPROACH, OTHER

    visited_at           TIMESTAMPTZ,
    visited_by           UUID         REFERENCES identity.officer(officer_id),

    description          TEXT,
    sketch_document_id   UUID,        -- FK to document after doc schema

    is_preserved         BOOLEAN      NOT NULL DEFAULT FALSE,
    preservation_notes   TEXT,

    created_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at           TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_scene_case ON investigation.scene_of_crime(case_id);

-- ---------------------------------------------------------------------------
-- 6. CASE NOTE — informal notes by any assigned officer
--    Not as formal as case diary but useful for internal coordination.
-- ---------------------------------------------------------------------------
CREATE TABLE investigation.case_note (
    note_id       UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    case_id       UUID         NOT NULL REFERENCES case_mgmt.case(case_id),
    officer_id    UUID         NOT NULL REFERENCES identity.officer(officer_id),
    note_text     TEXT         NOT NULL,
    is_internal   BOOLEAN      NOT NULL DEFAULT TRUE,  -- internal = not sharable outside station
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),

    -- Notes cannot be deleted; superseded notes should be replaced with new ones
    is_superseded BOOLEAN      NOT NULL DEFAULT FALSE,
    superseded_by UUID         REFERENCES investigation.case_note(note_id)
);

CREATE INDEX idx_note_case    ON investigation.case_note(case_id);
CREATE INDEX idx_note_officer ON investigation.case_note(officer_id);
CREATE INDEX idx_note_created ON investigation.case_note(created_at);
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
-- =============================================================================
-- 012_integrity.sql
-- Document and evidence integrity verification, hash records, alerts
-- =============================================================================
-- Purpose:
--   This schema answers the two critical questions:
--     1. "Is this document the exact version that was finalized?"
--     2. "Has the file changed since finalization?"
--   It also supports the QR / document-passport concept and raises
--   integrity alerts when hash mismatches are detected.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. INTEGRITY RECORD — master hash record for any verifiable entity
--    Created at the moment of finalization/sealing.
--    One record per (resource_type, resource_id, version).
--    Records are append-only; never updated.
-- ---------------------------------------------------------------------------
CREATE TABLE integrity.integrity_record (
    integrity_id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),

    -- What is being protected
    resource_type         VARCHAR(40)  NOT NULL
                                       CHECK (resource_type IN (
                                           'DOCUMENT_VERSION','EVIDENCE',
                                           'DIGITAL_EVIDENCE','FORENSIC_IMAGE',
                                           'CUSTODY_EVENT','AUDIT_EVENT')),
    resource_id           UUID         NOT NULL,

    -- The hash at time of finalization
    hash_value            VARCHAR(128) NOT NULL,
    hash_algorithm        VARCHAR(20)  NOT NULL DEFAULT 'SHA256'
                                       REFERENCES reference.hash_algorithm(algo_code),

    -- Secondary hash for extra assurance
    secondary_hash        VARCHAR(128),
    secondary_algorithm   VARCHAR(20)  REFERENCES reference.hash_algorithm(algo_code),

    -- Who created this record and when
    recorded_by           UUID         NOT NULL REFERENCES identity.officer(officer_id),
    recorded_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),

    -- Case and station context
    case_id               UUID         REFERENCES case_mgmt.case(case_id),
    station_id            UUID         REFERENCES organisation.police_station(station_id),

    -- Current verification status
    verification_status   VARCHAR(30)  NOT NULL DEFAULT 'UNVERIFIED'
                                       CHECK (verification_status IN (
                                           'UNVERIFIED','VERIFIED_INTACT',
                                           'HASH_MISMATCH','SIGNATURE_INVALID',
                                           'COMPROMISED')),
    last_verified_at      TIMESTAMPTZ,
    last_verified_by      UUID         REFERENCES identity.officer(officer_id),

    -- QR / document passport payload stored as JSONB
    -- Allows offline verification: scan QR → get this JSON → verify hash
    passport_payload      JSONB        NOT NULL DEFAULT '{}',

    -- Immutability: no UPDATE or DELETE (trigger enforced)
    created_at            TIMESTAMPTZ  NOT NULL DEFAULT now(),

    UNIQUE (resource_type, resource_id)
);

CREATE INDEX idx_integrity_resource    ON integrity.integrity_record(resource_type, resource_id);
CREATE INDEX idx_integrity_case        ON integrity.integrity_record(case_id);
CREATE INDEX idx_integrity_hash        ON integrity.integrity_record(hash_value);
CREATE INDEX idx_integrity_status      ON integrity.integrity_record(verification_status);
CREATE INDEX idx_integrity_passport    ON integrity.integrity_record USING gin(passport_payload);

-- ---------------------------------------------------------------------------
-- 2. VERIFICATION EVENT — each time a document/evidence is verified
--    Captures the result of hash re-computation against stored hash.
-- ---------------------------------------------------------------------------
CREATE TABLE integrity.verification_event (
    verification_id       UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    integrity_id          UUID         NOT NULL REFERENCES integrity.integrity_record(integrity_id),

    resource_type         VARCHAR(40)  NOT NULL,
    resource_id           UUID         NOT NULL,

    -- Verification details
    verification_method   VARCHAR(40)  NOT NULL DEFAULT 'HASH_COMPARISON'
                                       CHECK (verification_method IN (
                                           'HASH_COMPARISON','SIGNATURE_VERIFICATION',
                                           'MANUAL','AUTOMATED')),

    -- Hash computed at time of this verification
    computed_hash         VARCHAR(128) NOT NULL,
    stored_hash           VARCHAR(128) NOT NULL,
    hash_algorithm        VARCHAR(20)  NOT NULL DEFAULT 'SHA256',

    -- Result
    result                VARCHAR(30)  NOT NULL
                                       CHECK (result IN (
                                           'INTACT','HASH_MISMATCH',
                                           'SIGNATURE_INVALID','ERROR')),
    result_detail         TEXT,

    -- Who verified
    verified_by           UUID         NOT NULL REFERENCES identity.officer(officer_id),
    verified_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),

    -- Session and device context
    session_id            UUID         REFERENCES identity.officer_session(session_id),
    ip_address            INET,

    -- Alert raised?
    alert_raised          BOOLEAN      NOT NULL DEFAULT FALSE,
    alert_id              UUID,        -- FK to integrity_alert added below

    created_at            TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_ver_event_integrity ON integrity.verification_event(integrity_id);
CREATE INDEX idx_ver_event_resource  ON integrity.verification_event(resource_type, resource_id);
CREATE INDEX idx_ver_event_result    ON integrity.verification_event(result);
CREATE INDEX idx_ver_event_time      ON integrity.verification_event(verified_at);

-- ---------------------------------------------------------------------------
-- 3. INTEGRITY ALERT — raised when verification fails
--    Critical events that require immediate attention.
-- ---------------------------------------------------------------------------
CREATE TABLE integrity.integrity_alert (
    alert_id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    integrity_id          UUID         NOT NULL REFERENCES integrity.integrity_record(integrity_id),
    verification_id       UUID         REFERENCES integrity.verification_event(verification_id),

    resource_type         VARCHAR(40)  NOT NULL,
    resource_id           UUID         NOT NULL,
    case_id               UUID         REFERENCES case_mgmt.case(case_id),

    alert_type            VARCHAR(40)  NOT NULL
                                       CHECK (alert_type IN (
                                           'HASH_MISMATCH','SIGNATURE_INVALID',
                                           'UNEXPECTED_MODIFICATION',
                                           'UNAUTHORIZED_ACCESS',
                                           'AUDIT_CHAIN_BROKEN',
                                           'CUSTODY_SEAL_BROKEN',
                                           'OTHER')),
    severity              VARCHAR(20)  NOT NULL DEFAULT 'CRITICAL'
                                       CHECK (severity IN ('LOW','MEDIUM','HIGH','CRITICAL')),

    alert_title           VARCHAR(300) NOT NULL,
    alert_description     TEXT         NOT NULL,

    -- Expected vs actual values
    expected_value        TEXT,
    actual_value          TEXT,

    -- Who detected this
    detected_by           UUID         REFERENCES identity.officer(officer_id),
    detected_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),

    -- Resolution
    alert_status          VARCHAR(30)  NOT NULL DEFAULT 'OPEN'
                                       CHECK (alert_status IN (
                                           'OPEN','ACKNOWLEDGED','INVESTIGATING',
                                           'RESOLVED','FALSE_POSITIVE')),
    resolved_by           UUID         REFERENCES identity.officer(officer_id),
    resolved_at           TIMESTAMPTZ,
    resolution_notes      TEXT,

    -- Notification sent?
    notification_sent     BOOLEAN      NOT NULL DEFAULT FALSE,
    notified_officers     JSONB        NOT NULL DEFAULT '[]',

    created_at            TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at            TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_alert_integrity  ON integrity.integrity_alert(integrity_id);
CREATE INDEX idx_alert_case       ON integrity.integrity_alert(case_id);
CREATE INDEX idx_alert_type       ON integrity.integrity_alert(alert_type);
CREATE INDEX idx_alert_severity   ON integrity.integrity_alert(severity);
CREATE INDEX idx_alert_status     ON integrity.integrity_alert(alert_status);
CREATE INDEX idx_alert_detected   ON integrity.integrity_alert(detected_at);

-- Back-fill the alert FK on verification_event
ALTER TABLE integrity.verification_event
    ADD CONSTRAINT fk_ver_alert
    FOREIGN KEY (alert_id)
    REFERENCES integrity.integrity_alert(alert_id)
    DEFERRABLE INITIALLY DEFERRED;

-- ---------------------------------------------------------------------------
-- 4. DOCUMENT PASSPORT — QR-scannable verification passport for a document version
--    Generated when a document is finalized.
--    Contains enough data to verify the document offline.
-- ---------------------------------------------------------------------------
CREATE TABLE integrity.document_passport (
    passport_id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id           UUID         NOT NULL REFERENCES documents.document(document_id),
    version_id            UUID         NOT NULL UNIQUE REFERENCES documents.document_version(version_id),
    integrity_id          UUID         NOT NULL REFERENCES integrity.integrity_record(integrity_id),

    -- The unique passport code embedded in the QR
    passport_code         VARCHAR(80)  NOT NULL UNIQUE,

    -- Payload embedded in QR (JSON string, also stored in integrity_record.passport_payload)
    qr_payload            JSONB        NOT NULL,

    -- QR image stored in object storage
    qr_image_object_id    VARCHAR(255),
    qr_image_path         TEXT,

    issued_by             UUID         NOT NULL REFERENCES identity.officer(officer_id),
    issued_at             TIMESTAMPTZ  NOT NULL DEFAULT now(),

    is_active             BOOLEAN      NOT NULL DEFAULT TRUE,
    revoked_at            TIMESTAMPTZ,
    revoked_by            UUID         REFERENCES identity.officer(officer_id),
    revocation_reason     TEXT,

    created_at            TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_passport_document ON integrity.document_passport(document_id);
CREATE INDEX idx_passport_version  ON integrity.document_passport(version_id);
CREATE INDEX idx_passport_code     ON integrity.document_passport(passport_code);
-- =============================================================================
-- 013_audit.sql
-- Tamper-evident audit trail with cryptographic hash chain
-- =============================================================================
-- Design:
--   Every sensitive action produces one AuditEvent row.
--   Each row contains:
--     hash = SHA-256( previous_hash || event_data )
--   This forms a linked chain. Tampering with any row breaks the chain,
--   detectable by verify_audit_chain().
--
--   The chain is PER-CASE for case-related events, and GLOBAL for system events.
--   Records are append-only — UPDATE and DELETE are blocked by trigger.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. AUDIT EVENT — primary tamper-evident audit record
-- ---------------------------------------------------------------------------
CREATE TABLE audit.audit_event (
    audit_id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Chain references
    chain_id              UUID         NOT NULL,
                          -- Case UUID for case events; a fixed GLOBAL_CHAIN UUID for system events
    previous_audit_id     UUID         REFERENCES audit.audit_event(audit_id),
    previous_hash         VARCHAR(64),  -- SHA-256 of the previous event in this chain
    event_hash            VARCHAR(64)  NOT NULL,
                          -- SHA-256( previous_hash || chain_id || action_code ||
                          --           officer_id || resource_type || resource_id ||
                          --           result || timestamp_iso )

    -- Event metadata
    action_code           VARCHAR(60)  NOT NULL REFERENCES reference.audit_action_type(action_code),
    event_timestamp       TIMESTAMPTZ  NOT NULL DEFAULT now(),
    severity              VARCHAR(20)  NOT NULL DEFAULT 'INFO'
                                       CHECK (severity IN ('INFO','WARN','CRITICAL')),

    -- Who
    officer_id            UUID         REFERENCES identity.officer(officer_id),
    officer_name          VARCHAR(200),   -- denormalised snapshot
    officer_rank          VARCHAR(40),    -- denormalised snapshot
    session_id            UUID         REFERENCES identity.officer_session(session_id),

    -- Where (organisational context at time of action)
    police_station_id     UUID         REFERENCES organisation.police_station(station_id),
    station_name          VARCHAR(200),   -- denormalised snapshot

    -- What
    case_id               UUID         REFERENCES case_mgmt.case(case_id),
    case_number           VARCHAR(60),    -- denormalised snapshot
    resource_type         VARCHAR(60),    -- CASE, FIR, EVIDENCE, DOCUMENT, OFFICER, etc.
    resource_id           UUID,
    resource_ref          VARCHAR(120),   -- human-readable ref (case_number, evidence_number, etc.)

    -- Result
    result                VARCHAR(20)  NOT NULL DEFAULT 'SUCCESS'
                                       CHECK (result IN ('SUCCESS','FAILURE','PARTIAL','BLOCKED')),
    failure_reason        TEXT,

    -- State snapshots (before/after for change events)
    previous_state        JSONB,
    new_state             JSONB,

    -- Network/device context
    ip_address            INET,
    user_agent            TEXT,
    device_fingerprint    VARCHAR(255),

    -- Additional context
    reason                TEXT,
    notes                 TEXT,
    metadata              JSONB        NOT NULL DEFAULT '{}',

    -- Immutability: no UPDATE or DELETE (trigger enforced)
    created_at            TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_audit_chain_id    ON audit.audit_event(chain_id);
CREATE INDEX idx_audit_action      ON audit.audit_event(action_code);
CREATE INDEX idx_audit_timestamp   ON audit.audit_event(event_timestamp);
CREATE INDEX idx_audit_officer     ON audit.audit_event(officer_id);
CREATE INDEX idx_audit_case        ON audit.audit_event(case_id);
CREATE INDEX idx_audit_resource    ON audit.audit_event(resource_type, resource_id);
CREATE INDEX idx_audit_severity    ON audit.audit_event(severity);
CREATE INDEX idx_audit_result      ON audit.audit_event(result);
-- Composite: most common query pattern — all events for a case ordered by time
CREATE INDEX idx_audit_case_time   ON audit.audit_event(case_id, event_timestamp DESC);
-- Composite: chain traversal
CREATE INDEX idx_audit_prev        ON audit.audit_event(previous_audit_id);

-- Add deferred FK from custody events to audit
ALTER TABLE custody.evidence_custody_event
    ADD CONSTRAINT fk_custody_audit
    FOREIGN KEY (audit_event_id)
    REFERENCES audit.audit_event(audit_id)
    DEFERRABLE INITIALLY DEFERRED;

-- ---------------------------------------------------------------------------
-- 2. AUDIT CHAIN — tracks the head of each hash chain
--    One row per chain_id. Updated atomically when a new event is appended.
--    GLOBAL_CHAIN_ID is a well-known constant UUID for non-case system events.
-- ---------------------------------------------------------------------------
CREATE TABLE audit.audit_chain (
    chain_id              UUID         PRIMARY KEY,
                          -- Equals case_id for case chains; GLOBAL_CHAIN_ID for system
    chain_type            VARCHAR(20)  NOT NULL DEFAULT 'CASE'
                                       CHECK (chain_type IN ('CASE','GLOBAL','STATION')),
    head_audit_id         UUID         REFERENCES audit.audit_event(audit_id),
    head_hash             VARCHAR(64),
    event_count           BIGINT       NOT NULL DEFAULT 0,
    last_event_at         TIMESTAMPTZ,
    chain_status          VARCHAR(20)  NOT NULL DEFAULT 'INTACT'
                                       CHECK (chain_status IN ('INTACT','BROKEN','UNVERIFIED')),
    last_verified_at      TIMESTAMPTZ,
    created_at            TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at            TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- The well-known global chain UUID — used for all non-case system events
INSERT INTO audit.audit_chain (chain_id, chain_type) VALUES
('00000000-0000-0000-0000-000000000001', 'GLOBAL');

CREATE INDEX idx_audit_chain_type   ON audit.audit_chain(chain_type);
CREATE INDEX idx_audit_chain_status ON audit.audit_chain(chain_status);

-- ---------------------------------------------------------------------------
-- 3. SECURITY ALERT — generated when suspicious patterns are detected
--    Different from integrity.integrity_alert (which is about file hashes).
--    This covers login anomalies, access pattern violations, etc.
-- ---------------------------------------------------------------------------
CREATE TABLE audit.security_alert (
    alert_id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    alert_type            VARCHAR(60)  NOT NULL
                                       CHECK (alert_type IN (
                                           'BRUTE_FORCE_LOGIN',
                                           'UNAUTHORIZED_ACCESS_ATTEMPT',
                                           'PRIVILEGE_ESCALATION',
                                           'AUDIT_CHAIN_TAMPER',
                                           'UNUSUAL_DOWNLOAD_VOLUME',
                                           'ACCESS_OUTSIDE_HOURS',
                                           'MULTIPLE_FAILED_ACTIONS',
                                           'SENSITIVE_DATA_EXPORT',
                                           'OTHER')),

    severity              VARCHAR(20)  NOT NULL DEFAULT 'HIGH'
                                       CHECK (severity IN ('LOW','MEDIUM','HIGH','CRITICAL')),

    officer_id            UUID         REFERENCES identity.officer(officer_id),
    case_id               UUID         REFERENCES case_mgmt.case(case_id),
    station_id            UUID         REFERENCES organisation.police_station(station_id),

    -- Triggering audit event
    trigger_audit_id      UUID         REFERENCES audit.audit_event(audit_id),

    title                 VARCHAR(300) NOT NULL,
    description           TEXT         NOT NULL,

    -- Evidence of the anomaly
    evidence_detail       JSONB        NOT NULL DEFAULT '{}',

    alert_status          VARCHAR(30)  NOT NULL DEFAULT 'OPEN'
                                       CHECK (alert_status IN (
                                           'OPEN','ACKNOWLEDGED','INVESTIGATING',
                                           'RESOLVED','FALSE_POSITIVE')),

    detected_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),
    detected_by           VARCHAR(60)  NOT NULL DEFAULT 'SYSTEM',  -- SYSTEM or officer_id

    acknowledged_by       UUID         REFERENCES identity.officer(officer_id),
    acknowledged_at       TIMESTAMPTZ,

    resolved_by           UUID         REFERENCES identity.officer(officer_id),
    resolved_at           TIMESTAMPTZ,
    resolution_notes      TEXT,

    created_at            TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at            TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_sec_alert_type     ON audit.security_alert(alert_type);
CREATE INDEX idx_sec_alert_officer  ON audit.security_alert(officer_id);
CREATE INDEX idx_sec_alert_case     ON audit.security_alert(case_id);
CREATE INDEX idx_sec_alert_severity ON audit.security_alert(severity);
CREATE INDEX idx_sec_alert_status   ON audit.security_alert(alert_status);
CREATE INDEX idx_sec_alert_time     ON audit.security_alert(detected_at);

-- ---------------------------------------------------------------------------
-- 4. AUDIT SUMMARY — materialised daily summary for dashboards
--    Populated by a scheduled job or trigger; not a materialised view
--    (to avoid pg_matview refresh complexity for the MVP).
-- ---------------------------------------------------------------------------
CREATE TABLE audit.audit_summary (
    summary_id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    summary_date          DATE         NOT NULL,
    station_id            UUID         REFERENCES organisation.police_station(station_id),
    case_id               UUID         REFERENCES case_mgmt.case(case_id),

    total_events          INTEGER      NOT NULL DEFAULT 0,
    critical_events       INTEGER      NOT NULL DEFAULT 0,
    failed_events         INTEGER      NOT NULL DEFAULT 0,
    login_events          INTEGER      NOT NULL DEFAULT 0,
    document_downloads    INTEGER      NOT NULL DEFAULT 0,
    evidence_transfers    INTEGER      NOT NULL DEFAULT 0,
    alerts_raised         INTEGER      NOT NULL DEFAULT 0,

    computed_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),

    UNIQUE (summary_date, station_id, case_id)
);

CREATE INDEX idx_audit_sum_date    ON audit.audit_summary(summary_date);
CREATE INDEX idx_audit_sum_station ON audit.audit_summary(station_id);

-- ---------------------------------------------------------------------------
-- 5. LOGIN ATTEMPT LOG — dedicated table for authentication audit
--    Kept separate from the main audit chain to allow high-volume inserts
--    without impacting the chain performance.
-- ---------------------------------------------------------------------------
CREATE TABLE audit.login_attempt (
    attempt_id        UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    username          VARCHAR(60)  NOT NULL,
    officer_id        UUID         REFERENCES identity.officer(officer_id),
    attempt_timestamp TIMESTAMPTZ  NOT NULL DEFAULT now(),
    result            VARCHAR(20)  NOT NULL CHECK (result IN ('SUCCESS','FAILED','LOCKED','MFA_REQUIRED','MFA_FAILED')),
    failure_reason    TEXT,
    ip_address        INET,
    user_agent        TEXT,
    session_id        UUID         REFERENCES identity.officer_session(session_id)
);

CREATE INDEX idx_login_officer   ON audit.login_attempt(officer_id);
CREATE INDEX idx_login_username  ON audit.login_attempt(username);
CREATE INDEX idx_login_timestamp ON audit.login_attempt(attempt_timestamp);
CREATE INDEX idx_login_result    ON audit.login_attempt(result);
-- Composite: brute-force detection — recent failures for a username
CREATE INDEX idx_login_bf_detect ON audit.login_attempt(username, result, attempt_timestamp DESC);
-- =============================================================================
-- 014_workflow.sql
-- Workflow states, approval queues, notifications, task assignments
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. WORKFLOW DEFINITION — reusable workflow templates
--    e.g. "Document Approval", "Evidence Transfer Approval", "Case Closure"
-- ---------------------------------------------------------------------------
CREATE TABLE workflow.workflow_definition (
    workflow_def_id   UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    workflow_code     VARCHAR(60)  NOT NULL UNIQUE,
    workflow_name     VARCHAR(150) NOT NULL,
    description       TEXT,
    applies_to        VARCHAR(60)  NOT NULL,
                      -- DOCUMENT, EVIDENCE_TRANSFER, CASE_CLOSURE, FSL_REQUEST, CASE_TRANSFER
    is_active         BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at        TIMESTAMPTZ  NOT NULL DEFAULT now()
);

INSERT INTO workflow.workflow_definition (workflow_code, workflow_name, applies_to) VALUES
('DOC_APPROVAL',          'Document Approval Workflow',          'DOCUMENT'),
('EV_TRANSFER_APPROVAL',  'Evidence Transfer Approval',          'EVIDENCE_TRANSFER'),
('CASE_CLOSURE_APPROVAL', 'Case Closure Approval',               'CASE_CLOSURE'),
('FSL_REQUEST_APPROVAL',  'FSL Request Approval',                'FSL_REQUEST'),
('CASE_TRANSFER_APPROVAL','Case Transfer Approval',              'CASE_TRANSFER');

-- ---------------------------------------------------------------------------
-- 2. WORKFLOW STEP — individual steps in a workflow
-- ---------------------------------------------------------------------------
CREATE TABLE workflow.workflow_step (
    step_id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    workflow_def_id  UUID         NOT NULL REFERENCES workflow.workflow_definition(workflow_def_id),
    step_order       SMALLINT     NOT NULL,
    step_name        VARCHAR(120) NOT NULL,
    step_type        VARCHAR(40)  NOT NULL DEFAULT 'APPROVAL'
                                  CHECK (step_type IN ('APPROVAL','REVIEW','NOTIFICATION','SYSTEM')),
    required_role    VARCHAR(60),   -- case_role_code or system_role_code
    required_rank_level SMALLINT,
    auto_approve_after_hours SMALLINT,   -- NULL = no auto-approve
    is_mandatory     BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT now(),
    UNIQUE (workflow_def_id, step_order)
);

-- ---------------------------------------------------------------------------
-- 3. WORKFLOW INSTANCE — a running instance of a workflow for a specific resource
-- ---------------------------------------------------------------------------
CREATE TABLE workflow.workflow_instance (
    instance_id       UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    workflow_def_id   UUID         NOT NULL REFERENCES workflow.workflow_definition(workflow_def_id),

    -- Resource being processed
    resource_type     VARCHAR(60)  NOT NULL,
    resource_id       UUID         NOT NULL,
    case_id           UUID         REFERENCES case_mgmt.case(case_id),

    current_step_id   UUID         REFERENCES workflow.workflow_step(step_id),
    instance_status   VARCHAR(30)  NOT NULL DEFAULT 'PENDING'
                                   CHECK (instance_status IN (
                                       'PENDING','IN_PROGRESS','APPROVED',
                                       'REJECTED','CANCELLED','COMPLETED')),

    initiated_by      UUID         NOT NULL REFERENCES identity.officer(officer_id),
    initiated_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    completed_at      TIMESTAMPTZ,

    notes             TEXT,
    created_at        TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_wf_instance_resource ON workflow.workflow_instance(resource_type, resource_id);
CREATE INDEX idx_wf_instance_case     ON workflow.workflow_instance(case_id);
CREATE INDEX idx_wf_instance_status   ON workflow.workflow_instance(instance_status);

-- ---------------------------------------------------------------------------
-- 4. WORKFLOW ACTION — each action taken on a workflow instance step
-- ---------------------------------------------------------------------------
CREATE TABLE workflow.workflow_action (
    action_id         UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    instance_id       UUID         NOT NULL REFERENCES workflow.workflow_instance(instance_id),
    step_id           UUID         NOT NULL REFERENCES workflow.workflow_step(step_id),

    action_type       VARCHAR(30)  NOT NULL
                                   CHECK (action_type IN (
                                       'APPROVED','REJECTED','RETURNED',
                                       'COMMENTED','ESCALATED','AUTO_APPROVED')),
    action_by         UUID         NOT NULL REFERENCES identity.officer(officer_id),
    action_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),
    comments          TEXT,

    created_at        TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_wf_action_instance ON workflow.workflow_action(instance_id);

-- ---------------------------------------------------------------------------
-- 5. NOTIFICATION — system notifications to officers
-- ---------------------------------------------------------------------------
CREATE TABLE workflow.notification (
    notification_id   UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    recipient_id      UUID         NOT NULL REFERENCES identity.officer(officer_id),

    notification_type VARCHAR(60)  NOT NULL
                                   CHECK (notification_type IN (
                                       'CASE_ASSIGNED','TASK_ASSIGNED','DOCUMENT_APPROVAL_REQUIRED',
                                       'EVIDENCE_TRANSFER_REQUIRED','INTEGRITY_ALERT',
                                       'SECURITY_ALERT','WORKFLOW_UPDATE','FSL_REPORT_READY',
                                       'CASE_STATUS_CHANGE','DEADLINE_REMINDER','GENERAL')),

    title             VARCHAR(300) NOT NULL,
    body              TEXT         NOT NULL,

    -- Related resource
    resource_type     VARCHAR(60),
    resource_id       UUID,
    case_id           UUID         REFERENCES case_mgmt.case(case_id),

    -- Delivery
    is_read           BOOLEAN      NOT NULL DEFAULT FALSE,
    read_at           TIMESTAMPTZ,
    is_email_sent     BOOLEAN      NOT NULL DEFAULT FALSE,
    email_sent_at     TIMESTAMPTZ,

    priority          VARCHAR(20)  NOT NULL DEFAULT 'NORMAL'
                                   CHECK (priority IN ('LOW','NORMAL','HIGH','URGENT')),

    expires_at        TIMESTAMPTZ,
    created_at        TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_notif_recipient ON workflow.notification(recipient_id, is_read);
CREATE INDEX idx_notif_case      ON workflow.notification(case_id);
CREATE INDEX idx_notif_type      ON workflow.notification(notification_type);
CREATE INDEX idx_notif_created   ON workflow.notification(created_at DESC);

-- ---------------------------------------------------------------------------
-- 6. DEADLINE TRACKER — tracks statutory deadlines for cases and tasks
-- ---------------------------------------------------------------------------
CREATE TABLE workflow.deadline (
    deadline_id       UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    case_id           UUID         NOT NULL REFERENCES case_mgmt.case(case_id),
    deadline_type     VARCHAR(60)  NOT NULL
                                   CHECK (deadline_type IN (
                                       'CHARGE_SHEET_60_DAY','CHARGE_SHEET_90_DAY',
                                       'REMAND_EXPIRY','BAIL_HEARING',
                                       'FSL_RETURN','COURT_DATE',
                                       'INVESTIGATION_DEADLINE','OTHER')),
    deadline_date     DATE         NOT NULL,
    description       TEXT,
    is_met            BOOLEAN      NOT NULL DEFAULT FALSE,
    met_at            TIMESTAMPTZ,
    is_extended       BOOLEAN      NOT NULL DEFAULT FALSE,
    extension_reason  TEXT,
    extended_to       DATE,
    officer_id        UUID         REFERENCES identity.officer(officer_id),
    notification_sent BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at        TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_deadline_case     ON workflow.deadline(case_id);
CREATE INDEX idx_deadline_date     ON workflow.deadline(deadline_date);
CREATE INDEX idx_deadline_officer  ON workflow.deadline(officer_id);
CREATE INDEX idx_deadline_is_met   ON workflow.deadline(is_met) WHERE is_met = FALSE;
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
-- =============================================================================
-- 003_seed_data.sql
-- Realistic demo/seed data for SIH demonstration
-- ALL DATA IS FICTIONAL — no real officer personal information used
-- =============================================================================
-- Scenario covered:
--   SI Arjun Rao (PRIMARY_IO) at Central Police Station, Bengaluru
--   Registers Zero FIR → transferred → Case CASE-KA-BLR-CEN-2026-00000001
--   Seizes Mobile Phone (E001)
--   Malkhana → FSL → Forensic Image (E002) → Chat DB (E003) → Screenshot (E004)
--   Forensic Report (E005) created
--   FIR PDF v1 → v2 → FINAL + signed
--   Full audit trail
-- =============================================================================

-- BEGIN; -- removed to prevent cascade rollback on individual errors

-- =============================================================================
-- SECTION A: ORGANISATION UNITS
-- =============================================================================

-- Karnataka State
INSERT INTO organisation.organisation_unit
    (unit_id, unit_code, unit_name, unit_type_code, state_code, country_code)
VALUES
    ('10000000-0000-0000-0000-000000000001', 'IN-KA', 'Karnataka State', 'STATE', 'KA', 'IN'),
    ('10000000-0000-0000-0000-000000000002', 'IN-KA-SPHQ', 'Karnataka State Police Headquarters', 'STATE_POLICE_HQ', 'KA', 'IN'),
    ('10000000-0000-0000-0000-000000000003', 'IN-KA-BLR-COMM', 'Bengaluru City Commissionerate', 'COMMISSIONERATE', 'KA', 'IN'),
    ('10000000-0000-0000-0000-000000000004', 'IN-KA-BLR-CENT-DIV', 'Bengaluru Central Division', 'DIVISION', 'KA', 'IN'),
    ('10000000-0000-0000-0000-000000000005', 'IN-KA-BLR-CENT-SUB', 'Bengaluru Central Sub-Division', 'SUBDIVISION', 'KA', 'IN'),
    ('10000000-0000-0000-0000-000000000006', 'IN-KA-BLR-CEN-PS', 'Central Police Station Bengaluru', 'POLICE_STATION', 'KA', 'IN'),
    ('10000000-0000-0000-0000-000000000007', 'IN-KA-BLR-CYBER-PS', 'Cyber Crime Police Station Bengaluru', 'CYBER_CELL', 'KA', 'IN'),
    ('10000000-0000-0000-0000-000000000008', 'IN-KA-BLR-WOMEN-PS', 'Women Police Station Bengaluru', 'POLICE_STATION', 'KA', 'IN');

-- Maharashtra State
INSERT INTO organisation.organisation_unit
    (unit_id, unit_code, unit_name, unit_type_code, state_code, country_code)
VALUES
    ('10000000-0000-0000-0000-000000000010', 'IN-MH', 'Maharashtra State', 'STATE', 'MH', 'IN'),
    ('10000000-0000-0000-0000-000000000011', 'IN-MH-MUM-COMM', 'Mumbai City Commissionerate', 'COMMISSIONERATE', 'MH', 'IN'),
    ('10000000-0000-0000-0000-000000000012', 'IN-MH-MUM-CSTN-PS', 'Colaba Police Station Mumbai', 'POLICE_STATION', 'MH', 'IN');

-- Delhi
INSERT INTO organisation.organisation_unit
    (unit_id, unit_code, unit_name, unit_type_code, state_code, country_code)
VALUES
    ('10000000-0000-0000-0000-000000000020', 'IN-DL', 'Delhi (NCT)', 'STATE', 'DL', 'IN'),
    ('10000000-0000-0000-0000-000000000021', 'IN-DL-CP', 'Delhi Police Commissionerate', 'COMMISSIONERATE', 'DL', 'IN'),
    ('10000000-0000-0000-0000-000000000022', 'IN-DL-CNT-PS', 'Connaught Place Police Station', 'POLICE_STATION', 'DL', 'IN');

-- Set parent_unit_id
UPDATE organisation.organisation_unit SET parent_unit_id = '10000000-0000-0000-0000-000000000001' WHERE unit_code = 'IN-KA-SPHQ';
UPDATE organisation.organisation_unit SET parent_unit_id = '10000000-0000-0000-0000-000000000002' WHERE unit_code = 'IN-KA-BLR-COMM';
UPDATE organisation.organisation_unit SET parent_unit_id = '10000000-0000-0000-0000-000000000003' WHERE unit_code = 'IN-KA-BLR-CENT-DIV';
UPDATE organisation.organisation_unit SET parent_unit_id = '10000000-0000-0000-0000-000000000004' WHERE unit_code = 'IN-KA-BLR-CENT-SUB';
UPDATE organisation.organisation_unit SET parent_unit_id = '10000000-0000-0000-0000-000000000005' WHERE unit_code IN ('IN-KA-BLR-CEN-PS','IN-KA-BLR-CYBER-PS','IN-KA-BLR-WOMEN-PS');

-- =============================================================================
-- SECTION B: POLICE STATIONS
-- =============================================================================

INSERT INTO organisation.police_station
    (station_id, station_code, station_name, station_type_code,
     organisation_unit_id, state_code, district_name,
     address_line1, city, pincode, phone_primary, cctns_station_code)
VALUES
    ('20000000-0000-0000-0000-000000000001',
     'BLR-CEN', 'Central Police Station Bengaluru', 'POLICE_STATION',
     '10000000-0000-0000-0000-000000000006', 'KA', 'Bengaluru Urban',
     'Infantry Road, Shivajinagar', 'Bengaluru', '560001', '080-22942222', 'KA-BLR-CEN-001'),

    ('20000000-0000-0000-0000-000000000002',
     'BLR-CYBER', 'Cyber Crime Police Station Bengaluru', 'CYBER_PS',
     '10000000-0000-0000-0000-000000000007', 'KA', 'Bengaluru Urban',
     'CID Headquarters, Carlton House', 'Bengaluru', '560001', '080-22943151', 'KA-BLR-CYBER-001'),

    ('20000000-0000-0000-0000-000000000003',
     'BLR-WPS', 'Women Police Station Bengaluru', 'WOMEN_PS',
     '10000000-0000-0000-0000-000000000008', 'KA', 'Bengaluru Urban',
     'Halasuru, Ulsoor Road', 'Bengaluru', '560042', '080-25566100', 'KA-BLR-WPS-001'),

    ('20000000-0000-0000-0000-000000000004',
     'MUM-COL', 'Colaba Police Station Mumbai', 'POLICE_STATION',
     '10000000-0000-0000-0000-000000000012', 'MH', 'Mumbai City',
     'Colaba Causeway, Mumbai', 'Mumbai', '400005', '022-22021855', 'MH-MUM-COL-001'),

    ('20000000-0000-0000-0000-000000000005',
     'DL-CNT', 'Connaught Place Police Station Delhi', 'POLICE_STATION',
     '10000000-0000-0000-0000-000000000022', 'DL', 'New Delhi',
     'Connaught Place, New Delhi', 'New Delhi', '110001', '011-23415414', 'DL-CNT-001');

-- Jurisdiction
INSERT INTO organisation.jurisdiction
    (station_id, jurisdiction_name, jurisdiction_type,
     area_sq_km, localities_text)
VALUES
    ('20000000-0000-0000-0000-000000000001',
     'Central PS Jurisdiction', 'TERRITORIAL',
     12.5, 'Shivajinagar, Infantry Road, Brigade Road, MG Road, Cubbon Park area'),
    ('20000000-0000-0000-0000-000000000002',
     'Cyber Crime PS Jurisdiction', 'FUNCTIONAL',
     NULL, 'Entire Bengaluru City — cyber offences');

-- Beat
INSERT INTO organisation.beat (beat_code, beat_name, station_id)
VALUES
    ('BLR-CEN-B01', 'Infantry Road Beat',  '20000000-0000-0000-0000-000000000001'),
    ('BLR-CEN-B02', 'Brigade Road Beat',   '20000000-0000-0000-0000-000000000001'),
    ('BLR-CEN-B03', 'MG Road Beat',        '20000000-0000-0000-0000-000000000001');

-- =============================================================================
-- SECTION C: PERSONS (all fictional)
-- =============================================================================

INSERT INTO identity.person
    (person_id, first_name, last_name, date_of_birth, gender,
     phone_primary, address_current, city, state_code,
     is_police_officer)
VALUES
    -- Officers
    ('30000000-0000-0000-0000-000000000001', 'Rajesh',   'Kumar',      '1975-03-15', 'MALE',   '9900000001', 'Police HQ, Bengaluru',    'Bengaluru', 'KA', TRUE),
    ('30000000-0000-0000-0000-000000000002', 'Arjun',    'Rao',        '1988-07-22', 'MALE',   '9900000002', '12 Infantry Road, Blr',   'Bengaluru', 'KA', TRUE),
    ('30000000-0000-0000-0000-000000000003', 'Kavitha',  'Nair',       '1990-11-05', 'FEMALE', '9900000003', '45 Koramangala, Blr',     'Bengaluru', 'KA', TRUE),
    ('30000000-0000-0000-0000-000000000004', 'Suresh',   'Patil',      '1985-01-18', 'MALE',   '9900000004', '78 Malleswaram, Blr',     'Bengaluru', 'KA', TRUE),
    ('30000000-0000-0000-0000-000000000005', 'Priya',    'Sharma',     '1992-09-30', 'FEMALE', '9900000005', '23 Jayanagar, Blr',       'Bengaluru', 'KA', TRUE),
    ('30000000-0000-0000-0000-000000000006', 'Vikram',   'Singh',      '1982-06-12', 'MALE',   '9900000006', '56 Indiranagar, Blr',     'Bengaluru', 'KA', TRUE),
    ('30000000-0000-0000-0000-000000000007', 'Meena',    'Krishnan',   '1995-04-28', 'FEMALE', '9900000007', '34 BTM Layout, Blr',      'Bengaluru', 'KA', TRUE),
    ('30000000-0000-0000-0000-000000000008', 'Ravi',     'Malhotra',   '1987-12-10', 'MALE',   '9900000008', '67 Whitefield, Blr',      'Bengaluru', 'KA', TRUE),
    -- Civilians
    ('30000000-0000-0000-0000-000000000010', 'Anand',    'Verma',      '1985-05-20', 'MALE',   '9800000001', '101 MG Road, Bengaluru',  'Bengaluru', 'KA', FALSE),  -- complainant
    ('30000000-0000-0000-0000-000000000011', 'Farhan',   'Sheikh',     '1990-08-15', 'MALE',   '9800000002', '202 Shivajinagar, Blr',   'Bengaluru', 'KA', FALSE),  -- accused
    ('30000000-0000-0000-0000-000000000012', 'Sunita',   'Reddy',      '1988-03-25', 'FEMALE', '9800000003', '303 Brigade Road, Blr',   'Bengaluru', 'KA', FALSE),  -- witness
    ('30000000-0000-0000-0000-000000000013', 'Mohan',    'Das',        '1975-11-08', 'MALE',   '9800000004', '404 Cubbon Park, Blr',    'Bengaluru', 'KA', FALSE);   -- victim

-- =============================================================================
-- SECTION D: OFFICERS
-- =============================================================================

-- Password hashes are bcrypt of "Demo@1234!" — NEVER use in production
INSERT INTO identity.officer
    (officer_id, person_id, identity_code, service_number,
     current_rank_code, current_station_id,
     username, password_hash, date_of_joining, cadre, is_active)
VALUES
    ('40000000-0000-0000-0000-000000000001',
     '30000000-0000-0000-0000-000000000001',
     'IN-KA-BLR-CEN-DCP-00001', 'KA-IPS-2000-001',
     'DCP', '20000000-0000-0000-0000-000000000001',
     'rajesh.kumar', '$2b$12$DEMO_HASH_PLACEHOLDER_DCP001',
     '2000-08-01', 'IPS', TRUE),

    ('40000000-0000-0000-0000-000000000002',
     '30000000-0000-0000-0000-000000000002',
     'IN-KA-BLR-CEN-SI-00002', 'KA-SPS-2012-042',
     'SUB_INSPECTOR', '20000000-0000-0000-0000-000000000001',
     'arjun.rao', '$2b$12$DEMO_HASH_PLACEHOLDER_SI002',
     '2012-06-15', 'STATE', TRUE),

    ('40000000-0000-0000-0000-000000000003',
     '30000000-0000-0000-0000-000000000003',
     'IN-KA-BLR-CEN-SI-00003', 'KA-SPS-2015-067',
     'SUB_INSPECTOR', '20000000-0000-0000-0000-000000000001',
     'kavitha.nair', '$2b$12$DEMO_HASH_PLACEHOLDER_SI003',
     '2015-03-20', 'STATE', TRUE),

    ('40000000-0000-0000-0000-000000000004',
     '30000000-0000-0000-0000-000000000004',
     'IN-KA-BLR-CEN-INSP-00004', 'KA-SPS-2008-015',
     'INSPECTOR', '20000000-0000-0000-0000-000000000001',
     'suresh.patil', '$2b$12$DEMO_HASH_PLACEHOLDER_INSP004',
     '2008-09-01', 'STATE', TRUE),

    ('40000000-0000-0000-0000-000000000005',
     '30000000-0000-0000-0000-000000000005',
     'IN-KA-BLR-CEN-ASI-00005', 'KA-SPS-2018-102',
     'ASI', '20000000-0000-0000-0000-000000000001',
     'priya.sharma', '$2b$12$DEMO_HASH_PLACEHOLDER_ASI005',
     '2018-01-15', 'STATE', TRUE),

    ('40000000-0000-0000-0000-000000000006',
     '30000000-0000-0000-0000-000000000006',
     'IN-KA-BLR-CEN-HC-00006', 'KA-SPS-2010-088',
     'HEAD_CONSTABLE', '20000000-0000-0000-0000-000000000001',
     'vikram.singh', '$2b$12$DEMO_HASH_PLACEHOLDER_HC006',
     '2010-04-10', 'STATE', TRUE),

    ('40000000-0000-0000-0000-000000000007',
     '30000000-0000-0000-0000-000000000007',
     'IN-KA-BLR-CYB-SI-00007', 'KA-SPS-2019-121',
     'SUB_INSPECTOR', '20000000-0000-0000-0000-000000000002',
     'meena.krishnan', '$2b$12$DEMO_HASH_PLACEHOLDER_SI007',
     '2019-07-01', 'STATE', TRUE),

    ('40000000-0000-0000-0000-000000000008',
     '30000000-0000-0000-0000-000000000008',
     'IN-KA-BLR-CEN-INSP-00008', 'KA-SPS-2007-011',
     'INSPECTOR', '20000000-0000-0000-0000-000000000001',
     'ravi.malhotra', '$2b$12$DEMO_HASH_PLACEHOLDER_INSP008',
     '2007-05-20', 'STATE', TRUE);

-- =============================================================================
-- SECTION E: OFFICER POSTINGS (current postings + historical for Arjun Rao)
-- =============================================================================

-- Arjun Rao: previously posted at Cyber PS (2020-2023), now at Central PS
INSERT INTO identity.officer_posting
    (posting_id, officer_id, organisation_unit_id, police_station_id,
     rank_id, designation_id,
     posting_start_date, posting_end_date, is_current, posting_type)
SELECT
    '50000000-0000-0000-0000-000000000001',
    '40000000-0000-0000-0000-000000000002',
    '10000000-0000-0000-0000-000000000007',
    '20000000-0000-0000-0000-000000000002',
    r.rank_id,
    d.designation_id,
    '2020-06-01', '2023-05-31', FALSE, 'REGULAR'
FROM reference.rank r, reference.designation d
WHERE r.rank_code = 'SUB_INSPECTOR' AND d.designation_code = 'IO';

-- Arjun Rao: current posting at Central PS
INSERT INTO identity.officer_posting
    (posting_id, officer_id, organisation_unit_id, police_station_id,
     rank_id, designation_id,
     posting_start_date, is_current, posting_type)
SELECT
    '50000000-0000-0000-0000-000000000002',
    '40000000-0000-0000-0000-000000000002',
    '10000000-0000-0000-0000-000000000006',
    '20000000-0000-0000-0000-000000000001',
    r.rank_id,
    d.designation_id,
    '2023-06-01', TRUE, 'REGULAR'
FROM reference.rank r, reference.designation d
WHERE r.rank_code = 'SUB_INSPECTOR' AND d.designation_code = 'IO';

-- Suresh Patil (SHO) — current posting
INSERT INTO identity.officer_posting
    (posting_id, officer_id, organisation_unit_id, police_station_id,
     rank_id, designation_id,
     posting_start_date, is_current, posting_type)
SELECT
    '50000000-0000-0000-0000-000000000004',
    '40000000-0000-0000-0000-000000000004',
    '10000000-0000-0000-0000-000000000006',
    '20000000-0000-0000-0000-000000000001',
    r.rank_id,
    d.designation_id,
    '2022-01-01', TRUE, 'REGULAR'
FROM reference.rank r, reference.designation d
WHERE r.rank_code = 'INSPECTOR' AND d.designation_code = 'SHO';

-- Vikram Singh (Malkhana) — current posting
INSERT INTO identity.officer_posting
    (posting_id, officer_id, organisation_unit_id, police_station_id,
     rank_id, designation_id,
     posting_start_date, is_current, posting_type)
SELECT
    '50000000-0000-0000-0000-000000000006',
    '40000000-0000-0000-0000-000000000006',
    '10000000-0000-0000-0000-000000000006',
    '20000000-0000-0000-0000-000000000001',
    r.rank_id,
    d.designation_id,
    '2021-03-15', TRUE, 'REGULAR'
FROM reference.rank r, reference.designation d
WHERE r.rank_code = 'HEAD_CONSTABLE' AND d.designation_code = 'MALKHANA_INCHARGE';

-- Meena Krishnan (Cyber) — current posting
INSERT INTO identity.officer_posting
    (posting_id, officer_id, organisation_unit_id, police_station_id,
     rank_id, designation_id,
     posting_start_date, is_current, posting_type)
SELECT
    '50000000-0000-0000-0000-000000000007',
    '40000000-0000-0000-0000-000000000007',
    '10000000-0000-0000-0000-000000000007',
    '20000000-0000-0000-0000-000000000002',
    r.rank_id,
    d.designation_id,
    '2021-07-01', TRUE, 'REGULAR'
FROM reference.rank r, reference.designation d
WHERE r.rank_code = 'SUB_INSPECTOR' AND d.designation_code = 'CYBER_LIAISON';

-- =============================================================================
-- SECTION F: SYSTEM ROLE ASSIGNMENTS
-- =============================================================================

INSERT INTO authz.officer_system_role
    (officer_id, role_id, station_id, granted_by)
SELECT '40000000-0000-0000-0000-000000000001', sr.role_id,
       '20000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000001'
FROM authz.system_role sr WHERE sr.role_code = 'SYS_ADMIN';

INSERT INTO authz.officer_system_role
    (officer_id, role_id, station_id, granted_by)
SELECT '40000000-0000-0000-0000-000000000004', sr.role_id,
       '20000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000001'
FROM authz.system_role sr WHERE sr.role_code = 'SHO_ROLE';

INSERT INTO authz.officer_system_role
    (officer_id, role_id, station_id, granted_by)
SELECT '40000000-0000-0000-0000-000000000002', sr.role_id,
       '20000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000004'
FROM authz.system_role sr WHERE sr.role_code = 'IO_ROLE';

INSERT INTO authz.officer_system_role
    (officer_id, role_id, station_id, granted_by)
SELECT '40000000-0000-0000-0000-000000000006', sr.role_id,
       '20000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000004'
FROM authz.system_role sr WHERE sr.role_code = 'MALKHANA_ROLE';

INSERT INTO authz.officer_system_role
    (officer_id, role_id, station_id, granted_by)
SELECT '40000000-0000-0000-0000-000000000007', sr.role_id,
       '20000000-0000-0000-0000-000000000002', '40000000-0000-0000-0000-000000000001'
FROM authz.system_role sr WHERE sr.role_code = 'CYBER_OFFICER';

-- =============================================================================
-- SECTION G: CASES
-- =============================================================================

-- Case 1: Cyber fraud — primary demo case
INSERT INTO case_mgmt.case
    (case_id, case_number,
     originating_station_id, current_station_id,
     case_type_id, case_status_code, priority,
     confidentiality_code,
     incident_date, opened_at,
     incident_description, incident_location,
     primary_io_id, supervising_officer_id,
     created_by, ipc_sections, bnss_sections)
SELECT
    '60000000-0000-0000-0000-000000000001',
    'CASE-KA-BLR-CEN-2026-00000001',
    '20000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000001',
    ct.case_type_id, 'UNDER_INVESTIGATION', 'HIGH',
    'CONFIDENTIAL',
    '2026-01-15 14:30:00+05:30',
    '2026-01-15 16:00:00+05:30',
    'Complainant reports financial fraud via WhatsApp messages. Accused allegedly impersonated bank official and obtained OTP. Amount defrauded: Rs. 4,50,000.',
    'MG Road, Bengaluru',
    '40000000-0000-0000-0000-000000000002',
    '40000000-0000-0000-0000-000000000004',
    '40000000-0000-0000-0000-000000000002',
    '420, 419, 66C, 66D IT Act',
    '318, 319 BNSS'
FROM reference.case_type ct WHERE ct.type_code = 'CYBERCRIME';

-- Case 2: Robbery
INSERT INTO case_mgmt.case
    (case_id, case_number,
     originating_station_id, current_station_id,
     case_type_id, case_status_code, priority, confidentiality_code,
     incident_date, opened_at,
     incident_description, incident_location,
     primary_io_id, supervising_officer_id, created_by)
SELECT
    '60000000-0000-0000-0000-000000000002',
    'CASE-KA-BLR-CEN-2026-00000002',
    '20000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000001',
    ct.case_type_id, 'FIR_REGISTERED', 'NORMAL', 'INTERNAL',
    '2026-02-10 21:15:00+05:30',
    '2026-02-10 22:00:00+05:30',
    'Chain snatching near Brigade Road. Accused fled on motorcycle.',
    'Brigade Road, Bengaluru',
    '40000000-0000-0000-0000-000000000003',
    '40000000-0000-0000-0000-000000000004',
    '40000000-0000-0000-0000-000000000003'
FROM reference.case_type ct WHERE ct.type_code = 'ROBBERY';

-- Case 3: Zero FIR example — initially at Women PS, transferred to Central PS
INSERT INTO case_mgmt.case
    (case_id, case_number,
     originating_station_id, current_station_id,
     case_type_id, case_status_code, priority, confidentiality_code,
     incident_date, opened_at,
     incident_description, incident_location,
     is_zero_fir, is_transferred,
     primary_io_id, supervising_officer_id, created_by)
SELECT
    '60000000-0000-0000-0000-000000000003',
    'CASE-KA-BLR-CEN-2026-00000003',
    '20000000-0000-0000-0000-000000000003',   -- originated at Women PS
    '20000000-0000-0000-0000-000000000001',   -- currently at Central PS
    ct.case_type_id, 'UNDER_INVESTIGATION', 'CRITICAL', 'RESTRICTED',
    '2026-03-05 23:45:00+05:30',
    '2026-03-05 23:55:00+05:30',
    'Victim reported assault. Zero FIR registered at Women PS as incident occurred in Central PS jurisdiction.',
    'Cubbon Park, Bengaluru',
    TRUE, TRUE,
    '40000000-0000-0000-0000-000000000002',
    '40000000-0000-0000-0000-000000000004',
    '40000000-0000-0000-0000-000000000005'
FROM reference.case_type ct WHERE ct.type_code = 'ASSAULT';

-- =============================================================================
-- SECTION H: FIRs
-- =============================================================================

-- FIR for Case 1 (primary demo)
INSERT INTO case_mgmt.fir
    (fir_id, case_id, fir_number, fir_year, station_id, fir_type,
     complainant_person_id, incident_date, incident_location,
     incident_description, ipc_sections, bnss_sections,
     registered_by, registered_at, fir_status)
VALUES
    ('70000000-0000-0000-0000-000000000001',
     '60000000-0000-0000-0000-000000000001',
     'FIR/001/2026', 2026,
     '20000000-0000-0000-0000-000000000001', 'REGULAR',
     '30000000-0000-0000-0000-000000000010',
     '2026-01-15 14:30:00+05:30',
     'MG Road, Bengaluru',
     'Complainant Anand Verma states that on 15-01-2026 at about 2:30 PM he received WhatsApp calls from unknown number claiming to be SBI official. Caller obtained OTP and Rs.4,50,000 was debited from complainant account.',
     '420, 419, 66C, 66D IT Act',
     '318 BNSS',
     '40000000-0000-0000-0000-000000000002',
     '2026-01-15 16:00:00+05:30',
     'REGISTERED');

-- Zero FIR for Case 3
INSERT INTO case_mgmt.fir
    (fir_id, case_id, fir_number, fir_year, station_id, fir_type,
     complainant_person_id, incident_date, incident_location,
     incident_description,
     registered_by, registered_at, fir_status,
     transferred_to_station_id, transferred_at,
     transfer_reason_code)
VALUES
    ('70000000-0000-0000-0000-000000000003',
     '60000000-0000-0000-0000-000000000003',
     'FIR/015/2026', 2026,
     '20000000-0000-0000-0000-000000000003', 'ZERO_FIR',
     '30000000-0000-0000-0000-000000000013',
     '2026-03-05 23:45:00+05:30',
     'Cubbon Park, Bengaluru',
     'Victim Mohan Das reported assault by unknown persons at Cubbon Park. Zero FIR registered as victim approached Women PS outside jurisdiction.',
     '40000000-0000-0000-0000-000000000005',
     '2026-03-05 23:55:00+05:30',
     'TRANSFERRED',
     '20000000-0000-0000-0000-000000000001',
     '2026-03-06 02:00:00+05:30',
     'ZERO_FIR');

-- Re-registered FIR at Central PS after Zero FIR transfer
INSERT INTO case_mgmt.fir
    (fir_id, case_id, fir_number, fir_year, station_id, fir_type,
     zero_fir_parent_id,
     complainant_person_id, incident_date, incident_location,
     incident_description,
     registered_by, registered_at, fir_status)
VALUES
    ('70000000-0000-0000-0000-000000000004',
     '60000000-0000-0000-0000-000000000003',
     'FIR/022/2026', 2026,
     '20000000-0000-0000-0000-000000000001', 'RE_REGISTERED',
     '70000000-0000-0000-0000-000000000003',
     '30000000-0000-0000-0000-000000000013',
     '2026-03-05 23:45:00+05:30',
     'Cubbon Park, Bengaluru',
     'Re-registered FIR based on Zero FIR No. FIR/015/2026 from Women PS Bengaluru. Victim Mohan Das assaulted by 3 unknown persons at Cubbon Park.',
     '40000000-0000-0000-0000-000000000002',
     '2026-03-06 08:00:00+05:30',
     'REGISTERED');

-- =============================================================================
-- SECTION I: CASE TRANSFERS
-- =============================================================================

INSERT INTO case_mgmt.case_transfer
    (case_id,
     source_station_id, source_fir_id,
     dest_station_id,   dest_fir_id,
     reason_code, reason_detail,
     transfer_order_no,
     initiated_by, approved_by, approved_at,
     transfer_timestamp, transfer_status)
VALUES
    ('60000000-0000-0000-0000-000000000003',
     '20000000-0000-0000-0000-000000000003',
     '70000000-0000-0000-0000-000000000003',
     '20000000-0000-0000-0000-000000000001',
     '70000000-0000-0000-0000-000000000004',
     'ZERO_FIR', 'Zero FIR transfer to jurisdictional station',
     'BWPS/TRF/2026/015',
     '40000000-0000-0000-0000-000000000005',
     '40000000-0000-0000-0000-000000000004',
     '2026-03-06 01:30:00+05:30',
     '2026-03-06 02:00:00+05:30',
     'COMPLETED');

-- =============================================================================
-- SECTION J: OFFICER CASE ASSIGNMENTS
-- =============================================================================

-- Case 1 assignments
INSERT INTO authz.officer_case_assignment
    (case_id, officer_id, case_role_id, assigned_by, start_date, is_active, reason, scope)
SELECT '60000000-0000-0000-0000-000000000001',
       '40000000-0000-0000-0000-000000000002',
       cr.case_role_id,
       '40000000-0000-0000-0000-000000000004',
       '2026-01-15', TRUE,
       'Assigned as Primary IO for cyber fraud case',
       '{"resource_types": ["CASE","FIR","EVIDENCE","DOCUMENT","CUSTODY","FORENSIC"]}'
FROM reference.case_role cr WHERE cr.role_code = 'PRIMARY_IO';

INSERT INTO authz.officer_case_assignment
    (case_id, officer_id, case_role_id, assigned_by, start_date, is_active, reason, scope)
SELECT '60000000-0000-0000-0000-000000000001',
       '40000000-0000-0000-0000-000000000004',
       cr.case_role_id,
       '40000000-0000-0000-0000-000000000001',
       '2026-01-15', TRUE,
       'SHO supervising case',
       '{}'
FROM reference.case_role cr WHERE cr.role_code = 'CASE_OWNER';

INSERT INTO authz.officer_case_assignment
    (case_id, officer_id, case_role_id, assigned_by, start_date, is_active, reason, scope)
SELECT '60000000-0000-0000-0000-000000000001',
       '40000000-0000-0000-0000-000000000006',
       cr.case_role_id,
       '40000000-0000-0000-0000-000000000004',
       '2026-01-15', TRUE,
       'Malkhana custodian for seized items',
       '{"resource_types": ["EVIDENCE","CUSTODY"]}'
FROM reference.case_role cr WHERE cr.role_code = 'EVIDENCE_CUSTODIAN';

INSERT INTO authz.officer_case_assignment
    (case_id, officer_id, case_role_id, assigned_by, start_date, is_active, reason, scope)
SELECT '60000000-0000-0000-0000-000000000001',
       '40000000-0000-0000-0000-000000000007',
       cr.case_role_id,
       '40000000-0000-0000-0000-000000000004',
       '2026-01-16', TRUE,
       'Cyber officer for digital evidence analysis',
       '{"resource_types": ["EVIDENCE","FORENSIC","DOCUMENT"]}'
FROM reference.case_role cr WHERE cr.role_code = 'DIGITAL_EVIDENCE_OFFICER';

-- =============================================================================
-- SECTION K: CASE PERSONS
-- =============================================================================

INSERT INTO identity.case_person
    (case_id, person_id, role_type_code, added_by)
VALUES
    ('60000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000010', 'COMPLAINANT', '40000000-0000-0000-0000-000000000002'),
    ('60000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000011', 'ACCUSED',     '40000000-0000-0000-0000-000000000002'),
    ('60000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000012', 'WITNESS',     '40000000-0000-0000-0000-000000000002');

-- =============================================================================
-- SECTION L: CUSTODIANS
-- =============================================================================

INSERT INTO custody.custodian
    (custodian_id, custodian_type_code, officer_id, display_name)
VALUES
    ('80000000-0000-0000-0000-000000000001', 'OFFICER', '40000000-0000-0000-0000-000000000002', 'SI Arjun Rao — Investigating Officer'),
    ('80000000-0000-0000-0000-000000000006', 'OFFICER', '40000000-0000-0000-0000-000000000006', 'HC Vikram Singh — Malkhana In-Charge'),
    ('80000000-0000-0000-0000-000000000007', 'OFFICER', '40000000-0000-0000-0000-000000000007', 'SI Meena Krishnan — Digital Evidence Officer');

INSERT INTO custody.custodian
    (custodian_id, custodian_type_code, station_id, display_name)
VALUES
    ('80000000-0000-0000-0000-000000000010', 'MALKHANA', '20000000-0000-0000-0000-000000000001', 'Malkhana — Central Police Station Bengaluru');

INSERT INTO custody.custodian
    (custodian_id, custodian_type_code, lab_id, display_name)
SELECT '80000000-0000-0000-0000-000000000020', 'FSL', lab_id, 'FSL Bengaluru — Forensic Science Laboratory'
FROM organisation.forensic_laboratory WHERE lab_code = 'FSL-KA-BLR';

INSERT INTO custody.custodian
    (custodian_id, custodian_type_code, court_id, display_name)
SELECT '80000000-0000-0000-0000-000000000030', 'COURT', court_id, 'City Civil and Sessions Court Bengaluru'
FROM organisation.court WHERE court_code = 'COURT-KA-BLR-01';

-- =============================================================================
-- SECTION M: EVIDENCE
-- =============================================================================

-- E001: Mobile Phone (original seized item)
INSERT INTO evidence.evidence
    (evidence_id, case_id, evidence_number, evidence_type_id,
     description, source, discovery_method, collection_timestamp,
     collection_location, collected_by,
     current_status_code, classification_code,
     make, model, serial_number, colour, condition_on_collection,
     seal_number, seal_applied_by, seal_applied_at,
     sha256_hash, integrity_status)
SELECT
    '90000000-0000-0000-0000-000000000001',
    '60000000-0000-0000-0000-000000000001',
    'E001',
    et.evidence_type_id,
    'Samsung Galaxy A52 mobile phone — alleged device used in cyber fraud',
    'Recovered from accused Farhan Sheikh residence during search',
    'SEARCH', '2026-01-18 11:00:00+05:30',
    '202 Shivajinagar, Bengaluru',
    '40000000-0000-0000-0000-000000000002',
    'IN_MALKHANA', 'CONFIDENTIAL',
    'Samsung', 'Galaxy A52', 'R5CR30XXXXX', 'Blue',
    'Good condition, screen intact, battery at 40%',
    'SEAL-2026-CEN-001',
    '40000000-0000-0000-0000-000000000002',
    '2026-01-18 11:15:00+05:30',
    'a3f5c8d9e1b2f4a67890abcdef123456a3f5c8d9e1b2f4a67890abcdef123456',
    'INTACT'
FROM reference.evidence_type et WHERE et.type_code = 'MOBILE_PHONE';

-- E002: Forensic Image (derived from E001)
INSERT INTO evidence.evidence
    (evidence_id, case_id, evidence_number, evidence_type_id,
     description, source, discovery_method, collection_timestamp,
     collected_by, current_status_code, classification_code,
     sha256_hash, integrity_status,
     storage_object_id, storage_provider, storage_path, object_key, mime_type, file_size_bytes)
SELECT
    '90000000-0000-0000-0000-000000000002',
    '60000000-0000-0000-0000-000000000001',
    'E002',
    et.evidence_type_id,
    'Physical forensic image of Samsung Galaxy A52 (E001) — full physical acquisition',
    'FSL Bengaluru Digital Forensics Lab',
    'FORENSIC_ACQUISITION', '2026-01-25 10:30:00+05:30',
    '40000000-0000-0000-0000-000000000007',
    'AT_FSL', 'CONFIDENTIAL',
    'b4e6d0c1f3a57890bcdef234567890b4e6d0c1f3a57890bcdef234567890abcd',
    'INTACT',
    'fsl-images/case-001/E002_samsung_a52_physical.E01',
    'MINIO', 'fsl-evidence',
    'case-001/E002_samsung_a52_physical.E01',
    'application/octet-stream', 68719476736
FROM reference.evidence_type et WHERE et.type_code = 'FORENSIC_IMAGE';

-- E003: Chat Database extracted from E002
INSERT INTO evidence.evidence
    (evidence_id, case_id, evidence_number, evidence_type_id,
     description, source, discovery_method, collection_timestamp,
     collected_by, current_status_code, classification_code,
     sha256_hash, integrity_status,
     storage_object_id, storage_provider, storage_path, object_key, mime_type, file_size_bytes)
SELECT
    '90000000-0000-0000-0000-000000000003',
    '60000000-0000-0000-0000-000000000001',
    'E003',
    et.evidence_type_id,
    'WhatsApp message database extracted from forensic image — msgstore.db',
    'Extracted from E002 forensic image using Cellebrite UFED',
    'FORENSIC_EXTRACTION', '2026-01-26 14:00:00+05:30',
    '40000000-0000-0000-0000-000000000007',
    'AT_FSL', 'CONFIDENTIAL',
    'c5f7e1d2a4b68901cdef345678901234c5f7e1d2a4b68901cdef345678901234',
    'INTACT',
    'fsl-artifacts/case-001/E003_whatsapp_msgstore.db',
    'MINIO', 'fsl-evidence',
    'case-001/E003_whatsapp_msgstore.db',
    'application/octet-stream', 52428800
FROM reference.evidence_type et WHERE et.type_code = 'DATABASE_EXTRACT';

-- E004: Screenshot from E003
INSERT INTO evidence.evidence
    (evidence_id, case_id, evidence_number, evidence_type_id,
     description, source, discovery_method, collection_timestamp,
     collected_by, current_status_code, classification_code,
     sha256_hash, integrity_status,
     storage_object_id, storage_provider, storage_path, object_key, mime_type, file_size_bytes)
SELECT
    '90000000-0000-0000-0000-000000000004',
    '60000000-0000-0000-0000-000000000001',
    'E004',
    et.evidence_type_id,
    'Screenshot of WhatsApp conversation showing OTP solicitation by accused — key evidence of fraud',
    'Derived from WhatsApp database E003',
    'FORENSIC_EXTRACTION', '2026-01-26 15:30:00+05:30',
    '40000000-0000-0000-0000-000000000007',
    'AT_FSL', 'CONFIDENTIAL',
    'd6a8f2e3b5c79012def456789012345d6a8f2e3b5c79012def456789012345ef',
    'INTACT',
    'fsl-artifacts/case-001/E004_whatsapp_screenshot.png',
    'MINIO', 'fsl-evidence',
    'case-001/E004_whatsapp_screenshot.png',
    'image/png', 524288
FROM reference.evidence_type et WHERE et.type_code = 'SCREENSHOT';

-- E005: Forensic Report document (evidence item)
INSERT INTO evidence.evidence
    (evidence_id, case_id, evidence_number, evidence_type_id,
     description, source, discovery_method, collection_timestamp,
     collected_by, current_status_code, classification_code,
     sha256_hash, integrity_status)
SELECT
    '90000000-0000-0000-0000-000000000005',
    '60000000-0000-0000-0000-000000000001',
    'E005',
    et.evidence_type_id,
    'Forensic Examination Report — Digital Forensics of Samsung Galaxy A52 by FSL Bengaluru',
    'FSL Bengaluru', 'FSL_REPORT',
    '2026-02-05 16:00:00+05:30',
    '40000000-0000-0000-0000-000000000002',
    'RETURNED_FROM_FSL', 'CONFIDENTIAL',
    'e7b9a3f4c6d80123ef0567890123456e7b9a3f4c6d80123ef0567890123456ab',
    'INTACT'
FROM reference.evidence_type et WHERE et.type_code = 'FORENSIC_REPORT';

-- =============================================================================
-- SECTION N: DIGITAL EVIDENCE RECORD FOR E001
-- =============================================================================

INSERT INTO evidence.digital_evidence
    (evidence_id, case_id,
     device_type, device_make, device_model, device_serial, device_imei,
     device_os, device_os_version,
     acquisition_method, acquisition_tool, acquisition_tool_version,
     acquired_by, acquired_at,
     original_hash, original_hash_algo,
     acquisition_hash, acquisition_hash_algo,
     write_blocker_used, write_blocker_model,
     analysis_status, analysis_completed_at,
     key_findings)
VALUES
    ('90000000-0000-0000-0000-000000000001',
     '60000000-0000-0000-0000-000000000001',
     'MOBILE', 'Samsung', 'Galaxy A52', 'R5CR30XXXXX', '354123456789012',
     'Android', '11',
     'PHYSICAL', 'Cellebrite UFED 4PC', '7.67.0.121',
     '40000000-0000-0000-0000-000000000007',
     '2026-01-25 10:30:00+05:30',
     'a3f5c8d9e1b2f4a67890abcdef123456a3f5c8d9e1b2f4a67890abcdef123456', 'SHA256',
     'b4e6d0c1f3a57890bcdef234567890b4e6d0c1f3a57890bcdef234567890abcd', 'SHA256',
     TRUE, 'Tableau T35689iU Write Blocker',
     'COMPLETED', '2026-01-26 17:00:00+05:30',
     'WhatsApp messages showing communication with complainant on 15-01-2026. '
     'OTP solicitation messages found. Bank app installed. '
     'Multiple victim contact numbers found. Location data supports presence near MG Road.');

-- =============================================================================
-- SECTION O: EVIDENCE RELATIONSHIPS (Graph 1)
-- =============================================================================

-- E002 DERIVED_FROM E001
SELECT evidence.create_evidence_relationship(
    '60000000-0000-0000-0000-000000000001'::UUID,
    '90000000-0000-0000-0000-000000000002'::UUID,
    '90000000-0000-0000-0000-000000000001'::UUID,
    'DERIVED_FROM',
    '40000000-0000-0000-0000-000000000007'::UUID,
    1.0, 'Physical forensic image created from seized mobile phone using write-blocker'
);

-- E003 EXTRACTED_FROM E002
SELECT evidence.create_evidence_relationship(
    '60000000-0000-0000-0000-000000000001'::UUID,
    '90000000-0000-0000-0000-000000000003'::UUID,
    '90000000-0000-0000-0000-000000000002'::UUID,
    'EXTRACTED_FROM',
    '40000000-0000-0000-0000-000000000007'::UUID,
    1.0, 'WhatsApp database extracted from forensic image using Cellebrite UFED'
);

-- E004 DERIVED_FROM E003
SELECT evidence.create_evidence_relationship(
    '60000000-0000-0000-0000-000000000001'::UUID,
    '90000000-0000-0000-0000-000000000004'::UUID,
    '90000000-0000-0000-0000-000000000003'::UUID,
    'DERIVED_FROM',
    '40000000-0000-0000-0000-000000000007'::UUID,
    0.95, 'Screenshot extracted from WhatsApp message database showing OTP solicitation'
);

-- E004 SUPPORTS Case (via relationship to E001)
SELECT evidence.create_evidence_relationship(
    '60000000-0000-0000-0000-000000000001'::UUID,
    '90000000-0000-0000-0000-000000000004'::UUID,
    '90000000-0000-0000-0000-000000000001'::UUID,
    'SAME_DEVICE',
    '40000000-0000-0000-0000-000000000007'::UUID,
    1.0, 'Screenshot originated from the same mobile device'
);

-- E005 REPORTS_ON E002
SELECT evidence.create_evidence_relationship(
    '60000000-0000-0000-0000-000000000001'::UUID,
    '90000000-0000-0000-0000-000000000005'::UUID,
    '90000000-0000-0000-0000-000000000002'::UUID,
    'REPORTS_ON',
    '40000000-0000-0000-0000-000000000002'::UUID,
    1.0, 'FSL report covers examination of forensic image E002'
);

-- =============================================================================
-- SECTION P: CHAIN OF CUSTODY (Graph 2)
-- =============================================================================

-- E001: SEIZED by SI Arjun Rao
SELECT custody.record_custody_transfer(
    '90000000-0000-0000-0000-000000000001'::UUID,
    '60000000-0000-0000-0000-000000000001'::UUID,
    'SEIZED',
    NULL,
    '80000000-0000-0000-0000-000000000001'::UUID,
    '40000000-0000-0000-0000-000000000002'::UUID,
    'Seized from accused during search under Section 165 CrPC',
    NULL, 'SEAL-2026-CEN-001',
    'Good condition, screen intact', 'Sealed in evidence bag',
    NULL, 'a3f5c8d9e1b2f4a67890abcdef123456a3f5c8d9e1b2f4a67890abcdef123456',
    'Seized in presence of two panchas'
);

-- E001: DEPOSITED in Malkhana
SELECT custody.record_custody_transfer(
    '90000000-0000-0000-0000-000000000001'::UUID,
    '60000000-0000-0000-0000-000000000001'::UUID,
    'DEPOSITED',
    '80000000-0000-0000-0000-000000000001'::UUID,
    '80000000-0000-0000-0000-000000000010'::UUID,
    '40000000-0000-0000-0000-000000000002'::UUID,
    'Deposited in Malkhana for safe custody pending FSL submission',
    'SEAL-2026-CEN-001', 'SEAL-2026-CEN-001',
    'Sealed — intact', 'Sealed — intact',
    'a3f5c8d9e1b2f4a67890abcdef123456a3f5c8d9e1b2f4a67890abcdef123456',
    'a3f5c8d9e1b2f4a67890abcdef123456a3f5c8d9e1b2f4a67890abcdef123456',
    'Malkhana register entry no. MKH/2026/0042'
);

-- E001: SENT_TO_FSL
SELECT custody.record_custody_transfer(
    '90000000-0000-0000-0000-000000000001'::UUID,
    '60000000-0000-0000-0000-000000000001'::UUID,
    'SENT_TO_FSL',
    '80000000-0000-0000-0000-000000000010'::UUID,
    '80000000-0000-0000-0000-000000000020'::UUID,
    '40000000-0000-0000-0000-000000000002'::UUID,
    'Sent to FSL Bengaluru for digital forensic examination',
    'SEAL-2026-CEN-001', 'SEAL-2026-CEN-001',
    'Sealed — intact', 'Sealed — intact',
    'a3f5c8d9e1b2f4a67890abcdef123456a3f5c8d9e1b2f4a67890abcdef123456',
    'a3f5c8d9e1b2f4a67890abcdef123456a3f5c8d9e1b2f4a67890abcdef123456',
    'FSL request number: FSL-REQ-KA-2026-000001. Sent by SI Arjun Rao.'
);

-- E001: RECEIVED_BY_FSL
SELECT custody.record_custody_transfer(
    '90000000-0000-0000-0000-000000000001'::UUID,
    '60000000-0000-0000-0000-000000000001'::UUID,
    'RECEIVED_BY_FSL',
    '80000000-0000-0000-0000-000000000020'::UUID,
    '80000000-0000-0000-0000-000000000020'::UUID,
    '40000000-0000-0000-0000-000000000007'::UUID,
    'Received at FSL — acknowledgement issued. Seal intact.',
    'SEAL-2026-CEN-001', 'SEAL-2026-CEN-001',
    'Sealed — intact', 'Opened for examination after receipt',
    NULL, NULL,
    'FSL receipt ref: FSL-KA-BLR/2026/REC/0089'
);

-- E001: RETURNED_FROM_FSL back to Malkhana
SELECT custody.record_custody_transfer(
    '90000000-0000-0000-0000-000000000001'::UUID,
    '60000000-0000-0000-0000-000000000001'::UUID,
    'RETURNED_FROM_FSL',
    '80000000-0000-0000-0000-000000000020'::UUID,
    '80000000-0000-0000-0000-000000000010'::UUID,
    '40000000-0000-0000-0000-000000000002'::UUID,
    'Returned from FSL after examination. Re-sealed with new seal.',
    'SEAL-2026-CEN-001', 'SEAL-2026-CEN-002',
    'Original seal broken for examination', 'Re-sealed post examination',
    'a3f5c8d9e1b2f4a67890abcdef123456a3f5c8d9e1b2f4a67890abcdef123456',
    'a3f5c8d9e1b2f4a67890abcdef123456a3f5c8d9e1b2f4a67890abcdef123456',
    'FSL report received. Device returned intact.'
);

-- =============================================================================
-- SECTION Q: FORENSIC REQUEST AND REPORT
-- =============================================================================

INSERT INTO forensic.forensic_request
    (request_id, case_id, request_number, lab_id, discipline_id,
     requested_by, approved_by, approved_at,
     examination_required, purpose, priority,
     submitted_at, submitted_by, submission_ref,
     request_status)
SELECT
    'A0000000-0000-0000-0000-000000000001',
    '60000000-0000-0000-0000-000000000001',
    'FSL-REQ-KA-2026-000001',
    fl.lab_id,
    fd.discipline_id,
    '40000000-0000-0000-0000-000000000002',
    '40000000-0000-0000-0000-000000000004',
    '2026-01-20 10:00:00+05:30',
    'Physical acquisition of mobile phone. Extract call records, WhatsApp messages, '
    'browsing history, installed apps, location data, and any evidence of fraud.',
    'To examine mobile phone seized from accused and extract digital evidence '
    'relevant to cyber fraud case.',
    'HIGH',
    '2026-01-22 11:00:00+05:30',
    '40000000-0000-0000-0000-000000000002',
    'FSL-KA-BLR/2026/REC/0089',
    'RECEIVED'
FROM organisation.forensic_laboratory fl,
     reference.forensic_discipline fd
WHERE fl.lab_code = 'FSL-KA-BLR'
  AND fd.discipline_code = 'DIGITAL_FORENSICS';

INSERT INTO forensic.forensic_request_evidence
    (request_id, evidence_id, case_id, examination_required, item_seal_number)
VALUES
    ('A0000000-0000-0000-0000-000000000001',
     '90000000-0000-0000-0000-000000000001',
     '60000000-0000-0000-0000-000000000001',
     'Full physical acquisition, WhatsApp extraction, call log, location history',
     'SEAL-2026-CEN-001');

INSERT INTO forensic.forensic_examination
    (examination_id, request_id, case_id, lab_id, discipline_id,
     examiner_name, examiner_designation, examiner_employee_id,
     started_at, completed_at, examination_status,
     methods_used, instruments_used, lab_reference_number)
SELECT
    'A0000000-0000-0000-0000-000000000010',
    'A0000000-0000-0000-0000-000000000001',
    '60000000-0000-0000-0000-000000000001',
    fl.lab_id,
    fd.discipline_id,
    'Dr. Nalini Subramaniam',
    'Scientific Officer (Grade I)',
    'FSL-KA-EMP-042',
    '2026-01-25 09:00:00+05:30',
    '2026-01-30 17:00:00+05:30',
    'COMPLETED',
    'Physical acquisition using Cellebrite UFED 4PC. Logical extraction. '
    'File system analysis. Application data analysis. Hash verification.',
    'Cellebrite UFED 4PC v7.67, FTK Imager 4.7, Tableau T35689iU Write Blocker',
    'FSL/KA/BLR/DF/2026/0089'
FROM organisation.forensic_laboratory fl,
     reference.forensic_discipline fd
WHERE fl.lab_code = 'FSL-KA-BLR'
  AND fd.discipline_code = 'DIGITAL_FORENSICS';

INSERT INTO forensic.forensic_result
    (examination_id, request_id, case_id, evidence_id,
     question_examined, finding, conclusion, opinion, result_type)
VALUES
    ('A0000000-0000-0000-0000-000000000010',
     'A0000000-0000-0000-0000-000000000001',
     '60000000-0000-0000-0000-000000000001',
     '90000000-0000-0000-0000-000000000001',
     'WhatsApp messages between accused and complainant on 15-01-2026',
     'WhatsApp conversation thread found between number +91-98000XXXXX (registered to complainant) '
     'and +91-77000XXXXX (number on accused device). Messages show accused posing as '
     '"SBI Customer Care" requesting OTP. OTP "826571" sent by complainant at 14:47:32 IST.',
     'Digital evidence confirms WhatsApp-based OTP fraud on 15-01-2026.',
     'In my expert opinion, the recovered WhatsApp messages constitute direct evidence '
     'of cyber fraud under Section 66C and 66D IT Act.',
     'POSITIVE');

INSERT INTO forensic.forensic_report
    (report_id, request_id, case_id, lab_id,
     report_number, report_date,
     examiner_name, examiner_designation,
     summary, conclusions,
     report_status, received_by, received_at)
SELECT
    'A0000000-0000-0000-0000-000000000020',
    'A0000000-0000-0000-0000-000000000001',
    '60000000-0000-0000-0000-000000000001',
    fl.lab_id,
    'FSL/KA/BLR/DF/RPT/2026/0089',
    '2026-02-03',
    'Dr. Nalini Subramaniam',
    'Scientific Officer (Grade I), FSL Bengaluru',
    'Physical forensic examination of Samsung Galaxy A52 mobile phone seized from accused. '
    'Complete data extraction performed. WhatsApp messages, call logs and location data recovered.',
    'WhatsApp conversation confirms OTP solicitation by accused on 15-01-2026. '
    'Location data places device near MG Road Bengaluru at time of fraud. '
    'Hash values confirm integrity of extracted data.',
    'RECEIVED',
    '40000000-0000-0000-0000-000000000002',
    '2026-02-05 11:00:00+05:30'
FROM organisation.forensic_laboratory fl WHERE fl.lab_code = 'FSL-KA-BLR';

-- =============================================================================
-- SECTION R: DOCUMENTS
-- =============================================================================

-- FIR Document
INSERT INTO documents.document
    (document_id, document_ref, document_type_id, title,
     case_id, station_id,
     classification_code, retention_category,
     owner_officer_id, created_by)
SELECT
    'B0000000-0000-0000-0000-000000000001',
    'DOC-KA-BLR-CEN-2026-000001',
    dt.document_type_id,
    'FIR No. FIR/001/2026 — Cyber Fraud Case',
    '60000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000001',
    'CONFIDENTIAL', 'LONG_TERM',
    '40000000-0000-0000-0000-000000000002',
    '40000000-0000-0000-0000-000000000002'
FROM reference.document_type dt WHERE dt.type_code = 'FIR';

-- FIR Document Version 1 (draft)
INSERT INTO documents.document_version
    (version_id, document_id, version_number, version_label,
     storage_object_id, storage_provider, storage_path, object_key,
     file_name, mime_type, file_size_bytes,
     sha256_hash, hash_algorithm,
     status_code, change_reason, created_by)
VALUES
    ('B0000000-0000-0000-0001-000000000001',
     'B0000000-0000-0000-0000-000000000001',
     1, 'v1.0 — Initial Draft',
     'fir-docs/case-001/FIR_001_2026_v1.pdf',
     'MINIO', 'police-documents', 'case-001/FIR_001_2026_v1.pdf',
     'FIR_001_2026_v1.pdf', 'application/pdf', 524288,
     'f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6',
     'SHA256', 'DRAFT', 'Initial FIR draft',
     '40000000-0000-0000-0000-000000000002');

-- FIR Document Version 2 (reviewed)
INSERT INTO documents.document_version
    (version_id, document_id, version_number, version_label,
     storage_object_id, storage_provider, storage_path, object_key,
     file_name, mime_type, file_size_bytes,
     sha256_hash, hash_algorithm,
     previous_version_id,
     status_code, change_reason, created_by)
VALUES
    ('B0000000-0000-0000-0002-000000000001',
     'B0000000-0000-0000-0000-000000000001',
     2, 'v2.0 — Final',
     'fir-docs/case-001/FIR_001_2026_v2.pdf',
     'MINIO', 'police-documents', 'case-001/FIR_001_2026_v2.pdf',
     'FIR_001_2026_v2.pdf', 'application/pdf', 548864,
     'aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899',
     'SHA256',
     'B0000000-0000-0000-0001-000000000001',
     'APPROVED', 'Corrected sections, approved by SHO',
     '40000000-0000-0000-0000-000000000002');

-- Update document current_version_id
UPDATE documents.document
SET current_version_id = 'B0000000-0000-0000-0002-000000000001',
    current_version_no = 2
WHERE document_id = 'B0000000-0000-0000-0000-000000000001';

-- Finalize version 2
SELECT documents.finalize_document_version(
    'B0000000-0000-0000-0002-000000000001'::UUID,
    '40000000-0000-0000-0000-000000000004'::UUID
);

-- Digital signature on v2
INSERT INTO documents.digital_signature
    (signature_id, document_id, document_version_id,
     signer_officer_id, signer_name, signer_role,
     signature_algorithm, signed_hash, hash_algorithm,
     signature_value_b64,
     certificate_subject, signed_at, signature_status)
VALUES
    ('C0000000-0000-0000-0000-000000000001',
     'B0000000-0000-0000-0000-000000000001',
     'B0000000-0000-0000-0002-000000000001',
     '40000000-0000-0000-0000-000000000004',
     'Inspector Suresh Patil',
     'SHO, Central Police Station Bengaluru',
     'RSA_SHA256',
     'aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899',
     'SHA256',
     'DEMO_SIGNATURE_VALUE_BASE64_PLACEHOLDER==',
     'CN=Suresh Patil, O=Karnataka Police, C=IN',
     '2026-01-16 10:00:00+05:30',
     'VALID');

-- Link signature to version
UPDATE documents.document_version
SET digital_signature_id = 'C0000000-0000-0000-0000-000000000001'
WHERE version_id = 'B0000000-0000-0000-0002-000000000001';

-- Case document junction
INSERT INTO documents.case_document (case_id, document_id, link_type, added_by)
VALUES
    ('60000000-0000-0000-0000-000000000001',
     'B0000000-0000-0000-0000-000000000001',
     'FIR',
     '40000000-0000-0000-0000-000000000002');

-- Update FIR to reference document
UPDATE case_mgmt.fir
SET document_id = 'B0000000-0000-0000-0000-000000000001'
WHERE fir_id = '70000000-0000-0000-0000-000000000001';

-- =============================================================================
-- SECTION S: CASE EVENTS
-- =============================================================================

INSERT INTO case_mgmt.case_event
    (event_id, case_id, event_type_code, event_timestamp,
     recorded_by, title, description, location)
VALUES
    ('D0000000-0000-0000-0000-000000000001',
     '60000000-0000-0000-0000-000000000001',
     'FIR_REGISTERED', '2026-01-15 16:00:00+05:30',
     '40000000-0000-0000-0000-000000000002',
     'FIR No. FIR/001/2026 Registered',
     'FIR registered by SI Arjun Rao for cyber fraud. Complainant: Anand Verma.',
     'Central Police Station, Bengaluru'),

    ('D0000000-0000-0000-0000-000000000002',
     '60000000-0000-0000-0000-000000000001',
     'OFFICER_ASSIGNED', '2026-01-15 16:30:00+05:30',
     '40000000-0000-0000-0000-000000000004',
     'SI Arjun Rao Assigned as Primary IO',
     'SI Arjun Rao assigned as Primary Investigating Officer by SHO Suresh Patil.',
     'Central Police Station, Bengaluru'),

    ('D0000000-0000-0000-0000-000000000003',
     '60000000-0000-0000-0000-000000000001',
     'SEARCH_CONDUCTED', '2026-01-18 10:00:00+05:30',
     '40000000-0000-0000-0000-000000000002',
     'Search Conducted at Accused Premises',
     'Search conducted at 202 Shivajinagar, Bengaluru — premises of Farhan Sheikh under '
     'Section 165 CrPC in presence of two independent witnesses.',
     '202 Shivajinagar, Bengaluru'),

    ('D0000000-0000-0000-0000-000000000004',
     '60000000-0000-0000-0000-000000000001',
     'SEIZURE_MADE', '2026-01-18 11:00:00+05:30',
     '40000000-0000-0000-0000-000000000002',
     'Mobile Phone (E001) Seized',
     'Samsung Galaxy A52 mobile phone (IMEI: 354123456789012) seized from Farhan Sheikh. '
     'Sealed as E001 with seal SEAL-2026-CEN-001. Seizure memo prepared.',
     '202 Shivajinagar, Bengaluru'),

    ('D0000000-0000-0000-0000-000000000005',
     '60000000-0000-0000-0000-000000000001',
     'FSL_REQUESTED', '2026-01-22 11:00:00+05:30',
     '40000000-0000-0000-0000-000000000002',
     'FSL Request Submitted — Digital Forensics',
     'FSL request FSL-REQ-KA-2026-000001 submitted to FSL Bengaluru for digital forensic '
     'examination of seized mobile phone E001.',
     'Central Police Station, Bengaluru'),

    ('D0000000-0000-0000-0000-000000000006',
     '60000000-0000-0000-0000-000000000001',
     'FSL_REPORT_RECEIVED', '2026-02-05 11:00:00+05:30',
     '40000000-0000-0000-0000-000000000002',
     'FSL Report Received',
     'Forensic report FSL/KA/BLR/DF/RPT/2026/0089 received from FSL Bengaluru. '
     'WhatsApp evidence confirms fraud. Hash values verified.',
     'Central Police Station, Bengaluru'),

    ('D0000000-0000-0000-0000-000000000007',
     '60000000-0000-0000-0000-000000000001',
     'WITNESS_STATEMENT_RECORDED', '2026-02-10 14:00:00+05:30',
     '40000000-0000-0000-0000-000000000002',
     'Witness Statement of Sunita Reddy Recorded',
     'Section 161 CrPC statement of witness Sunita Reddy recorded. '
     'Witness confirms seeing accused use mobile phone on the date of incident.',
     'Central Police Station, Bengaluru');

-- =============================================================================
-- SECTION T: CASE DIARY ENTRIES
-- =============================================================================

INSERT INTO investigation.case_diary
    (case_id, entry_date, entry_time, entry_timestamp,
     officer_id, subject, content, location)
VALUES
    ('60000000-0000-0000-0000-000000000001',
     '2026-01-15', '16:30:00+05:30', '2026-01-15 16:30:00+05:30',
     '40000000-0000-0000-0000-000000000002',
     'FIR Registration and Initial Steps',
     'FIR No. FIR/001/2026 registered based on complaint of Anand Verma S/o Ramesh Verma, '
     'R/o 101 MG Road Bengaluru. Complainant states that on 15-01-2026 at about 14:30 hrs he '
     'received WhatsApp call from unknown number. Caller identified himself as SBI official '
     'and asked for OTP. Complainant shared OTP and subsequently Rs.4,50,000 was debited. '
     'Case registered under Section 420, 419 IPC and 66C, 66D IT Act. '
     'Assigned as IO. Verification of complainant bank records initiated.',
     'Central Police Station, Bengaluru'),

    ('60000000-0000-0000-0000-000000000001',
     '2026-01-18', '13:00:00+05:30', '2026-01-18 13:00:00+05:30',
     '40000000-0000-0000-0000-000000000002',
     'Search and Seizure at Accused Premises',
     'On the basis of call detail records obtained from telecom company, search conducted at '
     '202 Shivajinagar premises of Farhan Sheikh S/o Abdul Sheikh. Search conducted under '
     'Section 165 CrPC in presence of two pancha witnesses. '
     'One Samsung Galaxy A52 mobile phone IMEI 354123456789012 found and seized. '
     'Sealed with Seal No. SEAL-2026-CEN-001. Seizure memo prepared.',
     '202 Shivajinagar, Bengaluru');

-- =============================================================================
-- SECTION U: AUDIT EVENTS (representative sample)
-- =============================================================================

SELECT audit.create_audit_event(
    'FIR_CREATE',
    '40000000-0000-0000-0000-000000000002'::UUID,
    '20000000-0000-0000-0000-000000000001'::UUID,
    '60000000-0000-0000-0000-000000000001'::UUID,
    'FIR', '70000000-0000-0000-0000-000000000001'::UUID,
    'FIR/001/2026', 'SUCCESS', NULL, NULL,
    NULL, 'FIR registration',
    '192.168.1.100'::INET, NULL, '{}'
);

SELECT audit.create_audit_event(
    'EVIDENCE_CREATE',
    '40000000-0000-0000-0000-000000000002'::UUID,
    '20000000-0000-0000-0000-000000000001'::UUID,
    '60000000-0000-0000-0000-000000000001'::UUID,
    'EVIDENCE', '90000000-0000-0000-0000-000000000001'::UUID,
    'E001', 'SUCCESS', NULL, NULL,
    NULL, 'Evidence seized and registered',
    '192.168.1.100'::INET, NULL, '{}'
);

SELECT audit.create_audit_event(
    'CUSTODY_TRANSFER',
    '40000000-0000-0000-0000-000000000002'::UUID,
    '20000000-0000-0000-0000-000000000001'::UUID,
    '60000000-0000-0000-0000-000000000001'::UUID,
    'CUSTODY', '90000000-0000-0000-0000-000000000001'::UUID,
    'E001-CUSTODY', 'SUCCESS', NULL, NULL,
    NULL, 'E001 deposited in Malkhana',
    '192.168.1.100'::INET, NULL, '{}'
);

SELECT audit.create_audit_event(
    'DOCUMENT_UPLOAD',
    '40000000-0000-0000-0000-000000000002'::UUID,
    '20000000-0000-0000-0000-000000000001'::UUID,
    '60000000-0000-0000-0000-000000000001'::UUID,
    'DOCUMENT', 'B0000000-0000-0000-0000-000000000001'::UUID,
    'DOC-KA-BLR-CEN-2026-000001', 'SUCCESS', NULL, NULL,
    NULL, 'FIR document uploaded',
    '192.168.1.100'::INET, NULL, '{}'
);

SELECT audit.create_audit_event(
    'DOCUMENT_SIGN',
    '40000000-0000-0000-0000-000000000004'::UUID,
    '20000000-0000-0000-0000-000000000001'::UUID,
    '60000000-0000-0000-0000-000000000001'::UUID,
    'DOCUMENT', 'B0000000-0000-0000-0000-000000000001'::UUID,
    'DOC-KA-BLR-CEN-2026-000001', 'SUCCESS', NULL, NULL,
    NULL, 'FIR v2 finalized and signed by SHO',
    '192.168.1.101'::INET, NULL, '{}'
);

SELECT audit.create_audit_event(
    'DOCUMENT_DOWNLOAD',
    '40000000-0000-0000-0000-000000000002'::UUID,
    '20000000-0000-0000-0000-000000000001'::UUID,
    '60000000-0000-0000-0000-000000000001'::UUID,
    'DOCUMENT', 'B0000000-0000-0000-0000-000000000001'::UUID,
    'DOC-KA-BLR-CEN-2026-000001', 'SUCCESS', NULL, NULL,
    NULL, 'FIR downloaded by IO for review',
    '192.168.1.100'::INET, NULL, '{}'
);

-- =============================================================================
-- SECTION V: INTEGRATION REFERENCES
-- =============================================================================

INSERT INTO integration.external_reference
    (system_name, local_entity_type, local_entity_id,
     external_record_id, sync_status, created_by)
VALUES
    ('CCTNS', 'CASE', '60000000-0000-0000-0000-000000000001',
     'CCTNS/KA/BLR/2026/00001', 'SYNCED',
     '40000000-0000-0000-0000-000000000002'),
    ('CCTNS', 'FIR', '70000000-0000-0000-0000-000000000001',
     'CCTNS/KA/BLR/FIR/2026/001', 'SYNCED',
     '40000000-0000-0000-0000-000000000002');

-- COMMIT;
