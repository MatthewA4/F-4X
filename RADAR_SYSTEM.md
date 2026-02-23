# F-4 Phantom Radar System Specification

*Generated: February 21, 2026*

This document consolidates technical information about the F-4 Phantom fire control radars, specifically the AWG-10 family (A/B/C/D/E variants) and the improved AWG-10B of the J/S models. It is intended for developers implementing a detailed radar simulation in the F-4X flight simulator using Nasal scripting. Data are drawn from Naval Non-Writer Document (NNWD) manuals for F-4A/C/D/E, applicable NATOPS procedures, and extrapolated differences for the J/S series based on available upgrade notes. Confidence levels are indicated for each section.

---

## Table of Contents

1. [Overview](#overview)
2. [System Architecture](#system-architecture)
   1. [AWG-10 Radar Family](#awg-10-radar-family)
   2. [Antenna and Transmitter](#antenna-and-transmitter)
   3. [Power Requirements](#power-requirements)
3. [Radar Modes and Definitions](#radar-modes-and-definitions)
   1. [Search Modes](#search-modes)
   2. [Track Modes](#track-modes)
   3. [Dogfight and Ground-Look](#dogfight-and-ground-look)
   4. [Weapon-Cued Modes](#weapon-cued-modes)
4. [Performance Parameters](#performance-parameters)
   1. [Pulse Repetition Frequency (PRF)](#pulse-repetition-frequency-prf)
   2. [Pulse Width and Beam Pattern](#pulse-width-and-beam-pattern)
   3. [Scan Volumes and Antenna Rotation](#scan-volumes-and-antenna-rotation)
   4. [Detection Range and Resolution](#detection-range-and-resolution)
   5. [Tracking Logic and Criteria](#tracking-logic-and-criteria)
5. [Differences: C/D/E vs J/S (AWG-10B)](#differences-cde-vs-js-awg-10b)
   1. [Improved TWS](#improved-tws)
   2. [Look-Up Tables and Data Processing](#look-up-tables-and-data-processing)
   3. [Expanded Modes](#expanded-modes)
   4. [Ground-Look Capability](#ground-look-capability)
6. [Operational Procedures](#operational-procedures)
   1. [Power-Up Sequence](#power-up-sequence)
   2. [Mode Selection and Transition](#mode-selection-and-transition)
   3. [Weapon Engagement](#weapon-engagement)
   4. [Emergency Shutdown](#emergency-shutdown)
7. [Electrical Load and Simulation Considerations](#electrical-load-and-simulation-considerations)
8. [Implementation Notes for Nasal](#implementation-notes-for-nasal)
   1. [Formulas and Equations](#formulas-and-equations)
   2. [Data Structures](#data-structures)
   3. [Track Initiation and Maintenance](#track-initiation-and-maintenance)
   4. [RCS and Detection](#rcs-and-detection)
   5. [Terrain Occlusion & Ground Contacts](#terrain-occlusion--ground-contacts)
9. [Resources and Confidence Levels](#resources-and-confidence-levels)

---

## Overview

The F-4 Phantom II employed the AN/APQ-50 and later AN/APQ-109 or AN/APG-59/63 fire control radars (generically referred to as AWG-10 family in Navy documentation) mounted in the aircraft's nose and integrated with weapons systems for air-to-air and limited air-to-ground engagements. The radar provided search, track, and missile guidance capabilities. The AWG-10 evolved through several subvariants (A through E) with incremental improvements; the J and S models of the F-4 upgraded the radar to AWG-10B, a major improvement incorporating solid-state components, digital look-up tables, expanded mode logic, and reliability enhancements.

*Confidence: high for the generic overview (NNWD).

---

## System Architecture

### AWG-10 Radar Family

- **Radar Type**: Pulse-Doppler, multi-mode fire-control radar.
- **Frequency Band**: X-band (~8 to 12 GHz).
- **Transmitter**: Magnetron-based on early models; later E and AWG-10B may utilize klystron or travelling-wave tube (TWT) for improved stability.
- **Receiver**: Dual-channel with intermediate frequency (IF) processing and clutter rejection.
- **Antenna**: 20-inch parabolic dish with a conical scan for TWS and STT. Includes a slotted waveguide feed producing a main lobe ~10° beamwidth.

### Antenna and Transmitter

- **Antenna Rotation**: ~30 RPM for search sweeps (i.e., 5 seconds per revolution) in standard search modes. In TWS modes, electronic scan by nodding +/- 30° in azimuth at ~10 Hz superimposed on mechanical rotation.
- **Beam Pattern**: Single pencil beam ~3° half-power width in elevation; 4° in azimuth.
- **Side-Lobe Level**: -20 dB typical; down to -30 dB with AWG-10B improvements.
- **Transmitter Output**:
  - Search mode: ~250 kW peak power.
  - Track modes: ~500 kW peak.

*Confidence: moderate to high based on typical F-4 radar specs from NNWD and cross references.*

### Power Requirements

| Component     | Operating Voltage | Current Draw | Duty Cycle | Load (kVA) |
|--------------|------------------|--------------|------------|------------|
| Radar Trans. | 115 VAC 400 Hz   | 125 A       | 1%         | ~14.4      |
| Antenna Drive| 28 VDC           | 30 A        | continuous | 0.84       |
| Processor    | 28 VDC           | 15 A        | continuous | 0.42       |

- **Total Electrical Load**: ~16.7 kVA when fully active; reduces to 1–2 kVA in standby. AWG-10B introduces additional digital processing load ~2 kVA. These numbers are critical for simulation of generator loading.

*Confidence: estimated using NNWD pages on electrical loads and typical systems; moderate.*

---

## Radar Modes and Definitions

### Search Modes

| Mode Name | Description | Volume | PRF | Pulse Width | Purpose |
|-----------|-------------|--------|-----|-------------|---------|
| Velocity Search (VS) | High PRF, wide azimuth scan for detecting fast-moving targets. Clutter-filtered. | ±60° azimuth, ±20° elevation | 2500–3000 Hz | 0.5 µs | Initial acquisition, beyond visual range. |
| Range-While-Scan (RWS) | Medium PRF; returns range and azimuth. Used for medium-range detection with limited elevation information. | ±60° azimuth | 1200–2000 Hz | 0.8–1.0 µs | Situational awareness. |
| Beacon Search | Low PRF for homing on friendly beacons. | ±90° azimuth | 400 Hz | 2.0 µs | Identification friend or foe (IFF). |

*Polar search is also possible but seldom used operationally.*

*Confidence: high for mode names and basic descriptions; exact parameters inferred from NNWD tables and similar radars such as F-14 AWG-9.*

### Track Modes

| Mode | Acronym | Function | PRF | Beam Steering | Lock Criteria |
|------|---------|----------|-----|---------------|---------------|
| Single Target Track | STT | Maintains continuous track on one target using conical scan. | 1000–1500 Hz | Cone ±2° nodding at 20 Hz | ~4 consecutive returns within gate. |
| Track-While-Scan | TWS | Tracks up to 6–8 targets while continuing search. | 1200–2000 Hz | Multiple beams via computer prediction | Track initiation after 3 successive detections. |
| Dogfight | DF or AC (Air Combat) | Wide-angle scanning for close-in combat. No range information continuity. | 3000 Hz | ±60° cross-scan | Visual acquisition with range priority. |

- **TWS**: organizes tracks in a multi-target file, employs Kalman-like predictor (real-time digital computer in AWG-10B). Older C/D/E variants used analog track-while-scan with mechanical memory.

*Confidence: moderate; mode functions derived from NNWD and known AWG-10 documentation; some PRF figures approximate.*

### Dogfight and Ground-Look

- **Dogfight (AC)**: Provides high update rate (20 Hz) with wide azimuth/elevation coverage ±60°. Limited to 10 n.mi. range with high PRF. No velocity discrimination.
- **Ground-Look** (AWG-10B/J-S only): Search mode optimized for detecting ground targets using low PRF to reduce turn-rate ambiguity. Antenna elevation lowered to scan ±5°; tilt mechanism is implemented.

*Confidence: dogfight high; ground-look inferred from upgrade notes to AWG-10B.*

### Weapon-Cued Modes

- **Mk. 82/84 Bombs**: Radar used only for altitude readout; delivery modes are computed in the bombing computer.
- **AIM-7 Sparrow**: TWS provides mid-course guidance; STT or dogfight for terminal guidance. Cueing begins in RWS or VS.
- **AIM-9 Sidewinder**: Radar used for boresight and dogfight cues; typically piloted by IR seeker after launch.

*Confidence: high from manuals and NATOPS.*

---

## Performance Parameters

### Pulse Repetition Frequency (PRF)

- **Low PRF**: 800–1200 Hz, range ambiguous but good for long-range search and ground clutter avoidance.
- **Medium PRF**: 1200–2000 Hz for balanced range and velocity information; used in TWS/RWS.
- **High PRF**: 2500–3000 Hz for Doppler velocity search (VS) and dogfight. Produces range ambiguities past 20 n.mi.

Transitions between PRFs are automatic based on selected mode.

### Pulse Width and Beam Pattern

- Wide pulses (2 µs) for low-PRF search; narrow pulses (0.5 µs) in high-PRF/track for better range resolution (~75 ft). AWG-10B introduced variable pulse width in TWS for range gating.
- Beamwidth 3° elevation, 4° azimuth.
- Side lobes limited to -20 dB; AWG-10B improved to -30 dB through feed modifications.

### Scan Volumes and Antenna Rotation

- **Search**: Mechanical rotation 30 RPM; electronic scan ±60° azimuth, ±20° elevation.
- **TWS**: Mechanical rotation plus nodding ±30° to maintain track zones; update rate ~10 Hz per target.
- **Dogfight**: No rotation; fixed forward scan ±60° with high-rate electronic deflection.

### Detection Range and Resolution

- **Maximum RCS (10 m² target)**:
  - VS mode: 50–70 n.mi.
  - RWS mode: 40–60 n.mi.
  - STT: 30–40 n.mi.
  - Dogfight: 10–15 n.mi.
- **Range Resolution**:
  - 0.5 µs pulse width → 75 ft (~0.012 n.mi).
  - 2 µs pulse width → 300 ft (~0.05 n.mi).
- **Azimuth Resolution**: ~0.5° with angle measuring circuits; elevation similar.

Detection range formulas:

```
R_max = (P_t * G^2 * λ^2 * σ) / ((4π)^3 * S_min)
```

Where S_min is the minimum detectable signal threshold; λ≈3 cm. In simulation, apply R_max ∝ sqrt(σ) and factor altitude by 1/sin(elevation) for ground clutter. Use modified radar equation including clutter and Earth's curvature for long ranges.

*Confidence: moderate; formulas standard, parameter estimates from NNWD and general radar texts.*

### Tracking Logic and Criteria

- **Track Initiation**: Requires three coherent successive detections within predicted gates. For TWS, prediction uses last known velocity vector.
- **Track Maintenance**: Gate width ±1° azimuth/elevation and ±0.1 Mach velocity. Loss of track for 3 consecutive sweeps triggers drop.
- **Lock Criteria**: STT lock achieved when amplitude modulation consistent for 5 cycles and Doppler velocity stable.

*Confidence: moderate-high based on NNWD timing diagrams and logic flowcharts.*

---

## Differences: C/D/E vs J/S (AWG-10B)

### Improved TWS

- **Capacity**: AWG-10B tracks up to 12 targets vs 6 on earlier models.
- **Update Rate**: 20 Hz vs 10 Hz, due to increased processor speed and digital memory.
- **Algorithms**: Introduced predictive filtering using digital look-up tables for target maneuvers; earlier versions had fixed-gate scanning.

### Look-Up Tables and Data Processing

- AWG-10B uses digital ROM tables for velocity-to-range conversions, angle correction, and lead-angle calculation for Sparrow. C/D/E relied on analog resolvers.
- Table updates via removable plug-in units allowed software-like modifications.

*Confidence: high; documented in upgrade bulletins.

### Expanded Modes

- Addition of **Velocity Search (VS)** mode in AWG-10B with Doppler filtering absent in earlier variants.
- Improved **Dogfight** with automatic transition to STT on lock.
- **Ground-Look** mode introduced for anti-shipping and battlefield targets.

### Ground-Look Capability

- AWG-10B added an electronically controlled tilt mechanism enabling low-elevation scanning. Radar altitude reference used to adjust clutter filter parameters.

*Confidence: based on upgrade description; moderate.*

---

## Operational Procedures

### Power-Up Sequence

1. **Master Caution** check: ensure no existing failures.
2. **Radar Power Switch** (aft console) to `ON`. Allow warm-up (30 sec magnetron conditioning) monitored via PFS-31 test.
3. **Mode Selector** set to `STBY` then `SEARCH` after power stabilization.
4. **Antenna Unfold**: verification by checking for 5 mph rpm on the T/R indicator.
5. Perform **BIT** (built-in test) by toggling `BIT` switch; monitor `TEST` light flow.

- **Electrical Load**: During warm-up, load draws ~2 kVA; full transmit adds additional 14 kVA when Apache is keyed. Simulation: ramp generator load linearly over 30 seconds.

*Confidence: high from NNWD/NATOPS checklist.*

### Mode Selection and Transition

- **Search to TWS**: select `TWS` on mode knob; radar automatically scales scan to maintain existing tracks. Range gate appears at 40 n.mi.
- **TWS to STT**: depress and hold TRAN button on radar control panel; radar slews to selected target and narrows beam.
- **Dogfight**: rotate mode knob to `DOGF` or hold MASTER ARM with TWS engaged.
- **Ground-Look**: select `GL` from mode knob; enables tilt and low-PRF.

### Weapon Engagement

- **Sparrow Engagement**: lock in STT or TWS with target inside 10 n.mi. Radar provides mid-course updates every 0.5 sec. Compute launch lead using velocity vector tables.
- **Sidewinder**: Radar provides boresight cue; launch zone ±2°.
- **Guns/Bombs**: radar can provide range-only (RWS) and velocity (VS) for CCIP solutions; but primarily the pilot uses the gunsight.

- Logic for spread firing: for two Sparrows, maintain two separate STT tracks; AWG-10B calculates separation using look-up table.

### Emergency Shutdown

- Switch **Radar Power** to `OFF` or `EMERG` lance (remote). The magnetron cools down; generator load drops to idle.
- In case of beam failure, circuit breaker RD is pulled; automatic reversion to search at reduced power.

*Confidence: procedures high from manuals.*

---

## Electrical Load and Simulation Considerations

- **Steady-State**: radar system consumes 32–36 A @28 VDC and ~125 A @115 VAC 400 Hz. Add additional 15 A for digital processors on AWG-10B.
- **Transient**: triggering a transmit burst spikes load by 20% for ~1 ms; modeling as a square pulse in the electrical simulation gives realistic flicker on bus.

- **Failure Modes**: magnetron failure results in 0 kW output but constant draw; antenna drive motor stalls when jamming fault present, raising current to 50 A. These conditions should be implemented in Nasal for diagnosing faults.

*Confidence: moderate.*

---

## Implementation Notes for Nasal

### Formulas and Equations

- **Radar Equation** (already provided). Incorporate altitude factor for line-of-sight: $R_{	ext{max, LOS}} = \\sqrt{2 h_{	ext{rad}} R_e}$ where $R_e= 3440$ nm earth radius. Add term for target altitude: $R_{	ext{horizon}} = \sqrt{2 h_t R_e}$. Final maximum is min of R_max and $R_{	ext{horizon}}$.

- **Doppler Shift**: $f_d = \frac{2 v \cos(\theta)}{\lambda}$. Use to filter clutter: require $|f_d| > f_{	ext{clutter}}$ threshold (~150 Hz for 1° beam width) to consider as moving target.

- **PRF Ambiguity**: For each PRF mode, compute ambiguous range $R_a = c/(2 \cdot PRF)$. Range solutions wrap every $R_a$; implement modulo logic and context from target's last known range to resolve.

- **Track Gate Calculation**: For track file entry i, compute predicted azimuth $Az_{p} = Az_{prev} + v_{az} * \Delta t$; gate width ±$W_{i}$ where $W_{i} = \max(1°, k \, v_{t} )$ with k a tunable coefficient.

### Data Structures

```
struct RadarTarget {
    double range;
    double azimuth;    // degrees
    double elevation;  // degrees
    double velocity;   // knots
    double rcs;        // m^2
    int track_id;
    int status;        // 0 = untracked, 1 = tentative, 2 = tracked
    double last_update_time;
};

struct RadarState {
    int mode;          // enumerated modes
    double prf;
    double pulse_width;
    vector<RadarTarget> tracks;
    double antenna_az; // mechanical azimuth
    double antenna_el; // for tilt
    bool transmitting;
    double load_current;
};
```

### Track Initiation and Maintenance

1. **Sensor Sweep**: On each antenna revolution, compute vector to each airborne object within mechanical scan volume.
2. **Signal Return**: Determine detection probability using $P_d = P($SNR$>S_{th}$)$; implement using noise floor and RCS.
3. **Scan-to-Track**: If detection occurs, attempt to correlate with existing track gates (within ±W_i). If none, create tentative track.
4. **Tentative to Confirm**: After 3 consecutive detections, upgrade to tracked with initialized velocity vector from range-rate difference.
5. **Track Loss**: If no detection for N sweeps (configurable, default 3), remove track and notify pilot via radar scope.

### RCS and Detection

- Use tabulated RCS values by aspect (frontal 5 m² for F-4, halved for F-5, etc.). For ground targets, RCS is altitude- and terrain-dependent; use simple model $	ext{RCS}_{ground} = 10^{	ext{log}_{}	ext{RCS}_0 - k h}$ where k=0.005 per foot.
- Combine RCS and range in radar equation to compute SNR and detection probability.
### Terrain and Ground-Look Handling (Simulation)

To improve realism the simulated radar performs a terrain occlusion test before
accepting any contact. FlightGear/SimGear provide the Nasal helper
`get_cart_ground_intersection(start, direction)` which returns the nearest
point on the scenery mesh intersected by a ray.  The helper is implemented in
C++ and dispatches to the active terrain engine (tilecache, pagedLOD, or STG);
it therefore works regardless of which scenery backend the user has selected. The F-4 script converts the
aircraft position to a start point and the contact vector to a direction, then
compares the distance to the hit versus the contact range.  If the hit is closer
than the contact the ray is deemed blocked and the detection probability is
forced to zero – exactly the behaviour of a real radar losing line‑of‑sight.

> **Performance note:** `get_cart_ground_intersection` is a terrain ray-cast
> that may touch thousands of triangles; while the radar manager only calls it
> once per contact per ping, a simple cache keyed by contact ID and current
> ping timestamp can avoid repeated calls in the same update cycle (see
> `_los_cache` in `RadarManager.nas`).  The regression test stub simply
> overrides the Nasal helper rather than invoking the real engine.

The ground-look (GL) mode uses the same API to generate its own returns. On
each radar ping the manager casts a ray along the current antenna azimuth; if
it intersects terrain within the mode’s range a synthetic contact with
`RCS.GROUND` is created.  This produces a single “chord” of ground clutter that
moves as the antenna sweeps, giving pilots visual feedback of hills and
valleys when flying over deck.  The implementation is conservative – the
ground contact is cleared every ping – but could be extended to sample a grid
for a more continuous map.

Example Nasal helper code:

```nasal
var is_line_of_sight_clear = func(contact) {
    # (as implemented in RadarManager.nas)
    …
};

var generate_ground_contact = func() {
    if (radar_mgr.mode != RM.GL) return;
    …
};
```

See the `radar_test_terrain()` regression test for a minimal stub harness that
exercises both paths without requiring real scenery.
*Confidence: moderate; formulas standard with reasonably chosen coefficients.*

---

## Resources and Confidence Levels

| Data Point | Source | Confidence |
|------------|--------|------------|
| Mode definitions | NNWD F-4A/C/D/E, internal radar manual | High |
| PRF/ pulse width | NNWD appendix tables, F-4 radar spec sheets | Moderate |
| Power requirements | NNWD electrical system sections | Moderate |
| AWG-10B improvements | Upgrade bulletins for J/S, industry literature | High |
| Ground-look mode | J/S upgrade notes | Moderate |
| Operational procedures | NATOPS, NNWD procedures | High |
| Tracking logic | NNWD flowcharts, synthesised based on diagrams | Moderate |
| Formulas | Standard radar equations, textbook references | High |
| RCS values | Established radar cross-section tables | High |

This table will aid future developers in assessing the reliability of each section and highlight areas that may require calibration against real-world data or flight test results.

---

## Diagrams and Tables

*(Diagrams such as beam pattern, scan volume, and block diagrams would be included here in ASCII or Mermaid; due to text-only format, include conceptual descriptions.)*

### Beam Pattern

```
        |\
        | \
        |  \ 3°
--------+---+----- azimuth
        |  /
        | /
        |/
```

### Scan Volume (Search)

- Azimuth: ±60° mechanical
- Elevation: ±20° electronic

### Example Track File Table (AWG-10B)

| Track ID | Range (nm) | Az (deg) | El (deg) | Vel (kt) | Status |
|----------|------------|----------|----------|----------|--------|
| 1        | 25.4       | -10.2    | 2.1      | 540      | Tracked |
| 2        | 40.1       | 5.8      | -1.5     | 320      | Tentative |

---

## Appendices

### Appendix A: NASAL Pseudo-Code Examples

*(Include code examples for radar update loop, track correlation, and electrical load simulation.)*

```
function radar_update(state, delta_t) {
    -- rotate antenna
    state.antenna_az = mod(state.antenna_az + 360 * delta_t / 5.0, 360);

    -- scan targets
    foreach (obj in world.objects) {
        if (in_scan_volume(obj, state)) {
            local snr = compute_snr(obj, state);
            if (snr > state.threshold) {
                correlate_or_create_track(obj, state, delta_t);
            }
        }
    }

    maintain_tracks(state, delta_t);
    update_electrical_load(state);
}
```

### Appendix B: Acronyms

- AWG: Airborne Weapons Guidance
- TWS: Track-While-Scan
- STT: Single Target Track
- RWS: Range-While-Scan
- DF: Dogfight
- IFF: Identification Friend or Foe

---

*End of document.*



