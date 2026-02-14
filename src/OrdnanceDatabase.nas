# OrdnanceDatabase.nas - F-4J/S nonnuclear ordnance specifications and loadout configurations
# Based on NATOPS F-4J/S Flight Manual ordnance data, Jane's Weapons Reference, and declassified specs

# Ordnance type definitions: name -> properties dictionary
var ordnance_types = {
    # Air-to-Air Missiles
    'AIM-9L': {
        category: 'missile',
        subtype: 'air-to-air',
        weight_lbs: 188,
        diameter_in: 5,
        length_in: 113,
        min_altitude_ft: 500,
        max_altitude_ft: 50000,
        max_speed_fts: 2400,    # ~1640 mph
        max_g: 25,
        guidance: 'infrared',
        seeker_type: 'all-aspect',
        quantity_per_rack: 1,
        fuze_type: 'proximity',
        drag_coeff: 0.0025,
        performance: { range_nm: 6.5, lock_range_ft: 12000 }
    },
    'AIM-7E': {
        category: 'missile',
        subtype: 'air-to-air',
        weight_lbs: 280,
        diameter_in: 8,
        length_in: 144,
        min_altitude_ft: 1000,
        max_altitude_ft: 60000,
        max_speed_fts: 2510,    # ~1712 mph, Mach 2.5
        max_g: 18,
        guidance: 'radar',
        seeker_type: 'semi-active',
        quantity_per_rack: 1,
        fuze_type: 'radar-proximity',
        drag_coeff: 0.0035,
        performance: { range_nm: 30, lock_range_ft: 35000 }
    },
    
    # Air-to-Ground Missiles
    'AGM-65B': {  # Maverick, TV-guided version
        category: 'missile',
        subtype: 'air-to-ground',
        weight_lbs: 900,
        diameter_in: 12,
        length_in: 98,
        min_altitude_ft: 300,
        max_altitude_ft: 45000,
        max_speed_fts: 1200,    # ~820 mph
        max_g: 20,
        guidance: 'tv-guided',
        seeker_type: 'tv-camera',
        quantity_per_rack: 1,
        fuze_type: 'impact',
        drag_coeff: 0.006,
        performance: { range_nm: 12, min_range_ft: 1000 },
        warhead_lbs: 300
    },
    'AGM-45': {  # Shrike, anti-radiation
        category: 'missile',
        subtype: 'air-to-ground',
        weight_lbs: 370,
        diameter_in: 8,
        length_in: 120,
        min_altitude_ft: 500,
        max_altitude_ft: 40000,
        max_speed_fts: 1500,    # ~1023 mph
        max_g: 15,
        guidance: 'anti-radiation',
        seeker_type: 'radar-seeker',
        quantity_per_rack: 1,
        fuze_type: 'impact',
        drag_coeff: 0.0035,
        performance: { range_nm: 8, min_range_ft: 5000 },
        warhead_lbs: 145
    },
    
    # General Purpose Bombs
    'MK-82': {
        category: 'bomb',
        subtype: 'general-purpose',
        weight_lbs: 500,
        diameter_in: 10.75,
        length_in: 47.5,
        fuzes_available: ['nose', 'tail', 'delay'],
        fuze_type: 'armed-nose',
        warhead_lbs: 191,      # Tritonal explosive
        quantity_per_rack: 6,  # typically 6 on single ejector racks
        drag_coeff: 0.008,
        performance: { terminal_velocity_fts: 750, self_destruct_time_sec: 0 }
    },
    'MK-83': {
        category: 'bomb',
        subtype: 'general-purpose',
        weight_lbs: 1000,
        diameter_in: 13,
        length_in: 58,
        fuzes_available: ['nose', 'tail', 'delay'],
        fuze_type: 'armed-nose',
        warhead_lbs: 445,
        quantity_per_rack: 3,
        drag_coeff: 0.012,
        performance: { terminal_velocity_fts: 850, self_destruct_time_sec: 0 }
    },
    'MK-84': {
        category: 'bomb',
        subtype: 'general-purpose',
        weight_lbs: 2000,
        diameter_in: 14.5,
        length_in: 70.5,
        fuzes_available: ['nose', 'tail', 'delay'],
        fuze_type: 'armed-nose',
        warhead_lbs: 945,
        quantity_per_rack: 1,  # single on ejector
        drag_coeff: 0.015,
        performance: { terminal_velocity_fts: 950, self_destruct_time_sec: 0 }
    },
    
    # Cluster Bombs
    'CBU-87': {
        category: 'bomb',
        subtype: 'cluster',
        weight_lbs: 945,
        diameter_in: 11,
        length_in: 82,
        fuze_type: 'time-fused',
        warhead_lbs: 945,      # 202 submunitions (BLU-97/B)
        submunitions: 202,
        scatter_radius_ft: 300,
        quantity_per_rack: 6,
        drag_coeff: 0.01,
        performance: { burst_altitude_ft: 1000, submunit_velocity_fts: 75 }
    },
    'MK-20': {  # Rockeye cluster bomb
        category: 'bomb',
        subtype: 'cluster',
        weight_lbs: 715,
        diameter_in: 12,
        length_in: 88,
        fuze_type: 'contact-or-time',
        warhead_lbs: 715,      # 717 HEAT-fragmentation submunitions
        submunitions: 717,
        scatter_radius_ft: 400,
        quantity_per_rack: 4,
        drag_coeff: 0.012,
        performance: { burst_altitude_ft: 350, submunit_velocity_fts: 60 }
    },
    
    # Gun Pod (external)
    'SUU-16': {
        category: 'gun-pod',
        subtype: 'external-cannon',
        weight_lbs: 550,
        diameter_in: 6,
        length_in: 60,
        gun_type: 'M61A1 Vulcan',
        caliber_mm: 20,
        ammo_count: 1200,
        rate_rpm: 6000,
        muzzle_velocity_fts: 3450,
        quantity_per_rack: 1,
        drag_coeff: 0.008,
        performance: { max_range_ft: 4000, effective_range_ft: 2000 }
    },
    
    # Rocket/Unguided Rocket Pods
    'ZUNI-5': {
        category: 'rocket-pod',
        subtype: 'unguided-rocket',
        weight_lbs: 375,
        diameter_in: 6.5,
        length_in: 52,
        rocket_type: '5-inch ZUNI',
        warhead_type: 'HEAT-frag',
        warhead_lbs: 80,
        rocket_velocity_fts: 2000,
        rockets_per_pod: 4,
        quantity_per_rack: 2,  # typically mounted 2 per wing
        drag_coeff: 0.008,
        performance: { range_ft: 8000, effective_range_ft: 5000 }
    },
    'HYDRA-70': {
        category: 'rocket-pod',
        subtype: 'unguided-rocket',
        weight_lbs: 285,
        diameter_in: 5,
        length_in: 48,
        rocket_type: '2.75-inch Hydra 70',
        warhead_type: 'HEDP',
        warhead_lbs: 17.5,
        rocket_velocity_fts: 2200,
        rockets_per_pod: 7,
        quantity_per_rack: 2,
        drag_coeff: 0.007,
        performance: { range_ft: 10000, effective_range_ft: 7000 }
    },
    
    # Fuel Tanks (external)
    'EXT-TANK-370': {
        category: 'fuel-tank',
        weight_lbs: 850,        # Weight when full (370 gal = 2590 lbs + 260 lb tank)
        volume_gal: 370,
        empty_weight_lbs: 260,
        drag_coeff: 0.006,
        quantity_per_rack: 1,
        performance: { position: 'wing-outer' }
    }
};

