var _MP_dbg_lvl = "info";
#var _MP_dbg_lvl = "alert";

var makedie = func(prefix) func(msg) globals.die(prefix~" "~msg);

var __die = makedie("MapStructure");

var _arg2valarray = func
{
    var ret = arg;
    while (    typeof(ret) == "vector"
           and size(ret) == 1 and typeof(ret[0]) == "vector" )
    ret = ret[0];
    return ret;
}

##
# Combine a specific hash with a default hash, e.g. for
# options/df_options and style/df_style in a SymbolLayer.
#
var default_hash = func(opt, df) {
    if (opt != nil and typeof(opt)=='hash') {
        if (df != nil and opt != df and !isa(opt, df)) {
            if (contains(opt, "parents"))
            opt.parents ~= [df];
            else
                opt.parents = [df];
        }
        return opt;
    } else return df;
}


var try_aux_method = func(obj, method_name) {
    var name = "<test%"~id(caller(0)[0])~">";
    call(compile("obj."~method_name~"()", name), nil, var err=[]); # try...
    #debug.dump(err);
    if (size(err)) # ... and either leave caght or rethrow
    if (err[1] != name)
        die(err[0]);
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
    
    canvas.Symbol._new = func(m) {
        #m.style = m.layer.style;
        #m.options = m.layer.options;
        if (m.controller != nil) {
            temp = m.controller.new(m,m.model);
            if (temp != nil)
                m.controller = temp;
        }
        else __die("Symbol._new(): default controller not found");
    };
    
    canvas.Symbol.del = func() {
        if (me.controller != nil)
            me.controller.del(me, me.model);
        try_aux_method(me.model, "del");
    };

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
    
    canvas.LineSymbol = {
        parents:[canvas.Symbol],
        element_id: nil,
        needs_update: 1,
        # Static/singleton:
        makeinstance: func(name, hash) {
            if (!isa(hash, canvas.LineSymbol))
                die("LineSymbol: OOP error");
            return canvas.Symbol.add(name, hash);
        },
        # For the instances returned from makeinstance:
        new: func(group, model, controller=nil) {
            if (me == nil) die("Need me reference for LineSymbol.new()");
            if (typeof(model) != 'vector') die("LineSymbol.new(): need a vector of points");
            var m = {
                parents: [me],
                group: group,
                #layer: layer,
                model: model,
                controller: controller == nil ? me.df_controller : controller,
                element: group.createChild(
                    "path", me.element_id
                ),
            };
            append(m.parents, m.element);
            canvas.Symbol._new(m);

            m.init();
            return m;
        },
        # Non-static:
        draw: func() {
            if (!me.needs_update) return;
            #printlog(_MP_dbg_lvl, "redrawing a LineSymbol "~me.layer.type);
            me.element.reset();
            var cmds = [];
            var coords = [];
            var cmd = canvas.Path.VG_MOVE_TO;
            foreach (var m; me.model) {
                var (lat,lon) = me.controller.getpos(m);
                append(coords,"N"~lat);
                append(coords,"E"~lon);
                append(cmds,cmd); 
                cmd = canvas.Path.VG_LINE_TO;
            }
            me.element.setDataGeo(cmds, coords);
            me.element.update(); # this doesn't help with flickering, it seems
        },
        del: func() {
            printlog(_MP_dbg_lvl, "LineSymbol.del()");
            me.deinit();
            call(canvas.Symbol.del, nil, me);
            me.element.del();
        },
        # Default wrappers:
        init: func() me.draw(),
        deinit: func(),
        update: func() {
            if (me.controller != nil) {
                if (!me.controller.update(me, me.model)) return;
                elsif (!me.controller.isVisible(me.model)) {
                    me.element.hide();
                    return;
                }
            } else
                me.element.show();
            me.draw();
        },
    }; # of LineSymbol

    canvas.Path.addSegmentGeo = func(cmd, coords...)
    {
        var coords = _arg2valarray(coords);
        var num_coords = me.num_coords[cmd];
        if( size(coords) != num_coords )
        debug.warn
        (
            "Invalid number of arguments (expected " ~ num_coords ~ ")"
        );
        else
        {
            me.setInt("cmd[" ~ (me._last_cmd += 1) ~ "]", cmd);
            for(var i = 0; i < num_coords; i += 1)
                me.set("coord-geo[" ~ (me._last_coord += 1) ~ "]", coords[i]);
        }

        return me;
    }

    canvas.Path.arcGeo = func(cmd, rx,ry,unk,lat,lon){
        if(cmd < 18 and cmd > 24){
            debug.warn("Invalid command " ~ cmd);
            return me;
        }
        else
        {
            me.setInt("cmd[" ~ (me._last_cmd += 1) ~ "]", cmd);
            #for(var i = 0; i < num_coords; i += 1)
            me.setDouble("coord[" ~ (me._last_coord += 1) ~ "]", rx);
            me.setDouble("coord[" ~ (me._last_coord += 1) ~ "]", ry);
            me.setDouble("coord[" ~ (me._last_coord += 1) ~ "]", unk);
            me.setDouble("coord-geo[N" ~ (me._last_coord += 1) ~ "]", lat);
            me.setDouble("coord-geo[E" ~ (me._last_coord += 1) ~ "]", lat);
        }

        return me;
    }

    canvas.SymbolLayer.onRemoved = func(model) {
        #print('onRemoved');
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

        foreach( var name; ['APS','ALT-profile','SPD-profile','HOLD','RTE','WPT'] )
        load_deps( name );

    })();

    
});