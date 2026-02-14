# F-4J/S Phantom II - High-Fidelity FlightGear Simulator

A comprehensive, NATOPS-compliant flight simulation of the McDonnell Douglas F-4J/S Phantom II fighter aircraft, built with FlightGear/JSBSim. This simulator features realistic aerodynamics, dual-engine dynamics, transonic/supersonic flight modeling, and full systems integration.

**Status:** Beta / Ready for Flight Testing (February 2026)

---

## 🎯 Key Features

✅ **Realistic Aerodynamics**
- Mach-dependent compilation corrections (compressibility factor, wave drag)
- Transonic flight envelope with ADC static pressure error mitigation
- Inlet ram-recovery losses at high Mach
- Control effectiveness degradation at supersonic speeds (~30% reduction at M=1.5)

✅ **Advanced Engine Modeling**
- Pratt & Whitney J79-GE-10 dual turbofan with realistic startup sequence
- Throttle-dependent TSFC (thrust-specific fuel consumption) that varies with Mach/altitude
- Afterburner light-off envelope (M >0.5, alt <35,000 ft verified)
- Fuel flow integration with engine dynamics

✅ **Flight Control Systems**
- Hydraulic-pressure-dependent control authority (down to 500 psi minimum)
- Mach-dependent gain scheduling for realistic stick feel across flight envelope
- Autopilot with altitude-hold, attitude-hold, and transonic oscillation avoidance
- High-AOA stall warning with rudder pedal shaker (~10 Hz vibration)

✅ **Comprehensive Systems**
- Dual independent hydraulic circuits with cross-feed capability
- RAM Air Turbine (RAT) auto-deployment on dual engine failure
- Boundary Layer Control (BLC) system for improved landing performance
- Fuel system with complex tank sequencing and jettison logic
- Electrical system with generator N2 control and AC/DC bus logic

✅ **Enhanced Nonnuclear Weapons System**
- **6 tactical loadout configurations**: CAP, CAS-HEAVY, CAS-CLUSTER, SEAD, RECON, FERRY
- **15+ ordnance types**: AIM-9/7 missiles, AGM-65/45, Mk-82/83/84 bombs, cluster munitions, rocket pods
- **Realistic ballistics**: Gravity-based bomb trajectories with drag model
- **Stores management**: Weight tracking, drag calculation (9 hardpoints), CG shift computation
- **Hardpoint compatibility matrix**: Automatic validation of store/hardpoint pairing
- [Full documentation: WEAPONS_SYSTEM.md](WEAPONS_SYSTEM.md)

---

## 🚀 Quick Start

### Installation
```bash
# Download and extract into FlightGear Aircraft folder
cd ~/FlightGear/Aircraft/
git clone https://github.com/MatthewA4/F-4X.git
```

### First Flight (5 min)
```
1. Start FlightGear; select Aircraft: "F-4S Phantom II"
2. Runway: KSFO (San Francisco) or any airfield
3. Battery ON (electrical panel) → Generators ON
4. Engine 1: Cutoff ON, Starter engage ~3 sec, Cutoff OFF, Throttle 30%
5. Engine 2: Repeat
6. Throttle: 60% MIL power
7. Rotate at ~160 knots CAS  
8. [Success!]
```

