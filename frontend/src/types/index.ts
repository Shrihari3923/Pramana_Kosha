export type Role = 'INVESTIGATOR' | 'SUPERVISOR' | 'ADMIN';
export type UserRole = Role;

export type CaseStatus = 'DRAFT' | 'ACTIVE' | 'UNDER_REVIEW' | 'COURT_PROCEEDINGS' | 'CLOSED' | 'ARCHIVED';

export type Priority = 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL';

export type IntegrityStatus = 'VERIFIED' | 'TAMPERED' | 'INVALID' | 'PENDING' | 'UNAVAILABLE';

export type SignatureStatus = 'VALID' | 'INVALID' | 'UNSIGNED';

export interface User {
  id: string;
  email: string;
  name: string;
  role: Role;
  badgeNumber?: string;
  badge_number?: string;
  department?: string;
  jurisdictionNode?: string;
  jurisdiction_node?: string;
  publicKey?: string;
  public_key?: string;
  status?: 'ACTIVE' | 'SUSPENDED';
  assignedCasesCount?: number;
  avatarUrl?: string;
  created_at?: string;
}

export interface CreateUserPayload {
  name: string;
  email: string;
  role: Role;
  badge_number?: string;
  department?: string;
  jurisdiction_node?: string;
  password?: string;
}

export interface UpdateUserPayload {
  name?: string;
  email?: string;
  role?: Role;
  badge_number?: string;
  department?: string;
  jurisdiction_node?: string;
  status?: 'ACTIVE' | 'SUSPENDED';
}

export interface KeyEnclaveDetails {
  userId: string;
  userName: string;
  badgeNumber: string;
  publicKey: string;
  algorithm: string;
  curve: string;
  keyEnclaveId: string;
  fipsLevel: string;
  createdAt: string;
  status: 'ACTIVE' | 'REVOKED';
}

export interface Case {
  id: string;
  case_number: string;
  title: string;
  description: string;
  status: CaseStatus;
  priority: Priority;
  jurisdiction: string;
  lead_officer: string;
  lead_officer_id?: string;
  lead_officer_badge?: string;
  supervisor: string;
  created_by: string;
  created_at: string;
  updated_at: string;
  document_count: number;
  evidence_count: number;
  merkle_status: string;
  merkle_last_checked: string;
}

export interface DocumentVersion {
  version: number;
  timestamp: string;
  sha256: string;
  uploaded_by: string;
  notes?: string;
}

export interface Document {
  id: string;
  case_id: string;
  case_number?: string;
  title: string;
  document_type: string;
  description: string;
  version: number;
  sha256: string;
  original_sha256: string;
  is_tampered: boolean;
  tamper_offset?: string;
  integrity_status: IntegrityStatus;
  signature_status: SignatureStatus;
  signer_name?: string;
  signer_key?: string;
  signed_at?: string;
  uploaded_by: string;
  file_size: string;
  file_type: string;
  classification: string;
  legal_docket_ref?: string;
  created_at: string;
  versions: DocumentVersion[];
  extracted_text: string;
  ocr_status: 'not_requested' | 'processing' | 'completed' | 'failed' | string;
  ocr_error?: string;
  ocr_completed_at?: string;
}

export interface CustodyEvent {
  id: string;
  timestamp: string;
  actor: string;
  role: Role;
  action: string;
  prev_custodian: string;
  new_custodian: string;
  location: string;
  notes: string;
  tx_hash: string;
}

export interface EvidenceItem {
  id: string;
  case_id: string;
  case_number: string;
  item_number: string;
  name: string;
  category: string;
  description: string;
  custodian: string;
  custodian_badge: string;
  location: string;
  sealed_at: string;
  chain_hash: string;
  status: 'SECURE_VAULT' | 'IN_TRANSIT' | 'COURT_EXHIBIT' | 'ANALYSIS';
  custody_events: CustodyEvent[];
}

export interface AuditEvent {
  id: string;
  block_number: number;
  timestamp: string;
  actor: string;
  role: Role;
  action: string;
  target_reference: string;
  prev_hash: string;
  entry_hash: string;
  status: 'VALID' | 'TAMPERED';
}

export interface AuditVerificationResult {
  valid: boolean;
  total_entries: number;
  checked_entries: number;
  failed_entry_id?: string;
  failed_block_number?: number;
  reason?: string;
  latency_ms: number;
  witness_nodes_online: number;
  witness_nodes_total: number;
}

// ---------------------------------------------------------------------------
// Blockchain ledger types
// ---------------------------------------------------------------------------

export interface BlockchainBlock {
  id: string;
  block_index: number;
  prev_block_hash: string;
  merkle_root: string;
  block_hash: string;
  nonce: number;
  timestamp: string;
  transaction_count: number;
}

