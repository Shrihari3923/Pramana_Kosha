import { api } from './api';
import { Case, Priority, CaseStatus } from '../types';

export function normalizeCase(c: any, fallback?: Partial<Case>): Case {
  return {
    id: String(c?.id || fallback?.id || ''),
    case_number: c?.case_number || c?.caseNumber || fallback?.case_number || `CD-2026-${Math.floor(100 + Math.random() * 900)}`,
    title: c?.title || fallback?.title || 'Untitled Docket',
    description: c?.description || fallback?.description || 'Investigation docket registered on sovereign ledger',
    status: (c?.status as CaseStatus) || fallback?.status || 'ACTIVE',
    priority: (c?.priority as Priority) || fallback?.priority || 'HIGH',
    jurisdiction: c?.jurisdiction || fallback?.jurisdiction || 'Jurisdiction Alpha',
    lead_officer: c?.lead_officer || c?.leadOfficer || fallback?.lead_officer || '',
    lead_officer_id: c?.lead_officer_id || c?.created_by || fallback?.lead_officer_id,
    lead_officer_badge: c?.lead_officer_badge || fallback?.lead_officer_badge || 'POL-2026',
    supervisor: c?.supervisor || fallback?.supervisor || 'Supervising Officer',
    created_by: String(c?.created_by || fallback?.created_by || ''),
    created_at: c?.created_at || fallback?.created_at || new Date().toISOString(),
    updated_at: c?.updated_at || fallback?.updated_at || new Date().toISOString(),
    document_count: typeof c?.document_count === 'number' ? c.document_count : (c?.documents?.length || fallback?.document_count || 0),
    evidence_count: typeof c?.evidence_count === 'number' ? c.evidence_count : (c?.evidence?.length || fallback?.evidence_count || 0),
    merkle_status: c?.merkle_status || fallback?.merkle_status || 'VERIFIED',
    merkle_last_checked: c?.merkle_last_checked || fallback?.merkle_last_checked || 'Live Consensus',
  };
}

export async function getCases(): Promise<Case[]> {
  const res = await api.get<Case[] | { cases: Case[] } | { data: Case[] } | { items: Case[] } | { results: Case[] }>('/cases');
  let rawList: any[] = [];
  if (Array.isArray(res.data)) {
    rawList = res.data;
  } else if (res.data && typeof res.data === 'object') {
    const d = res.data as Record<string, unknown>;
    if (Array.isArray(d.cases)) {
      rawList = d.cases;
    } else if (Array.isArray(d.data)) {
      rawList = d.data;
    } else if (Array.isArray(d.items)) {
      rawList = d.items;
    } else if (Array.isArray(d.results)) {
      rawList = d.results;
    }
  }
  return rawList.map((c) => normalizeCase(c));
}

export async function getCaseById(id: string): Promise<Case | null> {
  const res = await api.get<Case | { case: Case } | { data: Case }>(`/cases/${id}`);
  if (res.data && typeof res.data === 'object') {
    const raw = 'case' in res.data ? (res.data as any).case : 'data' in res.data ? (res.data as any).data : res.data;
    return normalizeCase(raw);
  }
  return null;
}

export async function createCase(data: {
  title: string;
  case_number: string;
  description?: string;
  priority?: Priority;
  jurisdiction?: string;
  lead_officer?: string;
}): Promise<Case> {
  const payload = {
    title: data.title.trim(),
    case_number: data.case_number.trim(),
    description: data.description?.trim() || '',
    priority: data.priority || 'HIGH',
    jurisdiction: data.jurisdiction?.trim() || 'Jurisdiction Alpha',
    lead_officer: data.lead_officer?.trim() || '',
  };

  const res = await api.post<Case | { case: Case } | { data: Case }>('/cases', payload);
  if (res.data && typeof res.data === 'object') {
    const raw = 'case' in res.data ? (res.data as any).case : 'data' in res.data ? (res.data as any).data : res.data;
    // Pass payload as fallback so fields the backend doesn't echo back
    // (lead_officer, priority, jurisdiction, description) are preserved.
    return normalizeCase(raw, payload as Partial<Case>);
  }
  throw new Error('Failed to create case: Invalid response from backend');
}

export async function updateCaseStatus(caseId: string, status: CaseStatus): Promise<Case | null> {
  const res = await api.patch<Case | { case: Case }>(`/cases/${caseId}/status`, { status });
  if (res.data && typeof res.data === 'object') {
    const raw = 'case' in res.data ? (res.data as any).case : res.data;
    return normalizeCase(raw);
  }
  return null;
}

export interface CaseOfficer {
  id: string;
  email: string;
  role: string;
  name: string;
}

/** Returns the list of users assigned to a case via GET /cases/:id/access */
export async function getCaseAccess(caseId: string): Promise<CaseOfficer[]> {
  const res = await api.get<CaseOfficer[]>(`/cases/${caseId}/access`);
  const raw: any[] = Array.isArray(res.data) ? res.data : [];
  return raw.map((u) => ({
    id: String(u.id || ''),
    email: String(u.email || ''),
    role: String(u.role || 'Investigator'),
    // Derive a display name from email when no name field is returned
    name: u.name || u.email?.split('@')[0]?.replace(/[._]/g, ' ')
      .replace(/\b\w/g, (c: string) => c.toUpperCase()) || 'Officer',
  }));
}

export const casesService = {
  getCases,
  getCaseById,
  createCase,
  updateCaseStatus,
  getCaseAccess,
  normalizeCase,
};
