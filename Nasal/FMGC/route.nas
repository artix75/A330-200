var RouteManager = {
    init: func(){
        me.listeners = [];
        me.reset();
        me.update();
        me;
    },
    update: func(fpId = nil){
        if(me.sequencing) return;
        if(fpId != nil and fpId != 'current'){
            me.updateFlighPlan(fpId);
            return;
        }
        var fp = flightplan();
        if(fp == nil) return;
        me.flightplan = fp;
        me.plans['current'] = fp;
        if(me.flightplan_info['current'] == nil)
            me.flightplan_info['current'] = {};
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
            me.flightplan_info['current'].distance_nm = me.distance_nm;
            me.flightplan_info['current'].total_distance_nm = me.total_distance_nm;
        }
    },
    updateFlighPlan: func(fpId){
        if(fpId == nil or fpId == 'current'){
            me.update();
            return;
        }
        var fp = me.getFlightPlan(fpId);
        if(fp == nil) return;
        var fpData = me.flightplan_info[fpId];
        if(fpData == nil){
            fpData = {};
            me.flightplan_info[fpId] = fpData;
        }
        fpData.wp_count = fp.getPlanSize();
        fpData.total_wp_count = me.wp_count;
        if(fpData.wp_count >= 2){
            fpData.last_idx = fpData.wp_count - 1;
            fpData.destination_wp = nil;
            for(var i = fpData.last_idx; i >= 0; i = i - 1){
                var wp = fp.getWP(i);
                if(wp != nil){
                    var role = wp.wp_role;
                    var type = wp.wp_type;
                    if(role == 'approach' and type == 'runway'){
                        fpData.destination_wp = wp;
                        break;
                    }
                }
            }
            if(fpData.destination_wp == nil)
                fpData.destination_wp = fp.getWP(fpData.last_idx);
            fpData.destination_idx = fpData.destination_wp.index;
            fpData.missed_approach_planned = (fpData.last_idx > fpData.destination_idx);

            me._recalcDistance(fpId);
            fpData.distance_nm = fpData.total_distance_nm;
            if(fpData.missed_approach_planned){
                fpData.distance_nm = fpData.destination_wp.distance_along_route;
                fpData.missed_approach = {
                    distance_nm: (fpData.total_distance_nm - fpData.distance_nm),
                    wp_count: (fpData.wp_count - 1 - fpData.destination_idx),
                    first_wp: fp.getWP(fpData.destination_idx + 1)
                };
                fpData.wp_count -= me.missed_approach.wp_count;
            }
        }
    },
    reset: func(){
        me.flightplan = nil;
        me.plans = {};
        me.flightplan_info = {};
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
        me.sequencing = 0;
        me.under_transaction = 0;
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
        } else {
            me.copyFlightPlan(src, fp);
        }
        me.plans[planId] = fp;
        me.flightplan_info[planId] = {};
        if(empty){
            me.flightplan_info[planId].distance_nm = 0;
            me.flightplan_info[planId].total_distance_nm = 0;
        }
        elsif(src == me.flightplan){
            me.flightplan_info[planId].distance_nm = me.distance_nm;
            me.flightplan_info[planId].total_distance_nm = me.total_distance_nm;
        }
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
        if(!me.under_transaction)
            me.sequencing = 1;
        fp.sid = '';
        fp.star = '';
        fp.approach = '';
        while(fp.getPlanSize())
            fp.deleteWP(0);
        if(!me.under_transaction)
            me.sequencing = 0;
        me.trigger('edited', 'fp-clear');
    },
    copyFlightPlan: func(fp, dest_fp){
        if(fp == nil){
            print('RouteManager -> copyFlightPlan: no source flightplan.');
            return;
        }
        if(dest_fp == nil){
            print('RouteManager -> copyFlightPlan: no destination flightplan.');
            return;
        }
        var dep = dest_fp.departure;
        var dst = dest_fp.destination;
        var fpdep = fp.departure;
        var fpdst = fp.destination;
        dep = (dep != nil ? dep.id : '');
        dst = (dst != nil ? dst.id : '');
        fpdep = (fpdep != nil ? fpdep.id : '');
        fpdst = (fpdst != nil ? fpdst.id : '');
        var copy_dep_rwy = 0;
        if(fpdep != dep){
            dest_fp.departure = fp.departure;
            copy_dep_rwy = 1;
        }
        if(!copy_dep_rwy){
            dep = dest_fp.departure_runway;
            fpdep = fp.departure_runway;
            dep = (dep != nil ? dep.id : '');
            fpdep = (fpdep != nil ? fpdep.id : '');
            copy_dep_rwy = (fpdep != dep);
        }
        if(copy_dep_rwy)
            dest_fp.departure_runway = fp.departure_runway;
        var copy_dst_rwy = 0;
        if(fpdst != dst){
            dest_fp.destination = fp.destination;
            copy_dst_rwy = 1;
        }
        if(!copy_dst_rwy){
            dst = dest_fp.destination_runway;
            fpdst = fp.destination_runway;
            dst = (dst != nil ? dst.id : '');
            fpdst = (fpdst != nil ? fpdst.id : '');
            copy_dst_rwy = (fpdst != dst);
        }
        if(copy_dst_rwy)
            dest_fp.destination_runway = fp.destination_runway;
        while(dest_fp.getPlanSize())
            dest_fp.deleteWP(0);
        var sz = fp.getPlanSize();
        for(var i = 0; i < sz; i += 1){
            me._copyWP(fp, dest_fp, i);
        }
    },
    copyFlightPlanToActive: func(fp, delete_src = 0){
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
        me.under_transaction = 1;
        me.sequencing = 1;
        me.copyFlightPlan(fp, me.flightplan);
        if(delete_src and fpId != nil){
            me.deleteFlightPlan(fpId);
        }
        var cur_idx = me._findCurrentWPIndex();
        me.under_transaction = 0;
        me.sequencing = 0;
        me.update();
        me.trigger('edited', 'fp-copy');
        print('RouteManager: setting current wp to '~ cur_idx);
        setprop("/autopilot/route-manager/input", "@JUMP" ~ cur_idx);
    },
    deleteFlightPlan: func(fpId){
        if(fpId == 'current'){
            print('RouteManager -> deleteFlightPlan: cannot delete current fp.');
            return;
        }
        me.trigger('before-fp-del');
        me.plans[fpId] = nil;
        me.flightplan_info[fpId] = nil;
        me.trigger('edited', 'fp-del');
    },
    allFlightPlans: func(){
        me.update();
        me.plans;
    },
    getFlightPlan: func(fpId = nil){
        if(fpId == nil or fpId == '') return me.flightplan;#fpId = 'current';
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
    getWaypoints: func(fpID = nil){
        var fp = me.getFlightPlan(fpID);
        if(fp == nil){
            print('RouteManager -> getWaypoints: no flightplan.');
            return;
        }
        var wpts = [];
        var sz = fp.getPlanSize();
        for(var i = 0; i < sz; i += 1){
            var wp = fp.getWP(i);
            append(wpts, wp);
        }
        return wpts;
    },
    findWaypointByID: func(wpId, fpID = nil){
        var fp = me.getFlightPlan(fpID);
        if(fp == nil){
            print('RouteManager -> findWaypointByID: no flightplan.');
            return;
        }
        var sz = fp.getPlanSize();
        for(var i = 0; i < sz; i += 1){
            var wp = fp.getWP(i);
            if(wp.id == wpId) return wp;
        }
        return nil;
    },
    insertWP: func(wp, idx, fpID = nil){
        var fp = me.getFlightPlan(fpID);
        if(fp == nil){
            print('RouteManager -> insertWP: no flightplan.');
            return;
        }
        fp.insertWP(wp, idx);
        if(fpID != nil and fpID != 'current')
            me._recalcDistance(fpID);
        me.trigger('edited', 'fg-edited');
    },
    appendWP: func(wp, idx, fpID = nil){
        var fp = me.getFlightPlan(fpID);
        if(fp == nil){
            print('RouteManager -> appendWP: no flightplan.');
            return;
        }
        fp.appendWP(wp, idx);
        if(fpID != nil and fpID != 'current')
            me._recalcDistance(fpID);
        me.trigger('edited', 'fg-edited');
    },
    insertWaypoints: func(wpts, idx, fpID = nil){
        var fp = me.getFlightPlan(fpID);
        if(fp == nil){
            print('RouteManager -> insertWaypoints: no flightplan.');
            return;
        }
        fp.insertWaypoints(wpts, idx);
    },
    deleteWP: func(idx, fpID = nil){
        var fp = me.getFlightPlan(fpID);
        if(fp == nil){
            print('RouteManager -> deleteWP: no flightplan.');
            return;
        }
        fp.deleteWP(idx);
        if(fpID != nil and fpID != 'current')
            me._recalcDistance(fpID);
        me.trigger('edited', 'fg-edited');
    },
    deleteWaypoints: func(from, count, fpID = nil){
        var fp = me.getFlightPlan(fpID);
        if(fp == nil){
            print('RouteManager -> deleteWaypoints: no flightplan.');
            return;
        }
        var sz = fp.getPlanSize();
        if(from < 0) from = sz + from;
        if(from >= sz){
            print('RouteManager -> deleteWaypoints: from wpt out of bounds.');
            return;
        }
        var do_seq = 0;
        if(fp == me.flightplan and !me.sequencing){
            do_seq = 1;
            me.sequencing = 1;
        }
        if(count == nil){
            count = sz - from;
        }
        print('RouteManager -> deleteWaypoints: from '~from~', count: '~count);
        while(count){
            if(from >= fp.getPlanSize()) break;
            fp.deleteWP(from);
            count -= 1;
        }
        if(do_seq) me.sequencing = 0;
        me.trigger('edited', 'fg-edited');
    },
    deleteWaypointsAfter: func(wptIdx, fpID = nil){
        me.deleteWaypoints(wptIdx + 1, nil, fpID);
    },
    getDistance: func(fpID, total = 0){
        me.update();
        var info = me.flightplan_info[fpID];
        if(info == nil) return 0;
        var dist = 0;
        if(total)
            dist = info.total_distance_nm;
        else
            dist = info.distance_nm;
        if(dist == nil) dist = 0;
        return dist;
    },
    getDestinationWP: func(fpID = nil){
        if(fpID == nil or fpID == '' or fpID == 'current')
            return me.destination_wp;
        var info = me.flightplan_info[fpID];
        if(info == nil) return nil;
        return info['destination_wp'];
    },
    listen: func(prop){
        var _me = me;
        append(me.listeners, setlistener(prop, func _me.update()));
    },
    trigger: func(signals...){
        if(me.under_transaction) return;
        foreach(var signal; signals){
            var prp = me.getSignal(signal);
            setprop(prp, '');
        }
    },
    getSignal: func(signal){
        'autopilot/route-manager/signals/rm-' ~ signal;
    },
    _findCurrentWPIndex: func(){
        me.update();
        var remaining_nm = getprop("autopilot/route-manager/distance-remaining-nm");
        var my_offset = me.total_distance_nm - remaining_nm;
        var fp = me.flightplan;
        var sz = fp.getPlanSize();
        var idx = 0;
        for(var i = 0; i < sz; i += 1){
            var wp = fp.getWP(i);
            if(wp.distance_along_route > my_offset){
                idx = wp.index;
                break;
            }
        }
        return idx;
    },
    _copyWP: func(from, to, wpIdx, destIdx = -9999){
        if(typeof(from) == 'scalar')
            from = me.getFlightPlan(from);
        if(typeof(to) == 'scalar')
            to = me.getFlightPlan(to);
        if(from == nil){
            print('RouteManager -> _copyWP: missing "from" fp.');
            return nil;
        }
        if(to == nil){
            print('RouteManager -> _copyWP: missing "to" fp.');
            return nil;
        }
        var src_wp = from.getWP(wpIdx);
        if(src_wp == nil){
            print('RouteManager -> _copyWP: wp not found.');
            return nil;
        }
        var dest_wp = nil;
        var type = src_wp.wp_type;
        var role = src_wp.wp_role;
        if(type == 'runway'){
            var rwy = src_wp.runway();
            if(rwy == nil){
                print('RouteManager -> _copyWP: wp runway not found.');
                return nil;
            }
            if(role != nil)
                dest_wp = createWPFrom(rwy, role);
            else 
                dest_wp = createWPFrom(rwy);
        }
        elsif(type == 'navaid') {
            var navaid = src_wp.navaid();
            if(navaid == nil){
                foreach(var navtype; ['fix', 'airport', 'vor', 'ndb', 'dme']){
                    var navaids = navinfo(src_wp.wp_lat, src_wp.wp_lon, navtype, src_wp.id);
                    if(size(navaids) > 0){
                        navaid = navaids[0];
                        break;
                    }
                }
            }
            if(navaid == nil){
                print('RouteManager -> _copyWP: wp navaid not found.');
                return nil;
            }
            if(role != nil)
                dest_wp = createWPFrom(navaid, role);
            else 
                dest_wp = createWPFrom(navaid);
        } else {
            var pos = {
                lat: src_wp.wp_lat,
                lon: src_wp.wp_lon
            };
            if(role != nil)
                dest_wp = createWP(pos, src_wp.id, role);
            else 
                dest_wp = createWP(pos, src_wp.id);
        }
        if(dest_wp == nil){
            print('RouteManager -> _copyWP: failed to clone wp.');
            return nil;
        }
        if(destIdx >= 0){
            to.insertWP(dest_wp, destIdx);
            dest_wp = to.getWP(destIdx);
        } else {
            to.appendWP(dest_wp);
            dest_wp = to.getWP(to.getPlanSize() - 1);
        }
        var fly_type = src_wp.fly_type;
        if(fly_type != nil) dest_wp.fly_type = fly_type;
        var alt_cstr = src_wp.alt_cstr;
        if(alt_cstr != nil){
            var cstr_type = src_wp.alt_cstr_type;
            if(cstr_type == nil) cstr_type = 'at';
            dest_wp.setAltitude(alt_cstr, cstr_type);
        }
        var speed_cstr = src_wp.speed_cstr;
        if(speed_cstr != nil){
            var cstr_type = src_wp.speed_cstr_type;
            if(cstr_type == nil) cstr_type = 'at';
            dest_wp.setSpeed(speed_cstr, cstr_type);
        }
        dest_wp;
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
    _recalcDistance: func(fpId){
        var fp = me.getFlightPlan(fpId);
        if(fp != nil){
            var sz = fp.getPlanSize();
            var dist = 0;
            var total_dist = 0;
            for(var i = 0; i < sz; i += 1){
                var wp = fp.getWP(i);
                var role = wp.wp_role;
                var type = wp.wp_type;
                var is_dest = (role == 'approach' and type == 'runway');
                var leg_dist = wp.leg_distance;
                if(!is_dest)
                    dist += leg_dist;
                total_dist += leg_dist;
            }
            if(me.flightplan_info[fpId] == nil)
                me.flightplan_info[fpId] == {};
            me.flightplan_info[fpId].distance_nm = dist;
            me.flightplan_info[fpId].total_distance_nm = total_dist;
        }
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

