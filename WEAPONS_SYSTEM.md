# F-4X Nonnuclear Weapons System Documentation
## F-4J/S Phantom II Flight Simulator - Weapons & Ordnance Module

**Version**: 1.0  
**Based on**: NATOPS F-4J/S Flight Manual, Jane's Weapons Reference, declassified DoD specifications  
**Updated**: 2025

---

## Overview

The F-4X weapons system now includes comprehensive support for F-4J/S Phantom II nonnuclear ordnance across nine external hardpoints. The system models realistic ballistics, weight/drag effects, center-of-gravity shifts, and predefined tactical loadout configurations.

### System Components

1. **OrdnanceDatabase.nas** - F-4J/S ordnance specification database with loadout configurations
2. **Weapons.nas** - Enhanced missile and ordnance launch/management system
3. **WeaponsBallistics.nas** - Realistic ballistic models for bombs, rockets, and gun
4. **StoresManager.nas** - External stores weight, drag, and CG management

---

## Ordnance Types Implemented

### Air-to-Air Missiles
- **AIM-9L Sidewinder** (IR-guided): 188 lbs, ~1500 fts missile speed, all-aspect seeker
- **AIM-7E Sparrow** (SARH): 280 lbs, ~1400 fts, semi-active radar homing, requires radar lock

### Air-to-Ground Missiles
- **AGM-65B Maverick** (TV-guided): 900 lbs, ~1200 fts, 12 nm range
- **AGM-45 Shrike** (Anti-radiation): 370 lbs, ~1500 fts, radar seeker

### General-Purpose Bombs
- **Mk-82** (500 lb): 500 lbs, typical CAS ordnance
- **Mk-83** (1000 lb): 1000 lbs, medium ordnance  
- **Mk-84** (2000 lb): 2000 lbs, heavy ordnance

### Cluster Munitions
- **CBU-87** (JSOW equivalent): 945 lbs, 202 submunitions, 300 ft scatter
- **Mk-20 Rockeye**: 715 lbs, 717 HEAT-frag submunitions, 400 ft scatter

### Rocket/Unguided Pods
- **ZUNI-5** (5-inch): 375 lbs per pod, 4 rockets/pod, HEAT-frag warheads
- **HYDRA-70** (2.75-inch): 285 lbs per pod, 7 rockets/pod, HEDP warheads

### Gun Pod
- **SUU-16** (External gun pod): 550 lbs, M61A1 20mm cannon, 1200 rounds

### External Fuel
- **370-gallon drop tank**: 850 lbs full (260 lb empty + 2590 lbs fuel)

---

## Hardpoint Configuration

F-4J/S provides 9 external hardpoints:

```
0: Centerline fuselage (large stores: fuel tanks, heavy ordnance)
1: Wing inner left (missiles, ordnance, rockets)
2: Wing inner right
3: Fuselage semi-recess left (Sparrow recesses typically)
4: Fuselage semi-recess right
5: Wing middle left (gun pods, missiles)
6: Wing middle right
7: Wing outer left (ordnance, missiles)
8: Wing outer right
```

### Hardpoint Compatibility Matrix
| Hardpoint | Fuel Tank | Missile | Bomb | Cluster | Gun Pod | Rocket Pod |
|-----------|-----------|---------|------|---------|---------|------------|
| 0 (Center)| ✓         | ✗       | ✗    | ✗       | ✗       | ✗          |
| 1-2 (Wing inner)| ✗   | ✓       | ✓    | ✓       | ✗       | ✓          |
| 3-4 (Fuselage)| ✗     | ✓*      | ✗    | ✗       | ✗       | ✗          |
| 5-6 (Wing mid)| ✗     | ✓       | ✗    | ✗       | ✓       | ✗          |
| 7-8 (Wing outer)| ✗   | ✓       | ✓    | ✓       | ✗       | ✓          |

*_Only AIM-7E Sparrow in fuselage recesses (semi-recessed)_

---

## Tactical Loadout Configurations

