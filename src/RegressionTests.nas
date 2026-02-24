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



# Additional radar-specific tests for terrain occlusion and GL mode
var radar_test_terrain = func() {
    print('=== Radar Terrain/Occlusion Tests ===');

    # stub ground intersection to simulate a blocking hill directly ahead
    var orig_ground = get_cart_ground_intersection;
    get_cart_ground_intersection = func(pos, dir) {
        # return a point 1 km ahead of start (so contact would be behind terrain)
        return { x: pos.x + 1000.0, y: pos.y, z: 0.0 };
    };

    # setup minimal ownship state
    setprop('/position/altitude-ft', 1000);
    setprop('/position/ground-x-m', 0);
    setprop('/position/ground-y-m', 0);
    setprop('/orientation/heading-deg', 0);

    radar_mgr.mode = RM.VS;
    var contact = { dx: 2000.0, dy: 0.0, z: 0.0, rcs: 1.0 };
    var prob = calc_detection_prob(contact);
    rt_assert('Blocked contact yields zero detection probability', prob == 0.0);

    # test GL mode generates at least one terrain contact when intersection exists
    radar_mgr.mode = RM.GL;
    clear_contacts();
    radar_mgr.antenna_az = 0;
    radar_mgr.last_ping = -999;  # force immediate ping
    update_radar_manager(1.0);
    rt_assert('Ground-look mode creates ground return contact', radar_mgr.contacts.length > 0);

    # when flying low in a search mode, ground clutter should appear
    radar_mgr.mode = RM.RWS;
    clear_contacts();
    radar_mgr.last_ping = -999;
    update_radar_manager(1.0);
    rt_assert('Search mode ground clutter present', radar_mgr.contacts.length > 0);
    rt_assert('Clutter-count property reports >0', (getprop('/avionics/radar/clutter-count') or 0) > 0);

    # restore original function
    get_cart_ground_intersection = orig_ground;
};

var radar_test_weather = func() {
    print('=== Radar Weather Attenuation Tests ===');

    # simple contact far enough to detect in clear weather
    radar_mgr.mode = RM.VS;
    var contact = { dx: 50000.0, dy: 0.0, z: 5000.0, rcs: 10.0 };

    # clear conditions - attenuation should be 1.0
    setprop('/environment/rain-norm', 0);
    for (var i=0;i<3;i++) setprop(sprintf('/environment/clouds/layer[%d]/coverage',i), 0);
    var prob_clear = calc_detection_prob(contact);
    var att_clear = weather_attenuation();
    rt_assert('Weather attenuation unity in clear sky', att_clear == 1.0);

    # heavy rain should reduce probability significantly
    setprop('/environment/rain-norm', 1.0);
    var prob_rain = calc_detection_prob(contact);
    var att_rain = weather_attenuation();
    rt_assert('Rain attenuation factor < 1', att_rain < 1.0);
    rt_assert('Rain reduces detection probability', prob_rain < prob_clear);

    # rain clutter generation: put radar in VS and step ping
    radar_mgr.mode = RM.VS;
    clear_contacts();
    radar_mgr.last_ping = -999;
    update_radar_manager(1.0);
    rt_assert('Rain generates weather clutter contacts', radar_mgr.contacts.length > 0);
    var ccnt = getprop('/avionics/radar/clutter-count') or 0;
    rt_assert('Clutter-count property reports >0', ccnt > 0);

    # heavy cloud cover also reduces probability
    setprop('/environment/rain-norm', 0);
    for (var i=0;i<3;i++) setprop(sprintf('/environment/clouds/layer[%d]/coverage',i), 100);
    var prob_cloud = calc_detection_prob(contact);
    var att_cloud = weather_attenuation();
    rt_assert('Cloud attenuation factor < 1', att_cloud < 1.0);
    rt_assert('Cloud cover reduces detection probability', prob_cloud < prob_clear);
};

# call radar tests from NATOPS envelope
var natops_test_envelope = func() {
    print('=== NATOPS Envelope Tests ===');
    
    # Test 1: Basic property initialization
    rt_assert('Radar lock property exists', getprop('/avionics/radar/lock') != nil);
    rt_assert('Radar contacts property exists', getprop('/avionics/radar/contacts') != nil);
    rt_assert('Radar target range property exists', getprop('/avionics/radar/target-range-ft') != nil);
    rt_assert('Radar target bearing property exists', getprop('/avionics/radar/target-bearing-deg') != nil);
    rt_assert('Radar antenna azimuth property exists', getprop('/avionics/radar/antenna-az-deg') != nil);
    rt_assert('Radar weather attenuation property exists', getprop('/avionics/radar/weather-atten') != nil);
    rt_assert('Radar transmit flag property exists', getprop('/systems/radar/transmit') != nil);
    rt_assert('Stall warning horn property exists', getprop('/afcs/annunciator/stall-horn') != nil);
    rt_assert('Landing weight warning property exists', getprop('/afcs/annunciator/landing-weight-warning') != nil);
    
    # Test 2: System limits
    rt_assert('Max landing weight 36831 lb set', getprop('/fdm/jsbsim/inertia/max-landing-weight-lbs') == 36831);
    
    # Test 3: Autopilot properties
    rt_assert('Autopilot altitude hold exists', getprop('/afcs/ap-alt-hold') != nil);
    rt_assert('Autopilot attitude hold exists', getprop('/afcs/ap-att-hold') != nil);
    rt_assert('SAS roll engaged property exists', getprop('/afcs/sas-roll-engaged') != nil);

    # new terrain tests
    radar_test_terrain();
    # and weather attenuation tests
    radar_test_weather();
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

    # Test 3: TSFC lookup produces reasonable values
    var f = get_tsfc(0.0, 0);
    rt_assert_range('TSFC at zero mach sane', f, 0.5, 1.2);
    var f2 = get_tsfc(0.9, 0);
    rt_assert('TSFC increases in transonic', f2 > f);
    # change hydrogen content and verify factor applies
    setprop('/fuel/hydrogen-content-pct', 12.0);
    var f_lowH = get_tsfc(0.0, 0);
    setprop('/fuel/hydrogen-content-pct', 15.0);
    var f_highH = get_tsfc(0.0, 0);
    rt_assert('Higher hydrogen increases TSFC', f_highH > f_lowH);
};

# smoke model tests
var engines_test_smoke = func() {
    print('=== Engine Smoke Tests ===');
    # baseline smoke
    var s0 = get_smoke_number(10000, 0.5, 14.0, 1.0);
    rt_assert_range('Smoke number baseline positive', s0, 0, 10);
    # hydrogen effect
    var s_lowH = get_smoke_number(10000, 0.5, 12.0, 1.0);
    var s_highH = get_smoke_number(10000, 0.5, 15.0, 1.0);
    rt_assert('Lower hydrogen increases smoke', s_lowH > s_highH);
    # naphthalene effect
    var s_lowN = get_smoke_number(10000, 0.5, 14.0, 0.5);
    var s_highN = get_smoke_number(10000, 0.5, 14.0, 2.0);
    rt_assert('Higher naphthalene increases smoke', s_highN > s_lowN);
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
    engines_test_smoke();
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
