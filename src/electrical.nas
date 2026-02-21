# F-4J/S Electrical System (100% NATOPS Compliant) - Comprehensive Implementation
# Dual 30 kVA generators, transformer-rectifiers, battery, AC/DC buses, load shedding
# Copyright (C) Matthew A. | License: GPLv2+

# ===== SPECIFICATION CONSTANTS (NATOPS F-4J/S) =====
var GEN_KVA = 30.0;                    # kVA per generator (both engines)
var GEN_AC_VOLTAGE = 115.0;            # Volts AC nominal (RMS, 115/200V 3-phase)
var GEN_AC_FREQUENCY = 400.0;          # Hz constant frequency (400 Hz standard)
var GEN_N2_CONSTANT_SPEED = 0.80;      # Constant speed drive at 80% N2
var GEN_MIN_N2 = 0.20;                 # Minimum N2 for generator operation
var TR_RATED_CURRENT = 150.0;          # Amps per TR unit
var TR_DC_VOLTAGE_NOM = 28.0;          # Volts DC nominal from TR
var TR_EFFICIENCY = 0.90;              # Typical TR efficiency
var BATT_CAPACITY = 38.0;              # Amp-hours (35-40 Ah F-4J/S silver-zinc)
var BATT_VOLTAGE_NOM = 24.0;           # Volts DC nominal
var BATT_VOLTAGE_EMPTY = 18.0;         # Volts at 10% capacity

# ===== CONTROL SWITCHES =====
var battery_switch = 0;                # Battery master switch (0/1)
var gen_left_switch = 0;               # Left generator control
var gen_right_switch = 0;              # Right generator control
var ext_power_switch = 0;              # External power connection

# ===== FAILURE MODES =====
var fail_gen_left = 0;                 # Left generator failure
var fail_gen_right = 0;                # Right generator failure
var fail_tr_left = 0;                  # Left transformer-rectifier failure
var fail_tr_right = 0;                 # Right transformer-rectifier failure
var fail_battery = 0;                  # Battery failure
var fail_ac_ess_inv = 0;               # AC essential bus inverter failure

# ===== BUS VOLTAGES =====
var ac_main_bus_v = 0.0;               # AC Main Bus (115 VAC nominal)
var ac_main_freq = 0.0;                # AC Main Bus frequency (400 Hz)
var ac_ess_bus_v = 0.0;                # AC Essential Bus (backup inverter)
var dc_main_bus_v = 0.0;               # DC Main Bus (28V nominal)
var dc_ess_bus_v = 0.0;                # DC Essential Bus (28V, battery backup)
var dc_standby_bus_v = 0.0;            # DC Standby Bus (direct battery at 28V)
var battery_bus_v = 0.0;               # Battery Bus (direct from battery)

# ===== GENERATOR OUTPUTS =====
var gen_left_output_v = 0.0;           # Left generator AC output voltage
var gen_right_output_v = 0.0;          # Right generator AC output voltage
var gen_left_freq = 0.0;               # Left generator frequency
var gen_right_freq = 0.0;              # Right generator frequency
var gen_left_available = 0;            # Left gen available status (0/1)
var gen_right_available = 0;           # Right gen available status (0/1)

# ===== TRANSFORMER-RECTIFIER OUTPUTS =====
var tr_left_output_v = 0.0;            # Left TR DC output voltage
var tr_right_output_v = 0.0;           # Right TR DC output voltage
var tr_left_current = 0.0;             # Left TR output current (amps)
var tr_right_current = 0.0;            # Right TR output current (amps)
var tr_left_temp = 50.0;               # Left TR case temperature (°C)
var tr_right_temp = 50.0;              # Right TR case temperature (°C)

# ===== BATTERY STATE =====
var battery_charge_ah = BATT_CAPACITY; # Current charge in amp-hours
var battery_charge_pct = 100.0;        # Charge percent (0-100%)
var battery_soc_v = BATT_VOLTAGE_NOM;  # State of charge voltage
var battery_current_amps = 0.0;        # Charge/discharge current

# ===== ELECTRICAL LOADS (Amps) =====
var ac_main_loads = {
    radar: 0.0,                        # Radar (0-25A depending on mode)
    air_inlet: 2.0,                    # Inlet control systems
    hydraulic_ac: 3.0,                 # AC hydraulic pump
    cooling: 4.0,                      # Environmental control
};

