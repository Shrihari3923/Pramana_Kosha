import React from 'react';
import { ShieldAlert, FileText, CheckCircle2 } from 'lucide-react';
import { Document } from '../../types';

interface DocumentViewerProps {
  document: Document;
}

export const DocumentViewer: React.FC<DocumentViewerProps> = ({ document }) => {
  return (
    <div className="relative bg-surface-bright rounded-2xl p-6 sm:p-8 shadow-sm border border-moss-border/70 overflow-hidden min-h-[600px]">
      {/* Background Watermark */}
      <div className="pointer-events-none absolute inset-0 flex items-center justify-center select-none opacity-[0.025] rotate-[-25deg]">
        <span className="text-[90px] font-black text-forest-ink tracking-widest uppercase">
          CHAIN-DOCK RECORD
        </span>
      </div>

      {/* Tamper Alert Banner */}
      {document.is_tampered && (
        <div className="mb-6 p-4 bg-error-container text-on-error-container rounded-xl border border-error/40 flex items-start gap-3 shadow-md">
          <ShieldAlert size={24} className="text-error shrink-0 mt-0.5" />
          <div className="flex flex-col">
            <span className="text-sm font-bold text-error tracking-tight">
              CRITICAL INTEGRITY FAILURE: RECORD TAMPER DETECTED
            </span>
            <p className="text-xs text-on-error-container mt-0.5">
              The byte stream of this document payload differs from the anchored ledger commitment.
            </p>
          </div>
        </div>
      )}

      {/* Inner Document View */}
      <div className="max-w-3xl mx-auto flex flex-col gap-6 relative z-10">
        {/* Document Header */}
        <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between pb-4 bg-surface-container-low p-4 rounded-xl border border-moss-border/60 gap-3">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-lg bg-primary flex items-center justify-center text-surface-bright shadow-sm shrink-0">
              <FileText size={20} />
            </div>
            <div className="flex flex-col">
              <h2 className="text-base font-bold text-forest-ink tracking-tight">
                {document.title}
              </h2>
              <span className="text-xs text-on-surface-variant font-mono mt-0.5">
                Docket: {document.case_number || document.case_id} · Type: {document.document_type}
              </span>
            </div>
          </div>
          <div className="text-right shrink-0">
            <span className="px-2.5 py-1 rounded bg-surface-bright text-forest-ink font-mono text-xs font-bold border border-moss-border/40">
              v{document.version}.0
            </span>
          </div>
        </div>

        {/* Content Section */}
        <div className="flex flex-col gap-2">
          <span className="text-xs text-secondary uppercase font-bold tracking-wider">
            Document Content / Statement
          </span>
          <div className="p-5 bg-white rounded-xl border border-moss-border text-sm text-forest-ink leading-relaxed whitespace-pre-wrap min-h-[200px]">
            {document.description || 'No document content body recorded for this file.'}
          </div>
        </div>

        {/* Integrity Verification Card */}
        <div className="p-4 rounded-xl bg-surface-container-low border border-moss-border/60 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 text-xs">
          <div className="flex items-center gap-2">
            <CheckCircle2 size={18} className="text-primary shrink-0" />
            <span className="font-semibold text-forest-ink">SHA-256 Digest Anchored</span>
          </div>
          <span className="font-mono text-[11px] text-on-surface-variant break-all">
            {document.sha256}
          </span>
        </div>
      </div>
    </div>
  );
};
