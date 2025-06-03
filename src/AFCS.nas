# F-4J Automatic Flight Control System (AFCS) - NATOPS Section 1.17

var TRUE = 1;
var FALSE = 0;

# Properties for AFCS state
var props = {
    sas_roll: "/afcs/sas-roll-engaged",
    sas_pitch: "/afcs/sas-pitch-engaged",
    sas_yaw: "/afcs/sas-yaw-engaged",
    ap_att: "/afcs/ap-att-hold",
    ap_alt: "/afcs/ap-alt-hold",
    fail: "/afcs/fail",
    ann_ap_att: "/afcs/annunciator/ap-att",
    ann_ap_alt: "/afcs/annunciator/ap-alt",
    ann_sas: "/afcs/annunciator/sas",
    ann_fail: "/afcs/annunciator/fail"
};

# Read cockpit switches (to be mapped in cockpit/controls)
var get_switch = func(name, def) {
    return getprop("/controls/afcs/" ~ name, def);
}

# PID controller utility
var make_pid = func(kp, ki, kd) {
    return {
        kp: kp, ki: ki, kd: kd,
        prev_err: 0, integ: 0,
        update: func(self, setpoint, value, dt) {
            var err = setpoint - value;
            self.integ += err * dt;
            var deriv = (err - self.prev_err) / dt;
            self.prev_err = err;
            return self.kp * err + self.ki * self.integ + self.kd * deriv;
        },
        reset: func(self) {
            self.prev_err = 0;
            self.integ = 0;
        }
    };
};

# PID controllers for autopilot
var pid_att_roll = make_pid(0.8, 0.01, 0.15);   # Tune as needed
var pid_att_pitch = make_pid(1.2, 0.02, 0.18);
var pid_alt = make_pid(0.5, 0.005, 0.1);

# State for attitude/altitude hold
var att_hold = { roll: 0, pitch: 0, active: 0 };
var alt_hold = { alt: 0, active: 0 };

# SAS engagement logic (auto-disengage on stick force, failure, or switch off)
var update_sas = func {
    var fail = getprop(props.fail, 0);

    # Roll SAS
    var roll_switch = get_switch("sas-roll", 1);
    var roll_force = abs(getprop("/controls/flight/aileron", 0)) > 0.1;
    setprop(props.sas_roll, roll_switch and !fail and !roll_force);

    # Pitch SAS
    var pitch_switch = get_switch("sas-pitch", 1);
    var pitch_force = abs(getprop("/controls/flight/elevator", 0)) > 0.1;
    setprop(props.sas_pitch, pitch_switch and !fail and !pitch_force);

    # Yaw SAS
    var yaw_switch = get_switch("sas-yaw", 1);
    var yaw_force = abs(getprop("/controls/flight/rudder", 0)) > 0.1;
    setprop(props.sas_yaw, yaw_switch and !fail and !yaw_force);

    # Annunciator
    setprop(props.ann_sas, (getprop(props.sas_roll) or getprop(props.sas_pitch) or getprop(props.sas_yaw)) ? 1 : 0);
};

# Attitude hold logic (engages if switch on, no fail, and no stick force)
var update_att_hold = func(dt) {
    var fail = getprop(props.fail, 0);
    var att_switch = get_switch("ap-att", 0);
    var stick_force = abs(getprop("/controls/flight/aileron", 0)) > 0.1 or abs(getprop("/controls/flight/elevator", 0)) > 0.1;

    if (att_switch and !fail and !stick_force) {
        if (!att_hold.active) {
            # Capture current attitude as hold reference
            att_hold.roll = getprop("/orientation/roll-deg", 0);
            att_hold.pitch = getprop("/orientation/pitch-deg", 0);
            pid_att_roll.reset();
            pid_att_pitch.reset();
            att_hold.active = 1;
        }
        # Calculate corrections
        var roll_cmd = pid_att_roll.update(att_hold, att_hold.roll, getprop("/orientation/roll-deg", 0), dt);
        var pitch_cmd = pid_att_pitch.update(att_hold, att_hold.pitch, getprop("/orientation/pitch-deg", 0), dt);

        # Inject commands (add to trim, or use custom property for FCS input)
        setprop("/afcs/att/roll-cmd", roll_cmd);
        setprop("/afcs/att/pitch-cmd", pitch_cmd);

        setprop(props.ap_att, 1);
        setprop(props.ann_ap_att, 1);
    } else {
        att_hold.active = 0;
        setprop("/afcs/att/roll-cmd", 0);
        setprop("/afcs/att/pitch-cmd", 0);
        setprop(props.ap_att, 0);
        setprop(props.ann_ap_att, 0);
    }
};

# Altitude hold logic (engages if switch on, no fail, and no stick force)
var update_alt_hold = func(dt) {
    var fail = getprop(props.fail, 0);
    var alt_switch = get_switch("ap-alt", 0);
    var stick_force = abs(getprop("/controls/flight/elevator", 0)) > 0.1;

    if (alt_switch and !fail and !stick_force) {
        if (!alt_hold.active) {
            # Capture current altitude as hold reference
            alt_hold.alt = getprop("/position/altitude-ft", 0);
            pid_alt.reset();
            alt_hold.active = 1;
        }
        # Calculate correction
        var alt_cmd = pid_alt.update(alt_hold, alt_hold.alt, getprop("/position/altitude-ft", 0), dt);

        # Inject command (add to trim, or use custom property for FCS input)
        setprop("/afcs/alt/pitch-cmd", alt_cmd);

        setprop(props.ap_alt, 1);
        setprop(props.ann_ap_alt, 1);
    } else {
        alt_hold.active = 0;
        setprop("/afcs/alt/pitch-cmd", 0);
        setprop(props.ap_alt, 0);
        setprop(props.ann_ap_alt, 0);
    }
};

# Failure annunciator
var update_annunciators = func {
    setprop(props.ann_fail, getprop(props.fail, 0));
};

# Main update loop
var last_time = systime();
var periodic_update = func {
    var now = systime();
    var dt = (now - last_time) / 1000.0;
    last_time = now;

    update_sas();
    update_att_hold(dt);
    update_alt_hold(dt);
    update_annunciators();

    settimer(periodic_update, 0.1);
};
periodic_update();

# TODO: Connect /afcs/att/roll-cmd, /afcs/att/pitch-cmd, /afcs/alt/pitch-cmd to FCS input chain for autopilot authority.
# TODO: Add more detailed failure logic and annunciator logic per NATOPS.