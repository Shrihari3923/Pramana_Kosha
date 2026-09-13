import React from 'react';
import { User } from '../../types';

interface UserStatsCardsProps {
  personnel: User[];
}

export const UserStatsCards: React.FC<UserStatsCardsProps> = ({ personnel }) => {
  const totalOfficers = personnel.length;
  const activeEnclaves = personnel.filter((p) => p.status !== 'SUSPENDED').length;
  const investigators = personnel.filter((p) => p.role === 'INVESTIGATOR').length;
  const supervisorsAndAdmins = personnel.filter((p) => p.role === 'SUPERVISOR' || p.role === 'ADMIN').length;

  return (
    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
      {/* Commissioned Officers */}
      <div className="bg-[#fffdf9] p-4 rounded-xl border border-[#d1dbcb] shadow-xs flex flex-col justify-between">
        <div className="flex items-center justify-between">
          <span className="text-xs font-semibold text-[#4e5c56] uppercase tracking-wider">
            Commissioned Officers
          </span>
          <div className="w-8 h-8 rounded bg-[#f6eed6] text-[#2e5d4b] flex items-center justify-center border border-[#d1dbcb]">
            <span className="material-symbols-outlined text-[18px]">badge</span>
          </div>
        </div>
        <div className="mt-3">
          <div className="text-2xl font-bold font-mono text-[#1a2b27]">
            {totalOfficers} <span className="text-sm font-sans font-normal text-[#4e5c56]">Personnel</span>
          </div>
          <div className="text-[11px] text-[#2e5d4b] font-medium mt-1 flex items-center gap-1">
            <span className="w-2 h-2 rounded-full bg-emerald-600"></span>
            <span>Live Backend Registry</span>
          </div>
        </div>
      </div>

      {/* Ed25519 Key Enclaves */}
      <div className="bg-[#fffdf9] p-4 rounded-xl border border-[#d1dbcb] shadow-xs flex flex-col justify-between">
        <div className="flex items-center justify-between">
          <span className="text-xs font-semibold text-[#4e5c56] uppercase tracking-wider">
            Ed25519 Key Enclaves
          </span>
          <div className="w-8 h-8 rounded bg-[#cbe8db] text-[#143d2f] flex items-center justify-center border border-[#2e5d4b]/30">
            <span className="material-symbols-outlined text-[18px]">vpn_key</span>
          </div>
        </div>
        <div className="mt-3">
          <div className="text-2xl font-bold font-mono text-[#1a2b27]">
            {activeEnclaves} <span className="text-sm font-sans font-normal text-[#4e5c56]">Bound</span>
          </div>
          <div className="text-[11px] text-emerald-800 font-semibold mt-1">
            FIPS 140-3 Hardware Level 3
          </div>
        </div>
      </div>

      {/* Investigator Cadre */}
      <div className="bg-[#fffdf9] p-4 rounded-xl border border-[#d1dbcb] shadow-xs flex flex-col justify-between">
        <div className="flex items-center justify-between">
          <span className="text-xs font-semibold text-[#4e5c56] uppercase tracking-wider">
            Investigator Cadre
          </span>
          <div className="w-8 h-8 rounded bg-[#f6eed6] text-[#2e5d4b] flex items-center justify-center border border-[#d1dbcb]">
            <span className="material-symbols-outlined text-[18px]">policy</span>
          </div>
        </div>
        <div className="mt-3">
          <div className="text-2xl font-bold font-mono text-[#1a2b27]">
            {investigators} <span className="text-sm font-sans font-normal text-[#4e5c56]">Officers</span>
          </div>
          <div className="text-[11px] text-[#4e5c56] mt-1">
            Assigned to Active FIR Dockets
          </div>
        </div>
      </div>

      {/* Supervisory Oversight */}
      <div className="bg-[#fffdf9] p-4 rounded-xl border border-[#d1dbcb] shadow-xs flex flex-col justify-between">
        <div className="flex items-center justify-between">
          <span className="text-xs font-semibold text-[#4e5c56] uppercase tracking-wider">
            Supervisory Oversight
          </span>
          <div className="w-8 h-8 rounded bg-[#f6eed6] text-[#2e5d4b] flex items-center justify-center border border-[#d1dbcb]">
            <span className="material-symbols-outlined text-[18px]">verified</span>
          </div>
        </div>
        <div className="mt-3">
          <div className="text-2xl font-bold font-mono text-[#1a2b27]">
            {supervisorsAndAdmins} <span className="text-sm font-sans font-normal text-[#4e5c56]">Authorities</span>
          </div>
          <div className="text-[11px] text-[#4e5c56] mt-1">
            Section 65B Digital Signing Power
          </div>
        </div>
      </div>
    </div>
  );
};
