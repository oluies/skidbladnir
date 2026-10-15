# Survey of candidate propulsion systems

This document surveys the propulsion classes in scope for the project: electric propulsion
(gridded ion, Hall-effect, magnetoplasmadynamic), nuclear thermal propulsion, nuclear electric
propulsion, and the propellant alternatives that bear on all of them. The two reference missions
are a crewed Mars transfer and a 500 kg deep-space probe.

Every numeric claim carries a source tag of the form `[S01]`. The tags are the primary keys of the
`sources` table in `data/propulsion.duckdb` and of `data/raw/sources.csv`, so a number quoted here
can be traced to the same row the comparison pipeline reads. Full citations are at the end of this
file.

A note on what is recorded. Where a source gives a quantity, it is recorded. Where it does not,
the field is left empty in the CSV rather than filled with an estimate. Thruster dry mass is the
field most often missing, and that gap is carried through to `docs/findings.md` as one of the
unknowns that further work would resolve.

## Gridded ion thrusters

Gridded ion thrusters ionise a gas and accelerate the ions electrostatically through a pair or
triple of apertured grids. Because acceleration is decoupled from ionisation, exhaust velocity is
set by grid voltage and can be pushed high. The class has the highest demonstrated specific impulse
of any flown electric thruster and the lowest thrust density.

The flight record is long. The 13-cm XIPS thruster flew on Hughes PAS-5 in 1997 and produced
17.2 mN at 421 W, 2507 s and 50.0% total efficiency [S01]. Its 25-cm successor flew on the
Boeing 702 bus from 1999, running 80 mN at 2.0 kW and 3420 s for station keeping and 166 mN at
4.3 kW and 3550 s for orbit raising, at 67% and 68.8% total efficiency [S01]. NASA's NSTAR engine
flew on Deep Space 1 in 1998; at its highest throttle level it drew 2325 W at the engine and
produced 92.7 mN at 3127 s and 61.8% efficiency [S01]. NSTAR accumulated over 16,000 hours in
space, and the JPL Extended Life Test ran 30,252 hours across several throttle levels and was
stopped with the engine still running [S01]. The engine's design and flight behaviour are reviewed
in detail by Brophy [S03].

European and Japanese thrusters fill out the flown set. The 10-cm T5 Kaufman thruster, flown on
Artemis in 2001, gives 18 mN at 476 W, 3200 s and 55% efficiency [S01]. The RIT-10 radio-frequency
thruster, also on Artemis, gives 15 mN at 459 W, 3400 s and 52% [S01][S24]. Both were pressed into
an unplanned orbit-raising role after the launcher upper stage left Artemis in a 31,000 km parking
orbit, and they raised the spacecraft to geosynchronous orbit [S01]. JAXA's 10-cm microwave
discharge thruster on Hayabusa produced 8.1 mN at 3090 s and 36% efficiency [S01][S23]. The lower
efficiency is the price of the electrodeless ECR discharge, which removes the discharge cathode as
a life-limiting item.

Two thrusters define the current high end. NEXT, at 36 cm beam diameter, throttles from 0.54 to
6.9 kW; at full power the prototype model produced 237 mN at 4190 s and 0.71 thrust efficiency,
with peak specific impulse of 4310 s reached at an intermediate 4.0 kW [S02]. The beam extraction
area is 1.6 times that of NSTAR, which is what lets it take the higher power without raising
voltages or current densities [S02]. QinetiQ's 22-cm T6, baselined for BepiColombo, produced 143 mN
at 4120 s and 64% efficiency at 4.5 kW, improving to 4300 s and nearly 66% once the neutraliser was
optimised for lower flow [S26]. The T6 operating envelope spans 30 to 230 mN, and it is qualified
on BepiColombo for 75 to 145 mN [S26].

Beyond the flown set, two 20-to-40 kW engines were built and tested for nuclear electric missions
and then shelved. HiPEP reached 9620 s at 39.3 kW on 7.0 mg/s of xenon, and at 24.4 kW produced
460 mN at 8270 s; efficiency exceeded 72% between 6000 s and 10,000 s and passed 75% at peak power
[S04]. NEXIS, a 20-to-25 kW class engine with carbon-carbon grids, reached the highest efficiency of
any xenon ion thruster built, above 81% [S01][S05]. Both ended with the cancellation of the Jupiter
Icy Moons Orbiter in 2005 [S04].

