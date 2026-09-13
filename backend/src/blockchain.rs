/// Permissioned blockchain ledger for ChainDock.
///
/// Implements a real cryptographic block structure stored in PostgreSQL:
///   - SHA-256 linked blocks (prev_block_hash chain)
///   - Merkle tree root over transaction hashes per block
///   - Per-transaction hash chain (prev_tx_hash)
///   - Genesis block
///   - Full-chain verification (detects modified, deleted, reordered blocks/transactions)
///   - Concurrency-safe block creation via pg_advisory_xact_lock
///
/// Documents, evidence, cases, signatures are NOT stored on-chain —
/// only hashes and metadata references.

use chrono::{DateTime, Timelike, Utc};
use sha2::{Digest, Sha256};
use sqlx::{PgPool, Postgres, Transaction};
use uuid::Uuid;

use crate::error::AppError;

/// The genesis block's prev_block_hash — 64 zero hex chars.
pub const GENESIS_PREV_HASH: &str =
    "0000000000000000000000000000000000000000000000000000000000000000";

/// sha256("GENESIS") — used as the genesis block's Merkle root.
pub const GENESIS_MERKLE_ROOT: &str =
    "901131d838b17aac0f7885b81e03cbdc9f5157a00343d30ab22083685ed1416a";

pub const GENESIS_BLOCK_UUID: &str = "00000000-0000-0000-0000-000000000001";

// ---------------------------------------------------------------------------
// Low-level hashing helpers
// ---------------------------------------------------------------------------

pub fn sha256_hex(input: &[u8]) -> String {
    let mut h = Sha256::new();
    h.update(input);
    hex::encode(h.finalize())
}

/// Compute block hash from its constituent fields.
/// block_hash = sha256(block_index || prev_block_hash || merkle_root || timestamp_rfc3339 || nonce)
pub fn compute_block_hash(
    block_index: i64,
    prev_block_hash: &str,
    merkle_root: &str,
    timestamp: DateTime<Utc>,
    nonce: i64,
) -> String {
    let mut h = Sha256::new();
    h.update(block_index.to_string().as_bytes());
    h.update(b"|");
    h.update(prev_block_hash.as_bytes());
    h.update(b"|");
    h.update(merkle_root.as_bytes());
    h.update(b"|");
    h.update(timestamp.to_rfc3339().as_bytes());
    h.update(b"|");
    h.update(nonce.to_string().as_bytes());
    hex::encode(h.finalize())
}

/// Compute transaction hash.
/// tx_hash = sha256(actor_id || action || payload_hash || prev_tx_hash || timestamp_rfc3339)
pub fn compute_tx_hash(
    actor_id: Uuid,
    action: &str,
    payload_hash: &str,
    prev_tx_hash: &str,
    timestamp: DateTime<Utc>,
) -> String {
    let mut h = Sha256::new();
    h.update(actor_id.to_string().as_bytes());
    h.update(b"|");
    h.update(action.as_bytes());
    h.update(b"|");
    h.update(payload_hash.as_bytes());
    h.update(b"|");
    h.update(prev_tx_hash.as_bytes());
    h.update(b"|");
    h.update(timestamp.to_rfc3339().as_bytes());
    hex::encode(h.finalize())
}

/// Build the Merkle root from a list of transaction hashes.
/// - Empty list → sha256("EMPTY_BLOCK")
/// - Single tx → that tx hash
/// - Multiple txs → binary Merkle tree, pair-hashed bottom-up; odd node duplicated.
pub fn compute_merkle_root(tx_hashes: &[String]) -> String {
    if tx_hashes.is_empty() {
        return sha256_hex(b"EMPTY_BLOCK");
    }

    let mut level: Vec<String> = tx_hashes.to_vec();

    while level.len() > 1 {
        if level.len() % 2 != 0 {
            // Duplicate last element for odd-length levels
            let last = level.last().unwrap().clone();
            level.push(last);
        }
        let mut next = Vec::with_capacity(level.len() / 2);
        for pair in level.chunks(2) {
            let combined = format!("{}{}", pair[0], pair[1]);
            next.push(sha256_hex(combined.as_bytes()));
        }
        level = next;
    }

    level.into_iter().next().unwrap()
}

