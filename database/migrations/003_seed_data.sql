-- =============================================================================
-- 003_seed_data.sql
-- Realistic demo/seed data for SIH demonstration
-- ALL DATA IS FICTIONAL — no real officer personal information used
-- =============================================================================
-- Scenario covered:
--   SI Arjun Rao (PRIMARY_IO) at Central Police Station, Bengaluru
--   Registers Zero FIR → transferred → Case CASE-KA-BLR-CEN-2026-00000001
--   Seizes Mobile Phone (E001)
--   Malkhana → FSL → Forensic Image (E002) → Chat DB (E003) → Screenshot (E004)
--   Forensic Report (E005) created
--   FIR PDF v1 → v2 → FINAL + signed
--   Full audit trail
-- =============================================================================

BEGIN;

-- =============================================================================
-- SECTION A: ORGANISATION UNITS
-- =============================================================================

-- Karnataka State
INSERT INTO organisation.organisation_unit
    (unit_id, unit_code, unit_name, unit_type_code, state_code, country_code)
VALUES
    ('10000000-0000-0000-0000-000000000001', 'IN-KA', 'Karnataka State', 'STATE', 'KA', 'IN'),
    ('10000000-0000-0000-0000-000000000002', 'IN-KA-SPHQ', 'Karnataka State Police Headquarters', 'STATE_POLICE_HQ', 'KA', 'IN'),
    ('10000000-0000-0000-0000-000000000003', 'IN-KA-BLR-COMM', 'Bengaluru City Commissionerate', 'COMMISSIONERATE', 'KA', 'IN'),
    ('10000000-0000-0000-0000-000000000004', 'IN-KA-BLR-CENT-DIV', 'Bengaluru Central Division', 'DIVISION', 'KA', 'IN'),
    ('10000000-0000-0000-0000-000000000005', 'IN-KA-BLR-CENT-SUB', 'Bengaluru Central Sub-Division', 'SUBDIVISION', 'KA', 'IN'),
    ('10000000-0000-0000-0000-000000000006', 'IN-KA-BLR-CEN-PS', 'Central Police Station Bengaluru', 'POLICE_STATION', 'KA', 'IN'),
    ('10000000-0000-0000-0000-000000000007', 'IN-KA-BLR-CYBER-PS', 'Cyber Crime Police Station Bengaluru', 'CYBER_CELL', 'KA', 'IN'),
    ('10000000-0000-0000-0000-000000000008', 'IN-KA-BLR-WOMEN-PS', 'Women Police Station Bengaluru', 'POLICE_STATION', 'KA', 'IN');

-- Maharashtra State
INSERT INTO organisation.organisation_unit
    (unit_id, unit_code, unit_name, unit_type_code, state_code, country_code)
VALUES
    ('10000000-0000-0000-0000-000000000010', 'IN-MH', 'Maharashtra State', 'STATE', 'MH', 'IN'),
    ('10000000-0000-0000-0000-000000000011', 'IN-MH-MUM-COMM', 'Mumbai City Commissionerate', 'COMMISSIONERATE', 'MH', 'IN'),
    ('10000000-0000-0000-0000-000000000012', 'IN-MH-MUM-CSTN-PS', 'Colaba Police Station Mumbai', 'POLICE_STATION', 'MH', 'IN');

-- Delhi
INSERT INTO organisation.organisation_unit
    (unit_id, unit_code, unit_name, unit_type_code, state_code, country_code)
VALUES
    ('10000000-0000-0000-0000-000000000020', 'IN-DL', 'Delhi (NCT)', 'STATE', 'DL', 'IN'),
    ('10000000-0000-0000-0000-000000000021', 'IN-DL-CP', 'Delhi Police Commissionerate', 'COMMISSIONERATE', 'DL', 'IN'),
    ('10000000-0000-0000-0000-000000000022', 'IN-DL-CNT-PS', 'Connaught Place Police Station', 'POLICE_STATION', 'DL', 'IN');

-- Set parent_unit_id
UPDATE organisation.organisation_unit SET parent_unit_id = '10000000-0000-0000-0000-000000000001' WHERE unit_code = 'IN-KA-SPHQ';
UPDATE organisation.organisation_unit SET parent_unit_id = '10000000-0000-0000-0000-000000000002' WHERE unit_code = 'IN-KA-BLR-COMM';
UPDATE organisation.organisation_unit SET parent_unit_id = '10000000-0000-0000-0000-000000000003' WHERE unit_code = 'IN-KA-BLR-CENT-DIV';
UPDATE organisation.organisation_unit SET parent_unit_id = '10000000-0000-0000-0000-000000000004' WHERE unit_code = 'IN-KA-BLR-CENT-SUB';
UPDATE organisation.organisation_unit SET parent_unit_id = '10000000-0000-0000-0000-000000000005' WHERE unit_code IN ('IN-KA-BLR-CEN-PS','IN-KA-BLR-CYBER-PS','IN-KA-BLR-WOMEN-PS');

-- =============================================================================
-- SECTION B: POLICE STATIONS
-- =============================================================================

INSERT INTO organisation.police_station
    (station_id, station_code, station_name, station_type_code,
     organisation_unit_id, state_code, district_name,
     address_line1, city, pincode, phone_primary, cctns_station_code)
VALUES
    ('20000000-0000-0000-0000-000000000001',
     'BLR-CEN', 'Central Police Station Bengaluru', 'POLICE_STATION',
     '10000000-0000-0000-0000-000000000006', 'KA', 'Bengaluru Urban',
     'Infantry Road, Shivajinagar', 'Bengaluru', '560001', '080-22942222', 'KA-BLR-CEN-001'),

    ('20000000-0000-0000-0000-000000000002',
     'BLR-CYBER', 'Cyber Crime Police Station Bengaluru', 'CYBER_PS',
     '10000000-0000-0000-0000-000000000007', 'KA', 'Bengaluru Urban',
     'CID Headquarters, Carlton House', 'Bengaluru', '560001', '080-22943151', 'KA-BLR-CYBER-001'),

    ('20000000-0000-0000-0000-000000000003',
     'BLR-WPS', 'Women Police Station Bengaluru', 'WOMEN_PS',
     '10000000-0000-0000-0000-000000000008', 'KA', 'Bengaluru Urban',
     'Halasuru, Ulsoor Road', 'Bengaluru', '560042', '080-25566100', 'KA-BLR-WPS-001'),

    ('20000000-0000-0000-0000-000000000004',
     'MUM-COL', 'Colaba Police Station Mumbai', 'POLICE_STATION',
     '10000000-0000-0000-0000-000000000012', 'MH', 'Mumbai City',
     'Colaba Causeway, Mumbai', 'Mumbai', '400005', '022-22021855', 'MH-MUM-COL-001'),

    ('20000000-0000-0000-0000-000000000005',
     'DL-CNT', 'Connaught Place Police Station Delhi', 'POLICE_STATION',
     '10000000-0000-0000-0000-000000000022', 'DL', 'New Delhi',
     'Connaught Place, New Delhi', 'New Delhi', '110001', '011-23415414', 'DL-CNT-001');

-- Jurisdiction
INSERT INTO organisation.jurisdiction
    (station_id, jurisdiction_name, jurisdiction_type,
     area_sq_km, localities_text)
VALUES
    ('20000000-0000-0000-0000-000000000001',
     'Central PS Jurisdiction', 'TERRITORIAL',
     12.5, 'Shivajinagar, Infantry Road, Brigade Road, MG Road, Cubbon Park area'),
    ('20000000-0000-0000-0000-000000000002',
     'Cyber Crime PS Jurisdiction', 'FUNCTIONAL',
     NULL, 'Entire Bengaluru City — cyber offences');

-- Beat
INSERT INTO organisation.beat (beat_code, beat_name, station_id)
VALUES
    ('BLR-CEN-B01', 'Infantry Road Beat',  '20000000-0000-0000-0000-000000000001'),
    ('BLR-CEN-B02', 'Brigade Road Beat',   '20000000-0000-0000-0000-000000000001'),
    ('BLR-CEN-B03', 'MG Road Beat',        '20000000-0000-0000-0000-000000000001');

-- =============================================================================
-- SECTION C: PERSONS (all fictional)
-- =============================================================================

INSERT INTO identity.person
    (person_id, first_name, last_name, date_of_birth, gender,
     phone_primary, address_current, city, state_code,
     is_police_officer)
