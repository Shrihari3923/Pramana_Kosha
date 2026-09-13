-- =============================================================================
-- 001_extensions.sql
-- PostgreSQL Extensions required by the Police DMS
-- =============================================================================

-- UUID generation
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Additional UUID functions (gen_random_uuid etc.)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Trigram indexing for full-text search on names/descriptions
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Optional: PostGIS for geographic boundaries. 
-- Uncomment ONLY if PostGIS is installed on your PostgreSQL server.
-- The rest of the schema uses geometry TEXT columns as a safe fallback.
-- CREATE EXTENSION IF NOT EXISTS "postgis";

-- btree_gist — needed for EXCLUDE constraints on ranges (e.g. non-overlapping postings)
CREATE EXTENSION IF NOT EXISTS "btree_gist";

-- =============================================================================
-- SCHEMAS
-- Organise the database into logical namespaces.
-- Each schema maps to one domain area.
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS reference;       -- lookup / enumeration tables
CREATE SCHEMA IF NOT EXISTS organisation;    -- org units, police stations, jurisdictions
CREATE SCHEMA IF NOT EXISTS identity;        -- officers, persons, postings
CREATE SCHEMA IF NOT EXISTS authz;   -- roles, permissions, policies
CREATE SCHEMA IF NOT EXISTS case_mgmt;       -- cases, FIRs, case events, transfers
CREATE SCHEMA IF NOT EXISTS investigation;   -- investigation tasks, case diary
CREATE SCHEMA IF NOT EXISTS evidence;        -- evidence, relationships, digital evidence
CREATE SCHEMA IF NOT EXISTS custody;         -- chain of custody events
CREATE SCHEMA IF NOT EXISTS forensic;        -- FSL, forensic requests, reports
CREATE SCHEMA IF NOT EXISTS documents;       -- documents, versions, signatures
CREATE SCHEMA IF NOT EXISTS integrity;       -- verification records, integrity alerts
CREATE SCHEMA IF NOT EXISTS audit;           -- audit events, audit chain
CREATE SCHEMA IF NOT EXISTS workflow;        -- workflow states, notifications
CREATE SCHEMA IF NOT EXISTS integration;     -- CCTNS, ICJS, eSakshya, court references

COMMENT ON SCHEMA reference    IS 'Lookup and reference tables (ranks, roles, types, statuses)';
COMMENT ON SCHEMA organisation IS 'Organisational units, police stations, jurisdictions';
COMMENT ON SCHEMA identity     IS 'Officer identity, person registry, postings';
COMMENT ON SCHEMA authz IS 'Roles, permissions, case access policies';
COMMENT ON SCHEMA case_mgmt    IS 'Cases, FIRs, case events, transfers';
COMMENT ON SCHEMA investigation IS 'Investigation tasks, case diary, timelines';
COMMENT ON SCHEMA evidence     IS 'Evidence items, relationships, digital evidence';
COMMENT ON SCHEMA custody      IS 'Chain of custody events and transfers';
COMMENT ON SCHEMA forensic     IS 'FSL labs, forensic requests and reports';
COMMENT ON SCHEMA documents    IS 'Documents, versions, digital signatures';
COMMENT ON SCHEMA integrity    IS 'Hash verification, integrity alerts';
COMMENT ON SCHEMA audit        IS 'Tamper-evident audit trail with hash chain';
COMMENT ON SCHEMA workflow     IS 'Workflow states, task tracking, notifications';
COMMENT ON SCHEMA integration  IS 'External system references (CCTNS, ICJS, eSakshya, Court)';
