# EngineSurge.nas - J79 compressor stall and surge modeling
# Models compressor stall (temporary) and surge (catastrophic flameout) conditions

var engine_surge_state = {
    surge_active: [0, 0], # per engine
    compressor_stall_timers: [0, 0],
    stalled_eng_idx: -1,
    stall_recovery_attempts: 0,
};

var init_engine_surge = func() {
    setprop('/engines/engine[0]/compressor-stall', 0);
    setprop('/engines/engine[0]/surge-recovery', 0);
    setprop('/engines/engine[1]/compressor-stall', 0);
    setprop('/engines/engine[1]/surge-recovery', 0);
    setprop('/afcs/annunciator/engine-stall', 0);
};

var check_stall_conditions = func(eng_idx, dt) {
    # J79 compressor stall triggers:
    # 1. High angle of attack + high fuel flow (unstart inlet shock)
    # 2. Rapid throttle chop from mil power
    # 3. Rapid roll/pitch with high bank angle (g-induced inlet distortion)
    # 4. Engine bleed valve issues (intentional bleed extraction)
    # 5. Transonic shock oscillation (inlet buzz)
    
    var aoa = getprop('/orientation/alpha-deg') or 0;
    var n1 = getprop('/engines/engine['~eng_idx~']/n1-percent') or 0;
    var n2 = getprop('/engines/engine['~eng_idx~']/n2-percent') or 0;
    var fuel_flow = getprop('/engines/engine['~eng_idx~']/fuel-flow-pph') or 0;
    var throttle = getprop('/engines/engine['~eng_idx~']/throttle-cmd') or 0;
    var prev_throttle = getprop('/engines/engine['~eng_idx~']/prev-throttle-cmd') or 0;
    
    # Rapid decel check
    var throttle_rate = (throttle - prev_throttle); # per update (0.1 sec)
    setprop('/engines/engine['~eng_idx~']/prev-throttle-cmd', throttle);
    
    var stall_probability = 0;
    
    # High AOA + high fuel flow combo
    if (aoa > 20 and fuel_flow > 10000 and n1 > 80) {
        stall_probability += 0.0015;
    }
    
    # Rapid decel from military power (high risk)
    if (throttle_rate < -0.5 and prev_throttle > 0.8 and n1 > 90) {
        stall_probability += 0.002;
    }
    
    # Transonic inlet effect (shock oscillation)
    var inlet_shock = getprop('/engines/inlet/shock-position') or 0.5;
    if (inlet_shock > 0.7 and inlet_shock < 1.0) { # shock moving rapidly
        stall_probability += 0.0005;
    }
    
    # High g-load with high bank (inlet flow distortion)
    var g_load = getprop('/accelerations/n-accel-glue') or 1;
    var bank = getprop('/orientation/roll-deg') or 0;
    if (g_load > 6 and math.abs(bank) > 60) {
        stall_probability += 0.001;
    }
    
    # Check for stall
    if (rand() < stall_probability * dt and n1 > 50) {
        engine_surge_state.surge_active[eng_idx] = 1;
        engine_surge_state.stalled_eng_idx = eng_idx;
        engine_surge_state.stall_recovery_attempts = 0;
        setprop('/engines/engine['~eng_idx~']/compressor-stall', 1);
        print('ENGINE: Compressor stall on engine '~eng_idx);
    }
};

var manage_stall_recovery = func(eng_idx, dt) {
    var stalled = getprop('/engines/engine['~eng_idx~']/compressor-stall') or 0;
    if (!stalled) return;
    
    engine_surge_state.compressor_stall_timers[eng_idx] += dt;
    var stall_duration = engine_surge_state.compressor_stall_timers[eng_idx];
    
    # Stall characteristics:
    # - Fuel flow drops to zero temporarily
    # - N1/N2 can spool down rapidly or oscillate
    # - Loud bang and vibration (audio/haptic feedback)
    # - Recovery requires:
    #   a) Throttle back to idle
    #   b) Wait for compressor to windmill restart
    #   c) Relight (auto-relight logic if equipped)
    
    var throttle = getprop('/engines/engine['~eng_idx~']/throttle-cmd') or 0;
    var fuel_flow = getprop('/engines/engine['~eng_idx~']/fuel-flow-pph') or 0;
    
    # If still at high throttle, stall persists
    if (throttle > 0.3) {
        # Stall oscillation: N1 fluctuates
        var oscillation = math.sin(stall_duration * 10) * 500; # oscillation frequency ~10 Hz
        var n1_perturbed = math.max(0, getprop('/engines/engine['~eng_idx~']/n1-percent') or 0 + oscillation);
        print('ENGINE: Stall oscillation on engine '~eng_idx~' at throttle '~throttle);
    } else {
        # Idle: windmill restart imminent
        if (stall_duration > 1.0) {
            # Auto-relight after 1 second at idle
            engine_surge_state.surge_active[eng_idx] = 0;
            setprop('/engines/engine['~eng_idx~']/compressor-stall', 0);
            setprop('/engines/engine['~eng_idx~']/surge-recovery', 1);
            engine_surge_state.stall_recovery_attempts += 1;
            engine_surge_state.compressor_stall_timers[eng_idx] = 0;
            print('ENGINE: Auto-relight on engine '~eng_idx~' (attempt '~engine_surge_state.stall_recovery_attempts~')');
            
            # Clear recovery flag after 2 seconds
            settimer(func { setprop('/engines/engine['~eng_idx~']/surge-recovery', 0); }, 2.0);
        }
    }
};

var update_engine_surge = func(dt) {
    # Check stall conditions on both engines
    check_stall_conditions(0, dt);
    check_stall_conditions(1, dt);
    
    # Manage stall recovery on stalled engines
    if (engine_surge_state.surge_active[0]) manage_stall_recovery(0, dt);
    if (engine_surge_state.surge_active[1]) manage_stall_recovery(1, dt);
    
    # Annunciator
    var any_stall = engine_surge_state.surge_active[0] or engine_surge_state.surge_active[1];
    setprop('/afcs/annunciator/engine-stall', any_stall ? 1 : 0);
};

init_engine_surge();
