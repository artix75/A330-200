var warning = {
	msg: "",
	aural: "chime",
	light: "caution",
	prop: "",
	condition: func() { },
	disp: 0,
	new: func(arg1, arg2, arg3, arg4) {
		
		var t = {parents:[warning]};
		
		t.msg = arg1;
		t.aural = arg2;
		t.light = arg3;
		t.prop = "/warnings/"~arg4~"/";
		setprop(t.prop~"active", 0);
		
		return t;
	
	},
	sound: func() {
	
		setprop("/sim/sound/warnings/"~me.aural, 0);
		settimer(func() {setprop("/sim/sound/warnings/"~me.aural, 1)}, 0.5);
	
	},
	warnlight: func() {
	
		setprop("/warnings/master-"~me.light~"-light", 1);
	
	},
	trigger: func() {

		if(getprop(me.prop~"active") != 1) {
		
			me.sound();
			me.warnlight();
			setprop(me.prop~"active", 1);
			me.disp = 1;
			print("[ECAM] " ~ me.msg);
		
		}
	
	},
	deactivate: func() {
	
		setprop(me.prop~"active", 0);
		me.disp = 0;
	
	}
};

var memo_system = {
       init : func {
            me.UPDATE_INTERVAL = 0.5;
            me.loopid = 0;
  
            me.reset();
    },
    	update : func {
    	
			
    	
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

var state_loop = {
       init : func {
            me.UPDATE_INTERVAL = 0.5;
            me.loopid = 0;
        
			setprop("/warnings/master-warning-state", 0);
			setprop("/warnings/master-caution-state", 0);
			setprop("/warnings/master-warning-light", 0);
            setprop("/warnings/master-caution-light", 0);
            
			me.ws = "/warnings/master-warning-state";
			me.cs = "/warnings/master-caution-state";
			me.wl = "/warnings/master-warning-light";
			me.cl = "/warnings/master-caution-light";
  
            me.reset();
    },
    	update : func {
    	
			if ((getprop(me.ws) == 0) and (getprop(me.wl) == 1)) {
				setprop(me.ws, 1);
			} else {
				setprop(me.ws, 0);
			}
			
			if ((getprop(me.cs) == 0) and (getprop(me.cl) == 1)) {
				setprop(me.cs, 1);
			} else {
				setprop(me.cs, 0);
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


var warning_system = {
       init : func {
            me.UPDATE_INTERVAL = 1;
            me.loopid = 0;
           
            setprop("/warnings/master-warning-light", 0);
            setprop("/warnings/master-caution-light", 0);
            
            # Create Warnings #########################
            
            ## APU
            
           me.apu_emer = warning.new("APU EMER SHUT DOWN", "chime", "caution", "apu-emer");
            
            ## Flight Controls
            
			me.to_cfg_flaps = warning.new("TO CONFIG FLAPS", "crc", "warning", "to-flaps");
			
			me.to_cfg_spdbrk = warning.new("RETRACT SPD BRK", "crc", "warning", "to-spdbrk");
			
			me.to_cfg_ptrim = warning.new("CHECK PITCH TRIM", "crc", "warning", "to-ptrim");

			me.to_cfg_rtrim = warning.new("CHECK RUD TRIM", "crc", "warning", "to-rtrim");
			
			me.elev_fault = warning.new("L+R ELEV FAULT", "crc", "warning", "elev-fault");
			
			me.ail_fault = warning.new("L+R AIL FAULT", "crc", "warning", "ail-fault");
			
			me.rud_fault = warning.new("RUDDER FAULT", "crc", "warning", "rud-fault");
			
			me.spdbrk_fault = warning.new("L+R SPD BRK FAULT", "chime", "caution", "spdbrk-fault");
			
			me.flaps_fault = warning.new("L+R FLAPS FAULT", "chime", "caution", "flaps-fault");
			
			me.direct_law = warning.new("DIRECT LAW", "chime", "caution", "dir-law");
			
			me.altn_law = warning.new("ALTN LAW", "chime", "caution", "altn-law");
			
			me.abn_law = warning.new("ABNORMAL ALTN LAW", "chime", "caution", "abn-law");
			
			## Power Plant
			
			me.engd_fail = warning.new("ENG DUAL FAILURE", "crc", "warning", "engd-fail");
			
			me.eng1_fail = warning.new("ENG 1 FAILURE", "chime", "caution", "eng1-fail");
			
			me.eng2_fail = warning.new("ENG 2 FAILURE", "chime", "caution", "eng2-fail");
			
			me.engd_oilp = warning.new("ENG 1+2 OIL LO PR", "crc", "warning", "engd-oil");
			
			me.eng1_oilp = warning.new("ENG 1 OIL LO PR", "chime", "caution", "eng1-oil");
			
			me.eng2_oilp = warning.new("ENG 2 OIL LO PR", "chime", "caution", "eng2-oil");
			
			me.engd_shut = warning.new("ENG 1+2 SHUT DOWN", "chime", "caution", "engd-shut");
			
			me.eng1_shut = warning.new("ENG 1 SHUT DOWN", "chime", "caution", "eng1-shut");
			
			me.eng2_shut = warning.new("ENG 2 SHUT DOWN", "chime", "caution", "eng2-shut");
			
			## Hydraulics
			
			me.hydall = warning.new("HYD SYS LO PR", "crc", "warning", "hydall");
			
			me.hydby = warning.new("B+Y SYS LO PR", "crc", "warning", "hydby");
			
			me.hydbg = warning.new("B+G SYS LO PR", "crc", "warning", "hydbg");
			
			me.hydgy = warning.new("Y+G SYS LO PR", "crc", "warning", "hydgy");
			
			me.hydb = warning.new("B SYS LO PR", "chime", "caution", "hydb-lopr");
			
			me.hydy = warning.new("Y SYS LO PR", "chime", "caution", "hydy-lopr");
			
			me.hydg = warning.new("G SYS LO PR", "chime", "caution", "hydg-lopr");
			
			me.ptu_fault = warning.new("PTU FAULT", "chime", "caution", "ptu-fault");
			
			## Fuel
			
			me.fuel_1lo = warning.new("L WING TK LO LVL", "chime", "caution", "fuel1lo");
			
			me.fuel_2lo = warning.new("R WING TK LO LVL", "chime", "caution", "fuel2lo");
			
			me.fuel_clo = warning.new("CTR TK LO LVL", "chime", "caution", "fuelclo");
			
			me.fuel_wlo = warning.new("L+R WING TK LO LVL", "crc", "caution", "fuello");
			
			me.fuel_bal = warning.new("X-FEED FAULT", "chime", "caution", "fuelbal");
			
			
			## Electric
			
			me.apugen_fault = warning.new("APU GEN FAULT", "chime", "caution", "apugen-fault");
			
			me.gen1_fault = warning.new("GEN 1 FAULT", "chime", "caution", "gen1-fault");
			
			me.gen2_fault = warning.new("GEN 2 FAULT", "chime", "caution", "gen2-fault");
			
			me.emer_conf = warning.new("EMER CONFIG", "crc", "warning", "emer-conf");
			
			## FMGC
			
			me.ap_off = warning.new("AP 1+2 OFF", "ap_disc", "caution", "ap-off");
			
			me.athr_off = warning.new("A/THR OFF", "chime", "caution", "athr-off");
			
			me.warnings = [me.apu_emer, me.to_cfg_flaps, me.to_cfg_spdbrk, me.to_cfg_ptrim, me.to_cfg_rtrim, me.elev_fault, me.ail_fault, me.rud_fault, me.spdbrk_fault, me.flaps_fault, me.direct_law, me.altn_law, me.abn_law , me.engd_fail, me.eng1_fail, me.eng2_fail, me.engd_oilp, me.eng1_oilp, me.eng2_oilp, me.engd_shut, me.eng1_shut, me.eng2_shut, me.hydall, me.hydby, me.hydbg, me.hydgy, me.hydb, me.hydy, me.hydg, me.ptu_fault, me.fuel_1lo, me.fuel_2lo, me.fuel_clo, me.fuel_wlo, me.fuel_bal, me.apugen_fault, me.gen1_fault, me.gen2_fault, me.emer_conf, me.ap_off, me.athr_off];
            
            me.reset();
    },
		updateECAM : func {
    
		me.disp_warnings = [];
		me.warn_index = [];
		me.warn_type = [];
    
		var n = 0;
    
		foreach(var warn; me.warnings) {
			
			if ((getprop(warn.prop~"active") == 1) and (warn.disp == 1)) {
				append(me.disp_warnings, warn.msg);
				append(me.warn_index, n);
				append(me.warn_type, warn.light);
			}
			
			n+=1;
		
		}
		
		for(var n=0; n<12; n+=1) {
			if (size(me.disp_warnings) > n) {
				setprop("warnings/ecam/warn["~n~"]/msg", me.disp_warnings[n]);
				setprop("warnings/ecam/warn["~n~"]/index", me.warn_index[n]);
				setprop("warnings/ecam/warn["~n~"]/type", me.warn_type[n]);
			} else {
				setprop("warnings/ecam/warn["~n~"]/msg", "");
			}
		}
    
    },
		clr : func {
    
		var index = getprop("warnings/ecam/warn[0]/index");
		
		me.warnings[index].disp = 0;
		me.warnings[index].hide = 1;
    
    },
		rcl : func {
		
		foreach(var warn; me.warnings) {
		
			if (getprop(warn.prop~"active") == 1) {
				warn.disp = 1;
			}
		
		}
	
	},
    	update : func {
    	
			if (getprop("/engines/apu/on-fire")){
				me.apu_emer.trigger();
			} else {
				me.apu_emer.deactivate();
			}
			
			var weight = getprop("/fdm/jsbsim/inertia/weight-lbs");
			var flaps = getprop("/controls/flight/flaps");
			if ((getprop("/controls/engines/engine/throttle") > 0.95) and (getprop("/position/altitude-agl-ft") < 400) and (((weight > 380000) and (weight < 440001) and (flaps < 0.25)) or ((weight > 440000) and (flaps < 0.5)))){
				me.to_cfg_flaps.trigger();
			} else {
				me.to_cfg_flaps.deactivate();
			}
			
			if ((getprop("/controls/engines/engine/throttle") > 0.95) and (getprop("/controls/flight/speedbrake") != 0)){
				me.to_cfg_spdbrk.trigger();
			} else {
				me.to_cfg_spdbrk.deactivate();
			}
			
			if ((getprop("/controls/engines/engine/throttle") > 0.95) and (getprop("/position/altitude-agl-ft") < 400) and ((getprop("/controls/flight/elevator-trim") > 0.6) or (getprop("/controls/flight/elevator-trim") < -0.6))){
				me.to_cfg_ptrim.trigger();
			} else {
				me.to_cfg_ptrim.deactivate();
			}
			
			if ((getprop("/controls/engines/engine/throttle") > 0.95) and (getprop("/position/altitude-agl-ft") < 400) and ((getprop("/controls/flight/rudder-trim") > 0.5) or (getprop("/controls/flight/rudder-trim") < -0.5))){
				me.to_cfg_rtrim.trigger();
			} else {
				me.to_cfg_rtrim.deactivate();
			}
			
			if ((getprop("/sim/failure-manager/controls/flight/elevator/serviceable") == 0)){
				me.elev_fault.trigger();
			} else {
				me.elev_fault.deactivate();
			}
			
			if (getprop("/sim/failure-manager/controls/flight/aileron/serviceable") == 0){
				me.ail_fault.trigger();
			} else {
				me.ail_fault.deactivate();
			}
			
			if (getprop("/sim/failure-manager/controls/flight/rudder/serviceable") == 0){
				me.rud_fault.trigger();
			} else {
				me.rud_fault.deactivate();
			}
			
			if (getprop("/sim/failure-manager/controls/flight/speedbrake/serviceable") == 0){
				me.spdbrk_fault.trigger();
			} else {
				me.spdbrk_fault.deactivate();
			}
			
			if (getprop("/sim/failure-manager/controls/flight/flaps/serviceable") == 0){
				me.flaps_fault.trigger();
			} else {
				me.flaps_fault.deactivate();
			}
			
			if (getprop("/fbw/active-law") == "DIRECT LAW"){
				me.direct_law.trigger();
			} else {
				me.direct_law.deactivate();
			}
			
			if (getprop("/fbw/active-law") == "ALTERNATE LAW"){
				me.altn_law.trigger();
			} else {
				me.altn_law.deactivate();
			}
			
			if (getprop("/fbw/active-law") == "ABNORMAL ALTERNATE LAW"){
				me.abn_law.trigger();
			} else {
				me.abn_law.deactivate();
			}
			
			if ((getprop("/sim/failure-manager/engines/engine/serviceable") == 0) and ((getprop("/sim/failure-manager/engines/engine[1]/serviceable") == 0))){
				me.engd_fail.trigger();
			} else {
				me.engd_fail.deactivate();
			}
			
			if ((getprop("/sim/failure-manager/engines/engine/serviceable") == 0) and ((getprop("/sim/failure-manager/engines/engine[1]/serviceable") == 1))){
				me.eng1_fail.trigger();
			} else {
				me.eng1_fail.deactivate();
			}
			
			if ((getprop("/sim/failure-manager/engines/engine/serviceable") == 1) and ((getprop("/sim/failure-manager/engines/engine[1]/serviceable") == 0))){
				me.eng2_fail.trigger();
			} else {
				me.eng2_fail.deactivate();
			}
			
			if ((getprop("/engines/engine/oil-pressure-psi") < 13) and ((getprop("/engines/engine[1]/oil-pressure-psi") < 13))){
				me.engd_oilp.trigger();
			} else {
				me.engd_oilp.deactivate();
			}
			
			if ((getprop("/engines/engine/oil-pressure-psi") < 13) and ((getprop("/engines/engine[1]/oil-pressure-psi") >= 13))){
				me.eng1_oilp.trigger();
			} else {
				me.eng1_oilp.deactivate();
			}
			
			if ((getprop("/engines/engine/oil-pressure-psi") >= 13) and ((getprop("/engines/engine[1]/oil-pressure-psi") < 13))){
				me.eng2_oilp.trigger();
			} else {
				me.eng2_oilp.deactivate();
			}
			
			if ((getprop("/position/altitude-agl-ft") >= 400) and (getprop("/controls/engines/engine/cutoff-switch") == 1) and ((getprop("/controls/engines/engine/cutoff-switch") == 1))){
				me.engd_shut.trigger();
			} else {
				me.engd_shut.deactivate();
			}	
			
			if ((getprop("/position/altitude-agl-ft") >= 400) and (getprop("/controls/engines/engine/cutoff-switch") == 1) and ((getprop("/controls/engines/engine/cutoff-switch") == 0))){
				me.eng1_shut.trigger();
			} else {
				me.eng1_shut.deactivate();
			}	
			
			if ((getprop("/position/altitude-agl-ft") >= 400) and (getprop("/controls/engines/engine/cutoff-switch") == 0) and ((getprop("/controls/engines/engine/cutoff-switch") == 1))){
				me.eng2_shut.trigger();
			} else {
				me.eng2_shut.deactivate();
			}	
			
			if ((getprop("/hydraulics/blue/pressure-psi") < 1400) and (getprop("/hydraulics/yellow/pressure-psi") < 1400) and (getprop("/hydraulics/green/pressure-psi") < 1400)){
				me.hydall.trigger();
			} else {
				me.hydall.deactivate();
			}	
			
			if ((getprop("/hydraulics/blue/pressure-psi") < 1400) and (getprop("/hydraulics/yellow/pressure-psi") < 1400) and (getprop("/hydraulics/green/pressure-psi") >= 1400)){
				me.hydby.trigger();
			} else {
				me.hydby.deactivate();
			}	
			
			if ((getprop("/hydraulics/blue/pressure-psi") < 1400) and (getprop("/hydraulics/yellow/pressure-psi") >= 1400) and (getprop("/hydraulics/green/pressure-psi") < 1400)){
				me.hydbg.trigger();
			} else {
				me.hydbg.deactivate();
			}	
			
			if ((getprop("/hydraulics/blue/pressure-psi") >= 1400) and (getprop("/hydraulics/yellow/pressure-psi") < 1400) and (getprop("/hydraulics/green/pressure-psi") < 1400)){
				me.hydgy.trigger();
			} else {
				me.hydgy.deactivate();
			}	
			
			if ((getprop("/hydraulics/blue/pressure-psi") < 1400) and (getprop("/hydraulics/yellow/pressure-psi") >= 1400) and (getprop("/hydraulics/green/pressure-psi") >= 1400)){
				me.hydb.trigger();
			} else {
				me.hydb.deactivate();
			}	
			
			if ((getprop("/hydraulics/blue/pressure-psi") >= 1400) and (getprop("/hydraulics/yellow/pressure-psi") < 1400) and (getprop("/hydraulics/green/pressure-psi") >= 1400)){
				me.hydy.trigger();
			} else {
				me.hydy.deactivate();
			}	
			
			if ((getprop("/hydraulics/blue/pressure-psi") >= 1400) and (getprop("/hydraulics/yellow/pressure-psi") >= 1400) and (getprop("/hydraulics/green/pressure-psi") < 1400)){
				me.hydg.trigger();
			} else {
				me.hydg.deactivate();
			}
			
			if ((getprop("hydraulics/control/ptu") == 0) and (math.abs(getprop("/hydraulics/yellow/pressure-psi") - getprop("/hydraulics/green/pressure-psi")) > 500)){
				me.ptu_fault.trigger();
			} else {
				me.ptu_fault.deactivate();
			}
			
			if ((getprop("/consumables/fuel/tank[2]/level-kg") < 3000) and (getprop("/consumables/fuel/tank[4]/level-kg") >= 3000)){
				me.fuel_1lo.trigger();
			} else {
				me.fuel_1lo.deactivate();
			}
			
			if ((getprop("/consumables/fuel/tank[2]/level-kg") >= 3000) and (getprop("/consumables/fuel/tank[4]/level-kg") < 3000)){
				me.fuel_2lo.trigger();
			} else {
				me.fuel_2lo.deactivate();
			}
			
			if (getprop("/consumables/fuel/tank[3]/level-kg") < 3000){
				me.fuel_clo.trigger();
			} else {
				me.fuel_clo.deactivate();
			}
			
			if ((getprop("/consumables/fuel/tank[2]/level-kg") < 3000) and (getprop("/consumables/fuel/tank[4]/level-kg") < 3000)){
				me.fuel_wlo.trigger();
			} else {
				me.fuel_wlo.deactivate();
			}
			
			if ((getprop("controls/fuel/x-feed") != 1) and (math.abs(getprop("/consumables/fuel/tank[2]/level-kg") - getprop("/consumables/fuel/tank[4]/level-kg")) > 1000)){
				me.fuel_bal.trigger();
			} else {
				me.fuel_bal.deactivate();
			}
			
			if ((getprop("/controls/electric/APU-generator") == 1) and (getprop("/engines/apu/rpm") < 95)){
				me.apugen_fault.trigger();
			} else {
				me.apugen_fault.deactivate();
			}
			
			if (((getprop("/controls/electric/engine/generator") == 1) and (getprop("/controls/engines/engine/cutoff"))) and ((getprop("/controls/electric/engine[1]/generator") != 1) or (getprop("/controls/engines/engine[1]/cutoff")!= 1))){
				me.gen1_fault.trigger();
			} else {
				me.gen1_fault.deactivate();
			}
			
			if (((getprop("/controls/electric/engine/generator") != 1) or (getprop("/controls/engines/engine/cutoff") != 1)) and ((getprop("/controls/electric/engine[1]/generator") == 1) and (getprop("/controls/engines/engine[1]/cutoff")))){
				me.gen2_fault.trigger();
			} else {
				me.gen2_fault.deactivate();
			}
			
			if (((getprop("/controls/electric/engine/generator") == 1) and (getprop("/controls/engines/engine/cutoff"))) and ((getprop("/controls/electric/engine[1]/generator") == 1) and (getprop("/controls/engines/engine[1]/cutoff")))){
				me.emer_conf.trigger();
			} else {
				me.emer_conf.deactivate();
			}
			
			if ((getprop("/flight-management/control/ap1-master") == "off") and (getprop("/flight-management/control/ap2-master") == "off") and (((getprop("/position/altitude-agl-ft") > 400) and (getprop("/velocities/vertical-speed-fps") < -5)) or ((getprop("/position/altitude-agl-ft") > 10000) and (getprop("/velocities/vertical-speed-fps") > 5)))){
				me.ap_off.trigger();
			} else {
				me.ap_off.deactivate();
			}
			
			if ((getprop("/flight-management/a-thrust") == "off") and (getprop("/position/altitude-agl-ft") > 400)){
				me.athr_off.trigger();
			} else {
				me.athr_off.deactivate();
			}
			
			me.updateECAM();
    	
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

setlistener("sim/signals/fdm-initialized", func {
	state_loop.init();
});

setlistener("sim/signals/fdm-initialized", func {
	warning_system.init();
	memo_system.init()
});