### Open problems

Grid erosion sets life, and life is established by test rather than by model. The NSTAR and NEXT
life demonstrations each cost tens of thousands of test hours, and there is still no predictive
erosion model accurate enough to substitute for a wear test when a new grid geometry or propellant
is introduced. For a Mars-class vehicle this matters twice over, because the required throughput per
thruster is far above anything demonstrated.

Facility effects contaminate the measured numbers. Background pressure in ground chambers produces
charge-exchange ions that inflate measured thrust and depress apparent erosion, and the magnitude of
the correction is disputed. The high-specific-impulse data in particular come from a small number of
facilities.

Carbon-carbon and pyrolytic graphite grids promise the erosion margin that a multi-year mission
needs, but no carbon grid set has flown. NEXIS demonstrated them on the ground [S05] and the
programme stopped there.

Scaling to the power a crewed vehicle needs is an arithmetic problem with no good answer. At 237 mN
per 6.9 kW unit [S02], a megawatt-class vehicle implies on the order of 150 thrusters, with the
attendant mass, gimbal count, and failure modes.

## Hall-effect thrusters

Hall thrusters trap electrons in a crossed electric and magnetic field in an annular channel and
accelerate ions through the resulting potential drop. There are no grids, so the space-charge limit
that caps gridded-ion thrust density does not apply, and thrust per unit area is roughly an order of
magnitude higher. Specific impulse is correspondingly lower, typically 1500 to 3000 s [S10].

The Russian SPT line is the most flown. Across the family, the SPT-50 gives 20 mN at 350 W and
1100 s at 35% efficiency; the SPT-70, 40 mN at 700 W and 1500 s at 45%; the SPT-100, 80 mN at
1350 W and 1600 s at 50%; and the SPT-140, 300 mN at 5000 W and 1750 s above 55% [S01]. The
SPT-100 is quoted elsewhere at 82 mN and 1600 s at a 300 V, 4.5 A discharge, with 50% total
efficiency averaged over thruster life [S01]. SNECMA's PPS-1350-G, derived from the SPT-100, flew
as primary propulsion on SMART-1 in 2003; nominal performance at 1.5 kW is 88 mN at 1650 s and 55%
efficiency, and in flight it was throttled from 462 to 1190 W, accumulating about 5000 hours and
processing 82 kg of xenon [S01].

The SPT-140 is the Psyche thruster. Qualification-model testing covered the 0.9 to 4.5 kW range
required by the mission, with xenon flow from about 5 to 16 mg/s [S09]. Psyche is the first
deep-space use of Hall thrusters as primary propulsion.

Magnetic shielding changed the life picture. By shaping the field so that channel walls sit at
near-anode potential, wall erosion is suppressed to the point where it stops being the life-limiting
mechanism. HERMeS, developed jointly by NASA Glenn and JPL, applies this at 12.5 kW with a design
life of 50 kh at specific impulse up to 3000 s [S07]. Its production version, AEPS, is the
highest-power electric thruster in production: about 600 mN and specific impulse above 2600 s at
600 V input, at power up to 12.5 kW [S06]. AEPS is baselined for the Power and Propulsion Element
of Gateway [S06].

The power ceiling has been probed. The X3 nested-channel thruster, three concentric channels built
at the University of Michigan with AFRL and NASA Glenn, ran at NASA Glenn to 102 kW total power and
247 A discharge current [S08]. Peak thrust was 5.4 ± 0.1 N at 99 kW and 400 V, with total efficiency
from 0.54 to 0.67 ± 0.03 and specific impulse from 1800 to 2650 ± 60 s across the tested envelope
[S08]. The test matrix covered 46 conditions from 5 to 102 kW in all seven channel combinations
[S08].

### Open problems

Channel erosion is solved on paper and unproven in flight at the relevant durations. The 50 kh
design life of a magnetically shielded thruster [S07] is longer than any Hall thruster wear test
completed, and the pole-piece erosion that replaces channel erosion as the leading mechanism is not
yet characterised to the same depth.

