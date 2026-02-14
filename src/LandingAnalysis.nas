# LandingAnalysis.nas - Real-time landing distance calculator and approach stability advisor
# Computes safe landing performance and provides go/no-go guidance

var landing = {
    approach_mode: 0, # 0=normal, 1=approach (below 5000ft), 2=final (below 1000ft)
    approach_glideslope_deviation: 0, # feet (0 = on-slope)
    approach_speed_error: 0, # knots (0 = target speed)
    drift_angle: 0, # degrees (0 = aligned with runway)
    wind_component: 0, # knots (headwind positive)
    landing_distance_available: 10000, # feet (default runway)
    landing_distance_required: 2000, # feet (computed)
    margin_percentage: 0, # safety margin %
    go_nogo_decision: 1, # 1=go, 0=no-go
};

var init_landing_analysis = func() {
    setprop('/fdm/jsbsim/landing/approach-mode', 0);
    setprop('/fdm/jsbsim/landing/glideslope-error-ft', 0);
    setprop('/fdm/jsbsim/landing/speed-error-kt', 0);
    setprop('/fdm/jsbsim/landing/drift-angle-deg', 0);
    setprop('/fdm/jsbsim/landing/headwind-kt', 0);
    setprop('/fdm/jsbsim/landing/distance-required-ft', 0);
    setprop('/fdm/jsbsim/landing/distance-available-ft', 10000);
    setprop('/fdm/jsbsim/landing/safety-margin-pct', 0);
    setprop('/fdm/jsbsim/landing/go-nogo', 1);
};

var determine_approach_mode = func() {
    var altitude_agl = getprop('/position/altitude-agl-ft') or 0;
    var mode = 0;
    
    if (altitude_agl < 1000) {
        mode = 2; # final
    } elsif (altitude_agl < 5000) {
        mode = 1; # approach
    }
    
    landing.approach_mode = mode;
    setprop('/fdm/jsbsim/landing/approach-mode', mode);
};

var compute_glideslope_error = func() {
    # 3-degree standard glideslope
    var altitude_agl = getprop('/position/altitude-agl-ft') or 0;
    var distance_to_threshold = getprop('/fdm/jsbsim/landing/distance-to-touch-ft') or 0; # need prop
    
    if (distance_to_threshold < 0.1) return; # not near runway
    
    # Standard 3° slope: altitude = distance * tan(3°) ≈ distance * 0.052
    var ideal_altitude = distance_to_threshold * math.tan(3 * math.pi / 180);
    landing.approach_glideslope_deviation = altitude_agl - ideal_altitude;
    
    setprop('/fdm/jsbsim/landing/glideslope-error-ft', landing.approach_glideslope_deviation);
};

var compute_speed_error = func() {
    # Target approach speed: ~150-160 knots for F-4 with gear/flaps down
    var target_speed = 155; # knots
    var actual_speed = getprop('/velocities/airspeed-kt') or 0;
    
    landing.approach_speed_error = actual_speed - target_speed;
    setprop('/fdm/jsbsim/landing/speed-error-kt', landing.approach_speed_error);
};

var compute_drift_and_wind = func() {
    # Compute crosswind component and drift
    var track = getprop('/orientation/track-deg') or 0;
    var heading = getprop('/orientation/heading-deg') or 0;
    var true_track = getprop('/orientation/track-true-deg') or 0;
    var wind_from = getprop('/environment/wind-from-heading-deg') or 0;
    var wind_speed = getprop('/environment/wind-speed-kt') or 0;
    
    # Runway heading (assume aligned with true north for simplicity; could be param)
    var runway_heading = 0; # degrees (north)
    
    # Relative wind direction
    var relative_wind = wind_from - runway_heading;
    
    # Headwind/tailwind component
    landing.wind_component = wind_speed * math.cos(relative_wind * math.pi / 180);
    setprop('/fdm/jsbsim/landing/headwind-kt', landing.wind_component);
    
    # Drift angle (crabbing)
    landing.drift_angle = heading - runway_heading;
    setprop('/fdm/jsbsim/landing/drift-angle-deg', landing.drift_angle);
};

