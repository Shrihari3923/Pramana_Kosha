import React, { useState } from 'react';
import { Tag, Copy, Check } from 'lucide-react';
import { Card } from '../ui/Card';

interface HashVerificationCardProps {
  originalHash: string;
  currentHash: string;
  isTampered: boolean;
  algorithm?: string;
}

export const HashVerificationCard: React.FC<HashVerificationCardProps> = ({
  originalHash,
  currentHash,
  isTampered,
  algorithm = 'SHA-256 (256-bit Hexadecimal)',
}) => {
  const [copied, setCopied] = useState(false);

  const handleCopy = () => {
    navigator.clipboard.writeText(currentHash);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <Card className="flex flex-col gap-3">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <Tag size={18} className="text-primary" />
          <h4 className="text-sm font-bold text-forest-ink">Payload Digest Verification</h4>
        </div>
        <span
          className={`px-2 py-0.5 rounded text-xs font-bold font-mono uppercase ${
            isTampered
              ? 'bg-error-container text-error border border-error/30'
              : 'bg-secondary-container text-on-secondary-container border border-secondary/30'
          }`}
        >
          {isTampered ? 'MISMATCH (TAMPERED)' : 'MATCHED (VALID)'}
        </span>
      </div>

      <div className="bg-surface-container-low p-3.5 rounded-xl border border-moss-border/60 flex flex-col gap-2">
        <div className="flex flex-col gap-1">
          <span className="text-[10px] uppercase font-bold text-on-surface-variant tracking-wider">
            Ledger Committed Hash:
          </span>
          <div className="font-mono text-xs text-forest-ink font-semibold break-all bg-surface-bright p-2 rounded border border-moss-border/30 select-all">
            {originalHash}
          </div>
        </div>

        {isTampered && (
          <div className="flex flex-col gap-1 pt-1">
            <span className="text-[10px] uppercase font-bold text-error tracking-wider">
              Recalculated Buffer Hash (Drift Detected):
            </span>
            <div className="font-mono text-xs text-error font-bold break-all bg-error-container/40 p-2 rounded border border-error/30 select-all">
              {currentHash}
            </div>
          </div>
        )}

        <div className="flex items-center justify-between pt-1 text-[11px] text-on-surface-variant font-mono">
          <span>Standard: {algorithm}</span>
          <button
            onClick={handleCopy}
            className="text-secondary hover:text-forest-ink font-semibold flex items-center gap-1 transition-colors"
          >
            {copied ? <Check size={13} /> : <Copy size={13} />}
            <span>{copied ? 'Copied' : 'Copy Digest'}</span>
          </button>
        </div>
      </div>
    </Card>
  );
};
