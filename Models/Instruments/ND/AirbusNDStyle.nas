# ==============================================================================
# Airbus Navigation Display by Artix based on Boeing ND Gijs de Rooy
# ==============================================================================

##
# do we really need to keep track of each drawable here ??
var i = 0;

##
# pseudo DSL-ish: use these as placeholders in the config hash  below
var ALWAYS = func 1;
var NOTHING = func nil;

##
# so that we only need to update a single line ...
#
var trigger_update = func(layer)  layer._model.init();

##
# TODO: move ND-specific implementation details into this lookup hash
# so that other aircraft and ND types can be more easily supported
#
# any aircraft-specific ND behavior should be wrapped here,
# to isolate/decouple things in the generic NavDisplay class
#
# TODO: move this to an XML config file
#
var aircraft_dir = split('/', getprop("/sim/aircraft-dir"))[-1];

canvas.NDStyles["Airbus"] = {
        font_mapper: func(family, weight) {
            if( family == "Liberation Sans" and weight == "normal" )
                return "LiberationFonts/LiberationSans-Regular.ttf";
        },

        # where all the symbols are stored
        # TODO: SVG elements should be renamed to use boeing/airbus prefix
        # aircraft developers should all be editing the same ND.svg image
        # the code can deal with the differences now
        svg_filename: "Aircraft/" ~ aircraft_dir ~ "/Models/Instruments/ND/res/airbusND.svg",
        ##
        ## this loads and configures existing layers (currently, *.layer files in Nasal/canvas/map)
        ##

        layers: [
            { name:'fixes', disabled:1, update_on:['toggle_range','toggle_waypoints'],
                predicate: func(nd, layer) {
                    # print("Running fixes predicate");
                    var visible=nd.get_switch('toggle_waypoints') and nd.in_mode('toggle_display_mode', ['MAP']) and (nd.rangeNm() <= 40);
                    if (visible) {
                        # print("fixes update requested!");
                        trigger_update( layer );
                    }
                    layer._view.setVisible(visible);
                }, # end of layer update predicate
            }, # end of fixes layer
            { name:'FIX', isMapStructure:1, update_on:['toggle_range','toggle_waypoints'],
                # FIXME: this is a really ugly place for controller code
                predicate: func(nd, layer) {
                    # print("Running vor layer predicate");
                    # toggle visibility here
                    var visible=nd.get_switch('toggle_waypoints') and nd.in_mode('toggle_display_mode', ['MAP']) and (nd.rangeNm() <= 40);
                    layer.group.setVisible( nd.get_switch('toggle_waypoints') );
                    if (visible) {
                        #print("Updating MapStructure ND layer: FIX");
                        # (Hopefully) smart update
                        layer.update();
                    }
                }, # end of layer update predicate
            }, # end of FIX layer
            # Should redraw every 10 seconds
            { name:'storms', update_on:['toggle_range','toggle_weather','toggle_display_mode'],
                predicate: func(nd, layer) {
                    # print("Running fixes predicate");
                    var visible=nd.get_switch('toggle_weather') and nd.get_switch('toggle_display_mode') != "PLAN";
                    if (visible) {
                        #print("storms update requested!");
                        trigger_update( layer );
                    }
                    layer._view.setVisible(visible);
                }, # end of layer update predicate
            }, # end of storms layer
            { name:'airplaneSymbol', update_on:['toggle_display_mode','toggle_plan_loop'],
                predicate: func(nd, layer) {
                    var visible = nd.get_switch('toggle_display_mode') == "PLAN";
                    if (visible) {
                        trigger_update( layer );
                    } 
                    layer._view.setVisible(visible);
                },
            },
            { name:'airports-nd', update_on:['toggle_range','toggle_airports','toggle_display_mode'],
                predicate: func(nd, layer) {
                    # print("Running airports-nd predicate");
                    var visible = nd.get_switch('toggle_airports') and nd.in_mode('toggle_display_mode', ['MAP']);
                    if (visible) {
                        trigger_update( layer ); # clear & redraw
                    }
                    layer._view.setVisible( visible );
                }, # end of layer update predicate
            }, # end of airports layer

            # Should distinct between low and high altitude navaids. Hiding above 40 NM for now, to prevent clutter/lag.
            { name:'vor', disabled:1, update_on:['toggle_range','toggle_vor','toggle_display_mode'],
                predicate: func(nd, layer) {
                    # print("Running vor layer predicate");
                    var visible = nd.get_switch('toggle_vor') and nd.in_mode('toggle_display_mode', ['MAP']) and (nd.rangeNm() <= 40);
                    if(visible) {
                        trigger_update( layer ); # clear & redraw
                    }
                    layer._view.setVisible( nd.get_switch('toggle_vor') );
                }, # end of layer update predicate
            }, # end of VOR layer
            { name:'VOR', isMapStructure:1, update_on:['toggle_range','toggle_vor','toggle_display_mode'],
                # FIXME: this is a really ugly place for controller code
                predicate: func(nd, layer) {
                    # print("Running vor layer predicate");
                    # toggle visibility here
                    var visible = nd.get_switch('toggle_vor') and nd.in_mode('toggle_display_mode', ['MAP']) and (nd.rangeNm() <= 40);
                    layer.group.setVisible( visible );
                    if (visible) {
                        #print("Updating MapStructure ND layer: VOR");
                        # (Hopefully) smart update
                        layer.update();
                    }
                }, # end of layer update predicate
            }, # end of VOR layer

            # Should distinct between low and high altitude navaids. Hiding above 40 NM for now, to prevent clutter/lag.
            { name:'ndb', disabled:1, update_on:['toggle_range','toggle_ndb'],
                predicate: func(nd, layer) {
                    var visible = nd.get_switch('toggle_ndb') and nd.in_mode('toggle_display_mode', ['MAP']) and (nd.rangeNm() <= 40);
                    if(visible) {
                        trigger_update( layer ); # clear & redraw
                    }
                    layer._view.setVisible( nd.get_switch('toggle_ndb') );
                }, # end of layer update predicate
            }, # end of NDB layers
            { name:'NDB', isMapStructure:1, update_on:['toggle_range','toggle_ndb'],
                # FIXME: this is a really ugly place for controller code
                predicate: func(nd, layer) {
                    var visible = nd.get_switch('toggle_ndb') and nd.in_mode('toggle_display_mode', ['MAP']) and (nd.rangeNm() <= 40);
                    # print("Running vor layer predicate");
                    # toggle visibility here
                    layer.group.setVisible( visible );
                    if (visible) {
                        #print("Updating MapStructure ND layer: NDB");
                        # (Hopefully) smart update
                        layer.update();
                    }
                }, # end of layer update predicate
            }, # end of NDB layer

            { name:'mp-traffic', update_on:['toggle_range','toggle_traffic'],
                predicate: func(nd, layer) {
                    var visible = nd.get_switch('toggle_traffic');
                    layer._view.setVisible( visible );
                    if (visible) {
                        trigger_update( layer ); # clear & redraw
                    }
                }, # end of layer update predicate
            }, # end of traffic  layer
            { name:'TFC', disabled:1, isMapStructure:1, update_on:['toggle_range','toggle_traffic'],
                predicate: func(nd, layer) {
                    var visible = nd.get_switch('toggle_traffic');
                    layer.group.setVisible( visible );
                    if (visible) {
                        #print("Updating MapStructure ND layer: TFC");
                        layer.update();
                    }
                }, # end of layer update predicate
            }, # end of traffic  layer

            { name:'runway-nd', update_on:['toggle_range','toggle_display_mode'],
                predicate: func(nd, layer) {
                    var visible = (nd.rangeNm() <= 40) and getprop("autopilot/route-manager/active") and nd.in_mode('toggle_display_mode', ['MAP','PLAN']) ;
                    if (visible)
                        trigger_update( layer ); # clear & redraw
                    layer._view.setVisible( visible );
                }, # end of layer update predicate
            }, # end of airports-nd layer

{ name:'route', update_on:['toggle_range','toggle_display_mode', 'toggle_fplan', 'toggle_vnav', 'toggle_lnav', 'toggle_cstr','toggle_wpt_idx'],
                predicate: func(nd, layer) {
                    var visible= (nd.in_mode('toggle_display_mode', ['MAP','PLAN']));
                    if (visible)
                        trigger_update( layer ); # clear & redraw
                    layer._view.setVisible( visible );
                }, # end of layer update predicate
            }, # end of route layer

            ## add other layers here, layer names must match the registered names as used in *.layer files for now
            ## this will all change once we're using Philosopher's MapStructure framework

        ], # end of vector with configured layers

        # This is where SVG elements are configured by providing "behavior" hashes, i.e. for animations

        # to animate each SVG symbol, specify behavior via callbacks (predicate, and true/false implementation)
        # SVG identifier, callback  etc
        # TODO: update_on([]), update_mode (update() vs. timers/listeners)
        # TODO: support putting symbols on specific layers
        features: [
            {
                # TODO: taOnly doesn't need to use getprop polling in update(), use a listener instead!
                id: 'taOnly', # the SVG ID
                impl: { # implementation hash
                    init: func(nd, symbol), # for updateCenter stuff, called during initialization in the ctor
                    predicate: func(nd) getprop("instrumentation/tcas/inputs/mode") == 2, # the condition
                    is_true:   func(nd) nd.symbols.taOnly.show(), 			# if true, run this
                    is_false:  func(nd) nd.symbols.taOnly.hide(), 			# if false, run this
                }, # end of taOnly  behavior/callbacks
            }, # end of taOnly
            {
                id: 'tas',
                impl: {
                    init: func(nd,symbol),
                    predicate: func(nd) nd.aircraft_source.get_spd() > 100,
                    is_true: func(nd) {
                        nd.symbols.tas.setText(sprintf("%3.0f",getprop("/velocities/airspeed-kt") ));
                        nd.symbols.tas.show();
                    },
                    is_false: func(nd) nd.symbols.tas.hide(),
                },
            },
            {
                id: 'tasLbl',
                impl: {
                    init: func(nd,symbol),
                    predicate: func(nd) nd.aircraft_source.get_spd() > 100,
                    is_true: func(nd) nd.symbols.tasLbl.show(),
                    is_false: func(nd) nd.symbols.tasLbl.hide(),
                },
            },
            {
                id: 'ilsFreq',
                impl: {
                    init: func(nd,symbol),
                    predicate: func(nd) nd.in_mode('toggle_display_mode', ['APP', 'VOR']),
                    is_true: func(nd) {
                        nd.symbols.ilsFreq.show();
                        #if(getprop("instrumentation/nav/in-range"))
                        #    nd.symbols.ilsFreq.setText(getprop("instrumentation/nav/nav-id"));
                        #else
                            #nd.symbols.ilsFreq.setText(getprop("instrumentation/nav/frequencies/selected-mhz-fmt"));
                        nd.symbols.ilsFreq.setText(getprop("instrumentation/nav/frequencies/selected-mhz-fmt"));
                        if(nd.get_switch('toggle_display_mode') == 'APP')
                            nd.symbols.ilsFreq.setColor(0.69,0,0.39);
                        else
                            nd.symbols.ilsFreq.setColor(1,1,1);
                    },
                    is_false: func(nd) nd.symbols.ilsFreq.hide(),
                },
            },
            {
                id: 'ilsLbl',
                impl: {
                    init: func(nd,symbol),
                    predicate: func(nd) nd.in_mode('toggle_display_mode', ['APP', 'VOR']),
                    is_true: func(nd) {
                        nd.symbols.ilsLbl.show();
                        if(nd.get_switch('toggle_display_mode') == 'APP')
                            nd.symbols.ilsLbl.setText('ILS');
                        else
                            nd.symbols.ilsLbl.setText('VOR 1');
                    },
                    is_false: func(nd) nd.symbols.ilsLbl.hide(),
                },
            },
            {
                id: 'wpActiveId',
                impl: {
                    init: func(nd,symbol),
                    predicate: func(nd) getprop("/autopilot/route-manager/wp/id") != nil and getprop("autopilot/route-manager/active") and nd.in_mode('toggle_display_mode', ['MAP', 'PLAN']),
                    is_true: func(nd) {
                        nd.symbols.wpActiveId.setText(getprop("/autopilot/route-manager/wp/id"));
                        nd.symbols.wpActiveId.show();
                    },
                    is_false: func(nd) nd.symbols.wpActiveId.hide(),
                }, # of wpActiveId.impl
            }, # of wpActiveId
            {
                id: 'wpActiveCrs',
                impl: {
                    init: func(nd,symbol),
                    predicate: func(nd) getprop("/autopilot/route-manager/wp/id") != nil and getprop("autopilot/route-manager/active") and nd.in_mode('toggle_display_mode', ['MAP', 'PLAN']),
                    is_true: func(nd) {
                        var deg = int(getprop("/autopilot/route-manager/wp/bearing-deg"));
                        nd.symbols.wpActiveCrs.setText(''~deg~'°');
                        nd.symbols.wpActiveCrs.show();
                    },
                    is_false: func(nd) nd.symbols.wpActiveCrs.hide(),
                }, # of wpActiveId.impl
            }, # of wpActiveId
            {
                id: 'wpActiveDist',
                impl: {
                    init: func(nd,symbol),
                    predicate: func(nd) getprop("/autopilot/route-manager/wp/dist") != nil and getprop("autopilot/route-manager/active"),
                    is_true: func(nd) {
                        nd.symbols.wpActiveDist.setText(sprintf("%3.01f",getprop("/autopilot/route-manager/wp/dist")));
                        nd.symbols.wpActiveDist.show();
                    },
                    is_false: func(nd) nd.symbols.wpActiveDist.hide(),
                },
            },
            {
                id: 'wpActiveDistLbl',
                impl: {
                    init: func(nd,symbol),
                    predicate: func(nd) getprop("/autopilot/route-manager/wp/dist") != nil and getprop("autopilot/route-manager/active"),
                    is_true: func(nd) {
                        nd.symbols.wpActiveDistLbl.show();
                        if(getprop("/autopilot/route-manager/wp/dist") > 1000)
                            nd.symbols.wpActiveDistLbl.setText("   NM");
                    },
                    is_false: func(nd) nd.symbols.wpActiveDistLbl.hide(),
                },
            },
            {
                id: 'eta',
                impl: {
                    init: func(nd,symbol),
                    predicate: func(nd) getprop("autopilot/route-manager/wp/eta") != nil and getprop("autopilot/route-manager/active"),
                    is_true: func(nd) {
                        var etaSec = getprop("/sim/time/utc/day-seconds")+getprop("autopilot/route-manager/wp/eta-seconds");
                        var h = math.floor(etaSec/3600);
                        etaSec=etaSec-3600*h;
                        var m = math.floor(etaSec/60);
                        etaSec=etaSec-60*m;
                        var s = etaSec/10;
                        if (h>24) h=h-24;
                        nd.symbols.eta.setText(sprintf("%02.0f%02.0f.%01.0fz",h,m,s));
                        nd.symbols.eta.show();
                    },
                    is_false: func(nd) nd.symbols.eta.hide(),
                },  # of eta.impl
            }, # of eta
            {
                id: 'gsGroup',
                impl: {
                    init: func(nd,symbol),
                    predicate: func(nd) nd.in_mode('toggle_display_mode', ['APP']),
                    is_true: func(nd) {
                        if(nd.get_switch('toggle_centered'))
                            nd.symbols.gsGroup.setTranslation(0,0);
                        else
                            nd.symbols.gsGroup.setTranslation(0,150);
                        nd.symbols.gsGroup.show();
                    },
                    is_false: func(nd) nd.symbols.gsGroup.hide(),
                },
            },
            {
                id:'hdg',
                impl: {
                    init: func(nd,symbol),
                    predicate: func(nd) nd.in_mode('toggle_display_mode', ['APP','MAP','VOR']),
                    is_true: func(nd) {
                        var hdgText = "";
                        if(nd.in_mode('toggle_display_mode', ['MAP'])) {
                            if(nd.get_switch('toggle_true_north'))
                                hdgText = nd.aircraft_source.get_trk_tru();
                            else
                                hdgText = nd.aircraft_source.get_trk_mag();
                        } else {
                            if(nd.get_switch('toggle_true_north'))
                                hdgText = nd.aircraft_source.get_hdg_tru();
                            else
                                hdgText = nd.aircraft_source.get_hdg_mag();
                        }
                        nd.symbols.hdg.setText(sprintf("%03.0f", hdgText+0.5));
                    },
                    is_false: NOTHING,
                },
            },
            {
                id:'hdgGroup',
                impl: {
                    init: func(nd,symbol),
                    predicate: func(nd) {return 0},#nd.in_mode('toggle_display_mode', ['APP','MAP','VOR']),
                    is_true: func(nd) {
                        nd.symbols.hdgGroup.show();
                        if(nd.get_switch('toggle_centered'))
                            nd.symbols.hdgGroup.setTranslation(0,100);
                        else
                            nd.symbols.hdgGroup.setTranslation(0,0);
                    },
                    is_false: func(nd) nd.symbols.hdgGroup.hide(),
                },
            },
            {
                id:'gs',
                impl: {
                    init: func(nd,symbol),
                    common: func(nd) nd.symbols.gs.setText(sprintf("%3.0f",nd.aircraft_source.get_gnd_spd() )),
                    predicate: func(nd) nd.aircraft_source.get_gnd_spd() >= 30,
                    is_true: func(nd) {
                        nd.symbols.gs.setFontSize(36);
                    },
                    is_false: func(nd) nd.symbols.gs.setFontSize(52),
                },
            },
            {
                id:'compassApp',
                    impl: {
                        init: func(nd,symbol),
                            predicate: func(nd) (nd.get_switch('toggle_centered') and  nd.get_switch('toggle_display_mode') != "PLAN"),
                            is_true: func(nd) nd.symbols.compassApp.show(),
                            is_false: func(nd) nd.symbols.compassApp.hide(),
                    }, # of compassApp.impl
            }, # of compassApp
            {
                id:'planArcs',
                    impl: {
                        init: func(nd,symbol),
                            predicate: func(nd) ((nd.in_mode('toggle_display_mode', ['APP','VOR','PLAN'])) or ((nd.get_switch('toggle_display_mode') == "MAP") and (nd.get_switch('toggle_centered')))),
                            is_true: func(nd) nd.symbols.planArcs.show(),
                            is_false: func(nd) nd.symbols.planArcs.hide(),
                    }, # of planArcs.impl
            }, # of planArcs
            {
                id:'rangeArcs',
                impl: {
                    init: func(nd,symbol),
                    predicate: func(nd) ((nd.get_switch('toggle_display_mode') == "MAP") and (!nd.get_switch('toggle_centered'))),
                    is_true: func(nd) nd.symbols.rangeArcs.show(),
                    is_false: func(nd) nd.symbols.rangeArcs.hide(),
                }, # of rangeArcs.impl
            }, # of rangeArcs
            {
                id:'rangePln1',
                impl: {
                    init: func(nd,symbol),
                    predicate: func(nd) {return 0},
                    is_true: func(nd) {
                        nd.symbols.rangePln1.show();
                        nd.symbols.rangePln1.setText(sprintf("%3.0f",nd.rangeNm()));
                    },
                    is_false: func(nd) nd.symbols.rangePln1.hide(),
                },
            },
            {
                id:'rangePln2',
                impl: {
                    init: func(nd,symbol),
                    predicate: func(nd) {return 0},
                    is_true: func(nd) {
                        nd.symbols.rangePln2.show();
                        nd.symbols.rangePln2.setText(sprintf("%3.0f",nd.rangeNm()/2));
                    },
                    is_false: func(nd) nd.symbols.rangePln2.hide(),
                },
            },
            {
                id:'rangePln3',
                impl: {
                    init: func(nd,symbol),
                    predicate: func(nd) nd.get_switch('toggle_display_mode') == "PLAN" or nd.get_switch('toggle_centered'),
                    is_true: func(nd) {
                        nd.symbols.rangePln3.show();
                        nd.symbols.rangePln3.setText(sprintf("%3.0f",nd.rangeNm()/2));
                    },
                    is_false: func(nd) nd.symbols.rangePln3.hide(),
                },
            },
            {
                id:'rangePln4',
                impl: {
                    init: func(nd,symbol),
                    predicate: func(nd) nd.get_switch('toggle_display_mode') == "PLAN" or nd.get_switch('toggle_centered'),
                    is_true: func(nd) {
                        nd.symbols.rangePln4.show();
                        nd.symbols.rangePln4.setText(sprintf("%3.0f",nd.rangeNm()));
                    },
                    is_false: func(nd) nd.symbols.rangePln4.hide(),
                },
            },
            {
                id:'range',
                impl: {
                    init: func(nd,symbol),
                    predicate: func(nd) !nd.get_switch('toggle_centered'),
                    is_true: func(nd) {
                        nd.symbols.range.show();
                    },
                    is_false: func(nd) nd.symbols.range.hide(),
                },
            },
            {
                id:'aplSymMap',
                    impl: {
                        init: func(nd,symbol),
                            predicate: func(nd) (nd.get_switch('toggle_display_mode') == "MAP" and !nd.get_switch('toggle_centered')),
                                is_true: func(nd) {
                                    nd.symbols.aplSymMap.show();

                                },
                                is_false: func(nd) nd.symbols.aplSymMap.hide(),
                    },
            },
            {
                id:'aplSymMapCtr',
                    impl: {
                        init: func(nd,symbol),
                            predicate: func(nd) ((nd.get_switch('toggle_display_mode') == "MAP" and nd.get_switch('toggle_centered')) or nd.in_mode('toggle_display_mode', ['APP','VOR'])),
                                is_true: func(nd) {
                                    nd.symbols.aplSymMapCtr.show();

                                },
                                is_false: func(nd) nd.symbols.aplSymMapCtr.hide(),
                    },
            },
            {
                id:'aplSymVor',
                    impl: {
                        init: func(nd,symbol),
                            predicate: func(nd) {return 0;},
                                is_true: func(nd) {
                                    nd.symbols.aplSymVor.show();

                                },
                                    is_false: func(nd) nd.symbols.aplSymVor.hide(),
                    },
            },
            {
                id:'crsLbl',
                impl: {
                    init: func(nd,symbol),
                    predicate: func(nd) nd.in_mode('toggle_display_mode', ['APP','VOR']),
                    is_true: func(nd) nd.symbols.crsLbl.show(),
                    is_false: func(nd) nd.symbols.crsLbl.hide(),
                },
            },
            {
                id:'crs',
                impl: {
                    init: func(nd,symbol),
                    predicate: func(nd) nd.in_mode('toggle_display_mode', ['APP','VOR']),
                    is_true: func(nd) {
                        nd.symbols.crs.show();
                        if(getprop("instrumentation/nav/radials/selected-deg") != nil)
                            nd.symbols.crs.setText(sprintf("%03.0f",getprop("instrumentation/nav/radials/selected-deg")));
                    },
                    is_false: func(nd) nd.symbols.crs.hide(),
                },
            },
            {
                id:'dmeLbl',
                impl: {
                    init: func(nd,symbol),
                    predicate: func(nd) nd.in_mode('toggle_display_mode', ['APP','VOR']),
                    is_true: func(nd) nd.symbols.dmeLbl.show(),
                    is_false: func(nd) nd.symbols.dmeLbl.hide(),
                },
            },
            {
                id:'dme',
                impl: {
                    init: func(nd,symbol),
                    predicate: func(nd) nd.in_mode('toggle_display_mode', ['APP','VOR']),
                    is_true: func(nd) {
                        nd.symbols.dme.show();
                        #if(getprop("instrumentation/dme/in-range"))
                        #    nd.symbols.dme.setText(sprintf("%3.1f",getprop("instrumentation/nav/nav-distance")*0.000539));
                        nd.symbols.dme.setText(getprop("instrumentation/nav/nav-id"));
                        if(nd.get_switch('toggle_display_mode') == 'APP')
                            nd.symbols.dme.setColor(0.69,0,0.39);
                        else
                            nd.symbols.dme.setColor(1,1,1);
                    },
                    is_false: func(nd) nd.symbols.dme.hide(),
                },
            },
            {
                id:'trkInd2',
                impl: {
                    init: func(nd,symbol),
                    predicate: func(nd) (nd.in_mode('toggle_display_mode', ['APP','VOR','MAP']) and nd.get_switch('toggle_centered')),
                    is_true: func(nd) {
                        nd.symbols.trkInd2.show();
                        nd.symbols.trkInd2.setRotation((nd.aircraft_source.get_trk_tru()-nd.aircraft_source.get_hdg_tru())*D2R);
                    },
                    is_false: func(nd) nd.symbols.trkInd2.hide(),
                },
            },
            {
                id:'vorCrsPtr',
                impl: {
                    init: func(nd,symbol),
                    predicate: func(nd) (nd.in_mode('toggle_display_mode', ['APP','VOR']) and !nd.get_switch('toggle_centered')),
                    is_true: func(nd) {
                        nd.symbols.vorCrsPtr.show();
                        nd.symbols.vorCrsPtr.setRotation((getprop("instrumentation/nav/radials/selected-deg")-nd.aircraft_source.get_hdg_tru())*D2R);

                    },
                    is_false: func(nd) nd.symbols.vorCrsPtr.hide(),
                },
            },
            {
                id:'vorCrsPtr2',
                impl: {
                    init: func(nd,symbol),
                    predicate: func(nd) (nd.in_mode('toggle_display_mode', ['APP','VOR']) and nd.get_switch('toggle_centered')),
                    is_true: func(nd) {
                        nd.symbols.vorCrsPtr2.show();
                        nd.symbols.vorCrsPtr2.setRotation((getprop("instrumentation/nav/radials/selected-deg")-nd.aircraft_source.get_hdg_tru())*D2R);
                        var line = nd.symbols.vorCrsPtr2.getElementById('vorCrsPtr2_line');
                        if(nd.get_switch('toggle_display_mode') == 'VOR'){
                            #nd.symbols.vorCrsPtr2.setColor(0,0.62,0.84);
                            line.setColor(0,0.62,0.84);
                            line.setColorFill(0,0.62,0.84);
                        } else {
                            line.setColor(1,0,1);
                            line.setColorFill(1,0,1);
                        }
                    },
                    is_false: func(nd) nd.symbols.vorCrsPtr2.hide(),
                },
            },
            {
                id: 'gsDiamond',
                impl: {
                    init: func(nd,symbol),
                    predicate: func(nd) nd.in_mode('toggle_display_mode', ['APP']),
                    is_true: func(nd) {
                        if(getprop("instrumentation/nav/gs-needle-deflection-norm") != nil)
                            nd.symbols.gsDiamond.setTranslation(-getprop("instrumentation/nav/gs-needle-deflection-norm")*150,0);
                    },
                    is_false: func(nd) nd.symbols.gsGroup.hide(),
                },
            },
            {
                id:'locPtr',
                impl: {
                    init: func(nd,symbol),
                    predicate: func(nd) (nd.in_mode('toggle_display_mode', ['APP','VOR']) and !nd.get_switch('toggle_centered') and getprop("instrumentation/nav/in-range")),
                    is_true: func(nd) {
                        nd.symbols.locPtr.show();
                        var deflection = getprop("instrumentation/nav/heading-needle-deflection-norm");
                        nd.symbols.locPtr.setTranslation(deflection*150,0);
                        #if(abs(deflection) < 0.99)
                        #	nd.symbols.locPtr.setColorFill(1,0,1,1);
                        #else
                        #	nd.symbols.locPtr.setColorFill(1,0,1,0);
                    },
                    is_false: func(nd) nd.symbols.locPtr.hide(),
                },
            },
            {
                id:'locPtr2',
                impl: {
                    init: func(nd,symbol),
                    predicate: func(nd) (nd.in_mode('toggle_display_mode', ['APP','VOR']) and nd.get_switch('toggle_centered') and getprop("instrumentation/nav/in-range")),
                    is_true: func(nd) {
                        nd.symbols.locPtr2.show();
                        var deflection = getprop("instrumentation/nav/heading-needle-deflection-norm");
                        nd.symbols.locPtr2.setTranslation(deflection*150,0);
                        #if(abs(deflection) < 0.99)
                        #	nd.symbols.locPtr2.setColorFill(1,0,1,1);
                        #else
                        #	nd.symbols.locPtr2.setColorFill(1,0,1,0);
                        var line = nd.symbols.locPtr2.getElementById('locPtr2_line');
                        var arr1 = nd.symbols.locPtr2.getElementById('locPtr2_arr1');
                        var arr2 = nd.symbols.locPtr2.getElementById('locPtr2_arr2');
                        if(nd.get_switch('toggle_display_mode') == 'VOR'){
                            #nd.symbols.vorCrsPtr2.setColor(0,0.62,0.84);
                            line.setColor(0,0.62,0.84);
                            line.setColorFill(0,0.62,0.84);
                            arr1.show();
                            arr2.show();
                        } else {
                            line.setColor(1,0,1);
                            line.setColorFill(1,0,1);
                            arr1.hide();
                            arr2.hide();
                        }
                    },
                    is_false: func(nd) nd.symbols.locPtr2.hide(),
                },
            },
            {
                id:'wind',
                impl: {
                    init: func(nd,symbol),
                    predicate: ALWAYS,
                    is_true: func(nd) {
                        var windDir = getprop("environment/wind-from-heading-deg");
                        if(!nd.get_switch('toggle_true_north'))
                            windDir = windDir + getprop("environment/magnetic-variation-deg");
                        nd.symbols.wind.setText(sprintf("%03.0f / %02.0f",windDir,getprop("environment/wind-speed-kt")));
                    },
                    is_false: NOTHING,
                },
            },
            {
                id:'windArrow',
                impl: {
                    init: func(nd,symbol),
                    predicate: func(nd) (!(nd.in_mode('toggle_display_mode', ['PLAN']) and (nd.get_switch('toggle_display_type') == "LCD"))),
                    is_true: func(nd) {
                        nd.symbols.windArrow.show();
                        var windArrowRot = getprop("environment/wind-from-heading-deg");
                        if(nd.in_mode('toggle_display_mode', ['MAP','PLAN'])) {
                            if(nd.get_switch('toggle_true_north'))
                                windArrowRot = windArrowRot - nd.aircraft_source.get_trk_tru();
                            else
                                windArrowRot = windArrowRot - nd.aircraft_source.get_trk_mag();
                        } else {
                            if(nd.get_switch('toggle_true_north'))
                                windArrowRot = windArrowRot - nd.aircraft_source.get_hdg_tru();
                            else
                                windArrowRot = windArrowRot - nd.aircraft_source.get_hdg_mag();
                        }
                        nd.symbols.windArrow.setRotation(windArrowRot*D2R);
                    },
                    is_false: func(nd) nd.symbols.windArrow.hide(),
                },
            },
            {
                id:'staToL2',
                impl: {
                    init: func(nd,symbol),
                    predicate: func(nd) !(nd.in_mode('toggle_display_mode', ['PLAN', 'MAP'])) and ((getprop("instrumentation/nav/in-range") and nd.get_switch('toggle_lh_vor_adf') == 1) or (getprop("instrumentation/adf/in-range") and nd.get_switch('toggle_lh_vor_adf') == -1)),
                    is_true: func(nd) {
                        nd.symbols.staToL2.setColor(1,1,1);
                        nd.symbols.staFromL2.setColor(1,1,1);
                        nd.symbols.staToL2.show();
                        nd.symbols.staFromL2.show();
                    },
                    is_false: func(nd){
                        nd.symbols.staToL2.hide();
                        nd.symbols.staFromL2.hide();
                    }
                }
            },
            {
                id:'staToR2',
                impl: {
                    init: func(nd,symbol),
                    predicate: func(nd) !(nd.in_mode('toggle_display_mode', ['PLAN', 'MAP'])) and ((getprop("instrumentation/nav[1]/in-range") and nd.get_switch('toggle_rh_vor_adf') == 1) or (getprop("instrumentation/adf[1]/in-range") and nd.get_switch('toggle_rh_vor_adf') == -1)),
                    is_true: func(nd) {
                        nd.symbols.staToR2.setColor(1,1,1);
                        nd.symbols.staFromR2.setColor(1,1,1);
                        nd.symbols.staToR2.show();
                        nd.symbols.staFromR2.show();
                    },
                    is_false: func(nd){
                        nd.symbols.staToR2.hide();
                        nd.symbols.staFromR2.hide();
                    }
                }
            },
            {
                id:'dmeL',
                impl: {
                    init: func(nd,symbol),
                    predicate: func(nd) (nd.get_switch('toggle_lh_vor_adf') != 0),
                    is_true: func(nd) {
                        nd.symbols.dmeL.show();
                        nd.symbols.vorL.setText("VOR 1");
                        nd.symbols.dmeL.setText('NM');
                        nd.symbols.dmeL.setColor(0,0.59,0.8);
                    },
                    is_false: func(nd){
                        nd.symbols.dmeL.hide();
                    }
                }
            },
            {
                id:'dmeR',
                impl: {
                    init: func(nd,symbol),
                    predicate: func(nd) (nd.get_switch('toggle_rh_vor_adf') != 0),
                    is_true: func(nd) {
                        nd.symbols.dmeR.show();
                        nd.symbols.vorR.setText("VOR 2");
                        nd.symbols.dmeR.setText('NM');
                        nd.symbols.dmeR.setColor(0,0.59,0.8);
                    },
                    is_false: func(nd){
                        nd.symbols.dmeR.hide();
                    }
                }
            },
            {
                id:'vorLSym',
                impl: {
                    init: func(nd,symbol),
                    predicate: func(nd) (nd.get_switch('toggle_lh_vor_adf') != 0),
                    is_true: func(nd) {
                        nd.symbols.vorLSym.show();
                    },
                    is_false: func(nd){
                        nd.symbols.vorLSym.hide();
                    }
                }
            },
            {
                id:'vorRSym',
                impl: {
                    init: func(nd,symbol),
                    predicate: func(nd) (nd.get_switch('toggle_rh_vor_adf') != 0),
                    is_true: func(nd) {
                        nd.symbols.vorRSym.show();
                    },
                    is_false: func(nd){
                        nd.symbols.vorRSym.hide();
                    }
                }
            }

        ], # end of vector with features

}