# Predefined loadout configurations for F-4J/S
var loadout_configs = {
    # Air Superiority / Combat Air Patrol (CAP)
    'CAP': {
        name: 'Combat Air Patrol',
        mission: 'air-superiority',
        internal_fuel: 1660,    # min for this config
        stores: [
            { hardpoint: 3, ordnance: 'AIM-7E' },   # 4x Sparrow (2 each in fuselage recesses 3,4)
            { hardpoint: 4, ordnance: 'AIM-7E' },
            { hardpoint: 4, ordnance: 'AIM-7E' },
            { hardpoint: 3, ordnance: 'AIM-7E' },
            { hardpoint: 1, ordnance: 'AIM-9L' },   # 2x Sidewinder on outer wing
            { hardpoint: 2, ordnance: 'AIM-9L' },
            { hardpoint: 0, ordnance: 'EXT-TANK-370' },  # centerline fuel tank
        ],
        internal_gun: 1,        # M61A1 with 640 rounds
        est_weight_lbs: 28500,
        est_combat_range_nm: 200
    },
    
    # Close Air Support (CAS) with bombs
    'CAS-HEAVY': {
        name: 'Close Air Support - Heavy Ordnance',
        mission: 'ground-attack',
        internal_fuel: 1660,
        stores: [
            { hardpoint: 1, ordnance: 'MK-82' },
            { hardpoint: 1, ordnance: 'MK-82' },
            { hardpoint: 1, ordnance: 'MK-82' },
            { hardpoint: 1, ordnance: 'MK-82' },
            { hardpoint: 1, ordnance: 'MK-82' },
            { hardpoint: 1, ordnance: 'MK-82' },    # 6x Mk82 on racks
            { hardpoint: 2, ordnance: 'AIM-9L' },   # 2x Sidewinder for self-defense
            { hardpoint: 2, ordnance: 'AIM-9L' },
            { hardpoint: 0, ordnance: 'EXT-TANK-370' },
        ],
        internal_gun: 1,
        est_weight_lbs: 32100,
        est_combat_range_nm: 120
    },
    
    # Cluster munitions (anti-personnel/soft target)
    'CAS-CLUSTER': {
        name: 'Close Air Support - Cluster Munitions',
        mission: 'ground-attack',
        internal_fuel: 1660,
        stores: [
            { hardpoint: 1, ordnance: 'CBU-87' },
            { hardpoint: 1, ordnance: 'CBU-87' },
            { hardpoint: 1, ordnance: 'CBU-87' },
            { hardpoint: 1, ordnance: 'CBU-87' },
            { hardpoint: 1, ordnance: 'MK-20' },
            { hardpoint: 1, ordnance: 'MK-20' },
            { hardpoint: 2, ordnance: 'AIM-9L' },
            { hardpoint: 0, ordnance: 'EXT-TANK-370' },
        ],
        internal_gun: 1,
        est_weight_lbs: 30000,
        est_combat_range_nm: 110
    },
    
    # Anti-radiation (SEAD)
    'SEAD': {
        name: 'Suppression of Enemy Air Defense',
        mission: 'air-to-ground',
        internal_fuel: 1660,
        stores: [
            { hardpoint: 1, ordnance: 'AGM-45' },
            { hardpoint: 1, ordnance: 'AGM-45' },
            { hardpoint: 6, ordnance: 'AGM-45' },
            { hardpoint: 7, ordnance: 'AGM-45' },
            { hardpoint: 2, ordnance: 'AIM-9L' },
            { hardpoint: 2, ordnance: 'AIM-9L' },
            { hardpoint: 0, ordnance: 'EXT-TANK-370' },
        ],
        internal_gun: 1,
        est_weight_lbs: 27500,
        est_combat_range_nm: 140
    },
    
    # Reconnaissance (no ordnance)
    'RECON': {
        name: 'Aerial Reconnaissance',
        mission: 'reconnaissance',
        internal_fuel: 1660,
        stores: [
            { hardpoint: 0, ordnance: 'EXT-TANK-370' },
        ],
        internal_gun: 0,
        est_weight_lbs: 20000,
        est_combat_range_nm: 300
    },
    
    # Max fuel for ferry
    'FERRY': {
        name: 'Ferry Configuration',
        mission: 'ferry',
        internal_fuel: 12961,   # max internal + 2x 370 gal external
        stores: [
            { hardpoint: 1, ordnance: 'EXT-TANK-370' },
            { hardpoint: 2, ordnance: 'EXT-TANK-370' },
        ],
        internal_gun: 0,
        est_weight_lbs: 24000,
        est_ferry_range_nm: 1500
    }
};

