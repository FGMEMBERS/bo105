# $Id$
# Melchior FRANZ, < mfranz # aon : at >

if (!contains(globals, "cprint")) {
	globals.cprint = func {};
}

optarg = aircraft.optarg;
makeNode = aircraft.makeNode;

sin = func(a) { math.sin(a * math.pi / 180.0) }
cos = func(a) { math.cos(a * math.pi / 180.0) }
pow = func(v, w) { math.exp(math.ln(v) * w) }
npow = func(v, w) { math.exp(math.ln(abs(v)) * w) * (v < 0 ? -1 : 1) }
clamp = func(v, min, max) { v < min ? min : v > max ? max : v }
normatan = func(x) { math.atan2(x, 1) * 2 / math.pi }


sort = func(l) {
	while (1) {
		var n = 0;
		for (var i = 0; i < size(l) - 1; i += 1) {
			if (cmp(l[i], l[i + 1]) > 0) {
				var t = l[i + 1];
				l[i + 1] = l[i];
				l[i] = t;
				n += 1;
			}
		}
		if (!n) {
			return l;
		}
	}
}


# strobes ===========================================================
var strobe_switch = props.globals.getNode("controls/lighting/strobe", 1);
aircraft.light.new("sim/model/bo105/lighting/strobe-top", 0.05, 1.00, strobe_switch);
aircraft.light.new("sim/model/bo105/lighting/strobe-bottom", 0.05, 1.03, strobe_switch);

# beacons ===========================================================
var beacon_switch = props.globals.getNode("controls/lighting/beacon", 1);
aircraft.light.new("sim/model/bo105/lighting/beacon-top", 0.62, 0.62, beacon_switch);
aircraft.light.new("sim/model/bo105/lighting/beacon-bottom", 0.63, 0.63, beacon_switch);



# nav lights ========================================================
var nav_light_switch = props.globals.getNode("controls/lighting/nav-lights", 1);
var visibility = props.globals.getNode("environment/visibility-m", 1);
var sun_angle = props.globals.getNode("sim/time/sun-angle-rad", 1);
var nav_lights = props.globals.getNode("sim/model/bo105/lighting/nav-lights", 1);

nav_light_loop = func {
	if (nav_light_switch.getValue()) {
		nav_lights.setValue(visibility.getValue() < 5000 or sun_angle.getValue() > 1.4);
	} else {
		nav_lights.setValue(0);
	}
	settimer(nav_light_loop, 3);
}

settimer(nav_light_loop, 0);



# doors =============================================================
Doors = {
	new : func {
		var m = { parents : [Doors] };
		m.active = 0;
		m.list = [];
		foreach (var d; props.globals.getNode("sim/model/bo105/doors").getChildren("door")) {
			append(m.list, aircraft.door.new(d, 2.5));
		}
		return m;
	},
	next : func {
		me.select(me.active + 1);
	},
	previous : func {
		me.select(me.active - 1);
	},
	select : func(which) {
		me.active = which;
		if (me.active < 0) {
			me.active = size(me.list) - 1;
		} elsif (me.active >= size(me.list)) {
			me.active = 0;
		}
		gui.popupTip("Selecting " ~ me.list[me.active].node.getNode("name").getValue());
	},
	toggle : func {
		me.list[me.active].toggle();
	},
	reset : func {
		foreach (var d; me.list) {
			d.setpos(0);
		}
	},
};




# engines/rotor =====================================================
var state = props.globals.getNode("sim/model/bo105/state");
var rotor = props.globals.getNode("controls/engines/engine/magnetos");
var rotor_rpm = props.globals.getNode("rotors/main/rpm");
var torque = props.globals.getNode("rotors/gear/total-torque", 1);
var collective = props.globals.getNode("controls/engines/engine/throttle");
var turbine = props.globals.getNode("sim/model/bo105/turbine-rpm-pct", 1);
var torque_pct = props.globals.getNode("sim/model/bo105/torque-pct", 1);
var stall = props.globals.getNode("rotors/main/stall", 1);
var stall_filtered = props.globals.getNode("rotors/main/stall-filtered", 1);
var dt = props.globals.getNode("/sim/time/delta-realtime-sec", 1);
var throttle = props.globals.getNode("/controls/engines/engine/throttle", 1);


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
			interpolate(turbine, 100, 25);
			settimer(func { state.setValue(2) }, 10.5);	# -> engines running
		}
	} else {
		if (s == 2) {
			rotor.setValue(0);				# engines stopped
			state.setValue(3);
			interpolate(turbine, 0, 18);
			settimer(func { state.setValue(0) }, 25);	# -> engines off
		}
	}
}



