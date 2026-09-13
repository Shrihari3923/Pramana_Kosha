import { api } from './api';
import { Document } from '../types';
import { computeSHA256 } from '../utils/validation';
import { casesService } from './cases';

export function normalizeDocument(d: any, fallback?: Partial<Document>): Document {
  const isTampered = Boolean(d?.is_tampered ?? d?.isTampered ?? fallback?.is_tampered ?? false);

  // Backend (documents.rs DocumentResponse) returns `file_hash`, not `sha256`/`hash`.
  const sha256Val = String(d?.file_hash ?? d?.fileHash ?? fallback?.sha256 ?? '');
  const origSha256 = String(d?.original_file_hash ?? d?.originalFileHash ?? fallback?.original_sha256 ?? sha256Val);

  const created = String(d?.created_at || d?.createdAt || fallback?.created_at || new Date().toISOString());
  const uploadedBy = String(d?.uploaded_by || d?.uploadedBy || fallback?.uploaded_by || 'Investigating Officer');

  // Backend (documents.rs DocumentResponse) returns `doc_type`, not `document_type`.
  const documentType = String(d?.doc_type ?? d?.docType ?? fallback?.document_type ?? 'EVIDENTIARY_REPORT');

  let versionsList = Array.isArray(d?.versions) ? d.versions : fallback?.versions;
  if (!Array.isArray(versionsList) || versionsList.length === 0) {
    versionsList = [
      {
        version: Number(d?.version || 1),
        timestamp: created,
        sha256: sha256Val,
        uploaded_by: uploadedBy,
      },
    ];
  }

  let formattedSize = '1.2 MB';
  if (typeof d?.file_size === 'number') {
    formattedSize = `${(d.file_size / (1024 * 1024)).toFixed(2)} MB`;
  } else if (d?.file_size) {
    formattedSize = String(d.file_size);
  } else if (d?.fileSize) {
    formattedSize = String(d.fileSize);
  }

  return {
    id: String(d?.id || fallback?.id || ''),
    case_id: String(d?.case_id || d?.caseId || fallback?.case_id || ''),
    case_number: String(d?.case_number || d?.caseNumber || fallback?.case_number || 'CASE-2026'),
    title: String(d?.title || fallback?.title || 'Untitled Document'),
    document_type: documentType,
    description: String(d?.description || fallback?.description || ''),
    version: Number(d?.version || fallback?.version || 1),
    sha256: sha256Val,
    original_sha256: origSha256,
    is_tampered: isTampered,
    tamper_offset: d?.tamper_offset || d?.tamperOffset || fallback?.tamper_offset,
    integrity_status: d?.integrity_status || d?.integrityStatus || fallback?.integrity_status || (isTampered ? 'TAMPERED' : 'VERIFIED'),
    signature_status: d?.signature_status || d?.signatureStatus || fallback?.signature_status || 'VALID',
    signer_name: d?.signer_name || d?.signerName || fallback?.signer_name,
    signer_key: d?.signer_key || d?.signerKey || fallback?.signer_key,
    signed_at: d?.signed_at || d?.signedAt || fallback?.signed_at,
    uploaded_by: uploadedBy,
    file_size: formattedSize,
    file_type: String(d?.file_type || d?.fileType || d?.mime_type || fallback?.file_type || 'application/pdf'),
    classification: String(d?.classification || fallback?.classification || 'CONFIDENTIAL'),
    legal_docket_ref: d?.legal_docket_ref || d?.legalDocketRef || fallback?.legal_docket_ref,
    created_at: created,
    versions: versionsList,
    extracted_text: String(d?.extracted_text ?? d?.extractedText ?? fallback?.extracted_text ?? ''),
    ocr_status: String(d?.ocr_status ?? d?.ocrStatus ?? fallback?.ocr_status ?? 'not_requested'),
    ocr_error: d?.ocr_error ?? d?.ocrError ?? fallback?.ocr_error,
    ocr_completed_at: d?.ocr_completed_at ?? d?.ocrCompletedAt ?? fallback?.ocr_completed_at,
  };
}

async function getDocumentsForCase(caseId: string, caseNumber?: string): Promise<Document[]> {
  const res = await api.get<Document[] | { documents: Document[] } | { data: Document[] } | { items: Document[] } | { results: Document[] }>(
    `/cases/${caseId}/documents`
  );
  let rawList: any[] = [];
  if (Array.isArray(res.data)) {
    rawList = res.data;
  } else if (res.data && typeof res.data === 'object') {
    const d = res.data as Record<string, unknown>;
    if (Array.isArray(d.documents)) {
      rawList = d.documents;
    } else if (Array.isArray(d.data)) {
      rawList = d.data;
    } else if (Array.isArray(d.items)) {
      rawList = d.items;
    } else if (Array.isArray(d.results)) {
      rawList = d.results;
    }
  }
  return rawList.map((doc) => normalizeDocument(doc, { case_id: caseId, case_number: caseNumber }));
}

