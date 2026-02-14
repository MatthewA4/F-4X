# FCSTuning.nas - gain scheduling and control feel adjustments

var update_fcs_tuning = func(dt) {
    var mach = getprop('/velocities/mach') or 0;
    # Aileron/aileron feel: reduce effectiveness near transonic
    var aileron_gain = 1.0;
    var elevator_gain = 1.0;
    if (mach > 0.7) {
        aileron_gain = 1.0 - (mach - 0.7) * 1.0; # linear down to ~0.0 at M1.7 (clamped)
        elevator_gain = 1.0 - (mach - 0.85) * 0.8;
    }
    aileron_gain = math.max(0.4, aileron_gain);
    elevator_gain = math.max(0.5, elevator_gain);

    setprop('/fcs/aileron-gain', aileron_gain);
    setprop('/fcs/elevator-gain', elevator_gain);
};
