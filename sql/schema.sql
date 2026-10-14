-- Schema for the propulsion comparison database.
--
-- Build from the repository root with:
--     duckdb data/propulsion.duckdb < sql/schema.sql
--
-- The .duckdb file is a build artifact and is not version controlled. The raw CSVs
-- under data/raw/ and this file are the sources of truth.
--
-- Unit convention, applied everywhere:
--     thrust        mN
--     specific impulse  s
--     power         W
--     mass          kg
--     delta-v       m/s
--     time          days (missions), seconds (computed transfer times are stored in days)
-- Standard gravity is 9.80665 m/s^2 throughout.

DROP TABLE IF EXISTS results;
DROP TABLE IF EXISTS thrusters;
DROP TABLE IF EXISTS missions;
DROP TABLE IF EXISTS propellants;
DROP TABLE IF EXISTS sources;

-- ---------------------------------------------------------------- sources

CREATE TABLE sources (
    source_id    VARCHAR PRIMARY KEY,
    citation     VARCHAR NOT NULL,
    venue        VARCHAR,
    year         INTEGER CHECK (year IS NULL OR (year BETWEEN 1940 AND 2100)),
    url          VARCHAR,
    source_kind  VARCHAR NOT NULL
                 CHECK (source_kind IN ('journal','conference','technical_report','book_chapter',
                                        'study_report','preprint','datasheet','web_technical',
                                        'news','reference_data'))
);

-- ------------------------------------------------------------ propellants

CREATE TABLE propellants (
    propellant            VARCHAR PRIMARY KEY,
    accelerated_species   VARCHAR,
    stored_species        VARCHAR,
    molar_mass_g_mol      DOUBLE  NOT NULL CHECK (molar_mass_g_mol > 0),
    first_ionisation_eV   DOUBLE  CHECK (first_ionisation_eV IS NULL OR first_ionisation_eV > 0),
    storage_phase         VARCHAR NOT NULL
                          CHECK (storage_phase IN ('solid','liquid','gas','supercritical')),
    storage_density_kg_m3 DOUBLE  CHECK (storage_density_kg_m3 IS NULL OR storage_density_kg_m3 > 0),
    storage_temp_K        DOUBLE  CHECK (storage_temp_K IS NULL OR storage_temp_K > 0),
    storage_pressure_bar  DOUBLE  CHECK (storage_pressure_bar IS NULL OR storage_pressure_bar >= 0),
    density_basis         VARCHAR,
    source_id             VARCHAR REFERENCES sources(source_id),
    notes                 VARCHAR
);

-- --------------------------------------------------------------- missions

CREATE TABLE missions (
    mission_id         VARCHAR PRIMARY KEY,
    name               VARCHAR NOT NULL,
    mission_class      VARCHAR NOT NULL
                       CHECK (mission_class IN ('crewed_mars','deep_space_probe')),
    payload_mass_kg    DOUBLE  NOT NULL CHECK (payload_mass_kg > 0),
    delta_v_m_s        DOUBLE  NOT NULL CHECK (delta_v_m_s > 0),
    max_trip_time_days DOUBLE  CHECK (max_trip_time_days IS NULL OR max_trip_time_days > 0),
    power_available_W  DOUBLE  CHECK (power_available_W IS NULL OR power_available_W > 0),
    power_source       VARCHAR CHECK (power_source IN ('nuclear_electric','solar_electric',
                                                       'nuclear_thermal','chemical')),
    parameter_basis    VARCHAR NOT NULL CHECK (parameter_basis IN ('assumed','sourced')),
    source_id          VARCHAR REFERENCES sources(source_id),
    notes              VARCHAR
);

-- -------------------------------------------------------------- thrusters

