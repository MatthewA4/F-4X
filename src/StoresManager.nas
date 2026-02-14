# StoresManager.nas - manage external stores: weight, drag, CG shift, and jettison
# Enhanced for F-4J/S with realistic ordnance loading and balance calculations

# Load OrdnanceDatabase
io.load_nasal( getprop('/sim/fg-root') ~ '/Aircraft/F-4X/Systems', 'OrdnanceDatabase' );

var stores_cfg = {
    hardpoints: 9,
    empty_aircraft_cg_x: 0.0,  # relative to MAC leading edge
};

var init_stores = func() {
    for (var i = 0; i < stores_cfg.hardpoints; i += 1) {
        if (getprop('/fcs/store['~i~']/weight-lb') == nil) setprop('/fcs/store['~i~']/weight-lb', 0);
        if (getprop('/fcs/store['~i~']/jettisoned') == nil) setprop('/fcs/store['~i~']/jettisoned', 0);
        if (getprop('/fcs/store['~i~']/ordnance-type') == nil) setprop('/fcs/store['~i~']/ordnance-type', '');
    }
    setprop('/fcs/stores-total-weight-lb', 0);
    setprop('/fcs/stores-drag-delta', 0);
    setprop('/fcs/cg-shift-in', 0);  # inches from reference point
    setprop('/fcs/cg-shift-percent-mac', 0);  # as % of MAC
};

# Compute total stores weight, drag, and CG shift
var compute_stores = func() {
    var total = 0;
    var drag = 0.0;
    var cg_x_sum = 0.0;
    var cg_y_sum = 0.0;
    var cg_z_sum = 0.0;
    var moment_sum = 0.0;
    
    for (var i = 0; i < stores_cfg.hardpoints; i += 1) {
        var w = getprop('/fcs/store['~i~']/weight-lb') or 0;
        var j = getprop('/fcs/store['~i~']/jettisoned') or 0;
        var jseq = getprop('/fcs/store['~i~']/jettisoning') or 0;
        
        if (j == 1 or jseq == 1) w = 0;
        
        total += w;
        
        # Retrieve ordnance spec for accurate drag calculation
        var ord_type = getprop('/fcs/store['~i~']/ordnance-type') or '';
        var spec = nil;
        if (ord_type != '') {
            spec = get_ordnance_spec(ord_type);
        }
        
        # Station-specific drag deltas (refined for F-4J/S, in delta-CD units)
        if (w > 0) {
            if (i == 0) drag += 0.004;        # 0: centerline fuselage
            elsif (i == 1 or i == 2) drag += 0.0015;  # 1-2: wing inner pylons
            elsif (i == 3 or i == 4) drag += 0.0016;  # 3-4: Sparrow recesses
            elsif (i == 5 or i == 6) drag += 0.0045;  # 5-6: middle pylons (gun/missile)
            elsif (i == 7 or i == 8) drag += 0.008;   # 7-8: outer wing pylons (ordnance)
        }
        
        # Center of gravity calculations (get offsets from OrdnanceDatabase)
        if (w > 0 and i < 9) {
            # Get CG offset for this hardpoint from database (in feet from aircraft CG)
            var offset = hardpoint_cg_offsets[i];  # [x, y, z] in feet
            cg_x_sum += offset[0] * w;
            cg_y_sum += offset[1] * w;
            cg_z_sum += offset[2] * w;
            moment_sum += w;
        }
    }
    
    setprop('/fcs/stores-total-weight-lb', total);
    setprop('/fcs/stores-drag-delta', math.min(drag, 0.08)); # cap drag delta
    
    # CG shift: simple moment calculation
    if (moment_sum > 0) {
        var cg_shift_x_in = (cg_x_sum / moment_sum) * 12.0; # convert feet to inches
        var cg_shift_y_in = (cg_y_sum / moment_sum) * 12.0;
        var cg_shift_z_in = (cg_z_sum / moment_sum) * 12.0;
        
        # Store CG shift magnitude in inches
        var cg_shift_mag = math.sqrt(cg_shift_x_in*cg_shift_x_in + cg_shift_y_in*cg_shift_y_in);
        setprop('/fcs/cg-shift-in', cg_shift_mag);
        
        # Estimate impact on CG as % of Mean Aerodynamic Chord (~13 ft for F-4)
        var mac_in = 156.0;  # F-4 MAC ~13 feet
        var cg_shift_percent = (cg_shift_mag / mac_in) * 100.0;
        setprop('/fcs/cg-shift-percent-mac', math.min(cg_shift_percent, 5.0));
        
        print(sprintf('Stores CG shift: %.2f in (%.1f%% MAC), drag delta: %.5f',
                      cg_shift_mag, cg_shift_percent, getprop('/fcs/stores-drag-delta')));
    }
};

# Emergency jettison all stores
var jettison_stores = func() {
    var cmd = getprop('/controls/weapons/jettison') or 0;
    if (cmd == 0) return;
    
    print('STORES: Emergency jettison initiated');
    # Jettison all non-zero stores
    for (var i = 0; i < stores_cfg.hardpoints; i += 1) {
        var w = getprop('/fcs/store['~i~']/weight-lb') or 0;
        var j = getprop('/fcs/store['~i~']/jettisoned') or 0;
        if (w > 0 and j == 0) {
            setprop('/fcs/store['~i~']/jettisoned', 1);
            # create lightweight debris contact for radar manager to track
            if (typeof(create_contact) != 'nil') {
                create_contact(1000.0 + (i*500.0), (i-4)*10.0, getprop('/position/altitude-ft') or 0, 50.0);
            }
            print(sprintf('Jettisoned hardpoint %d (%.0f lb)', i, w));
        }
    }
    # clear jettison command
    setprop('/controls/weapons/jettison', 0);
};

var update_stores_manager = func(dt) {
    jettison_stores();
    compute_stores();
};

init_stores();

var update_stores = func(dt) { update_stores_manager(dt); };
