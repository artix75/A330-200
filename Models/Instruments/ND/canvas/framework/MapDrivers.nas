canvas.RouteDriver = {
    new: func(){
        var m = {
            parents: [canvas.RouteDriver],
        };
        m.init();
        return m;
    },
    init: func(){
        me.update();
    },
    update: func(){
        me.flightplan = flightplan();
    },
    getNumberOfFlightPlans: func(){1},
    getFlightPlanType: func(fpNum){'current'},
    getFlightPlan: func(fpNum){me.flightplan},
    getPlanSize: func(fpNum){me.flightplan.getPlanSize()},
    getWP: func(fpNum, idx){me.flightplan.getWP(idx)},
};

canvas.MultiRouteDriver = {
    parents: [canvas.RouteDriver],
    new: func(){
        var m = {
            parents: [canvas.MultiRouteDriver],
            _flightplans: []
        };
        m.init();
        return m;
    },
    addFlightPlan: func(type, plan){
        append(me._flightplans, {
            type: type,
            flightplan: plan
        });
    },
    getNumberOfFlightPlans: func(){
        size(me._flightplans);
    },
    getFlightPlanType: func(fpNum){
        if(fpNum >= size(me._flightplans)) return nil;
        var fp = me._flightplans[fpNum];
        return fp.type;
    },
    getFlightPlan: func(fpNum){
        if(fpNum >= size(me._flightplans)) return nil;
        return me._flightplans[fpNum];
    },
    getPlanSize: func(fpNum){
        if(fpNum >= size(me._flightplans)) return 0;
        return me._flightplans[fpNum].getPlanSize();
    },
    getWP: func(fpNum, idx){
        if(fpNum >= size(me._flightplans)) return nil;
        var fp = me._flightplans[fpNum].getPlanSize();
        return fp.getWP(idx);
    }
};
