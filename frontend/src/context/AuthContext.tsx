import { createContext, useContext, useState, useEffect, ReactNode } from 'react';
import { User, Role } from '../types';
import { api, ApiError } from '../services/api';
import { normalizeAuthUser, login as authLogin, logout as authLogout } from '../services/auth';

interface AuthContextType {
  user: User | null;
  role: Role | undefined;
  isAuthenticated: boolean;
  isLoading: boolean;
login: (email: string, password?: string, expectedRole?: Role) => Promise<void>;  logout: () => void;
  enterEvaluationSession: (role?: Role) => void;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;

    // Restore a session by validating the stored token against the backend
    // (GET /users/me) rather than trusting whatever's cached in storage.
    // Previously this block silently logged every visitor in as a fake
    // Admin user with a fake token whenever no session existed — no route
    // was ever actually protected, and /auth/login was mostly decorative.
    async function restoreSession() {
      const token = sessionStorage.getItem('chaindock_token') || localStorage.getItem('chaindock_token');
      if (!token) {
        if (!cancelled) setUser(null);
        if (!cancelled) setIsLoading(false);
        return;
      }

      try {
        const res = await api.get<any>('/users/me');
        const raw = res.data?.user || res.data;
        const validated = normalizeAuthUser(raw);
        if (!cancelled) {
          setUser(validated);
          sessionStorage.setItem('chaindock_user', JSON.stringify(validated));
        }
      } catch (err) {
        // Invalid/expired token (401) or backend unreachable — either way,
        // don't keep the person "logged in" on faith. Clear the stale
        // session and send them back to /login.
        if (!(err instanceof ApiError) || err.status === 401 || err.status === 0) {
          authLogout();
        }
        if (!cancelled) setUser(null);
      } finally {
        if (!cancelled) setIsLoading(false);
      }
    }

    restoreSession();

    const handleUnauthorized = () => {
      setUser(null);
    };

    window.addEventListener('chaindock:unauthorized', handleUnauthorized);
    return () => {
      cancelled = true;
      window.removeEventListener('chaindock:unauthorized', handleUnauthorized);
    };
  }, []);

const login = async (
  email: string,
  password?: string,
  expectedRole?: Role
) => {
  setIsLoading(true);

  try {
    const res = await authLogin(email, password);

    // Make sure the account matches the selected login type
    if (expectedRole && res.user.role !== expectedRole) {
      authLogout();
      throw new Error(
        expectedRole === 'ADMIN'
          ? 'This account is an Investigating Officer account. Please use the Investigating Officer login.'
          : 'This account is an Administrator account. Please use the Administrator login.'
      );
    }

    setUser(res.user);
  } finally {
    setIsLoading(false);
  }
};

  /**
   * Explicit, user-initiated "try it without a real account" shortcut for
   * judges/evaluators — triggered only by a deliberate click in Login.tsx,
   * never automatically. This does NOT hit the backend and does NOT grant
   * a real session; anything gated by a real AuthenticatedUser extractor
   * call server-side (case access, audit trail, etc.) will still 401/403
   * against a real backend, since there's no genuine JWT behind this token.
   */
  const enterEvaluationSession = (targetRole: Role = 'ADMIN') => {
    const roleUpper = String(targetRole).toUpperCase() as Role;
    const evalUser: User = {
      id: 'eval-session-user',
      name: roleUpper === 'ADMIN' ? 'Chief Registrar (Admin)' : 'Inspector Priya Sharma',
      email: roleUpper === 'ADMIN' ? 'admin@police.gov.in' : 'officer@police.gov.in',
      role: roleUpper,
      badgeNumber: roleUpper === 'ADMIN' ? 'ADM-01' : 'POL-8821',
      badge_number: roleUpper === 'ADMIN' ? 'ADM-01' : 'POL-8821',
      status: 'ACTIVE',
    };
    sessionStorage.setItem('chaindock_token', 'evaluation-preview-not-a-real-session');
    sessionStorage.setItem('chaindock_user', JSON.stringify(evalUser));
    setUser(evalUser);
  };

  const logout = () => {
    authLogout();
    setUser(null);
  };

  return (
    <AuthContext.Provider
      value={{
        user,
        role: user?.role,
        isAuthenticated: !!user,
        isLoading,
        login,
        logout,
        enterEvaluationSession,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}
