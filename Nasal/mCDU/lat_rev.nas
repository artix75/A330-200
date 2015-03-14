var mcdu_tree = "/instrumentation/mcdu/";
var lr_tree = mcdu_tree~ "lat_rev/";
var f_pln_disp = "/instrumentation/mcdu/f-pln/disp/";

var fpln_tree = "/flight-management/f-pln/";

var lat_rev = {
	tmpy_fplan: nil,
	revise : func (id) {
		#me.tmpy_fplan = nil;
		me.route_manager = fmgc.RouteManager;
		var fp = f_pln.get_current_flightplan();
		setprop(mcdu_tree~ "page", "lat_rev");
		
		setprop(lr_tree~ "name", getprop(rm_route~ "route/wp[" ~ id ~ "]/id"));
		
		setprop(lr_tree~ "id", id);
		
		var wp = fp.getWP(id);
		var wp_lat = wp.wp_lat;#getprop(rm_route~ "route/wp[" ~ id ~ "]/latitude-deg");
		
		var wp_lon = wp.wp_lon;#getprop(rm_route~ "route/wp[" ~ id ~ "]/longitude-deg");
		
		var wp_pos_str = me.pos_str(wp_lat, wp_lon);
		
		setprop(lr_tree~ "pos-string", wp_pos_str);
		
		if (id == 0)
			setprop(lr_tree~ "dep", 1);
		else
			setprop(lr_tree~ "dep", 0);
	
		setprop(lr_tree~ "arr", 0);
	
	},
	copy_to_tmpy: func(){
		me.tmpy_fplan = me.route_manager.createTemporaryFlightPlan();
		setprop(f_pln_disp~ 'current-flightplan', 'temporary');
		f_pln.update_disp();
	},
	revise_dest : func {
		var fp = f_pln.get_current_flightplan();
		setprop(mcdu_tree~ "page", "lat_rev");
		
		setprop(lr_tree~ "name", getprop(f_pln_disp~ "destination"));
		
		var num = getprop(rm_route~ "route/num");
		
		#var last_id = num - 1;
		var wp = f_pln.get_destination_wp();
		if(wp == nil){
			var last_id = fp.getPlanSize() - 1;
			wp = fp.getWP(last_id);
		}
		var wp_lat = wp.wp_lat;#getprop(rm_route~ "route/wp[" ~ last_id ~ "]/latitude-deg");
		
		var wp_lon = wp.wp_lon;#getprop(rm_route~ "route/wp[" ~ last_id ~ "]/longitude-deg");
		
		var wp_pos_str = me.pos_str(wp_lat, wp_lon);
		
		setprop(lr_tree~ "pos-string", wp_pos_str);
		
		setprop(lr_tree~ "arr", 1);
		
		setprop(lr_tree~ "dep", 0);
	
	},
	
	pos_str : func (wp_lat, wp_lon) {
	
		var wp_lat_abs = math.abs(wp_lat);
		
		var wp_lon_abs = math.abs(wp_lon);
		
		var wp_lat_l = "";
		
		var wp_lon_l = "";
		
		if (wp_lat >= 0)
			wp_lat_l = "N";
		else
			wp_lat_l = "S";
			
		if (wp_lon >= 0)
			wp_lon_l = "E";
		else
			wp_lon_l = "W";
			
		var wp_lat_int = int(wp_lat_abs);
		
		var wp_lon_int = int(wp_lon_abs);
		
		var wp_lat_dec = int(int(wp_lat_abs * 100000) - (wp_lat_int * 100000));
		
		var wp_lon_dec = int(int(wp_lon_abs * 100000) - (wp_lon_int * 100000));
		
		var wp_pos_str = wp_lat_int ~ "*" ~ wp_lat_dec ~ wp_lat_l ~ "/" ~ wp_lon_int ~ "*" ~ wp_lon_dec ~ wp_lon_l;
		
		return wp_pos_str;
	
	},
	
	new_dest : func (id, name) {
		var apt = airportinfo(name);
		if(apt != nil){
			var fpId = nil;
			var actv = getprop('autopilot/route-manager/active');
			if(actv and me.tmpy_fplan == nil){
				me.copy_to_tmpy();
				fpId = 'temporary';
			}
			me.route_manager.deleteWaypointsAfter(id, fpId);
			var fp = me.route_manager.getFlightPlan(fpId);
			fp.destination = apt;
			var wp = fp.getWP(id);
			if(wp != nil) me.route_manager.setDiscontinuity(wp.id, fpId);
			me.route_manager.trigger(me.route_manager.SIGNAL_FP_EDIT);
			setprop(f_pln_disp~ 'current-flightplan', getprop(f_pln_disp~ 'current-flightplan'));
		}
	
	},
	next_wp : func (id, name) {
		var actv = getprop('autopilot/route-manager/active');
		var fpId = nil;
		if(actv and me.tmpy_fplan == nil){
			me.copy_to_tmpy();
			fpId = 'temporary';
		}
		#setprop(rm_route~ "input", "@INSERT" ~ (id + 1) ~ ":" ~ name);
		
		#setprop(rm_route~ "route/wp[" ~ (id + 1) ~ "]/ias-mach", 0);
		var new_id = id + 1;
		var existing = me.route_manager.findWaypointByID(name, fpId);
		if(existing != nil){
			var existing_idx = existing.index;
			var wpt_count = existing_idx - new_id;
			me.route_manager.deleteWaypoints(new_id, wpt_count, fpId);
			new_id = existing_idx;
		} else {
			var wp = me.create_wp(name);
			if(wp == nil){
				return id;
			}
			me.route_manager.insertWP(wp, new_id, fpId);
			var dest_idx = me.route_manager.destination_idx;
			if(new_id > dest_idx){
				me.route_manager.update();
				wp = me.tmpy_fplan.getWP(new_id);
				wp.wp_role = 'missed';
			}
		}
		return new_id;
	},
	
	rm_wp : func (id) {
		var actv = getprop('autopilot/route-manager/active');
		if(actv and me.tmpy_fplan == nil){
			me.copy_to_tmpy();
		}
		me.route_manager.deleteWP(id, f_pln.get_flightplan_id());
	
	},
	
	create_wp: func(wp_id){
		if(wp_id == nil or string.trim(wp_id) == '') return nil;
		setprop('instrumentation/gps/scratch/query', wp_id);
		setprop('instrumentation/gps/scratch/type', '');
		setprop('instrumentation/gps/command', 'search');
		var results = getprop('instrumentation/gps/scratch/result-count');
		if(!results) return nil;
		var lat = getprop('instrumentation/gps/scratch/latitude-deg');
		var lon = getprop('instrumentation/gps/scratch/longitude-deg');
		var type = getprop('instrumentation/gps/scratch/type');
		var wp_pos = {
			lat: lat,
			lon: lon
		};
		var wp = createWP(wp_pos, wp_id);
		if(type == 'fix' or type == 'vor' or type == 'ndb' or type == 'dme')
			type = 'navaid';
		wp.wp_type = type;
		return wp;
	}
	
	# Holding is managed separately
 
};
