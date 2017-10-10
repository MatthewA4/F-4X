#******************************************
#Copyright Matthew A.
#LICENSE: GPLv2+
#******************************************


#disable specific views
var init = func ()
{
    print("successfully loaded realism.nas");
    setprop("/sim/view[3]/enabled", 0);
    setprop("/sim/view[4]/enabled", 0);
    setprop("/sim/view[5]/enabled", 0);
    setprop("/sim/view[6]/enabled", 0);
    setprop("/sim/view[7]/enabled", 0);
} _setlistener("/nasal/realism/loaded", init);
