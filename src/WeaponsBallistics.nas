# WeaponsBallistics.nas - gun and bomb ballistic models with realistic trajectories
# F-4J/S nonnuclear ordnance ballistics: Mk-series bombs, cluster munitions, rockets

# Calculate ballistic bomb impact point (gravity + drag)
# Returns time-to-impact and impact coordinates
var calculate_bomb_impact = func(release_alt_ft, release_speed_fts, release_pitch_deg) {
    var result = {
        time_sec: 0,
        impact_range_ft: 0,
        impact_x: 0,
        impact_y: 0,
        terminal_velocity_fts: 750,  # typical for GP bomb
    };
    
    # Simple ballistic: horizontal range = v*t, vertical drop = 0.5*g*t^2
    # Time to impact when pz reaches ground (alt=0)
    var g = 32.2; # ft/s^2
    var vz_initial = -release_speed_fts * math.sin(release_pitch_deg * math.pi / 180.0);
    var t_fall = (-vz_initial + math.sqrt(vz_initial*vz_initial + 2*g*release_alt_ft)) / g;
    
    result.time_sec = t_fall;
    result.impact_range_ft = release_speed_fts * math.cos(release_pitch_deg * math.pi / 180.0) * t_fall;
    result.impact_x = result.impact_range_ft;
    
    return result;
};

# Update air-to-ground ordnance ballistic trajectories
var update_ordnance_ballistics = func(dt) {
    if (typeof(weapons_state) == 'nil' or typeof(weapons_state.ordnance) == 'nil') return;
    
    var g = 32.2;  # gravity ft/s^2
    var air_density = 0.002377;  # slugs/ft^3 at sea level
    
    for (var i = weapons_state.ordnance.length - 1; i >= 0; i -= 1) {
        var o = weapons_state.ordnance[i];
        
        # Only update released ordnance
        if (o.status != 'released') continue;
        
        # Simple EOM: gravity + drag
        o.fall_time += dt;
        o.vz -= g * dt;  # gravity acceleration
        
        # Drag (simplified: proportional to v^2)
        var v_mag = math.sqrt(o.vx*o.vx + o.vy*o.vy + o.vz*o.vz);
        if (v_mag > 0.1) {
            var drag_accel = 0.5 * air_density * o.spec.drag_coeff * v_mag * v_mag / 50.0;  # normalized
            o.vx *= (1.0 - drag_accel * dt / v_mag);
            o.vy *= (1.0 - drag_accel * dt / v_mag);
            o.vz *= (1.0 - drag_accel * dt / v_mag);
        }
        
        # Update position
        o.px += o.vx * dt;
        o.py += o.vy * dt;
        o.pz += o.vz * dt;
        
        # Impact detection: check if ordnance has hit ground or water
        if (o.pz <= 0) {
            o.status = 'impact';
            print(sprintf('%s impact at range %.0f ft', o.type, math.sqrt(o.px*o.px + o.py*o.py)));
            setprop('/afcs/annunciator/weapon-impact', 1);
            
            # Simulate effect: remove nearby contacts from radar manager
            if (typeof(radar_mgr) != 'nil' and typeof(radar_mgr.contacts) != 'nil') {
                var blast_radius = 300.0;  # feet
                if (o.spec.category == 'cluster') {
                    blast_radius = o.spec.scatter_radius_ft;
                }
                
                for (var j = radar_mgr.contacts.length - 1; j >= 0; j -= 1) {
                    var c = radar_mgr.contacts[j];
                    var dx = c.dx - o.px;
                    var dy = c.dy - o.py;
                    var dist = math.sqrt(dx*dx + dy*dy);
                    if (dist < blast_radius) {
                        radar_mgr.contacts.splice(j, 1);
                        print(sprintf('%s destroyed contact id %d', o.type, c.id));
                    }
                }
            }
            
            # Remove ordnance from tracking after impact
            weapons_state.ordnance.splice(i, 1);
        }
    }
};

var update_weapons_ballistics = func(dt) {
    # Gun: instantaneous hit on radar target within short range
    var gun_cmd = getprop('/weapons/gun-cmd') or 0;
    var gun_ammo = getprop('/weapons/gun-ammo') or 640;
    var gun_burst = 6000; # M61A1 Vulcan: 6000 rpm

    if (gun_cmd and gun_ammo > 0) {
        var target_id = getprop('/avionics/radar/target-id') or 0;
        var range = getprop('/avionics/radar/target-range-ft') or 0;
        if (target_id > 0 and range > 0 and range < 4000.0) {
            # Hit probability scales with range: close range ~90%, degrading to ~30% at 4000 ft
            var p = 0.9 - (range / 4000.0) * 0.6;
            if (math.random() < p) {
                print(sprintf('GUN: Target %d hit at %.0f ft', target_id, range));
                # remove radar contact if present
                if (typeof(radar_mgr) != 'nil') {
                    for (var i = 0; i < radar_mgr.contacts.length; i += 1) {
                        if (radar_mgr.contacts[i].id == target_id) {
                            radar_mgr.contacts.splice(i, 1);
                            break;
                        }
                    }
                }
                setprop('/afcs/annunciator/weapon-impact', 1);
            }
        }
        # consume ammo proportional to burst and dt
        var rounds = gun_burst * dt / 60.0;
        gun_ammo = math.max(0, gun_ammo - rounds);
        setprop('/weapons/gun-ammo', gun_ammo);
    }

    # Update ordnance ballistics (bombs, cluster, rockets in flight)
    update_ordnance_ballistics(dt);

    # Clear the transient impact light after a short time
    if (getprop('/afcs/annunciator/weapon-impact') or 0) {
        if (math.random() < 0.2) setprop('/afcs/annunciator/weapon-impact', 0);
    }
};
# Initialize ballistics properties
setprop('/weapons/gun-ammo', 640);
setprop('/weapons/gun-cmd', 0);
setprop('/weapons/bomb-release', 0);