# Weapons.nas - Air-to-air and air-to-ground weapons management for F-4J/S
# Enhanced with nonnuclear ordnance support: Mk-series bombs, AGM missiles, rocket pods

# Load OrdnanceDatabase for spec data
io.load_nasal( getprop('/sim/fg-root') ~ '/Aircraft/F-4X/Systems', 'OrdnanceDatabase' );

var weapons_state = {
    missiles = [], # list of {id, type, status, target_id, px,py,pz, vx,vy,vz}
    ordnance = [], # list of bombs, rockets, air-to-ground missiles
    next_missile_id = 1,
    next_ord_id = 1000,
    active_loadout = 'CAP',
};

var load_missile = func(type) {
    var m = { id: weapons_state.next_missile_id, type: type, status: 'ready', target_id: 0, px:0, py:0, pz:0, vx:0, vy:0, vz:0 };
    weapons_state.next_missile_id += 1;
    weapons_state.missiles.push(m);
    return m;
};

# Create ordnance object (bombs, rockets, air-to-ground missiles) for release
var load_ordnance = func(ordnance_type, hardpoint) {
    var spec = get_ordnance_spec(ordnance_type);
    if (spec == nil) {
        print(sprintf('ERROR: Unknown ordnance type %s', ordnance_type));
        return nil;
    }
    
    var o = {
        id: weapons_state.next_ord_id,
        type: ordnance_type,
        hardpoint: hardpoint,
        spec: spec,
        status: 'ready',
        released: 0,
        target_id: 0,
        px: 0.0,
        py: 0.0, 
        pz: 0.0,
        vx: 0.0,
        vy: 0.0,
        vz: 0.0,
        fall_time: 0.0,
        guidance_mode: 'ballistic',
    };
    
    weapons_state.next_ord_id += 1;
    weapons_state.ordnance.push(o);
    return o;
};

# Apply a loadout configuration to aircraft
var apply_loadout = func(config_name) {
    var cfg = get_loadout_config(config_name);
    if (cfg == nil) {
        print(sprintf('ERROR: Unknown loadout %s', config_name));
        return;
    }
    
    print(sprintf('Applying loadout: %s - %s', config_name, cfg.name));
    weapons_state.active_loadout = config_name;
    
    # Clear existing ordnance
    for (var i = 0; i < 9; i += 1) {
        setprop('/fcs/store['~i~']/weight-lb', 0);
        setprop('/fcs/store['~i~']/jettisoned', 0);
    }
    weapons_state.ordnance = [];
    weapons_state.missiles = [];
    
    # Load stores from config definition
    foreach (var store; cfg.stores) {
        var hardpoint = store.hardpoint;
        var ord_type = store.ordnance;
        if (is_compatible(hardpoint, ord_type)) {
            var o = load_ordnance(ord_type, hardpoint);
            setprop('/fcs/store['~hardpoint~']/weight-lb', o.spec.weight_lbs);
        }
    }
    
    setprop('/weapons/loadout-name', config_name);
};

var find_missile = func(id) {
    for (var i = 0; i < weapons_state.missiles.length; i += 1) {
        if (weapons_state.missiles[i].id == id) return weapons_state.missiles[i];
    }
    return nil;
};

var aim9_launch = func(missile_id) {
    var m = find_missile(missile_id);
    if (m == nil) return 0;
    if (m.status != 'ready') return 0;

    var target_id = getprop("/avionics/radar/target-id") or 0;
    var lock = getprop("/avionics/radar/lock") or 0;
    if (target_id > 0 and lock == 1) {
        m.target_id = target_id;
        m.status = 'launched';
        # Initialize missile position near aircraft (local offsets)
        m.px = 0; m.py = 0; m.pz = getprop('/position/altitude-ft') or 0;
        var missile_speed_fts = 1500.0; # ~ 900 kt effective
        # Set initial velocity forward along aircraft heading
        var hdg = getprop('/orientation/heading-deg') * math.pi / 180.0;
        m.vx = missile_speed_fts * math.cos(hdg);
        m.vy = missile_speed_fts * math.sin(hdg);
        m.vz = 0;
        setprop('/afcs/annunciator/weapons-fired', 1);
        print(sprintf("AIM-9 launched at target %d with missile id %d", target_id, missile_id));
        return 1;
    } else {
        print("AIM-9 launch aborted: no lock/target");
        return 0;
    }
};

