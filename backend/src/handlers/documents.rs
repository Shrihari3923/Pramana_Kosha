use axum::{
    extract::{Multipart, Path, Query, State},
    http::header,
    response::{IntoResponse, Response},
    routing::{get, post},
    Json, Router,
};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::env;
use uuid::Uuid;

use crate::{
    blockchain::{self, NewTransaction},
    error::AppError,
    extractors::AuthenticatedUser,
    handlers::audit,
    models::Role,
    AppState,
};

// ---------------------------------------------------------------------------
// File security constants
// ---------------------------------------------------------------------------

/// Maximum upload size: 50 MB.
const MAX_FILE_SIZE_BYTES: usize = 50 * 1024 * 1024;

/// Allowed file extensions (server-side enforced).
const ALLOWED_EXTENSIONS: &[&str] = &[
    "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx",
    "txt", "csv", "jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif",
    "mp4", "avi", "mov", "mp3", "wav",
    "zip", "tar", "gz",
];

/// Blocked content type prefixes — never accept executable uploads.
const BLOCKED_MIME_PREFIXES: &[&str] = &[
    "application/x-msdownload",
    "application/x-executable",
    "application/x-sharedlib",
    "application/x-elf",
    "text/x-shellscript",
    "application/x-sh",
    "application/x-bat",
    "application/x-msdos-program",
];

const DOCUMENTS_DIR: &str = "data/documents";

// ---------------------------------------------------------------------------
// Public helper — needed by signatures.rs
// ---------------------------------------------------------------------------

/// Shared case-access check. Public so signatures.rs can call it.
pub async fn assert_case_access_pub(
    state: &AppState,
    user: &AuthenticatedUser,
    case_id: impl Into<Option<uuid::Uuid>>,
) -> Result<(), AppError> {
    let case_id = case_id.into().ok_or(AppError::NotFound)?;
    assert_case_access(state, user, case_id).await
}

async fn assert_case_access(
    state: &AppState,
    user: &AuthenticatedUser,
    case_id: Uuid,
) -> Result<(), AppError> {
    if matches!(user.role, Role::Supervisor | Role::Admin) {
        return Ok(());
    }
    let assigned = sqlx::query_scalar!(
        "SELECT 1 FROM case_assignments WHERE case_id = $1 AND user_id = $2",
        case_id,
        user.user_id
    )
    .fetch_optional(&state.db)
    .await?;
    if assigned.is_some() {
        Ok(())
    } else {
        Err(AppError::Forbidden)
    }
}

// ---------------------------------------------------------------------------
// File security validation
// ---------------------------------------------------------------------------

/// Sanitize a user-supplied filename.
/// - Strip any path components
/// - Replace dangerous chars with underscores
/// - Return only the extension for MIME/type checking
fn sanitize_filename(raw: &str) -> (String, Option<String>) {
    // Strip path separators — path traversal prevention.
    let base = raw
        .rsplit(|c| c == '/' || c == '\\')
        .next()
        .unwrap_or(raw)
        .trim();

    // Replace anything not alphanumeric/dot/dash/underscore/space.
    let safe: String = base
        .chars()
        .map(|c| {
            if c.is_alphanumeric() || matches!(c, '.' | '-' | '_' | ' ') {
                c
            } else {
                '_'
            }
        })
        .collect();

    // Extract extension.
    let ext = safe
        .rsplit('.')
        .next()
        .map(|e| e.to_lowercase())
        .filter(|e| !e.is_empty() && e.len() <= 10);

    (safe, ext)
}

/// Validate that the file extension is in the allowlist.
fn validate_extension(ext: Option<&str>) -> Result<(), AppError> {
    match ext {
        Some(e) if ALLOWED_EXTENSIONS.contains(&e) => Ok(()),
        Some(e) => Err(AppError::BadRequest(format!(
            "file extension '{}' is not permitted; allowed: {}",
            e,
            ALLOWED_EXTENSIONS.join(", ")
        ))),
        None => Err(AppError::BadRequest(
            "file must have a recognised extension".into(),
        )),
    }
}

