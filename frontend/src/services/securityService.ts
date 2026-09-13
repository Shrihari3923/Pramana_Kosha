import { api } from './api';
import {
  SecurityStats,
  SecurityEvent,
  LoginAttempt,
  SigningKey,
  DocumentSignature,
  SignatureVerifyResult,
  IntegrityCheckResult,
} from '../types';

// ---------------------------------------------------------------------------
// Security dashboard stats
// ---------------------------------------------------------------------------

export async function getSecurityStats(): Promise<SecurityStats> {
  const res = await api.get<SecurityStats>('/security/stats');
  return res.data;
}

export async function getSecurityEvents(): Promise<SecurityEvent[]> {
  const res = await api.get<SecurityEvent[]>('/security/events');
  return Array.isArray(res.data) ? res.data : [];
}

export async function getLoginAttempts(): Promise<LoginAttempt[]> {
  const res = await api.get<LoginAttempt[]>('/security/login-attempts');
  return Array.isArray(res.data) ? res.data : [];
}

// ---------------------------------------------------------------------------
// Signing key management
// ---------------------------------------------------------------------------

export async function generateSigningKey(): Promise<SigningKey> {
  const res = await api.post<SigningKey>('/users/me/signing-key');
  return res.data;
}

export async function getMySigningKey(): Promise<SigningKey | null> {
  try {
    const res = await api.get<SigningKey>('/users/me/signing-key');
    return res.data;
  } catch {
    return null;
  }
}

export async function getUserSigningKey(userId: string): Promise<SigningKey | null> {
  try {
    const res = await api.get<SigningKey>(`/users/${userId}/signing-key`);
    return res.data;
  } catch {
    return null;
  }
}

// ---------------------------------------------------------------------------
// Document signatures
// ---------------------------------------------------------------------------

export async function signDocument(documentId: string): Promise<DocumentSignature> {
  const res = await api.post<DocumentSignature>(`/documents/${documentId}/sign`);
  return res.data;
}

export async function getDocumentSignatures(
  documentId: string
): Promise<DocumentSignature[]> {
  const res = await api.get<{ signatures: DocumentSignature[] }>(
    `/documents/${documentId}/signature`
  );
  const raw = res.data;
  if (raw && typeof raw === 'object' && 'signatures' in raw) {
    return Array.isArray(raw.signatures) ? raw.signatures : [];
  }
  return [];
}

export async function verifyDocumentSignature(
  documentId: string
): Promise<SignatureVerifyResult> {
  const res = await api.get<SignatureVerifyResult>(
    `/documents/${documentId}/verify-signature`
  );
  return res.data;
}

export async function verifyDocumentIntegrity(
  documentId: string
): Promise<IntegrityCheckResult> {
  const res = await api.get<IntegrityCheckResult>(
    `/documents/${documentId}/verify-integrity`
  );
  return res.data;
}

export const securityService = {
  getSecurityStats,
  getSecurityEvents,
  getLoginAttempts,
  generateSigningKey,
  getMySigningKey,
  getUserSigningKey,
  signDocument,
  getDocumentSignatures,
  verifyDocumentSignature,
  verifyDocumentIntegrity,
};