Discharge oscillations, in particular the breathing mode, are a first-order feature of Hall thruster
operation and are still not predicted from first principles. This blocks design-by-simulation and
forces a test-heavy development path for every new size and propellant.

Cathode life and erosion at high current is the weak link in high-power units. The X3 drew 247 A
[S08]; cathodes at that current are a research item, not a product.

Nested-channel architecture adds failure modes that single-channel experience does not cover:
channel-to-channel coupling, shared cathode operation, and thermal interaction between channels.

## Magnetoplasmadynamic and high-power plasma thrusters

MPD thrusters accelerate a plasma by the Lorentz force arising from a discharge current and a
magnetic field, which may be self-induced or externally applied. They are the only electric class
with a credible path to newton-level thrust from a single unit, which is why they appear in crewed
Mars studies at all.

Applied-field MPD thrusters with lithium propellant have the best demonstrated numbers. Lithium's
low ionisation potential cuts frozen-flow losses, and lithium AF-MPD thrusters typically run at low
voltage in the 250 to 500 kW range with moderate specific impulse of 3500 to 4000 s [S13]. The
Moscow Aviation Institute 200 kW lithium thruster is the only device in that power range with
performance data that a recent review considers reliable: 185 kW input, 50% efficiency and 4240 s
specific impulse, excluding solenoid and vaporiser power [S13]. The same review records the MAI
series at 42% and 3769 s at 32 kW, and 44% and 3724 s at 150 kW [S13]. At lower power, lithium has
reached 69% efficiency and 5500 s at 21 kW [S13]. Work on lithium MPD thrusters sized for human
Mars missions continues at Princeton [S14].

VASIMR is an adjacent concept: a helicon ion source followed by ion cyclotron resonance heating and
a magnetic nozzle, with specific impulse variable by shifting power between the two stages. The
VX-200 established the performance benchmark at 4900 s and 70% thruster efficiency at 200 kW on
argon, in one-to-two minute pulses with limited cooling [S15]. The VX-200SS addressed duration
rather than peak performance, firing 88 continuous hours at 80 kW on 16 July 2021, with thrust
consistent within ±10% and no long-term trend; the 100-hour target was missed because a faulty
sensor triggered an automatic shutdown at 88.1 hours [S16].

### Open problems

Efficiency at the specific impulse a Mars mission wants is the central problem. The 50% figure at
4240 s [S13] excludes solenoid and vaporiser power, and a system-level efficiency including those
terms has not been reported for any thruster in this class.

Electrode erosion is the life limit and is largely uncharacterised at the hundreds of hours a real
mission needs. Published AF-MPD test durations are short compared with the gridded-ion and Hall
records.

Lithium is condensable. It plates onto spacecraft surfaces, solar arrays, and optics, and the
contamination behaviour at mission scale has not been demonstrated. This interacts with the vehicle
design rather than the thruster alone.

Applied-field MPD performance models are phenomenological. The scaling parameter used to correlate
data across devices is empirical [S13], which means extrapolation from a 200 kW test to a megawatt
system is unsupported.

Magnetic nozzle detachment, the question of how plasma leaves the applied field and whether the
momentum is recovered as thrust, is unresolved and bears directly on VASIMR-class performance
claims.

## Nuclear thermal propulsion

NTP heats hydrogen in a fission reactor and expands it through a nozzle. Specific impulse is set by
the core exit temperature and the propellant molecular weight, and with hydrogen it roughly doubles
the best chemical performance while keeping thrust at the hundreds-of-kilonewtons level. The
thrust-to-weight advantage over electric propulsion is what makes short crewed transfers attractive.

The technology was demonstrated at scale in the 1960s and early 1970s. Project Rover ran from 1955
to 1973 and completed 22 high-power reactor tests across the Kiwi, Phoebus, and Pewee series
[S17]. Pewee reached 503 MWt at 2550 K with average core power density of 2340 MWt/m³ and peak of
5200 MWt/m³, and demonstrated 845 s specific impulse [S17]. Phoebus-2A, the most powerful reactor
ever built, ran above 4000 MWt for twelve minutes; peak thrust was 930 kN, measured specific impulse
was 820 s, and the projected flight value was 825 to 850 s [S17]. These are the high-water marks,
and nothing since has matched them in hardware.

