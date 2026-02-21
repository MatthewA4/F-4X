# Hydraulics.nas - hydraulic system simulation for F-4J/S
# Models left/right channels, pumps, actuators, RAT, manual reversion

var hyd_state = {
    pump: { left:1, right:1, aux:1, hand:1 },
    pressure: { left:3000.0, right:3000.0 },
    pressure_low: { left:0, right:0 },
    rat: { deployed:0, available:1 },
    crossfeed_open: 0,
    compliance: 0.0005,        # ft^3/psi - system fluid compliance
    actuators: {
        elevator: {position:0, commanded:0, rate_limit:15.0, area:0.5},
        aileron:  {position:0, commanded:0, rate_limit:20.0, area:0.4},
        rudder:   {position:0, commanded:0, rate_limit:18.0, area:0.6}
    }
};

var init_hydraulics = func() {
    # initialize left/right pump status
    setprop('/hydraulics/pump/left/status', hyd_state.pump.left);
    setprop('/hydraulics/pump/right/status', hyd_state.pump.right);
    setprop('/hydraulics/pump/aux/status', hyd_state.pump.aux);
    setprop('/hydraulics/pump/hand/status', hyd_state.pump.hand);

    # initialize pressures
    setprop('/hydraulics/pressure/left-psi', hyd_state.pressure.left);
    setprop('/hydraulics/pressure/right-psi', hyd_state.pressure.right);
    setprop('/hydraulics/pressure-low/left', 0);
    setprop('/hydraulics/pressure-low/right', 0);

    # RAT state
    setprop('/hydraulics/rat-deployed', hyd_state.rat.deployed);
    setprop('/hydraulics/rat-available', hyd_state.rat.available);

    # actuator states
    foreach (name; _list(hyd_state.actuators)) {
        setprop('/hydraulics/actuator/'#name#'/position', hyd_state.actuators[name].position);
        setprop('/hydraulics/actuator/'#name#'/commanded', hyd_state.actuators[name].commanded);
        setprop('/hydraulics/actuator/'#name#'/rate-limit', hyd_state.actuators[name].rate_limit);
    }
};

var update_hydraulics = func(dt) {
    # update left & right pressures based on pump status, auxiliary, crossfeed, and RAT
    # left channel
    if (!hyd_state.pump.left and !hyd_state.pump.aux) {
        hyd_state.pressure.left = math.max(0, hyd_state.pressure.left - 200.0 * dt);
    } elsif (!hyd_state.pump.left and hyd_state.pump.aux) {
        hyd_state.pressure.left = math.max(0, hyd_state.pressure.left - 20.0 * dt);
    } else {
        hyd_state.pressure.left += (3000.0 - hyd_state.pressure.left) * math.min(1.0, dt * 0.5);
    }
    # right channel
    if (!hyd_state.pump.right and !hyd_state.pump.aux) {
        hyd_state.pressure.right = math.max(0, hyd_state.pressure.right - 200.0 * dt);
    } elsif (!hyd_state.pump.right and hyd_state.pump.aux) {
        hyd_state.pressure.right = math.max(0, hyd_state.pressure.right - 20.0 * dt);
    } else {
        hyd_state.pressure.right += (3000.0 - hyd_state.pressure.right) * math.min(1.0, dt * 0.5);
    }

    # crossfeed logic: if one side <1000 psi and opposite side >2000 psi and crossfeed open, equalize
    if (hyd_state.crossfeed_open) {
        var diff = hyd_state.pressure.left - hyd_state.pressure.right;
        var transfer = diff * 0.1 * dt;
        hyd_state.pressure.left -= transfer;
        hyd_state.pressure.right += transfer;
    }

    hyd_state.pressure_low.left = hyd_state.pressure.left < 1500.0 ? 1 : 0;
    hyd_state.pressure_low.right = hyd_state.pressure.right < 1500.0 ? 1 : 0;

    setprop('/hydraulics/pressure/left-psi', hyd_state.pressure.left);
    setprop('/hydraulics/pressure/right-psi', hyd_state.pressure.right);
    setprop('/hydraulics/pressure-low/left', hyd_state.pressure_low.left);
    setprop('/hydraulics/pressure-low/right', hyd_state.pressure_low.right);

    # RAT deployment logic based on both channels
    if ((hyd_state.pressure.left < 800.0 and hyd_state.pressure.right < 800.0) and hyd_state.rat.available and !hyd_state.rat.deployed) {
        hyd_state.rat.deployed = 1;
        hyd_state.rat.available = 0;
        print('RAT deployed due to dual hydraulic pressure loss');
    }

    if (hyd_state.rat.deployed) {
        hyd_state.pressure.left += 200.0 * dt;
        hyd_state.pressure.right += 200.0 * dt;
        if (hyd_state.pressure.left > 1800.0 and hyd_state.pressure.right > 1800.0) {
            hyd_state.rat.deployed = 0;
        }
    }

    setprop('/hydraulics/rat-deployed', hyd_state.rat.deployed ? 1 : 0);
    setprop('/hydraulics/rat-available', hyd_state.rat.available ? 1 : 0);

    # update actuators now that pressures are set
    update_actuators(dt);
};

init_hydraulics();

# actuator update helper
var update_actuators = func(dt) {
    foreach (name; _list(hyd_state.actuators)) {
        var act = hyd_state.actuators[name];
        # determine supply pressure (simplified: average left/right)
        var ps = (hyd_state.pressure.left + hyd_state.pressure.right) * 0.5;
        # degrade rate if low pressure
        var rate = act.rate_limit;
        if (ps < 1000.0) rate *= 0.5;
        # simple first-order response towards commanded
        var delta = act.commanded - act.position;
        var maxdelta = rate * dt;
        if (delta > maxdelta) delta = maxdelta;
        if (delta < -maxdelta) delta = -maxdelta;
        act.position += delta;
        setprop('/hydraulics/actuator/'#name#'/position', act.position);
    }
};

# helper routines
var set_pump_status = func(side, status) {
    if (hyd_state.pump[side] != nil) {
        hyd_state.pump[side] = status;
        setprop('/hydraulics/pump/'#side#'/status', status);
    }
};

var command_actuator = func(name, cmd) {
    if (hyd_state.actuators[name] != nil) {
        hyd_state.actuators[name].commanded = cmd;
        setprop('/hydraulics/actuator/'#name#'/commanded', cmd);
    }
};

# manager called from flight loop
var update_hydraulics_manager = func(dt) { update_hydraulics(dt); };
