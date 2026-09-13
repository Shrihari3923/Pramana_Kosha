ALTER TABLE documents
ADD COLUMN extracted_text TEXT NOT NULL DEFAULT '',
ADD COLUMN ocr_status TEXT NOT NULL DEFAULT 'not_requested',
ADD COLUMN ocr_error TEXT,
ADD COLUMN ocr_completed_at TIMESTAMPTZ;

ALTER TABLE documents
ADD CONSTRAINT documents_ocr_status_check CHECK (
    ocr_status IN (
        'not_requested',
        'processing',
        'completed',
        'failed'
    )
);