# Radar Nasal module - simple search/track stub

var radar_state = {
    mode: 0,
    lock: 0,
    last_ping: 0,
};

var init_radar = func() {
    setprop("/avionics/radar/mode", 0);
    setprop("/avionics/radar/lock", 0);
    setprop("/avionics/radar/contacts", 0);
};

var update_radar = func(dt) {
    var req = getprop("/avionics/radar/mode-request", 0) or 0;
    if (req != radar_state.mode) {
        radar_state.mode = req;
        setprop("/avionics/radar/mode", req);
        radar_state.lock = 0;
        setprop("/avionics/radar/lock", 0);
        setprop("/avionics/radar/contacts", 0);
    }

    # Simple behavior:
    # - Mode 0: radar off
    # - Mode 1: search ping, occasional contacts
    # - Mode 2: track - maintain a lock flag
    if (radar_state.mode == 0) {
        setprop("/avionics/radar/contacts", 0);
        setprop("/avionics/radar/lock", 0);
    } elsif (radar_state.mode == 1) {
        var t = getprop("/sim/time/elapsed-sec", 0);
        # ping every 2 seconds
        if ((t - radar_state.last_ping) > 2.0) {
            radar_state.last_ping = t;
            # simulate contact probability based on distance to ground (more likely low)
            var agl = getprop("/fdm/jsbsim/position/h-agl-ft", 10000) or 10000;
            var chance = agl < 2000 ? 0.7 : (agl < 10000 ? 0.25 : 0.05);
            if (math.random() < chance) {
                setprop("/avionics/radar/contacts", 1);
            } else {
                setprop("/avionics/radar/contacts", 0);
            }
        }
        setprop("/avionics/radar/lock", 0);
    } else { # track
        # assume a track lock is maintained
        setprop("/avionics/radar/contacts", 1);
        setprop("/avionics/radar/lock", 1);
    }
};

init_radar();
