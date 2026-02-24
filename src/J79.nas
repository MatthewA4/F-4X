# F-4J Phantom II J79-GE-10 Engine Control & NATOPS Startup Sequence
# =====================================================================
# Full startup, ignition, throttle control, and afterburner logic
# Reference: NATOPS F-4J Manual Section 3 (Engines), with TSFC modeling

var TRUE = 1;
var FALSE = 0;

# Engine properties (will be coordinated with JSBSim/FDM)
var engine = {
    n1: [0, 0],           # N1 (fan/LP) RPM percentage [left, right]
    n2: [0, 0],           # N2 (HP compressor) RPM percentage [left, right]
    egt: [0, 0],          # Exhaust Gas Temperature (deg C), [left, right]
    fuel_flow: [0, 0],    # Fuel flow (lbs/hr), [left, right]
    smoke_number: [0,0],  # SAE smoke number computed each frame
    # base TSFC values are taken from the F-4J NATOPS data; the ADA078440
    # "Evaluation of Fuel Character Effects on J79 Engine Combustion System"
    # report indicates a typical MIL figure of ≈0.846 lb/(lbf·hr) and shows that
    # fuels with different hydrogen contents alter TSFC by on the order of
    # ±10–20%.  A simple hydrogen-content correction is applied below.
    tsfc: 0.846,          # baseline MIL TSFC
    ab_tsfc: 1.98,        # baseline afterburner TSFC (approximately 2×)
};

# Throttle states
var throttle = {
    left_pos: 0,          # 0.0 = CUTOFF, 1.0 = MIL
    right_pos: 0,
    left_ab: 0,           # 0.0 = no AB, 1.0 = full AB
    right_ab: 0,
};

# Engine controls/switches (from cockpit)
var controls = {
    left_cutoff: 1,           # Fuel cutoff switch (1 = CUTOFF, 0 = ON)
    right_cutoff: 1,
    left_starter: 0,          # Start switch (0 = OFF, 1 = engaged)
    right_starter: 0,
    left_gen: 0,              # Generator switch
    right_gen: 0,
    ab_switch: [0, 0],        # AB armed switch [left, right]
    ab_light_test: 0,         # AB light test
};

# Engine state machine
var engine_state = {
    left_running: 0,
    right_running: 0,
    left_starter_active: 0,
    right_starter_active: 0,
    left_startup_time: 0,
    right_startup_time: 0,
};

# Afterburner state
var afterburner = {
    left_armed: 0,
    right_armed: 0,
    left_lit: 0,
    right_lit: 0,
    left_fuel_shutoff: 1,
    right_fuel_shutoff: 1,
};

# Helper: get property or default
var getp = func(p, d) { return getprop(p) != nil ? getprop(p) : d; }

# TSFC lookup with Mach/AB and fuel‑quality compensation
# percent hydrogen by weight in fuel; available via property so
# fuel-system/maintenance routines (or tests) can override for different
# blends.  Default value reflects typical JP‑4/JP‑5 composition.
var fuel_hydrogen_pct = func() {
    return getprop('/fuel/hydrogen-content-pct', 14.0);
};

# Simple linear correction based on ADA078440 results: more hydrogen tends to
# slightly increase TSFC (light fuel, lower energy density).  The slope here is
# modest (~5% per percent H) and can be tuned later.
var hydrogen_factor = func(h_pct) {
    return 1.0 + (h_pct - 14.0) * 0.05;
};

var get_tsfc = func(mach, ab_state) {
    var tsfc_baseline = ab_state ? engine.ab_tsfc : engine.tsfc;
var factor = hydrogen_factor(fuel_hydrogen_pct());
    tsfc_baseline *= factor;

    # Apply Mach correction (transonic/supersonic TSFC rise)
    if (mach < 0.8) {
        return tsfc_baseline * 0.95; # slight reduction at low mach
    } elsif (mach < 1.0) {
        # Transonic region: TSFC rises significantly
        var transonic_factor = 1.0 + (mach - 0.8) * 2.5;
        return tsfc_baseline * transonic_factor;
    } elsif (mach < 1.2) {
        # Supersonic climb: TSFC remains elevated
        return tsfc_baseline * 1.5;
    } else {
        # High supersonic: TSFC improves slightly
        return tsfc_baseline * (1.5 - (mach - 1.2) * 0.15);
    }
};

