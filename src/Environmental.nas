# Environmental.nas - canopy, pressurization and ECS stub

var env = {
    canopy_open: 0,
    cabin_press_psi: 14.7,
    cabin_max_alt_ft: 15000,
};

var init_environment = func() {
    setprop('/cabin/cabin-press-psi', env.cabin_press_psi);
    setprop('/cabin/cabin-altitude-ft', 0);
    setprop('/cabin/canopy-open', env.canopy_open);
};

var update_environment = func(dt) {
    var cmd_canopy = getprop('/controls/canopy/open') or 0;
    env.canopy_open = cmd_canopy;
    setprop('/cabin/canopy-open', env.canopy_open);

    # Simple pressurization: maintain ~8.5 psi differential up to max altitude
    var cabin_alt = (getprop('/position/altitude-ft') or 0) - ((env.canopy_open) ? 0 : 1000);
    setprop('/cabin/cabin-altitude-ft', cabin_alt);

    if (!env.canopy_open) {
        if (cabin_alt > env.cabin_max_alt_ft) {
            setprop('/afcs/annunciator/pressurization-fault', 1);
        } else {
            setprop('/afcs/annunciator/pressurization-fault', 0);
        }
    } else {
        setprop('/afcs/annunciator/pressurization-fault', 1);
    }
};

init_environment();

var update_env = func(dt) { update_environment(dt); };
