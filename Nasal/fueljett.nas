# Fuel Jettison system for A330-200s and A340-500/-600s

# When fuel jettison is armed, fuel starts filling up the ventilation tanks and when it is activated, it starts dumping the fuel from the vent tanks

var lvent = 0;
var rvent = 6;
var ctr = 3;
var lout = 1;
var lin = 2;
var rout = 5;
var rin = 4;

var transferFuel = func(from_tk, to_tk, amt) {
	var from = "/consumables/fuel/tank["~from_tk~"]/level-lbs";
	var to_norm = "/consumables/fuel/tank["~to_tk~"]/level-norm";
	if ((getprop(from) >= amt) and (getprop(to_norm) <= 0.99)) {
		setprop(from, getprop(from) - amt);
		var to = "/consumables/fuel/tank["~to_tk~"]/level-lbs";
		setprop(to, getprop(to) + amt);
	}
};

var jettison = func(from_tk, amt) {
	var from = "/consumables/fuel/tank["~from_tk~"]/level-lbs";
	if (getprop(from) >= amt) setprop(from, getprop(from) - amt);
}

var fuel_jett = func() {

	if (getprop("/consumables/fuel/total-fuel-kg") < 200) {
		setprop("/controls/fuel-dump/active", 0);
	}

	if (getprop("/controls/fuel-dump/arm") or getprop("/controls/fuel-dump/active")) {
	
		# Move fuel from tanks to vent tank
		
		transferFuel(ctr, lvent, 4);
		transferFuel(ctr, rvent, 4);
		
		transferFuel(lin, lvent, 6);
		transferFuel(rin, rvent, 6);
		
		transferFuel(lout, lvent, 2);
		transferFuel(rout, rvent, 2);
	
	}
	
	if (getprop("/controls/fuel-dump/active")) {
	
		jettison(lvent, 8);
		jettison(rvent, 8);
	
	}

};
