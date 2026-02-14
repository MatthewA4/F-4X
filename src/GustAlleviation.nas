# GustAlleviation.nas - Automatic wind gust load alleviation system
# Reduces structural loads during turbulence or wind shear by automatic control inputs

var gust_alleviation = {
    system_armed: 1,
    gust_detected: 0,
    vertical_gust: 0, # ft/sec
    lateral_gust: 0,
    longitudinal_gust: 0,
    wing_load_factor: 1.0, # g-load on wings
    max_safe_wing_load: 8.5, # g (F-4 limit ~8.5-9g)
    auto_pitch_correction: 0, # pitch input to alleviate
    auto_roll_correction: 0, # roll input to alleviate
};

var init_gust_alleviation = func() {
    setprop('/afcs/gust-alleviation-armed', 1);
    setprop('/afcs/gust-detected', 0);
    setprop('/afcs/vertical-gust-fts', 0);
    setprop('/afcs/wing-load-g', 1.0);
    setprop('/afcs/gust-relief-active', 0);
};

var compute_gust_components = func() {
    # Estimate wind gusts from vertical speed and wind changes
    # Compare aircraft vertical velocity to commanded vertical velocity
    
    var vz_actual = getprop('/velocities/vertical-speed-fps') or 0;
    var wind_speed = getprop('/environment/wind-speed-kt') or 0;
    var prev_wind = getprop('/environment/prev-wind-speed') or wind_speed;
    setprop('/environment/prev-wind-speed', wind_speed);
    
    # Gust detection: sudden change in wind or vertical velocity
    var gust_change = math.abs(wind_speed - prev_wind);
    
    # Vertical gust: sudden vertical wind component
    # Assume updraft/downdraft as vertical gust
    if (vz_actual > 500) { # strong climb (maybe updraft)
        gust_alleviation.vertical_gust = vz_actual;
    } elsif (vz_actual < -500) { # strong descent (maybe downdraft)
        gust_alleviation.vertical_gust = vz_actual;
    } else {
        gust_alleviation.vertical_gust = 0;
    }
    
    # Wind shear: lateral and longitudinal gust from wind direction change
    var wind_from = getprop('/environment/wind-from-heading-deg') or 0;
    var prev_wind_from = getprop('/environment/prev-wind-from') or wind_from;
    setprop('/environment/prev-wind-from', wind_from);
    
    var wind_dir_change = wind_from - prev_wind_from;
    gust_alleviation.lateral_gust = wind_speed * math.sin(wind_dir_change * math.pi / 180);
    
    setprop('/afcs/vertical-gust-fts', gust_alleviation.vertical_gust);
};

var compute_wing_load = func() {
    # Wing load is primarily determined by:
    # 1. Vertical acceleration (primary load path)
    # 2. High-speed turn with high bank angle
    # 3. Sudden control inputs
    # 4. Wind gusts
    
    var g_normal = getprop('/accelerations/n-accel-glue') or 1; # vertical g
    var g_side = getprop('/accelerations/a-accel-glue') or 0; # lateral g
    
    # Resultant g-load (rough approximation)
    var g_resultant = math.sqrt(g_normal * g_normal + g_side * g_side);
    
    # Wing load factor
    gust_alleviation.wing_load_factor = g_resultant;
    setprop('/afcs/wing-load-g', g_resultant);
    
    # Detect overload condition
    if (g_resultant > gust_alleviation.max_safe_wing_load) {
        print('GUST ALLEVIATION: Wing load WARNING - '~g_resultant~'g exceeds limit');
    }
};

var engage_gust_relief = func() {
    # If wing load too high, apply automatic corrective inputs
    # Pitch: reduce angle of attack to decrease lift and loading
    # Roll: level wings if banked too steep
    
    var wing_load = gust_alleviation.wing_load_factor;
    var max_load = gust_alleviation.max_safe_wing_load;
    
    if (wing_load > max_load * 0.9) {
        # Load approaching limit; engage relief
        gust_alleviation.auto_pitch_correction = -0.05; # slight nose-down
        setprop('/afcs/gust-relief-active', 1);
        
        print('GUST ALLEVIATION: Relief active - load='~wing_load~'g');
    } elsif (wing_load > max_load) {
        # Load exceeding limit; more aggressive relief
        gust_alleviation.auto_pitch_correction = -0.15; # aggressive nose-down
        print('GUST ALLEVIATION: AGGRESSIVE RELIEF - load='~wing_load~'g');
    } else {
        gust_alleviation.auto_pitch_correction = 0;
        setprop('/afcs/gust-relief-active', 0);
    }
};

var apply_relief_control_inputs = func() {
    # Apply pitch correction to flight control system
    # (In reality, this would integrate with the FCS elevator servo)
    
    if (gust_alleviation.auto_pitch_correction != 0) {
        # Get current elevator position
        var elev = getprop('/controls/flight/elevator') or 0;
        
        # Apply relief input (proportional to load excess)
        var relief_input = gust_alleviation.auto_pitch_correction;
        var new_elev = elev + relief_input;
        
        # Don't let relief override pilot input beyond certain degree
        // could limit to 90% pilot control, 10% relief
        
        setprop('/afcs/auto-gust-pitch-input', relief_input);
    }
};

var update_gust_alleviation = func(dt) {
    var armed = getprop('/afcs/gust-alleviation-armed') or 1;
    if (!armed) return;
    
    compute_gust_components();
    compute_wing_load();
    engage_gust_relief();
    apply_relief_control_inputs();
};

init_gust_alleviation();
