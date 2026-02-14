# F-4J Automatic Flight Control System (AFCS) - NATOPS Section 1.17

var TRUE = 1;
var FALSE = 0;

# Properties for AFCS state
var properties = {
    sas_roll: "/afcs/sas-roll-engaged",
    sas_pitch: "/afcs/sas-pitch-engaged",
    sas_yaw: "/afcs/sas-yaw-engaged",
    ap_att: "/afcs/ap-att-hold",
    ap_alt: "/afcs/ap-alt-hold",
    fail: "/afcs/fail",
    ann_ap_att: "/afcs/annunciator/ap-att",
    ann_ap_alt: "/afcs/annunciator/ap-alt",
    ann_sas: "/afcs/annunciator/sas",
    ann_fail: "/afcs/annunciator/fail"
};

# Read cockpit switches (to be mapped in cockpit/controls)
# - returns either the property or the def value.
var get_switch = func(name, def) {
    return getprop("/controls/afcs/" ~ name) or def;
}

# PID controller utility
var make_pid = func(kp, ki, kd) {
    return {
        kp: kp, ki: ki, kd: kd,
        prev_err: 0, integ: 0,
        update: func(self, setpoint, value, dt) {
            var err = setpoint - value;
            self.integ += err * dt;
            var deriv = (err - self.prev_err) / dt;
            self.prev_err = err;
            return self.kp * err + self.ki * self.integ + self.kd * deriv;
        },
        reset: func(self) {
            self.prev_err = 0;
            self.integ = 0;
        }
    };
};

# PID controllers for autopilot
var pid_att_roll = make_pid(0.8, 0.01, 0.15);   # Tune as needed
var pid_att_pitch = make_pid(1.2, 0.02, 0.18);
var pid_alt = make_pid(0.5, 0.005, 0.1);

# State for attitude/altitude hold
var att_hold = { roll: 0, pitch: 0, active: 0 };
var alt_hold = { alt: 0, active: 0 };

# High-AOA stall warning system (NATOPS Section 1.17)
# Stall warning at ~20-21 units AOA (flaps down), ~18 units (approach), warning starts ~2 units before
var stall_warning = {
    active: 0,
    aoa_critical: 21.0,      # Units AOA - stall threshold
    aoa_warning: 19.0,       # Units AOA - stall warning threshold
    shaker_on: 0,            # Rudder pedal shaker
    departure_risk: 0,       # High AOA approach-to-departure
    wing_rock_active: 0,     # Oscillation at high AOA
    last_aoa: 0,
    aoa_rate: 0,
};

# SAS engagement logic (auto-disengage on stick force, failure, or switch off)
var update_sas = func {
    var fail = getprop(properties.fail, 0);

    # Roll SAS
    var roll_switch = get_switch("sas-roll", 1);
    var roll_force = abs(getprop("/controls/flight/aileron", 0)) > 0.1;
    setprop(properties.sas_roll, roll_switch and !fail and !roll_force);

    # Pitch SAS
    var pitch_switch = get_switch("sas-pitch", 1);
    var pitch_force = abs(getprop("/controls/flight/elevator", 0)) > 0.1;
    setprop(properties.sas_pitch, pitch_switch and !fail and !pitch_force);

    # Yaw SAS
    var yaw_switch = get_switch("sas-yaw", 1);
    var yaw_force = abs(getprop("/controls/flight/rudder", 0)) > 0.1;
    setprop(properties.sas_yaw, yaw_switch and !fail and !yaw_force);

    # Annunciator
    setprop(properties.ann_sas, (getprop(properties.sas_roll) or getprop(properties.sas_pitch) or getprop(properties.sas_yaw)) ? 1 : 0);
};

