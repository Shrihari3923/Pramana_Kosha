import React from 'react';
import { ShieldCheck, FileText, CheckCircle2, Clock } from 'lucide-react';
import { formatTimestamp } from '../../utils/formatters';

interface Milestone {
  id: string;
  title: string;
  timestamp: string;
  actor: string;
  type: 'opened' | 'evidence_added' | 'verified' | 'court_filed';
}

interface CaseTimelineProps {
  milestones?: Milestone[];
}

export const CaseTimeline: React.FC<CaseTimelineProps> = ({ milestones }) => {
  const defaultMilestones: Milestone[] = [
    {
      id: 'm1',
      title: 'Dossier Registered & Genesis Block Seeded',
      timestamp: '2026-08-24T08:30:00Z',
      actor: 'Officer S. Jenkins',
      type: 'opened',
    },
    {
      id: 'm2',
      title: 'UAV Orthomosaic Video & LiDAR Telemetry Sealed (SHA-256)',
      timestamp: '2026-08-26T14:10:00Z',
      actor: 'Dr. L. Thorne',
      type: 'evidence_added',
    },
    {
      id: 'm3',
      title: 'Investigator Section 65B Deposition Finalized & Ed25519 Signed',
      timestamp: '2026-09-01T09:15:00Z',
      actor: 'Commander M. Vance',
      type: 'verified',
    },
    {
      id: 'm4',
      title: 'Full Merkle Hash-Chain Verified Across 12 Witness Nodes',
      timestamp: '2026-09-05T11:00:00Z',
      actor: 'Consensus Engine v0.7.4',
      type: 'court_filed',
    },
  ];

  const items = milestones && milestones.length > 0 ? milestones : defaultMilestones;

  return (
    <div className="relative flex flex-col gap-6 pl-6 before:absolute before:left-2.5 before:top-2 before:bottom-2 before:w-0.5 before:bg-moss-border">
      {items.map((item) => (
        <div key={item.id} className="relative flex items-start gap-4">
          <div className="absolute -left-6 top-0.5 w-5 h-5 rounded-full bg-surface-bright border-2 border-primary flex items-center justify-center text-primary">
            {item.type === 'verified' ? (
              <ShieldCheck size={11} className="text-secondary" />
            ) : item.type === 'opened' ? (
              <Clock size={11} />
            ) : item.type === 'court_filed' ? (
              <CheckCircle2 size={11} className="text-secondary" />
            ) : (
              <FileText size={11} />
            )}
          </div>
          <div className="flex flex-col gap-0.5 bg-surface-container-low/70 p-3 rounded-lg w-full border border-moss-border/30">
            <div className="flex items-center justify-between">
              <span className="text-xs font-bold text-forest-ink">{item.title}</span>
              <span className="font-mono text-[10px] text-on-surface-variant">
                {formatTimestamp(item.timestamp)}
              </span>
            </div>
            <span className="text-[11px] text-on-surface-variant">
              Recorded by: <strong className="text-forest-ink">{item.actor}</strong>
            </span>
          </div>
        </div>
      ))}
    </div>
  );
};
