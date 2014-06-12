##
# storage container for all ND instances 
var nd_display = {};

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
	'toggle_waypoints': 	{path: '/inputs/wpt', value:0, type:'BOOL'},
	'toggle_position': 	{path: '/inputs/pos', value:0, type:'BOOL'},
	'toggle_data': 		{path: '/inputs/data',value:0, type:'BOOL'},
	'toggle_terrain': 	{path: '/inputs/terr',value:0, type:'BOOL'},
	'toggle_traffic': 		{path: '/inputs/tfc',value:0, type:'BOOL'},
	'toggle_centered': 		{path: '/inputs/nd-centered',value:0, type:'BOOL'},
	'toggle_lh_vor_adf':	{path: '/inputs/lh-vor-adf',value:0, type:'INT'},
	'toggle_rh_vor_adf':	{path: '/inputs/rh-vor-adf',value:0, type:'INT'},
	'toggle_display_mode': 	{path: '/nd/canvas-display-mode', value:'NAV', type:'STRING'},
	'toggle_display_type': 	{path: '/mfd/display-type', value:'LCD', type:'STRING'},
	'toggle_true_north': 	{path: '/mfd/true-north', value:0, type:'BOOL'},
	# add new switches here
      };       
    
            
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
        .setScale(0.5,0.5); # FIXME: do proper LOD handling here - we need to scale according to current texture dimensions vs. original/design dimensions
        # the fix label
        me.text_ndb = me.element.createChild("text")
        .setDrawMode( canvas.Text.TEXT )
        .setText(me.model.id)
        .setFont("LiberationFonts/LiberationSans-Regular.ttf")
        .setFontSize(28)
        .setTranslation(5,25);
    } 
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

		
	print("ND Canvas Initialized!");

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

var showNd = func() {
	# The optional second arguments enables creating a window decoration
	var dlg = canvas.Window.new([400, 400], "dialog");
	dlg.setCanvas( nd_display["main"] );
}


