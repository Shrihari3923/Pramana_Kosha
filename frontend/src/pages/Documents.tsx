import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { AppShell } from '../components/layout/AppShell';
import { DocumentList } from '../components/documents/DocumentList';
import { DocumentUpload } from '../components/documents/DocumentUpload';
import { documentsService } from '../services/documents';
import { casesService } from '../services/cases';
import { Document as DocType } from '../types';
import { BackendUnavailable } from '../components/common/BackendUnavailable';
import { ApiError } from '../services/api';

export const Documents: React.FC = () => {
  const navigate = useNavigate();

  const [documents, setDocuments] = useState<DocType[]>([]);
  const [activeCaseId, setActiveCaseId] = useState<string>('cd-case-0412');
  const [loading, setLoading] = useState<boolean>(true);
  const [backendError, setBackendError] = useState<{
    status: number;
    endpoint: string;
    message: string;
  } | null>(null);

  const [searchQuery, setSearchQuery] = useState('');
  const [typeFilter, setTypeFilter] = useState<string>('ALL');
  const [isUploadOpen, setIsUploadOpen] = useState(false);

  const fetchDocuments = async () => {
    try {
      setLoading(true);
      setBackendError(null);

      const docs = await documentsService.getDocuments();
      setDocuments(docs);
    } catch (err: unknown) {
      console.error('Failed to load documents:', err);

      if (err instanceof ApiError) {
        setBackendError({
          status: err.status,
          endpoint: err.endpoint,
          message: err.message,
        });
      } else {
        setBackendError({
          status: 0,
          endpoint: '/documents',
          message: (err as Error).message,
        });
      }
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchDocuments();

    casesService
      .getCases()
      .then((list) => {
        if (list && list.length > 0 && list[0]?.id) {
          setActiveCaseId(list[0].id);
        }
      })
      .catch(() => {});
  }, []);

  const handleUploadComplete = async (
    caseId: string,
    file: File,
    metadata: {
      title: string;
      documentType: string;
      description: string;
      uploadedBy: string;
    }
  ) => {
    await documentsService.uploadDocument(caseId, file, metadata);

    setIsUploadOpen(false);
    await fetchDocuments();
  };

  const filteredDocs = documents.filter((doc) => {
    const q = searchQuery.toLowerCase().trim();

    const titleMatch = (doc.title || '').toLowerCase().includes(q);
    const hashMatch = (doc.sha256 || '').toLowerCase().includes(q);
    const typeMatch = (doc.file_type || '').toLowerCase().includes(q);
    const caseNumMatch = (doc.case_number || '').toLowerCase().includes(q);
    const caseIdMatch = (doc.case_id || '').toLowerCase().includes(q);

    const matchesSearch =
      !q ||
      titleMatch ||
      hashMatch ||
      typeMatch ||
      caseNumMatch ||
      caseIdMatch;

    const matchesType =
      typeFilter === 'ALL' ||
      (doc.document_type || '')
        .toUpperCase()
        .includes(typeFilter);

    return matchesSearch && matchesType;
  });

  const totalDocuments = documents.length;

  const firCount = documents.filter((doc) =>
    (doc.document_type || '').toUpperCase().includes('FIR')
  ).length;

  const tamperedCount = documents.filter(
    (doc) => doc.is_tampered === true
  ).length;

  const verifiedCount = documents.filter(
    (doc) => doc.is_tampered !== true
  ).length;

  return (
    <AppShell>
      {/* Page Header */}
      <section className="space-y-5">
        <div className="flex flex-col xl:flex-row xl:items-center xl:justify-between gap-4">
          <div>
            <div className="flex items-center gap-3 mb-2">
              <div className="h-10 w-10 rounded-xl bg-blue-900 text-white flex items-center justify-center shadow-sm">
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
                <p className="text-xs font-bold tracking-[0.18em] text-blue-700 uppercase">
                  pramāṇa-kośa
                </p>

                <h1 className="text-2xl sm:text-3xl font-black text-slate-900">
                  FIR & Digital Document Repository
                </h1>
              </div>
            </div>

            <p className="text-sm text-slate-500 max-w-3xl">
              Secure repository for FIRs, investigation records, forensic
              reports, witness statements, seizure documents and other
              case-related digital evidence.
            </p>
          </div>

          <div className="flex flex-wrap items-center gap-3">
            <button
              onClick={fetchDocuments}
              disabled={loading}
              className="inline-flex items-center gap-2 px-4 py-2.5 rounded-lg border border-slate-300 bg-white text-slate-700 font-semibold text-sm hover:bg-slate-50 transition disabled:opacity-50"
            >
              <svg
                className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`}
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M4 4v5h.582M20 20v-5h-.581M5.635 9A7.5 7.5 0 0118.365 7M18.365 15A7.5 7.5 0 015.635 17"
                />
              </svg>
              Refresh Repository
            </button>

            <button
              onClick={() => setIsUploadOpen(true)}
              className="inline-flex items-center gap-2 px-4 py-2.5 rounded-lg bg-blue-800 text-white font-bold text-sm shadow-sm hover:bg-blue-900 transition"
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
                  d="M12 4v16m8-8H4"
                />
              </svg>
              Deposit Document
            </button>
          </div>
        </div>

        {/* Security / ChainDock Banner */}
        <div className="rounded-xl border border-blue-200 bg-white shadow-sm overflow-hidden">
          <div className="px-5 py-4 flex flex-col md:flex-row md:items-center md:justify-between gap-4">
            <div className="flex items-start gap-3">
              <div className="mt-0.5 h-9 w-9 rounded-lg bg-blue-50 text-blue-800 flex items-center justify-center">
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
                <p className="text-sm font-bold text-slate-900">
                  ChainDock Evidence Protection
                </p>
                <p className="text-xs text-slate-500 mt-0.5">
                  Document records remain connected to the existing ChainDock
                  security, audit and integrity infrastructure.
                </p>
              </div>
            </div>

            <div className="flex items-center gap-2 text-xs font-bold text-emerald-700">
              <span className="h-2.5 w-2.5 rounded-full bg-emerald-500" />
              SECURE REPOSITORY
            </div>
          </div>
        </div>
      </section>

      {/* Repository Statistics */}
      <section className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-4">
        {/* Total */}
        <div className="bg-white border border-slate-200 rounded-xl p-5 shadow-sm">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-xs font-bold uppercase tracking-wider text-slate-500">
                Total Records
              </p>
              <p className="text-3xl font-black text-slate-900 mt-2">
                {totalDocuments}
              </p>
              <p className="text-xs text-slate-500 mt-1">
                Digital documents
              </p>
            </div>

            <div className="h-11 w-11 rounded-xl bg-slate-100 text-slate-700 flex items-center justify-center">
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
                  d="M7 7h10M7 11h10M7 15h6M5 3h10l4 4v14H5V3z"
                />
              </svg>
            </div>
          </div>
        </div>

        {/* FIR */}
        <div className="bg-white border border-slate-200 rounded-xl p-5 shadow-sm">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-xs font-bold uppercase tracking-wider text-slate-500">
                FIR Records
              </p>
              <p className="text-3xl font-black text-blue-800 mt-2">
                {firCount}
              </p>
              <p className="text-xs text-slate-500 mt-1">
                First Information Reports
              </p>
            </div>

            <div className="h-11 w-11 rounded-xl bg-blue-50 text-blue-800 flex items-center justify-center">
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
          </div>
        </div>

        {/* Verified */}
        <div className="bg-white border border-slate-200 rounded-xl p-5 shadow-sm">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-xs font-bold uppercase tracking-wider text-slate-500">
                Integrity Clear
              </p>
              <p className="text-3xl font-black text-emerald-700 mt-2">
                {verifiedCount}
              </p>
              <p className="text-xs text-slate-500 mt-1">
                Records without tamper flag
              </p>
            </div>

            <div className="h-11 w-11 rounded-xl bg-emerald-50 text-emerald-700 flex items-center justify-center">
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
                  d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 3c-2.755 0-5.28.925-7.31 2.484A11.953 11.953 0 002 12c0 4.478 2.364 8.404 6 10.392M17 20l2 2 4-4"
                />
              </svg>
            </div>
          </div>
        </div>

        {/* Tampered */}
        <div
          className={`bg-white border rounded-xl p-5 shadow-sm ${
            tamperedCount > 0
              ? 'border-red-200'
              : 'border-slate-200'
          }`}
        >
          <div className="flex items-center justify-between">
            <div>
              <p className="text-xs font-bold uppercase tracking-wider text-slate-500">
                Integrity Alerts
              </p>

              <p
                className={`text-3xl font-black mt-2 ${
                  tamperedCount > 0
                    ? 'text-red-700'
                    : 'text-slate-900'
                }`}
              >
                {tamperedCount}
              </p>

              <p className="text-xs text-slate-500 mt-1">
                Records flagged as tampered
              </p>
            </div>

            <div
              className={`h-11 w-11 rounded-xl flex items-center justify-center ${
                tamperedCount > 0
                  ? 'bg-red-50 text-red-700'
                  : 'bg-slate-100 text-slate-600'
              }`}
            >
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
                  d="M12 9v3.5m0 3.5h.01M10.29 3.86L2.82 17a2 2 0 001.74 3h14.88a2 2 0 001.74-3L13.71 3.86a2 2 0 00-3.42 0z"
                />
              </svg>
            </div>
          </div>
        </div>
      </section>

      {/* Repository Controls */}
      <section className="bg-white border border-slate-200 rounded-xl shadow-sm">
        <div className="p-5 border-b border-slate-200">
          <div className="flex flex-col lg:flex-row lg:items-center lg:justify-between gap-4">
            <div>
              <h2 className="text-lg font-black text-slate-900">
                Document Repository
              </h2>
              <p className="text-sm text-slate-500 mt-1">
                Search and filter case documentation stored in the backend.
              </p>
            </div>

            <div className="text-xs font-semibold text-slate-500">
              Showing{' '}
              <span className="text-slate-900 font-black">
                {filteredDocs.length}
              </span>{' '}
              of{' '}
              <span className="text-slate-900 font-black">
                {documents.length}
              </span>{' '}
              records
            </div>
          </div>
        </div>

        <div className="p-5 bg-slate-50/70">
          <div className="flex flex-col lg:flex-row gap-3">
            {/* Search */}
            <div className="relative flex-1">
              <svg
                className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M21 21l-4.35-4.35m1.35-5.15a6.5 6.5 0 11-13 0 6.5 6.5 0 0113 0z"
                />
              </svg>

              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Search title, case number, file type or SHA-256 hash..."
                className="w-full pl-10 pr-4 py-2.5 rounded-lg border border-slate-300 bg-white text-sm text-slate-900 placeholder-slate-400 outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              />
            </div>

            {/* Type Filter */}
            <select
              value={typeFilter}
              onChange={(e) => setTypeFilter(e.target.value)}
              className="lg:w-64 px-4 py-2.5 rounded-lg border border-slate-300 bg-white text-sm font-semibold text-slate-700 outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            >
              <option value="ALL">All Document Types</option>
              <option value="FIR">FIR</option>
              <option value="CHARGE">Charge Sheet</option>
              <option value="CFSL">CFSL / Forensic</option>
              <option value="WITNESS">Witness Statement</option>
              <option value="SEIZURE">Seizure Memo</option>
            </select>

            {(searchQuery || typeFilter !== 'ALL') && (
              <button
                onClick={() => {
                  setSearchQuery('');
                  setTypeFilter('ALL');
                }}
                className="px-4 py-2.5 rounded-lg border border-slate-300 bg-white text-sm font-semibold text-slate-600 hover:bg-slate-100 transition"
              >
                Clear
              </button>
            )}
          </div>
        </div>
      </section>

      {/* Backend Error */}
      {backendError && (
       <BackendUnavailable
  moduleName="Document Management"
  endpoint={backendError.endpoint}
  status={backendError.status}
  errorMessage={backendError.message}
  onRetry={fetchDocuments}
/>
      )}

      {/* Loading State */}
      {loading ? (
        <section className="bg-white border border-slate-200 rounded-xl shadow-sm p-10">
          <div className="flex flex-col items-center justify-center text-center">
            <div className="h-10 w-10 border-4 border-blue-100 border-t-blue-800 rounded-full animate-spin" />

            <h3 className="mt-4 text-sm font-bold text-slate-800">
              Loading document repository
            </h3>

            <p className="mt-1 text-xs text-slate-500">
              Retrieving records from the ChainDock backend...
            </p>
          </div>
        </section>
      ) : (
        <>
          {/* Document List */}
          <section className="bg-white border border-slate-200 rounded-xl shadow-sm overflow-hidden">
            <div className="px-5 py-4 border-b border-slate-200 flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
              <div>
                <h3 className="font-black text-slate-900">
                  Case Documents
                </h3>
                <p className="text-xs text-slate-500 mt-1">
                  Select a document to view its complete record and integrity
                  information.
                </p>
              </div>

              <div className="inline-flex items-center gap-2 text-xs font-bold text-slate-600">
                <span className="h-2 w-2 rounded-full bg-blue-700" />
                ChainDock repository
              </div>
            </div>

            <div className="p-4 sm:p-5">
              {filteredDocs.length > 0 ? (
                <DocumentList
                  documents={filteredDocs}
                  onSelect={(doc) => navigate(`/documents/${doc.id}`)}
                />
              ) : (
                <div className="py-16 text-center">
                  <div className="mx-auto h-14 w-14 rounded-2xl bg-slate-100 text-slate-500 flex items-center justify-center">
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
                        d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a2 2 0 011.414.586l4.414 4.414A2 2 0 0119 9v10a2 2 0 01-2 2z"
                      />
                    </svg>
                  </div>

                  <h3 className="mt-4 text-sm font-bold text-slate-800">
                    No documents found
                  </h3>

                  <p className="mt-1 text-xs text-slate-500 max-w-md mx-auto">
                    {searchQuery || typeFilter !== 'ALL'
                      ? 'No repository records match the current search or document type filter.'
                      : 'No digital documents are currently available in the repository.'}
                  </p>

                  {(searchQuery || typeFilter !== 'ALL') && (
                    <button
                      onClick={() => {
                        setSearchQuery('');
                        setTypeFilter('ALL');
                      }}
                      className="mt-5 px-4 py-2 rounded-lg bg-blue-800 text-white text-sm font-bold hover:bg-blue-900 transition"
                    >
                      Reset Filters
                    </button>
                  )}
                </div>
              )}
            </div>
          </section>

          {/* Integrity Information */}
          <section className="grid grid-cols-1 lg:grid-cols-3 gap-4">
            <div className="bg-white border border-slate-200 rounded-xl p-5 shadow-sm">
              <div className="flex items-start gap-3">
                <div className="h-10 w-10 rounded-lg bg-blue-50 text-blue-800 flex items-center justify-center shrink-0">
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
                      d="M12 11c1.105 0 2-.895 2-2s-.895-2-2-2-2 .895-2 2 .895 2 2 2zm0 0v5m0-14a9 9 0 110 18 9 9 0 010-18z"
                    />
                  </svg>
                </div>

                <div>
                  <h4 className="text-sm font-black text-slate-900">
                    SHA-256 Integrity
                  </h4>
                  <p className="text-xs text-slate-500 mt-1 leading-5">
                    Documents can be associated with cryptographic hashes so
                    investigators can inspect the integrity state of stored
                    records.
                  </p>
                </div>
              </div>
            </div>

            <div className="bg-white border border-slate-200 rounded-xl p-5 shadow-sm">
              <div className="flex items-start gap-3">
                <div className="h-10 w-10 rounded-lg bg-indigo-50 text-indigo-800 flex items-center justify-center shrink-0">
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
                      d="M8 7V3m8 4V3M5 11h14M5 5h14a2 2 0 012 2v13a2 2 0 01-2 2H5a2 2 0 01-2-2V7a2 2 0 012-2z"
                    />
                  </svg>
                </div>

                <div>
                  <h4 className="text-sm font-black text-slate-900">
                    Case Association
                  </h4>
                  <p className="text-xs text-slate-500 mt-1 leading-5">
                    Repository documents remain associated with their
                    corresponding investigation and case records.
                  </p>
                </div>
              </div>
            </div>

            <div className="bg-white border border-slate-200 rounded-xl p-5 shadow-sm">
              <div className="flex items-start gap-3">
                <div className="h-10 w-10 rounded-lg bg-emerald-50 text-emerald-800 flex items-center justify-center shrink-0">
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
                      d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 3c-2.755 0-5.28.925-7.31 2.484A11.953 11.953 0 002 12c0 4.478 2.364 8.404 6 10.392"
                    />
                  </svg>
                </div>

                <div>
                  <h4 className="text-sm font-black text-slate-900">
                    Audit & Security
                  </h4>
                  <p className="text-xs text-slate-500 mt-1 leading-5">
                    Existing ChainDock authentication, authorization and audit
                    infrastructure continues to protect repository operations.
                  </p>
                </div>
              </div>
            </div>
          </section>
        </>
      )}

      {/* Upload Modal */}
      <DocumentUpload
        isOpen={isUploadOpen}
        onClose={() => setIsUploadOpen(false)}
        caseId={activeCaseId}
        onUpload={handleUploadComplete}
      />
    </AppShell>
  );
};

export default Documents;
