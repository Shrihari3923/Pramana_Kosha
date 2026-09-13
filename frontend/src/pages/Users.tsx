import React, { useState, useEffect } from 'react';
import { AppShell } from '../components/layout/AppShell';
import { User } from '../types';
import { userService } from '../services/userService';
import { UserStatsCards } from '../components/users/UserStatsCards';
import { UserTable } from '../components/users/UserTable';
import { UserProvisionModal } from '../components/users/UserProvisionModal';
import { UserKeyModal } from '../components/users/UserKeyModal';
import { BackendUnavailable } from '../components/common/BackendUnavailable';
import { ApiError } from '../services/api';

export const Users: React.FC = () => {
  const [personnel, setPersonnel] = useState<User[]>([]);
  const [loading, setLoading] = useState<boolean>(true);
  const [backendError, setBackendError] = useState<{
    status: number;
    endpoint: string;
    message: string;
  } | null>(null);

  const [searchQuery, setSearchQuery] = useState('');
  const [roleFilter, setRoleFilter] = useState<string>('ALL');

  const [isProvisionModalOpen, setIsProvisionModalOpen] = useState(false);
  const [isKeyModalOpen, setIsKeyModalOpen] = useState(false);
  const [selectedOfficer, setSelectedOfficer] = useState<User | null>(null);
  const [actionLoadingId, setActionLoadingId] = useState<string | null>(null);

  const fetchUsers = async () => {
    try {
      setLoading(true);
      setBackendError(null);

      const data = await userService.getUsers();
      setPersonnel(data);
    } catch (err: unknown) {
      console.error('Failed to load personnel records from backend:', err);

      if (err instanceof ApiError) {
        setBackendError({
          status: err.status,
          endpoint: err.endpoint,
          message: err.message,
        });
      } else {
        setBackendError({
          status: 0,
          endpoint: '/users',
          message: (err as Error).message,
        });
      }
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchUsers();
  }, []);

  const handleInspectKey = (officer: User) => {
    setSelectedOfficer(officer);
    setIsKeyModalOpen(true);
  };

  const handleToggleStatus = async (officer: User) => {
    try {
      setActionLoadingId(officer.id);

      const currentStatus =
        officer.status === 'SUSPENDED' ? 'SUSPENDED' : 'ACTIVE';

      const updated = await userService.toggleUserStatus(
        officer.id,
        currentStatus
      );

      setPersonnel((prev) =>
        prev.map((p) => (p.id === officer.id ? updated : p))
      );
    } catch (err: any) {
      console.error('Failed to toggle status:', err);

      alert(
        `Backend update failed: ${
          err?.message || 'Unable to update officer status'
        }`
      );
    } finally {
      setActionLoadingId(null);
    }
  };

  const handleUserCreated = (newUser: User) => {
    setPersonnel((prev) => [newUser, ...prev]);
    fetchUsers();
  };

  const filteredPersonnel = personnel.filter((p) => {
    const q = searchQuery.toLowerCase();

    const nameStr = (p.name || '').toLowerCase();
    const emailStr = (p.email || '').toLowerCase();
    const badgeStr = (
      p.badgeNumber ||
      p.badge_number ||
      ''
    ).toLowerCase();
    const deptStr = (p.department || '').toLowerCase();

    const matchesSearch =
      nameStr.includes(q) ||
      emailStr.includes(q) ||
      badgeStr.includes(q) ||
      deptStr.includes(q);

    const matchesRole =
      roleFilter === 'ALL' || p.role === roleFilter;

    return matchesSearch && matchesRole;
  });

  return (
    <AppShell>
      <div className="flex flex-col gap-6 max-w-[1520px] mx-auto animate-fade-in">

        {/* =========================================================
            PAGE HEADER
        ========================================================= */}
        <section className="bg-white border border-slate-200 rounded-2xl shadow-sm overflow-hidden">
          <div className="bg-[#0B1F3A] px-5 sm:px-7 py-5 text-white">
            <div className="flex flex-col xl:flex-row xl:items-center justify-between gap-5">

              <div>
                <div className="flex flex-wrap items-center gap-2 mb-2">
                  <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md bg-white/10 border border-white/15 text-[10px] font-bold tracking-wider uppercase">
                    <span className="material-symbols-outlined text-[14px]">
                      admin_panel_settings
                    </span>
                    Administrator Control
                  </span>

                  <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md bg-emerald-400/10 border border-emerald-300/20 text-emerald-200 text-[10px] font-bold tracking-wider uppercase">
                    <span className="material-symbols-outlined text-[14px]">
                      verified_user
                    </span>
                    ChainDock Protected
                  </span>
                </div>

                <h1 className="text-2xl sm:text-3xl font-bold tracking-tight">
                  Officer Management
                </h1>

                <p className="text-sm text-slate-300 mt-1.5 max-w-3xl">
                  Manage authorized police personnel, access roles,
                  account status, and cryptographic signing credentials.
                </p>
              </div>

              <div className="flex items-center gap-2 shrink-0">
                <button
                  onClick={fetchUsers}
                  disabled={loading}
                  className="h-10 px-3.5 bg-white/10 hover:bg-white/15 border border-white/15 rounded-lg text-sm font-medium flex items-center gap-2 transition-colors disabled:opacity-50"
                  title="Refresh personnel records"
                >
                  <span
                    className={`material-symbols-outlined text-[18px] ${
                      loading ? 'animate-spin' : ''
                    }`}
                  >
                    refresh
                  </span>
                  Refresh
                </button>

                <button
                  onClick={() => setIsProvisionModalOpen(true)}
                  className="h-10 px-4 bg-white text-[#0B1F3A] hover:bg-slate-100 rounded-lg text-sm font-bold flex items-center gap-2 transition-colors shadow-sm"
                >
                  <span className="material-symbols-outlined text-[18px]">
                    person_add
                  </span>
                  Add Officer
                </button>
              </div>
            </div>
          </div>

          {/* Security strip */}
          <div className="px-5 sm:px-7 py-3 bg-slate-50 border-t border-slate-200 flex flex-wrap items-center gap-x-6 gap-y-2 text-xs">
            <div className="flex items-center gap-2 text-slate-600">
              <span className="material-symbols-outlined text-[17px] text-emerald-600">
                lock
              </span>
              <span>Role-based access control</span>
            </div>

            <div className="flex items-center gap-2 text-slate-600">
              <span className="material-symbols-outlined text-[17px] text-blue-600">
                key
              </span>
              <span>Cryptographic credentials</span>
            </div>

            <div className="flex items-center gap-2 text-slate-600">
              <span className="material-symbols-outlined text-[17px] text-violet-600">
                history
              </span>
              <span>Audit activity tracked</span>
            </div>

            <div className="flex items-center gap-2 text-slate-600">
              <span className="material-symbols-outlined text-[17px] text-amber-600">
                security
              </span>
              <span>Evidence operations protected</span>
            </div>
          </div>
        </section>

        {/* =========================================================
            LOADING / ERROR / CONTENT
        ========================================================= */}
        {loading ? (
          <div className="bg-white border border-slate-200 rounded-2xl shadow-sm p-16 text-center">
            <div className="w-10 h-10 border-2 border-[#0B1F3A] border-t-transparent rounded-full animate-spin mx-auto mb-4" />

            <h3 className="text-sm font-bold text-slate-800">
              Loading officer records
            </h3>

            <p className="text-xs text-slate-500 mt-1">
              Retrieving personnel and access-control information from
              the ChainDock backend...
            </p>
          </div>
        ) : backendError ? (
          <BackendUnavailable
            moduleName="Officer Management"
            endpoint={backendError.endpoint}
            status={backendError.status}
            errorMessage={backendError.message}
            onRetry={fetchUsers}
          />
        ) : (
          <>
            {/* =====================================================
                REAL BACKEND STATISTICS
            ===================================================== */}
            <section>
              <div className="flex items-center gap-2 mb-3">
                <span className="w-1 h-5 rounded-full bg-[#0B1F3A]" />

                <div>
                  <h2 className="text-sm font-bold text-slate-800">
                    Personnel Overview
                  </h2>

                  <p className="text-[11px] text-slate-500">
                    Current officer and administrator records
                  </p>
                </div>
              </div>

              <UserStatsCards personnel={personnel} />
            </section>

            {/* =====================================================
                PERSONNEL TABLE
            ===================================================== */}
            <section className="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden">

              {/* Toolbar */}
              <div className="px-4 sm:px-5 py-4 border-b border-slate-200 bg-slate-50">
                <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-3">

                  {/* Search */}
                  <div className="relative w-full lg:w-[430px]">
                    <span className="material-symbols-outlined absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 text-[19px]">
                      search
                    </span>

                    <input
                      type="text"
                      placeholder="Search officer, badge, email, or department..."
                      value={searchQuery}
                      onChange={(e) => setSearchQuery(e.target.value)}
                      className="w-full h-10 pl-10 pr-4 text-sm bg-white rounded-lg border border-slate-200 text-slate-800 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-[#0B1F3A]/10 focus:border-[#0B1F3A] transition-all"
                    />
                  </div>

                  {/* Filters */}
                  <div className="flex flex-wrap items-center gap-2">
                    <div className="flex items-center gap-2">
                      <span className="text-xs font-semibold text-slate-500">
                        Role:
                      </span>

                      <select
                        value={roleFilter}
                        onChange={(e) =>
                          setRoleFilter(e.target.value)
                        }
                        className="h-10 px-3 text-sm bg-white rounded-lg border border-slate-200 text-slate-800 focus:outline-none focus:ring-2 focus:ring-[#0B1F3A]/10 focus:border-[#0B1F3A]"
                      >
                        <option value="ALL">
                          All Roles
                        </option>

                        <option value="INVESTIGATOR">
                          Investigators
                        </option>

                        <option value="SUPERVISOR">
                          Supervisors
                        </option>

                        <option value="ADMIN">
                          Administrators
                        </option>
                      </select>
                    </div>

                    {(searchQuery || roleFilter !== 'ALL') && (
                      <button
                        onClick={() => {
                          setSearchQuery('');
                          setRoleFilter('ALL');
                        }}
                        className="h-10 px-3 rounded-lg border border-slate-200 bg-white text-xs font-semibold text-slate-600 hover:bg-slate-100 flex items-center gap-1.5"
                      >
                        <span className="material-symbols-outlined text-[16px]">
                          close
                        </span>
                        Clear
                      </button>
                    )}
                  </div>
                </div>

                {/* Results information */}
                <div className="flex flex-wrap items-center justify-between gap-2 mt-3">
                  <p className="text-[11px] text-slate-500">
                    Showing{' '}
                    <span className="font-bold text-slate-700">
                      {filteredPersonnel.length}
                    </span>{' '}
                    of{' '}
                    <span className="font-bold text-slate-700">
                      {personnel.length}
                    </span>{' '}
                    personnel records
                  </p>

                  <div className="flex items-center gap-1.5 text-[10px] font-bold uppercase tracking-wider text-emerald-700">
                    <span className="w-1.5 h-1.5 rounded-full bg-emerald-500" />
                    Live backend records
                  </div>
                </div>
              </div>

              {/* Table */}
              <div className="overflow-x-auto">
                <UserTable
                  personnel={filteredPersonnel}
                  onInspectKey={handleInspectKey}
                  onToggleStatus={handleToggleStatus}
                  actionLoadingId={actionLoadingId}
                />
              </div>
            </section>

            {/* =====================================================
                SECURITY INFORMATION
            ===================================================== */}
            <section className="grid grid-cols-1 md:grid-cols-3 gap-4">

              <div className="bg-white border border-slate-200 rounded-xl p-4 shadow-sm">
                <div className="flex items-start gap-3">
                  <div className="w-10 h-10 rounded-lg bg-blue-50 text-blue-700 flex items-center justify-center shrink-0">
                    <span className="material-symbols-outlined text-[21px]">
                      manage_accounts
                    </span>
                  </div>

                  <div>
                    <h3 className="text-sm font-bold text-slate-800">
                      Role-Based Access
                    </h3>

                    <p className="text-xs text-slate-500 mt-1 leading-relaxed">
                      Officer permissions are controlled through
                      backend role assignments and protected routes.
                    </p>
                  </div>
                </div>
              </div>

              <div className="bg-white border border-slate-200 rounded-xl p-4 shadow-sm">
                <div className="flex items-start gap-3">
                  <div className="w-10 h-10 rounded-lg bg-violet-50 text-violet-700 flex items-center justify-center shrink-0">
                    <span className="material-symbols-outlined text-[21px]">
                      vpn_key
                    </span>
                  </div>

                  <div>
                    <h3 className="text-sm font-bold text-slate-800">
                      Signing Credentials
                    </h3>

                    <p className="text-xs text-slate-500 mt-1 leading-relaxed">
                      Authorized personnel can inspect and manage
                      registered cryptographic signing credentials.
                    </p>
                  </div>
                </div>
              </div>

              <div className="bg-white border border-slate-200 rounded-xl p-4 shadow-sm">
                <div className="flex items-start gap-3">
                  <div className="w-10 h-10 rounded-lg bg-emerald-50 text-emerald-700 flex items-center justify-center shrink-0">
                    <span className="material-symbols-outlined text-[21px]">
                      policy
                    </span>
                  </div>

                  <div>
                    <h3 className="text-sm font-bold text-slate-800">
                      ChainDock Security
                    </h3>

                    <p className="text-xs text-slate-500 mt-1 leading-relaxed">
                      Personnel actions remain connected to the
                      platform's audit, access-control, and integrity
                      mechanisms.
                    </p>
                  </div>
                </div>
              </div>
            </section>
          </>
        )}
      </div>

      {/* ===========================================================
          PROVISION OFFICER MODAL
      =========================================================== */}
      <UserProvisionModal
        isOpen={isProvisionModalOpen}
        onClose={() => setIsProvisionModalOpen(false)}
        onCreated={handleUserCreated}
      />

      {/* ===========================================================
          INSPECT / ROTATE KEY MODAL
      =========================================================== */}
      <UserKeyModal
        officer={selectedOfficer}
        isOpen={isKeyModalOpen}
        onClose={() => setIsKeyModalOpen(false)}
        onKeyRotated={fetchUsers}
      />
    </AppShell>
  );
};
