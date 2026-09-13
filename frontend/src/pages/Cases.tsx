import React, { useState, useEffect } from 'react';
import { useSearchParams } from 'react-router-dom';
import { AppShell } from '../components/layout/AppShell';
import { CaseList } from '../components/cases/CaseList';
import { CaseCard } from '../components/cases/CaseCard';
import { CaseForm } from '../components/cases/CaseForm';
import { Case, Priority } from '../types';
import { casesService } from '../services/cases';
import { BackendUnavailable } from '../components/common/BackendUnavailable';
import { ApiError } from '../services/api';

export const Cases: React.FC = () => {
  const [searchParams] = useSearchParams();
  const [cases, setCases] = useState<Case[]>([]);
  const [loading, setLoading] = useState<boolean>(true);

  const [backendError, setBackendError] = useState<{
    status: number;
    endpoint: string;
    message: string;
  } | null>(null);

  const [viewMode, setViewMode] = useState<'grid' | 'table'>('table');

  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState<string>('ALL');
  const [priorityFilter, setPriorityFilter] = useState<string>('ALL');

  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);

  const fetchCases = async () => {
    try {
      setLoading(true);
      setBackendError(null);

      const data = await casesService.getCases();
      setCases(data);
    } catch (err: unknown) {
      console.error('Failed to load cases:', err);

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
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchCases();
    const q = searchParams.get('q');
    if (q) setSearchQuery(q);
  }, [searchParams]);

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

    setIsCreateModalOpen(false);
    fetchCases();
  };

  const filteredCases = cases.filter((c) => {
    const q = searchQuery.toLowerCase().trim();

    const matchesSearch =
      (c.title || '').toLowerCase().includes(q) ||
      (c.case_number || '').toLowerCase().includes(q) ||
      (c.lead_officer || '').toLowerCase().includes(q) ||
      (c.jurisdiction || '').toLowerCase().includes(q);

    const matchesStatus =
      statusFilter === 'ALL' || c.status === statusFilter;

    const matchesPriority =
      priorityFilter === 'ALL' || c.priority === priorityFilter;

    return matchesSearch && matchesStatus && matchesPriority;
  });

  const activeCount = cases.filter(
    (c) => c.status === 'ACTIVE'
  ).length;

  const highPriorityCount = cases.filter(
    (c) => c.priority === 'HIGH' || c.priority === 'CRITICAL'
  ).length;

  return (
    <AppShell>
      <div className="space-y-6 animate-fade-in max-w-[1520px] mx-auto">

        {/* =====================================================
            PAGE HEADER
        ===================================================== */}
        <section className="flex flex-col lg:flex-row lg:items-center justify-between gap-5 pb-5 border-b border-slate-200">

          <div>

            <div className="flex flex-wrap items-center gap-2 mb-2">

              <div className="flex items-center gap-2">

                <span className="material-symbols-outlined text-[#0b1f3a] text-[25px]">
                  folder_open
                </span>

                <h1 className="text-2xl lg:text-3xl font-bold text-[#0b1f3a] tracking-tight">
                  Case Management
                </h1>

              </div>

              <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md bg-blue-50 text-blue-700 border border-blue-100 text-[9px] font-bold uppercase tracking-wider">
                <span className="material-symbols-outlined text-[13px]">
                  local_police
                </span>
                pramāṇa-kośa
              </span>

            </div>

            <p className="text-sm text-slate-500">
              Centralized management of FIRs, investigations, case records,
              officers and legal proceedings.
            </p>

          </div>


          {/* Actions */}
          <div className="flex items-center gap-2 shrink-0">

            <button
              onClick={fetchCases}
              className="px-3.5 py-2.5 bg-white hover:bg-slate-50 text-slate-700 border border-slate-200 rounded-lg text-xs font-semibold flex items-center gap-2 transition-colors shadow-sm"
            >
              <span
                className={`material-symbols-outlined text-[17px] ${
                  loading ? 'animate-spin' : ''
                }`}
              >
                refresh
              </span>

              Refresh
            </button>

            <button
              onClick={() => setIsCreateModalOpen(true)}
              className="px-4 py-2.5 bg-[#0b1f3a] hover:bg-[#12345c] text-white rounded-lg text-xs font-semibold flex items-center gap-2 transition-colors shadow-sm"
            >
              <span className="material-symbols-outlined text-[17px]">
                add
              </span>

              Register New Case
            </button>

          </div>

        </section>


        {/* =====================================================
            SUMMARY CARDS
        ===================================================== */}
        {!loading && !backendError && (
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">

            <div className="bg-white border border-slate-200 rounded-xl p-4 shadow-sm">

              <div className="flex items-center justify-between">

                <div>

                  <p className="text-[9px] uppercase tracking-wider font-bold text-slate-400">
                    Total Cases
                  </p>

                  <p className="text-2xl font-bold text-[#0b1f3a] mt-1">
                    {cases.length}
                  </p>

                </div>

                <div className="w-10 h-10 rounded-lg bg-blue-50 flex items-center justify-center">
                  <span className="material-symbols-outlined text-blue-700">
                    folder
                  </span>
                </div>

              </div>

              <p className="text-[10px] text-slate-400 mt-2">
                Registered investigation records
              </p>

            </div>


            <div className="bg-white border border-slate-200 rounded-xl p-4 shadow-sm">

              <div className="flex items-center justify-between">

                <div>

                  <p className="text-[9px] uppercase tracking-wider font-bold text-slate-400">
                    Active Investigations
                  </p>

                  <p className="text-2xl font-bold text-emerald-700 mt-1">
                    {activeCount}
                  </p>

                </div>

                <div className="w-10 h-10 rounded-lg bg-emerald-50 flex items-center justify-center">
                  <span className="material-symbols-outlined text-emerald-700">
                    pending_actions
                  </span>
                </div>

              </div>

              <p className="text-[10px] text-slate-400 mt-2">
                Cases currently under investigation
              </p>

            </div>


            <div className="bg-white border border-slate-200 rounded-xl p-4 shadow-sm">

              <div className="flex items-center justify-between">

                <div>

                  <p className="text-[9px] uppercase tracking-wider font-bold text-slate-400">
                    Priority Attention
                  </p>

                  <p className="text-2xl font-bold text-red-700 mt-1">
                    {highPriorityCount}
                  </p>

                </div>

                <div className="w-10 h-10 rounded-lg bg-red-50 flex items-center justify-center">
                  <span className="material-symbols-outlined text-red-700">
                    priority_high
                  </span>
                </div>

              </div>

              <p className="text-[10px] text-slate-400 mt-2">
                High and critical priority cases
              </p>

            </div>

          </div>
        )}


        {/* =====================================================
            SEARCH & FILTER BAR
        ===================================================== */}
        <section className="bg-white p-4 rounded-xl border border-slate-200 shadow-sm">

          <div className="flex flex-col xl:flex-row xl:items-center justify-between gap-4">

            {/* Search */}
            <div className="relative w-full xl:max-w-md">

              <span className="material-symbols-outlined absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 text-[19px]">
                search
              </span>

              <input
                className="w-full h-10 pl-10 pr-3 bg-slate-50 border border-slate-200 text-slate-800 placeholder:text-slate-400 text-xs rounded-lg focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-100 transition-all"
                placeholder="Search case number, title, officer or jurisdiction..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
              />

            </div>


            {/* Filters */}
            <div className="flex flex-wrap items-center gap-2">

              <div className="flex items-center gap-2 text-slate-400 mr-1">

                <span className="material-symbols-outlined text-[18px]">
                  tune
                </span>

                <span className="hidden sm:inline text-[9px] uppercase font-bold tracking-wider">
                  Filters
                </span>

              </div>


              <select
                className="h-9 text-xs bg-slate-50 border border-slate-200 rounded-lg px-3 text-slate-700 focus:outline-none focus:border-blue-500"
                value={statusFilter}
                onChange={(e) => setStatusFilter(e.target.value)}
              >

                <option value="ALL">All Statuses</option>
                <option value="ACTIVE">Active</option>
                <option value="UNDER_REVIEW">Under Review</option>
                <option value="COURT_PROCEEDINGS">
                  Court Proceedings
                </option>
                <option value="CLOSED">Closed</option>
                <option value="ARCHIVED">Archived</option>

              </select>


              <select
                className="h-9 text-xs bg-slate-50 border border-slate-200 rounded-lg px-3 text-slate-700 focus:outline-none focus:border-blue-500"
                value={priorityFilter}
                onChange={(e) => setPriorityFilter(e.target.value)}
              >

                <option value="ALL">All Priorities</option>
                <option value="CRITICAL">Critical</option>
                <option value="HIGH">High</option>
                <option value="MEDIUM">Medium</option>
                <option value="LOW">Low</option>

              </select>


              {/* View toggle */}
              <div className="flex items-center border border-slate-200 rounded-lg overflow-hidden bg-slate-50 p-0.5 ml-1">

                <button
                  type="button"
                  className={`p-1.5 rounded transition-colors ${
                    viewMode === 'table'
                      ? 'bg-white text-[#0b1f3a] shadow-sm'
                      : 'text-slate-400 hover:text-slate-700'
                  }`}
                  onClick={() => setViewMode('table')}
                  title="Table View"
                >

                  <span className="material-symbols-outlined text-[18px]">
                    table_rows
                  </span>

                </button>


                <button
                  type="button"
                  className={`p-1.5 rounded transition-colors ${
                    viewMode === 'grid'
                      ? 'bg-white text-[#0b1f3a] shadow-sm'
                      : 'text-slate-400 hover:text-slate-700'
                  }`}
                  onClick={() => setViewMode('grid')}
                  title="Grid View"
                >

                  <span className="material-symbols-outlined text-[18px]">
                    grid_view
                  </span>

                </button>

              </div>

            </div>

          </div>


          {/* Filter status */}
          {(searchQuery || statusFilter !== 'ALL' || priorityFilter !== 'ALL') && (
            <div className="flex items-center gap-2 mt-3 pt-3 border-t border-slate-100">

              <span className="text-[10px] text-slate-400">
                Showing
              </span>

              <span className="text-[10px] font-bold text-[#0b1f3a]">
                {filteredCases.length}
              </span>

              <span className="text-[10px] text-slate-400">
                of {cases.length} cases
              </span>

              <button
                type="button"
                onClick={() => {
                  setSearchQuery('');
                  setStatusFilter('ALL');
                  setPriorityFilter('ALL');
                }}
                className="ml-2 text-[10px] font-semibold text-blue-700 hover:text-blue-900"
              >
                Clear filters
              </button>

            </div>
          )}

        </section>


        {/* =====================================================
            CONTENT
        ===================================================== */}
        {loading ? (

          <div className="bg-white border border-slate-200 rounded-xl p-16 text-center shadow-sm">

            <div className="animate-spin w-9 h-9 border-2 border-blue-700 border-t-transparent rounded-full mx-auto mb-4"></div>

            <p className="text-sm font-semibold text-[#0b1f3a]">
              Loading case records...
            </p>

            <p className="text-xs text-slate-400 mt-1">
              Connecting to pramāṇa-kośa / ChainDock backend
            </p>

          </div>

        ) : backendError ? (

          <BackendUnavailable
            moduleName="Case Management"
            endpoint={backendError.endpoint}
            status={backendError.status}
            errorMessage={backendError.message}
            onRetry={fetchCases}
          />

        ) : filteredCases.length === 0 ? (

          <div className="bg-white rounded-xl border border-dashed border-slate-300 p-16 text-center shadow-sm">

            <div className="w-14 h-14 mx-auto rounded-xl bg-slate-100 flex items-center justify-center mb-4">

              <span className="material-symbols-outlined text-slate-400 text-[28px]">
                folder_off
              </span>

            </div>

            <p className="text-base font-bold text-[#0b1f3a]">
              No matching case records
            </p>

            <p className="text-xs text-slate-500 mt-1">
              Try changing the search query or adjusting the filters.
            </p>

            <button
              type="button"
              onClick={() => {
                setSearchQuery('');
                setStatusFilter('ALL');
                setPriorityFilter('ALL');
              }}
              className="mt-4 px-4 py-2 rounded-lg bg-slate-100 hover:bg-slate-200 text-xs font-semibold text-slate-700"
            >
              Reset Filters
            </button>

          </div>

        ) : viewMode === 'table' ? (

          <section className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">

            <div className="px-4 py-3 border-b border-slate-200 flex items-center justify-between">

              <div className="flex items-center gap-2">

                <span className="material-symbols-outlined text-[#0b1f3a] text-[18px]">
                  folder_shared
                </span>

                <span className="text-xs font-bold text-[#0b1f3a] uppercase tracking-wider">
                  Investigation Case Register
                </span>

              </div>

              <span className="text-[10px] text-slate-400">
                {filteredCases.length} record
                {filteredCases.length !== 1 ? 's' : ''}
              </span>

            </div>

            <CaseList cases={filteredCases} />

          </section>

        ) : (

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">

            {filteredCases.map((c) => (
              <CaseCard
                key={c.id}
                caseItem={c}
              />
            ))}

          </div>

        )}


        {/* =====================================================
            CHAINDOCK INTEGRITY STRIP
        ===================================================== */}
        {!loading && !backendError && (
          <div className="bg-[#0b1f3a] rounded-xl px-4 py-3 text-white flex flex-col sm:flex-row sm:items-center justify-between gap-3">

            <div className="flex items-center gap-3">

              <div className="w-8 h-8 rounded-lg bg-white/10 flex items-center justify-center">

                <span className="material-symbols-outlined text-emerald-300 text-[18px]">
                  verified_user
                </span>

              </div>

              <div>

                <div className="text-[10px] font-bold uppercase tracking-wider">
                  ChainDock Evidence Infrastructure
                </div>

                <div className="text-[9px] text-blue-200/70 mt-0.5">
                  Case records remain protected by the existing secure backend,
                  audit and integrity mechanisms.
                </div>

              </div>

            </div>

            <div className="flex items-center gap-2 text-[9px] font-bold uppercase tracking-wider text-emerald-300">

              <span className="w-2 h-2 rounded-full bg-emerald-400"></span>

              Backend Connected

            </div>

          </div>
        )}

      </div>


      {/* =====================================================
          CASE CREATION MODAL
      ===================================================== */}
      <CaseForm
        isOpen={isCreateModalOpen}
        onClose={() => setIsCreateModalOpen(false)}
        onSubmit={handleCreateCase}
      />

    </AppShell>
  );
};
