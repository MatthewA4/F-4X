# BleedAirSystem.nas - engine bleed air extraction and pneumatic system coupling
# Models compressor bleed extraction, air conditioning, pressurization, and anti-ice

var bleed = {
    bleed_source: [0, 0], # 0=engine[n], 1=APU, 2=none
    bleed_valve_pos: [0.0, 0.0],
    bleed_flow: [0, 0],   # lb/min
    cabin_press_supply: 0,
    engine_thrust_loss: [0, 0],
};

var init_bleed_air = func() {
    setprop('/engines/bleed[0]/source', 0);
    setprop('/engines/bleed[0]/flow-lb-min', 0);
    setprop('/engines/bleed[0]/valve-position', 0);
    setprop('/cabin/bleed-supply', 0);
    setprop('/engines/engine[0]/bleed-thrust-loss', 0);
    setprop('/engines/engine[1]/bleed-thrust-loss', 0);
};

var update_bleed_air = func(dt) {
    var n1_0 = getprop('/fdm/jsbsim/propulsion/engine[0]/n1') or 0;
    var n1_1 = getprop('/fdm/jsbsim/propulsion/engine[1]/n1') or 0;
    var cabin_alt = getprop('/cabin/cabin-altitude-ft') or 0;
    var demand = getprop('/cabin/pressurization-demand') or 1;
    
    # Bleed source priority: Engine 1 > Engine 0 > none
    var bleed_source = 0;
    var n1_source = n1_0;
    
    if (n1_1 > n1_0) {
        bleed_source = 1;
        n1_source = n1_1;
    }
    
    # Bleed flow increases with N1 and cabin demand
    var max_flow = 15.0 + (n1_source / 100.0) * 30.0; # 15-45 lb/min
    var bleed_demand = 5.0 + demand * 10.0; # 5-15 lb/min base + demand
    
    bleed.bleed_flow[bleed_source] = math.min(bleed_demand, max_flow);
    
    # Bleed extraction reduces engine thrust slightly (~1-3% depending on extraction rate)
    for (var e = 0; e < 2; e += 1) {
        var extraction = (bleed.bleed_flow[e] / 45.0) * 0.03; # up to 3% loss
        bleed.engine_thrust_loss[e] = extraction;
        setprop('/engines/engine['~e~']/bleed-thrust-loss', extraction);
    }
    
    # Pressurize cabin via bleed air
    if (bleed.bleed_flow[bleed_source] > 0) {
        setprop('/cabin/bleed-supply', 1);
    } else {
        setprop('/cabin/bleed-supply', 0);
    }
};

init_bleed_air();