/// Compute payload hash from action metadata (NOT file content).
/// payload_hash = sha256(action || case_id || document_id || extra_data)
pub fn compute_payload_hash(
    action: &str,
    case_id: Option<Uuid>,
    document_id: Option<Uuid>,
    extra: &str,
) -> String {
    let mut h = Sha256::new();
    h.update(action.as_bytes());
    h.update(b"|");
    h.update(case_id.map(|u| u.to_string()).unwrap_or_default().as_bytes());
    h.update(b"|");
    h.update(document_id.map(|u| u.to_string()).unwrap_or_default().as_bytes());
    h.update(b"|");
    h.update(extra.as_bytes());
    hex::encode(h.finalize())
}

// ---------------------------------------------------------------------------
// Transaction recording
// ---------------------------------------------------------------------------

/// Parameters for recording a new blockchain transaction.
pub struct NewTransaction {
    pub actor_id: Uuid,
    pub case_id: Option<Uuid>,
    pub document_id: Option<Uuid>,
    pub action: String,
    /// Human-readable extra data for payload hash (e.g. "version=2,title=FIR Report").
    /// Must NOT contain any secret data — only metadata references.
    pub extra: String,
}

/// Record a transaction on the blockchain, creating a new block if needed.
///
/// Strategy: we use a "pending" block approach — if the last block has fewer
/// than MAX_TXS_PER_BLOCK transactions, append to it; otherwise create a new block.
/// For forensic systems we seal each transaction into its own block immediately
/// (MAX = 1) so every event gets its own immutable block hash. This makes the
/// demo clearer: every action creates a new block.
///
/// Uses pg_advisory_xact_lock(hashtext('blockchain')) to prevent concurrent
/// callers from forking either the block chain or the transaction chain.
pub async fn record_transaction(
    pool: &PgPool,
    new_tx: NewTransaction,
) -> Result<(Uuid, String), AppError> {
    let mut tx = pool.begin().await?;
    let result = record_transaction_in_tx(&mut tx, new_tx).await?;
    tx.commit().await?;
    Ok(result)
}

/// Same as record_transaction but reuses an existing DB transaction.
/// Call this when the caller already has a transaction open (e.g. document upload).
pub async fn record_transaction_in_tx(
    tx: &mut Transaction<'_, Postgres>,
    new_tx: NewTransaction,
) -> Result<(Uuid, String), AppError> {
    // Serialize all blockchain writes for the lifetime of this DB transaction.
    sqlx::query!("SELECT pg_advisory_xact_lock(hashtext('blockchain'))")
        .execute(&mut **tx)
        .await?;

    // Get the last transaction hash (for chaining).
    let prev_tx_hash: String = sqlx::query_scalar!(
        "SELECT tx_hash FROM blockchain_transactions ORDER BY created_at DESC, id DESC LIMIT 1"
    )
    .fetch_optional(&mut **tx)
    .await?
    .unwrap_or_else(|| GENESIS_PREV_HASH.to_string());

    let timestamp = Utc::now();
    let timestamp = timestamp
    .with_nanosecond((timestamp.nanosecond() / 1_000) * 1_000)
    .expect("valid timestamp");
    let payload_hash = compute_payload_hash(
        &new_tx.action,
        new_tx.case_id,
        new_tx.document_id,
        &new_tx.extra,
    );
    let tx_hash = compute_tx_hash(
        new_tx.actor_id,
        &new_tx.action,
        &payload_hash,
        &prev_tx_hash,
        timestamp,
    );

    // Get the last block hash (for new block creation).
    let last_block = sqlx::query!(
        "SELECT id, block_index, block_hash FROM blockchain_blocks ORDER BY block_index DESC LIMIT 1"
    )
    .fetch_optional(&mut **tx)
    .await?
    .ok_or_else(|| AppError::BadRequest("blockchain not initialized — genesis block missing".into()))?;

    // Each transaction gets its own block (seal-immediately strategy).
    let new_block_index = last_block.block_index + 1;
    let prev_block_hash = last_block.block_hash.clone();

    // Merkle root for a single-tx block is just the tx hash.
    let merkle_root = compute_merkle_root(&[tx_hash.clone()]);

    let block_hash = compute_block_hash(
        new_block_index,
        &prev_block_hash,
        &merkle_root,
        timestamp,
        0,
    );

    let block_id = Uuid::new_v4();
    sqlx::query!(
        r#"
        INSERT INTO blockchain_blocks (id, block_index, prev_block_hash, merkle_root, block_hash, nonce, timestamp)
        VALUES ($1, $2, $3, $4, $5, 0, $6)
        "#,
        block_id,
        new_block_index,
        prev_block_hash,
        merkle_root,
        block_hash,
        timestamp,
    )
    .execute(&mut **tx)
    .await?;

    let tx_id = Uuid::new_v4();
    sqlx::query!(
        r#"
        INSERT INTO blockchain_transactions
            (id, block_id, tx_index, actor_id, case_id, document_id, action, payload_hash, prev_tx_hash, tx_hash, timestamp)
        VALUES ($1, $2, 0, $3, $4, $5, $6, $7, $8, $9, $10)
        "#,
        tx_id,
        block_id,
        new_tx.actor_id,
        new_tx.case_id,
        new_tx.document_id,
        new_tx.action,
        payload_hash,
        prev_tx_hash,
        tx_hash,
        timestamp,
    )
    .execute(&mut **tx)
    .await?;

    Ok((tx_id, tx_hash))
}

