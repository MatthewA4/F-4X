# FDM.nas - supplemental flight dynamics utility functions and properties
# this module complements JSBSim F-4S-fdm.xml by providing Nasal-side access
# to mass properties, inertia, and toggles such as boundary-layer control.

# initialize basic properties (these may be overridden by other modules)
var init_fdm = func() {
    setprop('/fdm/mass-lbs', 55000);
    setprop('/fdm/cg-fraction-mac', 0.24);
    setprop('/fdm/inertia/Ixx', 22000);
    setprop('/fdm/inertia/Iyy', 150000);
    setprop('/fdm/inertia/Izz', 165000);
    setprop('/fdm/inertia/Ixy', 0);
    setprop('/fdm/inertia/Ixz', 1000);
    setprop('/fdm/inertia/Iyz', 0);

    # aerodynamic toggles
    setprop('/fdm/aero/blc-enabled', 0);
    setprop('/fdm/aero/mach-table', []);
};
init_fdm();

# update function called from main flight loop or JSBSim listener
var update_fdm = func(dt) {
    # read environment states and update derived properties
    var mach = getprop('/velocities/mach') or 0;
    # example: schedule gains or notify other systems
    # if BLC is commanded, ensure flaps >0 and below 250 KIAS
    if (getprop('/fdm/aero/blc-enabled') and getprop('/controls/flight/flaps') > 0) {
        setprop('/fcs/blc-active', 1);
    } else {
        setprop('/fcs/blc-active', 0);
    }
};

# host a simple container for aerodynamic tables from NATOPS
var load_aero_tables = func(filename) {
    # placeholder: user can load from Resources/aero_tables.dat
};

# provide helpers to expose aerodynamic coefficients to Nasal
var get_cl = func(alpha_deg) {
    # placeholder - actual lookup in JSBSim tables
    return getprop('/fdm/jsbsim/aero/coefficient/CL') or 0;
};

# register update listener
setlistener('/sim/flight-loop', func(dt) { update_fdm(dt); });