VALUES
    -- Officers
    ('30000000-0000-0000-0000-000000000001', 'Rajesh',   'Kumar',      '1975-03-15', 'MALE',   '9900000001', 'Police HQ, Bengaluru',    'Bengaluru', 'KA', TRUE),
    ('30000000-0000-0000-0000-000000000002', 'Arjun',    'Rao',        '1988-07-22', 'MALE',   '9900000002', '12 Infantry Road, Blr',   'Bengaluru', 'KA', TRUE),
    ('30000000-0000-0000-0000-000000000003', 'Kavitha',  'Nair',       '1990-11-05', 'FEMALE', '9900000003', '45 Koramangala, Blr',     'Bengaluru', 'KA', TRUE),
    ('30000000-0000-0000-0000-000000000004', 'Suresh',   'Patil',      '1985-01-18', 'MALE',   '9900000004', '78 Malleswaram, Blr',     'Bengaluru', 'KA', TRUE),
    ('30000000-0000-0000-0000-000000000005', 'Priya',    'Sharma',     '1992-09-30', 'FEMALE', '9900000005', '23 Jayanagar, Blr',       'Bengaluru', 'KA', TRUE),
    ('30000000-0000-0000-0000-000000000006', 'Vikram',   'Singh',      '1982-06-12', 'MALE',   '9900000006', '56 Indiranagar, Blr',     'Bengaluru', 'KA', TRUE),
    ('30000000-0000-0000-0000-000000000007', 'Meena',    'Krishnan',   '1995-04-28', 'FEMALE', '9900000007', '34 BTM Layout, Blr',      'Bengaluru', 'KA', TRUE),
    ('30000000-0000-0000-0000-000000000008', 'Ravi',     'Malhotra',   '1987-12-10', 'MALE',   '9900000008', '67 Whitefield, Blr',      'Bengaluru', 'KA', TRUE),
    -- Civilians
    ('30000000-0000-0000-0000-000000000010', 'Anand',    'Verma',      '1985-05-20', 'MALE',   '9800000001', '101 MG Road, Bengaluru',  'Bengaluru', 'KA', FALSE),  -- complainant
    ('30000000-0000-0000-0000-000000000011', 'Farhan',   'Sheikh',     '1990-08-15', 'MALE',   '9800000002', '202 Shivajinagar, Blr',   'Bengaluru', 'KA', FALSE),  -- accused
    ('30000000-0000-0000-0000-000000000012', 'Sunita',   'Reddy',      '1988-03-25', 'FEMALE', '9800000003', '303 Brigade Road, Blr',   'Bengaluru', 'KA', FALSE),  -- witness
    ('30000000-0000-0000-0000-000000000013', 'Mohan',    'Das',        '1975-11-08', 'MALE',   '9800000004', '404 Cubbon Park, Blr',    'Bengaluru', 'KA', FALSE);   -- victim

-- =============================================================================
-- SECTION D: OFFICERS
-- =============================================================================

-- Password hashes are bcrypt of "Demo@1234!" — NEVER use in production
INSERT INTO identity.officer
    (officer_id, person_id, identity_code, service_number,
     current_rank_code, current_station_id,
     username, password_hash, date_of_joining, cadre, is_active)
VALUES
    ('40000000-0000-0000-0000-000000000001',
     '30000000-0000-0000-0000-000000000001',
     'IN-KA-BLR-CEN-DCP-00001', 'KA-IPS-2000-001',
     'DCP', '20000000-0000-0000-0000-000000000001',
     'rajesh.kumar', '$2b$12$DEMO_HASH_PLACEHOLDER_DCP001',
     '2000-08-01', 'IPS', TRUE),

    ('40000000-0000-0000-0000-000000000002',
     '30000000-0000-0000-0000-000000000002',
     'IN-KA-BLR-CEN-SI-00002', 'KA-SPS-2012-042',
     'SUB_INSPECTOR', '20000000-0000-0000-0000-000000000001',
     'arjun.rao', '$2b$12$DEMO_HASH_PLACEHOLDER_SI002',
     '2012-06-15', 'STATE', TRUE),

    ('40000000-0000-0000-0000-000000000003',
     '30000000-0000-0000-0000-000000000003',
     'IN-KA-BLR-CEN-SI-00003', 'KA-SPS-2015-067',
     'SUB_INSPECTOR', '20000000-0000-0000-0000-000000000001',
     'kavitha.nair', '$2b$12$DEMO_HASH_PLACEHOLDER_SI003',
     '2015-03-20', 'STATE', TRUE),

    ('40000000-0000-0000-0000-000000000004',
     '30000000-0000-0000-0000-000000000004',
     'IN-KA-BLR-CEN-INSP-00004', 'KA-SPS-2008-015',
     'INSPECTOR', '20000000-0000-0000-0000-000000000001',
     'suresh.patil', '$2b$12$DEMO_HASH_PLACEHOLDER_INSP004',
     '2008-09-01', 'STATE', TRUE),

    ('40000000-0000-0000-0000-000000000005',
     '30000000-0000-0000-0000-000000000005',
     'IN-KA-BLR-CEN-ASI-00005', 'KA-SPS-2018-102',
     'ASI', '20000000-0000-0000-0000-000000000001',
     'priya.sharma', '$2b$12$DEMO_HASH_PLACEHOLDER_ASI005',
     '2018-01-15', 'STATE', TRUE),

    ('40000000-0000-0000-0000-000000000006',
     '30000000-0000-0000-0000-000000000006',
     'IN-KA-BLR-CEN-HC-00006', 'KA-SPS-2010-088',
     'HEAD_CONSTABLE', '20000000-0000-0000-0000-000000000001',
     'vikram.singh', '$2b$12$DEMO_HASH_PLACEHOLDER_HC006',
     '2010-04-10', 'STATE', TRUE),

    ('40000000-0000-0000-0000-000000000007',
     '30000000-0000-0000-0000-000000000007',
     'IN-KA-BLR-CYB-SI-00007', 'KA-SPS-2019-121',
     'SUB_INSPECTOR', '20000000-0000-0000-0000-000000000002',
     'meena.krishnan', '$2b$12$DEMO_HASH_PLACEHOLDER_SI007',
     '2019-07-01', 'STATE', TRUE),

    ('40000000-0000-0000-0000-000000000008',
     '30000000-0000-0000-0000-000000000008',
     'IN-KA-BLR-CEN-INSP-00008', 'KA-SPS-2007-011',
     'INSPECTOR', '20000000-0000-0000-0000-000000000001',
     'ravi.malhotra', '$2b$12$DEMO_HASH_PLACEHOLDER_INSP008',
     '2007-05-20', 'STATE', TRUE);

-- =============================================================================
-- SECTION E: OFFICER POSTINGS (current postings + historical for Arjun Rao)
-- =============================================================================

-- Arjun Rao: previously posted at Cyber PS (2020-2023), now at Central PS
INSERT INTO identity.officer_posting
    (posting_id, officer_id, organisation_unit_id, police_station_id,
     rank_id, designation_id,
     posting_start_date, posting_end_date, is_current, posting_type)
SELECT
    '50000000-0000-0000-0000-000000000001',
    '40000000-0000-0000-0000-000000000002',
    '10000000-0000-0000-0000-000000000007',
    '20000000-0000-0000-0000-000000000002',
    r.rank_id,
    d.designation_id,
    '2020-06-01', '2023-05-31', FALSE, 'REGULAR'
FROM reference.rank r, reference.designation d
WHERE r.rank_code = 'SUB_INSPECTOR' AND d.designation_code = 'IO';

-- Arjun Rao: current posting at Central PS
INSERT INTO identity.officer_posting
    (posting_id, officer_id, organisation_unit_id, police_station_id,
     rank_id, designation_id,
     posting_start_date, is_current, posting_type)
SELECT
    '50000000-0000-0000-0000-000000000002',
    '40000000-0000-0000-0000-000000000002',
    '10000000-0000-0000-0000-000000000006',
    '20000000-0000-0000-0000-000000000001',
    r.rank_id,
    d.designation_id,
    '2023-06-01', TRUE, 'REGULAR'
FROM reference.rank r, reference.designation d
WHERE r.rank_code = 'SUB_INSPECTOR' AND d.designation_code = 'IO';

-- Suresh Patil (SHO) — current posting
INSERT INTO identity.officer_posting
    (posting_id, officer_id, organisation_unit_id, police_station_id,
     rank_id, designation_id,
     posting_start_date, is_current, posting_type)
