# Fuel Jettison System for A330-200s

var crossfeed = 0;

var fuel_jett = func() {
	
	if (getprop("/controls/fuel-dump/arm")) {
		setprop("/controls/fuel/x-feed", 1);
	}
	
	if (getprop("/consumables/fuel/total-fuel-kg") < 10000) {
		setprop("/controls/fuel-dump/active", 0);
	}
};

var arm_fuel_jett = func() {
	if (getprop("/controls/fuel-dump/arm")) {
		crossfeed = getprop("/controls/fuel/x-feed");
	} else {
		setprop("/controls/fuel/x-feed", crossfeed);
	}
};

setlistener("/controls/fuel-dump/arm", arm_fuel_jett);