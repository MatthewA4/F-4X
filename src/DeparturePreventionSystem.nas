# DeparturePreventionSystem.nas - Automatic stall/departure prevention logic
# Advanced AFCS function designed to prevent wing drop or directional instability at high AOA

var departure_prevention = {
    system_active: 1, # can be disabled by pilot
    in_high_aoa_regime: 0,
    departure_warning_level: 0, # 0-1 degradation scale
    bank_limit_active: 0,
    stick_force_gain: 1.0, # reduced if approaching departure
};

var init_departure_prevention = func() {
    setprop('/afcs/departure-prevention-armed', 1);
    setprop('/afcs/departure-warning', 0);
    setprop('/afcs/departure-immanent', 0);
    setprop('/afcs/bank-limit-active', 0);
    setprop('/afcs/stick-force-aug-factor', 1.0);
};

var detect_departure_risk = func() {
    # AoA above critical threshold increases departure risk
    var aoa = getprop('/orientation/alpha-deg') or 0;
    var aoa_critical = 20.0; # units (F-4 departure risk starts ~20°)
    var aoa_immanent = 24.0; # imminent departure
    
    var yaw_rate = getprop('/orientation/yaw-rate-degps') or 0;
    var roll_rate = getprop('/orientation/roll-rate-degps') or 0;
    var pitch_rate = getprop('/orientation/pitch-rate-degps') or 0;
    
    var g_load = getprop('/accelerations/n-accel-glue') or 1;
    
    # Departure usually triggered by:
    # 1. High AOA with asymmetric control input
    # 2. Rapid roll at high AOA
    # 3. Yaw rate build-up during tight turn
    
    var asymmetric_control = 0;
    var aileron = getprop('/controls/flight/aileron') or 0;
    var rudder = getprop('/controls/flight/rudder') or 0;
    if (math.abs(aileron) > 0.7 or math.abs(rudder) > 0.7) {
        asymmetric_control = 1;
    }
    
    var departure_risk = 0;
    
    if (aoa > aoa_critical) {
        departure_prevention.in_high_aoa_regime = 1;
        departure_risk = (aoa - aoa_critical) / (aoa_immanent - aoa_critical);
        
        # Asymmetric control at high AOA increases risk exponentially
        if (asymmetric_control) {
            departure_risk *= 1.5;
        }
        
        # Rapid yaw/roll at high AOA
        if (math.abs(yaw_rate) > 20 or math.abs(roll_rate) > 30) {
            departure_risk *= 1.5;
        }
    } else {
        departure_prevention.in_high_aoa_regime = 0;
        departure_risk = 0;
    }
    
    departure_risk = math.min(1.0, departure_risk); # clamp
    departure_prevention.departure_warning_level = departure_risk;
    
    setprop('/afcs/departure-warning', departure_risk > 0.3 ? 1 : 0);
    setprop('/afcs/departure-immanent', departure_risk > 0.7 ? 1 : 0);
    
    if (departure_risk > 0.7) {
        print('DEPARTURE: IMMINENT - AOA='~aoa~', risk='~departure_risk);
    } elsif (departure_risk > 0.3) {
        print('DEPARTURE: WARNING - AOA='~aoa~', risk='~departure_risk);
    }
    
    return departure_risk;
};

var apply_departure_prevention_inputs = func(dt) {
    # If departure imminent, AFCS applies corrective inputs
    # Priority: nose down (pitch), then level wings (roll)
    
    var departure_risk = departure_prevention.departure_warning_level;
    if (departure_risk < 0.5) return; # no intervention below this threshold
    
    var aoa = getprop('/orientation/alpha-deg') or 0;
    var roll = getprop('/orientation/roll-deg') or 0;
    var yaw_rate = getprop('/orientation/yaw-rate-degps') or 0;
    
    # Pitch command: nose down if AOA high
    if (aoa > 20) {
        var pitch_cmd = getprop('/afcs/att/pitch-cmd') or 0;
        pitch_cmd = pitch_cmd - departure_risk * 5.0; # nose down command proportional to risk
        setprop('/afcs/att/pitch-cmd', pitch_cmd);
    }
    
    # Roll command: wings level if yaw out of control
    if (math.abs(yaw_rate) > 30) {
        var roll_cmd = getprop('/afcs/att/roll-cmd') or 0;
        roll_cmd = -roll / 20.0; # proportional control to level wings
        setprop('/afcs/att/roll-cmd', roll_cmd);
    }
};

var apply_control_limiting = func(dt) {
    # Reduce control authority as departure risk increases
    # Prevents pilot from making things worse
    
    var departure_risk = departure_prevention.departure_warning_level;
    
    if (departure_risk > 0.5) {
        # Limit aileron deflection at high AOA
        var aileron = getprop('/controls/flight/aileron') or 0;
        var aileron_limit = (1.0 - departure_risk * 0.5);
        aileron = math.max(-aileron_limit, math.min(aileron_limit, aileron));
        
        # Limit rudder at high AOA (can trigger departure)
        var rudder = getprop('/controls/flight/rudder') or 0;
        var rudder_limit = (1.0 - departure_risk * 0.7); # more restrictive than aileron
        rudder = math.max(-rudder_limit, math.min(rudder_limit, rudder));
        
        setprop('/afcs/bank-limit-active', 1);
    } else {
        setprop('/afcs/bank-limit-active', 0);
    }
};

var apply_stick_force_augmentation = func(dt) {
    # Stick force increases as pilot approaches stall/departure
    # (Requires AFCS with force feedback)
    
    var departure_risk = departure_prevention.departure_warning_level;
    var stick_force_factor = 1.0 + departure_risk * 2.0; # 1.0-3.0 range
    
    departure_prevention.stick_force_gain = stick_force_factor;
    setprop('/afcs/stick-force-aug-factor', stick_force_factor);
};

var update_departure_prevention = func(dt) {
    var armed = getprop('/afcs/departure-prevention-armed') or 1;
    if (!armed) return;
    
    var departure_risk = detect_departure_risk();
    
    if (departure_risk > 0) {
        apply_stick_force_augmentation(dt);
        apply_control_limiting(dt);
        apply_departure_prevention_inputs(dt);
    }
};

init_departure_prevention();
