var A330RouteDriver = {
	parents: [canvas.RouteDriver],
	new: func(){
		var m = {
			parents: [A330RouteDriver],
			plan_wp_info: nil
		};
		m.init();
		return m;
	},
	init: func(){
		me.route_manager = fmgc.RouteManager.init();
		me.fplan_types = [];
		me.plans = {};
		me.update();
	},
	update: func(){
		if(!getprop('autopilot/route-manager/route/num'))
			return;
		me.fplan_types = [];
		me.plans = me.route_manager.allFlightPlans();
		append(me.fplan_types, 'current');
		if(me.plans['temporary'] != nil) append(me.fplan_types, 'temporary');
		if(me.plans['secondary'] != nil) append(me.fplan_types, 'secondary');
		if(me.route_manager.missed_approach_planned)
			append(me.fplan_types, 'missed');
	},
	getNumberOfFlightPlans: func(){
		size(me.fplan_types);
	},
	getFlightPlanType: func(fpNum){
		if(fpNum >= me.getNumberOfFlightPlans()) return nil;
		me.fplan_types[fpNum];
	},
	getFlightPlan: func(fpNum){
		var type = me.getFlightPlanType(fpNum);
		if(type == nil) return nil;
		if(type != 'missed'){
			me.plans[type];
		} else {
			var srcPlan = me.plans.current;
			var fp = srcPlan.clone();
			#fp.cleanPlan();
			while(fp.getPlanSize())
				fp.deleteWP(0);
			var missed_appr = me.route_manager.missed_approach;
			var idx = me.route_manager.destination_idx;
			var size = srcPlan.getPlanSize();
			for(var i = idx; i < size; i += 1){
				var wp = srcPlan.getWP(i);
				fp.appendWP(wp);
			}
			fp;
		}
	},
	getPlanSize: func(fpNum){
		var type = me.getFlightPlanType(fpNum);
		if(type == nil) return 0;
		if(type == 'missed'){
			var missed_approach = me.route_manager.missed_approach;
			missed_approach.wp_count;
		} 
		elsif(type == 'current'){
			me.route_manager.wp_count;
		} else {
			me.plans[type].getPlanSize();
		}
	},
	getWP: func(fpNum, idx){
		var type = me.getFlightPlanType(fpNum);
		if(type == nil) return 0;
		if(type != 'missed'){
			me.plans[type].getWP(idx);
		} else {
			var fp = me.plans['current'];
			var missed_approach = me.route_manager.missed_approach;
			var offset = missed_approach.first_wp.index;
			fp.getWP(offset + idx);
		}
	},
	getPlanModeWP: func(idx){
		if(me.route_manager.sequencing) return me.plan_wp_info;
		var wp = mcdu.f_pln.get_wp(idx);
		if(wp != nil){
			me.plan_wp_info = {
				id: wp.id,
				wp_lat: wp.wp_lat,
				wp_lon: wp.wp_lon
			};
		}
		return wp;
	},
	getListeners: func(){
		var rm = fmgc.RouteManager;
		[
			me.route_manager.getSignal(rm.SIGNAL_FP_COPY),
			me.route_manager.getSignal(rm.SIGNAL_FP_CREATED),
			me.route_manager.getSignal(rm.SIGNAL_FP_DEL),
			me.route_manager.getSignal(rm.SIGNAL_FP_EDIT)
		]
	},
	shouldUpdate: func(){
		!me.route_manager.sequencing;
	},
	hasDiscontinuity: func(fpNum, wptID){
		var type = me.getFlightPlanType(fpNum);
		me.route_manager.hasDiscontinuity(wptID, type);
	}
};