SELECT
    '50000000-0000-0000-0000-000000000004',
    '40000000-0000-0000-0000-000000000004',
    '10000000-0000-0000-0000-000000000006',
    '20000000-0000-0000-0000-000000000001',
    r.rank_id,
    d.designation_id,
    '2022-01-01', TRUE, 'REGULAR'
FROM reference.rank r, reference.designation d
WHERE r.rank_code = 'INSPECTOR' AND d.designation_code = 'SHO';

-- Vikram Singh (Malkhana) — current posting
INSERT INTO identity.officer_posting
    (posting_id, officer_id, organisation_unit_id, police_station_id,
     rank_id, designation_id,
     posting_start_date, is_current, posting_type)
SELECT
    '50000000-0000-0000-0000-000000000006',
    '40000000-0000-0000-0000-000000000006',
    '10000000-0000-0000-0000-000000000006',
    '20000000-0000-0000-0000-000000000001',
    r.rank_id,
    d.designation_id,
    '2021-03-15', TRUE, 'REGULAR'
FROM reference.rank r, reference.designation d
WHERE r.rank_code = 'HEAD_CONSTABLE' AND d.designation_code = 'MALKHANA_INCHARGE';

-- Meena Krishnan (Cyber) — current posting
INSERT INTO identity.officer_posting
    (posting_id, officer_id, organisation_unit_id, police_station_id,
     rank_id, designation_id,
     posting_start_date, is_current, posting_type)
SELECT
    '50000000-0000-0000-0000-000000000007',
    '40000000-0000-0000-0000-000000000007',
    '10000000-0000-0000-0000-000000000007',
    '20000000-0000-0000-0000-000000000002',
    r.rank_id,
    d.designation_id,
    '2021-07-01', TRUE, 'REGULAR'
FROM reference.rank r, reference.designation d
WHERE r.rank_code = 'SUB_INSPECTOR' AND d.designation_code = 'CYBER_LIAISON';

-- =============================================================================
-- SECTION F: SYSTEM ROLE ASSIGNMENTS
-- =============================================================================

INSERT INTO authorization.officer_system_role
    (officer_id, role_id, station_id, granted_by)
SELECT '40000000-0000-0000-0000-000000000001', sr.role_id,
       '20000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000001'
FROM authorization.system_role sr WHERE sr.role_code = 'SYS_ADMIN';

INSERT INTO authorization.officer_system_role
    (officer_id, role_id, station_id, granted_by)
SELECT '40000000-0000-0000-0000-000000000004', sr.role_id,
       '20000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000001'
FROM authorization.system_role sr WHERE sr.role_code = 'SHO_ROLE';

INSERT INTO authorization.officer_system_role
    (officer_id, role_id, station_id, granted_by)
SELECT '40000000-0000-0000-0000-000000000002', sr.role_id,
       '20000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000004'
FROM authorization.system_role sr WHERE sr.role_code = 'IO_ROLE';

INSERT INTO authorization.officer_system_role
    (officer_id, role_id, station_id, granted_by)
SELECT '40000000-0000-0000-0000-000000000006', sr.role_id,
       '20000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000004'
FROM authorization.system_role sr WHERE sr.role_code = 'MALKHANA_ROLE';

INSERT INTO authorization.officer_system_role
    (officer_id, role_id, station_id, granted_by)
SELECT '40000000-0000-0000-0000-000000000007', sr.role_id,
       '20000000-0000-0000-0000-000000000002', '40000000-0000-0000-0000-000000000001'
FROM authorization.system_role sr WHERE sr.role_code = 'CYBER_OFFICER';

-- =============================================================================
-- SECTION G: CASES
-- =============================================================================

-- Case 1: Cyber fraud — primary demo case
INSERT INTO case_mgmt.case
    (case_id, case_number,
     originating_station_id, current_station_id,
     case_type_id, case_status_code, priority,
     confidentiality_code,
     incident_date, opened_at,
     incident_description, incident_location,
     primary_io_id, supervising_officer_id,
     created_by, ipc_sections, bnss_sections)
SELECT
    '60000000-0000-0000-0000-000000000001',
    'CASE-KA-BLR-CEN-2026-00000001',
    '20000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000001',
    ct.case_type_id, 'UNDER_INVESTIGATION', 'HIGH',
    'CONFIDENTIAL',
    '2026-01-15 14:30:00+05:30',
    '2026-01-15 16:00:00+05:30',
    'Complainant reports financial fraud via WhatsApp messages. Accused allegedly impersonated bank official and obtained OTP. Amount defrauded: Rs. 4,50,000.',
    'MG Road, Bengaluru',
    '40000000-0000-0000-0000-000000000002',
    '40000000-0000-0000-0000-000000000004',
    '40000000-0000-0000-0000-000000000002',
    '420, 419, 66C, 66D IT Act',
    '318, 319 BNSS'
FROM reference.case_type ct WHERE ct.type_code = 'CYBERCRIME';

-- Case 2: Robbery
INSERT INTO case_mgmt.case
    (case_id, case_number,
     originating_station_id, current_station_id,
     case_type_id, case_status_code, priority, confidentiality_code,
     incident_date, opened_at,
     incident_description, incident_location,
     primary_io_id, supervising_officer_id, created_by)
SELECT
    '60000000-0000-0000-0000-000000000002',
    'CASE-KA-BLR-CEN-2026-00000002',
    '20000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000001',
    ct.case_type_id, 'FIR_REGISTERED', 'NORMAL', 'INTERNAL',
    '2026-02-10 21:15:00+05:30',
    '2026-02-10 22:00:00+05:30',
    'Chain snatching near Brigade Road. Accused fled on motorcycle.',
    'Brigade Road, Bengaluru',
    '40000000-0000-0000-0000-000000000003',
    '40000000-0000-0000-0000-000000000004',
    '40000000-0000-0000-0000-000000000003'
FROM reference.case_type ct WHERE ct.type_code = 'ROBBERY';

-- Case 3: Zero FIR example — initially at Women PS, transferred to Central PS
INSERT INTO case_mgmt.case
    (case_id, case_number,
     originating_station_id, current_station_id,
     case_type_id, case_status_code, priority, confidentiality_code,
     incident_date, opened_at,
     incident_description, incident_location,
     is_zero_fir, is_transferred,
     primary_io_id, supervising_officer_id, created_by)
SELECT
    '60000000-0000-0000-0000-000000000003',
    'CASE-KA-BLR-CEN-2026-00000003',
    '20000000-0000-0000-0000-000000000003',   -- originated at Women PS
    '20000000-0000-0000-0000-000000000001',   -- currently at Central PS
    ct.case_type_id, 'UNDER_INVESTIGATION', 'CRITICAL', 'RESTRICTED',
    '2026-03-05 23:45:00+05:30',
    '2026-03-05 23:55:00+05:30',
    'Victim reported assault. Zero FIR registered at Women PS as incident occurred in Central PS jurisdiction.',
    'Cubbon Park, Bengaluru',
    TRUE, TRUE,
    '40000000-0000-0000-0000-000000000002',
    '40000000-0000-0000-0000-000000000004',
    '40000000-0000-0000-0000-000000000005'
FROM reference.case_type ct WHERE ct.type_code = 'ASSAULT';

-- =============================================================================
-- SECTION H: FIRs
-- =============================================================================

-- FIR for Case 1 (primary demo)
INSERT INTO case_mgmt.fir
    (fir_id, case_id, fir_number, fir_year, station_id, fir_type,
     complainant_person_id, incident_date, incident_location,
     incident_description, ipc_sections, bnss_sections,
     registered_by, registered_at, fir_status)
VALUES
    ('70000000-0000-0000-0000-000000000001',
     '60000000-0000-0000-0000-000000000001',
     'FIR/001/2026', 2026,
     '20000000-0000-0000-0000-000000000001', 'REGULAR',
     '30000000-0000-0000-0000-000000000010',
     '2026-01-15 14:30:00+05:30',
     'MG Road, Bengaluru',
     'Complainant Anand Verma states that on 15-01-2026 at about 2:30 PM he received WhatsApp calls from unknown number claiming to be SBI official. Caller obtained OTP and Rs.4,50,000 was debited from complainant account.',
     '420, 419, 66C, 66D IT Act',
     '318 BNSS',
     '40000000-0000-0000-0000-000000000002',
     '2026-01-15 16:00:00+05:30',
     'REGISTERED');

-- Zero FIR for Case 3
INSERT INTO case_mgmt.fir
    (fir_id, case_id, fir_number, fir_year, station_id, fir_type,
     complainant_person_id, incident_date, incident_location,
     incident_description,
     registered_by, registered_at, fir_status,
     transferred_to_station_id, transferred_at,
     transfer_reason_code)
