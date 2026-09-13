import React, { useEffect, useState } from 'react';
import { AppShell } from '../components/layout/AppShell';
import { CertificateViewer } from '../components/security/CertificateViewer';
import { securityService } from '../services/securityService';
import { blockchainService } from '../services/blockchain';
import { SecurityStats, BlockchainVerifyResult } from '../types';
import { BackendUnavailable } from '../components/common/BackendUnavailable';
import { ApiError } from '../services/api';

function StatTile({
  label,
  value,
  icon,
  color = 'text-[#0B1F3A]',
  note,
}: {
  label: string;
  value: string | number;
  icon: string;
  color?: string;
  note?: string;
}) {
  return (
    <div className="bg-white border border-slate-200 rounded-xl p-4 shadow-sm hover:shadow-md transition-shadow">
      <div className="flex items-center gap-2">
        <div className="w-8 h-8 rounded-lg bg-slate-100 flex items-center justify-center">
          <span className={`material-symbols-outlined text-[18px] ${color}`}>
            {icon}
          </span>
        </div>

        <span className="text-[10px] uppercase tracking-wide text-slate-400 font-bold">
          {label}
        </span>
      </div>

      <div className={`text-2xl font-bold font-mono mt-3 ${color}`}>
        {value}
      </div>

      {note && (
        <div className="text-[10px] text-slate-400 mt-1">
          {note}
        </div>
      )}
    </div>
  );
}