var aim7_launch = func(missile_id) {
    var m = find_missile(missile_id);
    if (m == nil) return 0;
    if (m.status != 'ready') return 0;

    var target_id = getprop("/avionics/radar/target-id") or 0;
    var lock = getprop("/avionics/radar/lock") or 0;
    if (target_id > 0 and lock == 1) {
        m.target_id = target_id;
        m.status = 'launched';
        m.type = 'AIM-7';
        m.px = 0; m.py = 0; m.pz = getprop('/position/altitude-ft') or 0;
        var missile_speed_fts = 1400.0; # slower than AIM-9
        var hdg = getprop('/orientation/heading-deg') * math.pi / 180.0;
        m.vx = missile_speed_fts * math.cos(hdg);
        m.vy = missile_speed_fts * math.sin(hdg);
        m.vz = 0;
        setprop('/afcs/annunciator/weapons-fired', 1);
        print(sprintf("AIM-7 launched at target %d with missile id %d", target_id, missile_id));
        return 1;
    } else {
        print("AIM-7 launch aborted: no lock/target");
        return 0;
    }
};

# Air-to-ground missile launch: AGM-65 Maverick (TV-guided), AGM-45 Shrike (anti-radiation)
var agm_launch = func(ordnance_id) {
    for (var i = 0; i < weapons_state.ordnance.length; i += 1) {
        var o = weapons_state.ordnance[i];
        if (o.id == ordnance_id and o.status == 'ready') {
            if (o.spec.subtype != 'air-to-ground') {
                print("AGM launch: ordnance is not air-to-ground type");
                return 0;
            }
            
            o.status = 'launched';
            o.released = 1;
            var alt = getprop('/position/altitude-ft') or 0;
            o.px = 0; o.py = 0; o.pz = alt;
            
            # Get aircraft velocity
            var hdg = getprop('/orientation/heading-deg') * math.pi / 180.0;
            var air_speed = getprop('/velocities/airspeed-kt') or 300;
            var air_speed_fts = air_speed * 1.68781;
            
            o.vx = air_speed_fts * math.cos(hdg);
            o.vy = air_speed_fts * math.sin(hdg);
            o.vz = getprop('/velocities/vertical-speed-fps') or 0;
            
            setprop('/afcs/annunciator/weapons-fired', 1);
            print(sprintf("AGM %s launched (id=%d) at altitude %.0f ft", o.type, ordnance_id, alt));
            return 1;
        }
    }
    return 0;
};

# Bomb or cluster ordnance release
var release_ordnance = func(ordnance_id, mode) {
    # mode: 'single', 'ripple', 'salvo'
    for (var i = 0; i < weapons_state.ordnance.length; i += 1) {
        var o = weapons_state.ordnance[i];
        if (o.id == ordnance_id and o.status == 'ready') {
            o.status = 'released';
            o.released = 1;
            o.fall_time = 0.0;
            o.release_mode = mode;
            
            var alt = getprop('/position/altitude-ft') or 0;
            o.px = 0; o.py = 0; o.pz = alt;
            
            # Inherit aircraft velocity at release
            var hdg = getprop('/orientation/heading-deg') * math.pi / 180.0;
            var air_speed = getprop('/velocities/airspeed-kt') or 300;
            var air_speed_fts = air_speed * 1.68781;
            
            o.vx = air_speed_fts * math.cos(hdg);
            o.vy = air_speed_fts * math.sin(hdg);
            o.vz = getprop('/velocities/vertical-speed-fps') or 0;
            
            setprop('/afcs/annunciator/weapons-fired', 1);
            print(sprintf("%s released (id=%d, mode=%s) at altitude %.0f ft", o.type, ordnance_id, mode, alt));
            
            # Mark hardpoint jettisoned in stores manager
            setprop('/fcs/store['~o.hardpoint~']/jettisoned', 1);
            
            return 1;
        }
    }
    return 0;
};

