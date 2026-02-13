# F-4J Automatic Flight Control System (AFCS) - NATOPS Section 1.17

var TRUE = 1;
var FALSE = 0;

# Properties for AFCS state
var properties = {
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
# - returns either the property or the def value.
var get_switch = func(name, def) {
    return getprop("/controls/afcs/" ~ name) or def;
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
    var fail = getprop(properties.fail, 0);

    # Roll SAS
    var roll_switch = get_switch("sas-roll", 1);
    var roll_force = abs(getprop("/controls/flight/aileron", 0)) > 0.1;
    setprop(properties.sas_roll, roll_switch and !fail and !roll_force);

    # Pitch SAS
    var pitch_switch = get_switch("sas-pitch", 1);
    var pitch_force = abs(getprop("/controls/flight/elevator", 0)) > 0.1;
    setprop(properties.sas_pitch, pitch_switch and !fail and !pitch_force);

    # Yaw SAS
    var yaw_switch = get_switch("sas-yaw", 1);
    var yaw_force = abs(getprop("/controls/flight/rudder", 0)) > 0.1;
    setprop(properties.sas_yaw, yaw_switch and !fail and !yaw_force);

    # Annunciator
    setprop(properties.ann_sas, (getprop(properties.sas_roll) or getprop(properties.sas_pitch) or getprop(properties.sas_yaw)) ? 1 : 0);
};

# Attitude hold logic (engages if switch on, no fail, and no stick force)
var update_att_hold = func(dt) {
    var fail = getprop(properties.fail, 0);
    var att_switch = get_switch("ap-att", 0);
    var stick_force = abs(getprop("/controls/flight/aileron", 0)) > 0.1 or abs(getprop("/controls/flight/elevator", 0)) > 0.1;

    if (att_switch and !fail and !stick_force) {
        if (!att_hold.active) {
            # Capture current attitude as hold reference
            att_hold.roll = getprop("/orientation/roll-deg", 0);
            att_hold.pitch = getprop("/orientation/pitch-deg", 0);
            pid_att_roll.reset(pid_att_roll);
            pid_att_pitch.reset(pid_att_pitch);
            att_hold.active = 1;
        }
        # Calculate corrections (use PID object as self)
        var roll_cmd = pid_att_roll.update(pid_att_roll, att_hold.roll, getprop("/orientation/roll-deg", 0), dt);
        var pitch_cmd = pid_att_pitch.update(pid_att_pitch, att_hold.pitch, getprop("/orientation/pitch-deg", 0), dt);

        # Inject commands (add to trim, or use custom property for FCS input)
        setprop("/afcs/att/roll-cmd", roll_cmd);
        setprop("/afcs/att/pitch-cmd", pitch_cmd);

        setprop(properties.ap_att, 1);
        setprop(properties.ann_ap_att, 1);
    } else {
        att_hold.active = 0;
        setprop("/afcs/att/roll-cmd", 0);
        setprop("/afcs/att/pitch-cmd", 0);
        setprop(properties.ap_att, 0);
        setprop(properties.ann_ap_att, 0);
    }
};

# ADC static correction & transonic oscillation avoidance (NATOPS 4.24-4.26)
# The ADC suffers from airspeed oscillations near Mach 0.9-1.0; reduce altitude-hold
# gain or disable briefly to avoid pilot-induced oscillations (PIO)
var adc_state = {
    static_corr_off: 0,          # 1 = ADC in transonic region, airspeed unreliable
    transonic_recovery: 0,       # Recovery timer to resume alt-hold
    airspeed_smooth: 0,          # Low-pass filtered airspeed
};

var update_adc_static_correction = func(dt) {
    var mach = getprop("/velocities/mach", 0);
    var cas = getprop("/velocities/airspeed-kt", 0);
    var altitude = getprop("/position/altitude-ft", 0);
    
    # ADC static error region: Mach 0.85-1.05
    if (mach >= 0.85 and mach <= 1.05) {
        if (!adc_state.static_corr_off) {
            adc_state.static_corr_off = 1;
            adc_state.transonic_recovery = 2.0; # 2-sec timeout for phase-out
            pid_alt.reset(pid_alt);
            setprop("/afcs/annunciator/adc-static-error", 1);
        }
    } else if (adc_state.static_corr_off) {
        adc_state.transonic_recovery -= dt;
        if (adc_state.transonic_recovery <= 0) {
            adc_state.static_corr_off = 0;
            setprop("/afcs/annunciator/adc-static-error", 0);
        }
    }
};

# Altitude hold logic (engages if switch on, no fail, and no stick force)
# Modified to reduce gain during transonic ADC uncertainty
var update_alt_hold = func(dt) {
    var fail = getprop(properties.fail, 0);
    var alt_switch = get_switch("ap-alt", 0);
    var stick_force = abs(getprop("/controls/flight/elevator", 0)) > 0.1;

    if (alt_switch and !fail and !stick_force) {
        if (!alt_hold.active) {
            # Capture current altitude as hold reference
            alt_hold.alt = getprop("/position/altitude-ft", 0);
            pid_alt.reset(pid_alt);
            alt_hold.active = 1;
        }
        
        var alt_error = alt_hold.alt - getprop("/position/altitude-ft", 0);
        var alt_cmd = pid_alt.update(pid_alt, alt_hold.alt, getprop("/position/altitude-ft", 0), dt);
        
        # NATOPS: During transonic climb (M 0.9-1.0), reduce alt-hold gain to ~50% 
        # to prevent pilot-induced oscillation from ADC airspeed fluctuations
        if (adc_state.static_corr_off) {
            # Reduce all PID action during transonic
            alt_cmd *= 0.5;
        }

        # Inject command (add to trim, or use custom property for FCS input)
        setprop("/afcs/alt/pitch-cmd", alt_cmd);

        setprop(properties.ap_alt, 1);
        setprop(properties.ann_ap_alt, 1);
    } else {
        alt_hold.active = 0;
        setprop("/afcs/alt/pitch-cmd", 0);
        setprop(properties.ap_alt, 0);
        setprop(properties.ann_ap_alt, 0);
    }
};

# Failure annunciator
var update_annunciators = func {
    setprop(properties.ann_fail, getprop(properties.fail) or 0);
};

# Main update loop
var last_time = systime();
var periodic_update = func {
    var now = systime();
    var dt = (now - last_time) / 1000.0;
    last_time = now;

    update_adc_static_correction(dt);
    update_sas();
    update_att_hold(dt);
    update_alt_hold(dt);
    update_annunciators();
    # Ensure yaw command property exists for FCS input (default 0)
    setprop("/afcs/att/yaw-cmd", 0);

    settimer(periodic_update, 0.1);
};
periodic_update();

# TODO: Connect /afcs/att/roll-cmd, /afcs/att/pitch-cmd, /afcs/alt/pitch-cmd to FCS input chain for autopilot authority.
# TODO: Add more detailed failure logic and annunciator logic per NATOPS.