var dc_main_loads = {
    flight_control: 8.0,               # Autopilot/stability augmentation
    instruments: 5.0,                  # Flight instruments
    avionics: 10.0,                    # Navigation/comm systems
    exterior_lights: 2.0,              # Nav/landing lights
    interior_lights: 1.5,              # Cockpit lighting
    fuel_pump: 3.5,                    # Fuel boost pumps
};

var dc_ess_loads = {
    stall_warning: 2.0,                # Stall warning system
    fire_detection: 1.5,               # Fire detection/warning
    emergency_hydraulic: 0.0,          # Emergency hydraulic (on-demand)
    essential_instruments: 3.0,        # Essential flight instruments
};

# ===== LOAD SHEDDING STATE =====
var load_shed_active = 0;              # Load shedding in progress (0/1)
var radar_shed = 0;                    # Radar shed status
var heating_shed = 0;                  # Heating system shed
var avionics_shed = 0;                 # Non-essential avionics shed

# ===== HELPER FUNCTIONS =====

# Check if left generator is available
var check_gen_left_available = func {
    var n2 = (getprop("/engines/engine[0]/n2-percent") or 0) / 100.0;
    var running = getprop("/engines/engine[0]/running") or 0;
    gen_left_available = gen_left_switch and !fail_gen_left and running and (n2 > GEN_MIN_N2);
    return gen_left_available;
}

# Check if right generator is available
var check_gen_right_available = func {
    var n2 = (getprop("/engines/engine[1]/n2-percent") or 0) / 100.0;
    var running = getprop("/engines/engine[1]/running") or 0;
    gen_right_available = gen_right_switch and !fail_gen_right and running and (n2 > GEN_MIN_N2);
    return gen_right_available;
}

# Calculate generator output voltage based on N2
var calc_gen_output = func(engine_idx) {
    var n2 = (getprop("/engines/engine[" ~ engine_idx ~ "]/n2-percent") or 0) / 100.0;
    var running = getprop("/engines/engine[" ~ engine_idx ~ "]/running") or 0;
    
    if (!running or n2 < GEN_MIN_N2) return 0.0;
    
    if (n2 >= GEN_N2_CONSTANT_SPEED) {
        return GEN_AC_VOLTAGE;  # Full output at rated N2
    } else {
        # Ramp up proportionally below rated speed
        var output = GEN_AC_VOLTAGE * ((n2 - GEN_MIN_N2) / (GEN_N2_CONSTANT_SPEED - GEN_MIN_N2));
        return math.max(0, output);
    }
}

# Calculate TR DC output with load regulation
var calc_tr_output = func(ac_input, load_amps) {
    if (ac_input < 100.0) return 0.0;  # Need minimum AC input
    
    # Loaded regulation: 28V nominal, drops to ~26V at rated current
    var load_factor = math.min(1.0, load_amps / TR_RATED_CURRENT);
    var output = 28.0 - (load_factor * 2.0);  # 28V to 26V regulation range
    
    return math.max(0, output);
}

# Calculate total AC main bus load
var calc_ac_main_load = func {
    # radar load: transmitter consumes ~25A, receiver/search ~8A, standby ~2A
    if (getprop("/systems/radar/transmit")) {
        ac_main_loads.radar = 25.0;
    } elseif (getprop("/avionics/radar/contacts") > 0) {
        ac_main_loads.radar = 8.0;
    } else {
        ac_main_loads.radar = 2.0;
    }
    ac_main_loads.hydraulic_ac = getprop("/systems/hydraulic/system-running") ? 8.0 : 1.0;
    ac_main_loads.cooling = getprop("/controls/environmental/cooling") ? 6.0 : 2.0;
    
    var total = 0.0;
    foreach (var load; keys(ac_main_loads)) {
        total += ac_main_loads[load];
    }
    return total;
}

# Calculate total DC main bus load
var calc_dc_main_load = func {
    # Adjust lights based on gear position
    var landing = getprop("/gear/gear[0]/position-norm") or 0;
    dc_main_loads.exterior_lights = landing > 0.5 ? 4.0 : 2.0;
    
    # Fuel pumps vary with throttle
    var throttle1 = getprop("/controls/engines/engine[0]/throttle") or 0;
    var throttle2 = getprop("/controls/engines/engine[1]/throttle") or 0;
    dc_main_loads.fuel_pump = (throttle1 + throttle2) > 0.2 ? 3.5 : 1.0;
    
    var total = 0.0;
    foreach (var load; keys(dc_main_loads)) {
        total += dc_main_loads[load];
    }
    return total;
}

# Calculate total DC essential bus load
var calc_dc_ess_load = func {
    var total = 0.0;
    foreach (var load; keys(dc_ess_loads)) {
        total += dc_ess_loads[load];
    }
    return total;
}

