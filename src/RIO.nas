# RIO (Rear Seat) controls for F-4 Phantom II
# Handles switches and controls in the rear cockpit

var RIO = {
    init: func {
        # Initialize properties if not set
        setprop("/controls/switches/rio/function-selector", getprop("/controls/switches/rio/function-selector") or 0);
        setprop("/controls/switches/rio/intercom-foot-switch", getprop("/controls/switches/rio/intercom-foot-switch") or 0);
        setprop("/controls/switches/rio/bdhi-mode", getprop("/controls/switches/rio/bdhi-mode") or 0);
        setprop("/controls/switches/rio/radar-scope-brightness", getprop("/controls/switches/rio/radar-scope-brightness") or 0.5);
        setprop("/controls/switches/rio/weapons-station-selector", getprop("/controls/switches/rio/weapons-station-selector") or 0);
        setprop("/controls/switches/rio/antenna-switch", getprop("/controls/switches/rio/antenna-switch") or 0);
        setprop("/controls/switches/rio/cooling-reset", getprop("/controls/switches/rio/cooling-reset") or 0);
        setprop("/controls/switches/rio/outflow-valve", getprop("/controls/switches/rio/outflow-valve") or 0.5);
        setprop("/controls/switches/rio/canopy-light", getprop("/controls/switches/rio/canopy-light") or 0);
        setprop("/controls/switches/rio/interior-lighting", getprop("/controls/switches/rio/interior-lighting") or 0.5);
        setprop("/controls/switches/rio/utility-light", getprop("/controls/switches/rio/utility-light") or 0);
        setprop("/controls/switches/rio/supply-lever", getprop("/controls/switches/rio/supply-lever") or 0);
        setprop("/controls/switches/rio/oxygen-gage", getprop("/controls/switches/rio/oxygen-gage") or 0.0);
        setprop("/controls/switches/rio/link-panel", getprop("/controls/switches/rio/link-panel") or 0);
        setprop("/controls/switches/rio/emergency-amplifiers", getprop("/controls/switches/rio/emergency-amplifiers") or 0);
        setprop("/controls/switches/rio/attitude-indicator", getprop("/controls/switches/rio/attitude-indicator") or 0);
        setprop("/controls/switches/rio/comm-nav-panel", getprop("/controls/switches/rio/comm-nav-panel") or 0);
        setprop("/controls/switches/rio/radio-mike", getprop("/controls/switches/rio/radio-mike") or 0);
        setprop("/controls/switches/rio/ados-indicator", getprop("/controls/switches/rio/ados-indicator") or 0);
        setprop("/controls/switches/rio/canopy-controls", getprop("/controls/switches/rio/canopy-controls") or 0);
        setprop("/controls/switches/rio/circuit-breakers", getprop("/controls/switches/rio/circuit-breakers") or 0);
        setprop("/controls/switches/rio/fuel-indicators", getprop("/controls/switches/rio/fuel-indicators") or 0.0);
        setprop("/controls/switches/rio/electrical-test-receptacle", getprop("/controls/switches/rio/electrical-test-receptacle") or 0);
        setprop("/controls/switches/rio/compass-system", getprop("/controls/switches/rio/compass-system") or 0);
        setprop("/controls/switches/rio/computer-control-panel", getprop("/controls/switches/rio/computer-control-panel") or 0);
        setprop("/controls/switches/rio/bit-switch", getprop("/controls/switches/rio/bit-switch") or 0);

        # Set up listeners or timers for dynamic behavior
        # For example, radar scope brightness affects display
        # Weapons selector affects selected station
        # etc.

        # Example: Link weapons selector to main weapons system
        setlistener("/controls/switches/rio/weapons-station-selector", func(n) {
            # Assume weapons system has /controls/armament/station-select
            setprop("/controls/armament/station-select", n.getValue());
        });

        # Radar brightness
        setlistener("/controls/switches/rio/radar-scope-brightness", func(n) {
            # Affect radar display brightness
            setprop("/instrumentation/radar/brightness", n.getValue());
        });

        # Other switches can be linked similarly
        # For now, basic setup
    },

    update: func(dt) {
        # Periodic updates if needed
        # For example, update oxygen gage based on system
        var oxygen = getprop("/systems/oxygen/pressure") or 0;
        setprop("/controls/switches/rio/oxygen-gage", oxygen);

        # Fuel indicators
        var fuel_total = 0;
        for (var i = 0; i < 9; i += 1) {
            fuel_total += getprop("/consumables/fuel/tank[" ~ i ~ "]/level-lbs") or 0;
        }
        setprop("/controls/switches/rio/fuel-indicators", fuel_total);
    }
};

# Initialize on startup
setlistener("/sim/signals/fdm-initialized", func {
    RIO.init();
});

# Update loop
var update_timer = maketimer(0.1, func {
    RIO.update(0.1);
});
update_timer.start();