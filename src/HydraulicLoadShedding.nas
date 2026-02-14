# HydraulicLoadShedding.nas - Reduce control authority on hydraulic failure
# When pump pressure drops, automatically shed non-essential hydraulic loads to preserve core flight control

var hyd_loads = {
    core_systems: {
        flight_control: 35,  # flight control surfaces (elevator, aileron, rudder) - ALWAYS prioritized
        landing_gear: 15,    # landing gear extension - high priority
    },
    auxiliary_systems: {
        air_refuel: 5,       # air refuel probe extension
        canopy: 3,           # canopy actuator
        wheel_brakes: 8,     # wheel brake pressure
        tail_hook: 4,        # tail hook extension
        utility_pump: 12,    # auxiliary hydraulic pump
    },
    pressure_nominal: 3000, # psi nominal system pressure
    pressure_critical: 1500, # psi below which load shedding mandatory
    core_pressure_threshold: 2500, # if below this, reduce FCS authority
    demand_total: 0,
    failure_mode: 0, # 0=normal, 1=pump failure, 2=leak, 3=qty low
};

var init_hydraulic_loads = func() {
    setprop('/hydraulics/main-pump-psi', hyd_loads.pressure_nominal);
    setprop('/hydraulics/core-demand-gpm', 0);
    setprop('/hydraulics/auxiliary-demand-gpm', 0);
    setprop('/hydraulics/load-shed-active', 0);
    setprop('/hydraulics/control-authority-factor', 1.0); # 1.0 = full, 0.5 = degraded
    setprop('/hydraulics/utility-pump-shed', 0);
    setprop('/hydraulics/wheel-brake-shed', 0);
    setprop('/hydraulics/refuel-probe-shed', 0);
};

var compute_pump_pressure = func(dt) {
    # Pump pressure is driven by engine speed, modulated by demand
    var eng0_n2 = getprop('/engines/engine[0]/n2-percent') or 0;
    var eng1_n2 = getprop('/engines/engine[1]/n2-percent') or 0;
    var avg_n2 = (eng0_n2 + eng1_n2) / 2.0;
    
    # Nominal pressure = 3000 psi at 100% N2
    var pressure_cmd = (avg_n2 / 100.0) * hyd_loads.pressure_nominal;
    pressure_cmd = math.max(500, math.min(3000, pressure_cmd)); # clamp
    
    # Slew pressure gradually
    var current = getprop('/hydraulics/main-pump-psi') or hyd_loads.pressure_nominal;
    var dP = (pressure_cmd - current) * 0.5; # lag constant
    var new_pressure = current + dP * dt;
    
    # Simulate failure scenarios (random with low probability)
    if (rand() < 0.00001) { # extremely rare spontaneous failure
        hyd_loads.failure_mode = int(rand() * 3) + 1; # modes 1-3
        print('HYDRAULICS: Failure mode '~hyd_loads.failure_mode~' detected');
    }
    
    # Apply failure mode effects
    switch (hyd_loads.failure_mode) {
        case 1: # pump failure
            new_pressure = 500; # pump output drops to min relief
            break;
        case 2: # external leak
            new_pressure = math.max(500, new_pressure - (rand() - 0.5) * 100 * dt);
            break;
        case 3: # low fluid quantity
            new_pressure = math.max(800, new_pressure * 0.7);
            break;
    }
    
    setprop('/hydraulics/main-pump-psi', new_pressure);
    return new_pressure;
};

var schedule_load_shedding = func(pump_psi) {
    # Emergency load shedding hierarchy
    var shed_utility = 0;
    var shed_brakes = 0;
    var shed_probe = 0;
    var control_factor = 1.0;
    
    if (pump_psi < hyd_loads.pressure_critical) {
        # Critical: shed all auxiliary loads, reduce FCS authority
        shed_utility = 1;
        shed_brakes = 1;
        shed_probe = 1;
        control_factor = 0.3; # reduced to 30% authority
        
        print('HYDRAULICS: Critical pressure - shedding all auxiliary loads');
    } elsif (pump_psi < hyd_loads.core_pressure_threshold) {
        # Degraded: shed non-essential, reduce FCS authority
        shed_utility = 1;
        shed_probe = 1;
        control_factor = 0.6; # reduced to 60% authority
    } else {
        control_factor = 1.0;
    }
    
    setprop('/hydraulics/load-shed-active', (shed_utility or shed_brakes or shed_probe) ? 1 : 0);
    setprop('/hydraulics/utility-pump-shed', shed_utility);
    setprop('/hydraulics/wheel-brake-shed', shed_brakes);
    setprop('/hydraulics/refuel-probe-shed', shed_probe);
    setprop('/hydraulics/control-authority-factor', control_factor);
};

var compute_demand = func(dt) {
    # Demand from control inputs
    var pitch_input = getprop('/controls/flight/elevator') or 0;
    var roll_input = getprop('/controls/flight/aileron') or 0;
    var yaw_input = getprop('/controls/flight/rudder') or 0;
    
    # Base demand: all inputs active
    var core_demand = hyd_loads.core_systems.flight_control * 
                      (math.abs(pitch_input) + math.abs(roll_input) + math.abs(yaw_input)) / 3.0;
    core_demand += hyd_loads.core_systems.landing_gear * (getprop('/controls/gear/gear-down') or 0);
    
    # Auxiliary demand: conditional on system integrity
    var aux_demand = hyd_loads.auxiliary_systems.utility_pump;
    if (!(getprop('/hydraulics/utility-pump-shed') or 0)) {
        aux_demand += hyd_loads.auxiliary_systems.wheel_brakes * 
                     (getprop('/controls/gear/brake-left') or 0);
        aux_demand += hyd_loads.auxiliary_systems.air_refuel * 0.5; # always some baseline
    }
    if (!(getprop('/hydraulics/refuel-probe-shed') or 0)) {
        aux_demand += hyd_loads.auxiliary_systems.air_refuel;
    }
    
    hyd_loads.demand_total = math.max(core_demand, 5); # always minimum demand
    setprop('/hydraulics/core-demand-gpm', core_demand);
    setprop('/hydraulics/auxiliary-demand-gpm', aux_demand);
};

var update_hydraulic_loads = func(dt) {
    var pump_psi = compute_pump_pressure(dt);
    compute_demand(dt);
    schedule_load_shedding(pump_psi);
    
    # Temperature effects on fluid viscosity and pressure
    var fluid_temp = getprop('/hydraulics/fluid-temperature-c') or 50;
    if (pump_psi < 2000 and fluid_temp < 0) {
        # Cold soak: fluid viscosity up, system sluggish
        setprop('/hydraulics/control-authority-factor', 
                (getprop('/hydraulics/control-authority-factor') or 1.0) * 0.9);
    }
};

init_hydraulic_loads();
