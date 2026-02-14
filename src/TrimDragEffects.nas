# TrimDragEffects.nas - Elevator, aileron, rudder trim contributions to total drag
# Control surface deflection increases drag even in "trim" mode; models this drag penalty

var trim_drag = {
    elevator_trim_range: 30,  # degrees (±15)
    aileron_trim_range: 10,   # degrees (±5)
    rudder_trim_range: 20,    # degrees (±10)
    
    # Drag coefficient increments per degree of trim deflection
    # Based on typical fighter aircraft aerodynamic characteristics
    cd_per_deg_elevator: 0.00008,
    cd_per_deg_aileron: 0.00006,
    cd_per_deg_rudder: 0.00015,
};

var init_trim_drag = func() {
    setprop('/controls/flight/elevator-trim', 0);
    setprop('/controls/flight/aileron-trim', 0);
    setprop('/controls/flight/rudder-trim', 0);
    
    setprop('/aerodynamics/trim-drag-cd', 0);
    setprop('/aerodynamics/trim-drag-contribution', 0);
};

var compute_trim_drag_cd = func() {
    # Get current trim positions (normalized -1 to +1)
    var elev_trim = getprop('/controls/flight/elevator-trim') or 0;
    var aileron_trim = getprop('/controls/flight/aileron-trim') or 0;
    var rudder_trim = getprop('/controls/flight/rudder-trim') or 0;
    
    # Convert to physical degrees
    var elev_deg = elev_trim * trim_drag.elevator_trim_range / 2.0; # ±degree
    var aileron_deg = aileron_trim * trim_drag.aileron_trim_range / 2.0;
    var rudder_deg = rudder_trim * trim_drag.rudder_trim_range / 2.0;
    
    # Calculate drag contribution (use absolute values since deflection in either direction adds drag)
    var cd_elev = math.abs(elev_deg) * trim_drag.cd_per_deg_elevator;
    var cd_aileron = math.abs(aileron_deg) * trim_drag.cd_per_deg_aileron;
    var cd_rudder = math.abs(rudder_deg) * trim_drag.cd_per_deg_rudder;
    
    var total_trim_cd = cd_elev + cd_aileron + cd_rudder;
    
    setprop('/aerodynamics/trim-drag-cd', total_trim_cd);
    
    # Also track elevator trim specifically (most significant contributor)
    var elev_cd = math.abs(elev_deg) * trim_drag.cd_per_deg_elevator;
    setprop('/aerodynamics/elevator-trim-drag-cd', elev_cd);
    
    return total_trim_cd;
};

var compute_trim_moment_coupling = func() {
    # Deflected control surfaces also couple to moments when CG is not at aerodynamic center
    # Elevator deflection -> pitch moment delta
    # Aileron deflection -> roll moment (opposing trim input)
    # Rudder deflection -> minor pitch moment (sideslip effect)
    
    var elev_trim = getprop('/controls/flight/elevator-trim') or 0;
    var aileron_trim = getprop('/controls/flight/aileron-trim') or 0;
    var rudder_trim = getprop('/controls/flight/rudder-trim') or 0;
    
    # Elevator trim moment: translates to additional pitch-up/down tendency
    # Needs to be trimmed manually or via autopilot
    var pitch_moment_delta = elev_trim * 0.02; # radians per control input
    setprop('/aerodynamics/elevator-trim-moment-rad', pitch_moment_delta);
    
    # Aileron trim moment: typically small but noticeable
    var roll_moment_delta = aileron_trim * 0.01;
    setprop('/aerodynamics/aileron-trim-moment-rad', roll_moment_delta);
};

var update_trim_drag = func(dt) {
    compute_trim_drag_cd();
    compute_trim_moment_coupling();
};

init_trim_drag();