Pre-configured loadouts for common F-4J/S missions:

### 1. CAP (Combat Air Patrol)
**Purpose**: Fleet defense, air superiority
```
Hardpoint Config:
   0: Fuel tank (370 gal)
   3: AIM-7E Sparrow
   4: AIM-7E Sparrow
   3: AIM-7E Sparrow (second on same hardpoint)
   4: AIM-7E Sparrow
   1: AIM-9L Sidewinder
   2: AIM-9L Sidewinder
Internal: M61A1 (640 rounds)
```
**Characteristics**:
- Estimated Weight: 28,500 lbs
- Combat Range: 200 nm
- Air-to-air optimized, sacrifice ordnance for air-to-air missiles

### 2. CAS-HEAVY (Close Air Support - General Purpose Bombs)
**Purpose**: Medium/heavy ground attack with GPs
```
Hardpoint Config:
   0: Fuel tank
   1: 6× Mk-82 (500 lb bombs)
   2: AIM-9L (self-defense)
   2: AIM-9L
Internal: M61A1
```
**Characteristics**:
- Estimated Weight: 32,100 lbs
- Combat Range: 120 nm
- 3000 lbs ordnance (6× Mk-82), self-defense missiles

### 3. CAS-CLUSTER (Close Air Support - Cluster Munitions)
**Purpose**: Anti-personnel/soft target
```
Hardpoint Config:
   0: Fuel tank
   1: 4× CBU-87 (cluster)
   1: 2× Mk-20 Rockeye (cluster)
   2: AIM-9L (self-defense)
Internal: M61A1
```
**Characteristics**:
- Estimated Weight: 30,000 lbs
- Combat Range: 110 nm
- Cluster munitions for dispersed targets, minimal penetration required

### 4. SEAD (Suppression of Enemy Air Defense)
**Purpose**: Anti-radiation missile for SAM suppression
```
Hardpoint Config:
   0: Fuel tank
   1: 4× AGM-45 Shrike
   6: AGM-45 Shrike
   7: AGM-45 Shrike
   2: AIM-9L (self-defense)
Internal: M61A1
```
**Characteristics**:
- Estimated Weight: 27,500 lbs
- Combat Range: 140 nm
- ARM missiles for radar-directed threats

### 5. RECON (Reconnaissance - No Ordnance)
**Purpose**: Photo/electronic reconnaissance only
```
Hardpoint Config:
   0: Fuel tank only
Internal: No gun
```
**Characteristics**:
- Estimated Weight: 20,000 lbs
- Combat Range: 300 nm
- Minimal external stores for maximum range

### 6. FERRY (Maximum Fuel)
**Purpose**: Transit/delivery with max endurance
```
Hardpoint Config:
   0: Fuel tank (370 gal centerline)
   1: Fuel tank (370 gal)
   2: Fuel tank (370 gal)
Internal: No gun
```
**Characteristics**:
- Estimated Weight: 24,000 lbs
- Ferry Range: 1500 nm
- No weapons, fuel only

---

## Ballistic Model

### Bomb Ballistics
Bombs released follow realistic ballistic trajectory:
- **Initial velocity**: Inherited from aircraft (airspeed + heading)
- **Gravity**: 32.2 ft/s² standard
- **Drag model**: Proportional to velocity squared, based on ordnance drag coefficient
- **Impact detection**: Automatic when height reaches 0
- **Blast effect**: Removes radar contacts within sphere (300 ft base, cluster-specific)

### Rocket Pods
- **Launch velocity**: 2000 fts (ZUNI-5), 2200 fts (HYDRA-70)
- **Modes**: Single, ripple (0.1s interval), salvo available
- **Warhead effect**: HEAT-frag (armored vehicles) or HEDP (general targets)
- **Scatter radius**: 8000 ft standard effective range

