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
