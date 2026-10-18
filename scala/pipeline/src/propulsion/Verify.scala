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


    println("tank mass model")

    // Calibration anchor: xenon at 150 bar, 1600 kg/m3 should land near 5 percent.
    check("xenon tank fraction is near the flown 5 percent") {
      val f = Physics.tankMassFraction(1600.0, 150.0)
      f > 0.04 && f < 0.07
    }

    check("krypton pays more than twice xenon's tank fraction") {
      val fXe = Physics.tankMassFraction(1600.0, 150.0)
      val fKr = Physics.tankMassFraction(650.0, 200.0)
      fKr > fXe && fKr / fXe > 2.5
    }

    // Lean: tankMassFraction_lt_of_density_lt.
    check("tank fraction strictly decreases with storage density") {
      val ds = Seq(400.0, 650.0, 1000.0, 1600.0, 4933.0)
      ds.map(Physics.tankMassFraction(_, 150.0)).sliding(2).forall {
        case Seq(a, b) => b < a
        case _         => true
      }
    }

    // Lean: tankMassFraction_lt_of_pressure_lt.
    check("tank fraction strictly increases with storage pressure") {
      val ps = Seq(0.0, 50.0, 150.0, 300.0)
      ps.map(Physics.tankMassFraction(1000.0, _)).sliding(2).forall {
        case Seq(a, b) => b > a
        case _         => true
      }
    }

    check("an unpressurised dense solid still gets a structural floor") {
      Physics.tankMassFraction(4933.0, 0.0) > 0.0
    }

    // Lean: inertMassWithTank_zero.
    check("no tank gives back the base inert mass") {
      Physics.inertMassWithTank(1000.0, 1.5, 0.0).contains(1000.0)
    }

    // Lean: inertMassWithTank_fixed_point.
    check("inert mass solves m_f = base + f * m_f * (MR - 1)") {
      val base = 1000.0
      val mr = 1.5
      Seq(0.0, 0.05, 0.176, 0.5).forall { f =>
        Physics.inertMassWithTank(base, mr, f).exists { mf =>
          close(mf, base + f * (mf * (mr - 1.0)))
        }
      }
    }

    // Lean: inertMassWithTank_lt_of_tankFraction_lt and le_inertMassWithTank.
    check("inert mass rises with tank fraction and never falls below the base") {
      val base = 1000.0
      val mr = 1.5
      val ms = Seq(0.0, 0.1, 0.2, 0.4).map(Physics.inertMassWithTank(base, mr, _))
      ms.forall(_.isDefined) &&
      ms.flatten.sliding(2).forall { case Seq(a, b) => b > a; case _ => true } &&
      ms.flatten.forall(_ >= base)
    }

    // Lean: the tankCloses hypothesis.
    check("no finite vehicle closes once f times (MR-1) reaches 1") {
      Physics.inertMassWithTank(1000.0, 3.0, 0.5).isEmpty &&
      Physics.inertMassWithTank(1000.0, 3.0, 0.6).isEmpty &&
      Physics.inertMassWithTank(1000.0, 3.0, 0.49).isDefined
    }

    // Lean: tankCloses_iff_lt_max.
    check("a vehicle closes exactly below the tank fraction limit") {
      Seq(1.5, 2.2, 5.5, 6.46).forall { mr =>
        val fmax = Physics.maxTankFraction(mr)
        Physics.inertMassWithTank(1000.0, mr, fmax * 0.99).isDefined &&
        Physics.inertMassWithTank(1000.0, mr, fmax * 1.01).isEmpty
      }
    }

    // Lean: tankCloses_bound_antitone.
    check("a larger mass ratio tolerates a smaller tank fraction") {
      Seq(1.5, 2.5, 4.0, 6.5).map(Physics.maxTankFraction).sliding(2).forall {
        case Seq(a, b) => b < a
        case _         => true
      }
    }

    check("no propellant means tankage is unconstrained") {
      Physics.maxTankFraction(1.0).isPosInfinity && Physics.maxTankFraction(0.5).isPosInfinity
    }

    check("critical structural floor inverts the tank relation") {
      val (rho, pBar) = (70.85, 1.0)
      Seq(2.21, 5.47, 6.46).forall { mr =>
        val kcrit = Physics.criticalStructuralFloor(rho, pBar, mr)
        val fAtCrit =
          1.5 * pBar * 1.0e5 / (rho * Physics.tankSpecificStrengthJPerKg) + kcrit / rho
        close(fAtCrit, Physics.maxTankFraction(mr), 1e-12)
      }
    }

    // Hydrogen's tank is floor-dominated, xenon's pressure-dominated. This is why the wall
    // strength sweep moves the electric cases and barely touches nuclear thermal.
    check("hydrogen tankage is dominated by the structural floor") {
      val pressure = 1.5 * 1.0e5 / (70.85 * Physics.tankSpecificStrengthJPerKg)
      val floor = Physics.tankStructuralFloorKgPerM3 / 70.85
      floor > 10 * pressure
    }

    check("xenon tankage is dominated by pressure") {
      val pressure = 1.5 * 150.0e5 / (1600.0 * Physics.tankSpecificStrengthJPerKg)
      val floor = Physics.tankStructuralFloorKgPerM3 / 1600.0
      pressure > 5 * floor
    }

    check("the fast-Mars nuclear thermal case sits under twice the assumed floor") {
      val kcrit = Physics.criticalStructuralFloor(70.85, 1.0, 6.458)
      kcrit > Physics.tankStructuralFloorKgPerM3 &&
      kcrit < 2 * Physics.tankStructuralFloorKgPerM3
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


      // The tightest case in the study, driven from the dataset rather than a literal Isp
      // list so a new nuclear thermal row cannot slip past. Mirrors the Julia testset.
      check("high-energy probe: every nuclear thermal row falls below the assumed floor") {
        val ntp = thrusters.filter(t =>
          t.thrusterType == ThrusterType.NuclearThermal && t.ispS.isDefined)
        val mission = missions.find(_.missionId == "probe500_aggressive").get
        val fH2 = Physics.tankMassFraction(70.85, 1.0)
        val margins = ntp.map { t =>
          val mr = Physics.massRatio(mission.deltaVMS, Physics.exhaustVelocity(t.ispS.get))
          val kcrit = Physics.criticalStructuralFloor(70.85, 1.0, mr)
          val closes = Physics.inertMassWithTank(mission.payloadMassKg + t.massKg.getOrElse(0.0),
                                                 mr, fH2).isDefined
          (kcrit, closes)
        }
        ntp.size >= 4 &&
        margins.forall { case (k, closes) => k < Physics.tankStructuralFloorKgPerM3 && !closes } &&
        {
          val best = margins.map(_._1).max / Physics.tankStructuralFloorKgPerM3
          best > 0.9 && best < 1.0
        }
      }

      check("validation reports no errors") {
        Validation.run(conn).count(_.severity == Severity.Error) == 0
      }

      val results = Comparison.runAll(missions, thrusters, propellants, "verify", "scala")

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
        val fr = Comparison.tankFractions(propellants)
        val lo = Comparison.compare(m, thrusters.find(_.thrusterId == "spt100").get, "v", "scala", fr("xenon")).get
        val hi = Comparison.compare(m, thrusters.find(_.thrusterId == "next_pm1").get, "v", "scala", fr("xenon")).get
        hi.propellantMassFraction.get < lo.propellantMassFraction.get
      }
    }

    println()
    println(s"$passed passed, $failed failed")
    if failed > 0 then sys.exit(1)
