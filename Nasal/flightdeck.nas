var fcu = {
    init: func(){
        me.UPDATE_INTERVAL = 0.1;
        me.FCU_DISPLAY_TIMEOUT = 3;
        foreach(var knob; ['spd','hdg','alt']){
            setprop('/flight-management/fcu/'~knob~'-rotation-time',-1); 
            setprop('/flight-management/fcu/display-'~knob, 0); 
        }
        me.update();
    },
    update: func(){
        foreach(var knob; ['spd','hdg','alt']){
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
    knob_rotated: func(name){
        var type = '';
        if(name == 'hdg')
            type = 'lat';
        elsif(name == 'spd')
            type = name;
        elsif(name == 'alt')
            type = 'ver';
        if(type == '') return;
        var mode = getprop('/flight-management/control/' ~ type ~ '-ctrl');
        if(mode == 'fmgc'){
            var sec = int(getprop('sim/time/elapsed-sec'));
            setprop('/flight-management/fcu/'~name~'-rotation-time', sec);
        } else {
            setprop('/flight-management/fcu/'~name~'-rotation-time', -1);
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