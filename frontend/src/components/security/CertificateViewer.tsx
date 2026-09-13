import React from 'react';
import { Award, ShieldCheck } from 'lucide-react';
import { Modal } from '../ui/Modal';
import { Button } from '../ui/Button';

import { Document } from '../../types';

interface CertificateViewerProps {
  isOpen: boolean;
  onClose: () => void;
  document?: Document;
}

export const CertificateViewer: React.FC<CertificateViewerProps> = ({ isOpen, onClose, document }) => {
  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title={document ? `Section 65B Electronic Certificate — ${document.title}` : 'Root Security & HSM Certificate'}
      subtitle={document ? `Legal Reference: ${document.legal_docket_ref || document.id}` : 'FIPS 140-3 Level 3 Hardware Security Module Attestation'}
      icon={<Award size={20} />}
    >
      <div className="flex flex-col gap-4 text-xs text-forest-ink">
        <div className="p-4 bg-secondary-container/30 border border-secondary/40 rounded-xl flex items-start gap-3">
          <ShieldCheck size={24} className="text-secondary shrink-0 mt-0.5" />
          <div className="flex flex-col">
            <span className="font-bold text-sm text-forest-ink">
              Certificate Valid · Chain of Trust Verified
            </span>
            <p className="text-on-surface-variant mt-0.5">
              Issued by National Cryptographic Infrastructure Authority under Section 65B Digital Evidence Guidelines.
            </p>
          </div>
        </div>

        <div className="grid grid-cols-2 gap-3">
          <div className="p-3 bg-surface-container-low rounded-xl border border-moss-border/60">
            <span className="text-[10px] uppercase font-bold text-on-surface-variant block">
              Common Name (CN)
            </span>
            <span className="font-mono font-bold text-forest-ink">
              chaindock-root-ca-alpha.gov.in
            </span>
          </div>

          <div className="p-3 bg-surface-container-low rounded-xl border border-moss-border/60">
            <span className="text-[10px] uppercase font-bold text-on-surface-variant block">
              Serial Number
            </span>
            <span className="font-mono text-forest-ink">0x4F92-A108-8839-E401</span>
          </div>
        </div>

        <div className="p-3 bg-surface-container-low rounded-xl border border-moss-border/60 flex flex-col gap-1 font-mono text-[11px]">
          <span className="text-[10px] uppercase font-bold text-on-surface-variant">
            SHA-256 Fingerprint:
          </span>
          <span className="break-all text-forest-ink font-semibold">
            B9:44:8A:10:92:CF:7B:A1:08:44:E2:19:0C:4A:88:91:02:14:55:90:3A:C1:88:D2:19:40:AA:11:80:23:44:19
          </span>
        </div>

        <div className="grid grid-cols-2 gap-3 text-[11px]">
          <div className="p-2.5 bg-surface-container rounded-lg">
            <span className="text-on-surface-variant block">Valid From:</span>
            <strong className="font-mono">2025-01-01 00:00:00 UTC</strong>
          </div>
          <div className="p-2.5 bg-surface-container rounded-lg">
            <span className="text-on-surface-variant block">Expires:</span>
            <strong className="font-mono">2035-12-31 23:59:59 UTC</strong>
          </div>
        </div>

        <div className="flex justify-end pt-2 border-t border-moss-border/40">
          <Button variant="secondary" onClick={onClose}>
            Close Certificate
          </Button>
        </div>
      </div>
    </Modal>
  );
};