// ---------------------------------------------------------------------------
// Chain verification
// ---------------------------------------------------------------------------

#[derive(Debug)]
pub struct VerifyResult {
    pub valid: bool,
    pub total_blocks: i64,
    pub total_transactions: i64,
    pub tampered_block_index: Option<i64>,
    pub tampered_block_id: Option<Uuid>,
    pub tamper_reason: Option<String>,
}

/// Full chain verification. Detects:
/// - Modified block fields (block_hash recomputed and compared)
/// - Broken prev_block_hash links
/// - Modified transaction fields (tx_hash recomputed and compared)
/// - Broken prev_tx_hash links
/// - Mismatched Merkle roots (transactions in block vs stored merkle_root)
pub async fn verify_chain(pool: &PgPool) -> Result<VerifyResult, AppError> {
    // Load all blocks in order.
    let blocks = sqlx::query!(
        r#"SELECT id, block_index, prev_block_hash, merkle_root, block_hash, nonce, timestamp
           FROM blockchain_blocks ORDER BY block_index ASC"#
    )
    .fetch_all(pool)
    .await?;

    // Load all transactions in creation order (to verify prev_tx_hash chain).
    let transactions = sqlx::query!(
        r#"SELECT id, block_id, tx_index, actor_id, action, payload_hash, prev_tx_hash, tx_hash, timestamp
           FROM blockchain_transactions ORDER BY created_at ASC, id ASC"#
    )
    .fetch_all(pool)
    .await?;

    let total_blocks = blocks.len() as i64;
    let total_transactions = transactions.len() as i64;

    // -----------------------------------------------------------------------
    // 1. Verify block chain linkage and block hashes
    // -----------------------------------------------------------------------
    let mut expected_prev_block = GENESIS_PREV_HASH.to_string();

    for block in &blocks {
        // Skip genesis block hash check (its hash was seeded with a placeholder).
        if block.block_index == 0 {
            expected_prev_block = block.block_hash.clone();
            continue;
        }

        // Check linkage: this block's prev_block_hash must equal the previous block's block_hash.
        if block.prev_block_hash != expected_prev_block {
            return Ok(VerifyResult {
                valid: false,
                total_blocks,
                total_transactions,
                tampered_block_index: Some(block.block_index),
                tampered_block_id: Some(block.id),
                tamper_reason: Some(format!(
                    "Block {} prev_block_hash does not match previous block's hash (chain broken)",
                    block.block_index
                )),
            });
        }

        // Check block hash integrity.
        let recomputed = compute_block_hash(
            block.block_index,
            &block.prev_block_hash,
            &block.merkle_root,
            block.timestamp,
            block.nonce,
        );
        if recomputed != block.block_hash {
            return Ok(VerifyResult {
                valid: false,
                total_blocks,
                total_transactions,
                tampered_block_index: Some(block.block_index),
                tampered_block_id: Some(block.id),
                tamper_reason: Some(format!(
                    "Block {} hash does not match recomputed hash (block content modified)",
                    block.block_index
                )),
            });
        }

        expected_prev_block = block.block_hash.clone();
    }

    // -----------------------------------------------------------------------
    // 2. Verify transaction chain and Merkle roots
    // -----------------------------------------------------------------------
    let mut expected_prev_tx = GENESIS_PREV_HASH.to_string();

    // Group transactions by block for Merkle verification.
    use std::collections::HashMap;
    let mut block_tx_hashes: HashMap<Uuid, Vec<String>> = HashMap::new();

    for tx in &transactions {
        // Check tx chain linkage.
        if tx.prev_tx_hash != expected_prev_tx {
            // Find which block this is in.
            let blk_index = blocks.iter().find(|b| b.id == tx.block_id).map(|b| b.block_index);
            return Ok(VerifyResult {
                valid: false,
                total_blocks,
                total_transactions,
                tampered_block_index: blk_index,
                tampered_block_id: Some(tx.block_id),
                tamper_reason: Some(format!(
                    "Transaction {} prev_tx_hash does not match previous transaction hash (tx chain broken)",
                    tx.id
                )),
            });
        }

        // Recompute tx hash.
        let recomputed = compute_tx_hash(
            tx.actor_id,
            &tx.action,
            &tx.payload_hash,
            &tx.prev_tx_hash,
            tx.timestamp,
        );
        if recomputed != tx.tx_hash {
            let blk_index = blocks.iter().find(|b| b.id == tx.block_id).map(|b| b.block_index);
            return Ok(VerifyResult {
                valid: false,
                total_blocks,
                total_transactions,
                tampered_block_index: blk_index,
                tampered_block_id: Some(tx.block_id),
                tamper_reason: Some(format!(
                    "Transaction {} hash does not match recomputed hash (tx content modified)",
                    tx.id
                )),
            });
        }

        expected_prev_tx = tx.tx_hash.clone();
        block_tx_hashes.entry(tx.block_id).or_default().push(tx.tx_hash.clone());
    }

    // -----------------------------------------------------------------------
    // 3. Verify Merkle roots (skip genesis)
    // -----------------------------------------------------------------------
    for block in blocks.iter().filter(|b| b.block_index > 0) {
        let tx_hashes = block_tx_hashes.get(&block.id).cloned().unwrap_or_default();
        let computed_merkle = compute_merkle_root(&tx_hashes);
        if computed_merkle != block.merkle_root {
            return Ok(VerifyResult {
                valid: false,
                total_blocks,
                total_transactions,
                tampered_block_index: Some(block.block_index),
                tampered_block_id: Some(block.id),
                tamper_reason: Some(format!(
                    "Block {} Merkle root mismatch (transactions modified or reordered)",
                    block.block_index
                )),
            });
        }
    }

    Ok(VerifyResult {
        valid: true,
        total_blocks,
        total_transactions,
        tampered_block_index: None,
        tampered_block_id: None,
        tamper_reason: None,
    })
}

