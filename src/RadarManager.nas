# Advanced F-4 Fire Control Radar Manager (AWG-10 family)
# Author: Matthew A. (derived from NNWD manuals & NATOPS)
# License: GPLv2+

# This module simulates the F-4 Phantom fire control radar in detail.
# Supports multiple modes (VS, RWS, TWS, STT, DF, GL, Beacon) and
# implements detection probability, track-while-scan, single-target
# track logic, and electrical loading.  AWG-10B/J-S improvements are
# modelled where data are available.

# ------------------------------------------------------------------
# == Constants and Configuration ==
# ------------------------------------------------------------------

# Radar modes enumeration (matching mode-request control)
var RM = {
    OFF:   0,
    VS:    1,   # Velocity search
    RWS:   2,   # Range-while-scan (sector search)
    BEACON:3,   # Beacon search / IFF
    TWS:   4,   # Track-while-scan
    STT:   5,   # Single-target track
    DF:    6,   # Dogfight/air combat
    GL:    7,   # Ground-look (AWG-10B/J-S)
};

# Physical constants
var FT_PER_NM = 6076.11549;
var KT_TO_FT_S = 1.68781;
var RADAR_HORIZON_FACTOR = 1.23;   # Miles per sqrt(altitude in feet)

# Radar parameter sets keyed by mode for quick lookup
var radar_params = {
    # max_range_ft approximate for a 1m^2 RCS target
    [RM.VS]  = { max_range_ft: 360000.0, prf: 3000, pulse_width: 0.5e-6,
                  scan_az: 120, scan_el: 40, az_rate_dps: 360 },
    [RM.RWS] = { max_range_ft: 250000.0, prf: 1500, pulse_width: 1.0e-6,
                  scan_az: 120, scan_el: 40, az_rate_dps: 180 },
    [RM.BEACON] = { max_range_ft: 500000.0, prf: 400, pulse_width: 2.0e-6,
                    scan_az: 180, scan_el: 60, az_rate_dps: 90 },
    [RM.TWS] = { max_range_ft: 200000.0, prf: 1800, pulse_width: 0.8e-6,
                 scan_az: 120, scan_el: 40, az_rate_dps: 180 },
    [RM.STT] = { max_range_ft: 150000.0, prf: 1200, pulse_width: 1.2e-6,
                 scan_az: 4, scan_el: 4, az_rate_dps: 0 },
    [RM.DF]  = { max_range_ft: 60000.0, prf: 3000, pulse_width: 0.5e-6,
                 scan_az: 120, scan_el: 120, az_rate_dps: 720 },
    [RM.GL]  = { max_range_ft: 150000.0, prf: 800, pulse_width: 1.5e-6,
                 scan_az: 120, scan_el: 10, az_rate_dps: 180 },
};

# RCS reference values (m^2) for common target classes
var RCS = {
    FIGHTER: 1.0,
    TANKER:  10.0,
    BOMB:    2.5,
    GROUND:  20.0,
    UNKNOWN: 1.0,
};

# Electrical load parameters (AC mains amps)
var RADAR_LOAD = {
    TRANSMIT: 25.0,    # AC load when transmitter active
    RECEIVE:  8.0,     # AC load when receiver only (standby/search)
    DRIVE:    0.5,     # antenna drive at 28V DC (converted externally)
};

# Track-While-Scan configuration
var TWS_MAX_TRACKS = 8;           # C/D/E capability; AWG-10B/J-S can do 10
var TWS_INIT_HITS = 3;            # number of successive detections to start track
var TWS_LOST_TIMEOUT = 5.0;       # seconds without update before dropping track

# Single-Target Track parameters
var STT_LOCK_RANGE_FT = 120000.0; # maximum range to achieve STT lock
var STT_CONE_WIDTH_DEG = 3.0;     # conical scan width

# Dogfight shorthand
var DF_MAX_RANGE_FT = 60000.0;    # ~10 nm
var DF_UPDATE_RATE_HZ = 20.0;

