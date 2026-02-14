# LandingGear.nas - landing gear dynamics and arrestor hook stub

var gear_state = {
    gear_down: 0,
    gear_extended_time: 0,
    arrestor_hook: 0,
};

var init_gear = func() {
    setprop('/gear/gear-pos-norm', 0);
    setprop('/gear/arrestor-hook-pos', 0);
    setprop('/afcs/annunciator/hook-engaged', 0);
};

var update_landing_gear = func(dt) {
    var cmd = getprop('/controls/gear/lever-down') or 0;
    if (cmd) {
        gear_state.gear_down = 1;
        gear_state.gear_extended_time += dt;
        setprop('/gear/gear-pos-norm', 1);
    } else {
        gear_state.gear_down = 0;
        gear_state.gear_extended_time = 0;
        setprop('/gear/gear-pos-norm', 0);
    }

    # Arrestor hook handle control
    var hook_cmd = getprop('/controls/gear/arrestor-hook') or 0;
    gear_state.arrestor_hook = hook_cmd;
    setprop('/gear/arrestor-hook-pos', hook_cmd);

    # Engagement detection: if hook down and over runway cable property
    var cable = getprop('/runway/arresting-cable-present') or 0;
    if (gear_state.arrestor_hook and cable and gear_state.gear_down and getprop('/position/altitude-agl-ft') < 20) {
        setprop('/afcs/annunciator/hook-engaged', 1);
        print('Arresting hook engaged with cable');
    } else {
        setprop('/afcs/annunciator/hook-engaged', 0);
    }
};

init_gear();

var update_gears = func(dt) { update_landing_gear(dt); };
