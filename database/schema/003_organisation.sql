-- =============================================================================
-- 003_organisation.sql
-- Organisational hierarchy, police stations, jurisdictions
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. ORGANISATION UNIT — flexible self-referencing hierarchy
--    Supports both District system and Commissionerate system.
--    Different Indian states may have different depth/structure.
-- ---------------------------------------------------------------------------
CREATE TABLE organisation.organisation_unit (
    unit_id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    unit_code          VARCHAR(60)  NOT NULL UNIQUE,
    unit_name          VARCHAR(200) NOT NULL,
    unit_type_code     VARCHAR(40)  NOT NULL REFERENCES reference.unit_type(unit_type_code),
    parent_unit_id     UUID         REFERENCES organisation.organisation_unit(unit_id),
    state_code         CHAR(2),                    -- ISO 3166-2 state code, e.g. KA, MH, DL
    country_code       CHAR(2)      NOT NULL DEFAULT 'IN',
    address            TEXT,
    city               VARCHAR(100),
    district           VARCHAR(100),
    pincode            VARCHAR(10),
    phone              VARCHAR(20),
    email              VARCHAR(120),
    latitude           NUMERIC(10,7),
    longitude          NUMERIC(10,7),
    -- PostGIS-compatible geometry stored as text; replace with geometry(Point,4326)
    -- if PostGIS is available
    geom_wkt           TEXT,
    is_active          BOOLEAN      NOT NULL DEFAULT TRUE,
    established_on     DATE,
    notes              TEXT,
    created_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by         UUID,        -- officer_id; circular ref resolved by deferral
    updated_by         UUID
);

CREATE INDEX idx_org_unit_parent    ON organisation.organisation_unit(parent_unit_id);
CREATE INDEX idx_org_unit_type      ON organisation.organisation_unit(unit_type_code);
CREATE INDEX idx_org_unit_state     ON organisation.organisation_unit(state_code);
CREATE INDEX idx_org_unit_name_trgm ON organisation.organisation_unit USING gin(unit_name gin_trgm_ops);

-- ---------------------------------------------------------------------------
-- 2. POLICE STATION — dedicated entity linked to organisation unit
--    Every police station IS an organisation_unit but has its own richer record.
-- ---------------------------------------------------------------------------
CREATE TABLE organisation.police_station (
    station_id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    station_code            VARCHAR(60)  NOT NULL UNIQUE,
    station_name            VARCHAR(200) NOT NULL,
    station_type_code       VARCHAR(40)  NOT NULL REFERENCES reference.station_type(station_type_code),
    organisation_unit_id    UUID         NOT NULL UNIQUE REFERENCES organisation.organisation_unit(unit_id),

    -- Soft hierarchy references for quick lookup (all FKs into org unit)
    -- These are denormalised convenience columns — truth is in org_unit hierarchy
    parent_station_id       UUID         REFERENCES organisation.police_station(station_id),  -- for outpost → PS

    state_code              CHAR(2)      NOT NULL,
    district_name           VARCHAR(100),
    subdivision_name        VARCHAR(100),
    circle_name             VARCHAR(100),

    -- Address
    address_line1           VARCHAR(200),
    address_line2           VARCHAR(200),
    city                    VARCHAR(100),
    pincode                 VARCHAR(10),
    phone_primary           VARCHAR(20),
    phone_emergency         VARCHAR(20),
    email                   VARCHAR(120),
    fax                     VARCHAR(20),

    -- Location
    latitude                NUMERIC(10,7),
    longitude               NUMERIC(10,7),
    geom_wkt                TEXT,

    -- Identifiers used in external systems
    cctns_station_code      VARCHAR(60),   -- CCTNS assigned code
    state_station_code      VARCHAR(60),   -- State-assigned code

    -- Status
    is_active               BOOLEAN      NOT NULL DEFAULT TRUE,
    established_on          DATE,
    notes                   TEXT,

    created_at              TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by              UUID,
    updated_by              UUID
);

