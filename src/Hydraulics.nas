# Hydraulics.nas - simple hydraulic pressure and failure simulation

var hyd_state = {
    pressure_psi: 3000.0,
    engine_pump_ok: 1,
    aux_pump_ok: 1,
    pressure_low: 0,
    rat_deployed: 0,
    rat_available: 1,
};

var init_hydraulics = func() {
    setprop('/hydraulics/pressure-psi', hyd_state.pressure_psi);
    setprop('/hydraulics/pressure-low', 0);
};

var update_hydraulics = func(dt) {
    # If engine pump fails or switch set, pressure decays
    var engine_ok = getprop('/systems/engine/hyd-pump-ok') or 1;
    var aux_ok = getprop('/systems/hyd/aux-pump-on') or 0;

    if (!engine_ok and !aux_ok) {
        hyd_state.pressure_psi = math.max(0, hyd_state.pressure_psi - 200.0 * dt);
    } elsif (!engine_ok and aux_ok) {
        hyd_state.pressure_psi = math.max(0, hyd_state.pressure_psi - 20.0 * dt);
    } else {
        # normal regen to nominal
        hyd_state.pressure_psi += (3000.0 - hyd_state.pressure_psi) * math.min(1.0, dt * 0.5);
    }

    hyd_state.pressure_low = hyd_state.pressure_psi < 1500.0 ? 1 : 0;
    setprop('/hydraulics/pressure-psi', hyd_state.pressure_psi);
    setprop('/hydraulics/pressure-low', hyd_state.pressure_low);

    # Automatic RAT deployment logic: if pressure critically low and RAT available
    if (hyd_state.pressure_psi < 800.0 and hyd_state.rat_available and !hyd_state.rat_deployed) {
        # deploy RAT to bleed air/hydraulic assist
        hyd_state.rat_deployed = 1;
        hyd_state.rat_available = 0;
        print('RAT deployed due to hydraulic pressure loss');
    }

    if (hyd_state.rat_deployed) {
        # RAT provides limited hydraulic recovery
        hyd_state.pressure_psi += 200.0 * dt; # slow restore
        if (hyd_state.pressure_psi > 1800.0) {
            # once pressure recovers, RAT can be stowed (simulated)
            hyd_state.rat_deployed = 0;
        }
    }

    setprop('/hydraulics/rat-deployed', hyd_state.rat_deployed ? 1 : 0);
    setprop('/hydraulics/rat-available', hyd_state.rat_available ? 1 : 0);
};

init_hydraulics();

var update_hydraulics_manager = func(dt) { update_hydraulics(dt); };