# torquemeter
var torque_val = 0;
torque.setDoubleValue(0);

set_torque = func {
	var f = 0.1;						# low pass coeff
	var t = torque.getValue();
	torque_val = t * f + torque_val * (1 - f);
	torque_pct.setDoubleValue(torque_val / 5300);
}



# stall sound
var stall_val = 0;
stall.setDoubleValue(0);

set_stall = func {
	var s = stall.getValue();
	if (s < stall_val) {
		var delta_time = dt.getValue();
		var f = delta_time / (0.3 + delta_time);	# low pass coeff
		stall_val = s * f + stall_val * (1 - f);
	} else {
		stall_val = s;
	}
	var t = throttle.getValue();
	stall_filtered.setDoubleValue(stall_val + 0.006 * (1 - t));
}



# crash handler =====================================================
var load = nil;
crash = func {
	if (arg[0]) {
		# crash
		setprop("sim/model/bo105/tail-angle", 35);
		setprop("sim/model/bo105/shadow", 0);
		setprop("sim/model/bo105/doors/door[0]/position-norm", 0.2);
		setprop("sim/model/bo105/doors/door[1]/position-norm", 0.9);
		setprop("sim/model/bo105/doors/door[2]/position-norm", 0.2);
		setprop("sim/model/bo105/doors/door[3]/position-norm", 0.6);
		setprop("sim/model/bo105/doors/door[4]/position-norm", 0.1);
		setprop("sim/model/bo105/doors/door[5]/position-norm", 0.05);
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
		torque_pct.setValue(torque_val = 0);
		stall_filtered.setValue(stall_val = 0);
		state.setValue(0);
		var n = props.globals.getNode("models", 1);
		for (var i = 0; 1; i += 1) {
			if (n.getChild("model", i, 0) == nil) {
				n = n.getChild("model", i, 1);
				n.setValues({
					"path": "Models/Fauna/cow.ac",
					"longitude-deg": getprop("position/longitude-deg"),
					"latitude-deg": getprop("position/latitude-deg"),
					"elevation-ft": getprop("position/ground-elev-ft"),
					"heading-deg": getprop("orientation/heading-deg"),
					#"pitch-deg": getprop("orientation/pitch-deg"),
					#"roll-deg": getprop("orientation/roll-deg"),
				});
				load = n;
				break;
			}
		}
	} else {
		# uncrash (for replay)
		setprop("sim/model/bo105/tail-angle", 0);
		setprop("sim/model/bo105/shadow", 1);
		doors.reset();
		setprop("rotors/tail/rpm", 2219);
		setprop("rotors/main/rpm", 442);
		for (i = 1; i < 5; i += 1) {
			setprop("rotors/main/blade" ~ i ~ "_flap", 0);
			setprop("rotors/main/blade" ~ i ~ "_incidence", 0);
		}
		strobe_switch.setValue(1);
		beacon_switch.setValue(1);
		rotor.setValue(1);
		turbine.setValue(100);
		state.setValue(2);
	}
}




# "manual" rotor animation for flight data recorder replay ============
var rotor_step = props.globals.getNode("sim/model/bo105/rotor-step-deg");
var blade1_pos = props.globals.getNode("rotors/main/blade1_pos", 1);
var blade2_pos = props.globals.getNode("rotors/main/blade2_pos", 1);
var blade3_pos = props.globals.getNode("rotors/main/blade3_pos", 1);
var blade4_pos = props.globals.getNode("rotors/main/blade4_pos", 1);
var rotorangle = 0;

