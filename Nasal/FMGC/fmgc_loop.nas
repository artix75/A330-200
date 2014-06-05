var fmgc = "/flight-management/control/";
var settings = "/flight-management/settings/";
var fcu = "/flight-management/fcu-values/";
var fmgc_val = "/flight-management/fmgc-values/";
var servo = "/servo-control/";

setprop("/flight-management/text/qnh", "QNH");

setprop(settings~ "gps-accur", "LOW");

setprop("/flight-management/end-flight", 0);

var fmgc_loop = {
    init : func {
    me.UPDATE_INTERVAL = 0.1;
    me.loopid = 0;

    me.current_wp = 0;

    setprop("/flight-management/current-wp", me.current_wp);
    setprop("/flight-management/control/qnh-mode", 'inhg');

    # ALT SELECT MODE

    setprop(fmgc~ "alt-sel-mode", "100"); # AVAIL MODES : 100 1000

    # AUTO-THROTTLE

    setprop(fmgc~ "spd-mode", "ias"); # AVAIL MODES : ias mach
    setprop(fmgc~ "spd-ctrl", "man-set"); # AVAIL MODES : --- fmgc man-set

    setprop(fmgc~ "a-thr/ias", 0);
    setprop(fmgc~ "a-thr/mach", 0);

    setprop(fmgc~ "fmgc/ias", 0);
    setprop(fmgc~ "fmgc/mach", 0);

    # AUTOPILOT (LATERAL)

    setprop(fmgc~ "lat-mode", "hdg"); # AVAIL MODES : hdg nav1
    setprop(fmgc~ "lat-ctrl", "man-set"); # AVAIL MODES : --- fmgc man-set

    # AUTOPILOT (VERTICAL)

    setprop(fmgc~ "ver-mode", "alt"); # AVAIL MODES : alt (vs/fpa) ils
    setprop(fmgc~ "ver-sub", "vs"); # AVAIL MODES : vs fpa
    setprop(fmgc~ "ver-ctrl", "man-set"); # AVAIL MODES : --- fmgc man-set

    # AUTOPILOT (MASTER)

    setprop(fmgc~ "ap1-master", "off");
    setprop(fmgc~ "ap2-master", "off");
    setprop(fmgc~ "a-thrust", "off");

    # Rate/Load Factor Configuration

    setprop(settings~ "pitch-norm", 0.1);
    setprop(settings~ "roll-norm", 0.2);

    # Terminal Procedure

    setprop("/flight-management/procedures/active", "off"); # AVAIL MODES : off sid star iap

    # Set Flight Control Unit Initial Values

    setprop(fcu~ "ias", 250);
    setprop(fcu~ "mach", 0.78);

    setprop(fcu~ "alt", 10000);
    setprop(fcu~ "vs", 1800);
    setprop(fcu~ "fpa", 5);

    setprop(fcu~ "hdg", 0);

    setprop(fmgc_val~ "ias", 250);
    setprop(fmgc_val~ "mach", 0.78);

    # Servo Control Settings

    setprop(servo~ "aileron", 0);
    setprop(servo~ "aileron-nav1", 0);
    setprop(servo~ "target-bank", 0);

    setprop(servo~ "elevator-vs", 0);
    setprop(servo~ "elevator", 0);
    setprop(servo~ "target-pitch", 0);
    
    setprop(servo~ "fd-aileron", 0);
    setprop(servo~ "fd-aileron-nav1", 0);
    setprop(servo~ "fd-target-bank", 0);

    #setprop(servo~ "fd-elevator-vs", 0);
    #setprop(servo~ "fd-elevator-gs", 0);
    #setprop(servo~ "fd-elevator", 0);
    setprop(servo~ "fd-target-pitch", 0);

    me.vne = getprop('limits/vne');
    me.reset();
},
update : func {   	

        var altitude = getprop("/instrumentation/altimeter/indicated-altitude-ft");

        var vmode_vs_fps = getprop('/velocities/vertical-speed-fps');
        setprop("/instrumentation/pfd/vs-100", vmode_vs_fps * 0.6);
        if(vmode_vs_fps > 8 or vmode_vs_fps < -8){
            setprop('/flight-management/flch_active', 1);     
        } else {
            setprop('/flight-management/flch_active', 0);     
        }

        me.flight_phase();

        me.get_settings();

        me.lvlch_check();

        me.knob_sum();

        me.hdg_disp();

        me.fcu_lights();

        setprop("flight-management/procedures/active", procedure.check());

        setprop(fcu~ "alt-100", me.alt_100());
        var flaps = getprop("/controls/flight/flaps");
        var ias = getprop("/velocities/airspeed-kt");
        var stall_spd = 0;
        if(flaps <= 0.29)
            stall_spd = 150;
        elsif(flaps == 0.596)
            stall_spd = 135;
        elsif(flaps >= 0.74)
            stall_spd = 120;
        setprop(fmgc_val ~ 'stall-speed', stall_spd);
        setprop(fmgc_val ~ 'ind-stall-speed', stall_spd - 125);

        var top_desc = me.calc_td();
    	me.calc_tc();
    	var decel_point = me.calc_decel_point();
    	var plan_mode = getprop("/instrumentation/nd/plan-mode");
    	if(plan_mode != nil and plan_mode){
        	setprop("/instrumentation/nd/symbols/aircraft/latitude-deg", getprop('position/latitude-deg'));
        	setprop("/instrumentation/nd/symbols/aircraft/longitude-deg", getprop('position/longitude-deg'));
        	setprop("/instrumentation/nd/symbols/aircraft/true-heading-deg", getprop('orientation/heading-magnetic-deg'));   
    	} else {
            setprop("/instrumentation/nd/symbols/aircraft", '');
        }
        var flplan_active = getprop("/autopilot/route-manager/active");	
        if (flplan_active and  !getprop("/flight-management/freq/ils")){
            var dest_airport = getprop("/autopilot/route-manager/destination/airport");
            var dest_rwy = getprop("/autopilot/route-manager/destination/runway");
            if(dest_airport and dest_rwy){
                var apt_info = airportinfo(dest_airport);
                var rwy_ils = apt_info.runways[dest_rwy].ils;
                if(rwy_ils != nil){
                    var frq = rwy_ils.frequency / 100;
                    var crs = rwy_ils.course;
                    var dist = getprop("/autopilot/route-manager/wp-last/dist");
                    if(dist <= 50){
                        var radio = "/flight-management/freq/";
                        setprop("/flight-management/freq/ils", frq);
                        setprop("/flight-management/freq/ils-crs", int(crs));
                        if (getprop(radio~ "ils-mode")) {

                                mcdu.rad_nav.switch_nav1(1);

                        }
                    }
                }
            }
        }

        # SET OFF IF NOT USED

        if (me.lat_ctrl != "fmgc") {

            setprop("/flight-management/hold/init", 0);

        }

        # Turn off rudder control when AP is off

        if ((me.ap1 == "off") and (me.ap2 == "off")) {
            setprop("/autoland/rudder", 0);
            setprop("/autoland/active", 0);
            setprop("/autoland/phase", "disengaged")
        }

        if ((me.spd_ctrl == "off") or (me.a_thr == "off")) {

            setprop(fmgc~ "a-thr/ias", 0);
            setprop(fmgc~ "a-thr/mach", 0);

            setprop(fmgc~ "fmgc/ias", 0);
            setprop(fmgc~ "fmgc/mach", 0);

        }

        if ((me.lat_ctrl == "off") or ((me.ap1 == "off") and (me.ap2 == "off"))) {

            setprop(servo~ "aileron", 0);
            setprop(servo~ "aileron-nav1", 0);
            setprop(servo~ "target-bank", 0);

        }

        if ((me.ver_ctrl == "off") or ((me.ap1 == "off") and (me.ap2 == "off"))) {

            setprop(servo~ "elevator-vs", 0);
            setprop(servo~ "elevator-gs", 0);
            setprop(servo~ "elevator", 0);
            setprop(servo~ "target-pitch", 0);

        }

        # MANUAL SELECT MODE ===================================================

        ## AUTO-THROTTLE -------------------------------------------------------

        if ((me.spd_ctrl == "man-set") and (me.a_thr == "eng")) {

            if (me.spd_mode == "ias") {

                setprop(fmgc~ "a-thr/ias", 1);
                setprop(fmgc~ "a-thr/mach", 0);

                setprop(fmgc~ "fmgc/ias", 0);
                setprop(fmgc~ "fmgc/mach", 0);

            } else {

                setprop(fmgc~ "a-thr/ias", 0);
                setprop(fmgc~ "a-thr/mach", 1);

                setprop(fmgc~ "fmgc/ias", 0);
                setprop(fmgc~ "fmgc/mach", 0);

            }

        }

        var apEngaged = ((me.ap1 == "eng") or (me.ap2 == "eng"));
        var fdEngaged = getprop("flight-management/control/fd");
        #print("FMGC Loop: AP Eng -> " ~ apEngaged);
        if (!fdEngaged) {

            setprop(servo~ "fd-aileron", 0);
            setprop(servo~ "fd-aileron-nav1", 0);
            setprop(servo~ "fd-target-bank", 0);

            #setprop(servo~ "fd-elevator-vs", 0);
            #setprop(servo~ "fd-elevator-gs", 0);
            #setprop(servo~ "fd-elevator", 0);
            setprop(servo~ "fd-target-pitch", 0);

        }
        if (apEngaged or fdEngaged) {

            ## LATERAL CONTROL -----------------------------------------------------

            if (me.lat_ctrl == "man-set") {

                if (me.lat_mode == "hdg") {

                    # Find Heading Deflection

                    var bug = getprop(fcu~ "hdg");
                    print("HDG: bug -> " ~ bug);

                    var bank = -1 * defl(bug, 20);
                    print("HDG: bank -> " ~ bank);

                    var deflection = defl(bug, 180);
                    print("HDG: defl -> " ~ deflection);

                    if(apEngaged){
                        setprop(servo~  "aileron", 1);
                        setprop(servo~ "aileron-nav1", 0);

                        if (math.abs(deflection) <= 1)
                            setprop(servo~ "target-bank", 0);
                        else
                            setprop(servo~ "target-bank", bank);
                    }
                    setprop(servo~  "fd-aileron", 1);
                    setprop(servo~ "fd-aileron-nav1", 0);
                    if (math.abs(deflection) <= 1)
                        setprop(servo~ "fd-target-bank", 0);
                    else
                        setprop(servo~ "fd-target-bank", bank);

                } elsif (me.lat_mode == "nav1") {

                    var nav1_error = getprop("/autopilot/internal/nav1-track-error-deg");

                    var agl = getprop("/position/altitude-agl-ft");

                    var bank = limit(nav1_error, 30);

                    if (agl < 100) {

                        bank = 0; # Level the wings for AUTOLAND

                        setprop(servo~ "target-rudder", bank);	

                    }


                    if(apEngaged){
                        setprop(servo~ "aileron", 0);

                        setprop(servo~ "aileron-nav1", 1); 
                        setprop(servo~ "target-bank", bank);
                    }
                    setprop(servo~ "fd-aileron", 0);

                    setprop(servo~ "fd-aileron-nav1", 1); 	
                    setprop(servo~ "fd-target-bank", bank);

                } # else, this is handed over from fcu to fmgc

            }

            ## VERTICAL CONTROL ----------------------------------------------------

            var vs_setting = getprop(fcu~ "vs");

            var fpa_setting = getprop(fcu~ "fpa");

            if (me.ver_ctrl == "man-set") {

                if (me.ver_mode == "alt") {

                    if (me.ver_sub == "vs") {

                        var target = getprop(fcu~ "alt");

                        var trgt_vs = 0;

                        if (((altitude - target) * vs_setting) > 0) {

                            trgt_vs = limit((target - altitude) * 2, 200);

                        } else {

                            trgt_vs = limit2((target - altitude) * 2, vs_setting);

                        }
                        if(apEngaged){
                            setprop(servo~ "target-vs", trgt_vs / 60);
                            setprop(servo~ "elevator-vs", 1);
                            setprop(servo~ "elevator", 0);
                            setprop(servo~ "elevator-gs", 0);
                        }
                        #setprop(servo~ "fd-elevator-vs", 0);
                        #setprop(servo~ "fd-elevator", 0);
                        #setprop(servo~ "fd-elevator-gs", 0);
                        setprop(servo~ "fd-target-vs", trgt_vs / 60);
                        setprop(servo~ "fd-target-pitch", (trgt_vs / 60) * 0.1);

                    } else {

                        var target_alt = getprop(fcu~ "alt");

                        var trgt_fpa = limit2((target_alt - altitude) * 2, fpa_setting);
                        if(apEngaged){
                            setprop(servo~ "target-pitch", trgt_fpa);

                            setprop(servo~ "elevator-vs", 0);

                            setprop(servo~ "elevator", 1);

                            setprop(servo~ "elevator-gs", 0);
                        }
                        #setprop(servo~ "fd-elevator-vs", 0);

                        #setprop(servo~ "fd-elevator", 1);

                        #setprop(servo~ "fd-elevator-gs", 0);
                        setprop(servo~ "fd-target-pitch", trgt_fpa);
                    }

                } elsif (me.ver_mode == "ils") {

                    # Main stuff are done on the PIDs

                    autoland.phase_check();

                    var agl = getprop("/position/altitude-agl-ft");

                    # if (agl > 100) {
                    if(apEngaged){
                        if (agl > getprop("/autoland/early-descent")) {

                            setprop(servo~ "elevator-gs", 1);

                            setprop(servo~ "elevator-vs", 0);

                        } else {

                            setprop(servo~ "elevator-gs", 0);

                            setprop(servo~ "elevator-vs", 1);

                        }

                        setprop(servo~ "elevator", 0);
                    }

                    #setprop(servo~ "fd-elevator", 0);

                }

            } # End of Manual Setting Check

        } # End of AP1 Master Check

        # FMGC CONTROL MODE ====================================================

        if ((me.spd_ctrl == "fmgc") and (me.a_thr == "eng")) {

            var cur_wp = getprop("autopilot/route-manager/current-wp");
            #var ias = getprop("/velocities/airspeed-kt");

            ## AUTO-THROTTLE -------------------------------------------------------

            var agl = getprop("/position/altitude-agl-ft");

            if ((me.ver_mode == "ils") and (agl < 3000) and (getprop("/flight-management/spd-manager/approach/mode") == "MANAGED (AUTO)")) {

                setprop(fmgc~ "fmgc/ias", 1);
                setprop(fmgc~ "fmgc/mach", 0);

                setprop(fmgc~ "a-thr/ias", 0);
                setprop(fmgc~ "a-thr/mach", 0);
                var spd = getprop(fmgc_val~ "target-spd");

                if (spd != nil) {
                    if (spd > 1) {
                        setprop("instrumentation/pfd/target-spd", spd);
                    }
                }

            } else {

                if (((getprop("/flight-management/phase") == "CLB") and (getprop("/flight-management/spd-manager/climb/mode") == "MANAGED (F-PLN)")) or ((getprop("/flight-management/phase") == "CRZ") and (getprop("/flight-management/spd-manager/cruise/mode") == "MANAGED (F-PLN)")) or ((getprop("/flight-management/phase") == "DES") and (getprop("/flight-management/spd-manager/descent/mode") == "MANAGED (F-PLN)")) and (me.ver_mode != "ils") and flplan_active) {

                    var spd = nil;
                    if(getprop("/autopilot/route-manager/route/num") > 0)
                        spd = getprop("/autopilot/route-manager/route/wp[" ~ cur_wp ~ "]/ias-mach");

                    if (spd == nil or spd == 0) {

                    
                        var remaining = getprop("autopilot/route-manager/distance-remaining-nm");
                        if(remaining < decel_point){
                            spd = 180;
                        } else {
                            if (altitude <= 10000){
                                spd = 250;
                            }
                            else{
                                if(vmode_vs_fps <= -8){
                                    spd = 280;
                                } else{
                                    if(altitude < 25000)
                                        spd = 320;
                                    else
                                        spd = 0.78;
                                }
                            }
                        }

                    }
                    if(ias >= (me.vne - 20))
                        spd = me.vne - 20;

                    setprop(fmgc_val~ "target-spd", spd);

                }

                # Performance and Automatic Calculated speeds from the PERF page on the mCDU are managed separately

                manage_speeds();

                setprop(fmgc~ "a-thr/ias", 0);
                setprop(fmgc~ "a-thr/mach", 0);

                var spd = getprop(fmgc_val~ "target-spd");

                if (spd == nil) {

                    if (altitude <= 10000)
                        spd = 250;
                    elsif(altitude < 25000)
                        spd = 320;
                    else
                        spd = 0.78;

                }
                if(ias >= (me.vne - 20))
                    spd = me.vne - 30;

                if (spd < 1) {

                    setprop(fmgc~ "fmgc/ias", 0);
                    setprop(fmgc~ "fmgc/mach", 1);

                } else {

                    setprop(fmgc~ "fmgc/ias", 1);
                    setprop(fmgc~ "fmgc/mach", 0);
                    setprop("instrumentation/pfd/target-spd", spd);
                }

            }

        } else {
            var fcu_ias = getprop(fcu ~ 'ias');
            setprop("instrumentation/pfd/target-spd", fcu_ias);
        }

        if (apEngaged or fdEngaged) {

            ## LATERAL CONTROL -----------------------------------------------------

            if (me.lat_ctrl == "fmgc") {

                # If A procedure's NOT being flown, we'll fly the active F-PLN (unless it's a hold pattern)

                if (getprop("/flight-management/procedures/active") == "off") {

                    if (((getprop("/flight-management/hold/wp_id") == getprop("/flight-management/current-wp")) or (getprop("/flight-management/hold/init") == 1)) and (getprop("/flight-management/hold/wp_id") != 0)) {

                        if (getprop("/flight-management/hold/init") != 1) {

                            hold_pattern.init();

                        } else {

                            if (getprop("/flight-management/hold/phase") == 5) {

                                hold_pattern.entry();

                            } else {

                                hold_pattern.transit();

                            }	

                            # Now, fly the actual hold

                            var bug = getprop("/flight-management/hold/fly/course");

                            var bank = -1 * defl(bug, 30);

                            var deflection = defl(bug, 180);

                            if(apEngaged){
                                setprop(servo~  "aileron", 1);
                                setprop(servo~ "aileron-nav1", 0);

                                if (math.abs(deflection) <= 1)
                                    setprop(servo~ "target-bank", 0);
                                else
                                    setprop(servo~ "target-bank", bank);
                            }
                            setprop(servo~  "fd-aileron", 1);
                            setprop(servo~ "fd-aileron-nav1", 0);

                            if (math.abs(deflection) <= 1)
                                setprop(servo~ "fd-target-bank", 0);
                            else
                                setprop(servo~ "fd-target-bank", bank);							

                        }

                    } else {

                        setprop("/flight-management/hold/init", 0);

                        var bug = getprop("/autopilot/internal/true-heading-error-deg");

                        var accuracy = getprop(settings~ "gps-accur");

                        var bank = 0; 

                        if (accuracy == "HIGH")
                            bank = limit(bug, 25);
                        else
                            bank = limit(bug, 15);

                        if(apEngaged){
                            setprop(servo~  "aileron", 1);

                            setprop(servo~ "aileron-nav1", 0);

                            setprop(servo~ "target-bank", bank);
                        }
                        setprop(servo~  "fd-aileron", 1);

                        setprop(servo~ "fd-aileron-nav1", 0);

                        setprop(servo~ "fd-target-bank", bank);
                    }

                    # Else, fly the respective procedures

                } else {

                    if (getprop("/flight-management/procedures/active") == "sid") {

                        procedure.fly_sid();

                        var bug = getprop("/flight-management/procedures/sid/course");

                        var bank = -1 * defl(bug, 25);					

                        if(apEngaged){
                            setprop(servo~  "aileron", 1);

                            setprop(servo~ "aileron-nav1", 0);

                            setprop(servo~ "target-bank", bank);
                        }
                        setprop(servo~  "fd-aileron", 1);

                        setprop(servo~ "fd-aileron-nav1", 0);

                        setprop(servo~ "fd-target-bank", bank);

                    } elsif (getprop("/flight-management/procedures/active") == "star") {

                        procedure.fly_star();

                        var bug = getprop("/flight-management/procedures/star/course");

                        var bank = -1 * defl(bug, 25);	
                        if(apEngaged){

                            setprop(servo~  "aileron", 1);

                            setprop(servo~ "aileron-nav1", 0);

                            setprop(servo~ "target-bank", bank);
                        }
                        setprop(servo~  "fd-aileron", 1);

                        setprop(servo~ "fd-aileron-nav1", 0);

                        setprop(servo~ "fd-target-bank", bank);

                    } else {

                        procedure.fly_iap();

                        var bug = getprop("/flight-management/procedures/iap/course");

                        var bank = -1 * defl(bug, 28);		

                        if(apEngaged){

                            setprop(servo~  "aileron", 1);

                            setprop(servo~ "aileron-nav1", 0);

                            setprop(servo~ "target-bank", bank);
                        }
                        setprop(servo~  "fd-aileron", 1);

                        setprop(servo~ "fd-aileron-nav1", 0);

                        setprop(servo~ "fd-target-bank", bank);
                    }

                }

            }

            ## VERTICAL CONTROL ----------------------------------------------------

            if (me.ver_ctrl == "fmgc") {

                var current_wp = getprop("/autopilot/route-manager/current-wp");

                var target_alt = getprop("/autopilot/route-manager/route/wp[" ~ current_wp ~ "]/altitude-ft");

                var ref_altitude = altitude;
                var cruise_alt = getprop("autopilot/route-manager/cruise/altitude-ft");
                var destination_elevation = getprop("/autopilot/route-manager/destination/field-elevation-ft");
                var remaining = getprop("autopilot/route-manager/distance-remaining-nm");
                var phase = '';
                var no_constraint = 0;
                if(remaining <= top_desc){
                    ref_altitude = destination_elevation; 
                    phase = 'des';
                } else {
                    ref_altitude = cruise_alt;
                    phase = 'clb';
                }
                setprop(fmgc_val ~ 'vnav-phase', phase);

                if (target_alt == nil or target_alt < 0){
                    target_alt = ref_altitude;
                    no_constraint = 1;
                }
                setprop(fmgc_val ~ 'vnav-target-alt', target_alt);

                var alt_diff = target_alt - altitude;

                var final_vs = 0;
                var abs_diff = math.abs(alt_diff);

                if (abs_diff >= 100) {
                    if(no_constraint == 0 or phase == 'des'){
                        var ground_speed_kt = getprop("/velocities/groundspeed-kt");

                        #var leg_dist_nm = getprop("/instrumentation/gps/wp/leg-distance-nm");
                        var leg_dist_nm = getprop("/autopilot/route-manager/wp/dist");
                        if(no_constraint == 1)
                            leg_dist_nm = remaining;
                        
                        #var leg_time_hr = leg_dist_nm / ground_speed_kt;

                        #var leg_time_sec = leg_time_hr * 3600;

                        #var target_fps = (alt_diff / leg_time_sec) + 5;
                        var nm_min = ground_speed_kt / 60.0;
                        var min = leg_dist_nm / nm_min;
                        if(min == 0) {
                            final_vs = 0;
                        }
                        else{
                            final_vs = alt_diff / min;
                            final_vs = final_vs / 60.0;
                        }
                        final_vs = limit(final_vs, 40);
                    } else {
                        var vs_fpm = 0;
                        if(altitude < 10000)
                            vs_fpm = 1800;
                        else{
                            if(abs_diff > 1000)
                                vs_fpm = 1400;
                            else
                                vs_fpm = 500;
                        }
                        if(altitude > cruise_alt)
                            vs_fpm = vs_fpm * -1.0;
                        final_vs = limit(vs_fpm / 60.0, 40);
                    }
                } else {
                        if (((altitude - target_alt) * vs_setting) > 0) {
                            final_vs = limit((target_alt - altitude) * 2, 200);
                        } else {
                            final_vs = limit2((target_alt - altitude) * 2, vs_setting);
                        } 
                        final_vs = final_vs / 60.0;
                }
                setprop(fmgc_val ~ 'vnav-final-vs', final_vs);
                if(apEngaged){
                    setprop(servo~ "target-vs", final_vs);

                    setprop(servo~ "elevator-vs", 1);

                    setprop(servo~ "elevator", 0);

                    setprop(servo~ "elevator-gs", 0);
                }
                setprop(servo~ "fd-target-vs", final_vs);
                setprop(servo~ "fd-target-pitch", final_vs * 0.1);
            }

        } # End of AP1 MASTER CHECK

    },
        get_settings : func {

            me.spd_mode = getprop(fmgc~ "spd-mode");
            me.spd_ctrl = getprop(fmgc~ "spd-ctrl");

            me.lat_mode = getprop(fmgc~ "lat-mode");
            me.lat_ctrl = getprop(fmgc~ "lat-ctrl");

            me.ver_mode = getprop(fmgc~ "ver-mode");
            me.ver_ctrl = getprop(fmgc~ "ver-ctrl");

            me.ver_sub = getprop(fmgc~ "ver-sub");

            me.ap1 = getprop(fmgc~ "ap1-master");
            me.ap2 = getprop(fmgc~ "ap2-master");
            me.a_thr = getprop(fmgc~ "a-thrust");

        },

            lvlch_check : func {

                if ((me.ap1 == "eng") or (me.ap2 == "eng")) {

                    var vs_fps = getprop("/velocities/vertical-speed-fps");

                    if (math.abs(vs_fps) > 8)
                        setprop("/flight-management/fcu/level_ch", 1);
                    else
                        setprop("/flight-management/fcu/level_ch", 0);

                } else
                    setprop("/flight-management/fcu/level_ch", 0);

            },

                knob_sum : func {

                    var ias = getprop(fcu~ "ias");

                    var mach = getprop(fcu~ "mach");

                    setprop(fcu~ "spd-knob", ias + (100 * mach));

                    var vs = getprop(fcu~ "vs");

                    var fpa = getprop(fcu~ "fpa");

                    setprop(fcu~ "vs-knob", fpa + (vs/100));

                },
                    hdg_disp : func {

                        var hdg = getprop(fcu~ "hdg");

                        if (hdg < 10)
                            setprop(fcu~ "hdg-disp", "00" ~ hdg);
                        elsif (hdg < 100)
                        setprop(fcu~ "hdg-disp", "0" ~ hdg);
                        else
                            setprop(fcu~ "hdg-disp", "" ~ hdg);

                    },

                        fcu_lights : func {

                            if (me.lat_mode == "nav1")
                                setprop(fmgc~ "fcu/nav1", 1);
                            else
                                setprop(fmgc~ "fcu/nav1", 0);

                            if (me.ver_mode == "ils")
                                setprop(fmgc~ "fcu/ils", 1);
                            else
                                setprop(fmgc~ "fcu/ils", 0);

                            if (me.a_thr == "eng")
                                setprop(fmgc~ "fcu/a-thrust", 1);
                            else
                                setprop(fmgc~ "fcu/a-thrust", 0);

                            if (me.ap1 == "eng")
                                setprop(fmgc~ "fcu/ap1", 1);
                            else
                                setprop(fmgc~ "fcu/ap1", 0);

                            if (me.ap2 == "eng")
                                setprop(fmgc~ "fcu/ap2", 1);
                            else
                                setprop(fmgc~ "fcu/ap2", 0);

                        },

                            alt_100 : func {

                                var alt = getprop("/instrumentation/altimeter/indicated-altitude-ft");

                                return int(alt/100);

                            },

                                flight_phase : func {

                                    var phase = getprop("/flight-management/phase");
                                    var ias = getprop("/velocities/airspeed-kt");

                                    if ((phase == "T/O") and (!getprop("/gear/gear[3]/wow") and ias > 80)) {

                                        setprop("/flight-management/phase", "CLB");

                                    } elsif (phase == "CLB") {

                                        var crz_fl = getprop("/flight-management/crz_fl");

                                        if (crz_fl != 0) {

                                            if (getprop("/position/altitude-ft") >= ((crz_fl * 100) - 500))
                                                setprop("/flight-management/phase", "CRZ");

                                        } else {

                                            if (getprop("/position/altitude-ft") > 26000)
                                                setprop("/flight-management/phase", "CRZ");

                                        }

                                    } elsif (phase == "CRZ") {

                                        var crz_fl = getprop("/flight-management/crz_fl");

                                        if (crz_fl != 0) {

                                            if (getprop("/position/altitude-ft") < ((crz_fl * 100) - 500))
                                                setprop("/flight-management/phase", "DES");

                                        } else {

                                            if (getprop("/position/altitude-ft") < 26000)
                                                setprop("/flight-management/phase", "DES");

                                        }

                                    } elsif ((phase == "DES") and (getprop("/flight-management/control/ver-mode") == "ils")) {

                                        setprop("/flight-management/phase", "APP");

                                    } elsif ((phase == "APP") and (getprop("/gear/gear/wow"))) {

                                        setprop("/flight-management/phase", "T/O");

                                        new_flight();

                                        me.current_wp = 0;

                                    }

                                },
                                    calc_td: func {
                                        var tdNode = "/instrumentation/nd/symbols/td";
                                        var top_of_descent = 36;

                                        if (getprop("/autopilot/route-manager/active")){
                                            var cruise_alt = getprop("autopilot/route-manager/cruise/altitude-ft");
                                            var destination_elevation = getprop("/autopilot/route-manager/destination/field-elevation-ft");
                                            if(cruise_alt > 10000) {
                                                top_of_descent += 21;
                                                if(cruise_alt > 29000)
                                                {
                                                    top_of_descent += 41.8;
                                                    if(cruise_alt > 36000)
                                                    {
                                                        top_of_descent += 28;
                                                        top_of_descent += (cruise_alt - 36000) / 1000 * 3.8;
                                                    }
                                                    else
                                                    {
                                                        top_of_descent += (cruise_alt - 29000) / 1000 * 4;
                                                    }
                                                }
                                                else
                                                {
                                                    top_of_descent += (cruise_alt - 10000) / 1000 * 2.2;
                                                }
                                                top_of_descent += 6.7;
                                            } else {
                                                top_of_descent += (cruise_alt - 3000) / 1000 * 3;
                                            }
                                            top_of_descent -= (destination_elevation / 1000 * 3);
                                            #print("TD: " ~ top_of_descent);
                                            var f= flightplan(); 
                                            #                   var topClimb = f.pathGeod(0, 100);
                                            var topDescent = f.pathGeod(-1, -top_of_descent);
                                            setprop(tdNode ~ "/latitude-deg", topDescent.lat); 
                                            setprop(tdNode ~ "/longitude-deg", topDescent.lon); 
                                        } else {
                                            setprop(tdNode, ''); 
                                        }
                                        return top_of_descent;
                                    },
                                    calc_tc: func {
                                        var tcNode = "/instrumentation/nd/symbols/tc";
                                        if (getprop("/autopilot/route-manager/active") and !getprop("/gear/gear[3]/wow")){
                                            var vs_fpm = int(0.6 * getprop("velocities/vertical-speed-fps")) * 100;
                                            var cruise_alt = getprop("autopilot/route-manager/cruise/altitude-ft");
                                            var altitude = getprop("/instrumentation/altimeter/indicated-altitude-ft");
                                            var d = cruise_alt - altitude;
                                            if(d > 100){
                                                var min = d / vs_fpm;
                                                var ground_speed_kt = getprop("/velocities/groundspeed-kt");
                                                var nm_min = ground_speed_kt / 60;
                                                var nm = nm_min * min;
                                                var remaining = getprop("autopilot/route-manager/distance-remaining-nm");
                                                var totdist = getprop("autopilot/route-manager/total-distance");
                                                nm = nm + (totdist - remaining);
                                                var f= flightplan(); 
                                                #print("TC: " ~ nm);
                                                var topClimb = f.pathGeod(0, nm);
                                                setprop(tcNode ~ "/latitude-deg", topClimb.lat); 
                                                setprop(tcNode ~ "/longitude-deg", topClimb.lon); 
                                            } else {
                                               setprop(tcNode, ''); 
                                            }
                                        } else {
                                            setprop(tcNode, '');
                                        }

                                    },
                                    calc_decel_point: func{
                                        var decelNode = "/instrumentation/nd/symbols/decel";
                                        if (getprop("/autopilot/route-manager/active")){
                                            var actrte = "/autopilot/route-manager/route/";
                                            var f= flightplan(); 
                                            var numwp = getprop(actrte~"num");
                                            var i = 0;
                                            var first_approach_wp = nil;
                                            for(i = 0; i < numwp; i = i + 1){
                                                var wp = f.getWP(i);
                                                if(wp != nil){
                                                    var role = wp.wp_role;
                                                    if(role == 'approach'){
                                                        first_approach_wp = wp;
                                                        break;
                                                    }
                                                }
                                            }
                                            if(first_approach_wp != nil){
                                                var dist = wp.distance_along_route;
                                                var totdist = getprop("autopilot/route-manager/total-distance");
                                                dist = totdist - dist;
                                                var nm = dist + 11;
                                                var decelPoint = f.pathGeod(-1, -nm);
                                                setprop(decelNode ~ "/latitude-deg", decelPoint.lat); 
                                                setprop(decelNode ~ "/longitude-deg", decelPoint.lon); 
                                                return nm;
                                            } else {
                                                setprop(decelNode, '');
                                            }
                                        } else {
                                            setprop(decelNode, '');
                                        }
                                        return 0;
                                    },
                                        reset : func {
                                            me.loopid += 1;
                                            me._loop_(me.loopid);
                                        },
                                            _loop_ : func(id) {
                                                id == me.loopid or return;
                                                me.update();
                                                settimer(func { me._loop_(id); }, me.UPDATE_INTERVAL);
}

};

