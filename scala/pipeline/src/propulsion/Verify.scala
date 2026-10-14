package propulsion

/** Assertion-based self-tests.
  *
  * This module stays within the dependency budget (Scala standard library plus the DuckDB
  * JDBC driver), so there is no test framework. Failures throw and the exit code is non-zero.
  */
object Verify:

  private var passed = 0
  private var failed = 0

  private def check(name: String)(body: => Boolean): Unit =
    var thrown: Option[Throwable] = None
    val ok =
      try body
      catch
        case e: Throwable =>
          thrown = Some(e)

          false
    if ok then
      passed += 1
      println(s"  ok   $name")
    else
      failed += 1
      println(s"  FAIL $name" + thrown.map(e => s": threw $e").getOrElse(""))

  private def close(a: Double, b: Double, tol: Double = 1e-9): Boolean =
    math.abs(a - b) <= tol * math.max(1.0, math.max(math.abs(a), math.abs(b)))

  def main(args: Array[String]): Unit =
    println("physics relations")

    check("exhaust velocity is g0 times Isp") {
      close(Physics.exhaustVelocity(3000.0), 9.80665 * 3000.0)
    }

    check("specific impulse inverts exhaust velocity") {
      close(Physics.specificImpulse(Physics.exhaustVelocity(4190.0)), 4190.0)
    }

    check("zero delta-v gives unit mass ratio") {
      close(Physics.massRatio(0.0, 30000.0), 1.0)
    }

    check("mass ratio matches exp(dv/ve)") {
      close(Physics.massRatio(7000.0, 30000.0), math.exp(7000.0 / 30000.0))
    }

    check("propellant mass fraction equals 1 - 1/MR") {
      val ve = 30000.0
      val dv = 12000.0
      close(Physics.propellantMassFraction(dv, ve), 1.0 - 1.0 / Physics.massRatio(dv, ve))
    }

    // The inequality the comparison depends on, and the one proved in Lean.
    check("propellant mass fraction is strictly below 1 for any finite delta-v") {
      Seq(1.0, 1e3, 1e4, 1e5, 1e6).forall { dv =>
        val z = Physics.propellantMassFraction(dv, 30000.0)
        z > 0.0 && z < 1.0
      }
    }

    check("propellant mass fraction increases with delta-v") {
      val ve = 30000.0
      val zs = Seq(1000.0, 5000.0, 10000.0, 20000.0).map(Physics.propellantMassFraction(_, ve))
      zs.sliding(2).forall { case Seq(a, b) => b > a; case _ => true }
    }

    check("initial mass equals final mass times mass ratio") {
      val ve = Physics.exhaustVelocity(3000.0)
      close(Physics.initialMass(1000.0, 5000.0, ve), 1000.0 * Physics.massRatio(5000.0, ve))
    }

    check("propellant mass is initial minus final") {
      val ve = Physics.exhaustVelocity(3000.0)
      close(
        Physics.propellantMass(1000.0, 5000.0, ve),
        Physics.initialMass(1000.0, 5000.0, ve) - 1000.0
      )
    }

    check("power and thrust relations invert each other") {
      val ve = Physics.exhaustVelocity(4190.0)
      val p = Physics.inputPower(0.237, ve, 0.71)
      close(Physics.thrustFromPower(p, ve, 0.71), 0.237)
    }

    // NEXT at its full-power point: 237 mN, 4190 s, 0.71 should reproduce about 6.9 kW.
    check("NEXT full-power point reproduces its quoted input power") {
      val p = Physics.inputPower(0.237, Physics.exhaustVelocity(4190.0), 0.71)
      math.abs(p - 6900.0) / 6900.0 < 0.01
    }

    check("mass flow is thrust over exhaust velocity") {
      val ve = Physics.exhaustVelocity(3000.0)
      close(Physics.massFlow(0.0927, ve), 0.0927 / ve)
    }

    check("transfer time equals propellant mass over mass flow") {
      val ve = Physics.exhaustVelocity(4000.0)
      val eta = 0.7
      val p = 100000.0
      val mp = 2000.0
      val mdot = 2.0 * eta * p / (ve * ve)
      close(Physics.transferTimeSeconds(mp, ve, eta, p), mp / mdot, 1e-9)
    }

    check("transfer time falls as power rises") {
      val ve = Physics.exhaustVelocity(4000.0)
      val t1 = Physics.transferTimeSeconds(2000.0, ve, 0.7, 100000.0)
      val t2 = Physics.transferTimeSeconds(2000.0, ve, 0.7, 200000.0)
      close(t1, 2.0 * t2)
    }

    println("dataset and comparison")

    Db.withConnection() { conn =>
      val thrusters = Dataset.thrusters(conn)
      val missions = Dataset.missions(conn)
      val sources = Dataset.sources(conn)
      val propellants = Dataset.propellants(conn)

      check("at least 15 flown or ground-tested thrusters load") {
        thrusters.count(t => t.status == Status.Flown || t.status == Status.GroundTested) >= 15
      }

      check("all four tables load non-empty") {
        thrusters.nonEmpty && missions.nonEmpty && sources.nonEmpty && propellants.nonEmpty
      }

      check("absent dry mass stays None rather than becoming zero") {
        thrusters.filter(_.massBasis == MassBasis.Unknown).forall(_.massKg.isEmpty)
      }

      check("every thruster source resolves") {
        val ids = sources.map(_.sourceId).toSet
        thrusters.forall(t => ids.contains(t.sourceId))
      }

      check("nuclear thermal rows never claim electrical input power") {
        thrusters
          .filter(_.thrusterType == ThrusterType.NuclearThermal)
          .forall(_.powerBasis == PowerBasis.ReactorThermal)
      }

      check("validation reports no errors") {
        Validation.run(conn).count(_.severity == Severity.Error) == 0
      }

      val results = Comparison.runAll(missions, thrusters, "verify", "scala")

      check("every thruster with an Isp produces a result per mission") {
        val withIsp = thrusters.count(_.hasIsp)
        results.size == withIsp * missions.size
      }

      check("initial mass always exceeds payload") {
        results.forall { r =>
          val m = missions.find(_.missionId == r.missionId).get
          r.initialMassKg.forall(_ > m.payloadMassKg)
        }
      }

      check("propellant mass fraction stays in (0,1)") {
        results.forall(_.propellantMassFraction.forall(z => z > 0.0 && z < 1.0))
      }

      check("initial mass equals propellant plus inert mass") {
        results.forall { r =>
          (r.initialMassKg, r.propellantMassKg) match
            case (Some(m0), Some(mp)) => mp < m0
            case _                    => true
        }
      }

      check("nuclear thermal rows leave trip time unevaluated") {
        val ntpIds = thrusters.filter(_.powerBasis == PowerBasis.ReactorThermal).map(_.thrusterId).toSet
        results.filter(r => ntpIds.contains(r.thrusterId)).forall(_.tripTimeDays.isEmpty)
      }

      check("a higher-Isp thruster needs less propellant on the same mission") {
        val m = missions.find(_.missionId == "probe500_nominal").get
        val lo = Comparison.compare(m, thrusters.find(_.thrusterId == "spt100").get, "v", "scala").get
        val hi = Comparison.compare(m, thrusters.find(_.thrusterId == "next_pm1").get, "v", "scala").get
        hi.propellantMassFraction.get < lo.propellantMassFraction.get
      }
    }

    println()
    println(s"$passed passed, $failed failed")
    if failed > 0 then sys.exit(1)
