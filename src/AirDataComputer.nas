# F-4J Air Data Computer System (NATOPS Section: Air Data Computer System)

# Constants
var P0 = 29.92; # inHg, standard sea level pressure
var T0 = 288.15; # K, standard sea level temperature
var R = 287.05; # J/(kg·K), specific gas constant for air
var gamma = 1.4; # Ratio of specific heats

# Helper: get property with default
var getp = func(p, d) { return getprop(p, d); }

# Convert pressure altitude from static pressure (inHg)
var pressure_altitude = func(static_p_inHg) {
    return 145442.16 * (1 - math.pow(static_p_inHg / P0, 0.190284));
};

# Calculate Mach number
var calc_mach = func(ias_kt, alt_ft) {
    var temp_K = T0 - 0.0019812 * alt_ft * 0.5556; # ISA lapse rate
    var a = math.sqrt(gamma * R * temp_K); # speed of sound (m/s)
    var ias_ms = ias_kt * 0.514444;
    return ias_ms / a;
};

var update_adc = func {
    var static_p = getp("/instrumentation/altimeter/pressure-inhg", 29.92);
    var pitot_p = getp("/instrumentation/airspeed-indicator/pressure-inhg", 29.92);
    var alt_ft = pressure_altitude(static_p);

    var ias_kt = getp("/instrumentation/airspeed-indicator/indicated-speed-kt", 0);
    var mach = calc_mach(ias_kt, alt_ft);

    var baro_setting = getp("/instrumentation/altimeter/setting-inhg", 29.92);
    var baro_alt = alt_ft + (static_p - baro_setting) * 1000;

    # Set ADC outputs
    setprop("/systems/adc/pressure-altitude-ft", alt_ft);
    setprop("/systems/adc/baro-altitude-ft", baro_alt);
    setprop("/systems/adc/indicated-airspeed-kt", ias_kt);
    setprop("/systems/adc/mach", mach);
};

# Update every 0.5 seconds
var timer = maketimer(0.5, update_adc);
timer.start();