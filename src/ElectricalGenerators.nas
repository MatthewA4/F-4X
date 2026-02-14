# F-4J/S Generator Modeling - N2-Dependent Output & Frequency Regulation
# Implements 30 kVA AC generators with constant-speed drive integration
# License: GPLv2+

# Generator specifications (F-4J/S J79-GE-10B engines)
var GEN_RATED_KVA = 30.0;              # Rated output per generator
var GEN_AC_VOLTAGE_NOM = 115.0;        # RMS voltage nominal
var GEN_AC_FREQUENCY_NOM = 400.0;      # Hz constant frequency
var GEN_CSD_RATIO = 1.0 / 0.80;        # Constant-speed drive ratio (80% N2)
var GEN_N2_MIN_OPERATE = 0.20;         # 20% N2 minimum for operation
var GEN_N2_RATED = 0.80;               # 80% N2 for full output

# Generator state tracking
var gen_state = {
    left: {
        n2_input: 0.0,
        running: 0,
        available: 0,
        output_v: 0.0,
        output_freq: 0.0,
        load_amps: 0.0,
        case_temp: 50.0,
        overvoltage_trip: 0,
        undervoltage_trip: 0,
        disconnect_relay: 0,
        failed: 0
    },
    right: {
        n2_input: 0.0,
        running: 0,
        available: 0,
        output_v: 0.0,
        output_freq: 0.0,
        load_amps: 0.0,
        case_temp: 50.0,
        overvoltage_trip: 0,
        undervoltage_trip: 0,
        disconnect_relay: 0,
        failed: 0
    }
};

# Voltage regulation constants (NATOPS specs)
var GEN_VOLTAGE_NOMINAL = 115.0;       # Nominal line-to-neutral
var GEN_VOLTAGE_MAX = 122.0;           # Maximum acceptable
var GEN_VOLTAGE_MIN = 108.0;           # Minimum acceptable
var GEN_OVERVOLTAGE_TRIP = 135.0;      # Overvoltage protection point
var GEN_UNDERVOLTAGE_LOW = 100.0;      # Undervoltage warning threshold

# Temperature management
var GEN_CASE_TEMP_NOMINAL = 50.0;      # Temperature at idle (°C)
var GEN_CASE_TEMP_MAX = 85.0;          # Maximum case temperature
var GEN_CASE_TEMP_OVERHEAT = 100.0;    # Overheat trip point

# Check if generator engine is running
var is_engine_running = func(engine_idx) {
    return getprop("/engines/engine[" ~ engine_idx ~ "]/running") or 0;
}

# Get N2 speed from engine (percent)
var get_engine_n2 = func(engine_idx) {
    var n2 = getprop("/engines/engine[" ~ engine_idx ~ "]/n2-percent") or 0;
    return n2 / 100.0;  # Convert to decimal 0.0-1.0
}

# Calculate generator AC output voltage based on N2
# At <20% N2: 0V (below minimum operating speed)
# 20-80% N2: Linear ramp-up (proportional to N2)
# >=80% N2: Full 115V (constant-speed drive maintains 400Hz)
var calc_gen_voltage = func(n2, running, failed) {
    if (!running or failed or n2 < GEN_N2_MIN_OPERATE) {
        return 0.0;
    }
    
    if (n2 >= GEN_N2_RATED) {
        # At or above rated N2, full voltage output
        return GEN_AC_VOLTAGE_NOM;
    } else {
        # Below rated N2, linear proportional output
        # Formula: V = Vnom * (N2 - N2_min) / (N2_rated - N2_min)
        var voltage = GEN_AC_VOLTAGE_NOM * ((n2 - GEN_N2_MIN_OPERATE) / (GEN_N2_RATED - GEN_N2_MIN_OPERATE));
        return math.max(0, voltage);
    }
}

# Calculate generator output frequency (400 Hz constant on CSD)
# With functioning CSD, frequency remains constant despite N2 variations
var calc_gen_frequency = func(n2, running, failed, csd_ok) {
    if (!running or failed or n2 < GEN_N2_MIN_OPERATE or !csd_ok) {
        return 0.0;
    }
    
    # Constant-speed drive maintains 400 Hz regardless of N2 variation
    return GEN_AC_FREQUENCY_NOM;
}

# Generate case temperature based on load and ambient
var calc_gen_case_temp = func(output_v, load_amps, ambient_temp) {
    if (output_v < 50.0) {
        # Not generating, return ambient
        return ambient_temp or 20.0;
    }
    
    # Temperature rise proportional to load
    var load_factor = load_amps / 50.0;  # Scale to typical 50A load
    var temp_rise = load_factor * 30.0;  # Up to 30°C rise at full load
    
    var case_temp = (ambient_temp or 20.0) + 15.0 + temp_rise;
    return math.min(GEN_CASE_TEMP_MAX, case_temp);
}

# Check for overvoltage condition (protection circuit)
var check_overvoltage = func(output_v) {
    return output_v > GEN_OVERVOLTAGE_TRIP;
}

# Check for undervoltage condition
var check_undervoltage = func(output_v) {
    return output_v > 0 and output_v < GEN_UNDERVOLTAGE_LOW;
}

