#Copyright (C) Matthew A.
#F-4J Phantom II Hydraulics System (detailed simulation)

// Engine-driven pump states
var eng_left_running = 1;
var eng_right_running = 1;

// System specs (F-4J typical)
var hyd_a_nominal = 3000.0; # psi
var hyd_b_nominal = 3000.0; # psi
var accumulator_a_nom = 1500.0; # psi
var accumulator_b_nom = 1500.0; # psi
var brake_accumulator_nom = 1200.0; # psi

// Fluid quantity (gallons, F-4J: ~2.5 gal per system)
var hyd_a_qty = 2.5;
var hyd_b_qty = 2.5;
var hyd_a_qty_min = 0.5;
var hyd_b_qty_min = 0.5;

// System pressures
var hyd_a_psi = 0.0;
var hyd_b_psi = 0.0;
var accumulator_a_psi = accumulator_a_nom;
var accumulator_b_psi = accumulator_b_nom;
var brake_accumulator_psi = brake_accumulator_nom;

// Failure simulation
var hyd_a_leak = 0; # 0 = no leak, 1 = leak
var hyd_b_leak = 0;
var hyd_a_pump_fail = 0;
var hyd_b_pump_fail = 0;

// Emergency RAT (Ram Air Turbine)
var rat_deployed = 0;
var rat_pressure = 2000.0; # psi when deployed

// Crossfeed/Isolation
var crossfeed_open = 0; # If open, A & B can supply each other
var a_isolated = 0;
var b_isolated = 0;

// Subsystem loads (psi drop per update if active)
var flight_controls_active = 1; # always on
var gear_active = 0;
var brakes_active = 0;
var probe_active = 0;
var flaps_active = 0;

var flight_controls_drop = 50.0;
var gear_drop = 200.0;
var brakes_drop = 100.0;
var probe_drop = 50.0;
var flaps_drop = 30.0;

// Accumulator discharge rates
var accumulator_discharge = 20.0;
var brake_accumulator_discharge = 50.0;

