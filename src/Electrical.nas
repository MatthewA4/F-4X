# Electrical.nas - simple electrical bus and inverter logic

var elec = {
    main_bus_ok: 1,
    aux_bus_ok: 1,
    battery_voltage: 28.0,
};

var init_electrical = func() {
    setprop('/electrical/main-bus-ok', elec.main_bus_ok);
    setprop('/electrical/aux-bus-ok', elec.aux_bus_ok);
    setprop('/electrical/battery-voltage', elec.battery_voltage);
};

var update_electrical = func(dt) {
    var main_ok = getprop('/systems/electrical/main-switch') or 1;
    var aux_ok = getprop('/systems/electrical/aux-switch') or 0;
    var auto_failover = getprop('/systems/electrical/auto-failover') or 1;

    elec.main_bus_ok = main_ok;
    elec.aux_bus_ok = aux_ok;

    # Automatic switchover: if main bus lost and aux available, route aux to essential bus
    if (!main_ok and aux_ok and auto_failover) {
        setprop('/electrical/ess-bus-powered', 1);
    } else {
        setprop('/electrical/ess-bus-powered', main_ok ? 1 : (aux_ok ? 1 : 0));
    }

    # Battery voltage sags if both buses lost
    if (!main_ok and !aux_ok) {
        elec.battery_voltage = math.max(0, elec.battery_voltage - 5.0 * dt);
    } else {
        elec.battery_voltage += (28.0 - elec.battery_voltage) * math.min(1.0, dt * 0.5);
    }

    setprop('/electrical/main-bus-ok', elec.main_bus_ok);
    setprop('/electrical/aux-bus-ok', elec.aux_bus_ok);
    setprop('/electrical/battery-voltage', elec.battery_voltage);

    # Annunciator if voltage low
    setprop('/afcs/annunciator/electrical-fault', elec.battery_voltage < 18.0 ? 1 : 0);
};

init_electrical();

var update_electrical_manager = func(dt) { update_electrical(dt); };
