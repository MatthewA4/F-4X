# F-4J/S Electrical System - Quick Reference & Checklists

## Pre-Flight Electrical System Check

### Cockpit Electrical Panel Setup (Cold & Dark)

```
MASTER BATTERY:      OFF (starting position)
GEN A SELECT:        ON (ready for left gen)
GEN B SELECT:        ON (ready for right gen)
TR-1 SELECT:         AUTO (normal position)
TR-2 SELECT:         AUTO (normal position)
EXT POWER:           OFF (unless GPU available)
RADAR POWER:         STBY (not full power yet)
```

### Power-Up Sequence

| Step | Control | Action | Verify | Parameter |
|---|---|---|---|---|
| **1** | MASTER BATTERY | Switch to ON | Battery bus energized | 27-28 VDC on meter |
| **2** | Stall Warning Test | Press test button | Pedal shaker activates 3 sec | Shaker felt in pedals |
| **3** | DC Bus Voltage | Check essential bus | All green lights | 28 ±3 VDC |
| **4** | Fire System Test | Press test button | Fire light illuminates | Annunciator activates |
| **5** | Engine 1 Start | Engage starter | N2 >50% within 5 sec | N2 gauge moving |
| **6** | Gen A Online | Verify auto-engagement | AC main bus appears | 115 ±5 VAC on AC meter |
| **7** | Engine 2 Start | Repeat engine 1 | N2 >50% within 5 sec | Dual engine running |
| **8** | Both Generators | Verify online | AC main at 115V, full power | No GEN lights (amber) |
| **9** | DC Main Bus | Verify stable | Voltage steady 28V | 28.0 ±1.5 VDC |
| **10** | Load Shedding Check | No lights lit | Verify normal power mode | All non-essential loads ON |

---

## In-Flight Electrical Monitoring

### Normal Operation (All Generators Running)

**Key Voltages to Monitor:**
- AC Main Bus: 115 ±5 VAC (450-460 Hz nominal)
- DC Main Bus: 28.0 ±2.0 VDC
- Battery Voltage: 28.0 VDC (fully charged in flight)

**Annunciators - All Should Be Dark:**
- GEN A light: OFF
- GEN B light: OFF
- AC BUS light: OFF
- DC BUS light: OFF
- LOW VOLT light: OFF
- CRITICAL light: OFF (only in emergency)

**Generator Current Balance:**
- Left Gen: ~75-80A at cruise power
- Right Gen: ~75-80A at cruise power
- If imbalance >10A, investigate governor regulation

### Combat Maneuvers (High Electrical Load)

During air combat with radar tracking:

| Maneuver Type | AC Load | DC Load | Voltage Expected | Action |
|---|---|---|---|---|
| **CAP (combat air patrol)** | Radar full-power track | Radar + FCS + avionics | 115V / 28V (nominal) | Monitor current; should be OK |
| **Dash (afterburner + radar)** | Radar + cool pumps | All systems maxed | 114-115V / 27.5-28V (slight sag OK) | Normal; no action required |
| **9G turn (sustained)** | Radar continuous | FCS + instruments | 113-114V / 27.5V (acceptable) | No annunciators should light |
| **If voltage <24V DC** | Load shedding active | See section below | 24-25V (RED condition) | LAND ASAP |

---

## Electrical System Failure Responses

### Situation: Single Generator Failure (In-flight)

**Symptoms:**
- Amber GEN light illuminates for failed generator
- AC main bus voltage dips 5-10% briefly, then recovers
- DC main bus voltage stable (backup TR takes over)

**Pilot Response - IMMEDIATE (First 30 seconds):**
1. Verify which generator failed (check annunciator - GEN A or GEN B light)
2. Switch failed generator to OFF (leave working generator ON)
3. Monitor AC main bus voltage: Should recover to ~115V
4. Monitor DC main bus voltage: Should stay 28V

**Pilot Response - 1-5 minutes:**
1. Handoff to backup generator (automatic, but verify no flicker)
2. Verify no other electrical failures (check all annunciator lights dark)
3. Reduce non-essential electrical loads (optional, to reduce demand)
4. Plan for landing (recommended within 2-4 hours; single generator no redundancy)

