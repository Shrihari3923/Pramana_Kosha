import React, { useState } from 'react';
import { Role, User } from '../../types';
import { userService } from '../../services/userService';

interface UserProvisionModalProps {
  isOpen: boolean;
  onClose: () => void;
  onCreated: (newUser: User) => void;
}

export const UserProvisionModal: React.FC<UserProvisionModalProps> = ({
  isOpen,
  onClose,
  onCreated,
}) => {
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [role, setRole] = useState<Role>('INVESTIGATOR');
  const [badgeNumber, setBadgeNumber] = useState('');
  const [department, setDepartment] = useState('State Special Crime Branch');
  const [jurisdictionNode, setJurisdictionNode] = useState('Jurisdiction Node Alpha');
  const [submitting, setSubmitting] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  if (!isOpen) return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!name || !email) return;

    try {
      setSubmitting(true);
      setErrorMessage(null);
      
      const createdUser = await userService.createUser({
        name,
        email,
        role,
        badge_number: badgeNumber || `POL-${Math.floor(1000 + Math.random() * 9000)}`,
        department: department || 'Investigation Squad',
        jurisdiction_node: jurisdictionNode || 'Jurisdiction Alpha',
      });

      onCreated(createdUser);
      onClose();
      // Reset
      setName('');
      setEmail('');
      setBadgeNumber('');
      setRole('INVESTIGATOR');
    } catch (err: any) {
      setErrorMessage(err?.message || 'Failed to provision officer credential on backend.');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4 animate-fade-in">
      <div className="bg-[#fffdf9] rounded-xl shadow-2xl border border-[#d1dbcb] max-w-md w-full overflow-hidden flex flex-col">
        {/* Header */}
        <div className="p-4 sm:p-5 border-b border-[#d1dbcb] bg-[#f6eed6]/60 flex items-center justify-between">
          <div className="flex items-center gap-2.5">
            <div className="w-9 h-9 rounded-lg bg-[#0e1c19] text-[#fffdf9] flex items-center justify-center">
              <span className="material-symbols-outlined text-[20px]">person_add</span>
            </div>
            <div>
              <h3 className="text-sm font-bold text-[#1a2b27]">
                Provision Officer Credential
              </h3>
              <p className="text-[11px] text-[#4e5c56]">
                Institutional Onboarding &amp; Ed25519 Hardware Issuance
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

        {/* Form Body */}
        <form onSubmit={handleSubmit} className="p-5 flex flex-col gap-3.5 text-xs">
          {errorMessage && (
            <div className="p-2.5 rounded bg-red-50 text-red-900 border border-red-300 font-mono text-[11px]">
              {errorMessage}
            </div>
          )}

          <div>
            <label className="font-semibold text-[#1a2b27] block mb-1">
              Officer Full Name <span className="text-red-600">*</span>
            </label>
            <input
              type="text"
              required
              placeholder="e.g. Inspector Ananya Ray"
              value={name}
              onChange={(e) => setName(e.target.value)}
              className="w-full h-9 px-3 text-xs bg-white rounded border border-[#d1dbcb] text-[#1a2b27] focus:outline-none focus:border-[#2e5d4b]"
            />
          </div>

          <div>
            <label className="font-semibold text-[#1a2b27] block mb-1">
              Institutional Email <span className="text-red-600">*</span>
            </label>
            <input
              type="email"
              required
              placeholder="e.g. ananya.ray@police.gov.in"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full h-9 px-3 text-xs bg-white rounded border border-[#d1dbcb] text-[#1a2b27] focus:outline-none focus:border-[#2e5d4b]"
            />
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="font-semibold text-[#1a2b27] block mb-1">
                Badge / Serial #
              </label>
              <input
                type="text"
                placeholder="e.g. INSP-8821"
                value={badgeNumber}
                onChange={(e) => setBadgeNumber(e.target.value)}
                className="w-full h-9 px-3 text-xs bg-white rounded border border-[#d1dbcb] text-[#1a2b27] focus:outline-none focus:border-[#2e5d4b]"
              />
            </div>

            <div>
              <label className="font-semibold text-[#1a2b27] block mb-1">
                Clearance Cadre / Role
              </label>
              <select
                value={role}
                onChange={(e) => setRole(e.target.value as Role)}
                className="w-full h-9 px-2 text-xs bg-white rounded border border-[#d1dbcb] text-[#1a2b27] focus:outline-none focus:border-[#2e5d4b]"
              >
                <option value="INVESTIGATOR">Investigator (Tier 1)</option>
                <option value="SUPERVISOR">Supervisor (Tier 2)</option>
                <option value="ADMIN">Administrator (Tier 3)</option>
              </select>
            </div>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="font-semibold text-[#1a2b27] block mb-1">
                Department / Branch
              </label>
              <input
                type="text"
                value={department}
                onChange={(e) => setDepartment(e.target.value)}
                className="w-full h-9 px-3 text-xs bg-white rounded border border-[#d1dbcb] text-[#1a2b27] focus:outline-none focus:border-[#2e5d4b]"
              />
            </div>

            <div>
              <label className="font-semibold text-[#1a2b27] block mb-1">
                Jurisdiction Node
              </label>
              <input
                type="text"
                value={jurisdictionNode}
                onChange={(e) => setJurisdictionNode(e.target.value)}
                className="w-full h-9 px-3 text-xs bg-white rounded border border-[#d1dbcb] text-[#1a2b27] focus:outline-none focus:border-[#2e5d4b]"
              />
            </div>
          </div>

          <div className="p-3 rounded bg-[#cbe8db]/50 border border-[#2e5d4b]/30 text-[11px] text-[#143d2f] leading-relaxed mt-1">
            <strong>Automatic Enclave Provisioning:</strong> Submitting will request the backend HSM to generate a dedicated Ed25519 Curve25519 keypair for cryptographic evidence signing.
          </div>

          {/* Form Actions */}
          <div className="flex justify-end gap-2 pt-3 border-t border-[#d1dbcb] mt-2">
            <button
              type="button"
              onClick={onClose}
              disabled={submitting}
              className="px-3.5 py-2 rounded text-xs font-semibold text-[#4e5c56] hover:bg-[#f6eed6] transition-colors"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={submitting}
              className="px-4 py-2 rounded bg-[#0e1c19] hover:bg-[#243b35] text-[#fffdf9] text-xs font-semibold flex items-center gap-1.5 transition-colors disabled:opacity-60 shadow-xs"
            >
              {submitting ? (
                <>
                  <span className="w-3.5 h-3.5 border-2 border-white border-t-transparent rounded-full animate-spin"></span>
                  <span>Provisioning Backend...</span>
                </>
              ) : (
                <>
                  <span className="material-symbols-outlined text-[16px]">how_to_reg</span>
                  <span>Commission Officer</span>
                </>
              )}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