# ------------------------------------------------------------------
# == State Variables ==
# ------------------------------------------------------------------
var radar_mgr = {
    # contact list: each entry = {id, dx,dy,z, vx,vy,vz, rcs, detected, age}
    contacts: [],
    next_id: 1,

    # track list for TWS/STT: entries = {track_id, contact_id, last_range,
    # bearing, elevation, vx,vy,vz, age, status}
    tracks: [],
    next_track_id: 1,

    mode: RM.OFF,
    locked_track: nil,    # reference to track object
    lock_age: 0.0,

    antenna_az: 0.0,      # degrees, 0=heads-up
    last_ping: 0.0,
    update_interval: 0.1, # seconds
};

# Utility to convert bearing to radar-local cartesian components
var polar_to_cartesian = func(range_ft, bearing_deg) {
    var rad = bearing_deg * math.pi / 180.0;
    return [range_ft * math.cos(rad), range_ft * math.sin(rad)];
};

# ------------------------------------------------------------------
# Contact Management
# ------------------------------------------------------------------

var create_contact = func(range_ft, bearing_deg, altitude_ft, speed_kt, rcs_m2) {
    var hdg = getprop("/orientation/heading-deg", 0);
    var [dx0, dy0] = polar_to_cartesian(range_ft, bearing_deg + hdg);
    var speed_fts = speed_kt * KT_TO_FT_S;
    var rad = (hdg + bearing_deg) * math.pi / 180.0;
    var vx = -speed_fts * math.cos(rad);
    var vy = -speed_fts * math.sin(rad);
    var vz = 0;
    var c = { id: radar_mgr.next_id,
              dx: dx0, dy: dy0, z: altitude_ft,
              vx: vx, vy: vy, vz: vz,
              rcs: rcs_m2 or RCS.UNKNOWN,
              detected: 0,
              age: 0.0 };
    radar_mgr.next_id += 1;
    radar_mgr.contacts.push(c);
    return c;
};

var clear_contacts = func {
    radar_mgr.contacts = [];
    radar_mgr.next_id = 1;
    radar_mgr.tracks = [];
    radar_mgr.next_track_id = 1;
    radar_mgr.locked_track = nil;
    radar_mgr.lock_age = 0.0;
    _los_cache = {};     # drop stale LOS entries
};

# generate a pseudo‑contact from the terrain in the current beam direction
var generate_ground_contact = func() {
    # only valid in GL mode
    if (radar_mgr.mode != RM.GL) return;

    var own_alt_ft = getprop("/position/altitude-ft") or 0;
    var start = {
        x: (getprop("/position/ground-x-m") or 0),
        y: (getprop("/position/ground-y-m") or 0),
        z: own_alt_ft * 0.3048
    };
    # point along antenna azimuth relative to heading
    var hdg = getprop("/orientation/heading-deg", 0);
    var az_rad = (radar_mgr.antenna_az + hdg) * math.pi / 180.0;
    var dir = { x: math.cos(az_rad), y: math.sin(az_rad), z: 0 };

    var hit = get_cart_ground_intersection(start, dir);
    if (hit == nil) return;

    var dx = hit.x - start.x;
    var dy = hit.y - start.y;
    var rng_ft = math.sqrt(dx*dx + dy*dy) / 0.3048;
    var bear = math.atan2(dy, dx) * 180.0 / math.pi - hdg;
    while (bear > 180) bear -= 360;
    while (bear < -180) bear += 360;

    # create a contact representing the ground return
    create_contact(rng_ft, bear, hit.z / 0.3048, RCS.GROUND);
};

# ------------------------------------------------------------------
# Track Management
# ------------------------------------------------------------------

var create_track = func(contact) {
    if (radar_mgr.tracks.length >= TWS_MAX_TRACKS) return nil;
    var t = {
        track_id: radar_mgr.next_track_id,
        contact_id: contact.id,
        last_range: math.sqrt(contact.dx*contact.dx + contact.dy*contact.dy),
        bearing: math.atan2(contact.dy, contact.dx) * 180.0 / math.pi,
        elevation: contact.z,
        vx: contact.vx, vy: contact.vy, vz: contact.vz,
        age: 0.0,
        status: "tracking" # or "lost" or "locked"
    };
    radar_mgr.next_track_id += 1;
    radar_mgr.tracks.push(t);
    return t;
};

var remove_track = func(index) {
    if (index < radar_mgr.tracks.length) {
        radar_mgr.tracks.splice(index, 1);
    }
};