/// Sniff the first bytes of the file for known dangerous magic numbers.
fn validate_magic_bytes(bytes: &[u8]) -> Result<(), AppError> {
    // ELF binary
    if bytes.starts_with(b"\x7fELF") {
        return Err(AppError::BadRequest("executable binaries are not permitted".into()));
    }
    // DOS/PE executable (MZ)
    if bytes.starts_with(b"MZ") {
        return Err(AppError::BadRequest("Windows executables are not permitted".into()));
    }
    // Shell script (#!)
    if bytes.starts_with(b"#!") {
        return Err(AppError::BadRequest("shell scripts are not permitted".into()));
    }
    Ok(())
}

/// Validate client-provided content type. Note: we do NOT trust this alone —
/// magic-byte check is the real gate. But clearly malicious MIME types are rejected early.
fn validate_content_type(content_type: Option<&str>) -> Result<(), AppError> {
    if let Some(ct) = content_type {
        let ct_lower = ct.to_lowercase();
        for blocked in BLOCKED_MIME_PREFIXES {
            if ct_lower.starts_with(blocked) {
                return Err(AppError::BadRequest(format!(
                    "content type '{}' is not permitted",
                    ct
                )));
            }
        }
    }
    Ok(())
}

// ---------------------------------------------------------------------------
// Router
// ---------------------------------------------------------------------------

pub fn router() -> Router<AppState> {
    Router::new()
        .route(
            "/cases/:case_id/documents",
            post(upload_document).get(list_documents),
        )
        .route("/documents/:id", get(get_document))
        .route("/documents/:id/download", get(download_document))
}

// ---------------------------------------------------------------------------
// Response type
// ---------------------------------------------------------------------------

#[derive(Serialize)]
struct DocumentResponse {
    id: Uuid,
    case_id: Uuid,
    uploaded_by: Uuid,
    title: String,
    doc_type: String,
    description: String,
    file_hash: String,
    version: i32,
    extracted_text: String,
    ocr_status: String,
    ocr_error: Option<String>,
    ocr_completed_at: Option<chrono::DateTime<chrono::Utc>>,
    blockchain_tx_id: Option<Uuid>,
    blockchain_tx_hash: Option<String>,
}

// ---------------------------------------------------------------------------
// OCR helper (unchanged from original)
// ---------------------------------------------------------------------------

#[derive(Deserialize)]
struct OcrResponse {
    text: String,
}

async fn run_ocr(file_path: &str) -> Result<String, String> {
    let service_url = env::var("OCR_SERVICE_URL")
        .unwrap_or_else(|_| "http://127.0.0.1:8000/ocr".to_string());

    let file_bytes = tokio::fs::read(file_path)
        .await
        .map_err(|e| e.to_string())?;

    let form = reqwest::multipart::Form::new().part(
        "file",
        reqwest::multipart::Part::bytes(file_bytes)
            .file_name("document.jpg")
            .mime_str("image/jpeg")
            .map_err(|e| e.to_string())?,
    );

    let response = reqwest::Client::new()
        .post(service_url)
        .multipart(form)
        .send()
        .await
        .map_err(|e| e.to_string())?;

    if !response.status().is_success() {
        return Err(format!("OCR service returned {}", response.status()));
    }

    response
        .json::<OcrResponse>()
        .await
        .map(|r| r.text)
        .map_err(|e| e.to_string())
}

// ---------------------------------------------------------------------------
// Upload
// ---------------------------------------------------------------------------