rotoranim_loop = func {
	i = rotor_step.getValue();
	if (i >= 0.0) {
		blade1_pos.setValue(rotorangle);
		blade2_pos.setValue(rotorangle + 90);
		blade3_pos.setValue(rotorangle + 180);
		blade4_pos.setValue(rotorangle + 270);
		rotorangle += i;
		settimer(rotoranim_loop, 0.1);
	}
}

init_rotoranim = func {
	if (rotor_step.getValue() >= 0.0) {
		settimer(rotoranim_loop, 0.1);
	}
}



# Red Cross emblem ==================================================
determine_emblem = func {
	# Use the appropriate internationally acknowleged protective Red Cross/Crescent
	# symbol, depending on the starting airport. (http://www.ifrc.org/ADDRESS/directory.asp)

	var C = 1;	# Red Cross
	var L = 2;	# Rec Crescent (opening left)
	var R = 3;	# Red Crescent (opening right)
	var Y = 4;	# Red Crystal
	var X = 5;	# StarOfLife

	var emblem = [
		["<none>",       "empty.rgb"],
		["Red Cross",    "Emblems/red-cross.rgb"],
		["Red Crescent", "Emblems/red-crescent-l.rgb"],
		["Red Crescent", "Emblems/red-crescent-r.rgb"],
		["Red Crystal",  "Emblems/red-crystal.rgb"],
		["Star of Life", "Emblems/star-of-life.rgb"],
	];

	var icao = [
		["",	C, "<default>"],
		["DA",	R, "Algeria"],
		["DT",	L, "Tunisia"],
		["GM",	R, "Morocco"],
		["GQ",	R, "Mauritania"],
		["HC",	R, "Somalia"],
		["HD",	R, "Djibouti"],
		["HE",	R, "Egypt"],
		["HL",	R, "Libyan Arab Jamahiriya"],
		["HS",	R, "Sudan"],
		["LL",	Y, "Israel"],
		["LO",	C, "Austria"],
		["LT",	L, "Turkey"],
		["LV",	R, "Palestine"],
		["OA",	R, "Afghanistan"],
		["OB",	R, "Bahrain"],
		["OE",	R, "Saudi Arabia"],
		["OI",	R, "Islamic Republic of Iran"],
		["OJ",	R, "Jordan"],
		["OK",	R, "Kuwait"],
		["OM",	R, "United Arab Emirates"],
		["OP",	L, "Pakistan"],
		["OR",	R, "Iraq"],
		["OS",	R, "Syrian Arab Republic"],
		["OT",	R, "Qatar"],
		["OY",	R, "Yemen"],
		["UA",	R, "Kazakhstan"],
		["UAF",	L, "Kyrgyzstan"],
		["UB",	L, "Azerbaidjan"],
		["UT",	L, "Uzbekistan"],
		["UTA",	L, "Turkmenistan"],
		["UTD",	R, "Tajikistan"],
		["VG",	R, "Bangladesh"],
		["WB",	R, "Malaysia"],
		["WBAK",R, "Brunei Darussalam"],
		["WBSB",R, "Brunei Darussalam"],
		["WM",	R, "Malaysia"],
	];

	var apt = getprop("/sim/presets/airport-id");
	var country = nil;
	var maxlen = -1;

	foreach (var entry; icao) {
		if (substr(apt, 0, size(entry[0])) == entry[0]) {
			if (size(entry[0]) > maxlen) {
				maxlen = size(entry[0]);
				country = entry;
			}
		}
	}
	printlog("info", "bo105: ", apt ~ "/" ~ country[2] ~ " >> " ~ emblem[country[1]][0]);
	return emblem[country[1]][1];
}