export interface BlockchainTransaction {
  id: string;
  block_id: string;
  block_index: number;
  tx_index: number;
  actor_id: string;
  actor_email: string;
  case_id?: string;
  document_id?: string;
  action: string;
  payload_hash: string;
  prev_tx_hash: string;
  tx_hash: string;
  timestamp: string;
}

export interface BlockchainStatus {
  total_blocks: number;
  total_transactions: number;
  latest_block_index?: number;
  latest_block_hash?: string;
  latest_merkle_root?: string;
  latest_block_timestamp?: string;
  chain_valid: boolean;
  last_verification?: string;
}

export interface BlockchainVerifyResult {
  valid: boolean;
  total_blocks: number;
  total_transactions: number;
  tampered_block_index?: number;
  tampered_block_id?: string;
  tamper_reason?: string;
  verified_at: string;
}

// ---------------------------------------------------------------------------
// Digital signature types
// ---------------------------------------------------------------------------

export interface SigningKey {
  key_id: string;
  user_id: string;
  public_key_hex: string;
  fingerprint: string;
  key_mode: string; // 'DEV' | 'HSM' | 'NOT_CONFIGURED'
  created_at: string;
  revoked_at?: string;
}

export interface DocumentSignature {
  signature_id: string;
  document_id: string;
  signer_id: string;
  signer_email: string;
  document_hash: string;
  signature_hex: string;
  public_key_hex: string;
  fingerprint: string;
  signed_at: string;
  blockchain_tx_id?: string;
  blockchain_tx_hash?: string;
  verification_status: string;
}

export interface SignatureVerifyResult {
  document_id: string;
  document_hash_stored: string;
  document_hash_current: string;
  integrity_match: boolean;
  integrity_status: string; // 'VERIFIED' | 'INTEGRITY_COMPROMISED'
  signatures: SignatureVerifyDetail[];
  overall_valid: boolean;
  verified_at: string;
}

export interface SignatureVerifyDetail {
  signature_id: string;
  signer_id: string;
  signer_email: string;
  fingerprint: string;
  signed_at: string;
  verification_status: string; // 'VALID' | 'INVALID'
  verification_detail: string;
}

export interface IntegrityCheckResult {
  document_id: string;
  title: string;
  original_hash: string;
  current_hash: string;
  integrity_match: boolean;
  integrity_status: string;
  verified_at: string;
}

// ---------------------------------------------------------------------------
// Custody event types (real backend)
// ---------------------------------------------------------------------------

export interface CustodyEventReal {
  id: string;
  evidence_id: string;
  actor_id: string;
  actor_email: string;
  prev_custodian_id?: string;
  prev_custodian_email?: string;
  new_custodian_id: string;
  new_custodian_email: string;
  action: string;
  location: string;
  notes: string;
  evidence_hash: string;
  prev_event_hash: string;
  event_hash: string;
  blockchain_tx_id?: string;
  occurred_at: string;
  chain_status: string;
}

export interface CustodyVerifyResult {
  evidence_id: string;
  valid: boolean;
  total_events: number;
  broken_at_event_id?: string;
  tamper_reason?: string;
  chain_status: string; // 'CHAIN_OF_CUSTODY_VERIFIED' | 'CHAIN_OF_CUSTODY_COMPROMISED'
  verified_at: string;
}

export interface EvidenceItemReal {
  id: string;
  case_id: string;
  item_number: string;
  name: string;
  category: string;
  description: string;
  status: string;
  custodian_id: string;
  custodian_email: string;
  location: string;
  sealed_at: string;
  created_at: string;
  custody_event_count: number;
}

// ---------------------------------------------------------------------------
// Security dashboard types
// ---------------------------------------------------------------------------

export interface SecurityStats {
  crypto_integrity: {
    sha256_enabled: boolean;
    total_documents: number;
    documents_with_hash: number;
    blockchain_blocks: number;
    blockchain_transactions: number;
    audit_chain_entries: number;
    signed_documents: number;
    total_signatures: number;
    evidence_items: number;
    custody_events: number;
  };
  authentication: {
    active_sessions: number;
    revoked_tokens: number;
    total_login_attempts_24h: number;
    failed_login_attempts_24h: number;
    successful_login_attempts_24h: number;
    accounts_locked: number;
  };
  access_control: {
    total_users: number;
    investigators: number;
    supervisors: number;
    admins: number;
    denied_access_events_24h: number;
  };
  signatures: {
    signed_documents: number;
    unsigned_documents: number;
    total_signatures: number;
    users_with_keys: number;
  };
  generated_at: string;
  blockchain_status: string;
  audit_chain_status: string;
}

export interface SecurityEvent {
  id: string;
  event_type: string;
  severity: string;
  actor_id?: string;
  resource?: string;
  detail: string;
  occurred_at: string;
}

export interface LoginAttempt {
  id: string;
  email: string;
  success: boolean;
  failure_reason?: string;
  attempted_at: string;
}
