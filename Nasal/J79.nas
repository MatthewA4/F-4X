#Copyright (C) 2017 Matthew A.
#License: GPLv2+


var TRUE = 1;
var FALSE = 0;


source = {
cutoff1: 	"/controls/engines/engine/cutoff",
cutoff2:	"/controls/engines/engine[1]/cutoff",
engineN1:	"/engines/engine/n1",
engineN2:	"/engines/engine/n2",
engine2N1:	"/engines/engine[1]/n1",
engine2N2:	"/engines/engine[1]/n2",
engine1Gen:	"/controls/engines/engine/generator",
engine2Gen:	"/controls/engines/engine[1]/generator",
engine1Starter:  "/controls/engines/engine/starter",
engine2Starter:  "/controls/engines/engine[1]/starter",
};

var runit = TRUE;


var openFuelCutoff = func ()
{
	setprop(source.cutoff1, FALSE);
	setprop(source.cutoff2, FALSE);
}

var init = func ()
{
	setprop(source.cutoff1, TRUE);
	setprop(source.cutoff2, TRUE);

	setprop(source.engine1Gen, TRUE);
	setprop(source.engine2Gen, TRUE);
	
	setprop(source.engine1Starter, TRUE);
	setprop(source.engine2Starter, TRUE);

	settimer(openFuelCutoff, 10);



} _setlistener("/nasal/J79/loaded", init);