Modern programme activity has been start-stop. The NASEM committee's 2021 assessment set the
reference NTP system at specific impulse of at least 900 s with hydrogen heated to at least 2700 K
[S18]. NASA design studies in the interim examined engine configurations chosen for affordability and
for a shortened path to flight rather than for peak performance [S22]. DRACO, the DARPA and NASA
flight demonstration, was to launch in late 2025 or early 2026
[S25]. It was cancelled; the FY2026 NASA budget request contained no funding for nuclear thermal or
nuclear electric propulsion, with the technical supplement stating that the efforts are costly, take
many years, have not been identified as the propulsion mode for deep space missions, and that
nearer-term alternatives exist for Mars transit [S25].

### Open problems

Fuel survivability at temperature in flowing hydrogen is the oldest and most persistent problem.
Rover-era fuel elements suffered hydrogen corrosion and cracking, and reaching the 900 s target
[S18] requires higher temperature than Pewee's 2550 K [S17] for longer durations than any Rover test
sustained.

Low-enriched uranium is now a programmatic requirement, and the Rover database is entirely
highly-enriched. Moving to LEU changes core size, moderation, and thermal margin, and invalidates
direct use of the historical performance data.

Hydrogen storage over a mission is a separate engineering problem of comparable size; see the
propellant section.

Ground testing is constrained in a way it was not in 1968. Full-power exhaust capture or scrubbing
is required, and no such facility exists, so the test path to flight qualification is undefined.

There is no current programme. With DRACO cancelled and no NTP line in the FY2026 request [S25],
the technology-readiness trajectory that mission studies assume has no funding behind it.

## Nuclear electric propulsion

NEP pairs a fission reactor and power conversion with electric thrusters. It separates the power
source from the propellant, so specific impulse is set by the thruster and is not limited by
material temperature as it is in NTP. The cost is the power system's mass.

The NASEM study is the reference point for the crewed case. For an opposition-class human Mars
mission in the 2039 opportunity, an electric system used in combination with a chemical system
requires between 2 and 6 MWe, with planning work assuming roughly 2 MWe [S18]. The study's NEP
reference has power of at least 1 MWe and a mass-to-power ratio substantially below the state of the
art [S18]. Its central finding on NEP is that a MWe-class system for the baseline mission would
require increasing power by orders of magnitude relative to any NEP flight or ground demonstration
completed to date [S18]. NASA's subsequent narrowing of NEP architecture options is documented in
the IEPC-2022 work [S20].

The demonstrated base is small. KRUSTY, tested in March 2018, was a prototypic nuclear-powered test
of a 5 kWt Kilopower reactor using heat pipes and Stirling conversion, aimed at 1 to 10 kWe space
and surface power [S19]. It was started on 20 March 2018 and ran 28 continuous hours [S19], the
first nuclear-powered operation of a genuinely new reactor concept in the United States in over
forty years [S19]. The gap between 1 kWe demonstrated and 1 to 2 MWe required is three orders of
magnitude, which is the NASEM finding restated in hardware terms.

### Open problems

Specific mass, the kilograms of power system per kilowatt of electrical output, is the quantity that
decides whether NEP closes. It sets trip time through the power-limited transfer relation, and no
megawatt-class system has been built to measure it against. Every published crewed NEP trip time
rests on an assumed value.

Heat rejection dominates the mass at megawatt scale. Radiator area scales with rejected power and
inversely with the fourth power of radiator temperature, so the whole architecture turns on
conversion efficiency and radiator temperature, both of which are assumptions rather than
measurements at this scale.

Power conversion at megawatt scale in space has no demonstration. Stirling conversion is proven at
kilowatt scale [S19]; Brayton at megawatt scale in a reactor loop is not.

Thruster count and power processing follow from the same gap. A 2 MWe bus feeding 12.5 kW AEPS units
[S06] implies well over a hundred thrusters and their power processing units.

As with NTP, the FY2026 budget request terminates NEP project funding [S25].

## Propellant alternatives

Xenon is the reference propellant for both gridded-ion and Hall thrusters, and essentially all of
the flight data cited above is xenon [S01]. It is easy to ionise, stores as a high-density
supercritical fluid at moderate pressure, and is chemically inert. It is also scarce and expensive,
produced as a by-product of air separation in quantities that constellation-scale electric
propulsion can visibly move.