# Attitude hold logic (engages if switch on, no fail, and no stick force)
var update_att_hold = func(dt) {
    var fail = getprop(properties.fail, 0);
    var att_switch = get_switch("ap-att", 0);
    var stick_force = abs(getprop("/controls/flight/aileron", 0)) > 0.1 or abs(getprop("/controls/flight/elevator", 0)) > 0.1;

    if (att_switch and !fail and !stick_force) {
        if (!att_hold.active) {
            # Capture current attitude as hold reference
            att_hold.roll = getprop("/orientation/roll-deg", 0);
            att_hold.pitch = getprop("/orientation/pitch-deg", 0);
            pid_att_roll.reset(pid_att_roll);
            pid_att_pitch.reset(pid_att_pitch);
            att_hold.active = 1;
        }
        # Calculate corrections (use PID object as self)
        var roll_cmd = pid_att_roll.update(pid_att_roll, att_hold.roll, getprop("/orientation/roll-deg", 0), dt);
        var pitch_cmd = pid_att_pitch.update(pid_att_pitch, att_hold.pitch, getprop("/orientation/pitch-deg", 0), dt);

        # Inject commands (add to trim, or use custom property for FCS input)
        setprop("/afcs/att/roll-cmd", roll_cmd);
        setprop("/afcs/att/pitch-cmd", pitch_cmd);

        setprop(properties.ap_att, 1);
        setprop(properties.ann_ap_att, 1);
    } else {
        att_hold.active = 0;
        setprop("/afcs/att/roll-cmd", 0);
        setprop("/afcs/att/pitch-cmd", 0);
        setprop(properties.ap_att, 0);
        setprop(properties.ann_ap_att, 0);
    }
};

# ADC static correction & transonic oscillation avoidance (NATOPS 4.24-4.26)
# The ADC suffers from airspeed oscillations near Mach 0.9-1.0; reduce altitude-hold
# gain or disable briefly to avoid pilot-induced oscillations (PIO)
var adc_state = {
    static_corr_off: 0,          # 1 = ADC in transonic region, airspeed unreliable
    transonic_recovery: 0,       # Recovery timer to resume alt-hold
    airspeed_smooth: 0,          # Low-pass filtered airspeed
};

var update_adc_static_correction = func(dt) {
    var mach = getprop("/velocities/mach", 0);
    var cas = getprop("/velocities/airspeed-kt", 0);
    var altitude = getprop("/position/altitude-ft", 0);
    
    # ADC static error region: Mach 0.85-1.05
    if (mach >= 0.85 and mach <= 1.05) {
        if (!adc_state.static_corr_off) {
            adc_state.static_corr_off = 1;
            adc_state.transonic_recovery = 2.0; # 2-sec timeout for phase-out
            pid_alt.reset(pid_alt);
            setprop("/afcs/annunciator/adc-static-error", 1);
        }
    } else if (adc_state.static_corr_off) {
        adc_state.transonic_recovery -= dt;
        if (adc_state.transonic_recovery <= 0) {
            adc_state.static_corr_off = 0;
            setprop("/afcs/annunciator/adc-static-error", 0);
        }
    }
};

# Altitude hold logic (engages if switch on, no fail, and no stick force)
# Modified to reduce gain during transonic ADC uncertainty
var update_alt_hold = func(dt) {
    var fail = getprop(properties.fail, 0);
    var alt_switch = get_switch("ap-alt", 0);
    var stick_force = abs(getprop("/controls/flight/elevator", 0)) > 0.1;

    if (alt_switch and !fail and !stick_force) {
        if (!alt_hold.active) {
            # Capture current altitude as hold reference
            alt_hold.alt = getprop("/position/altitude-ft", 0);
            pid_alt.reset(pid_alt);
            alt_hold.active = 1;
        }
        
        var alt_error = alt_hold.alt - getprop("/position/altitude-ft", 0);
        var alt_cmd = pid_alt.update(pid_alt, alt_hold.alt, getprop("/position/altitude-ft", 0), dt);
        
        # NATOPS: During transonic climb (M 0.9-1.0), reduce alt-hold gain to ~50% 
        # to prevent pilot-induced oscillation from ADC airspeed fluctuations
        if (adc_state.static_corr_off) {
            # Reduce all PID action during transonic
            alt_cmd *= 0.5;
        }

        # Inject command (add to trim, or use custom property for FCS input)
        setprop("/afcs/alt/pitch-cmd", alt_cmd);

        setprop(properties.ap_alt, 1);
        setprop(properties.ann_ap_alt, 1);
    } else {
        alt_hold.active = 0;
        setprop("/afcs/alt/pitch-cmd", 0);
        setprop(properties.ap_alt, 0);
        setprop(properties.ann_ap_alt, 0);
    }
};

# Landing weight monitoring system (NATOPS-based)
# F-4J/S Maximum Landing Weight: 36,831 lbs (from Wikipedia, verified specs)
# Warns pilot if attempting to land overweight (affects structural stress, landing distance, handling)
var landing_weight_monitor = {
    max_landing_weight: 36831,  # lbs - From F-4E/J/S specifications
    overweight_warned: 0,
};