**Can Continue Flight?**
- ✅ **YES** - Single generator provides 30 kVA (more than needed)
- Duration: Unlimited (single generator is reliable)
- Recovery: Land at nearest suitable airfield; repair generator

---

### Situation: Single TR Unit Failure

**Symptoms:**
- DC BUS warning light (amber) illuminates briefly
- DC main bus voltage dips 2-3 seconds, then recovers to 28V
- Likely accompanied by slight load shedding (heating, some avionics offline)

**Pilot Response - IMMEDIATE:**
1. Check TR selector switch: Verify failed TR is OFF (if toggleable)
2. Monitor DC main bus voltage: Should recover to 28V ±2V
3. Check DC-Essential bus: Must see 28V for critical systems

**Possible Automatic Actions (Simulator):**
- Non-essential load shedding activates: Cabin heating OFF, some avionics STBY
- Radar may shift to STANDBY mode (manual restart required)
- No loss of flight critical systems

**Can Continue Flight?**
- ✅ **YES** - Single TR still provides 150A DC (adequate for all essential loads)
- Duration: Up to 2-2.5 hours (single TR has zero redundancy; any problem = total DC loss)
- Recovery: Land at nearest airfield; repair TR unit

---

### Situation: AC Bus Loss (Both Generators Fail)

**Symptoms (Catastrophic):**
- AC main bus voltage drops to zero instantly
- All AC lights go out (flight deck, navigation)
- AC BUS warning light (RED) illuminates
- DC main bus voltage unaffected initially (on TR power from remaining small AC source or battery inverter)

**Electrical System Response (Automatic):**
1. **T+0.1 sec:** Emergency inverter activates (battery-powered)
2. **T+0.2 sec:** AC Essential bus re-powers at ~115V AC (from inverter)
3. **T+0.5 sec:** Load shedding: Radar disabled, non-essential avionics offline
4. **T+1.0 sec:** System stabilizes with essential AC loads only (radar receiver, cooling pumps)

**Pilot Response - IMMEDIATE (First 10 seconds):**
1. **Declare emergency** to ATC: "STANDBY to DECLARE" or "MAYDAY - total AC power loss"
2. Check engine status: If engines flamed out, attempt restart (battery power available)
3. Verify flight controls responding (still powered by DC-Essential on battery)
4. Activate landing lights manually (if desired)
5. Prepare for non-radar approach

**Flight Control Status (Battery Powered):**
- Elevators: ✅ Responsive
- Ailerons: ✅ Responsive
- Rudder: ✅ Responsive
- Stall warning: ✅ Active
- Hydraulic pump: ✅ Marginal pressure (battery-powered backup)

**Navigation Available:**
- Compass: ✅ Mechanical
- Clock: ✅ Battery-powered
- Altitude (standby): ✅ Battery-powered
- UHF Radio: ✅ Battery-powered
- Radar: ❌ Offline (no AC inversion)

**Time Limit (Battery Only):**
- Battery reserve: ~30 minutes (DC-Essential loads only)
- Recommended landing window: Within 15 minutes (maintains 15 min safety margin)

**Recovery Procedure (If Engine Restarts):**
1. Left/Right engine N2 >60%: Corresponding gen auto-engages
2. AC main bus voltage climbs: Should see ~115V within 5 seconds
3. AC BUS warning light extinguishes
4. TR units power up: DC main bus recovers to 28V
5. Load shedding reverses: Radar, heating, non-essential loads restore
6. **Confirm:** All three buses at normal voltage before resuming combat ops

---

### Situation: Total DC Bus Loss (Both TRs Failed)

**Symptoms (Most Perilous):**
- DC BUS warning light (RED) illuminates
- DC main bus voltage drops to zero (no power to FCS servos!)
- AC main bus still available (assuming generators running)
- **CRITICAL:** Flight controls may be non-responsive

**Electrical System Response (Emergency Battery Takeover):**
1. **T+0.1 sec:** Battery bus contactors close automatically
2. **T+0.5 sec:** DC-Essential bus re-powers from battery (~27V initial)
3. **T+1.0 sec:** Flight controls regain power; system stabilizes

**Pilot Response - IMMEDIATE (Seconds 0-5):**
1. **Declare emergency now:** "MAYDAY - total electrical failure"
2. Check flight control responsiveness: Verify elevator, aileron, rudder moving
3. If controls dead: **Eject from aircraft** (ejection system battery-independent)
4. If controls responding: Proceed to emergency landing procedures