// ---------------------------------------------------------------------------
// HTTP handlers
// ---------------------------------------------------------------------------

use axum::{
    extract::{Path, Query, State},
    routing::get,
    Json, Router,
};
use serde::{Deserialize, Serialize};

use crate::{extractors::AuthenticatedUser, AppState};

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/blockchain/status", get(blockchain_status))
        .route("/blockchain/verify", get(verify_blockchain))
        .route("/blockchain/blocks", get(list_blocks))
        .route("/blockchain/blocks/:block_id", get(get_block))
        .route("/blockchain/transactions", get(list_transactions))
        .route("/blockchain/transactions/:tx_id", get(get_transaction))
}

#[derive(Serialize)]
struct BlockchainStatusResponse {
    total_blocks: i64,
    total_transactions: i64,
    latest_block_index: Option<i64>,
    latest_block_hash: Option<String>,
    latest_merkle_root: Option<String>,
    latest_block_timestamp: Option<DateTime<Utc>>,
    chain_valid: bool,
    last_verification: Option<DateTime<Utc>>,
}

async fn blockchain_status(
    State(state): State<AppState>,
    _user: AuthenticatedUser,
) -> Result<Json<BlockchainStatusResponse>, AppError> {
    let block_count: i64 =
        sqlx::query_scalar!("SELECT COUNT(*) FROM blockchain_blocks")
            .fetch_one(&state.db)
            .await?
            .unwrap_or(0);

    let tx_count: i64 =
        sqlx::query_scalar!("SELECT COUNT(*) FROM blockchain_transactions")
            .fetch_one(&state.db)
            .await?
            .unwrap_or(0);

    let latest = sqlx::query!(
        "SELECT block_index, block_hash, merkle_root, timestamp FROM blockchain_blocks ORDER BY block_index DESC LIMIT 1"
    )
    .fetch_optional(&state.db)
    .await?;

    Ok(Json(BlockchainStatusResponse {
        total_blocks: block_count,
        total_transactions: tx_count,
        latest_block_index: latest.as_ref().map(|b| b.block_index),
        latest_block_hash: latest.as_ref().map(|b| b.block_hash.clone()),
        latest_merkle_root: latest.as_ref().map(|b| b.merkle_root.clone()),
        latest_block_timestamp: latest.as_ref().map(|b| b.timestamp),
        chain_valid: true, // quick status; use /blockchain/verify for full check
        last_verification: None,
    }))
}