VALUES
    ('70000000-0000-0000-0000-000000000003',
     '60000000-0000-0000-0000-000000000003',
     'FIR/015/2026', 2026,
     '20000000-0000-0000-0000-000000000003', 'ZERO_FIR',
     '30000000-0000-0000-0000-000000000013',
     '2026-03-05 23:45:00+05:30',
     'Cubbon Park, Bengaluru',
     'Victim Mohan Das reported assault by unknown persons at Cubbon Park. Zero FIR registered as victim approached Women PS outside jurisdiction.',
     '40000000-0000-0000-0000-000000000005',
     '2026-03-05 23:55:00+05:30',
     'TRANSFERRED',
     '20000000-0000-0000-0000-000000000001',
     '2026-03-06 02:00:00+05:30',
     'ZERO_FIR');

-- Re-registered FIR at Central PS after Zero FIR transfer
INSERT INTO case_mgmt.fir
    (fir_id, case_id, fir_number, fir_year, station_id, fir_type,
     zero_fir_parent_id,
     complainant_person_id, incident_date, incident_location,
     incident_description,
     registered_by, registered_at, fir_status)
VALUES
    ('70000000-0000-0000-0000-000000000004',
     '60000000-0000-0000-0000-000000000003',
     'FIR/022/2026', 2026,
     '20000000-0000-0000-0000-000000000001', 'RE_REGISTERED',
     '70000000-0000-0000-0000-000000000003',
     '30000000-0000-0000-0000-000000000013',
     '2026-03-05 23:45:00+05:30',
     'Cubbon Park, Bengaluru',
     'Re-registered FIR based on Zero FIR No. FIR/015/2026 from Women PS Bengaluru. Victim Mohan Das assaulted by 3 unknown persons at Cubbon Park.',
     '40000000-0000-0000-0000-000000000002',
     '2026-03-06 08:00:00+05:30',
     'REGISTERED');

-- =============================================================================
-- SECTION I: CASE TRANSFERS
-- =============================================================================

INSERT INTO case_mgmt.case_transfer
    (case_id,
     source_station_id, source_fir_id,
     dest_station_id,   dest_fir_id,
     reason_code, reason_detail,
     transfer_order_no,
     initiated_by, approved_by, approved_at,
     transfer_timestamp, transfer_status)
VALUES
    ('60000000-0000-0000-0000-000000000003',
     '20000000-0000-0000-0000-000000000003',
     '70000000-0000-0000-0000-000000000003',
     '20000000-0000-0000-0000-000000000001',
     '70000000-0000-0000-0000-000000000004',
     'ZERO_FIR', 'Zero FIR transfer to jurisdictional station',
     'BWPS/TRF/2026/015',
     '40000000-0000-0000-0000-000000000005',
     '40000000-0000-0000-0000-000000000004',
     '2026-03-06 01:30:00+05:30',
     '2026-03-06 02:00:00+05:30',
     'COMPLETED');

-- =============================================================================
-- SECTION J: OFFICER CASE ASSIGNMENTS
-- =============================================================================

-- Case 1 assignments
INSERT INTO authorization.officer_case_assignment
    (case_id, officer_id, case_role_id, assigned_by, start_date, is_active, reason, scope)
SELECT '60000000-0000-0000-0000-000000000001',
       '40000000-0000-0000-0000-000000000002',
       cr.case_role_id,
       '40000000-0000-0000-0000-000000000004',
       '2026-01-15', TRUE,
       'Assigned as Primary IO for cyber fraud case',
       '{"resource_types": ["CASE","FIR","EVIDENCE","DOCUMENT","CUSTODY","FORENSIC"]}'
FROM reference.case_role cr WHERE cr.role_code = 'PRIMARY_IO';

INSERT INTO authorization.officer_case_assignment
    (case_id, officer_id, case_role_id, assigned_by, start_date, is_active, reason, scope)
SELECT '60000000-0000-0000-0000-000000000001',
       '40000000-0000-0000-0000-000000000004',
       cr.case_role_id,
       '40000000-0000-0000-0000-000000000001',
       '2026-01-15', TRUE,
       'SHO supervising case',
       '{}'
FROM reference.case_role cr WHERE cr.role_code = 'CASE_OWNER';

INSERT INTO authorization.officer_case_assignment
    (case_id, officer_id, case_role_id, assigned_by, start_date, is_active, reason, scope)
SELECT '60000000-0000-0000-0000-000000000001',
       '40000000-0000-0000-0000-000000000006',
       cr.case_role_id,
       '40000000-0000-0000-0000-000000000004',
       '2026-01-15', TRUE,
       'Malkhana custodian for seized items',
       '{"resource_types": ["EVIDENCE","CUSTODY"]}'
FROM reference.case_role cr WHERE cr.role_code = 'EVIDENCE_CUSTODIAN';

INSERT INTO authorization.officer_case_assignment
    (case_id, officer_id, case_role_id, assigned_by, start_date, is_active, reason, scope)
SELECT '60000000-0000-0000-0000-000000000001',
       '40000000-0000-0000-0000-000000000007',
       cr.case_role_id,
       '40000000-0000-0000-0000-000000000004',
       '2026-01-16', TRUE,
       'Cyber officer for digital evidence analysis',
       '{"resource_types": ["EVIDENCE","FORENSIC","DOCUMENT"]}'
FROM reference.case_role cr WHERE cr.role_code = 'DIGITAL_EVIDENCE_OFFICER';

-- =============================================================================
-- SECTION K: CASE PERSONS
-- =============================================================================

INSERT INTO identity.case_person
    (case_id, person_id, role_type_code, added_by)
VALUES
    ('60000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000010', 'COMPLAINANT', '40000000-0000-0000-0000-000000000002'),
    ('60000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000011', 'ACCUSED',     '40000000-0000-0000-0000-000000000002'),
    ('60000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000012', 'WITNESS',     '40000000-0000-0000-0000-000000000002');

-- =============================================================================
-- SECTION L: CUSTODIANS
-- =============================================================================

INSERT INTO custody.custodian
    (custodian_id, custodian_type_code, officer_id, display_name)
VALUES
    ('80000000-0000-0000-0000-000000000001', 'OFFICER', '40000000-0000-0000-0000-000000000002', 'SI Arjun Rao — Investigating Officer'),
    ('80000000-0000-0000-0000-000000000006', 'OFFICER', '40000000-0000-0000-0000-000000000006', 'HC Vikram Singh — Malkhana In-Charge'),
    ('80000000-0000-0000-0000-000000000007', 'OFFICER', '40000000-0000-0000-0000-000000000007', 'SI Meena Krishnan — Digital Evidence Officer');

INSERT INTO custody.custodian
    (custodian_id, custodian_type_code, station_id, display_name)
VALUES
    ('80000000-0000-0000-0000-000000000010', 'MALKHANA', '20000000-0000-0000-0000-000000000001', 'Malkhana — Central Police Station Bengaluru');

INSERT INTO custody.custodian
    (custodian_id, custodian_type_code, lab_id, display_name)
SELECT '80000000-0000-0000-0000-000000000020', 'FSL', lab_id, 'FSL Bengaluru — Forensic Science Laboratory'
FROM organisation.forensic_laboratory WHERE lab_code = 'FSL-KA-BLR';

INSERT INTO custody.custodian
    (custodian_id, custodian_type_code, court_id, display_name)
SELECT '80000000-0000-0000-0000-000000000030', 'COURT', court_id, 'City Civil and Sessions Court Bengaluru'
FROM organisation.court WHERE court_code = 'COURT-KA-BLR-01';

-- =============================================================================
-- SECTION M: EVIDENCE
-- =============================================================================

-- E001: Mobile Phone (original seized item)
INSERT INTO evidence.evidence
    (evidence_id, case_id, evidence_number, evidence_type_id,
     description, source, discovery_method, collection_timestamp,
     collection_location, collected_by,
     current_status_code, classification_code,
     make, model, serial_number, colour, condition_on_collection,
     seal_number, seal_applied_by, seal_applied_at,
     sha256_hash, integrity_status)