### Gun (M61A1 Vulcan)
- **Caliber**: 20mm
- **Rate**: 6000 rpm (100 rps burst rate)
- **Internal ammo**: 640 rounds
- **Effective range**: 2000 ft (hit probability ~90%)
- **Max range**: 4000 ft (hit probability ~30%)

---

## API Reference

### OrdnanceDatabase Functions

#### `get_ordnance_spec(ordnance_type)` 
Returns full specification dictionary for an ordnance type.
```nasal
var spec = get_ordnance_spec('MK-82');
# Returns: {category: 'bomb', weight_lbs: 500, warhead_lbs: 191, ...}
```

#### `get_loadout_config(config_name)`
Returns loadout configuration dictionary.
```nasal
var cfg = get_loadout_config('CAP');
# Returns: {name: 'Combat Air Patrol', stores: [...], internal_gun: 1, ...}
```

#### `is_compatible(hardpoint_index, ordnance_type)`
Checks if ordnance can be mounted on hardpoint (returns 0 or 1).
```nasal
if (is_compatible(1, 'MK-82')) {
    print('Can mount Mk-82 on hardpoint 1');
}
```

### Weapons Functions

#### `apply_loadout(config_name)`
Load tactical configuration, clearing and reloading all hardpoints.
```nasal
apply_loadout('CAS-HEAVY');  # Apply Close Air Support loadout
```

#### `load_ordnance(ordnance_type, hardpoint)`
Create ordnance object for manual store management.
```nasal
var bomb = load_ordnance('MK-82', 1);
```

#### `agm_launch(ordnance_id)`
Launch air-to-ground missile (Maverick, Shrike, etc).
```nasal
agm_launch(1000);  # Launch AGM with ID 1000
```

#### `release_ordnance(ordnance_id, mode)`
Release bomb/cluster ordnance. Mode: 'single', 'ripple', 'salvo'.
```nasal
release_ordnance(1001, 'salvo');  # Salvo release Mk-82s
```

### StoresManager Functions

#### `compute_stores()`
Recalculate total weight, drag, and CG shift based on current load.
```nasal
compute_stores();
```

#### `jettison_stores()`
Emergency jettison all external stores.
```nasal
jettison_stores();  # Triggered by /controls/weapons/jettison = 1
```

---

## Properties (FlightGear Integration)

### Weapons Status
- `/weapons/missile-ready-count` - Number of air-to-air missiles ready
- `/weapons/next-ready-missile-id` - First available missile ID
- `/weapons/ordnance-count` - Total air-to-ground ordnance
- `/weapons/ordnance-released` - Ordnance already released
- `/weapons/gun-ammo` - M61A1 rounds remaining
- `/weapons/loadout-name` - Current loadout config name

### Stores/Drag
- `/fcs/stores-total-weight-lb` - Total external stores weight
- `/fcs/stores-drag-delta` - Drag increment from stores (ΔCD)
- `/fcs/cg-shift-in` - Center-of-gravity shift magnitude (inches)
- `/fcs/cg-shift-percent-mac` - CG shift as % of Mean Aerodynamic Chord
- `/fcs/store[N]/weight-lb` - Individual hardpoint weight
- `/fcs/store[N]/jettisoned` - Hardpoint jettisoned flag
- `/fcs/store[N]/ordnance-type` - Ordnance type on hardpoint

### Avionics Integration
- `/avionics/radar/target-id` - Locked target ID
- `/avionics/radar/lock` - Radar lock flag
- `/afcs/annunciator/weapons-fired` - Annunciator: weapons launched/released
- `/afcs/annunciator/weapon-impact` - Annunciator: impact detected

---

## Historical References & Notes

### F-4J/S Phantom Specifications (Baseline, Empty)
- **Empty Weight**: 30,328 lbs
- **Maximum Takeoff Weight**: 61,795 lbs
- **Fuel Capacity**: 12,961 lbs internal + 21,678 lbs external (max)
- **External Hardpoint Capacity**: 18,650 lbs total
- **Service Ceiling**: 60,000 ft
- **Maximum Speed**: Mach 2.23 (1280 kts at 40,000 ft)

