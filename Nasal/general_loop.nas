setprop("/instrumentation/fmc/vspeeds/V1", 0);
setprop("/instrumentation/fmc/vspeeds/VR", 0);
setprop("/instrumentation/fmc/vspeeds/V2", 0);

var cpy_props = func() {

	if ((getprop("/sim/replay/time") == 0) or (getprop("/sim/replay/time") == nil)) {
	
		setprop("/aircraft/wingflex", getprop("/fdm/jsbsim/aero/force/Lift_alpha"));
		setprop("/aircraft/nose-compression", getprop("/gear/gear[0]/compression-ft"));
		
	}

};

var target = func(prop, value, step, deadband) {

	if (math.abs(getprop(prop) - value) >= deadband) {
	
		if (getprop(prop) > value)
			setprop(prop, getprop(prop) - step);
		else
			setprop(prop, getprop(prop) + step);
	
	}

};

var general_loop_1 = {
       init : func {
            me.UPDATE_INTERVAL = 0.02;
            me.loopid = 0;
            
            setprop("/gear/tilt/left-tilt-deg", 0);
            setprop("/gear/tilt/right-tilt-deg", 0);
            
            me.reset();
    },
    	update : func {
    	
    	# Engine Fuel Flow Conversion
    	
    	setprop("/engines/engine/fuel-flow-kgph", getprop("/engines/engine/fuel-flow_pph") * 0.45359237);
    	setprop("/engines/engine[1]/fuel-flow-kgph", getprop("/engines/engine[1]/fuel-flow_pph") * 0.45359237);
    	
    	tyresmoke();
    	
    	cpy_props();
    	
    	ldg_compress();
    	
    	tilt_calc();
    	
    	var nav = getprop("/controls/lighting/nav-lights-switch");
    	
    	if (nav == 2)
    		setprop("/controls/lighting/logo", 1);
    	else
    		setprop("/controls/lighting/logo", 0);
    	
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

var terrain_loop = {
       init : func {
            me.UPDATE_INTERVAL = 0.03;
            me.loopid = 0;
            
            me.reset();
    },
    	update : func {
    	
    	if (getprop("/instrumentation/efis/nd/terrain-on-nd"))
    		terrain_map();
    	
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
 general_loop_1.init();
 terrain_loop.init();
 });
