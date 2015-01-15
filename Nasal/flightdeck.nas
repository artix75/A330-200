var fcu = {
    init: func(){
        me.UPDATE_INTERVAL = 0.1;
        me.FCU_DISPLAY_TIMEOUT = 3;
        foreach(var knob; ['spd','hdg','alt','vs']){
            setprop('/flight-management/fcu/'~knob~'-rotation-time',-1); 
            setprop('/flight-management/fcu/display-'~knob, 0); 
        }
        me.update();
    },
    update: func(){
        foreach(var knob; ['spd','hdg','alt','vs']){
            var sec = getprop('/flight-management/fcu/'~knob~'-rotation-time');
            if(sec > 0){
                var cur_sec = int(getprop('sim/time/elapsed-sec'));
                var elapsed = cur_sec - sec;
                var disp = (elapsed <= me.FCU_DISPLAY_TIMEOUT);
                setprop('/flight-management/fcu/display-'~knob, disp);
            } else {
                setprop('/flight-management/fcu/display-'~knob, 0);
            }     
        }
        settimer(func { me.update(); }, me.UPDATE_INTERVAL);
    },
    get_type: func(name){
        var type = '';
        if(name == 'hdg')
            type = 'lat';
        elsif(name == 'spd')
            type = name;
        elsif(name == 'alt')
            type = 'ver';
        return type;
    },
    knob_rotated: func(name){
        var type = me.get_type(name);
        if(type == '') return;
        var mode = getprop('/flight-management/control/' ~ type ~ '-ctrl');
        if(mode == 'fmgc'){
            var sec = int(getprop('sim/time/elapsed-sec'));
            setprop('/flight-management/fcu/'~name~'-rotation-time', sec);
        } else {
            setprop('/flight-management/fcu/'~name~'-rotation-time', -1);
        }
    },
    knob_pushed: func(name){
        utils.clickSound(4);
		me.push_animation(name);
        if (fmgc.fmgc_loop.active_common_mode == 'LAND')
            return;
        var type = me.get_type(name);
        if(type == '') return;
        var mode_prop = '/flight-management/control/' ~ type ~ '-ctrl';
        var mode = getprop(mode_prop);
        if (mode != 'fmgc'){
            setprop(mode_prop, 'fmgc');
        }
        if(name == 'alt'){
            setprop("/flight-management/fcu-values/alt", 
                    getprop("/flight-management/fcu-values/fcu-alt"));
            setprop('/flight-management/control/vsfpa-mode', 0);
            setprop('/flight-management/fcu/display-vs', 0);
        }
    },
    knob_pulled: func(name){
        utils.clickSound(4);
		me.pull_animation(name);
        if (fmgc.fmgc_loop.active_common_mode == 'LAND')
            return;
        var type = me.get_type(name);
        if(type == '') return;
        var mode_prop = '/flight-management/control/' ~ type ~ '-ctrl';
        var mode = getprop(mode_prop);
        if (mode != 'man-set'){
            setprop(mode_prop, 'man-set');
        }
        if(name == 'alt'){
            setprop("/flight-management/fcu-values/alt", 
                    getprop("/flight-management/fcu-values/fcu-alt"));
            setprop('/flight-management/control/vsfpa-mode', 0);
            setprop('/flight-management/fcu/display-vs', 0);
        }
        elsif(name == 'hdg'){
            setprop('autopilot/settings/heading-bug-deg', 
                    getprop("/flight-management/fcu-values/hdg"));
        }
    },
	push_animation: func(name){
		var pos_prop = 'flightdeck/fcu/'~name~'-knob-pos';
		var knob_pos = getprop(pos_prop);
		if(knob_pos == nil) knob_pos = 0;
		if(knob_pos <= 0){
			interpolate(pos_prop, 1, 0.1);
			settimer(func setprop(pos_prop, 0), 0.11);
		}
	},
	pull_animation: func(name){
		var pos_prop = 'flightdeck/fcu/'~name~'-knob-pos';
		var knob_pos = getprop(pos_prop);
		if(knob_pos == nil) knob_pos = 0;
		if(knob_pos >= 0){
			interpolate(pos_prop, -1, 0.1);
			settimer(func setprop(pos_prop, 0), 0.11);
		}
	},
    vsfpa_rotated: func(){
        var vs_mode = getprop('/flight-management/control/vsfpa-mode');
        if (!vs_mode){
            var sec = int(getprop('sim/time/elapsed-sec'));
            setprop('/flight-management/fcu/vs-rotation-time', sec);
        } else {
            setprop('/flight-management/fcu/vs-rotation-time', -1);
        }
    },
    vsfpa_pushed: func(){
        utils.clickSound(4);
        if (fmgc.fmgc_loop.active_common_mode == 'LAND')
            return;
        setprop("/flight-management/fcu-values/vs", 0);
        setprop("/flight-management/fcu-values/fpa", 0);
        setprop("/flight-management/control/ver-ctrl", "man-set");
        setprop('/flight-management/control/vsfpa-mode', 1);
    },
    vsfpa_pulled: func(){
        utils.clickSound(4);
        if (fmgc.fmgc_loop.active_common_mode == 'LAND')
            return;
        setprop("/flight-management/control/ver-ctrl", "man-set");
        setprop('/flight-management/control/vsfpa-mode', 1);
        setprop("/flight-management/fcu-values/alt", 
                getprop("/flight-management/fcu-values/fcu-alt"));
    },
    alt_rotated: func(direction){
        var step = getprop("/flight-management/control/alt-sel-mode");
        var alt_prop = "/flight-management/fcu-values/alt";
        var alt_disp = "/flight-management/fcu-values/fcu-alt";
        var current_val = getprop(alt_disp);
        var selected_alt = getprop(alt_prop);
        if (direction == 'decr'){
            step *= -1;  
            if (0 >= current_val) return;
        } else {
            if (41000 <= current_val) return;
        };
        var new_alt = current_val + step;
        setprop(alt_disp, new_alt);
        var alt = fmgc.fmgc_loop.altitude;
        var is_alt_mode = (math.abs(alt - selected_alt) <= 250);
        if (!is_alt_mode){
            setprop(alt_prop, new_alt);
            me.alt_changed(new_alt);
        }
    },
    alt_changed: func(new_alt){
        var crz_fl = getprop("/flight-management/crz_fl");
        var crz_alt = int(crz_fl * 100);
        if(new_alt > crz_alt){
            setprop("/flight-management/crz_fl", int(new_alt / 100));
            setprop("autopilot/route-manager/cruise/altitude-ft", new_alt);
        }
    }
};

setlistener("sim/signals/fdm-initialized", func{
    fcu.init();
    print("FCU initialized");
});