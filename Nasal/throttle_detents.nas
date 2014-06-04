var set_detent = func(detent_name){
    if(detent_name == 'rev'){
        if(getprop('/flight-management/control/a-thrust') != 'off')
            setprop('/flight-management/control/a-thrust', 'off');
        setprop('controls/engines/engine[0]/throttle', 0);
        setprop('controls/engines/engine[1]/throttle', 0);
        if(!getprop('controls/engines/engine/reverser'))
            reversethrust.togglereverser();
        setprop('controls/engines/engine[0]/throttle', 0.6);
        setprop('controls/engines/engine[1]/throttle', 0.6);
    } 
    elsif(detent_name == 'idle'){
        if(getprop('/flight-management/control/a-thrust') != 'off'){
            setprop('/flight-management/control/a-thrust', 'off');
            settimer(func{
                setprop('controls/engines/engine[0]/throttle', 0);
                setprop('controls/engines/engine[1]/throttle', 0);
            }, 0.05);
        }
        setprop('controls/engines/engine[0]/throttle', 0);
        setprop('controls/engines/engine[1]/throttle', 0);
        if(getprop('controls/engines/engine/reverser'))
            reversethrust.togglereverser();
    }
    elsif(detent_name == 'clb'){
        if(getprop('controls/engines/engine/reverser')){
            setprop('controls/engines/engine[0]/throttle', 0);
            setprop('controls/engines/engine[1]/throttle', 0);
            reversethrust.togglereverser();
        }
        if(getprop('/flight-management/control/a-thrust') == 'off')
            setprop('/flight-management/control/a-thrust', 'eng');
    }
    elsif(detent_name == 'toga'){
        if(getprop('controls/engines/engine/reverser')){
            setprop('controls/engines/engine[0]/throttle', 0);
            setprop('controls/engines/engine[1]/throttle', 0);
            reversethrust.togglereverser();
        }
        if(getprop('/flight-management/control/a-thrust') != 'off')
            setprop('/flight-management/control/a-thrust', 'off');
        setprop('controls/engines/engine[0]/throttle', 1);
        setprop('controls/engines/engine[1]/throttle', 1);
    }
}
