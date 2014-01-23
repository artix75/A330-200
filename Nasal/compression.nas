var tilt_calc = func() {

	if ((getprop("/sim/replay/time") == 0) or (getprop("/sim/replay/time") == nil)) {

		var rod_length = 37.547; # In Inches

		# LEFT MAIN GEAR
	
		var front_z_pos = getprop("fdm/jsbsim/gear/unit[1]/z-position");
	
		var coeff = (222.61 + front_z_pos) / rod_length;
	
		setprop("gear/tilt/left-tilt-deg", math.asin(coeff) * 57.29);
	
		# RIGHT MAIN GEAR
	
		front_z_pos = getprop("fdm/jsbsim/gear/unit[2]/z-position");
	
		coeff = (222.61 + front_z_pos) / rod_length;
	
		setprop("gear/tilt/right-tilt-deg", math.asin(coeff) * 57.29);
	
	}

};

var ldg_compress = func() {

	if ((getprop("/sim/replay/time") == 0) or (getprop("/sim/replay/time") == nil)) {

		# Landing Gear Compression Calculations
	
		if (getprop("/position/altitude-agl-ft") > 100) {
	
			setprop("gear/compression/left/avg-ft", 0);
			setprop("gear/compression/right/avg-ft", 0);
	
		} else {
	
			# There are 4 possible cases- both sections are airborne, both are on the ground, only the front section is on the ground and finally, only the rear section is on the ground.
	
			# LEFT MAIN GEAR
		
			var front_wow = getprop("/gear/gear[1]/wow");
			var rear_wow = getprop("/gear/gear[3]/wow");
		
			if (front_wow and rear_wow) {
			
				var front_comp = getprop("/gear/gear[1]/compression-ft");
				var rear_comp = getprop("/gear/gear[3]/compression-ft");
			
				setprop("gear/compression/left/avg-ft", (front_comp + rear_comp) / 2);
			
				setprop("fdm/jsbsim/gear/unit[1]/z-position", -222.61);
				setprop("fdm/jsbsim/gear/unit[3]/z-position", -222.61);
		
			} elsif (!front_wow and rear_wow) {
		
				var front_z_pos = getprop("fdm/jsbsim/gear/unit[1]/z-position");
				var rear_z_pos = getprop("fdm/jsbsim/gear/unit[3]/z-position");
			
				setprop("gear/compression/left/avg-ft", 0);
			
				if (front_z_pos > -225.88) {
			
					setprop("fdm/jsbsim/gear/unit[1]/z-position", front_z_pos - 0.5);
					setprop("fdm/jsbsim/gear/unit[3]/z-position", rear_z_pos + 0.5);
			
				}
		
			} else {
		
				var front_z_pos = getprop("fdm/jsbsim/gear/unit[1]/z-position");
				var rear_z_pos = getprop("fdm/jsbsim/gear/unit[3]/z-position");
			
				setprop("gear/compression/left/avg-ft", 0);
			
				if (rear_z_pos > -230) {
			
					setprop("fdm/jsbsim/gear/unit[1]/z-position", front_z_pos + 1);
					setprop("fdm/jsbsim/gear/unit[3]/z-position", rear_z_pos - 1);
			
				}
		
			}
		
			# RIGHT MAIN GEAR
		
			var front_wow = getprop("/gear/gear[2]/wow");
			var rear_wow = getprop("/gear/gear[4]/wow");
		
			if (front_wow and rear_wow) {
			
				var front_comp = getprop("/gear/gear[2]/compression-ft");
				var rear_comp = getprop("/gear/gear[4]/compression-ft");
			
				setprop("gear/compression/right/avg-ft", (front_comp + rear_comp) / 2);
			
				setprop("fdm/jsbsim/gear/unit[2]/z-position", -222.61);
				setprop("fdm/jsbsim/gear/unit[4]/z-position", -222.61);
		
			} elsif (!front_wow and rear_wow) {
		
				var front_z_pos = getprop("fdm/jsbsim/gear/unit[2]/z-position");
				var rear_z_pos = getprop("fdm/jsbsim/gear/unit[4]/z-position");
			
				setprop("gear/compression/right/avg-ft", 0);
			
				if (front_z_pos > -225.88) {
			
					setprop("fdm/jsbsim/gear/unit[2]/z-position", front_z_pos - 1);
					setprop("fdm/jsbsim/gear/unit[4]/z-position", rear_z_pos + 1);
			
				}
		
			} else {
		
				var front_z_pos = getprop("fdm/jsbsim/gear/unit[2]/z-position");
				var rear_z_pos = getprop("fdm/jsbsim/gear/unit[4]/z-position");
			
				setprop("gear/compression/right/avg-ft", 0);
			
				if (rear_z_pos > -230) {
			
					setprop("fdm/jsbsim/gear/unit[2]/z-position", front_z_pos + 1);
					setprop("fdm/jsbsim/gear/unit[4]/z-position", rear_z_pos - 1);
			
				}
		
			}
	
		}
		
	}

};
