# LandingGearDamping.nas - Shock absorber dynamics and landing gear oscillation modeling
# Models stroke, damping, spring forces, and coupling to fuselage dynamics

var landing_gear = {
    strut: [{}, {}], # [nose_gear, main_gear]
    nominal_stroke: [15, 20],       # inches (typical for F-4)
    spring_constant: [1.2, 0.95],   # lbf per inch deflection (normalized)
    damping_coeff: [0.85, 0.80],    # damping ratio (0.7-1.0 is critical-to-overdamped)
    natural_freq: [2.5, 2.0],       # Hz (oleo-pneumatic strut frequency)
};

var init_landing_gear = func() {
    # Nose gear tires
    setprop('/gear/nose-gear/stroke-m', 0);
    setprop('/gear/nose-gear/vertical-velocity-fps', 0);
    setprop('/gear/nose-gear/load-force-lbf', 0);
    setprop('/gear/nose-gear/on-ground', 0);
    
    # Main landing gear (left and right)
    setprop('/gear/main-gear[0]/stroke-m', 0);
    setprop('/gear/main-gear[0]/vertical-velocity-fps', 0);
    setprop('/gear/main-gear[0]/load-force-lbf', 0);
    setprop('/gear/main-gear[0]/on-ground', 0);
    
    setprop('/gear/main-gear[1]/stroke-m', 0);
    setprop('/gear/main-gear[1]/vertical-velocity-fps', 0);
    setprop('/gear/main-gear[1]/load-force-lbf', 0);
    setprop('/gear/main-gear[1]/on-ground', 1);
    
    setprop('/fdm/jsbsim/landing-gear/pitch-oscillation-rad', 0);
    setprop('/fdm/jsbsim/landing-gear/roll-oscillation-rad', 0);
    setprop('/fdm/jsbsim/landing-gear/touchdown-sink-rate-fps', 0);
};

var compute_strut_force = func(strut_idx, dt) {
    # Get vertical velocity from FDM
    var vz = getprop('/velocities/vertical-speed-fps') or 0;
    var on_gnd = getprop('/gear/' ~ (strut_idx == 0 ? 'nose-gear' : 'main-gear[0]') ~ '/on-ground') or 0;
    
    if (!on_gnd) {
        setprop('/gear/' ~ (strut_idx == 0 ? 'nose-gear' : 'main-gear[0]') ~ '/load-force-lbf', 0);
        return;
    }
    
    # Sink rate at touchdown (for initialization)
    var sink = getprop('/fdm/jsbsim/landing-gear/touchdown-sink-rate-fps') or 5; # fps
    
    # Stroke calculation from compression
    var weight = getprop('/fdm/jsbsim/inertia/weight-lbs') or 54000;
    var static_load = weight / 3; # distribute across 3 gear (2 main + nose)
    
    # Oleo-pneumatic strut: F = k*x + c*v
    # x = current compression (0 = uncompressed)
    # v = compression rate (dstroke/dt)
    var max_stroke = landing_gear.nominal_stroke[strut_idx]; # theoretical max
    var k = landing_gear.spring_constant[strut_idx] * 1000; # lbf/in -> lbf/m effective
    var c = landing_gear.damping_coeff[strut_idx] * 500; # damping lbf*sec/m
    
    # During sink, strut compresses
    var compression_rate = math.max(0, -vz); # positive = compression (downward)
    
    # Spring force + damping force
    var spring_force = k * compression_rate * dt;
    var damping_force = c * compression_rate;
    var total_force = spring_force + damping_force + static_load;
    
    # Clamp to reasonable bounds
    total_force = math.max(0, math.min(weight * 1.5, total_force));
    
    var strut_name = strut_idx == 0 ? 'nose-gear' : 'main-gear[0]';
    setprop('/gear/'~strut_name~'/load-force-lbf', total_force);
    
    return total_force;
};