var update_landing_weight = func(dt) {
    var gross_weight = getprop("/fdm/jsbsim/inertia/total-weight-lbs", 0);
    var gear_down = getprop("/gear/gear-pos-norm", 0) > 0.95;
    var on_ground = getprop("/fdm/jsbsim/position/h-agl-ft", 0) < 50;  # Within 50 feet of ground
    var in_approach = getprop("/fdm/jsbsim/position/h-agl-ft", 0) < 1000 and 
                      getprop("/velocities/airspeed-kt", 0) < 200;
    
    # Check for overweight landing attempt
    if ((on_ground or in_approach) and gear_down) {
        if (gross_weight > landing_weight_monitor.max_landing_weight) {
            # Overweight landing warning
            setprop("/afcs/annunciator/landing-weight-warning", 1);
            landing_weight_monitor.overweight_warned = 1;
        } else {
            # Within limits
            setprop("/afcs/annunciator/landing-weight-warning", 0);
            landing_weight_monitor.overweight_warned = 0;
        }
    } else {
        # Not in landing approach
        setprop("/afcs/annunciator/landing-weight-warning", 0);
        landing_weight_monitor.overweight_warned = 0;
    }
    
    # Publish current weight for reference (useful for procedures)
    setprop("/fdm/jsbsim/inertia/max-landing-weight-lbs", landing_weight_monitor.max_landing_weight);
    setprop("/afcs/weight/overweight-margin-lbs", 
            landing_weight_monitor.max_landing_weight - gross_weight);
};

# High-AOA stall warning system (NATOPS-based)
# Detects approach to stall and provides warnings
# Updated to account for leading edge slats (F-4E/S variant)
var update_stall_warning = func(dt) {
    var aoa = getprop("/orientation/alpha-deg", 0);
    var cas = getprop("/velocities/airspeed-kt", 0);
    var alt = getprop("/position/altitude-ft", 0);
    var gear_down = getprop("/gear/gear-pos-norm", 0) > 0.95;
    var flaps_down = getprop("/fdm/jsbsim/fcs/flap-pos-deg", 0) > 5;
    var slats_deployed = getprop("/fcs/slats-deployed", 0) or getprop("/fdm/jsbsim/fcs/slats-deployed", 0);
    
    # AOA rate calculation for wing-rock detection
    stall_warning.aoa_rate = (aoa - stall_warning.last_aoa) / dt;
    stall_warning.last_aoa = aoa;
    
    # Get weight-dependent stall thresholds from JSBSim functions (StallWeightLookup system)
    var base_critical = getprop("/fcs/stall-aoa-critical") or 20.0;
    var base_warning = getprop("/fcs/stall-aoa-warning") or (base_critical - 2.0);

    # Flaps configuration modifies thresholds (landing config increases margin)
    var threshold_critical = base_critical + (flaps_down ? 1.5 : 0.0);
    var threshold_warning = base_warning + (flaps_down ? 1.5 : 0.0);

    # Slats provide additional stall margin (reduce thresholds by ~2 deg when deployed)
    if (slats_deployed) {
        threshold_warning -= 2.0;
        threshold_critical -= 2.0;
    }

    # Stores/weight penalty: heavier external stores lower effective stall AOA slightly
    var stores_wt = getprop("/fcs/stores-total-weight-lb") or 0;
    if (stores_wt > 8000.0) {
        # Reduce thresholds by up to 1.0 deg for very heavy external loads
        var penalty = math.min(1.0, (stores_wt - 8000.0) / 6000.0);
        threshold_warning -= penalty;
        threshold_critical -= penalty;
    }
    
    # Stall warning engages if AOA exceeds computed warning threshold
    if (aoa > threshold_warning) {
        stall_warning.active = 1;
        stall_warning.shaker_on = 1;
        setprop("/afcs/annunciator/stall-warning", 1);
        setprop("/afcs/annunciator/stall-horn", 1);
        
        # Simulate rudder pedal shaker vibration by setting cockpit vibration property
        if (int(systime() * 10) % 3 == 0) {  # ~10 Hz vibration
            setprop("/controls/afcs/rudder-shaker", 0.3);
        } else {
            setprop("/controls/afcs/rudder-shaker", 0);
        }
    } else {
        stall_warning.active = 0;
        stall_warning.shaker_on = 0;
        setprop("/afcs/annunciator/stall-warning", 0);
        setprop("/afcs/annunciator/stall-horn", 0);
        setprop("/controls/afcs/rudder-shaker", 0);
    }
    
    # Departure/wing-rock detection at extreme AOA
    # High-AOA oscillations can lead to uncontrolled wing rock or spin entry
    if (aoa > threshold_critical + 1.0 and abs(stall_warning.aoa_rate) > 2.0) {
        stall_warning.departure_risk = 1;
        stall_warning.wing_rock_active = 1;
        setprop("/afcs/annunciator/departure-warning", 1);
    } else {
        stall_warning.departure_risk = 0;
        setprop("/afcs/annunciator/departure-warning", 0);
    }
};

