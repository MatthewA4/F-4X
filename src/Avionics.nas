# Avionics Nasal module - HUD, ADI, HSI, Radar stubs

var avionics_state = {
    hud_enable: 1,
    radar_mode: 0,
    radar_lock: 0,
};

var init_avionics = func() {
    setprop("/avionics/hud/enable", avionics_state.hud_enable);
    setprop("/avionics/hud/airspeed-kt", 0);
    setprop("/avionics/hud/pitch-deg", 0);
    setprop("/avionics/radar/mode", avionics_state.radar_mode);
    setprop("/avionics/radar/lock", avionics_state.radar_lock);
    setprop("/avionics/radar/contacts", 0);
    setprop("/avionics/radar/mode-request", 0);
};

var update_avionics = func(dt) {
    # HUD: publish flight data for cockpit display
    var ias = getprop("/velocities/airspeed-kt", 0);
    var pitch = getprop("/orientation/pitch-deg", 0);
    setprop("/avionics/hud/airspeed-kt", ias);
    setprop("/avionics/hud/pitch-deg", pitch);
};

init_avionics();
