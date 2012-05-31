setprop("/autoland/phase", "disengaged");

var autoland = {

	phase_check: func() {
	
		var agl = getprop("/position/altitude-agl-ft");
		
		var spd = getprop("/velocities/airspeed-kt");
		
		var lbs = getprop("/fdm/jsbsim/inertia/weight-lbs");
		
		var nose_wow = getprop("/gear/gear/wow");
		
		var main_wow = getprop("/gear/gear[3]/wow");
		
		# LAND > FLARE1 > FLARE2 > MAIN_TOUCH (SLOWLY REDUCE PITCH) > NOSE TOUCH (RETARD)
		
		if ((getprop("/flight-management/control/a-thrust") != "off") and (getprop("/flight-management/control/spd-ctrl") == "fmgc")) {
		
			if (nose_wow) {
		
				me.retard();
		
			} elsif (main_wow) {
		
				me.slow(spd);

			} elsif (agl <= 20) {
			
				setprop("/flight-management/fmgc-values/target-spd", me.spd_manage(lbs) - 30);

			} elsif (agl <= 40) {

				setprop("/flight-management/fmgc-values/target-spd", me.spd_manage(lbs) - 10);
		
			} else {
		
				setprop("/flight-management/fmgc-values/target-spd", me.spd_manage(lbs));
		
			}
		
		}
		
		if (nose_wow) {
			
			# Exit Autoland
			
			setprop("/autoland/active", 0);
			
			setprop("/flight-management/control/ap1-master", "off");
			
			setprop("/flight-management/control/ap2-master", "off");
			
			setprop("/flight-management/control/a-thrust", "off");
			
			setprop("/autoland/phase", "disengaged");
			
			setprop("/autoland/rudder", 0);
		
		} elsif (main_wow) {
			
			setprop("/autoland/rudder", 1);
			
			setprop("/autoland/phase", "retard");
		
		} elsif (agl <= 20) {
		
			me.flare2();
			
			setprop("/autoland/rudder", 1);
			
			setprop("/autoland/phase", "flare");
		
		} elsif (agl <= 40) {
		
			# me.flare1();
		
			me.flare2();

			setprop("/autoland/phase", "flare");
			
			setprop("/autoland/rudder", 0);
		
		} else {
		
			setprop("/autoland/phase", "land");
			
			setprop("/autoland/rudder", 0);
		
		}
	
	},
	
	spd_manage: func(lbs) {
	
		var spd = 125 + ((lbs - 287000) * 0.000235);
		
		return spd;
	
	},
	
	flare1: func() {
	
		setprop("/servo-control/target-vs", -2);
	
	},

	flare2: func() {
	
		setprop("/servo-control/target-vs", -0.1667);
	
	},
	
	retard: func() {
	
		setprop("/controls/engines/engine[0]/throttle", 0);
		setprop("/controls/engines/engine[1]/throttle", 0);
	
	},
	
	slow: func(spd) {
		
		var trgt_spd = spd - 5;
		
		setprop("/flight-management/fmgc-values/target-spd", trgt_spd);
	
	}

};
