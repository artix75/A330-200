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

    setlistener(nd_props.fplan_active, func{
        var actv = getprop(nd_props.fplan_active);
        setprop('instrumentation/efis/nd/route-manager-active', actv);
    });

    setlistener(nd_props.athr, func{
        var athr = getprop(nd_props.athr);
        setprop('instrumentation/efis/nd/athr', (athr == 'eng'));
    });

    setlistener('flight-management/control/ver-ctrl', func{
        var verctrl = getprop("flight-management/control/ver-ctrl");
        setprop('instrumentation/efis/nd/vnav', (verctrl == 'fmgc'));
    });

    setlistener("/flight-management/control/spd-ctrl", func{
        var spdctrl = getprop("/flight-management/control/spd-ctrl");
        setprop('instrumentation/efis/nd/managed-spd', (spdctrl == 'fmgc'));
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

    setlistener('instrumentation/nav/frequencies/selected-mhz', func{
        var mhz = getprop('instrumentation/nav/frequencies/selected-mhz');
        if(mhz == nil) mhz = 0;
        setprop('/instrumentation/efis/nd/nav1_frq', mhz);
    });

    setlistener('instrumentation/nav[1]/frequencies/selected-mhz', func{
        var mhz = getprop('instrumentation/nav[1]/frequencies/selected-mhz');
        if(mhz == nil) mhz = 0;
        setprop('/instrumentation/efis/nd/nav2_frq', mhz);
    });

    setlistener('instrumentation/adf/frequencies/selected-khz', func{
        var khz = getprop('instrumentation/adf/frequencies/selected-khz');
        if(khz == nil) khz = 0;
        setprop('/instrumentation/efis/nd/adf1_frq', khz);
    });

    setlistener('instrumentation/adf[1]/frequencies/selected-khz', func{
        var khz = getprop('instrumentation/adf[1]/frequencies/selected-khz');
        if(khz == nil) khz = 0;
        setprop('/instrumentation/efis/nd/adf2_frq', khz);
    });

    setlistener('flight-management/hold/init', func{
        var init = getprop('flight-management/hold/init');
        if(init == nil) init = 0;
        setprop('/instrumentation/efis/nd/hold_init', init);
    });

    setlistener("/flight-management/hold/wp", func{
        var wpid = getprop("/flight-management/hold/wp");
        if(wpid == nil) wpid = '';
            setprop('/instrumentation/efis/nd/hold_wp', wpid);
    });

    setlistener('autopilot/route-manager/route/num', func{
        var num = getprop('autopilot/route-manager/route/num');
        setprop('/instrumentation/efis/nd/route_num', num);
    });

    setlistener(nd_props.cur_wp, func(){
        var curwp = getprop(nd_props.cur_wp);
        setprop('/instrumentation/efis/nd/cur_wp',curwp);
    });

    setlistener("/flight-management/control/ap1-master", func(){
        var ap1 = getprop("/flight-management/control/ap1-master");
        setprop('/instrumentation/efis/nd/ap1',ap1);
    });

    setlistener("/flight-management/control/ap2-master", func(){
        var ap2 = getprop("/flight-management/control/ap2-master");
        setprop('/instrumentation/efis/nd/ap2',ap2);
    });

    setlistener("/autopilot/route-manager/departure/runway", func(){
        var rwy = getprop("/autopilot/route-manager/departure/runway");
        setprop('/instrumentation/efis/nd/dep_rwy',rwy);
    });

    setlistener("/autopilot/route-manager/destination/runway", func(){
        var rwy = getprop("/autopilot/route-manager/destination/runway");
        setprop('/instrumentation/efis/nd/dest_rwy',rwy);
    });

    var showNd = func() {
        # The optional second arguments enables creating a window decoration
        var dlg = canvas.Window.new([400, 400], "dialog");
        dlg.setCanvas( nd_display["main"] );
    }

}
