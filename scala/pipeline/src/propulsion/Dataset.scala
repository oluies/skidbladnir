package propulsion

import java.sql.Connection

/** Loads the typed dataset out of DuckDB. */
object Dataset:

  def sources(conn: Connection): Vector[Source] =
    Db.query(conn, "SELECT * FROM sources ORDER BY source_id") { rs =>
      Source(
        sourceId = Db.str(rs, "source_id"),
        citation = Db.str(rs, "citation"),
        venue = Db.optString(rs, "venue"),
        year = Db.optInt(rs, "year"),
        url = Db.optString(rs, "url"),
        sourceKind = Db.str(rs, "source_kind")
      )
    }

  def propellants(conn: Connection): Vector[Propellant] =
    Db.query(conn, "SELECT * FROM propellants ORDER BY propellant") { rs =>
      Propellant(
        propellant = Db.str(rs, "propellant"),
        acceleratedSpecies = Db.optString(rs, "accelerated_species"),
        storedSpecies = Db.optString(rs, "stored_species"),
        molarMassGMol = Db.dbl(rs, "molar_mass_g_mol"),
        firstIonisationEV = Db.optDouble(rs, "first_ionisation_eV"),
        storagePhase = Db.str(rs, "storage_phase"),
        storageDensityKgM3 = Db.optDouble(rs, "storage_density_kg_m3"),
        storagePressureBar = Db.optDouble(rs, "storage_pressure_bar"),
        sourceId = Db.optString(rs, "source_id")
      )
    }

  def thrusters(conn: Connection): Vector[Thruster] =
    Db.query(conn, "SELECT * FROM thrusters ORDER BY thruster_id") { rs =>
      Thruster(
        thrusterId = Db.str(rs, "thruster_id"),
        name = Db.str(rs, "name"),
        thrusterType = ThrusterType.fromDb(Db.str(rs, "thruster_type")),
        propellant = Db.str(rs, "propellant"),
        thrustMN = Db.optDouble(rs, "thrust_mN"),
        ispS = Db.optDouble(rs, "isp_s"),
        inputPowerW = Db.optDouble(rs, "input_power_W"),
        efficiency = Db.optDouble(rs, "efficiency"),
        massKg = Db.optDouble(rs, "mass_kg"),
        massBasis = MassBasis.fromDb(Db.str(rs, "mass_basis")),
        powerBasis = PowerBasis.fromDb(Db.str(rs, "power_basis")),
        status = Status.fromDb(Db.str(rs, "status")),
        firstFlightYear = Db.optInt(rs, "first_flight_year"),
        sourceId = Db.str(rs, "source_id"),
        derivedFields = Db.optString(rs, "derived_fields")
      )
    }

  def missions(conn: Connection): Vector[Mission] =
    Db.query(conn, "SELECT * FROM missions ORDER BY mission_id") { rs =>
      Mission(
        missionId = Db.str(rs, "mission_id"),
        name = Db.str(rs, "name"),
        missionClass = MissionClass.fromDb(Db.str(rs, "mission_class")),
        payloadMassKg = Db.dbl(rs, "payload_mass_kg"),
        deltaVMS = Db.dbl(rs, "delta_v_m_s"),
        maxTripTimeDays = Db.optDouble(rs, "max_trip_time_days"),
        powerAvailableW = Db.optDouble(rs, "power_available_W"),
        powerSource = Db.optString(rs, "power_source")
      )
    }
