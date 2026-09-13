import { api } from './api';
import { User, Role } from '../types';

interface LoginResponse {
  access_token?: string;
  token?: string;
  user: User;
}

export function normalizeAuthUser(rawUser: any): User {
  const roleUpper = String(rawUser.role || 'INVESTIGATOR').toUpperCase() as Role;
  const email = String(rawUser.email || '');
  const derivedName =
    rawUser.name ||
    (roleUpper === 'ADMIN'
      ? 'Chief Registrar (Admin)'
      : roleUpper === 'SUPERVISOR'
      ? 'Supervising Officer'
      : 'Investigating Officer');

  return {
    id: String(rawUser.id || ''),
    email,
    name: derivedName,
    role: roleUpper,
    badgeNumber: rawUser.badgeNumber || rawUser.badge_number || (roleUpper === 'ADMIN' ? 'ADM-01' : 'POL-2026'),
    badge_number: rawUser.badge_number || rawUser.badgeNumber || (roleUpper === 'ADMIN' ? 'ADM-01' : 'POL-2026'),
    jurisdictionNode: rawUser.jurisdictionNode || rawUser.jurisdiction_node || 'Node Alpha',
    jurisdiction_node: rawUser.jurisdiction_node || rawUser.jurisdictionNode || 'Node Alpha',
    status: rawUser.status === 'SUSPENDED' ? 'SUSPENDED' : 'ACTIVE',
  };
}

export async function login(email: string, password?: string): Promise<{ user: User; token: string }> {
  const res = await api.post<LoginResponse>('/auth/login', { email, password });
  const token = res.data?.access_token || res.data?.token;

  if (token && res.data?.user) {
    const user = normalizeAuthUser(res.data.user);
    sessionStorage.setItem('chaindock_token', token);
    sessionStorage.setItem('chaindock_user', JSON.stringify(user));
    localStorage.setItem('chaindock_token', token);
    localStorage.setItem('chaindock_user', JSON.stringify(user));
    return { user, token };
  }

  throw new Error('Authentication failed: Invalid response from backend.');
}

export function getCurrentUser(): User | null {
  const stored = sessionStorage.getItem('chaindock_user') || localStorage.getItem('chaindock_user');
  if (stored) {
    try {
      const u = JSON.parse(stored);
      if (u) {
        return normalizeAuthUser(u);
      }
      return null;
    } catch {
      return null;
    }
  }
  return null;
}

export function logout(): void {
  sessionStorage.removeItem('chaindock_token');
  sessionStorage.removeItem('chaindock_user');
  localStorage.removeItem('chaindock_token');
  localStorage.removeItem('chaindock_user');
}

export async function getUsers(): Promise<User[]> {
  const res = await api.get<User[] | { users: User[] }>('/users');
  if (Array.isArray(res.data)) {
    return res.data;
  }
  if (res.data && typeof res.data === 'object' && 'users' in res.data && Array.isArray((res.data as { users: User[] }).users)) {
    return (res.data as { users: User[] }).users;
  }
  return [];
}

export const authService = {
  login,
  logout,
  getCurrentUser,
  getUsers,
};
