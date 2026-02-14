# TestHarness.nas - regression test harness

var test_results = [];
var test_count = 0;
var test_passed = 0;

var assert_prop_exists = func(prop) {
    test_count += 1;
    var v = getprop(prop);
    if (v != nil) {
        test_passed += 1;
        return 1;
    } else {
        print(sprintf('FAIL: Property %s not found', prop));
        return 0;
    }
};

var run_smoke = func() {
    print('=== F-4X Smoke Test ===');
    var dt = 0.1;
    
    # Invoke all subsystem updates
    if (typeof('update_radar') != 'nil') update_radar(dt);
    if (typeof('update_weapons') != 'nil') update_weapons(dt);
    if (typeof('update_stores') != 'nil') update_stores(dt);
    if (typeof('update_fuel') != 'nil') update_fuel(dt);
    if (typeof('update_hydraulics_manager') != 'nil') update_hydraulics_manager(dt);
    if (typeof('update_electrical_manager') != 'nil') update_electrical_manager(dt);
    if (typeof('update_gears') != 'nil') update_gears(dt);
    if (typeof('update_env') != 'nil') update_env(dt);
    if (typeof('update_fcs_tuning') != 'nil') update_fcs_tuning(dt);
    
    # Validate key properties exist
    assert_prop_exists('/avionics/radar/lock');
    assert_prop_exists('/avionics/radar/target-range-ft');
    assert_prop_exists('/weapons/missile-ready-count');
    assert_prop_exists('/fcs/stores-total-weight-lb');
    assert_prop_exists('/fcs/fuel-total-lb');
    assert_prop_exists('/hydraulics/pressure-psi');
    assert_prop_exists('/electrical/battery-voltage');
    assert_prop_exists('/gear/gear-pos-norm');
    assert_prop_exists('/cabin/canopy-open');
    assert_prop_exists('/fcs/aileron-gain');
    
    print(sprintf('=== TEST RESULTS: %d/%d passed ===' , test_passed, test_count));
    return (test_passed == test_count);
};

setprop('/test/smoke-ready', 1);
