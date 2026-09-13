import React, { useState } from 'react';
import { useAuth } from '../../hooks/useAuth';

interface OfficerProfileModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const OfficerProfileModal: React.FC<OfficerProfileModalProps> = ({ isOpen, onClose }) => {
  const { user, role } = useAuth();
  const [copied, setCopied] = useState(false);

  if (!isOpen) return null;

  const pubKey = user?.publicKey || user?.public_key || `ed25519:${user?.id ? user.id.substring(0, 8) : 'curr-session'}`;

  const handleCopyKey = () => {
    navigator.clipboard.writeText(pubKey);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const getRoleBadge = (r?: string) => {
    switch (r) {
      case 'ADMIN':
        return { label: 'Administrator (Tier 3)', color: 'bg-amber-100 text-amber-950 border-amber-300' };
      case 'SUPERVISOR':
        return { label: 'Supervisor (Tier 2)', color: 'bg-[#cbe8db] text-[#143d2f] border-[#2e5d4b]/30' };
      default:
        return { label: 'Investigator (Tier 1)', color: 'bg-blue-50 text-blue-900 border-blue-200' };
    }
  };

  const badgeInfo = getRoleBadge(role);

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4 animate-fade-in">
      <div className="bg-[#fffdf9] rounded-xl shadow-2xl border border-[#d1dbcb] max-w-lg w-full overflow-hidden flex flex-col">
        {/* Header */}
        <div className="p-4 sm:p-5 border-b border-[#d1dbcb] bg-[#f6eed6]/60 flex items-center justify-between">
          <div className="flex items-center gap-2.5">
            <div className="w-9 h-9 rounded-lg bg-[#0e1c19] text-[#fffdf9] flex items-center justify-center">
              <span className="material-symbols-outlined text-[20px]">badge</span>
            </div>
            <div>
              <h3 className="text-sm font-bold text-[#1a2b27]">
                Officer Institutional Credentials
              </h3>
              <p className="text-[11px] text-[#4e5c56]">
                National Digital Evidence &amp; Case Repository Identity
              </p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-1 rounded text-[#4e5c56] hover:bg-[#d1dbcb]/50 transition-colors"
            title="Close"
          >
            <span className="material-symbols-outlined text-[20px]">close</span>
          </button>
        </div>

        {/* Profile Details */}
        <div className="p-5 flex flex-col gap-4 text-xs">
          {/* Identity Card */}
          <div className="p-4 rounded-xl bg-white border border-[#d1dbcb] flex items-center gap-4">
            <div className="w-14 h-14 rounded-full bg-[#243b35] text-white flex items-center justify-center text-xl font-bold font-serif shrink-0 shadow-xs border border-[#d1dbcb]">
              {user?.name
                ? user.name
                    .split(' ')
                    .map((n) => n[0])
                    .slice(0, 2)
                    .join('')
                : 'AO'}
            </div>
            <div className="flex flex-col min-w-0">
              <span className="text-base font-bold text-[#1a2b27] truncate">
                {user?.name || 'Authorized Officer'}
              </span>
              <span className="text-xs text-[#4e5c56] font-mono truncate">
                {user?.email || 'officer@police.gov.in'}
              </span>
              <div className="mt-1 flex items-center gap-2">
                <span
                  className={`text-[10px] font-bold font-mono px-2 py-0.5 rounded border ${badgeInfo.color}`}
                >
                  {badgeInfo.label}
                </span>
              </div>
            </div>
          </div>

          {/* Department & Jurisdiction Node */}
          <div className="grid grid-cols-2 gap-3">
            <div className="p-3 rounded-lg bg-white border border-[#d1dbcb] flex flex-col gap-0.5">
              <span className="text-[10px] uppercase font-bold text-[#4e5c56] tracking-wider">
                Badge / Serial Number
              </span>
              <span className="text-xs font-mono font-bold text-[#1a2b27]">
                {user?.badgeNumber || user?.badge_number || 'POL-8821'}
              </span>
            </div>

            <div className="p-3 rounded-lg bg-white border border-[#d1dbcb] flex flex-col gap-0.5">
              <span className="text-[10px] uppercase font-bold text-[#4e5c56] tracking-wider">
                Assigned Jurisdiction
              </span>
              <span className="text-xs font-mono font-bold text-[#2e5d4b]">
                {user?.jurisdictionNode || user?.jurisdiction_node || 'Jurisdiction Node Alpha'}
              </span>
            </div>
          </div>

          {/* Ed25519 Public Key Box */}
          <div className="p-3.5 rounded-lg bg-white border border-[#d1dbcb] flex flex-col gap-1.5">
            <div className="flex items-center justify-between">
              <span className="text-[10px] font-bold uppercase tracking-wider text-[#4e5c56]">
                Personal Ed25519 Signing Key (RFC 8032)
              </span>
              <button
                onClick={handleCopyKey}
                className="text-[11px] font-semibold text-[#2e5d4b] hover:underline flex items-center gap-1"
              >
                <span className="material-symbols-outlined text-[13px]">
                  {copied ? 'check' : 'content_copy'}
                </span>
                <span>{copied ? 'Copied' : 'Copy'}</span>
              </button>
            </div>
            <div className="p-2.5 rounded bg-[#f6eed6]/70 border border-[#d1dbcb] font-mono text-[11px] text-[#1a2b27] break-all select-all">
              {pubKey}
            </div>
            <p className="text-[10px] text-[#4e5c56] mt-0.5">
              Used to generate verifiable asymmetric signatures on document finalization and evidentiary custody handovers.
            </p>
          </div>

          {/* Legal / Institutional Compliance Notice */}
          <div className="p-3 rounded bg-[#cbe8db]/50 border border-[#2e5d4b]/30 text-[11px] text-[#143d2f] space-y-1">
            <div className="font-bold flex items-center gap-1.5">
              <span className="material-symbols-outlined text-[15px]">verified_user</span>
              <span>Court-Admissible Electronic Evidence (Section 65B)</span>
            </div>
            <p className="text-[10px] text-[#143d2f]/90 leading-relaxed">
              All digital actions taken in this session are cryptographically signed and committed to the immutable SHA-256 audit ledger.
            </p>
          </div>
        </div>

        {/* Footer */}
        <div className="p-4 border-t border-[#d1dbcb] bg-[#f6eed6]/40 flex justify-end">
          <button
            onClick={onClose}
            className="px-4 py-1.5 rounded bg-[#0e1c19] hover:bg-[#243b35] text-[#fffdf9] text-xs font-semibold transition-colors"
          >
            Close
          </button>
        </div>
      </div>
    </div>
  );
};
