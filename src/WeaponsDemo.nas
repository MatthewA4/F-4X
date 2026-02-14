# Weapons System Demo Script
# Demo and test script for F-4X Weapons System
# Usage: Run in FlightGear with F-4 aircraft loaded

# Test OrdnanceDatabase functionality
var test_ordnance_db = func() {
    print("=== ORDNANCE DATABASE TEST ===");
    
    # Test 1: Retrieve ordnance spec
    print("\nTest 1: Retrieve Mk-82 specification");
    var spec = get_ordnance_spec('MK-82');
    print(sprintf("  MK-82: %d lbs, category: %s, warhead: %d lbs", 
                  spec.weight_lbs, spec.category, spec.warhead_lbs));
    
    # Test 2: Retrieve loadout config
    print("\nTest 2: Retrieve CAP loadout config");
    var cfg = get_loadout_config('CAP');
    print(sprintf("  Config: %s (%s)", cfg.name, cfg.mission));
    print(sprintf("  Est. Weight: %d lbs, Combat Range: %d nm", 
                  cfg.est_weight_lbs, cfg.est_combat_range_nm));
    print(sprintf("  Stores count: %d", cfg.stores.size()));
    
    # Test 3: Hardpoint compatibility
    print("\nTest 3: Hardpoint compatibility checks");
    var tests = [
        [0, 'EXT-TANK-370', 'Fuel tank on centerline'],
        [1, 'MK-82', 'Bomb on wing inner'],
        [3, 'AIM-7E', 'Sparrow on fuselage recess'],
        [7, 'MK-20', 'Rockeye on wing outer'],
    ];
    
    foreach (var test; tests) {
        var hp = test[0];
        var ord = test[1];
        var desc = test[2];
        var compat = is_compatible(hp, ord);
        print(sprintf("  %s: %s", desc, compat ? "✓ Compatible" : "✗ Incompatible"));
    }
    
    print("\n=== DATABASE TEST COMPLETE ===\n");
};

# Test Weapons system functionality
var test_weapons_system = func() {
    print("=== WEAPONS SYSTEM TEST ===");
    
    # Test 1: Apply loadout
    print("\nTest 1: Apply CAP loadout");
    apply_loadout('CAP');
    print(sprintf("  Active loadout: %s", getprop('/weapons/loadout-name')));
    print(sprintf("  Ordnance count: %d", getprop('/weapons/ordnance-count')));
    
    # Test 2: Switch to CAS-HEAVY
    print("\nTest 2: Switch to CAS-HEAVY loadout");
    apply_loadout('CAS-HEAVY');
    print(sprintf("  Active loadout: %s", getprop('/weapons/loadout-name')));
    print(sprintf("  Ordnance count: %d", getprop('/weapons/ordnance-count')));
    
    # Test 3: Switch to SEAD
    print("\nTest 3: Switch to SEAD loadout");
    apply_loadout('SEAD');
    print(sprintf("  Active loadout: %s", getprop('/weapons/loadout-name')));
    print(sprintf("  Ordnance count: %d", getprop('/weapons/ordnance-count')));
    
    # Test 4: Verify missiles
    print("\nTest 4: Air-to-air missile status");
    print(sprintf("  Missiles loaded: %d", weapons_state.missiles.size()));
    print(sprintf("  Air-to-ground ordnance: %d", weapons_state.ordnance.size()));
    
    print("\n=== WEAPONS TEST COMPLETE ===\n");
};

# Test Stores system functionality
var test_stores_system = func() {
    print("=== STORES MANAGER TEST ===");
    
    # Test 1: CAP loadout stores/drag
    print("\nTest 1: CAP configuration stores analysis");
    apply_loadout('CAP');
    var total_w = getprop('/fcs/stores-total-weight-lb') or 0;
    var drag_d = getprop('/fcs/stores-drag-delta') or 0;
    var cg_shift = getprop('/fcs/cg-shift-in') or 0;
    print(sprintf("  Total stores: %.0f lbs", total_w));
    print(sprintf("  Drag delta: %.5f (ΔCD)", drag_d));
    print(sprintf("  CG shift: %.2f inches", cg_shift));
    
    # Test 2: CAS-HEAVY loadout stores/drag
    print("\nTest 2: CAS-HEAVY configuration stores analysis");
    apply_loadout('CAS-HEAVY');
    total_w = getprop('/fcs/stores-total-weight-lb') or 0;
    drag_d = getprop('/fcs/stores-drag-delta') or 0;
    cg_shift = getprop('/fcs/cg-shift-in') or 0;
    print(sprintf("  Total stores: %.0f lbs", total_w));
    print(sprintf("  Drag delta: %.5f (ΔCD)", drag_d));
    print(sprintf("  CG shift: %.2f inches", cg_shift));
    
    # Test 3: FERRY loadout (max fuel)
    print("\nTest 3: FERRY configuration (max fuel)");
    apply_loadout('FERRY');
    total_w = getprop('/fcs/stores-total-weight-lb') or 0;
    drag_d = getprop('/fcs/stores-drag-delta') or 0;
    print(sprintf("  Total fuel tanks: %.0f lbs", total_w));
    print(sprintf("  Drag delta: %.5f (ΔCD)", drag_d));
    
    # Test 4: Hardpoint detail (CAP)
    print("\nTest 4: CAP hardpoint breakdown");
    apply_loadout('CAP');
    for (var i = 0; i < 9; i += 1) {
        var w = getprop('/fcs/store['~i~']/weight-lb') or 0;
        if (w > 0) {
            print(sprintf("  Hardpoint %d: %.0f lbs", i, w));
        }
    }
    
    print("\n=== STORES TEST COMPLETE ===\n");
};

# Run all tests
var run_all_tests = func() {
    print("\n");
    print("╔════════════════════════════════════════════════════════════════╗");
    print("║           F-4X WEAPONS SYSTEM VERIFICATION TEST               ║");
    print("╠════════════════════════════════════════════════════════════════╣");
    print("║  Testing OrdnanceDatabase, Weapons, StoresManager modules     ║");
    print("╚════════════════════════════════════════════════════════════════╝");
    print("");
    
    test_ordnance_db();
    test_weapons_system();
    test_stores_system();
    
    print("\n");
    print("╔════════════════════════════════════════════════════════════════╗");
    print("║                    ALL TESTS COMPLETE                         ║");
    print("║               System ready for flight operations              ║");
    print("╚════════════════════════════════════════════════════════════════╝");
    print("");
};

# Run tests - execute when script is loaded
run_all_tests();

