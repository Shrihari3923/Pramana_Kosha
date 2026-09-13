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
