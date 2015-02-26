var RouteManager = {
    init: func(){
        me.listeners = [];
        me.reset();
        me.update();
        me;
    },
    update: func(){
        var fp = flightplan();
        if(fp == nil) return;
        me.flightplan = fp;
        me.wp_count = fp.getPlanSize();
        me.total_wp_count = me.wp_count;
        me.active = getprop('autopilot/route-manager/active');
        if(me.wp_count >= 2){
            me.last_idx = me.wp_count - 1;
            me.destination_wp = nil;
            for(var i = me.last_idx; i >= 0; i = i - 1){
                var wp = fp.getWP(i);
                if(wp != nil){
                    var role = wp.wp_role;
                    var type = wp.wp_type;
                    if(role == 'approach' and type == 'runway'){
                        me.destination_wp = wp;
                        break;
                    }
                }
            }
            if(me.destination_wp == nil)
                me.destination_wp = fp.getWP(me.last_idx);
            me.destination_idx = me.destination_wp.index;
            me.missed_approach_planned = (me.last_idx > me.destination_idx);
            me.current_wp = fp.currentWP();
            if(me.current_wp != nil)
                me.current_wp_idx = me.current_wp.index;

            me.total_distance_nm = getprop("autopilot/route-manager/total-distance");
            me.distance_nm = me.total_distance_nm;
            if(me.missed_approach_planned){
                me.missed_approach_active = (me.current_wp_idx > me.destination_idx);
                me.distance_nm = me.destination_wp.distance_along_route;
                me.missed_approach = {
                    distance_nm: (me.total_distance_nm - me.distance_nm),
                    wp_count: (me.wp_count - 1 - me.destination_idx),
                    first_wp: fp.getWP(me.destination_idx + 1)
                };
                me.wp_count -= me.missed_approach.wp_count;
            } else {
                me.missed_approach_active = 0;
            }
        }
    },
    reset: func(){
        me.flightplan = nil;
        me.wp_count = 0;
        me.total_wp_count = 0;
        me.last_idx = 0;
        me.destination_wp = nil;
        me.destination_idx = 0;
        me.missed_approach_planned = 0;
        me.missed_approach_active = 0;
        me.missed_approach = nil;
        me.current_wp = nil;
        me.current_wp_idx = 0;
        me.total_distance_nm = -9999;
        me.distance_nm = me.total_distance_nm;
        me.temporary_flightplan = nil;
        me.secondary_flightplan = nil;
        foreach(var listener; me.listeners){
            removelistener(listener);
        }
        me.listeners = [];
        me.listen('autopilot/route-manager/signals/edited');
        me.listen('autopilot/route-manager/active');
        me.listen('autopilot/route-manager/current-wp');
        me.listen("autopilot/route-manager/total-distance");
    },
    getRemainingNM: func(){
        var remaining_nm = getprop("autopilot/route-manager/distance-remaining-nm");
        if(me.missed_approach_planned){
            remaining_nm -= me.missed_approach.distance_nm;
        }
        return remaining_nm;
    },
    createTemporaryFlightPlan: func(){
        me.update();
        me.temporary_flightplan = me.flightplan.clone();
        return me.temporary_flightplan;
    },
    createSecondaryFlightPlan: func(empty = 0){
        me.update();
        me.secondary_flightplan = me.flightplan.clone();
        if(empty) {
            #me.secondary_flightplan.cleanPlan();
            while(me.secondary_flightplan.getPlanSize())
                me.secondary_flightplan.deleteWP(0);
        }
        return me.secondary_flightplan;
    },
    allFlightPlans: func(){
        return {
            current: me.flightplan,
            temporary: me.temporary_flightplan,
            secondary: me.secondary_flightplan
        };
    },
    getFlightPlan: func(fplan = nil){
        if(fplan == nil) fplan = 'current';
        var all_plans = me.allFlightPlans();
        if(!contains(all_plans, fplan)) return nil;
        return all_plans[fplan];
    },
    getWP: func(idx, fplan = nil){
        var plan = me.getFlightPlan(fplan);
        if(plan == nil) return nil;
        return plan.getWP(idx);
    },
    listen: func(prop){
        var _me = me;
        append(me.listeners, setlistener(prop, func _me.update()));
    },
    dump: func(){
        var dump_bool = func(val) (val ? 'true' : 'false');
        var dump_wp = func(wp){
            if(wp == nil) return 'nil';
            return  "\n   ID: "~ wp.id~
                    "\n   Name: "~wp.wp_name;
        };
        var dump_missed_approach = func(){
            if(me.missed_approach == nil)
                return 'nil';
            var first_wp = me.missed_approach.first_wp;
            return  "\n   distance_nm: " ~ me.missed_approach.distance_nm ~
                    "\n   wp_count: " ~ me.missed_approach.wp_count ~ 
                    "\n   first_wp: [" ~ first_wp.index ~"] " ~  first_wp.id;
        };
        print('active: ', dump_bool(me.active));
        print('wp_count: ', me.wp_count);
        print('last_idx: ', me.last_idx);
        print('current_wp: ', dump_wp(me.current_wp));
        print('current_wp_idx: ', me.current_wp_idx);
        print('destination_wp: ', dump_wp(me.destination_wp));
        print('destination_idx: ', me.destination_idx);
        print('missed_approach_planned: ', dump_bool(me.missed_approach_planned));
        print('missed_approach_active: ', dump_bool(me.missed_approach_active));
        print('total_distance_nm: ', me.total_distance_nm);
        print('distance_nm: ', me.distance_nm);
        print('remaining_nm: ',me.getRemainingNM());
        #print('remaining_total_nm: ', me.remaining_total_nm);
        print('missed_approach: ', dump_missed_approach());
    }
};

setlistener("sim/signals/fdm-initialized", func(){
    RouteManager.init();
    print("FMGC Route Manager Initialized");
});

