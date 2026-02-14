# FuelCGManagement.nas - fuel distribution and center-of-gravity effects
# Models fuel tank sequencing, CG shift, and longitudinal stability impact

var fuel_cg = {
    tank_positions: {
        feed: 8.5,    # main feed tanks (fuselage center) - MAC position
        aux: 7.8,     # auxiliary tanks (slightly fwd)
        drop: 9.2,    # drop tanks (slightly aft)
    },
    current_cg: 8.5,
    cg_margin: 5.0,   # stability margin in % MAC
};

var init_fuel_cg = func() {
    setprop('/fdm/jsbsim/inertia/cg-position', fuel_cg.current_cg);
    setprop('/fdm/jsbsim/inertia/cg-margin', fuel_cg.cg_margin);
    setprop('/afcs/annunciator/cg-limits-warning', 0);
    setprop('/afcs/annunciator/aft-cg-warning', 0);
};

var compute_fuel_cg = func() {
    # Compute total aircraft CG based on fuel distribution
    # Simple model: interpolate CG based on tank fill levels
    
    var feed_fuel = getprop('/propulsion/tank[0]/contents-lbs') or 0;
    var aux1_fuel = getprop('/propulsion/tank[2]/contents-lbs') or 0;
    var aux2_fuel = getprop('/propulsion/tank[3]/contents-lbs') or 0;
    var total_fuel = feed_fuel + aux1_fuel + aux2_fuel;
    
    if (total_fuel < 1) {
        # if no fuel, assume empty CG (typically aft)
        fuel_cg.current_cg = 9.0;
    } else {
        # Weighted average CG position
        var weighted_cg = 0;
        weighted_cg += feed_fuel * fuel_cg.tank_positions.feed;
        weighted_cg += (aux1_fuel + aux2_fuel) * fuel_cg.tank_positions.aux;
        fuel_cg.current_cg = weighted_cg / total_fuel;
    }
    
    # Stability margin (from design CG at ~8.5% MAC)
    var empty_cg = 9.0;
    var neutral_point = 8.9; # ~11% MAC back from leading edge (typical fighter)
    fuel_cg.cg_margin = (neutral_point - fuel_cg.current_cg) * 100 / 5.0; # convert to % MAC
    
    # Limit CG to forward and aft boundaries
    fuel_cg.current_cg = math.max(7.8, math.min(10.0, fuel_cg.current_cg));
    fuel_cg.cg_margin = math.max(-15, math.min(15, fuel_cg.cg_margin));
    
    setprop('/fdm/jsbsim/inertia/cg-position', fuel_cg.current_cg);
    setprop('/fdm/jsbsim/inertia/cg-margin', fuel_cg.cg_margin);
};

var check_cg_limits = func() {
    # Warn if CG approaches limits
    # Forward CG limit: ~6.5% MAC (lose pitch authority down)
    # Aft CG limit: ~14% MAC (lose pitch authority up, can depart)
    
    var fwd_limit = 7.8;
    var aft_limit = 10.0;
    var fwd_warn = 8.2;
    var aft_warn = 9.6;
    
    if (fuel_cg.current_cg < fwd_limit or fuel_cg.current_cg > aft_limit) {
        setprop('/afcs/annunciator/cg-limits-warning', 1);
        print(sprintf('CG OUT OF LIMITS: %.2f %% MAC', fuel_cg.current_cg));
    } elsif (fuel_cg.current_cg > aft_warn) {
        setprop('/afcs/annunciator/aft-cg-warning', 1);
        print(sprintf('WARNING: Aft CG: %.2f %% MAC - Pitch control limit', fuel_cg.current_cg));
    } else {
        setprop('/afcs/annunciator/cg-limits-warning', 0);
        setprop('/afcs/annunciator/aft-cg-warning', 0);
    }
};

var update_fuel_cg = func(dt) {
    compute_fuel_cg();
    check_cg_limits();
};

init_fuel_cg();
