import React, { TableHTMLAttributes } from 'react';

export const Table: React.FC<TableHTMLAttributes<HTMLTableElement>> = ({
  children,
  className = '',
  ...props
}) => {
  return (
    <div className="w-full overflow-hidden rounded-xl border border-moss-border/70 bg-surface-bright shadow-sm">
      <div className="overflow-x-auto">
        <table className={`w-full text-left border-collapse text-sm text-forest-ink ${className}`} {...props}>
          {children}
        </table>
      </div>
    </div>
  );
};

export const TableHead: React.FC<React.HTMLAttributes<HTMLTableSectionElement>> = ({
  children,
  className = '',
  ...props
}) => {
  return (
    <thead className={`bg-surface-dim border-b border-moss-border text-forest-ink ${className}`} {...props}>
      {children}
    </thead>
  );
};

export const TableRow: React.FC<React.HTMLAttributes<HTMLTableRowElement>> = ({
  children,
  className = '',
  ...props
}) => {
  return (
    <tr className={`hover:bg-surface-container/40 border-b border-moss-border/40 last:border-0 transition-colors ${className}`} {...props}>
      {children}
    </tr>
  );
};

export const TableHeaderCell: React.FC<React.ThHTMLAttributes<HTMLTableCellElement>> = ({
  children,
  className = '',
  ...props
}) => {
  return (
    <th className={`py-3 px-4 text-xs font-semibold uppercase tracking-wider text-forest-ink ${className}`} {...props}>
      {children}
    </th>
  );
};

export const TableCell: React.FC<React.TdHTMLAttributes<HTMLTableCellElement>> = ({
  children,
  className = '',
  ...props
}) => {
  return (
    <td className={`py-3.5 px-4 align-middle ${className}`} {...props}>
      {children}
    </td>
  );
};
