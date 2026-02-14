# FireDetectionSuppression.nas - Engine/cargo fire detection and suppression
# Models fire detection loops in engines and cargo bay, Halon suppression cartridges

var fire_system = {
    fire_detected: [0, 0], # per engine
    fire_loop_temperature: [0, 0],
    fire_loop_bay_temp: 0,
    halon_quantity: [0.75, 0.75], # 75% full per engine
    halon_discharge_rate: 0.15, # fraction per second when active
    suppression_active: [0, 0],
    cargo_fire_detected: 0,
};

var init_fire_detection = func() {
    setprop('/engines/engine[0]/fire-detected', 0);
    setprop('/engines/engine[0]/fire-ext-armed', 0);
    setprop('/engines/engine[0]/fire-ext-discharge', 0);
    setprop('/engines/engine[0]/halon-qty', 75);
    
    setprop('/engines/engine[1]/fire-detected', 0);
    setprop('/engines/engine[1]/fire-ext-armed', 0);
    setprop('/engines/engine[1]/fire-ext-discharge', 0);
    setprop('/engines/engine[1]/halon-qty', 75);
    
    setprop('/fdm/jsbsim/cargo-bay/fire-detected', 0);
    setprop('/afcs/annunciator/fire-warning', 0);
};

var check_engine_fire = func(eng_idx, dt) {
    var n1 = getprop('/engines/engine['~eng_idx~']/n1-percent') or 0;
    var egt = getprop('/engines/engine['~eng_idx~']/egt-degc') or 0;
    var engine_on = n1 > 15;
    
    # Fire loop temperature rise in hot section
    var fire_loop_temp = egt * 0.8 + (rand() - 0.5) * 50; # noisy sensor
    fire_system.fire_loop_temperature[eng_idx] = fire_loop_temp;
    
    # Fire detection logic: over-temp in engine compartment or fuel leak + heat + ignition probability
    var fire_bool = 0;
    if (engine_on) {
        # Most fires are fuel-related in jet engines
        var fuel_flow = getprop('/engines/engine['~eng_idx~']/fuel-flow-pph') or 0;
        var comp_pressure = getprop('/engines/engine['~eng_idx~']/comp-pressure-ratio') or 1.0;
        
        # High fuel flow + high EGT + high compression = risk
        if (egt > 750 and fuel_flow > 9000 and comp_pressure > 8) {
            fire_bool = rand() < 0.002; # ~0.2% chance per update if conditions extreme
        }
        
        # Hydraulic fluid leak + hot surface ignition (separate fire loop)
        var hyd_press = getprop('/hydraulics/main-pump-psi') or 0;
        if (hyd_press > 3500) { # high pressure leak risk
            fire_bool = fire_bool or (rand() < 0.001);
        }
    }
    
    fire_system.fire_detected[eng_idx] = fire_bool;
    setprop('/engines/engine['~eng_idx~']/fire-detected', fire_bool ? 1 : 0);
    
    # Auto-fire warning to annunciator
    if (fire_bool) {
        setprop('/afcs/annunciator/fire-warning', 1);
    }
};

var manage_halon_discharge = func(eng_idx, dt) {
    var fire_det = getprop('/engines/engine['~eng_idx~']/fire-detected') or 0;
    var discharge_btn = getprop('/engines/engine['~eng_idx~']/fire-ext-discharge') or 0;
    var armed = getprop('/engines/engine['~eng_idx~']/fire-ext-armed') or 0;
    
    # Discharge starts if pilot presses button AND armed
    if (discharge_btn and armed and fire_system.halon_quantity[eng_idx] > 0) {
        fire_system.halon_quantity[eng_idx] -= fire_system.halon_discharge_rate * dt;
        fire_system.halon_quantity[eng_idx] = math.max(0, fire_system.halon_quantity[eng_idx]);
        
        # Suppress fire if enough Halon remains
        var suppress_prob = math.max(0, fire_system.halon_quantity[eng_idx] * 0.5); # 50% effective per unit
        if (rand() < suppress_prob * dt) {
            fire_system.fire_detected[eng_idx] = 0;
            setprop('/engines/engine['~eng_idx~']/fire-detected', 0);
            print('FIRE: Halon discharge on engine '~eng_idx~' - fire suppressed');
        }
    }
    
    var qty_pct = math.round(fire_system.halon_quantity[eng_idx] * 100);
    setprop('/engines/engine['~eng_idx~']/halon-qty', qty_pct);
};

var check_cargo_fire = func(dt) {
    # Cargo bay fire from cargo heating during high-speed climb or hypersonic maneuver
    var airspeed = getprop('/velocities/airspeed-kt') or 0;
    var altitude = getprop('/position/altitude-ft') or 0;
    
    # Cargo bay heating model (aerodynamic):
    # T_cargo = ambient + (q * 0.83) where q = 0.5 * rho * V^2
    # At Mach 2, q ~10,000 psf -> T_rise ~80°C
    var mach = getprop('/velocities/mach') or 0;
    var ambient_temp = getprop('/environment/temperature-degc') or 15;
    var dynamic_pressure = 0.5 * getprop('/environment/density-slugft3') * airspeed * airspeed / 295.0; # lbf/ft²
    var cargo_temp_rise = dynamic_pressure * 0.0001; # rough conversion to ΔT
    var cargo_temp = ambient_temp + cargo_temp_rise;
    
    # Cargo (ordnance, fuel pods) ignition risk
    if (cargo_temp > 150) {
        fire_system.cargo_fire_detected = rand() < 0.001;
    } else {
        fire_system.cargo_fire_detected = 0;
    }
    
    setprop('/fdm/jsbsim/cargo-bay/fire-detected', fire_system.cargo_fire_detected ? 1 : 0);
    setprop('/fdm/jsbsim/cargo-bay/temperature-c', cargo_temp);
    
    if (fire_system.cargo_fire_detected) {
        setprop('/afcs/annunciator/fire-warning', 1);
    }
};

var update_fire_system = func(dt) {
    # Check fires on both engines
    check_engine_fire(0, dt);
    check_engine_fire(1, dt);
    
    # Manage Halon discharge
    manage_halon_discharge(0, dt);
    manage_halon_discharge(1, dt);
    
    # Check cargo fire
    check_cargo_fire(dt);
    
    # Clear fire warning if no active fires
    if (!fire_system.fire_detected[0] and !fire_system.fire_detected[1] and !fire_system.cargo_fire_detected) {
        setprop('/afcs/annunciator/fire-warning', 0);
    }
};

init_fire_detection();
