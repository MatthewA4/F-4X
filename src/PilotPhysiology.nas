# PilotPhysiology.nas - Pilot G-awareness, G-LOC (loss of consciousness) modeling
# Critical for fighter operations; high-g maneuvers can cause temporary unconsciousness

var pilot = {
    g_exposure_accumulated: 0, # cumulative g-seconds for fatigue
    conscious: 1,
    blood_pressure_cerebral: 100, # mmHg (normal ~120)
    consciousness_threshold: 3.5, # g-units at which LOC becomes possible
    anti_g_suit_active: 0,
    anti_g_suit_effectiveness: 0.5, # reduces effective g by 50%
    tolerance_baseline: 4.5, # g-units baseline consciousness limit (trained pilot)
    recovery_time: 2.0, # seconds to regain consciousness after g reduction
    time_unconscious: 0,
    pilot_workload: 0, # 0-1 scale affects g-tolerance
};

var init_pilot_physiology = func() {
    setprop('/pilot/conscious', 1);
    setprop('/pilot/effective-g-load', 0);
    setprop('/pilot/g-loc-status', 'conscious');
    setprop('/pilot/g-duration-sec', 0);
    setprop('/pilot/anti-g-suit', 0);
    setprop('/pilot/cerebral-blood-pressure', 100);
    setprop('/pilot/vision-blackout', 0); # 0.0 = normal, 1.0 = complete blackout
    setprop('/pilot/vision-redout', 0);
    setprop('/afcs/annunciator/pilot-unconscious', 0);
};

var update_g_forces = func(dt) {
    # Get actual g-load from FDM
    var g_load = getprop('/accelerations/n-accel-glue') or 0; # +1g = 1g, -1g = -1g (inverted)
    
    # F-4 pilots typically wear anti-g suit (G-suit)
    # Effective g_limit increases from 4.5 to ~6.5 with g-suit
    var g_suit = (getprop('/pilot/anti-g-suit') or 0);
    var effective_tolerance = pilot.tolerance_baseline;
    if (g_suit) {
        effective_tolerance = pilot.tolerance_baseline + 2.0; # +2g with suit
    }
    
    # Workload reduces g-tolerance by ~5% per workload unit
    effective_tolerance *= (1.0 - pilot.pilot_workload * 0.05);
    
    setprop('/pilot/effective-g-load', g_load);
    setprop('/pilot/g-tolerance-limit', effective_tolerance);
};

var update_consciousness = func(dt) {
    var g_load = getprop('/accelerations/n-accel-glue') or 0;
    var abs_g = math.abs(g_load);
    var effective_tolerance = getprop('/pilot/g-tolerance-limit') or 4.5;
    
    # Cerebral blood pressure model (Korotkoff method)
    # P_cerebral = P_mean - (ρ * g * h) where h = height of head above heart
    # In fighter, head can be ~1 meter above heart on upright seat
    # Gravity field effect: ~10.2 cmH2O per 1g per meter
    var blood_pressure_loss = abs_g * 10.2; # mmHg loss per g at 1 meter
    var cerebral_bp = 100 - blood_pressure_loss;
    
    pilot.blood_pressure_cerebral = cerebral_bp;
    setprop('/pilot/cerebral-blood-pressure', cerebral_bp);
    
    # LOC threshold: cerebral blood pressure < 40 mmHg (syncope)
    var loc_threshold = 40;
    var loc_margin = cerebral_bp - loc_threshold;
    
    # If already unconscious:
    if (!pilot.conscious) {
        pilot.time_unconscious += dt;
        
        # Vision effects during LOC
        setprop('/pilot/vision-blackout', 1.0); # complete blackout
        setprop('/pilot/vision-redout', 0);
        
        # Regain consciousness when g-load reduces below tolerance + recovery margin
        if (abs_g < (effective_tolerance - 1.5)) {
            if (pilot.time_unconscious > pilot.recovery_time) {
                pilot.conscious = 1;
                pilot.time_unconscious = 0;
                setprop('/pilot/g-loc-status', 'regaining-consciousness');
                print('PILOT: Regained consciousness after '~pilot.time_unconscious~' seconds');
            }
        }
    } else {
        # Consciousness check during sustained high-g
        pilot.time_unconscious = 0;
        
        if (abs_g > effective_tolerance) {
            # LOC probability increases with g excess
            var g_excess = abs_g - effective_tolerance;
            var loc_probability = 0.001 * g_excess * g_excess; # quadratic risk
            
            if (rand() < loc_probability * dt) {
                pilot.conscious = 0;
                setprop('/pilot/g-loc-status', 'unconscious');
                setprop('/afcs/annunciator/pilot-unconscious', 1);
                print('PILOT: Loss of consciousness at '~abs_g~'g for '~effective_tolerance~'g tolerance');
            }
            
            # Vision greyout/blackout warning as approach threshold
            var margin_to_loc = effective_tolerance - abs_g;
            if (margin_to_loc < 1.5 and margin_to_loc > 0) {
                # Vision darkening (greyout) - edges of vision first
                setprop('/pilot/vision-blackout', 1.0 - (margin_to_loc / 1.5));
            } elsif (margin_to_loc <= 0) {
                setprop('/pilot/vision-blackout', 1.0);
            } else {
                setprop('/pilot/vision-blackout', 0);
            }
        } else {
            setprop('/pilot/g-loc-status', 'conscious');
            setprop('/pilot/vision-blackout', 0);
            setprop('/afcs/annunciator/pilot-unconscious', 0);
        }
    }
    
    # Redout during negative-g (inverted flight)
    if (g_load < -3) {
        var redout_intensity = math.min(1.0, (-g_load - 3) / 2.0);
        setprop('/pilot/vision-redout', redout_intensity);
    } else {
        setprop('/pilot/vision-redout', 0);
    }
};

var update_g_accumulation = func(dt) {
    var g_load = getprop('/accelerations/n-accel-glue') or 0;
    var abs_g = math.abs(g_load);
    
    # Pilot fatigue accumulates during sustained high-g
    if (abs_g > 3.0) {
        pilot.g_exposure_accumulated += abs_g * dt;
    }
    
    setprop('/pilot/g-duration-sec', pilot.g_exposure_accumulated);
    
    # Pilot workload increases with fatigue
    # After 30 seconds of >3g, workload becomes significant
    pilot.pilot_workload = math.min(1.0, pilot.g_exposure_accumulated / 30.0);
};

var update_pilot_control_inputs = func() {
    # When unconscious, pilot cannot provide inputs
    if (!pilot.conscious) {
        # Stabilize controls (no deflections)
        setprop('/controls/flight/aileron', 0); # ideally should not bleed current input,
        setprop('/controls/flight/elevator', 0); # but this forces it for safety
        # Rudder left at current position (feet on pedals)
    }
};

var update_pilot_physiology = func(dt) {
    update_g_forces(dt);
    update_consciousness(dt);
    update_g_accumulation(dt);
    update_pilot_control_inputs();
};

init_pilot_physiology();
