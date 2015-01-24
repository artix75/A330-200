# A330-200 ND Implementation

print('Loading local canvas ND...');


var get_local_path = func(file){
    var aircraft_dir = split('/', getprop("/sim/aircraft-dir"))[-1];
    return "Aircraft/" ~ aircraft_dir ~ "/Models/Instruments/ND/canvas/"~ file;
};

var version = getprop('sim/version/flightgear');
var v = split('.', version);
version = num(v[0]~'.'~v[1]);

var SymbolLayer = canvas.SymbolLayer;
var SingleSymbolLayer = canvas.SingleSymbolLayer;
var MultiSymbolLayer = canvas.MultiSymbolLayer;
var NavaidSymbolLayer = canvas.NavaidSymbolLayer;
var Symbol = canvas.Symbol;
var Group = canvas.Group;
var Path = canvas.Path;
var DotSym = canvas.DotSym;
var Map = canvas.Map;
var SVGSymbol = canvas.SVGSymbol;
var LineSymbol = canvas.LineSymbol;
var StyleableCacheable = canvas.StyleableCacheable;
var SymbolCache32x32 = canvas.SymbolCache32x32;
var SymbolCache = canvas.SymbolCache;
var Text = canvas.Text;


if(version < 3.2){
    io.include('canvas_compat.nas');
}

io.include('ND_config.nas');
io.include('framework/canvas.nas');
io.include('framework/navdisplay.nas');
io.include('loaders.nas');
io.include('helpers.nas');
io.include('style.nas');

var nd_display = {};

#canvas.NavDisplay.old_update = canvas.NavDisplay.update;

###
# entry point, this will set up all ND instances

setlistener("sim/signals/fdm-initialized", func() {

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
        'toggle_true_north': 	{path: '/mfd/true-north', value:1, type:'BOOL'},
        'toggle_track_heading': 	{path: '/trk-selected', value:0, type:'BOOL'},
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
        'toggle_cur_sd': {path: '/nd/current-sd', value: 0, type: 'INT'},
        'toggle_cur_ec': {path: '/nd/current-ec', value: 0, type: 'INT'},
        'toggle_lvl_off_at': {path: '/nd/level-off-at', value: 0, type: 'INT'},
        'toggle_man_spd': {path: '/nd/managed-spd', value: 0, type: 'INT'},
        'toggle_athr': {path: '/nd/athr', value: 0, type: 'INT'},
        'toggle_spd_point_100': {path: '/nd/spd-change-raw-100', value: 0, type: 'INT'},
        'toggle_spd_point_140': {path: '/nd/spd-change-raw-140', value: 0, type: 'INT'},
        'toggle_spd_point_250': {path: '/nd/spd-change-raw-250', value: 0, type: 'INT'},
        'toggle_spd_point_260': {path: '/nd/spd-change-raw-260', value: 0, type: 'INT'},
        'toggle_nav1_frq': {path: '/nd/nav1_frq', value: 0, type: 'INT'},
        'toggle_nav2_frq': {path: '/nd/nav2_frq', value: 0, type: 'INT'},
        'toggle_adf1_frq': {path: '/nd/adf1_frq', value: 0, type: 'INT'},
        'toggle_adf2_frq': {path: '/nd/adf2_frq', value: 0, type: 'INT'},
        'toggle_hold_init': {path: '/nd/hold_init', value: 0, type: 'INT'},
        'toggle_hold_update': {path: '/nd/hold_update', value: 0, type: 'INT'},
        'toggle_hold_wp': {path: '/nd/hold_wp', value: '', type: 'STRING'},
        'toggle_route_num': {path: '/nd/route_num', value: 0, type: 'INT'},
        'toggle_cur_wp': {path: '/nd/cur_wp', value: 0, type: 'INT'},
        'toggle_ap1': {path: '/nd/ap1', value: '', type: 'STRING'},
        'toggle_ap2': {path: '/nd/ap2', value: '', type: 'STRING'},
        'toggle_dep_rwy': {path: '/nd/dep_rwy', value: '', type: 'STRING'},
        'toggle_dest_rwy': {path: '/nd/dest_rwy', value: '', type: 'STRING'},
        # add new switches here
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
    var layer_names = keys(NDCpt.layers);

    foreach(var layer_name; layer_names){
        var the_layer = NDCpt.layers[layer_name];
        if(the_layer != nil)
            the_layer.map = NDCpt.map;
    }
    NDCpt.update();

    setprop("instrumentation/efis/inputs/plan-wpt-index", -1);

    print("ND Canvas Initialized!");
}); # fdm-initialized listener callback

var nd_props = canvas.NDConfig.properties;

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