CREATE INDEX idx_ps_org_unit    ON organisation.police_station(organisation_unit_id);
CREATE INDEX idx_ps_state       ON organisation.police_station(state_code);
CREATE INDEX idx_ps_parent      ON organisation.police_station(parent_station_id);
CREATE INDEX idx_ps_name_trgm   ON organisation.police_station USING gin(station_name gin_trgm_ops);
CREATE INDEX idx_ps_cctns_code  ON organisation.police_station(cctns_station_code);

-- ---------------------------------------------------------------------------
-- 3. JURISDICTION — territorial jurisdiction of a police station
-- ---------------------------------------------------------------------------
CREATE TABLE organisation.jurisdiction (
    jurisdiction_id      UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    station_id           UUID         NOT NULL REFERENCES organisation.police_station(station_id),
    jurisdiction_name    VARCHAR(200) NOT NULL,
    jurisdiction_type    VARCHAR(40)  NOT NULL DEFAULT 'TERRITORIAL',
                                      -- TERRITORIAL, FUNCTIONAL, CONCURRENT
    description          TEXT,
    area_sq_km           NUMERIC(12,4),
    population_approx    BIGINT,

    -- Boundary as WKT polygon (PostGIS-compatible; store as text for portability)
    boundary_wkt         TEXT,

    -- Constituent localities / areas described textually when geometry unavailable
    localities_text      TEXT,

    is_active            BOOLEAN      NOT NULL DEFAULT TRUE,
    effective_from       DATE,
    effective_to         DATE,
    created_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by           UUID,
    updated_by           UUID
);

CREATE INDEX idx_jurisdiction_station ON organisation.jurisdiction(station_id);