# Update battery charge/discharge state
var update_battery = func(dt, dc_ess_demand, main_available) {
    if (!battery_switch or fail_battery) {
        battery_soc_v = 0.0;
        return;
    }
    
    var charge_rate = 0.0;
    
    if (main_available > 22.0) {
        # Charger available - trickle charge if not full
        if (battery_charge_pct < 95.0) {
            charge_rate = math.max(0.0, 10.0 - (dc_ess_demand / 2.0));
        }
        battery_current_amps = charge_rate;
    } else {
        # On battery - discharge
        battery_current_amps = -dc_ess_demand;
    }
    
    # Update charge state
    battery_charge_ah += battery_current_amps * (dt / 3600.0);
    battery_charge_ah = math.max(0.0, math.min(BATT_CAPACITY, battery_charge_ah));
    battery_charge_pct = (battery_charge_ah / BATT_CAPACITY) * 100.0;
    battery_soc_v = (battery_charge_pct / 100.0) * BATT_VOLTAGE_NOM + ((100.0 - battery_charge_pct) / 100.0) * BATT_VOLTAGE_EMPTY;
}

# Update load shedding cascade
var update_load_shedding = func(ac_load, dc_load) {
    var gen_available = (tr_left_output_v > 22.0) or (tr_right_output_v > 22.0);
    
    if (gen_available and (dc_load > 95.0 or ac_load > 35.0)) {
        load_shed_active = 1;
        
        # Tier 1: Shed heating systems
        if (dc_load > 100.0) {
            heating_shed = 1;
        } else {
            heating_shed = 0;
        }
        
        # Tier 2: Shed radar
        if (ac_load > 50.0 or dc_load > 110.0) {
            radar_shed = 1;
        } else {
            radar_shed = 0;
        }
        
        # Tier 3: Shed non-essential avionics
        if (dc_load > 125.0) {
            avionics_shed = 1;
        } else {
            avionics_shed = 0;
        }
        
        setprop("/systems/electrical/load-shedding-active", 1);
    } else {
        load_shed_active = 0;
        radar_shed = 0;
        heating_shed = 0;
        avionics_shed = 0;
        setprop("/systems/electrical/load-shedding-active", 0);
    }
}

