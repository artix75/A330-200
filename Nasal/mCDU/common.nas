var clear_inp = func {

	setprop("/instrumentation/mcdu/input", "");

};

var insert_procedure_wp = func(type, proc_wp, idx){
	var fp = flightplan();
	var lat = num(string.trim(proc_wp.wp_lat));
	var lon = num(string.trim(proc_wp.wp_lon));
	if((lat == 0 and lon == 0) or 
		(math.abs(lat) > 90) or 
		(math.abs(lon) > 180) or 
		(proc_wp.wp_type == 'Intc') or 
		(proc_wp.wp_type == 'Hold')) {
		return nil;
	}
	var wp_pos = {
		lat: lat,
		lon: lon
	};
	var wpt = createWP(wp_pos, proc_wp.wp_name, type);
	#wpt.wp_role = 'sid';
	print('Insert '~type~' WP '~proc_wp.wp_name ~ ' at ' ~ idx);
	fp.insertWP(wpt, idx);
	wpt = fp.getWP(idx);
	if(proc_wp.alt_cstr_ind)
		wpt.setAltitude(proc_wp.alt_cstr, 'at');
	if(proc_wp.spd_cstr_ind)
		wpt.setSpeed(proc_wp.spd_cstr, 'at');
	var fly_type = string.lc(string.trim(proc_wp.fly_type));
	if(fly_type == 'fly-over'){
		wpt.fly_type = 'flyOver';
	}
	return wpt;
}

var get_destination_wp = func(){
	var f= flightplan(); 
	var numwp = f.getPlanSize();
	var lastidx = numwp - 1;
	var wp_info = nil;
	for(var i = lastidx; i >= 0; i = i - 1){
		var wp = f.getWP(i);
		if(wp != nil){
			var role = wp.wp_role;
			var type = wp.wp_type;
			if(role == 'approach' and type == 'runway'){
				wp_info = {
					index: wp.index,
					id: wp.id
				};
				break;
			}
		}
	}
	return wp_info;
}