var update_tracks = func(dt) {
    # age tracks and remove stale ones
    for (var i = radar_mgr.tracks.length - 1; i >= 0; i--) {
        var tr = radar_mgr.tracks[i];
        tr.age += dt;
        if (tr.status == "lost" and tr.age > TWS_LOST_TIMEOUT) {
            radar_mgr.tracks.splice(i, 1);
            continue;
        }
        # attempt to refresh track if corresponding contact detected
        for (var j = 0; j < radar_mgr.contacts.length; j++) {
            var c = radar_mgr.contacts[j];
            if (c.id != tr.contact_id) continue;
            if (c.detected) {
                var r = math.sqrt(c.dx*c.dx + c.dy*c.dy);
                tr.last_range = r;
                tr.bearing = math.atan2(c.dy, c.dx) * 180.0 / math.pi;
                tr.elevation = c.z;
                tr.vx = c.vx; tr.vy = c.vy; tr.vz = c.vz;
                tr.age = 0.0;
                tr.status = "tracking";
            } else {
                tr.status = "lost";
            }
        }
    }
};

# ------------------------------------------------------------------
# Scanning and Detection
# ------------------------------------------------------------------

var update_antenna = func(dt) {
    # rotate antenna according to current mode
    var p = radar_params[radar_mgr.mode] or nil;
    if (p) {
        radar_mgr.antenna_az = (radar_mgr.antenna_az + p.az_rate_dps * dt) % 360.0;
    }
};

var in_scan_volume = func(contact) {
    var p = radar_params[radar_mgr.mode];
    if (!p) return false;
    var r = math.sqrt(contact.dx*contact.dx + contact.dy*contact.dy);
    var bearing = math.atan2(contact.dy, contact.dx) * 180.0 / math.pi;
    # normalize relative to aircraft heading
    bearing -= getprop("/orientation/heading-deg",0);
    while (bearing > 180) bearing -= 360;
    while (bearing < -180) bearing += 360;
    if (math.abs(bearing - radar_mgr.antenna_az) > p.scan_az/2) return false;
    # elevation check omitted (assume within volume)
    return true;
};

# cache results of LOS checks to avoid repeated ray-casts within the same
# ping.  Keyed by contact id and ping timestamp.
var _los_cache = {};
var is_line_of_sight_clear = func(contact) {
    if (contact.id != nil and contains(_los_cache, contact.id)) {
        var entry = _los_cache[contact.id];
        if (entry.ping == radar_mgr.last_ping) {
            return entry.clear;
        }
    }

    # build a start point at the aircraft position (metres)
    var own_alt_ft = getprop("/position/altitude-ft") or 0;
    var start = {
        x: (getprop("/position/ground-x-m") or 0),
        y: (getprop("/position/ground-y-m") or 0),
        z: own_alt_ft * 0.3048   # ft -> m
    };
    # direction vector towards contact (m)
    var dir = {
        x: contact.dx * 0.3048,
        y: contact.dy * 0.3048,
        z: (contact.z - own_alt_ft) * 0.3048
    };
    var hit = get_cart_ground_intersection(start, dir);
    var clear;
    if (hit == nil) {
        clear = 1;           # nothing blocking
    } else {
        # compute distances along ray: hit may not lie exactly on the unit direction
        var dxh = hit.x - start.x;
        var dyh = hit.y - start.y;
        var dzh = hit.z - start.z;
        var d_hit = math.sqrt(dxh*dxh + dyh*dyh + dzh*dzh);
        var d_contact = math.sqrt(dir.x*dir.x + dir.y*dir.y + dir.z*dir.z);
        clear = (d_hit >= d_contact);
    }
    if (contact.id != nil) {
        _los_cache[contact.id] = { ping: radar_mgr.last_ping, clear: clear };
    }
    return clear;
};

