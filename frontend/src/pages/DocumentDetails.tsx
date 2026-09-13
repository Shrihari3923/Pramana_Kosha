import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { AppShell } from '../components/layout/AppShell';
import { documentsService } from '../services/documents';
import { casesService } from '../services/cases';
import { securityService } from '../services/securityService';
import { useAuth } from '../hooks/useAuth';
import {
  Document as DocType,
  Case,
  DocumentSignature,
  SignatureVerifyResult,
  IntegrityCheckResult,
} from '../types';
import { CertificateViewer } from '../components/security/CertificateViewer';
import { BackendUnavailable } from '../components/common/BackendUnavailable';
import { ApiError } from '../services/api';

export const DocumentDetails: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { role, user } = useAuth();

  const [document, setDocument] = useState<DocType | null>(null);
  const [caseItem, setCaseItem] = useState<Case | null>(null);
  const [loading, setLoading] = useState<boolean>(true);
  const [copied, setCopied] = useState<boolean>(false);
  const [isCertModalOpen, setIsCertModalOpen] = useState(false);

  const [backendError, setBackendError] = useState<{
    status: number;
    endpoint: string;
    message: string;
  } | null>(null);

  // Real ChainDock security state
  const [signatures, setSignatures] = useState<DocumentSignature[]>([]);
  const [verifyResult, setVerifyResult] =
    useState<SignatureVerifyResult | null>(null);
  const [integrityResult, setIntegrityResult] =
    useState<IntegrityCheckResult | null>(null);

  const [verifying, setVerifying] = useState(false);
  const [signingInProgress, setSigningInProgress] = useState(false);
  const [signingError, setSigningError] = useState<string | null>(null);
  const [signingSuccess, setSigningSuccess] = useState(false);

  const fetchDocument = async () => {
    if (!id) return;

    try {
      setLoading(true);
      setBackendError(null);

      const doc = await documentsService.getDocumentById(id);

      if (doc) {
        setDocument(doc);

        if (doc.case_id) {
          casesService
            .getCaseById(doc.case_id)
            .then((c) => setCaseItem(c || null))
            .catch(() => {});
        }

        // Real API signature retrieval
        securityService
          .getDocumentSignatures(id)
          .then((sigs) => setSignatures(sigs))
          .catch(() => {});
      }
    } catch (err: unknown) {
      if (err instanceof ApiError) {
        setBackendError({
          status: err.status,
          endpoint: err.endpoint,
          message: err.message,
        });
      } else {
        setBackendError({
          status: 0,
          endpoint: `/documents/${id}`,
          message: (err as Error).message,
        });
      }
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchDocument();
  }, [id]);

  const handleSignDocument = async () => {
    if (!document) return;

    setSigningInProgress(true);
    setSigningError(null);
    setSigningSuccess(false);

    try {
      const sig = await securityService.signDocument(document.id);

      setSignatures((prev) => [sig, ...prev]);
      setSigningSuccess(true);

      // Refresh document to obtain updated blockchain transaction data.
      const updated = await documentsService.getDocumentById(document.id);

      if (updated) {
        setDocument(updated);
      }
    } catch (err: any) {
      setSigningError(err?.message || 'Signing failed');
    } finally {
      setSigningInProgress(false);
    }
  };

  const handleVerifySignature = async () => {
    if (!document) return;

    setVerifying(true);
    setVerifyResult(null);
    setIntegrityResult(null);

    try {
      const [vr, ir] = await Promise.all([
        securityService.verifyDocumentSignature(document.id),
        securityService.verifyDocumentIntegrity(document.id),
      ]);

      setVerifyResult(vr);
      setIntegrityResult(ir);
    } catch (err: any) {
      setVerifyResult(null);
    } finally {
      setVerifying(false);
    }
  };

  const copyHash = () => {
    if (!document) return;

    navigator.clipboard.writeText(document.sha256);
    setCopied(true);

    setTimeout(() => setCopied(false), 2000);
  };

  if (loading) {
    return (
      <AppShell>
        <div className="min-h-[60vh] flex items-center justify-center">
          <div className="text-center">
            <div className="w-10 h-10 border-4 border-blue-100 border-t-blue-800 rounded-full animate-spin mx-auto mb-4" />

            <h2 className="text-sm font-bold text-slate-800">
              Loading document record
            </h2>

            <p className="text-xs text-slate-500 mt-1">
              Retrieving document data and security information...
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
          moduleName="Document Record Inspection"
          endpoint={backendError.endpoint}
          status={backendError.status}
          errorMessage={backendError.message}
          onRetry={fetchDocument}
        />
      </AppShell>
    );
  }

  if (!document) {
    return (
      <AppShell>
        <div className="max-w-lg mx-auto my-12 bg-white rounded-xl border border-slate-200 shadow-sm p-10 text-center">
          <div className="w-14 h-14 mx-auto rounded-full bg-amber-50 text-amber-700 flex items-center justify-center">
            <svg
              className="w-7 h-7"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M12 9v3m0 4h.01M10.29 3.86L2.82 17a2 2 0 001.74 3h14.88a2 2 0 001.74-3L13.71 3.86a2 2 0 00-3.42 0z"
              />
            </svg>
          </div>

          <h2 className="text-lg font-black text-slate-900 mt-4">
            Document Not Found
          </h2>

          <p className="text-sm text-slate-500 mt-2">
            The requested document record could not be found in the repository.
          </p>

          <button
            onClick={() => navigate('/documents')}
            className="mt-5 px-5 py-2.5 bg-blue-800 text-white text-sm font-bold rounded-lg hover:bg-blue-900 transition"
          >
            Return to Documents
          </button>
        </div>
      </AppShell>
    );
  }

  // Prefer the real integrity verification result.
  const isTampered = integrityResult
    ? !integrityResult.integrity_match
    : document.is_tampered ||
      document.integrity_status === 'TAMPERED';

  const isInvestigator = role === 'INVESTIGATOR';
  const hasSigned = signatures.length > 0;
  // Check if the current user has already signed this document
  const currentUserSigned = signatures.some(
    (s: any) => s.signer_id === user?.id || s.signer_email === user?.email
  );
  return (
    <AppShell>
      <div className="flex flex-col gap-6 max-w-[1520px] mx-auto">
        {/* ============================================================
            HEADER / BREADCRUMB
        ============================================================ */}
        <section className="flex flex-col lg:flex-row lg:items-center lg:justify-between gap-4">
          <div>
            <div className="flex items-center gap-2 text-xs mb-2">
              <button
                onClick={() => navigate('/documents')}
                className="text-blue-800 font-bold hover:text-blue-950 flex items-center gap-1"
              >
                <svg
                  className="w-4 h-4"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M15 19l-7-7 7-7"
                  />
                </svg>
                Documents
              </button>

              <span className="text-slate-300">/</span>

              <span className="font-mono text-slate-500 truncate max-w-xs">
                {document.case_number || document.case_id}
              </span>

              <span className="text-slate-300">/</span>

              <span className="font-mono font-bold text-slate-700 truncate max-w-sm">
                {document.id}
              </span>
            </div>

            <div className="flex items-center gap-3">
              <div className="w-11 h-11 rounded-xl bg-blue-900 text-white flex items-center justify-center shadow-sm">
                <svg
                  className="w-6 h-6"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a2 2 0 011.414.586l4.414 4.414A2 2 0 0119 9v10a2 2 0 01-2 2z"
                  />
                </svg>
              </div>

              <div>
                <p className="text-[11px] font-bold uppercase tracking-[0.16em] text-blue-700">
                  pramāṇa-kośa
                </p>

                <h1 className="text-2xl sm:text-3xl font-black text-slate-900">
                  Document Record
                </h1>
              </div>
            </div>
          </div>

          <div className="flex flex-wrap items-center gap-2">
            {isInvestigator && (
              <button
                onClick={handleSignDocument}
                disabled={signingInProgress || currentUserSigned}
                className="px-4 py-2.5 bg-blue-800 text-white hover:bg-blue-900 disabled:opacity-50 disabled:cursor-not-allowed rounded-lg text-xs font-bold flex items-center gap-2 shadow-sm transition"
              >
                <svg
                  className={`w-4 h-4 ${signingInProgress ? 'animate-spin' : ''}`}
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M15.5 5.5a2.121 2.121 0 013 3L9 18l-4 1 1-4 9.5-9.5z"
                  />
                </svg>
                {signingInProgress
                  ? 'Signing...'
                  : currentUserSigned
                  ? 'Already Signed'
                  : 'Sign Document'}
              </button>
            )}

            <button
              onClick={() => setIsCertModalOpen(true)}
              className="px-4 py-2.5 bg-slate-900 text-white hover:bg-slate-800 rounded-lg text-xs font-bold flex items-center gap-2 shadow-sm transition"
            >
              <svg
                className="w-4 h-4"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 3c-2.755 0-5.28.925-7.31 2.484A11.953 11.953 0 002 12c0 4.478 2.364 8.404 6 10.392"
                />
              </svg>

              View Certificate
            </button>
          </div>
        </section>

        {/* ============================================================
            SECURITY FEEDBACK
        ============================================================ */}
        {signingSuccess && (
          <div className="rounded-xl border border-emerald-200 bg-emerald-50 px-4 py-3 flex items-start gap-3">
            <div className="w-8 h-8 rounded-lg bg-emerald-100 text-emerald-700 flex items-center justify-center shrink-0">
              <svg
                className="w-4 h-4"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M5 13l4 4L19 7"
                />
              </svg>
            </div>

            <div>
              <p className="text-sm font-bold text-emerald-900">
                Document signed successfully
              </p>

              <p className="text-xs text-emerald-700 mt-0.5">
                The ChainDock signing operation completed successfully and the
                document record has been refreshed.
              </p>
            </div>
          </div>
        )}

        {signingError && (
          <div className="rounded-xl border border-red-200 bg-red-50 px-4 py-3 flex items-start gap-3">
            <div className="w-8 h-8 rounded-lg bg-red-100 text-red-700 flex items-center justify-center shrink-0">
              <svg
                className="w-4 h-4"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M12 8v4m0 4h.01M10.29 3.86L2.82 17a2 2 0 001.74 3h14.88a2 2 0 001.74-3L13.71 3.86a2 2 0 00-3.42 0z"
                />
              </svg>
            </div>

            <div>
              <p className="text-sm font-bold text-red-900">
                Document signing failed
              </p>

              <p className="text-xs text-red-700 mt-0.5">
                {signingError}
              </p>
            </div>
          </div>
        )}

        {/* ============================================================
            DOCUMENT SUMMARY
        ============================================================ */}
        <section className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
          <div className="bg-slate-900 px-5 py-4 text-white">
            <div className="flex flex-col lg:flex-row lg:items-center lg:justify-between gap-4">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-lg bg-blue-800 flex items-center justify-center">
                  <svg
                    className="w-5 h-5"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      strokeWidth={2}
                      d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a2 2 0 011.414.586l4.414 4.414A2 2 0 0119 9v10a2 2 0 01-2 2z"
                    />
                  </svg>
                </div>

                <div>
                  <p className="text-[10px] uppercase tracking-[0.18em] text-blue-200 font-bold">
                    Digital Evidence Record
                  </p>

                  <h2 className="text-base sm:text-lg font-black mt-0.5">
                    {document.title}
                  </h2>
                </div>
              </div>

              <div
                className={`inline-flex items-center gap-2 px-3 py-2 rounded-lg text-xs font-black border ${
                  isTampered
                    ? 'bg-red-500/20 border-red-400 text-red-200'
                    : 'bg-emerald-500/20 border-emerald-400 text-emerald-200'
                }`}
              >
                <span
                  className={`w-2.5 h-2.5 rounded-full ${
                    isTampered
                      ? 'bg-red-400'
                      : 'bg-emerald-400'
                  }`}
                />

                {isTampered
                  ? 'INTEGRITY BREACH DETECTED'
                  : 'INTEGRITY VERIFIED'}
              </div>
            </div>
          </div>

          <div className="p-5 grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-4">
            <div>
              <p className="text-[10px] uppercase tracking-wider font-bold text-slate-400">
                Case
              </p>
              <p className="text-sm font-bold text-slate-800 mt-1 break-words">
                {caseItem?.title ||
                  document.case_number ||
                  document.case_id}
              </p>
            </div>

            <div>
              <p className="text-[10px] uppercase tracking-wider font-bold text-slate-400">
                Document Type
              </p>
              <p className="text-sm font-bold text-slate-800 mt-1">
                {document.document_type}
              </p>
            </div>

            <div>
              <p className="text-[10px] uppercase tracking-wider font-bold text-slate-400">
                Version
              </p>
              <p className="text-sm font-bold text-slate-800 mt-1">
                v{document.version}.0
              </p>
            </div>

            <div>
              <p className="text-[10px] uppercase tracking-wider font-bold text-slate-400">
                File Type
              </p>
              <p className="text-sm font-bold text-slate-800 mt-1">
                {document.file_type || 'Not specified'}
              </p>
            </div>
          </div>
        </section>

        {/* ============================================================
            MAIN CONTENT
        ============================================================ */}
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 items-start">
          {/* ==========================================================
              LEFT COLUMN
          ========================================================== */}
          <div className="lg:col-span-8 flex flex-col gap-5">
            {/* Document Description */}
            <section className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
              <div className="px-5 py-4 border-b border-slate-200 flex items-center justify-between">
                <div>
                  <h2 className="text-base font-black text-slate-900">
                    Document Information
                  </h2>

                  <p className="text-xs text-slate-500 mt-1">
                    Official record information associated with this document.
                  </p>
                </div>

                <span className="hidden sm:inline-flex px-2.5 py-1 rounded-md bg-blue-50 text-blue-800 text-[10px] font-black uppercase">
                  Case Record
                </span>
              </div>

              <div className="p-5">
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 mb-5">
                  <div className="rounded-lg bg-slate-50 border border-slate-200 p-4">
                    <p className="text-[10px] uppercase tracking-wider font-bold text-slate-400">
                      Document ID
                    </p>

                    <p className="font-mono text-xs font-bold text-slate-800 mt-2 break-all">
                      {document.id}
                    </p>
                  </div>

                  <div className="rounded-lg bg-slate-50 border border-slate-200 p-4">
                    <p className="text-[10px] uppercase tracking-wider font-bold text-slate-400">
                      Case Reference
                    </p>

                    <p className="font-mono text-xs font-bold text-slate-800 mt-2 break-all">
                      {document.case_number || document.case_id}
                    </p>
                  </div>
                </div>

                <div>
                  <h3 className="text-xs font-black uppercase tracking-wider text-slate-700 mb-2">
                    Description
                  </h3>

                  <div className="rounded-lg border border-slate-200 bg-slate-50 p-4">
                    <p className="text-sm text-slate-700 leading-7 whitespace-pre-wrap">
                      {document.description ||
                        'No description provided for this document.'}
                    </p>
                  </div>
                </div>
              </div>
            </section>

            {/* OCR */}
            <section className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
              <div className="px-5 py-4 border-b border-slate-200 flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2">
                <div>
                  <h2 className="text-base font-black text-slate-900">
                    OCR Extracted Text
                  </h2>

                  <p className="text-xs text-slate-500 mt-1">
                    Text extracted from the stored digital document.
                  </p>
                </div>

                <span className="inline-flex w-fit px-2.5 py-1 rounded-md bg-slate-100 text-slate-700 text-[10px] font-black uppercase">
                  {document.ocr_status}
                </span>
              </div>

              <div className="p-5">
                <div className="max-h-96 overflow-auto rounded-lg border border-slate-200 bg-slate-50 p-4">
                  <p className="whitespace-pre-wrap text-sm leading-7 text-slate-700">
                    {document.extracted_text ||
                      document.ocr_error ||
                      'No OCR text available.'}
                  </p>
                </div>
              </div>
            </section>

            {/* ChainDock Security Information */}
            <section className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
              <div className="px-5 py-4 bg-blue-50 border-b border-blue-100">
                <div className="flex items-center gap-3">
                  <div className="w-9 h-9 rounded-lg bg-blue-800 text-white flex items-center justify-center">
                    <svg
                      className="w-5 h-5"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeWidth={2}
                        d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"
                      />
                    </svg>
                  </div>

                  <div>
                    <h2 className="text-sm font-black text-slate-900">
                      ChainDock Security Layer
                    </h2>

                    <p className="text-xs text-slate-500 mt-0.5">
                      Cryptographic integrity, signatures and audit protection
                      for this record.
                    </p>
                  </div>
                </div>
              </div>

              <div className="p-5 grid grid-cols-1 sm:grid-cols-3 gap-4">
                <div className="rounded-lg border border-slate-200 p-4">
                  <p className="text-[10px] uppercase tracking-wider font-bold text-slate-400">
                    Hashing
                  </p>

                  <p className="text-sm font-black text-slate-800 mt-1">
                    SHA-256
                  </p>
                </div>

                <div className="rounded-lg border border-slate-200 p-4">
                  <p className="text-[10px] uppercase tracking-wider font-bold text-slate-400">
                    Digital Signatures
                  </p>

                  <p className="text-sm font-black text-slate-800 mt-1">
                    Ed25519
                  </p>
                </div>

                <div className="rounded-lg border border-slate-200 p-4">
                  <p className="text-[10px] uppercase tracking-wider font-bold text-slate-400">
                    Signatures Stored
                  </p>

                  <p className="text-sm font-black text-slate-800 mt-1">
                    {signatures.length}
                  </p>
                </div>
              </div>
            </section>
          </div>

          {/* ==========================================================
              RIGHT COLUMN
          ========================================================== */}
          <div className="lg:col-span-4 flex flex-col gap-5">
            {/* Integrity Status */}
            <section
              className={`rounded-xl shadow-sm overflow-hidden border ${
                isTampered
                  ? 'bg-red-950 border-red-900'
                  : 'bg-slate-900 border-slate-950'
              }`}
            >
              <div className="p-5">
                <div className="flex items-start gap-3">
                  <div
                    className={`w-11 h-11 rounded-xl flex items-center justify-center shrink-0 ${
                      isTampered
                        ? 'bg-red-600 text-white'
                        : 'bg-emerald-500/20 text-emerald-300'
                    }`}
                  >
                    <svg
                      className="w-6 h-6"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      {isTampered ? (
                        <path
                          strokeLinecap="round"
                          strokeLinejoin="round"
                          strokeWidth={2}
                          d="M12 9v3m0 4h.01M10.29 3.86L2.82 17a2 2 0 001.74 3h14.88a2 2 0 001.74-3L13.71 3.86a2 2 0 00-3.42 0z"
                        />
                      ) : (
                        <path
                          strokeLinecap="round"
                          strokeLinejoin="round"
                          strokeWidth={2}
                          d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 3c-2.755 0-5.28.925-7.31 2.484A11.953 11.953 0 002 12c0 4.478 2.364 8.404 6 10.392"
                        />
                      )}
                    </svg>
                  </div>

                  <div>
                    <p className="text-[10px] uppercase tracking-[0.18em] font-bold text-slate-400">
                      Cryptographic Integrity
                    </p>

                    <h2 className="text-base font-black text-white mt-1">
                      {isTampered
                        ? 'INTEGRITY COMPROMISED'
                        : 'INTEGRITY VERIFIED'}
                    </h2>
                  </div>
                </div>

                {integrityResult && (
                  <div className="mt-5 space-y-2 text-[11px] font-mono">
                    <div className="rounded-lg bg-white/5 border border-white/10 p-3">
                      <p className="text-slate-400 mb-1">
                        Stored Hash
                      </p>
                      <p className="text-slate-200 break-all">
                        {integrityResult.original_hash}
                      </p>
                    </div>

                    <div className="rounded-lg bg-white/5 border border-white/10 p-3">
                      <p className="text-slate-400 mb-1">
                        Current Hash
                      </p>
                      <p className="text-slate-200 break-all">
                        {integrityResult.current_hash}
                      </p>
                    </div>

                    <div
                      className={`rounded-lg p-3 font-black ${
                        integrityResult.integrity_match
                          ? 'bg-emerald-500/10 text-emerald-300'
                          : 'bg-red-500/10 text-red-300'
                      }`}
                    >
                      {integrityResult.integrity_match
                        ? '✓ HASH MATCH — RECORD INTEGRITY CONFIRMED'
                        : '✕ HASH MISMATCH — FILE MODIFICATION DETECTED'}
                    </div>
                  </div>
                )}
              </div>
            </section>

            {/* SHA-256 */}
            <section className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
              <div className="px-4 py-4 border-b border-slate-200">
                <div className="flex items-center gap-2">
                  <div className="w-8 h-8 rounded-lg bg-blue-50 text-blue-800 flex items-center justify-center">
                    <span className="text-sm font-black">#</span>
                  </div>

                  <div>
                    <h3 className="text-sm font-black text-slate-900">
                      SHA-256 Checksum
                    </h3>

                    <p className="text-[10px] text-slate-500 mt-0.5">
                      Cryptographic document fingerprint
                    </p>
                  </div>
                </div>
              </div>

              <div className="p-4">
                <div className="rounded-lg bg-slate-50 border border-slate-200 p-3">
                  <p className="font-mono text-[11px] leading-5 break-all text-slate-700">
                    {document.sha256}
                  </p>

                  <div className="mt-3 pt-3 border-t border-slate-200 flex justify-end">
                    <button
                      onClick={copyHash}
                      className="inline-flex items-center gap-1.5 text-xs font-bold text-blue-800 hover:text-blue-950"
                    >
                      <svg
                        className="w-4 h-4"
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                      >
                        <path
                          strokeLinecap="round"
                          strokeLinejoin="round"
                          strokeWidth={2}
                          d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2M10 20h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"
                        />
                      </svg>

                      {copied ? 'Copied!' : 'Copy Hash'}
                    </button>
                  </div>
                </div>
              </div>
            </section>

            {/* Signatures */}
            <section className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
              <div className="px-4 py-4 border-b border-slate-200">
                <div className="flex items-center justify-between gap-3">
                  <div>
                    <h3 className="text-sm font-black text-slate-900">
                      Digital Signatures
                    </h3>

                    <p className="text-[10px] text-slate-500 mt-0.5">
                      ChainDock signature verification
                    </p>
                  </div>

                  <span
                    className={`px-2 py-1 rounded-md text-[10px] font-black ${
                      hasSigned
                        ? 'bg-emerald-50 text-emerald-700'
                        : 'bg-amber-50 text-amber-700'
                    }`}
                  >
                    {hasSigned
                      ? `SIGNED (${signatures.length})`
                      : 'UNSIGNED'}
                  </span>
                </div>
              </div>

              <div className="p-4">
                {signatures.length > 0 ? (
                  <div className="space-y-3">
                    {signatures.map((sig) => (
                      <div
                        key={sig.signature_id}
                        className="rounded-lg border border-slate-200 bg-slate-50 p-3"
                      >
                        <div className="flex items-start justify-between gap-3">
                          <div className="min-w-0">
                            <p className="text-xs font-bold text-slate-800 break-all">
                              {sig.signer_email}
                            </p>
                          </div>

                          <span
                            className={`shrink-0 px-1.5 py-0.5 rounded text-[9px] font-black ${
                              sig.verification_status === 'VALID'
                                ? 'bg-emerald-100 text-emerald-800'
                                : 'bg-red-100 text-red-800'
                            }`}
                          >
                            {sig.verification_status}
                          </span>
                        </div>

                        <div className="mt-2 space-y-1">
                          <p className="text-[10px] font-mono text-slate-500 break-all">
                            Fingerprint: {sig.fingerprint}
                          </p>

                          <p className="text-[10px] text-slate-500">
                            {new Date(sig.signed_at).toLocaleString()}
                          </p>
                        </div>
                      </div>
                    ))}
                  </div>
                ) : (
                  <div className="rounded-lg bg-slate-50 border border-dashed border-slate-300 p-5 text-center">
                    <p className="text-xs font-semibold text-slate-500">
                      No digital signatures are currently associated with this
                      document.
                    </p>
                  </div>
                )}

                <button
                  onClick={handleVerifySignature}
                  disabled={verifying}
                  className="mt-4 w-full py-2.5 px-3 rounded-lg bg-blue-800 text-white hover:bg-blue-900 disabled:opacity-50 text-xs font-bold flex items-center justify-center gap-2 transition shadow-sm"
                >
                  <svg
                    className={`w-4 h-4 ${
                      verifying ? 'animate-spin' : ''
                    }`}
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      strokeWidth={2}
                      d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 3c-2.755 0-5.28.925-7.31 2.484A11.953 11.953 0 002 12c0 4.478 2.364 8.404 6 10.392"
                    />
                  </svg>

                  {verifying
                    ? 'Verifying...'
                    : 'Verify Integrity & Signatures'}
                </button>

                {/* Verification Result */}
                {verifyResult && (
                  <div className="mt-4 space-y-2">
                    <div
                      className={`rounded-lg p-3 text-center text-xs font-bold border ${
                        verifyResult.overall_valid
                          ? 'bg-emerald-50 text-emerald-800 border-emerald-200'
                          : 'bg-red-50 text-red-800 border-red-200'
                      }`}
                    >
                      {verifyResult.overall_valid
                        ? '✓ All signatures valid — integrity confirmed'
                        : '✕ Signature verification failed'}
                    </div>

                    {verifyResult.signatures.map((s) => (
                      <div
                        key={s.signature_id}
                        className={`rounded-lg p-3 text-[10px] border ${
                          s.verification_status === 'VALID'
                            ? 'bg-emerald-50 border-emerald-200'
                            : 'bg-red-50 border-red-200'
                        }`}
                      >
                        <p className="font-bold text-slate-800">
                          {s.signer_email} — {s.verification_status}
                        </p>

                        <p className="text-slate-500 mt-1">
                          {s.verification_detail}
                        </p>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </section>

            {/* Blockchain Record */}
            {(document as any).blockchain_tx_id && (
              <section className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
                <div className="px-4 py-4 border-b border-slate-200">
                  <div className="flex items-center gap-2">
                    <div className="w-8 h-8 rounded-lg bg-indigo-50 text-indigo-800 flex items-center justify-center">
                      <svg
                        className="w-4 h-4"
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                      >
                        <path
                          strokeLinecap="round"
                          strokeLinejoin="round"
                          strokeWidth={2}
                          d="M12 2v20M2 12h20M5 5l14 14M19 5L5 19"
                        />
                      </svg>
                    </div>

                    <div>
                      <h3 className="text-sm font-black text-slate-900">
                        Blockchain Record
                      </h3>

                      <p className="text-[10px] text-slate-500 mt-0.5">
                        ChainDock ledger transaction reference
                      </p>
                    </div>
                  </div>
                </div>

                <div className="p-4">
                  <div className="rounded-lg bg-slate-50 border border-slate-200 p-3">
                    <p className="text-[10px] uppercase tracking-wider font-bold text-slate-400 mb-1">
                      Transaction
                    </p>

                    <p className="font-mono text-[11px] text-slate-700 break-all">
                      {(document as any).blockchain_tx_hash ||
                        (document as any).blockchain_tx_id}
                    </p>
                  </div>
                </div>
              </section>
            )}
          </div>
        </div>
      </div>

      {/* Certificate Modal */}
      {isCertModalOpen && (
        <CertificateViewer
          isOpen={isCertModalOpen}
          onClose={() => setIsCertModalOpen(false)}
          document={document}
        />
      )}
    </AppShell>
  );
};

export default DocumentDetails;
