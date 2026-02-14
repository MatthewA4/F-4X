# RadarManager.nas - simple contact generator and tracker for HUD cues

# Config
var RADAR_MAX_RANGE_FT = 200000.0; # ~33 nm
var RADAR_PING_SEC = 1.0;

var radar_mgr = {
    last_ping_time: 0,
    contacts: [], # list of {id, dx,dy,z, vx,vy,vz, detected}
    next_id: 1,
    mode: 0, # 0=off,1=search,2=TWS,3=STT
    locked_target: 0,
    lock_age: 0,
};

var create_contact = func(range_ft, bearing_deg, altitude_ft, speed_kt) {
    var hdg = getprop("/orientation/heading-deg", 0);
    var rad = (hdg + bearing_deg) * math.pi / 180.0;
    var dx = range_ft * math.cos(rad);
    var dy = range_ft * math.sin(rad);
    var vz = 0;
    var kt_to_ft_s = 1.68781;
    var speed_fts = speed_kt * kt_to_ft_s;
    var vx = -speed_fts * math.cos(rad); # heading toward/away simplification
    var vy = -speed_fts * math.sin(rad);

    var c = { id: radar_mgr.next_id, dx: dx, dy: dy, z: altitude_ft, vx: vx, vy: vy, vz: vz, detected: 0 };
    radar_mgr.next_id += 1;
    radar_mgr.contacts.push(c);
    return c;
};

var clear_contacts = func() {
    radar_mgr.contacts = [];
    radar_mgr.next_id = 1;
    radar_mgr.locked_target = 0;
    radar_mgr.lock_age = 0;
};

