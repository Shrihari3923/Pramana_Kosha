import React from 'react';
import { ShieldAlert, QrCode } from 'lucide-react';
import { Table, TableHead, TableHeaderCell, TableRow, TableCell } from '../ui/Table';
import { Badge } from '../ui/Badge';
import { EvidenceItem } from '../../types';
import { truncateHash } from '../../utils/formatters';

interface EvidenceListProps {
  items: EvidenceItem[];
  onSelect: (item: EvidenceItem) => void;
  onTransfer: (item: EvidenceItem) => void;
}

export const EvidenceList: React.FC<EvidenceListProps> = ({ items, onSelect, onTransfer }) => {
  return (
    <Table>
      <TableHead>
        <TableRow>
          <TableHeaderCell>Evidence ID / Item</TableHeaderCell>
          <TableHeaderCell>Case Reference</TableHeaderCell>
          <TableHeaderCell>Current Custodian</TableHeaderCell>
          <TableHeaderCell>Physical Location</TableHeaderCell>
          <TableHeaderCell>Custody Trail Hash</TableHeaderCell>
          <TableHeaderCell>Status</TableHeaderCell>
          <TableHeaderCell className="text-right">Actions</TableHeaderCell>
        </TableRow>
      </TableHead>
      <tbody>
        {items.map((item) => (
          <TableRow key={item.id} className="hover:bg-surface-container/30">
            <TableCell>
              <div className="flex items-start gap-2.5">
                <span className="p-2 rounded-lg bg-surface-container text-primary shrink-0">
                  <ShieldAlert size={16} />
                </span>
                <div className="flex flex-col">
                  <span className="font-bold text-forest-ink">{item.name}</span>
                  <span className="text-[11px] font-mono text-on-surface-variant">
                    Tag: {item.item_number} · {item.category}
                  </span>
                </div>
              </div>
            </TableCell>
            <TableCell className="font-mono text-xs font-bold text-primary">
              #{item.case_number}
            </TableCell>
            <TableCell>
              <span className="text-xs font-semibold text-forest-ink">{item.custodian}</span>
            </TableCell>
            <TableCell className="text-xs text-on-surface-variant">
              {item.location}
            </TableCell>
            <TableCell className="font-mono text-xs text-on-surface-variant">
              <span className="flex items-center gap-1">
                <QrCode size={13} className="text-secondary" />
                {truncateHash(item.chain_hash, 6, 6)}
              </span>
            </TableCell>
            <TableCell>
              <Badge status={item.status} />
            </TableCell>
            <TableCell className="text-right">
              <div className="flex items-center justify-end gap-2">
                <button
                  onClick={() => onTransfer(item)}
                  className="px-2.5 py-1 rounded bg-surface-container-high hover:bg-secondary-container text-forest-ink text-xs font-semibold transition-colors"
                >
                  Transfer
                </button>
                <button
                  onClick={() => onSelect(item)}
                  className="px-2.5 py-1 rounded bg-primary text-surface-bright text-xs font-semibold hover:bg-primary-container transition-colors"
                >
                  Trail ({item.custody_events.length})
                </button>
              </div>
            </TableCell>
          </TableRow>
        ))}
      </tbody>
    </Table>
  );
};
