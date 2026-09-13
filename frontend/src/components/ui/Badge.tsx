import React from 'react';
import { ShieldCheck, AlertTriangle, XCircle, Clock } from 'lucide-react';

interface BadgeProps {
  status: string;
  className?: string;
  showIcon?: boolean;
}

export const Badge: React.FC<BadgeProps> = ({ status, className = '', showIcon = true }) => {
  const normalized = status.toUpperCase();

  const getStyle = () => {
    switch (normalized) {
      case 'VERIFIED':
      case 'VALID':
      case 'ACTIVE':
      case '100% IMMUTABLE':
        return {
          bg: 'bg-secondary-container text-on-secondary-container border-secondary/30',
          icon: <ShieldCheck size={13} className="shrink-0 text-secondary" />,
        };
      case 'TAMPERED':
      case 'TAMPER DETECTED':
      case 'CORRUPTED':
        return {
          bg: 'bg-status-tampered-soft text-status-tampered border-status-tampered/40',
          icon: <AlertTriangle size={13} className="shrink-0 text-status-tampered" />,
        };
      case 'INVALID':
      case 'FAILED':
        return {
          bg: 'bg-error-container text-on-error-container border-error/30',
          icon: <XCircle size={13} className="shrink-0 text-error" />,
        };
      case 'PENDING':
      case 'UNDER_REVIEW':
        return {
          bg: 'bg-surface-container-high text-forest-ink border-moss-border',
          icon: <Clock size={13} className="shrink-0 text-forest-ink" />,
        };
      case 'COURT_PROCEEDINGS':
        return {
          bg: 'bg-surface-dim text-forest-ink border-moss-border',
          icon: null,
        };
      default:
        return {
          bg: 'bg-surface-container text-on-surface-variant border-moss-border/40',
          icon: null,
        };
    }
  };

  const { bg, icon } = getStyle();

  return (
    <span
      className={`inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-semibold tracking-wide uppercase border ${bg} ${className}`}
    >
      {showIcon && icon}
      <span>{status}</span>
    </span>
  );
};