SELECT
    '90000000-0000-0000-0000-000000000001',
    '60000000-0000-0000-0000-000000000001',
    'E001',
    et.evidence_type_id,
    'Samsung Galaxy A52 mobile phone — alleged device used in cyber fraud',
    'Recovered from accused Farhan Sheikh residence during search',
    'SEARCH', '2026-01-18 11:00:00+05:30',
    '202 Shivajinagar, Bengaluru',
    '40000000-0000-0000-0000-000000000002',
    'IN_MALKHANA', 'CONFIDENTIAL',
    'Samsung', 'Galaxy A52', 'R5CR30XXXXX', 'Blue',
    'Good condition, screen intact, battery at 40%',
    'SEAL-2026-CEN-001',
    '40000000-0000-0000-0000-000000000002',
    '2026-01-18 11:15:00+05:30',
    'a3f5c8d9e1b2f4a67890abcdef123456a3f5c8d9e1b2f4a67890abcdef123456',
    'INTACT'
FROM reference.evidence_type et WHERE et.type_code = 'MOBILE_PHONE';

-- E002: Forensic Image (derived from E001)
INSERT INTO evidence.evidence
    (evidence_id, case_id, evidence_number, evidence_type_id,
     description, source, discovery_method, collection_timestamp,
     collected_by, current_status_code, classification_code,
     sha256_hash, integrity_status,
     storage_object_id, storage_provider, storage_path, mime_type, file_size_bytes)
SELECT
    '90000000-0000-0000-0000-000000000002',
    '60000000-0000-0000-0000-000000000001',
    'E002',
    et.evidence_type_id,
    'Physical forensic image of Samsung Galaxy A52 (E001) — full physical acquisition',
    'FSL Bengaluru Digital Forensics Lab',
    'FORENSIC_ACQUISITION', '2026-01-25 10:30:00+05:30',
    '40000000-0000-0000-0000-000000000007',
    'AT_FSL', 'CONFIDENTIAL',
    'b4e6d0c1f3a57890bcdef234567890b4e6d0c1f3a57890bcdef234567890abcd',
    'INTACT',
    'fsl-images/case-001/E002_samsung_a52_physical.E01',
    'MINIO', 'fsl-evidence', 'case-001/E002_samsung_a52_physical.E01',
    'application/octet-stream', 68719476736   -- 64GB image
FROM reference.evidence_type et WHERE et.type_code = 'FORENSIC_IMAGE';

-- E003: Chat Database extracted from E002
INSERT INTO evidence.evidence
    (evidence_id, case_id, evidence_number, evidence_type_id,
     description, source, discovery_method, collection_timestamp,
     collected_by, current_status_code, classification_code,
     sha256_hash, integrity_status,
     storage_object_id, storage_provider, storage_path, mime_type, file_size_bytes)
SELECT
    '90000000-0000-0000-0000-000000000003',
    '60000000-0000-0000-0000-000000000001',
    'E003',
    et.evidence_type_id,
    'WhatsApp message database extracted from forensic image — msgstore.db',
    'Extracted from E002 forensic image using Cellebrite UFED',
    'FORENSIC_EXTRACTION', '2026-01-26 14:00:00+05:30',
    '40000000-0000-0000-0000-000000000007',
    'AT_FSL', 'CONFIDENTIAL',
    'c5f7e1d2a4b68901cdef345678901234c5f7e1d2a4b68901cdef345678901234',
    'INTACT',
    'fsl-artifacts/case-001/E003_whatsapp_msgstore.db',
    'MINIO', 'fsl-evidence', 'case-001/E003_whatsapp_msgstore.db',
    'application/octet-stream', 52428800
FROM reference.evidence_type et WHERE et.type_code = 'DATABASE_EXTRACT';

-- E004: Screenshot from E003
INSERT INTO evidence.evidence
    (evidence_id, case_id, evidence_number, evidence_type_id,
     description, source, discovery_method, collection_timestamp,
     collected_by, current_status_code, classification_code,
     sha256_hash, integrity_status,
     storage_object_id, storage_provider, storage_path, mime_type, file_size_bytes)
SELECT
    '90000000-0000-0000-0000-000000000004',
    '60000000-0000-0000-0000-000000000001',
    'E004',
    et.evidence_type_id,
    'Screenshot of WhatsApp conversation showing OTP solicitation by accused — key evidence of fraud',
    'Derived from WhatsApp database E003',
    'FORENSIC_EXTRACTION', '2026-01-26 15:30:00+05:30',
    '40000000-0000-0000-0000-000000000007',
    'AT_FSL', 'CONFIDENTIAL',
    'd6a8f2e3b5c79012def456789012345d6a8f2e3b5c79012def456789012345ef',
    'INTACT',
    'fsl-artifacts/case-001/E004_whatsapp_screenshot.png',
    'MINIO', 'fsl-evidence', 'case-001/E004_whatsapp_screenshot.png',
    'image/png', 524288
FROM reference.evidence_type et WHERE et.type_code = 'SCREENSHOT';

-- E005: Forensic Report document (evidence item)
INSERT INTO evidence.evidence
    (evidence_id, case_id, evidence_number, evidence_type_id,
     description, source, discovery_method, collection_timestamp,
     collected_by, current_status_code, classification_code,
     sha256_hash, integrity_status)
SELECT
    '90000000-0000-0000-0000-000000000005',
    '60000000-0000-0000-0000-000000000001',
    'E005',
    et.evidence_type_id,
    'Forensic Examination Report — Digital Forensics of Samsung Galaxy A52 by FSL Bengaluru',
    'FSL Bengaluru', 'FSL_REPORT',
    '2026-02-05 16:00:00+05:30',
    '40000000-0000-0000-0000-000000000002',
    'RETURNED_FROM_FSL', 'CONFIDENTIAL',
    'e7b9a3f4c6d80123ef0567890123456e7b9a3f4c6d80123ef0567890123456ab',
    'INTACT'
FROM reference.evidence_type et WHERE et.type_code = 'FORENSIC_REPORT';

-- =============================================================================
-- SECTION N: DIGITAL EVIDENCE RECORD FOR E001
-- =============================================================================

INSERT INTO evidence.digital_evidence
    (evidence_id, case_id,
     device_type, device_make, device_model, device_serial, device_imei,
     device_os, device_os_version,
     acquisition_method, acquisition_tool, acquisition_tool_version,
     acquired_by, acquired_at,
     original_hash, original_hash_algo,
     acquisition_hash, acquisition_hash_algo,
     write_blocker_used, write_blocker_model,
     analysis_status, analysis_completed_at,
     key_findings)
VALUES
    ('90000000-0000-0000-0000-000000000001',
     '60000000-0000-0000-0000-000000000001',
     'MOBILE', 'Samsung', 'Galaxy A52', 'R5CR30XXXXX', '354123456789012',
     'Android', '11',
     'PHYSICAL', 'Cellebrite UFED 4PC', '7.67.0.121',
     '40000000-0000-0000-0000-000000000007',
     '2026-01-25 10:30:00+05:30',
     'a3f5c8d9e1b2f4a67890abcdef123456a3f5c8d9e1b2f4a67890abcdef123456', 'SHA256',
     'b4e6d0c1f3a57890bcdef234567890b4e6d0c1f3a57890bcdef234567890abcd', 'SHA256',
     TRUE, 'Tableau T35689iU Write Blocker',
     'COMPLETED', '2026-01-26 17:00:00+05:30',
     'WhatsApp messages showing communication with complainant on 15-01-2026. '
     'OTP solicitation messages found. Bank app installed. '
     'Multiple victim contact numbers found. Location data supports presence near MG Road.');

-- =============================================================================
-- SECTION O: EVIDENCE RELATIONSHIPS (Graph 1)
-- =============================================================================

-- E002 DERIVED_FROM E001
SELECT evidence.create_evidence_relationship(
    '60000000-0000-0000-0000-000000000001'::UUID,
    '90000000-0000-0000-0000-000000000002'::UUID,
    '90000000-0000-0000-0000-000000000001'::UUID,
    'DERIVED_FROM',
    '40000000-0000-0000-0000-000000000007'::UUID,
    1.0, 'Physical forensic image created from seized mobile phone using write-blocker'
);

-- E003 EXTRACTED_FROM E002
SELECT evidence.create_evidence_relationship(
    '60000000-0000-0000-0000-000000000001'::UUID,
    '90000000-0000-0000-0000-000000000003'::UUID,
    '90000000-0000-0000-0000-000000000002'::UUID,
    'EXTRACTED_FROM',
    '40000000-0000-0000-0000-000000000007'::UUID,
    1.0, 'WhatsApp database extracted from forensic image using Cellebrite UFED'
);

