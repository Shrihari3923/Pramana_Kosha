-- 001_initial_schema.sql
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
CREATE SCHEMA IF NOT EXISTS authorization;   -- roles, permissions, policies
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
COMMENT ON SCHEMA authorization IS 'Roles, permissions, case access policies';
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
-- 005_authorization.sql
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
CREATE TABLE authorization.system_role (
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

INSERT INTO authorization.system_role (role_code, role_name, description, is_system) VALUES
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
CREATE TABLE authorization.role_permission (
    role_permission_id  UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    role_id             UUID         NOT NULL REFERENCES authorization.system_role(role_id),
    permission_id       UUID         NOT NULL REFERENCES reference.permission(permission_id),
    granted_by          UUID         REFERENCES identity.officer(officer_id),
    granted_at          TIMESTAMPTZ  NOT NULL DEFAULT now(),
    is_active           BOOLEAN      NOT NULL DEFAULT TRUE,
    UNIQUE (role_id, permission_id)
);

-- ---------------------------------------------------------------------------
-- 3. OFFICER SYSTEM ROLE — assign system roles to officers
-- ---------------------------------------------------------------------------
CREATE TABLE authorization.officer_system_role (
    assignment_id   UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    officer_id      UUID         NOT NULL REFERENCES identity.officer(officer_id),
    role_id         UUID         NOT NULL REFERENCES authorization.system_role(role_id),
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

CREATE INDEX idx_osr_officer  ON authorization.officer_system_role(officer_id);
CREATE INDEX idx_osr_role     ON authorization.officer_system_role(role_id);
CREATE INDEX idx_osr_station  ON authorization.officer_system_role(station_id);

-- ---------------------------------------------------------------------------
-- 4. CASE ROLE PERMISSION — what each case role can do
--    This is the case-scoped permission set evaluated when an officer
--    accesses a specific case resource.
-- ---------------------------------------------------------------------------
CREATE TABLE authorization.case_role_permission (
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
CREATE TABLE authorization.officer_case_assignment (
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
    ON authorization.officer_case_assignment(case_id, officer_id, case_role_id)
    WHERE is_active = TRUE;

CREATE INDEX idx_oca_case     ON authorization.officer_case_assignment(case_id);
CREATE INDEX idx_oca_officer  ON authorization.officer_case_assignment(officer_id);
CREATE INDEX idx_oca_role     ON authorization.officer_case_assignment(case_role_id);

-- ---------------------------------------------------------------------------
-- 6. ACCESS POLICY — named policies that can be applied to resources
--    Policies are evaluated server-side by the authorization service.
--    They reference permission codes and conditions as JSONB.
-- ---------------------------------------------------------------------------
CREATE TABLE authorization.access_policy (
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
CREATE TABLE authorization.policy_rule (
    rule_id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    policy_id        UUID         NOT NULL REFERENCES authorization.access_policy(policy_id),
    rule_order       SMALLINT     NOT NULL DEFAULT 0,
    description      TEXT,
    conditions       JSONB        NOT NULL DEFAULT '{}',
    is_active        BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_policy_rule_policy ON authorization.policy_rule(policy_id);

-- ---------------------------------------------------------------------------
-- 8. DOCUMENT ACCESS POLICY — classification-level access rules
--    Maps classification level to minimum required rank level or role.
-- ---------------------------------------------------------------------------
CREATE TABLE authorization.document_access_policy (
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

INSERT INTO authorization.document_access_policy
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
--             SELECT 1 FROM authorization.officer_case_assignment oca
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
    INSERT INTO authorization.case_role_permission (case_role_id, permission_id)
    SELECT v_primary_io, permission_id FROM reference.permission
    WHERE permission_code IN (
        'CASE_VIEW','CASE_EDIT','FIR_CREATE','FIR_VIEW','FIR_EDIT',
        'EVIDENCE_CREATE','EVIDENCE_VIEW','EVIDENCE_EDIT','EVIDENCE_TRANSFER','EVIDENCE_VERIFY',
        'DOCUMENT_UPLOAD','DOCUMENT_VIEW','DOCUMENT_DOWNLOAD','DOCUMENT_SIGN','DOCUMENT_VERSION_CREATE',
        'FORENSIC_REQUEST_CREATE','FORENSIC_REPORT_VIEW',
        'CUSTODY_VIEW','CUSTODY_TRANSFER','CASE_EXPORT'
    );

    -- ASSISTANT_IO
    INSERT INTO authorization.case_role_permission (case_role_id, permission_id)
    SELECT v_asst_io, permission_id FROM reference.permission
    WHERE permission_code IN (
        'CASE_VIEW','FIR_VIEW',
        'EVIDENCE_CREATE','EVIDENCE_VIEW','EVIDENCE_EDIT','EVIDENCE_VERIFY',
        'DOCUMENT_UPLOAD','DOCUMENT_VIEW','DOCUMENT_DOWNLOAD','DOCUMENT_VERSION_CREATE',
        'FORENSIC_REPORT_VIEW','CUSTODY_VIEW','CUSTODY_TRANSFER'
    );

    -- SUPERVISING_OFFICER
    INSERT INTO authorization.case_role_permission (case_role_id, permission_id)
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
    INSERT INTO authorization.case_role_permission (case_role_id, permission_id)
    SELECT v_case_owner, permission_id FROM reference.permission;

    -- EVIDENCE_CUSTODIAN — evidence and custody only
    INSERT INTO authorization.case_role_permission (case_role_id, permission_id)
    SELECT v_ev_custodian, permission_id FROM reference.permission
    WHERE permission_code IN (
        'CASE_VIEW','EVIDENCE_VIEW','EVIDENCE_EDIT','EVIDENCE_TRANSFER','EVIDENCE_VERIFY',
        'CUSTODY_VIEW','CUSTODY_TRANSFER','DOCUMENT_VIEW'
    );

    -- DIGITAL_EVIDENCE_OFFICER — digital evidence only
    INSERT INTO authorization.case_role_permission (case_role_id, permission_id)
    SELECT v_dig_ev_officer, permission_id FROM reference.permission
    WHERE permission_code IN (
        'CASE_VIEW','EVIDENCE_VIEW','EVIDENCE_CREATE','EVIDENCE_EDIT','EVIDENCE_VERIFY',
        'FORENSIC_REQUEST_CREATE','FORENSIC_REPORT_VIEW',
        'DOCUMENT_UPLOAD','DOCUMENT_VIEW','DOCUMENT_DOWNLOAD','DOCUMENT_VERSION_CREATE',
        'CUSTODY_VIEW'
    );

    -- FORENSIC_COORDINATOR
    INSERT INTO authorization.case_role_permission (case_role_id, permission_id)
    SELECT v_forensic_coord, permission_id FROM reference.permission
    WHERE permission_code IN (
        'CASE_VIEW','EVIDENCE_VIEW',
        'FORENSIC_REQUEST_CREATE','FORENSIC_REPORT_VIEW',
        'DOCUMENT_VIEW','DOCUMENT_DOWNLOAD','CUSTODY_VIEW'
    );

    -- COURT_LIAISON
    INSERT INTO authorization.case_role_permission (case_role_id, permission_id)
    SELECT v_court_liaison, permission_id FROM reference.permission
    WHERE permission_code IN (
        'CASE_VIEW','FIR_VIEW',
        'EVIDENCE_VIEW','CUSTODY_VIEW',
        'DOCUMENT_VIEW','DOCUMENT_DOWNLOAD','DOCUMENT_SIGN',
        'FORENSIC_REPORT_VIEW','CASE_EXPORT'
    );

    -- CASE_REVIEWER — view only
    INSERT INTO authorization.case_role_permission (case_role_id, permission_id)
    SELECT v_case_reviewer, permission_id FROM reference.permission
    WHERE permission_code IN (
        'CASE_VIEW','FIR_VIEW','EVIDENCE_VIEW','CUSTODY_VIEW',
        'DOCUMENT_VIEW','FORENSIC_REPORT_VIEW','AUDIT_VIEW'
    );

    -- AUDITOR — audit only
    INSERT INTO authorization.case_role_permission (case_role_id, permission_id)
    SELECT v_auditor, permission_id FROM reference.permission
    WHERE permission_code IN (
        'CASE_VIEW','FIR_VIEW','EVIDENCE_VIEW','CUSTODY_VIEW',
        'DOCUMENT_VIEW','FORENSIC_REPORT_VIEW','AUDIT_VIEW'
    );

    -- READ_ONLY
    INSERT INTO authorization.case_role_permission (case_role_id, permission_id)
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
    SELECT role_id INTO v_admin    FROM authorization.system_role WHERE role_code = 'SYS_ADMIN';
    SELECT role_id INTO v_sho      FROM authorization.system_role WHERE role_code = 'SHO_ROLE';
    SELECT role_id INTO v_io       FROM authorization.system_role WHERE role_code = 'IO_ROLE';
    SELECT role_id INTO v_malkhana FROM authorization.system_role WHERE role_code = 'MALKHANA_ROLE';
    SELECT role_id INTO v_cyber    FROM authorization.system_role WHERE role_code = 'CYBER_OFFICER';
    SELECT role_id INTO v_forensic FROM authorization.system_role WHERE role_code = 'FORENSIC_COORD';
    SELECT role_id INTO v_court    FROM authorization.system_role WHERE role_code = 'COURT_LIAISON';
    SELECT role_id INTO v_auditor  FROM authorization.system_role WHERE role_code = 'AUDITOR_ROLE';
    SELECT role_id INTO v_readonly FROM authorization.system_role WHERE role_code = 'READ_ONLY_ROLE';
    SELECT role_id INTO v_duty     FROM authorization.system_role WHERE role_code = 'DUTY_OFFICER';

    -- SYS_ADMIN — all permissions
    INSERT INTO authorization.role_permission (role_id, permission_id)
    SELECT v_admin, permission_id FROM reference.permission;

    -- SHO
    INSERT INTO authorization.role_permission (role_id, permission_id)
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
    INSERT INTO authorization.role_permission (role_id, permission_id)
    SELECT v_io, permission_id FROM reference.permission
    WHERE permission_code IN (
        'CASE_VIEW','CASE_EDIT','FIR_CREATE','FIR_VIEW','FIR_EDIT',
        'EVIDENCE_CREATE','EVIDENCE_VIEW','EVIDENCE_EDIT','EVIDENCE_TRANSFER','EVIDENCE_VERIFY',
        'DOCUMENT_UPLOAD','DOCUMENT_VIEW','DOCUMENT_DOWNLOAD','DOCUMENT_SIGN','DOCUMENT_VERSION_CREATE',
        'FORENSIC_REQUEST_CREATE','FORENSIC_REPORT_VIEW','CUSTODY_VIEW','CUSTODY_TRANSFER'
    );

    -- MALKHANA_ROLE
    INSERT INTO authorization.role_permission (role_id, permission_id)
    SELECT v_malkhana, permission_id FROM reference.permission
    WHERE permission_code IN (
        'EVIDENCE_VIEW','EVIDENCE_EDIT','EVIDENCE_TRANSFER','EVIDENCE_VERIFY',
        'CUSTODY_VIEW','CUSTODY_TRANSFER','DOCUMENT_VIEW'
    );

    -- CYBER_OFFICER
    INSERT INTO authorization.role_permission (role_id, permission_id)
    SELECT v_cyber, permission_id FROM reference.permission
    WHERE permission_code IN (
        'CASE_VIEW','CASE_EDIT',
        'EVIDENCE_CREATE','EVIDENCE_VIEW','EVIDENCE_EDIT','EVIDENCE_VERIFY',
        'FORENSIC_REQUEST_CREATE','FORENSIC_REPORT_VIEW',
        'DOCUMENT_UPLOAD','DOCUMENT_VIEW','DOCUMENT_DOWNLOAD','DOCUMENT_VERSION_CREATE',
        'CUSTODY_VIEW','CUSTODY_TRANSFER'
    );

    -- FORENSIC_COORD
    INSERT INTO authorization.role_permission (role_id, permission_id)
    SELECT v_forensic, permission_id FROM reference.permission
    WHERE permission_code IN (
        'EVIDENCE_VIEW','FORENSIC_REQUEST_CREATE','FORENSIC_REPORT_VIEW',
        'DOCUMENT_VIEW','DOCUMENT_DOWNLOAD','CUSTODY_VIEW'
    );

    -- COURT_LIAISON
    INSERT INTO authorization.role_permission (role_id, permission_id)
    SELECT v_court, permission_id FROM reference.permission
    WHERE permission_code IN (
        'CASE_VIEW','FIR_VIEW','EVIDENCE_VIEW','CUSTODY_VIEW',
        'DOCUMENT_VIEW','DOCUMENT_DOWNLOAD','DOCUMENT_SIGN','FORENSIC_REPORT_VIEW','CASE_EXPORT'
    );

    -- AUDITOR
    INSERT INTO authorization.role_permission (role_id, permission_id)
    SELECT v_auditor, permission_id FROM reference.permission
    WHERE permission_code IN (
        'CASE_VIEW','FIR_VIEW','EVIDENCE_VIEW','DOCUMENT_VIEW',
        'FORENSIC_REPORT_VIEW','CUSTODY_VIEW','AUDIT_VIEW'
    );

    -- READ_ONLY
    INSERT INTO authorization.role_permission (role_id, permission_id)
    SELECT v_readonly, permission_id FROM reference.permission
    WHERE permission_code IN ('CASE_VIEW','FIR_VIEW','EVIDENCE_VIEW','DOCUMENT_VIEW');

    -- DUTY_OFFICER
    INSERT INTO authorization.role_permission (role_id, permission_id)
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

-- Add deferred FK from authorization.officer_case_assignment back to case
ALTER TABLE authorization.officer_case_assignment
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
    added_at        TIMESTAMPTZ  NOT NULL DEFAULT now(),
    UNIQUE (document_id, COALESCE(request_id, '00000000-0000-0000-0000-000000000000'::uuid),
            COALESCE(report_id,  '00000000-0000-0000-0000-000000000000'::uuid))
);
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

    UNIQUE (summary_date, COALESCE(station_id, '00000000-0000-0000-0000-000000000000'::uuid),
            COALESCE(case_id, '00000000-0000-0000-0000-000000000000'::uuid))
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

    UNIQUE (court_id, court_case_number, COALESCE(court_case_year, 0))
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
