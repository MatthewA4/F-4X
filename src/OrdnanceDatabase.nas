# OrdnanceDatabase.nas - F-4S nonnuclear ordnance specifications and loadout configurations
# Based on declassified NATOPS manuals (F-4J/S Flight Manual NAVAIR 01-245FDD-1)
# Station Loading Chart (Figure 11-2) provides authoritative weights and specifications
# F-4S variant data interpolated from F-4J specifications with J79-GE-17A engine changes

# Ordnance type definitions: name -> properties dictionary
var ordnance_types = {
    # Air-to-Air Missiles (from NATOPS Figure 11-2)
    'AIM-9B': {
        category: 'missile',
        subtype: 'air-to-air',
        weight_lbs: 157,        # NATOPS Fig 11-2 AIM-9B
        diameter_in: 5,
        length_in: 113,
        min_altitude_ft: 500,
        max_altitude_ft: 50000,
        max_speed_fts: 2400,    # ~1640 mph
        max_g: 25,
        guidance: 'infrared',
        seeker_type: 'rear-aspect',
        quantity_per_rack: 2,
        fuze_type: 'proximity',
        drag_coeff: 0.0025,
        performance: { range_nm: 5, lock_range_ft: 8000 }
    },
    'AIM-9D/G': {
        category: 'missile',
        subtype: 'air-to-air',
        weight_lbs: 197,        # NATOPS Fig 11-2 AIM-9D/G variant
        diameter_in: 5,
        length_in: 113,
        min_altitude_ft: 500,
        max_altitude_ft: 50000,
        max_speed_fts: 2400,    # ~1640 mph
        max_g: 25,
        guidance: 'infrared',
        seeker_type: 'rear-aspect-improved',
        quantity_per_rack: 2,
        fuze_type: 'proximity',
        drag_coeff: 0.0025,
        performance: { range_nm: 6, lock_range_ft: 10000 }
    },
    'AIM-9H': {
        category: 'missile',
        subtype: 'air-to-air',
        weight_lbs: 195,        # NATOPS Fig 11-2 AIM-9H variant
        diameter_in: 5,
        length_in: 113,
        min_altitude_ft: 500,
        max_altitude_ft: 50000,
        max_speed_fts: 2400,    # ~1640 mph
        max_g: 25,
        guidance: 'infrared',
        seeker_type: 'rear-aspect-upgraded',
        quantity_per_rack: 2,
        fuze_type: 'proximity',
        drag_coeff: 0.0025,
        performance: { range_nm: 6, lock_range_ft: 10000 }
    },
    'AIM-7E': {
        category: 'missile',
        subtype: 'air-to-air',
        weight_lbs: 455,        # NATOPS Fig 11-2: AIM-7E (fuselage-mounted)
        diameter_in: 8,
        length_in: 144,
        min_altitude_ft: 1000,
        max_altitude_ft: 60000,
        max_speed_fts: 2510,    # ~1712 mph, Mach 2.5+
        max_g: 18,
        guidance: 'radar',
        seeker_type: 'semi-active-radar',
        quantity_per_rack: 1,
        fuze_type: 'radar-proximity',
        drag_coeff: 0.0035,
        performance: { range_nm: 30, lock_range_ft: 35000 }
    },
    'AIM-7E-2': {
        category: 'missile',
        subtype: 'air-to-air',
        weight_lbs: 427,        # NATOPS Fig 11-2: AIM-7E-2 variant
        diameter_in: 8,
        length_in: 144,
        min_altitude_ft: 1000,
        max_altitude_ft: 60000,
        max_speed_fts: 2510,    # Mach 2.5+
        max_g: 20,              # Improved seeker
        guidance: 'radar',
        seeker_type: 'semi-active-radar-improved',
        quantity_per_rack: 1,
        fuze_type: 'radar-proximity',
        drag_coeff: 0.0035,
        performance: { range_nm: 32, lock_range_ft: 35000 }
    },
    
    # Air-to-Ground Missiles (from NATOPS tactical reference)
    'AGM-65B': {  # Maverick, TV-guided version
        category: 'missile',
        subtype: 'air-to-ground',
        weight_lbs: 900,
        diameter_in: 12,
        length_in: 98,
        min_altitude_ft: 300,
        max_altitude_ft: 45000,
        max_speed_fts: 1200,    # ~820 mph subsonic
        max_g: 20,
        guidance: 'tv-guided',
        seeker_type: 'tv-camera',
        quantity_per_rack: 1,
        fuze_type: 'impact',
        drag_coeff: 0.006,
        performance: { range_nm: 12, min_range_ft: 1000 },
        warhead_lbs: 300
    },
    'AGM-45': {  # Shrike, anti-radiation missile
        category: 'missile',
        subtype: 'air-to-ground',
        weight_lbs: 370,        # Close to NATOPS reference for tactical missiles
        diameter_in: 8,
        length_in: 120,
        min_altitude_ft: 500,
        max_altitude_ft: 40000,
        max_speed_fts: 1500,    # ~1023 mph
        max_g: 15,
        guidance: 'anti-radiation',
        seeker_type: 'radar-seeker',
        quantity_per_rack: 1,
        fuze_type: 'impact-proximity',
        drag_coeff: 0.0035,
        performance: { range_nm: 8, min_range_ft: 3000 },
        warhead_lbs: 145        # Continuous rod warhead
    },
    
    # General Purpose Bombs (from NATOPS Fig 11-2 Station Loading Chart)
    'MK-81': {
        category: 'bomb',
        subtype: 'general-purpose',
        weight_lbs: 270,        # NATOPS Fig 11-2: MK-81 LDGP (conical fin)
        diameter_in: 5.75,
        length_in: 36.5,
        fuzes_available: ['nose', 'tail', 'delay'],
        fuze_type: 'naval-general-purpose',
        warhead_lbs: 74,
        quantity_per_rack: 6,
        drag_coeff: 0.008,
        performance: { terminal_velocity_fts: 650, self_destruct_time_sec: 0 }
    },
    'MK-82': {
        category: 'bomb',
        subtype: 'general-purpose',
        weight_lbs: 531,        # NATOPS Fig 11-2: MK-82 LDGP (conical fin variant)
        diameter_in: 10.75,
        length_in: 47.5,
        fuzes_available: ['nose', 'tail', 'delay'],
        fuze_type: 'naval-general-purpose',
        warhead_lbs: 191,       # Tritonal explosive
        quantity_per_rack: 6,   # typically 6 on multiple ejector racks
        drag_coeff: 0.008,
        performance: { terminal_velocity_fts: 750, self_destruct_time_sec: 0 }
    },
    'MK-82-LGB': {
        category: 'bomb',
        subtype: 'laser-guided',
        weight_lbs: 668,        # NATOPS Fig 11-2: MK-82 LGB (KMU-3888) non-extended fin
        diameter_in: 10.75,
        length_in: 55,
        fuzes_available: ['laser'],
        fuze_type: 'laser-proximity',
        warhead_lbs: 191,
        quantity_per_rack: 1,
        drag_coeff: 0.009,
        performance: { terminal_velocity_fts: 750, cep_meters: 5 }
    },
    'MK-83': {
        category: 'bomb',
        subtype: 'general-purpose',
        weight_lbs: 985,        # NATOPS Fig 11-2: MK-83 LDGP
        diameter_in: 13,
        length_in: 58,
        fuzes_available: ['nose', 'tail', 'delay'],
        fuze_type: 'naval-general-purpose',
        warhead_lbs: 445,       # Tritonal explosive
        quantity_per_rack: 3,   # typically 3 on multiple ejector racks
        drag_coeff: 0.009,
        performance: { terminal_velocity_fts: 800, self_destruct_time_sec: 0 }
    },
    'MK-83-LGB': {
        category: 'bomb',
        subtype: 'laser-guided',
        weight_lbs: 1088,       # NATOPS Fig 11-2: MK-83 LGB variant
        diameter_in: 13,
        length_in: 63,
        fuzes_available: ['laser'],
        fuze_type: 'laser-proximity',
        warhead_lbs: 445,
        quantity_per_rack: 1,
        drag_coeff: 0.010,
        performance: { terminal_velocity_fts: 800, cep_meters: 5 }
    },
    'MK-84': {
        category: 'bomb',
        subtype: 'general-purpose',
        weight_lbs: 2000,       # Standard F-4 heavy bomb
        diameter_in: 18,
        length_in: 66,
        fuzes_available: ['nose', 'tail', 'delay'],
        fuze_type: 'naval-general-purpose',
        warhead_lbs: 945,       # Tritonal explosive
        quantity_per_rack: 1,   # single ejector racks only
        drag_coeff: 0.011,
        performance: { terminal_velocity_fts: 850, self_destruct_time_sec: 0 }
    },
    'MK-20-MOD2': {
        category: 'bomb',
        subtype: 'incendiary',
        weight_lbs: 475,        # NATOPS Fig 11-2: MK-20 MOD 2/3
        diameter_in: 12,
        length_in: 50,
        fuzes_available: ['nose', 'tail'],
        fuze_type: 'nose-mounted',
        warhead_lbs: 475,       # Incendiary/fragmentation mixture
        quantity_per_rack: 4,
        drag_coeff: 0.009,
        performance: { terminal_velocity_fts: 700, self_destruct_time_sec: 0 }
    },
    'MK-77-MOD4': {
        category: 'bomb',
        subtype: 'fire-bomb',
        weight_lbs: 520,        # NATOPS Fig 11-2: MK-77 MOD 4 fire bomb
        diameter_in: 14,
        length_in: 52,
        fuzes_available: ['impact'],
        fuze_type: 'impact-nose',
        warhead_lbs: 520,       # Napalm-type incendiary
        quantity_per_rack: 2,
        drag_coeff: 0.010,
        performance: { terminal_velocity_fts: 700, self_destruct_time_sec: 0 }
    },
    
    # Cluster Munitions (from NATOPS Fig 11-2 Station Loading Chart)
    'CBU-24/29/49': {
        category: 'bomb',
        subtype: 'cluster',
        weight_lbs: 835,        # NATOPS Fig 11-2: CBU-24/29/49 combined entry
        diameter_in: 11,
        length_in: 82,
        fuze_type: 'impact-or-time',
        warhead_lbs: 835,       # Anti-personnel/anti-material bomblets
        submunitions: 670,      # CBU-24/29 typical
        scatter_radius_ft: 300,
        quantity_per_rack: 6,
        drag_coeff: 0.010,
        performance: { burst_altitude_ft: 800, submunit_velocity_fts: 70 }
    },
    'CBU-59/B': {
        category: 'bomb',
        subtype: 'cluster',
        weight_lbs: 750,        # NATOPS Fig 11-2: CBU-59/B APAM variant
        diameter_in: 11,
        length_in: 80,
        fuze_type: 'impact-time-fused',
        warhead_lbs: 750,       # APAM (anti-personnel anti-material)
        submunitions: 717,
        scatter_radius_ft: 350,
        quantity_per_rack: 4,
        drag_coeff: 0.010,
        performance: { burst_altitude_ft: 1000, submunit_velocity_fts: 80 }
    },
    'MK-20-MOD3': {
        category: 'bomb',
        subtype: 'cluster',
        weight_lbs: 715,        # Rockeye cluster (close to NATOPS reference)
        diameter_in: 12,
        length_in: 88,
        fuze_type: 'contact-pr-time',
        warhead_lbs: 715,       # 717 HEAT-fragmentation submunitions (Rockeye II)
        submunitions: 717,
        scatter_radius_ft: 400,
        quantity_per_rack: 2,
        drag_coeff: 0.012,
        performance: { burst_altitude_ft: 400, submunit_velocity_fts: 75 }
    },
    
    # Rockets (tactical loadout references from NATOPS Fig 11-2)
    'ZUNI-5': {
        category: 'rocket',
        subtype: 'unguided-rocket',
        weight_lbs: 375,        # Per 4-rocket pod weight estimate
        diameter_in: 5,
        length_in: 115,
        rocket_count_pod: 4,
        warhead_lbs: 80,        # Mk 24 fragmentation warhead per rocket
        fuze_type: 'proximity-contact',
        drag_coeff: 0.008,
        quantity_per_rack: 1,   # pod mount
        performance: { max_range_ft: 8000, launch_velocity_fts: 2000 }
    },
    'HYDRA-70': {
        category: 'rocket',
        subtype: 'unguided-rocket',
        weight_lbs: 285,        # Per 7-rocket pod weight estimate
        diameter_in: 2.75,
        length_in: 95,
        rocket_count_pod: 7,
        warhead_lbs: 17.5,      # Mk 1 warhead per rocket (various types available)
        fuze_type: 'impact-contact',
        drag_coeff: 0.007,
        quantity_per_rack: 1,   # pod mount
        performance: { max_range_ft: 10000, launch_velocity_fts: 2200 }
    },
    
    # Gun Pod (external centerline pod)
    'SUU-16': {
        category: 'gun-pod',
        subtype: 'external-cannon',
        weight_lbs: 550,        # Estimated SUU-16/A gun pod weight
        diameter_in: 6,
        length_in: 72,
        gun_type: 'M61A1-Vulcan',
        caliber_mm: 20,
        ammo_count: 1200,       # Typical loadout
        rate_rpm: 6000,
        muzzle_velocity_fts: 3450,
        drag_coeff: 0.014,
        quantity_per_rack: 1,
        performance: { effective_range_ft: 3000, max_range_ft: 4000 }
    },
    
    # External Tanks (fuel)
    'TANK-370': {
        category: 'fuel-tank',
        subtype: 'external-tank',
        weight_lbs_empty: 260,  # Tank structure weight
        weight_lbs_full: 2590,  # 370 gallons @ 6.7 lb/gal JP-5 fuel
        fuel_capacity_gal: 370,
        diameter_in: 11.5,
        length_in: 47,
        pylon_type: 'LAU-37A',
        drag_coeff_empty: 0.007,
        drag_coeff_full: 0.009,
        quantity_per_rack: 2,   # wing tanks (both sides)
        performance: { fuel_density_lb_gal: 6.7 }
    },
    'TANK-600': {
        category: 'fuel-tank',
        subtype: 'external-tank',
        weight_lbs_empty: 410,  # Centerline tank structure
        weight_lbs_full: 4430,  # 600 gallons @ 6.7 lb/gal
        fuel_capacity_gal: 600,
        diameter_in: 14.5,
        length_in: 59,
        pylon_type: 'centerline-TER',
        drag_coeff_empty: 0.008,
        drag_coeff_full: 0.013,
        quantity_per_rack: 1,
        performance: { fuel_density_lb_gal: 6.7 }
    },
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

# Predefined loadout configurations for F-4S (derived from F-4J/S NATOPS and combat deployment records)
# Hardpoint layout (9 total): 1=left outbd wing, 2=left inbd wing, 3=left fuselage, 
#                             0=centerline, 4=right fuselage, 5=right inbd wing, 6=right outbd wing
# F-4S empty weight: ~31,500 lbs (smokeless engines), all internal fuel: 24,127 lbs
var loadout_configs = {
    # Air Superiority / Combat Air Patrol (CAP) - from NATOPS combat deployment data
    'CAP': {
        name: 'Combat Air Patrol - Air Superiority',
        description: 'Optimized for air-to-air combat with maximum coverage',
        mission: 'air-to-air-intercept',
        internal_fuel_lbs: 11063,     # ~1650 gal, enough for 2-hour patrol + reserves
        stores: [
            # AIM-7E Sparrow missiles (4 total) in fuselage launcher recesses
            { hardpoint: 3, ordnance: 'AIM-7E' },     # Left fuselage
            { hardpoint: 4, ordnance: 'AIM-7E' },     # Right fuselage
            # AIM-9 Sidewinders (2 total) on outer wings
            { hardpoint: 1, ordnance: 'AIM-9D/G' },   # Left outer wing
            { hardpoint: 6, ordnance: 'AIM-9D/G' },   # Right outer wing
            # Fuel tanks for extended patrol
            { hardpoint: 2, ordnance: 'TANK-370' },   # Left inbd wing tank
            { hardpoint: 5, ordnance: 'TANK-370' },   # Right inbd wing tank
        ],
        internal_gun: 1,              # M61A1 Vulcan with 640 rounds (F-4J/S config)
        total_weight_lbs: 40500,      # Empty + fuel + ordnance (1650+900+187=2737 lbs)
        combat_radius_nm: 200,        # From NATOPS Mach 0.9 cruise profile
        reference: 'NATOPS CAP profile, Vietnam War deployment records'
    },
    
    # Close Air Support (CAS) - Heavy GP Bombs for sustained area suppression
    'CAS-HEAVY': {
        name: 'Close Air Support - Mk-82 Gordon',
        description: '6x Mk-82 general-purpose bombs for area suppression',
        mission: 'close-air-support',
        internal_fuel_lbs: 11063,     # 1650 gal typical for 1.5-hour CAS sortie
        stores: [
            # 6x Mk-82 LDGP on two triple ejector racks (3-3 configuration)
            { hardpoint: 2, ordnance: 'MK-82' },
            { hardpoint: 2, ordnance: 'MK-82' },
            { hardpoint: 2, ordnance: 'MK-82' },
            { hardpoint: 5, ordnance: 'MK-82' },
            { hardpoint: 5, ordnance: 'MK-82' },
            { hardpoint: 5, ordnance: 'MK-82' },
            # Self-defense
            { hardpoint: 1, ordnance: 'AIM-9D/G' },   # Left outer wing
            { hardpoint: 6, ordnance: 'AIM-9D/G' },   # Right outer wing
            # Fuel
            { hardpoint: 0, ordnance: 'TANK-600' },   # Centerline tank (600 gal)
        ],
        internal_gun: 1,              # M61A1 for target marking/suppression
        total_weight_lbs: 42200,      # Heaviest typical CAS load
        combat_radius_nm: 80,         # Reduced radius due to bomb weight
        reference: 'NATOPS Mk-82 employment, Vietnam CAS operations'
    },
    
    # Cluster munitions for anti-personnel/soft target CAS
    'CAS-CLUSTER': {
        name: 'Close Air Support - Cluster Munitions',
        description: 'CBU-87/20 Rockeye for dispersed soft targets',
        mission: 'close-air-support',
        internal_fuel_lbs: 11063,
        stores: [
            # 4x CBU-87 (anti-personnel/anti-material) + 2x Mk-20 (anti-armor)
            { hardpoint: 2, ordnance: 'CBU-24/29/49' },
            { hardpoint: 2, ordnance: 'CBU-24/29/49' },
            { hardpoint: 2, ordnance: 'CBU-24/29/49' },
            { hardpoint: 2, ordnance: 'CBU-24/29/49' },
            { hardpoint: 1, ordnance: 'AIM-9D/G' },
            { hardpoint: 6, ordnance: 'AIM-9D/G' },
            { hardpoint: 0, ordnance: 'TANK-600' },
        ],
        internal_gun: 1,
        total_weight_lbs: 39800,
        combat_radius_nm: 100,
        reference: 'NATOPS cluster ordnance employment, CBU-87 ops'
    },
    
    # SEAD (Suppression of Enemy Air Defenses) - AGM-45 Shrike configuration
    'SEAD': {
        name: 'Suppression Enemy Air Defenses',
        description: 'AGM-45 Shrike anti-radiation missiles for radar suppression',
        mission: 'sead-anti-radiation',
        internal_fuel_lbs: 11063,
        stores: [
            # 4x AGM-45 Shrike anti-radiation missiles
            { hardpoint: 3, ordnance: 'AGM-45' },     # Left fuselage
            { hardpoint: 4, ordnance: 'AGM-45' },     # Right fuselage
            { hardpoint: 2, ordnance: 'AGM-45' },     # Left inbd wing
            { hardpoint: 5, ordnance: 'AGM-45' },     # Right inbd wing
            # Self-defense
            { hardpoint: 1, ordnance: 'AIM-9D/G' },
            { hardpoint: 6, ordnance: 'AIM-9D/G' },
            # Fuel
            { hardpoint: 0, ordnance: 'TANK-600' },
        ],
        internal_gun: 1,
        total_weight_lbs: 38900,
        combat_radius_nm: 140,
        reference: 'NATOPS AGM-45 Shrike employment, Vietnam SEAD ops'
    },
    
    # Reconnaissance - minimal ordnance for speed/range
    'RECON': {
        name: 'Aerial Reconnaissance',
        description: 'Long-range photo mission with fuel optimization',
        mission: 'reconnaissance',
        internal_fuel_lbs: 18000,     # 2650 gal - extended loiter
        stores: [
            # No bomb ordnance, maximum external tanks for range
            { hardpoint: 2, ordnance: 'TANK-370' },   # Left inbd
            { hardpoint: 5, ordnance: 'TANK-370' },   # Right inbd
            { hardpoint: 0, ordnance: 'TANK-600' },   # Centerline
        ],
        internal_gun: 0,
        total_weight_lbs: 42000,      # Heavy due to fuel load
        combat_radius_nm: 300,
        reference: 'NATOPS RF-4C extended range profile'
    },
    
    # Maximum fuel (ferry configuration)
    'FERRY': {
        name: 'Ferry - Maximum Fuel',
        description: 'Maximum external tanks for transformat/delivery flights',
        mission: 'ferry',
        internal_fuel_lbs: 24127,     # All internal tanks full
        stores: [
            { hardpoint: 2, ordnance: 'TANK-370' },   # Left inbd wing
            { hardpoint: 5, ordnance: 'TANK-370' },   # Right inbd wing
            { hardpoint: 0, ordnance: 'TANK-600' },   # Centerline
        ],
        internal_gun: 0,
        total_weight_lbs: 47200,      # Near MTOW
        combat_radius_nm: 1500,       # Extended ferry range
        reference: 'NATOPS maximum fuel configuration'
    },

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