var model_touchdown_oscillation = func(dt) {
    # After touchdown, landing gear exhibits PIO (pilot-induced oscillation) or porpoising if not damped correctly
    # Nose gear touches first, then main gear; pitch oscillation couples to fuselage
    
    var on_gnd = getprop('/gear/main-gear[0]/on-ground') or 0;
    if (!on_gnd) return; # no oscillation if airborne
    
    # Get weight and CG
    var weight = getprop('/fdm/jsbsim/inertia/weight-lbs') or 54000;
    var cg_position = getprop('/fdm/jsbsim/inertia/cg-position-m') or 5.0; # meter
    
    # Landing gear geometry: main gear ~8.5 m behind nose gear; main gear ~4.5 m from CG
    var nose_to_main = 8.5; # meters
    var pitch_arm = 4.5; # moment arm from CG to main gear
    
    # If nose gear still loaded heavily while main settles, pitch-up moment is created
    var nose_load = getprop('/gear/nose-gear/load-force-lbf') or 0;
    var main_load_0 = getprop('/gear/main-gear[0]/load-force-lbf') or 0;
    var main_load_1 = getprop('/gear/main-gear[1]/load-force-lbf') or 0;
    var main_load = (main_load_0 + main_load_1) / 2.0;
    
    # Pitch moment from uneven load distribution
    var load_imbalance = (nose_load - main_load) / (weight + 0.1);
    var pitch_oscillation = getprop('/fdm/jsbsim/landing-gear/pitch-oscillation-rad') or 0;
    
    # Damped harmonic oscillation model
    # d²θ/dt² = -ω²θ - 2ζωdθ/dt + external_moment
    var natural_freq = landing_gear.natural_freq[1]; # main gear freq (Hz) -> rad/s
    var omega = natural_freq * 2 * math.pi;
    var zeta = 0.75; # damping ratio (~0.75 is typical for well-damped oleos)
    
    # Stimulate with load imbalance
    var accel = -omega * omega * pitch_oscillation - 2 * zeta * omega * pitch_oscillation + load_imbalance * 0.01;
    var new_oscillation = pitch_oscillation + accel * dt;
    new_oscillation = math.max(-0.05, math.min(0.05, new_oscillation)); # clamp to ±2.8°
    
    setprop('/fdm/jsbsim/landing-gear/pitch-oscillation-rad', new_oscillation);
    
    # Store sink rate at touchdown for logging
    var vz = getprop('/velocities/vertical-speed-fps') or 0;
    if (vz < -3) { # define hard landing as >3 fps descent
        setprop('/fdm/jsbsim/landing-gear/touchdown-sink-rate-fps', math.abs(vz));
    }
};

var check_nose_gear_shimmy = func(dt) {
    # Nose gear shimmy is a self-excited oscillation caused by yaw input + tire friction
    # Occurs at certain ground velocities and yaw rates
    var vx = getprop('/velocities/groundspeed-kt') or 0;
    var r = getprop('/orientation/roll-rate-degps') or 0; # yaw rate (confusing notation)
    var nose_load = getprop('/gear/nose-gear/load-force-lbf') or 0;
    var on_gnd = getprop('/gear/nose-gear/on-ground') or 0;
    
    if (!on_gnd or vx < 10) return; # no shimmy if not rolling or too slow
    
    # Shimmy occurs in band ~80-110 knots for many aircraft
    var shimmy_freq = 4.0; # Hz typical
    var shimmy_amplitude = math.min(0.03, nose_load / 5000); # oscillation amplitude limited by load
    
    if (vx > 70 and vx < 130 and math.abs(r) > 5) {
        # Yaw input triggers shimmy
        var shimmy_phase = math.mod(getprop('/sim/time/elapsed-sec') or 0, 1.0 / shimmy_freq);
        var shimmy = shimmy_amplitude * math.sin(shimmy_phase * 2 * math.pi * shimmy_freq);
        
        # Apply as yaw oscillation to rudder trim or aerodynamic yaw
        setprop('/fdm/jsbsim/landing-gear/nose-shimmy-rad', shimmy);
    }
};

var update_landing_gear_dynamics = func(dt) {
    # Update strut forces
    compute_strut_force(0, dt); # nose gear
    compute_strut_force(1, dt); # main gear
    
    # Model oscillations
    model_touchdown_oscillation(dt);
    check_nose_gear_shimmy(dt);
};

init_landing_gear();
