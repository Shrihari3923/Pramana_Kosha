import React, { useState, useEffect, useRef } from 'react';
import { FolderPlus } from 'lucide-react';
import { Modal } from '../ui/Modal';
import { Input } from '../ui/Input';
import { Button } from '../ui/Button';
import { Priority, User } from '../../types';
import { getUsers } from '../../services/userService';

interface CaseFormProps {
  isOpen: boolean;
  onClose: () => void;
  onSubmit: (data: {
    title: string;
    case_number: string;
    description: string;
    priority: Priority;
    jurisdiction: string;
    lead_officer: string;
  }) => Promise<void>;
}

export const CaseForm: React.FC<CaseFormProps> = ({ isOpen, onClose, onSubmit }) => {
  const [title, setTitle] = useState('');
  const [caseNumber, setCaseNumber] = useState(`CD-2026-${Math.floor(100 + Math.random() * 900)}`);
  const [description, setDescription] = useState('');
  const [priority, setPriority] = useState<Priority>('HIGH');
  const [jurisdiction, setJurisdiction] = useState('Jurisdiction Alpha');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Officer picker state
  const [officers, setOfficers] = useState<User[]>([]);
  const [officersLoading, setOfficersLoading] = useState(false);
  const [selectedOfficer, setSelectedOfficer] = useState<User | null>(null);
  const [search, setSearch] = useState('');
  const [dropdownOpen, setDropdownOpen] = useState(false);
  const dropdownRef = useRef<HTMLDivElement>(null);

  // Fetch officers when modal opens
  useEffect(() => {
    if (!isOpen) return;
    setOfficersLoading(true);
    getUsers()
      .then((users) => {
        // Show investigators and supervisors — anyone who can be assigned a case
        const eligible = users.filter(
          (u) => u.role === 'INVESTIGATOR' || u.role === 'SUPERVISOR'
        );
        setOfficers(eligible);
      })
      .catch(() => {
        // Non-fatal — fall back to empty list, user can still type
        setOfficers([]);
      })
      .finally(() => setOfficersLoading(false));
  }, [isOpen]);

  // Close dropdown on outside click
  useEffect(() => {
    const handler = (e: MouseEvent) => {
      if (dropdownRef.current && !dropdownRef.current.contains(e.target as Node)) {
        setDropdownOpen(false);
      }
    };
    document.addEventListener('mousedown', handler);
    return () => document.removeEventListener('mousedown', handler);
  }, []);

  const filteredOfficers = officers.filter((o) => {
    const q = search.toLowerCase();
    return (
      o.name.toLowerCase().includes(q) ||
      o.email.toLowerCase().includes(q) ||
      (o.badge_number || o.badgeNumber || '').toLowerCase().includes(q)
    );
  });

  const roleLabel = (role: string) => {
    if (role === 'SUPERVISOR') return 'Supervisor';
    return 'Investigator';
  };

  const roleBadgeClass = (role: string) => {
    if (role === 'SUPERVISOR')
      return 'bg-purple-50 text-purple-700 border border-purple-200';
    return 'bg-blue-50 text-blue-700 border border-blue-200';
  };

  const resetForm = () => {
    setTitle('');
    setDescription('');
    setCaseNumber(`CD-2026-${Math.floor(100 + Math.random() * 900)}`);
    setSelectedOfficer(null);
    setSearch('');
    setDropdownOpen(false);
    setError(null);
  };

  const handleClose = () => {
    resetForm();
    onClose();
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim() || !caseNumber.trim()) return;
    if (!selectedOfficer) {
      setError('Please select a lead investigator from the list.');
      return;
    }

    setLoading(true);
    setError(null);
    try {
      await onSubmit({
        title: title.trim(),
        case_number: caseNumber.trim(),
        description: description.trim(),
        priority,
        jurisdiction: jurisdiction.trim(),
        lead_officer: selectedOfficer.name,
      });
      resetForm();
      onClose();
    } catch (err: any) {
      const msg =
        err?.message ||
        'Failed to commit case to backend ledger. Ensure backend is running and you have Supervisor/Admin authorization.';
      setError(msg);
    } finally {
      setLoading(false);
    }
  };

  return (
    <Modal
      isOpen={isOpen}
      onClose={handleClose}
      title="Create New Case Docket"
      subtitle="Register an official evidentiary case container on the sovereign ledger"
      icon={<FolderPlus size={20} />}
    >
      <form onSubmit={handleSubmit} className="flex flex-col gap-4">

        {error && (
          <div className="p-3.5 bg-red-50 text-red-900 rounded-lg text-xs font-medium border border-red-300 flex items-start gap-2.5">
            <span className="material-symbols-outlined text-[18px] text-red-700 shrink-0 mt-0.5">
              error
            </span>
            <div className="flex-1">
              <span className="font-semibold block mb-0.5">Case Registration Error:</span>
              <span>{error}</span>
            </div>
          </div>
        )}

        <Input
          label="Case Reference Number"
          value={caseNumber}
          onChange={(e) => setCaseNumber(e.target.value)}
          required
          placeholder="e.g. CD-2026-104"
          helperText="Unique sovereign jurisdiction identifier (committed to backend DB)"
        />

        <Input
          label="Docket Matter / Title"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          required
          placeholder="e.g. Illegal Timber Felling in Sector 4 Reserve"
        />

        <div className="flex flex-col gap-1.5">
          <label className="text-xs font-semibold uppercase tracking-wider text-forest-ink">
            Dossier Scope &amp; Preliminary Facts
          </label>
          <textarea
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            rows={3}
            className="w-full p-3 bg-surface-container-low text-forest-ink placeholder:text-on-surface-variant/70 border border-moss-border/60 rounded-lg text-sm focus:outline-none focus:bg-surface-bright focus:border-secondary transition-colors"
            placeholder="Describe initial complaint, seized coordinates, or incident overview..."
          />
        </div>

        <div className="grid grid-cols-2 gap-3">
          <div className="flex flex-col gap-1.5">
            <label className="text-xs font-semibold uppercase tracking-wider text-forest-ink">
              Priority Tier
            </label>
            <select
              value={priority}
              onChange={(e) => setPriority(e.target.value as Priority)}
              className="h-10 px-3 bg-surface-container-low text-forest-ink border border-moss-border/60 rounded-lg text-sm focus:outline-none focus:bg-surface-bright focus:border-secondary"
            >
              <option value="LOW">Low</option>
              <option value="MEDIUM">Medium</option>
              <option value="HIGH">High (Magistrate Fast-Track)</option>
              <option value="CRITICAL">Critical (Active Encroachment)</option>
            </select>
          </div>

          <div className="flex flex-col gap-1.5">
            <label className="text-xs font-semibold uppercase tracking-wider text-forest-ink">
              Jurisdiction Sector
            </label>
            <input
              type="text"
              value={jurisdiction}
              onChange={(e) => setJurisdiction(e.target.value)}
              className="h-10 px-3 bg-surface-container-low text-forest-ink border border-moss-border/60 rounded-lg text-sm focus:outline-none focus:bg-surface-bright focus:border-secondary"
            />
          </div>
        </div>

        {/* ── Officer picker ── */}
        <div className="flex flex-col gap-1.5" ref={dropdownRef}>
          <label className="text-xs font-semibold uppercase tracking-wider text-forest-ink flex items-center justify-between">
            <span>Assigned Lead Investigator</span>
            <span className="text-error text-xs">*</span>
          </label>

          {/* Trigger — shows selected officer or placeholder */}
          <button
            type="button"
            onClick={() => setDropdownOpen((v) => !v)}
            className={`w-full h-10 px-3.5 flex items-center justify-between bg-surface-container-low border rounded-lg text-sm transition-all focus:outline-none focus:ring-2 focus:ring-secondary/20 ${
              dropdownOpen
                ? 'border-secondary bg-surface-bright'
                : 'border-moss-border/60 hover:border-slate-400'
            }`}
          >
            {selectedOfficer ? (
              <span className="flex items-center gap-2 min-w-0">
                <span className="material-symbols-outlined text-[17px] text-slate-500 shrink-0">
                  badge
                </span>
                <span className="font-medium text-forest-ink truncate">
                  {selectedOfficer.name}
                </span>
                <span className={`text-[9px] font-bold px-1.5 py-0.5 rounded uppercase shrink-0 ${roleBadgeClass(selectedOfficer.role)}`}>
                  {roleLabel(selectedOfficer.role)}
                </span>
              </span>
            ) : (
              <span className="text-on-surface-variant/70 flex items-center gap-2">
                <span className="material-symbols-outlined text-[17px] shrink-0">
                  person_search
                </span>
                {officersLoading ? 'Loading officers…' : 'Select an officer…'}
              </span>
            )}
            <span className="material-symbols-outlined text-[18px] text-slate-400 shrink-0 ml-2">
              {dropdownOpen ? 'expand_less' : 'expand_more'}
            </span>
          </button>

          {/* Dropdown panel */}
          {dropdownOpen && (
            <div className="relative z-50">
              <div className="absolute top-1 left-0 right-0 bg-white border border-slate-200 rounded-xl shadow-xl overflow-hidden">

                {/* Search bar */}
                <div className="p-2 border-b border-slate-100">
                  <div className="relative">
                    <span className="material-symbols-outlined absolute left-2.5 top-1/2 -translate-y-1/2 text-[17px] text-slate-400">
                      search
                    </span>
                    <input
                      autoFocus
                      type="text"
                      value={search}
                      onChange={(e) => setSearch(e.target.value)}
                      placeholder="Search by name, email or badge…"
                      className="w-full h-9 pl-8 pr-3 text-xs bg-slate-50 border border-slate-200 rounded-lg focus:outline-none focus:border-blue-400 focus:ring-1 focus:ring-blue-200 transition-all"
                    />
                  </div>
                </div>

                {/* Officer list */}
                <ul className="max-h-52 overflow-y-auto divide-y divide-slate-50">
                  {officersLoading ? (
                    <li className="px-4 py-3 text-xs text-slate-400 text-center">
                      Loading officers…
                    </li>
                  ) : filteredOfficers.length === 0 ? (
                    <li className="px-4 py-3 text-xs text-slate-400 text-center">
                      {search ? 'No officers match your search.' : 'No officers found.'}
                    </li>
                  ) : (
                    filteredOfficers.map((officer) => (
                      <li key={officer.id}>
                        <button
                          type="button"
                          onClick={() => {
                            setSelectedOfficer(officer);
                            setDropdownOpen(false);
                            setSearch('');
                          }}
                          className={`w-full px-4 py-2.5 flex items-center gap-3 text-left hover:bg-slate-50 transition-colors ${
                            selectedOfficer?.id === officer.id ? 'bg-blue-50' : ''
                          }`}
                        >
                          {/* Avatar circle */}
                          <div className="w-8 h-8 rounded-full bg-[#0b1f3a] flex items-center justify-center shrink-0">
                            <span className="text-white text-[11px] font-bold">
                              {officer.name
                                .split(' ')
                                .map((n) => n[0])
                                .slice(0, 2)
                                .join('')
                                .toUpperCase()}
                            </span>
                          </div>

                          <div className="flex-1 min-w-0">
                            <div className="flex items-center gap-2">
                              <span className="text-xs font-semibold text-slate-800 truncate">
                                {officer.name}
                              </span>
                              <span className={`text-[9px] font-bold px-1.5 py-0.5 rounded uppercase shrink-0 ${roleBadgeClass(officer.role)}`}>
                                {roleLabel(officer.role)}
                              </span>
                            </div>
                            <div className="text-[10px] text-slate-400 truncate mt-0.5">
                              {officer.email}
                              {(officer.badge_number || officer.badgeNumber) && (
                                <span className="ml-2 font-mono">
                                  · {officer.badge_number || officer.badgeNumber}
                                </span>
                              )}
                            </div>
                          </div>

                          {selectedOfficer?.id === officer.id && (
                            <span className="material-symbols-outlined text-[17px] text-blue-600 shrink-0">
                              check_circle
                            </span>
                          )}
                        </button>
                      </li>
                    ))
                  )}
                </ul>

                {/* Clear selection */}
                {selectedOfficer && (
                  <div className="p-2 border-t border-slate-100">
                    <button
                      type="button"
                      onClick={() => {
                        setSelectedOfficer(null);
                        setSearch('');
                      }}
                      className="w-full py-1.5 text-[10px] font-semibold text-slate-500 hover:text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                    >
                      Clear selection
                    </button>
                  </div>
                )}
              </div>
            </div>
          )}
        </div>

        <div className="flex items-center justify-end gap-3 pt-3 border-t border-moss-border/40">
          <Button variant="secondary" type="button" onClick={handleClose} disabled={loading}>
            Cancel
          </Button>
          <Button variant="primary" type="submit" loading={loading}>
            Commit Case to Ledger
          </Button>
        </div>

      </form>
    </Modal>
  );
};
