import React from 'react';
import { useNavigate } from 'react-router-dom';
import { Table, TableHead, TableHeaderCell, TableRow, TableCell } from '../ui/Table';
import { Case } from '../../types';

interface CaseListProps {
  cases: Case[];
}

export const CaseList: React.FC<CaseListProps> = ({ cases }) => {
  const navigate = useNavigate();

  return (
    <Table>
      <TableHead>
        <TableRow>
          <TableHeaderCell>Case Reference</TableHeaderCell>
          <TableHeaderCell>Matter / Statutory Scope</TableHeaderCell>
          <TableHeaderCell>Lead Officer</TableHeaderCell>
          <TableHeaderCell>Dossier State</TableHeaderCell>
          <TableHeaderCell className="text-right">Sealed Docs</TableHeaderCell>
          <TableHeaderCell>Merkle Status</TableHeaderCell>
        </TableRow>
      </TableHead>
      <tbody className="divide-y divide-moss-border/60">
        {cases.map((c) => (
          <TableRow
            key={c.id}
            onClick={() => navigate(`/cases/${c.id}`)}
            className="cursor-pointer hover:bg-surface-container-low transition-colors"
          >
            <TableCell className="font-mono font-bold text-forest-ink">
              <div className="flex items-center gap-2">
                <span className="material-symbols-outlined text-primary text-[18px]">folder</span>
                <span className="bg-surface-container px-2 py-0.5 rounded text-xs text-primary border border-moss-border">
                  {c.case_number}
                </span>
              </div>
            </TableCell>

            <TableCell>
              <div className="flex flex-col max-w-md">
                <span className="font-bold text-forest-ink hover:text-primary transition-colors text-xs">
                  {c.title}
                </span>
                <span className="text-[11px] text-forest-ink/60 line-clamp-1 mt-0.5">
                  {c.description}
                </span>
              </div>
            </TableCell>

            <TableCell>
              {c.lead_officer ? (
                <span className="text-xs font-medium text-forest-ink">
                  {c.lead_officer}
                </span>
              ) : (
                <span className="text-xs text-forest-ink/40">—</span>
              )}
            </TableCell>

            <TableCell>
              <span className={`px-2.5 py-0.5 rounded text-[10px] font-bold uppercase tracking-wider inline-flex items-center gap-1 border ${
                c.status === 'ACTIVE'
                  ? 'bg-[#C3E8D2] text-[#1B3B2B] border-[#6B8E7B]/40'
                  : c.status === 'COURT_PROCEEDINGS'
                  ? 'bg-purple-100 text-purple-900 border-purple-200'
                  : 'bg-surface-container text-forest-ink border-moss-border'
              }`}>
                <span className="w-1.5 h-1.5 rounded-full bg-current"></span>
                {c.status}
              </span>
            </TableCell>

            <TableCell className="text-right font-mono font-semibold text-xs text-forest-ink">
              {c.document_count} exhibits
            </TableCell>

            <TableCell>
              <div className="flex items-center gap-1 text-secondary font-mono text-xs font-semibold">
                <span className="material-symbols-outlined text-[15px]">verified</span>
                <span>{c.merkle_status}</span>
              </div>
            </TableCell>
          </TableRow>
        ))}
      </tbody>
    </Table>
  );
};
