# F-4J Electrical System Simulation (per NATOPS)
# Copyright (C) Matthew A.
# License: GPLv2+

# Switch states
var battery_on = 0;
var gen_left_on = 0;
var gen_right_on = 0;
var ext_power_on = 0;

# Failure simulation (0 = normal, 1 = failed)
var fail_gen_left = 0;
var fail_gen_right = 0;
var fail_tr1 = 0;
var fail_tr2 = 0;
var fail_battery = 0;

# Generator and battery specs
var gen_voltage_ac = 115.0;    # Volts AC, 400 Hz
var gen_kva = 30.0;            # kVA per generator
var battery_voltage_nom = 24.0;# Volts DC nominal
var battery_capacity = 20.0;   # Amp-hours
var battery_charge = battery_capacity; # Current charge (Ah)
var battery_discharge_rate = 5.0; # Amps (typical essential load)
var battery_min_voltage = 20.0; # Cutoff voltage

# Transformer-rectifier output (DC from AC)
var tr_voltage = 28.0;         # Volts DC

# Bus voltages
var ac_main_bus_v = 0.0;
var ac_ess_bus_v = 0.0;
var dc_main_bus_v = 0.0;
var dc_ess_bus_v = 0.0;
var battery_bus_v = 0.0;

# Example loads in amps (customize as needed)
var ac_main_load = 20.0;    # Amps
var ac_ess_load = 5.0;      # Amps
var dc_main_load = 15.0;    # Amps
var dc_ess_load = 5.0;      # Amps
var battery_bus_load = 1.0; # Amps

# Helper: is generator available?
var gen_left_avail = func { gen_left_on and !fail_gen_left; }
var gen_right_avail = func { gen_right_on and !fail_gen_right; }

# Helper: is TR available? (TR1: left, TR2: right)
var tr1_avail = func { (gen_left_avail() or ext_power_on) and !fail_tr1; }
var tr2_avail = func { (gen_right_avail() or ext_power_on) and !fail_tr2; }

# Helper: is battery available?
var battery_avail = func { battery_on and !fail_battery and battery_charge > 0.1; }

# Helper: is external power available?
var ext_power_avail = func { ext_power_on; }