Krypton is the first substitution. It is cheaper and more abundant, and its lower atomic mass
gives it a theoretical specific impulse about 25% above xenon at the same discharge potential
[S12]. The measured picture is worse than the theory, and the dataset now carries three
measured krypton operating points, two of them with a xenon control taken on the same thruster
in the same campaign, so the penalty can be read off directly rather than taken as a range.
The third, the SPT-100 at 393 V, comes from the separate life-test paper [S31] and has no
condition-matched xenon run.

| thruster | propellant | power W | Isp s | total efficiency | thrust mN |
|---|---|---|---|---|---|
| SPT-100, nominal 302 V [S30] | krypton | 1356 | 1568 | 0.360 | 63.5 |
| SPT-100, nominal 302 V [S30] | xenon | 1351 | 1511 | 0.440 | 80.2 |
| SPT-100, 393 V [S31] | krypton | 1977 | 1966 | 0.423 | 86.7 |
| BHT-1500-C, 400 V [S12] | krypton | 1900 | 2160 | 0.474 | 85.0 |
| BHT-1500-C, 400 V [S12] | xenon | 1800 | 1970 | 0.543 | 101.2 |

The SPT-100 nominal pair is the clearest statement of the problem. On the same flight-model
thruster in the same facility, krypton gave 1568 s against 1511 s for xenon, so the 25%
theoretical gain in specific impulse arrived as under 4% [S30]. Total efficiency fell from
0.440 to 0.360, eight points. The thrust figures in the table for that pair are derived from
the measured specific impulse and efficiency; the derived xenon value of 80.2 mN reproduces
the 80 mN flight figure quoted independently in [S01], which is a check on the derivation.
The 393 V SPT-100 row is the one whose thrust, specific impulse and efficiency were all
measured directly, and they agree with each other to within 0.0003 in efficiency [S31].

The BHT-1500-C pair shows what a thruster designed around the propellant can recover.
Krypton raised specific impulse by about 190 s at nearly equivalent discharge power and
potential, and cost 7 to 8 points of efficiency rather than the SPT-100's eight on a much
lower base [S12]. Running the SPT-100 harder helps too: at 393 V krypton reaches 1966 s at
0.423 efficiency [S31], which is most of the BHT-1500-C's specific impulse.

The losses are attributed mainly to propellant utilisation and beam divergence [S12][S32].
Krypton's smaller ionisation cross-section and higher ionisation energy also narrow the
stable operating window; one 300 W-class study found unstable operation below 250 V and
above 450 V anode voltage [S12]. Linnell and Gallimore found a 5 to 15 percentage point
reduction in overall efficiency on the NASA-173Mv1 at 6 to 8 kW [S32]. Storage is a separate
penalty: at 14 MPa and 50 C krypton stores at about one third the density of xenon, so three
times the volume for a given mass, though the gap closes as temperature falls and at -50 C
krypton approaches xenon at 50 C [S12]. The representative densities carried in the
propellants table, 650 against 1600 kg/m3 at 293 K, are milder and give 2.46 times the volume
per kilogram. The 2.2 times quoted in docs/findings.md is a third quantity again: it is the
probe case, where krypton carries 12% less propellant as well, so the two effects partly
cancel. The three figures are at different conditions and on different bases, and none of
them contradicts the others.

Life is less dark than it was. A flight-model SPT-100 ran 205 hours on krypton at 2 kW, 50%
above its nominal power, holding a steady discharge current and beam profile, with boron
nitride channel erosion measured by optical profilometry at 100 and 205 hours [S31]. The
authors could not say whether the thruster would reach the 5860 hours their example
geosynchronous mission needed, and noted that 5860 hours at that krypton condition puts the
same energy through the thruster as 8800 hours of nominal xenon operation, against a
validated xenon capability of about 9000 hours [S31].

Iodine is the most interesting recent change. It is stored as a solid and sublimated at low
temperature, which removes the high-pressure tank entirely and allows severe miniaturisation.
ThrustMe's NPT30-I2 flew on Beihangkongshi-1 and became the first in-orbit demonstration of iodine
electric propulsion, reported in Nature in November 2021 [S11]. The system runs 0.8 mN at 55 W
nominal, generating plasma by radio-frequency electron-impact ionisation and extracting ions
through grids to about 40 km/s, and the demonstration produced a cumulative altitude change above
3 km [S11].

