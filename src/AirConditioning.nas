# F-4J Air Conditioning and Pressurization System (Section 1, Part 2 NATOPS)

var AUTO_MODE = 1;      # 1=auto, 0=manual
var BLEED_LEFT = 1;     # 1=on, 0=off
var BLEED_RIGHT = 1;    # 1=on, 0=off
var CABIN_LEAK = 0;     # 1=leak, 0=normal

var MAX_DIFF_PRESS = 8.0;   # psi, typical for F-4J
var SAFETY_VALVE_DIFF = 8.6;# psi, safety valve opens

# Standard atmosphere (simplified)
var ambient_pressure = func(alt_ft) {
    return 14.7 * math.pow(1 - 6.8753e-6 * alt_ft, 5.2559);
};

var update_aircond = func {
    var alt = getprop("/position/altitude-ft");
    var left_bleed = getprop("/systems/aircond/bleed-left", 1);
    var right_bleed = getprop("/systems/aircond/bleed-right", 1);
    var auto_mode = getprop("/systems/aircond/auto", 1);
    var leak = getprop("/systems/aircond/leak", 0);
    var manual_cabin_alt = getprop("/systems/aircond/manual-cabin-alt", 8000);

    var ambient = ambient_pressure(alt);
    var target_cabin_alt = 0;

    # Bleed air supply logic
    if (!left_bleed and !right_bleed) {
        # No bleed air, cabin climbs to ambient
        target_cabin_alt = alt;
    } else {
        if (auto_mode) {
            # Automatic schedule: 
            # - Cabin follows aircraft up to 8,000 ft
            # - Above 8,000 ft, cabin stays at 8,000 ft until diff pressure maxed
            if (alt <= 8000) {
                target_cabin_alt = alt;
            } elsif (alt <= 23000) {
                target_cabin_alt = 8000;
            } else {
                # Above 23,000 ft, diff pressure is limited to 8 psi
                var cabin_p = ambient - MAX_DIFF_PRESS;
                target_cabin_alt = 145442.16 * (1 - math.pow(cabin_p/14.7, 1/5.2559));
                if (target_cabin_alt < 8000) target_cabin_alt = 8000;
            }
        } else {
            # Manual mode: pilot sets cabin altitude
            target_cabin_alt = manual_cabin_alt;
        }
    }

    # Leak logic: if leak, cabin altitude rises toward ambient
    if (leak) {
        target_cabin_alt = math.min(target_cabin_alt + 500, alt);
    }

    # Calculate actual cabin pressure and diff
    var cabin_p = ambient_pressure(target_cabin_alt);
    var diff_p = ambient - cabin_p;

    # Safety valve logic: opens at 8.6 psi diff
    if (diff_p > SAFETY_VALVE_DIFF) {
        diff_p = SAFETY_VALVE_DIFF;
        cabin_p = ambient - SAFETY_VALVE_DIFF;
        target_cabin_alt = 145442.16 * (1 - math.pow(cabin_p/14.7, 1/5.2559));
    }

    # Set properties for instruments and systems
    setprop("/systems/aircond/cabin-altitude", target_cabin_alt);
    setprop("/systems/aircond/diff-pressure", diff_p);
    setprop("/systems/aircond/cabin-pressure", cabin_p);
    setprop("/systems/aircond/auto", auto_mode);
    setprop("/systems/aircond/bleed-left", left_bleed);
    setprop("/systems/aircond/bleed-right", right_bleed);
    setprop("/systems/aircond/leak", leak);
};

# Update every 0.5 seconds
var timer = maketimer(0.5, update_aircond);
timer.start();