# Main update logic
var update_electrical = func {
    # --- AC Main Bus ---
    # Priority: External Power > Either Generator > None
    if (ext_power_avail()) {
        ac_main_bus_v = gen_voltage_ac;
    } elsif (gen_left_avail() or gen_right_avail()) {
        ac_main_bus_v = gen_voltage_ac;
    } else {
        ac_main_bus_v = 0.0;
    }

    # --- AC Essential Bus ---
    # Normally powered by AC Main Bus
    if (ac_main_bus_v > 100.0) {
        ac_ess_bus_v = ac_main_bus_v;
    } else {
        ac_ess_bus_v = 0.0;
    }

    # --- DC Main Bus ---
    # Powered by both TRs (from AC Main or Ext Power)
    var tr_count = 0;
    if (tr1_avail()) tr_count += 1;
    if (tr2_avail()) tr_count += 1;
    if (tr_count == 2) {
        dc_main_bus_v = tr_voltage;
    } elsif (tr_count == 1) {
        dc_main_bus_v = tr_voltage * 0.9; # Slight drop if only one TR
    } else {
        dc_main_bus_v = 0.0;
    }

    # --- DC Essential Bus ---
    # Normally powered by DC Main Bus, else by battery if available
    if (dc_main_bus_v > 20.0) {
        dc_ess_bus_v = dc_main_bus_v;
    } elsif (battery_avail()) {
        dc_ess_bus_v = battery_voltage_nom * (battery_charge / battery_capacity);
    } else {
        dc_ess_bus_v = 0.0;
    }

    # --- Battery Bus (direct from battery if on) ---
    if (battery_avail()) {
        battery_bus_v = battery_voltage_nom * (battery_charge / battery_capacity);
    } else {
        battery_bus_v = 0.0;
    }

    # --- Load Shedding ---
    # If only battery is available, only DC Essential and Battery Bus are powered
    var dc_main_load_actual = 0.0;
    var dc_ess_load_actual = 0.0;
    var battery_bus_load_actual = 0.0;

    if (dc_main_bus_v > 20.0) {
        dc_main_load_actual = dc_main_load;
        dc_ess_load_actual = dc_ess_load;
    } elsif (dc_ess_bus_v > 20.0) {
        dc_ess_load_actual = dc_ess_load;
    }
    if (battery_bus_v > 20.0) {
        battery_bus_load_actual = battery_bus_load;
    }

    # --- Battery drain simulation (now based on actual loads) ---
    if (battery_on and !fail_battery) {
        var dt = getprop("/sim/time/delta-sec", 0.1);
        var amps = dc_ess_load_actual + battery_bus_load_actual;
        if (amps > 0) {
            battery_charge -= amps * (dt / 3600.0); # Ah = A * h
            if (battery_charge < 0.0) battery_charge = 0.0;
        }
    }

    # --- Set properties for use in cockpit/systems ---
    setprop("/systems/electrical/ac_main_bus_v", ac_main_bus_v);
    setprop("/systems/electrical/ac_ess_bus_v", ac_ess_bus_v);
    setprop("/systems/electrical/dc_main_bus_v", dc_main_bus_v);
    setprop("/systems/electrical/dc_ess_bus_v", dc_ess_bus_v);
    setprop("/systems/electrical/battery_bus_v", battery_bus_v);
    setprop("/systems/electrical/battery_charge", battery_charge);
    setprop("/systems/electrical/battery_on", battery_on);
    setprop("/systems/electrical/gen_left_on", gen_left_on);
    setprop("/systems/electrical/gen_right_on", gen_right_on);
    setprop("/systems/electrical/ext_power_on", ext_power_on);
    setprop("/systems/electrical/fail_gen_left", fail_gen_left);
    setprop("/systems/electrical/fail_gen_right", fail_gen_right);
    setprop("/systems/electrical/fail_tr1", fail_tr1);
    setprop("/systems/electrical/fail_tr2", fail_tr2);
    setprop("/systems/electrical/fail_battery", fail_battery);

    # Set load properties for cockpit display or debugging
    setprop("/systems/electrical/dc_main_load_actual", dc_main_load_actual);
    setprop("/systems/electrical/dc_ess_load_actual", dc_ess_load_actual);
    setprop("/systems/electrical/battery_bus_load_actual", battery_bus_load_actual);

    # Optional: Add warnings/alerts for bus loss or battery low
    setprop("/systems/electrical/battery_low", battery_charge < (0.2 * battery_capacity));
    setprop("/systems/electrical/ac_main_bus_fail", ac_main_bus_v < 100.0);
    setprop("/systems/electrical/dc_main_bus_fail", dc_main_bus_v < 20.0);
    setprop("/systems/electrical/dc_ess_bus_fail", dc_ess_bus_v < 20.0);
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
var set_ext_power = func(state) {
    ext_power_on = state;
    update_electrical();
};

# Failure handlers
var set_fail_gen_left = func(state) {
    fail_gen_left = state;
    update_electrical();
};
var set_fail_gen_right = func(state) {
    fail_gen_right = state;
    update_electrical();
};
var set_fail_tr1 = func(state) {
    fail_tr1 = state;
    update_electrical();
};
var set_fail_tr2 = func(state) {
    fail_tr2 = state;
    update_electrical();
};
var set_fail_battery = func(state) {
    fail_battery = state;
    update_electrical();
};

# Initialization and listeners
var init = func {
    setlistener("/controls/electrical/battery", func { set_battery(getprop("/controls/electrical/battery")); });
    setlistener("/controls/electrical/gen_left", func { set_gen_left(getprop("/controls/electrical/gen_left")); });
    setlistener("/controls/electrical/gen_right", func { set_gen_right(getprop("/controls/electrical/gen_right")); });
    setlistener("/controls/electrical/ext_power", func { set_ext_power(getprop("/controls/electrical/ext_power")); });
    setlistener("/controls/electrical/fail_gen_left", func { set_fail_gen_left(getprop("/controls/electrical/fail_gen_left")); });
    setlistener("/controls/electrical/fail_gen_right", func { set_fail_gen_right(getprop("/controls/electrical/fail_gen_right")); });
    setlistener("/controls/electrical/fail_tr1", func { set_fail_tr1(getprop("/controls/electrical/fail_tr1")); });
    setlistener("/controls/electrical/fail_tr2", func { set_fail_tr2(getprop("/controls/electrical/fail_tr2")); });
    setlistener("/controls/electrical/fail_battery", func { set_fail_battery(getprop("/controls/electrical/fail_battery")); });
    settimer(update_electrical, 0.1); # periodic update for battery drain
    update_electrical();
}
_setlistener("/nasal/electrical/loaded", init);
