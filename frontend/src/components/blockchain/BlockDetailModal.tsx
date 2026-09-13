import React, { useState, useEffect } from 'react';
import { Modal } from '../ui/Modal';
import { blockchainService } from '../../services/blockchain';
import { BlockchainBlock, BlockchainTransaction } from '../../types';

interface Props {
  block: BlockchainBlock;
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
        <span className="font-mono text-xs break-all text-forest-ink leading-relaxed flex-1">{value}</span>
        <button onClick={copy} className="shrink-0 text-forest-ink/40 hover:text-primary transition-colors" title="Copy">
          <span className="material-symbols-outlined text-[14px]">{copied ? 'check' : 'content_copy'}</span>
        </button>
      </div>
    </div>
  );
}

export const BlockDetailModal: React.FC<Props> = ({ block, onClose }) => {
  const [transactions, setTransactions] = useState<BlockchainTransaction[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    blockchainService.getBlock(block.id)
      .then((r) => setTransactions(r.transactions))
      .catch(() => setTransactions([]))
      .finally(() => setLoading(false));
  }, [block.id]);

  return (
    <Modal
      isOpen
      onClose={onClose}
      title={`Block #${block.block_index}`}
      subtitle={`${block.transaction_count} transaction${block.transaction_count === 1 ? '' : 's'} · ${new Date(block.timestamp).toLocaleString()}`}
      maxWidth="lg"
    >
      <div className="space-y-4 text-xs">
        <div className="grid grid-cols-2 gap-3 p-3 bg-surface-container-low rounded-lg border border-moss-border">
          <div>
            <span className="text-forest-ink/50 uppercase tracking-wide text-[10px]">Block Index</span>
            <div className="font-mono font-bold text-primary text-base">#{block.block_index}</div>
          </div>
          <div>
            <span className="text-forest-ink/50 uppercase tracking-wide text-[10px]">Nonce</span>
            <div className="font-mono text-forest-ink">{block.nonce}</div>
          </div>
          <div>
            <span className="text-forest-ink/50 uppercase tracking-wide text-[10px]">Timestamp</span>
            <div className="text-forest-ink">{new Date(block.timestamp).toLocaleString()}</div>
          </div>
          <div>
            <span className="text-forest-ink/50 uppercase tracking-wide text-[10px]">Transactions</span>
            <div className="font-mono text-forest-ink">{block.transaction_count}</div>
          </div>
        </div>

        <HashRow label="Block Hash (sha256)" value={block.block_hash} />
        <HashRow label="Previous Block Hash" value={block.prev_block_hash} />
        <HashRow label="Merkle Root" value={block.merkle_root} />

        <div>
          <h3 className="text-[10px] uppercase tracking-wider font-bold text-forest-ink/50 mb-2">Transactions in this block</h3>
          {loading ? (
            <div className="p-4 text-center text-forest-ink/50">Loading transactions…</div>
          ) : transactions.length === 0 ? (
            <div className="p-4 text-center text-forest-ink/50">Genesis block — no transactions.</div>
          ) : (
            <div className="space-y-2">
              {transactions.map((t: any) => (
                <div key={t.id} className="p-3 bg-surface-container-low rounded-lg border border-moss-border space-y-1.5">
                  <div className="flex items-center justify-between">
                    <span className="font-mono font-bold text-primary">{t.action}</span>
                    <span className="text-forest-ink/50">{t.actor_email}</span>
                  </div>
                  <div className="font-mono text-[10px] text-forest-ink/60 break-all">
                    TX: {t.tx_hash}
                  </div>
                  {t.document_id && (
                    <div className="text-[10px] text-forest-ink/50">Doc: {t.document_id}</div>
                  )}
                </div>
              ))}
            </div>
          )}
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
