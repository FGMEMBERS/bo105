# $Id$
# Melchior FRANZ, < mfranz # aon : at >

# the attitude indicator needs pressure
settimer(func { setprop("engines/engine/rpm", 3000) }, 8);
settimer(func { setprop("sim/freeze/position", 1) }, 8);



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

door = 0;
doors = [
	["pilot's door", "controls/doors/front-right", 1],
	["copilot's door", "controls/doors/front-left", 1],
	["right backdoor", "controls/doors/back-right", 1],
	["left backdoor", "controls/doors/back-left", 1],
	["right rear door", "controls/doors/rear-right", 1],
	["left rear door", "controls/doors/rear-left", 1]
];

nextDoor = func {
	if (door < 5) {
		door = door + 1;
	} else {
		door = 0;
	}
	gui.popupTip("Selecting " ~ doors[door][0]);
}

swingTime = 2.5;

toggleDoor = func {
	doornode = props.globals.getNode(doors[door][1], 1);
	target = doors[door][2];
	val = doornode.getValue();
	if (val >= 0) {
		time = abs(val - target) * swingTime;
		interpolate(doornode, target, time);
		doors[door][2] = !doors[door][2];
	}
}

removeDoor = func {
	doornode = props.globals.getNode(doors[door][1], 1);
	val = doornode.getValue();
	if (val > 0.99) {
		doornode.setValue(-1);
	} elsif (val < 0.0) {
		doornode.setValue(1);
		doors[door][2] = 0;
	}
}



# engines/rotor =====================================================
rotor = props.globals.getNode("controls/engines/engine/magnetos");
state = props.globals.getNode("sim/model/bo105/state");
turbine = props.globals.getNode("sim/model/bo105/turbine-rpm-pct", 1);

# 0 off
# 1 startup sound in progress
# 2 sound loop
# 3 shutdown sound in progress

engines = func {
	s = state.getValue();
	if (arg[0] == 1) {
		if (s == 0) {
			state.setValue(1);				# engines started
			settimer(func { rotor.setValue(1) }, 3);
			interpolate(turbine, 100, 10.5);
			settimer(func { state.setValue(2) }, 10.5);	# -> engines running
		}
	} else {
		if (s == 2) {
			rotor.setValue(0);				# engines stopped
			state.setValue(3);
			interpolate(turbine, 0, 18);
			settimer(func { state.setValue(0) }, 30);	# -> engines off
		}
	}
}



# crash handler =====================================================
crashed = props.globals.getNode("sim/crashed");