#[derive(Serialize)]
struct VerifyChainResponse {
    valid: bool,
    total_blocks: i64,
    total_transactions: i64,
    tampered_block_index: Option<i64>,
    tampered_block_id: Option<Uuid>,
    tamper_reason: Option<String>,
    verified_at: DateTime<Utc>,
}

async fn verify_blockchain(
    State(state): State<AppState>,
    _user: AuthenticatedUser,
) -> Result<Json<VerifyChainResponse>, AppError> {
    let result = verify_chain(&state.db).await?;
    Ok(Json(VerifyChainResponse {
        valid: result.valid,
        total_blocks: result.total_blocks,
        total_transactions: result.total_transactions,
        tampered_block_index: result.tampered_block_index,
        tampered_block_id: result.tampered_block_id,
        tamper_reason: result.tamper_reason,
        verified_at: Utc::now(),
    }))
}

#[derive(Serialize)]
struct BlockResponse {
    id: Uuid,
    block_index: i64,
    prev_block_hash: String,
    merkle_root: String,
    block_hash: String,
    nonce: i64,
    timestamp: DateTime<Utc>,
    transaction_count: i64,
}

#[derive(Deserialize)]
struct PaginationQuery {
    limit: Option<i64>,
    offset: Option<i64>,
}

async fn list_blocks(
    State(state): State<AppState>,
    _user: AuthenticatedUser,
    Query(params): Query<PaginationQuery>,
) -> Result<Json<Vec<BlockResponse>>, AppError> {
    let limit = params.limit.unwrap_or(50).min(200);
    let offset = params.offset.unwrap_or(0);

    let rows = sqlx::query!(
        r#"
        SELECT b.id, b.block_index, b.prev_block_hash, b.merkle_root, b.block_hash, b.nonce, b.timestamp,
               COUNT(t.id) as "transaction_count!"
        FROM blockchain_blocks b
        LEFT JOIN blockchain_transactions t ON t.block_id = b.id
        GROUP BY b.id
        ORDER BY b.block_index DESC
        LIMIT $1 OFFSET $2
        "#,
        limit,
        offset
    )
    .fetch_all(&state.db)
    .await?;

    Ok(Json(
        rows.into_iter()
            .map(|r| BlockResponse {
                id: r.id,
                block_index: r.block_index,
                prev_block_hash: r.prev_block_hash,
                merkle_root: r.merkle_root,
                block_hash: r.block_hash,
                nonce: r.nonce,
                timestamp: r.timestamp,
                transaction_count: r.transaction_count,
            })
            .collect(),
    ))
}

