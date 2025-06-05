# F-4J Phantom II Fuel System Simulation (NATOPS accurate, advanced)

# Tank capacities (approximate, in pounds)
var fus_fwd_capacity = 2200;
var fus_ctr_capacity = 2200;
var fus_aft_capacity = 2200;
var fus_feed_capacity = 700; # Feed tank (small, always kept full if possible)
var fuselage_capacity = fus_fwd_capacity + fus_ctr_capacity + fus_aft_capacity + fus_feed_capacity;

var wing_left_capacity = 1000;
var wing_right_capacity = 1000;
var wing_capacity = wing_left_capacity + wing_right_capacity;

var ext_center_capacity = 4000; # 600 gal
var ext_wing_capacity = 2500;   # 370 gal each
var external_capacity = ext_center_capacity + ext_wing_capacity * 2;

# Initial quantities
var fus_fwd_qty = fus_fwd_capacity;
var fus_ctr_qty = fus_ctr_capacity;
var fus_aft_qty = fus_aft_capacity;
var fus_feed_qty = fus_feed_capacity;

var wing_left_qty = wing_left_capacity;
var wing_right_qty = wing_right_capacity;

var external_qtys = [ext_center_capacity, ext_wing_capacity, ext_wing_capacity];

# Unusable fuel (NATOPS: ~100 lbs per tank group)
var unusable_fuselage = 100;
var unusable_wing = 50;
var unusable_external = 50;

# CG shift (arbitrary scale, negative = aft, positive = forward)
var cg_shift = 0.0;

# Leak rates (lbs/sec if leak active)
var fuselage_leak_rate = 2.0;
var wing_leak_rate = 1.0;
var external_leak_rate = 3.0;

# Fuel flow per engine (lbs/sec, typical cruise)
var engine_flow = 1.2;

# Helper: get property or default
var getp = func(p, d) { return getprop(p) != nil ? getprop(p) : d; }

# Transfer logic for external tanks to fuselage (to feed tank first, then to other fuselage tanks)
var transfer_external_to_fuselage = func(ext_attached) {
    forindex(var i; ext_attached) {
        if (ext_attached[i] and external_qtys[i] > unusable_external and fus_feed_qty < fus_feed_capacity) {
            var transfer = math.min(20, external_qtys[i] - unusable_external, fus_feed_capacity - fus_feed_qty);
            external_qtys[i] -= transfer;
            fus_feed_qty += transfer;
        }
    }
}

# Transfer logic for wing tanks to fuselage (to feed tank first, then to other fuselage tanks)
var transfer_wing_to_fuselage = func {
    var wing_total = wing_left_qty + wing_right_qty;
    if (wing_total > 2 * unusable_wing and fus_feed_qty < fus_feed_capacity) {
        var transfer = math.min(10, wing_total - 2 * unusable_wing, fus_feed_capacity - fus_feed_qty);
        # Split transfer equally from both wings
        var left_share = math.min(transfer / 2, wing_left_qty - unusable_wing);
        var right_share = transfer - left_share;
        wing_left_qty -= left_share;
        wing_right_qty -= right_share;
        fus_feed_qty += transfer;
    }
}

# Internal transfer: keep feed tank full from fwd/ctr/aft tanks
var transfer_fuselage_to_feed = func {
    var needed = fus_feed_capacity - fus_feed_qty;
    if (needed > 0) {
        # Take equally from fwd, ctr, aft (if above unusable)
        var sources = [fus_fwd_qty, fus_ctr_qty, fus_aft_qty];
        var available = 0;
        forindex(var i; sources) {
            if (sources[i] > unusable_fuselage) available += sources[i] - unusable_fuselage;
        }
        if (available > 0) {
            forindex(var i; sources) {
                if (sources[i] > unusable_fuselage) {
                    var take = math.min(needed / 3, sources[i] - unusable_fuselage);
                    if (i == 0) fus_fwd_qty -= take;
                    if (i == 1) fus_ctr_qty -= take;
                    if (i == 2) fus_aft_qty -= take;
                    fus_feed_qty += take;
                }
            }
        }
    }
}

# Draw fuel for engines from feed tank only (crossfeed logic included)
var draw_feed_fuel = func(amount) {
    var drawn = math.min(amount, fus_feed_qty - unusable_fuselage);
    fus_feed_qty -= drawn;
    return drawn;
}