Variant = {
	new : func {
		var m = { parents : [Variant] };
		m.self = props.globals.getNode("sim/model/bo105", 1);
		m.emblem_medevac = determine_emblem();
		m.emblem_military = m.self.getNode("insignia", 1).getValue();
		m.variantN = m.self.getNode("variants", 1);
		m.list = [];
		m.index = m.self.getNode("variant", 1).getValue();
		m.scan();
		return m;
	},
	scan : func {
		me.variantN.removeChildren("variant");
		me.list = nil;
		var dir = "Aircraft/bo105/Models/Variants";
		foreach (var f; directory(getprop("/sim/fg-root") ~ "/" ~ dir)) {
			if (substr(f, size(f) - 4) != ".xml") {
				continue;
			}
			var tmp = me.self.getNode("tmp", 1);
			printlog("info", "bo105: loading ", dir ~ "/" ~ f);
			me.load(dir ~ "/" ~ f);
			var index = tmp.getNode("index");
			if (index != nil) {
				index = index.getValue();
			}
			printlog("info", "       #", index, " -- ", tmp.getNode("desc", 1).getValue());
			if (index == nil or index < 0) {
				for (index = 1000; 693; index += 1) {
					if (me.variantN.getChild("variant", index, 0) == nil) {
						break;
					}
				}
			}
			props.copy(tmp, me.variantN.getChild("variant", index, 1));
			tmp.removeChildren();
		}
		me.list = me.variantN.getChildren("variant");
		if (me.index < 0 or me.index >= size(me.list)) {
			me.index = 0;
		}
		me.reset();
	},
	next : func {
		me.index += 1;
		if (me.index >= size(me.list)) {
			me.index = 0;
		}
		me.reset();
	},
	previous : func {
		me.index -= 1;
		if (me.index < 0) {
			me.index = size(me.list) - 1;
		}
		me.reset();
	},
	load : func(file) {
		fgcommand("loadxml", props.Node.new({"filename": file, "targetnode": "sim/model/bo105/tmp"}));
	},
	reset : func {
		props.copy(me.list[me.index], me.self);
		var emblem = me.self.getNode("emblem", 1).getValue();
		if (emblem == "$MED") {
			emblem = me.emblem_medevac;
		} elsif (emblem == "$MIL") {
			emblem = me.emblem_military;
		} elsif (emblem == "") {
			emblem = "empty.rgb";
		}
		me.self.getNode("material/emblem/texture", 1).setValue(emblem);

		if (weapons != nil) {
			weapons.disable();
			weapons = nil;
		}

		if (me.self.getNode("missiles", 1).getBoolValue()) {
			weapons = HOT;
		} elsif (me.self.getNode("miniguns", 1).getBoolValue()) {
			weapons = MG;
		}

		if (weapons != nil) {
			weapons.enable();
		}
		me.self.getNode("variant", 1).setIntValue(me.index);
	},
};




# weapons ===========================================================

# aircraft.weapon.new(
#	<property>,
#	<submodel-index>,
#	<capacity>,
#	<drop-weight>,		# dropped weight per shot round/missile
#	<base-weight>		# remaining empty weight
#	[, <submodel-factor>	# one reported submodel counts for how many items
#	[, <weight-prop>]]);	# where to put the calculated weight
Weapon = {
	new : func(prop, ndx, cap, dropw, basew, fac = 1, wprop = nil) {
		m = { parents : [Weapon] };
		m.node = makeNode(prop);
		m.enabledN = m.node.getNode("enabled", 1);
		m.enabledN.setBoolValue(0);

		m.triggerN = m.node.getNode("trigger", 1);
		m.triggerN.setBoolValue(0);

		m.countN = m.node.getNode("count", 1);
		m.countN.setIntValue(0);

		m.sm_countN = props.globals.getNode("ai/submodels/submodel[" ~ ndx ~ "]/count", 1);
		m.sm_countN.setValue(0);

		m.capacity = cap;
		m.dropweight = dropw * 2.2046226;	# kg2lbs
		m.baseweight = basew * 2.2046226;
		m.ratio = fac;

		if (wprop != nil) {
			m.weightN = makeNode(wprop);
		} else {
			m.weightN = m.node.getNode("weight-lb", 1);
		}
		return m;
	},
	enable : func {
		me.fire(0);
		me.enabledN.setBoolValue(arg[0]);
		me.update();
		me;
	},
	setammo : func {
		me.sm_countN.setValue(arg[0] / me.ratio);
		me.update();
		me;
	},
	getammo : func {
		me.countN.getValue();
	},
	getweight : func {
		me.weightN.getValue();
	},
	reload : func {
		me.fire(0);
		me.setammo(me.capacity);
		me;
	},
	update : func {
		if (me.enabledN.getValue()) {
			me.countN.setValue(me.sm_countN.getValue() * me.ratio);
			me.weightN.setValue(me.baseweight + me.countN.getValue() * me.dropweight);
		} else {
			me.countN.setValue(0);
			me.weightN.setValue(0);
		}
	},
	fire : func(t) {
		me.triggerN.setBoolValue(t);
		if (t) {
			me._loop_();
		}
	},
	_loop_  : func {
		me.update();
		if (me.triggerN.getBoolValue() and me.enabledN.getValue() and me.countN.getValue()) {
			settimer(func { me._loop_() }, 1);
		}
	},
};


