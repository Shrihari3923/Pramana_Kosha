-- file_path stores the on-disk location (/data/documents/{uuid}), never sent to the
-- client directly — GET /documents/:id/download streams through the API instead.
-- file_hash is sha256(bytes), hex-encoded, computed synchronously at upload time.
CREATE TABLE documents (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    case_id     UUID NOT NULL REFERENCES cases(id) ON DELETE CASCADE,
    uploaded_by UUID NOT NULL REFERENCES users(id),
    title       TEXT NOT NULL,
    doc_type    TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    file_path   TEXT NOT NULL,
    file_hash   TEXT NOT NULL,
    version     INT NOT NULL DEFAULT 1,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),

    -- Generated column, kept in sync by Postgres on every insert/update — no app-side
    -- trigger logic needed. Weighted so title matches rank above description matches.
    search_vector tsvector GENERATED ALWAYS AS (
        setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
        setweight(to_tsvector('english', coalesce(description, '')), 'B')
    ) STORED
);

CREATE INDEX idx_documents_case_id ON documents(case_id);
CREATE INDEX idx_documents_search_vector ON documents USING GIN (search_vector);