# Engine startup: open fuel cutoff and engage starter
var start_engine = func(engine_idx) {
    if (engine_idx < 0 or engine_idx > 1) return;
    
    var cutoff_prop = "/controls/engines/engine[" ~ engine_idx ~ "]/cutoff";
    var starter_prop = "/controls/engines/engine[" ~ engine_idx ~ "]/starter";
    var running_prop = "/engines/engine[" ~ engine_idx ~ "]/running";
    
    setprop(cutoff_prop, 0);       # Open fuel
    setprop(starter_prop, 1);      # Engage starter
    setprop(running_prop, 1);      # Tell JSBSim to run
    
    if (engine_idx == 0) {
        engine_state.left_starter_active = 1;
    } else {
        engine_state.right_starter_active = 1;
    }
};

# Monitor startup and disengage starter at idle
var check_startup = func(engine_idx) {
    if (engine_idx < 0 or engine_idx > 1) return;
    
    var n2_prop = "/engines/engine[" ~ engine_idx ~ "]/n2";
    var n1_prop = "/engines/engine[" ~ engine_idx ~ "]/n1";
    var starter_prop = "/controls/engines/engine[" ~ engine_idx ~ "]/starter";
    
    var n2 = getp(n2_prop, 0);
    var n1 = getp(n1_prop, 0);
    
    if (n2 > 65 and n1 > 28) {
        setprop(starter_prop, 0);
        if (engine_idx == 0) {
            engine_state.left_starter_active = 0;
            engine_state.left_running = 1;
        } else {
            engine_state.right_starter_active = 0;
            engine_state.right_running = 1;
        }
    }
};

# Afterburner control
var engage_afterburner = func(engine_idx) {
    if (engine_idx < 0 or engine_idx > 1) return;
    
    var mach = getp("/velocities/mach", 0);
    var alt = getp("/position/altitude-ft", 0);
    
    # AB light-off conditions (NATOPS): M > 0.5, alt < 35,000 ft
    if (mach > 0.5 and alt < 35000) {
        if (engine_idx == 0) {
            afterburner.left_lit = 1;
        } else {
            afterburner.right_lit = 1;
        }
        setprop("/engines/engine[" ~ engine_idx ~ "]/augmentation", 1);
    }
};

var disengage_afterburner = func(engine_idx) {
    if (engine_idx < 0 or engine_idx > 1) return;
    if (engine_idx == 0) {
        afterburner.left_lit = 0;
    } else {
        afterburner.right_lit = 0;
    }
    setprop("/engines/engine[" ~ engine_idx ~ "]/augmentation", 0);
};

