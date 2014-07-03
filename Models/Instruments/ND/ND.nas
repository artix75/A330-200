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

    settimer(update_apl_sym, 1);
}

###
# entry point, this will set up all ND instances

setlistener("sim/signals/fdm-initialized", func() {

    canvas.Group.setColor = func(r,g,b, excl = nil){
        var children = me.getChildren();
        foreach(var e; children){
            var do_skip = 0;
            if(excl != nil){
                foreach(var cl; excl){
                    if(isa(e, cl)){
                        do_skip = 1;
                        continue;                 
                    }
                }
            }
            if(!do_skip)
                e.setColor(r,g,b);
        }
    }

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
        #debug.dump(model);
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

        foreach( var name; ['APS','ALT-profile','SPD-profile'] )
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
        'toggle_man_spd': {path: '/nd/managed-spd', value: 0, type: 'INT'},
        'toggle_athr': {path: '/nd/athr', value: 0, type: 'INT'},
        'toggle_spd_point_100': {path: '/nd/spd-change-raw-100', value: 0, type: 'INT'},
        'toggle_spd_point_140': {path: '/nd/spd-change-raw-140', value: 0, type: 'INT'},
        'toggle_spd_point_250': {path: '/nd/spd-change-raw-250', value: 0, type: 'INT'},
        'toggle_spd_point_260': {path: '/nd/spd-change-raw-260', value: 0, type: 'INT'},
        'toggle_nav1_frq': {path: '/nd/nav1_frq', value: 0, type: 'INT'},
        'toggle_nav2_frq': {path: '/nd/nav2_frq', value: 0, type: 'INT'},
        'toggle_adf1_frq': {path: '/nd/adf1_frq', value: 0, type: 'INT'},
        'toggle_adf2_frq': {path: '/nd/adf2_frq', value: 0, type: 'INT'}
        # add new switches here
    };

    var SymbolPainter = {
        aircraft_dir: nil,
        getOpts: func(opts){
            if(opts == nil) opts = {};
            var defOpts = {id:nil,color:nil,scale:1,create_group:0,update_center:0};
            if(contains(opts, 'id'))
                defOpts.id = opts.id;
            if(contains(opts, 'color'))
                defOpts.color = opts.color;
            if(contains(opts, 'scale'))
                defOpts.scale = opts.scale;
            if(contains(opts, 'create_group'))
                defOpts.create_group = opts.create_group;
            if(contains(opts, 'update_center'))
                defOpts.update_center = opts.update_center;
            return defOpts;
        },
        getAircraftDir: func(){
            if(me.aircraft_dir == nil)
                me.aircraft_dir = split('/', getprop("/sim/aircraft-dir"))[-1];
            return me.aircraft_dir;
        },
        svgPath: func(file){
            return "Aircraft/" ~ me.getAircraftDir() ~ "/Models/Instruments/ND/res/"~file;
        },
        drawFIX : func(grp, opts = nil){
            var icon_fix = nil;
            opts = me.getOpts(opts);
            var sym_id = opts.id;
            if(sym_id != nil)
                icon_fix = grp.createChild("path", sym_id);
            else 
                icon_fix = grp.createChild("path");
            var color = opts.color;
            if(color == nil){
                color = {
                    r: 0.69,
                    g: 0,
                    b: 0.39
                };
            }
            var scale = opts.scale;
            if(scale == nil) scale = 0.8;
            icon_fix.moveTo(-10,0)
            .lineTo(0,-17)
            .lineTo(10,0)
            .lineTo(0,17)
            .close()
            .setStrokeLineWidth(3)
            .setColor(color.r,color.g,color.b)
            .setScale(scale,scale);
            return icon_fix;
        },
        drawVOR: func(grp, opts = nil){
            opts = me.getOpts(opts);
            if(opts.create_group){
                var sym_id = opts.id;
                if(sym_id != nil)
                    grp = grp.createChild("group", sym_id);
                else 
                    grp = grp.createChild("group");
            }
            var svg_path = me.svgPath('airbus_vor.svg');
            canvas.parsesvg(grp, svg_path);
            var scale = opts.scale;
            if(scale == nil) scale = 0.8;
            grp.setScale(scale,scale);
            if(opts.update_center)
                grp.setTranslation(-24 * scale,-24 * scale);
            return grp;
        },
        drawNDB: func(grp, opts = nil){
            var icon_ndb = nil;
            opts = me.getOpts(opts);
            var sym_id = opts.id;
            if(sym_id != nil)
                icon_ndb = grp.createChild("path", sym_id);
            else 
                icon_ndb = grp.createChild("path");
            var color = opts.color;
            var color = opts.color;
            if(color == nil){
                color = {
                    r: 0.69,
                    g: 0,
                    b: 0.39
                };
            }
            var scale = opts.scale;
            if(scale == nil) scale = 0.8;
            icon_ndb.moveTo(-15,15)
            .lineTo(0,-15)
            .lineTo(15,15)
            .close()
            .setStrokeLineWidth(3)
            .setColor(color.r,color.g,color.b)
            .setScale(scale,scale);
            return icon_ndb;
        },
        drawAirport: func(grp, opts = nil){
            opts = me.getOpts(opts);
            if(opts.create_group){
                var sym_id = opts.id;
                if(sym_id != nil)
                    grp = grp.createChild("group", sym_id);
                else 
                    grp = grp.createChild("group");
            }
            var svg_path = me.svgPath('airbus_airport.svg');
            canvas.parsesvg(grp, svg_path);
            var scale = opts.scale;
            if(scale == nil) scale = 0.8;
            grp.setScale(scale,scale);
            if(opts.update_center)
                grp.setTranslation(-24 * scale,-24 * scale);
            return grp;
        },
        draw: func(type, grp, opts = nil){
            if(type == 'VOR' or type == 'vor')
                return me.drawVOR(grp, opts);
            elsif(type == 'NDB' or type == 'ndb')
                return me.drawNDB(grp, opts);
            elsif(type == 'ARPT' or type == 'arpt')
                return me.drawAirport(grp, opts);
            else 
                return me.drawFIX(grp, opts);
        }
    };

    canvas.Symbol.get("FIX").icon_fix = nil;
    canvas.Symbol.get("FIX").draw = func{
        if (me.icon_fix != nil) return;
        # the fix symbol
        me.icon_fix = SymbolPainter.drawFIX(me.element);
        me.text_fix = me.element.createChild("text")
        .setDrawMode( canvas.Text.TEXT )
        .setText(me.model.id)
        .setFont("LiberationFonts/LiberationSans-Regular.ttf")
        .setFontSize(28)
        .setTranslation(20,10);
    }

    canvas.Symbol.get("VOR").svg_loaded = nil;
    canvas.Symbol.get("VOR").draw = func{
        var grp = nil;
        if(me.svg_loaded == nil) {
            me.element.removeAllChildren();
            grp = me.element.createChild("group");
            SymbolPainter.drawVOR(grp);

            me.text_vor = me.element.createChild("text")
            .setDrawMode( canvas.Text.TEXT )
            .setText(me.model.id)
            .setFont("LiberationFonts/LiberationSans-Regular.ttf")
            .setFontSize(28)
            .setColor(1,1,1)
            .setTranslation(45,25);
            me.svg_loaded = 1;
        } else {
            grp = me.element;
        }
        var frq = me.model.frequency;
        if(frq != nil and grp != nil){
            frq = frq / 100;
            var nav1_frq = getprop('instrumentation/nav/frequencies/selected-mhz');
            var nav2_frq = getprop('instrumentation/nav[1]/frequencies/selected-mhz');
            if(nav1_frq == frq or nav2_frq == frq){
                grp.setColor(0,0.62,0.84, [canvas.Text]);
            } else {
                grp.setColor(0.9,0,0.47, [canvas.Text]);
            }
        }
    }

    canvas.Symbol.get("NDB").icon_ndb = nil;
    canvas.Symbol.get("NDB").draw = func{
        if (me.icon_ndb == nil) {
            # the fix symbol
            me.icon_ndb = SymbolPainter.drawNDB(me.element);
            me.text_ndb = me.element.createChild("text")
            .setDrawMode( canvas.Text.TEXT )
            .setText(me.model.id)
            .setFont("LiberationFonts/LiberationSans-Regular.ttf")
            .setFontSize(28)
            .setTranslation(25,10);
        };
        var frq = me.model.frequency;
        if(frq != nil and me.icon_ndb != nil){
            frq = frq / 100;
            var adf1_frq = getprop('instrumentation/adf/frequencies/selected-khz');
            var adf2_frq = getprop('instrumentation/adf[1]/frequencies/selected-khz');
            if(adf1_frq == frq or adf2_frq == frq){
                me.icon_ndb.setColor(0,0.62,0.84);
            } else {
                me.icon_ndb.setColor(0.9,0,0.47);
            }
        }
    }

    canvas.draw_apt = func(group, apt, controller=nil, lod=0){
        var lat = apt.lat;
        var lon = apt.lon;
        var name = apt.id;
        # print("drawing nd airport:", name);

        var apt_grp = group.createChild("group", name);

        SymbolPainter.drawAirport(apt_grp);
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

    canvas.drawwp =  func (group, lat, lon, wpLeg, i, wp) {
        var name = wpLeg.wp_name;
        var alt = wpLeg.alt_cstr;
        var wp_id = wpLeg.id;
        var wp_type = wpLeg.wp_type;
        var idLen = size(wp_id);
        var wp_group = group.createChild("group","wp");
        
        #wp[i] = wp_group.createChild("path", "wp-" ~ i)
        #.setStrokeLineWidth(3)
        #.moveTo(-10,0)
        #.lineTo(0,-17)
        #.lineTo(10,0)
        #.lineTo(0,17)
        #.setColor(1,1,1)
        #.close();
        var opts = {
            id: 'wp-' ~ i,
            create_group: 1,
            update_center: 1
        };
        if(wp_type == 'navaid'){
            if(idLen == 4)
                wp[i] = SymbolPainter.drawAirport(wp_group, opts);
            elsif(idLen == 3){
                var navaids = navinfo(lat,lon,wp_id);
                var type = 'VOR';
                if(size(navaids) > 0)
                    type = navaids[0].type;
                if(type == nil) type = 'VOR';
                wp[i] = SymbolPainter.draw(type, wp_group, opts);
            }
            else
                wp[i] = SymbolPainter.drawFIX(wp_group, opts);
        }
        else
            wp[i] = SymbolPainter.drawFIX(wp_group, opts);
        #####
        # The commented code leads to a segfault when a route is replaced by a new one
        #####
        #
        # text_wp[i] = wp_group.createChild("text", "wp-text-" ~ i)
        #
        var vnav_actv = getprop("flight-management/control/ver-ctrl") == 'fmgc';
        if(alt > 0){
            var wp_d = wpLeg.distance_along_route; 
            var estimated_sc = getprop('instrumentation/efis/nd/current-sc');
            var alt_path = wp_group.createChild("path").
            setStrokeLineWidth(4).
            moveTo(-22,0).
            arcSmallCW(22,22,0,44,0).
            arcSmallCW(22,22,0,-44,0);
            if(vnav_actv){
                var curwp = getprop("/autopilot/route-manager/current-wp");
                if((estimated_sc - wp_d) > 0.5 and curwp == i)
                    alt_path.setColor(1,0.57,0.14);
                else
                    alt_path.setColor(0.69,0,0.39);
            }
            else
                alt_path.setColor(1,1,1);
            if(getprop('instrumentation/efis/inputs/CSTR'))
                alt_path.show();
            else
                alt_path.hide();
            #alt = "";#\n"~alt;
        }
        var text_wps = wp_group.createChild("text", "wp-text-" ~ i)
        .setDrawMode( canvas.Text.TEXT )
        .setText(name)
        .setFont("LiberationFonts/LiberationSans-Regular.ttf")
        .setFontSize(28)
        .setTranslation(25,35)
        .setColor(1,1,1);
        if(alt > 0){
            var text_alt = wp_group.createChild("text", "wp-alt-text-" ~ i)
            .setDrawMode( canvas.Text.TEXT )
            .setText("\n" ~ alt)
            .setFont("LiberationFonts/LiberationSans-Regular.ttf")
            .setFontSize(28)
            .setTranslation(25,35);
            if(vnav_actv)
                text_alt.setColor(0.69,0,0.39);
            else
                text_alt.setColor(1,1,1);
        }
        var hold_id = getprop("/flight-management/hold/wp");
        var hold_init = getprop("/flight-management/hold/init");
        if(hold_init and hold_id != nil and hold_id == wpLeg.id){
            #var hold_grp = wp_group.createChild("group", "wp-hold-" ~ i);
            #var aircraft_dir = split('/', getprop("/sim/aircraft-dir"))[-1];
            #var hold_turn = getprop("/flight-management/hold/turn");
            #canvas.parsesvg(hold_grp, "Aircraft/" ~ aircraft_dir ~ "/Models/Instruments/ND/res/airbus_hold"~hold_turn~".svg");
            #hold_grp.setTranslation(25,-55).set('z-index', 4);
            var hold_path = group.createChild('path', 'hold-pattern');
            var crds = [];
            var cmds = [];
            append(crds, 'N'~getprop('/flight-management/hold/points/point[0]/lat'));
            append(crds, 'E'~getprop('/flight-management/hold/points/point[0]/lon'));
            append(cmds, 2);
            append(crds, 'N'~getprop('/flight-management/hold/points/point[1]/lat'));
            append(crds, 'E'~getprop('/flight-management/hold/points/point[1]/lon'));
            append(cmds, 4);#20);
            append(crds, 'N'~getprop('/flight-management/hold/points/point[2]/lat'));
            append(crds, 'E'~getprop('/flight-management/hold/points/point[2]/lon'));
            append(cmds, 4);
            append(crds, 'N'~getprop('/flight-management/hold/points/point[3]/lat'));
            append(crds, 'E'~getprop('/flight-management/hold/points/point[3]/lon'));
            append(cmds, 4);#20);
            append(crds, 'N'~getprop('/flight-management/hold/points/point[0]/lat'));
            append(crds, 'E'~getprop('/flight-management/hold/points/point[0]/lon'));
            append(cmds, 4);
            hold_path.setStrokeLineWidth(5)
            .setColor(0.4,0.7,0.4)
            .setDataGeo(cmds,crds);
            path.addA
        }
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
                var first_wp = fp.getWP(0);
                canvas.drawwp(group, leg.path()[0].lat, leg.path()[0].lon, first_wp, i, canvas.wp);
                i+=1;
            }
            var leg = fp.getWP(i);
            foreach (var pt; leg.path()) {
                append(coords,"N"~pt.lat);
                append(coords,"E"~pt.lon);
                append(cmds,4);
            }
            canvas.drawwp(group, leg.path()[-1].lat, leg.path()[-1].lon, leg, i, canvas.wp);
        }
        if(fpSize > 0){
            var first_wp = canvas.wp[0];
            var last_wp = canvas.wp[fpSize - 1];
            if(fp.departure_runway != nil and first_wp != nil) 
                first_wp.hide();
            if(fp.destination_runway != nil and last_wp != nil) 
                last_wp.hide();
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
        #debug.dump(cmds);
        #debug.dump(coords);
        route.setDataGeo(cmds, coords);
        route.set('z-index', 3);
        #canvas.updatewp(0);
        canvas.updatewp(getprop("/autopilot/route-manager/current-wp"));
    }

    canvas.drawprofile =  func (group, property, disptext)
    {
        #print("Reading profile for instrumentation/nd/symbols/"~property);
        var symNode = props.globals.getNode("instrumentation/nd/symbols/"~property, 1);
        var lon = symNode.getNode("longitude-deg", 1).getValue();
        var lat = symNode.getNode("latitude-deg", 1).getValue();
        #if(lat != nil and lon != nil)
        #    print("Coord: "~lat~", "~lon);
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
                    #print(property~" bearing: " ~ bearing);
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
        } else {
            var userHdgMag = me.aircraft_source.get_hdg_mag();
            var userHdgTru = me.aircraft_source.get_hdg_tru();
            var userTrkMag = me.aircraft_source.get_trk_mag();
            var userTrkTru = me.aircraft_source.get_trk_tru();

            if(me.get_switch('toggle_true_north')) {
                me.symbols.truMag.setText("TRU");
                var userHdg=userHdgTru;
                var userTrk=userTrkTru;
            } else {
                me.symbols.truMag.setText("MAG");
                var userHdg=userHdgMag;
                var userTrk=userTrkMag;
            }
            var trk_heading = me.get_switch('toggle_track_heading');
            if(trk_heading){
                userHdgTrk = userTrk;
            } else {
                userHdgTrk = userHdg;
            }
            var vhdg_bug = getprop("autopilot/settings/heading-bug-deg");

            var hdgBugRot = (vhdg_bug-userHdgTrk)*D2R;
            me.map._node.getNode("hdg",1).setDoubleValue(userHdgTrk);
            me.symbols.hdgBug.setRotation(hdgBugRot);
            me.symbols.hdgBug2.setRotation(hdgBugRot);
            me.symbols.trkInd.setRotation((userTrk-userHdg)*D2R);
            me.symbols.curHdgPtr.setRotation(0);
            me.symbols.curHdgPtr2.setRotation(0);
            me.symbols.compass.setRotation(-userHdgTrk*D2R);
            me.symbols.compassApp.setRotation(-userHdgTrk*D2R);
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

setlistener('/flight-management/control/a-thrust', func{
    var athr = getprop('/flight-management/control/a-thrust');
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

var showNd = func() {
    # The optional second arguments enables creating a window decoration
    var dlg = canvas.Window.new([400, 400], "dialog");
    dlg.setCanvas( nd_display["main"] );
}


