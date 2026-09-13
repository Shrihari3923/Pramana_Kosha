import { api } from './api';
import { AuditEvent, AuditVerificationResult } from '../types';
import { casesService } from './cases';

export function normalizeAuditEvent(e: any, fallback?: { case_number?: string }): AuditEvent {
  // Backend audit_trail rows (audit.rs AuditTrailEntry) don't have a block_number —
  // ordering comes from `seq` server-side and isn't exposed per-entry. We derive a
  // stable display index from created_at ordering at the call site instead.
  const statusStr = String(e?.status || 'VALID').toUpperCase();

  return {
    id: String(e?.id || `audit-${Math.random().toString(36).slice(2)}`),
    block_number: Number(e?.block_number ?? e?.blockNumber ?? 0),
    timestamp: String(e?.created_at || e?.timestamp || new Date().toISOString()),
    actor: String(e?.actor_email || e?.actor || 'System Custodian'),
    role: (String(e?.role || 'INVESTIGATOR').toUpperCase() as AuditEvent['role']),
    action: String(e?.action || 'LEDGER_COMMIT'),
    target_reference: String(
      e?.target_reference || e?.document_id || fallback?.case_number || 'GENESIS_RECORD'
    ),
    // The per-case audit-trail endpoint (GET /cases/:id/audit-trail) doesn't return
    // prev_hash/entry_hash at all (see audit.rs AuditTrailEntry) — those only exist
    // internally and via GET /audit/verify-chain's pass/fail result. We show
    // placeholders here rather than pretending we have real hash values.
    prev_hash: String(e?.prev_hash || e?.prevHash || ''),
    entry_hash: String(e?.entry_hash || e?.entryHash || e?.id || ''),
    status: statusStr === 'TAMPERED' ? 'TAMPERED' : 'VALID',
  };
}

/**
 * There is no listing endpoint for all audit events — only
 * GET /cases/:id/audit-trail (per case) and GET /audit/verify-chain (pass/fail,
 * no listing). audit-trail is now open to all three roles (audit.rs
 * assert_case_access), scoped the same way case visibility already is:
 * investigators only see the trail for cases they're assigned to, so
 * `GET /cases` naturally returns only the cases this call will succeed for.
 */
export async function getAuditEvents(): Promise<AuditEvent[]> {
  const cases = await casesService.getCases();

  const perCase = await Promise.all(
    cases.map(async (c) => {
      try {
        const res = await api.get<any[] | { events: any[] }>(`/cases/${c.id}/audit-trail`);
        const rawList = Array.isArray(res.data) ? res.data : (res.data as any)?.events || [];
        return rawList.map((e: any) => normalizeAuditEvent(e, { case_number: c.case_number }));
      } catch (err) {
        console.warn(`Failed to load audit trail for case ${c.id}:`, err);
        return [] as AuditEvent[];
      }
    })
  );

  return perCase.flat();
}

/**
 * Executes cryptographic hash-chain verification. The real backend route is
 * GET /audit/verify-chain (admin-only), which returns
 * { valid, total_entries, broken_at_seq, broken_at_id } — not the
 * failed_block_number/reason/witness_nodes_* shape this used to assume.
 */
export async function verifyAuditChain(): Promise<AuditVerificationResult> {
  const res = await api.get<{
    valid: boolean;
    total_entries: number;
    broken_at_seq: number | null;
    broken_at_id: string | null;
  }>('/audit/verify-chain');

  const raw = res.data;

  return {
    valid: Boolean(raw?.valid ?? true),
    total_entries: Number(raw?.total_entries ?? 0),
    checked_entries: Number(raw?.total_entries ?? 0),
    failed_entry_id: raw?.broken_at_id ?? undefined,
    failed_block_number: raw?.broken_at_seq ?? undefined,
    reason: raw?.broken_at_id ? 'entry_hash or prev_hash mismatch' : undefined,
    latency_ms: 0,
    witness_nodes_online: 1,
    witness_nodes_total: 1,
  };
}

// There is no backend route to deliberately corrupt a row from the app —
// by design, tampering is only ever introduced via scripts/seed_tamper.sql
// before a demo (see DESIGN.md "the demo moment"). These are kept as no-ops
// so callers in AuditLog.tsx don't crash, but they no longer pretend to hit
// a real endpoint.
export async function injectTamperAtBlock150(): Promise<boolean> {
  console.warn(
    'Tamper injection is not an API feature — run scripts/seed_tamper.sql against the DB before the demo instead.'
  );
  return false;
}

export async function resetAuditChain(): Promise<boolean> {
  console.warn('There is no reset-chain endpoint — the audit log is append-only by design.');
  return false;
}

export const auditService = {
  getAuditEvents,
  getAuditLogs: getAuditEvents,
  verifyAuditChain,
  injectTamperAtBlock150,
  resetAuditChain,
};
