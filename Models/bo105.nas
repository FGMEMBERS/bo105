# $Id$

# the attitude indicator needs pressure
settimer(func { setprop("engines/engine/rpm", 3000) }, 8);



# strobes ===========================================================
strobe_switch = props.globals.getNode("controls/lighting/strobe");
strobe_top = props.globals.getNode("sim/model/bo105/strobe-top");
strobe_bottom = props.globals.getNode("sim/model/bo105/strobe-bottom");

do_strobe_top = func {
	if (!strobe_switch.getValue()) {
		strobe_top.setValue(0);
		return settimer(do_strobe_top, 2);
	}
	if (val = !strobe_top.getValue()) {
		settimer(do_strobe_top, 0.05);
	} else {
		settimer(do_strobe_top, 1.00);
	}
	strobe_top.setValue(val);
}

do_strobe_bottom = func {
	if (!strobe_switch.getValue()) {
		strobe_top.setValue(0);
		return settimer(do_strobe_bottom, 2);
	}
	if (val = !strobe_bottom.getValue()) {
		settimer(do_strobe_bottom, 0.05);
	} else {
		settimer(do_strobe_bottom, 1.03);
	}
	strobe_bottom.setValue(val);
}

settimer(do_strobe_top, 6);
settimer(do_strobe_bottom, 7);


# beacons ===========================================================
beacon_switch = props.globals.getNode("controls/lighting/beacon");
beacon_top = props.globals.getNode("sim/model/bo105/beacon-top");
beacon_bottom = props.globals.getNode("sim/model/bo105/beacon-bottom");

do_beacon_top = func {
	if (beacon_switch.getValue()) {
		beacon_top.setValue(!beacon_top.getValue());
	} else {
		beacon_top.setValue(0);
	}

	settimer(do_beacon_top, 0.62);
}

do_beacon_bottom = func {
	if (beacon_switch.getValue()) {
		beacon_bottom.setValue(!beacon_bottom.getValue());
	} else {
		beacon_bottom.setValue(0);
	}

	settimer(do_beacon_bottom, 0.63);
}

settimer(do_beacon_top, 8);
settimer(do_beacon_bottom, 9);


# nav lights ========================================================
nav_light_switch = props.globals.getNode("controls/lighting/nav-lights");
visibility = props.globals.getNode("environment/visibility-m");
sun_angle = props.globals.getNode("sim/time/sun-angle-rad");
nav_lights = props.globals.getNode("sim/model/bo105/nav-lights");

do_nav_lights = func {
	if (nav_light_switch.getValue()) {
		nav_lights.setValue(visibility.getValue() < 5000 or sun_angle.getValue() > 1.4);
	} else {
		nav_lights.setValue(0);
	}
	settimer(do_nav_lights, 3);
}

settimer(do_nav_lights, 10);



# doors =============================================================
door = props.globals.getNode("controls/doors/rear", 1);
swingTime = 2.5;

target = 1;
toggleDoor = func {
	val = door.getValue();
	time = abs(val - target) * swingTime;
	interpolate(door, target, time);
	target = !target;
}



# engines/rotor =====================================================
rotor = props.globals.getNode("controls/engines/engine/magnetos");
state = props.globals.getNode("sim/model/bo105/state");
turbine = props.globals.getNode("sim/model/bo105/turbine-rpm-pct", 1);

# 0 off
# 1 startup sound in progress
# 2 sound loop
# 3 shutdown sound in progress

print("engines off");
engines = func {
	s = state.getValue();
	if (arg[0] == 1) {
		if (s == 0) {
			state.setValue(1);
			print("engines started");
			settimer(func { rotor.setValue(1) }, 3);
			interpolate(turbine, 100, 10.5);
			settimer(func { state.setValue(2) ; print("engines running") }, 10.5);
		}
	} else {
		if (s == 2) {
			print("engines stopped");
			rotor.setValue(0);
			state.setValue(3);
			interpolate(turbine, 0, 18);
			settimer(func { state.setValue(0) ; print("engines off") }, 18);
		}
	}
}



# crash handler =====================================================
crashed = props.globals.getNode("sim/crashed");

crashhandler = func {
	if (crashed.getValue()) {
		setprop("sim/model/bo105/tail-angle", 35);
		setprop("sim/model/bo105/shadow-blend", 1);
		setprop("controls/doors/front_left", 0.3);
		setprop("controls/doors/front_right", 0.6);
		setprop("controls/doors/back_left", 0.2);
		setprop("controls/doors/back_left", 0.4);
		setprop("controls/doors/rear", 0.3);
		setprop("rotors/main/rpm", 0);
		setprop("rotors/main/blade1_flap", -60);
		setprop("rotors/main/blade2_flap", -50);
		setprop("rotors/main/blade3_flap", -40);
		setprop("rotors/main/blade4_flap", -30);
		setprop("rotors/main/blade1_incidence", -30);
		setprop("rotors/main/blade2_incidence", -20);
		setprop("rotors/main/blade3_incidence", -50);
		setprop("rotors/main/blade4_incidence", -55);
		setprop("rotors/tail/rpm", 0);
		strobe_switch.setValue(0);
		beacon_switch.setValue(0);
		nav_light_switch.setValue(0);
		rotor.setValue(0);
		turbine.setValue(0);
		state.setValue(0);
	}
	settimer(crashhandler, 0.2);
}

settimer(crashhandler, 20);



# manual rotor animation for flight data recorder replay ============
rotor_step = props.globals.getNode("sim/model/bo105/rotor-step-deg");
blade1_pos = props.globals.getNode("rotors/main/blade1_pos", 1);
blade2_pos = props.globals.getNode("rotors/main/blade2_pos", 1);
blade3_pos = props.globals.getNode("rotors/main/blade3_pos", 1);
blade4_pos = props.globals.getNode("rotors/main/blade4_pos", 1);
rotorangle = 0;

rotoranim = func {
	i = rotor_step.getValue();
	if (i != 0.0) {
		blade1_pos.setValue(rotorangle);
		blade2_pos.setValue(rotorangle + 90);
		blade3_pos.setValue(rotorangle + 180);
		blade4_pos.setValue(rotorangle + 270);
		rotorangle = rotorangle + i;
		settimer(rotoranim, 0.1);
	} else {
		settimer(rotoranim, 5);
	}
}

settimer(rotoranim, 5);


