##
# storage container for all ND instances
var nd_display = {};

var update_apl_sym = func {
    if (getprop("/instrumentation/efis/nd/display-mode") == "PLAN"){
        #    setprop("/instrumentation/efis/nd/display-mode","PLAN");
        var loopid = getprop("/instrumentation/efis/nd/plan-mode-loop");
        if(loopid == nil) loopid = 0;
        loopid = loopid + 1;
        if(loopid > 100) loopid = 0;
        setprop("/instrumentation/efis/nd/plan-mode-loop", loopid);
    }

    settimer(update_apl_sym, 2);
}

###
# entry point, this will set up all ND instances

setlistener("sim/signals/fdm-initialized", func() {

    canvas.SymbolLayer.findsym = func(model, del=0) {
        forindex (var i; me.list) {
            var e = me.list[i];
            #print("List["~i~"]");
            #debug.dump(e);
            if (canvas.Symbol.Controller.equals(e.model, model)) {
                if (del) {
                    # Remove this element from the list
                    # TODO: maybe C function for this? extend pop() to accept index?
                    var prev = subvec(me.list, 0, i);
                    var next = subvec(me.list, i+1);
                    me.list = prev~next;
                    #return 1;
                }
                return e;
            }
        }
        return nil;
    };
    
    # to add support for additional ghosts, just append them to the vector below, possibly at runtime:
    var supported_ghosts = ['positioned','Navaid','Fix','flightplan-leg','FGAirport'];
    var is_positioned_ghost = func(obj) {
        var gt = ghosttype(obj);
        foreach(var ghost; supported_ghosts) {
            if (gt == ghost) return 1; # supported ghost was found
        }
        return 0; # not a known/supported ghost
    };
    
    canvas.Symbol.Controller.equals = func(l, r, p=nil) {
        if (l == r) return 1;
        if (p == nil) {
            var ret = canvas.Symbol.Controller.equals(l, r, l);
            if (ret != nil) return ret;
            if (contains(l, "parents")) {
                foreach (var p; l.parents) {
                    var ret = canvas.Symbol.Controller.equals(l, r, p);
                    if (ret != nil) return ret;
                }
            }
            die("Symbol.Controller: no suitable equals() found! Of type: "~typeof(l));
        } else {
            if (typeof(p) == 'ghost')
                if ( is_positioned_ghost(p) )
                    return l.id == r.id;
                else
                    die("Symbol.Controller: bad/unsupported ghost of type '"~ghosttype(l)~"' (see MapStructure.nas Symbol.Controller.getpos() to add new ghosts)");
            if (typeof(p) == 'hash'){
                # Somewhat arbitrary convention:
                #   * l.equals(r)         -- instance method, i.e. uses "me" and "arg[0]"
                #   * parent._equals(l,r) -- class method, i.e. uses "arg[0]" and "arg[1]"
                if (contains(p, "equals"))
                    return l.equals(r);
            }
            if (contains(p, "_equals"))
                return p._equals(l,r);
        }
        return nil; # scio correctum est
    };
    
    canvas.SymbolLayer.onRemoved = func(model) {
        debug.dump(model);
        var sym = me.findsym(model, 1);
        if (sym == nil) die("model not found");
        #print(typeof(model.del));
        #call(func sym.del, nil, var err = []);
        sym.del();
        #print('ERR CHK');
        #debug.dump(err);
        # ignore errors
        # TODO: ignore only missing member del() errors? and only from the above line?
        # Note: die(err[0]) rethrows it; die(err[0]~"") does not.
    }
####### LOAD FILES #######
#print("loading files");
(func {
 var FG_ROOT = getprop("/sim/aircraft-dir");

var load = func(file, name) {
    #print(file);
    if (name == nil)
        var name = split("/", file)[-1];
    if (substr(name, size(name)-4) == ".draw")
    name = substr(name, 0, size(name)-5);
    #print("reading file");
    var code = io.readfile(file);
    #print("compiling file");
    # This segfaults for some reason:
    #var code = call(compile, [code], var err=[]);
    var code = call(func compile(code, file), [code], var err=[]);
    if (size(err)) {
        #print("handling error");
        if (substr(err[0], 0, 12) == "Parse error:") { # hack around Nasal feature
            var e = split(" at line ", err[0]);
            if (size(e) == 2)
            err[0] = string.join("", [e[0], "\n  at ", file, ", line ", e[1], "\n "]);
        }
        for (var i = 1; (var c = caller(i)) != nil; i += 1)
        err ~= subvec(c, 2, 2);
        debug.printerror(err);
        return;
    }
    #print("calling code");
    call(code, nil, nil, var hash = {});
    #debug.dump(keys(hash));
    return hash;
};

var load_deps = func(name) {
    load(FG_ROOT~"/Models/Instruments/ND/map/"~name~".lcontroller",  name);
    load(FG_ROOT~"/Models/Instruments/ND/map/"~name~".symbol", name);
    load(FG_ROOT~"/Models/Instruments/ND/map/"~name~".scontroller", name);
}

foreach( var name; ['APS','ALT-profile'] )
load_deps( name );

})();

##
# configure aircraft specific cockpit/ND switches here
# these are to be found in the property branch you specify
# via the NavDisplay.new() call
# the backend code in navdisplay.mfd should NEVER contain any aircraft-specific
# properties, or it will break other aircraft using different properties
# instead, make up an identifier (hash key) and map it to the property used
# in your aircraft, relative to your ND root in the backend code, only ever
# refer to the handle/key instead via the me.get_switch('toggle_range') method
# which would internally look up the matching aircraft property, e.g. '/instrumentation/efis'/inputs/range-nm'
#
# note: it is NOT sufficient to just add new switches here, the backend code in navdisplay.mfd also
# needs to know what to do with them !
# refer to incomplete symbol implementations to learn how they work (e.g. WXR, STA)

var myCockpit_switches = {
    # symbolic alias : relative property (as used in bindings), initial value, type
    'toggle_range': 	{path: '/inputs/range-nm', value:40, type:'INT'},
    'toggle_weather': 	{path: '/inputs/wxr', value:0, type:'BOOL'},
    'toggle_airports': 	{path: '/inputs/arpt', value:0, type:'BOOL'},
    'toggle_ndb': 	{path: '/inputs/NDB', value:0, type:'BOOL'},
    'toggle_stations':     {path: '/inputs/sta', value:0, type:'BOOL'},
    'toggle_vor': 	{path: '/inputs/VORD', value:0, type:'BOOL'},
    'toggle_cstr': 	{path: '/inputs/CSTR', value:0, type:'BOOL'},
    'toggle_waypoints': 	{path: '/inputs/wpt', value:0, type:'BOOL'},
    'toggle_position': 	{path: '/inputs/pos', value:0, type:'BOOL'},
    'toggle_data': 		{path: '/inputs/data',value:0, type:'BOOL'},
    'toggle_terrain': 	{path: '/inputs/terr',value:0, type:'BOOL'},
    'toggle_traffic': 		{path: '/inputs/tfc',value:0, type:'BOOL'},
    'toggle_centered': 		{path: '/inputs/nd-centered',value:0, type:'BOOL'},
    'toggle_lh_vor_adf':	{path: '/input/lh-vor-adf',value:0, type:'INT'},
    'toggle_rh_vor_adf':	{path: '/input/rh-vor-adf',value:0, type:'INT'},
    'toggle_display_mode': 	{path: '/nd/canvas-display-mode', value:'NAV', type:'STRING'},
    'toggle_display_type': 	{path: '/mfd/display-type', value:'LCD', type:'STRING'},
    'toggle_true_north': 	{path: '/mfd/true-north', value:0, type:'BOOL'},
    'toggle_fplan': {path: '/nd/route-manager-active', value:0, type: 'BOOL'},
    'toggle_lnav': {path: '/nd/lnav', value:0, type: 'BOOL'},
    'toggle_vnav': {path: '/nd/vnav', value:0, type: 'BOOL'},
    'toggle_wpt_idx': {path: '/inputs/plan-wpt-index', value: -1, type: 'INT'},
    'toggle_plan_loop': {path: '/nd/plan-mode-loop', value: 0, type: 'INT'},
    'toggle_app_mode': {path: '/nd/app-mode', value:'', type: 'STRING'},
    'toggle_cur_td': {path: '/nd/current-td', value: 0, type: 'INT'},
    'toggle_cur_tc': {path: '/nd/current-tc', value: 0, type: 'INT'},
    'toggle_cur_sc': {path: '/nd/current-sc', value: 0, type: 'INT'},
    'toggle_cur_ed': {path: '/nd/current-ed', value: 0, type: 'INT'},
    # add new switches here
};

canvas.Symbol.get("FIX").icon_fix = nil;
canvas.Symbol.get("FIX").draw = func{
    if (me.icon_fix != nil) return;
    # the fix symbol
    me.icon_fix = me.element.createChild("path")
    .moveTo(-10,0)
    .lineTo(0,-17)
    .lineTo(10,0)
    .lineTo(0,17)
    .close()
    .setStrokeLineWidth(3)
    .setColor(0.69,0,0.39)
    .setScale(0.8,0.8); # FIXME: do proper LOD handling here - we need to scale according to current texture dimensions vs. original/design dimensions
    # the fix label
    me.text_fix = me.element.createChild("text")
    .setDrawMode( canvas.Text.TEXT )
    .setText(me.model.id)
    .setFont("LiberationFonts/LiberationSans-Regular.ttf")
    .setFontSize(28)
    .setTranslation(20,10);
}

canvas.Symbol.get("VOR").svg_loaded = nil;
canvas.Symbol.get("VOR").draw = func{
    if(me.svg_loaded != nil) return;
    var aircraft_dir = split('/', getprop("/sim/aircraft-dir"))[-1];
    var svg_path = "Aircraft/" ~ aircraft_dir ~ "/Models/Instruments/ND/res/airbus_vor.svg";
    me.element.removeAllChildren();
    var grp = me.element.createChild("group");
    canvas.parsesvg(grp, svg_path);
    grp.setScale(0.8,0.8);
    print("VOR SVG: " ~ svg_path);
    me.text_vor = me.element.createChild("text")
    .setDrawMode( canvas.Text.TEXT )
    .setText(me.model.id)
    .setFont("LiberationFonts/LiberationSans-Regular.ttf")
    .setFontSize(28)
    .setColor(1,1,1)
    .setTranslation(45,25);
    me.svg_loaded = 1;
}

canvas.Symbol.get("NDB").icon_ndb = nil;
canvas.Symbol.get("NDB").draw = func{
    if (me.icon_ndb != nil) return;
    # the fix symbol
    me.icon_ndb = me.element.createChild("path")
    .moveTo(-15,15)
    .lineTo(0,-15)
    .lineTo(15,15)
    .close()
    .setStrokeLineWidth(3)
    .setColor(0.69,0,0.39)
    .setScale(0.8,0.8); # FIXME: do proper LOD handling here - we need to scale according to current texture dimensions vs. original/design dimensions
    # the fix label
    me.text_ndb = me.element.createChild("text")
    .setDrawMode( canvas.Text.TEXT )
    .setText(me.model.id)
    .setFont("LiberationFonts/LiberationSans-Regular.ttf")
    .setFontSize(28)
    .setTranslation(25,10);
}

canvas.draw_apt = func(group, apt, controller=nil, lod=0){
    var lat = apt.lat;
    var lon = apt.lon;
    var name = apt.id;
    # print("drawing nd airport:", name);

    var apt_grp = group.createChild("group", name);

    # FIXME: conditions don't belong here, use the controller hash instead!
    # if (1 or getprop("instrumentation/efis/inputs/arpt")) {
    var aircraft_dir = split('/', getprop("/sim/aircraft-dir"))[-1];
    var svg_path = "Aircraft/" ~ aircraft_dir ~ "/Models/Instruments/ND/res/airbus_airport.svg";
    #me.element.removeAllChildren();
    canvas.parsesvg(apt_grp, svg_path);
    #apt_grp.setScale(0.8,0.8);
    print("VOR SVG: " ~ svg_path);
    var text_apt = apt_grp.createChild("text", name ~ " label")
    .setDrawMode( canvas.Text.TEXT )
    .setTranslation(45,35)
    .setText(name)
    .setFont("LiberationFonts/LiberationSans-Regular.ttf")
    .setColor(1,1,1)
    .setFontSize(28);
    apt_grp.setGeoPosition(lat, lon)
    .set("z-index",1); # FIXME: this needs to be configurable!!
    #}

    # draw routines should always return their canvas group to the caller for further processing

}

canvas.draw_airplane_symbol = func (group, apl, controller=nil, lod=0) {
    var lat = apl.lat;
    var lon = apl.lon;
    var hdg = apl.hdg;

    var aircraft_dir = split('/', getprop("/sim/aircraft-dir"))[-1];
    var airplane_grp = group.getElementById("airplane");
    var apl_path = nil;
    var aplSymbol = nil;
    if(airplane_grp == nil){
        airplane_grp = group.createChild("group","airplane");
        canvas.parsesvg(airplane_grp, "Aircraft/" ~ aircraft_dir ~ "/Models/Instruments/ND/res/airbusAirplane.svg");
        aplSymbol = airplane_grp.getElementById("airplane");
        apl_path = aplSymbol.getElementById("apl_path");
        #aplSymbol.hide();
        aplSymbol.setTranslation(-45,-52)
        .setCenter(0,0);
        #airplane_grp.setScale(0,0);
    }
    apl_path = aplSymbol.getElementById("apl_path");
    airplane_grp.setGeoPosition(lat, lon)
    .set("z-index",10)
    .setRotation(hdg*D2R);
    #.setScale(1,1);
}

canvas.RouteModel.init = func {
    me._view.reset();
    #if (!getprop("/autopilot/route-manager/active"))
    #    return;

    ## TODO: all the model stuff is still inside the draw file for now, this just ensures that it will be called once
    foreach(var t; [nil] )
    me.push(t);

    me.notifyView();

    #FIXME: segfault of the day: use this layer once without a route, and then with a route - and  BOOM, need to investigate.

    # TODO: should register a route manager listener here to update itself whenever the route/active WPT changes!
    # also, if the layer is used in a dialog, the listener should be removed when the dialog is closed
    if (me.route_monitor == nil) # FIXME: remove this listener durint reinit
        me.route_monitor=setlistener("/autopilot/route-manager/active", func me.init() ); # this can probably be shared (singleton), because all canvases will be displaying same route ???
}

canvas.updatewp = func(activeWp)
{
    forindex(var i; canvas.wp) {
        if(i == activeWp) {
            canvas.wp[i].setColor(1,1,1);
            #text_wp[i].setColor(1,0,1);
        } else {
            canvas.wp[i].setColor(0.4,0.7,0.4);
            #text_wp[i].setColor(1,1,1);
        }
    }
}

canvas.drawwp =  func (group, lat, lon, alt, name, i, wp) {
    var wp_group = group.createChild("group","wp");
    wp[i] = wp_group.createChild("path", "wp-" ~ i)
    .setStrokeLineWidth(3)
    .moveTo(-10,0)
    .lineTo(0,-17)
    .lineTo(10,0)
    .lineTo(0,17)
    .setColor(1,1,1)
    .close();
    #####
    # The commented code leads to a segfault when a route is replaced by a new one
    #####
    #
    # text_wp[i] = wp_group.createChild("text", "wp-text-" ~ i)
    #
    if (alt <= 0){
        alt = "";
    }
    else{
        var alt_path = wp_group.createChild("path").
        setStrokeLineWidth(3).
        moveTo(-17,0).
        arcSmallCW(17,17,0,34,0).
        arcSmallCW(17,17,0,-34,0);
        if(getprop("flight-management/control/ver-ctrl") == 'fmgc')
        alt_path.setColor(0.69,0,0.39);
        else
            alt_path.setColor(1,1,1);
        if(getprop('instrumentation/efis/inputs/CSTR'))
        alt_path.show();
        else
            alt_path.hide();
        alt = "";#\n"~alt;
    }
    var text_wps = wp_group.createChild("text", "wp-text-" ~ i)
    .setDrawMode( canvas.Text.TEXT )
    .setText(name~alt)
    .setFont("LiberationFonts/LiberationSans-Regular.ttf")
    .setFontSize(28)
    .setTranslation(25,35)
    .setColor(1,1,1);
    wp_group.setGeoPosition(lat, lon)
    .set("z-index",4);
};

canvas.draw_route =  func (group, theroute, controller=nil, lod=0)
{
    #print("draw_route");
    var route_group = group;

    var route = route_group.createChild("path","route")
    .setStrokeLineWidth(5)
    .setColor(0.4,0.7,0.4);

    var lnav = (getprop('flight-management/control/lat-ctrl') == 'fmgc');
    var actv = getprop('autopilot/route-manager/active');

    if(!lnav or !actv)
        route.setStrokeDashArray([32, 16]);
    else
        route.setStrokeDashArray([]);
    if(!actv)
        route.setColor(0.95,0.95,0.21);

    var cmds = [];
    var coords = [];

    var fp = flightplan();
    var fpSize = fp.getPlanSize();

    canvas.wp = [];
    canvas.text_wp = [];
    setsize(canvas.wp,fpSize);
    setsize(canvas.text_wp,fpSize);

    # Retrieve route coordinates
    for (var i=0; i<(fpSize); i += 1)
    {
        if (i == 0) {
            var leg = fp.getWP(1);
            var j = 0;
            foreach (var pt; leg.path()) {
                append(coords,"N"~pt.lat);
                append(coords,"E"~pt.lon);
                if (j==0){
                    append(cmds,2);
                    j=1;
                } else
                    append(cmds,4);
            }
            canvas.drawwp(group, leg.path()[0].lat, leg.path()[0].lon, fp.getWP(0).alt_cstr, fp.getWP(0).wp_name, i, canvas.wp);
            i+=1;
        }
        var leg = fp.getWP(i);
        foreach (var pt; leg.path()) {
            append(coords,"N"~pt.lat);
            append(coords,"E"~pt.lon);
            append(cmds,4);
        }
        canvas.drawwp(group, leg.path()[-1].lat, leg.path()[-1].lon, leg.alt_cstr, leg.wp_name, i, canvas.wp);
    }

    # Set Top Of Climb coordinate
    #canvas.drawprofile(route_group, "tc", "T/C");
    # Set Top Of Descent coordinate
    #canvas.drawprofile(route_group, "td", "T/D");
    canvas.drawprofile(route_group, "decel", "D");
    # Set Step Climb coordinate
    #canvas.drawprofile(route_group, "sc", "S/C");
    # Set Top Of Descent coordinate
    #canvas.drawprofile(route_group, "ed", "E/D");
    #canvas.drawprofile(route_group, "ec", "E/C");

    # Update route coordinates
    debug.dump(cmds);
    debug.dump(coords);
    route.setDataGeo(cmds, coords);
    #canvas.updatewp(0);
    canvas.updatewp(getprop("/autopilot/route-manager/current-wp"));
}

canvas.drawprofile =  func (group, property, disptext)
{
    print("Reading profile for instrumentation/nd/symbols/"~property);
    var symNode = props.globals.getNode("instrumentation/nd/symbols/"~property, 1);
    var lon = symNode.getNode("longitude-deg", 1).getValue();
    var lat = symNode.getNode("latitude-deg", 1).getValue();
    if(lat != nil and lon != nil)
        print("Coord: "~lat~", "~lon);
    var sym_group = group.createChild("group", property);
    var aircraft_dir = split('/', getprop("/sim/aircraft-dir"))[-1];

    if(lon != nil)
    {
        canvas.parsesvg(sym_group, "Aircraft/" ~ aircraft_dir ~ "/Models/Instruments/ND/res/airbus_"~property~".svg");
        sym_group.setGeoPosition(lat, lon)
        .set("z-index",4);
        var grp = sym_group.getElementById(property~'_symbol');
        if(property == 'tc' or property == 'ec' or property == 'ed'){
            grp.setTranslation(-50,0);
        }
        if(grp != nil){
            var bearing = getprop("instrumentation/nd/symbols/"~property~"/bearing-deg");
            if(bearing){
                print(property~" bearing: " ~ bearing);
                var hdg = a332.nd_display.main._node.getNode('group/map').getValue('hdg');
                if(hdg == nil) hdg = 0;
                bearing -= hdg;
                if(bearing < 0) bearing = 360 + bearing; 
                grp.setRotation(bearing*D2R);
            }
        }
        #var rot = me.map._node.getNode("hdg",1).getDoubleValue();
        #var rot = nd_display.main._node.getNode('group/map/hdg').getValue();
        #sym_group.setRotation(rot);
    }
}

canvas._draw_rwy_nd = func (group, lat, lon, length, width, rwyhdg) {
    var apt = airportinfo("EHAM");
    var rwy = apt.runway("18R");

    var ctr_len = length * 0.75;
    var crds = [];
    var coord = geo.Coord.new();
    width=width*20; # Else rwy is too thin to be visible
    coord.set_latlon(lat, lon);
    coord.apply_course_distance(rwyhdg, -(ctr_len / 2));
    append(crds,"N"~coord.lat());
    append(crds,"E"~coord.lon());
    coord.apply_course_distance(rwyhdg, (ctr_len));
    append(crds,"N"~coord.lat());
    append(crds,"E"~coord.lon());
    icon_rwy = group.createChild("path", "rwy-cl")
    .setStrokeLineWidth(3)
    .setDataGeo([2,4],crds)
    .setColor(1,1,1);
    #.setStrokeDashArray([10, 20, 10, 20, 10]);
    #icon_rwy.hide();
    var crds = [];
    coord.set_latlon(lat, lon);
    append(crds,"N"~coord.lat());
    append(crds,"E"~coord.lon());
    coord.apply_course_distance(rwyhdg + 90, width/2);
    append(crds,"N"~coord.lat());
    append(crds,"E"~coord.lon());
    coord.apply_course_distance(rwyhdg, length);
    append(crds,"N"~coord.lat());
    append(crds,"E"~coord.lon());
    icon_rwy = group.createChild("path", "rwy")
    .setStrokeLineWidth(3)
    .setDataGeo([2,4,4],crds)
    .setColor(1,1,1);
    var crds = [];
    append(crds,"N"~coord.lat());
    append(crds,"E"~coord.lon());
    coord.apply_course_distance(rwyhdg - 90, width);
    append(crds,"N"~coord.lat());
    append(crds,"E"~coord.lon());
    coord.apply_course_distance(rwyhdg, -length);
    append(crds,"N"~coord.lat());
    append(crds,"E"~coord.lon());
    coord.apply_course_distance(rwyhdg + 90, width / 2);
    append(crds,"N"~coord.lat());
    append(crds,"E"~coord.lon());
    icon_rwy = group.createChild("path", "rwy")
    .setStrokeLineWidth(3)
    .setDataGeo([2,4,4,4],crds)
    .setColor(1,1,1);
};


canvas.NavDisplay.old_update = canvas.NavDisplay.update;

canvas.NavDisplay.update = func(){
    me.old_update();
    if(me.in_mode('toggle_display_mode', ['PLAN'])) {
        me.map._node.getNode("hdg",1).setDoubleValue(0);
    }
};

# get a handle to the NavDisplay in canvas namespace (for now), see $FG_ROOT/Nasal/canvas/map/navdisplay.mfd
var ND = canvas.NavDisplay;

## TODO: We want to support multiple independent ND instances here!
# foreach(var pilot; var pilots = [ {name:'cpt', path:'instrumentation/efis',
#				     name:'fo',  path:'instrumentation[1]/efis']) {


##
# set up a  new ND instance, under 'instrumentation/efis' and use the
# myCockpit_switches hash to map control properties
var NDCpt = ND.new("instrumentation/efis", myCockpit_switches, 'Airbus');

nd_display.main = canvas.new({
    "name": "ND",
    "size": [1024, 1024],
    "view": [1024, 1024],
    "mipmapping": 1
});

nd_display.main.addPlacement({"node": "ND.screen"});
var group = nd_display.main.createGroup();
NDCpt.newMFD(group);

NDCpt.update();

setprop("instrumentation/efis/inputs/plan-wpt-index", -1);

print("ND Canvas Initialized!");
update_apl_sym();
}); # fdm-initialized listener callback