Lithium is the propellant that makes AF-MPD numbers work, for the reasons given in that section
[S13][S14], and it carries the condensation and contamination problem described there.

Hydrogen is the NTP propellant and the reason NTP specific impulse is high, since specific impulse
at a given temperature scales with the inverse square root of molecular weight. Storing it is the
difficulty. Hydrogen must be held as a liquid at 20 K for periods up to 18 months for a Mars
architecture [S21]. One assessment of a nuclear propulsion concept estimated passive boil-off from a
tank carrying 38 tonnes of hydrogen for a three-year mission at about 16 tonnes per year, against
which an active zero-boil-off system would save 42% of propellant mass per year [S21]. The
zero-boil-off approach combines an active cryocooler with passive insulation, and NASA has invested
in 20 K cryocooler technology for hydrogen and 90 K for oxygen and methane [S21].

### Open problems

Krypton's efficiency penalty is now measured on specific thrusters rather than quoted as a
range, but only on three. The SPT-100 loses eight points of total efficiency at its nominal
condition [S30] and the BHT-1500-C loses seven to eight [S12], which is a narrow enough band
to design against; whether it holds at the tens of kilowatts a Mars vehicle needs is
untested, and the one high-power data point in the literature, a 50 kW thruster reported to
reach similar efficiency on krypton and xenon [S31], has no published operating table behind
it here.

Krypton tankage is not characterised in a way a trade study can use. The one-third storage
density figure [S12] is quoted at a single pressure and temperature, and the mass of a tank
sized for the resulting volume is what decides whether krypton's propellant saving survives to
the vehicle level. No source consulted gives a measured tank mass for a krypton system. The
comparison in this project therefore sizes the tank from a thin-walled pressure vessel
relation calibrated against flown xenon tankage, and on that model krypton loses the
comparison it won without one (see docs/findings.md). That is a modelled result, not a
measured one, and a published krypton tank mass would replace it.

Krypton erosion and life remain open. The 205-hour test [S31] is the longest published krypton
run on any thruster, about forty times short of the roughly 9000 hours validated on xenon for
the same hardware and twenty-nine times short of the 5860 hours its authors' own example
mission needed. They could not conclude whether the thruster would survive that mission, and
said plainly that serious use of krypton would require long-duration life testing [S31].

Iodine is chemically aggressive. It attacks many spacecraft materials, and long-duration
compatibility data for grids, cathodes, and external surfaces does not exist at mission timescales.
The flown demonstration was a small total impulse [S11].

Iodine performance at high power is unknown. Everything flown is at the tens-of-watts scale [S11],
and whether the propellant behaves acceptably in a kilowatt-class Hall or gridded thruster is open.

Hydrogen boil-off control is not demonstrated at the tank size and duration a Mars NTP vehicle
needs. The 20 K cryocooler development [S21] has not been flown at the required lift and scale, and
the cryocooler's own power and radiator mass must be charged against the propellant saved.

Lithium feed systems require a vaporiser whose power is often excluded from quoted efficiencies
[S13], so the propellant choice and the efficiency bookkeeping are entangled.

## What this project's comparison can and cannot settle

The comparison implemented in the Scala and Julia pipelines uses the recorded thruster parameters,
the Tsiolkovsky relation, the power-thrust-specific-impulse relation, and a power-limited transfer
model. Those relations are exact, and the Lean development in `lean/` states and proves the ones the
comparison depends on.

What the comparison cannot do is supply the numbers the literature has not measured. Three of these
dominate: power system specific mass at megawatt scale, thruster and power-processing dry mass for
most of the surveyed units, and demonstrated propellant throughput per thruster against the
throughput a Mars-class mission requires. Results in `docs/findings.md` are therefore reported
against explicit assumed values for these, with sensitivity shown rather than a single ranked answer
presented as settled.

## References

