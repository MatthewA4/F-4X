# PitchUpPrevention.nas - Transonic pitch-up prevention and control reversal warning
# Automatically limits angle of attack and pitch rates near transonic shock wave

var pitch_up_prevention = {
    system_active: 1,
    transonic_pitch_up_detected: 0,
    critical_mach: 0.85, # transonic shock onset
    aoa_limit_transonic: 18, # degrees (reduced from normal ~25)
    pitch_rate_limit: 45, # deg/sec max allowed
    auto_pitch_recovery: 0,
};

var init_pitch_up_prevention = func() {
    setprop('/afcs/pitch-up-prevention-armed', 1);
    setprop('/afcs/pitch-up-imminent', 0);
    setprop('/afcs/critical-mach-warning', 0);
    setprop('/afcs/aoa-limit-active', 0);
    setprop('/afcs/pitch-rate-limit-active', 0);
};

var check_transonic_pitch_up_conditions = func() {
    # Pitch-up most likely when:
    # 1. Mach > 0.80 (transonic shock effects)
    # 2. AOA > 18° (shock-induced stress concentration)
    # 3. Sustained high-g turn (structural loaded condition)
    # 4. Sudden control input at transonic Mach
    
    var mach = getprop('/velocities/mach') or 0;
    var aoa = getprop('/orientation/alpha-deg') or 0;
    var pitch_rate = getprop('/orientation/pitch-rate-degps') or 0;
    var g_load = getprop('/accelerations/n-accel-glue') or 1;
    var roll_rate = getprop('/orientation/roll-rate-degps') or 0;
    
    # Detect transonic regime
    if (mach > pitch_up_prevention.critical_mach) {
        setprop('/afcs/critical-mach-warning', 1);
        
        # Check for pitch-up conditions
        if (aoa > 16 and math.abs(pitch_rate) > 60) {
            # High AOA + rapid pitch = pitch-up condition
            pitch_up_prevention.transonic_pitch_up_detected = 1;
            setprop('/afcs/pitch-up-imminent', 1);
            print('PITCH-UP: WARNING - M='~math.round(mach*100)/100~', AOA='~math.round(aoa*10)/10~'°, pitch_rate='~pitch_rate~'°/s');
            
            # Try to recover
            pitch_up_prevention.auto_pitch_recovery = -1; # nose-down
        } else if (aoa > 18 and g_load > 6) {
            # High AOA + high g + transonic = structural risk
            pitch_up_prevention.transonic_pitch_up_detected = 1;
            setprop('/afcs/pitch-up-imminent', 1);
            
            pitch_up_prevention.auto_pitch_recovery = -0.5; # moderate relief
        } else {
            pitch_up_prevention.transonic_pitch_up_detected = 0;
            setprop('/afcs/pitch-up-imminent', 0);
            pitch_up_prevention.auto_pitch_recovery = 0;
        }
    } else {
        setprop('/afcs/critical-mach-warning', 0);
        pitch_up_prevention.transonic_pitch_up_detected = 0;
        setprop('/afcs/pitch-up-imminent', 0);
    }
};

var enforce_aoa_limits = func() {
    # Dynamically reduce AOA limit as Mach increases
    var mach = getprop('/velocities/mach') or 0;
    var aoa = getprop('/orientation/alpha-deg') or 0;
    
    # Baseline AOA limit: 25° subsonic, reduces to 18° transonic
    var aoa_limit = 25.0;
    if (mach > 0.75) {
        aoa_limit = 25 - (mach - 0.75) * 14 / (0.90 - 0.75); # linear interpolation
    }
    
    aoa_limit = math.max(18, aoa_limit); # minimum 18°
    
    if (aoa > aoa_limit - 2) {
        # Approaching limit
        setprop('/afcs/aoa-limit-active', 1);
        
        # Pitch control authority reduced near limit
        var limit_margin = aoa_limit - aoa;
        if (limit_margin < 0) {
            // exceeded limit - hard over nose-down
            pitch_up_prevention.auto_pitch_recovery = -1.0;
        }
    } else {
        setprop('/afcs/aoa-limit-active', 0);
    }
};

var enforce_pitch_rate_limits = func() {
    # Limit pitch rate in transonic regime to prevent structural overstress
    var mach = getprop('/velocities/mach') or 0;
    var pitch_rate = getprop('/orientation/pitch-rate-degps') or 0;
    
    if (mach > pitch_up_prevention.critical_mach) {
        var pitch_rate_limit = 45; # deg/sec max
        
        if (math.abs(pitch_rate) > pitch_rate_limit) {
            setprop('/afcs/pitch-rate-limit-active', 1);
            
            # Reduce pitch control
            var elevator = getprop('/controls/flight/elevator') or 0;
            var limiter = 0.5; # reduce elevator authority to 50%
            elevator = elevator * limiter;
            
            setprop('/afcs/auto-pitch-rate-damping', -pitch_rate * 0.1); # proportional damping
        } else {
            setprop('/afcs/pitch-rate-limit-active', 0);
        }
    }
};

var apply_recovery_inputs = func() {
    # Apply automatic pitch recovery if transonic pitch-up detected
    if (pitch_up_prevention.auto_pitch_recovery != 0) {
        setprop('/afcs/auto-pitch-relief-input', pitch_up_prevention.auto_pitch_recovery);
    }
};

var update_pitch_up_prevention = func(dt) {
    var armed = getprop('/afcs/pitch-up-prevention-armed') or 1;
    if (!armed) return;
    
    check_transonic_pitch_up_conditions();
    enforce_aoa_limits();
    enforce_pitch_rate_limits();
    apply_recovery_inputs();
};

init_pitch_up_prevention();
