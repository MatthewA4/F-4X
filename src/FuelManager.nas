# FuelManager.nas - simple tank transfer and jettison logic

var fuel_cfg = {
    tanks: 4, # indices 0..3 map to existing JSBSim tanks if present
    transfer_rate_lb_s: 100.0, # default transfer rate
};

var init_fuel = func() {
    for (var i = 0; i < fuel_cfg.tanks; i += 1) {
        if (getprop('/propulsion/tank['~i~']/contents-lbs') == nil) setprop('/propulsion/tank['~i~']/contents-lbs', 0);
        if (getprop('/propulsion/tank['~i~']/jettisoned') == nil) setprop('/propulsion/tank['~i~']/jettisoned', 0);
    }
    setprop('/fcs/fuel-total-lb', 0);
};

var compute_total_fuel = func() {
    var total = 0;
    for (var i = 0; i < fuel_cfg.tanks; i += 1) {
        var j = getprop('/propulsion/tank['~i~']/jettisoned') or 0;
        var c = getprop('/propulsion/tank['~i~']/contents-lbs') or 0;
        if (j == 1) c = 0;
        total += c;
    }
    setprop('/fcs/fuel-total-lb', total);
};

var update_fuel_transfer = func(dt) {
    var auto_transfer = getprop('/controls/fuel/transfer-auto') or 1;
    if (auto_transfer) {
        # Move fuel from tanks 2/3 to feed tanks 0/1 as required
        var feed0 = getprop('/propulsion/tank[0]/contents-lbs') or 0;
        var aux2 = getprop('/propulsion/tank[2]/contents-lbs') or 0;
        var xfer = math.min(fuel_cfg.transfer_rate_lb_s*dt, aux2);
        if (xfer > 0) {
            setprop('/propulsion/tank[2]/contents-lbs', aux2 - xfer);
            setprop('/propulsion/tank[0]/contents-lbs', feed0 + xfer);
        }
    }
};

var handle_fuel_jettison = func() {
    var cmd = getprop('/controls/fuel/jettison') or 0;
    if (!cmd) return;
    # jettison selected tank index in property /controls/fuel/jettison-tank (0..3)
    var t = getprop('/controls/fuel/jettison-tank') or 0;
    if (t < 0 or t >= fuel_cfg.tanks) return;
    # Implement timed jettison sequence: set jettisoning flag and drain over time
    setprop('/propulsion/tank['~t~']/jettisoning', 1);
    setprop('/propulsion/tank['~t~']/jettison-sequence-time', 0);
    setprop('/controls/fuel/jettison', 0);
};

var process_jettison_sequences = func(dt) {
    for (var i = 0; i < fuel_cfg.tanks; i += 1) {
        var jseq = getprop('/propulsion/tank['~i~']/jettisoning') or 0;
        if (!jseq) continue;
        var elapsed = getprop('/propulsion/tank['~i~']/jettison-sequence-time') or 0;
        elapsed += dt;
        setprop('/propulsion/tank['~i~']/jettison-sequence-time', elapsed);
        # drain at 200 lb/s for 10 seconds as demonstration
        var drain = math.min(200.0 * dt, getprop('/propulsion/tank['~i~']/contents-lbs') or 0);
        var cur = (getprop('/propulsion/tank['~i~']/contents-lbs') or 0) - drain;
        setprop('/propulsion/tank['~i~']/contents-lbs', cur);
        if (elapsed > 10.0 or cur <= 0) {
            setprop('/propulsion/tank['~i~']/jettisoning', 0);
            setprop('/propulsion/tank['~i~']/jettisoned', 1);
            setprop('/propulsion/tank['~i~']/jettison-sequence-time', 0);
            print(sprintf('Fuel tank %d jettison sequence completed', i));
        }
    }
};

var update_fuel_manager = func(dt) {
    update_fuel_transfer(dt);
    handle_fuel_jettison();
    process_jettison_sequences(dt);
    compute_total_fuel();
};

init_fuel();

var update_fuel = func(dt) { update_fuel_manager(dt); };
