export function isValidEmail(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

export function isValidCaseNumber(caseNum: string): boolean {
  return /^[A-Za-z0-9-_]{2,30}$/.test(caseNum.trim());
}

export function isValidSha256(hash: string): boolean {
  return /^[a-fA-F0-9]{64}$/.test(hash.trim());
}

/**
 * Computes actual SHA-256 hash using Web Crypto API.
 */
export async function computeSHA256(data: string | ArrayBuffer): Promise<string> {
  const buffer = typeof data === 'string' ? new TextEncoder().encode(data) : data;
  const hashBuffer = await crypto.subtle.digest('SHA-256', buffer);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
}