/**
 * The backend has no flat "all documents" route by design (DESIGN.md scopes
 * documents per-case through case_assignments access control). When no
 * caseId is given, we fan out across every case the current user can already
 * see via GET /cases and flatten the results, instead of calling a route
 * that doesn't exist.
 */
export async function getDocuments(caseId?: string): Promise<Document[]> {
  if (caseId) {
    return getDocumentsForCase(caseId);
  }

  const cases = await casesService.getCases();
  const perCase = await Promise.all(
    cases.map((c) =>
      getDocumentsForCase(c.id, c.case_number).catch((err) => {
        console.warn(`Failed to load documents for case ${c.id}:`, err);
        return [] as Document[];
      })
    )
  );
  return perCase.flat();
}

export async function getDocumentById(id: string): Promise<Document | null> {
  const res = await api.get<Document | { document: Document } | { data: Document }>(`/documents/${id}`);
  if (res.data && typeof res.data === 'object') {
    const raw = 'document' in res.data ? (res.data as any).document : 'data' in res.data ? (res.data as any).data : res.data;
    return normalizeDocument(raw);
  }
  return null;
}

export async function uploadDocument(
  caseId: string,
  file: File,
  data: {
    title: string;
    documentType: string;
    description: string;
    uploadedBy: string;
    classification?: string;
  }
): Promise<Document> {
  // Note: the backend (documents.rs upload_document) computes file_hash itself
  // server-side from the raw bytes and ignores any client-supplied hash field.
  // We still compute this locally for the "live checksum" UI preview in
  // DocumentUpload.tsx, but we no longer send it as `sha256`/expect the backend
  // to use it — that field name doesn't exist in the multipart contract either
  // (see documents.rs: fields are title, doc_type, description, file).
  let fileHash = '';
  try {
    const buffer = await file.arrayBuffer();
    fileHash = await computeSHA256(buffer);
  } catch {
    fileHash = '';
  }

  const formData = new FormData();
  formData.append('file', file);
  formData.append('title', data.title);
  formData.append('doc_type', data.documentType);
  formData.append('description', data.description);

  let res;
  try {
    res = await api.post<Document | { document: Document } | { data: Document }>(
      `/cases/${caseId}/documents`,
      formData
    );
  } catch (err: any) {
    if (err?.status === 404) {
      res = await api.post<Document | { document: Document } | { data: Document }>(
        '/documents',
        formData
      );
    } else {
      throw err;
    }
  }

  if (res.data && typeof res.data === 'object') {
    const raw = 'document' in res.data ? (res.data as any).document : 'data' in res.data ? (res.data as any).data : res.data;
    return normalizeDocument(raw, {
      case_id: caseId,
      title: data.title,
      document_type: data.documentType,
      description: data.description,
      uploaded_by: data.uploadedBy,
      sha256: fileHash,
      file_size: `${(file.size / (1024 * 1024)).toFixed(2)} MB`,
      file_type: file.type || 'application/pdf',
    });
  }

  throw new Error('Failed to upload document: Invalid backend response');
}

export async function finalizeDocument(
  docId: string,
  signerName: string,
  signerKey: string
): Promise<Document | null> {
  try {
    const res = await api.post<Document | { document: Document }>(`/documents/${docId}/finalize`, {
      signer_name: signerName,
      signer_key: signerKey,
    });
    if (res.data && typeof res.data === 'object') {
      const raw = 'document' in res.data ? (res.data as { document: Document }).document : (res.data as Document);
      return normalizeDocument(raw);
    }
  } catch (err) {
    console.warn('Backend finalize endpoint unavailable:', err);
  }
  return null;
}

export async function toggleDocumentTamper(docId: string): Promise<Document | null> {
  try {
    const res = await api.post<Document | { document: Document }>(`/documents/${docId}/tamper`);
    if (res.data && typeof res.data === 'object') {
      const raw = 'document' in res.data ? (res.data as { document: Document }).document : (res.data as Document);
      return normalizeDocument(raw);
    }
  } catch (err) {
    console.warn('Backend tamper simulation endpoint unavailable:', err);
  }
  return null;
}

export const documentsService = {
  getDocuments,
  getDocumentById,
  uploadDocument,
  finalizeDocument,
  toggleDocumentTamper,
  normalizeDocument,
};
