import React from 'react';
import { ShieldCheck, AlertTriangle } from 'lucide-react';

interface AuditVerificationBadgeProps {
  valid: boolean;
  checkedCount: number;
}

export const AuditVerificationBadge: React.FC<AuditVerificationBadgeProps> = ({
  valid,
  checkedCount,
}) => {
  return (
    <div
      className={`inline-flex items-center gap-2 px-3 py-1.5 rounded-full text-xs font-bold font-mono tracking-wider border shadow-sm ${
        valid
          ? 'bg-secondary-container text-on-secondary-container border-secondary/30'
          : 'bg-error-container text-on-error-container border-error/40 animate-pulse'
      }`}
    >
      {valid ? (
        <>
          <ShieldCheck size={16} className="text-secondary" />
          <span>CHAIN VERIFIED ({checkedCount}/{checkedCount} BLOCKS)</span>
        </>
      ) : (
        <>
          <AlertTriangle size={16} className="text-error" />
          <span>CHAIN FAILURE: MISMATCH DETECTED</span>
        </>
      )}
    </div>
  );
};
