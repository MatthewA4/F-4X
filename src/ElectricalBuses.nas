# F-4J/S Electrical Bus Architecture & Failover Logic
# Manages AC/DC bus topology, priority sequencing, cross-feed logic
# License: GPLv2+

# Bus priority constants
var BUS_PRIORITY_BOTH_GENS = 3;
var BUS_PRIORITY_SINGLE_GEN = 2;
var BUS_PRIORITY_EXT_POWER = 1;
var BUS_PRIORITY_NONE = 0;

# Bus minimum viable voltages
var AC_BUS_MIN_VIABLE = 100.0;       # Volts AC (115V nominal)
var DC_BUS_MIN_VIABLE = 22.0;         # Volts DC (28V nominal) 
var DC_BUS_CRITICAL = 20.0;           # Below this, essential functions only
var DC_BUS_DEAD = 18.0;               # Below this, emergency battery reserve

# AC Bus Topology
var ac_bus_class = {
    new: func(name) {
        var m = { parents: [ac_bus_class] };
        m.name = name;
        m.voltage = 0.0;
        m.frequency = 0.0;
        m.load_amps = 0.0;
        m.source = "";
        return m;
    },
    
    get_health: func {
        # Return bus health status for annunciators
        if (me.voltage > AC_BUS_MIN_VIABLE) return "OK";
        if (me.voltage > 80.0) return "DEGRADED";
        return "FAILED";
    }
};

# DC Bus Topology
var dc_bus_class = {
    new: func(name) {
        var m = { parents: [dc_bus_class] };
        m.name = name;
        m.voltage = 0.0;
        m.load_amps = 0.0;
        m.primary_source = "";
        m.backup_source = "";
        m.is_battery_backed = 0;
        return m;
    },
    
    get_health: func {
        # Return DC bus health status
        if (me.voltage > DC_BUS_MIN_VIABLE) return "OK";
        if (me.voltage > DC_BUS_CRITICAL) return "CRITICAL";
        if (me.voltage > DC_BUS_DEAD) return "RESERVE";
        return "FAILED";
    },
    
    is_viable: func {
        return me.voltage >= DC_BUS_MIN_VIABLE;
    }
};

# AC Main Bus Priority Logic
# Selects highest priority source (both gens > single gen > ext power > none)
var calc_ac_main_priority = func(gen_left_ok, gen_right_ok, ext_power_ok) {
    if (gen_left_ok and gen_right_ok) return BUS_PRIORITY_BOTH_GENS;
    if (gen_left_ok or gen_right_ok) return BUS_PRIORITY_SINGLE_GEN;
    if (ext_power_ok) return BUS_PRIORITY_EXT_POWER;
    return BUS_PRIORITY_NONE;
}

# DC Main Bus Cross-Feed Logic
# Both TRs can supply DC main - selects higher voltage for optimal performance
var get_dc_main_voltage = func(tr_left_v, tr_right_v) {
    var left_ok = tr_left_v > 0;
    var right_ok = tr_right_v > 0;
    
    if (left_ok and right_ok) {
        # Both available - pick higher voltage
        return math.max(tr_left_v, tr_right_v);
    } elsif (left_ok) {
        return tr_left_v;
    } elsif (right_ok) {
        return tr_right_v;
    } else {
        return 0.0;
    }
}

# DC Essential Bus Failover Logic
# Primary: DC Main bus (if >22V)
# Secondary: Battery (if available)
# Tertiary: None (system dead)
var get_dc_ess_voltage = func(dc_main_v, battery_v, battery_available) {
    if (dc_main_v > DC_BUS_MIN_VIABLE) {
        return dc_main_v;  # Powered from main bus
    } elsif (battery_available and battery_v > DC_BUS_CRITICAL) {
        return battery_v;  # Battery backup
    } else {
        return 0.0;        # System failed
    }
}

# AC Essential Bus Failover Logic
# Primary: AC Main bus (if available)
# Secondary: Static inverter from DC main (if >24V)
# Tertiary: None (AC system failed)
var get_ac_ess_voltage = func(ac_main_v, dc_main_v, inverter_ok) {
    if (ac_main_v > AC_BUS_MIN_VIABLE) {
        return ac_main_v;  # Powered from AC main
    } elsif (inverter_ok and dc_main_v > 24.0) {
        return 115.0 * 0.90;  # Static inverter backup (slight reduction)
    } else {
        return 0.0;        # AC system failed
    }
}

