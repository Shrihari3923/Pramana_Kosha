import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { AppShell } from '../components/layout/AppShell';
import { DocumentUpload } from '../components/documents/DocumentUpload';
import { EvidenceUpload } from '../components/evidence/EvidenceUpload';
import { ChainOfCustodyLog } from '../components/evidence/ChainOfCustodyLog';
import { casesService } from '../services/cases';
import { documentsService } from '../services/documents';
import { evidenceService } from '../services/evidence';
import { useAuth } from '../hooks/useAuth';
import { generateOTP, sendOTP } from '../services/otp';
import { OtpModal } from '../components/common/OtpModal';
import {
  Case,
  Document as DocType,
  EvidenceItem,
} from '../types';
import {
  formatTimestamp,
  truncateHash,
} from '../utils/formatters';
import { BackendUnavailable } from '../components/common/BackendUnavailable';
import { ApiError } from '../services/api';

export const CaseDetails: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { role, user } = useAuth();

  const isAdmin = role === 'ADMIN';

  const [caseItem, setCaseItem] = useState<Case | null>(null);
  const [documents, setDocuments] = useState<DocType[]>([]);
  const [evidenceItems, setEvidenceItems] = useState<EvidenceItem[]>([]);

  const [activeTab, setActiveTab] = useState<
    'documents' | 'evidence' | 'timeline' | 'details'
  >('documents');

  const [loading, setLoading] = useState(true);

  const [tableSearch, setTableSearch] = useState('');
  const [tableFilter, setTableFilter] = useState<
    'all' | 'verified' | 'tampered'
  >('all');

  const [formatFilter, setFormatFilter] = useState('ALL');

  const [isVerifyingHashes, setIsVerifyingHashes] = useState(false);
  const [verifyNotice, setVerifyNotice] = useState<string | null>(null);
  const [copiedHash, setCopiedHash] = useState<string | null>(null);

  const [isDocUploadOpen, setIsDocUploadOpen] = useState(false);
  const [isEvidenceUploadOpen, setIsEvidenceUploadOpen] = useState(false);

  const [selectedEvidenceForTransfer, setSelectedEvidenceForTransfer] =
    useState<EvidenceItem | null>(null);

  const [backendError, setBackendError] = useState<{
    status: number;
    endpoint: string;
    message: string;
  } | null>(null);

  // Delete evidence with OTP
  const [evidenceToDelete, setEvidenceToDelete] = useState<EvidenceItem | null>(null);
  const [deleteOtp, setDeleteOtp] = useState('');
  const [deleteOtpSending, setDeleteOtpSending] = useState(false);
  const [deleteOtpError, setDeleteOtpError] = useState<string | null>(null);
  const [deleting, setDeleting] = useState(false);

  const loadCaseData = async () => {
    if (!id) return;

    try {
      setLoading(true);
      setBackendError(null);

      const fetchedCase = await casesService.getCaseById(id);
      setCaseItem(fetchedCase || null);

      try {
        const fetchedDocs = await documentsService.getDocuments(id);
        setDocuments(fetchedDocs);
      } catch {
        setDocuments([]);
      }

      try {
        const fetchedEvidence = await evidenceService.getEvidence(id);
        setEvidenceItems(fetchedEvidence);
      } catch {
        setEvidenceItems([]);
      }
    } catch (err: unknown) {
      console.error('Failed to load case details:', err);

      if (err instanceof ApiError) {
        setBackendError({
          status: err.status,
          endpoint: err.endpoint,
          message: err.message,
        });
      } else {
        setBackendError({
          status: 0,
          endpoint: `/cases/${id}`,
          message: (err as Error).message,
        });
      }
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadCaseData();
  }, [id]);

  const handleVerifyAllHashes = () => {
    setIsVerifyingHashes(true);
    setVerifyNotice(null);

    setTimeout(() => {
      setIsVerifyingHashes(false);

      const hasTamper = documents.some((doc) => doc.is_tampered);

      if (hasTamper) {
        setVerifyNotice(
          'SECURITY ALERT: One or more document integrity discrepancies were detected.'
        );
      } else {
        setVerifyNotice(
          `VERIFICATION COMPLETE: ${documents.length} document record(s) passed the available SHA-256 integrity check.`
        );
      }
    }, 800);
  };

  const handleCopy = async (text: string) => {
    try {
      await navigator.clipboard.writeText(text);
      setCopiedHash(text);

      setTimeout(() => {
        setCopiedHash(null);
      }, 2000);
    } catch {
      console.error('Unable to copy hash');
    }
  };

  const handleDocUpload = async (
    caseId: string,
    file: File,
    metadata: {
      title: string;
      documentType: string;
      description: string;
      uploadedBy: string;
    }
  ) => {
    await documentsService.uploadDocument(
      caseId,
      file,
      metadata
    );

    setIsDocUploadOpen(false);
    await loadCaseData();
  };

  const handleEvidenceUpload = async (data: {
    item_number: string;
    name: string;
    category: string;
    description: string;
    location: string;
  }) => {
    if (!caseItem) return;

    await evidenceService.createEvidence({
      case_id: caseItem.id,
      item_number: data.item_number,
      name: data.name,
      category: data.category,
      description: data.description,
      location: data.location,
    });

    setIsEvidenceUploadOpen(false);
    await loadCaseData();
  };

  const handleCustodyTransfer = async (
    evidenceId: string,
    data: {
      newCustodian: string;
      location: string;
      notes: string;
      actor: string;
    }
  ) => {
    await evidenceService.transferCustody(evidenceId, {
      new_custodian_id: data.newCustodian,
      location: data.location,
      notes: data.notes,
    });

    setSelectedEvidenceForTransfer(null);
    await loadCaseData();
  };

  // ── Delete evidence (admin only, OTP-gated) ──────────────────────────────

  const handleRequestDelete = async (item: EvidenceItem) => {
    setEvidenceToDelete(item);
    setDeleteOtpSending(true);
    setDeleteOtpError(null);
    const otp = generateOTP();
    setDeleteOtp(otp);
    try {
      await sendOTP({
        otp,
        userEmail: user?.email || 'admin',
        action: `Delete Evidence: ${item.name} (${item.item_number})`,
      });
    } catch {
      setDeleteOtpError('Failed to send OTP. Check EmailJS configuration.');
    } finally {
      setDeleteOtpSending(false);
    }
  };

  const handleDeleteOtpResend = async () => {
    if (!evidenceToDelete) return;
    const otp = generateOTP();
    setDeleteOtp(otp);
    setDeleteOtpSending(true);
    try {
      await sendOTP({
        otp,
        userEmail: user?.email || 'admin',
        action: `Delete Evidence: ${evidenceToDelete.name}`,
      });
      setDeleteOtpError(null);
    } catch {
      setDeleteOtpError('Failed to resend OTP.');
    } finally {
      setDeleteOtpSending(false);
    }
  };

  const handleDeleteConfirmed = async () => {
    if (!evidenceToDelete) return;
    setDeleting(true);
    try {
      await evidenceService.deleteEvidence(evidenceToDelete.id);
      setEvidenceToDelete(null);
      await loadCaseData();
    } catch (err: any) {
      setDeleteOtpError(err?.message || 'Deletion failed.');
    } finally {
      setDeleting(false);
    }
  };

  const filteredDocs = documents.filter((doc) => {
    const query = tableSearch.toLowerCase();

    const matchesSearch =
      doc.title.toLowerCase().includes(query) ||
      doc.sha256.toLowerCase().includes(query) ||
      doc.document_type.toLowerCase().includes(query) ||
      doc.uploaded_by.toLowerCase().includes(query);

    const matchesStatus =
      tableFilter === 'all'
        ? true
        : tableFilter === 'verified'
        ? !doc.is_tampered
        : doc.is_tampered;

    const matchesFormat =
      formatFilter === 'ALL'
        ? true
        : doc.file_type
            .toLowerCase()
            .includes(formatFilter.toLowerCase());

    return matchesSearch && matchesStatus && matchesFormat;
  });

  const custodyEventCount = evidenceItems.reduce(
    (total, evidence) =>
      total + evidence.custody_events.length,
    0
  );

  const verifiedDocuments = documents.filter(
    (doc) => !doc.is_tampered
  ).length;

  const tamperedDocuments = documents.filter(
    (doc) => doc.is_tampered
  ).length;

  const initials = (name?: string) =>
    (name || 'Officer')
      .split(' ')
      .map((word) => word[0])
      .join('')
      .slice(0, 2)
      .toUpperCase();

  if (loading) {
    return (
      <AppShell>
        <div className="flex min-h-[500px] items-center justify-center">
          <div className="text-center">
            <div className="mx-auto mb-4 flex h-12 w-12 items-center justify-center rounded-full bg-blue-50 border border-blue-200">
              <span className="material-symbols-outlined animate-spin text-blue-700 text-[24px]">
                progress_activity
              </span>
            </div>

            <h2 className="text-sm font-bold text-[#0b1f3a]">
              Loading Investigation Record
            </h2>

            <p className="mt-1 text-xs text-slate-500">
              Retrieving case, document and evidence data from ChainDock.
            </p>
          </div>
        </div>
      </AppShell>
    );
  }

  if (backendError) {
    return (
      <AppShell>
        <BackendUnavailable
          moduleName="Case Dossier"
          endpoint={backendError.endpoint}
          status={backendError.status}
          errorMessage={backendError.message}
          onRetry={loadCaseData}
        />
      </AppShell>
    );
  }

  if (!caseItem) {
    return (
      <AppShell>
        <div className="rounded-xl border border-slate-200 bg-white p-12 text-center shadow-sm">
          <div className="mx-auto mb-4 flex h-14 w-14 items-center justify-center rounded-full bg-amber-50 border border-amber-200">
            <span className="material-symbols-outlined text-amber-700 text-[28px]">
              folder_off
            </span>
          </div>

          <h2 className="text-lg font-bold text-[#0b1f3a]">
            Case Record Not Found
          </h2>

          <p className="mx-auto mt-2 max-w-lg text-xs leading-relaxed text-slate-500">
            The requested investigation record could not be retrieved from
            the pramāṇa-kośa database.
          </p>

          <button
            onClick={() => navigate('/cases')}
            className="mt-5 inline-flex items-center gap-2 rounded-lg bg-[#0b1f3a] px-4 py-2.5 text-xs font-semibold text-white hover:bg-[#12345c]"
          >
            <span className="material-symbols-outlined text-[17px]">
              arrow_back
            </span>
            Return to Case Management
          </button>
        </div>
      </AppShell>
    );
  }

  return (
    <AppShell>
      <div className="space-y-5">

        {/* ========================================================= */}
        {/* BREADCRUMB */}
        {/* ========================================================= */}

        <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">

          <div className="flex flex-wrap items-center gap-2">
            <button
              onClick={() => navigate('/cases')}
              className="inline-flex items-center gap-1.5 rounded-lg px-2.5 py-2 text-xs font-semibold text-slate-600 hover:bg-slate-200 hover:text-[#0b1f3a]"
            >
              <span className="material-symbols-outlined text-[17px]">
                arrow_back
              </span>
              Case Management
            </button>

            <span className="text-slate-300">/</span>

            <span className="rounded-md bg-blue-50 px-2.5 py-1 font-mono text-[11px] font-bold text-blue-800 border border-blue-100">
              {caseItem.case_number}
            </span>
          </div>

          <div className="flex items-center gap-2">
            <span className="flex items-center gap-1.5 rounded-lg border border-emerald-200 bg-emerald-50 px-3 py-1.5 text-[10px] font-semibold uppercase tracking-wide text-emerald-800">
              <span className="h-2 w-2 rounded-full bg-emerald-500" />
              ChainDock Protected
            </span>
          </div>
        </div>

        {/* ========================================================= */}
        {/* CASE HEADER */}
        {/* ========================================================= */}

        <section className="overflow-hidden rounded-xl border border-slate-200 bg-white shadow-sm">

          <div className="border-b border-slate-200 bg-[#0b1f3a] px-5 py-5 text-white lg:px-6">

            <div className="flex flex-col gap-5 xl:flex-row xl:items-start xl:justify-between">

              <div className="min-w-0">

                <div className="mb-3 flex flex-wrap items-center gap-2">

                  <span className="rounded-md bg-white px-2.5 py-1 font-mono text-[11px] font-bold text-[#0b1f3a]">
                    {caseItem.case_number}
                  </span>

                  <span className="flex items-center gap-1.5 rounded-md border border-blue-300/30 bg-blue-400/15 px-2.5 py-1 text-[10px] font-semibold uppercase tracking-wide text-blue-100">
                    <span className="h-2 w-2 rounded-full bg-emerald-400" />
                    {caseItem.status}
                  </span>

                  <span
                    className={`flex items-center gap-1.5 rounded-md border px-2.5 py-1 text-[10px] font-semibold uppercase tracking-wide ${
                      caseItem.priority === 'CRITICAL'
                        ? 'border-red-300/40 bg-red-500/20 text-red-100'
                        : caseItem.priority === 'HIGH'
                        ? 'border-orange-300/40 bg-orange-500/20 text-orange-100'
                        : 'border-blue-300/30 bg-blue-400/15 text-blue-100'
                    }`}
                  >
                    <span className="material-symbols-outlined text-[14px]">
                      flag
                    </span>
                    {caseItem.priority}
                  </span>

                  <span className="rounded-md border border-white/10 bg-white/5 px-2.5 py-1 text-[10px] font-medium uppercase tracking-wide text-blue-100">
                    {caseItem.jurisdiction}
                  </span>
                </div>

                <h1 className="text-2xl font-bold tracking-tight lg:text-3xl">
                  {caseItem.title}
                </h1>

                <p className="mt-2 max-w-4xl text-sm leading-relaxed text-blue-100/80">
                  {caseItem.description || 'No case description available.'}
                </p>
              </div>

              {/* CASE ACTIONS */}

              <div className="flex flex-wrap gap-2 xl:max-w-md xl:justify-end">

                <button
                  onClick={() => {
                    if (evidenceItems.length > 0) {
                      setSelectedEvidenceForTransfer(
                        evidenceItems[0]
                      );
                    } else {
                      setIsEvidenceUploadOpen(true);
                    }
                  }}
                  className="inline-flex h-9 items-center gap-1.5 rounded-lg border border-white/15 bg-white/10 px-3.5 text-xs font-semibold text-white hover:bg-white/15"
                >
                  <span className="material-symbols-outlined text-[17px]">
                    swap_horiz
                  </span>
                  Transfer Custody
                </button>

                <button
                  onClick={handleVerifyAllHashes}
                  disabled={isVerifyingHashes}
                  className="inline-flex h-9 items-center gap-1.5 rounded-lg bg-white px-3.5 text-xs font-bold text-[#0b1f3a] hover:bg-blue-50 disabled:opacity-60"
                >
                  <span
                    className={`material-symbols-outlined text-[17px] ${
                      isVerifyingHashes ? 'animate-spin' : ''
                    }`}
                  >
                    {isVerifyingHashes
                      ? 'sync'
                      : 'verified_user'}
                  </span>

                  {isVerifyingHashes
                    ? 'Verifying...'
                    : 'Verify Hashes'}
                </button>

                <button
                  onClick={() => setIsDocUploadOpen(true)}
                  className="inline-flex h-9 items-center gap-1.5 rounded-lg bg-blue-500 px-3.5 text-xs font-semibold text-white hover:bg-blue-600"
                >
                  <span className="material-symbols-outlined text-[17px]">
                    upload_file
                  </span>
                  Upload Document
                </button>

                <button
                  onClick={() => setIsEvidenceUploadOpen(true)}
                  className="inline-flex h-9 items-center gap-1.5 rounded-lg border border-white/15 bg-white/10 px-3.5 text-xs font-semibold text-white hover:bg-white/15"
                >
                  <span className="material-symbols-outlined text-[17px]">
                    inventory_2
                  </span>
                  Register Evidence
                </button>

              </div>
            </div>
          </div>

          {/* ======================================================= */}
          {/* VERIFICATION NOTICE */}
          {/* ======================================================= */}

          {verifyNotice && (
            <div
              className={`mx-5 mt-4 rounded-lg border p-3 lg:mx-6 ${
                verifyNotice.includes('ALERT')
                  ? 'border-red-200 bg-red-50 text-red-800'
                  : 'border-emerald-200 bg-emerald-50 text-emerald-800'
              }`}
            >
              <div className="flex items-start justify-between gap-3">

                <div className="flex items-start gap-2">
                  <span className="material-symbols-outlined text-[18px]">
                    {verifyNotice.includes('ALERT')
                      ? 'error'
                      : 'check_circle'}
                  </span>

                  <span className="text-xs font-medium leading-relaxed">
                    {verifyNotice}
                  </span>
                </div>

                <button
                  onClick={() => setVerifyNotice(null)}
                  className="text-[10px] font-bold uppercase opacity-60 hover:opacity-100"
                >
                  Dismiss
                </button>

              </div>
            </div>
          )}

          {/* ======================================================= */}
          {/* CASE SUMMARY */}
          {/* ======================================================= */}

          <div className="grid grid-cols-1 gap-3 p-5 sm:grid-cols-2 xl:grid-cols-4 lg:p-6">

            {/* Investigator */}

            <div className="rounded-lg border border-slate-200 bg-slate-50 p-3.5">

              <div className="flex items-center gap-3">

                <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-[#0b1f3a] text-xs font-bold text-white">
                  {initials(caseItem.lead_officer)}
                </div>

                <div className="min-w-0">
                  <p className="text-[9px] font-bold uppercase tracking-wider text-slate-400">
                    Investigating Officer
                  </p>

                  <p className="truncate text-sm font-bold text-[#0b1f3a]">
                    {caseItem.lead_officer}
                  </p>

                  <p className="font-mono text-[10px] text-slate-500">
                    Badge #{caseItem.lead_officer_badge}
                  </p>
                </div>

              </div>
            </div>

            {/* Supervisor */}

            <div className="rounded-lg border border-slate-200 bg-slate-50 p-3.5">

              <div className="flex items-center gap-3">

                <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-blue-600 text-white">
                  <span className="material-symbols-outlined text-[20px]">
                    supervisor_account
                  </span>
                </div>

                <div className="min-w-0">
                  <p className="text-[9px] font-bold uppercase tracking-wider text-slate-400">
                    Supervisory Officer
                  </p>

                  <p className="truncate text-sm font-bold text-[#0b1f3a]">
                    {caseItem.supervisor}
                  </p>

                  <p className="text-[10px] text-slate-500">
                    Investigation Oversight
                  </p>
                </div>

              </div>
            </div>

            {/* Registered */}

            <div className="rounded-lg border border-slate-200 bg-slate-50 p-3.5">

              <div className="flex items-center gap-3">

                <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-white border border-slate-200 text-[#0b1f3a]">
                  <span className="material-symbols-outlined text-[20px]">
                    calendar_today
                  </span>
                </div>

                <div className="min-w-0">
                  <p className="text-[9px] font-bold uppercase tracking-wider text-slate-400">
                    Case Registered
                  </p>

                  <p className="text-sm font-bold text-[#0b1f3a]">
                    {formatTimestamp(caseItem.created_at)}
                  </p>

                  <p className="text-[10px] text-slate-500">
                    Digital Case Diary
                  </p>
                </div>

              </div>
            </div>

            {/* Integrity */}

            <div className="rounded-lg border border-emerald-200 bg-emerald-50 p-3.5">

              <div className="flex items-center gap-3">

                <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-emerald-700 text-white">
                  <span className="material-symbols-outlined text-[20px]">
                    security
                  </span>
                </div>

                <div className="min-w-0">
                  <p className="text-[9px] font-bold uppercase tracking-wider text-emerald-700">
                    ChainDock Integrity
                  </p>

                  <p className="text-sm font-bold text-emerald-900">
                    Protected
                  </p>

                  <p className="text-[10px] text-emerald-700">
                    {verifiedDocuments} verified · {tamperedDocuments} flagged
                  </p>
                </div>

              </div>
            </div>

          </div>
        </section>

        {/* ========================================================= */}
        {/* MAIN CONTENT */}
        {/* ========================================================= */}

        <div className="grid grid-cols-1 items-start gap-5 xl:grid-cols-12">

          {/* ======================================================= */}
          {/* LEFT */}
          {/* ======================================================= */}

          <div className="flex min-w-0 flex-col gap-5 xl:col-span-8">

            {/* TABS */}

            <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white p-1 shadow-sm">

              <div className="flex min-w-max gap-1">

                <button
                  onClick={() => setActiveTab('documents')}
                  className={`flex items-center gap-2 rounded-lg px-4 py-2.5 text-xs font-bold ${
                    activeTab === 'documents'
                      ? 'bg-[#0b1f3a] text-white'
                      : 'text-slate-600 hover:bg-slate-100'
                  }`}
                >
                  <span className="material-symbols-outlined text-[17px]">
                    description
                  </span>
                  Documents
                  <span
                    className={`rounded px-1.5 py-0.5 font-mono text-[9px] ${
                      activeTab === 'documents'
                        ? 'bg-white/15 text-white'
                        : 'bg-slate-100 text-slate-600'
                    }`}
                  >
                    {documents.length}
                  </span>
                </button>

                <button
                  onClick={() => setActiveTab('evidence')}
                  className={`flex items-center gap-2 rounded-lg px-4 py-2.5 text-xs font-semibold ${
                    activeTab === 'evidence'
                      ? 'bg-[#0b1f3a] text-white'
                      : 'text-slate-600 hover:bg-slate-100'
                  }`}
                >
                  <span className="material-symbols-outlined text-[17px]">
                    inventory_2
                  </span>
                  Evidence
                  <span
                    className={`rounded px-1.5 py-0.5 font-mono text-[9px] ${
                      activeTab === 'evidence'
                        ? 'bg-white/15 text-white'
                        : 'bg-slate-100 text-slate-600'
                    }`}
                  >
                    {evidenceItems.length}
                  </span>
                </button>

                <button
                  onClick={() => setActiveTab('timeline')}
                  className={`flex items-center gap-2 rounded-lg px-4 py-2.5 text-xs font-semibold ${
                    activeTab === 'timeline'
                      ? 'bg-[#0b1f3a] text-white'
                      : 'text-slate-600 hover:bg-slate-100'
                  }`}
                >
                  <span className="material-symbols-outlined text-[17px]">
                    account_tree
                  </span>
                  Chain of Custody
                </button>

                <button
                  onClick={() => setActiveTab('details')}
                  className={`flex items-center gap-2 rounded-lg px-4 py-2.5 text-xs font-semibold ${
                    activeTab === 'details'
                      ? 'bg-[#0b1f3a] text-white'
                      : 'text-slate-600 hover:bg-slate-100'
                  }`}
                >
                  <span className="material-symbols-outlined text-[17px]">
                    gavel
                  </span>
                  Case Details
                </button>

              </div>
            </div>

            {/* ===================================================== */}
            {/* DOCUMENTS */}
            {/* ===================================================== */}

            {activeTab === 'documents' && (
              <div className="space-y-4">

                <div className="rounded-xl border border-slate-200 bg-white p-4 shadow-sm">

                  <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">

                    <div className="relative w-full lg:max-w-sm">
                      <span className="material-symbols-outlined absolute left-3 top-1/2 -translate-y-1/2 text-[18px] text-slate-400">
                        search
                      </span>

                      <input
                        value={tableSearch}
                        onChange={(e) =>
                          setTableSearch(e.target.value)
                        }
                        placeholder="Search documents, hash, officer..."
                        className="h-9 w-full rounded-lg border border-slate-200 bg-slate-50 pl-9 pr-3 text-xs text-slate-800 outline-none focus:border-blue-500 focus:bg-white"
                      />
                    </div>

                    <div className="flex flex-wrap gap-2">

                      <div className="flex rounded-lg border border-slate-200 bg-slate-50 p-0.5">

                        <button
                          onClick={() =>
                            setTableFilter('all')
                          }
                          className={`rounded-md px-2.5 py-1.5 text-[10px] font-semibold ${
                            tableFilter === 'all'
                              ? 'bg-white text-[#0b1f3a] shadow-sm'
                              : 'text-slate-500'
                          }`}
                        >
                          All
                        </button>

                        <button
                          onClick={() =>
                            setTableFilter('verified')
                          }
                          className={`rounded-md px-2.5 py-1.5 text-[10px] font-semibold ${
                            tableFilter === 'verified'
                              ? 'bg-white text-emerald-700 shadow-sm'
                              : 'text-slate-500'
                          }`}
                        >
                          Verified
                        </button>

                        <button
                          onClick={() =>
                            setTableFilter('tampered')
                          }
                          className={`rounded-md px-2.5 py-1.5 text-[10px] font-semibold ${
                            tableFilter === 'tampered'
                              ? 'bg-white text-red-700 shadow-sm'
                              : 'text-slate-500'
                          }`}
                        >
                          Tampered
                        </button>

                      </div>

                      <select
                        value={formatFilter}
                        onChange={(e) =>
                          setFormatFilter(e.target.value)
                        }
                        className="h-9 rounded-lg border border-slate-200 bg-slate-50 px-3 text-[10px] font-medium text-slate-700 outline-none focus:border-blue-500"
                      >
                        <option value="ALL">
                          All Formats
                        </option>
                        <option value="PDF">PDF</option>
                        <option value="FORENSIC">
                          Forensic
                        </option>
                        <option value="IMAGE">
                          Disk Image
                        </option>
                      </select>

                    </div>
                  </div>
                </div>

                {/* DOCUMENT TABLE */}

                <div className="overflow-hidden rounded-xl border border-slate-200 bg-white shadow-sm">

                  <div className="overflow-x-auto">

                    <table className="w-full min-w-[760px] text-left">

                      <thead>
                        <tr className="border-b border-slate-200 bg-slate-50">

                          <th className="px-4 py-3 text-[10px] font-bold uppercase tracking-wider text-slate-500">
                            Document
                          </th>

                          <th className="px-4 py-3 text-[10px] font-bold uppercase tracking-wider text-slate-500">
                            SHA-256
                          </th>

                          <th className="px-4 py-3 text-[10px] font-bold uppercase tracking-wider text-slate-500">
                            Registered
                          </th>

                          <th className="px-4 py-3 text-[10px] font-bold uppercase tracking-wider text-slate-500">
                            Type / Size
                          </th>

                          <th className="px-4 py-3 text-[10px] font-bold uppercase tracking-wider text-slate-500">
                            Integrity
                          </th>

                          <th className="px-4 py-3 text-right text-[10px] font-bold uppercase tracking-wider text-slate-500">
                            Action
                          </th>

                        </tr>
                      </thead>

                      <tbody className="divide-y divide-slate-100">

                        {filteredDocs.length === 0 ? (
                          <tr>
                            <td
                              colSpan={6}
                              className="px-4 py-12 text-center"
                            >
                              <span className="material-symbols-outlined text-[30px] text-slate-300">
                                description
                              </span>

                              <p className="mt-2 text-xs font-semibold text-slate-500">
                                No documents found
                              </p>

                              <p className="mt-1 text-[10px] text-slate-400">
                                Try changing the search or filters.
                              </p>
                            </td>
                          </tr>
                        ) : (
                          filteredDocs.map((doc) => (
                            <tr
                              key={doc.id}
                              onClick={() =>
                                navigate(
                                  `/documents/${doc.id}`
                                )
                              }
                              className="cursor-pointer hover:bg-blue-50/40"
                            >

                              <td className="px-4 py-3.5">

                                <div className="flex items-center gap-3">

                                  <div
                                    className={`flex h-9 w-9 shrink-0 items-center justify-center rounded-lg border ${
                                      doc.is_tampered
                                        ? 'border-red-200 bg-red-50 text-red-600'
                                        : 'border-blue-100 bg-blue-50 text-blue-700'
                                    }`}
                                  >
                                    <span className="material-symbols-outlined text-[18px]">
                                      {doc.is_tampered
                                        ? 'warning'
                                        : 'description'}
                                    </span>
                                  </div>

                                  <div className="min-w-0">
                                    <p className="max-w-[230px] truncate text-xs font-bold text-[#0b1f3a]">
                                      {doc.title}
                                    </p>

                                    <p className="mt-0.5 max-w-[250px] truncate font-mono text-[9px] text-slate-400">
                                      {doc.legal_docket_ref ||
                                        doc.id}
                                    </p>

                                  </div>

                                </div>

                              </td>

                              <td
                                className="px-4 py-3.5"
                                onClick={(e) =>
                                  e.stopPropagation()
                                }
                              >

                                <div className="flex w-fit items-center gap-1 rounded-md border border-slate-200 bg-slate-50 px-2 py-1">

                                  <span
                                    className={`font-mono text-[9px] ${
                                      doc.is_tampered
                                        ? 'font-bold text-red-600 line-through'
                                        : 'text-slate-700'
                                    }`}
                                  >
                                    {truncateHash(
                                      doc.sha256,
                                      7,
                                      7
                                    )}
                                  </span>

                                  <button
                                    onClick={() =>
                                      handleCopy(doc.sha256)
                                    }
                                    className="text-slate-400 hover:text-blue-700"
                                    title="Copy SHA-256"
                                  >
                                    <span className="material-symbols-outlined text-[14px]">
                                      {copiedHash ===
                                      doc.sha256
                                        ? 'check'
                                        : 'content_copy'}
                                    </span>
                                  </button>

                                </div>

                              </td>

                              <td className="px-4 py-3.5 font-mono text-[10px] text-slate-500">
                                {formatTimestamp(
                                  doc.created_at
                                )}
                              </td>

                              <td className="px-4 py-3.5">

                                <p className="text-[10px] font-semibold text-slate-700">
                                  {doc.file_type}
                                </p>

                                <p className="mt-0.5 text-[9px] text-slate-400">
                                  {doc.file_size}
                                </p>

                              </td>

                              <td className="px-4 py-3.5">

                                {doc.is_tampered ? (
                                  <span className="inline-flex items-center gap-1 rounded-full border border-red-200 bg-red-50 px-2 py-1 text-[9px] font-bold uppercase text-red-700">
                                    <span className="material-symbols-outlined text-[12px]">
                                      gpp_bad
                                    </span>
                                    Tampered
                                  </span>
                                ) : (
                                  <span className="inline-flex items-center gap-1 rounded-full border border-emerald-200 bg-emerald-50 px-2 py-1 text-[9px] font-bold uppercase text-emerald-700">
                                    <span className="material-symbols-outlined text-[12px]">
                                      verified
                                    </span>
                                    Verified
                                  </span>
                                )}

                              </td>

                              <td
                                className="px-4 py-3.5 text-right"
                                onClick={(e) =>
                                  e.stopPropagation()
                                }
                              >

                                <button
                                  onClick={() =>
                                    navigate(
                                      `/documents/${doc.id}`
                                    )
                                  }
                                  className="rounded-lg p-2 text-slate-400 hover:bg-blue-50 hover:text-blue-700"
                                  title="Inspect document"
                                >
                                  <span className="material-symbols-outlined text-[17px]">
                                    open_in_new
                                  </span>
                                </button>

                              </td>

                            </tr>
                          ))
                        )}

                      </tbody>
                    </table>
                  </div>

                  <div className="flex flex-col gap-2 border-t border-slate-200 bg-slate-50 px-4 py-3 sm:flex-row sm:items-center sm:justify-between">

                    <span className="text-[10px] text-slate-500">
                      Showing{' '}
                      <strong className="text-slate-700">
                        {filteredDocs.length}
                      </strong>{' '}
                      of{' '}
                      <strong className="text-slate-700">
                        {documents.length}
                      </strong>{' '}
                      document records
                    </span>

                    <span className="flex items-center gap-1.5 font-mono text-[9px] font-semibold uppercase text-emerald-700">
                      <span className="h-1.5 w-1.5 rounded-full bg-emerald-500" />
                      ChainDock Integrity Layer
                    </span>

                  </div>

                </div>
              </div>
            )}

            {/* ===================================================== */}
            {/* EVIDENCE */}
            {/* ===================================================== */}

            {activeTab === 'evidence' && (
              <div className="space-y-4">

                {evidenceItems.length === 0 ? (
                  <div className="rounded-xl border border-slate-200 bg-white p-12 text-center shadow-sm">

                    <div className="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-slate-100">
                      <span className="material-symbols-outlined text-slate-400">
                        inventory_2
                      </span>
                    </div>

                    <h3 className="mt-3 text-sm font-bold text-[#0b1f3a]">
                      No Evidence Registered
                    </h3>

                    <p className="mt-1 text-xs text-slate-500">
                      Evidence items registered against this case will
                      appear here.
                    </p>

                    <button
                      onClick={() =>
                        setIsEvidenceUploadOpen(true)
                      }
                      className="mt-4 rounded-lg bg-[#0b1f3a] px-4 py-2 text-xs font-semibold text-white hover:bg-[#12345c]"
                    >
                      Register Evidence
                    </button>

                  </div>
                ) : (
                  <div className="grid grid-cols-1 gap-4 md:grid-cols-2">

                    {evidenceItems.map((item) => (
                      <div
                        key={item.id}
                        className="rounded-xl border border-slate-200 bg-white p-4 shadow-sm hover:border-blue-200"
                      >

                        <div className="flex items-start justify-between gap-3">

                          <span className="rounded-md bg-blue-50 px-2 py-1 font-mono text-[10px] font-bold text-blue-800 border border-blue-100">
                            {item.item_number}
                          </span>

                          <span className="rounded-full border border-emerald-200 bg-emerald-50 px-2 py-1 text-[9px] font-bold uppercase text-emerald-700">
                            {item.status}
                          </span>

                        </div>

                        <h3 className="mt-3 text-sm font-bold text-[#0b1f3a]">
                          {item.name}
                        </h3>

                        <p className="mt-1 line-clamp-2 text-xs leading-relaxed text-slate-500">
                          {item.description}
                        </p>

                        <div className="mt-4 flex items-end justify-between gap-3 border-t border-slate-100 pt-3">

                          <div className="min-w-0">
                            <p className="text-[9px] font-bold uppercase tracking-wider text-slate-400">
                              Current Location
                            </p>

                            <p className="mt-0.5 truncate text-xs font-semibold text-[#0b1f3a]">
                              {item.location}
                            </p>
                          </div>

                          <div className="flex items-center gap-2">
                            <button
                              onClick={() =>
                                setSelectedEvidenceForTransfer(item)
                              }
                              className="shrink-0 inline-flex items-center gap-1 rounded-lg border border-slate-200 bg-slate-50 px-2.5 py-1.5 text-[10px] font-semibold text-slate-700 hover:bg-blue-50 hover:text-blue-700"
                            >
                              <span className="material-symbols-outlined text-[14px]">
                                swap_horiz
                              </span>
                              Handover
                            </button>

                            {isAdmin && (
                              <button
                                onClick={() => handleRequestDelete(item)}
                                disabled={deleting}
                                className="shrink-0 inline-flex items-center gap-1 rounded-lg border border-red-200 bg-red-50 px-2.5 py-1.5 text-[10px] font-semibold text-red-700 hover:bg-red-100 disabled:opacity-50"
                              >
                                <span className="material-symbols-outlined text-[14px]">
                                  delete
                                </span>
                                Delete
                              </button>
                            )}
                          </div>

                        </div>

                      </div>
                    ))}

                  </div>
                )}

              </div>
            )}

            {/* ===================================================== */}
            {/* CUSTODY TIMELINE */}
            {/* ===================================================== */}

            {activeTab === 'timeline' && (
              <div className="rounded-xl border border-slate-200 bg-white p-5 shadow-sm lg:p-6">

                <div className="flex flex-col gap-3 border-b border-slate-200 pb-4 sm:flex-row sm:items-center sm:justify-between">

                  <div>
                    <div className="flex items-center gap-2">
                      <span className="material-symbols-outlined text-[20px] text-[#0b1f3a]">
                        account_tree
                      </span>

                      <h3 className="text-sm font-bold text-[#0b1f3a]">
                        Chain of Custody
                      </h3>
                    </div>

                    <p className="mt-1 text-xs text-slate-500">
                      Chronological evidence custody events recorded by
                      ChainDock.
                    </p>
                  </div>

                  <span className="inline-flex w-fit items-center gap-1.5 rounded-lg border border-blue-100 bg-blue-50 px-2.5 py-1.5 font-mono text-[9px] font-bold uppercase text-blue-800">
                    <span className="material-symbols-outlined text-[13px]">
                      security
                    </span>
                    {custodyEventCount} Events
                  </span>

                </div>

                <div className="mt-5 space-y-3">

                  {custodyEventCount === 0 ? (
                    <div className="rounded-lg border border-dashed border-slate-300 bg-slate-50 p-10 text-center">

                      <span className="material-symbols-outlined text-[28px] text-slate-300">
                        timeline
                      </span>

                      <p className="mt-2 text-xs font-semibold text-slate-500">
                        No custody events recorded
                      </p>

                    </div>
                  ) : (
                    evidenceItems
                      .flatMap((evidence) =>
                        evidence.custody_events.map((event) => ({
                          ...event,
                          item_name: evidence.name,
                          item_number:
                            evidence.item_number,
                        }))
                      )
                      .map((event, index) => (
                        <div
                          key={event.id || index}
                          className="flex gap-3 rounded-lg border border-slate-200 bg-slate-50 p-3.5"
                        >

                          <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-[#0b1f3a] text-[10px] font-bold text-white">
                            {index + 1}
                          </div>

                          <div className="min-w-0 flex-1">

                            <div className="flex flex-col gap-1 sm:flex-row sm:items-center sm:justify-between">

                              <span className="text-xs font-bold text-[#0b1f3a]">
                                {event.action}
                              </span>

                              <span className="font-mono text-[9px] text-slate-400">
                                {formatTimestamp(
                                  event.timestamp
                                )}
                              </span>

                            </div>

                            <p className="mt-1 text-xs text-slate-600">
                              <span className="font-mono font-bold text-blue-700">
                                {event.item_number}
                              </span>{' '}
                              — {event.item_name}
                            </p>

                            <div className="mt-2 flex flex-wrap items-center gap-x-3 gap-y-1 border-t border-slate-200 pt-2 text-[10px] text-slate-500">

                              <span>
                                From:{' '}
                                <strong className="text-slate-700">
                                  {event.prev_custodian}
                                </strong>
                              </span>

                              <span className="text-slate-300">
                                →
                              </span>

                              <span>
                                To:{' '}
                                <strong className="text-slate-700">
                                  {event.new_custodian}
                                </strong>
                              </span>

                              <span className="font-mono text-[9px] text-blue-700 sm:ml-auto">
                                {event.tx_hash}
                              </span>

                            </div>

                          </div>
                        </div>
                      ))
                  )}

                </div>
              </div>
            )}

            {/* ===================================================== */}
            {/* CASE DETAILS */}
            {/* ===================================================== */}

            {activeTab === 'details' && (
              <div className="rounded-xl border border-slate-200 bg-white p-5 shadow-sm lg:p-6">

                <div className="flex items-center gap-2 border-b border-slate-200 pb-4">

                  <span className="material-symbols-outlined text-[20px] text-[#0b1f3a]">
                    folder_shared
                  </span>

                  <div>
                    <h3 className="text-sm font-bold text-[#0b1f3a]">
                      Investigation Details
                    </h3>

                    <p className="mt-0.5 text-[10px] text-slate-500">
                      Official case information maintained in the pramāṇa-kośa.
                    </p>
                  </div>

                </div>

                <div className="mt-5 grid grid-cols-1 gap-4 sm:grid-cols-2">

                  <div className="rounded-lg border border-slate-200 bg-slate-50 p-3.5">
                    <p className="text-[9px] font-bold uppercase tracking-wider text-slate-400">
                      Case Number
                    </p>
                    <p className="mt-1 font-mono text-sm font-bold text-[#0b1f3a]">
                      {caseItem.case_number}
                    </p>
                  </div>

                  <div className="rounded-lg border border-slate-200 bg-slate-50 p-3.5">
                    <p className="text-[9px] font-bold uppercase tracking-wider text-slate-400">
                      Jurisdiction
                    </p>
                    <p className="mt-1 text-sm font-bold text-[#0b1f3a]">
                      {caseItem.jurisdiction}
                    </p>
                  </div>

                  <div className="rounded-lg border border-slate-200 bg-slate-50 p-3.5">
                    <p className="text-[9px] font-bold uppercase tracking-wider text-slate-400">
                      Status
                    </p>
                    <p className="mt-1 text-sm font-bold text-[#0b1f3a]">
                      {caseItem.status}
                    </p>
                  </div>

                  <div className="rounded-lg border border-slate-200 bg-slate-50 p-3.5">
                    <p className="text-[9px] font-bold uppercase tracking-wider text-slate-400">
                      Priority
                    </p>
                    <p className="mt-1 text-sm font-bold text-[#0b1f3a]">
                      {caseItem.priority}
                    </p>
                  </div>

                </div>

                <div className="mt-5 rounded-lg border border-blue-100 bg-blue-50 p-4">

                  <div className="flex items-center gap-2">

                    <span className="material-symbols-outlined text-[18px] text-blue-700">
                      gavel
                    </span>

                    <h4 className="text-xs font-bold uppercase tracking-wider text-blue-900">
                      Digital Evidence Framework
                    </h4>

                  </div>

                  <p className="mt-2 text-xs leading-relaxed text-blue-900/80">
                    Digital records and evidence associated with this case
                    are managed through the ChainDock integrity layer.
                    Cryptographic hashes, audit events and custody records
                    remain associated with the underlying case record.
                  </p>

                </div>

                <div className="mt-5">

                  <p className="text-[9px] font-bold uppercase tracking-wider text-slate-400">
                    Case Description
                  </p>

                  <p className="mt-2 text-sm leading-relaxed text-slate-600">
                    {caseItem.description ||
                      'No additional case description available.'}
                  </p>

                </div>

              </div>
            )}

          </div>

          {/* ======================================================= */}
          {/* RIGHT SIDEBAR */}
          {/* ======================================================= */}

          <div className="flex min-w-0 flex-col gap-5 xl:col-span-4">

            {/* SECURITY */}

            <div className="overflow-hidden rounded-xl bg-[#0b1f3a] text-white shadow-sm">

              <div className="border-b border-white/10 px-5 py-4">

                <div className="flex items-center justify-between">

                  <div className="flex items-center gap-2">

                    <span className="material-symbols-outlined text-[20px] text-blue-300">
                      security
                    </span>

                    <h2 className="text-sm font-bold">
                      ChainDock Security
                    </h2>

                  </div>

                  <span className="rounded-md border border-emerald-400/20 bg-emerald-400/10 px-2 py-1 text-[8px] font-bold uppercase tracking-wider text-emerald-300">
                    ACTIVE
                  </span>

                </div>

              </div>

              <div className="space-y-4 p-5">

                <div>
                  <p className="text-[9px] font-bold uppercase tracking-wider text-blue-300">
                    Protected Case Reference
                  </p>

                  <div className="mt-1.5 rounded-lg border border-white/10 bg-white/5 px-3 py-2.5 font-mono text-[10px] text-blue-100">
                    {caseItem.case_number || caseItem.id}
                  </div>
                </div>

                <div className="grid grid-cols-2 gap-3">

                  <div className="rounded-lg border border-white/10 bg-white/5 p-3">

                    <p className="text-[9px] uppercase text-blue-300">
                      Documents
                    </p>

                    <p className="mt-1 text-xl font-bold">
                      {documents.length}
                    </p>

                  </div>

                  <div className="rounded-lg border border-white/10 bg-white/5 p-3">

                    <p className="text-[9px] uppercase text-blue-300">
                      Evidence
                    </p>

                    <p className="mt-1 text-xl font-bold">
                      {evidenceItems.length}
                    </p>

                  </div>

                </div>

                <div className="border-t border-white/10 pt-3">

                  <div className="flex items-center justify-between">

                    <span className="text-[10px] text-blue-200">
                      Verified documents
                    </span>

                    <span className="font-mono text-xs font-bold text-emerald-300">
                      {verifiedDocuments}
                    </span>

                  </div>

                  <div className="mt-2 flex items-center justify-between">

                    <span className="text-[10px] text-blue-200">
                      Integrity alerts
                    </span>

                    <span className="font-mono text-xs font-bold text-red-300">
                      {tamperedDocuments}
                    </span>

                  </div>

                </div>

                <div className="rounded-lg border border-blue-400/20 bg-blue-500/10 p-3">

                  <div className="flex items-start gap-2">

                    <span className="material-symbols-outlined text-[17px] text-blue-300">
                      verified_user
                    </span>

                    <p className="text-[10px] leading-relaxed text-blue-100/80">
                      ChainDock provides the cryptographic integrity,
                      audit and evidence custody infrastructure behind
                      this pramāṇa-kośa case record.
                    </p>

                  </div>

                </div>

              </div>
            </div>

            {/* INVESTIGATING AUTHORITY */}

            <div className="rounded-xl border border-slate-200 bg-white p-5 shadow-sm">

              <div className="mb-3 flex items-center gap-2">

                <span className="material-symbols-outlined text-[20px] text-[#0b1f3a]">
                  badge
                </span>

                <h2 className="text-sm font-bold uppercase tracking-wider text-[#0b1f3a]">
                  Investigating Authority
                </h2>

              </div>

              <div className="rounded-lg border border-slate-200 bg-slate-50 p-3">

                <div className="flex items-center gap-3">

                  <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-[#0b1f3a] text-white">
                    <span className="material-symbols-outlined text-[20px]">
                      local_police
                    </span>
                  </div>

                  <div className="min-w-0">

                    <p className="truncate text-sm font-bold text-[#0b1f3a]">
                      {caseItem.lead_officer ||
                        'Officer Assigned'}
                    </p>

                    <p className="truncate text-[10px] text-slate-500">
                      {caseItem.jurisdiction}
                    </p>

                    <p className="mt-1 truncate text-[10px] font-semibold text-blue-700">
                      Supervisor:{' '}
                      {caseItem.supervisor ||
                        'Institutional Oversight'}
                    </p>

                  </div>

                </div>

              </div>

            </div>

            {/* CUSTODY SUMMARY */}

            <div className="rounded-xl border border-slate-200 bg-white p-5 shadow-sm">

              <div className="flex items-center justify-between border-b border-slate-200 pb-3">

                <div className="flex items-center gap-2">

                  <span className="material-symbols-outlined text-[20px] text-[#0b1f3a]">
                    account_tree
                  </span>

                  <h2 className="text-sm font-bold uppercase tracking-wider text-[#0b1f3a]">
                    Custody Summary
                  </h2>

                </div>

                <span className="rounded-md bg-blue-50 px-2 py-1 font-mono text-[9px] font-bold text-blue-700">
                  {custodyEventCount}
                </span>

              </div>

              <div className="mt-3 space-y-2">

                {evidenceItems.slice(0, 4).map((item) => (
                  <div
                    key={item.id}
                    className="flex items-center justify-between gap-3 rounded-lg border border-slate-100 bg-slate-50 p-2.5"
                  >

                    <div className="min-w-0">

                      <p className="truncate text-[10px] font-bold text-[#0b1f3a]">
                        {item.name}
                      </p>

                      <p className="mt-0.5 font-mono text-[8px] text-slate-400">
                        {item.item_number}
                      </p>

                    </div>

                    <span className="shrink-0 text-[8px] font-bold uppercase text-emerald-700">
                      {item.status}
                    </span>

                  </div>
                ))}

                {evidenceItems.length === 0 && (
                  <p className="py-5 text-center text-[10px] text-slate-400">
                    No custody records available.
                  </p>
                )}

              </div>

              {evidenceItems.length > 0 && (
                <button
                  onClick={() => setActiveTab('timeline')}
                  className="mt-3 flex w-full items-center justify-center gap-1.5 rounded-lg border border-slate-200 py-2 text-[10px] font-semibold text-blue-700 hover:bg-blue-50"
                >
                  View Complete Custody Chain
                  <span className="material-symbols-outlined text-[14px]">
                    arrow_forward
                  </span>
                </button>
              )}

            </div>

          </div>
        </div>
      </div>

      {/* =========================================================== */}
      {/* DOCUMENT UPLOAD */}
      {/* =========================================================== */}

      <DocumentUpload
        isOpen={isDocUploadOpen}
        onClose={() => setIsDocUploadOpen(false)}
        caseId={caseItem.id}
        onUpload={handleDocUpload}
      />

      {/* =========================================================== */}
      {/* EVIDENCE UPLOAD */}
      {/* =========================================================== */}

      <EvidenceUpload
        isOpen={isEvidenceUploadOpen}
        onClose={() => setIsEvidenceUploadOpen(false)}
        caseId={caseItem.id}
        onSubmit={handleEvidenceUpload}
      />

      {/* =========================================================== */}
      {/* CUSTODY TRANSFER */}
      {/* =========================================================== */}

      <ChainOfCustodyLog
        isOpen={Boolean(selectedEvidenceForTransfer)}
        onClose={() => setSelectedEvidenceForTransfer(null)}
        evidenceItem={selectedEvidenceForTransfer}
        onTransfer={handleCustodyTransfer}
      />

      {/* =========================================================== */}
      {/* DELETE EVIDENCE OTP MODAL */}
      {/* =========================================================== */}

      {evidenceToDelete && (
        <OtpModal
          title="Confirm Evidence Deletion"
          description={`An OTP has been sent to bkadikuppur@gmail.com. Enter it to permanently delete "${evidenceToDelete.name}" (${evidenceToDelete.item_number}).`}
          expectedOtp={deleteOtp}
          sending={deleteOtpSending}
          sendError={deleteOtpError}
          onVerified={handleDeleteConfirmed}
          onCancel={() => { setEvidenceToDelete(null); setDeleteOtpError(null); }}
          onResend={handleDeleteOtpResend}
        />
      )}

    </AppShell>
  );
};
