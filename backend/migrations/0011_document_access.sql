-- Per-document access control.
-- A user must also be assigned to the case before this permission is useful.
-- Note: documents and users are views on Aiven, so FK constraints are omitted;
-- referential integrity is enforced at the application layer.
CREATE TABLE document_access (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id UUID NOT NULL,
    user_id     UUID NOT NULL,
    granted_by  UUID NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (document_id, user_id)
);

CREATE INDEX idx_document_access_document_id
    ON document_access(document_id);

CREATE INDEX idx_document_access_user_id
    ON document_access(user_id);