var update_radar_manager = func(dt) {
    var now = getprop("/sim/time/elapsed-sec", 0);
    # Update mode from avionics request
    var req_mode = getprop("/avionics/radar/mode-request", 0) or 0;
    if (req_mode != radar_mgr.mode) {
        radar_mgr.mode = req_mode;
        radar_mgr.locked_target = 0;
        radar_mgr.lock_age = 0;
        setprop("/avionics/radar/lock", 0);
    }

    # Periodic ping
    if ((now - radar_mgr.last_ping_time) >= RADAR_PING_SEC) {
        radar_mgr.last_ping_time = now;

        # Populate demo contacts if empty
        if (radar_mgr.contacts.length == 0) {
            create_contact(80000.0, 10.0, 5000.0, 350.0);
            create_contact(120000.0, -25.0, 15000.0, 420.0);
        }

        for (var i = 0; i < radar_mgr.contacts.length; i += 1) {
            var c = radar_mgr.contacts[i];
            var range = math.sqrt(c.dx*c.dx + c.dy*c.dy);
            var detection_prob = 0.0;
            if (range <= RADAR_MAX_RANGE_FT) {
                detection_prob = 0.15 + 0.85 * (1.0 - (range / RADAR_MAX_RANGE_FT));
                if (c.z > 10000) detection_prob += 0.05;
                detection_prob = math.min(1.0, detection_prob);
            }
            c.detected = (math.random() < detection_prob) ? 1 : 0;
        }
    }

    # Propagate contacts
    for (var j = 0; j < radar_mgr.contacts.length; j += 1) {
        var cc = radar_mgr.contacts[j];
        cc.dx += cc.vx * dt;
        cc.dy += cc.vy * dt;
        cc.z += cc.vz * dt;
    }

    # Handle mode-specific behavior
    var nearest = nil;
    var nearest_range = 1e12;
    for (var k = 0; k < radar_mgr.contacts.length; k += 1) {
        var ct = radar_mgr.contacts[k];
        var r = math.sqrt(ct.dx*ct.dx + ct.dy*ct.dy);
        if (!ct.detected) continue;
        if (r < nearest_range) {
            nearest_range = r;
            nearest = ct;
        }
    }

    # Mode: search -> show contacts, no lock
    if (radar_mgr.mode == 1) {
        if (nearest != nil) {
            setprop("/avionics/radar/contacts", 1);
            setprop("/avionics/radar/lock", 0);
            setprop("/avionics/radar/target-range-ft", nearest_range);
            var bearing = math.atan2(nearest.dy, nearest.dx) * 180.0 / math.pi;
            if (bearing > 180) bearing -= 360;
            if (bearing < -180) bearing += 360;
            setprop("/avionics/radar/target-bearing-deg", bearing);
            setprop("/avionics/radar/target-alt-ft", nearest.z);
            setprop("/avionics/radar/target-id", nearest.id);
        } else {
            setprop("/avionics/radar/contacts", 0);
            setprop("/avionics/radar/target-range-ft", 0);
            setprop("/avionics/radar/target-bearing-deg", 0);
            setprop("/avionics/radar/target-alt-ft", 0);
            setprop("/avionics/radar/target-id", 0);
        }
    } elsif (radar_mgr.mode == 2) {
        # TWS - track up to N contacts; for now provide nearest and possible lock cue
        if (nearest != nil) {
            setprop("/avionics/radar/contacts", 1);
            setprop("/avionics/radar/target-range-ft", nearest_range);
            var bearing2 = math.atan2(nearest.dy, nearest.dx) * 180.0 / math.pi;
            if (bearing2 > 180) bearing2 -= 360;
            if (bearing2 < -180) bearing2 += 360;
            setprop("/avionics/radar/target-bearing-deg", bearing2);
            setprop("/avionics/radar/target-alt-ft", nearest.z);
            setprop("/avionics/radar/target-id", nearest.id);
            # Candidate for lock; establish lock if range < 120k ft
            if (nearest_range < 120000.0) {
                radar_mgr.lock_age += 1.0;
                if (radar_mgr.lock_age > 2.0) {
                    radar_mgr.locked_target = nearest.id;
                    setprop("/avionics/radar/lock", 1);
                }
            } else {
                radar_mgr.lock_age = 0;
                setprop("/avionics/radar/lock", 0);
            }
        } else {
            setprop("/avionics/radar/contacts", 0);
            setprop("/avionics/radar/lock", 0);
            radar_mgr.lock_age = 0;
            setprop("/avionics/radar/target-range-ft", 0);
            setprop("/avionics/radar/target-bearing-deg", 0);
            setprop("/avionics/radar/target-alt-ft", 0);
            setprop("/avionics/radar/target-id", 0);
        }
    } elsif (radar_mgr.mode == 3) {
        # STT - single target track; lock the nearest detected contact immediately
        if (nearest != nil) {
            radar_mgr.locked_target = nearest.id;
            setprop("/avionics/radar/lock", 1);
            setprop("/avionics/radar/contacts", 1);
            setprop("/avionics/radar/target-range-ft", nearest_range);
            var bearing3 = math.atan2(nearest.dy, nearest.dx) * 180.0 / math.pi;
            if (bearing3 > 180) bearing3 -= 360;
            if (bearing3 < -180) bearing3 += 360;
            setprop("/avionics/radar/target-bearing-deg", bearing3);
            setprop("/avionics/radar/target-alt-ft", nearest.z);
            setprop("/avionics/radar/target-id", nearest.id);
        } else {
            radar_mgr.locked_target = 0;
            setprop("/avionics/radar/lock", 0);
            setprop("/avionics/radar/contacts", 0);
            setprop("/avionics/radar/target-range-ft", 0);
            setprop("/avionics/radar/target-bearing-deg", 0);
            setprop("/avionics/radar/target-alt-ft", 0);
            setprop("/avionics/radar/target-id", 0);
        }
    } else {
        # Mode 0 or unknown: off
        setprop("/avionics/radar/contacts", 0);
        setprop("/avionics/radar/lock", 0);
        setprop("/avionics/radar/target-range-ft", 0);
        setprop("/avionics/radar/target-bearing-deg", 0);
        setprop("/avionics/radar/target-alt-ft", 0);
        setprop("/avionics/radar/target-id", 0);
    }
};

# Initialize HUD/radar target properties
setprop("/avionics/radar/target-range-ft", 0);
setprop("/avionics/radar/target-bearing-deg", 0);
setprop("/avionics/radar/target-alt-ft", 0);
setprop("/avionics/radar/target-id", 0);
setprop("/avionics/hud/target-range-display", "---");
setprop("/avionics/hud/radar-mode-text", "OFF");
setprop("/avionics/hud/lock-indicator", 0);

# Export update function under known name so AFCS can call it
var update_radar = func(dt) {
    update_radar_manager(dt);
    # Publish HUD symbology
    var mode = radar_mgr.mode;
    var range = getprop("/avionics/radar/target-range-ft") or 0;
    var lock = getprop("/avionics/radar/lock") or 0;
    if (mode == 0) setprop("/avionics/hud/radar-mode-text", "OFF");
    elsif (mode == 1) setprop("/avionics/hud/radar-mode-text", "SRCH");
    elsif (mode == 2) setprop("/avionics/hud/radar-mode-text", "TWS");
    elsif (mode == 3) setprop("/avionics/hud/radar-mode-text", "STT");
    if (range > 0) {
        var range_nm = range / 6076.0;
        setprop("/avionics/hud/target-range-display", sprintf("%.1f nm", range_nm));
    } else {
        setprop("/avionics/hud/target-range-display", "---");
    }
    setprop("/avionics/hud/lock-indicator", lock);
};
