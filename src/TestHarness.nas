# TestHarness.nas - simple smoke-test runner to exercise update loops

var run_smoke = func() {
    print('Running smoke test: invoking several subsystem updates with dt=0.1');
    var dt = 0.1;
    if (typeof('update_radar') != 'nil') update_radar(dt);
    if (typeof('update_radar_manager') != 'nil') update_radar_manager(dt);
    if (typeof('update_weapons') != 'nil') update_weapons(dt);
    if (typeof('update_weapons_ballistics') != 'nil') update_weapons_ballistics(dt);
    if (typeof('update_stores') != 'nil') update_stores(dt);
    if (typeof('update_fuel') != 'nil') update_fuel(dt);
    if (typeof('update_hydraulics_manager') != 'nil') update_hydraulics_manager(dt);
    if (typeof('update_electrical_manager') != 'nil') update_electrical_manager(dt);
    if (typeof('update_gears') != 'nil') update_gears(dt);
    if (typeof('update_env') != 'nil') update_env(dt);
    if (typeof('update_fcs_tuning') != 'nil') update_fcs_tuning(dt);
    print('Smoke test completed.');
};

setprop('/test/smoke-ready', 1);