# Failure annunciator
var update_annunciators = func {
    setprop(properties.ann_fail, getprop(properties.fail) or 0);
};

# Main update loop
# ======== REFUELING PROBE SYSTEM ========
# Air refueling probe control and envelope monitoring
# F-4 uses probe-and-drogue system

var update_refuel_probe = func(dt) {
    # Get pilot control input (manual toggle via property)
    var pilot_request = getprop("/controls/refueling/probe-extended") or 0;
    
    # Check safety conditions for probe extension
    var speed_kts = getprop("/velocities/vcas-kts") or 0;
    var mach = getprop("/velocities/mach") or 0;
    var agl_ft = getprop("/position/altitude-agl-ft") or 0;
    
    # Can extend: speed < 300 kt AND mach < 0.85 AND altitude > 5,000 ft
    var can_extend = (speed_kts < 300.0) and (mach < 0.85) and (agl_ft > 5000.0);
    
    # Must retract: speed > 350 kt OR mach > 0.90 OR altitude < 2,000 ft AGL
    var must_retract = (speed_kts > 350.0) or (mach > 0.90) or (agl_ft < 2000.0);
    
    # Set probe state based on pilot input and safety
    var probe_safe = 0;
    if (must_retract) {
        probe_safe = 0;
        # Override pilot if dangerously high speed - auto-retract
        setprop("/controls/refueling/probe-extended", 0);
    } elsif (pilot_request and can_extend) {
        probe_safe = 1;
    }
    
    setprop("/fcs/refuel-probe-extended", probe_safe);
    
    # Refuel rate tracking (cumulative fuel added)
    var rate_lb_min = getprop("/fcs/refuel-rate-lb-min") or 0;
    var current_total = getprop("/fcs/refuel-total-added-lb") or 0;
    var new_total = current_total + (rate_lb_min * dt / 60.0);
    setprop("/fcs/refuel-total-added-lb", new_total);
    
    # Envelope monitoring warnings
    var envelope_valid = getprop("/fcs/refuel-envelope-valid") or 0;
    var refuel_active = getprop("/afcs/annunciator/refuel-contact") or 0;
    
    # Alert if probe extended but envelope invalid (approaching limits)
    if (probe_safe and !envelope_valid and refuel_active == 0) {
        setprop("/afcs/annunciator/refuel-envelope-warning", 1);
    } else {
        setprop("/afcs/annunciator/refuel-envelope-warning", 0);
    }
    
    # Procedural check: warn if probe not stowed at high speed
    if (probe_safe and speed_kts > 350.0) {
        # This should trigger auto-retract above, but second buffer
        if (!must_retract) {
            # Speed climbing toward limit - alert
            setprop("/afcs/annunciator/probe-stow-warning", 1);
        }
    } else {
        setprop("/afcs/annunciator/probe-stow-warning", 0);
    }
    
    # Log refueling events (informational)
    var contact_now = refuel_active;
    var was_contact = getprop("/fcs/refuel-contact-last") or 0;
    if (contact_now and !was_contact) {
        # Just engaged - log contact time and fuel status
        var current_fuel = getprop("/propulsion/tank[0]/contents-lbs") or 0;
        print(sprintf("Refuel contact established. Current fuel: %.0f lb, Transfer rate: %.0f lb/min", 
                      current_fuel, rate_lb_min));
    }
    setprop("/fcs/refuel-contact-last", contact_now);
};