// Update logic for hydraulic system
var update_hydraulics = func {
    # Leak simulation
    if (hyd_a_leak and hyd_a_qty > hyd_a_qty_min) hyd_a_qty -= 0.01;
    if (hyd_b_leak and hyd_b_qty > hyd_b_qty_min) hyd_b_qty -= 0.01;

    # System A logic
    var a_pump_on = eng_left_running and !hyd_a_pump_fail and !a_isolated and hyd_a_qty > hyd_a_qty_min;
    if (a_pump_on) {
        hyd_a_psi = hyd_a_nominal;
        accumulator_a_psi = hyd_a_nominal * 0.5;
    } elsif (rat_deployed and hyd_a_qty > hyd_a_qty_min) {
        hyd_a_psi = rat_pressure;
        accumulator_a_psi = rat_pressure * 0.5;
    } elsif (hyd_a_qty > hyd_a_qty_min) {
        hyd_a_psi = accumulator_a_psi;
        accumulator_a_psi = math.max(accumulator_a_psi - accumulator_discharge, 0.0);
    } else {
        hyd_a_psi = 0.0;
        accumulator_a_psi = 0.0;
    }

    # System B logic
    var b_pump_on = eng_right_running and !hyd_b_pump_fail and !b_isolated and hyd_b_qty > hyd_b_qty_min;
    if (b_pump_on) {
        hyd_b_psi = hyd_b_nominal;
        accumulator_b_psi = hyd_b_nominal * 0.5;
    } elsif (rat_deployed and hyd_b_qty > hyd_b_qty_min) {
        hyd_b_psi = rat_pressure;
        accumulator_b_psi = rat_pressure * 0.5;
    } elsif (hyd_b_qty > hyd_b_qty_min) {
        hyd_b_psi = accumulator_b_psi;
        accumulator_b_psi = math.max(accumulator_b_psi - accumulator_discharge, 0.0);
    } else {
        hyd_b_psi = 0.0;
        accumulator_b_psi = 0.0;
    }

    # Crossfeed logic
    if (crossfeed_open) {
        if (hyd_a_psi > hyd_b_psi and hyd_a_qty > hyd_a_qty_min) {
            hyd_b_psi = hyd_a_psi * 0.9;
        } elsif (hyd_b_psi > hyd_a_psi and hyd_b_qty > hyd_b_qty_min) {
            hyd_a_psi = hyd_b_psi * 0.9;
        }
    }

    # Subsystem loads
    if (flight_controls_active) {
        hyd_a_psi = math.max(hyd_a_psi - flight_controls_drop, 0.0);
        hyd_b_psi = math.max(hyd_b_psi - flight_controls_drop, 0.0);
    }
    if (gear_active) {
        hyd_a_psi = math.max(hyd_a_psi - gear_drop, 0.0);
        hyd_b_psi = math.max(hyd_b_psi - gear_drop, 0.0);
    }
    if (brakes_active) {
        hyd_a_psi = math.max(hyd_a_psi - brakes_drop, 0.0);
        hyd_b_psi = math.max(hyd_b_psi - brakes_drop, 0.0);
        brake_accumulator_psi = math.max(brake_accumulator_psi - brake_accumulator_discharge, 0.0);
    }
    if (probe_active) {
        hyd_a_psi = math.max(hyd_a_psi - probe_drop, 0.0);
    }
    if (flaps_active) {
        hyd_b_psi = math.max(hyd_b_psi - flaps_drop, 0.0);
    }

    # Emergency brake accumulator recharge
    if (hyd_a_psi > brake_accumulator_psi + 100.0) {
        brake_accumulator_psi = hyd_a_psi * 0.4;
    }

    # Set properties for cockpit/systems
    setprop("/systems/hydraulics/a_psi", hyd_a_psi);
    setprop("/systems/hydraulics/b_psi", hyd_b_psi);
    setprop("/systems/hydraulics/a_qty", hyd_a_qty);
    setprop("/systems/hydraulics/b_qty", hyd_b_qty);
    setprop("/systems/hydraulics/a_leak", hyd_a_leak);
    setprop("/systems/hydraulics/b_leak", hyd_b_leak);
    setprop("/systems/hydraulics/a_pump_fail", hyd_a_pump_fail);
    setprop("/systems/hydraulics/b_pump_fail", hyd_b_pump_fail);
    setprop("/systems/hydraulics/accumulator_a_psi", accumulator_a_psi);
    setprop("/systems/hydraulics/accumulator_b_psi", accumulator_b_psi);
    setprop("/systems/hydraulics/brake_accumulator_psi", brake_accumulator_psi);
    setprop("/systems/hydraulics/rat_deployed", rat_deployed);
    setprop("/systems/hydraulics/crossfeed_open", crossfeed_open);
    setprop("/systems/hydraulics/a_isolated", a_isolated);
    setprop("/systems/hydraulics/b_isolated", b_isolated);
};

# Handlers for system state
var set_eng_left = func(state) { eng_left_running = state; update_hydraulics(); };
var set_eng_right = func(state) { eng_right_running = state; update_hydraulics(); };
var set_brakes = func(state) { brakes_active = state; update_hydraulics(); };
var set_gear = func(state) { gear_active = state; update_hydraulics(); };
var set_probe = func(state) { probe_active = state; update_hydraulics(); };
var set_flaps = func(state) { flaps_active = state; update_hydraulics(); };
var set_leak_a = func(state) { hyd_a_leak = state; };
var set_leak_b = func(state) { hyd_b_leak = state; };
var set_pump_fail_a = func(state) { hyd_a_pump_fail = state; };
var set_pump_fail_b = func(state) { hyd_b_pump_fail = state; };
var set_rat = func(state) { rat_deployed = state; };
var set_crossfeed = func(state) { crossfeed_open = state; };
var set_a_isolated = func(state) { a_isolated = state; };
var set_b_isolated = func(state) { b_isolated = state; };

# Initialization and listeners
var init = func {
    setlistener("/engines/engine[0]/running", func { set_eng_left(getprop("/engines/engine[0]/running")); });
    setlistener("/engines/engine[1]/running", func { set_eng_right(getprop("/engines/engine[1]/running")); });
    # Add listeners for cockpit controls, failures, RAT, crossfeed, isolation, etc.
    update_hydraulics();
}
_setlistener("/nasal/hydraulics/loaded", init);