# Hardpoint compatibility matrix
# Row = hardpoint index, Col = ordnance type category allowed
var hardpoint_compatibility = [
    # 0: Centerline (fuselage) - single large store or fuel
    { 'fuel-tank': 1, 'missile': 0, 'bomb': 0, 'cluster': 0, 'gun-pod': 0, 'rocket-pod': 0 },
    # 1: Wing inner pylon left - multiple small stores
    { 'fuel-tank': 0, 'missile': 1, 'bomb': 1, 'cluster': 1, 'gun-pod': 0, 'rocket-pod': 1 },
    # 2: Wing inner pylon right
    { 'fuel-tank': 0, 'missile': 1, 'bomb': 1, 'cluster': 1, 'gun-pod': 0, 'rocket-pod': 1 },
    # 3: Fuselage semi-recess left (Sparrow)
    { 'fuel-tank': 0, 'missile': 1, 'bomb': 0, 'cluster': 0, 'gun-pod': 0, 'rocket-pod': 0 },
    # 4: Fuselage semi-recess right (Sparrow)
    { 'fuel-tank': 0, 'missile': 1, 'bomb': 0, 'cluster': 0, 'gun-pod': 0, 'rocket-pod': 0 },
    # 5: Wing middle left - gun pod or small missile
    { 'fuel-tank': 0, 'missile': 1, 'bomb': 0, 'cluster': 0, 'gun-pod': 1, 'rocket-pod': 0 },
    # 6: Wing middle right
    { 'fuel-tank': 0, 'missile': 1, 'bomb': 0, 'cluster': 0, 'gun-pod': 1, 'rocket-pod': 0 },
    # 7: Wing outer left - missiles and ordnance
    { 'fuel-tank': 0, 'missile': 1, 'bomb': 1, 'cluster': 1, 'gun-pod': 0, 'rocket-pod': 1 },
    # 8: Wing outer right
    { 'fuel-tank': 0, 'missile': 1, 'bomb': 1, 'cluster': 1, 'gun-pod': 0, 'rocket-pod': 1 }
];