async fn upload_document(
    State(state): State<AppState>,
    user: AuthenticatedUser,
    Path(case_id): Path<Uuid>,
    mut multipart: Multipart,
) -> Result<Json<DocumentResponse>, AppError> {
    assert_case_access(&state, &user, case_id).await?;

    let mut title: Option<String> = None;
    let mut doc_type: Option<String> = None;
    let mut description = String::new();
    let mut file_bytes: Option<Vec<u8>> = None;
    let mut original_filename: Option<String> = None;
    let mut content_type: Option<String> = None;

    while let Some(field) = multipart
        .next_field()
        .await
        .map_err(|_| AppError::BadRequest("invalid multipart body".into()))?
    {
        let name = field.name().unwrap_or("").to_string();
        match name.as_str() {
            "title" => {
                title = Some(
                    field
                        .text()
                        .await
                        .map_err(|_| AppError::BadRequest("invalid title".into()))?,
                )
            }
            "doc_type" => {
                doc_type = Some(
                    field
                        .text()
                        .await
                        .map_err(|_| AppError::BadRequest("invalid doc_type".into()))?,
                )
            }
            "description" => {
                description = field
                    .text()
                    .await
                    .map_err(|_| AppError::BadRequest("invalid description".into()))?;
            }
            "file" => {
                // Capture client-provided filename and content-type BEFORE reading bytes.
                original_filename = field.file_name().map(|s| s.to_string());
                content_type = field.content_type().map(|s| s.to_string());

                let bytes = field
                    .bytes()
                    .await
                    .map_err(|_| AppError::BadRequest("failed to read file data".into()))?;

                // Enforce size limit.
                if bytes.len() > MAX_FILE_SIZE_BYTES {
                    return Err(AppError::BadRequest(format!(
                        "file exceeds maximum allowed size of {} MB",
                        MAX_FILE_SIZE_BYTES / 1024 / 1024
                    )));
                }

                file_bytes = Some(bytes.to_vec());
            }
            _ => {} // ignore unknown fields
        }
    }

    let title = title.ok_or_else(|| AppError::BadRequest("title is required".into()))?;
    let doc_type = doc_type.ok_or_else(|| AppError::BadRequest("doc_type is required".into()))?;
    let file_bytes = file_bytes.ok_or_else(|| AppError::BadRequest("file is required".into()))?;

    if title.trim().is_empty() || doc_type.trim().is_empty() {
        return Err(AppError::BadRequest(
            "title and doc_type cannot be empty".into(),
        ));
    }

    // Title/doc_type length limits.
    if title.len() > 500 {
        return Err(AppError::BadRequest("title exceeds 500 characters".into()));
    }
    if doc_type.len() > 100 {
        return Err(AppError::BadRequest("doc_type exceeds 100 characters".into()));
    }

    // File security: validate extension, content type, magic bytes.
    let (_, ext) = sanitize_filename(original_filename.as_deref().unwrap_or(""));
    validate_extension(ext.as_deref())?;
    validate_content_type(content_type.as_deref())?;
    validate_magic_bytes(&file_bytes)?;

    // Compute SHA-256 server-side (client-provided hash is never trusted).
    let mut hasher = Sha256::new();
    hasher.update(&file_bytes);
    let file_hash = hex::encode(hasher.finalize());

    // Generate a server-controlled storage name — never use the client filename on disk.
    let doc_id = Uuid::new_v4();
    tokio::fs::create_dir_all(DOCUMENTS_DIR)
        .await
        .map_err(|_| AppError::BadRequest("failed to prepare storage directory".into()))?;

    // Storage path: data/documents/{uuid} — no extension, no client-controlled characters.
let file_path = format!("{DOCUMENTS_DIR}/{doc_id}");

// Absolute path check — paranoia against path traversal/symlink attacks.
// The file does not exist yet, so canonicalize the existing storage directory
// and construct the expected file path beneath it.
let canonical_dir = std::path::Path::new(DOCUMENTS_DIR)
    .canonicalize()
    .map_err(|_| AppError::BadRequest("failed to resolve storage directory".into()))?;

let canonical = canonical_dir.join(doc_id.to_string());

if !canonical.starts_with(&canonical_dir) {
    return Err(AppError::BadRequest("invalid storage path".into()));
}

    tokio::fs::write(&file_path, &file_bytes)
        .await
        .map_err(|_| AppError::BadRequest("failed to write file to disk".into()))?;

    let (extracted_text, ocr_status, ocr_error, ocr_completed_at) =
        match run_ocr(&file_path).await {
            Ok(text) => (text, "completed", None, Some(chrono::Utc::now())),
            Err(error) => (String::new(), "failed", Some(error), None),
        };

    let mut tx = state.db.begin().await?;

    sqlx::query!(
        r#"
        INSERT INTO documents
            (id, case_id, uploaded_by, title, doc_type, description, file_path, file_hash,
             extracted_text, ocr_status, ocr_error, ocr_completed_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
        "#,
        doc_id,
        case_id,
        user.user_id,
        title,
        doc_type,
        description,
        file_path,
        file_hash,
        extracted_text,
        ocr_status,
        ocr_error,
        ocr_completed_at
    )
    .execute(&mut *tx)
    .await?;

    // Audit log (existing chain).
    audit::append_entry(&mut tx, user.user_id, "UPLOAD", Some(doc_id), Some(case_id)).await?;

    // Blockchain transaction — record document upload with its hash.
    let (bc_tx_id, bc_tx_hash) = blockchain::record_transaction_in_tx(
        &mut tx,
        NewTransaction {
            actor_id: user.user_id,
            case_id: Some(case_id),
            document_id: Some(doc_id),
            action: "DOCUMENT_UPLOAD".to_string(),
            extra: format!("hash={},doc_type={}", file_hash, doc_type),
        },
    )
    .await?;

    tx.commit().await?;

    Ok(Json(DocumentResponse {
        id: doc_id,
        case_id,
        uploaded_by: user.user_id,
        title,
        doc_type,
        description,
        file_hash,
        version: 1,
        extracted_text,
        ocr_status: ocr_status.to_string(),
        ocr_error,
        ocr_completed_at,
        blockchain_tx_id: Some(bc_tx_id),
        blockchain_tx_hash: Some(bc_tx_hash),
    }))
}

// ---------------------------------------------------------------------------
// List / Get / Download (unchanged logic, added blockchain_tx fields)
// ---------------------------------------------------------------------------

#[derive(Deserialize)]
struct ListDocumentsQuery {
    q: Option<String>,
}

async fn list_documents(
    State(state): State<AppState>,
    user: AuthenticatedUser,
    Path(case_id): Path<Uuid>,
    Query(params): Query<ListDocumentsQuery>,
) -> Result<Json<Vec<DocumentResponse>>, AppError> {
    assert_case_access(&state, &user, case_id).await?;

    let rows = if let Some(q) = params.q.filter(|q| !q.trim().is_empty()) {
        sqlx::query!(
            r#"SELECT id as "id!: uuid::Uuid",
                      case_id as "case_id!: uuid::Uuid",
                      uploaded_by as "uploaded_by!: uuid::Uuid",
                      title as "title!: String",
                      doc_type as "doc_type!: String",
                      description as "description!: String",
                      file_hash as "file_hash!: String",
                      version as "version!: i32",
                      extracted_text as "extracted_text!: String",
                      ocr_status as "ocr_status!: String",
                      ocr_error,
                      ocr_completed_at
            FROM documents
            WHERE case_id = $1 AND search_vector @@ plainto_tsquery('english', $2)
            ORDER BY ts_rank(search_vector, plainto_tsquery('english', $2)) DESC
            "#,
            case_id,
            q
        )
        .fetch_all(&state.db)
        .await?
        .into_iter()
        .map(|r| DocumentResponse {
            id: r.id,
            case_id: r.case_id,
            uploaded_by: r.uploaded_by,
            title: r.title,
            doc_type: r.doc_type,
            description: r.description,
            file_hash: r.file_hash,
            version: r.version,
            extracted_text: r.extracted_text,
            ocr_status: r.ocr_status,
            ocr_error: r.ocr_error,
            ocr_completed_at: r.ocr_completed_at,
            blockchain_tx_id: None,
            blockchain_tx_hash: None,
        })
        .collect()
    } else {
        sqlx::query!(
            r#"SELECT id as "id!: uuid::Uuid",
                      case_id as "case_id!: uuid::Uuid",
                      uploaded_by as "uploaded_by!: uuid::Uuid",
                      title as "title!: String",
                      doc_type as "doc_type!: String",
                      description as "description!: String",
                      file_hash as "file_hash!: String",
                      version as "version!: i32",
                      extracted_text as "extracted_text!: String",
                      ocr_status as "ocr_status!: String",
                      ocr_error,
                      ocr_completed_at
            FROM documents
            WHERE case_id = $1
            ORDER BY created_at DESC
            "#,
            case_id
        )
        .fetch_all(&state.db)
        .await?
        .into_iter()
        .map(|r| DocumentResponse {
            id: r.id,
            case_id: r.case_id,
            uploaded_by: r.uploaded_by,
            title: r.title,
            doc_type: r.doc_type,
            description: r.description,
            file_hash: r.file_hash,
            version: r.version,
            extracted_text: r.extracted_text,
            ocr_status: r.ocr_status,
            ocr_error: r.ocr_error,
            ocr_completed_at: r.ocr_completed_at,
            blockchain_tx_id: None,
            blockchain_tx_hash: None,
        })
        .collect()
    };

    Ok(Json(rows))
}

struct DocumentRow {
    id: Uuid,
    case_id: Uuid,
    uploaded_by: Uuid,
    title: String,
    doc_type: String,
    description: String,
    file_path: String,
    file_hash: String,
    version: i32,
    extracted_text: String,
    ocr_status: String,
    ocr_error: Option<String>,
    ocr_completed_at: Option<chrono::DateTime<chrono::Utc>>,
}

async fn fetch_document_row(state: &AppState, id: Uuid) -> Result<DocumentRow, AppError> {
    sqlx::query_as!(
        DocumentRow,
        r#"SELECT id as "id!: uuid::Uuid",
                  case_id as "case_id!: uuid::Uuid",
                  uploaded_by as "uploaded_by!: uuid::Uuid",
                  title as "title!: String",
                  doc_type as "doc_type!: String",
                  description as "description!: String",
                  file_path as "file_path!: String",
                  file_hash as "file_hash!: String",
                  version as "version!: i32",
                  extracted_text as "extracted_text!: String",
                  ocr_status as "ocr_status!: String",
                  ocr_error,
                  ocr_completed_at
           FROM documents WHERE id = $1"#,
        id
    )
    .fetch_optional(&state.db)
    .await?
    .ok_or(AppError::NotFound)
}

async fn get_document(
    State(state): State<AppState>,
    user: AuthenticatedUser,
    Path(id): Path<Uuid>,
) -> Result<Json<DocumentResponse>, AppError> {
    let row = fetch_document_row(&state, id).await?;
    assert_case_access(&state, &user, row.case_id).await?;

    // Look up the most recent blockchain tx for this document.
    let bc = sqlx::query!(
        "SELECT id, tx_hash FROM blockchain_transactions WHERE document_id = $1 ORDER BY created_at DESC LIMIT 1",
        id
    )
    .fetch_optional(&state.db)
    .await?;

    Ok(Json(DocumentResponse {
        id: row.id,
        case_id: row.case_id,
        uploaded_by: row.uploaded_by,
        title: row.title,
        doc_type: row.doc_type,
        description: row.description,
        file_hash: row.file_hash,
        version: row.version,
        extracted_text: row.extracted_text,
        ocr_status: row.ocr_status,
        ocr_error: row.ocr_error,
        ocr_completed_at: row.ocr_completed_at,
        blockchain_tx_id: bc.as_ref().map(|b| b.id),
        blockchain_tx_hash: bc.map(|b| b.tx_hash),
    }))
}

async fn download_document(
    State(state): State<AppState>,
    user: AuthenticatedUser,
    Path(id): Path<Uuid>,
) -> Result<Response, AppError> {
    let row = fetch_document_row(&state, id).await?;
    assert_case_access(&state, &user, row.case_id).await?;

    let bytes = tokio::fs::read(&row.file_path)
        .await
        .map_err(|_| AppError::NotFound)?;

    // Record document download on blockchain.
    let _ = blockchain::record_transaction(
        &state.db,
        NewTransaction {
            actor_id: user.user_id,
            case_id: Some(row.case_id),
            document_id: Some(row.id),
            action: "DOCUMENT_DOWNLOAD".to_string(),
            extra: format!("hash={}", row.file_hash),
        },
    )
    .await;

    // Sanitize title for Content-Disposition header.
    let safe_title: String = row
        .title
        .chars()
        .map(|c| if c.is_alphanumeric() || matches!(c, '-' | '_' | ' ') { c } else { '_' })
        .collect();
    let filename = format!("{}-{}.bin", row.id, safe_title.replace(' ', "_"));

    Ok((
        [
            (
                header::CONTENT_TYPE,
                "application/octet-stream".to_string(),
            ),
            (
                header::CONTENT_DISPOSITION,
                format!("attachment; filename=\"{}\"", filename),
            ),
            // Prevent MIME sniffing.
            (
                header::HeaderName::from_static("x-content-type-options"),
                "nosniff".to_string(),
            ),
        ],
        bytes,
    )
        .into_response())
}

// ---------------------------------------------------------------------------
// Unit tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_sanitize_filename_strips_path() {
        let (safe, ext) = sanitize_filename("../../etc/passwd");
        assert!(!safe.contains(".."));
        assert!(!safe.contains('/'));
        assert_eq!(ext.as_deref(), Some("passwd"));
    }

    #[test]
    fn test_sanitize_filename_extracts_extension() {
        let (_, ext) = sanitize_filename("report.pdf");
        assert_eq!(ext.as_deref(), Some("pdf"));
    }

    #[test]
    fn test_validate_extension_allowed() {
        assert!(validate_extension(Some("pdf")).is_ok());
        assert!(validate_extension(Some("docx")).is_ok());
        assert!(validate_extension(Some("jpg")).is_ok());
    }

    #[test]
    fn test_validate_extension_blocked() {
        assert!(validate_extension(Some("exe")).is_err());
        assert!(validate_extension(Some("sh")).is_err());
        assert!(validate_extension(Some("py")).is_err());
        assert!(validate_extension(Some("js")).is_err());
        assert!(validate_extension(None).is_err());
    }

    #[test]
    fn test_validate_magic_bytes_elf() {
        let bytes = b"\x7fELFsome binary data";
        assert!(validate_magic_bytes(bytes).is_err());
    }

    #[test]
    fn test_validate_magic_bytes_mz() {
        let bytes = b"MZsome pe header data";
        assert!(validate_magic_bytes(bytes).is_err());
    }

    #[test]
    fn test_validate_magic_bytes_shell() {
        let bytes = b"#!/bin/bash\nrm -rf /";
        assert!(validate_magic_bytes(bytes).is_err());
    }

    #[test]
    fn test_validate_magic_bytes_pdf_ok() {
        let bytes = b"%PDF-1.4 header data";
        assert!(validate_magic_bytes(bytes).is_ok());
    }

    #[test]
    fn test_validate_content_type_blocked() {
        assert!(validate_content_type(Some("application/x-msdownload")).is_err());
        assert!(validate_content_type(Some("application/x-executable")).is_err());
    }

    #[test]
    fn test_validate_content_type_ok() {
        assert!(validate_content_type(Some("application/pdf")).is_ok());
        assert!(validate_content_type(Some("image/jpeg")).is_ok());
        assert!(validate_content_type(None).is_ok());
    }
}
