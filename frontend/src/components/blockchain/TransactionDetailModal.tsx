import React, { useState } from 'react';
import { Modal } from '../ui/Modal';
import { BlockchainTransaction } from '../../types';

interface Props {
  tx: BlockchainTransaction;
  onClose: () => void;
}

function HashRow({ label, value }: { label: string; value: string }) {
  const [copied, setCopied] = useState(false);
  const copy = () => {
    navigator.clipboard.writeText(value);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };
  return (
    <div className="flex flex-col gap-1">
      <span className="text-[10px] uppercase tracking-wider font-bold text-forest-ink/50">{label}</span>
      <div className="flex items-start gap-2 bg-surface-container-low rounded p-2 border border-moss-border">
        <span className="font-mono text-xs break-all text-forest-ink leading-relaxed flex-1">{value || '—'}</span>
        {value && (
          <button onClick={copy} className="shrink-0 text-forest-ink/40 hover:text-primary transition-colors" title="Copy">
            <span className="material-symbols-outlined text-[14px]">{copied ? 'check' : 'content_copy'}</span>
          </button>
        )}
      </div>
    </div>
  );
}

const ACTION_ICONS: Record<string, string> = {
  DOCUMENT_UPLOAD: 'upload_file',
  DOCUMENT_DOWNLOAD: 'download',
  SIGN_DOCUMENT: 'draw',
  CASE_CREATE: 'folder_open',
  CASE_ASSIGN_USER: 'person_add',
  USER_LOGIN: 'login',
  USER_LOGOUT: 'logout',
  USER_REGISTER: 'person_add_alt',
  EVIDENCE_REGISTER: 'policy',
  KEY_GENERATE: 'vpn_key',
};

export const TransactionDetailModal: React.FC<Props> = ({ tx, onClose }) => {
  return (
    <Modal
      isOpen
      onClose={onClose}
      title="Transaction Detail"
      subtitle={`Block #${tx.block_index} · ${new Date(tx.timestamp).toLocaleString()}`}
      maxWidth="lg"
    >
      <div className="space-y-4 text-xs">
        {/* Action badge */}
        <div className="flex items-center gap-3 p-3 bg-[#243B35] rounded-lg">
          <span className="material-symbols-outlined text-[#B7C9B1] text-[24px]">
            {ACTION_ICONS[tx.action] ?? 'receipt_long'}
          </span>
          <div>
            <div className="text-[#B7C9B1] text-[10px] uppercase tracking-wider">Action</div>
            <div className="font-mono font-bold text-[#FFF9ED] text-sm">{tx.action}</div>
          </div>
        </div>

        {/* Metadata grid */}
        <div className="grid grid-cols-2 gap-3 p-3 bg-surface-container-low rounded-lg border border-moss-border">
          <div>
            <span className="text-forest-ink/50 uppercase tracking-wide text-[10px]">Block</span>
            <div className="font-mono font-bold text-primary">#{tx.block_index}</div>
          </div>
          <div>
            <span className="text-forest-ink/50 uppercase tracking-wide text-[10px]">TX Index</span>
            <div className="font-mono text-forest-ink">{tx.tx_index}</div>
          </div>
          <div>
            <span className="text-forest-ink/50 uppercase tracking-wide text-[10px]">Actor</span>
            <div className="text-forest-ink break-all">{tx.actor_email}</div>
          </div>
          <div>
            <span className="text-forest-ink/50 uppercase tracking-wide text-[10px]">Timestamp</span>
            <div className="text-forest-ink">{new Date(tx.timestamp).toLocaleString()}</div>
          </div>
          {tx.case_id && (
            <div>
              <span className="text-forest-ink/50 uppercase tracking-wide text-[10px]">Case ID</span>
              <div className="font-mono text-forest-ink break-all">{tx.case_id}</div>
            </div>
          )}
          {tx.document_id && (
            <div>
              <span className="text-forest-ink/50 uppercase tracking-wide text-[10px]">Document ID</span>
              <div className="font-mono text-forest-ink break-all">{tx.document_id}</div>
            </div>
          )}
        </div>

        <HashRow label="Transaction Hash (sha256)" value={tx.tx_hash} />
        <HashRow label="Payload Hash" value={tx.payload_hash} />
        <HashRow label="Previous Transaction Hash" value={tx.prev_tx_hash} />

        <div className="p-3 bg-surface-container-low rounded-lg border border-moss-border text-[11px] text-forest-ink/60 space-y-1">
          <p className="font-semibold text-forest-ink/80">How this hash is computed:</p>
          <p className="font-mono">tx_hash = sha256(actor_id | action | payload_hash | prev_tx_hash | timestamp)</p>
          <p>Any modification to any field would produce a different hash, breaking the chain.</p>
        </div>

        <div className="pt-3 border-t border-moss-border flex justify-end">
          <button
            onClick={onClose}
            className="px-4 py-2 bg-surface-container hover:bg-surface-container-high text-forest-ink border border-moss-border rounded-lg text-xs font-semibold"
          >
            Close
          </button>
        </div>
      </div>
    </Modal>
  );
};
