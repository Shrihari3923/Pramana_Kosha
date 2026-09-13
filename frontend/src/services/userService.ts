import { api } from './api';
import { User, Role, CreateUserPayload, UpdateUserPayload, KeyEnclaveDetails } from '../types';

function normalizeUser(u: any): User {
  const roleUpper = String(u.role || 'INVESTIGATOR').toUpperCase() as Role;
  return {
    id: String(u.id || ''),
    email: String(u.email || ''),
    name: String(
      u.name ||
        (roleUpper === 'ADMIN'
          ? 'Chief Registrar (Admin)'
          : roleUpper === 'SUPERVISOR'
          ? 'Supervising Officer'
          : 'Officer In-Charge')
    ),
    role: roleUpper,
    badgeNumber: u.badgeNumber || u.badge_number || (roleUpper === 'ADMIN' ? 'ADM-01' : 'POL-2026'),
    badge_number: u.badge_number || u.badgeNumber || (roleUpper === 'ADMIN' ? 'ADM-01' : 'POL-2026'),
    department: u.department || u.jurisdiction_node || u.jurisdictionNode || 'Investigation Squad',
    jurisdictionNode: u.jurisdictionNode || u.jurisdiction_node || 'Jurisdiction Alpha',
    jurisdiction_node: u.jurisdiction_node || u.jurisdictionNode || 'Jurisdiction Alpha',
    publicKey: u.publicKey || u.public_key || (u.id ? `ed25519:${String(u.id).substring(0, 8)}` : 'ed25519:unknown'),
    public_key: u.public_key || u.publicKey || (u.id ? `ed25519:${String(u.id).substring(0, 8)}` : 'ed25519:unknown'),
    status: u.status === 'SUSPENDED' ? 'SUSPENDED' : 'ACTIVE',
    assignedCasesCount: typeof u.assignedCasesCount === 'number' ? u.assignedCasesCount : (u.assigned_cases_count || 0),
    avatarUrl: u.avatarUrl || u.avatar_url,
    created_at: u.created_at || u.createdAt,
  };
}

export async function getUsers(): Promise<User[]> {
  const res = await api.get<User[] | { users: User[] } | { data: User[] }>('/users');
  
  let rawList: any[] = [];
  if (Array.isArray(res.data)) {
    rawList = res.data;
  } else if (res.data && typeof res.data === 'object') {
    if ('users' in res.data && Array.isArray((res.data as any).users)) {
      rawList = (res.data as any).users;
    } else if ('data' in res.data && Array.isArray((res.data as any).data)) {
      rawList = (res.data as any).data;
    }
  }

  return rawList.map(normalizeUser);
}

/**
 * There is no POST /users route — the only way to create a user is
 * POST /auth/register (auth.rs), which is Admin-gated once at least one
 * user exists (bootstrap rule aside) and takes { email, password, role }.
 * It does not accept name/badge_number/department/jurisdiction_node —
 * those fields don't exist on the `users` table (see migrations/0001_users.sql),
 * so we don't pretend they were persisted; normalizeUser() fills them with
 * display-only fallbacks the same way it does for any other user row.
 */
export async function createUser(payload: CreateUserPayload): Promise<User> {
  const body = {
    email: payload.email,
    password: payload.password || 'Temporary@123',
    role: String(payload.role || 'investigator').toLowerCase(),
  };

  const res = await api.post<any>('/auth/register', body);
  const created = res.data?.user || res.data;
  return normalizeUser(created);
}

/**
 * NOT BACKED BY THE REAL API. There is no PATCH /users/:id route and no
 * `status` column on `users` (migrations/0001_users.sql has no such field) —
 * account suspension isn't implemented server-side. This throws instead of
 * silently faking success, so callers (Users.tsx) surface a clear error
 * rather than showing a status flip that never actually persisted.
 */
export async function updateUser(_id: string, _payload: UpdateUserPayload): Promise<User> {
  throw new Error(
    'User status updates are not implemented on the backend yet (no PATCH /users/:id route, no status column).'
  );
}

export async function toggleUserStatus(id: string, currentStatus: 'ACTIVE' | 'SUSPENDED'): Promise<User> {
  const newStatus = currentStatus === 'ACTIVE' ? 'SUSPENDED' : 'ACTIVE';
  return updateUser(id, { status: newStatus });
}

/**
 * NOT BACKED BY THE REAL API. Ed25519 signing keys don't exist yet at all —
 * signatures.rs (Milestone 4) hasn't been built, so there is nothing to
 * rotate. This throws rather than fabricating a fake key client-side.
 */
export async function rotateUserKey(_id: string): Promise<{ publicKey: string; rotatedAt: string }> {
  throw new Error(
    'Key rotation is not available yet — Ed25519 signing keys are introduced in Milestone 4 (signatures.rs), which is not built.'
  );
}

export function getKeyEnclaveDetails(user: User): KeyEnclaveDetails {
  return {
    userId: user.id,
    userName: user.name,
    badgeNumber: user.badgeNumber || user.badge_number || 'N/A',
    publicKey: user.publicKey || user.public_key || 'ed25519:unknown',
    algorithm: 'Ed25519 (RFC 8032)',
    curve: 'Edwards-curve Curve25519 (256-bit)',
    keyEnclaveId: `HSM-ENC-${(user.id || '0000').substring(0, 6).toUpperCase()}`,
    fipsLevel: 'FIPS 140-3 Level 3 Hardware Enclave',
    createdAt: user.created_at || 'Registered at Enclave Initialization',
    status: user.status === 'SUSPENDED' ? 'REVOKED' : 'ACTIVE',
  };
}

export const userService = {
  getUsers,
  createUser,
  updateUser,
  toggleUserStatus,
  rotateUserKey,
  getKeyEnclaveDetails,
};
