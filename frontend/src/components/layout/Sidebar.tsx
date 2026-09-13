import React from 'react';
import { NavLink } from 'react-router-dom';
import { useAuth } from '../../context/AuthContext';
import { canManageUsers } from '../../utils/permissions';

export const Sidebar: React.FC = () => {
  const { role, logout } = useAuth();

  const navItems: {
    to: string;
    label: string;
    icon: string;
    badge?: string;
  }[] = [
    {
      to: '/dashboard',
      label: 'Dashboard',
      icon: 'dashboard',
    },
    {
      to: '/cases',
      label: 'Case Management',
      icon: 'folder_open',
    },
    {
      to: '/documents',
      label: 'FIR & Documents',
      icon: 'description',
    },
    {
      to: '/evidence',
      label: 'Evidence Management',
      icon: 'inventory_2',
    },
    {
      to: '/audit',
      label: 'Audit Trail',
      icon: 'history',
    },
    {
      to: '/blockchain',
      label: 'Evidence Ledger',
      icon: 'account_tree',
      badge: 'SECURE',
    },
    {
      to: '/security',
      label: 'Security Center',
      icon: 'security',
    },
  ];

  if (canManageUsers(role)) {
    navItems.push({
      to: '/users',
      label: 'Officer Management',
      icon: 'manage_accounts',
      badge: 'ADMIN',
    });
  }

  return (
    <aside className="fixed left-0 top-0 h-full w-64 bg-[#0b1f3a] text-white z-50 flex flex-col justify-between border-r border-[#16365f] select-none">

      {/* =========================
          BRAND HEADER
      ========================== */}
      <div className="flex flex-col">

        <div className="h-16 flex items-center px-5 gap-3 border-b border-[#16365f] bg-[#0b1f3a]">

          {/* Police Shield */}
          <div className="w-9 h-9 rounded-lg bg-white flex items-center justify-center shadow-sm shrink-0">
            <span className="material-symbols-outlined text-[23px] text-[#0b1f3a]">
              local_police
            </span>
          </div>

          <div className="flex flex-col min-w-0">

            <span className="font-bold text-sm tracking-wide uppercase text-white leading-none truncate">
              pramāṇa-kośa
            </span>

            <span className="text-[9px] text-blue-200 uppercase tracking-wider mt-1 truncate">
              Digital Investigation Platform
            </span>

          </div>

        </div>

        {/* =========================
            SYSTEM STATUS
        ========================== */}
        <div className="px-3.5 py-3 border-b border-[#16365f]">

          <div className="px-3 py-2.5 rounded-lg bg-[#102b4d] border border-[#1c4777] flex items-center justify-between text-xs">

            <span className="flex items-center gap-2 text-blue-100">

              <span className="relative flex h-2.5 w-2.5">
                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-60"></span>
                <span className="relative inline-flex rounded-full h-2.5 w-2.5 bg-emerald-400"></span>
              </span>

              SYSTEM ONLINE

            </span>

            <span className="text-[9px] uppercase text-blue-300 font-semibold">
              SECURE
            </span>

          </div>

        </div>

        {/* =========================
            NAVIGATION
        ========================== */}
        <nav className="flex flex-col gap-1 p-3">

          <div className="px-3 pb-2 pt-1">
            <span className="text-[9px] font-semibold uppercase tracking-[0.15em] text-blue-300">
              Operations
            </span>
          </div>

          {navItems.map((item) => (

            <NavLink
              key={item.to}
              to={item.to}
              className={({ isActive }) =>
                `group flex items-center justify-between px-3 py-2.5 rounded-lg text-xs tracking-wide transition-all duration-150 ${
                  isActive
                    ? 'bg-white text-[#0b1f3a] font-semibold shadow-sm'
                    : 'text-blue-100 hover:bg-[#12345c] hover:text-white'
                }`
              }
            >

              <div className="flex items-center gap-3 min-w-0">

                <span className="material-symbols-outlined text-[19px] shrink-0">
                  {item.icon}
                </span>

                <span className="truncate">
                  {item.label}
                </span>

              </div>

              {item.badge && (

                <span
                  className={`text-[8px] font-bold px-1.5 py-0.5 rounded border ${
                    item.badge === 'ADMIN'
                      ? 'bg-amber-400/15 text-amber-300 border-amber-400/30'
                      : 'bg-emerald-400/15 text-emerald-300 border-emerald-400/30'
                  }`}
                >
                  {item.badge}
                </span>

              )}

            </NavLink>

          ))}

        </nav>

      </div>

      {/* =========================
          SECURITY / LOGOUT
      ========================== */}
      <div className="p-3 flex flex-col gap-2">

        {/* Security Status */}
        <div className="p-3 rounded-lg bg-[#102b4d] border border-[#1c4777] flex flex-col gap-2">

          <div className="flex items-center justify-between">

            <span className="flex items-center gap-2 text-[10px] text-blue-100 font-medium uppercase tracking-wide">

              <span className="material-symbols-outlined text-[15px]">
                verified_user
              </span>

              Evidence Integrity

            </span>

            <span className="text-emerald-400 font-semibold text-[9px]">
              ACTIVE
            </span>

          </div>

          <div className="h-1 rounded-full bg-[#183b64] overflow-hidden">

            <div className="h-full w-full bg-emerald-400 rounded-full"></div>

          </div>

          <div className="flex justify-between text-[9px] text-blue-300">
            <span>Database</span>
            <span>Protected</span>
          </div>

        </div>

        {/* Logout */}
        <button
          onClick={logout}
          className="w-full flex items-center justify-center gap-2 px-3 py-2.5 rounded-lg text-xs font-semibold text-blue-200 hover:text-white hover:bg-red-500/15 transition-colors"
        >

          <span className="material-symbols-outlined text-[17px]">
            logout
          </span>

          <span>
            Secure Logout
          </span>

        </button>

      </div>

    </aside>
  );
};
