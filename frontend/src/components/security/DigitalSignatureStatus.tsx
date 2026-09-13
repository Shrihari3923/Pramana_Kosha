import React from 'react';
import { KeyRound, ShieldCheck, XCircle } from 'lucide-react';
import { Card } from '../ui/Card';
import { SignatureStatus } from '../../types';
import { formatTimestamp } from '../../utils/formatters';

interface DigitalSignatureStatusProps {
  signerName?: string;
  publicKey?: string;
  signatureStatus: SignatureStatus;
  signedAt?: string;
}

export const DigitalSignatureStatus: React.FC<DigitalSignatureStatusProps> = ({
  signerName = 'Officer Samuel Jenkins',
  publicKey = 'ed25519:9f83ea019482bf41aa72190bc412093e',
  signatureStatus,
  signedAt = '2026-09-05T14:22:01Z',
}) => {
  const isValid = signatureStatus === 'VALID';

  return (
    <Card className="flex flex-col gap-4">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <KeyRound size={18} className="text-primary" />
          <h4 className="text-sm font-bold text-forest-ink">Ed25519 Digital Signature</h4>
        </div>
        <span
          className={`px-2.5 py-0.5 rounded-full text-xs font-bold font-mono uppercase flex items-center gap-1 border ${
            isValid
              ? 'bg-secondary-container text-on-secondary-container border-secondary/30'
              : 'bg-error-container text-on-error-container border-error/30'
          }`}
        >
          {isValid ? (
            <>
              <ShieldCheck size={13} className="text-secondary" />
              VALID SIGNATURE
            </>
          ) : (
            <>
              <XCircle size={13} className="text-error" />
              SIGNATURE INVALID
            </>
          )}
        </span>
      </div>

      <div className="flex flex-col gap-3">
        <div className="p-3 bg-surface-container rounded-xl flex flex-col gap-1 border border-moss-border/40">
          <span className="text-[10px] uppercase font-bold text-on-surface-variant tracking-wider">
            Authorized Signer
          </span>
          <span className="text-sm font-bold text-forest-ink">{signerName}</span>
          <div className="font-mono text-[11px] text-on-surface-variant truncate pt-0.5">
            Public Key: {publicKey}
          </div>
        </div>

        <div className="grid grid-cols-2 gap-3 text-xs">
          <div className="p-3 bg-surface-container rounded-xl border border-moss-border/40 flex flex-col">
            <span className="text-[10px] uppercase font-bold text-on-surface-variant">
              Curve Standard
            </span>
            <span className="font-bold text-forest-ink mt-0.5">Curve25519 (FIPS 186-5)</span>
          </div>

          <div className="p-3 bg-surface-container rounded-xl border border-moss-border/40 flex flex-col">
            <span className="text-[10px] uppercase font-bold text-on-surface-variant">
              Signature Timestamp
            </span>
            <span className="font-mono text-forest-ink font-medium mt-0.5">
              {formatTimestamp(signedAt)}
            </span>
          </div>
        </div>
      </div>
    </Card>
  );
};
