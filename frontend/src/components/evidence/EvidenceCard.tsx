import React from 'react';
import { ShieldAlert, QrCode, User, MapPin, ArrowRight } from 'lucide-react';
import { Card } from '../ui/Card';
import { Badge } from '../ui/Badge';
import { EvidenceItem } from '../../types';
import { truncateHash } from '../../utils/formatters';

interface EvidenceCardProps {
  item: EvidenceItem;
  onSelect?: (item: EvidenceItem) => void;
  onTransfer?: (item: EvidenceItem) => void;
}

export const EvidenceCard: React.FC<EvidenceCardProps> = ({ item, onSelect, onTransfer }) => {
  return (
    <Card hoverable className="flex flex-col justify-between gap-4">
      <div className="flex flex-col gap-3">
        <div className="flex items-start justify-between">
          <div className="flex items-center gap-2">
            <span className="p-2 rounded-lg bg-surface-container text-primary">
              <ShieldAlert size={18} />
            </span>
            <div className="flex flex-col">
              <span className="font-mono text-xs font-bold text-primary">{item.item_number}</span>
              <span className="text-[10px] uppercase font-semibold text-on-surface-variant">
                Case #{item.case_number}
              </span>
            </div>
          </div>
          <Badge status={item.status} />
        </div>

        <div>
          <h3 className="text-base font-bold text-forest-ink line-clamp-1">{item.name}</h3>
          <p className="text-xs text-on-surface-variant line-clamp-2 mt-1">{item.description}</p>
        </div>
      </div>

      <div className="flex flex-col gap-2.5 pt-3 border-t border-moss-border/40 text-xs">
        <div className="flex items-center justify-between text-on-surface-variant">
          <span className="flex items-center gap-1">
            <User size={13} className="text-secondary" />
            Custodian: <strong className="text-forest-ink">{item.custodian}</strong>
          </span>
          <span className="flex items-center gap-1 font-mono text-[11px]">
            <MapPin size={13} /> {item.location}
          </span>
        </div>

        <div className="p-2 bg-surface-container-low rounded font-mono text-[11px] text-on-surface-variant flex items-center justify-between">
          <span className="flex items-center gap-1">
            <QrCode size={13} /> Hash: {truncateHash(item.chain_hash, 6, 6)}
          </span>
          <span className="text-secondary font-bold">SEALED</span>
        </div>

        <div className="flex items-center justify-between pt-1">
          <button
            onClick={() => onTransfer && onTransfer(item)}
            className="text-xs font-semibold text-secondary hover:text-forest-ink flex items-center gap-1"
          >
            Transfer Custody
          </button>
          <button
            onClick={() => onSelect && onSelect(item)}
            className="text-xs font-bold text-primary flex items-center gap-1 hover:underline"
          >
            View Trail <ArrowRight size={13} />
          </button>
        </div>
      </div>
    </Card>
  );
};
