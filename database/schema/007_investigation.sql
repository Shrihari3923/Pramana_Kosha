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