# External stores management (drag, weight, annunciators)
var update_stores_status = func(dt) {
    # Stores system properties are computed via JSBSim, but we update annunciators
    var total_stores = getprop("/fcs/stores-total-weight-lb") or 0;
    var stores_drag = getprop("/fcs/stores-drag-delta") or 0;
    
    # Heavy stores loaded indicator (8000+ lbs)
    var loaded = (total_stores > 8000.0) ? 1 : 0;
    setprop("/afcs/annunciator/stores-loaded", loaded);
    
    # Very heavy load indicator (14000+ lbs combat load)
    var heavy = (total_stores > 14000.0) ? 1 : 0;
    setprop("/afcs/annunciator/stores-heavy-load", heavy);
    
    # Informational logging for pilot awareness
    if (loaded and !getprop("/afcs/stores-logged") or 0) {
        var speed_kts = getprop("/velocities/vcas-kts") or 0;
        var mach = getprop("/velocities/mach") or 0;
        print(sprintf("Stores loaded: %.0f lb total | Drag delta: %.5f | Current: %.0f kts / Mach %.2f", 
                      total_stores, stores_drag, speed_kts, mach));
        setprop("/afcs/stores-logged", 1);
    } elsif (!loaded and getprop("/afcs/stores-logged") or 0) {
        print("Stores unloaded - clean configuration");
        setprop("/afcs/stores-logged", 0);
    }
};

# Initialize refueling properties
setprop("/controls/refueling/probe-extended", 0);     # Pilot control
setprop("/fcs/refuel-probe-extended", 0);              # Actual probe state
setprop("/fcs/refuel-envelope-valid", 0);              # Safety check
setprop("/fcs/refuel-contact-active", 0);              # Boom contact
setprop("/fcs/refuel-rate-lb-min", 0);                 # Transfer rate
setprop("/fcs/refuel-total-added-lb", 0);              # Cumulative added
setprop("/fcs/refuel-contact-last", 0);                # For event logging
setprop("/afcs/annunciator/refuel-probe-extended", 0);  # Pilot indicator
setprop("/afcs/annunciator/refuel-contact", 0);         # Green light
setprop("/afcs/annunciator/refuel-envelope-warning", 0); # Amber light
setprop("/afcs/annunciator/refuel-max-fuel", 0);        # Max fuel flag
setprop("/afcs/annunciator/probe-stow-warning", 0);     # Speed too high

# Initialize external stores properties (9 hardpoints)
# Configuration: centerline tank, left/right wing pylons (inner+outer), fuselage Sparrows, gun pod, ordnance rack
for (var i = 0; i < 9; i += 1) {
    setprop("/fcs/store[" ~ i ~ "]/weight-lb", 0);
}
setprop("/fcs/stores-total-weight-lb", 0);             # Total stores weight
setprop("/fcs/stores-config", 0);                      # Config identifier (for reference)
setprop("/afcs/annunciator/stores-loaded", 0);         # Heavy load indicator
setprop("/afcs/annunciator/stores-heavy-load", 0);     # Very heavy load indicator

