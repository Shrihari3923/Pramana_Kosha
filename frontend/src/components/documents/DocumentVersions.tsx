import React from 'react';
import { History, ShieldCheck } from 'lucide-react';
import { DocumentVersion } from '../../types';
import { formatTimestamp, truncateHash } from '../../utils/formatters';

interface DocumentVersionsProps {
  versions: DocumentVersion[];
  currentVersion: number;
}

export const DocumentVersions: React.FC<DocumentVersionsProps> = ({ versions, currentVersion }) => {
  return (
    <div className="flex flex-col gap-3 p-4 bg-surface-bright rounded-xl border border-moss-border/60">
      <div className="flex items-center justify-between pb-2 border-b border-moss-border/40">
        <div className="flex items-center gap-2">
          <History size={17} className="text-secondary" />
          <h4 className="text-xs font-bold uppercase tracking-wider text-forest-ink">
            Version History &amp; Cryptographic Continuity
          </h4>
        </div>
        <span className="text-[11px] font-mono text-on-surface-variant font-semibold">
          {versions.length} versions committed
        </span>
      </div>

      <div className="flex flex-col gap-2">
        {versions.map((v) => (
          <div
            key={v.version}
            className={`p-3 rounded-lg border transition-colors flex flex-col gap-1 ${
              v.version === currentVersion
                ? 'bg-secondary-container/20 border-secondary'
                : 'bg-surface-container-low border-moss-border/40'
            }`}
          >
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <span
                  className={`px-2 py-0.5 rounded text-[10px] font-mono font-bold ${
                    v.version === currentVersion
                      ? 'bg-secondary text-surface-bright'
                      : 'bg-surface-container-high text-forest-ink'
                  }`}
                >
                  v{v.version}.0 {v.version === currentVersion && '· CURRENT (FINAL)'}
                </span>
                <span className="text-xs font-semibold text-forest-ink">{v.uploaded_by}</span>
              </div>
              <span className="font-mono text-[10px] text-on-surface-variant">
                {formatTimestamp(v.timestamp)}
              </span>
            </div>

            {v.notes && <p className="text-xs text-on-surface-variant mt-0.5">{v.notes}</p>}

            <div className="flex items-center justify-between pt-1 font-mono text-[11px] text-on-surface-variant">
              <span className="flex items-center gap-1">
                <ShieldCheck size={12} className="text-secondary" />
                Digest: <strong className="text-forest-ink">{truncateHash(v.sha256, 8, 8)}</strong>
              </span>
              <span className="text-[10px] text-secondary font-semibold">ANCHORED</span>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};
