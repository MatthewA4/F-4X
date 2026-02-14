# StoresManager.nas - manage external stores weights, drag and jettison

var stores_cfg = {
    hardpoints: 9,
};

var init_stores = func() {
    for (var i = 0; i < stores_cfg.hardpoints; i += 1) {
        if (getprop('/fcs/store['~i~']/weight-lb') == nil) setprop('/fcs/store['~i~']/weight-lb', 0);
        if (getprop('/fcs/store['~i~']/jettisoned') == nil) setprop('/fcs/store['~i~']/jettisoned', 0);
    }
    setprop('/fcs/stores-total-weight-lb', 0);
    setprop('/fcs/stores-drag-delta', 0);
};

var compute_stores = func() {
    var total = 0;
    var drag = 0.0;
    for (var i = 0; i < stores_cfg.hardpoints; i += 1) {
        var w = getprop('/fcs/store['~i~']/weight-lb') or 0;
        var j = getprop('/fcs/store['~i~']/jettisoned') or 0;
        if (j == 1) w = 0;
        total += w;
        # Simple drag mapping by station type: approximate by weight
        drag += (w / 10000.0) * 0.002; # each 10k lb gives 0.002 deltaCD
    }
    setprop('/fcs/stores-total-weight-lb', total);
    setprop('/fcs/stores-drag-delta', drag);
};

var jettison_stores = func() {
    var cmd = getprop('/controls/weapons/jettison') or 0;
    if (cmd == 0) return;
    # Jettison all non-zero stores (simple emergency jettison)
    for (var i = 0; i < stores_cfg.hardpoints; i += 1) {
        var w = getprop('/fcs/store['~i~']/weight-lb') or 0;
        var j = getprop('/fcs/store['~i~']/jettisoned') or 0;
        if (w > 0 and j == 0) {
            setprop('/fcs/store['~i~']/jettisoned', 1);
            # create a lightweight debris contact for radar manager
            if (typeof('create_contact') != 'nil') create_contact(1000.0 + (i*500.0), (i-4)*10.0, getprop('/position/altitude-ft') or 0, 200.0);
            print(sprintf('Jettisoned store at hardpoint %d (%.0f lb)', i, w));
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
