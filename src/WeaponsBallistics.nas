# WeaponsBallistics.nas - simple gun and bomb ballistics (instant-hit approximations)

var update_weapons_ballistics = func(dt) {
    # Gun: instantaneous hit on radar target within short range
    var gun_cmd = getprop('/weapons/gun-cmd') or 0;
    var gun_ammo = getprop('/weapons/gun-ammo') or 2000;
    var gun_burst = getprop('/weapons/gun-burst-rate') or 6000; # rounds per minute

    if (gun_cmd and gun_ammo > 0) {
        var target_id = getprop('/avionics/radar/target-id') or 0;
        var range = getprop('/avionics/radar/target-range-ft') or 0;
        if (target_id > 0 and range > 0 and range < 3000.0) {
            # Hit probability scales with range
            var p = 0.9 - (range / 3000.0) * 0.6;
            if (math.random() < p) {
                print(sprintf('GUN: Target %d hit at %.0f ft', target_id, range));
                # remove radar contact if present
                if (typeof('radar_mgr') != 'nil') {
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

    # Bomb release: drop forward if commanded; simple ballistic thud at ground
    var bomb_cmd = getprop('/weapons/bomb-release') or 0;
    if (bomb_cmd) {
        var target_range = getprop('/avionics/radar/target-range-ft') or 5000.0;
        var target_bearing = getprop('/avionics/radar/target-bearing-deg') or 0;
        var impact_x = target_range;
        print(sprintf('BOMB: Released toward bearing %.1f°, range %.0f ft', target_bearing, target_range));
        # Simple effect: remove nearest contact within 2000 ft of impact
        if (typeof('radar_mgr') != 'nil') {
            for (var j = radar_mgr.contacts.length-1; j >= 0; j -= 1) {
                var c = radar_mgr.contacts[j];
                var r = math.sqrt(c.dx*c.dx + c.dy*c.dy);
                if (math.abs(r - impact_x) < 2000.0) {
                    radar_mgr.contacts.splice(j, 1);
                    print(sprintf('BOMB: Destroyed contact %d', c.id));
                }
            }
        }
        # consume a store if available on a dedicated bomb station
        # find any store weight >0 and mark jettisoned
        for (var s = 0; s < 9; s += 1) {
            var w = getprop('/fcs/store['~s~']/weight-lb') or 0;
            var j = getprop('/fcs/store['~s~']/jettisoned') or 0;
            if (w > 0 and j == 0) { setprop('/fcs/store['~s~']/jettisoned', 1); break; }
        }
        setprop('/weapons/bomb-release', 0);
        setprop('/afcs/annunciator/weapon-impact', 1);
    }

    # Clear the transient impact light after a short time
    if (getprop('/afcs/annunciator/weapon-impact') or 0) {
        if (math.random() < 0.2) setprop('/afcs/annunciator/weapon-impact', 0);
    }
};

setprop('/weapons/gun-ammo', 2000);
setprop('/weapons/gun-burst-rate', 6000);
setprop('/weapons/gun-cmd', 0);
setprop('/weapons/bomb-release', 0);
