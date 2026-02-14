# RefuelingProbe.nas - Air-to-air refueling probe dynamics and boom contact
# Models probe extension, boom alignment feedback, and crew interface

var refuel = {
    probe_deployed: 0,
    probe_lock_engaged: 0,
    boom_contact_status: 0, # 0=none, 1=contact, 2=latched
    refuel_in_progress: 0,
    flow_rate_gpm: 0, # gallons per minute
    refuel_duration: 0,
    max_fuel_transfer: 5000, # pounds max safe transfer per sortie
    fuel_transferred: 0,
};

var init_refueling_probe = func() {
    setprop('/systems/refuel/probe-deployed', 0);
    setprop('/systems/refuel/probe-lock', 0);
    setprop('/systems/refuel/boom-position-m', 0);
    setprop('/systems/refuel/boom-contact', 0);
    setprop('/systems/refuel/refuel-rate-gpm', 0);
    setprop('/systems/refuel/fuel-transferred-lbs', 0);
    setprop('/systems/refuel/boom-boom-oscillation-rad', 0);
};

var deploy_refuel_probe = func(deploy_cmd) {
    # Pilot extends probe via switch
    if (deploy_cmd and !refuel.probe_deployed) {
        refuel.probe_deployed = 1;
        setprop('/systems/refuel/probe-deployed', 1);
        print('REFUEL: Probe extended');
    } elsif (!deploy_cmd and refuel.probe_deployed) {
        refuel.probe_deployed = 0;
        refuel.probe_lock_engaged = 0;
        refuel.boom_contact_status = 0;
        setprop('/systems/refuel/probe-deployed', 0);
        setprop('/systems/refuel/probe-lock', 0);
        print('REFUEL: Probe retracted');
    }
};

var model_boom_contact = func(dt) {
    # Boom (from tanker) attempts to connect to probe
    # Requires:
    # 1. Probe extended
    # 2. Formation flying (closure rate <2 ft/sec typically)
    # 3. Relative position aligned (~3-4 feet offset max)
    
    if (!refuel.probe_deployed) {
        refuel.boom_contact_status = 0;
        return;
    }
    
    # Simulate tanker closure - for now, assume perfect formation if probe extended
    # In realistic scenario, pilot would receive boom signals and align position
    var relative_roll = getprop('/orientation/roll-deg') or 0; # relative to tanker
    var relative_pitch = getprop('/orientation/pitch-deg') or 0;
    var airspeed = getprop('/velocities/airspeed-kt') or 0;
    
    # Contact envelope: small offset acceptable
    var contact_tolerance = 2.0; # degrees max roll/pitch error
    var contact_possible = (math.abs(relative_roll) < contact_tolerance and 
                           math.abs(relative_pitch) < contact_tolerance and
                           airspeed > 240 and airspeed < 350);
    
    if (contact_possible) {
        refuel.boom_contact_status = 1; # contact established
        setprop('/systems/refuel/boom-contact', 1);
        
        # Engagement logic (simulated)
        if (!refuel.probe_lock_engaged) {
            refuel.probe_lock_engaged = 1;
            refuel.boom_contact_status = 2; # latched
            setprop('/systems/refuel/probe-lock', 1);
            print('REFUEL: Boom latched to probe');
        }
    } else {
        refuel.boom_contact_status = 0;
        setprop('/systems/refuel/boom-contact', 0);
        if (refuel.probe_lock_engaged) {
            refuel.probe_lock_engaged = 0;
            setprop('/systems/refuel/probe-lock', 0);
            print('REFUEL: Boom disengaged from probe');
        }
    }
};

var execute_refueling = func(dt) {
    # Transfer fuel while latched
    if (refuel.probe_lock_engaged and refuel.boom_contact_status == 2) {
        if (!refuel.refuel_in_progress) {
            refuel.refuel_in_progress = 1;
            print('REFUEL: Fuel transfer starting');
        }
        
        # Refuel flow rate: typical F-4 receives ~500-600 GPM (J-model) or ~1000 GPM (S-model)
        # F-4S specs suggest higher flow; assume 800 GPM nominal
        refuel.flow_rate_gpm = 800;
        
        # Fuel density: Jet-A ~6.8 lbs/gallon
        var fuel_density = 6.8;
        var fuel_rate_lbm = refuel.flow_rate_gpm * fuel_density * (dt / 60.0); # lbs/sec
        
        # Check transfer limits
        if (refuel.fuel_transferred + fuel_rate_lbm > refuel.max_fuel_transfer) {
            # Limit reached; cut flow
            refuel.flow_rate_gpm = 0;
            print('REFUEL: Maximum transfer limit reached');
        } else {
            refuel.fuel_transferred += fuel_rate_lbm;
        }
    } else {
        refuel.refuel_in_progress = 0;
        refuel.flow_rate_gpm = 0;
    }
    
    setprop('/systems/refuel/refuel-rate-gpm', refuel.flow_rate_gpm);
    setprop('/systems/refuel/fuel-transferred-lbs', refuel.fuel_transferred);
};

var model_boom_oscillation = func(dt) {
    # Boom has resonance (~2-3 Hz typical drogue boom)
    # Forced oscillations from aircraft pitch/roll coupling
    # Damping affects refuel rate stability
    
    var pitch_rate = getprop('/orientation/pitch-rate-degps') or 0;
    var roll_rate = getprop('/orientation/roll-rate-degps') or 0;
    
    if (refuel.probe_lock_engaged) {
        # Boom oscillation driven by aircraft motion
        var boom_freq = 2.5; # Hz
        var time_sec = getprop('/sim/time/elapsed-sec') or 0;
        var forced_oscillation = math.sin(time_sec * boom_freq * 2 * math.pi) * 0.02; # ±0.02 rad (±1.15°)
        
        # Input coupling from aircraft rates
        var dynamic_coupling = (pitch_rate + roll_rate) / 100.0 * 0.05;
        
        var total_oscillation = forced_oscillation + dynamic_coupling;
        setprop('/systems/refuel/boom-boom-oscillation-rad', total_oscillation);
    } else {
        setprop('/systems/refuel/boom-boom-oscillation-rad', 0);
    }
};

var update_refueling_probe = func(dt) {
    # Check pilot inputs
    var probe_cmd = getprop('/controls/aircraft/refuel-probe-deploy') or 0;
    deploy_refuel_probe(probe_cmd);
    
    # Model boom contact and engagement
    model_boom_contact(dt);
    
    # Execute refueling transfer
    execute_refueling(dt);
    
    # Boom oscillation effects
    model_boom_oscillation(dt);
};

init_refueling_probe();
