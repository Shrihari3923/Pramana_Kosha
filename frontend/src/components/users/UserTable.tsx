import React from 'react';
import { User } from '../../types';

interface UserTableProps {
  personnel: User[];
  onInspectKey: (user: User) => void;
  onToggleStatus: (user: User) => void;
  actionLoadingId?: string | null;
}

export const UserTable: React.FC<UserTableProps> = ({
  personnel,
  onInspectKey,
  onToggleStatus,
  actionLoadingId,
}) => {
  const getRoleBadgeClass = (role: string) => {
    switch (role) {
      case 'ADMIN':
        return 'bg-amber-100 text-amber-950 border-amber-300';
      case 'SUPERVISOR':
        return 'bg-[#cbe8db] text-[#143d2f] border-[#2e5d4b]/30';
      default:
        return 'bg-blue-50 text-blue-900 border-blue-200';
    }
  };

  return (
    <div className="overflow-x-auto">
      <table className="w-full text-left text-xs border-collapse">
        <thead>
          <tr className="bg-[#f6eed6] text-[#1a2b27] border-b border-[#d1dbcb] uppercase font-bold text-[10px] tracking-wider">
            <th className="py-3 px-4">Officer Identity</th>
            <th className="py-3 px-4">Badge / Role</th>
            <th className="py-3 px-4">Jurisdiction / Unit</th>
            <th className="py-3 px-4">Ed25519 Public Key</th>
            <th className="py-3 px-4">Clearance Status</th>
            <th className="py-3 px-4 text-right">Actions</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-[#d1dbcb]/60 text-[#1a2b27] font-sans">
          {personnel.length === 0 ? (
            <tr>
              <td colSpan={6} className="py-16 text-center text-[#4e5c56]">
                <div className="flex flex-col items-center justify-center gap-2">
                  <span className="material-symbols-outlined text-[36px] text-[#4e5c56]/60">
                    manage_accounts
                  </span>
                  <span className="font-semibold text-sm text-[#1a2b27]">
                    No personnel records registered
                  </span>
                  <p className="text-xs text-[#4e5c56] max-w-sm">
                    No officer accounts were returned by the backend registry for this jurisdiction or filter.
                  </p>
                </div>
              </td>
            </tr>
          ) : (
            personnel.map((p) => {
              const isActionLoading = actionLoadingId === p.id;
              const isActive = p.status !== 'SUSPENDED';
              const pubKeyStr = p.publicKey || p.public_key || 'ed25519:unknown';

              return (
                <tr
                  key={p.id}
                  className="hover:bg-[#f6eed6]/30 transition-colors"
                >
                  {/* Officer Identity */}
                  <td className="py-3.5 px-4">
                    <div className="flex items-center gap-2.5">
                      <div className="w-8 h-8 rounded-full bg-[#243b35] text-white flex items-center justify-center font-bold text-[11px] shrink-0 shadow-xs">
                        {p.name ? p.name.charAt(0).toUpperCase() : 'O'}
                      </div>
                      <div className="flex flex-col min-w-0">
                        <span className="font-bold text-[#1a2b27] truncate">
                          {p.name || 'Unnamed Officer'}
                        </span>
                        <span className="text-[11px] text-[#4e5c56] font-mono truncate">
                          {p.email}
                        </span>
                      </div>
                    </div>
                  </td>

                  {/* Badge & Role */}
                  <td className="py-3.5 px-4">
                    <div className="flex flex-col">
                      <span className="font-mono font-semibold text-[#1a2b27]">
                        {p.badgeNumber || p.badge_number || 'N/A'}
                      </span>
                      <span
                        className={`text-[9px] font-bold uppercase font-mono px-1.5 py-0.5 rounded border mt-0.5 w-fit ${getRoleBadgeClass(
                          p.role
                        )}`}
                      >
                        {p.role}
                      </span>
                    </div>
                  </td>

                  {/* Department & Node */}
                  <td className="py-3.5 px-4 text-[#4e5c56]">
                    <div className="flex flex-col">
                      <span className="font-medium text-[#1a2b27]">
                        {p.department || 'Investigation Squad'}
                      </span>
                      <span className="text-[10px] font-mono text-[#4e5c56]">
                        {p.jurisdictionNode || p.jurisdiction_node || 'Node Alpha'}
                      </span>
                    </div>
                  </td>

                  {/* Ed25519 Key Fingerprint */}
                  <td className="py-3.5 px-4">
                    <button
                      onClick={() => onInspectKey(p)}
                      className="font-mono text-[11px] text-[#243b35] hover:text-[#2e5d4b] hover:underline flex items-center gap-1 group text-left"
                      title="Inspect Ed25519 Hardware Key Enclave"
                    >
                      <span className="material-symbols-outlined text-[15px] text-[#2e5d4b] group-hover:scale-110 transition-transform">
                        vpn_key
                      </span>
                      <span className="truncate max-w-[140px]">{pubKeyStr}</span>
                    </button>
                  </td>

                  {/* Clearance Status */}
                  <td className="py-3.5 px-4">
                    <span
                      className={`inline-flex items-center gap-1 px-2 py-0.5 rounded text-[10px] font-bold font-mono border ${
                        isActive
                          ? 'bg-[#cbe8db] text-[#143d2f] border-[#2e5d4b]/30'
                          : 'bg-red-100 text-red-900 border-red-300'
                      }`}
                    >
                      <span
                        className={`w-1.5 h-1.5 rounded-full ${
                          isActive ? 'bg-emerald-600' : 'bg-red-600'
                        }`}
                      ></span>
                      <span>{isActive ? 'ACTIVE' : 'SUSPENDED'}</span>
                    </span>
                  </td>

                  {/* Actions */}
                  <td className="py-3.5 px-4 text-right">
                    <div className="flex items-center justify-end gap-1.5">
                      <button
                        onClick={() => onInspectKey(p)}
                        className="px-2.5 py-1 text-[11px] font-semibold text-[#1a2b27] hover:bg-[#f6eed6] rounded border border-[#d1dbcb] transition-colors"
                        title="View hardware enclave & specs"
                      >
                        Inspect Key
                      </button>

                      <button
                        onClick={() => onToggleStatus(p)}
                        disabled={isActionLoading}
                        className={`px-2.5 py-1 text-[11px] font-semibold rounded border transition-colors ${
                          isActive
                            ? 'text-red-800 hover:bg-red-50 border-red-200'
                            : 'text-emerald-800 hover:bg-emerald-50 border-emerald-200'
                        }`}
                      >
                        {isActionLoading ? 'Saving...' : isActive ? 'Suspend' : 'Reinstate'}
                      </button>
                    </div>
                  </td>
                </tr>
              );
            })
          )}
        </tbody>
      </table>
    </div>
  );
};