# Check for overtemp condition
var check_overtemp = func(case_temp) {
    return case_temp > GEN_CASE_TEMP_OVERHEAT;
}

# Update left generator state
var update_generator_left = func(dt) {
    var eng_idx = 0;
    var gen = gen_state.left;
    
    gen.running = is_engine_running(eng_idx);
    gen.n2_input = get_engine_n2(eng_idx);
    
    # Calculate voltage
    gen.output_v = calc_gen_voltage(gen.n2_input, gen.running, gen.failed);
    
    # Calculate frequency
    gen.output_freq = calc_gen_frequency(gen.n2_input, gen.running, gen.failed, 1);
    
    # Generator availability (has output and no protection trip)
    gen.available = gen.output_v > 100.0;
    
    # Protection monitoring
    gen.overvoltage_trip = check_overvoltage(gen.output_v);
    gen.undervoltage_trip = check_undervoltage(gen.output_v);
    gen.case_temp = calc_gen_case_temp(gen.output_v, gen.load_amps, 20.0);
    
    # Load overvoltage protection if tripped
    if (gen.overvoltage_trip) {
        gen.disconnect_relay = 1;  # Disconnect from bus
        gen.available = 0;
    } else {
        gen.disconnect_relay = 0;  # Allow connection
    }
    
    setprop("/systems/generators/left/n2-input", gen.n2_input * 100.0);
    setprop("/systems/generators/left/output-v", gen.output_v);
    setprop("/systems/generators/left/output-hz", gen.output_freq);
    setprop("/systems/generators/left/available", gen.available);
    setprop("/systems/generators/left/case-temp", gen.case_temp);
    setprop("/systems/generators/left/overvoltage-trip", gen.overvoltage_trip);
}

# Update right generator state
var update_generator_right = func(dt) {
    var eng_idx = 1;
    var gen = gen_state.right;
    
    gen.running = is_engine_running(eng_idx);
    gen.n2_input = get_engine_n2(eng_idx);
    
    # Calculate voltage
    gen.output_v = calc_gen_voltage(gen.n2_input, gen.running, gen.failed);
    
    # Calculate frequency
    gen.output_freq = calc_gen_frequency(gen.n2_input, gen.running, gen.failed, 1);
    
    # Generator availability
    gen.available = gen.output_v > 100.0;
    
    # Protection monitoring
    gen.overvoltage_trip = check_overvoltage(gen.output_v);
    gen.undervoltage_trip = check_undervoltage(gen.output_v);
    gen.case_temp = calc_gen_case_temp(gen.output_v, gen.load_amps, 20.0);
    
    if (gen.overvoltage_trip) {
        gen.disconnect_relay = 1;
        gen.available = 0;
    } else {
        gen.disconnect_relay = 0;
    }
    
    setprop("/systems/generators/right/n2-input", gen.n2_input * 100.0);
    setprop("/systems/generators/right/output-v", gen.output_v);
    setprop("/systems/generators/right/output-hz", gen.output_freq);
    setprop("/systems/generators/right/available", gen.available);
    setprop("/systems/generators/right/case-temp", gen.case_temp);
    setprop("/systems/generators/right/overvoltage-trip", gen.overvoltage_trip);
}

# Verify CSD operation (constant-speed drive)
var verify_csd = func(engine_n2) {
    # CSD typically operates at 80% engine N2
    # At this ratio, output frequency is held constant at 400 Hz
    # Function returns 1 if CSD is operating normally
    
    if (engine_n2 < GEN_N2_MIN_OPERATE) return 0;
    return 1;
}

# Get generator output summary
var get_gen_summary = func {
    return {
        left_output: gen_state.left.output_v,
        left_available: gen_state.left.available,
        right_output: gen_state.right.output_v,
        right_available: gen_state.right.available,
        left_temp: gen_state.left.case_temp,
        right_temp: gen_state.right.case_temp
    };
}

# Inject generator failure
var set_gen_failed = func(which, state) {
    if (which == "left") {
        gen_state.left.failed = state ? 1 : 0;
    } elsif (which == "right") {
        gen_state.right.failed = state ? 1 : 0;
    }
}

# N2 voltage regulation info
var get_voltage_regulation = func {
    return {
        min_acceptable: GEN_VOLTAGE_MIN,
        nominal: GEN_VOLTAGE_NOMINAL,
        max_acceptable: GEN_VOLTAGE_MAX,
        overvoltage_trip: GEN_OVERVOLTAGE_TRIP
    };
}

# Startup initialization
var startup_generators = func {
    setprop("/systems/generators/left/case-temp", GEN_CASE_TEMP_NOMINAL);
    setprop("/systems/generators/right/case-temp", GEN_CASE_TEMP_NOMINAL);
    
    # Periodic update (10 Hz with main electrical system)
    var update_timer = func {
        update_generator_left(0.1);
        update_generator_right(0.1);
        settimer(update_timer, 0.1);
    }
    settimer(update_timer, 0.1);
}

# Export generator functions
var electrical_generators = {
    startup: startup_generators,
    get_gen_summary: get_gen_summary,
    set_gen_failed: set_gen_failed,
    get_voltage_regulation: get_voltage_regulation
};
