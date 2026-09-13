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