**Emergency Landing on Battery Power:**
- **Resources available:** Flight controls (DC-Ess), stall warning, radio (UHF)
- **Resources NOT available:** Radar (no AC), most avionics displays
- **Procedure:** Radio-aided approach with visual contact; use compass heading if needed
- **Time available:** 20-25 minutes before battery critical

**Immediate Actions (If systems stabilize):**
1. Reduce altitude to <10,000 ft (improves battery efficiency)
2. Reduce electrical load: Turn off non-flying instruments
3. Execute emergency landing at nearest suitable airfield
4. **Do NOT attempt aerobatics or sustained high-G flight** (battery cannot sustain full FCS load in intense combat)

---

## Load Shedding Reference (Automatic & Manual)

### Automatic Load Shedding Cascade

The system sheds loads automatically based on DC main bus voltage:

| Voltage Threshold | Annunciator | Action | Status |
|---|---|---|---|
| **>26.0 VDC** | —— (dark) | Normal | All loads available |
| **25.5-26.0 VDC** | AC BUS (yellow) | Warning; prepare to reduce load | Non-essential loads caution |
| **24.5-25.5 VDC** | LOW VOLT (amber) | **ACTIVE:** Heating & lighting shed | Radar still on; FCS full power |
| **23.0-24.5 VDC** | CRITICAL (red) | **ACTIVE:** Radar & non-essential avionics shed | Only DC-Ess bus + battery inverter |
| **<22.0 VDC** | CRITICAL (red flash) | **TOTAL EMERGENCY:** Battery reserve ~15 min remaining | Prepare to eject or emergency land |

### Manual Load Reduction (Cockpit Switches)

**If Voltage Warning Appears (NOT in emergency):**

Recommended manual shedding sequence (if generator output marginal):

| Priority | Load | Switch | Effect |
|---|---|---|---|
| **1st** | Cabin Heating | HEAT OFF | ~20A reduction; slight cabin warming loss |
| **2nd** | Landing Lights | LANDING LIGHTS off | ~3A reduction; minimal (use at landing only) |
| **3rd** | Anti-Collision Light | ANTI-COLL off | ~1A reduction; minimal (use in formation only) |
| **4th** | Radar (Full Power) | RADAR to STBY | ~25A reduction; can quickly restore when needed |
| **Last Resort** | Avionics Displays | Individual AVIONICS switches off | Disables instruments; avoid if possible |

**Restoration Sequence (After Generator Recovery):**
- Restore in REVERSE order: Avionics → Radar → Anti-Coll → Landing Lights → Heating
- Wait 2 seconds between each restoration (allows voltage to stabilize)
- Verify voltage stable before next load

---

## Startup Troubleshooting

### Symptom: Master Battery shows only 25V (Low Battery)

**Cause:** Battery discharged from previous flights or ground standby

| Step | Action | Expected Result | If Failed |
|---|---|---|---|
| 1 | Confirm battery voltage low (25V) | Battery at 25V is marginal | **Ground equipment GPU required** |
| 2 | Request ground power unit (GPU) | 25V GPU connects to airplane | Airplane receives 25-26V trickle charge |
| 3 | Wait 10-15 minutes | Battery charges to 26.5V | If no improvement, **battery bad; replace** |
| 4 | Retry engine start | Starters should crank vigorously | If still weak, **defer flight** |

**Decision:**
- **Voltage >26.0V:** Safe to dispatch (battery charged enough)
- **Voltage 25.5-26.0V:** Marginal; recommend charging before flight
- **Voltage <25.5V:** **Do NOT dispatch** (risk of single-engine-out electrical loss)

### Symptom: GEN A or GEN B Light Stays On After Engine Start

**Cause:** Engine N2 <60%, so generator not engaging

| Step | Action | Expected Result | If Failed |
|---|---|---|---|
| 1 | Check N2 gauge | N2 should be >60% | If N2 <50%, engine not running properly |
| 2 | Advance throttle slowly to 50% | N2 should climb | If N2 stuck, possible engine problem |
| 3 | When N2 >60% | Gen light should extinguish automatically | If gen light persists: **Generator problem** |
| 4 | If gen light stays on at high throttle | Suspect generator mechanical failure | **Switch generator to OFF; use backup** |