# Landing distance monitoring function
var update_landing_distance = func(dt) {
    # Only calculate during approach/landing phases (gear down, AGL < 2000 ft)
    var gear_down = getprop("/gear/gear[0]/wow") or 0;
    var agl = getprop("/position/altitude-agl-ft") or 5000;
    
    if (!gear_down or agl > 2000.0) {
        return; # Not in landing phase
    }
    
    # Get landing weight
    var weight_lb = getprop("/inertia/weight-lbs") or 36831;
    
    # Get wind components (assuming runway heading available from property)
    # If not available, assume calm: simplified calculation
    var wind_direction_deg = getprop("/environment/wind-from-heading-deg") or 180;
    var wind_speed_kt = getprop("/environment/wind-speed-kt") or 0;
    var aircraft_heading_deg = getprop("/orientation/heading-deg") or 0;
    
    # Calculate headwind component (positive = headwind = good for landing)
    var relative_wind_deg = wind_direction_deg - aircraft_heading_deg;
    var headwind_kt = wind_speed_kt * math.cos(relative_wind_deg * math.pi / 180.0);
    var crosswind_kt = wind_speed_kt * math.sin(relative_wind_deg * math.pi / 180.0);
    
    # Use baseline landing distance from weight (3,680 ft at max 36,831 lbs)
    # Scale linearly for other weights
    var max_landing_wt = 36831.0;
    var baseline_distance = 3680.0;
    var landing_distance = baseline_distance * (weight_lb / max_landing_wt);
    
    # Apply wind correction: headwind -4% per 10 kt, crosswind +0.5% per 10 kt
    var wind_factor = 1.0 + (headwind_kt * -0.004) + (abs(crosswind_kt) * 0.0005);
    landing_distance = landing_distance * wind_factor;
    
    # Apply surface correction (assume dry: 1.0, wet: 1.4, ice: 2.0)
    var surface_factor = 1.0; # TODO: tie to runway surface property when available
    landing_distance = landing_distance * surface_factor;
    
    # Apply altitude correction (density ratio effect)
    var density_ratio = getprop("/atmosphere/density-ratio") or 1.0;
    if (density_ratio > 0.1) {
        landing_distance = landing_distance / density_ratio;
    }
    
    # Safety margin: 1.67× for approach planning
    var min_usable_runway = landing_distance * 1.67;
    
    # Assume runway length 10,000 ft (typical fighter runway), update if property available
    var runway_available = 10000.0;
    var margin = runway_available - min_usable_runway;
    
    # Update properties
    setprop("/fcs/landing-distance-required", landing_distance);
    setprop("/fcs/minimum-usable-runway", min_usable_runway);
    setprop("/fcs/landing-distance-available-ft", runway_available);
    setprop("/fcs/landing-distance-margin", margin);
    
    # Annunciators
    var marginal = (margin > 0 and margin < 1000.0);
    var inadequate = (margin <= 0);
    setprop("/afcs/annunciator/landing-distance-marginal", marginal ? 1 : 0);
    setprop("/afcs/annunciator/landing-distance-inadequate", inadequate ? 1 : 0);
    
    # Pilot warnings during approach
    if (inadequate and !getprop("/afcs/landing-distance-warning") or 0) {
        print(sprintf("LANDING DISTANCE INADEQUATE! Required: %.0f ft (w/ safety margin: %.0f ft) Available: %.0f ft Margin: %.0f ft",
              landing_distance, min_usable_runway, runway_available, margin));
        setprop("/afcs/landing-distance-warning", 1);
    } elsif (marginal and !getprop("/afcs/landing-distance-marginal-alert") or 0) {
        print(sprintf("Landing distance marginal. Required: %.0f ft Margin: %.0f ft (should be >1000 ft)",
              landing_distance, margin));
        setprop("/afcs/landing-distance-marginal-alert", 1);
    } elsif (!marginal and !inadequate) {
        setprop("/afcs/landing-distance-warning", 0);
        setprop("/afcs/landing-distance-marginal-alert", 0);
    }
};

# Landing distance initialization
setprop("/fcs/landing-distance-required", 0);
setprop("/fcs/minimum-usable-runway", 0);
setprop("/fcs/landing-distance-available-ft", 10000);
setprop("/fcs/landing-distance-margin", 0);
setprop("/afcs/annunciator/landing-distance-marginal", 0);
setprop("/afcs/annunciator/landing-distance-inadequate", 0);
setprop("/afcs/landing-distance-warning", 0);
setprop("/afcs/landing-distance-marginal-alert", 0);