setlistener("instrumentation/efis/nd/display-mode", func{
            var canvas_mode = "instrumentation/efis/nd/canvas-display-mode";
            var nd_centered = "instrumentation/efis/inputs/nd-centered";
            var mode = getprop("instrumentation/efis/nd/display-mode");
var cvs_mode = 'NAV';
var centered = 1;
if(mode == 'ILS'){
    cvs_mode = 'APP';
}
elsif(mode == 'VOR') {
    cvs_mode = 'VOR';
}
elsif(mode == 'NAV'){
    cvs_mode = 'MAP';
}
elsif(mode == 'ARC'){
    cvs_mode = 'MAP';
    centered = 0;
}
elsif(mode == 'PLAN'){
    cvs_mode = 'PLAN';
}
setprop(canvas_mode, cvs_mode);
setprop(nd_centered, centered);
});

setlistener('autopilot/route-manager/active', func{
            var actv = getprop("autopilot/route-manager/active");
setprop('instrumentation/efis/nd/route-manager-active', actv);
});

setlistener('flight-management/control/ver-ctrl', func{
            var verctrl = getprop("flight-management/control/ver-ctrl");
setprop('instrumentation/efis/nd/vnav', (verctrl == 'fmgc'));
});

setlistener('flight-management/control/lat-ctrl', func{
            var latctrl = getprop("flight-management/control/lat-ctrl");
setprop('instrumentation/efis/nd/lnav', (latctrl == 'fmgc'));
});

setlistener("/instrumentation/mcdu/f-pln/disp/first", func{
            var first = getprop("/instrumentation/mcdu/f-pln/disp/first");
if(typeof(first) == 'nil') first = -1;
if(getprop('autopilot/route-manager/route/num') == 0) first = -1;
setprop("instrumentation/efis/inputs/plan-wpt-index", first);
});

setlistener('/instrumentation/efis/nd/terrain-on-nd', func{
            var terr_on_hd = getprop('/instrumentation/efis/nd/terrain-on-nd');
var alpha = 1;
if(terr_on_hd) alpha = 0.5;
nd_display.main.setColorBackground(0,0,0,alpha);
});

var showNd = func() {
    # The optional second arguments enables creating a window decoration
    var dlg = canvas.Window.new([400, 400], "dialog");
    dlg.setCanvas( nd_display["main"] );
}