var compute_landing_distance_required = func() {
    # Landing distance computation based on:
    # 1. Actual weight
    # 2. Actual airspeed
    # 3. Headwind/tailwind
    # 4. Runway altitude and temperature
    # 5. Drag chute deployment
    
    var weight = getprop('/fdm/jsbsim/inertia/weight-lbs') or 54000;
    var speed = getprop('/velocities/airspeed-kt') or 160;
    var headwind = landing.wind_component;
    var alt = getprop('/position/altitude-ft') or 0;
    var temp = getprop('/environment/temperature-degc') or 15;
    
    # Baseline landing distance: ~4000 ft at max weight, SL, no wind
    # Decreases with every knot of headwind
    var distance_baseline = 4500; # feet (conservative)
    
    # Headwind benefit: -x feet per knot
    var headwind_factor = 1.0 - (headwind / 100.0);
    headwind_factor = math.max(0.5, headwind_factor); # tailwind penalty
    
    # Speed factor: distance ~= v^2 relationship (more or less)
    var speed_factor = math.pow(speed / 150.0, 2); # normalized to 150 kt target
    
    # Weight factor
    var weight_factor = weight / 54000; # normalized to 54000 lbs
    
    # High altitude/temp penalty
    var density_ratio = (288 / (temp + 273)) * ((29.92 - alt * 0.001) / 29.92);
    density_ratio = math.max(0.5, density_ratio);
    
    landing.landing_distance_required = distance_baseline * speed_factor * weight_factor * 
                                       headwind_factor / density_ratio;
    
    # Add safety margin (15% regulatory + 0% discretionary)
    landing.landing_distance_required *= 1.15;
    
    setprop('/fdm/jsbsim/landing/distance-required-ft', landing.landing_distance_required);
};

var compute_safety_margin = func() {
    var available = landing.landing_distance_available;
    var required = landing.landing_distance_required;
    
    var margin = available - required;
    landing.margin_percentage = (margin / available) * 100;
    
    setprop('/fdm/jsbsim/landing/safety-margin-pct', landing.margin_percentage);
};

var make_go_nogo_decision = func() {
    # Go criteria:
    # 1. Safety margin > 15%
    # 2. Glideslope error < 200 ft
    # 3. Speed error < ±15 kt
    # 4. Drift angle < ±10 degrees
    
    var go = 1;
    var reason = '';
    
    if (landing.margin_percentage < 15) {
        go = 0;
        reason = 'Insufficient landing distance';
    }
    
    if (math.abs(landing.approach_glideslope_deviation) > 200) {
        go = 0;
        reason = 'Not on glideslope';
    }
    
    if (math.abs(landing.approach_speed_error) > 15) {
        go = 0;
        reason = 'Speed unstable';
    }
    
    if (math.abs(landing.drift_angle) > 10) {
        go = 0;
        reason = 'Excessive drift (not aligned with runway)';
    }
    
    landing.go_nogo_decision = go;
    setprop('/fdm/jsbsim/landing/go-nogo', go);
    
    if (!go and landing.approach_mode > 0) {
        print('LANDING: NO-GO - '~reason);
    }
};

var display_landing_cues = func() {
    # Pilot guidance info (would appear on HUD in real aircraft)
    if (landing.approach_mode < 1) return; # not in approach
    
    var cue_string = '';
    
    # Speed guidance
    if (landing.approach_speed_error > 5) {
        cue_string = cue_string ~ 'SLOW: ';
    } elsif (landing.approach_speed_error < -5) {
        cue_string = cue_string ~ 'FAST: ';
    } else {
        cue_string = cue_string ~ 'SPEED OK: ';
    }
    
    # Slope guidance
    if (landing.approach_glideslope_deviation > 100) {
        cue_string = cue_string ~ 'HIGH, ';
    } elsif (landing.approach_glideslope_deviation < -100) {
        cue_string = cue_string ~ 'LOW, ';
    } else {
        cue_string = cue_string ~ 'SLOPE OK, ';
    }
    
    # Alignment guidance
    if (math.abs(landing.drift_angle) > 3) {
        cue_string = cue_string ~ 'ALIGN RUNWAY';
    } else {
        cue_string = cue_string ~ 'ALIGNED';
    }
    
    if (landing.margin_percentage < 30) {
        cue_string = cue_string ~ ' [SHORT FIELD]';
    }
    
    setprop('/fdm/jsbsim/landing/cue-string', cue_string);
};

var update_landing_analysis = func(dt) {
    determine_approach_mode();
    
    if (landing.approach_mode > 0) {
        compute_glideslope_error();
        compute_speed_error();
        compute_drift_and_wind();
        compute_landing_distance_required();
        compute_safety_margin();
        make_go_nogo_decision();
        display_landing_cues();
    }
};

init_landing_analysis();
