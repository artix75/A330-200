var target = func(prop, value, step, deadband) {

	if (math.abs(getprop(prop) - value) >= deadband) {
	
		if (getprop(prop) > value)
			setprop(prop, getprop(prop) - step);
		else
			setprop(prop, getprop(prop) + step);
	
	}

};

var general_loop = {
       init : func {
            me.UPDATE_INTERVAL = 0.05;
            me.loopid = 0;
            
            setprop("/gear/tilt/left-tilt-deg", 0);
            setprop("/gear/tilt/right-tilt-deg", 0);
            
            me.reset();
    },
    	update : func {
    	
    	# Engine Fuel Flow Conversion
    	
    	setprop("/engines/engine/fuel-flow-kgph", getprop("/engines/engine/fuel-flow_pph") * 0.45359237);
    	setprop("/engines/engine[1]/fuel-flow-kgph", getprop("/engines/engine[1]/fuel-flow_pph") * 0.45359237);
    	
    	# Landing Gear Compression Calculations
    	
    	var lf_comp = getprop("/gear/gear[1]/compression-ft");
    	var lr_comp = getprop("/gear/gear[3]/compression-ft");
    	
    	var rf_comp = getprop("/gear/gear[2]/compression-ft");
    	var rr_comp = getprop("/gear/gear[4]/compression-ft");
    	
    	var lf_wow = getprop("/gear/gear[1]/wow");
    	var lr_wow = getprop("/gear/gear[3]/wow");
    	
    	var rf_wow = getprop("/gear/gear[2]/wow");
    	var rr_wow = getprop("/gear/gear[4]/wow");
    	
    	var rod_length = 0.9471;
    	
    	var l_tilt = getprop("/gear/tilt/left-tilt-deg");
    	var r_tilt = getprop("/gear/tilt/right-tilt-deg");
    	
    	## LEFT MAIN GEAR
    	
    	if (lr_wow) { # Rear wheels touch the ground
    	
    		if (lf_wow) { # Front wheels also touch the ground
    		
    			var avg_comp = (lf_comp + lr_comp) / 2;
    			
    			var delta_comp = lr_comp - avg_comp;
    			
    			setprop("/gear/compression/left/avg-ft", avg_comp);
    			
    			var new_tilt = math.atan2(rod_length, delta_comp);
    			
    			if ((new_tilt >= 0) and (new_tilt < 25))
    				setprop("/gear/tilt/left-tilt-deg", new_tilt);
    			else
    				setprop("/gear/tilt/left-tilt-deg", 0);
    				
    			# NOTE : z-positions are in inches (conv. factor = 39.4)
    				
    			# setprop("/fdm/jsbsim/gear/unit[1]/z-position", -222.61);
    		
    			# setprop("/fdm/jsbsim/gear/unit[3]/z-position", -222.61);
    		
    		} else { # Front wheels DON'T touch the ground
    		
    			setprop("/gear/compression/left/avg-ft", 0);
    		
    			if (lr_comp > 0) {
    			
    				var delta_comp = lr_comp;
    				
    				# var z1_pos = getprop("/fdm/jsbsim/gear/unit[1]/z-position");
    				
    				# setprop("/fdm/jsbsim/gear/unit[1]/z-position", z1_pos + (delta_comp * 39.4));
    		
			  		# var z2_pos = getprop("/fdm/jsbsim/gear/unit[3]/z-position");
			  		
			  		# setprop("/fdm/jsbsim/gear/unit[3]/z-position", z2_pos - (delta_comp * 39.4));
			  		
			  		var tilt = getprop("/gear/tilt/left-tilt-deg");
			  		
			  		var delta_tilt = math.atan2(rod_length, delta_comp);
			  		
    				setprop("/gear/tilt/left-tilt-deg", tilt + delta_tilt);
    			
    			}
    		
    		}
    	
    	} else { # All wheels are airborne
    	
    		setprop("/gear/compression/left/avg-ft", 0);
    	
    		target("/gear/tilt/left-tilt-deg", 25, 2, 2);
    		
    		var delta_comp = math.tan(getprop("/gear/tilt/left-tilt-deg")) * rod_length;
    		
    		# setprop("/fdm/jsbsim/gear/unit[1]/z-position", -222.61 - delta_comp);
    		
    		# setprop("/fdm/jsbsim/gear/unit[3]/z-position", -222.61 + delta_comp);
    	
    	}
    	
    	## RIGHT MAIN GEAR
    	
    	if (lr_wow) { # Rear wheels touch the ground
    	
    		if (lf_wow) { # Front wheels also touch the ground
    		
    			var avg_comp = (rf_comp + rr_comp) / 2;
    			
    			var delta_comp = rr_comp - avg_comp;
    			
    			setprop("/gear/compression/right/avg-ft", avg_comp);
    			
    			var new_tilt = math.atan2(rod_length, delta_comp);
    			
    			if ((new_tilt >= 0) and (new_tilt < 25))
    				setprop("/gear/tilt/right-tilt-deg", new_tilt);
    			else
    				setprop("/gear/tilt/right-tilt-deg", 0);
    				
    			# NOTE : z-positions are in inches (conv. factor = 39.4)
    				
    			# setprop("/fdm/jsbsim/gear/unit[2]/z-position", -222.61);
    		
    			# setprop("/fdm/jsbsim/gear/unit[4]/z-position", -222.61);
    		
    		} else { # Front wheels DON'T touch the ground
    		
    			setprop("/gear/compression/right/avg-ft", 0);
    		
    			if (rr_comp > 0) {
    			
    				var delta_comp = rr_comp;
    				
    				# var z1_pos = getprop("/fdm/jsbsim/gear/unit[2]/z-position");
    				
    				# setprop("/fdm/jsbsim/gear/unit[2]/z-position", z1_pos + (delta_comp * 39.4));
    		
			  		# var z2_pos = getprop("/fdm/jsbsim/gear/unit[4]/z-position");
			  		
			  		# setprop("/fdm/jsbsim/gear/unit[4]/z-position", z2_pos - (delta_comp * 39.4));
			  		
			  		var tilt = getprop("/gear/tilt/right-tilt-deg");
			  		
			  		var delta_tilt = math.atan2(rod_length, delta_comp);
			  		
    				setprop("/gear/tilt/right-tilt-deg", tilt + delta_tilt);
    			
    			}
    		
    		}
    	
    	} else { # All wheels are airborne
    	
    		setprop("/gear/compression/right/avg-ft", 0);
    	
    		target("/gear/tilt/right-tilt-deg", 25, 2, 2);
    		
    		var delta_comp = math.tan(getprop("/gear/tilt/right-tilt-deg")) * rod_length;
    		
    		# setprop("/fdm/jsbsim/gear/unit[2]/z-position", -222.61 - delta_comp);
    		
    		# setprop("/fdm/jsbsim/gear/unit[4]/z-position", -222.61 + delta_comp);
    	
    	}
		
	},

        reset : func {
            me.loopid += 1;
            me._loop_(me.loopid);
    },
        _loop_ : func(id) {
            id == me.loopid or return;
            me.update();
            settimer(func { me._loop_(id); }, me.UPDATE_INTERVAL);
    }

};

setlistener("sim/signals/fdm-initialized", func
 {
 general_loop.init();
 });
