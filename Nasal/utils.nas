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
