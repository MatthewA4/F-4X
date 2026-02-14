# InletControl.nas - Variable inlet geometry and transonic shock management
# F-4J Phantom II uses fixed-geometry inlet with shock-boundary-layer interaction effects
# This module models inlet mass-flow, pressure recovery, and shock oscillations

var inlet = {
    inlet_open: 1,        # 0=closed, 1=open for airflow
    shock_position: 0.5,  # normalized position in inlet (0.0-1.0)
    mass_flow_fb: 1.0,    # feedback factor (nominal 1.0)
    pressure_recovery: 1.0, # ram pressure recovery ratio
    mach_shock_induced: 0, # 1 if shock > M 1.3
};

var init_inlet = func() {
    setprop('/engines/inlet/open', inlet.inlet_open);
    setprop('/engines/inlet/shock-position', inlet.shock_position);
    setprop('/engines/inlet/pressure-recovery', inlet.pressure_recovery);
    setprop('/engines/inlet/mass-flow-feedback', inlet.mass_flow_fb);
};

var update_inlet_control = func(dt) {
    var mach = getprop('/velocities/mach') or 0;
    var alt = getprop('/position/altitude-ft') or 0;
    var throttle = getprop('/controls/engines/engine[0]/throttle') or 0;
    
    # F-4 inlet design: fixed geometry, but transonic behavior changes dramatically
    # Mach 0.5-1.3: relatively stable, good pressure recovery
    # Mach 1.3-2.0: inlet shock position oscillates, pressure recovery drops
    
    if (mach < 0.5) {
        inlet.pressure_recovery = 0.98;
        inlet.shock_position = 0.9;
        inlet.mass_flow_fb = 1.0;
    } elsif (mach < 1.3) {
        # Subsonic/transonic: gradual shock penetration
        var recovery_drop = (mach - 0.5) * 0.15;
        inlet.pressure_recovery = 0.98 - recovery_drop;
        inlet.shock_position = 0.9 - (mach - 0.5) * 0.5;
        inlet.mass_flow_fb = 1.0 - (mach - 0.5) * 0.08;
    } else {
        # Supersonic: inlet shock stands in entrance
        # Shock-induced oscillation at M > 1.3 (buzzing effect)
        var overspeed = mach - 1.3;
        inlet.pressure_recovery = 0.82 - (overspeed * 0.05);
        
        # Shock position oscillates with ~0.5-1 Hz frequency at M > 1.5
        var buzz_freq = math.min(overspeed * 2.0, 1.0);
        inlet.shock_position = 0.3 + 0.1 * math.sin(getprop('/sim/time/elapsed-sec') * buzz_freq * 2 * math.pi);
        
        # Mass flow unstart risk at high oversspeed (reduces fuel available to engines)
        inlet.mass_flow_fb = 0.92 - (overspeed * overspeed * 0.05);
        inlet.mach_shock_induced = 1;
    }
    
    if (mach < 1.1) inlet.mach_shock_induced = 0;
    
    # Apply pressure recovery to engine inlet pressure for fuel flow adjustment
    setprop('/engines/inlet/pressure-recovery', inlet.pressure_recovery);
    setprop('/engines/inlet/mass-flow-feedback', inlet.mass_flow_fb);
    setprop('/engines/inlet/shock-position', inlet.shock_position);
};

init_inlet();