function StatusBadge({ value }: { value: string }) {
  const ok =
    value === 'OPERATIONAL' ||
    value === 'VERIFIED' ||
    value === 'EMPTY';

  return (
    <span
      className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[10px] font-bold font-mono border ${
        ok
          ? 'bg-emerald-50 text-emerald-700 border-emerald-200'
          : 'bg-red-50 text-red-700 border-red-200'
      }`}
    >
      <span
        className={`w-1.5 h-1.5 rounded-full ${
          ok ? 'bg-emerald-500' : 'bg-red-500'
        }`}
      />
      {value}
    </span>
  );
}

export const Security: React.FC = () => {
  const [isCertModalOpen, setIsCertModalOpen] = useState(false);

  const [stats, setStats] = useState<SecurityStats | null>(null);

  const [chainVerify, setChainVerify] =
    useState<BlockchainVerifyResult | null>(null);

  const [verifying, setVerifying] = useState(false);
  const [loading, setLoading] = useState(true);

  const [backendError, setBackendError] = useState<{
    status: number;
    endpoint: string;
    message: string;
  } | null>(null);

  const [statsError, setStatsError] = useState<string | null>(null);

  const loadStats = async () => {
    try {
      setLoading(true);
      setBackendError(null);
      setStatsError(null);

      const s = await securityService.getSecurityStats();

      setStats(s);
    } catch (err: unknown) {
      console.error('Failed to load security statistics:', err);

      if (err instanceof ApiError) {
        if (err.status === 403) {
          setStatsError(
            'Security statistics require Supervisor or Admin role.'
          );
        } else {
          setBackendError({
            status: err.status,
            endpoint: err.endpoint,
            message: err.message,
          });
        }
      } else {
        setBackendError({
          status: 0,
          endpoint: '/security/stats',
          message:
            err instanceof Error
              ? err.message
              : 'Unable to load security statistics.',
        });
      }
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadStats();
  }, []);

  const runVerification = async () => {
    setVerifying(true);

    try {
      const result = await blockchainService.verifyBlockchain();

      setChainVerify(result);
    } catch (err) {
      console.error('Blockchain verification failed:', err);
    } finally {
      setVerifying(false);
    }
  };

  return (
    <AppShell>
      <div className="space-y-6 animate-fade-in max-w-[1520px] mx-auto">

        {/* =====================================================
            HEADER
        ====================================================== */}
        <div className="flex flex-col xl:flex-row xl:items-center justify-between gap-5 pb-5 border-b border-slate-200">

          <div>
            <div className="flex flex-wrap items-center gap-3">

              <div className="flex items-center gap-3">

                <div className="w-11 h-11 rounded-xl bg-[#0B1F3A] flex items-center justify-center shadow-sm">
                  <span className="material-symbols-outlined text-white text-[24px]">
                    security
                  </span>
                </div>

                <div>
                  <h1 className="text-2xl lg:text-3xl font-bold tracking-tight text-[#0B1F3A]">
                    Security Center
                  </h1>

                  <p className="text-sm text-slate-500 mt-0.5">
                    pramāṇa-kośa security &amp; ChainDock integrity control
                  </p>
                </div>

              </div>

              <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-emerald-50 border border-emerald-200 text-emerald-700 text-[10px] font-bold tracking-wide">
                <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse" />
                SECURITY ACTIVE
              </span>

            </div>

            <p className="text-xs text-slate-500 mt-3 max-w-4xl">
              Monitor authentication, access control, cryptographic integrity,
              digital signatures, blockchain verification and evidence custody
              using live ChainDock backend data.
            </p>
          </div>

          <div className="flex items-center gap-2">

            <button
              onClick={loadStats}
              disabled={loading}
              className="px-3.5 py-2.5 bg-white hover:bg-slate-50 disabled:opacity-50 text-slate-700 border border-slate-200 rounded-lg text-xs font-semibold flex items-center gap-2 transition-colors shadow-sm"
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
              onClick={() => setIsCertModalOpen(true)}
              className="px-4 py-2.5 bg-[#0B1F3A] hover:bg-[#07172B] text-white rounded-lg text-xs font-bold flex items-center gap-2 transition-colors shadow-sm"
            >
              <span className="material-symbols-outlined text-[17px]">
                verified
              </span>

              Root CA Certificate
            </button>

          </div>
        </div>

        {/* =====================================================
            SECURITY LAYERS
        ====================================================== */}
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-4">

          {/* Cryptographic Hash */}
          <div className="bg-white border border-slate-200 rounded-xl p-5 shadow-sm">

            <div className="flex items-start justify-between">

              <div className="w-10 h-10 rounded-lg bg-blue-50 flex items-center justify-center">
                <span className="material-symbols-outlined text-blue-700">
                  tag
                </span>
              </div>

              <span className="text-[9px] font-bold text-emerald-600 bg-emerald-50 px-2 py-1 rounded-full">
                ACTIVE
              </span>

            </div>

            <h3 className="text-sm font-bold text-[#0B1F3A] mt-4">
              SHA-256 Integrity
            </h3>

            <p className="text-[11px] text-slate-500 leading-relaxed mt-2">
              Document and evidence integrity is protected through
              server-side cryptographic hashing and verification.
            </p>

            <div className="flex items-center gap-1.5 mt-4 text-[10px] font-semibold text-slate-500">
              <span className="material-symbols-outlined text-[14px]">
                verified
              </span>
              NIST FIPS 180-4
            </div>

          </div>

          {/* Digital Signatures */}
          <div className="bg-white border border-slate-200 rounded-xl p-5 shadow-sm">

            <div className="flex items-start justify-between">

              <div className="w-10 h-10 rounded-lg bg-indigo-50 flex items-center justify-center">
                <span className="material-symbols-outlined text-indigo-700">
                  draw
                </span>
              </div>

              <span className="text-[9px] font-bold text-emerald-600 bg-emerald-50 px-2 py-1 rounded-full">
                ACTIVE
              </span>

            </div>

            <h3 className="text-sm font-bold text-[#0B1F3A] mt-4">
              Digital Signatures
            </h3>

            <p className="text-[11px] text-slate-500 leading-relaxed mt-2">
              Officer and document signatures provide cryptographic
              authentication for protected records.
            </p>

            <div className="flex items-center gap-1.5 mt-4 text-[10px] font-semibold text-slate-500">
              <span className="material-symbols-outlined text-[14px]">
                key
              </span>
              Ed25519
            </div>

          </div>

          {/* Blockchain */}
          <div className="bg-white border border-slate-200 rounded-xl p-5 shadow-sm">

            <div className="flex items-start justify-between">

              <div className="w-10 h-10 rounded-lg bg-violet-50 flex items-center justify-center">
                <span className="material-symbols-outlined text-violet-700">
                  account_tree
                </span>
              </div>

              <span className="text-[9px] font-bold text-emerald-600 bg-emerald-50 px-2 py-1 rounded-full">
                CHAIN
              </span>

            </div>

            <h3 className="text-sm font-bold text-[#0B1F3A] mt-4">
              Evidence Ledger
            </h3>

            <p className="text-[11px] text-slate-500 leading-relaxed mt-2">
              ChainDock maintains linked blocks and transaction records for
              tamper detection and audit verification.
            </p>

            <div className="flex items-center gap-1.5 mt-4 text-[10px] font-semibold text-slate-500">
              <span className="material-symbols-outlined text-[14px]">
                link
              </span>
              SHA-256 Chain
            </div>

          </div>

          {/* Key Storage */}
          <div className="bg-white border border-slate-200 rounded-xl p-5 shadow-sm">

            <div className="flex items-start justify-between">

              <div className="w-10 h-10 rounded-lg bg-amber-50 flex items-center justify-center">
                <span className="material-symbols-outlined text-amber-700">
                  vpn_key
                </span>
              </div>

              <span className="text-[9px] font-bold text-amber-700 bg-amber-50 px-2 py-1 rounded-full">
                DEV MODE
              </span>

            </div>

            <h3 className="text-sm font-bold text-[#0B1F3A] mt-4">
              Key Protection
            </h3>

            <p className="text-[11px] text-slate-500 leading-relaxed mt-2">
              Development deployment protects private keys using encrypted
              database storage.
            </p>

            <div className="flex items-center gap-1.5 mt-4 text-[10px] font-semibold text-slate-500">
              <span className="material-symbols-outlined text-[14px]">
                lock
              </span>
              AES-256-GCM
            </div>

          </div>

        </div>

        {/* =====================================================
            LOADING
        ====================================================== */}
        {loading && (
          <div className="bg-white border border-slate-200 rounded-xl p-16 text-center shadow-sm">

            <div className="animate-spin w-9 h-9 border-2 border-[#0B1F3A] border-t-transparent rounded-full mx-auto mb-4" />

            <p className="text-sm font-semibold text-slate-700">
              Loading security statistics...
            </p>

            <p className="text-xs text-slate-400 mt-1">
              Retrieving live security information from ChainDock backend
            </p>

          </div>
        )}

        {/* =====================================================
            BACKEND ERROR
        ====================================================== */}
        {!loading && backendError && (
          <BackendUnavailable
            moduleName="Security Statistics"
            endpoint={backendError.endpoint}
            status={backendError.status}
            errorMessage={backendError.message}
            onRetry={loadStats}
          />
        )}

        {/* =====================================================
            ROLE ERROR
        ====================================================== */}
        {!loading && !backendError && statsError && (
          <div className="bg-amber-50 border border-amber-200 rounded-xl p-5">

            <div className="flex items-start gap-3">

              <div className="w-9 h-9 rounded-lg bg-amber-100 flex items-center justify-center shrink-0">
                <span className="material-symbols-outlined text-amber-700">
                  admin_panel_settings
                </span>
              </div>

              <div>
                <p className="text-sm font-bold text-amber-900">
                  Restricted Security Statistics
                </p>

                <p className="text-xs text-amber-800 mt-1">
                  {statsError}
                </p>
              </div>

            </div>

          </div>
        )}

        {/* =====================================================
            LIVE SECURITY DATA
        ====================================================== */}
        {!loading && !backendError && !statsError && stats && (
          <>

            {/* =================================================
                SYSTEM STATUS
            ================================================== */}
            <div className="bg-[#0B1F3A] rounded-xl p-5 text-white shadow-sm">

              <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-5">

                <div className="flex items-start gap-3">

                  <div className="w-10 h-10 rounded-lg bg-white/10 flex items-center justify-center">
                    <span className="material-symbols-outlined">
                      shield
                    </span>
                  </div>

                  <div>
                    <p className="text-sm font-bold">
                      ChainDock Security Infrastructure
                    </p>

                    <p className="text-[11px] text-slate-300 mt-1">
                      Live integrity and access-control status
                    </p>
                  </div>

                </div>

                <div className="flex flex-wrap items-center gap-3">

                  <div className="flex items-center gap-2">
                    <span className="text-[10px] text-slate-300">
                      Blockchain
                    </span>

                    <StatusBadge value={stats.blockchain_status} />
                  </div>

                  <div className="flex items-center gap-2">
                    <span className="text-[10px] text-slate-300">
                      Audit Chain
                    </span>

                    <StatusBadge value={stats.audit_chain_status} />
                  </div>

                </div>

              </div>

            </div>

            {/* =================================================
                CRYPTOGRAPHIC INTEGRITY
            ================================================== */}
            <section className="bg-white border border-slate-200 rounded-xl shadow-sm overflow-hidden">

              <div className="px-5 py-4 border-b border-slate-200 bg-slate-50/70">

                <div className="flex items-center gap-2">

                  <span className="material-symbols-outlined text-[#0B1F3A]">
                    fingerprint
                  </span>

                  <div>
                    <h2 className="text-sm font-bold text-[#0B1F3A]">
                      Cryptographic Integrity
                    </h2>

                    <p className="text-[10px] text-slate-500 mt-0.5">
                      Document, blockchain and audit-chain integrity metrics
                    </p>
                  </div>

                </div>

              </div>

              <div className="p-5 grid grid-cols-2 md:grid-cols-3 xl:grid-cols-5 gap-4">

                <StatTile
                  label="Total Documents"
                  value={stats.crypto_integrity.total_documents}
                  icon="description"
                />

                <StatTile
                  label="SHA-256 Hashes"
                  value={stats.crypto_integrity.documents_with_hash}
                  icon="tag"
                  color="text-emerald-700"
                />

                <StatTile
                  label="Blockchain Blocks"
                  value={stats.crypto_integrity.blockchain_blocks}
                  icon="view_agenda"
                  color="text-violet-700"
                />

                <StatTile
                  label="Blockchain TXs"
                  value={stats.crypto_integrity.blockchain_transactions}
                  icon="receipt_long"
                  color="text-blue-700"
                />

                <StatTile
                  label="Audit Entries"
                  value={stats.crypto_integrity.audit_chain_entries}
                  icon="history"
                />

              </div>

            </section>

            {/* =================================================
                BLOCKCHAIN VERIFICATION
            ================================================== */}
            <section className="bg-white border border-slate-200 rounded-xl shadow-sm overflow-hidden">

              <div className="px-5 py-4 border-b border-slate-200 bg-slate-50/70">

                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">

                  <div className="flex items-center gap-2">

                    <span className="material-symbols-outlined text-violet-700">
                      account_tree
                    </span>

                    <div>
                      <h2 className="text-sm font-bold text-[#0B1F3A]">
                        Blockchain Verification
                      </h2>

                      <p className="text-[10px] text-slate-500 mt-0.5">
                        Verify the complete ChainDock evidence ledger
                      </p>
                    </div>

                  </div>

                  <button
                    onClick={runVerification}
                    disabled={verifying}
                    className="px-4 py-2 bg-[#0B1F3A] hover:bg-[#07172B] disabled:opacity-50 text-white rounded-lg text-xs font-bold flex items-center justify-center gap-2"
                  >
                    <span
                      className={`material-symbols-outlined text-[16px] ${
                        verifying ? 'animate-spin' : ''
                      }`}
                    >
                      {verifying
                        ? 'hourglass_top'
                        : 'verified_user'}
                    </span>

                    {verifying
                      ? 'Verifying...'
                      : 'Run Full Verification'}
                  </button>

                </div>

              </div>

              <div className="p-5">

                {chainVerify ? (
                  <div
                    className={`p-4 rounded-xl border flex items-start gap-3 ${
                      chainVerify.valid
                        ? 'bg-emerald-50 border-emerald-200'
                        : 'bg-red-50 border-red-200'
                    }`}
                  >

                    <div
                      className={`w-10 h-10 rounded-lg flex items-center justify-center shrink-0 ${
                        chainVerify.valid
                          ? 'bg-emerald-100'
                          : 'bg-red-100'
                      }`}
                    >
                      <span
                        className={`material-symbols-outlined ${
                          chainVerify.valid
                            ? 'text-emerald-700'
                            : 'text-red-700'
                        }`}
                      >
                        {chainVerify.valid
                          ? 'verified_user'
                          : 'gpp_bad'}
                      </span>
                    </div>

                    <div className="space-y-1">

                      <div
                        className={`text-sm font-bold ${
                          chainVerify.valid
                            ? 'text-emerald-800'
                            : 'text-red-800'
                        }`}
                      >
                        {chainVerify.valid
                          ? 'Chain Integrity Confirmed'
                          : 'TAMPER DETECTED'}
                      </div>

                      <div className="text-xs text-slate-600">
                        {chainVerify.total_blocks} blocks ·{' '}
                        {chainVerify.total_transactions} transactions
                        verified
                      </div>

                      {!chainVerify.valid &&
                        chainVerify.tamper_reason && (
                          <div className="text-xs font-mono text-red-700 mt-2">
                            {chainVerify.tamper_reason}
                          </div>
                        )}

                      <div className="text-[10px] text-slate-400">
                        Verified at{' '}
                        {new Date(
                          chainVerify.verified_at
                        ).toLocaleString()}
                      </div>

                    </div>

                  </div>
                ) : (
                  <div className="p-5 bg-slate-50 rounded-xl border border-slate-200">

                    <div className="flex items-center gap-3">

                      <span className="material-symbols-outlined text-slate-400">
                        info
                      </span>

                      <p className="text-xs text-slate-500">
                        Run full verification to cryptographically verify
                        every block and transaction in the ChainDock ledger.
                      </p>

                    </div>

                  </div>
                )}

              </div>

            </section>

            {/* =================================================
                AUTHENTICATION SECURITY
            ================================================== */}
            <section className="bg-white border border-slate-200 rounded-xl shadow-sm overflow-hidden">

              <div className="px-5 py-4 border-b border-slate-200 bg-slate-50/70">

                <div className="flex items-center gap-2">

                  <span className="material-symbols-outlined text-blue-700">
                    login
                  </span>

                  <div>
                    <h2 className="text-sm font-bold text-[#0B1F3A]">
                      Authentication Security
                    </h2>

                    <p className="text-[10px] text-slate-500">
                      Sessions, login activity and account protection
                    </p>
                  </div>

                </div>

              </div>

              <div className="p-5 grid grid-cols-2 md:grid-cols-3 xl:grid-cols-6 gap-4">

                <StatTile
                  label="Active Sessions"
                  value={stats.authentication.active_sessions}
                  icon="devices"
                />

                <StatTile
                  label="Revoked Tokens"
                  value={stats.authentication.revoked_tokens}
                  icon="block"
                  color="text-amber-700"
                />

                <StatTile
                  label="Login Attempts"
                  value={stats.authentication.total_login_attempts_24h}
                  icon="login"
                />

                <StatTile
                  label="Failed Logins"
                  value={stats.authentication.failed_login_attempts_24h}
                  icon="no_accounts"
                  color="text-red-700"
                />

                <StatTile
                  label="Successful Logins"
                  value={
                    stats.authentication
                      .successful_login_attempts_24h
                  }
                  icon="verified_user"
                  color="text-emerald-700"
                />

                <StatTile
                  label="Locked Accounts"
                  value={stats.authentication.accounts_locked}
                  icon="lock_person"
                  color={
                    stats.authentication.accounts_locked > 0
                      ? 'text-red-700'
                      : 'text-emerald-700'
                  }
                  note="5+ failures / 15m"
                />

              </div>

            </section>

            {/* =================================================
                ACCESS CONTROL
            ================================================== */}
            <section className="bg-white border border-slate-200 rounded-xl shadow-sm overflow-hidden">

              <div className="px-5 py-4 border-b border-slate-200 bg-slate-50/70">

                <div className="flex items-center gap-2">

                  <span className="material-symbols-outlined text-indigo-700">
                    admin_panel_settings
                  </span>

                  <div>
                    <h2 className="text-sm font-bold text-[#0B1F3A]">
                      Officer Access Control
                    </h2>

                    <p className="text-[10px] text-slate-500">
                      Role distribution and denied access events
                    </p>
                  </div>

                </div>

              </div>

              <div className="p-5 grid grid-cols-2 md:grid-cols-3 xl:grid-cols-5 gap-4">

                <StatTile
                  label="Total Users"
                  value={stats.access_control.total_users}
                  icon="group"
                />

                <StatTile
                  label="Investigators"
                  value={stats.access_control.investigators}
                  icon="person_search"
                  color="text-blue-700"
                />

                <StatTile
                  label="Supervisors"
                  value={stats.access_control.supervisors}
                  icon="supervisor_account"
                  color="text-indigo-700"
                />

                <StatTile
                  label="Administrators"
                  value={stats.access_control.admins}
                  icon="admin_panel_settings"
                  color="text-violet-700"
                />

                <StatTile
                  label="Denied Access"
                  value={
                    stats.access_control.denied_access_events_24h
                  }
                  icon="do_not_disturb_on"
                  color={
                    stats.access_control
                      .denied_access_events_24h > 0
                      ? 'text-red-700'
                      : 'text-emerald-700'
                  }
                  note="Last 24 hours"
                />

              </div>

            </section>

            {/* =================================================
                DIGITAL SIGNATURES
            ================================================== */}
            <section className="bg-white border border-slate-200 rounded-xl shadow-sm overflow-hidden">

              <div className="px-5 py-4 border-b border-slate-200 bg-slate-50/70">

                <div className="flex items-center gap-2">

                  <span className="material-symbols-outlined text-emerald-700">
                    draw
                  </span>

                  <div>
                    <h2 className="text-sm font-bold text-[#0B1F3A]">
                      Digital Signatures
                    </h2>

                    <p className="text-[10px] text-slate-500">
                      Document signing and officer cryptographic keys
                    </p>
                  </div>

                </div>

              </div>

              <div className="p-5 grid grid-cols-2 md:grid-cols-4 gap-4">

                <StatTile
                  label="Signed Documents"
                  value={stats.signatures.signed_documents}
                  icon="draw"
                  color="text-emerald-700"
                />

                <StatTile
                  label="Unsigned Documents"
                  value={stats.signatures.unsigned_documents}
                  icon="edit_off"
                  color="text-amber-700"
                />

                <StatTile
                  label="Total Signatures"
                  value={stats.signatures.total_signatures}
                  icon="verified"
                  color="text-blue-700"
                />

                <StatTile
                  label="Users With Keys"
                  value={stats.signatures.users_with_keys}
                  icon="vpn_key"
                  color="text-emerald-700"
                />

              </div>

            </section>

            {/* =================================================
                EVIDENCE SECURITY
            ================================================== */}
            <section className="bg-white border border-slate-200 rounded-xl shadow-sm overflow-hidden">

              <div className="px-5 py-4 border-b border-slate-200 bg-slate-50/70">

                <div className="flex items-center gap-2">

                  <span className="material-symbols-outlined text-amber-700">
                    inventory_2
                  </span>

                  <div>
                    <h2 className="text-sm font-bold text-[#0B1F3A]">
                      Evidence &amp; Chain of Custody
                    </h2>

                    <p className="text-[10px] text-slate-500">
                      Evidence inventory and custody activity
                    </p>
                  </div>

                </div>

              </div>

              <div className="p-5 grid grid-cols-2 gap-4">

                <StatTile
                  label="Evidence Items"
                  value={stats.crypto_integrity.evidence_items}
                  icon="inventory_2"
                  color="text-[#0B1F3A]"
                />

                <StatTile
                  label="Custody Events"
                  value={stats.crypto_integrity.custody_events}
                  icon="swap_horiz"
                  color="text-emerald-700"
                />

              </div>

            </section>

            {/* =================================================
                DEVELOPMENT KEY NOTICE
            ================================================== */}
            <div className="bg-amber-50 border border-amber-200 rounded-xl p-5">

              <div className="flex items-start gap-3">

                <div className="w-9 h-9 rounded-lg bg-amber-100 flex items-center justify-center shrink-0">
                  <span className="material-symbols-outlined text-amber-700">
                    warning
                  </span>
                </div>

                <div className="space-y-2">

                  <h3 className="text-sm font-bold text-amber-900">
                    Development Security Notice
                  </h3>

                  <p className="text-xs text-amber-800 leading-relaxed">
                    Ed25519 private keys are currently protected using
                    encrypted database storage with AES-256-GCM and
                    PBKDF2-SHA256 under the configured key-encryption
                    secret.
                  </p>

                  <p className="text-xs text-amber-800 leading-relaxed">
                    This deployment is labeled <strong>DEV MODE</strong>.
                    Production deployment should use appropriate HSM-based
                    key protection.
                  </p>

                  <p className="text-xs text-amber-800 leading-relaxed">
                    Ed25519 provides classical cryptographic security and
                    is not a post-quantum signature scheme. A future
                    post-quantum migration can be evaluated separately.
                  </p>

                </div>

              </div>

            </div>

            {/* =================================================
                FORENSIC / LEGAL NOTICE
            ================================================== */}
            <div className="bg-white border border-slate-200 rounded-xl p-5">

              <div className="flex items-start gap-3">

                <div className="w-9 h-9 rounded-lg bg-slate-100 flex items-center justify-center shrink-0">
                  <span className="material-symbols-outlined text-[#0B1F3A]">
                    gavel
                  </span>
                </div>

                <div>

                  <h3 className="text-sm font-bold text-[#0B1F3A]">
                    Legal / Forensic Notice
                  </h3>

                  <p className="text-xs text-slate-500 leading-relaxed mt-2">
                    ChainDock provides cryptographic integrity evidence and
                    auditability supporting forensic verification. The
                    software does not automatically guarantee court
                    admissibility. Admissibility is determined by competent
                    courts under applicable law, including the Bharatiya
                    Sakshya Adhiniyam 2023 and related provisions.
                  </p>

                </div>

              </div>

            </div>

            {/* Generated time */}
            <p className="text-[10px] text-slate-400 text-right">
              Security statistics generated at{' '}
              {new Date(stats.generated_at).toLocaleString()}
            </p>

          </>
        )}

        {/* =====================================================
            CHAINDOCK SECURITY FOOTER
        ====================================================== */}
        {!loading && (
          <div className="bg-[#0B1F3A] rounded-xl p-5 text-white">

            <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">

              <div className="flex items-center gap-3">

                <div className="w-9 h-9 rounded-lg bg-white/10 flex items-center justify-center">
                  <span className="material-symbols-outlined">
                    verified_user
                  </span>
                </div>

                <div>
                  <p className="text-xs font-bold">
                    ChainDock Security Layer
                  </p>

                  <p className="text-[10px] text-slate-300 mt-0.5">
                    Existing authentication, cryptographic integrity,
                    audit and ledger functionality remains active.
                  </p>
                </div>

              </div>

              <div className="flex flex-wrap items-center gap-4 text-[10px] text-slate-300 font-semibold">

                <span className="flex items-center gap-1.5">
                  <span className="material-symbols-outlined text-[14px]">
                    lock
                  </span>
                  Access Controlled
                </span>

                <span className="flex items-center gap-1.5">
                  <span className="material-symbols-outlined text-[14px]">
                    fingerprint
                  </span>
                  Cryptographic Integrity
                </span>

                <span className="flex items-center gap-1.5">
                  <span className="material-symbols-outlined text-[14px]">
                    account_tree
                  </span>
                  Blockchain Ledger
                </span>

              </div>

            </div>

          </div>
        )}

      </div>

      {/* =====================================================
          ROOT CA CERTIFICATE
      ====================================================== */}
      <CertificateViewer
        isOpen={isCertModalOpen}
        onClose={() => setIsCertModalOpen(false)}
      />
    </AppShell>
  );
};

export default Security;