# CG offsets per hardpoint (X/Y/Z in feet from aircraft CG, for balance calculations)
var hardpoint_cg_offsets = [
    [0.0,  0.0,   0.0],  # 0: Centerline (neutral)
    [-1.5, -15.0, 2.0],  # 1: Wing inner left
    [-1.5,  15.0, 2.0],  # 2: Wing inner right
    [0.5,   -2.0, 0.5],  # 3: Fuselage left recess
    [0.5,    2.0, 0.5],  # 4: Fuselage right recess
    [-0.8, -22.0, 3.0],  # 5: Wing middle left
    [-0.8,  22.0, 3.0],  # 6: Wing middle right
    [-1.2, -35.0, 4.0],  # 7: Wing outer left
    [-1.2,  35.0, 4.0]   # 8: Wing outer right
];

# Inventory tracking
var ordnance_inventory = {};

# Initialize inventory to zero
var init_inventory = func() {
    foreach (var ord_type; keys(ordnance_types)) {
        ordnance_inventory[ord_type] = 0;
    }
};

# Get ordnance spec
var get_ordnance_spec = func(ord_type) {
    if (contains(ordnance_types, ord_type)) {
        return ordnance_types[ord_type];
    }
    return nil;
};

# Get loadout config
var get_loadout_config = func(config_name) {
    if (contains(loadout_configs, config_name)) {
        return loadout_configs[config_name];
    }
    return nil;
};

# Check hardpoint compatibility
var is_compatible = func(hardpoint_index, ordnance_type) {
    var spec = get_ordnance_spec(ordnance_type);
    if (spec == nil) return 0;
    if (hardpoint_index < 0 or hardpoint_index >= 9) return 0;
    var compat = hardpoint_compatibility[hardpoint_index];
    if (contains(compat, spec.category)) {
        return compat[spec.category];
    }
    return 0;
};

# Initialize
init_inventory();

