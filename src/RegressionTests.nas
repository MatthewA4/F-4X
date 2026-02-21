# RegressionTests.nas - NATOPS compliance and system validation tests

var rt_results = {
    total: 0,
    passed: 0,
    failures: [],
};

var rt_assert = func(test_name, condition) {
    rt_results.total += 1;
    if (condition) {
        rt_results.passed += 1;
        print(sprintf('✓ %s', test_name));
    } else {
        rt_results.passed = rt_results.passed;
        print(sprintf('✗ %s', test_name));
        append(rt_results.failures, test_name);
    }
};

var rt_assert_range = func(test_name, value, min_val, max_val) {
    rt_assert(test_name ~ sprintf(' (%.2f in [%.2f, %.2f])', value, min_val, max_val), 
              value >= min_val and value <= max_val);
};

var natops_test_envelope = func() {
    print('=== NATOPS Envelope Tests ===');
    
    # Test 1: Basic property initialization
    rt_assert('Radar lock property exists', getprop('/avionics/radar/lock') != nil);
    rt_assert('Radar contacts property exists', getprop('/avionics/radar/contacts') != nil);
    rt_assert('Radar target range property exists', getprop('/avionics/radar/target-range-ft') != nil);
    rt_assert('Radar target bearing property exists', getprop('/avionics/radar/target-bearing-deg') != nil);
    rt_assert('Radar antenna azimuth property exists', getprop('/avionics/radar/antenna-az-deg') != nil);
    rt_assert('Radar transmit flag property exists', getprop('/systems/radar/transmit') != nil);
    rt_assert('Stall warning horn property exists', getprop('/afcs/annunciator/stall-horn') != nil);
    rt_assert('Landing weight warning property exists', getprop('/afcs/annunciator/landing-weight-warning') != nil);
    
    # Test 2: System limits
    rt_assert('Max landing weight 36831 lb set', getprop('/fdm/jsbsim/inertia/max-landing-weight-lbs') == 36831);
    
    # Test 3: Autopilot properties
    rt_assert('Autopilot altitude hold exists', getprop('/afcs/ap-alt-hold') != nil);
    rt_assert('Autopilot attitude hold exists', getprop('/afcs/ap-att-hold') != nil);
    rt_assert('SAS roll engaged property exists', getprop('/afcs/sas-roll-engaged') != nil);
};

var weapons_test_ballistics = func() {
    print('=== Weapons Ballistics Tests ===');
    
    # Test 1: Missile properties
    rt_assert('Missile ready count property exists', getprop('/weapons/missile-ready-count') != nil);
    rt_assert('Next ready missile ID property exists', getprop('/weapons/next-ready-missile-id') != nil);
    rt_assert('Gun ammo property exists', getprop('/weapons/gun-ammo') != nil);
    
    # Test 2: Stores drag impact
    var stores_drag = getprop('/fcs/stores-drag-delta') or 0;
    rt_assert('Stores drag delta within bounds', stores_drag >= 0 and stores_drag <= 0.05);
};

var systems_test_hydraulics = func() {
    print('=== Systems: Hydraulics Tests ===');
    
    # Test 1: Hydraulic pressures nominal
    var hyd_left = getprop('/hydraulics/pressure/left-psi') or 0;
    var hyd_right = getprop('/hydraulics/pressure/right-psi') or 0;
    rt_assert_range('Hydraulic left pressure nominal', hyd_left, 2500, 3500);
    rt_assert_range('Hydraulic right pressure nominal', hyd_right, 2500, 3500);

    # Test 2: Pumps status properties exist
    rt_assert('Left pump status property exists', getprop('/hydraulics/pump/left/status') != nil);
    rt_assert('Right pump status property exists', getprop('/hydraulics/pump/right/status') != nil);
    rt_assert('Aux pump status property exists', getprop('/hydraulics/pump/aux/status') != nil);

    # Test 3: Actuator position properties
    rt_assert('Elevator actuator position exists', getprop('/hydraulics/actuator/elevator/position') != nil);
    rt_assert('Aileron actuator position exists', getprop('/hydraulics/actuator/aileron/position') != nil);
    rt_assert('Rudder actuator position exists', getprop('/hydraulics/actuator/rudder/position') != nil);

    # Test 4: RAT available before emergency
    rt_assert('RAT available property exists', getprop('/hydraulics/rat-available') != nil);
    rt_assert('RAT deployed property exists', getprop('/hydraulics/rat-deployed') != nil);
};