# Update throttle and fuel flow based on TSFC
var update_throttle = func {
    var left_throttle = getp("/controls/engines/engine[0]/throttle", 0);
    var right_throttle = getp("/controls/engines/engine[1]/throttle", 0);
    var mach = getp("/velocities/mach", 0);
    
    forindex(var i; [0, 1]) {
        var throttle_val = (i == 0) ? left_throttle : right_throttle;
        var thrust_lbf = getp("/engines/engine[" ~ i ~ "]/thrust-lbf", 0);
        var running = (i == 0 ? engine_state.left_running : engine_state.right_running);
        
        # Afterburner engagement threshold (throttle > 0.95 = AB range)
        var ab_active = (throttle_val > 0.95) ? 1 : 0;
        
        if (ab_active and running) {
            engage_afterburner(i);
        } else {
            disengage_afterburner(i);
        }
        
        # Compute fuel flow from TSFC only if engine is running
        var fuel_flow_lbs_per_hr = 0;
        if (running) {
            var tsfc = get_tsfc(mach, ab_active);
            var fuel_flow_lbs_per_sec = (thrust_lbf * tsfc) / 3600;
            fuel_flow_lbs_per_hr = fuel_flow_lbs_per_sec * 3600;
        }
        
        engine.fuel_flow[i] = fuel_flow_lbs_per_hr;
        
        # Smoke number: based on thrust, Mach, fuel chemistry
        var h_pct = fuel_hydrogen_pct();
        var naph = getprop('/fuel/naphthalene-content-volpct') or 0;
        engine.smoke_number[i] = get_smoke_number(thrust_lbf, mach, h_pct, naph);
        setprop("/engines/engine[" ~ i ~ "]/smoke-number", engine.smoke_number[i]);
        
        # Push fuel flow to properties so fuel system can read it
        setprop("/engines/engine[" ~ i ~ "]/fuel-flow-gph", fuel_flow_lbs_per_hr / 6.7);
        setprop("/fdm/jsbsim/propulsion/engine[" ~ i ~ "]/fuel-flow-lbs_per_hr", fuel_flow_lbs_per_hr);
        
        # Signal fuel flameout if running but fuel unavailable (would be signaled by fuel system)
        if (running and fuel_flow_lbs_per_hr == 0) {
            setprop("/engines/engine[" ~ i ~ "]/flameout", 1);
            engine_state[i == 0 ? "left_running" : "right_running"] = 0;
        }
    }
};

# Smoke number calculation helper
var get_smoke_number = func(thrust_lbf, mach, h_pct, naph_v) {
    # Simple empirical model based on ADA095057 results:
    #  - smoke increases substantially with lower hydrogen content (exponential)
    #  - smoke rises linearly with naphthalene volume percent (slope 0.00711)
    #  - assume smoke roughly proportional to thrust magnitude
    var base = 0.02 + (thrust_lbf / 50000.0) * 0.1; # very coarse baseline
    var h_factor = math.exp((14.0 - h_pct) * 0.4);
    var n_factor = 1.0 + 0.00711 * naph_v;
    return base * h_factor * n_factor;
};

# Generator online logic
var update_generators = func {
    forindex(var i; [0, 1]) {
        var n2 = getp("/engines/engine[" ~ i ~ "]/n2", 0);
        var gen_switch = getp("/controls/engines/engine[" ~ i ~ "]/generator", 0);
        if (n2 > 60 and gen_switch) {
            setprop("/systems/electrical/gen-" ~ (i == 0 ? "left" : "right") ~ "-online", 1);
        } else {
            setprop("/systems/electrical/gen-" ~ (i == 0 ? "left" : "right") ~ "-online", 0);
        }
    }
};

# Main periodic update
var periodic_update = func {
    forindex(var i; [0, 1]) {
        if (engine_state.left_starter_active or engine_state.right_starter_active) {
            check_startup(i);
        }
    }
    
    update_throttle();
    update_generators();
    
    setprop("/engines/engine[0]/running", engine_state.left_running);
    setprop("/engines/engine[1]/running", engine_state.right_running);
    setprop("/engines/afterburner[0]/lit", afterburner.left_lit);
    setprop("/engines/afterburner[1]/lit", afterburner.right_lit);
    
    settimer(periodic_update, 0.1);
};

# Initialize
var init = func {
    setlistener("/controls/engines/engine[0]/starter", func(node) {
        if (node.getValue() == 1 and !engine_state.left_running) {
            start_engine(0);
        }
    });
    
    setlistener("/controls/engines/engine[1]/starter", func(node) {
        if (node.getValue() == 1 and !engine_state.right_running) {
            start_engine(1);
        }
    });
    
    periodic_update();
};

_setlistener("/sim/signals/fdm-initialized", init);

# Magic startup for testing
var magic_startup = func {
    start_engine(0);
    start_engine(1);
};

setlistener("/sim/signals/fdm-initialized", magic_startup);