# Simulate boost pump and feed tank failures
var pump_fail = {
    fus_fwd: 0, fus_ctr: 0, fus_aft: 0, fus_feed: 0,
    wing_left: 0, wing_right: 0,
    ext_center: 0, ext_left: 0, ext_right: 0
};

# Simulate sensor failures (0 = OK, 1 = failed)
var sensor_fail = {
    fuselage: 0, wing: 0, external: 0
};

# Simulate air trapping (if transfer fails, feed tank may run dry)
var air_trap = 0;

# Gravity feed only available below 10,000 ft (NATOPS)
var get_altitude = func { return getprop("/position/altitude-ft") or 0; }
var gravity_feed_allowed = func {
    return get_altitude() < 10000;
}

var update_fuel = func {
    # Read switches and states
    var feed_lock = getp("/systems/fuel/feed-lock", 0);
    var pump_fuselage = getp("/systems/fuel/boost-pump-fuselage", 1) and !pump_fail.fus_feed;
    var pump_wing = getp("/systems/fuel/boost-pump-wing", 1) and !pump_fail.wing_left and !pump_fail.wing_right;
    var pump_external = getp("/systems/fuel/boost-pump-external", 1) and !pump_fail.ext_center and !pump_fail.ext_left and !pump_fail.ext_right;
    var gravity_feed = getp("/systems/fuel/gravity-feed", 0);
    var crossfeed = getp("/systems/fuel/crossfeed", 0);

    var ext_attached = [
        getp("/systems/fuel/external-centerline-attached", 1),
        getp("/systems/fuel/external-wing-left-attached", 1),
        getp("/systems/fuel/external-wing-right-attached", 1)
    ];
    var ext_jettison = [
        getp("/systems/fuel/external-centerline-jettison", 0),
        getp("/systems/fuel/external-wing-left-jettison", 0),
        getp("/systems/fuel/external-wing-right-jettison", 0)
    ];

    var refuel_probe = getp("/systems/fuel/refuel-probe-connected", 0);
    var single_point = getp("/systems/fuel/single-point-connected", 0);

    var fuselage_leak = getp("/systems/fuel/fuselage-leak", 0);
    var wing_leak = getp("/systems/fuel/wing-leak", 0);
    var external_leak = getp("/systems/fuel/external-leak", 0);

    # Engine feed logic
    var engine1_feed = getp("/systems/fuel/engine1-feed", 1);
    var engine2_feed = getp("/systems/fuel/engine2-feed", 1);

    # Jettison logic
    forindex(var i; ext_jettison) {
        if (ext_jettison[i] and ext_attached[i]) {
            ext_attached[i] = 0;
            external_qtys[i] = 0;
        }
    }

    # Refueling logic (probe or single-point)
    if (refuel_probe or single_point) {
        var add = 200;
        var to_fus_feed = math.min(add, fus_feed_capacity - fus_feed_qty);
        fus_feed_qty += to_fus_feed;
        add -= to_fus_feed;
        if (add > 0) {
            var to_fwd = math.min(add / 3, fus_fwd_capacity - fus_fwd_qty);
            var to_ctr = math.min(add / 3, fus_ctr_capacity - fus_ctr_qty);
            var to_aft = math.min(add / 3, fus_aft_capacity - fus_aft_qty);
            fus_fwd_qty += to_fwd;
            fus_ctr_qty += to_ctr;
            fus_aft_qty += to_aft;
            add -= (to_fwd + to_ctr + to_aft);
        }
        if (add > 0) {
            var to_wl = math.min(add / 2, wing_left_capacity - wing_left_qty);
            var to_wr = math.min(add / 2, wing_right_capacity - wing_right_qty);
            wing_left_qty += to_wl;
            wing_right_qty += to_wr;
            add -= (to_wl + to_wr);
        }
        if (add > 0) {
            forindex(var i; ext_attached) {
                if (ext_attached[i] and !ext_jettison[i]) {
                    var ext_cap = (i == 0) ? ext_center_capacity : ext_wing_capacity;
                    var to_ext = math.min(add, ext_cap - external_qtys[i]);
                    external_qtys[i] += to_ext;
                    add -= to_ext;
                    if (add <= 0) break;
                }
            }
        }
    }

    # Leak logic (only for attached and NOT jettisoned tanks)
    if (fuselage_leak) {
        fus_fwd_qty = math.max(fus_fwd_qty - fuselage_leak_rate, unusable_fuselage);
        fus_ctr_qty = math.max(fus_ctr_qty - fuselage_leak_rate, unusable_fuselage);
        fus_aft_qty = math.max(fus_aft_qty - fuselage_leak_rate, unusable_fuselage);
        fus_feed_qty = math.max(fus_feed_qty - fuselage_leak_rate, unusable_fuselage);
    }
    if (wing_leak) {
        wing_left_qty = math.max(wing_left_qty - wing_leak_rate, unusable_wing);
        wing_right_qty = math.max(wing_right_qty - wing_leak_rate, unusable_wing);
    }
    if (external_leak) {
        forindex(var i; ext_attached) {
            if (ext_attached[i] and !ext_jettison[i]) external_qtys[i] = math.max(external_qtys[i] - external_leak_rate, unusable_external);
        }
    }

    # --- NATOPS FEED SEQUENCE LOGIC ---

    # 1. External tanks transfer to fuselage feed tank if any external fuel remains and pumps are on
    var ext_total = 0;
    forindex(var i; ext_attached) {
        if (ext_attached[i]) ext_total += external_qtys[i];
    }
    var external_transfer_active = (pump_external and ext_total > 3 * unusable_external);

    if (external_transfer_active) {
        transfer_external_to_fuselage(ext_attached);
    } else if (pump_wing and (wing_left_qty + wing_right_qty) > 2 * unusable_wing and ext_total <= 3 * unusable_external) {
        # 2. Only after external tanks are empty/disconnected, wing tanks transfer to fuselage feed tank
        transfer_wing_to_fuselage();
    }

    # Internal transfer: keep feed tank full from fwd/ctr/aft tanks
    if (pump_fuselage and !pump_fail.fus_feed) transfer_fuselage_to_feed();

    # Gravity feed only available below 10,000 ft and only from feed tank
    var gravity_ok = gravity_feed_allowed();
    if (!pump_fuselage and !pump_wing and !pump_external and gravity_ok) {
        gravity_feed = 1;
        setprop("/systems/fuel/gravity-feed", 1);
    } else if (gravity_feed) {
        setprop("/systems/fuel/gravity-feed", 0);
    }

    # Engine feed logic: only from feed tank (crossfeed allows both engines to use any feed tank)
    var total_flow = 0;
    var feed_available = (pump_fuselage or gravity_feed) and (fus_feed_qty > unusable_fuselage);
    var engine1_flameout = 0;
    var engine2_flameout = 0;
    if (!feed_lock and feed_available) {
        var engines_active = 0;
        if (engine1_feed) engines_active += 1;
        if (engine2_feed) engines_active += 1;
        var total_needed = engines_active * engine_flow;
        var drawn = draw_feed_fuel(total_needed);
        total_flow += drawn;
        if (drawn < engine_flow and engine1_feed) engine1_flameout = 1;
        if (drawn < engine_flow and engine2_feed) engine2_flameout = 1;
    } else {
        if (engine1_feed) engine1_flameout = 1;
        if (engine2_feed) engine2_flameout = 1;
    }
    # Crossfeed: if enabled, allow both engines to use any available feed tank (already handled above)

    # Simulate air trapping: if transfer fails, feed tank may run dry even if other tanks have fuel
    if (fus_feed_qty <= unusable_fuselage and (fus_fwd_qty > unusable_fuselage or fus_ctr_qty > unusable_fuselage or fus_aft_qty > unusable_fuselage)) {
        air_trap = 1;
    } else {
        air_trap = 0;
    }

    # CG shift: more accurate, based on tank positions
    cg_shift = (
        (fus_fwd_qty / fus_fwd_capacity) * 0.2 +
        (fus_ctr_qty / fus_ctr_capacity) * 0.1 +
        (fus_aft_qty / fus_aft_capacity) * -0.2 +
        (wing_left_qty / wing_left_capacity + wing_right_qty / wing_right_capacity) * -0.1 +
        (external_qtys[0] / ext_center_capacity) * -0.15 +
        ((external_qtys[1] + external_qtys[2]) / (2 * ext_wing_capacity)) * -0.1
    );

    # Clamp values
    fus_fwd_qty = math.max(math.min(fus_fwd_qty, fus_fwd_capacity), unusable_fuselage);
    fus_ctr_qty = math.max(math.min(fus_ctr_qty, fus_ctr_capacity), unusable_fuselage);
    fus_aft_qty = math.max(math.min(fus_aft_qty, fus_aft_capacity), unusable_fuselage);
    fus_feed_qty = math.max(math.min(fus_feed_qty, fus_feed_capacity), unusable_fuselage);
    wing_left_qty = math.max(math.min(wing_left_qty, wing_left_capacity), unusable_wing);
    wing_right_qty = math.max(math.min(wing_right_qty, wing_right_capacity), unusable_wing);
    forindex(var i; external_qtys) {
        var ext_cap = (i == 0) ? ext_center_capacity : ext_wing_capacity;
        external_qtys[i] = math.max(math.min(external_qtys[i], ext_cap), unusable_external);
    }

    # Set properties for instruments and systems (simulate sensor failure)
    setprop("/systems/fuel/qty-fuselage", sensor_fail.fuselage ? -1 : fus_fwd_qty + fus_ctr_qty + fus_aft_qty + fus_feed_qty);
    setprop("/systems/fuel/qty-wing", sensor_fail.wing ? -1 : wing_left_qty + wing_right_qty);
    setprop("/systems/fuel/qty-external", sensor_fail.external ? -1 : external_qtys[0] + external_qtys[1] + external_qtys[2]);
    setprop("/systems/fuel/qty-total", (sensor_fail.fuselage or sensor_fail.wing or sensor_fail.external) ? -1 :
        fus_fwd_qty + fus_ctr_qty + fus_aft_qty + fus_feed_qty + wing_left_qty + wing_right_qty + external_qtys[0] + external_qtys[1] + external_qtys[2]);
    setprop("/systems/fuel/cg-shift", cg_shift);

    # Set engine flameout properties
    setprop("/engines/engine[0]/flameout-fuel", engine1_flameout);
    setprop("/engines/engine[1]/flameout-fuel", engine2_flameout);

    # Set air trap property
    setprop("/systems/fuel/air-trap", air_trap);

    # Fuel dump logic (NATOPS: dump from all tanks except unusable, at ~50 lbs/sec per tank group)
    var fuel_dump = getp("/systems/fuel/dump", 0);
    var dump_rate = 50; # lbs/sec per tank group

    if (fuel_dump) {
        # Dump from fuselage tanks (fwd, ctr, aft, feed)
        fus_fwd_qty = math.max(fus_fwd_qty - dump_rate, unusable_fuselage);
        fus_ctr_qty = math.max(fus_ctr_qty - dump_rate, unusable_fuselage);
        fus_aft_qty = math.max(fus_aft_qty - dump_rate, unusable_fuselage);
        fus_feed_qty = math.max(fus_feed_qty - dump_rate, unusable_fuselage);
        # Dump from wing tanks
        wing_left_qty = math.max(wing_left_qty - dump_rate, unusable_wing);
        wing_right_qty = math.max(wing_right_qty - dump_rate, unusable_wing);
        # Dump from external tanks (if attached and not jettisoned)
        forindex(var i; external_qtys) {
            var ext_cap = (i == 0) ? ext_center_capacity : ext_wing_capacity;
            if (ext_attached[i] and !ext_jettison[i]) {
                external_qtys[i] = math.max(external_qtys[i] - dump_rate, unusable_external);
            }
        }
    }
};

# Periodic update
var periodic_update = func {
    update_fuel();
    settimer(periodic_update, 1); # update every second
}
periodic_update();

setprop("/systems/fuel/qty-fuselage-fwd", sensor_fail.fuselage ? -1 : fus_fwd_qty);
setprop("/systems/fuel/qty-fuselage-ctr", sensor_fail.fuselage ? -1 : fus_ctr_qty);
setprop("/systems/fuel/qty-fuselage-aft", sensor_fail.fuselage ? -1 : fus_aft_qty);
setprop("/systems/fuel/qty-fuselage-feed", sensor_fail.fuselage ? -1 : fus_feed_qty);
setprop("/systems/fuel/qty-wing-left", sensor_fail.wing ? -1 : wing_left_qty);
setprop("/systems/fuel/qty-wing-right", sensor_fail.wing ? -1 : wing_right_qty);
setprop("/systems/fuel/qty-external-center", sensor_fail.external ? -1 : external_qtys[0]);
setprop("/systems/fuel/qty-external-left", sensor_fail.external ? -1 : external_qtys[1]);
setprop("/systems/fuel/qty-external-right", sensor_fail.external ? -1 : external_qtys[2]);