var calc_detection_prob = func(contact) {
    var p = radar_params[radar_mgr.mode];
    if (!p) return 0.0;
    var r = math.sqrt(contact.dx*contact.dx + contact.dy*contact.dy);
    if (r > p.max_range_ft) return 0.0;
    # ground-look returns are synthetic; always detect if within range
    if (radar_mgr.mode == RM.GL and contact.rcs == RCS.GROUND) return 1.0;
    # if terrain blocks ray, no detection
    if (!is_line_of_sight_clear(contact)) return 0.0;
    # simple range-to-rcs scaling using R^4 law
    var sigma = contact.rcs;
    var ref_range = p.max_range_ft * math.pow(sigma, 0.25); # scale with RCS
    var prob = 1.0 - math.pow(r / ref_range, 4);
    prob = math.max(0.0, math.min(1.0, prob));
    # adjust for horizon
    var alt_ft = contact.z;
    var own_alt_ft = getprop("/position/altitude-ft") or 0;
    var horizon = RADAR_HORIZON_FACTOR * math.sqrt(own_alt_ft);
    if ((r/FT_PER_NM) > horizon) {
        prob *= 0.5; # beyond horizon degrade
    }
    return prob;
};

# ------------------------------------------------------------------
# Main update routine
# ------------------------------------------------------------------