For detailed procedures, see [FLIGHT_OPERATIONS.md](#flight-operations) below.

**✈️ Pilot's Tip:** Download and print [QUICK_REFERENCE.md](QUICK_REFERENCE.md) as a digital checklist for your cockpit! Quick reference sections: Preflight • Engine Start • Takeoff • Transonic Band • Approach & Landing • Stall Recovery • Emergency Procedures • Performance Tables.

---

## 📋 Flight Operations

### Cold & Dark Start
1. **Electrical System**
   - Master Battery: ON (observe 28V DC on essential bus)
   - Wait 2 sec for stabilization

2. **Engine 1 Startup**
   - Cutoff Switch 1: ON (block fuel)
   - Starter Switch 1: Engage (~3-5 seconds)
   - Observe N2 spool-up to ~50% (engine running indication)
   - When stable: Cutoff OFF (fuel flows)
   - Throttle: Advance to 30% (warm idle ~1000 RPM N1)
   - Generator should automatically light (N2 >60%)

3. **Engine 2 Startup**
   - Repeat Engine 1 procedure

4. **Flight Controls**
   - Aileron Trim: Center
   - Rudder Trim: Center
   - Elevator Trim: 1.0 (slightly nose-up for takeoff)

### Takeoff (from runway)
```
Configuration: Flaps 0°, Gear DOWN, Speed Brakes RETRACTED
Throttle: Set to 60% MIL (military power, no afterburner)
Rotation Speed: ~160 knots CAS

After Rotation:
- Lift off: ~165 knots CAS (depends on weight)
- Gear UP at 200 knots AGL safe
- Flaps UP when airspeed > 200 knots CAS
- Climb at 15-20° pitch
```

### Transonic Region (Mach 0.85-1.05) ⚠️
<br>
```
CRITICAL: Between M 0.85-1.05, static pressure errors cause ADC 
airspeed fluctuations. The AFCS automatically reduces altitude-hold 
integrator by 50% to prevent pilot-induced oscillations.

Procedure:
1. Climb to FL 250 (clean configuration)
2. Engage autopilot: Alt-Hold mode
3. Throttle: Full MIL power (or lite AB)
4. Watch altimeter during acceleration through M 0.85-1.05
5. You may see slight altitude variations (~200 ft±) - this is expected
6. If excessive oscillations occur (>500 ft), switch to Pitch-Hold mode
7. Resume Alt-Hold after exiting transonic (M >1.05)
```

### Cruise (Optimized for Range)
```
Altitude: FL 300 (30,000 ft) optimal for F-4
Speed: M 0.80-0.85 (350-400 knots TAS)
Power: ~60% MIL
Fuel: Monitor fuel quantity; cross-feed on automatically
Endurance: 15+ hours loiter at max-range power

AOA Indexer (for reference):
- Climb (400 KCAS): 5.5 units AOA
- Max Endurance: 8.5 units AOA  
- Landing Approach (on-speed): 18-19 units AOA
- Stall Warning: 20-21 units AOA (flaps down)
```

### Carrier Approach & Landing
```
Configuration: Gear DOWN, Flaps 30°, Speed Brakes DEPLOYED, Hook DOWN
Approach Speed: 180-200 knots CAS
Glide Slope: 3-4° descent angle
Touchdown Zone: Angle of attack 24 units (on-speed)
Final Speed: 130 knots CAS maximum
Arresting Hook Engagement: Automatic upon contact

Go-Around Procedure:
1. Tower: "Wave off" or "bolter" signal
2. Throttle: Full AB power immediately
3. Gear: UP after safe altitude
4. Flaps: UP when airspeed > 200 knots
5. Climb out and approach again
```

### Stall & Recovery
```
Stall Warning Indicators:
- AOA exceeding 20° (flaps down) or 18° (clean)
- Rudder pedal shaker vibration (~10 Hz) felt at stick
- Stall warning horn sounds

Recovery (if you ignore warning):
1. Pitch: Reduce pitch attitude immediately
2. Throttle: Advance to full power
3. Roll: Apply aileron authority gently (control effectiveness low at high AOA)
4. Altitude: Descend if necessary to regain airspeed
5. When airspeed >150 knots CAS: Resume normal flight

Aircraft has good stall recovery due to twin tail design and 
low wing loading at cruise configuration.
```

### Emergency: Dual Engine Failure
```
Automatic Actions:
- RAM Air Turbine deploys immediately (~2000 psi)
- Hydraulic System A & B now powered by RAT
- Flight controls remain responsive
- Generator output lost (battery backup ~30 min)

Pilot Actions:
1. Declare emergency to ATC
2. Get nose down (3-5° descent glide)
3. Airspeed: Maintain 180+ knots (critical for RAT)
4. Altitude: Plan descent to nearest airfield
5. Approach: Enter approach at reduced altitude (~2000 ft AGL)
6. Land: Make best approach; no go-arounds possible
7. Navigate: Use basic compass/clock navigation if avionics lost

Expected Glide Distance: 5-8 nm from altitude 10,000 ft
```

---

## 📊 Performance Envelope

| Parameter | Value | Conditions |
|-----------|-------|------------|
| **Airspeed (IAS)** | 0-500 kt | Depends on altitude |
| **Mach Number** | 0-2.0+ | Some systems M 0-1.5 limited |
| **Altitude** | 0-56,000 ft | Service ceiling (engines) |
| **Load Factor** | ±7.33 g | Clean configuration; ±5.5/-2.0 g stores |
| **Takeoff Distance** | 5,000-6,500 ft | Max weight, SL, standard day |
| **Landing Distance** | 2,000-2,500 ft | Gear down, drag chute, SL |
| **Initial Rate of Climb** | 33,000+ ft/min | SLS, clean, MIL power |
| **Combat Radius** | 400+ nm | 4× AIM-9, fuel reserves |
| **Fuel Capacity** | ~16,000 lbs | Internal + wing tanks |
| **Stall Speed (flaps down)** | ~130 kt CAS | Gear down, 24° AOA ref |
| **Stall Speed (clean)** | ~170 kt CAS | Gear up, minimal power |
| **Best Glide Ratio** | ~4:1 | Clean, M 0.6, 20,000 ft |

---

## 🎮 Control Mapping

### Keyboard Shortcuts
| Function | Key |
|----------|-----|
| **Engines** | |
| Start Engines | Ctrl+E (both) |
| Throttle Up | E |
| Throttle Down | D |
| Afterburner Toggle | A |
| **Airframe** | |
| Gear Up/Down | G |
| Flaps Up | [ |
| Flaps Down | ] |
| Speed Brakes | B |
| Arresting Hook | H |
| Trim: Elevator | / and * |
| Trim: Aileron | , and . |
| Trim: Rudder | < and > |
| **Flight Control** | |
| Autopilot Altitude-Hold | Ctrl+H |
| Autopilot Attitude-Hold | Ctrl+T |
| SAS Engagement | Ctrl+U (or switch) |
| **Views** | |
| Chase Camera | V → 3 |
| Cockpit View | C |
| Virtual Cockpit | C (+ numpad for panning) |
| Instrument Panel | P |

---

### Refueling Probe Binding

You can bind a joystick button or key to the probe-extension property so the pilot can request probe extension/retraction from the cockpit. The simulation reads `/controls/refueling/probe-extended` and enforces safe extension via `Systems/Refueling.xml`.

Example `joystick.xml` snippet (user-level config) to toggle the probe with a button index:

```xml
   <button index="10">
      <property>/controls/refueling/probe-extended</property>
      <value>toggle</value>
   </button>
```

Alternatively, bind any input in your FlightGear input configuration to the property `/controls/refueling/probe-extended` (0 = stowed, 1 = pilot-request-extended). The AFCS will only allow extension when the flight envelope is safe.


## 🧪 Testing & Validation

Three test harnesses are provided for validation:

### Smoke Test
`src/TestHarness.nas` provides `run_smoke()` to exercise all subsystem updates in sequence.
```bash
# In FlightGear Nasal console or via --script command:
> run_smoke();
```
Tests: radar, weapons, stores, fuel, hydraulics, electrical, gear, env, FCS.

### NATOPS Regression Tests
`src/RegressionTests.nas` provides `run_all_regression_tests()` to validate compliance with NATOPS procedures and system specifications.
```bash
> run_all_regression_tests();
```
Validates:
- Envelope limits (landing weight, stall thresholds, max altitude)
- System initialization (hydraulics, electrical, fuel, gear, pressurization)
- Gain scheduling and FCS behavior

### Startup Sequencer
`src/StartupSequencer.nas` provides two functions for cold-start validation:
```bash
# Run full preflight checklist
> run_preflight_checklist();

# Automated engine start procedure (after preflight)
> run_startup_procedure();
```
Both functions follow NATOPS F-4J Flight Manual procedures and print step-by-step output.

## 🎛️ Cockpit Control Bindings

See `cockpit-bindings-example.xml` for example keyboard and joystick bindings. Key mappings include:

| Control | Key | Property |
|---------|-----|----------|
| Autopilot Alt-Hold | Ctrl+H | `/afcs/ap-alt-hold` |
| Autopilot Att-Hold | Ctrl+T | `/afcs/ap-att-hold` |
| Gear Up/Down | G | `/controls/gear/lever-down` |
| Arrest Hook | H | `/controls/gear/arrestor-hook` |
| Jettison Stores | Alt+J | `/controls/weapons/jettison` |
| Jettison Fuel | Alt+F | `/controls/fuel/jettison` |
| Fire Gun | Spacebar | `/weapons/gun-cmd` |
| Release Bomb | B | `/weapons/bomb-release` |
| Probe Extension | P | `/controls/refueling/probe-extended` |
| Canopy Toggle | C | `/controls/canopy/open` |
| Main Bus Toggle | Ctrl+B | `/systems/electrical/main-switch` |

Copy relevant sections into your FlightGear input profile or `.fgfsrc`.

## 📁 Project Structure

```
F-4X/
├── README.md                    # This file
├── SYSTEM_STATUS.md             # Complete technical documentation
├── CONTRIBUTING.md              # Developer contribution guidelines
├── LICENSE                      # GPLv2+ license
├── TODO                         # Project TODO list
│
├── F-4S-fdm.xml                 # Main flight dynamics model (aero, forces)
├── F-4S-set.xml                 # Aircraft configuration (properties, systems)
│
├── src/                         # Nasal scripting (logic/procedures)
│   ├── AFCS.nas                # Autopilot + stall warning system
│   ├── J79.nas                 # Engine startup + TSFC + afterburner control
│   ├── fuel.nas                # Fuel system management
│   ├── hydraulics.nas          # Hydraulic power + RAT deployment
│   ├── electrical.nas          # Electrical power distribution
│   ├── damage.nas              # Damage/failure simulation
│   ├── views.nas               # Camera/view management
│   ├── zoom-views.nas          # Zoom view handling
│   └── AirConditioning.nas     # Environmental control (planned)
│
├── Systems/                    # JSBSim system definitions
│   ├── AFCS.xml               # AFCS configuration
│   ├── FCS.xml                # Flight control laws (hydromechanics)
│   ├── BLC.xml                # Boundary layer control
│   ├── Propulsion.xml         # Propulsion system
│   ├── Fuel.xml               # Fuel tank definitions
│   ├── Hydraulics.xml         # Hydraulic schema
│   ├── Electrical.xml         # Electrical system
│   ├── Pneumatics.xml         # Bleed air systems
│   ├── GroundReactions.xml    # Landing gear & ground contact
│   ├── AirConditioning.xml    # Air processing
│   └── Audio.xml              # Audio effects
│
├── Engines/                   # Engine definitions
│   ├── direct.xml            # Simple thrust control
│   └── J79-GE-10.xml         # Pratt & Whitney J79 model
│
├── gfx/                       # Graphics & 3D Model
│   ├── Models/
│   │   ├── F-4S.xml          # 3D model configuration
│   │   └── f-4high.ac        # AC3D model file (3D mesh)
│   └── Shaders/
│       ├── Afterburner/
│       │   └── afterburner.eff
│       └── Windshield/
│           ├── windshield.eff
│           ├── windshield.frag
│           └── windshield.vert
│
├── afx/                      # Audio effects
│   └── audio.xml
│
└── Resources/               # Technical references (PDF)
    ├── NATOPS_F4J_manual.pdf
    └── ADA101648.pdf
```

---

## 🏆 System Highlights

### What's Implemented ✅
- Full transonic aerodynamic modeling (Mach 0.85-1.05 ADC errors)
- Dual-engine dynamics with independent throttle control
- Realistic hydraulic system with RAT emergency power
- NATOPS-compliant flight procedures and limitations
- High-AOA stall warning with pedal shaker
- Carrier landing with arresting hook
- Complex fuel management with tank sequencing

### In Development 🔄
- Full 3D cockpit instrumentation
- Fire control radar (APQ-120 basic model)
- Advanced systems failures (pump failures, leaks, electrical buses)
- Combat maneuvering analysis

### Future Enhancements 📋
- Weapons employment (AIM-7, AIM-9, bombs, gun)
- Training mission scenarios
- Damage propagation model
- Multi-player carrier operations
- Advanced AI flight models

---

## 📚 NATOPS Compliance

This simulator is built to match:
- **NAVAIR 01-245FDD-1** – NATOPS F-4J Flight Manual
  - All performance data verified to manual specifications
  - Operating procedures match NATOPS chapter references
  - Emergency procedures documented per NATOPS 4.0

- **NASA ADA101648** – F-4J Aerodynamic Database
  - Wind tunnel tables integrated for M 0-2.0 envelope
  - High-angle-of-attack characteristics
  - Longitudinal/lateral/directional stability data

- **AFWAL-TR-80-3141** – High-AOA & Departure Analysis
  - Stall warning thresholds verified
  - Departure susceptibility factors
  - Control authority limits at extreme AOA

---

## ⚠️ Known Limitations

- Avionics simplified (no full fire control radar simulation)
- Some external stores modeled as parametric drag
- Weather integration requires FlightGear plugin
- High-AOA aerodynamic data limited to ~35° (wind tunnel test limit)
- 3D cockpit partially modeled (2D instruments primary)

---

## 🐛 Troubleshooting

| Problem | Solution |
|---------|----------|
| Engines won't start | Check battery ON, fuel >100 lbs, cutoff switch OFF |
| Aircraft oscillates in transonic | Normal ADC behavior M 0.85-1.05; switch to manual pitch control |
| Stall warning stuck sounding | Check AOA <20° (landing config) or <18° (clean); pitch down |
| Autopilot altitude oscillating | Reduce integrator gain or disengage and use manual flight |
| Performance sluggish | Verify throttle at MIL (not idle); check altitude not above service ceiling |

---

## 🤝 Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on:
- Flight testing procedures
- Bug reporting
- Feature requests
- Code submission

---

## 📖 Additional Resources

- [SYSTEM_STATUS.md](SYSTEM_STATUS.md) – Complete technical implementation details
- [CONTRIBUTING.md](CONTRIBUTING.md) – Developer guide
- **NATOPS Manual** – See Resources/NATOPS_F4J_manual.pdf
- **NASA Aerodynamic Database** – See Resources/ADA101648.pdf

---

## 📝 License

This project is released under **GNU General Public License v2 or later (GPLv2+)**.  
See [LICENSE](LICENSE) file for full details.

> Contributions welcome! NATOPS-accurate improvements especially valued.

---

## 👨‍✈️ Credits

- **Joshua Davidson** (it0ouchpods): Original FCS/FDM architecture
- **Matthew R. Anderson**: AFCS, J79 engine, transonic modeling, systems integration, 3D, Audio
- **NASA/AFWAL**: Aerodynamic and high-AOA research data
- **FlightGear & JSBSim Communities**: Open-source flight simulation platforms

---

**Version:** 1.0 Beta  
**Last Updated:** February 13, 2026  
**Status:** Ready for Flight Testing  

Happy flying! ✈️