var systems_test_electrical = func() {
    print('=== Systems: Electrical Tests ===');
    
    # Test 1: Battery voltage normal
    var batt_volt = getprop('/electrical/battery-voltage') or 0;
    rt_assert_range('Battery voltage nominal', batt_volt, 25, 32);
    
    # Test 2: Electrical fault flag exists
    rt_assert('Electrical fault annunciator exists', getprop('/afcs/annunciator/electrical-fault') != nil);
};

var systems_test_fuel = func() {
    print('=== Systems: Fuel Tests ===');
    
    # Test 1: Fuel tank properties
    rt_assert('Total fuel property exists', getprop('/fcs/fuel-total-lb') != nil);
    
    # Test 2: Jettison tank index valid range (0-3)
    var jettison_tank = getprop('/controls/fuel/jettison-tank') or 0;
    rt_assert_range('Jettison tank index valid', jettison_tank, 0, 3);
};

var systems_test_gear = func() {
    print('=== Systems: Landing Gear Tests ===');
    
    # Test 1: Gear position range
    var gear_pos = getprop('/gear/gear-pos-norm') or 0;
    rt_assert_range('Gear position normalized', gear_pos, 0, 1);
    
    # Test 2: Hook position
    rt_assert('Arrestor hook position exists', getprop('/gear/arrestor-hook-pos') != nil);
    rt_assert('Hook engaged annunciator exists', getprop('/afcs/annunciator/hook-engaged') != nil);
};

var systems_test_environment = func() {
    print('=== Systems: Environment Tests ===');
    
    # Test 1: Pressurization
    rt_assert('Canopy open property exists', getprop('/cabin/canopy-open') != nil);
    rt_assert('Pressurization fault annunciator exists', getprop('/afcs/annunciator/pressurization-fault') != nil);
};

var systems_test_fcs = func() {
    print('=== Systems: FCS Tests ===');
    
    # Test 1: Gain scheduling
    var aileron_gain = getprop('/fcs/aileron-gain') or 0;
    rt_assert_range('Aileron gain in bounds', aileron_gain, 0.3, 1.1);
    
    var elevator_gain = getprop('/fcs/elevator-gain') or 0;
    rt_assert_range('Elevator gain in bounds', elevator_gain, 0.4, 1.1);

    # Test 2: FDM properties exist
    rt_assert('FDM mass property exists', getprop('/fdm/mass-lbs') != nil);
    rt_assert('FDM cg property exists', getprop('/fdm/cg-fraction-mac') != nil);
    rt_assert('BLC enable flag exists', getprop('/fdm/aero/blc-enabled') != nil);
    
    # Test 3: Autopilot command generation
    # simulate a small attitude error and run update_att_hold
    setprop('/orientation/roll-deg', 5.0);
    setprop('/orientation/pitch-deg', 2.0);
    setprop('/afcs/ap-att-hold', 1);
    update_att_hold(0.1);
    var roll_cmd = getprop('/afcs/att/roll-cmd') or 0;
    var pitch_cmd = getprop('/afcs/att/pitch-cmd') or 0;
    rt_assert('Autopilot roll command produced', abs(roll_cmd) > 0);
    rt_assert('Autopilot pitch command produced', abs(pitch_cmd) > 0);
};

var run_all_regression_tests = func() {
    print('\n╔════════════════════════════════════════════╗');
    print('║  F-4X NATOPS COMPLIANCE TEST SUITE        ║');
    print('║  Date: ' ~ getprop('/sim/time/real/year') ~ '  Flight Test Beta');
    print('╚════════════════════════════════════════════╝\n');
    
    natops_test_envelope();
    weapons_test_ballistics();
    systems_test_hydraulics();
    systems_test_electrical();
    systems_test_fuel();
    systems_test_gear();
    systems_test_environment();
    systems_test_fcs();
    
    print('\n╔════════════════════════════════════════════╗');
    print('║  REGRESSION TEST RESULTS                  ║');
    print(sprintf('║  Passed: %d / %d', rt_results.passed, rt_results.total));
    print('╚════════════════════════════════════════════╝\n');
    
    if (rt_results.passed < rt_results.total) {
        print('Failed tests:');
        foreach (var f; rt_results.failures) {
            print('  - ' ~ f);
        }
    }
    
    return (rt_results.passed == rt_results.total);
};

setprop('/test/regression-ready', 1);
