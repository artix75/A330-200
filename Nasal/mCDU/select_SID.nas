var gps = "/instrumentation/gps/";

var dep = "/flight-management/procedures/sid/";

setprop(dep~ "active-sid/name", "------");

var sid = {

	select_arpt : func(icao) {
		
		me.DepICAO = procedures.fmsDB.new(icao);
		
		# Get a list of all available runways on the departure airport
		
        var info = airportinfo(icao);
        if (info == nil){
            setprop(dep~ "runway", '');
            me.update_rwys();
            return;
        }

        var runways = keys(info.runways);
        var rwy_count = size(runways);

        for(var rwy_index = 0; rwy_index < rwy_count; rwy_index += 1) {
            var rwy_name = runways[rwy_index];
            var rwy = info.runways[rwy_name];

            setprop(dep~ "runway[" ~ rwy_index ~ "]/id", rwy.id);

            setprop(dep~ "runway[" ~ rwy_index ~ "]/crs", int(rwy.heading));

            setprop(dep~ "runway[" ~ rwy_index ~ "]/length-m", int(rwy.length));

            setprop(dep~ "runway[" ~ rwy_index ~ "]/width-ft", rwy.width * globals.M2FT);

            var ils = rwy.ils;
            if (ils != nil){
                var ils_frq = ils.frequency;
                if(ils_frq == nil) ils_frq = 0; 
                ils_frq = ils_frq / 100;
                setprop(dep~ "runway[" ~ rwy_index ~ "]/ils-frequency-mhz", ils_frq);
            } else {
                setprop(dep~ "runway[" ~ rwy_index ~ "]/ils-frequency-mhz", 0);
            }

        }
		
		setprop(dep~ "runways", rwy_index);
		
		setprop("/instrumentation/mcdu/page", "RWY_SEL");
		
		setprop(dep~ "first", 0);
		
		setprop(dep~ "selected-rwy", "---");
		
		setprop(dep~ "selected-sid", "-------");
		
		me.update_rwys();
	
	},
	
	select_rwy : func(id) {
	
		me.SIDList = me.DepICAO.getSIDList(id);
		me.SIDmax = size(me.SIDList);
		
		for(var sid_index = 0; sid_index < me.SIDmax; sid_index += 1) {
		
			setprop(dep~ "sid[" ~ sid_index ~ "]/id", me.SIDList[sid_index].wp_name);
		
		}
		
		setprop(dep~ "selected-rwy", id);
		
		setprop(dep~ "sids", me.SIDmax);
		
		setprop("/instrumentation/mcdu/page", "SID_SEL");
		
		setprop(dep~ "first", 0);
		
		setprop("/autopilot/route-manager/departure/runway", id);
		
		me.update_sids();
		var fp = flightplan();
		var sz = fp.getPlanSize();
		for(var i = 0; i < sz; i += 1){
			var wp = fp.getWP(i);
			if(wp.wp_role == 'sid' and wp.wp_type != 'runway')
				fp.deleteWP(wp);
		}
	
	},
	
	select_sid : func(n) {
	
		setprop(dep~ "selected-sid", me.SIDList[n].wp_name);
		
		setprop("/instrumentation/mcdu/page", "SID_CONFIRM");
		
		setprop(dep~ "sid-index", n);
	
	},
	
	confirm_sid : func(n) {
                
		var fp = flightplan();
		me.WPmax = size(me.SIDList[n].wpts);
		var skipped = 0;
		for(var wp = 0; wp < me.WPmax; wp += 1) {
		
			# Copy waypoints to property tree
			var sid_wp = me.SIDList[n].wpts[wp];
			
			setprop(dep~ "active-sid/wp[" ~ wp ~ "]/name", sid_wp.wp_name);
			
			setprop(dep~ "active-sid/wp[" ~ wp ~ "]/latitude-deg", sid_wp.wp_lat);
			
			setprop(dep~ "active-sid/wp[" ~ wp ~ "]/longitude-deg", sid_wp.wp_lon);
			
			setprop(dep~ "active-sid/wp[" ~ wp ~ "]/alt_cstr", sid_wp.alt_cstr);
			
			# Insert waypoints into Route Manager After Departure (INDEX = 0)
			
			#	setprop("/autopilot/route-manager/input", "@INSERT" ~ (wp + 1) ~ ":" ~ sid_wp.wp_lon ~ "," ~ sid_wp.wp_lat ~ "@" ~ sid_wp.alt_cstr);
			var wp_idx = (wp + 1) - skipped;
			var wpt = insert_procedure_wp('sid', sid_wp, wp_idx);
			if(wpt == nil) skipped += 1;
		
		}
        if (me.SIDList[n].wp_name == 'DEFAULT'){
            setprop('/autopilot/route-manager/departure/sid', 'DEFAULT'); 
            setprop(dep~ "active-sid/name", 'DEFAULT');
        } else {
            setprop(dep~ "active-sid/name", me.SIDList[n].wp_name);
        }
		
		
		setprop("/flight-management/procedures/sid-current", 0);
		setprop("/flight-management/procedures/sid-transit", me.WPmax);
		
		setprop("/instrumentation/mcdu/page", "f-pln");
		
		mcdu.f_pln.update_disp();
	
	},
	
	# The below functions will be to update mCDU display pages based on DEPARTURE
	
	update_rwys : func() {
	
		var first = getprop(dep~ "first"); # FIRST RWY
		
		for(var l = 0; l <= 3; l += 1) {
		
			if ((first + l) < getprop(dep~ "runways")) {
		
				setprop(dep~ "rwy-disp/line[" ~ l ~ "]/id", getprop(dep~ "runway[" ~ (first + l) ~ "]/id"));
			
				setprop(dep~ "rwy-disp/line[" ~ l ~ "]/crs", getprop(dep~ "runway[" ~ (first + l) ~ "]/crs"));
			
				setprop(dep~ "rwy-disp/line[" ~ l ~ "]/length-m", getprop(dep~ "runway[" ~ (first + l) ~ "]/length-m"));
			
				setprop(dep~ "rwy-disp/line[" ~ l ~ "]/width-ft", getprop(dep~ "runway[" ~ (first + l) ~ "]/width-ft"));
				setprop(dep~ "rwy-disp/line[" ~ l ~ "]/ils-frequency-mhz", getprop(dep~ "runway[" ~ (first + l) ~ "]/ils-frequency-mhz"));
				
			} else {
			
				setprop(dep~ "rwy-disp/line[" ~ l ~ "]/id", "---");
			
				setprop(dep~ "rwy-disp/line[" ~ l ~ "]/crs", "---");
			
				setprop(dep~ "rwy-disp/line[" ~ l ~ "]/length-m", "----");
			
				setprop(dep~ "rwy-disp/line[" ~ l ~ "]/width-ft", "");
				setprop(dep~ "rwy-disp/line[" ~ l ~ "]/ils-frequency-mhz", "");
			
			}
		
		}
	
	},
	
	update_sids: func() {
	
		var first = getprop(dep~ "first"); # FIRST SID
		
		for(var l = 0; l <= 3; l += 1) {
		
			if ((first + l) < getprop(dep~ "sids")) {
		
				setprop(dep~ "sid-disp/line[" ~ l ~ "]/id", getprop(dep~ "sid[" ~ (first + l) ~ "]/id"));
				
			} else {
			
				setprop(dep~ "sid-disp/line[" ~ l ~ "]/id", "------");
			
			}
		
		}
	
	}

};
