# $Id$

# the attitude indicator needs pressure
settimer(func { setprop("/engines/engine/rpm", 3000) }, 8);



# strobes ===========================================================
strobe_switch = props.globals.getNode("/controls/lighting/strobe");
strobe_top = props.globals.getNode("/sim/model/bo105/strobe-top");
strobe_bottom = props.globals.getNode("/sim/model/bo105/strobe-bottom");

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
beacon_switch = props.globals.getNode("/controls/lighting/beacon");
beacon_top = props.globals.getNode("/sim/model/bo105/beacon-top");
beacon_bottom = props.globals.getNode("/sim/model/bo105/beacon-bottom");

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
nav_light_switch = props.globals.getNode("/controls/lighting/nav-lights");
visibility = props.globals.getNode("/environment/visibility-m");
sun_angle = props.globals.getNode("/sim/time/sun-angle-rad");
nav_lights = props.globals.getNode("/sim/model/bo105/nav-lights");

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
door = props.globals.getNode("/controls/doors/rear", 1);
swingTime = 2.5;

target = 1;
toggleDoor = func {
	val = door.getValue();
	time = abs(val - target) * swingTime;
	interpolate(door, target, time);
	target = !target;
}