setlistener("sim/signals/fdm-initialized", func
            {
            fmgc_loop.init();
print("Flight Management and Guidance Computer Initialized");
});

setlistener('controls/engines/engine/reverser', func{
    var rev = getprop('controls/engines/engine/reverser');
    var rev_detent = getprop('controls/engines/detents/rev');
    var throttle = getprop('controls/engines/engine[1]/throttle');
    if(rev){
        setprop('controls/engines/detents/throttle', rev_detent - throttle);
        setprop('controls/engines/detents/current', 'rev');
    } else {
        var detent_thr = getprop('controls/engines/detents/throttle');
        setprop('controls/engines/detents/throttle', 0);
        settimer(func{setprop('controls/engines/detents/current', 'none')},0.25);
    }

});

setlistener('/flight-management/control/a-thrust', func{
    var athr = getprop('/flight-management/control/a-thrust');
    var clb_detent = getprop('controls/engines/detents/clb');
    var throttle = getprop('controls/engines/engine[1]/throttle');
    if(athr == 'eng'){
        setprop('controls/engines/detents/throttle', clb_detent - throttle);
        setprop('controls/engines/detents/current', 'clb');
    } else {
        var detent_thr = getprop('controls/engines/detents/throttle');
        setprop('controls/engines/detents/throttle', 0);
        settimer(func{setprop('controls/engines/detents/current', 'none')},0.25);
    }

});