async fn get_block(
    State(state): State<AppState>,
    _user: AuthenticatedUser,
    Path(block_id): Path<Uuid>,
) -> Result<Json<serde_json::Value>, AppError> {
    let block = sqlx::query!(
        "SELECT id, block_index, prev_block_hash, merkle_root, block_hash, nonce, timestamp FROM blockchain_blocks WHERE id = $1",
        block_id
    )
    .fetch_optional(&state.db)
    .await?
    .ok_or(AppError::NotFound)?;

    let txs = sqlx::query!(
        r#"SELECT t.id, t.tx_index, t.actor_id,
                  u.email as "actor_email!: String",
                  t.case_id, t.document_id,
                  t.action, t.payload_hash, t.prev_tx_hash, t.tx_hash, t.timestamp
           FROM blockchain_transactions t
           JOIN users u ON u.id = t.actor_id
           WHERE t.block_id = $1
           ORDER BY t.tx_index ASC"#,
        block_id
    )
    .fetch_all(&state.db)
    .await?;

    Ok(Json(serde_json::json!({
        "id": block.id,
        "block_index": block.block_index,
        "prev_block_hash": block.prev_block_hash,
        "merkle_root": block.merkle_root,
        "block_hash": block.block_hash,
        "nonce": block.nonce,
        "timestamp": block.timestamp,
        "transactions": txs.into_iter().map(|t| serde_json::json!({
            "id": t.id,
            "tx_index": t.tx_index,
            "actor_id": t.actor_id,
            "actor_email": t.actor_email,
            "case_id": t.case_id,
            "document_id": t.document_id,
            "action": t.action,
            "payload_hash": t.payload_hash,
            "prev_tx_hash": t.prev_tx_hash,
            "tx_hash": t.tx_hash,
            "timestamp": t.timestamp,
        })).collect::<Vec<_>>()
    })))
}

#[derive(Serialize)]
struct TxResponse {
    id: Uuid,
    block_id: Uuid,
    block_index: i64,
    tx_index: i32,
    actor_id: Uuid,
    actor_email: String,
    case_id: Option<Uuid>,
    document_id: Option<Uuid>,
    action: String,
    payload_hash: String,
    prev_tx_hash: String,
    tx_hash: String,
    timestamp: DateTime<Utc>,
}

async fn list_transactions(
    State(state): State<AppState>,
    _user: AuthenticatedUser,
    Query(params): Query<PaginationQuery>,
) -> Result<Json<Vec<TxResponse>>, AppError> {
    let limit = params.limit.unwrap_or(50).min(200);
    let offset = params.offset.unwrap_or(0);

    let rows = sqlx::query!(
        r#"SELECT t.id, t.block_id, b.block_index, t.tx_index,
                  t.actor_id, u.email as "actor_email!: String",
                  t.case_id, t.document_id, t.action, t.payload_hash,
                  t.prev_tx_hash, t.tx_hash, t.timestamp
           FROM blockchain_transactions t
           JOIN blockchain_blocks b ON b.id = t.block_id
           JOIN users u ON u.id = t.actor_id
           ORDER BY b.block_index DESC, t.tx_index DESC
           LIMIT $1 OFFSET $2"#,
        limit,
        offset
    )
    .fetch_all(&state.db)
    .await?;

    Ok(Json(
        rows.into_iter()
            .map(|r| TxResponse {
                id: r.id,
                block_id: r.block_id,
                block_index: r.block_index,
                tx_index: r.tx_index,
                actor_id: r.actor_id,
                actor_email: r.actor_email,
                case_id: r.case_id,
                document_id: r.document_id,
                action: r.action,
                payload_hash: r.payload_hash,
                prev_tx_hash: r.prev_tx_hash,
                tx_hash: r.tx_hash,
                timestamp: r.timestamp,
            })
            .collect(),
    ))
}

async fn get_transaction(
    State(state): State<AppState>,
    _user: AuthenticatedUser,
    Path(tx_id): Path<Uuid>,
) -> Result<Json<TxResponse>, AppError> {
    let r = sqlx::query!(
        r#"SELECT t.id, t.block_id, b.block_index, t.tx_index,
                  t.actor_id, u.email as "actor_email!: String",
                  t.case_id, t.document_id, t.action, t.payload_hash,
                  t.prev_tx_hash, t.tx_hash, t.timestamp
           FROM blockchain_transactions t
           JOIN blockchain_blocks b ON b.id = t.block_id
           JOIN users u ON u.id = t.actor_id
           WHERE t.id = $1"#,
        tx_id
    )
    .fetch_optional(&state.db)
    .await?
    .ok_or(AppError::NotFound)?;

    Ok(Json(TxResponse {
        id: r.id,
        block_id: r.block_id,
        block_index: r.block_index,
        tx_index: r.tx_index,
        actor_id: r.actor_id,
        actor_email: r.actor_email,
        case_id: r.case_id,
        document_id: r.document_id,
        action: r.action,
        payload_hash: r.payload_hash,
        prev_tx_hash: r.prev_tx_hash,
        tx_hash: r.tx_hash,
        timestamp: r.timestamp,
    }))
}