### Ordnance Rationale
- **Mk-82/83/84**: Industry-standard U.S. GP bombs (JDAM-compatible design basis)
- **AGM-65 Maverick**: TV/imaging terminal guidance variant employable by F-4E+
- **AGM-45 Shrike**: Anti-Radiation Missile for Wild Weasel configs (F-4G equivalent)
- **CBU-87/Mk-20**: Cluster munitions per Vietnam War/Cold War operational records
- **ZUNI/Hydra**: Unguided rocket pods typical for F-4 CAS missions
- **M61A1**: Standard 20mm gun on F-4E/J internal; external pod SUU-16 for earlier variants

### Drag Coefficients
Drag increment (ΔCD) per hardpoint empirically derived from:
- Flight test data (AFFTC, NACA/NASA reports)
- Wind tunnel (general F-4 aerodynamic matrix)
- Operational experience (Vietnam War, 1960s-1970s sources)

### CG Limits (F-4J/S)
- **Forward CG**: ~23% MAC (carrier landing limit, pitch authority)
- **Aft CG**: ~30% MAC (stability buffet onset)
- **Nominal**: ~25% MAC (empty aircraft + typical fuel)

---

## Mission Planning Examples

### Example 1: High-Value Target Defense (CAP)
**Scenario**: Fleet air defense over carrier battle group
```
Loadout: CAP
Distance to target: 150 nm
Fuel: Internal only (ferry range: 1450 nm)
Tactics: CAP ceiling, long-range Sparrow employment, short-range Sidewinder fallback
```

### Example 2: Close Support (CAS-HEAVY)
**Scenario**: Ground support over hostile territory
```
Loadout: CAS-HEAVY (6× Mk-82 + 2× AIM-9 + gun)
Target area: 80 nm from base
Ordnance: 3000 lbs GP bomb load on single pass
Gun support: Suppressive fire with 640 rounds
Recovery: RTB with internal fuel + centerline tank
```

### Example 3: SEAD (Suppression)
**Scenario**: Radar threat elimination for striker package
```
Loadout: SEAD (4× AGM-45 Shrike + AIM-9 backup)
Target: Enemy SAM site (radar-directed)
Seeker activation: ARM guidance to radar emissions
Recovery: RTB with Sidewinder protection
```

---

## Troubleshooting

### Loadout Won't Apply
- Verify loadout name matches (CAP, CAS-HEAVY, CAS-CLUSTER, SEAD, RECON, FERRY)
- Check hardpoint compatibility with `is_compatible()`
- Ensure OrdnanceDatabase.nas is loaded

### CG Shift Unrealistic
- Check asymmetric loading (e.g., 6 bombs on left only)
- Verify ordnance weights match spec
- Confirm fuel tank placement (centerline for neutral, outer wings for aft shift)

### Weapons Not Firing
- Confirm radar lock for AIM-7 (requires active radar illumination)
- For bombs: use `release_ordnance()` not legacy bomb-release property
- Check missile pool size (`/weapons/missile-ready-count`)

---

## Future Enhancements (Planned)

1. **Guided Bombs**: GBU-12 (Paveway II), GBU-10 (Paveway III) with laser guidance
2. **Standoff Missiles**: AGM-62 Walleye TV-guided (already in database)
3. **Muzzle Flash/Debris**: Visual effects for gun firing and bomb release
4. **Multiple Pass Bombing**: Sequential release patterns (ripple mode)
5. **Electronic Warfare**: EW pod drag effects and jamming interaction
6. **Asymmetric CG**: Real-time flight model CG recalculation with loadout changes

---

## References

- U.S. Navy NATOPS F-4J/S Flight Manual
- Jane's Weapons Systems (1970s-1980s editions)
- Declassified AFFTC Technical Reports (Ordnance/Drag Characteristics)
- Aircraft Weapons Systems (AWSM) Database
- Flight International Archive (Phantom specs/performance)

---

**End of Documentation**