-- ---------------------------------------------------------------------------
-- 4. JURISDICTION LOCALITY — specific named localities under a jurisdiction
--    Allows answering "which PS has jurisdiction over locality X?"
-- ---------------------------------------------------------------------------
CREATE TABLE organisation.jurisdiction_locality (
    locality_id      UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    jurisdiction_id  UUID         NOT NULL REFERENCES organisation.jurisdiction(jurisdiction_id),
    locality_name    VARCHAR(200) NOT NULL,
    locality_type    VARCHAR(60),   -- VILLAGE, WARD, MOHALLA, COLONY, ROAD, etc.
    pin_code         VARCHAR(10),
    notes            TEXT,
    is_active        BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_jlocality_jurisdiction ON organisation.jurisdiction_locality(jurisdiction_id);
CREATE INDEX idx_jlocality_name_trgm    ON organisation.jurisdiction_locality
    USING gin(locality_name gin_trgm_ops);

-- ---------------------------------------------------------------------------
-- 5. BEAT — smallest patrol unit under a police station
-- ---------------------------------------------------------------------------
CREATE TABLE organisation.beat (
    beat_id       UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    beat_code     VARCHAR(60)  NOT NULL,
    beat_name     VARCHAR(120) NOT NULL,
    station_id    UUID         NOT NULL REFERENCES organisation.police_station(station_id),
    beat_type     VARCHAR(40)  NOT NULL DEFAULT 'REGULAR',  -- REGULAR, MOBILE, CYBER
    area_sq_km    NUMERIC(10,4),
    boundary_wkt  TEXT,
    notes         TEXT,
    is_active     BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    UNIQUE (station_id, beat_code)
);

CREATE INDEX idx_beat_station ON organisation.beat(station_id);

-- ---------------------------------------------------------------------------
-- 6. EXTERNAL AGENCY — for referencing other agencies (CBI, CID, NCB, ED, etc.)
-- ---------------------------------------------------------------------------
CREATE TABLE organisation.external_agency (
    agency_id     UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    agency_code   VARCHAR(60)  NOT NULL UNIQUE,
    agency_name   VARCHAR(200) NOT NULL,
    agency_type   VARCHAR(60),   -- CENTRAL, STATE, JUDICIAL, FORENSIC, PROSECUTION
    parent_ministry VARCHAR(120),
    website       VARCHAR(200),
    contact_email VARCHAR(120),
    contact_phone VARCHAR(20),
    notes         TEXT,
    is_active     BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now()
);

INSERT INTO organisation.external_agency (agency_code, agency_name, agency_type) VALUES
('CBI',   'Central Bureau of Investigation',        'CENTRAL'),
('CID',   'Criminal Investigation Department',      'STATE'),
('NCB',   'Narcotics Control Bureau',               'CENTRAL'),
('ED',    'Enforcement Directorate',                'CENTRAL'),
('NIA',   'National Investigation Agency',          'CENTRAL'),
('SFIO',  'Serious Fraud Investigation Office',     'CENTRAL'),
('IT_DEPT','Income Tax Department',                 'CENTRAL'),
('CUSTOMS','Customs Department',                    'CENTRAL');

-- ---------------------------------------------------------------------------
-- 7. FSL / FORENSIC LABORATORY — may belong to state police or central body
-- ---------------------------------------------------------------------------
CREATE TABLE organisation.forensic_laboratory (
    lab_id             UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    lab_code           VARCHAR(60)  NOT NULL UNIQUE,
    lab_name           VARCHAR(200) NOT NULL,
    lab_type           VARCHAR(40)  NOT NULL DEFAULT 'STATE_FSL',
                                    -- STATE_FSL, CENTRAL_FSL, PRIVATE, UNIVERSITY
    organisation_unit_id UUID       REFERENCES organisation.organisation_unit(unit_id),
    address            TEXT,
    city               VARCHAR(100),
    state_code         CHAR(2),
    phone              VARCHAR(20),
    email              VARCHAR(120),
    accreditation_body VARCHAR(120),
    accreditation_no   VARCHAR(80),
    accreditation_valid_until DATE,
    is_active          BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by         UUID,
    updated_by         UUID
);

INSERT INTO organisation.forensic_laboratory (lab_code, lab_name, lab_type, state_code, city) VALUES
('FSL-KA-BLR',  'Forensic Science Laboratory Bengaluru',          'STATE_FSL', 'KA', 'Bengaluru'),
('FSL-KA-MYS',  'Forensic Science Laboratory Mysuru',             'STATE_FSL', 'KA', 'Mysuru'),
('FSL-MH-MUM',  'Forensic Science Laboratory Mumbai',             'STATE_FSL', 'MH', 'Mumbai'),
('FSL-DL-NEW',  'Forensic Science Laboratory New Delhi',          'STATE_FSL', 'DL', 'New Delhi'),
('CFSL-HYD',    'Central Forensic Science Laboratory Hyderabad',  'CENTRAL_FSL','TS','Hyderabad'),
('CFSL-CHN',    'Central Forensic Science Laboratory Chennai',    'CENTRAL_FSL','TN','Chennai');

-- ---------------------------------------------------------------------------
-- 8. COURT — for references when submitting documents / exhibits
-- ---------------------------------------------------------------------------
CREATE TABLE organisation.court (
    court_id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    court_code        VARCHAR(60)  NOT NULL UNIQUE,
    court_name        VARCHAR(200) NOT NULL,
    court_type        VARCHAR(60)  NOT NULL,
                      -- SUPREME, HIGH, SESSIONS, CJM, JMFC, SPECIAL, MAGISTRATE, OTHER
    state_code        CHAR(2),
    district          VARCHAR(100),
    city              VARCHAR(100),
    address           TEXT,
    phone             VARCHAR(20),
    email             VARCHAR(120),
    is_active         BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at        TIMESTAMPTZ  NOT NULL DEFAULT now()
);

INSERT INTO organisation.court (court_code, court_name, court_type, state_code, city) VALUES
('COURT-KA-BLR-01', 'City Civil and Sessions Court Bengaluru',  'SESSIONS',    'KA', 'Bengaluru'),
('COURT-KA-BLR-02', 'Chief Metropolitan Magistrate Bengaluru',  'CJM',         'KA', 'Bengaluru'),
('COURT-MH-MUM-01', 'City Civil and Sessions Court Mumbai',     'SESSIONS',    'MH', 'Mumbai'),
('COURT-DL-NEW-01', 'Sessions Court Delhi',                     'SESSIONS',    'DL', 'New Delhi');
