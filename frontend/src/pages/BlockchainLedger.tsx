import React, { useState, useEffect, useCallback } from 'react';
import { AppShell } from '../components/layout/AppShell';
import { blockchainService } from '../services/blockchain';
import { BackendUnavailable } from '../components/common/BackendUnavailable';
import { ApiError } from '../services/api';
import {
  BlockchainStatus,
  BlockchainBlock,
  BlockchainTransaction,
  BlockchainVerifyResult,
} from '../types';
import { BlockDetailModal } from '../components/blockchain/BlockDetailModal';
import { TransactionDetailModal } from '../components/blockchain/TransactionDetailModal';

function truncateHash(h: string, chars = 12): string {
  if (!h || h.length <= chars * 2) return h;
  return `${h.slice(0, chars)}…${h.slice(-6)}`;
}

function timeAgo(ts: string): string {
  const diff = Date.now() - new Date(ts).getTime();
  const s = Math.floor(diff / 1000);

  if (s < 60) return `${s}s ago`;
  if (s < 3600) return `${Math.floor(s / 60)}m ago`;
  if (s < 86400) return `${Math.floor(s / 3600)}h ago`;

  return `${Math.floor(s / 86400)}d ago`;
}

const ACTION_STYLES: Record<string, string> = {
  DOCUMENT_UPLOAD:
    'bg-blue-50 text-blue-700 border-blue-200',
  DOCUMENT_DOWNLOAD:
    'bg-sky-50 text-sky-700 border-sky-200',
  SIGN_DOCUMENT:
    'bg-violet-50 text-violet-700 border-violet-200',
  CASE_CREATE:
    'bg-emerald-50 text-emerald-700 border-emerald-200',
  CASE_ASSIGN_USER:
    'bg-teal-50 text-teal-700 border-teal-200',
  USER_LOGIN:
    'bg-slate-100 text-slate-700 border-slate-200',
  USER_LOGOUT:
    'bg-slate-100 text-slate-600 border-slate-200',
  USER_REGISTER:
    'bg-green-50 text-green-700 border-green-200',
  EVIDENCE_REGISTER:
    'bg-amber-50 text-amber-700 border-amber-200',
  EVIDENCE_TRANSFER:
    'bg-orange-50 text-orange-700 border-orange-200',
  KEY_GENERATE:
    'bg-indigo-50 text-indigo-700 border-indigo-200',
};

function actionBadge(action: string) {
  const cls =
    ACTION_STYLES[action] ||
    'bg-slate-50 text-slate-700 border-slate-200';

  return (
    <span
      className={`inline-flex px-2 py-1 rounded-md text-[10px] font-mono font-bold border ${cls}`}
    >
      {action}
    </span>
  );
}