var update_radar_manager = func(dt) {
    # periodic update at radar_mgr.update_interval
    if (dt <= 0) dt = 0.1;
    update_antenna(dt);

    # advance contacts
    for (var i = 0; i < radar_mgr.contacts.length; i++) {
        var c = radar_mgr.contacts[i];
        c.dx += c.vx * dt;
        c.dy += c.vy * dt;
        c.z  += c.vz * dt;
        c.age += dt;
    }

    # ping logic: every 0.5 sec for search modes, higher for DF
    var now = getprop("/sim/time/elapsed-sec") or 0;
    var ping_interval = 1.0;
    if (radar_mgr.mode == RM.DF) ping_interval = 1.0 / DF_UPDATE_RATE_HZ;
    if ((now - radar_mgr.last_ping) >= ping_interval) {
        radar_mgr.last_ping = now;

        # clear existing contacts when switching to ground-look mode so we only
        # report fresh terrain returns
        if (radar_mgr.mode == RM.GL) {
            clear_contacts();
            generate_ground_contact();
        }

        # evaluate detection for each contact
        for (var j = 0; j < radar_mgr.contacts.length; j++) {
            var cc = radar_mgr.contacts[j];
            if (!in_scan_volume(cc)) {
                cc.detected = 0;
                continue;
            }
            var prob = calc_detection_prob(cc);
            cc.detected = (math.random() < prob) ? 1 : 0;
        }
        # manage track initiation (TWS/STT)
        if (radar_mgr.mode == RM.TWS or radar_mgr.mode == RM.STT) {
            for (var k = 0; k < radar_mgr.contacts.length; k++) {
                var ct = radar_mgr.contacts[k];
                if (!ct.detected) continue;
                # see if contact already has a track
                var found = nil;
                for (var m = 0; m < radar_mgr.tracks.length; m++) {
                    if (radar_mgr.tracks[m].contact_id == ct.id) {
                        found = radar_mgr.tracks[m];
                        break;
                    }
                }
                if (!found) {
                    # potentially start new track after successive hits
                    if (ct.age > ping_interval * TWS_INIT_HITS) {
                        create_track(ct);
                    }
                }
            }
        }
    }

    # update existing tracks
    update_tracks(dt);

    # mode-specific behaviour and lock logic
    var nearest = nil;
    var nearest_range = 1e12;
    for (var idx = 0; idx < radar_mgr.contacts.length; idx++) {
        var ct = radar_mgr.contacts[idx];
        var rng = math.sqrt(ct.dx*ct.dx + ct.dy*ct.dy);
        if (!ct.detected) continue;
        if (rng < nearest_range) {
            nearest_range = rng;
            nearest = ct;
        }
    }

    # update properties based on mode
    if (radar_mgr.mode == RM.OFF) {
        setprop("/avionics/radar/contacts", 0);
        setprop("/avionics/radar/lock", 0);
    } elsif (radar_mgr.mode == RM.VS or radar_mgr.mode == RM.RWS or radar_mgr.mode == RM.BEACON) {
        if (nearest) {
            setprop("/avionics/radar/contacts", 1);
            setprop("/avionics/radar/target-range-ft", nearest_range);
            var bear = math.atan2(nearest.dy, nearest.dx) * 180.0 / math.pi;
            if (bear > 180) bear -= 360;
            if (bear < -180) bear += 360;
            setprop("/avionics/radar/target-bearing-deg", bear);
            setprop("/avionics/radar/target-alt-ft", nearest.z);
            setprop("/avionics/radar/target-id", nearest.id);
        } else {
            setprop("/avionics/radar/contacts", 0);
            setprop("/avionics/radar/target-range-ft", 0);
            setprop("/avionics/radar/target-bearing-deg", 0);
            setprop("/avionics/radar/target-alt-ft", 0);
            setprop("/avionics/radar/target-id", 0);
        }
        setprop("/avionics/radar/lock", 0);
    } elsif (radar_mgr.mode == RM.TWS) {
        # show nearest track candidate
        if (radar_mgr.tracks.length > 0) {
            var tr0 = radar_mgr.tracks[0];
            setprop("/avionics/radar/contacts", radar_mgr.tracks.length);
            setprop("/avionics/radar/target-range-ft", tr0.last_range);
            setprop("/avionics/radar/target-bearing-deg", tr0.bearing);
            setprop("/avionics/radar/target-alt-ft", tr0.elevation);
            setprop("/avionics/radar/target-id", tr0.contact_id);
            # candidate for lock
            if (tr0.last_range < STT_LOCK_RANGE_FT) {
                radar_mgr.lock_age += dt;
                if (radar_mgr.lock_age > 2.0) {
                    radar_mgr.locked_track = tr0;
                    setprop("/avionics/radar/lock", 1);
                }
            } else {
                radar_mgr.lock_age = 0.0;
                setprop("/avionics/radar/lock", 0);
            }
        } else {
            setprop("/avionics/radar/contacts", 0);
            setprop("/avionics/radar/lock", 0);
            radar_mgr.lock_age = 0.0;
            setprop("/avionics/radar/target-range-ft", 0);
            setprop("/avionics/radar/target-bearing-deg", 0);
            setprop("/avionics/radar/target-alt-ft", 0);
            setprop("/avionics/radar/target-id", 0);
        }
    } elsif (radar_mgr.mode == RM.STT) {
        if (nearest && nearest_range < STT_LOCK_RANGE_FT) {
            radar_mgr.locked_track = { contact_id: nearest.id };
            setprop("/avionics/radar/lock", 1);
            setprop("/avionics/radar/contacts", 1);
            setprop("/avionics/radar/target-range-ft", nearest_range);
            var b3 = math.atan2(nearest.dy, nearest.dx) * 180.0 / math.pi;
            if (b3 > 180) b3 -= 360;
            if (b3 < -180) b3 += 360;
            setprop("/avionics/radar/target-bearing-deg", b3);
            setprop("/avionics/radar/target-alt-ft", nearest.z);
            setprop("/avionics/radar/target-id", nearest.id);
        } else {
            radar_mgr.locked_track = nil;
            setprop("/avionics/radar/lock", 0);
            setprop("/avionics/radar/contacts", 0);
            setprop("/avionics/radar/target-range-ft", 0);
            setprop("/avionics/radar/target-bearing-deg", 0);
            setprop("/avionics/radar/target-alt-ft", 0);
            setprop("/avionics/radar/target-id", 0);
        }
    } elsif (radar_mgr.mode == RM.DF) {
        # treat same as search but update HUD faster
        if (nearest) {
            setprop("/avionics/radar/contacts", 1);
            setprop("/avionics/radar/target-range-ft", nearest_range);
            var bdf = math.atan2(nearest.dy, nearest.dx) * 180.0 / math.pi;
            if (bdf > 180) bdf -= 360;
            if (bdf < -180) bdf += 360;
            setprop("/avionics/radar/target-bearing-deg", bdf);
            setprop("/avionics/radar/target-alt-ft", nearest.z);
            setprop("/avionics/radar/target-id", nearest.id);
        } else {
            setprop("/avionics/radar/contacts", 0);
            setprop("/avionics/radar/target-range-ft", 0);
            setprop("/avionics/radar/target-bearing-deg", 0);
            setprop("/avionics/radar/target-alt-ft", 0);
            setprop("/avionics/radar/target-id", 0);
        }
        setprop("/avionics/radar/lock", 0);
    } elsif (radar_mgr.mode == RM.GL) {
        # ground-look: only report ground returns (marked by RCS.GROUND)
        var ground_near = nil;
        var grng = 1e12;
        for (var i = 0; i < radar_mgr.contacts.length; i++) {
            var cc = radar_mgr.contacts[i];
            if (!cc.detected) continue;
            if (cc.rcs == RCS.GROUND) {
                var rr = math.sqrt(cc.dx*cc.dx + cc.dy*cc.dy);
                if (rr < grng) { grng = rr; ground_near = cc; }
            }
        }
        if (ground_near) {
            setprop("/avionics/radar/contacts", 1);
            setprop("/avionics/radar/target-range-ft", grng);
            var bg = math.atan2(ground_near.dy, ground_near.dx) * 180.0 / math.pi;
            if (bg > 180) bg -= 360;
            if (bg < -180) bg += 360;
            setprop("/avionics/radar/target-bearing-deg", bg);
            setprop("/avionics/radar/target-alt-ft", ground_near.z);
            setprop("/avionics/radar/target-id", ground_near.id);
        } else {
            setprop("/avionics/radar/contacts", 0);
            setprop("/avionics/radar/target-range-ft", 0);
            setprop("/avionics/radar/target-bearing-deg", 0);
            setprop("/avionics/radar/target-alt-ft", 0);
            setprop("/avionics/radar/target-id", 0);
        }
        setprop("/avionics/radar/lock", 0);
    }

    # electrical load property update
    var transmitting = (radar_mgr.mode != RM.OFF);
    setprop("/systems/radar/transmit", transmitting ? 1 : 0);

    # HUD symbology outputs
    var mode_text = "OFF";
    if (radar_mgr.mode == RM.VS) mode_text = "VS";
    elsif (radar_mgr.mode == RM.RWS) mode_text = "RWS";
    elsif (radar_mgr.mode == RM.BEACON) mode_text = "BCN";
    elsif (radar_mgr.mode == RM.TWS) mode_text = "TWS";
    elsif (radar_mgr.mode == RM.STT) mode_text = "STT";
    elsif (radar_mgr.mode == RM.DF) mode_text = "DF";
    elsif (radar_mgr.mode == RM.GL) mode_text = "GL";
    setprop("/avionics/hud/radar-mode-text", mode_text);
    # target range display in nm
    var r = getprop("/avionics/radar/target-range-ft") or 0;
    setprop("/avionics/radar/antenna-az-deg", radar_mgr.antenna_az);
    if (r > 0) {
        var rnm = r / FT_PER_NM;
        setprop("/avionics/hud/target-range-display", sprintf("%.1f nm", rnm));
    } else {
        setprop("/avionics/hud/target-range-display", "---");
    }
    setprop("/avionics/hud/lock-indicator", getprop("/avionics/radar/lock") or 0);
};

