var ND_AIRBUS_SUPPORT = contains(canvas.NDStyles, 'Airbus');

if(!ND_AIRBUS_SUPPORT){
    io.include('A330_ND.nas');
} else {
    io.include('ND_config.nas');
    var nd_display = {};

    setlistener("sim/signals/fdm-initialized", func() {

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
            'toggle_wpt_idx': {path: '/inputs/plan-wpt-index', value: -1, type: 'INT'},
            'toggle_plan_loop': {path: '/nd/plan-mode-loop', value: 0, type: 'INT'},
            'toggle_app_mode': {path: '/nd/app-mode', value:'', type: 'STRING'},
            'toggle_hold_update': {path: '/nd/hold_update', value: 0, type: 'INT'},
            'toggle_hold_wp': {path: '/nd/hold_wp', value: '', type: 'STRING'},
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

}