crashhandler = func {
	if (crashed.getValue()) {
		setprop("sim/model/bo105/tail-angle", 35);
		setprop("sim/model/bo105/shadow", 0);
		setprop("controls/doors/front-right", 0.2);
		setprop("controls/doors/front-left", 0.9);
		setprop("controls/doors/back-right", 0.2);
		setprop("controls/doors/back-left", 0.6);
		setprop("controls/doors/rear-right", 0.1);
		setprop("controls/doors/rear-left", 0.05);
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



# "manual" rotor animation for flight data recorder replay ============
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


determine_emblem = func {
	# Use the appropriate internationally acknowleged protective Red Cross/Crescent
	# symbol, depending on the starting airport. (http://www.ifrc.org/ADDRESS/directory.asp)
	# As soon as the decision for a third protective emblem has been made, I'll add that.
	# For now there's only the Star-of-Live for these cases.
	# This information is from official sources. I'm open for corrections, but don't
	# bother me with politics, or I'll punish your country with a "Red Pretzel" emblem!)

	C = 1;	# Red Cross
	L = 2;	# Rec Crescent (opening left)
	R = 3;	# Red Crescent (opening right)
	X = 4;	# StarOfLife  # Red Chevron/Crystal/Diamond (decision pending)

	emblem = [
		["<none>", "empty.rgb"],
		["Red Cross", "emblems/red-cross.rgb"],
		["Red Crescent", "emblems/red-crescent-l.rgb"],
		["Red Crescent", "emblems/red-crescent-r.rgb"],
		["Star of Life", "emblems/star-of-life.rgb"],
	];

	icao = {
		"":    ["<default>", C],
		"DA":  ["Algeria", R],
		"DT":  ["Tunisia", L],
		"GM":  ["Morocco", R],
		"GQ":  ["Mauritania", R],
		"HC":  ["Somalia", R],
		"HD":  ["Djibouti", R],
		"HE":  ["Egypt", R],
		"HL":  ["Libyan Arab Jamahiriya", R],
		"HS":  ["Sudan", R],
		"LL":  ["Israel", X],		# observer; admission pending (no symbol yet; probably X)
		"LO":  ["Austria", C],
		"LT":  ["Turkey", L],
		"LV":  ["Palestine", 2],	# observer; admission pending (L or R?)
		"OA":  ["Afghanistan", R],
		"OB":  ["Bahrain", R],
		"OE":  ["Saudi Arabia", R],
		"OI":  ["Islamic Republic of Iran", R],
		"OJ":  ["Jordan", R],
		"OK":  ["Kuwait", R],
		"OM":  ["United Arab Emirates", R],
		"OP":  ["Pakistan", L],
		"OR":  ["Iraq", R],
		"OS":  ["Syrian Arab Republic", R],
		"OT":  ["Qatar", R],
		"OY":  ["Yemen", R],
		"UA":  ["Kazakhstan", R],
		"UAF": ["Kyrgyzstan", L],
		"UB":  ["Azerbaidjan", L],
		"UT":  ["Uzbekistan", L],
		"UTA": ["Turkmenistan", L],
		"UTD": ["Tajikistan", R],
		"VG":  ["Bangladesh", R],
		"WB":  ["Malaysia", R],
		"WBAK":["Brunei Darussalam", R],
		"WBSB":["Brunei Darussalam", R],
		"WM":  ["Malaysia", R],
	};

	apt = getprop("/sim/presets/airport-id");
	found = "";

	foreach (key; keys(icao)) {
		if (substr(apt, 0, size(key)) == key) {
			if (size(key) > size(found)) {
				found = key;
			}
		}
	}
	soc = icao[found];
	print(apt ~ "/" ~ soc[0] ~ " >> " ~ emblem[soc[1]][0]);
	return emblem[soc[1]][1];
}


#	           diffuse            ambient            specular        emission           shi trans
matlist = {
	"mil":    [0.35, 0.36, 0.31,  0.35, 0.36, 0.31,  0.0, 0.0, 0.0,  0.02, 0.02, 0.02,  0,  0],
	"blue":   [0.0, 0.45, 0.6,    0.0, 0.45, 0.6,    0.8, 0.8, 1.0,  0.0, 0.0, 0.0,     10, 0],
	"yellow": [0.83, 0.62, 0.0,   0.78, 0.71, 0.0,   0.0, 0.0, 0.0,  0.05, 0.05, 0.05,  0, 0],
};

varlist = [
	["yellow", nil, 0],				# medevac
	["mil", nil, 0],				# mil medevac
	["mil", "empty.rgb", 0],			# generic mil
	["mil", "emblems/oebh.rgb", 1],			# Austrian antitank (HOT mounting)
	["blue", "emblems/star-of-life.rgb", 0],	# blue medevac (star of life)
];


apply_mat = func {
	obj = arg[0];
	mat = arg[1];
	i = 0;
	base = "/sim/model/bo105/material/" ~ obj ~ "/";
	foreach (t; ["diffuse", "ambient", "specular", "emission"]) {
		foreach (c; ["-red", "-green", "-blue"]) {
			setprop(base ~ t ~ c, mat[i]);
			i = i + 1;
		}
	}
	setprop(base ~ "shininess", mat[i]);
	setprop(base ~ "transparency", mat[i + 1]);
}


localsoc = nil;
variant = nil;

select_variant = func {
	if (size(arg)) {
		variant = arg[0];
	} else {
		variant = variant + 1;
		if (variant == size(varlist)) {
			variant = 0;
		}
	}
	apply_mat("fuselage", matlist[varlist[variant][0]]);
	e = varlist[variant][1];
	if (e == nil) {
		e = localsoc;
	}
	setprop("sim/model/bo105/material/emblem/texture", e);
	setprop("sim/model/bo105/hot", varlist[variant][2]);
}


INIT = func {
	localsoc = determine_emblem();
	n = props.globals.getNode("sim/model/bo105/variant");
	select_variant(if (n == nil) { 0 } else { n.getValue() });
}

settimer(INIT, 0);


