# $Id$
# Melchior FRANZ, < mfranz # aon : at >



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
doors = props.globals.getNode("controls/doors").getChildren("door");

nextDoor = func {
	if (door < size(doors)) {
		door = door + 1;
	} else {
		door = 0;
	}
	gui.popupTip("Selecting " ~ doors[door].getNode("name").getValue());
}

swingTime = 2.5;

toggleDoor = func {
	position = doors[door].getNode("position");
	target = doors[door].getNode("target");
	time = abs(position.getValue() - target.getValue()) * swingTime;
	interpolate(position, target.getValue(), time);
	target.setValue(!target.getValue());
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
crashed = nil;

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


matlist = { # MATERIALS
#       fuselage   diffuse            ambient            specular           emission           shi trans
	"mil":    [0.35, 0.36, 0.31,  0.35, 0.36, 0.31,  0.0, 0.0, 0.0,     0.02, 0.02, 0.02,  0,  0],
	"blue":   [0.0, 0.45, 0.6,    0.0, 0.45, 0.6,    0.8, 0.8, 1.0,     0.0, 0.0, 0.0,     10, 0],
	"yellow": [0.83, 0.62, 0.0,   0.78, 0.71, 0.0,   0.0, 0.0, 0.0,     0.05, 0.05, 0.05,  0, 0],
	"black":  [0.3, 0.3, 0.23,    0.18, 0.18, 0.19,  0.32, 0.32, 0.32,  0.0, 0.0, 0.0,     15, 0],
#       windows
	"glass":  [0.2, 0.2, 0.2,     0.2, 0.2, 0.2,     1.0, 1.0, 1.0,     0.0, 0.0, 0.0,     25, 0.8],
	"taint":  [0.0, 0.0, 0.0,     0.0, 0.0, 0.0,     0.5, 0.5, 0.5,     0.0, 0.0, 0.0,     25, 0.5],
};


varlist = [ # VARIANTS
#        paint     glass    emblem                     MG HOT
	["yellow", "glass", "$med",                     0, 0],
	["mil",    "glass", "$med",                     0, 0],
	["mil",    "glass", "empty.rgb",                1, 0],	# GE-M134
	["mil",    "glass", "$mil",                     0, 1],	# HOT
	["blue",   "glass", "emblems/star-of-life.rgb", 0, 0],
	#["black",  "taint", "empty.rgb",               1, 1],
# LEGEND:
#  $med ... medevac emblem (/sim/model/bo105/emblem; defaults to national RC society, depending on airport)
#  $mil ... military insignia (/sim/model/bo105/insignia; defaults to Austrian)
];


apply_mat = func {
	obj = arg[0];
	mat = arg[1];
	i = 0;
	base = "/sim/model/bo105/material/" ~ obj ~ "/";
	foreach (t; ["diffuse", "ambient", "specular", "emission"]) {
		foreach (c; ["red", "green", "blue"]) {
			setprop(base ~ t ~ "/" ~ c, mat[i]);
			i = i + 1;
		}
	}
	setprop(base ~ "shininess", mat[i]);
	setprop(base ~ "transparency", mat[i + 1]);
}


variant = -1;

select_variant = func {
	variant = if (size(arg) and arg[0] != nil) { arg[0] } else { variant + 1 };
	if (variant >= size(varlist)) {
		variant = 0;
	}
	e = varlist[variant][2];
	if (e == "$med") {
		e = getprop("sim/model/bo105/emblem");
	} elsif (e == "$mil") {
		e = getprop("sim/model/bo105/insignia");
	}
	if (!size(e)) {
		e = "empty.rgb";
	}
	apply_mat("fuselage", matlist[varlist[variant][0]]);
	apply_mat("glass", matlist[varlist[variant][1]]);
	setprop("sim/model/bo105/material/emblem/texture", e);
	setprop("sim/model/bo105/MG/enabled", varlist[variant][3]);
	setprop("sim/model/bo105/HOT/enabled", varlist[variant][4]);

	MG[0].getNode("trigger", 1).setValue(0);
	MG[1].getNode("trigger", 1).setValue(0);
	reload();
}


showDialog = func {
	dialog = gui.Widget.new();
	name = "bo105-config";
	dialog.set("layout", "vbox");
	dialog.set("name", name);

# "window" titlebar
	titlebar = dialog.addChild("group");
	titlebar.set("layout", "hbox");
	titlebar.addChild("text").set("label", "___________Bo105 configuration___________");
	titlebar.addChild("empty").set("stretch", 1);

	w = titlebar.addChild("button");
	w.set("pref-width", 16);
	w.set("pref-height", 16);
	w.set("legend", "");
	w.set("default", 1);
	w.prop().getNode("binding[1]/command", 1).setValue("dialog-close");

	checkbox = func {
		group = dialog.addChild("group");
		group.set("layout", "hbox");
		group.addChild("empty").set("pref-width", 4);
		box = group.addChild("checkbox");
		group.addChild("empty").set("stretch", 1);

		box.set("halign", "left");
		box.set("label", arg[0]);
		box;
	}

# doors
	foreach (d; doors) {
		w = checkbox(d.getNode("name").getValue());
		w.set("property", d.getNode("enabled").getPath());
		w.prop().getNode("binding[0]/command", 1).setValue("dialog-apply");
	}

# lights
	w = checkbox("beacon");
	w.set("property", "controls/lighting/beacon");
	w.prop().getNode("binding[0]/command", 1).setValue("dialog-apply");

	w = checkbox("strobe");
	w.set("property", "controls/lighting/strobe");
	w.prop().getNode("binding[0]/command", 1).setValue("dialog-apply");

# ammunition
	group = dialog.addChild("group");
	group.set("layout", "hbox");
	group.addChild("empty").set("pref-width", 4);

	w = group.addChild("button");
	w.set("halign", "left");
	w.set("legend", "Reload");
	w.prop().getNode("binding[0]/command", 1).setValue("nasal");
	w.prop().getNode("binding[0]/script", 1).setValue("bo105.reload()");

	w = group.addChild("text");
	w.set("halign", "left");
	w.set("label", "");
	w.set("format", "%6.f Rounds");
	w.set("property", "sim/model/bo105/MG[0]/total");
	w.set("live", 1);
	group.addChild("empty").set("stretch", 1);
	
# finale
	dialog.addChild("empty").set("pref-height", "3");
	fgcommand("dialog-new", dialog.prop());
	gui.showDialog(name);
}



# toys'R'us
trigger = props.globals.getNode("controls/gear/brake-left");
SUB = [];	# submodels
MG = [];
HOT = [];
HOTselect = 0;
trigger_lock = 0;


init_submodels = func {
	for (i = 0; i < 2; i = i + 1) {
		p = props.globals.getNode("sim/model/bo105/MG[" ~ i ~ "]", 1);
		p.getNode("trigger", 1).setBoolValue(0);
		append(MG, p);
	}
	MG[0].getNode("enabled", 1).setBoolValue(0);
	MG[0].getNode("total", 1).setIntValue(0);

	for (i = 0; i < 6; i = i + 1) {
		p = props.globals.getNode("sim/model/bo105/HOT[" ~ i ~ "]", 1);
		p.getNode("trigger", 1).setBoolValue(0);
		append(HOT, p);
	}
	HOT[0].getNode("enabled", 1).setBoolValue(0);
	HOT[0].getNode("total", 1).setIntValue(0);

	SUB = props.globals.getNode("ai/submodels").getChildren("submodel");
}


recalc_ammo_loop = func {
	n = 10 * SUB[0].getNode("count", 1).getValue();
	n = n + 10 * SUB[1].getNode("count", 1).getValue();
	MG[0].getNode("total").setIntValue(n);

	n = 0;
	for (i = 2; i < 2 + size(HOT); i = i + 1) {
		n = n + SUB[i].getNode("count", 1).getValue()
	}
	HOT[0].getNode("total").setIntValue(n);
	settimer(recalc_ammo_loop, 0.5);
}


submodel_loop = func {
	trig = trigger.getValue();
	if (varlist[variant][3]) {		# MG
		MG[0].getNode("trigger").setBoolValue(trig);
		MG[1].getNode("trigger").setBoolValue(trig);
		settimer(submodel_loop, 0.2);

	} elsif (varlist[variant][4]) {		# HOT
		if (trig) {
			if (!trigger_lock and (HOTselect < size(HOT))) {
				trigger_lock = 1;
				HOT[HOTselect].getNode("trigger").setBoolValue(1);
				HOTselect = HOTselect + 1;
			}
		} else {
			trigger_lock = 0;
		}
		settimer(submodel_loop, 0.2);

	} else {
		settimer(submodel_loop, 1);
	}
}


reload = func {
	# number of *tracers*, not rounds! (1:9)
	setprop("ai/submodels/submodel[0]/count", 400);
	setprop("ai/submodels/submodel[1]/count", 400);

	HOTselect = 0;
	for (i = 0; i < size(HOT); i = i + 1) {
		setprop("ai/submodels/submodel[" ~ (i + 2) ~ "]/count", 1);
		HOT[i].getNode("trigger").setBoolValue(0);
	}
}




INIT = func {
	crashed = props.globals.getNode("sim/crashed", 1);
	settimer(crashhandler, 20);

	# the attitude indicator needs pressure
	settimer(func { setprop("engines/engine/rpm", 3000) }, 8);

	foreach (d; doors) {
		position = d.getNode("position").getValue();
		target = if (position > 0.5) { 0.0 } else { 1.0 };
		d.getNode("target", 1).setDoubleValue(target);
	}
	n = props.globals.getNode("sim/model/bo105/emblem");
	e = n.getValue();
	if (e != nil and !size(e)) {
		n.setValue(determine_emblem());
	}

	init_submodels();
	select_variant(getprop("sim/model/bo105/variant"));
	recalc_ammo_loop();
	submodel_loop();
}

settimer(INIT, 0);