# "name", <ammo-desc>
WeaponSystem = {
	new : func(name, adesc) {
		m = { parents : [WeaponSystem] };
		m.name = name;
		m.ammunition_type = adesc;
		m.weapons = [];
		m.enabled = 0;
		m.select = 0;
		return m;
	},
	add : func {
		append(me.weapons, arg[0]);
	},
	reload : func {
		me.select = 0;
		foreach (w; me.weapons) {
			w.reload();
		}
	},
	fire : func {
		foreach (w; me.weapons) {
			w.fire(arg[0]);
		}
	},
	getammo : func {
		n = 0;
		foreach (w; me.weapons) {
			n += w.getammo();
		}
		return n;
	},
	ammodesc : func {
		me.ammunition_type;
	},
	disable : func {
		me.enabled = 0;
		foreach (w; me.weapons) {
			w.enable(0);
		}
	},
	enable : func {
		me.select = 0;
		foreach (w; me.weapons) {
			w.enable(1);
			w.reload();
		}
		me.enabled = 1;
	},
};


var weapons = nil;
var MG = nil;
var HOT = nil;

init_weapons = func {
	MG = WeaponSystem.new("M134", "rounds (7.62 mm)");
	# propellant: 2.98 g + bullet: 9.75 g  ->  0.0127 kg
	# M134 minigun: 18.8 kg + M27 armament subsystem: ??  ->
	MG.add(Weapon.new("sim/model/bo105/weapons/MG[0]", 0, 4000, 0.0127, 100, 10));
	MG.add(Weapon.new("sim/model/bo105/weapons/MG[1]", 1, 4000, 0.0127, 100, 10));

	HOT = WeaponSystem.new("HOT", "missiles");
	# 24 kg; missile + tube: 32 kg
	HOT.add(Weapon.new("sim/model/bo105/weapons/HOT[0]", 2, 1, 24, 20));
	HOT.add(Weapon.new("sim/model/bo105/weapons/HOT[1]", 3, 1, 24, 20));
	HOT.add(Weapon.new("sim/model/bo105/weapons/HOT[2]", 4, 1, 24, 20));
	HOT.add(Weapon.new("sim/model/bo105/weapons/HOT[3]", 5, 1, 24, 20));
	HOT.add(Weapon.new("sim/model/bo105/weapons/HOT[4]", 6, 1, 24, 20));
	HOT.add(Weapon.new("sim/model/bo105/weapons/HOT[5]", 7, 1, 24, 20));
	HOT.fire = func(trigger) {
		if (!trigger or me.select >= size(me.weapons)) {
			return;
		}
		wp = me.weapons[me.select];
		wp.fire(1);
		weight = wp.weightN.getValue();
		wp.weightN.setValue(weight + 300);	# shake the bo
		settimer(func { wp.weightN.setValue(weight) }, 0.3);
		me.select += 1;
	}
}


# called from Dialogs/config.xml
get_ammunition = func {
	weapons != nil ? weapons.getammo() ~ " " ~ weapons.ammodesc() : "";
}


var TRIGGER = -1;
setlistener("controls/armament/trigger", func {
	if (weapons != nil) {
		var t = cmdarg().getBoolValue();
		if (t != TRIGGER) {
			weapons.fire(TRIGGER = t);
		}
	}
});


setlistener("controls/gear/brake-left", func {
	setprop("controls/armament/trigger", cmdarg().getBoolValue());
});


reload = func {
	if (weapons != nil) {
		weapons.reload();
	}
}



