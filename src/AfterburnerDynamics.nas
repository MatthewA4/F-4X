# AfterburnerDynamics.nas - realistic Pratt & Whitney J79 afterburner simulation
# Covers light-off envelope, augmented thrust, fuel flow, and transonic/supersonic behavior

var ab_state = {
    ab_light: [0, 0],           # [engine 0, engine 1] afterburner lit (0/1)
    combustor_temp: [300, 300], # stabilization temp
    ab_fuel_flow: [0, 0],       # augmented fuel (lb/hr)
    light_lag: [0, 0],          # time to achieve stable light-off
};

var init_afterburner = func() {
    setprop('/engines/engine[0]/afterburner-lit', 0);
    setprop('/engines/engine[1]/afterburner-lit', 0);
    setprop('/engines/engine[0]/afterburner-thrust-aug', 0);
    setprop('/engines/engine[1]/afterburner-thrust-aug', 0);
};

var update_afterburner = func(dt) {
    # NATOPS: Afterburner light-off envelope is Mach >0.5, altitude <35,000 ft
    var mach = getprop('/velocities/mach') or 0;
    var alt = getprop('/position/altitude-ft') or 0;
    
    for (var e = 0; e < 2; e += 1) {
        var ab_request = getprop('/controls/engines/engine['~e~']/afterburner') or 0;
        var n1 = getprop('/fdm/jsbsim/propulsion/engine['~e~']/n1') or 0;
        var n2 = getprop('/fdm/jsbsim/propulsion/engine['~e~']/n2') or 0;
        var fuel = getprop('/propulsion/tank[0]/contents-lbs') or 0;
        
        # Light-off conditions
        var can_light = (mach > 0.5 and alt < 35000 and n2 > 70 and fuel > 200);
        
        if (ab_request and can_light and !ab_state.ab_light[e]) {
            # Start light-off sequence (takes ~0.5 sec to stabilize)
            ab_state.light_lag[e] += dt;
            if (ab_state.light_lag[e] > 0.5) {
                ab_state.ab_light[e] = 1;
                ab_state.light_lag[e] = 0;
                print(sprintf('Engine %d: Afterburner LIGHT', e));
            }
        } elsif (!ab_request) {
            ab_state.ab_light[e] = 0;
            ab_state.light_lag[e] = 0;
        }
        
        # Thrust augmentation factor (simplified)
        var thrust_aug = 0;
        if (ab_state.ab_light[e]) {
            # Base augmentation ~60% extra thrust
            # Reduces at high altitude and high Mach (exhaust mixing efficiency)
            var alt_factor = 1.0 - (alt / 35000.0) * 0.4;
            var mach_factor = 1.0 - math.max(0, mach - 1.5) * 0.2;
            thrust_aug = 0.60 * alt_factor * mach_factor;
            
            # Fuel consumption for afterburner: ~2x engine base TSFC
            ab_state.ab_fuel_flow[e] = (n1 / 100.0) * 20000.0; # approx lb/hr
        }
        
        setprop('/engines/engine['~e~']/afterburner-lit', ab_state.ab_light[e]);
        setprop('/engines/engine['~e~']/afterburner-thrust-aug', thrust_aug);
    }
};

init_afterburner();
