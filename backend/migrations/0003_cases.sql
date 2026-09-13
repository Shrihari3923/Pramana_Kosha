-- Cases are the top-level container documents attach to. `case_number` is the
-- human-facing identifier (e.g. FIR number) — unique, but distinct from the UUID PK.
CREATE TABLE cases (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title       TEXT NOT NULL,
    case_number TEXT NOT NULL UNIQUE,
    created_by  UUID NOT NULL REFERENCES users(id),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- This table is the entire access-control model (per DESIGN.md). Every documents
-- query joins through it. Unique on (case_id, user_id) — no duplicate assignments.
CREATE TABLE case_assignments (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    case_id    UUID NOT NULL REFERENCES cases(id) ON DELETE CASCADE,
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (case_id, user_id)
);

CREATE INDEX idx_case_assignments_user_id ON case_assignments(user_id);
CREATE INDEX idx_case_assignments_case_id ON case_assignments(case_id);
