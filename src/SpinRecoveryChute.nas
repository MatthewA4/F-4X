# SpinRecoveryChute.nas - Anti-spin recovery parachute system
# F-4S equipped with spin recovery parachute for emergency spin recovery
# Provides yaw damping and enhanced recovery authority during deep stall/spin

var spin_chute = {
    deployed: 0,
    chute_area_sq_ft: 45.0, # typical drogue chute area
    max_deployment_speed: 500, # knots (limit to avoid structural failure)
    deployment_time: 0.5, # seconds to full deployment
    current_deployment: 0, # 0-1 scale
    drag_coefficient: 1.2, # parachute general drag coeff
    yaw_control_moment: 0, # moment arm effect in yaw
};

var init_spin_recovery_chute = func() {
    setprop('/aircraft/parachutes/spin-chute-armed', 1); # default armed
    setprop('/aircraft/parachutes/spin-chute-deployed', 0);
    setprop('/aircraft/parachutes/spin-chute-sail-integrity', 100); # % remaining
    setprop('/aircraft/parachutes/spin-chute-drag-force-lbf', 0);
};

var check_spin_condition = func() {
    # Detect deep stall or spin
    # Spin characteristics:
    # - High angle of attack (>30°)
    # - Sustained yaw rate (>20°/sec)
    # - Negative or near-zero airspeed in vertical reference
    # - Wingtip separation risk
    
    var aoa = getprop('/orientation/alpha-deg') or 0;
    var yaw_rate = getprop('/orientation/yaw-rate-degps') or 0;
    var pitch_rate = getprop('/orientation/pitch-rate-degps') or 0;
    var roll_rate = getprop('/orientation/roll-rate-degps') or 0;
    var climb_rate = getprop('/velocities/vertical-speed-fps') or 0;
    var airspeed = getprop('/velocities/airspeed-kt') or 0;
    
    # Deep stall: AOA > 30° and oscillating pitch
    var deep_stall = (aoa > 30 and math.abs(pitch_rate) < 10);
    
    # Spin: High AOA + sustained yaw + negative climb (descending with high yaw)
    var spinning = (aoa > 25 and math.abs(yaw_rate) > 20 and climb_rate < -200 and airspeed < 150);
    
    return (deep_stall or spinning);
};

var deploy_spin_chute = func() {
    if (spin_chute.deployed) return; # already deployed
    
    var armed = getprop('/aircraft/parachutes/spin-chute-armed') or 0;
    if (!armed) {
        print('SPIN CHUTE: Deployment blocked - not armed');
        return;
    }
    
    var airspeed = getprop('/velocities/airspeed-kt') or 0;
    if (airspeed > spin_chute.max_deployment_speed) {
        print('SPIN CHUTE: Deployment blocked - airspeed '~airspeed~'kt exceeds limit');
        return; # structural limit
    }
    
    spin_chute.deployed = 1;
    setprop('/aircraft/parachutes/spin-chute-deployed', 1);
    print('SPIN CHUTE: Deployed at '~airspeed~'kt');
};

var compute_parachute_forces = func(dt) {
    if (!spin_chute.deployed) return;
    
    # Deployment animation
    if (spin_chute.current_deployment < 1.0) {
        spin_chute.current_deployment += (dt / spin_chute.deployment_time);
        spin_chute.current_deployment = math.min(1.0, spin_chute.current_deployment);
    }
    
    var deployment_factor = spin_chute.current_deployment;
    
    # Parachute drag force = 0.5 * rho * V^2 * Cd * A
    var airspeed = getprop('/velocities/airspeed-kt') or 0;
    var airspeed_fps = airspeed * 6076.12 / 3600; # convert knots to ft/s
    var density = getprop('/environment/density-slugft3') or 0.002377;
    
    var dynamic_pressure = 0.5 * density * airspeed_fps * airspeed_fps;
    var drag_force = dynamic_pressure * spin_chute.drag_coefficient * 
                     (spin_chute.chute_area_sq_ft * deployment_factor);
    
    setprop('/aircraft/parachutes/spin-chute-drag-force-lbf', drag_force);
    
    # Yaw damping effect of parachute
    # Chute off-center creates yaw moment opposing rotation
    var yaw_rate = getprop('/orientation/yaw-rate-degps') or 0;
    var yaw_damping_moment = yaw_rate * deployment_factor * -50; # damping proportional to yaw rate
    
    spin_chute.yaw_control_moment = yaw_damping_moment;
};

var check_chute_integrity = func(dt) {
    # Parachute can be damaged by:
    # - Deployment at too high airspeed (structural failure)
    # - Collision with ground/obstacles
    # - Excessive time deployed (fabric wear)
    
    var airspeed = getprop('/velocities/airspeed-kt') or 0;
    var integrity = getprop('/aircraft/parachutes/spin-chute-sail-integrity') or 100;
    
    if (spin_chute.deployed) {
        # Structural damage if deployed beyond design speed
        if (airspeed > spin_chute.max_deployment_speed) {
            var overspeed = airspeed - spin_chute.max_deployment_speed;
            var damage_rate = (overspeed / 100) * 0.5; # % per second
            integrity -= damage_rate * dt;
            
            if (integrity < 0) {
                print('SPIN CHUTE: Chute destroyed from overspeed deployment');
                spin_chute.deployed = 0;
                integrity = 0;
            }
        }
        
        # Wear from sustained deployment
        integrity -= 0.001 * dt; # gradual wear
    }
    
    integrity = math.max(0, math.min(100, integrity));
    setprop('/aircraft/parachutes/spin-chute-sail-integrity', integrity);
    
    # If integrity critical, chute may fail
    if (integrity < 20 and spin_chute.deployed and rand() < 0.001) {
        print('SPIN CHUTE: Catastrophic chute failure!');
        spin_chute.deployed = 0;
        integrity = 0;
    }
};

var manual_chute_deployment = func() {
    # Pilot can manually deploy via button/switch
    var deploy_cmd = getprop('/controls/aircraft/spin-chute-deploy') or 0;
    if (deploy_cmd) {
        deploy_spin_chute();
    }
};

var automatic_chute_deployment = func() {
    # Auto-deploy if spin detected and airspeed safe
    var in_spin = check_spin_condition();
    var airspeed = getprop('/velocities/airspeed-kt') or 0;
    
    if (in_spin and airspeed < spin_chute.max_deployment_speed) {
        deploy_spin_chute();
    }
};

var update_spin_recovery_chute = func(dt) {
    # Check inputs
    manual_chute_deployment();
    automatic_chute_deployment();
    
    # Compute forces if deployed
    compute_parachute_forces(dt);
    
    # Check integrity
    check_chute_integrity(dt);
};

init_spin_recovery_chute();