### Symptom: DC Bus Voltage 24V but AC Bus 115V (Normal)

**Cause:** Likely single TR unit failure

| Step | Action | Expected Result | If Failed |
|---|---|---|---|
| 1 | Check which TR is online | Should read ~28V on DC main | If reading <24V, TR failed |
| 2 | Toggle TR selector: Both to AUTO | System should use backup TR | If no recovery, **both TRs bad** |
| 3 | Verify DC voltage climbs to 28V | DC main should stabilize | If unstable or low, TR failing |
| 4 | Monitor for next 5 min | Voltage should remain stable 28V ±2V | If drops again, TR thermal issue |

**Recommendation:** Land within 2 hours (single TR redundancy lost); equipment repair needed

---

## Quick Reference: Voltage Limits by System

| System / Function | Minimum Safe Voltage | Nominal Voltage | Maximum Safe Voltage |
|---|---|---|---|
| **AC Main Bus (Generator)** | 105 VAC | 115 ±5 VAC | 125 VAC |
| **AC Essential Bus (Inverter)** | 100 VAC | 115 ±5 VAC | 125 VAC |
| **DC Main Bus (TR output)** | 20 VDC | 28.0 ±2 VDC | 32 VDC |
| **DC Essential Bus (Critical)** | 20 VDC | 28.0 ±3 VDC | 34 VDC |
| **Battery Bus (Direct)** | 18 VDC | 24-28 VDC | 31 VDC |
| **Flight Control Servos** | 24 VDC | 28.0 VDC | 31 VDC |
| **Radar Transmitter** | 110 VAC | 115 ±5 VAC | 125 VAC |
| **Stall Warning Solenoid** | 22 VDC | 28.0 VDC | 31 VDC |
| **Radio UHF** | 20 VDC | 28.0 VDC | 31 VDC |

---

## Emergency Equipment Battery Status

**Emergency Equipment with Independent Power:**

| Equipment | Power Source | Duration | Notes |
|---|---|---|---|
| **Ejection Seat** | Pyrotechnic cartridges | Single use | Operates independent of aircraft electrical |
| **Emergency Oxygen** | High-pressure bottles | 60+ minutes | Pressure-regulated, no electrical required |
| **Survival Radio** | Internal battery | 8-12 hours | Separate lithium reserve battery |
| **Anti-G Suit Inflator** | Manual hand pump | Unlimited | Mechanical; no electrical |
| **Emergency Parachute** | Barometric/altitude fuse | Single use | Auto-deploys at 14,000 ft if needed |

**Note:** Electrical system failure does NOT affect emergency egress systems.

---

## Pilot Workload Considerations

### Electrical System Monitoring During Different Flight Phases

**Pre-Flight & Startup (5 minutes)**
- Check battery voltage
- Monitor generator online indications
- Verify all bus voltages normal

**Climb to Altitude (15 minutes)**
- Periodic AC/DC voltage checks (every 2-3 minutes)
- Verify generator current balance
- Confirm no annunciator lights

**Level Flight / Cruise (Continuous)**
- Background monitoring (check every 5-10 minutes)
- Routine check of generator loads
- Normal workload acceptable

**Combat Ops / High Load (Continuous focus)**
- Primary monitoring (check voltages every 30 seconds during radar track)
- Ready to shed loads if voltage sags
- Elevated workload; may require pilot + WSO division

**Landing Approach (10 minutes)**
- Final voltage check before landing
- Verify landing lights operational
- Confirm all systems normal before touchdown

---

## Document Revision

| Date | Version | Changes | Notes |
|---|---|---|---|
| 2026-02-14 | 1.0 | Initial release | Complete electrical system reference |
| 2026-02-14 | 1.1 | Added load shedding cascades | Enhanced troubleshooting section |

---

**Related Documents:**
- [ELECTRICAL_SYSTEM.md](ELECTRICAL_SYSTEM.md) - Complete technical specification  
- [SYSTEM_STATUS.md](SYSTEM_STATUS.md) - Overall F-4X system implementation status  
- [electrical.nas](src/electrical.nas) - Nasal implementation code  