# Missile dynamics: simple proportional navigation / pure pursuit
var update_missiles = func(dt) {
    # Helper: find contact by id in radar manager
    var find_contact = func(id) {
        for (var i = 0; i < radar_mgr.contacts.length; i += 1) {
            if (radar_mgr.contacts[i].id == id) return radar_mgr.contacts[i];
        }
        return nil;
    };

    for (var i = weapons_state.missiles.length-1; i >= 0; i -= 1) {
        var mm = weapons_state.missiles[i];
        if (mm.status == 'launched') {
            var tgt = find_contact(mm.target_id);
            if (tgt == nil) {
                # No target - fly forward
                mm.px += mm.vx * dt;
                mm.py += mm.vy * dt;
                mm.pz += mm.vz * dt;
                # Long-run abort after leaving range
                if (math.sqrt(mm.px*mm.px + mm.py*mm.py) > RADAR_MAX_RANGE_FT*1.5) {
                    mm.status = 'expended';
                }
                continue;
            }

            # Compute LOS to target in local coordinates
            var tx = tgt.dx; var ty = tgt.dy; var tz = tgt.z - mm.pz;
            var dist = math.sqrt((tx-mm.px)*(tx-mm.px) + (ty-mm.py)*(ty-mm.py) + (tz)*(tz));
            if (dist < 150.0) {
                # Hit
                mm.status = 'impact';
                print(sprintf('Missile %d impacted target %d at range %.0f ft', mm.id, tgt.id, dist));
                # Remove contact from radar list
                for (var j = 0; j < radar_mgr.contacts.length; j += 1) {
                    if (radar_mgr.contacts[j].id == tgt.id) {
                        radar_mgr.contacts.splice(j, 1);
                        break;
                    }
                }
                # Clear avionics target if it matched
                if (getprop('/avionics/radar/target-id') == tgt.id) {
                    setprop('/avionics/radar/contacts', 0);
                    setprop('/avionics/radar/lock', 0);
                    setprop('/avionics/radar/target-id', 0);
                }
                continue;
            }

            # Guidance: behavior differs by missile type
            if (mm.type == 'AIM-9') {
                var desired_vx = (tx - mm.px) / dist * 2500.0; # desired speed ~2500 ft/s
                var desired_vy = (ty - mm.py) / dist * 2500.0;
                var steer_gain = 2.0; # responsiveness
                mm.vx += (desired_vx - mm.vx) * math.min(1.0, steer_gain * dt);
                mm.vy += (desired_vy - mm.vy) * math.min(1.0, steer_gain * dt);
            } else if (mm.type == 'AIM-7') {
                # AIM-7: semi-active radar homing - requires continued radar illumination (we simulate by requiring lock)
                var radar_lock = getprop('/avionics/radar/lock') or 0;
                if (radar_lock and getprop('/avionics/radar/target-id') == mm.target_id) {
                    # home gradually
                    var desired_vx2 = (tx - mm.px) / dist * 2200.0;
                    var desired_vy2 = (ty - mm.py) / dist * 2200.0;
                    var steer_gain2 = 1.2;
                    mm.vx += (desired_vx2 - mm.vx) * math.min(1.0, steer_gain2 * dt);
                    mm.vy += (desired_vy2 - mm.vy) * math.min(1.0, steer_gain2 * dt);
                } else {
                    # no illumination - fly ballistic
                    mm.vx *= 0.995;
                    mm.vy *= 0.995;
                }
            } else {
                var desired_vx = (tx - mm.px) / dist * 2000.0;
                var desired_vy = (ty - mm.py) / dist * 2000.0;
                var steer_gain = 1.0;
                mm.vx += (desired_vx - mm.vx) * math.min(1.0, steer_gain * dt);
                mm.vy += (desired_vy - mm.vy) * math.min(1.0, steer_gain * dt);
            }
            mm.px += mm.vx * dt;
            mm.py += mm.vy * dt;
            mm.pz += mm.vz * dt;
        }
    }
};

# Simple management loop: expose missile count and first ready id
var update_weapons = func(dt) {
    var ready_count = 0;
    var first_ready = 0;
    for (var i = 0; i < weapons_state.missiles.length; i += 1) {
        var mm = weapons_state.missiles[i];
        if (mm.status == 'ready') {
            ready_count += 1;
            if (first_ready == 0) first_ready = mm.id;
        }
    }
    setprop('/weapons/missile-ready-count', ready_count);
    setprop('/weapons/next-ready-missile-id', first_ready);

    # Count ordnance status
    var ordnance_count = weapons_state.ordnance.length;
    var ordnance_released = 0;
    foreach (var o; weapons_state.ordnance) {
        if (o.released) ordnance_released += 1;
    }
    setprop('/weapons/ordnance-count', ordnance_count);
    setprop('/weapons/ordnance-released', ordnance_released);

    # Update missile dynamics
    update_missiles(dt);

    # Clear weapons-fired annunciator after brief moment
    var fired = getprop('/afcs/annunciator/weapons-fired') or 0;
    if (fired) setprop('/afcs/annunciator/weapons-fired', 0);
};

# Initialize default CAP loadout and properties
apply_loadout('CAP');

setprop('/weapons/missile-ready-count', 0);
setprop('/weapons/next-ready-missile-id', 0);
setprop('/weapons/ordnance-count', 0);
setprop('/weapons/ordnance-released', 0);
setprop('/weapons/gun-ammo', 640);
setprop('/weapons/gun-cmd', 0);
setprop('/weapons/bomb-release', 0);
setprop('/weapons/loadout-name', 'CAP');

var update_weapons_manager = func(dt) {
    update_weapons(dt);
};

# Expose function expected by AFCS
var update_weapons = func(dt) {
    update_weapons_manager(dt);
};
