import React, { useState } from 'react';
import { User } from '../../types';
import { userService } from '../../services/userService';

interface UserKeyModalProps {
  officer: User | null;
  isOpen: boolean;
  onClose: () => void;
  onKeyRotated?: () => void;
}

export const UserKeyModal: React.FC<UserKeyModalProps> = ({
  officer,
  isOpen,
  onClose,
  onKeyRotated,
}) => {
  const [copied, setCopied] = useState(false);
  const [isRotating, setIsRotating] = useState(false);
  const [rotationSuccess, setRotationSuccess] = useState<string | null>(null);
  const [rotationError, setRotationError] = useState<string | null>(null);

  if (!isOpen || !officer) return null;

  const keyDetails = userService.getKeyEnclaveDetails(officer);

  const handleCopyKey = () => {
    navigator.clipboard.writeText(keyDetails.publicKey);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const handleRotateKey = async () => {
    try {
      setIsRotating(true);
      setRotationError(null);
      setRotationSuccess(null);
      const result = await userService.rotateUserKey(officer.id);
      setRotationSuccess(`Key rotated successfully: ${result.publicKey}`);
      if (onKeyRotated) {
        onKeyRotated();
      }
    } catch (err: any) {
      setRotationError(err?.message || 'Failed to rotate cryptographic key');
    } finally {
      setIsRotating(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4 animate-fade-in">
      <div className="bg-[#fffdf9] rounded-xl shadow-2xl border border-[#d1dbcb] max-w-lg w-full overflow-hidden flex flex-col">
        {/* Modal Header */}
        <div className="p-4 sm:p-5 border-b border-[#d1dbcb] bg-[#f6eed6]/60 flex items-center justify-between">
          <div className="flex items-center gap-2.5">
            <div className="w-9 h-9 rounded-lg bg-[#0e1c19] text-[#fffdf9] flex items-center justify-center">
              <span className="material-symbols-outlined text-[20px]">vpn_key</span>
            </div>
            <div>
              <h3 className="text-sm font-bold text-[#1a2b27]">
                Cryptographic Key Enclave
              </h3>
              <p className="text-[11px] text-[#4e5c56]">
                FIPS 140-3 Hardware Key Binding for {officer.name}
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

        {/* Modal Body */}
        <div className="p-5 flex flex-col gap-4 text-xs">
          {/* Officer identity banner */}
          <div className="p-3 rounded-lg bg-white border border-[#d1dbcb] flex items-center justify-between">
            <div className="flex flex-col">
              <span className="font-bold text-[#1a2b27] text-sm">{officer.name}</span>
              <span className="text-[11px] text-[#4e5c56] font-mono">{officer.email}</span>
            </div>
            <div className="flex flex-col text-right">
              <span className="font-mono font-semibold text-[#2e5d4b]">
                {officer.badgeNumber || officer.badge_number || 'N/A'}
              </span>
              <span className="text-[10px] uppercase font-bold text-[#4e5c56]">{officer.role}</span>
            </div>
          </div>

          {/* Enclave specs */}
          <div className="space-y-2 border border-[#d1dbcb] rounded-lg p-3 bg-white">
            <div className="flex items-center justify-between text-[#4e5c56] pb-1 border-b border-[#d1dbcb]/40">
              <span className="font-medium">Algorithm Standard:</span>
              <span className="font-mono font-bold text-[#1a2b27]">{keyDetails.algorithm}</span>
            </div>
            <div className="flex items-center justify-between text-[#4e5c56] pb-1 border-b border-[#d1dbcb]/40">
              <span className="font-medium">Elliptic Curve:</span>
              <span className="font-mono font-bold text-[#1a2b27]">{keyDetails.curve}</span>
            </div>
            <div className="flex items-center justify-between text-[#4e5c56] pb-1 border-b border-[#d1dbcb]/40">
              <span className="font-medium">Enclave Identifier:</span>
              <span className="font-mono font-bold text-[#2e5d4b]">{keyDetails.keyEnclaveId}</span>
            </div>
            <div className="flex items-center justify-between text-[#4e5c56]">
              <span className="font-medium">Security Boundary:</span>
              <span className="font-mono text-emerald-800 font-semibold">{keyDetails.fipsLevel}</span>
            </div>
          </div>

          {/* Public Key Details with Copy */}
          <div className="flex flex-col gap-1.5">
            <div className="flex items-center justify-between">
              <span className="font-semibold text-[#1a2b27] text-[11px] uppercase tracking-wider">
                Ed25519 Public Key Digest
              </span>
              <button
                onClick={handleCopyKey}
                className="text-[11px] font-semibold text-[#2e5d4b] hover:underline flex items-center gap-1"
              >
                <span className="material-symbols-outlined text-[14px]">
                  {copied ? 'check' : 'content_copy'}
                </span>
                <span>{copied ? 'Copied' : 'Copy Key'}</span>
              </button>
            </div>
            <div className="p-2.5 rounded bg-[#f6eed6]/70 border border-[#d1dbcb] font-mono text-[11px] text-[#1a2b27] break-all select-all">
              {keyDetails.publicKey}
            </div>
          </div>

          {/* Rotation Messages */}
          {rotationSuccess && (
            <div className="p-2.5 rounded bg-emerald-50 text-emerald-900 border border-emerald-300 text-xs font-mono">
              {rotationSuccess}
            </div>
          )}

          {rotationError && (
            <div className="p-2.5 rounded bg-red-50 text-red-900 border border-red-300 text-xs font-mono">
              {rotationError}
            </div>
          )}

          {/* Institutional Compliance Notice */}
          <div className="p-3 rounded bg-[#cbe8db]/50 border border-[#2e5d4b]/30 text-[11px] text-[#143d2f] leading-relaxed">
            <strong>Section 65B Integrity Binding:</strong> This public key uniquely anchors digital signatures for FIRs, court filings, and custody transitions submitted by this officer.
          </div>
        </div>

        {/* Modal Actions */}
        <div className="p-4 border-t border-[#d1dbcb] bg-[#f6eed6]/40 flex items-center justify-between gap-3">
          <button
            onClick={handleRotateKey}
            disabled={isRotating}
            className="px-3 py-1.5 rounded bg-amber-100 hover:bg-amber-200 text-amber-950 border border-amber-300 text-xs font-semibold flex items-center gap-1.5 transition-colors disabled:opacity-60"
          >
            <span className={`material-symbols-outlined text-[16px] ${isRotating ? 'animate-spin' : ''}`}>
              refresh
            </span>
            <span>{isRotating ? 'Rotating Keypair...' : 'Rotate Key Enclave'}</span>
          </button>

          <button
            onClick={onClose}
            className="px-4 py-1.5 rounded bg-[#0e1c19] hover:bg-[#243b35] text-[#fffdf9] text-xs font-semibold transition-colors"
          >
            Done
          </button>
        </div>
      </div>
    </div>
  );
};
