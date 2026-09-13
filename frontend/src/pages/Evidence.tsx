import React, { useState, useEffect } from 'react';
import { AppShell } from '../components/layout/AppShell';
import { EvidenceList } from '../components/evidence/EvidenceList';
import { EvidenceUpload } from '../components/evidence/EvidenceUpload';
import { ChainOfCustodyLog } from '../components/evidence/ChainOfCustodyLog';
import { ChainOfCustodyTimeline } from '../components/evidence/ChainOfCustodyTimeline';
import { Modal } from '../components/ui/Modal';
import { evidenceService } from '../services/evidence';
import { casesService } from '../services/cases';
import { EvidenceItem } from '../types';
import { BackendUnavailable } from '../components/common/BackendUnavailable';
import { ApiError } from '../services/api';

export const Evidence: React.FC = () => {
  const [evidenceItems, setEvidenceItems] = useState<EvidenceItem[]>([]);
  const [activeCaseId, setActiveCaseId] = useState<string>('');
  const [loading, setLoading] = useState<boolean>(true);
  const [backendError, setBackendError] = useState<{
    status: number;
    endpoint: string;
    message: string;
  } | null>(null);

  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState<string>('ALL');

  // Modals
  const [isUploadOpen, setIsUploadOpen] = useState(false);
  const [transferTargetItem, setTransferTargetItem] =
    useState<EvidenceItem | null>(null);
  const [timelineTargetItem, setTimelineTargetItem] =
    useState<EvidenceItem | null>(null);

  const fetchEvidence = async () => {
    try {
      setLoading(true);
      setBackendError(null);

      const items = await evidenceService.getEvidence();
      setEvidenceItems(items);
    } catch (err: unknown) {
      console.error('Failed to load evidence catalog:', err);

      if (err instanceof ApiError) {
        setBackendError({
          status: err.status,
          endpoint: err.endpoint,
          message: err.message,
        });
      } else {
        setBackendError({
          status: 0,
          endpoint: '/evidence',
          message:
            err instanceof Error ? err.message : 'Unable to load evidence',
        });
      }
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchEvidence();

    casesService
      .getCases()
      .then((list) => {
        if (list && list.length > 0 && list[0]?.id) {
          setActiveCaseId(list[0].id);
        }
      })
      .catch((err) => {
        console.error('Failed to load cases:', err);
      });
  }, []);

  const handleUploadSubmit = async (data: {
    item_number: string;
    name: string;
    category: string;
    description: string;
    location: string;
  }) => {
    if (!activeCaseId) {
      throw new Error(
        'No active case is available. Please create a case before registering evidence.'
      );
    }

    await evidenceService.createEvidence({
      case_id: activeCaseId,
      item_number: data.item_number,
      name: data.name,
      category: data.category,
      description: data.description,
      location: data.location,
    });

    setIsUploadOpen(false);
    await fetchEvidence();
  };

  const handleTransfer = async (
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

    setTransferTargetItem(null);
    await fetchEvidence();
  };

  const filteredItems = evidenceItems.filter((item) => {
    const q = searchQuery.toLowerCase().trim();

    const matchesSearch =
      !q ||
      (item.name || '').toLowerCase().includes(q) ||
      (item.item_number || '').toLowerCase().includes(q) ||
      (item.custodian || '').toLowerCase().includes(q) ||
      (item.location || '').toLowerCase().includes(q) ||
      (item.description || '').toLowerCase().includes(q);

    const matchesStatus =
      statusFilter === 'ALL' || item.status === statusFilter;

    return matchesSearch && matchesStatus;
  });

  const secureCount = evidenceItems.filter(
    (item) => item.status === 'SECURE_VAULT'
  ).length;

  const analysisCount = evidenceItems.filter(
    (item) => item.status === 'ANALYSIS'
  ).length;

  const transitCount = evidenceItems.filter(
    (item) => item.status === 'IN_TRANSIT'
  ).length;

  const courtCount = evidenceItems.filter(
    (item) => item.status === 'COURT_EXHIBIT'
  ).length;

  return (
    <AppShell>
      <div className="space-y-6 animate-fade-in max-w-[1520px] mx-auto">

        {/* =========================================================
            HEADER
        ========================================================== */}
        <div className="flex flex-col xl:flex-row xl:items-center justify-between gap-5 pb-5 border-b border-slate-200">

          <div>
            <div className="flex flex-wrap items-center gap-3">

              <div className="flex items-center gap-3">
                <div className="w-11 h-11 rounded-xl bg-[#0B1F3A] flex items-center justify-center shadow-sm">
                  <span className="material-symbols-outlined text-white text-[24px]">
                    inventory_2
                  </span>
                </div>

                <div>
                  <h1 className="text-2xl lg:text-3xl font-bold tracking-tight text-[#0B1F3A]">
                    Evidence Management
                  </h1>

                  <p className="text-sm text-slate-500 mt-0.5">
                    Digital evidence registry &amp; chain-of-custody control
                  </p>
                </div>
              </div>

              <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-emerald-50 border border-emerald-200 text-emerald-700 text-[11px] font-bold tracking-wide">
                <span className="material-symbols-outlined text-[15px]">
                  verified_user
                </span>
                CHAINLOCK VERIFIED
              </span>
            </div>

            <p className="text-xs text-slate-500 mt-3 max-w-3xl">
              Register, track, transfer and audit physical and digital
              forensic exhibits while preserving ChainDock custody records
              and cryptographic integrity.
            </p>
          </div>

          <div className="flex items-center gap-2">

            <button
              onClick={fetchEvidence}
              className="px-3.5 py-2.5 bg-white hover:bg-slate-50 text-slate-700 border border-slate-200 rounded-lg text-xs font-semibold flex items-center gap-2 transition-colors shadow-sm"
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
              onClick={() => setIsUploadOpen(true)}
              disabled={!activeCaseId}
              className="px-4 py-2.5 bg-[#0B1F3A] hover:bg-[#07172B] disabled:bg-slate-300 disabled:cursor-not-allowed text-white rounded-lg text-xs font-bold flex items-center gap-2 transition-colors shadow-sm"
            >
              <span className="material-symbols-outlined text-[18px]">
                add_box
              </span>
              Register Evidence
            </button>

          </div>
        </div>

        {/* =========================================================
            SUMMARY CARDS
        ========================================================== */}
        {!loading && !backendError && (
          <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">

            {/* Total */}
            <div className="bg-white border border-slate-200 rounded-xl p-4 shadow-sm">
              <div className="flex items-center justify-between">

                <div>
                  <p className="text-[10px] uppercase tracking-wider font-bold text-slate-400">
                    Total Exhibits
                  </p>

                  <p className="text-2xl font-bold text-[#0B1F3A] mt-1">
                    {evidenceItems.length}
                  </p>
                </div>

                <div className="w-10 h-10 rounded-lg bg-slate-100 flex items-center justify-center">
                  <span className="material-symbols-outlined text-[#0B1F3A]">
                    inventory
                  </span>
                </div>

              </div>

              <p className="text-[10px] text-slate-400 mt-2">
                Registered in ChainDock
              </p>
            </div>

            {/* Secure Vault */}
            <div className="bg-white border border-slate-200 rounded-xl p-4 shadow-sm">
              <div className="flex items-center justify-between">

                <div>
                  <p className="text-[10px] uppercase tracking-wider font-bold text-slate-400">
                    Secure Vault
                  </p>

                  <p className="text-2xl font-bold text-emerald-700 mt-1">
                    {secureCount}
                  </p>
                </div>

                <div className="w-10 h-10 rounded-lg bg-emerald-50 flex items-center justify-center">
                  <span className="material-symbols-outlined text-emerald-700">
                    lock
                  </span>
                </div>

              </div>

              <p className="text-[10px] text-slate-400 mt-2">
                Secure custody
              </p>
            </div>

            {/* Forensic Analysis */}
            <div className="bg-white border border-slate-200 rounded-xl p-4 shadow-sm">
              <div className="flex items-center justify-between">

                <div>
                  <p className="text-[10px] uppercase tracking-wider font-bold text-slate-400">
                    Forensic Analysis
                  </p>

                  <p className="text-2xl font-bold text-blue-700 mt-1">
                    {analysisCount}
                  </p>
                </div>

                <div className="w-10 h-10 rounded-lg bg-blue-50 flex items-center justify-center">
                  <span className="material-symbols-outlined text-blue-700">
                    science
                  </span>
                </div>

              </div>

              <p className="text-[10px] text-slate-400 mt-2">
                Currently under analysis
              </p>
            </div>

            {/* Transit / Court */}
            <div className="bg-white border border-slate-200 rounded-xl p-4 shadow-sm">
              <div className="flex items-center justify-between">

                <div>
                  <p className="text-[10px] uppercase tracking-wider font-bold text-slate-400">
                    Active Movement
                  </p>

                  <p className="text-2xl font-bold text-amber-700 mt-1">
                    {transitCount}
                  </p>
                </div>

                <div className="w-10 h-10 rounded-lg bg-amber-50 flex items-center justify-center">
                  <span className="material-symbols-outlined text-amber-700">
                    local_shipping
                  </span>
                </div>

              </div>

              <p className="text-[10px] text-slate-400 mt-2">
                {courtCount} court exhibit{courtCount === 1 ? '' : 's'}
              </p>
            </div>

          </div>
        )}

        {/* =========================================================
            SEARCH / FILTER BAR
        ========================================================== */}
        <div className="bg-white p-4 rounded-xl border border-slate-200 shadow-sm">

          <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-4">

            <div className="relative w-full lg:max-w-xl">

              <span className="material-symbols-outlined absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 text-[19px]">
                search
              </span>

              <input
                className="w-full h-10 pl-10 pr-4 bg-slate-50 border border-slate-200 text-slate-800 placeholder:text-slate-400 text-xs rounded-lg focus:outline-none focus:border-[#0B1F3A] focus:ring-2 focus:ring-[#0B1F3A]/10 focus:bg-white transition-all"
                placeholder="Search exhibit number, name, custodian, location or description..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
              />

            </div>

            <div className="flex flex-wrap items-center gap-2">

              <div className="flex items-center gap-1.5 text-slate-400">
                <span className="material-symbols-outlined text-[18px]">
                  filter_alt
                </span>

                <span className="text-[10px] font-bold uppercase tracking-wide">
                  Status
                </span>
              </div>

              <select
                className="text-xs bg-slate-50 border border-slate-200 rounded-lg px-3 py-2.5 text-slate-700 focus:outline-none focus:border-[#0B1F3A] focus:ring-1 focus:ring-[#0B1F3A]"
                value={statusFilter}
                onChange={(e) => setStatusFilter(e.target.value)}
              >
                <option value="ALL">All Custody Statuses</option>
                <option value="SECURE_VAULT">
                  Central Evidence Vault
                </option>
                <option value="ANALYSIS">
                  Forensic Lab Analysis
                </option>
                <option value="COURT_EXHIBIT">
                  Submitted in Court
                </option>
                <option value="IN_TRANSIT">
                  In Transit
                </option>
              </select>

            </div>
          </div>

          {/* Result information */}
          <div className="flex flex-wrap items-center justify-between gap-2 mt-3 pt-3 border-t border-slate-100">

            <div className="flex items-center gap-2 text-[11px] text-slate-500">
              <span className="material-symbols-outlined text-[15px]">
                database
              </span>

              Showing
              <span className="font-bold text-slate-700">
                {filteredItems.length}
              </span>
              of
              <span className="font-bold text-slate-700">
                {evidenceItems.length}
              </span>
              evidence records
            </div>

            <div className="flex items-center gap-1.5 text-[10px] font-semibold text-emerald-700">
              <span className="w-1.5 h-1.5 rounded-full bg-emerald-500"></span>
              ChainDock custody records active
            </div>

          </div>
        </div>

        {/* =========================================================
            LOADING
        ========================================================== */}
        {loading && (
          <div className="bg-white border border-slate-200 rounded-xl p-16 text-center shadow-sm">

            <div className="animate-spin w-9 h-9 border-2 border-[#0B1F3A] border-t-transparent rounded-full mx-auto mb-4"></div>

            <p className="text-sm font-semibold text-slate-700">
              Loading evidence registry...
            </p>

            <p className="text-xs text-slate-400 mt-1">
              Retrieving custody records from ChainDock backend
            </p>

          </div>
        )}

        {/* =========================================================
            BACKEND ERROR
        ========================================================== */}
        {!loading && backendError && (
          <BackendUnavailable
            moduleName="Evidence Custody Ledger"
            endpoint={backendError.endpoint}
            status={backendError.status}
            errorMessage={backendError.message}
            onRetry={fetchEvidence}
          />
        )}

        {/* =========================================================
            EVIDENCE LIST
        ========================================================== */}
        {!loading && !backendError && (
          <div className="bg-white border border-slate-200 rounded-xl shadow-sm overflow-hidden">

            <div className="px-5 py-4 border-b border-slate-200 bg-slate-50/70">

              <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">

                <div>
                  <div className="flex items-center gap-2">

                    <span className="material-symbols-outlined text-[#0B1F3A] text-[20px]">
                      fact_check
                    </span>

                    <h2 className="text-sm font-bold text-[#0B1F3A]">
                      Evidence Registry
                    </h2>

                  </div>

                  <p className="text-[11px] text-slate-500 mt-1">
                    Select an exhibit to view its custody history or initiate
                    a controlled handover.
                  </p>
                </div>

                <div className="flex items-center gap-2">

                  <span className="inline-flex items-center gap-1.5 px-2.5 py-1.5 rounded-md bg-white border border-slate-200 text-[10px] font-bold text-slate-600">
                    <span className="material-symbols-outlined text-[14px]">
                      shield
                    </span>
                    Integrity Protected
                  </span>

                </div>

              </div>

            </div>

            <div className="p-4">
              <EvidenceList
                items={filteredItems}
                onSelect={(item) => setTimelineTargetItem(item)}
                onTransfer={(item) => setTransferTargetItem(item)}
              />
            </div>

          </div>
        )}

        {/* =========================================================
            CHAINDOCK SECURITY STRIP
        ========================================================== */}
        {!loading && !backendError && (
          <div className="rounded-xl border border-[#0B1F3A]/15 bg-[#0B1F3A] text-white p-4">

            <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">

              <div className="flex items-start gap-3">

                <div className="w-9 h-9 rounded-lg bg-white/10 flex items-center justify-center shrink-0">
                  <span className="material-symbols-outlined text-[19px]">
                    verified
                  </span>
                </div>

                <div>
                  <p className="text-xs font-bold">
                    ChainDock Evidence Integrity
                  </p>

                  <p className="text-[10px] text-slate-300 mt-0.5">
                    Evidence registration, custody transfers and audit
                    operations remain connected to the existing secure
                    backend.
                  </p>
                </div>

              </div>

              <div className="flex flex-wrap items-center gap-3 text-[10px] font-semibold text-slate-300">

                <span className="flex items-center gap-1">
                  <span className="material-symbols-outlined text-[14px]">
                    lock
                  </span>
                  Access Controlled
                </span>

                <span className="flex items-center gap-1">
                  <span className="material-symbols-outlined text-[14px]">
                    history
                  </span>
                  Audit Logged
                </span>

                <span className="flex items-center gap-1">
                  <span className="material-symbols-outlined text-[14px]">
                    link
                  </span>
                  Ledger Connected
                </span>

              </div>

            </div>

          </div>
        )}

      </div>

      {/* =========================================================
          REGISTER EVIDENCE MODAL
      ========================================================== */}
      <EvidenceUpload
        isOpen={isUploadOpen}
        onClose={() => setIsUploadOpen(false)}
        caseId={activeCaseId}
        onSubmit={handleUploadSubmit}
      />

      {/* =========================================================
          TRANSFER CUSTODY MODAL
      ========================================================== */}
      <ChainOfCustodyLog
        isOpen={Boolean(transferTargetItem)}
        onClose={() => setTransferTargetItem(null)}
        evidenceItem={transferTargetItem}
        onTransfer={handleTransfer}
      />

      {/* =========================================================
          CUSTODY HISTORY
      ========================================================== */}
      <Modal
        isOpen={Boolean(timelineTargetItem)}
        onClose={() => setTimelineTargetItem(null)}
        title={`Custody History — ${
          timelineTargetItem?.item_number || ''
        }`}
        subtitle={timelineTargetItem?.name}
        maxWidth="lg"
      >
        <div className="space-y-4">

          {/* Current status */}
          <div className="p-4 bg-slate-50 rounded-lg border border-slate-200">

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">

              <div>
                <p className="text-[10px] uppercase tracking-wider font-bold text-slate-400">
                  Current Location
                </p>

                <div className="flex items-center gap-2 mt-1">

                  <span className="material-symbols-outlined text-[#0B1F3A] text-[17px]">
                    location_on
                  </span>

                  <p className="text-xs font-bold text-[#0B1F3A]">
                    {timelineTargetItem?.location || 'Not specified'}
                  </p>

                </div>
              </div>

              <div>
                <p className="text-[10px] uppercase tracking-wider font-bold text-slate-400">
                  Current Custodian
                </p>

                <div className="flex items-center gap-2 mt-1">

                  <span className="material-symbols-outlined text-[#0B1F3A] text-[17px]">
                    badge
                  </span>

                  <p className="text-xs font-bold text-[#0B1F3A]">
                    {timelineTargetItem?.custodian || 'Not specified'}
                  </p>

                </div>
              </div>

            </div>

          </div>

          {/* Timeline */}
          <div>
            <div className="flex items-center gap-2 mb-3">

              <span className="material-symbols-outlined text-[#0B1F3A] text-[18px]">
                timeline
              </span>

              <h3 className="text-xs font-bold uppercase tracking-wide text-slate-600">
                Chain of Custody
              </h3>

            </div>

            <ChainOfCustodyTimeline
              events={timelineTargetItem?.custody_events || []}
            />
          </div>

          {/* Actions */}
          <div className="pt-4 border-t border-slate-200 flex flex-col sm:flex-row justify-end gap-2">

            <button
              onClick={() => setTimelineTargetItem(null)}
              className="px-4 py-2 bg-white hover:bg-slate-50 text-slate-700 border border-slate-200 rounded-lg text-xs font-semibold transition-colors"
            >
              Close History
            </button>

            <button
              onClick={() => {
                const item = timelineTargetItem;

                setTimelineTargetItem(null);

                if (item) {
                  setTransferTargetItem(item);
                }
              }}
              className="px-4 py-2 bg-[#0B1F3A] hover:bg-[#07172B] text-white rounded-lg text-xs font-semibold flex items-center justify-center gap-2 transition-colors"
            >
              <span className="material-symbols-outlined text-[16px]">
                swap_horiz
              </span>

              Initiate Handover
            </button>

          </div>

        </div>
      </Modal>
    </AppShell>
  );
};

export default Evidence;