-- E004 DERIVED_FROM E003
SELECT evidence.create_evidence_relationship(
    '60000000-0000-0000-0000-000000000001'::UUID,
    '90000000-0000-0000-0000-000000000004'::UUID,
    '90000000-0000-0000-0000-000000000003'::UUID,
    'DERIVED_FROM',
    '40000000-0000-0000-0000-000000000007'::UUID,
    0.95, 'Screenshot extracted from WhatsApp message database showing OTP solicitation'
);

-- E004 SUPPORTS Case (via relationship to E001)
SELECT evidence.create_evidence_relationship(
    '60000000-0000-0000-0000-000000000001'::UUID,
    '90000000-0000-0000-0000-000000000004'::UUID,
    '90000000-0000-0000-0000-000000000001'::UUID,
    'SAME_DEVICE',
    '40000000-0000-0000-0000-000000000007'::UUID,
    1.0, 'Screenshot originated from the same mobile device'
);

-- E005 REPORTS_ON E002
SELECT evidence.create_evidence_relationship(
    '60000000-0000-0000-0000-000000000001'::UUID,
    '90000000-0000-0000-0000-000000000005'::UUID,
    '90000000-0000-0000-0000-000000000002'::UUID,
    'REPORTS_ON',
    '40000000-0000-0000-0000-000000000002'::UUID,
    1.0, 'FSL report covers examination of forensic image E002'
);

-- =============================================================================
-- SECTION P: CHAIN OF CUSTODY (Graph 2)
-- =============================================================================

-- E001: SEIZED by SI Arjun Rao
SELECT custody.record_custody_transfer(
    '90000000-0000-0000-0000-000000000001'::UUID,
    '60000000-0000-0000-0000-000000000001'::UUID,
    'SEIZED',
    NULL,
    '80000000-0000-0000-0000-000000000001'::UUID,
    '40000000-0000-0000-0000-000000000002'::UUID,
    'Seized from accused during search under Section 165 CrPC',
    NULL, 'SEAL-2026-CEN-001',
    'Good condition, screen intact', 'Sealed in evidence bag',
    NULL, 'a3f5c8d9e1b2f4a67890abcdef123456a3f5c8d9e1b2f4a67890abcdef123456',
    'Seized in presence of two panchas'
);

-- E001: DEPOSITED in Malkhana
SELECT custody.record_custody_transfer(
    '90000000-0000-0000-0000-000000000001'::UUID,
    '60000000-0000-0000-0000-000000000001'::UUID,
    'DEPOSITED',
    '80000000-0000-0000-0000-000000000001'::UUID,
    '80000000-0000-0000-0000-000000000010'::UUID,
    '40000000-0000-0000-0000-000000000002'::UUID,
    'Deposited in Malkhana for safe custody pending FSL submission',
    'SEAL-2026-CEN-001', 'SEAL-2026-CEN-001',
    'Sealed — intact', 'Sealed — intact',
    'a3f5c8d9e1b2f4a67890abcdef123456a3f5c8d9e1b2f4a67890abcdef123456',
    'a3f5c8d9e1b2f4a67890abcdef123456a3f5c8d9e1b2f4a67890abcdef123456',
    'Malkhana register entry no. MKH/2026/0042'
);

-- E001: SENT_TO_FSL
SELECT custody.record_custody_transfer(
    '90000000-0000-0000-0000-000000000001'::UUID,
    '60000000-0000-0000-0000-000000000001'::UUID,
    'SENT_TO_FSL',
    '80000000-0000-0000-0000-000000000010'::UUID,
    '80000000-0000-0000-0000-000000000020'::UUID,
    '40000000-0000-0000-0000-000000000002'::UUID,
    'Sent to FSL Bengaluru for digital forensic examination',
    'SEAL-2026-CEN-001', 'SEAL-2026-CEN-001',
    'Sealed — intact', 'Sealed — intact',
    'a3f5c8d9e1b2f4a67890abcdef123456a3f5c8d9e1b2f4a67890abcdef123456',
    'a3f5c8d9e1b2f4a67890abcdef123456a3f5c8d9e1b2f4a67890abcdef123456',
    'FSL request number: FSL-REQ-KA-2026-000001. Sent by SI Arjun Rao.'
);

-- E001: RECEIVED_BY_FSL
SELECT custody.record_custody_transfer(
    '90000000-0000-0000-0000-000000000001'::UUID,
    '60000000-0000-0000-0000-000000000001'::UUID,
    'RECEIVED_BY_FSL',
    '80000000-0000-0000-0000-000000000020'::UUID,
    '80000000-0000-0000-0000-000000000020'::UUID,
    '40000000-0000-0000-0000-000000000007'::UUID,
    'Received at FSL — acknowledgement issued. Seal intact.',
    'SEAL-2026-CEN-001', 'SEAL-2026-CEN-001',
    'Sealed — intact', 'Opened for examination after receipt',
    NULL, NULL,
    'FSL receipt ref: FSL-KA-BLR/2026/REC/0089'
);

-- E001: RETURNED_FROM_FSL back to Malkhana
SELECT custody.record_custody_transfer(
    '90000000-0000-0000-0000-000000000001'::UUID,
    '60000000-0000-0000-0000-000000000001'::UUID,
    'RETURNED_FROM_FSL',
    '80000000-0000-0000-0000-000000000020'::UUID,
    '80000000-0000-0000-0000-000000000010'::UUID,
    '40000000-0000-0000-0000-000000000002'::UUID,
    'Returned from FSL after examination. Re-sealed with new seal.',
    'SEAL-2026-CEN-001', 'SEAL-2026-CEN-002',
    'Original seal broken for examination', 'Re-sealed post examination',
    'a3f5c8d9e1b2f4a67890abcdef123456a3f5c8d9e1b2f4a67890abcdef123456',
    'a3f5c8d9e1b2f4a67890abcdef123456a3f5c8d9e1b2f4a67890abcdef123456',
    'FSL report received. Device returned intact.'
);

-- =============================================================================
-- SECTION Q: FORENSIC REQUEST AND REPORT
-- =============================================================================

INSERT INTO forensic.forensic_request
    (request_id, case_id, request_number, lab_id, discipline_id,
     requested_by, approved_by, approved_at,
     examination_required, purpose, priority,
     submitted_at, submitted_by, submission_ref,
     request_status)
SELECT
    'A0000000-0000-0000-0000-000000000001',
    '60000000-0000-0000-0000-000000000001',
    'FSL-REQ-KA-2026-000001',
    fl.lab_id,
    fd.discipline_id,
    '40000000-0000-0000-0000-000000000002',
    '40000000-0000-0000-0000-000000000004',
    '2026-01-20 10:00:00+05:30',
    'Physical acquisition of mobile phone. Extract call records, WhatsApp messages, '
    'browsing history, installed apps, location data, and any evidence of fraud.',
    'To examine mobile phone seized from accused and extract digital evidence '
    'relevant to cyber fraud case.',
    'HIGH',
    '2026-01-22 11:00:00+05:30',
    '40000000-0000-0000-0000-000000000002',
    'FSL-KA-BLR/2026/REC/0089',
    'RECEIVED'
FROM organisation.forensic_laboratory fl,
     reference.forensic_discipline fd
WHERE fl.lab_code = 'FSL-KA-BLR'
  AND fd.discipline_code = 'DIGITAL_FORENSICS';

INSERT INTO forensic.forensic_request_evidence
    (request_id, evidence_id, case_id, examination_required, item_seal_number)
VALUES
    ('A0000000-0000-0000-0000-000000000001',
     '90000000-0000-0000-0000-000000000001',
     '60000000-0000-0000-0000-000000000001',
     'Full physical acquisition, WhatsApp extraction, call log, location history',
     'SEAL-2026-CEN-001');

INSERT INTO forensic.forensic_examination
    (examination_id, request_id, case_id, lab_id, discipline_id,
     examiner_name, examiner_designation, examiner_employee_id,
     started_at, completed_at, examination_status,
     methods_used, instruments_used, lab_reference_number)
SELECT
    'A0000000-0000-0000-0000-000000000010',
    'A0000000-0000-0000-0000-000000000001',
    '60000000-0000-0000-0000-000000000001',
    fl.lab_id,
    fd.discipline_id,
    'Dr. Nalini Subramaniam',
    'Scientific Officer (Grade I)',
    'FSL-KA-EMP-042',
    '2026-01-25 09:00:00+05:30',
    '2026-01-30 17:00:00+05:30',
    'COMPLETED',
    'Physical acquisition using Cellebrite UFED 4PC. Logical extraction. '
    'File system analysis. Application data analysis. Hash verification.',
    'Cellebrite UFED 4PC v7.67, FTK Imager 4.7, Tableau T35689iU Write Blocker',
    'FSL/KA/BLR/DF/2026/0089'