export const BlockchainLedger: React.FC = () => {
  const [status, setStatus] =
    useState<BlockchainStatus | null>(null);

  const [blocks, setBlocks] =
    useState<BlockchainBlock[]>([]);

  const [transactions, setTransactions] =
    useState<BlockchainTransaction[]>([]);

  const [verifyResult, setVerifyResult] =
    useState<BlockchainVerifyResult | null>(null);

  const [loading, setLoading] = useState(true);
  const [verifying, setVerifying] = useState(false);

  const [backendError, setBackendError] = useState<{
    status: number;
    endpoint: string;
    message: string;
  } | null>(null);

  const [selectedBlock, setSelectedBlock] =
    useState<BlockchainBlock | null>(null);

  const [selectedTx, setSelectedTx] =
    useState<BlockchainTransaction | null>(null);

  const [activeTab, setActiveTab] =
    useState<'blocks' | 'transactions'>('blocks');

  const load = useCallback(async () => {
    try {
      setLoading(true);
      setBackendError(null);

      const [s, b, t] = await Promise.all([
        blockchainService.getBlockchainStatus(),
        blockchainService.listBlocks(50, 0),
        blockchainService.listTransactions(50, 0),
      ]);

      setStatus(s);
      setBlocks(b);
      setTransactions(t);
    } catch (err) {
      if (err instanceof ApiError) {
        setBackendError({
          status: err.status,
          endpoint: err.endpoint,
          message: err.message,
        });
      } else {
        setBackendError({
          status: 0,
          endpoint: '/blockchain/status',
          message: (err as Error).message,
        });
      }
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const runVerification = async () => {
    setVerifying(true);

    try {
      const r = await blockchainService.verifyBlockchain();
      setVerifyResult(r);
    } catch (err) {
      console.error('Verification failed', err);
    } finally {
      setVerifying(false);
    }
  };

  const chainOk = verifyResult
    ? verifyResult.valid
    : (status?.chain_valid ?? true);

  if (loading) {
    return (
      <AppShell>
        <div className="bg-white border border-slate-200 rounded-2xl shadow-sm p-16 text-center">
          <div className="w-10 h-10 border-2 border-[#0B1F3A] border-t-transparent rounded-full animate-spin mx-auto mb-4" />

          <h3 className="text-sm font-bold text-slate-800">
            Loading evidence ledger
          </h3>

          <p className="text-xs text-slate-500 mt-1">
            Retrieving cryptographic blocks and transactions from
            the ChainDock backend...
          </p>
        </div>
      </AppShell>
    );
  }

  if (backendError) {
    return (
      <AppShell>
        <BackendUnavailable
          moduleName="Evidence Ledger"
          endpoint={backendError.endpoint}
          status={backendError.status}
          errorMessage={backendError.message}
          onRetry={load}
        />
      </AppShell>
    );
  }

  return (
    <AppShell>
      <div className="space-y-6 max-w-[1520px] mx-auto animate-fade-in">

        {/* =====================================================
            HEADER
        ===================================================== */}
        <section className="bg-white border border-slate-200 rounded-2xl shadow-sm overflow-hidden">

          <div className="bg-[#0B1F3A] px-5 sm:px-7 py-5 text-white">
            <div className="flex flex-col xl:flex-row xl:items-center justify-between gap-5">

              <div>
                <div className="flex flex-wrap items-center gap-2 mb-2">

                  <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md bg-white/10 border border-white/15 text-[10px] font-bold tracking-wider uppercase">
                    <span className="material-symbols-outlined text-[14px]">
                      account_balance
                    </span>
                    Digital Evidence Ledger
                  </span>

                  <span
                    className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md text-[10px] font-bold tracking-wider uppercase ${
                      chainOk
                        ? 'bg-emerald-400/10 text-emerald-200 border border-emerald-300/20'
                        : 'bg-red-400/10 text-red-200 border border-red-300/20'
                    }`}
                  >
                    <span className="material-symbols-outlined text-[14px]">
                      {chainOk ? 'verified' : 'warning'}
                    </span>

                    {chainOk
                      ? 'Chain Verified'
                      : 'Integrity Alert'}
                  </span>
                </div>

                <h1 className="text-2xl sm:text-3xl font-bold tracking-tight">
                  Evidence Ledger
                </h1>

                <p className="text-sm text-slate-300 mt-1.5 max-w-3xl">
                  Immutable ChainDock record of evidence, documents,
                  case activity, authentication events, and other
                  protected system operations.
                </p>
              </div>

              <div className="flex items-center gap-2 shrink-0">

                <button
                  onClick={load}
                  disabled={loading}
                  className="h-10 px-3.5 bg-white/10 hover:bg-white/15 border border-white/15 rounded-lg text-sm font-medium flex items-center gap-2 transition-colors disabled:opacity-50"
                >
                  <span
                    className={`material-symbols-outlined text-[18px] ${
                      loading ? 'animate-spin' : ''
                    }`}
                  >
                    refresh
                  </span>
                  Refresh
                </button>

                <button
                  onClick={runVerification}
                  disabled={verifying}
                  className="h-10 px-4 bg-white text-[#0B1F3A] hover:bg-slate-100 rounded-lg text-sm font-bold flex items-center gap-2 transition-colors shadow-sm disabled:opacity-60"
                >
                  <span
                    className={`material-symbols-outlined text-[18px] ${
                      verifying ? 'animate-spin' : ''
                    }`}
                  >
                    {verifying
                      ? 'hourglass_top'
                      : 'verified_user'}
                  </span>

                  {verifying
                    ? 'Verifying...'
                    : 'Verify Full Chain'}
                </button>
              </div>
            </div>
          </div>

          {/* Security strip */}
          <div className="px-5 sm:px-7 py-3 bg-slate-50 border-t border-slate-200 flex flex-wrap items-center gap-x-6 gap-y-2 text-xs">

            <div className="flex items-center gap-2 text-slate-600">
              <span className="material-symbols-outlined text-[17px] text-emerald-600">
                lock
              </span>
              SHA-256 protected
            </div>

            <div className="flex items-center gap-2 text-slate-600">
              <span className="material-symbols-outlined text-[17px] text-blue-600">
                account_tree
              </span>
              Linked block history
            </div>

            <div className="flex items-center gap-2 text-slate-600">
              <span className="material-symbols-outlined text-[17px] text-violet-600">
                hub
              </span>
              Merkle verification
            </div>

            <div className="flex items-center gap-2 text-slate-600">
              <span className="material-symbols-outlined text-[17px] text-amber-600">
                policy
              </span>
              Forensic audit trail
            </div>
          </div>
        </section>

        {/* =====================================================
            VERIFICATION RESULT
        ===================================================== */}
        {verifyResult && (
          <div
            className={`rounded-2xl border p-4 sm:p-5 ${
              verifyResult.valid
                ? 'bg-emerald-50 border-emerald-200'
                : 'bg-red-50 border-red-300'
            }`}
          >
            <div className="flex items-start gap-3">

              <div
                className={`w-10 h-10 rounded-xl flex items-center justify-center shrink-0 ${
                  verifyResult.valid
                    ? 'bg-emerald-100 text-emerald-700'
                    : 'bg-red-100 text-red-700'
                }`}
              >
                <span className="material-symbols-outlined text-[22px]">
                  {verifyResult.valid
                    ? 'verified_user'
                    : 'gpp_bad'}
                </span>
              </div>

              <div className="min-w-0">

                <h3
                  className={`text-sm font-bold ${
                    verifyResult.valid
                      ? 'text-emerald-900'
                      : 'text-red-900'
                  }`}
                >
                  {verifyResult.valid
                    ? 'Chain Verification Passed'
                    : 'Chain Integrity Compromised'}
                </h3>

                <p className="text-xs text-slate-600 mt-1">
                  {verifyResult.valid
                    ? 'All verified blocks and transactions passed the cryptographic integrity check.'
                    : 'The verification process detected an integrity problem in the ledger.'}
                </p>

                {!verifyResult.valid && (
                  <div className="mt-2 text-xs font-mono text-red-800">
                    {verifyResult.tamper_reason}
                    {' '}
                    (block index{' '}
                    {verifyResult.tampered_block_index})
                  </div>
                )}

                <div className="flex flex-wrap gap-x-5 gap-y-1 mt-3 text-[11px] text-slate-500">
                  <span>
                    Blocks:{' '}
                    <strong className="text-slate-700">
                      {verifyResult.total_blocks}
                    </strong>
                  </span>

                  <span>
                    Transactions:{' '}
                    <strong className="text-slate-700">
                      {verifyResult.total_transactions}
                    </strong>
                  </span>

                  <span>
                    Verified:{' '}
                    <strong className="text-slate-700">
                      {new Date(
                        verifyResult.verified_at
                      ).toLocaleString()}
                    </strong>
                  </span>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* =====================================================
            STATUS CARDS
        ===================================================== */}
        <section>
          <div className="flex items-center gap-2 mb-3">
            <span className="w-1 h-5 rounded-full bg-[#0B1F3A]" />

            <div>
              <h2 className="text-sm font-bold text-slate-800">
                Ledger Status
              </h2>

              <p className="text-[11px] text-slate-500">
                Live blockchain state reported by the backend
              </p>
            </div>
          </div>

          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">

            <div className="bg-white border border-slate-200 rounded-xl p-4 shadow-sm">
              <div className="flex items-center gap-2">
                <span className="material-symbols-outlined text-[20px] text-blue-700">
                  view_agenda
                </span>

                <span className="text-xs text-slate-500 font-medium">
                  Total Blocks
                </span>
              </div>

              <div className="text-2xl font-bold font-mono text-slate-900 mt-2">
                {status?.total_blocks ?? 0}
              </div>
            </div>

            <div className="bg-white border border-slate-200 rounded-xl p-4 shadow-sm">
              <div className="flex items-center gap-2">
                <span className="material-symbols-outlined text-[20px] text-violet-700">
                  receipt_long
                </span>

                <span className="text-xs text-slate-500 font-medium">
                  Transactions
                </span>
              </div>

              <div className="text-2xl font-bold font-mono text-slate-900 mt-2">
                {status?.total_transactions ?? 0}
              </div>
            </div>

            <div className="bg-white border border-slate-200 rounded-xl p-4 shadow-sm">
              <div className="flex items-center gap-2">
                <span className="material-symbols-outlined text-[20px] text-teal-700">
                  tag
                </span>

                <span className="text-xs text-slate-500 font-medium">
                  Latest Block
                </span>
              </div>

              <div className="text-2xl font-bold font-mono text-slate-900 mt-2">
                {status?.latest_block_index ?? '—'}
              </div>
            </div>

            <div className="bg-white border border-slate-200 rounded-xl p-4 shadow-sm">
              <div className="flex items-center gap-2">
                <span
                  className={`material-symbols-outlined text-[20px] ${
                    chainOk
                      ? 'text-emerald-600'
                      : 'text-red-600'
                  }`}
                >
                  {chainOk ? 'lock' : 'lock_open'}
                </span>

                <span className="text-xs text-slate-500 font-medium">
                  Integrity
                </span>
              </div>

              <div
                className={`text-lg font-bold mt-2 ${
                  chainOk
                    ? 'text-emerald-700'
                    : 'text-red-700'
                }`}
              >
                {chainOk ? 'VERIFIED' : 'COMPROMISED'}
              </div>
            </div>

          </div>
        </section>

        {/* =====================================================
            LATEST BLOCK
        ===================================================== */}
        {status?.latest_block_hash && (
          <section className="bg-white border border-slate-200 rounded-2xl shadow-sm overflow-hidden">

            <div className="px-5 py-4 border-b border-slate-200 bg-slate-50">
              <div className="flex items-center gap-2">
                <span className="material-symbols-outlined text-[19px] text-[#0B1F3A]">
                  deployed_code
                </span>

                <div>
                  <h2 className="text-sm font-bold text-slate-800">
                    Latest Ledger Block
                  </h2>

                  <p className="text-[11px] text-slate-500">
                    Most recent block recorded by ChainDock
                  </p>
                </div>
              </div>
            </div>

            <div className="p-5 grid grid-cols-1 md:grid-cols-2 gap-5">

              <div>
                <span className="text-[10px] font-bold uppercase tracking-wider text-slate-400">
                  Block Hash
                </span>

                <div className="mt-1.5 p-3 bg-slate-50 border border-slate-200 rounded-lg font-mono text-xs text-slate-700 break-all">
                  {status.latest_block_hash}
                </div>
              </div>

              <div>
                <span className="text-[10px] font-bold uppercase tracking-wider text-slate-400">
                  Merkle Root
                </span>

                <div className="mt-1.5 p-3 bg-slate-50 border border-slate-200 rounded-lg font-mono text-xs text-slate-700 break-all">
                  {status.latest_merkle_root}
                </div>
              </div>

              {status.latest_block_timestamp && (
                <div>
                  <span className="text-[10px] font-bold uppercase tracking-wider text-slate-400">
                    Timestamp
                  </span>

                  <div className="mt-1.5 text-sm text-slate-700">
                    {new Date(
                      status.latest_block_timestamp
                    ).toLocaleString()}
                  </div>
                </div>
              )}

            </div>
          </section>
        )}

        {/* =====================================================
            BLOCKS / TRANSACTIONS
        ===================================================== */}
        <section className="bg-white border border-slate-200 rounded-2xl shadow-sm overflow-hidden">

          <div className="px-5 pt-4 border-b border-slate-200 bg-white">

            <div className="flex items-center gap-2 mb-4">
              <span className="material-symbols-outlined text-[19px] text-[#0B1F3A]">
                history
              </span>

              <div>
                <h2 className="text-sm font-bold text-slate-800">
                  Immutable Activity Record
                </h2>

                <p className="text-[11px] text-slate-500">
                  Cryptographically linked ChainDock records
                </p>
              </div>
            </div>

            <div className="flex">

              <button
                onClick={() => setActiveTab('blocks')}
                className={`px-5 py-3 text-xs font-bold transition-colors border-b-2 ${
                  activeTab === 'blocks'
                    ? 'text-[#0B1F3A] border-[#0B1F3A]'
                    : 'text-slate-500 border-transparent hover:text-slate-800'
                }`}
              >
                Blocks ({blocks.length})
              </button>

              <button
                onClick={() => setActiveTab('transactions')}
                className={`px-5 py-3 text-xs font-bold transition-colors border-b-2 ${
                  activeTab === 'transactions'
                    ? 'text-[#0B1F3A] border-[#0B1F3A]'
                    : 'text-slate-500 border-transparent hover:text-slate-800'
                }`}
              >
                Transactions ({transactions.length})
              </button>

            </div>
          </div>

          {/* =================================================
              BLOCK TABLE
          ================================================= */}
          {activeTab === 'blocks' && (
            <div className="overflow-x-auto">

              <table className="w-full text-xs">

                <thead className="bg-slate-50 border-b border-slate-200">
                  <tr>
                    {[
                      'Block',
                      'Block Hash',
                      'Merkle Root',
                      'Previous Hash',
                      'Transactions',
                      'Recorded',
                      '',
                    ].map((heading) => (
                      <th
                        key={heading}
                        className="px-4 py-3 text-left text-[10px] font-bold uppercase tracking-wider text-slate-500 whitespace-nowrap"
                      >
                        {heading}
                      </th>
                    ))}
                  </tr>
                </thead>

                <tbody>
                  {blocks.map((b, i) => (
                    <tr
                      key={b.id}
                      className={`border-b border-slate-100 hover:bg-slate-50 transition-colors ${
                        i === 0
                          ? 'bg-emerald-50/40'
                          : ''
                      }`}
                    >
                      <td className="px-4 py-3 font-mono font-bold text-[#0B1F3A]">
                        #{b.block_index}
                      </td>

                      <td className="px-4 py-3 font-mono text-slate-600 whitespace-nowrap">
                        {truncateHash(b.block_hash)}
                      </td>

                      <td className="px-4 py-3 font-mono text-slate-600 whitespace-nowrap">
                        {truncateHash(b.merkle_root)}
                      </td>

                      <td className="px-4 py-3 font-mono text-slate-500 whitespace-nowrap">
                        {truncateHash(b.prev_block_hash)}
                      </td>

                      <td className="px-4 py-3 text-center font-semibold text-slate-700">
                        {b.transaction_count}
                      </td>

                      <td className="px-4 py-3 text-slate-500 whitespace-nowrap">
                        {timeAgo(b.timestamp)}
                      </td>

                      <td className="px-4 py-3">
                        <button
                          onClick={() =>
                            setSelectedBlock(b)
                          }
                          className="px-2.5 py-1.5 rounded-md border border-slate-200 bg-white hover:bg-slate-100 text-[#0B1F3A] text-[10px] font-bold transition-colors"
                        >
                          Inspect
                        </button>
                      </td>
                    </tr>
                  ))}

                  {blocks.length === 0 && (
                    <tr>
                      <td
                        colSpan={7}
                        className="px-4 py-12 text-center"
                      >
                        <span className="material-symbols-outlined text-3xl text-slate-300">
                          inventory_2
                        </span>

                        <p className="text-sm font-semibold text-slate-600 mt-2">
                          No ledger blocks available
                        </p>

                        <p className="text-xs text-slate-400 mt-1">
                          Protected system actions will create
                          ledger records.
                        </p>
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          )}

          {/* =================================================
              TRANSACTION TABLE
          ================================================= */}
          {activeTab === 'transactions' && (
            <div className="overflow-x-auto">

              <table className="w-full text-xs">

                <thead className="bg-slate-50 border-b border-slate-200">
                  <tr>
                    {[
                      'Block',
                      'Action',
                      'Actor',
                      'Transaction Hash',
                      'Payload Hash',
                      'Recorded',
                      '',
                    ].map((heading) => (
                      <th
                        key={heading}
                        className="px-4 py-3 text-left text-[10px] font-bold uppercase tracking-wider text-slate-500 whitespace-nowrap"
                      >
                        {heading}
                      </th>
                    ))}
                  </tr>
                </thead>

                <tbody>
                  {transactions.map((t) => (
                    <tr
                      key={t.id}
                      className="border-b border-slate-100 hover:bg-slate-50 transition-colors"
                    >
                      <td className="px-4 py-3 font-mono font-bold text-[#0B1F3A]">
                        #{t.block_index}
                      </td>

                      <td className="px-4 py-3">
                        {actionBadge(t.action)}
                      </td>

                      <td className="px-4 py-3 text-slate-700 whitespace-nowrap">
                        {t.actor_email}
                      </td>

                      <td className="px-4 py-3 font-mono text-slate-600 whitespace-nowrap">
                        {truncateHash(t.tx_hash)}
                      </td>

                      <td className="px-4 py-3 font-mono text-slate-500 whitespace-nowrap">
                        {truncateHash(t.payload_hash)}
                      </td>

                      <td className="px-4 py-3 text-slate-500 whitespace-nowrap">
                        {timeAgo(t.timestamp)}
                      </td>

                      <td className="px-4 py-3">
                        <button
                          onClick={() =>
                            setSelectedTx(t)
                          }
                          className="px-2.5 py-1.5 rounded-md border border-slate-200 bg-white hover:bg-slate-100 text-[#0B1F3A] text-[10px] font-bold transition-colors"
                        >
                          Inspect
                        </button>
                      </td>
                    </tr>
                  ))}

                  {transactions.length === 0 && (
                    <tr>
                      <td
                        colSpan={7}
                        className="px-4 py-12 text-center"
                      >
                        <span className="material-symbols-outlined text-3xl text-slate-300">
                          receipt_long
                        </span>

                        <p className="text-sm font-semibold text-slate-600 mt-2">
                          No transactions available
                        </p>

                        <p className="text-xs text-slate-400 mt-1">
                          System operations will appear here once
                          recorded.
                        </p>
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          )}
        </section>

        {/* =====================================================
            FORENSIC NOTICE
        ===================================================== */}
        <section className="bg-[#0B1F3A] rounded-xl p-4 sm:p-5 text-white">

          <div className="flex items-start gap-3">

            <span className="material-symbols-outlined text-emerald-300 text-[21px]">
              verified
            </span>

            <div>
              <h3 className="text-sm font-bold">
                ChainDock Evidence Integrity
              </h3>

              <p className="text-xs text-slate-300 mt-1 leading-relaxed">
                Ledger entries provide a cryptographically linked
                record of protected platform activity. Block hashes,
                previous-block references, transaction hashes, and
                Merkle roots can be verified through the backend
                integrity service.
              </p>
            </div>

          </div>
        </section>

      </div>

      {/* =======================================================
          MODALS
      ======================================================= */}
      {selectedBlock && (
        <BlockDetailModal
          block={selectedBlock}
          onClose={() => setSelectedBlock(null)}
        />
      )}

      {selectedTx && (
        <TransactionDetailModal
          tx={selectedTx}
          onClose={() => setSelectedTx(null)}
        />
      )}
    </AppShell>
  );
};
