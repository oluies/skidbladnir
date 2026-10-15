package propulsion

import java.time.Instant
import java.util.Locale

object Main:

  private val producer = "scala"

  def main(args: Array[String]): Unit =
    val command = args.headOption.getOrElse("validate")
    command match
      case "validate" => sys.exit(validate())
      case "compare"  => sys.exit(compare())
      case "report"   => sys.exit(report())
      case other =>
        Console.err.println(s"unknown command '$other'; expected validate, compare or report")
        sys.exit(2)

  /** Run the SQL checks. Exit code 1 if any Error-severity rule is violated. */
  def validate(): Int =
    Db.withConnection() { conn =>
      val violations = Validation.run(conn)
      print(Validation.report(violations))
      if violations.exists(_.severity == Severity.Error) then 1 else 0
    }

  /** Validate, run the comparison, write the results table. */
  def compare(): Int =
    Db.withConnection() { conn =>
      val violations = Validation.run(conn)
      print(Validation.report(violations))
      if violations.exists(_.severity == Severity.Error) then
        Console.err.println("refusing to run the comparison while validation errors stand")
        1
      else
        val missions = Dataset.missions(conn)
        val thrusters = Dataset.thrusters(conn)
        val runId = s"scala-${Instant.now().toString}"
        val propellants = Dataset.propellants(conn)
        val results = Comparison.runAll(missions, thrusters, propellants, runId, producer)
        val written = ResultsWriter.write(conn, producer, results)
        println(
          s"comparison: ${missions.size} missions x ${thrusters.size} thrusters " +
            s"-> $written rows written as producer '$producer' (run_id $runId)"
        )
        println(s"  feasible combinations: ${results.count(_.feasible)} of ${results.size}")
        0
    }

  private def fmtDouble(v: Option[Double], width: Int, decimals: Int): String =
    v match
      case Some(d) => ("%" + width + "." + decimals + "f").formatLocal(Locale.ROOT, d)
      case None    => " ".repeat(math.max(0, width - 1)) + "-"

  private def fmtInt(v: Option[Int], width: Int): String =
    v match
      case Some(n) => ("%" + width + "d").formatLocal(Locale.ROOT, n)
      case None    => " ".repeat(math.max(0, width - 1)) + "-"

  /** Print the ranking the findings document is built from. */
  def report(): Int =
    Db.withConnection() { conn =>
      val rows = Db.query(
        conn,
        s"""SELECT m.name AS mission, m.mission_id AS mission_id, t.name AS thruster,
                   t.thruster_type AS ttype, t.propellant AS propellant,
                   r.initial_mass_kg, r.propellant_mass_kg, r.trip_time_days, r.n_thrusters
            FROM results r
            JOIN missions m ON m.mission_id = r.mission_id
            JOIN thrusters t ON t.thruster_id = r.thruster_id
            WHERE r.producer = '$producer' AND r.feasible
            ORDER BY m.mission_id, r.initial_mass_kg"""
      ) { rs =>
        (
          Db.str(rs, "mission"),
          Db.str(rs, "thruster"),
          Db.str(rs, "ttype"),
          Db.str(rs, "propellant"),
          Db.optDouble(rs, "initial_mass_kg"),
          Db.optDouble(rs, "propellant_mass_kg"),
          Db.optDouble(rs, "trip_time_days"),
          Db.optInt(rs, "n_thrusters")
        )
      }
      if rows.isEmpty then
        println("no results; run 'compare' first")
        1
      else
        val header = "%-28s %-15s %-9s %14s %14s %10s %6s"
          .format("thruster", "type", "propellant", "m0 kg", "mp kg", "days", "N")
        var currentMission = ""
        for (mission, thruster, ttype, prop, m0, mp, days, n) <- rows do
          if mission != currentMission then
            currentMission = mission
            println()
            println(mission)
            println("  " + header)
            println("  " + "-" * header.length)
          println(
            "  " + "%-28s %-15s %-9s %s %s %s %s".format(
              thruster,
              ttype,
              prop,
              fmtDouble(m0, 14, 0),
              fmtDouble(mp, 14, 0),
              fmtDouble(days, 10, 1),
              fmtInt(n, 6)
            )
          )
        println()
        0
    }
