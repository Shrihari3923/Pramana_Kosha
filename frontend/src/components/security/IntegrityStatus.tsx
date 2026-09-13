import React from 'react';
import { ShieldCheck, ShieldAlert, Cpu } from 'lucide-react';
import { IntegrityStatus as StatusType } from '../../types';

interface IntegrityStatusProps {
  status: StatusType;
  isTampered: boolean;
  algorithm?: string;
  latency?: string;
}

export const IntegrityStatus: React.FC<IntegrityStatusProps> = ({
  status,
  isTampered,
  algorithm = 'BLAKE2b + SHA-256',
  latency = '0.018s',
}) => {
  return (
    <div
      className={`rounded-2xl p-6 shadow-md transition-all duration-300 text-surface-bright flex flex-col gap-3 ${
        isTampered || status === 'TAMPERED'
          ? 'bg-error border-2 border-error-container shadow-error/20'
          : 'bg-primary border border-primary-container'
      }`}
    >
      <div className="flex items-center gap-3.5">
        <div
          className={`w-12 h-12 rounded-xl flex items-center justify-center shrink-0 shadow-sm ${
            isTampered ? 'bg-surface-bright text-error' : 'bg-secondary-fixed text-forest-ink'
          }`}
        >
          {isTampered ? <ShieldAlert size={28} /> : <ShieldCheck size={28} />}
        </div>
        <div className="flex flex-col">
          <span className="text-[10px] uppercase tracking-widest text-primary-fixed-dim font-bold">
            Cryptographic Attestation
          </span>
          <h3 className="text-xl font-bold tracking-tight text-surface-bright">
            {isTampered ? 'CRITICAL INTEGRITY FAILURE' : 'INTEGRITY VERIFIED'}
          </h3>
        </div>
      </div>

      <p className="text-xs text-surface-container-high leading-relaxed">
        {isTampered
          ? 'The byte payload has drifted from the genesis state. Mismatch detected against root Merkle anchor. Immediate forensic containment triggered.'
          : 'The document content strictly corresponds to the cryptographic commitment registered on the Merkle Audit Chain. Zero tampering detected.'}
      </p>

      <div className="mt-2 pt-3 bg-forest-ink/40 p-3 rounded-xl flex items-center justify-between font-mono text-xs text-surface-variant">
        <span className="flex items-center gap-1.5">
          <Cpu size={14} className="text-secondary-fixed" />
          Engine: {algorithm}
        </span>
        <span className="text-secondary-fixed font-bold">{latency}</span>
      </div>
    </div>
  );
};
