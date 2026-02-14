# ElectricalLoadShedding.nas - automatic bus priority and load shedding under emergency
# Ensures critical avionics stay powered during generator failure or electrical emergency

var elec_loads = {
    main_bus_loads: {}, # {system: power_draw_amps}
    ess_bus_loads: {},
    total_demand: 0,
    main_bus_available: 150, # amps from generator
    battery_capacity: 40,    # amp-hours, ~28V nominal
};

var init_load_shedding = func() {
    # Define critical load priorities
    elec_loads.main_bus_loads = {
        radar: 25,
        engine_start: 40, # transient only
        avionics: 30,
        flight_controls: 15,
        lighting: 10,
        heating: 20,
    };
    
    elec_loads.ess_bus_loads = {
        essential_avionics: 15,
        stall_warning: 2,
        fire_warning: 3,
        hydraulic_pump: 20,
    };
    
    setprop('/electrical/main-bus-load-amps', 0);
    setprop('/electrical/ess-bus-load-amps', 0);
    setprop('/electrical/load-shedding-active', 0);
    setprop('/electrical/radar-shed', 0);
    setprop('/electrical/heating-shed', 0);
};

var update_electrical_loads = func(dt) {
    var main_bus_ok = getprop('/electrical/main-bus-ok') or 0;
    var ess_bus_ok = getprop('/electrical/ess-bus-powered') or 0;
    var gen_output = main_bus_ok ? elec_loads.main_bus_available : 0;
    var batt_volt = getprop('/electrical/battery-voltage') or 28;
    var batt_soc = math.max(0, (batt_volt - 0) / 28.0); # state of charge
    
    # Calculate total demand
    var main_load = 0;
    foreach (var load; keys(elec_loads.main_bus_loads)) {
        var shed = getprop('/electrical/'~load~'-shed') or 0;
        if (!shed) {
            main_load += elec_loads.main_bus_loads[load];
        }
    }
    
    var ess_load = 0;
    foreach (var load; keys(elec_loads.ess_bus_loads)) {
        ess_load += elec_loads.ess_bus_loads[load];
    }
    
    # Under-generation emergency: start load shedding
    if (gen_output > 0 and main_load > gen_output * 0.8) {
        # Shed non-essential loads in priority order
        setprop('/electrical/load-shedding-active', 1);
        
        # Shed heating first
        if (main_load > gen_output * 0.9) setprop('/electrical/heating-shed', 1);
        # Then radar
        if (main_load > gen_output * 1.0) setprop('/electrical/radar-shed', 1);
        
        print('ELECTRICAL: Load shedding active');
    } else {
        setprop('/electrical/load-shedding-active', 0);
        setprop('/electrical/heating-shed', 0);
        setprop('/electrical/radar-shed', 0);
    }
    
    setprop('/electrical/main-bus-load-amps', main_load);
    setprop('/electrical/ess-bus-load-amps', ess_load);
};

init_load_shedding();
