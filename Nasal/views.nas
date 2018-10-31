#******************************************
#Copyright Matthew A.
#LICENSE: GPLv2+
#******************************************

var TRUE  = 1;
var FALSE = 0;

# much simplier solution, doesn't toggle enabled view sim-wide anymore.
var viewAntiCheat = func()
{
    if(getprop("/nasal/libraries/view-enabled") == TRUE)
    {
        if(getprop("/sim/current-view/view-number") != 0)
        {
	    setprop("/sim/current-view/view-number", 0);
	}
    }
} _setlistener("/sim/current-view/view-number", viewAntiCheat);


var setPilotView = func()
{
    if(getprop("/nasal/libraries/view-enabled") == TRUE)
    {
       if(getprop("/sim/current-view/view-number") != 0)
       {
	   setprop("/sim/current-view/view-number", 0);
       }
    }
} _setlistener("/nasal/libraries/view-enabled", setPilotView);