CREATE TABLE thrusters (
    thruster_id       VARCHAR PRIMARY KEY,
    name              VARCHAR NOT NULL,
    thruster_type     VARCHAR NOT NULL
                      CHECK (thruster_type IN ('gridded_ion','hall','mpd','other_plasma',
                                               'nuclear_thermal')),
    propellant        VARCHAR NOT NULL REFERENCES propellants(propellant),
    thrust_mN         DOUBLE  CHECK (thrust_mN IS NULL OR thrust_mN > 0),
    isp_s             DOUBLE  CHECK (isp_s IS NULL OR isp_s > 0),
    input_power_W     DOUBLE  CHECK (input_power_W IS NULL OR input_power_W > 0),
    efficiency        DOUBLE  CHECK (efficiency IS NULL OR (efficiency > 0 AND efficiency <= 1)),
    mass_kg           DOUBLE  CHECK (mass_kg IS NULL OR mass_kg > 0),
    -- how mass_kg was obtained; 'unknown' means the cited source does not give it
    mass_basis        VARCHAR NOT NULL
                      CHECK (mass_basis IN ('measured','vendor','secondary','unknown')),
    -- electric thrusters quote electrical input power; NTP rows quote reactor thermal power,
    -- so the two are not comparable and must not be mixed in a power-limited calculation
    power_basis       VARCHAR NOT NULL
                      CHECK (power_basis IN ('electrical_input','reactor_thermal')),
    status            VARCHAR NOT NULL
                      CHECK (status IN ('flown','ground_tested','reference_concept')),
    first_flight_year INTEGER CHECK (first_flight_year IS NULL
                                     OR (first_flight_year BETWEEN 1960 AND 2100)),
    source_id         VARCHAR NOT NULL REFERENCES sources(source_id),
    -- semicolon-free list of columns computed for self-consistency rather than quoted
    derived_fields    VARCHAR,
    notes             VARCHAR
);

-- ---------------------------------------------------------------- results
-- Written by both the Scala pipeline and the Julia models; `producer` tells them apart.

CREATE TABLE results (
    run_id                  VARCHAR NOT NULL,
    run_ts                  TIMESTAMP NOT NULL,
    producer                VARCHAR NOT NULL CHECK (producer IN ('scala','julia')),
    mission_id              VARCHAR NOT NULL REFERENCES missions(mission_id),
    thruster_id             VARCHAR NOT NULL REFERENCES thrusters(thruster_id),
    n_thrusters             INTEGER CHECK (n_thrusters IS NULL OR n_thrusters >= 1),
    exhaust_velocity_m_s    DOUBLE,
    mass_ratio              DOUBLE,
    propellant_mass_fraction DOUBLE,
    propellant_mass_kg      DOUBLE,
    initial_mass_kg         DOUBLE,
    power_plant_mass_kg     DOUBLE,
    thrust_total_N          DOUBLE,
    power_total_W           DOUBLE,
    trip_time_days          DOUBLE,
    meets_time_constraint   BOOLEAN,
    feasible                BOOLEAN,
    alpha_kg_per_kW         DOUBLE,
    notes                   VARCHAR,
    PRIMARY KEY (run_id, mission_id, thruster_id)
);

-- ------------------------------------------------------------------ load

COPY sources     FROM 'data/raw/sources.csv'     (FORMAT CSV, HEADER, NULLSTR '');
COPY propellants FROM 'data/raw/propellants.csv' (FORMAT CSV, HEADER, NULLSTR '');
COPY missions    FROM 'data/raw/missions.csv'    (FORMAT CSV, HEADER, NULLSTR '');
COPY thrusters   FROM 'data/raw/thrusters.csv'   (FORMAT CSV, HEADER, NULLSTR '');

-- ------------------------------------------------------------------ views

-- Rows carrying everything a power-limited electric comparison needs.
CREATE OR REPLACE VIEW v_electric_thrusters AS
SELECT *
FROM thrusters
WHERE power_basis = 'electrical_input'
  AND thrust_mN IS NOT NULL
  AND isp_s IS NOT NULL
  AND input_power_W IS NOT NULL
  AND efficiency IS NOT NULL;

-- Internal consistency of the quoted (thrust, Isp, power, efficiency) quadruple.
-- For an electric thruster, P = T * g0 * Isp / (2 * eta) exactly. Published tables round,
-- and some mix anode efficiency with total efficiency or PPU input with thruster input,
-- so a non-zero residual is expected; a large one means the row should not be trusted.
CREATE OR REPLACE VIEW v_thruster_consistency AS
SELECT
    thruster_id,
    name,
    thruster_type,
    efficiency                                         AS efficiency_quoted,
    (thrust_mN / 1000.0) * 9.80665 * isp_s
        / (2.0 * input_power_W)                        AS efficiency_derived,
    (thrust_mN / 1000.0) * 9.80665 * isp_s
        / (2.0 * input_power_W) - efficiency           AS efficiency_residual,
    abs((thrust_mN / 1000.0) * 9.80665 * isp_s
        / (2.0 * input_power_W) - efficiency)          AS efficiency_abs_residual,
    derived_fields,
    source_id
FROM v_electric_thrusters;
