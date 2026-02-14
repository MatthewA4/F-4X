# TransonicShockEffects.nas - transonic shock-induced control authority loss & pitch-up
# Models shock-boundary layer interaction, control surface effectiveness loss, pitch-up tendency

var shock_effects = {
    shock_on_wing: 0,      # 1 if shock present on wing
    shock_on_tail: 0,      # 1 if shock on tail
    control_reversal: [0, 0], # [roll, pitch] control reversal factor
    pitch_up_margin: 0,    # margin to pitch-up (units AOA)
    effective_cg_shift: 0, # CG shift due to shock induced pressure
};

var init_transonic = func() {
    setprop('/aerodynamics/shock-on-wing', 0);
    setprop('/aerodynamics/shock-on-tail', 0);
    setprop('/aerodynamics/control-reversal-factor', 0);
    setprop('/aerodynamics/pitch-up-margin', 10);
    setprop('/aerodynamics/cg-shock-induced-shift', 0);
};

var update_transonic_shock = func(dt) {
    var mach = getprop('/velocities/mach') or 0;
    var aoa = getprop('/orientation/alpha-deg') or 0;
    var alt = getprop('/position/altitude-ft') or 0;
    
    # Shock formation thresholds (critical Mach = sqrt(1 / cos^2(sweep)) * sqrt(1-M^2) roughly)
    # F-4 has ~45° sweep, so critical Mach ~0.75-0.85 depending on AOA
    
    var crit_mach_clean = 0.80 + (aoa / 30.0) * 0.15; # increases with AOA
    var crit_mach_loaded = 0.75; # stores lower critical Mach
    
    var stores_wt = getprop('/fcs/stores-total-weight-lb') or 0;
    var crit_mach = (stores_wt > 5000) ? crit_mach_loaded : crit_mach_clean;
    
    # Shock presence
    shock_effects.shock_on_wing = (mach >= crit_mach and mach <= 1.25) ? 1 : 0;
    shock_effects.shock_on_tail = (mach >= crit_mach + 0.05 and mach <= 1.3) ? 1 : 0;
    
    # Control reversal (aileron becomes less effective or reverses)
    var reversal_factor = 0;
    if (shock_effects.shock_on_wing) {
        # Wing shock reduces aileron effectiveness
        var shock_intensity = mach - crit_mach;
        reversal_factor = -0.15 * shock_intensity / 0.45; # up to -15% reversal by M 1.25
    }
    shock_effects.control_reversal[0] = reversal_factor;
    
    # Pitch-up tendency (shock on tail causes pitching moment shift)
    # Reduces available pitch margin
    var pitch_up_reduction = 0;
    if (shock_effects.shock_on_tail and aoa > 15) {
        pitch_up_reduction = math.min(10, 5.0 + (aoa - 15.0) * 0.5);
    }
    shock_effects.pitch_up_margin = math.max(0, 15 - pitch_up_reduction);
    
    # CG effective shift due to shock-induced CP movement
    var cp_shift = 0;
    if (mach > crit_mach) {
        cp_shift = (mach - crit_mach) * 0.02; # ~2% MAC shift per 0.1M
    }
    shock_effects.effective_cg_shift = cp_shift;
    
    setprop('/aerodynamics/shock-on-wing', shock_effects.shock_on_wing);
    setprop('/aerodynamics/shock-on-tail', shock_effects.shock_on_tail);
    setprop('/aerodynamics/control-reversal-factor', shock_effects.control_reversal[0]);
    setprop('/aerodynamics/pitch-up-margin', shock_effects.pitch_up_margin);
    setprop('/aerodynamics/cg-shock-induced-shift', shock_effects.effective_cg_shift);
    
    # Annunciator for pilot awareness
    if (shock_effects.shock_on_wing or shock_effects.shock_on_tail) {
        setprop('/afcs/annunciator/transonic-shock', 1);
    } else {
        setprop('/afcs/annunciator/transonic-shock', 0);
    }
};

init_transonic();
