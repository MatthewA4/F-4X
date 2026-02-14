# CockpitBindings.nas - default control property bindings (suggested defaults)

var init_bindings = func() {
    # Establish all control properties that cockpit/input bindings should target
    setprop('/controls/gear/lever-down', 0);
    setprop('/controls/gear/arrestor-hook', 0);
    setprop('/controls/refueling/probe-extended', 0);
    setprop('/controls/fuel/jettison', 0);
    setprop('/controls/fuel/jettison-tank', 0);
    setprop('/controls/weapons/jettison', 0);
    setprop('/weapons/gun-cmd', 0);
    setprop('/weapons/bomb-release', 0);
    setprop('/controls/canopy/open', 0);
    setprop('/systems/electrical/main-switch', 1);
    setprop('/systems/electrical/aux-switch', 0);
    setprop('/systems/hyd/aux-pump-on', 0);
    setprop('/controls/fuel/transfer-auto', 1);
    setprop('/afcs/sas-roll-engaged', 0);
    setprop('/afcs/sas-pitch-engaged', 0);
    setprop('/afcs/sas-yaw-engaged', 0);
    setprop('/afcs/ap-att-hold', 0);
    setprop('/afcs/ap-alt-hold', 0);
};

init_bindings();

var update_bindings = func(dt) {
    # Cockpit input mapping should set above properties via bindings or panel logic
    # This stub ensures all properties exist for pilot input
};
