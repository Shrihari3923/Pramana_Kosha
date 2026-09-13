import React from 'react';
import { UserCheck, QrCode, MapPin } from 'lucide-react';
import { CustodyEvent } from '../../types';
import { formatTimestamp, truncateHash } from '../../utils/formatters';

interface ChainOfCustodyTimelineProps {
  events: CustodyEvent[];
}

export const ChainOfCustodyTimeline: React.FC<ChainOfCustodyTimelineProps> = ({ events }) => {
  return (
    <div className="relative flex flex-col gap-6 pl-6 before:absolute before:left-2.5 before:top-2 before:bottom-2 before:w-0.5 before:bg-secondary/40">
      {events.map((evt, idx) => (
        <div key={evt.id || idx} className="relative flex items-start gap-4">
          <div className="absolute -left-6 top-1 w-5 h-5 rounded-full bg-secondary text-surface-bright flex items-center justify-center text-[10px] font-bold shadow-sm">
            {idx + 1}
          </div>
          <div className="flex flex-col gap-1.5 bg-surface-container-low p-4 rounded-xl w-full border border-moss-border/60">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-1">
              <span className="text-xs font-bold text-forest-ink uppercase tracking-wider flex items-center gap-1.5">
                <UserCheck size={14} className="text-secondary" />
                {evt.action.replace(/_/g, ' ')}
              </span>
              <span className="font-mono text-[11px] text-on-surface-variant">
                {formatTimestamp(evt.timestamp)}
              </span>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 text-xs pt-1">
              <div className="p-2 bg-surface-bright rounded border border-moss-border/30">
                <span className="text-[10px] uppercase font-bold text-on-surface-variant block">
                  Released By (Previous Custodian)
                </span>
                <span className="font-semibold text-forest-ink">{evt.prev_custodian}</span>
              </div>
              <div className="p-2 bg-surface-bright rounded border border-secondary/30">
                <span className="text-[10px] uppercase font-bold text-secondary block">
                  Accepted By (New Custodian)
                </span>
                <span className="font-semibold text-forest-ink">{evt.new_custodian}</span>
              </div>
            </div>

            <div className="flex items-center justify-between text-xs text-on-surface-variant pt-1">
              <span className="flex items-center gap-1 font-mono text-[11px]">
                <MapPin size={12} /> {evt.location}
              </span>
              <span className="flex items-center gap-1 font-mono text-[11px] text-secondary font-semibold">
                <QrCode size={12} /> TX: {truncateHash(evt.tx_hash, 6, 6)}
              </span>
            </div>

            {evt.notes && (
              <p className="text-xs text-on-surface-variant bg-surface-container p-2 rounded mt-1 italic">
                "{evt.notes}"
              </p>
            )}
          </div>
        </div>
      ))}
    </div>
  );
};
