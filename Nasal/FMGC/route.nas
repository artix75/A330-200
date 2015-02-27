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
        me.plans['current'] = fp;
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
        me.plans = {};
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
    createFlightPlan: func(planId, src = nil, empty = 0){
        me.update();
        if(planId == 'current' or string.trim(planId) == ''){
            print('RouteManager -> createFlightPlan: cannot create current fp.');
            return;
        }
        if(src == nil) src = me.flightplan;
        var fp = src.clone();
        if(empty){
            me.clearFlightPlan(fp);
        }
        me.plans[planId] = fp;
        me.trigger('edited', 'fp-created');
        return fp;
    },
    createTemporaryFlightPlan: func(){
        var fp = me.createFlightPlan('temporary');
        me.trigger('tmpy-created');
        return fp;
    },
    createSecondaryFlightPlan: func(empty = 0){
        var fp = me.createFlightPlan('secondary', nil, empty);
        me.trigger('sec-created');
        return fp;
    },
    clearFlightPlan: func(fp = nil){
        if(fp == nil)
            fp = me.flightplan;
        elsif(typeof(fp) == 'scalar')
            fp = me.getFlightPlan(fp);
        if(fp == nil){
            print('RouteManager -> clearFlightPlan: no flightplan.');
            return;
        }
        me.trigger('before-fp-clear');
        while(fp.getPlanSize())
            fp.deleteWP(0);
        me.trigger('edited', 'fp-clear');
    },
    copyToActiveFlightPlan: func(fp, delete_src = 0){
        if(fp == nil) {
            print('RouteManager -> copyToActiveFlightPlan: no flightplan.');
            return;
        }
        var fpId = nil;
        if(typeof(fp) == 'scalar'){
            fpId = fp;
            fp = me.getFlightPlan(fp);
        }
        if(fp == nil){
            print('RouteManager -> copyToActiveFlightPlan: no flightplan.');
            return;
        }
        me.trigger('before-fp-copy');
        me.clearFlightPlan();
        var sz = fp.getPlanSize();
        var dest = me.flightplan;
        for(var i = 0; i < sz; i += 1){
            var wp = fp.getWP(i);
            dest.appendWP(wp);
        }
        if(delete_src and fpId != nil){
            me.deleteFlightPlan(fpId);
        }
        me.trigger('edited', 'fp-copy');
    },
    deleteFlightPlan: func(fpId){
        if(fpId == 'current'){
            print('RouteManager -> deleteFlightPlan: cannot delete current fp.');
            return;
        }
        me.trigger('before-fp-del');
        me.plans[fpId] = nil;
        me.trigger('edited', 'fp-del');
    },
    allFlightPlans: func(){
        me.update();
        me.plans;
    },
    getFlightPlan: func(fpId = nil){
        if(fpId == nil) return me.flightplan;#fpId = 'current';
        var all_plans = me.allFlightPlans();
        if(!contains(all_plans, fpId)) return nil;
        return all_plans[fpId];
    },
    getTemporaryFlightPlan: func(){
        me.getFlightPlan('temporary');
    },
    getSecondaryFlightPlan: func(){
        me.getFlightPlan('secondary');
    },
    getWP: func(idx, fpID = nil){
        var fp = me.getFlightPlan(fpID);
        if(fp == nil) return nil;
        return fp.getWP(idx);
    },
    insertWP: func(wp, idx, fpID = nil){
        var fp = me.getFlightPlan(fpID);
        if(fp == nil){
            print('RouteManager -> insertWP: no flightplan.');
            return;
        }
        fp.insertWP(wp, idx);
        me.trigger('edited', 'fg-edited');
    },
    appendWP: func(wp, idx, fpID = nil){
        var fp = me.getFlightPlan(fpID);
        if(fp == nil){
            print('RouteManager -> appendWP: no flightplan.');
            return;
        }
        fp.appendWP(wp, idx);
        me.trigger('edited', 'fg-edited');
    },
    deleteWP: func(idx, fpID = nil){
        var fp = me.getFlightPlan(fpID);
        if(fp == nil){
            print('RouteManager -> deleteWP: no flightplan.');
            return;
        }
        fp.deleteWP(idx);
        me.trigger('edited', 'fg-edited');
    },
    listen: func(prop){
        var _me = me;
        append(me.listeners, setlistener(prop, func _me.update()));
    },
    trigger: func(signals...){
        foreach(var signal; signals){
            var prp = me.getSignal(signal);
            setprop(prp, '');
        }
    },
    getSignal: func(signal){
        'autopilot/route-manager/signals/rm-' ~ signal;
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
    },
    # CONSTANTS
    SIGNAL_EDIT: 'edited',
    SIGNAL_FP_CLEAR: 'fp-clear',
    SIGNAL_FP_COPY: 'fp-copy',
    SIGNAL_FP_CREATED: 'fp-created',
    SIGNAL_FP_DEL: 'fp-del',
    SIGNAL_FP_EDIT: 'fg-edited'
    
};

setlistener("sim/signals/fdm-initialized", func(){
    RouteManager.init();
    print("FMGC Route Manager Initialized");
});

