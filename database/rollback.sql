-- =============================================================================
-- rollback.sql
-- Development rollback script — drops all Police DMS schemas and extensions
-- =============================================================================
-- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
-- WARNING: THIS SCRIPT PERMANENTLY DESTROYS ALL DATA IN THE DATABASE.
-- NEVER RUN AGAINST A PRODUCTION DATABASE.
-- NEVER RUN WITHOUT A VERIFIED BACKUP.
-- THIS IS FOR DEVELOPMENT RESET AND CI/CD TEARDOWN ONLY.
-- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

-- Uncomment the line below as a deliberate confirmation step before running:
-- SET police_dms.confirm_rollback = 'I_UNDERSTAND_THIS_DESTROYS_ALL_DATA';

DO $$
BEGIN
    -- Commented out by default — uncomment to actually run
    -- IF current_setting('police_dms.confirm_rollback', true)
    --       IS DISTINCT FROM 'I_UNDERSTAND_THIS_DESTROYS_ALL_DATA' THEN
    --     RAISE EXCEPTION 'Rollback not confirmed. Set police_dms.confirm_rollback first.';
    -- END IF;
    RAISE NOTICE 'Starting Police DMS rollback...';
END $$;

-- Drop schemas in reverse dependency order (CASCADE handles object dependencies)
DROP SCHEMA IF EXISTS integration  CASCADE;
DROP SCHEMA IF EXISTS workflow     CASCADE;
DROP SCHEMA IF EXISTS audit        CASCADE;
DROP SCHEMA IF EXISTS integrity    CASCADE;
DROP SCHEMA IF EXISTS documents    CASCADE;
DROP SCHEMA IF EXISTS forensic     CASCADE;
DROP SCHEMA IF EXISTS custody      CASCADE;
DROP SCHEMA IF EXISTS evidence     CASCADE;
DROP SCHEMA IF EXISTS investigation CASCADE;
DROP SCHEMA IF EXISTS case_mgmt    CASCADE;
DROP SCHEMA IF EXISTS authorization CASCADE;
DROP SCHEMA IF EXISTS identity     CASCADE;
DROP SCHEMA IF EXISTS organisation CASCADE;
DROP SCHEMA IF EXISTS reference    CASCADE;

-- Drop utility functions in public schema
DROP FUNCTION IF EXISTS public.set_updated_at() CASCADE;
DROP FUNCTION IF EXISTS public.check_version_no() CASCADE;

-- Drop extensions (only if no other databases on this server need them)
-- Comment these out if sharing extensions with other projects
DROP EXTENSION IF EXISTS btree_gist;
DROP EXTENSION IF EXISTS pg_trgm;
DROP EXTENSION IF EXISTS "uuid-ossp";
DROP EXTENSION IF EXISTS pgcrypto;

DO $$ BEGIN RAISE NOTICE 'Police DMS rollback complete. All schemas dropped.'; END $$;
