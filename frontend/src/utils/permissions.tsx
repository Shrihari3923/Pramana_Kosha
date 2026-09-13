import { Role } from '../types';

export const PERMISSIONS = {
  CAN_VIEW_CASES: ['INVESTIGATOR', 'SUPERVISOR', 'ADMIN'] as Role[],
  CAN_CREATE_CASE: ['SUPERVISOR', 'ADMIN'] as Role[],
  CAN_VIEW_DOCUMENTS: ['INVESTIGATOR', 'SUPERVISOR', 'ADMIN'] as Role[],
  CAN_UPLOAD_DOCUMENT: ['INVESTIGATOR', 'SUPERVISOR', 'ADMIN'] as Role[],
  CAN_DOWNLOAD_DOCUMENT: ['INVESTIGATOR', 'SUPERVISOR', 'ADMIN'] as Role[],
  CAN_FINALIZE_DOCUMENT: ['SUPERVISOR', 'ADMIN'] as Role[],
  CAN_SIGN_DOCUMENT: ['SUPERVISOR', 'ADMIN'] as Role[],
  CAN_VERIFY_DOCUMENT: ['INVESTIGATOR', 'SUPERVISOR', 'ADMIN'] as Role[],
  CAN_VIEW_EVIDENCE: ['INVESTIGATOR', 'SUPERVISOR', 'ADMIN'] as Role[],
  CAN_TRANSFER_CUSTODY: ['INVESTIGATOR', 'SUPERVISOR', 'ADMIN'] as Role[],
  // audit_trail (GET /cases/:id/audit-trail) is now open to all three roles,
  // scoped to cases the caller is assigned to (see audit.rs assert_case_access) —
  // this used to be SUPERVISOR/ADMIN only, matching the old backend gate.
  CAN_VIEW_AUDIT: ['INVESTIGATOR', 'SUPERVISOR', 'ADMIN'] as Role[],
  // GET /audit/verify-chain (audit.rs verify_chain) is Admin-only on the
  // backend — this used to say SUPERVISOR/ADMIN, which showed the "Verify
  // Chain Integrity" button to supervisors who would then get a 403.
  // Matches PRD.md's role table, which lists chain-verification under Admin only.
  CAN_RUN_CHAIN_VERIFICATION: ['ADMIN'] as Role[],
  CAN_MANAGE_USERS: ['ADMIN'] as Role[],
  CAN_VIEW_SECURITY_CENTER: ['SUPERVISOR', 'ADMIN'] as Role[],
};

export function hasPermission(role: Role | string | undefined, allowedRoles: Role[]): boolean {
  if (!role) return false;
  const upper = String(role).toUpperCase();
  return allowedRoles.some((r) => r.toUpperCase() === upper);
}

export function canFinalize(role?: Role): boolean {
  return hasPermission(role, PERMISSIONS.CAN_FINALIZE_DOCUMENT);
}

export function canSign(role?: Role): boolean {
  return hasPermission(role, PERMISSIONS.CAN_SIGN_DOCUMENT);
}

export function canViewAudit(role?: Role): boolean {
  return hasPermission(role, PERMISSIONS.CAN_VIEW_AUDIT);
}

export function canVerifyChain(role?: Role): boolean {
  return hasPermission(role, PERMISSIONS.CAN_RUN_CHAIN_VERIFICATION);
}

export function canManageUsers(role?: Role): boolean {
  return hasPermission(role, PERMISSIONS.CAN_MANAGE_USERS);
}

export function canProvisionUsers(role?: Role): boolean {
  return hasPermission(role, PERMISSIONS.CAN_MANAGE_USERS);
}

export function canRevokeCredentials(role?: Role): boolean {
  return hasPermission(role, PERMISSIONS.CAN_MANAGE_USERS);
}

export function canRotateKeys(role?: Role): boolean {
  return hasPermission(role, PERMISSIONS.CAN_MANAGE_USERS);
}
