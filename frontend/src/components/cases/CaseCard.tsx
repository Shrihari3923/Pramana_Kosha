import React from 'react';
import { useNavigate } from 'react-router-dom';
import { Card } from '../ui/Card';
import { Case } from '../../types';

interface CaseCardProps {
  caseItem: Case;
}

export const CaseCard: React.FC<CaseCardProps> = ({ caseItem }) => {
  const navigate = useNavigate();

  return (
    <Card
      hoverable
      onClick={() => navigate(`/cases/${caseItem.id}`)}
      className="flex flex-col justify-between gap-4 bg-surface-bright border border-moss-border rounded-xl p-5 hover:border-primary/60 transition-all shadow-xs"
    >
      <div className="flex flex-col gap-3">
        <div className="flex items-start justify-between gap-2">
          <div className="flex items-center gap-2">
            <span className="p-1.5 rounded-lg bg-surface-container text-primary flex items-center justify-center">
              <span className="material-symbols-outlined text-[18px]">folder</span>
            </span>
            <span className="font-mono text-xs font-bold text-primary bg-surface-container-low px-2 py-0.5 rounded border border-moss-border/60">
              {caseItem.case_number}
            </span>
          </div>
          <span className={`px-2 py-0.5 rounded text-[10px] font-bold uppercase tracking-wider inline-flex items-center gap-1 border ${
            caseItem.status === 'ACTIVE'
              ? 'bg-[#C3E8D2] text-[#1B3B2B] border-[#6B8E7B]/40'
              : caseItem.status === 'COURT_PROCEEDINGS'
              ? 'bg-purple-100 text-purple-900 border-purple-200'
              : 'bg-surface-container text-forest-ink border-moss-border'
          }`}>
            <span className="w-1.5 h-1.5 rounded-full bg-current"></span>
            {caseItem.status}
          </span>
        </div>

        <div>
          <h3 className="text-sm font-bold text-primary line-clamp-1 hover:underline">
            {caseItem.title}
          </h3>
          <p className="text-xs text-forest-ink/70 line-clamp-2 mt-1 leading-relaxed">
            {caseItem.description}
          </p>
        </div>
      </div>

      <div className="flex flex-col gap-2.5 border-t border-moss-border/60 pt-3">
        <div className="flex items-center justify-between text-xs text-forest-ink/70">
          <span className="truncate max-w-[170px]">
            Lead: <strong className="text-primary">{caseItem.lead_officer}</strong>
          </span>
          <span className="font-mono text-[11px] text-secondary font-semibold flex items-center gap-1">
            <span className="material-symbols-outlined text-[13px]">verified</span>
            {caseItem.merkle_status}
          </span>
        </div>

        <div className="flex items-center justify-between pt-1 text-xs">
          <div className="flex items-center gap-3 text-forest-ink/60 font-mono text-[11px]">
            <span className="flex items-center gap-1">
              <span className="material-symbols-outlined text-[14px]">description</span>
              {caseItem.document_count} docs
            </span>
            <span className="flex items-center gap-1">
              <span className="material-symbols-outlined text-[14px]">inventory_2</span>
              {caseItem.evidence_count} evidence
            </span>
          </div>
          <span className="text-primary font-semibold text-xs flex items-center gap-0.5 hover:underline">
            <span>Dossier</span>
            <span className="material-symbols-outlined text-[15px]">arrow_forward</span>
          </span>
        </div>
      </div>
    </Card>
  );
};