- `[S01]` Goebel, D. M., and Katz, I., *Fundamentals of Electric Propulsion: Ion and Hall Thrusters*,
  Chapter 9, "Flight Ion and Hall Thrusters", JPL Space Science and Technology Series, Jet Propulsion
  Laboratory, 2008.
  https://descanso.jpl.nasa.gov/SciTechBook/series1/Goebel_09_Chap9_Flight.pdf
- `[S02]` "Performance Evaluation of the Prototype Model NEXT Ion Thruster", NASA Glenn Research
  Center, NTRS 20080012739.
  https://ntrs.nasa.gov/api/citations/20080012739/downloads/20080012739.pdf
- `[S03]` Brophy, J. R., "NASA's Deep Space 1 Ion Engine", *Review of Scientific Instruments*,
  vol. 73, pp. 1071-1078, 2002.
- `[S04]` "The High Power Electric Propulsion (HiPEP) Ion Thruster", NASA Glenn Research Center,
  NTRS 20040139476.
  https://ntrs.nasa.gov/api/citations/20040139476/downloads/20040139476.pdf
- `[S05]` Polk, J. E., Goebel, D. M., Katz, I., Snyder, J., Schneider, A., Johnson, L., and
  Sengupta, A., "Performance and Wear Test Results for a 20-kW Class Ion Engine with Carbon-Carbon
  Grids", AIAA-2005-4393, 41st Joint Propulsion Conference, Tucson, Arizona, July 2005.
- `[S06]` "12-kW Advanced Electric Propulsion System Hall Current Thruster Qualification and
  Production Status", IEPC-2024, NTRS 20240006249.
  https://ntrs.nasa.gov/api/citations/20240006249/downloads/AEPS%20Status%20IEPC%202024%20v7.pdf
- `[S07]` "Completing the Development of the 12.5 kW Hall Effect Rocket with Magnetic Shielding
  (HERMeS)", IEPC-2019-193, 36th International Electric Propulsion Conference, Vienna, 2019.
  https://electricrocket.org/2019/193.pdf
- `[S08]` "Performance and High-Speed Characterization of a 100-kW Nested Hall Thruster",
  *Journal of Propulsion and Power*, AIAA 10.2514/1.B38080; NTRS 20210013351.
  https://ntrs.nasa.gov/api/citations/20210013351/downloads/2020-04-B38080.R2_Final.pdf
- `[S09]` "Electric Propulsion for the Psyche Mission", IEPC-2019-244, 36th International Electric
  Propulsion Conference, Vienna, 2019.
  https://electricrocket.org/2019/244.pdf
- `[S10]` "Review of High-Power Electrostatic and Electrothermal Electric Propulsion",
  *Journal of Propulsion and Power*, November 2022.
  https://hpepl.ae.gatech.edu/sites/default/files/files/Review%20of%20HP%20ES%20ET%20EP_JPP%20Nov%202022.pdf
- `[S11]` Rafalskyi, D., et al., "In-orbit demonstration of an iodine electric propulsion system",
  *Nature*, vol. 599, November 2021. DOI 10.1038/s41586-021-04015-y.
  https://www.nature.com/articles/s41586-021-04015-y
- `[S12]` Szabo, J., Tedrake, R., Kolencik, G., and Pote, B., "Measurements of a Krypton Fed
  1.5 kW Hall Effect Thruster with a Centrally Located Cathode" (BHT-1500-C), IEPC-2017-26,
  35th International Electric Propulsion Conference, Atlanta, 2017.
  https://electricrocket.org/IEPC/IEPC_2017_26.pdf
- `[S13]` "Applied-Field Magnetoplasmadynamic Thrusters for Deep Space Exploration",
  arXiv:2410.17478. https://arxiv.org/pdf/2410.17478
- `[S14]` Polk, J. E., et al., "Development of High Power Lithium Magnetoplasmadynamic Thrusters for
  Human Mars Missions", IEPC-2024, Electric Propulsion and Plasma Dynamics Laboratory, Princeton
  University. https://alfven.princeton.edu/publications/pdf/polk-iepc-2024.pdf
- `[S15]` "Improved Efficiency and Throttling Range of the VX-200 Magnetoplasma Thruster",
  *Journal of Propulsion and Power*, 2014.
  https://www.adastrarocket.com/technical-papers-archives/Ben-JPP-2014.pdf
