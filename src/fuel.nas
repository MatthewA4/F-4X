# F-4J Phantom II Fuel System Simulation

# Tank capacities (approximate, in pounds)
var fuselage_capacity = 7300;
var wing_capacity = 2000;
var external_tank_capacity = 2000; # each external tank
var external_capacity = external_tank_capacity * 3; # sum of all externals

# Initial quantities
var fuselage_qty = fuselage_capacity;
var wing_qty = wing_capacity;
var external_qtys = [external_tank_capacity, external_tank_capacity, external_tank_capacity];

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

var draw_fuel = func(amount, fuselage_avail, wing_avail, external_avail, ext_attached) {
    var drawn = 0.0;
    var left = amount;

    # Fuselage first
    if (fuselage_avail and fuselage_qty > 0) {
        var take = math.min(left, fuselage_qty);
        fuselage_qty -= take;
        drawn += take;
        left -= take;
    }
    # Wing next
    if (left > 0 and wing_avail and wing_qty > 0) {
        var take = math.min(left, wing_qty);
        wing_qty -= take;
        drawn += take;
        left -= take;
    }
    # External last (draw from attached tanks in order)
    if (left > 0 and external_avail) {
        forindex(var i; ext_attached) {
            if (ext_attached[i] and external_qtys[i] > 0 and left > 0) {
                var take = math.min(left, external_qtys[i]);
                external_qtys[i] -= take;
                drawn += take;
                left -= take;
            }
        }
    }
    return drawn;
};

var update_fuel = func {
    # Read switches and states
    var feed_lock = getp("/systems/fuel/feed-lock", 0);
    var pump_fuselage = getp("/systems/fuel/boost-pump-fuselage", 1);
    var pump_wing = getp("/systems/fuel/boost-pump-wing", 1);
    var pump_external = getp("/systems/fuel/boost-pump-external", 1);
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

    # Tank selector (auto transfer logic)
    var tank_selector = getp("/systems/fuel/tank-selector", 1);

    # Jettison logic
    forindex(var i; ext_jettison) {
        if (ext_jettison[i] and ext_attached[i]) {
            ext_attached[i] = 0;
            external_qtys[i] = 0;
        }
    }

    # Refueling logic
    if (refuel_probe or single_point) {
        fuselage_qty = math.min(fuselage_qty + 100, fuselage_capacity);
        wing_qty = math.min(wing_qty + 30, wing_capacity);
        forindex(var i; ext_attached) {
            if (ext_attached[i]) external_qtys[i] = math.min(external_qtys[i] + 50, external_tank_capacity);
        }
    }

    # Leak logic
    if (fuselage_leak) fuselage_qty = math.max(fuselage_qty - fuselage_leak_rate, 0);
    if (wing_leak) wing_qty = math.max(wing_qty - wing_leak_rate, 0);
    if (external_leak) {
        forindex(var i; ext_attached) {
            if (ext_attached[i]) external_qtys[i] = math.max(external_qtys[i] - external_leak_rate, 0);
        }
    }

    # Determine tank availability
    var fuselage_avail = (pump_fuselage or gravity_feed) and (fuselage_qty > 0);
    var wing_avail = (pump_wing or gravity_feed) and (wing_qty > 0);
    var external_attached = ext_attached[0] or ext_attached[1] or ext_attached[2];
    var external_avail = (pump_external or gravity_feed) and (sum([forindex(var i; ext_attached) ext_attached[i] and external_qtys[i] > 0 ? 1 : 0]) > 0);

    # Fuel feed logic with bleed lines
    var total_flow = 0;
    if (!feed_lock) {
        var pumps_ok = fuselage_avail or wing_avail or external_avail;
        var tanks_avail = fuselage_avail or wing_avail or external_avail;

        if (pumps_ok and tanks_avail) {
            var engines_active = 0;
            if (engine1_feed) engines_active += 1;
            if (engine2_feed) engines_active += 1;
            var total_needed = engines_active * engine_flow;
            var drawn = draw_fuel(total_needed, fuselage_avail, wing_avail, external_avail, ext_attached);
            total_flow += drawn;
        }
        # Crossfeed: if enabled, allow any available tank to feed both engines
        if (crossfeed and tanks_avail) {
            var engines_active = 0;
            if (engine1_feed) engines_active += 1;
            if (engine2_feed) engines_active += 1;
            var total_needed = engines_active * engine_flow;
            var drawn = draw_fuel(total_needed, fuselage_avail, wing_avail, external_avail, ext_attached);
            total_flow += drawn;
        }
    }

    # Auto gravity feed if all pumps fail
    if (!pump_fuselage and !pump_wing and !pump_external) {
        gravity_feed = 1;
        setprop("/systems/fuel/gravity-feed", 1);
    } else if (gravity_feed) {
        setprop("/systems/fuel/gravity-feed", 0);
    }

    # Auto tank transfer (simulate CG management)
    if (fuselage_qty < fuselage_capacity * 0.2 and wing_qty > 0) {
        var transfer = math.min(20, wing_qty);
        fuselage_qty += transfer;
        wing_qty -= transfer;
    }

    # CG shift: negative if aft tanks (external/wing) are full, positive if fuselage is full
    cg_shift = ((fuselage_qty / fuselage_capacity) - (external_qty / external_capacity + wing_qty / wing_capacity) * 0.5);

    # Calculate total external fuel from attached tanks
    var external_qty = 0;
    forindex(var i; ext_attached) {
        if (ext_attached[i]) external_qty += external_qtys[i];
    }

    # Clamp values
    fuselage_qty = math.max(math.min(fuselage_qty, fuselage_capacity), 0);
    wing_qty = math.max(math.min(wing_qty, wing_capacity), 0);
    forindex(var i; external_qtys) {
        external_qtys[i] = math.max(math.min(external_qtys[i], external_tank_capacity), 0);
    }

    # Set properties for instruments and systems
    setprop("/systems/fuel/qty-fuselage", fuselage_qty);
    setprop("/systems/fuel/qty-wing", wing_qty);
    setprop("/systems/fuel/qty-external", external_qty);
    setprop("/systems/fuel/qty-total", fuselage_qty + wing_qty + external_qty);
    setprop("/systems/fuel/cg-shift", cg_shift);
};

# Periodic update
var periodic_update = func {
    update_fuel();
    settimer(periodic_update, 1); # update every second
}
periodic_update();