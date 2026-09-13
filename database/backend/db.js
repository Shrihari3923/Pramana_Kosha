// =============================================================================
// db.js — PostgreSQL connection pool for Police DMS backend
// Compatible with: Node.js + Express / NestJS / Fastify
// Driver: pg (node-postgres)  npm install pg
// =============================================================================

'use strict';

const { Pool } = require('pg');

// ---------------------------------------------------------------------------
// Connection pool — reads from environment variables
// ---------------------------------------------------------------------------
const pool = new Pool({
  host:     process.env.DB_HOST     || 'localhost',
  port:     parseInt(process.env.DB_PORT || '5432', 10),
  database: process.env.DB_NAME     || 'police_dms',
  user:     process.env.DB_USER     || 'postgres',
  password: process.env.DB_PASSWORD,
  max:      parseInt(process.env.DB_POOL_MAX || '20', 10),   // max connections
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
  ssl: process.env.DB_SSL === 'true'
    ? { rejectUnauthorized: process.env.DB_SSL_REJECT_UNAUTHORIZED !== 'false' }
    : false,
});

pool.on('error', (err) => {
  console.error('[DB] Unexpected client error:', err.message);
});

// ---------------------------------------------------------------------------
// query(sql, params) — single query helper
// ---------------------------------------------------------------------------
async function query(sql, params = []) {
  const start = Date.now();
  try {
    const result = await pool.query(sql, params);
    const duration = Date.now() - start;
    if (process.env.DB_LOG_QUERIES === 'true') {
      console.debug(`[DB] query ${duration}ms | rows: ${result.rowCount}`);
    }
    return result;
  } catch (err) {
    console.error('[DB] Query error:', err.message, '| SQL:', sql.slice(0, 120));
    throw err;
  }
}

// ---------------------------------------------------------------------------
// transaction(fn) — wraps multiple queries in a transaction
// Usage:
//   const result = await transaction(async (client) => {
//     await client.query('INSERT ...');
//     const r = await client.query('SELECT ...');
//     return r.rows;
//   });
// ---------------------------------------------------------------------------
async function transaction(fn) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

// ---------------------------------------------------------------------------
// setOfficerContext(client, officerId, stationId)
// Sets session variables used by RLS policies and audit functions
// ---------------------------------------------------------------------------
async function setOfficerContext(client, officerId, stationId) {
  await client.query(
    `SELECT set_config('app.current_officer_id', $1, true),
            set_config('app.current_station_id', $2, true)`,
    [officerId, stationId ?? '']
  );
}

module.exports = { pool, query, transaction, setOfficerContext };