- `[S16]` "Steady-State Testing in the VASIMR VX-200SS Project", AIAA ASCEND, 2021.
  https://www.adastrarocket.com/wp-content/uploads/2021/12/2021_AIAA_ASCEND_VASIMR.pdf
- `[S17]` Finseth, J. L., "Rover Nuclear Rocket Engine Program: Overview of Rover Engine Tests,
  Final Report", NASA CR-184270, Sverdrup Technology, Huntsville, Alabama, February 1991.
  NTRS 19920005899. https://ntrs.nasa.gov/citations/19920005899
- `[S18]` National Academies of Sciences, Engineering, and Medicine, *Space Nuclear Propulsion for
  Human Mars Exploration*, The National Academies Press, Washington DC, 2021.
  DOI 10.17226/25977. https://nap.nationalacademies.org/read/25977
- `[S19]` "KRUSTY Reactor Design", *Nuclear Technology*, 2020.
  DOI 10.1080/00295450.2020.1725382; NTRS 20205009350.
  https://ntrs.nasa.gov/api/citations/20205009350/downloads/03-KRUSTY%20Reactor%20Design.pdf
- `[S20]` "Nuclear Electric Propulsion for Human Mars Exploration", IEPC-2022-155,
  NTRS 20220009379.
  https://ntrs.nasa.gov/api/citations/20220009379/downloads/SNP%20NEP%20paper%20-%20IEPC-2022-155%20final.pdf
- `[S21]` "Achieving Zero Boiloff for LH2 Supply Tanks on an NTP Rocket to Mars", AIAA 2026-2384,
  and NASA cryocooler technology development reporting.
  https://arc.aiaa.org/doi/10.2514/6.2026-2384
- `[S22]` "Safe, Affordable, Nuclear Thermal Propulsion Systems", NASA, NTRS 20140010981.
  https://ntrs.nasa.gov/api/citations/20140010981/downloads/20140010981.pdf
- `[S23]` Kuninaka, H., Nishiyama, K., Funaki, I., and Shimizu, Y., "Asteroid Rendezvous of Hayabusa
  Explorer Using Microwave Discharge Ion Engines", IEPC-2005-010, 29th International Electric
  Propulsion Conference, Princeton, New Jersey, 2005.
- `[S24]` Killinger, R., Bassner, H., Leiter, H., and Kukies, R., "RITA Ion Propulsion for Artemis",
  AIAA-2001-3490, 37th Joint Propulsion Conference, Salt Lake City, Utah, July 2001.
- `[S25]` DRACO cancellation and the FY2026 NASA budget request technical supplement, as reported
  June 2025. https://www.neimagazine.com/news/draco-project-cancelled/ and
  https://breakingdefense.com/2025/06/darpas-draco-nuclear-propulsion-project-roars-no-more/
- `[S26]` Hutchins, M., and Simpson, H., "QinetiQ's T6 and T5 Ion Thruster Electric Propulsion
  System Architectures and Performances", International Electric Propulsion Conference; and
  "Performance Evaluation of the T6 Ion Engine", *Journal of Propulsion and Power*.
  https://www.semanticscholar.org/paper/493bfc9382080d253e5a6af5a178e21681d302bf
- `[S30]` Nakles, M. R., Hargus, W. A., Jr., Delgado, J. J., and Corey, R. L., "A Performance
  Comparison of Xenon and Krypton Propellant on an SPT-100 Hall Thruster", IEPC-2011-003,
  32nd International Electric Propulsion Conference, Wiesbaden, 2011.
  https://electricrocket.org/IEPC/IEPC-2011-003.pdf
- `[S31]` Nakles, M. R., Hargus, W. A., Jr., Delgado, J. J., and Corey, R. L., "A 205 Hour
  Krypton Propellant Life Test of the SPT-100 Operating at 2 kW", IEPC-2013-347, 33rd
  International Electric Propulsion Conference, Washington DC, 2013.
  https://electricrocket.org/IEPC/hu4akp90.pdf
- `[S32]` Linnell, J. A., and Gallimore, A. D., "Efficiency Analysis of a Hall Thruster
  Operating with Krypton and Xenon", *Journal of Propulsion and Power*, vol. 22, no. 6,
  pp. 1402-1418, 2006.
