#Copyright (C) Matthew A.
// License: GPLv2+

# Switch states
var battery_on = 0;
var gen_left_on = 0;
var gen_right_on = 0;

# Generator and battery specs (F-4J typical)
var gen_voltage_ac = 115.0;    # Volts AC, 400 Hz
var gen_kva = 30.0;            # kVA per generator
var battery_voltage = 24.0;    # Volts DC
var battery_capacity = 20.0;   # Amp-hours

# Transformer-rectifier output (DC from AC)
var tr_voltage = 28.0;         # Volts DC

# Bus voltages
var ac_main_bus_v = 0.0;
var dc_main_bus_v = 0.0;
var dc_essential_bus_v = 0.0;

# Update logic for electrical system
var update_electrical = func {
    # AC Main Bus: powered if either generator is online
    if (gen_left_on or gen_right_on) {
        ac_main_bus_v = gen_voltage_ac;
    } else {
        ac_main_bus_v = 0.0;
    }

    # DC Main Bus: powered by transformer-rectifiers if AC available, else battery if on
    if (ac_main_bus_v > 100.0) {
        dc_main_bus_v = tr_voltage;
    } elsif (battery_on) {
        dc_main_bus_v = battery_voltage;
    } else {
        dc_main_bus_v = 0.0;
    }

    # DC Essential Bus: always powered if battery is on, else from DC main bus
    if (battery_on) {
        dc_essential_bus_v = battery_voltage;
    } elsif (dc_main_bus_v > 20.0) {
        dc_essential_bus_v = dc_main_bus_v;
    } else {
        dc_essential_bus_v = 0.0;
    }

    # Set properties for use in cockpit/systems
    setprop("/systems/electrical/ac_main_bus_v", ac_main_bus_v);
    setprop("/systems/electrical/dc_main_bus_v", dc_main_bus_v);
    setprop("/systems/electrical/dc_essential_bus_v", dc_essential_bus_v);
    setprop("/systems/electrical/battery_on", battery_on);
    setprop("/systems/electrical/gen_left_on", gen_left_on);
    setprop("/systems/electrical/gen_right_on", gen_right_on);
};

# Switch handlers
var set_battery = func(state) {
    battery_on = state;
    update_electrical();
};

var set_gen_left = func(state) {
    gen_left_on = state;
    update_electrical();
};

var set_gen_right = func(state) {
    gen_right_on = state;
    update_electrical();
};

# Initialization and listeners
var init = func {
    setlistener("/controls/electrical/battery", func { set_battery(getprop("/controls/electrical/battery")); });
    setlistener("/controls/electrical/gen_left", func { set_gen_left(getprop("/controls/electrical/gen_left")); });
    setlistener("/controls/electrical/gen_right", func { set_gen_right(getprop("/controls/electrical/gen_right")); });
    update_electrical();
}
_setlistener("/nasal/electrical/loaded", init);
