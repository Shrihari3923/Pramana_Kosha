import React from 'react';
import { useNavigate } from 'react-router-dom';
import { AppShell } from '../../components/layout/AppShell';
import { useAuth } from '../../hooks/useAuth';

export const Unauthorized: React.FC = () => {
  const navigate = useNavigate();
  const { role, user } = useAuth();

  return (
    <AppShell>
      <div className="min-h-[70vh] flex items-center justify-center px-4 py-8">
        <div className="w-full max-w-2xl">

          {/* Security Header */}
          <div className="bg-[#0b1f3a] text-white rounded-t-2xl px-6 sm:px-8 py-5 border border-[#0b1f3a]">
            <div className="flex items-center gap-3">
              <div className="w-11 h-11 rounded-xl bg-white/10 border border-white/20 flex items-center justify-center">
                <span className="material-symbols-outlined text-[25px]">
                  shield_lock
                </span>
              </div>

              <div>
                <p className="text-[10px] uppercase tracking-[0.18em] text-blue-200 font-mono font-bold">
                  pramāṇa-kośa
                </p>
                <h1 className="text-lg sm:text-xl font-bold tracking-tight">
                  Access Control
                </h1>
              </div>
            </div>
          </div>

          {/* Main Card */}
          <div className="bg-white border-x border-b border-slate-200 rounded-b-2xl shadow-xl overflow-hidden">

            {/* Restricted Status */}
            <div className="px-6 sm:px-8 pt-8 pb-6 text-center">
              <div className="mx-auto w-20 h-20 rounded-full bg-red-50 border-4 border-red-100 flex items-center justify-center">
                <span className="material-symbols-outlined text-[42px] text-red-600">
                  gpp_maybe
                </span>
              </div>

              <div className="mt-5">
                <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-red-50 border border-red-200 text-red-700 text-[10px] font-mono font-bold uppercase tracking-wider">
                  <span className="w-1.5 h-1.5 rounded-full bg-red-500" />
                  403 — Access Denied
                </span>
              </div>

              <h2 className="mt-4 text-2xl sm:text-3xl font-bold text-[#0b1f3a]">
                Access Restricted
              </h2>

              <p className="mt-2 text-sm text-slate-500 max-w-lg mx-auto leading-relaxed">
                Your current officer clearance does not permit access to this
                protected pramāṇa-kośa resource.
              </p>
            </div>

            {/* Session Security Context */}
            <div className="mx-6 sm:mx-8 mb-6 rounded-xl border border-slate-200 bg-slate-50 overflow-hidden">

              <div className="px-4 py-3 bg-[#0b1f3a] text-white flex items-center gap-2">
                <span className="material-symbols-outlined text-[17px]">
                  badge
                </span>
                <span className="text-[10px] font-mono font-bold uppercase tracking-wider">
                  Current Session Security Context
                </span>
              </div>

              <div className="p-4 space-y-3 text-xs">

                <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-1 border-b border-slate-200 pb-3">
                  <span className="text-slate-500">
                    Authenticated Officer
                  </span>
                  <span className="font-semibold text-slate-900">
                    {user?.name || 'Officer'}
                  </span>
                </div>

                <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-1 border-b border-slate-200 pb-3">
                  <span className="text-slate-500">
                    Assigned Clearance
                  </span>
                  <span className="font-mono font-bold text-[#0b1f3a]">
                    {role || 'UNKNOWN'}
                  </span>
                </div>

                <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-1">
                  <span className="text-slate-500">
                    Access Disposition
                  </span>
                  <span className="inline-flex w-fit items-center gap-1 px-2 py-1 rounded-md bg-red-50 border border-red-200 text-red-700 text-[10px] font-mono font-bold">
                    <span className="material-symbols-outlined text-[13px]">
                      block
                    </span>
                    FORBIDDEN
                  </span>
                </div>

              </div>
            </div>

            {/* Permission Notice */}
            <div className="mx-6 sm:mx-8 mb-6 rounded-xl border border-blue-100 bg-blue-50/60 p-4">
              <div className="flex gap-3">
                <span className="material-symbols-outlined text-blue-700 text-[20px]">
                  admin_panel_settings
                </span>

                <div>
                  <p className="text-xs font-bold text-blue-900">
                    Restricted Administrative Resource
                  </p>

                  <p className="text-[11px] text-blue-800/80 mt-1 leading-relaxed">
                    This resource requires elevated administrative clearance.
                    Access permissions are enforced by the ChainDock security
                    layer and recorded through the system audit mechanism.
                  </p>
                </div>
              </div>
            </div>

            {/* Actions */}
            <div className="px-6 sm:px-8 pb-7">
              <div className="flex flex-col sm:flex-row gap-3">

                <button
                  onClick={() => navigate('/dashboard')}
                  className="flex-1 py-3 px-4 rounded-lg bg-[#0b1f3a] text-white hover:bg-[#12345f] text-xs font-semibold flex items-center justify-center gap-2 transition-colors shadow-sm"
                >
                  <span className="material-symbols-outlined text-[17px]">
                    dashboard
                  </span>
                  Return to Dashboard
                </button>

                <button
                  onClick={() => navigate('/login')}
                  className="flex-1 py-3 px-4 rounded-lg bg-white border border-slate-300 text-slate-700 hover:bg-slate-50 text-xs font-semibold flex items-center justify-center gap-2 transition-colors"
                >
                  <span className="material-symbols-outlined text-[17px]">
                    switch_account
                  </span>
                  Switch Session
                </button>

              </div>
            </div>

            {/* ChainDock Security Footer */}
            <div className="border-t border-slate-200 bg-slate-50 px-6 sm:px-8 py-4">
              <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2">

                <div className="flex items-center gap-2">
                  <span className="material-symbols-outlined text-[16px] text-emerald-600">
                    verified_user
                  </span>

                  <span className="text-[10px] font-mono font-bold uppercase tracking-wider text-slate-600">
                    ChainDock Security Layer
                  </span>
                </div>

                <span className="text-[10px] font-mono text-slate-400">
                  Authorization event recorded
                </span>

              </div>
            </div>

          </div>
        </div>
      </div>
    </AppShell>
  );
};
