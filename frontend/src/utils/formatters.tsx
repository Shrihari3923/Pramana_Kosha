/**
 * Truncates hash strings to 8f4a...92c1 format for clean tabular viewing.
 */
export function truncateHash(hash: string, startChars: number = 6, endChars: number = 6): string {
  if (!hash) return '';
  if (hash.length <= startChars + endChars) return hash;
  return `${hash.slice(0, startChars)}...${hash.slice(-endChars)}`;
}

/**
 * Formats ISO date or unix timestamp into human-readable UTC string.
 */
export function formatTimestamp(isoString: string): string {
  if (!isoString) return '';
  try {
    const date = new Date(isoString);
    return date.toISOString().replace('T', ' ').substring(0, 19) + ' UTC';
  } catch {
    return isoString;
  }
}

/**
 * Formats bytes to MB/KB string.
 */
export function formatFileSize(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

/**
 * Status color mappings
 */
export function getIntegrityColorClass(status: string): string {
  switch (status) {
    case 'VERIFIED':
      return 'bg-secondary-container text-on-secondary-container border border-secondary/30';
    case 'TAMPERED':
      return 'bg-status-tampered-soft text-status-tampered border border-status-tampered/40';
    case 'INVALID':
      return 'bg-error-container text-on-error-container border border-error/30';
    case 'PENDING':
      return 'bg-status-pending-soft text-status-pending border border-status-pending/30';
    default:
      return 'bg-surface-container text-on-surface-variant';
  }
}
