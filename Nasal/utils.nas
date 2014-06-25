var posToTower = func (){
    var i = airportinfo();
    var twr = i.tower();
    var lat = twr.lat;
    var lon = twr.lon;
    setprop('position/latitude-deg', lat);
    setprop('position/longitude-deg', lon);
}

var printTowerPos = func (){
    var i = airportinfo();
    var twr = i.tower();
    var lat = twr.lat;
    var lon = twr.lon;
    print("Tower position (" ~ i.id  ~ ")");
    print("Lat: " ~ lat);
    print("Lon: " ~ lon);
}

var clickSound = func(n){
    if (getprop("sim/freeze/replay-state"))
        return;
    var propName = "sim/sound/click"~n;
    setprop(propName,1);
    settimer(func { setprop(propName,0) },0.4);
}

var fastStartUp = func(){
    systems.startup();
    setprop('controls/flight/flaps',0.596);
    while (getprop("consumables/fuel/total-fuel-kg") < 45812) {
        setprop("/consumables/fuel/tank[1]/level-kg", getprop("/consumables/fuel/tank[1]/level-kg") + 5);
        setprop("/consumables/fuel/tank[2]/level-kg", getprop("/consumables/fuel/tank[2]/level-kg") + 20);
        setprop("/consumables/fuel/tank[3]/level-kg", getprop("/consumables/fuel/tank[3]/level-kg") + 35);
        setprop("/consumables/fuel/tank[4]/level-kg", getprop("/consumables/fuel/tank[4]/level-kg") + 20);
        setprop("/consumables/fuel/tank[5]/level-kg", getprop("/consumables/fuel/tank[5]/level-kg") + 5);
    }
    setprop('services/chokes/left', 0);
    setprop('services/chokes/right', 0);
    setprop('services/chokes/nose', 0);
    setprop('services/ext-pwr/enable', 0);
    setprop('/controls/gear/tiller-enabled', 1);
}

var test_nd_symbol = func(symbol, dist_nm){
    var prop = "instrumentation/nd/symbols/"~symbol;
    if(dist_nm == 0){
        setprop(prop,'');
    } else {
        if (getprop("/autopilot/route-manager/active")){
            var f= flightplan(); 
            var point = f.pathGeod(0, dist_nm);
            setprop(prop ~ "/latitude-deg", point.lat); 
            setprop(prop ~ "/longitude-deg", point.lon);
        } 
    }
    var rt = 'autopilot/route-manager/route/';
    var n = getprop(rt~'num');
    if(n != nil and n != 0){
        var bearing = 0;
        var idx = 0;
        for(idx = 0; idx < n; idx += 1){
            var wp = rt~'wp['~idx~']';
            var dist = getprop(wp~'/distance-along-route-nm');
            if(dist >= dist_nm){
                break;
            }
            bearing = getprop(wp~'/leg-bearing-true-deg');
        }
        setprop(prop~'/bearing-deg', bearing);
    }

    setprop('instrumentation/efis/nd/current-'~symbol, dist_nm);
}
