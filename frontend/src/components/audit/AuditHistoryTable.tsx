import React from 'react';
import { Table, TableHead, TableHeaderCell, TableRow, TableCell } from '../ui/Table';
import { Badge } from '../ui/Badge';
import { AuditEvent } from '../../types';
import { truncateHash, formatTimestamp } from '../../utils/formatters';

interface AuditHistoryTableProps {
  events: AuditEvent[];
}

export const AuditHistoryTable: React.FC<AuditHistoryTableProps> = ({ events }) => {
  return (
    <Table>
      <TableHead>
        <TableRow>
          <TableHeaderCell>Block #</TableHeaderCell>
          <TableHeaderCell>Timestamp (UTC)</TableHeaderCell>
          <TableHeaderCell>Actor / Role</TableHeaderCell>
          <TableHeaderCell>Event Action</TableHeaderCell>
          <TableHeaderCell>Target Docket / File</TableHeaderCell>
          <TableHeaderCell>Chain Leaf Hash</TableHeaderCell>
          <TableHeaderCell className="text-right">State</TableHeaderCell>
        </TableRow>
      </TableHead>
      <tbody>
        {events.map((evt) => (
          <TableRow
            key={evt.id}
            className={`transition-colors ${
              evt.status === 'TAMPERED'
                ? 'bg-error-container/20 hover:bg-error-container/30 border-l-4 border-l-error'
                : 'hover:bg-surface-container/30'
            }`}
          >
            <TableCell className="font-mono font-bold text-xs text-forest-ink">
              #{evt.block_number}
            </TableCell>
            <TableCell className="font-mono text-xs text-on-surface-variant">
              {formatTimestamp(evt.timestamp)}
            </TableCell>
            <TableCell>
              <div className="flex flex-col">
                <span className="font-semibold text-xs text-forest-ink">{evt.actor}</span>
                <span className="text-[10px] uppercase font-bold text-on-surface-variant">
                  {evt.role}
                </span>
              </div>
            </TableCell>
            <TableCell>
              <span className="px-2 py-0.5 rounded bg-surface-container font-mono text-[11px] font-bold text-forest-ink">
                {evt.action}
              </span>
            </TableCell>
            <TableCell className="text-xs text-forest-ink max-w-xs truncate">
              {evt.target_reference}
            </TableCell>
            <TableCell className="font-mono text-xs text-on-surface-variant">
              <span className={evt.status === 'TAMPERED' ? 'text-error font-bold' : ''}>
                {truncateHash(evt.entry_hash, 6, 6)}
              </span>
            </TableCell>
            <TableCell className="text-right">
              <Badge status={evt.status} />
            </TableCell>
          </TableRow>
        ))}
      </tbody>
    </Table>
  );
};
