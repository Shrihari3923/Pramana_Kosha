import React from 'react';
import { ShieldCheck, AlertTriangle, ArrowRight } from 'lucide-react';
import { AuditEvent } from '../../types';
import { truncateHash, formatTimestamp } from '../../utils/formatters';

interface AuditLogViewerProps {
  events: AuditEvent[];
}

export const AuditLogViewer: React.FC<AuditLogViewerProps> = ({ events }) => {
  // Sort ascending by block number for visual sequence
  const displaySequence = [...events].sort((a, b) => a.block_number - b.block_number);

  return (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 relative">
      {displaySequence.map((evt, idx) => {
        const isTampered = evt.status === 'TAMPERED';
        const isTip = idx === displaySequence.length - 1;

        return (
          <div
            key={evt.id}
            className={`rounded-xl p-5 shadow-sm flex flex-col justify-between gap-4 transition-all duration-200 border ${
              isTampered
                ? 'bg-error-container/20 border-error text-error ring-2 ring-error/50'
                : isTip
                ? 'bg-surface-bright border-secondary ring-2 ring-secondary/30'
                : 'bg-surface-bright border-moss-border/70 hover:shadow-md'
            }`}
          >
            <div className="flex flex-col gap-2">
              <div className="flex items-center justify-between">
                <span
                  className={`px-2.5 py-0.5 rounded font-mono text-xs font-bold ${
                    isTampered
                      ? 'bg-error text-surface-bright'
                      : isTip
                      ? 'bg-secondary text-surface-bright'
                      : 'bg-surface-container-high text-forest-ink'
                  }`}
                >
                  #{evt.block_number} {isTip && '(TIP)'}
                </span>
                <span className="font-mono text-[11px] text-on-surface-variant">
                  {formatTimestamp(evt.timestamp).split(' ')[1]}
                </span>
              </div>

              <div className="flex flex-col">
                <span
                  className={`text-xs font-bold uppercase ${
                    isTampered ? 'text-error' : 'text-secondary'
                  }`}
                >
                  {evt.action}
                </span>
                <span className="text-sm font-bold text-forest-ink line-clamp-1">
                  {evt.target_reference.split('·')[1]?.trim() || evt.target_reference}
                </span>
                <span className="text-[11px] text-on-surface-variant font-mono">
                  {evt.target_reference.split('·')[0]?.trim()}
                </span>
              </div>
            </div>

            <div className="flex flex-col gap-1.5 text-xs bg-surface-container-low p-3 rounded-lg border border-moss-border/40">
              <div className="flex items-center justify-between">
                <span className="text-on-surface-variant text-[11px]">Actor:</span>
                <span className="font-semibold text-forest-ink">{evt.actor}</span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-on-surface-variant text-[11px]">Role:</span>
                <span className="px-1.5 py-0.2 rounded bg-surface text-[10px] uppercase font-bold text-forest-ink">
                  {evt.role}
                </span>
              </div>

              <div className="flex flex-col pt-1 border-t border-moss-border/30">
                <span className="text-on-surface-variant text-[10px]">Prev Hash:</span>
                <span className="font-mono text-[11px] text-forest-ink truncate">
                  {truncateHash(evt.prev_hash, 8, 4)}
                </span>
              </div>

              <div className="flex flex-col">
                <span className="text-on-surface-variant text-[10px]">Node Hash:</span>
                <span
                  className={`font-mono text-[11px] font-bold truncate flex items-center gap-1 ${
                    isTampered ? 'text-error' : 'text-secondary'
                  }`}
                >
                  {isTampered ? (
                    <AlertTriangle size={12} className="shrink-0 text-error" />
                  ) : (
                    <ShieldCheck size={12} className="shrink-0 text-secondary" />
                  )}
                  {truncateHash(evt.entry_hash, 8, 4)}
                </span>
              </div>
            </div>

            {idx < displaySequence.length - 1 && (
              <div className="hidden lg:block absolute -right-3 top-1/2 -translate-y-1/2 z-20 pointer-events-none text-secondary">
                <ArrowRight size={16} />
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
};
