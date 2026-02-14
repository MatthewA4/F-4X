# CockpitBindings.nas - default control property bindings (suggested defaults)

var init_bindings = func() {
    # These do not rebind hardware but provide properties that cockpit can map to
    setprop('/controls/gear/lever-down', 0);
    setprop('/controls/gear/arrestor-hook', 0);
    setprop('/controls/refueling/probe-extended', 0);
    setprop('/controls/fuel/jettison', 0);
    setprop('/controls/fuel/jettison-tank', 0);
    setprop('/controls/weapons/jettison', 0);
    setprop('/weapons/gun-cmd', 0);
    setprop('/weapons/bomb-release', 0);
};

init_bindings();

var update_bindings = func(dt) {
    # Placeholder: cockpit input mapping should set above properties via bindings.xml
};
