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
    # 2. Formation flying (closure rate must be low for stable contact)
    # 3. Relative position aligned (~3-4 feet offset max)
    # 4. Airspeed envelope: 240-350 knots typical (F-4 refueling envelope)
    
    if (!refuel.probe_deployed) {
        refuel.boom_contact_status = 0;
        return;
    }
    
    # Simulate tanker closure - for now, assume perfect formation if probe extended
    # In realistic scenario, pilot would receive boom signals and align position
    var relative_roll = getprop('/orientation/roll-deg') or 0; # relative to tanker
    var relative_pitch = getprop('/orientation/pitch-deg') or 0;
    var relative_yaw = getprop('/orientation/heading-deg') or 0;
    var airspeed = getprop('/velocities/airspeed-kt') or 0;
    
    # Contact envelope: small offset acceptable (NATOPS values)
    # Lateral tolerance: ±3 feet (±2.5 degrees at typical boom length of ~70 feet)
    # Vertical tolerance: ±2 feet (±1.7 degrees)
    # Longitudinal: within ~4 feet (boom extension/retraction range)
    
    var lateral_tolerance = 2.5; # degrees
    var vertical_tolerance = 1.7; # degrees
    var refuel_envelope_low = 240;  # knots
    var refuel_envelope_high = 350; # knots
    
    var contact_possible = (math.abs(relative_roll) < lateral_tolerance and 
                           math.abs(relative_pitch) < vertical_tolerance and
                           airspeed > refuel_envelope_low and airspeed < refuel_envelope_high);
    
    if (contact_possible) {
        refuel.boom_contact_status = 1; # contact established
        setprop('/systems/refuel/boom-contact', 1);
        
        # Engagement logic (simulated): after 2 seconds of stable contact, engage latch
        if (!refuel.probe_lock_engaged) {
            # Add a small delay before latch (simulated boom operator action)
            var boom_time = getprop('/systems/refuel/boom-contact-time') or 0;
            boom_time += dt;
            setprop('/systems/refuel/boom-contact-time', boom_time);
            
            if (boom_time > 2.0) {  # 2 second stabilization time
                refuel.probe_lock_engaged = 1;
                refuel.boom_contact_status = 2; # latched
                setprop('/systems/refuel/probe-lock', 1);
                setprop('/systems/refuel/boom-contact-time', 0);
                print('REFUEL: Boom latched to probe');
            }
        }
    } else {
        refuel.boom_contact_status = 0;
        setprop('/systems/refuel/boom-contact', 0);
        setprop('/systems/refuel/boom-contact-time', 0);
        
        if (refuel.probe_lock_engaged) {
            refuel.probe_lock_engaged = 0;
            setprop('/systems/refuel/probe-lock', 0);
            print('REFUEL: Boom disengaged from probe (contact lost)');
        }
    }
};

var execute_refueling = func(dt) {
    # Transfer fuel while latched
    if (refuel.probe_lock_engaged and refuel.boom_contact_status == 2) {
        if (!refuel.refuel_in_progress) {
            refuel.refuel_in_progress = 1;
            print('REFUEL: Fuel transfer starting - rate 800 GPM, max transfer 5000 lbs');
        }
        
        # Refuel flow rate: typical F-4 receives ~500-600 GPM (J-model) or ~1000 GPM (S-model)
        # F-4S specs suggest higher flow; assume 800 GPM nominal (can be modified by pilot)
        var pilot_refuel_rate = getprop('/controls/aircraft/refuel-rate-adjust') or 0; # 0-100 percent
        refuel.flow_rate_gpm = 800 * (0.5 + pilot_refuel_rate / 200.0); # 400-1000 GPM range
        
        # Fuel density: Jet-A ~6.8 lbs/gallon
        var fuel_density = 6.8;
        var fuel_rate_lbm = refuel.flow_rate_gpm * fuel_density * (dt / 60.0); # lbs transferred this frame
        
        # Check transfer limits
        if (refuel.fuel_transferred + fuel_rate_lbm > refuel.max_fuel_transfer) {
            # Limit reached; cut flow and auto-disconnect
            refuel.flow_rate_gpm = 0;
            refuel.refuel_in_progress = 0;
            refuel.probe_lock_engaged = 0;
            refuel.boom_contact_status = 0;
            setprop('/systems/refuel/probe-lock', 0);
            setprop('/systems/refuel/boom-contact', 0);
            print('REFUEL: Maximum transfer limit (5000 lbs) reached - boom disconnected');
        } else {
            refuel.fuel_transferred += fuel_rate_lbm;
        }
    } else {
        refuel.refuel_in_progress = 0;
        refuel.flow_rate_gpm = 0;
        if (refuel.fuel_transferred >= refuel.max_fuel_transfer) {
            print('REFUEL: Transfer complete - tanks full or limit reached');
        }
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