FROM organisation.forensic_laboratory fl,
     reference.forensic_discipline fd
WHERE fl.lab_code = 'FSL-KA-BLR'
  AND fd.discipline_code = 'DIGITAL_FORENSICS';

INSERT INTO forensic.forensic_result
    (examination_id, request_id, case_id, evidence_id,
     question_examined, finding, conclusion, opinion, result_type)
VALUES
    ('A0000000-0000-0000-0000-000000000010',
     'A0000000-0000-0000-0000-000000000001',
     '60000000-0000-0000-0000-000000000001',
     '90000000-0000-0000-0000-000000000001',
     'WhatsApp messages between accused and complainant on 15-01-2026',
     'WhatsApp conversation thread found between number +91-98000XXXXX (registered to complainant) '
     'and +91-77000XXXXX (number on accused device). Messages show accused posing as '
     '"SBI Customer Care" requesting OTP. OTP "826571" sent by complainant at 14:47:32 IST.',
     'Digital evidence confirms WhatsApp-based OTP fraud on 15-01-2026.',
     'In my expert opinion, the recovered WhatsApp messages constitute direct evidence '
     'of cyber fraud under Section 66C and 66D IT Act.',
     'POSITIVE');

INSERT INTO forensic.forensic_report
    (report_id, request_id, case_id, lab_id,
     report_number, report_date,
     examiner_name, examiner_designation,
     summary, conclusions,
     report_status, received_by, received_at)
SELECT
    'A0000000-0000-0000-0000-000000000020',
    'A0000000-0000-0000-0000-000000000001',
    '60000000-0000-0000-0000-000000000001',
    fl.lab_id,
    'FSL/KA/BLR/DF/RPT/2026/0089',
    '2026-02-03',
    'Dr. Nalini Subramaniam',
    'Scientific Officer (Grade I), FSL Bengaluru',
    'Physical forensic examination of Samsung Galaxy A52 mobile phone seized from accused. '
    'Complete data extraction performed. WhatsApp messages, call logs and location data recovered.',
    'WhatsApp conversation confirms OTP solicitation by accused on 15-01-2026. '
    'Location data places device near MG Road Bengaluru at time of fraud. '
    'Hash values confirm integrity of extracted data.',
    'RECEIVED',
    '40000000-0000-0000-0000-000000000002',
    '2026-02-05 11:00:00+05:30'
FROM organisation.forensic_laboratory fl WHERE fl.lab_code = 'FSL-KA-BLR';

-- =============================================================================
-- SECTION R: DOCUMENTS
-- =============================================================================

-- FIR Document
INSERT INTO documents.document
    (document_id, document_ref, document_type_id, title,
     case_id, station_id,
     classification_code, retention_category,
     owner_officer_id, created_by)
SELECT
    'B0000000-0000-0000-0000-000000000001',
    'DOC-KA-BLR-CEN-2026-000001',
    dt.document_type_id,
    'FIR No. FIR/001/2026 — Cyber Fraud Case',
    '60000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000001',
    'CONFIDENTIAL', 'LONG_TERM',
    '40000000-0000-0000-0000-000000000002',
    '40000000-0000-0000-0000-000000000002'
FROM reference.document_type dt WHERE dt.type_code = 'FIR';

-- FIR Document Version 1 (draft)
INSERT INTO documents.document_version
    (version_id, document_id, version_number, version_label,
     storage_object_id, storage_provider, storage_path, object_key,
     file_name, mime_type, file_size_bytes,
     sha256_hash, hash_algorithm,
     status_code, change_reason, created_by)
VALUES
    ('B0000000-0000-0000-0001-000000000001',
     'B0000000-0000-0000-0000-000000000001',
     1, 'v1.0 — Initial Draft',
     'fir-docs/case-001/FIR_001_2026_v1.pdf',
     'MINIO', 'police-documents', 'case-001/FIR_001_2026_v1.pdf',
     'FIR_001_2026_v1.pdf', 'application/pdf', 524288,
     'f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6',
     'SHA256', 'DRAFT', 'Initial FIR draft',
     '40000000-0000-0000-0000-000000000002');

-- FIR Document Version 2 (reviewed)
INSERT INTO documents.document_version
    (version_id, document_id, version_number, version_label,
     storage_object_id, storage_provider, storage_path, object_key,
     file_name, mime_type, file_size_bytes,
     sha256_hash, hash_algorithm,
     previous_version_id,
     status_code, change_reason, created_by)
VALUES
    ('B0000000-0000-0000-0002-000000000001',
     'B0000000-0000-0000-0000-000000000001',
     2, 'v2.0 — Final',
     'fir-docs/case-001/FIR_001_2026_v2.pdf',
     'MINIO', 'police-documents', 'case-001/FIR_001_2026_v2.pdf',
     'FIR_001_2026_v2.pdf', 'application/pdf', 548864,
     'aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899',
     'SHA256',
     'B0000000-0000-0000-0001-000000000001',
     'FINAL', 'Corrected sections, approved by SHO',
     '40000000-0000-0000-0000-000000000002');

-- Update document current_version_id
UPDATE documents.document
SET current_version_id = 'B0000000-0000-0000-0002-000000000001',
    current_version_no = 2
WHERE document_id = 'B0000000-0000-0000-0000-000000000001';

-- Finalize version 2
SELECT documents.finalize_document_version(
    'B0000000-0000-0000-0002-000000000001'::UUID,
    '40000000-0000-0000-0000-000000000004'::UUID
);

-- Digital signature on v2
INSERT INTO documents.digital_signature
    (signature_id, document_id, document_version_id,
     signer_officer_id, signer_name, signer_role,
     signature_algorithm, signed_hash, hash_algorithm,
     signature_value_b64,
     certificate_subject, signed_at, signature_status)
VALUES
    ('C0000000-0000-0000-0000-000000000001',
     'B0000000-0000-0000-0000-000000000001',
     'B0000000-0000-0000-0002-000000000001',
     '40000000-0000-0000-0000-000000000004',
     'Inspector Suresh Patil',
     'SHO, Central Police Station Bengaluru',
     'RSA_SHA256',
     'aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899',
     'SHA256',
     'DEMO_SIGNATURE_VALUE_BASE64_PLACEHOLDER==',
     'CN=Suresh Patil, O=Karnataka Police, C=IN',
     '2026-01-16 10:00:00+05:30',
     'VALID');

-- Link signature to version
UPDATE documents.document_version
SET digital_signature_id = 'C0000000-0000-0000-0000-000000000001'
WHERE version_id = 'B0000000-0000-0000-0002-000000000001';

-- Case document junction
INSERT INTO documents.case_document (case_id, document_id, link_type, added_by)
VALUES
    ('60000000-0000-0000-0000-000000000001',
     'B0000000-0000-0000-0000-000000000001',
     'FIR',
     '40000000-0000-0000-0000-000000000002');

-- Update FIR to reference document
UPDATE case_mgmt.fir
SET document_id = 'B0000000-0000-0000-0000-000000000001'
WHERE fir_id = '70000000-0000-0000-0000-000000000001';

-- =============================================================================
-- SECTION S: CASE EVENTS
-- =============================================================================

INSERT INTO case_mgmt.case_event
    (event_id, case_id, event_type_code, event_timestamp,
     recorded_by, title, description, location)
