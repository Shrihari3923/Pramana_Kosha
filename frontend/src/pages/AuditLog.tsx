import React, { useState, useEffect } from 'react';
import { AppShell } from '../components/layout/AppShell';
import { auditService } from '../services/audit';
import { AuditEvent, AuditVerificationResult } from '../types';
import { BackendUnavailable } from '../components/common/BackendUnavailable';
import { ApiError } from '../services/api';

export const AuditLog: React.FC = () => {
  const [events, setEvents] = useState<AuditEvent[]>([]);
  const [filterQuery, setFilterQuery] = useState('');
  const [loading, setLoading] = useState(true);

  const [backendError, setBackendError] = useState<{
    status: number;
    endpoint: string;
    message: string;
  } | null>(null);

  const [isVerifying, setIsVerifying] = useState(false);

  const [verificationResult, setVerificationResult] =
    useState<AuditVerificationResult | null>(null);

  const fetchAuditLogs = async () => {
    try {
      setLoading(true);
      setBackendError(null);

      const logs = await auditService.getAuditEvents();
      setEvents(logs);
    } catch (err: unknown) {
      console.error('Failed to load audit logs:', err);

      if (err instanceof ApiError) {
        setBackendError({
          status: err.status,
          endpoint: err.endpoint,
          message: err.message,
        });
      } else {
        setBackendError({
          status: 0,
          endpoint: '/audit',
          message: (err as Error).message,
        });
      }
    } finally {
      setLoading(false);
    }
  };

  const handleVerifyChain = async () => {
    try {
      setIsVerifying(true);

      const result = await auditService.verifyAuditChain();
      setVerificationResult(result);
    } catch (err) {
      console.warn('Failed to verify audit chain:', err);
    } finally {
      setIsVerifying(false);
    }
  };

  useEffect(() => {
    fetchAuditLogs();
    handleVerifyChain();
  }, []);

  const handleInjectTamper = async () => {
    try {
      await auditService.injectTamperAtBlock150();
      await fetchAuditLogs();
      await handleVerifyChain();
    } catch (err) {
      console.warn('Tamper simulation failed:', err);
    }
  };

  const handleResetChain = async () => {
    try {
      await auditService.resetAuditChain();
      await fetchAuditLogs();
      await handleVerifyChain();
    } catch (err) {
      console.warn('Chain restoration failed:', err);
    }
  };

  const isChainTampered =
    verificationResult !== null && !verificationResult.valid;

  const filteredEvents = events.filter((event) => {
    if (!filterQuery.trim()) return true;

    const query = filterQuery.toLowerCase();

    return (
      event.action.toLowerCase().includes(query) ||
      event.actor.toLowerCase().includes(query) ||
      event.target_reference.toLowerCase().includes(query) ||
      event.entry_hash.toLowerCase().includes(query) ||
      event.block_number.toString().includes(query)
    );
  });

  const validEvents = events.filter(
    (event) => event.status !== 'TAMPERED'
  ).length;

  const tamperedEvents = events.filter(
    (event) => event.status === 'TAMPERED'
  ).length;

  return (
    <AppShell>
      <div className="flex flex-col gap-6 max-w-[1520px] mx-auto animate-fade-in">

        {/* ========================================================= */}
        {/* HEADER */}
        {/* ========================================================= */}

        <header className="flex flex-col lg:flex-row lg:items-center justify-between gap-5 pb-5 border-b border-slate-200">

          <div className="flex flex-col gap-2">

            <div className="flex flex-wrap items-center gap-2">

              <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md bg-blue-50 border border-blue-200 text-blue-800 text-[10px] font-bold uppercase tracking-wider">
                <span className="material-symbols-outlined text-[14px]">
                  policy
                </span>
                pramāṇa-kośa
              </span>

              <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md bg-slate-100 border border-slate-200 text-slate-600 text-[10px] font-mono font-semibold">
                ChainDock Security Layer
              </span>

            </div>

            <h1 className="text-2xl sm:text-3xl font-bold tracking-tight text-[#0B1F3A]">
              Audit Trail &amp; Evidence Provenance
            </h1>

            <p className="text-sm text-slate-500 max-w-3xl">
              Immutable activity record for FIRs, case files, digital
              evidence, officer actions, signatures, and chain-of-custody
              operations.
            </p>

          </div>

          <div className="flex flex-wrap items-center gap-2">

            <button
              onClick={fetchAuditLogs}
              disabled={loading}
              className="h-10 px-3.5 rounded-lg bg-white hover:bg-slate-50 text-slate-700 border border-slate-200 text-xs font-semibold transition-colors flex items-center gap-2 shadow-sm"
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
              onClick={handleVerifyChain}
              disabled={isVerifying}
              className="h-10 px-4 rounded-lg bg-[#0B1F3A] hover:bg-[#07172B] text-white text-xs font-semibold transition-colors flex items-center gap-2 shadow-sm disabled:opacity-60"
            >
              <span
                className={`material-symbols-outlined text-[18px] ${
                  isVerifying ? 'animate-spin' : ''
                }`}
              >
                verified_user
              </span>

              {isVerifying
                ? 'Verifying Chain...'
                : 'Verify Audit Chain'}
            </button>

          </div>

        </header>


        {/* ========================================================= */}
        {/* LOADING / BACKEND ERROR */}
        {/* ========================================================= */}

        {loading ? (

          <div className="p-16 text-center text-slate-500 text-sm">

            <div className="animate-spin w-9 h-9 border-2 border-[#0B1F3A] border-t-transparent rounded-full mx-auto mb-4" />

            Loading secure audit records...

          </div>

        ) : backendError ? (

          <BackendUnavailable
            moduleName="pramāṇa-kośa Audit Trail"
            endpoint={backendError.endpoint}
            status={backendError.status}
            errorMessage={backendError.message}
            onRetry={() => {
              fetchAuditLogs();
              handleVerifyChain();
            }}
          />

        ) : (

          <>

            {/* ===================================================== */}
            {/* INTEGRITY STATUS */}
            {/* ===================================================== */}

            <section
              className={`rounded-2xl border shadow-sm overflow-hidden ${
                isChainTampered
                  ? 'bg-red-50 border-red-300'
                  : 'bg-white border-slate-200'
              }`}
            >

              <div
                className={`p-5 sm:p-6 flex flex-col lg:flex-row lg:items-center justify-between gap-5 ${
                  isChainTampered
                    ? 'bg-red-50'
                    : 'bg-gradient-to-r from-[#0B1F3A] to-[#173A63] text-white'
                }`}
              >

                <div className="flex items-center gap-4">

                  <div
                    className={`w-12 h-12 rounded-xl flex items-center justify-center shrink-0 ${
                      isChainTampered
                        ? 'bg-red-100 text-red-700 border border-red-200'
                        : 'bg-white/10 text-emerald-300 border border-white/15'
                    }`}
                  >
                    <span className="material-symbols-outlined text-[28px]">
                      {isChainTampered ? 'gpp_bad' : 'verified'}
                    </span>
                  </div>

                  <div>

                    <div
                      className={`text-[10px] uppercase tracking-widest font-bold ${
                        isChainTampered
                          ? 'text-red-700'
                          : 'text-blue-200'
                      }`}
                    >
                      ChainDock Integrity Monitor
                    </div>

                    <h2
                      className={`text-lg sm:text-xl font-bold mt-1 ${
                        isChainTampered
                          ? 'text-red-900'
                          : 'text-white'
                      }`}
                    >
                      {isChainTampered
                        ? 'Integrity Breach Detected'
                        : events.length === 0
                        ? 'Audit Ledger Ready'
                        : 'Audit Chain Verified'}
                    </h2>

                    <p
                      className={`text-xs mt-1 ${
                        isChainTampered
                          ? 'text-red-700'
                          : 'text-blue-100'
                      }`}
                    >
                      {isChainTampered
                        ? 'One or more cryptographic commitments require investigation.'
                        : events.length === 0
                        ? 'No audit records have been committed yet.'
                        : 'Cryptographic relationships between recorded audit events are valid.'}
                    </p>

                  </div>

                </div>


                <div
                  className={`px-4 py-3 rounded-xl border font-mono text-[11px] ${
                    isChainTampered
                      ? 'bg-white border-red-200 text-red-800'
                      : 'bg-white/10 border-white/15 text-blue-100'
                  }`}
                >

                  <div className="text-[9px] uppercase tracking-wider opacity-70 mb-1">
                    Verification Primitive
                  </div>

                  SHA-256 Hash Chain

                </div>

              </div>


              {/* Metrics */}

              <div className="grid grid-cols-2 lg:grid-cols-4 divide-x divide-y lg:divide-y-0 divide-slate-200">

                <Metric
                  label="Audit Entries"
                  value={events.length}
                  icon="receipt_long"
                />

                <Metric
                  label="Valid Entries"
                  value={validEvents}
                  icon="verified"
                  valueClass="text-emerald-700"
                />

                <Metric
                  label="Tampered Entries"
                  value={tamperedEvents}
                  icon="gpp_bad"
                  valueClass={
                    tamperedEvents > 0
                      ? 'text-red-700'
                      : 'text-slate-800'
                  }
                />

                <Metric
                  label="Verified Blocks"
                  value={
                    verificationResult
                      ? `${verificationResult.checked_entries}/${verificationResult.total_entries}`
                      : '—'
                  }
                  icon="account_tree"
                />

              </div>

            </section>


            {/* ===================================================== */}
            {/* VERIFICATION RESULT */}
            {/* ===================================================== */}

            {verificationResult && (

              <section
                className={`rounded-xl border p-4 ${
                  verificationResult.valid
                    ? 'bg-emerald-50 border-emerald-200'
                    : 'bg-red-50 border-red-300'
                }`}
              >

                <div className="flex items-start gap-3">

                  <span
                    className={`material-symbols-outlined text-[22px] ${
                      verificationResult.valid
                        ? 'text-emerald-700'
                        : 'text-red-700'
                    }`}
                  >
                    {verificationResult.valid
                      ? 'verified'
                      : 'warning'}
                  </span>

                  <div className="flex flex-col gap-1">

                    <span
                      className={`text-sm font-bold ${
                        verificationResult.valid
                          ? 'text-emerald-900'
                          : 'text-red-900'
                      }`}
                    >
                      {verificationResult.valid
                        ? 'Cryptographic verification passed'
                        : 'Cryptographic verification failed'}
                    </span>

                    <span className="text-xs text-slate-600">
                      Checked{' '}
                      {verificationResult.checked_entries}{' '}
                      of{' '}
                      {verificationResult.total_entries}{' '}
                      audit entries.

                      {verificationResult.latency_ms !== undefined &&
                        ` Verification completed in ${verificationResult.latency_ms} ms.`}
                    </span>

                    {!verificationResult.valid && (
                      <span className="text-xs font-mono text-red-800 mt-1">
                        Chain integrity violation detected. Review the audit
                        records and verify the ledger again.
                      </span>
                    )}

                  </div>

                </div>

              </section>

            )}


            {/* ===================================================== */}
            {/* CHAIN CONTROLS */}
            {/* ===================================================== */}

            <section className="bg-white border border-slate-200 rounded-xl p-4 shadow-sm">

              <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">

                <div>

                  <h3 className="text-sm font-bold text-[#0B1F3A]">
                    Chain Integrity Controls
                  </h3>

                  <p className="text-xs text-slate-500 mt-1">
                    Administrative tools for testing and restoring the
                    ChainDock audit chain.
                  </p>

                </div>

                <div className="flex flex-wrap gap-2">

                  <button
                    onClick={handleInjectTamper}
                    className="h-9 px-3 rounded-lg bg-red-50 hover:bg-red-100 border border-red-200 text-red-800 text-xs font-semibold flex items-center gap-2 transition-colors"
                  >
                    <span className="material-symbols-outlined text-[17px]">
                      bug_report
                    </span>

                    Simulate Tamper
                  </button>

                  {isChainTampered && (
                    <button
                      onClick={handleResetChain}
                      className="h-9 px-3 rounded-lg bg-[#0B1F3A] hover:bg-[#07172B] text-white text-xs font-semibold flex items-center gap-2 transition-colors"
                    >
                      <span className="material-symbols-outlined text-[17px]">
                        restart_alt
                      </span>

                      Restore Chain
                    </button>
                  )}

                </div>

              </div>

            </section>


            {/* ===================================================== */}
            {/* CHAIN SEQUENCE */}
            {/* ===================================================== */}

            <section>

              <div className="flex items-center justify-between mb-3">

                <div>

                  <h2 className="text-sm font-bold text-[#0B1F3A]">
                    Cryptographic Chain Sequence
                  </h2>

                  <p className="text-xs text-slate-500 mt-0.5">
                    Latest committed audit events
                  </p>

                </div>

                <span className="hidden sm:flex items-center gap-1.5 text-[10px] font-mono text-slate-500 uppercase">
                  <span className="w-2 h-2 rounded-full bg-emerald-500" />
                  Append-only ledger
                </span>

              </div>


              {events.length === 0 ? (

                <div className="bg-white border border-dashed border-slate-300 rounded-xl p-10 text-center">

                  <span className="material-symbols-outlined text-[32px] text-slate-300">
                    account_tree
                  </span>

                  <p className="text-sm font-medium text-slate-600 mt-2">
                    No audit chain entries available
                  </p>

                  <p className="text-xs text-slate-400 mt-1">
                    Audit events will appear here after system activity.
                  </p>

                </div>

              ) : (

                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">

                  {events.slice(0, 4).map((event, index) => (

                    <div
                      key={event.id}
                      className={`bg-white rounded-xl border shadow-sm p-4 ${
                        event.status === 'TAMPERED'
                          ? 'border-red-300 bg-red-50/40'
                          : index === 0
                          ? 'border-blue-300 ring-1 ring-blue-100'
                          : 'border-slate-200'
                      }`}
                    >

                      <div className="flex items-center justify-between gap-2 pb-3 border-b border-slate-100">

                        <span className="font-mono text-[11px] font-bold text-[#0B1F3A]">
                          BLOCK #{event.block_number}
                        </span>

                        {index === 0 && (
                          <span className="px-1.5 py-0.5 rounded bg-blue-50 border border-blue-200 text-blue-700 text-[9px] font-bold">
                            TIP
                          </span>
                        )}

                      </div>


                      <div className="mt-3">

                        <div className="text-[10px] uppercase tracking-wider font-bold text-blue-700">
                          {event.action}
                        </div>

                        <div className="text-sm font-semibold text-slate-800 mt-1 truncate">
                          {event.target_reference}
                        </div>

                        <div className="text-[11px] text-slate-500 mt-1">
                          Officer: {event.actor}
                        </div>

                        <div className="text-[10px] text-slate-400 mt-1">
                          Role: {event.role}
                        </div>

                      </div>


                      <div className="mt-4 pt-3 border-t border-slate-100 space-y-2">

                        <div className="flex items-center justify-between">

                          <span className="text-[9px] uppercase text-slate-400">
                            Status
                          </span>

                          <span
                            className={`px-1.5 py-0.5 rounded border text-[9px] font-bold ${
                              event.status === 'TAMPERED'
                                ? 'bg-red-100 border-red-300 text-red-800'
                                : 'bg-emerald-50 border-emerald-200 text-emerald-700'
                            }`}
                          >
                            {event.status === 'TAMPERED'
                              ? 'TAMPERED'
                              : 'VALID'}
                          </span>

                        </div>


                        <div>

                          <div className="text-[9px] uppercase text-slate-400">
                            Previous Hash
                          </div>

                          <div className="font-mono text-[10px] text-slate-600 truncate">
                            {event.prev_hash}
                          </div>

                        </div>


                        <div>

                          <div className="text-[9px] uppercase text-slate-400">
                            Entry Hash
                          </div>

                          <div className="font-mono text-[10px] text-[#0B1F3A] font-semibold truncate">
                            {event.entry_hash}
                          </div>

                        </div>

                      </div>

                    </div>

                  ))}

                </div>

              )}

            </section>


            {/* ===================================================== */}
            {/* MAIN LEDGER + SECURITY */}
            {/* ===================================================== */}

            <div className="grid grid-cols-1 xl:grid-cols-12 gap-6">

              {/* LEDGER */}

              <section className="xl:col-span-8 flex flex-col gap-3">

                <div className="flex flex-col sm:flex-row sm:items-end justify-between gap-3">

                  <div>

                    <h2 className="text-sm font-bold text-[#0B1F3A]">
                      Complete Police Audit Ledger
                    </h2>

                    <p className="text-xs text-slate-500 mt-1">
                      Searchable record of officer and system activity.
                    </p>

                  </div>

                  <div className="relative w-full sm:w-72">

                    <span className="material-symbols-outlined absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 text-[18px]">
                      search
                    </span>

                    <input
                      type="text"
                      value={filterQuery}
                      onChange={(e) => setFilterQuery(e.target.value)}
                      placeholder="Search block, officer, action, hash..."
                      className="w-full h-10 pl-9 pr-3 bg-white border border-slate-200 rounded-lg text-xs text-slate-800 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-blue-100 focus:border-blue-300"
                    />

                  </div>

                </div>


                <div className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">

                  <div className="overflow-x-auto">

                    <table className="w-full text-xs">

                      <thead className="bg-[#0B1F3A] text-white">

                        <tr>

                          <th className="py-3 px-4 text-left font-semibold">
                            Block
                          </th>

                          <th className="py-3 px-4 text-left font-semibold">
                            Timestamp
                          </th>

                          <th className="py-3 px-4 text-left font-semibold">
                            Officer
                          </th>

                          <th className="py-3 px-4 text-left font-semibold">
                            Action
                          </th>

                          <th className="py-3 px-4 text-left font-semibold">
                            Reference
                          </th>

                          <th className="py-3 px-4 text-left font-semibold">
                            Hash
                          </th>

                          <th className="py-3 px-4 text-right font-semibold">
                            Status
                          </th>

                        </tr>

                      </thead>


                      <tbody className="divide-y divide-slate-100">

                        {filteredEvents.length === 0 ? (

                          <tr>

                            <td
                              colSpan={7}
                              className="py-12 text-center text-slate-500"
                            >
                              {events.length === 0
                                ? 'No audit records found.'
                                : 'No records match the current search.'}
                            </td>

                          </tr>

                        ) : (

                          filteredEvents.map((event) => (

                            <tr
                              key={event.id}
                              className={`hover:bg-slate-50 transition-colors ${
                                event.status === 'TAMPERED'
                                  ? 'bg-red-50/70'
                                  : ''
                              }`}
                            >

                              <td className="py-3 px-4 font-mono font-bold text-[#0B1F3A]">
                                #{event.block_number}
                              </td>

                              <td className="py-3 px-4 font-mono text-[10px] text-slate-500 whitespace-nowrap">
                                {event.timestamp
                                  .replace('T', ' ')
                                  .slice(0, 19)}
                              </td>

                              <td className="py-3 px-4 font-medium text-slate-800">
                                {event.actor}
                              </td>

                              <td className="py-3 px-4">

                                <span className="inline-flex px-2 py-1 rounded-md bg-blue-50 border border-blue-200 text-blue-800 text-[9px] font-bold font-mono">
                                  {event.action}
                                </span>

                              </td>

                              <td className="py-3 px-4 max-w-[220px] truncate text-slate-600">
                                {event.target_reference}
                              </td>

                              <td className="py-3 px-4 font-mono text-[10px] text-slate-500">
                                {event.entry_hash.slice(0, 14)}...
                              </td>

                              <td className="py-3 px-4 text-right">

                                <span
                                  className={`inline-flex items-center gap-1 px-2 py-1 rounded-full text-[9px] font-bold ${
                                    event.status === 'TAMPERED'
                                      ? 'bg-red-100 text-red-800 border border-red-200'
                                      : 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                                  }`}
                                >

                                  <span className="material-symbols-outlined text-[12px]">
                                    {event.status === 'TAMPERED'
                                      ? 'close'
                                      : 'check'}
                                  </span>

                                  {event.status === 'TAMPERED'
                                    ? 'TAMPERED'
                                    : 'VALID'}

                                </span>

                              </td>

                            </tr>

                          ))

                        )}

                      </tbody>

                    </table>

                  </div>

                </div>

              </section>


              {/* =================================================== */}
              {/* SECURITY / GOVERNANCE */}
              {/* =================================================== */}

              <aside className="xl:col-span-4 flex flex-col gap-4">

                <div className="rounded-xl bg-[#0B1F3A] text-white p-5 shadow-sm">

                  <div className="flex items-center justify-between">

                    <div>

                      <div className="text-[10px] uppercase tracking-wider font-bold text-blue-200">
                        ChainDock Security
                      </div>

                      <h3 className="text-base font-bold mt-1">
                        Evidence Integrity
                      </h3>

                    </div>

                    <span className="material-symbols-outlined text-emerald-300">
                      shield
                    </span>

                  </div>


                  <div className="mt-5 space-y-3">

                    <SecurityRow
                      label="Hash-chain verification"
                      value={
                        verificationResult
                          ? verificationResult.valid
                            ? 'PASS'
                            : 'FAIL'
                          : 'PENDING'
                      }
                      ok={
                        verificationResult
                          ? verificationResult.valid
                          : false
                      }
                    />

                    <SecurityRow
                      label="Audit storage"
                      value="POSTGRESQL"
                      ok
                    />

                    <SecurityRow
                      label="Ledger mode"
                      value="APPEND-ONLY"
                      ok
                    />

                    <SecurityRow
                      label="Evidence provenance"
                      value="TRACKED"
                      ok
                    />

                  </div>

                </div>


                <div className="rounded-xl bg-white border border-slate-200 p-5 shadow-sm">

                  <div className="flex items-center gap-3 mb-4">

                    <div className="w-9 h-9 rounded-lg bg-blue-50 border border-blue-100 text-blue-700 flex items-center justify-center">

                      <span className="material-symbols-outlined text-[20px]">
                        gavel
                      </span>

                    </div>

                    <div>

                      <h3 className="text-xs font-bold uppercase tracking-wider text-[#0B1F3A]">
                        Evidence Governance
                      </h3>

                      <p className="text-[10px] text-slate-500">
                        Digital investigation controls
                      </p>

                    </div>

                  </div>


                  <div className="space-y-3">

                    <ComplianceItem
                      title="Audit provenance"
                      description="Officer actions remain associated with the recorded audit event."
                    />

                    <ComplianceItem
                      title="Evidence traceability"
                      description="Evidence operations can be correlated with their chain-of-custody records."
                    />

                    <ComplianceItem
                      title="Integrity verification"
                      description="Cryptographic hashes provide a mechanism for detecting modifications to the recorded chain."
                    />

                  </div>

                </div>


                <div className="rounded-xl border border-slate-200 bg-slate-50 p-4">

                  <div className="flex items-start gap-3">

                    <span className="material-symbols-outlined text-blue-700 text-[20px]">
                      info
                    </span>

                    <div>

                      <div className="text-xs font-bold text-[#0B1F3A]">
                        Administrative Testing
                      </div>

                      <p className="text-[10px] text-slate-500 leading-relaxed mt-1">
                        The tamper simulation and restore controls are
                        intended for authorized testing of ChainDock
                        integrity monitoring.
                      </p>

                    </div>

                  </div>

                </div>

              </aside>

            </div>

          </>

        )}

      </div>
    </AppShell>
  );
};


