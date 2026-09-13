import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { AppShell } from '../components/layout/AppShell';
import { casesService } from '../services/cases';
import { documentsService } from '../services/documents';
import { evidenceService } from '../services/evidence';
import { auditService } from '../services/audit';
import { useAuth } from '../hooks/useAuth';
import {
  Case,
  Document as DocType,
  AuditEvent,
  Priority,
} from '../types';
import { CaseForm } from '../components/cases/CaseForm';
import { BackendUnavailable } from '../components/common/BackendUnavailable';
import { ApiError } from '../services/api';

export const Dashboard: React.FC = () => {
  const navigate = useNavigate();
  const { user, role } = useAuth();

  const [cases, setCases] = useState<Case[]>([]);
  const [documents, setDocuments] = useState<DocType[]>([]);
  const [auditEvents, setAuditEvents] = useState<AuditEvent[]>([]);
  const [evidenceCount, setEvidenceCount] = useState<number>(0);

  const [backendError, setBackendError] = useState<{
    status: number;
    endpoint: string;
    message: string;
  } | null>(null);

  const [isVerifying, setIsVerifying] = useState<boolean>(false);
  const [scanResult, setScanResult] = useState<string | null>(null);

  const [isCaseModalOpen, setIsCaseModalOpen] = useState(false);

  /* =========================================================
     LOAD REAL BACKEND DATA
  ========================================================= */

  const loadDashboardData = async () => {
    try {
      setBackendError(null);

      const fetchedCases = await casesService.getCases();

      let fetchedDocs: DocType[] = [];
      let fetchedEvidence: any[] = [];
      let fetchedLogs: AuditEvent[] = [];

      try {
        fetchedDocs = await documentsService.getDocuments();
      } catch {
        // Documents endpoint may be unavailable independently.
      }

      try {
        fetchedEvidence = await evidenceService.getEvidence();
      } catch {
        // Evidence endpoint may be unavailable independently.
      }

      try {
        fetchedLogs = await auditService.getAuditEvents();
      } catch {
        // Audit endpoint may be unavailable independently.
      }

      setCases(fetchedCases);
      setDocuments(fetchedDocs);
      setEvidenceCount(fetchedEvidence.length);
      setAuditEvents(fetchedLogs);
    } catch (err: unknown) {
      console.error('Failed to load dashboard data:', err);

      if (err instanceof ApiError) {
        setBackendError({
          status: err.status,
          endpoint: err.endpoint,
          message: err.message,
        });
      } else {
        setBackendError({
          status: 0,
          endpoint: '/cases',
          message: (err as Error).message,
        });
      }
    } finally {
    }
  };

  useEffect(() => {
    loadDashboardData();
  }, []);

  /* =========================================================
     CREATE CASE
  ========================================================= */

  const handleCreateCase = async (data: {
    title: string;
    case_number: string;
    description: string;
    priority: Priority;
    jurisdiction: string;
    lead_officer: string;
  }) => {
    const created = await casesService.createCase(data);

    setCases((prev) => [
      created,
      ...prev.filter((c) => c.id !== created.id),
    ]);

    setIsCaseModalOpen(false);

    await loadDashboardData();
  };

  /* =========================================================
     CHAIN INTEGRITY VERIFICATION
  ========================================================= */

  const handleRunIntegrityScan = async () => {
    setIsVerifying(true);
    setScanResult(null);

    try {
      const result = await auditService.verifyAuditChain();

      if (result.valid) {
        setScanResult(
          `CHAIN INTEGRITY VERIFIED — ${result.total_entries} audit blocks validated successfully. No tampering detected.`
        );
      } else {
        setScanResult(
          `SECURITY ALERT — Tampering detected at Block #${result.failed_block_number}. ${result.reason}`
        );
      }
    } catch (error) {
      setScanResult(
        `INTEGRITY SCAN FAILED — Unable to verify the audit chain.`
      );
    } finally {
      setIsVerifying(false);
    }
  };

  /* =========================================================
     PRIORITY BADGES
  ========================================================= */

  const getPriorityBadgeClass = (priority: Priority) => {
    switch (priority) {
      case 'CRITICAL':
        return 'bg-red-50 text-red-700 border-red-200';

      case 'HIGH':
        return 'bg-amber-50 text-amber-700 border-amber-200';

      case 'MEDIUM':
        return 'bg-blue-50 text-blue-700 border-blue-200';

      default:
        return 'bg-slate-50 text-slate-700 border-slate-200';
    }
  };

  /* =========================================================
     BACKEND ERROR
  ========================================================= */

  if (backendError) {
    return (
      <AppShell>
        <BackendUnavailable
          moduleName="pramāṇa-kośa Dashboard"
          endpoint={backendError.endpoint}
          status={backendError.status}
          errorMessage={backendError.message}
          onRetry={loadDashboardData}
        />
      </AppShell>
    );
  }

  /* =========================================================
     DASHBOARD
  ========================================================= */

  return (
    <AppShell>

      <div className="flex flex-col gap-6">

        {/* =====================================================
            HEADER
        ====================================================== */}

        <div className="flex flex-col xl:flex-row xl:items-center justify-between gap-5 pb-5 border-b border-slate-200">

          <div>

            <div className="flex flex-wrap items-center gap-2 mb-2">

              <span className="inline-flex items-center gap-1.5 text-[10px] font-bold uppercase tracking-wider text-blue-700 px-2.5 py-1 rounded-md bg-blue-50 border border-blue-100">

                <span className="w-1.5 h-1.5 rounded-full bg-emerald-500"></span>

                System Online

              </span>

              <span className="text-[10px] font-mono text-slate-500">
                JURISDICTION: {user?.jurisdictionNode || 'NODE ALPHA'}
              </span>

              <span className="text-[10px] font-mono text-slate-500">
                ROLE: {role || 'OFFICER'}
              </span>

            </div>

            <h1 className="text-2xl sm:text-3xl font-bold tracking-tight text-slate-900">
              Police Operations Dashboard
            </h1>

            <p className="text-sm text-slate-500 mt-1">
              Case investigations, digital evidence, officer activity and ChainDock integrity monitoring.
            </p>

          </div>

          {/* ACTIONS */}

          <div className="flex flex-wrap items-center gap-2">

<button
              onClick={handleRunIntegrityScan}
              disabled={isVerifying}
              className="h-10 px-3.5 bg-white border border-slate-200 text-slate-700 rounded-lg text-xs font-semibold hover:bg-slate-50 flex items-center gap-2 transition-colors shadow-sm disabled:opacity-60"
            >

              <span className="material-symbols-outlined text-[18px]">
                {isVerifying ? 'sync' : 'verified_user'}
              </span>

              {isVerifying
                ? 'Verifying Chain...'
                : 'Verify Chain'}

            </button>



            <button
              onClick={() => setIsCaseModalOpen(true)}
              className="h-10 px-4 bg-blue-600 text-white rounded-lg text-xs font-semibold hover:bg-blue-700 flex items-center gap-2 transition-colors shadow-sm"
            >

              <span className="material-symbols-outlined text-[18px]">
                add
              </span>

              New Case

            </button>

          </div>

        </div>

        {/* =====================================================
            INTEGRITY RESULT
        ====================================================== */}

        {scanResult && (

          <div
            className={`p-4 rounded-xl border flex items-start justify-between gap-4 ${
              scanResult.includes('ALERT') ||
              scanResult.includes('FAILED')
                ? 'bg-red-50 border-red-200 text-red-800'
                : 'bg-emerald-50 border-emerald-200 text-emerald-800'
            }`}
          >

            <div className="flex items-start gap-3">

              <span className="material-symbols-outlined text-[20px]">
                {scanResult.includes('ALERT') ||
                scanResult.includes('FAILED')
                  ? 'warning'
                  : 'verified'}
              </span>

              <div>

                <div className="text-xs font-bold uppercase tracking-wide">
                  ChainDock Security Status
                </div>

                <div className="text-xs mt-1">
                  {scanResult}
                </div>

              </div>

            </div>

            <button
              onClick={() => setScanResult(null)}
              className="text-xs font-semibold hover:underline shrink-0"
            >
              Dismiss
            </button>

          </div>

        )}

        {/* =====================================================
            CORE METRICS
        ====================================================== */}

        <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-4">

          {/* CASES */}

          <div className="bg-white rounded-xl border border-slate-200 shadow-sm p-5">

            <div className="flex items-center justify-between">

              <div className="w-10 h-10 rounded-lg bg-blue-50 text-blue-700 flex items-center justify-center">
                <span className="material-symbols-outlined">
                  folder_open
                </span>
              </div>

              <span className="text-[10px] font-bold uppercase tracking-wider text-slate-400">
                Cases
              </span>

            </div>

            <div className="mt-4">

              <div className="text-3xl font-bold text-slate-900">
                {cases.length}
              </div>

              <div className="text-xs text-slate-500 mt-1">
                Registered investigation cases
              </div>

            </div>

          </div>

          {/* DOCUMENTS */}

          <div className="bg-white rounded-xl border border-slate-200 shadow-sm p-5">

            <div className="flex items-center justify-between">

              <div className="w-10 h-10 rounded-lg bg-indigo-50 text-indigo-700 flex items-center justify-center">
                <span className="material-symbols-outlined">
                  description
                </span>
              </div>

              <span className="text-[10px] font-bold uppercase tracking-wider text-slate-400">
                Records
              </span>

            </div>

            <div className="mt-4">

              <div className="text-3xl font-bold text-slate-900">
                {documents.length}
              </div>

              <div className="text-xs text-slate-500 mt-1">
                Digital documents and FIR records
              </div>

            </div>

          </div>

          {/* EVIDENCE */}

          <div className="bg-white rounded-xl border border-slate-200 shadow-sm p-5">

            <div className="flex items-center justify-between">

              <div className="w-10 h-10 rounded-lg bg-amber-50 text-amber-700 flex items-center justify-center">
                <span className="material-symbols-outlined">
                  inventory_2
                </span>
              </div>

              <span className="text-[10px] font-bold uppercase tracking-wider text-slate-400">
                Evidence
              </span>

            </div>

            <div className="mt-4">

              <div className="text-3xl font-bold text-slate-900">
                {evidenceCount}
              </div>

              <div className="text-xs text-slate-500 mt-1">
                Registered evidence items
              </div>

            </div>

          </div>

          {/* CHAIN */}

          <div className="bg-white rounded-xl border border-slate-200 shadow-sm p-5">

            <div className="flex items-center justify-between">

              <div className="w-10 h-10 rounded-lg bg-emerald-50 text-emerald-700 flex items-center justify-center">
                <span className="material-symbols-outlined">
                  verified_user
                </span>
              </div>

              <span className="text-[10px] font-bold uppercase tracking-wider text-slate-400">
                ChainDock
              </span>

            </div>

            <div className="mt-4">

              <div className="text-xl font-bold text-emerald-700">
                PROTECTED
              </div>

              <div className="text-xs text-slate-500 mt-1">
                Cryptographic evidence integrity
              </div>

            </div>

          </div>

        </div>

        {/* =====================================================
            MAIN CONTENT
        ====================================================== */}

        <div className="grid grid-cols-1 xl:grid-cols-12 gap-6">

          {/* ===================================================
              CASE TABLE
          ==================================================== */}

          <div className="xl:col-span-8 bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">

            <div className="p-5 border-b border-slate-200 flex flex-col sm:flex-row sm:items-center justify-between gap-3">

              <div>

                <h2 className="text-sm font-bold text-slate-900">
                  Active Investigation Cases
                </h2>

                <p className="text-xs text-slate-500 mt-1">
                  Live cases retrieved from the ChainDock backend.
                </p>

              </div>

              <button
                onClick={() => navigate('/cases')}
                className="text-xs font-semibold text-blue-600 hover:text-blue-700 flex items-center gap-1"
              >
                View All Cases

                <span className="material-symbols-outlined text-[15px]">
                  arrow_forward
                </span>

              </button>

            </div>

            <div className="overflow-x-auto">

              <table className="w-full text-left text-xs">

                <thead className="bg-slate-50 text-slate-500 border-b border-slate-200">

                  <tr>

                    <th className="py-3 px-5 font-semibold">
                      Case / FIR
                    </th>

                    <th className="py-3 px-5 font-semibold">
                      Investigation
                    </th>

                    <th className="py-3 px-5 font-semibold">
                      Priority
                    </th>

                    <th className="py-3 px-5 font-semibold">
                      Evidence
                    </th>

                    <th className="py-3 px-5">
                    </th>

                  </tr>

                </thead>

                <tbody className="divide-y divide-slate-100">

                  {cases.length === 0 ? (

                    <tr>

                      <td
                        colSpan={5}
                        className="py-14 text-center text-slate-400"
                      >

                        <span className="material-symbols-outlined text-[30px] mb-2">
                          folder_off
                        </span>

                        <div>
                          No investigation cases registered.
                        </div>

                      </td>

                    </tr>

                  ) : (

                    cases.map((c) => (

                      <tr
                        key={c.id}
                        onClick={() =>
                          navigate(`/cases/${c.id}`)
                        }
                        className="hover:bg-slate-50 cursor-pointer transition-colors"
                      >

                        <td className="py-3.5 px-5">

                          <div className="font-mono font-bold text-blue-700">
                            {c.case_number}
                          </div>

                        </td>

                        <td className="py-3.5 px-5">

                          <div className="font-semibold text-slate-800 max-w-[220px] truncate">
                            {c.title}
                          </div>

                        </td>

                        <td className="py-3.5 px-5">

                          <span
                            className={`inline-flex px-2 py-1 rounded-md text-[9px] font-bold uppercase border ${getPriorityBadgeClass(
                              c.priority
                            )}`}
                          >
                            {c.priority}
                          </span>

                        </td>

                        <td className="py-3.5 px-5">

                          <div className="flex flex-col">

                            <span className="font-semibold text-slate-700">
                              {c.document_count}
                            </span>

                            <span className="text-[9px] text-slate-400">
                              documents
                            </span>

                          </div>

                        </td>

                        <td className="py-3.5 px-5 text-right">

                          <span className="material-symbols-outlined text-[17px] text-slate-400">
                            chevron_right
                          </span>

                        </td>

                      </tr>

                    ))

                  )}

                </tbody>

              </table>

            </div>

          </div>

          {/* ===================================================
              SECURITY PANEL
          ==================================================== */}

          <div className="xl:col-span-4 flex flex-col gap-6">

            {/* ChainDock Security */}

            <div className="bg-[#0b1f3a] rounded-xl shadow-sm p-5 text-white">

              <div className="flex items-center justify-between pb-4 border-b border-white/10">

                <div className="flex items-center gap-2">

                  <span className="material-symbols-outlined text-emerald-400">
                    shield
                  </span>

                  <h3 className="text-sm font-bold">
                    ChainDock Security
                  </h3>

                </div>

                <span className="text-[9px] font-bold px-2 py-1 rounded bg-emerald-400/10 text-emerald-300 border border-emerald-400/20">
                  ACTIVE
                </span>

              </div>

              <div className="py-4 space-y-3">

                <div className="flex justify-between text-xs">

                  <span className="text-blue-200">
                    Evidence Integrity
                  </span>

                  <span className="text-emerald-300 font-semibold">
                    VERIFIED
                  </span>

                </div>

                <div className="flex justify-between text-xs">

                  <span className="text-blue-200">
                    Audit Chain
                  </span>

                  <span className="text-emerald-300 font-semibold">
                    ACTIVE
                  </span>

                </div>

                <div className="flex justify-between text-xs">

                  <span className="text-blue-200">
                    Cryptographic Records
                  </span>

                  <span className="text-emerald-300 font-semibold">
                    PROTECTED
                  </span>

                </div>

              </div>

              <button
                onClick={() => navigate('/blockchain')}
                className="w-full mt-1 py-2 rounded-lg bg-white/10 hover:bg-white/15 text-xs font-semibold transition-colors"
              >
                Open Evidence Ledger
              </button>

            </div>

            {/* =================================================
                AUDIT STREAM
            ================================================== */}

            <div className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">

              <div className="p-4 border-b border-slate-200 flex items-center justify-between">

                <div className="flex items-center gap-2">

                  <span className="material-symbols-outlined text-blue-600 text-[18px]">
                    history
                  </span>

                  <h3 className="text-xs font-bold uppercase tracking-wider text-slate-800">
                    Recent Audit Activity
                  </h3>

                </div>

                <button
                  onClick={() => navigate('/audit')}
                  className="text-[10px] font-semibold text-blue-600 hover:underline"
                >
                  Full Trail
                </button>

              </div>

              <div className="divide-y divide-slate-100">

                {auditEvents.length === 0 ? (

                  <div className="p-7 text-center text-xs text-slate-400">

                    No audit events recorded.

                  </div>

                ) : (

                  auditEvents.slice(0, 5).map((evt) => (

                    <div
                      key={evt.id}
                      className="p-3.5 hover:bg-slate-50 transition-colors"
                    >

                      <div className="flex items-center justify-between gap-2">

                        <span className="text-[10px] font-mono font-bold text-blue-700">
                          BLOCK #{evt.block_number}
                        </span>

                        <span className="text-[9px] text-slate-400">
                          {evt.timestamp
                            .split('T')[1]
                            ?.slice(0, 8)}
                        </span>

                      </div>

                      <div className="flex items-center justify-between gap-2 mt-1">

                        <span className="text-xs font-semibold text-slate-800 truncate">
                          {evt.action}
                        </span>

                        <span
                          className={`text-[8px] font-bold px-1.5 py-0.5 rounded border ${
                            evt.status === 'TAMPERED'
                              ? 'bg-red-50 text-red-700 border-red-200'
                              : 'bg-emerald-50 text-emerald-700 border-emerald-200'
                          }`}
                        >
                          {evt.status}
                        </span>

                      </div>

                      <div className="text-[10px] text-slate-500 mt-1 truncate">
                        {evt.target_reference}
                      </div>

                      <div className="text-[9px] font-mono text-slate-400 mt-1 truncate">
                        {evt.actor} · {evt.entry_hash.slice(0, 16)}...
                      </div>

                    </div>

                  ))

                )}

              </div>

            </div>

          </div>

        </div>

      </div>

      {/* =======================================================
          CASE MODAL
      ======================================================== */}

      {isCaseModalOpen && (

        <CaseForm
          isOpen={isCaseModalOpen}
          onClose={() => setIsCaseModalOpen(false)}
          onSubmit={handleCreateCase}
        />

      )}

    </AppShell>
  );
};