# Generator AC output with bus consideration
var get_generator_ac_output = func(n2_percent, running, is_failed) {
    var n2 = n2_percent / 100.0;
    
    if (!running or is_failed or n2 < 0.20) return 0.0;
    
    if (n2 >= 0.80) {
        return 115.0;  # Full output at constant-speed drive
    } else {
        # Proportional ramp 20-80% N2
        return 115.0 * ((n2 - 0.20) / 0.60);
    }
}

# TR voltage droop calculation based on load
# 28V nominal at light load, ~26V at full rated current
var get_tr_voltage = func(input_ac, load_amps, rated_current) {
    if (input_ac < 100.0) return 0.0;  # Insufficient input
    
    var load_factor = math.min(1.0, load_amps / rated_current);
    var voltage = 28.0 - (load_factor * 2.0);  # 28V to 26V range
    
    return math.max(0, voltage);
}

# Battery state of charge voltage representation
var get_battery_soc_voltage = func(charge_pct) {
    # Maps charge percentage to working voltage range
    # 100% = 24V nominal, 10% = 18V (emergency reserve)
    var nom_v = 24.0;
    var empty_v = 18.0;
    
    return (charge_pct / 100.0) * nom_v + ((100.0 - charge_pct) / 100.0) * empty_v;
}

# DC bus load determines which loads are shed
var get_effective_dc_load = func(base_load, shed_active, shed_radar, shed_heating) {
    var load = base_load;
    
    if (shed_heating) load -= 2.0;   # Heating ~2A
    if (shed_radar) load -= 0.0;     # Radar already on AC main
    
    return math.max(0, load);
}

# Detect bus anomalies for crew alerting
var check_bus_anomalies = func {
    var anomalies = [];
    
    var ac_main_v = getprop("/systems/electrical/ac-main-bus-v") or 0;
    var dc_main_v = getprop("/systems/electrical/dc-main-bus-v") or 0;
    var dc_ess_v = getprop("/systems/electrical/dc-ess-bus-v") or 0;
    
    # AC anomalies
    if (ac_main_v > 0 and ac_main_v < AC_BUS_MIN_VIABLE) {
        anomalies += ["AC Main Degraded"];
    }
    
    # DC Main anomalies
    if (dc_main_v > 0 and dc_main_v < DC_BUS_CRITICAL) {
        anomalies += ["DC Main Critical"];
    }
    
    # DC Essential anomalies
    if (dc_ess_v > 0 and dc_ess_v < DC_BUS_CRITICAL) {
        anomalies += ["DC Ess Critical"];
    }
    
    # Total bus failure
    if (ac_main_v == 0 and dc_main_v == 0) {
        anomalies += ["All AC Buses Failed"];
    }
    
    return anomalies;
}

# Estimate time-to-deadstick on battery alone
var estimate_battery_endurance = func {
    var battery_pct = getprop("/systems/electrical/battery-charge-pct") or 100;
    var dc_ess_load = getprop("/systems/electrical/dc-ess-load") or 10;
    
    # Typical DC essential load ~10A, battery 38 Ah
    # At 20-30% capacity draw: 38Ah / 10A = 3.8 hours
    # At 10% capacity draw (essential only): ~20+ minutes
    
    var charge_ah = (battery_pct / 100.0) * 38.0;
    var hours_remaining = charge_ah / math.max(1.0, dc_ess_load);
    
    return hours_remaining;
}

# Verify electrical system health on startup
var verify_electrical_health = func {
    var errors = [];
    
    # Check all buses are at reasonable defaults
    var ac_main = getprop("/systems/electrical/ac-main-bus-v") or 0;
    var dc_main = getprop("/systems/electrical/dc-main-bus-v") or 0;
    var battery_v = getprop("/systems/electrical/battery-voltage") or 0;
    
    # Should be off initially (engines off, no battery switch)
    if (ac_main != 0) errors += ["AC Main bus not off at startup"];
    if (dc_main != 0) errors += ["DC Main bus not off at startup"];
    
    # Battery voltage should be nominal
    if (battery_v > 0 and (battery_v < 22.0 or battery_v > 25.0)) {
        errors += ["Battery voltage out of range: " ~ battery_v ~ "V"];
    }
    
    return errors;
}

# Export functions for use by main electrical system
var electrical_buses = {
    get_ac_main_priority: get_ac_main_priority,
    get_dc_main_voltage: get_dc_main_voltage,
    get_dc_ess_voltage: get_dc_ess_voltage,
    get_ac_ess_voltage: get_ac_ess_voltage,
    get_generator_ac_output: get_generator_ac_output,
    get_tr_voltage: get_tr_voltage,
    get_battery_soc_voltage: get_battery_soc_voltage,
    check_bus_anomalies: check_bus_anomalies,
    estimate_battery_endurance: estimate_battery_endurance,
    verify_electrical_health: verify_electrical_health
};
