import { api } from './api';
import { EvidenceItem, EvidenceItemReal, CustodyEventReal, CustodyVerifyResult } from '../types';
import { casesService } from './cases';

// ---------------------------------------------------------------------------
// Legacy normalizer kept for backward-compat with any existing components
// that still use the old EvidenceItem type (with custodian string fields).
// ---------------------------------------------------------------------------
export function normalizeEvidence(e: any, fallback?: Partial<EvidenceItem>): EvidenceItem {
  const events = Array.isArray(e?.custody_events) ? e.custody_events : [];
  return {
    id: String(e?.id || fallback?.id || ''),
    case_id: String(e?.case_id || e?.caseId || fallback?.case_id || ''),
    case_number: String(e?.case_number || e?.caseNumber || fallback?.case_number || 'CASE-2026'),
    item_number: String(e?.item_number || e?.itemNumber || fallback?.item_number || `EVI-${e?.id || 'ITEM'}`),
    name: String(e?.name || fallback?.name || 'Unnamed Evidence Exhibit'),
    category: String(e?.category || fallback?.category || 'PHYSICAL'),
    description: String(e?.description || fallback?.description || ''),
    custodian: String(e?.custodian_email || e?.custodian || fallback?.custodian || 'Evidence Custody Vault'),
    custodian_badge: String(e?.custodian_badge || fallback?.custodian_badge || 'POL-VAULT'),
    location: String(e?.location || fallback?.location || 'Central Evidence Locker'),
    sealed_at: String(e?.sealed_at || fallback?.sealed_at || new Date().toISOString()),
    chain_hash: String(e?.event_hash || e?.chain_hash || fallback?.chain_hash || '0'.repeat(64)),
    status: (e?.status as EvidenceItem['status']) || fallback?.status || 'SECURE_VAULT',
    custody_events: events,
  };
}

// ---------------------------------------------------------------------------
// Real API — gets evidence items from the backend (per-case or fan-out)
// ---------------------------------------------------------------------------

export async function getEvidence(caseId?: string): Promise<EvidenceItem[]> {
  if (caseId) {
    return getEvidenceForCase(caseId);
  }
  // Fan out across visible cases.
  const cases = await casesService.getCases();
  const perCase = await Promise.all(
    cases.map((c) =>
      getEvidenceForCase(c.id).catch(() => [] as EvidenceItem[])
    )
  );
  return perCase.flat();
}

async function getEvidenceForCase(caseId: string): Promise<EvidenceItem[]> {
  const res = await api.get<EvidenceItemReal[]>(`/cases/${caseId}/evidence`);
  const rawList = Array.isArray(res.data) ? res.data : [];
  return rawList.map((e) => normalizeEvidence(e));
}

export async function getEvidenceById(id: string): Promise<EvidenceItemReal | null> {
  const res = await api.get<EvidenceItemReal>(`/evidence/${id}`);
  return res.data || null;
}

export async function createEvidence(data: {
  case_id: string;
  item_number: string;
  name: string;
  category?: string;
  description?: string;
  location?: string;
}): Promise<EvidenceItemReal> {
  const res = await api.post<EvidenceItemReal>(`/cases/${data.case_id}/evidence`, {
    item_number: data.item_number,
    name: data.name,
    category: data.category,
    description: data.description,
    location: data.location,
  });
  return res.data;
}

export async function transferCustody(
  evidenceId: string,
  data: {
    new_custodian_id: string;
    action?: string;
    location?: string;
    notes?: string;
  }
): Promise<CustodyEventReal> {
  const res = await api.post<CustodyEventReal>(`/evidence/${evidenceId}/transfer`, data);
  return res.data;
}

export async function getCustodyChain(evidenceId: string): Promise<CustodyEventReal[]> {
  const res = await api.get<CustodyEventReal[]>(`/evidence/${evidenceId}/custody`);
  return Array.isArray(res.data) ? res.data : [];
}

export async function verifyCustodyChain(evidenceId: string): Promise<CustodyVerifyResult> {
  const res = await api.get<CustodyVerifyResult>(`/evidence/${evidenceId}/verify-custody`);
  return res.data;
}

export async function deleteEvidence(evidenceId: string): Promise<void> {
  await api.delete(`/evidence/${evidenceId}`);
}

export const evidenceService = {
  getEvidence,
  getEvidenceById,
  createEvidence,
  transferCustody,
  getCustodyChain,
  verifyCustodyChain,
  deleteEvidence,
  normalizeEvidence,
};
