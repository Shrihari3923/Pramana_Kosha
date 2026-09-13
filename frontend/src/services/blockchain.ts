import { api } from './api';
import {
  BlockchainStatus,
  BlockchainBlock,
  BlockchainTransaction,
  BlockchainVerifyResult,
} from '../types';

export async function getBlockchainStatus(): Promise<BlockchainStatus> {
  const res = await api.get<BlockchainStatus>('/blockchain/status');
  return res.data;
}

export async function verifyBlockchain(): Promise<BlockchainVerifyResult> {
  const res = await api.get<BlockchainVerifyResult>('/blockchain/verify');
  return res.data;
}

export async function listBlocks(limit = 50, offset = 0): Promise<BlockchainBlock[]> {
  const res = await api.get<BlockchainBlock[]>(`/blockchain/blocks?limit=${limit}&offset=${offset}`);
  return Array.isArray(res.data) ? res.data : [];
}

export async function getBlock(blockId: string): Promise<{ block: BlockchainBlock; transactions: BlockchainTransaction[] }> {
  const res = await api.get<any>(`/blockchain/blocks/${blockId}`);
  const raw = res.data;
  return {
    block: {
      id: raw.id,
      block_index: raw.block_index,
      prev_block_hash: raw.prev_block_hash,
      merkle_root: raw.merkle_root,
      block_hash: raw.block_hash,
      nonce: raw.nonce,
      timestamp: raw.timestamp,
      transaction_count: (raw.transactions || []).length,
    },
    transactions: raw.transactions || [],
  };
}

export async function listTransactions(limit = 50, offset = 0): Promise<BlockchainTransaction[]> {
  const res = await api.get<BlockchainTransaction[]>(
    `/blockchain/transactions?limit=${limit}&offset=${offset}`
  );
  return Array.isArray(res.data) ? res.data : [];
}

export async function getTransaction(txId: string): Promise<BlockchainTransaction> {
  const res = await api.get<BlockchainTransaction>(`/blockchain/transactions/${txId}`);
  return res.data;
}

export const blockchainService = {
  getBlockchainStatus,
  verifyBlockchain,
  listBlocks,
  getBlock,
  listTransactions,
  getTransaction,
};