VALUES
    ('D0000000-0000-0000-0000-000000000001',
     '60000000-0000-0000-0000-000000000001',
     'FIR_REGISTERED', '2026-01-15 16:00:00+05:30',
     '40000000-0000-0000-0000-000000000002',
     'FIR No. FIR/001/2026 Registered',
     'FIR registered by SI Arjun Rao for cyber fraud. Complainant: Anand Verma.',
     'Central Police Station, Bengaluru'),

    ('D0000000-0000-0000-0000-000000000002',
     '60000000-0000-0000-0000-000000000001',
     'OFFICER_ASSIGNED', '2026-01-15 16:30:00+05:30',
     '40000000-0000-0000-0000-000000000004',
     'SI Arjun Rao Assigned as Primary IO',
     'SI Arjun Rao assigned as Primary Investigating Officer by SHO Suresh Patil.',
     'Central Police Station, Bengaluru'),

    ('D0000000-0000-0000-0000-000000000003',
     '60000000-0000-0000-0000-000000000001',
     'SEARCH_CONDUCTED', '2026-01-18 10:00:00+05:30',
     '40000000-0000-0000-0000-000000000002',
     'Search Conducted at Accused Premises',
     'Search conducted at 202 Shivajinagar, Bengaluru — premises of Farhan Sheikh under '
     'Section 165 CrPC in presence of two independent witnesses.',
     '202 Shivajinagar, Bengaluru'),

    ('D0000000-0000-0000-0000-000000000004',
     '60000000-0000-0000-0000-000000000001',
     'SEIZURE_MADE', '2026-01-18 11:00:00+05:30',
     '40000000-0000-0000-0000-000000000002',
     'Mobile Phone (E001) Seized',
     'Samsung Galaxy A52 mobile phone (IMEI: 354123456789012) seized from Farhan Sheikh. '
     'Sealed as E001 with seal SEAL-2026-CEN-001. Seizure memo prepared.',
     '202 Shivajinagar, Bengaluru'),

    ('D0000000-0000-0000-0000-000000000005',
     '60000000-0000-0000-0000-000000000001',
     'FSL_REQUESTED', '2026-01-22 11:00:00+05:30',
     '40000000-0000-0000-0000-000000000002',
     'FSL Request Submitted — Digital Forensics',
     'FSL request FSL-REQ-KA-2026-000001 submitted to FSL Bengaluru for digital forensic '
     'examination of seized mobile phone E001.',
     'Central Police Station, Bengaluru'),

    ('D0000000-0000-0000-0000-000000000006',
     '60000000-0000-0000-0000-000000000001',
     'FSL_REPORT_RECEIVED', '2026-02-05 11:00:00+05:30',
     '40000000-0000-0000-0000-000000000002',
     'FSL Report Received',
     'Forensic report FSL/KA/BLR/DF/RPT/2026/0089 received from FSL Bengaluru. '
     'WhatsApp evidence confirms fraud. Hash values verified.',
     'Central Police Station, Bengaluru'),

    ('D0000000-0000-0000-0000-000000000007',
     '60000000-0000-0000-0000-000000000001',
     'WITNESS_STATEMENT_RECORDED', '2026-02-10 14:00:00+05:30',
     '40000000-0000-0000-0000-000000000002',
     'Witness Statement of Sunita Reddy Recorded',
     'Section 161 CrPC statement of witness Sunita Reddy recorded. '
     'Witness confirms seeing accused use mobile phone on the date of incident.',
     'Central Police Station, Bengaluru');

-- =============================================================================
-- SECTION T: CASE DIARY ENTRIES
-- =============================================================================

INSERT INTO investigation.case_diary
    (case_id, entry_date, entry_time, entry_timestamp,
     officer_id, subject, content, location)
VALUES
    ('60000000-0000-0000-0000-000000000001',
     '2026-01-15', '16:30:00+05:30', '2026-01-15 16:30:00+05:30',
     '40000000-0000-0000-0000-000000000002',
     'FIR Registration and Initial Steps',
     'FIR No. FIR/001/2026 registered based on complaint of Anand Verma S/o Ramesh Verma, '
     'R/o 101 MG Road Bengaluru. Complainant states that on 15-01-2026 at about 14:30 hrs he '
     'received WhatsApp call from unknown number. Caller identified himself as SBI official '
     'and asked for OTP. Complainant shared OTP and subsequently Rs.4,50,000 was debited. '
     'Case registered under Section 420, 419 IPC and 66C, 66D IT Act. '
     'Assigned as IO. Verification of complainant bank records initiated.',
     'Central Police Station, Bengaluru'),

    ('60000000-0000-0000-0000-000000000001',
     '2026-01-18', '13:00:00+05:30', '2026-01-18 13:00:00+05:30',
     '40000000-0000-0000-0000-000000000002',
     'Search and Seizure at Accused Premises',
     'On the basis of call detail records obtained from telecom company, search conducted at '
     '202 Shivajinagar premises of Farhan Sheikh S/o Abdul Sheikh. Search conducted under '
     'Section 165 CrPC in presence of two pancha witnesses. '
     'One Samsung Galaxy A52 mobile phone IMEI 354123456789012 found and seized. '
     'Sealed with Seal No. SEAL-2026-CEN-001. Seizure memo prepared.',
     '202 Shivajinagar, Bengaluru');

-- =============================================================================
-- SECTION U: AUDIT EVENTS (representative sample)
-- =============================================================================

SELECT audit.create_audit_event(
    'FIR_CREATE',
    '40000000-0000-0000-0000-000000000002'::UUID,
    '20000000-0000-0000-0000-000000000001'::UUID,
    '60000000-0000-0000-0000-000000000001'::UUID,
    'FIR', '70000000-0000-0000-0000-000000000001'::UUID,
    'FIR/001/2026', 'SUCCESS', NULL, NULL,
    NULL, 'FIR registration',
    '192.168.1.100'::INET, NULL, '{}'
);

SELECT audit.create_audit_event(
    'EVIDENCE_CREATE',
    '40000000-0000-0000-0000-000000000002'::UUID,
    '20000000-0000-0000-0000-000000000001'::UUID,
    '60000000-0000-0000-0000-000000000001'::UUID,
    'EVIDENCE', '90000000-0000-0000-0000-000000000001'::UUID,
    'E001', 'SUCCESS', NULL, NULL,
    NULL, 'Evidence seized and registered',
    '192.168.1.100'::INET, NULL, '{}'
);

SELECT audit.create_audit_event(
    'CUSTODY_TRANSFER',
    '40000000-0000-0000-0000-000000000002'::UUID,
    '20000000-0000-0000-0000-000000000001'::UUID,
    '60000000-0000-0000-0000-000000000001'::UUID,
    'CUSTODY', '90000000-0000-0000-0000-000000000001'::UUID,
    'E001-CUSTODY', 'SUCCESS', NULL, NULL,
    NULL, 'E001 deposited in Malkhana',
    '192.168.1.100'::INET, NULL, '{}'
);

SELECT audit.create_audit_event(
    'DOCUMENT_UPLOAD',
    '40000000-0000-0000-0000-000000000002'::UUID,
    '20000000-0000-0000-0000-000000000001'::UUID,
    '60000000-0000-0000-0000-000000000001'::UUID,
    'DOCUMENT', 'B0000000-0000-0000-0000-000000000001'::UUID,
    'DOC-KA-BLR-CEN-2026-000001', 'SUCCESS', NULL, NULL,
    NULL, 'FIR document uploaded',
    '192.168.1.100'::INET, NULL, '{}'
);

SELECT audit.create_audit_event(
    'DOCUMENT_SIGN',
    '40000000-0000-0000-0000-000000000004'::UUID,
    '20000000-0000-0000-0000-000000000001'::UUID,
    '60000000-0000-0000-0000-000000000001'::UUID,
    'DOCUMENT', 'B0000000-0000-0000-0000-000000000001'::UUID,
    'DOC-KA-BLR-CEN-2026-000001', 'SUCCESS', NULL, NULL,
    NULL, 'FIR v2 finalized and signed by SHO',
    '192.168.1.101'::INET, NULL, '{}'
);

SELECT audit.create_audit_event(
    'DOCUMENT_DOWNLOAD',
    '40000000-0000-0000-0000-000000000002'::UUID,
    '20000000-0000-0000-0000-000000000001'::UUID,
    '60000000-0000-0000-0000-000000000001'::UUID,
    'DOCUMENT', 'B0000000-0000-0000-0000-000000000001'::UUID,
    'DOC-KA-BLR-CEN-2026-000001', 'SUCCESS', NULL, NULL,
    NULL, 'FIR downloaded by IO for review',
    '192.168.1.100'::INET, NULL, '{}'
);

-- =============================================================================
-- SECTION V: INTEGRATION REFERENCES
-- =============================================================================

INSERT INTO integration.external_reference
    (system_name, local_entity_type, local_entity_id,
     external_record_id, sync_status, created_by)
VALUES
    ('CCTNS', 'CASE', '60000000-0000-0000-0000-000000000001',
     'CCTNS/KA/BLR/2026/00001', 'SYNCED',
     '40000000-0000-0000-0000-000000000002'),
    ('CCTNS', 'FIR', '70000000-0000-0000-0000-000000000001',
     'CCTNS/KA/BLR/FIR/2026/001', 'SYNCED',
     '40000000-0000-0000-0000-000000000002');

COMMIT;