# view management ===================================================

ViewAxis = dynamic_view.ViewAxis;

ViewManager = {
	new : func {
		var m = { parents : [ViewManager] };
		m.pitchN = props.globals.getNode("orientation/pitch-deg", 1);
		m.rollN = props.globals.getNode("orientation/roll-deg", 1);
		m.speedN = props.globals.getNode("velocities/airspeed-kt", 1);

		m.heading_axis = ViewAxis.new("sim/current-view/goal-heading-offset-deg");
		m.pitch_axis = ViewAxis.new("sim/current-view/goal-pitch-offset-deg");
		m.roll_axis = ViewAxis.new("sim/current-view/goal-roll-offset-deg");

		m.reset();
		return m;
	},
	reset : func {
		me.lookat_active = 0;
		me.heading_axis.reset();
		me.pitch_axis.reset();
		me.roll_axis.reset();
	},
	add_offset : func {
		me.heading_axis.add_offset();
		me.pitch_axis.add_offset();
		me.roll_axis.add_offset();
	},
	apply : func {
		if (me.lookat_active) {
			me.heading_axis.prop.setValue(me.lookat_heading);
			me.pitch_axis.prop.setValue(me.lookat_pitch);
			return;
		}

		var roll = me.rollN.getValue();
		var pitch = me.pitchN.getValue();
		var speed = 1 - normatan(me.speedN.getValue() / 20);

		me.heading_axis.apply(							# view heading due to ...
			(roll < 0 ? -50 : -25) * npow(sin(roll) * cos(pitch), 2)	#    roll
		);
		me.pitch_axis.apply(							# view pitch due to ...
			(pitch < 0 ? -35 : -40) * sin(pitch) * speed			#    pitch
			+ 15 * sin(roll) * sin(roll)					#    roll
		);
		me.roll_axis.apply(							# view roll due to ...
			-20 * sin(roll) * cos(pitch) * speed				#    roll
		);
	},
	lookat : func(h = nil, p = nil) {
		if (h == nil) {
			view.resetView();
			me.lookat_active = 0;
			return;
		}
		me.lookat_heading = h;
		me.lookat_pitch = p;
		me.lookat_active = 1;
	},
};


var flap_mode = 0;
controls.flapsDown = func(v) {
	if (!flap_mode) {
		if (v < 0) {
			flap_mode = 1;
			view_manager.lookat(10, -12);
		} elsif (v > 0) {
			flap_mode = 2;
		}
	} else {
		if (flap_mode == 1) {
			view_manager.lookat();
		} else {
		}
		flap_mode = 0;
	}
}


# main() ============================================================

main_loop = func {
	set_torque();
	set_stall();
	settimer(main_loop, 0);
}


var CRASHED = 0;
var variant = nil;
var doors = nil;
var view_manager = nil;
var config_dialog = nil;


# initialization
setlistener("/sim/signals/fdm-initialized", func {
	config_dialog = gui.Dialog.new("/sim/gui/dialogs/bo105/config/dialog",
			"Aircraft/bo105/Dialogs/config.xml");

	init_rotoranim();
	init_weapons();

	doors = Doors.new();
	variant = Variant.new();

	settimer(func { dynamic_view.register(view_manager = ViewManager.new()) }, 4);

	setlistener("/sim/signals/reinit", func {
		cprint("32;1", "reinit ", cmdarg().getValue());
		variant.scan();
		view_manager.reset();
		CRASHED = 0;

		if (load != nil) {
			load.getNode("load", 1);
			load.removeChildren("load");
			load = nil;
		}
	});

	setlistener("sim/crashed", func {
		cprint("31;1", "crashed ", cmdarg().getValue());
		if (cmdarg().getBoolValue()) {
			crash(CRASHED = 1);
		}
	});

	setlistener("/sim/freeze/replay-state", func {
		cprint("33;1", cmdarg().getValue() ? "replay" : "pause");
		if (CRASHED) {
			crash(!cmdarg().getBoolValue())
		}
	});

	# the attitude indicator needs pressure
	settimer(func { setprop("engines/engine/rpm", 3000) }, 8);

	main_loop();
});