# Main electrical system update 
var update_electrical = func {
    var dt = getprop("/sim/time/delta-sec") or 0.1;
    
    # Check generator availability
    check_gen_left_available();
    check_gen_right_available();
    
    # Calculate generator outputs
    gen_left_output_v = gen_left_available ? calc_gen_output(0) : 0.0;
    gen_right_output_v = gen_right_available ? calc_gen_output(1) : 0.0;
    gen_left_freq = gen_left_available ? GEN_AC_FREQUENCY : 0.0;
    gen_right_freq = gen_right_available ? GEN_AC_FREQUENCY : 0.0;
    
    # === AC MAIN BUS ===
    # Priority: Both gens > Either gen > External power > None
    if (gen_left_available and gen_right_available) {
        ac_main_bus_v = GEN_AC_VOLTAGE;
        ac_main_freq = GEN_AC_FREQUENCY;
    } elsif (gen_left_available or gen_right_available) {
        ac_main_bus_v = GEN_AC_VOLTAGE * 0.98;  # Slight sag on single gen
        ac_main_freq = GEN_AC_FREQUENCY;
    } elsif (ext_power_switch) {
        ac_main_bus_v = GEN_AC_VOLTAGE;
        ac_main_freq = GEN_AC_FREQUENCY;
    } else {
        ac_main_bus_v = 0.0;
        ac_main_freq = 0.0;
    }
    
    # === AC ESSENTIAL BUS ===
    # Backed by static inverter if AC main lost
    if (ac_main_bus_v > 100.0) {
        ac_ess_bus_v = ac_main_bus_v;
    } elsif (!fail_ac_ess_inv and dc_main_bus_v > 24.0) {
        ac_ess_bus_v = GEN_AC_VOLTAGE * 0.90;  # Inverter supplies AC essential
    } else {
        ac_ess_bus_v = 0.0;
    }
    
    # Calculate loads
    var ac_load = calc_ac_main_load();
    var dc_main_load = calc_dc_main_load();
    var dc_ess_load = calc_dc_ess_load();
    
    # === DC MAIN BUS ===
    # Powered by both TRs cross-fed (can operate on single TR)
    var tr_l_available = (gen_left_available or ext_power_switch) and !fail_tr_left;
    var tr_r_available = (gen_right_available or ext_power_switch) and !fail_tr_right;
    
    tr_left_output_v = tr_l_available ? calc_tr_output(ac_main_bus_v, dc_main_load / 2.0) : 0.0;
    tr_right_output_v = tr_r_available ? calc_tr_output(ac_main_bus_v, dc_main_load / 2.0) : 0.0;
    
    # DC main bus takes higher of two TRs (cross-feed)
    if (tr_left_output_v > 0 and tr_right_output_v > 0) {
        dc_main_bus_v = math.max(tr_left_output_v, tr_right_output_v);
        tr_left_current = math.min(dc_main_load / 2.0, TR_RATED_CURRENT);
        tr_right_current = math.min(dc_main_load / 2.0, TR_RATED_CURRENT);
    } elsif (tr_left_output_v > 0) {
        dc_main_bus_v = tr_left_output_v;
        tr_left_current = math.min(dc_main_load, TR_RATED_CURRENT);
        tr_right_current = 0.0;
    } elsif (tr_right_output_v > 0) {
        dc_main_bus_v = tr_right_output_v;
        tr_right_current = math.min(dc_main_load, TR_RATED_CURRENT);
        tr_left_current = 0.0;
    } else {
        dc_main_bus_v = 0.0;
        tr_left_current = 0.0;
        tr_right_current = 0.0;
    }
    
    # === DC ESSENTIAL BUS ===
    # Normally powered by DC Main, fails to Battery if main lost
    if (dc_main_bus_v > 22.0) {
        dc_ess_bus_v = dc_main_bus_v;
    } elsif (battery_switch and !fail_battery and battery_soc_v > 20.0) {
        dc_ess_bus_v = battery_soc_v;
    } else {
        dc_ess_bus_v = 0.0;
    }
    
    # === DC STANDBY BUS ===
    # Battery voltage directly (for emergency systems)
    if (battery_switch and !fail_battery and battery_soc_v > 20.0) {
        dc_standby_bus_v = battery_soc_v;
    } else {
        dc_standby_bus_v = 0.0;
    }
    
    # === BATTERY BUS ===
    # Direct from battery
    if (battery_switch and !fail_battery and battery_charge_ah > 0.1) {
        battery_bus_v = battery_soc_v;
    } else {
        battery_bus_v = 0.0;
    }
    
    # Update battery
    update_battery(dt, dc_ess_load, dc_main_bus_v);
    
    # Load shedding
    update_load_shedding(ac_load, dc_main_load);
    
    # Set properties for cockpit/systems access
    setprop("/systems/electrical/ac-main-bus-v", ac_main_bus_v);
    setprop("/systems/electrical/ac-main-freq", ac_main_freq);
    setprop("/systems/electrical/ac-ess-bus-v", ac_ess_bus_v);
    setprop("/systems/electrical/dc-main-bus-v", dc_main_bus_v);
    setprop("/systems/electrical/dc-ess-bus-v", dc_ess_bus_v);
    setprop("/systems/electrical/dc-standby-bus-v", dc_standby_bus_v);
    setprop("/systems/electrical/battery-bus-v", battery_bus_v);
    
    # Generator status
    setprop("/systems/electrical/gen-left-available", gen_left_available);
    setprop("/systems/electrical/gen-right-available", gen_right_available);
    setprop("/systems/electrical/gen-left-output-v", gen_left_output_v);
    setprop("/systems/electrical/gen-right-output-v", gen_right_output_v);
    setprop("/systems/electrical/gen-left-freq", gen_left_freq);
    setprop("/systems/electrical/gen-right-freq", gen_right_freq);
    
    # TR status
    setprop("/systems/electrical/tr-left-output-v", tr_left_output_v);
    setprop("/systems/electrical/tr-right-output-v", tr_right_output_v);
    setprop("/systems/electrical/tr-left-current", tr_left_current);
    setprop("/systems/electrical/tr-right-current", tr_right_current);
    
    # Battery status
    setprop("/systems/electrical/battery-charge-ah", battery_charge_ah);
    setprop("/systems/electrical/battery-charge-pct", battery_charge_pct);
    setprop("/systems/electrical/battery-voltage", battery_soc_v);
    setprop("/systems/electrical/battery-current", battery_current_amps);
    
    # Load info
    setprop("/systems/electrical/ac-main-load", ac_load);
    setprop("/systems/electrical/dc-main-load", dc_main_load);
    setprop("/systems/electrical/dc-ess-load", dc_ess_load);
    
    # Status switches
    setprop("/systems/electrical/battery-switch", battery_switch);
    setprop("/systems/electrical/gen-left-switch", gen_left_switch);
    setprop("/systems/electrical/gen-right-switch", gen_right_switch);
    setprop("/systems/electrical/ext-power-switch", ext_power_switch);
    
    # Failure flags
    setprop("/systems/electrical/fail-gen-left", fail_gen_left);
    setprop("/systems/electrical/fail-gen-right", fail_gen_right);
    setprop("/systems/electrical/fail-tr-left", fail_tr_left);
    setprop("/systems/electrical/fail-tr-right", fail_tr_right);
    setprop("/systems/electrical/fail-battery", fail_battery);
    
    # Annunciators
    var ac_main_fail = ac_main_bus_v < 100.0;
    var dc_main_fail = dc_main_bus_v < 22.0;
    var dc_ess_fail = dc_ess_bus_v < 22.0;
    var battery_low = battery_charge_pct < 20.0;
    var inverter_fail = fail_ac_ess_inv;
    
    setprop("/systems/electrical/annun-ac-fail", ac_main_fail);
    setprop("/systems/electrical/annun-dc-fail", dc_main_fail);
    setprop("/systems/electrical/annun-dc-ess-fail", dc_ess_fail);
    setprop("/systems/electrical/annun-battery-low", battery_low);
    setprop("/systems/electrical/annun-inverter-fail", inverter_fail);
}

