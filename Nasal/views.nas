#******************************************
#Copyright Matthew A.
#LICENSE: GPLv2+
#******************************************

var TRUE  = 1;
var FALSE = 0;

var bypass = FALSE;

source = {
cockpitViewEnabled:	"/sim/view/enabled",	#cockpit view
HeliViewEnabled:   	"/sim/view[1]/enabled", #helicopter view
ChaseViewEnabled:   	"/sim/view[2]/enabled", #chase view
TowerViewEnabled:   	"/sim/view[3]/enabled", #tower view
TowerViewLfEnabled:   	"/sim/view[4]/enabled", #tower view look from
ChaseViewNoYawEnabled:  "/sim/view[5]/enabled", #chase view without yaw
FBWViewEnabled:   	"/sim/view[6]/enabled", #fly-by-view
ModelViewEnabled:   	"/sim/view[7]/enabled", #model view
};


#disable specific views
var init = func ()
{
    print("successfully loaded views.nas");
    setprop(source.HeliViewEnabled, FALSE);
    setprop(source.ChaseViewEnabled, FALSE);
    setprop(source.TowerViewEnabled, FALSE);
    setprop(source.TowerViewLfEnabled, FALSE);
    setprop(source.ChaseViewNoYawEnabled, FALSE);
    setprop(source.FBWViewEnabled, FALSE);
    setprop(source.ModelViewEnabled, TRUE);
} _setlistener("/nasal/views/loaded", init);


var ResetHeliView = func ()
{	
	if(!bypass){
		setprop(source.HeliViewEnabled, FALSE);
		}
} _setlistener(source.HeliViewEnabled, ResetHeliView);

var ResetChaseView = func ()
{
	if(!bypass){
	setprop(source.ChaseViewEnabled, FALSE);
	}
} _setlistener(source.ChaseViewEnabled, ResetChaseView);

var ResetTowerView = func ()
{
	if(!bypass){
	setprop(source.TowerViewEnabled, FALSE);
	}
} _setlistener(source.TowerViewEnabled, ResetTowerView);

var ResetTowerViewLf = func ()
{
	if(!bypass){
	setprop(source.TowerViewLfEnabled, FALSE);
	}
} _setlistener(source.TowerViewLfEnabled, ResetTowerViewLf);

var ResetChaseViewNoYaw = func ()
{
	if(!bypass){
	setprop(source.ChaseViewNoYawEnabled, FALSE);
	}
} _setlistener(source.ChaseViewNoYawEnabled, ResetChaseViewNoYaw);

var ResetFBWview = func ()
{
	if(!bypass){
		setprop(source.FBWViewEnabled, FALSE);
	}
} _setlistener(source.FBWViewEnabled, ResetFBWview);
