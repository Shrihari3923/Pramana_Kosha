import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../../context/AuthContext';
import { OfficerProfileModal } from '../common/OfficerProfileModal';
import { canManageUsers } from '../../utils/permissions';

interface NavbarProps {
  onMenuToggle?: () => void;
}

export const Navbar: React.FC<NavbarProps> = ({ onMenuToggle }) => {
  const navigate = useNavigate();
  const { user, role, logout } = useAuth();

  const [dropdownOpen, setDropdownOpen] = useState(false);
  const [isProfileModalOpen, setIsProfileModalOpen] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');

  const initials = user?.name
    ? user.name
        .split(' ')
        .map((n) => n[0])
        .slice(0, 2)
        .join('')
        .toUpperCase()
    : 'AO';

  return (
    <header className="fixed top-0 left-0 lg:left-64 right-0 h-16 bg-white border-b border-slate-200 z-40 flex items-center justify-between px-4 sm:px-6 lg:px-8 gap-3 select-none shadow-sm">

      {/* =====================================================
          LEFT SIDE
      ====================================================== */}
      <div className="flex items-center gap-3 sm:gap-5 flex-1 min-w-0">

        {/* Mobile Menu */}
        <button
          onClick={onMenuToggle}
          className="lg:hidden p-2 rounded-lg border border-slate-200 text-slate-700 hover:bg-slate-100 shrink-0 flex items-center justify-center"
          aria-label="Toggle navigation menu"
        >
          <span className="material-symbols-outlined text-[20px]">
            menu
          </span>
        </button>

        {/* Department Branding */}
        <div className="flex flex-col min-w-0 shrink-0">

          <span className="text-[10px] sm:text-[11px] font-bold tracking-wider text-[#0b1f3a] uppercase truncate">
            pramāṇa-kośa
          </span>

          <span className="text-[10px] sm:text-xs text-slate-500 font-medium hidden sm:block truncate">
            Digital Investigation & Evidence Management
          </span>

        </div>

        <div className="hidden md:block h-7 w-px bg-slate-200 shrink-0" />

        {/* Search */}
        <div className="hidden sm:block relative flex-1 max-w-sm">

          <span className="material-symbols-outlined absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 text-[18px]">
            search
          </span>

          <form
            onSubmit={(e) => {
              e.preventDefault();
              if (searchQuery.trim()) {
                navigate(`/cases?q=${encodeURIComponent(searchQuery.trim())}`);
                setSearchQuery('');
              }
            }}
            className="w-full"
          >
            <input
              className="w-full h-9 pl-9 pr-3 bg-slate-50 border border-slate-200 rounded-lg text-xs text-slate-800 placeholder:text-slate-400 focus:outline-none focus:border-[#2563eb] focus:ring-1 focus:ring-blue-200 transition-all"
              placeholder="Search case, FIR, evidence, hash..."
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
            />
          </form>

        </div>

      </div>

      {/* =====================================================
          RIGHT SIDE
      ====================================================== */}
      <div className="flex items-center gap-2 sm:gap-4 shrink-0">

        {/* ChainDock Integrity Status */}
        <div className="hidden md:flex items-center gap-2 px-3 py-1.5 rounded-lg bg-emerald-50 text-emerald-800 border border-emerald-200 text-xs font-medium">

          <span className="material-symbols-outlined text-[16px] text-emerald-600">
            verified_user
          </span>

          <span className="hidden lg:inline">
            EVIDENCE INTEGRITY: VERIFIED
          </span>

          <span className="lg:hidden">
            VERIFIED
          </span>

        </div>

        <div className="hidden md:block h-7 w-px bg-slate-200" />

        {/* =====================================================
            OFFICER PROFILE
        ====================================================== */}
        <div className="relative">

          <button
            onClick={() => setDropdownOpen(!dropdownOpen)}
            className="flex items-center gap-2.5 p-1.5 rounded-lg hover:bg-slate-100 transition-colors border border-transparent hover:border-slate-200"
          >

            {/* Officer Information */}
            <div className="hidden sm:flex flex-col text-right">

              <span className="text-xs font-semibold text-slate-800 leading-tight truncate max-w-[160px]">
                {user?.name || 'Authorized Officer'}
              </span>

              <span className="text-[9px] text-slate-500 tracking-wider uppercase font-semibold">
                {role || 'OFFICER'}
                {user?.badgeNumber ? ` · ${user.badgeNumber}` : ''}
              </span>

            </div>

            {/* Avatar */}
            <div className="w-9 h-9 rounded-lg bg-[#0b1f3a] text-white flex items-center justify-center font-bold text-xs border border-[#16365f] shrink-0">
              {initials}
            </div>

            <span className="material-symbols-outlined text-[18px] text-slate-400">
              arrow_drop_down
            </span>

          </button>

          {/* =================================================
              DROPDOWN
          ================================================== */}
          {dropdownOpen && (

            <div className="absolute right-0 mt-2 w-72 bg-white rounded-xl shadow-xl border border-slate-200 p-3 flex flex-col gap-2 z-50">

              {/* Officer Details */}
              <div className="px-2 py-2 border-b border-slate-100 pb-3">

                <div className="flex items-center gap-3">

                  <div className="w-10 h-10 rounded-lg bg-[#0b1f3a] text-white flex items-center justify-center font-bold text-xs">
                    {initials}
                  </div>

                  <div className="min-w-0">

                    <div className="text-sm font-bold text-slate-800 truncate">
                      {user?.name || 'Authorized Officer'}
                    </div>

                    <div className="text-[10px] text-slate-500 truncate">
                      {user?.email || 'Officer account'}
                    </div>

                  </div>

                </div>

                <div className="mt-3 flex items-center gap-2">

                  <span className="text-[9px] font-bold px-2 py-1 rounded bg-blue-50 text-blue-700 border border-blue-100">
                    {role || 'INVESTIGATOR'}
                  </span>

                  {user?.badgeNumber && (
                    <span className="text-[10px] text-slate-500 font-mono">
                      Badge: {user.badgeNumber}
                    </span>
                  )}

                </div>

              </div>

              {/* Officer Credentials */}
              <button
                onClick={() => {
                  setDropdownOpen(false);
                  setIsProfileModalOpen(true);
                }}
                className="w-full text-left px-3 py-2.5 rounded-lg text-xs font-medium text-slate-700 hover:bg-slate-100 flex items-center gap-3 transition-colors"
              >

                <span className="material-symbols-outlined text-[17px] text-[#0b1f3a]">
                  badge
                </span>

                <span>
                  View Officer Credentials
                </span>

              </button>

              {/* Admin */}
              {canManageUsers(role) && (

                <button
                  onClick={() => {
                    setDropdownOpen(false);
                    navigate('/users');
                  }}
                  className="w-full text-left px-3 py-2.5 rounded-lg text-xs font-medium text-slate-700 hover:bg-slate-100 flex items-center gap-3 transition-colors"
                >

                  <span className="material-symbols-outlined text-[17px] text-[#0b1f3a]">
                    manage_accounts
                  </span>

                  <span>
                    Officer Management
                  </span>

                  <span className="ml-auto text-[8px] font-bold px-1.5 py-0.5 rounded bg-amber-50 text-amber-700 border border-amber-200">
                    ADMIN
                  </span>

                </button>

              )}

              {/* Security */}
              <button
                onClick={() => {
                  setDropdownOpen(false);
                  navigate('/security');
                }}
                className="w-full text-left px-3 py-2.5 rounded-lg text-xs font-medium text-slate-700 hover:bg-slate-100 flex items-center gap-3 transition-colors"
              >

                <span className="material-symbols-outlined text-[17px] text-emerald-600">
                  security
                </span>

                <span>
                  Security Center
                </span>

              </button>

              {/* Logout */}
              <button
                onClick={() => {
                  setDropdownOpen(false);
                  logout();
                }}
                className="w-full text-left px-3 py-2.5 rounded-lg text-xs font-medium text-red-700 hover:bg-red-50 flex items-center gap-3 transition-colors border-t border-slate-100 mt-1 pt-3"
              >

                <span className="material-symbols-outlined text-[17px]">
                  logout
                </span>

                <span>
                  Secure Logout
                </span>

              </button>

            </div>

          )}

        </div>

      </div>

      {/* Officer Profile Modal */}
      <OfficerProfileModal
        isOpen={isProfileModalOpen}
        onClose={() => setIsProfileModalOpen(false)}
      />

    </header>
  );
};