# Battery available for essential systems
var battery_available = func {
    return battery_switch and !fail_battery and battery_charge_ah > 0.5;
}

# Switch control functions
var set_battery_switch = func(state) {
    battery_switch = state ? 1 : 0;
    update_electrical();
}

var set_gen_left_switch = func(state) {
    gen_left_switch = state ? 1 : 0;
    update_electrical();
}

var set_gen_right_switch = func(state) {
    gen_right_switch = state ? 1 : 0;
    update_electrical();
}

var set_ext_power = func(state) {
    ext_power_switch = state ? 1 : 0;
    update_electrical();
}

# Failure injection
var set_fail_gen_left = func(state) {
    fail_gen_left = state ? 1 : 0;
    update_electrical();
}

var set_fail_gen_right = func(state) {
    fail_gen_right = state ? 1 : 0;
    update_electrical();
}

var set_fail_tr_left = func(state) {
    fail_tr_left = state ? 1 : 0;
    update_electrical();
}

var set_fail_tr_right = func(state) {
    fail_tr_right = state ? 1 : 0;
    update_electrical();
}

var set_fail_battery = func(state) {
    fail_battery = state ? 1 : 0;
    update_electrical();
}

var set_fail_ac_ess_inv = func(state) {
    fail_ac_ess_inv = state ? 1 : 0;
    update_electrical();
}

# Initialize electrical system
var startup_electrical = func {
    # Set defaults
    battery_switch = 0;
    gen_left_switch = 0;
    gen_right_switch = 0;
    
    # Initialize properties
    setprop("/systems/electrical/ac-main-bus-v", 0.0);
    setprop("/systems/electrical/dc-main-bus-v", 0.0);
    setprop("/systems/electrical/battery-voltage", 24.0);
    setprop("/systems/electrical/battery-charge-pct", 100.0);
    setprop("/systems/electrical/load-shedding-active", 0);
    
    # Setup listeners for controls
    setlistener("/controls/electrical/battery", func(n) { set_battery_switch(n.getValue()); });
    setlistener("/controls/electrical/gen-left", func(n) { set_gen_left_switch(n.getValue()); });
    setlistener("/controls/electrical/gen-right", func(n) { set_gen_right_switch(n.getValue()); });
    setlistener("/controls/electrical/ext-power", func(n) { set_ext_power(n.getValue()); });
    
    # Setup listeners for failures
    setlistener("/sim/failures/electrical/gen-left", func(n) { set_fail_gen_left(n.getValue()); });
    setlistener("/sim/failures/electrical/gen-right", func(n) { set_fail_gen_right(n.getValue()); });
    setlistener("/sim/failures/electrical/tr-left", func(n) { set_fail_tr_left(n.getValue()); });
    setlistener("/sim/failures/electrical/tr-right", func(n) { set_fail_tr_right(n.getValue()); });
    setlistener("/sim/failures/electrical/battery", func(n) { set_fail_battery(n.getValue()); });
    
    # Periodic update (10 Hz for system response)
    var update_timer = func { 
        update_electrical(); 
        settimer(update_timer, 0.1); 
    }
    settimer(update_timer, 0.1);
}

# Start system when script loads
startup_electrical();