# Spin recovery & departure warning monitoring function
var update_spin_recovery = func(dt) {
    # Get aircraft state
    var aoa = getprop("/orientation/alpha-deg") or 0;
    var roll_rate = getprop("/velocities/roll-rate-dps") or 0;
    var pitch_rate = getprop("/velocities/pitch-rate-dps") or 0;
    var airspeed_kt = getprop("/velocities/vcas-kts") or 0;
    var alt_agl = getprop("/position/altitude-agl-ft") or 0;
    var aileron_left = getprop("/surface-positions/aileron-left") or 0;
    var aileron_right = getprop("/surface-positions/aileron-right") or 0;
    
    # Track roll rate for spin detection
    setprop("/fcs/roll-rate-deg-sec", roll_rate);
    
    # Departure warning: high AOA (>15°) + high aileron deflection (>30°)
    var departure_warning = (aoa > 15.0 and abs(aileron_left) > 30.0) or
                            (aoa > 15.0 and abs(aileron_right) > 30.0);
    setprop("/afcs/annunciator/departure-warning", departure_warning ? 1 : 0);
    
    # Spin suspected: very high roll rate (>40 deg/sec) + high AOA (>18°) + low speed (<200 kt)
    var spin_suspected = (abs(roll_rate) > 40.0 and aoa > 18.0 and airspeed_kt < 200.0);
    setprop("/afcs/annunciator/spin-suspected", spin_suspected ? 1 : 0);
    
    # Recovery procedure guidance: if spin suspected, prompt recovery (center stick + opposite rudder)
    if (spin_suspected) {
        setprop("/afcs/annunciator/recover-rudder-center-stick", 1);
        # Print recovery reminder
        if (!getprop("/afcs/spin-recovery-active") or 0) {
            print(sprintf("SPIN RECOVERY: Center stick, apply opposite rudder. AOA=%.1f° Roll=%.0f°/s Speed=%.0f kt",
                  aoa, roll_rate, airspeed_kt));
            setprop("/afcs/spin-recovery-active", 1);
        }
    } else {
        setprop("/afcs/annunciator/recover-rudder-center-stick", 0);
        setprop("/afcs/spin-recovery-active", 0);
    }
    
    # Departure warning for pilot awareness (even if not in actual spin yet)
    if (departure_warning and !getprop("/afcs/departure-warning-active") or 0) {
        print(sprintf("DEPARTURE WARNING: High AOA (%.1f°) with aileron input (%.0f°) - Reduce pitch, level wings",
              aoa, abs(aileron_left) > abs(aileron_right) ? abs(aileron_left) : abs(aileron_right)));
        setprop("/afcs/departure-warning-active", 1);
    } elsif (!departure_warning) {
        setprop("/afcs/departure-warning-active", 0);
    }
};

# Initialize spin recovery properties
setprop("/fcs/roll-rate-deg-sec", 0);                  # Roll rate tracking
setprop("/afcs/annunciator/departure-warning", 0);    # Departure risk indicator
setprop("/afcs/annunciator/spin-suspected", 0);       # Spin-in-progress indicator
setprop("/afcs/annunciator/recover-rudder-center-stick", 0); # Recovery procedure
setprop("/afcs/spin-recovery-active", 0);             # Recovery procedure engaged flag
setprop("/afcs/departure-warning-active", 0);         # Departure warning engaged flag
setprop("/afcs/annunciator/weapons-fired", 0);

var last_time = systime();
var periodic_update = func {
    var now = systime();
    var dt = (now - last_time) / 1000.0;
    last_time = now;

    update_adc_static_correction(dt);
    update_landing_weight(dt);
    update_stall_warning(dt);
    update_refuel_probe(dt);
    update_stores_status(dt);
    update_spin_recovery(dt);
    update_landing_distance(dt);
    update_sas();
    update_att_hold(dt);
    update_alt_hold(dt);
    update_annunciators();
    # Avionics and cockpit instruments
    if (typeof("update_avionics") != "nil") update_avionics(dt);
    if (typeof("update_cockpit_instruments") != "nil") update_cockpit_instruments(dt);
    if (typeof("update_radar") != "nil") update_radar(dt);
    if (typeof("update_weapons") != "nil") update_weapons(dt);
    if (typeof("update_stores") != "nil") update_stores(dt);
    if (typeof("update_fuel") != "nil") update_fuel(dt);
    if (typeof("update_hydraulics_manager") != "nil") update_hydraulics_manager(dt);
    if (typeof("update_electrical_manager") != "nil") update_electrical_manager(dt);
    if (typeof("update_weapons_ballistics") != "nil") update_weapons_ballistics(dt);
    if (typeof("update_gears") != "nil") update_gears(dt);
    if (typeof("update_env") != "nil") update_env(dt);
    if (typeof("update_fcs_tuning") != "nil") update_fcs_tuning(dt);
    if (typeof("update_bindings") != "nil") update_bindings(dt);
    # Ensure yaw command property exists for FCS input (default 0)
    setprop("/afcs/att/yaw-cmd", 0);

    settimer(periodic_update, 0.1);
};
periodic_update();

# NOTE: Test harnesses available:
# - run_smoke() in TestHarness.nas
# - run_all_regression_tests() in RegressionTests.nas
# - run_preflight_checklist() in StartupSequencer.nas
# - run_startup_procedure() in StartupSequencer.nas

# TODO: Connect /afcs/att/roll-cmd, /afcs/att/pitch-cmd, /afcs/alt/pitch-cmd to FCS input chain for autopilot authority.
# TODO: Add more detailed failure logic and annunciator logic per NATOPS.