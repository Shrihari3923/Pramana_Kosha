import React from 'react';
import { useNavigate } from 'react-router-dom';
import { Table, TableHead, TableHeaderCell, TableRow, TableCell } from '../ui/Table';
import { Document } from '../../types';
import { truncateHash } from '../../utils/formatters';

interface DocumentListProps {
  documents: Document[];
  onSelect?: (doc: Document) => void;
}

export const DocumentList: React.FC<DocumentListProps> = ({ documents, onSelect }) => {
  const navigate = useNavigate();

  return (
    <Table>
      <TableHead>
        <TableRow>
          <TableHeaderCell>Document Title / Reference</TableHeaderCell>
          <TableHeaderCell>Statutory Type</TableHeaderCell>
          <TableHeaderCell>SHA-256 Digest</TableHeaderCell>
          <TableHeaderCell>Version</TableHeaderCell>
          <TableHeaderCell>Integrity Status</TableHeaderCell>
          <TableHeaderCell>Ed25519 Signature</TableHeaderCell>
          <TableHeaderCell className="text-right">Action</TableHeaderCell>
        </TableRow>
      </TableHead>
      <tbody className="divide-y divide-moss-border/60">
        {documents.map((doc) => (
          <TableRow
            key={doc.id}
            onClick={() => (onSelect ? onSelect(doc) : navigate(`/documents/${doc.id}`))}
            className="cursor-pointer hover:bg-surface-container-low transition-colors"
          >
            <TableCell>
              <div className="flex items-start gap-2.5">
                <div className={`p-2 rounded-lg shrink-0 flex items-center justify-center ${
                  doc.is_tampered ? 'bg-red-50 text-red-700 border border-red-200' : 'bg-surface-container text-primary border border-moss-border'
                }`}>
                  <span className="material-symbols-outlined text-[18px]">
                    {doc.is_tampered ? 'gpp_bad' : 'description'}
                  </span>
                </div>
                <div className="flex flex-col max-w-sm">
                  <span className="font-bold text-forest-ink hover:text-primary transition-colors line-clamp-1 text-xs">
                    {doc.title}
                  </span>
                  <span className="text-[11px] text-forest-ink/60 font-mono">
                    Case: {doc.case_number || doc.case_id} · {doc.file_size}
                  </span>
                </div>
              </div>
            </TableCell>

            <TableCell>
              <span className="px-2 py-0.5 rounded bg-surface-container font-mono text-[11px] font-semibold text-primary border border-moss-border">
                {doc.document_type}
              </span>
            </TableCell>

            <TableCell className="font-mono text-xs text-forest-ink/70">
              <span className={doc.is_tampered ? 'text-red-700 font-bold line-through' : 'text-primary font-medium'}>
                {truncateHash(doc.sha256, 8, 8)}
              </span>
            </TableCell>

            <TableCell className="font-mono font-bold text-xs text-forest-ink">
              v{doc.version}.0
            </TableCell>

            <TableCell>
              {doc.is_tampered ? (
                <span className="px-2 py-0.5 rounded-full bg-red-100 text-red-800 font-bold text-[10px] inline-flex items-center gap-1 border border-red-300">
                  <span className="material-symbols-outlined text-[13px]">gpp_bad</span>
                  TAMPER DETECTED
                </span>
              ) : (
                <span className="px-2 py-0.5 rounded-full bg-[#C3E8D2] text-[#1B3B2B] font-semibold text-[10px] inline-flex items-center gap-1 border border-[#6B8E7B]/40">
                  <span className="material-symbols-outlined text-[13px]">verified</span>
                  VERIFIED
                </span>
              )}
            </TableCell>

            <TableCell>
              <div className="flex items-center gap-1 font-semibold text-xs text-secondary font-mono">
                {doc.signature_status === 'VALID' ? (
                  <span className="flex items-center gap-1 text-secondary">
                    <span className="material-symbols-outlined text-[14px]">vpn_key</span>
                    ED25519 SEALED
                  </span>
                ) : (
                  <span className="text-forest-ink/50">UNSIGNED</span>
                )}
              </div>
            </TableCell>

            <TableCell className="text-right">
              <button
                onClick={(e) => {
                  e.stopPropagation();
                  navigate(`/documents/${doc.id}`);
                }}
                className="p-1.5 rounded-lg text-primary hover:bg-surface-container transition-colors"
                title="Inspect Forensic Record"
              >
                <span className="material-symbols-outlined text-[18px]">visibility</span>
              </button>
            </TableCell>
          </TableRow>
        ))}
      </tbody>
    </Table>
  );
};