/* =============================================================== */
/* SMALL UI COMPONENTS                                             */
/* =============================================================== */

interface MetricProps {
  label: string;
  value: string | number;
  icon: string;
  valueClass?: string;
}

const Metric: React.FC<MetricProps> = ({
  label,
  value,
  icon,
  valueClass = 'text-[#0B1F3A]',
}) => {
  return (
    <div className="p-4 sm:p-5">

      <div className="flex items-center gap-2">

        <span className="material-symbols-outlined text-[19px] text-slate-400">
          {icon}
        </span>

        <span className="text-[10px] uppercase tracking-wider font-semibold text-slate-500">
          {label}
        </span>

      </div>

      <div
        className={`text-xl sm:text-2xl font-bold font-mono mt-2 ${valueClass}`}
      >
        {value}
      </div>

    </div>
  );
};


interface SecurityRowProps {
  label: string;
  value: string;
  ok: boolean;
}

const SecurityRow: React.FC<SecurityRowProps> = ({
  label,
  value,
  ok,
}) => {
  return (
    <div className="flex items-center justify-between gap-3 py-2 border-b border-white/10 last:border-0">

      <span className="text-[10px] text-blue-100">
        {label}
      </span>

      <span
        className={`text-[9px] font-bold font-mono ${
          ok ? 'text-emerald-300' : 'text-amber-300'
        }`}
      >
        {ok ? '✓ ' : ''}
        {value}
      </span>

    </div>
  );
};


interface ComplianceItemProps {
  title: string;
  description: string;
}

const ComplianceItem: React.FC<ComplianceItemProps> = ({
  title,
  description,
}) => {
  return (
    <div className="flex gap-2.5">

      <span className="material-symbols-outlined text-[17px] text-emerald-600 shrink-0">
        verified
      </span>

      <div>

        <div className="text-xs font-semibold text-slate-800">
          {title}
        </div>

        <p className="text-[10px] text-slate-500 leading-relaxed mt-0.5">
          {description}
        </p>

      </div>

    </div>
  );
};