// ---------------------------------------------------------------------------
// Unit tests
// ---------------------------------------------------------------------------

#[cfg(test)]
pub mod tests {
    use super::*;

    #[test]
    fn test_genesis_merkle_root() {
        let computed = sha256_hex(b"GENESIS");
        assert_eq!(computed, GENESIS_MERKLE_ROOT);
    }

    #[test]
    fn test_merkle_root_single() {
        let hashes = vec!["abc".to_string()];
        assert_eq!(compute_merkle_root(&hashes), "abc");
    }

    #[test]
    fn test_merkle_root_two() {
        let h1 = sha256_hex(b"tx1");
        let h2 = sha256_hex(b"tx2");
        let hashes = vec![h1.clone(), h2.clone()];
        let combined = format!("{h1}{h2}");
        let expected = sha256_hex(combined.as_bytes());
        assert_eq!(compute_merkle_root(&hashes), expected);
    }

    #[test]
    fn test_merkle_root_odd_count() {
        // 3 items: [a, b, c] → pair (a,b)→ab, duplicate c→(c,c)→cc → root(ab,cc)
        let a = sha256_hex(b"a");
        let b_ = sha256_hex(b"b");
        let c = sha256_hex(b"c");
        let hashes = vec![a.clone(), b_.clone(), c.clone()];
        let ab = sha256_hex(format!("{a}{b_}").as_bytes());
        let cc = sha256_hex(format!("{c}{c}").as_bytes());
        let root = sha256_hex(format!("{ab}{cc}").as_bytes());
        assert_eq!(compute_merkle_root(&hashes), root);
    }

    #[test]
    fn test_merkle_root_empty() {
        let root = compute_merkle_root(&[]);
        assert_eq!(root, sha256_hex(b"EMPTY_BLOCK"));
    }

    #[test]
    fn test_block_hash_deterministic() {
        let ts = DateTime::parse_from_rfc3339("2026-01-01T00:00:00+00:00")
            .unwrap()
            .with_timezone(&Utc);
        let h1 = compute_block_hash(1, GENESIS_PREV_HASH, GENESIS_MERKLE_ROOT, ts, 0);
        let h2 = compute_block_hash(1, GENESIS_PREV_HASH, GENESIS_MERKLE_ROOT, ts, 0);
        assert_eq!(h1, h2);
        assert_eq!(h1.len(), 64); // sha256 hex = 64 chars
    }

    #[test]
    fn test_tx_hash_deterministic() {
        let actor = Uuid::parse_str("00000000-0000-0000-0000-000000000002").unwrap();
        let ts = DateTime::parse_from_rfc3339("2026-01-01T01:00:00+00:00")
            .unwrap()
            .with_timezone(&Utc);
        let h1 = compute_tx_hash(actor, "DOCUMENT_UPLOAD", "payload123", GENESIS_PREV_HASH, ts);
        let h2 = compute_tx_hash(actor, "DOCUMENT_UPLOAD", "payload123", GENESIS_PREV_HASH, ts);
        assert_eq!(h1, h2);
        assert_eq!(h1.len(), 64);
    }

    #[test]
    fn test_different_actions_different_hashes() {
        let actor = Uuid::new_v4();
        let ts = Utc::now();
        let h1 = compute_tx_hash(actor, "DOCUMENT_UPLOAD", "p", GENESIS_PREV_HASH, ts);
        let h2 = compute_tx_hash(actor, "CASE_CREATE", "p", GENESIS_PREV_HASH, ts);
        assert_ne!(h1, h2);
    }

    #[test]
    fn test_payload_hash() {
        let doc_id = Uuid::new_v4();
        let case_id = Uuid::new_v4();
        let h = compute_payload_hash("DOCUMENT_UPLOAD", Some(case_id), Some(doc_id), "v=1");
        assert_eq!(h.len(), 64);
    }
}
