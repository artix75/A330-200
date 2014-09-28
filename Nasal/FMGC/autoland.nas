setprop("/autoland/phase", "disengaged");
setprop("/autoland/retard", 0);
setprop("/autoland/early-descent", 400);

var autoland = {

	phase_check: func() {
	
		var agl = getprop("/position/altitude-agl-ft");
		
		var spd = getprop("/velocities/airspeed-kt");
		
		var lbs = getprop("/fdm/jsbsim/inertia/weight-lbs");
		
		var nose_wow = getprop("/gear/gear/wow");
		
		var main_wow = getprop("/gear/gear[3]/wow");
        
        #print("Autoland phase check");
		
		# LAND > FLARE1 > FLARE2 > MAIN_TOUCH (SLOWLY REDUCE PITCH) > NOSE TOUCH (RETARD)
		
		if ((getprop("/flight-management/control/a-thrust") != "off") and (getprop("/flight-management/control/spd-ctrl") == "fmgc") and (getprop("/flight-management/spd-manager/approach/mode") == "MANAGED (AUTO)")) {
		    #print("Autoland speed management");
            if (nose_wow or main_wow) { 
                print("Autoland: Touch down, retard...");
		
				me.retard();
		
			#} elsif (main_wow) {
		
				#me.slow(spd);

			} elsif (agl <= 50) {
                #print("Autoland: AGL <= 50, retard...");
			
				#setprop("/flight-management/fmgc-values/target-spd", 60);
				
				#setprop("/flight-management/control/a-thrust", "off");
                me.retard();
				
				##var throttle_l = getprop("/controls/engines/engine[0]/throttle");
				
				##var throttle_r = getprop("/controls/engines/engine[1]/throttle");
				
				##setprop("/controls/engines/engine[0]/throttle", throttle_l / 2);
				
				##setprop("/controls/engines/engine[1]/throttle", throttle_r / 2);

			} elsif (agl <= 100) {
                #print("Autoland: AGL <= 100, regulating speed and activating autoland");

				setprop("/flight-management/fmgc-values/target-spd", me.spd_manage(lbs) - 15);
			    setprop("/autoland/active", 1);
                setprop("/autoland/retard", 0);
                
		
			} else {
                #print("Autoland: regulating speed and activating autoland");
				setprop("/flight-management/fmgc-values/target-spd", me.spd_manage(lbs));
                setprop("/autoland/retard", 0);
			}
		
		}
		
		if (getprop("/velocities/airspeed-kt") <= 70) {
            #print("Autoland: IAS <= 70, deactivating autoland and AP");
			setprop("/autoland/active", 0);
			
			setprop("/autoland/phase", "disengaged");
			
			setprop("/flight-management/control/ap1-master", "off");
			
			setprop("/flight-management/control/ap2-master", "off");
		
		} elsif (nose_wow) {
            #print("Autoland: nose touch down, deactivating ATHR, activating rollout");
			setprop("/flight-management/control/a-thrust", "off");
			
			setprop("/autoland/phase", "rollout");
			
			setprop("/autoland/rudder", 1);
		
		} elsif (main_wow) {
            #print("Autoland: main touch down, target-vs -10 and rollout");
            setprop("/servo-control/target-vs", -10);
			setprop("/autoland/rudder", 1);
			
			setprop("/autoland/phase", "rollout");
		
		} elsif (agl <= 25) {
            #print("Autoland: AGL <= 25, flare2");
		
			me.flare2(agl);
			
			setprop("/autoland/rudder", 1);
			
			setprop("/autoland/phase", "flare");
		
		} elsif (agl <= 50) {
            #print("Autoland: AGL <= 50, flare1");
		
			me.flare1(agl);

			setprop("/autoland/phase", "flare");
			
			setprop("/autoland/rudder", 1);
			
		} 
		
		# Early Descent Approach Scenario as Proposed by Geir
		
		elsif (agl < getprop("/autoland/early-descent")) {
            #print("Autoland: early descent");
		
			me.early_descent(spd);
		
		} else {
            #print("Autoland: no rudder");
		
			setprop("/autoland/phase", "land");
			
			setprop("/autoland/rudder", 0);
		
		}
	
	},
	
	spd_manage: func(lbs) {
	
		var spd = 125 + ((lbs - 287000) * 0.000235);
		
		return spd;
	
	},
	
	early_descent : func(spd) {
	
		var trgt_vs = 0.01667 * ((-5 * spd) - 150); # Approx (0,01667 = conv factor for fpm to fps)
		
		setprop("/servo-control/target-vs", trgt_vs);
	
	},
	
	flare1: func(agl) {
	
		if (agl <= 30)
			setprop("/servo-control/target-vs", -2.5); # -150 fpm
		else
			setprop("/servo-control/target-vs", -5); # -300 fpm
	
	},

	flare2: func(agl) {
	
		# setprop("/servo-control/target-vs", -0.5); Sometimes acts funny
		
		# Using a gradual increase (negative decrease) in target vertical speed, using about -100 fpm at 50 ft and -8 fpm on touchdown (result in feet per second)
		
		# var trgt_vs = -0.01667 * (8 + (agl - 11) * 2.307); (If f2_alt = 50)
		
		var trgt_vs = -0.01667 * (15 + ((agl - 11) * 3.103));
        if(trgt_vs > -2.3)
            trgt_vs = -2.3;
		
		setprop("/servo-control/target-vs", trgt_vs);
	
	},
	
	retard: func() {
	
		setprop("/flight-management/control/a-thrust", "off");
        setprop("/flight-management/control/a-thr/ias", 0);
        setprop("/flight-management/control/a-thr/mach", 0);
        setprop("/flight-management/control/fmgc/ias", 0);
        setprop("/flight-management/control/fmgc/mach", 0);
		setprop("/controls/engines/engine[0]/throttle", 0);
		setprop("/controls/engines/engine[1]/throttle", 0);
        setprop("/autoland/retard", 1);
        settimer(func(){ # WORKAROUND FOR IDLE
            setprop("/controls/engines/engine[0]/throttle", 0);
            setprop("/controls/engines/engine[1]/throttle", 0);
        }, 0.35);
	
	},
	
	slow: func(spd) {
		
		#setprop("/controls/engines/engine[0]/throttle", 0.1);
				
		#setprop("/controls/engines/engine[1]/throttle", 0.1);
                
		setprop("/flight-management/fmgc-values/target-spd", 60);
	
	}

};