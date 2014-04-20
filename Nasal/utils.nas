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
