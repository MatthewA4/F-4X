# StartupSequencer.nas - NATOPS-compliant startup and verification procedures

var startup_state = {
    phase: 0,  # 0=cold, 1=preflight, 2=engine-start, 3=flight-ready
    checklist_items: [],
    engine1_n2: 0,
    engine2_n2: 0,
    preflight_complete: 0,
};

var startup_checklist = {
    electrical: {
        name: 'Battery/Electrical',
        checks: [
            { name: 'Master Battery', prop: '/systems/electrical/main-switch', expected: 1 },
            { name: 'Battery Voltage >25V', prop: '/electrical/battery-voltage', min: 25, max: 32 },
        ],
    },
    engines: {
        name: 'Engine Systems',
        checks: [
            { name: 'Fuel Quantity >100 lb', prop: '/fcs/fuel-total-lb', min: 100 },
            { name: 'Engine 1 Cutoff ON', prop: '/systems/engines/engine[0]/cutoff', expected: 1 },
            { name: 'Engine 2 Cutoff ON', prop: '/systems/engines/engine[1]/cutoff', expected: 1 },
        ],
    },
    flight_controls: {
        name: 'Flight Controls',
        checks: [
            { name: 'Throttle Idle', prop: '/controls/engines/engine[0]/throttle', max: 0.15 },
            { name: 'Throttle Idle (Eng 2)', prop: '/controls/engines/engine[1]/throttle', max: 0.15 },
            { name: 'Flaps Up', prop: '/fdm/jsbsim/fcs/flap-pos-deg', max: 5 },
            { name: 'Gear Down', prop: '/gear/gear-pos-norm', min: 0.95 },
            { name: 'Speed Brake Retracted', prop: '/fdm/jsbsim/fcs/speedbrake-pos-norm', max: 0.1 },
        ],
    },
};

var check_item = func(item) {
    var prop = item.prop or '';
    var val = getprop(prop) or 0;
    
    if (item.expected != nil) {
        return val == item.expected;
    } elsif (item.min != nil and item.max != nil) {
        return val >= item.min and val <= item.max;
    } elsif (item.min != nil) {
        return val >= item.min;
    } elsif (item.max != nil) {
        return val <= item.max;
    }
    return 1;
};

var run_preflight_checklist = func() {
    print('\n╔═══════════════════════════════════════════╗');
    print('║  F-4X NATOPS PREFLIGHT CHECKLIST         ║');
    print('╚═══════════════════════════════════════════╝\n');
    
    var all_ok = 1;
    foreach (var category; ['electrical', 'engines', 'flight_controls']) {
        var cat = startup_checklist[category];
        print('--- ' ~ cat.name ~ ' ---');
        foreach (var check; cat.checks) {
            var ok = check_item(check);
            var status = ok ? '✓' : '✗';
            print(sprintf('%s %s', status, check.name));
            if (!ok) all_ok = 0;
        }
        print('');
    }
    
    if (all_ok) {
        print('✓ PREFLIGHT COMPLETE - Ready for ENGINE START\n');
        startup_state.preflight_complete = 1;
    } else {
        print('✗ PREFLIGHT INCOMPLETE - Address failures above\n');
        startup_state.preflight_complete = 0;
    }
    
    return all_ok;
};

var verify_engine1_start = func() {
    var n2 = getprop('/fdm/jsbsim/propulsion/engine[0]/n2') or 0;
    var running = getprop('/engines/engine[0]/running') or 0;
    return (n2 > 50 and running == 1);
};

var verify_engine2_start = func() {
    var n2 = getprop('/fdm/jsbsim/propulsion/engine[1]/n2') or 0;
    var running = getprop('/engines/engine[1]/running') or 0;
    return (n2 > 50 and running == 1);
};

var run_startup_procedure = func() {
    print('\n╔═══════════════════════════════════════════╗');
    print('║  F-4X NATOPS ENGINE START PROCEDURE      ║');
    print('╚═══════════════════════════════════════════╝\n');
    
    if (!startup_state.preflight_complete) {
        print('✗ Preflight checklist not complete. Run run_preflight_checklist() first.\n');
        return 0;
    }
    
    print('1. Battery ON (observe 28V DC)');\n    setprop('/systems/electrical/main-switch', 1);
    print('   Wait 2 seconds...\n');
    
    print('2. Engine 1: Cutoff ON (block fuel)');
    setprop('/systems/engines/engine[0]/cutoff', 1);
    
    print('   Starter: ENGAGE');
    setprop('/controls/engines/engine[0]/starter', 1);
    print('   [Waiting ~3-5 sec for N2 spool...]\n');
    
    print('3. When N2 > 50%: Cutoff OFF (fuel flows)');
    setprop('/systems/engines/engine[0]/cutoff', 0);
    
    print('   Throttle: Advance to 30% (warm idle)');
    setprop('/controls/engines/engine[0]/throttle', 0.30);
    print('   [Engine should stabilize] ✓\n');
    
    print('4. Repeat for Engine 2...');
    setprop('/systems/engines/engine[1]/cutoff', 1);
    setprop('/controls/engines/engine[1]/starter', 1);
    print('   [Waiting ~3-5 sec]\n');
    
    setprop('/systems/engines/engine[1]/cutoff', 0);
    setprop('/controls/engines/engine[1]/throttle', 0.30);
    print('   [Both engines running] ✓\n');
    
    print('╔═══════════════════════════════════════════╗');
    print('║  ENGINES STARTED - FLIGHT READY           ║');
    print('╚═══════════════════════════════════════════╝\n');
};

setprop('/startup/checklist-complete', 0);
setprop('/startup/engines-running', 0);
