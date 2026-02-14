# Cockpit instruments: ADI, HSI, Engine gauges, HUD hooks

var init_cockpit_instruments = func() {
    setprop("/instruments/adi/pitch-deg", 0);
    setprop("/instruments/adi/roll-deg", 0);
    setprop("/instruments/hsi/heading-deg", 0);
    setprop("/instruments/hud/airspeed-kt", 0);
    setprop("/instruments/engine/left-n1", 0);
    setprop("/instruments/engine/right-n1", 0);
    setprop("/instruments/engine/left-n2", 0);
    setprop("/instruments/engine/right-n2", 0);
    setprop("/instruments/fuel/total-lb", 0);
};

var update_cockpit_instruments = func(dt) {
    var pitch = getprop("/orientation/pitch-deg", 0);
    var roll = getprop("/orientation/roll-deg", 0);
    var hdg = getprop("/orientation/heading-deg", 0) % 360.0;
    var ias = getprop("/velocities/airspeed-kt", 0);

    setprop("/instruments/adi/pitch-deg", pitch);
    setprop("/instruments/adi/roll-deg", roll);
    setprop("/instruments/hsi/heading-deg", hdg);
    setprop("/instruments/hud/airspeed-kt", ias);

    # Engines (JSBSim properties)
    var left_n1 = getprop("/engines/engine[0]/n1", 0);
    var right_n1 = getprop("/engines/engine[1]/n1", 0);
    var left_n2 = getprop("/engines/engine[0]/n2", 0);
    var right_n2 = getprop("/engines/engine[1]/n2", 0);

    setprop("/instruments/engine/left-n1", left_n1);
    setprop("/instruments/engine/right-n1", right_n1);
    setprop("/instruments/engine/left-n2", left_n2);
    setprop("/instruments/engine/right-n2", right_n2);

    # Fuel (sum internal + external if present)
    var internal = getprop("/fdm/jsbsim/fuel/total-weight-lbs", 0) or getprop("/fdm/jsbsim/inertia/total-weight-lbs", 0);
    var ext_fuel = 0;
    # some configurations expose external tanks; try common props
    ext_fuel += getprop("/payload/external-tank/left/weight-lb", 0);
    ext_fuel += getprop("/payload/external-tank/right/weight-lb", 0);
    setprop("/instruments/fuel/total-lb", internal + ext_fuel);
};

init_cockpit_instruments();