# ------------------------------------------------------------------
# Utilities exposed for other modules
# ------------------------------------------------------------------
var radar_system = {
    create_contact: create_contact,
    clear_contacts: clear_contacts,
    update: update_radar_manager,
    modes: RM,
    params: radar_params,
    get_contacts: func { return radar_mgr.contacts; },
    get_tracks: func { return radar_mgr.tracks; },
};

# maintain backward compatibility: legacy caller name
var update_radar = radar_system.update;

# ------------------------------------------------------------------
# Property initialization and listeners
# ------------------------------------------------------------------
setprop("/avionics/radar/mode", RM.OFF);
setprop("/avionics/radar/lock", 0);
setprop("/avionics/radar/contacts", 0);
setprop("/avionics/radar/target-range-ft", 0);
setprop("/avionics/radar/target-bearing-deg", 0);
setprop("/avionics/radar/target-alt-ft", 0);
setprop("/avionics/radar/target-id", 0);

# create electrical load property used by electrical system
setprop("/systems/radar/transmit", 0);

# listen for mode-request changes
setlistener("/avionics/radar/mode-request", func(n) {
    var req = n.getValue();
    if (req != radar_mgr.mode) {
        radar_mgr.mode = req;
        radar_mgr.lock_age = 0;
        radar_mgr.locked_track = nil;
    }
});

# periodic timer for radar update
var radar_timer = func {
    update_radar_manager(radar_mgr.update_interval);
    settimer(radar_timer, radar_mgr.update_interval);
};
settimer(radar_timer, radar_mgr.update_interval);

# end of RadarManager.nas
