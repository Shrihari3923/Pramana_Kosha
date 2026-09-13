import React from 'react';
import { Search } from 'lucide-react';

interface AuditFilterProps {
  value: string;
  onChange: (val: string) => void;
}

export const AuditFilter: React.FC<AuditFilterProps> = ({ value, onChange }) => {
  return (
    <div className="relative w-full sm:w-80">
      <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-on-surface-variant pointer-events-none" />
      <input
        type="text"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder="Filter by hash, block #, actor or docket..."
        className="w-full h-10 pl-9 pr-4 bg-surface-bright text-forest-ink placeholder:text-on-surface-variant/70 border border-moss-border/60 rounded-xl text-xs focus:outline-none focus:border-secondary shadow-sm"
      />
    </div>
  );
};
