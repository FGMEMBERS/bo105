# Melchior FRANZ, < mfranz # aon : at >

if (!contains(globals, "cprint")) {
	globals.cprint = func {};
}

var makeNode = aircraft.makeNode;

var sin = func(a) { math.sin(a * math.pi / 180.0) }
var cos = func(a) { math.cos(a * math.pi / 180.0) }
var pow = func(v, w) { math.exp(math.ln(v) * w) }
var npow = func(v, w) { math.exp(math.ln(abs(v)) * w) * (v < 0 ? -1 : 1) }
var clamp = func(v, min = 0, max = 1) { v < min ? min : v > max ? max : v }
var normatan = func(x) { math.atan2(x, 1) * 2 / math.pi }


# config file entries ===============================================
aircraft.data.add("/sim/model/bo105/variant");

# timers ============================================================
var turbine_timer = aircraft.timer.new("/sim/time/hobbs/turbines", 10);
aircraft.timer.new("/sim/time/hobbs/helicopter", nil).start();

# strobes ===========================================================
var strobe_switch = props.globals.getNode("controls/lighting/strobe", 1);
aircraft.light.new("sim/model/bo105/lighting/strobe-top", [0.05, 1.00], strobe_switch);
aircraft.light.new("sim/model/bo105/lighting/strobe-bottom", [0.05, 1.03], strobe_switch);

# beacons ===========================================================
var beacon_switch = props.globals.getNode("controls/lighting/beacon", 1);
aircraft.light.new("sim/model/bo105/lighting/beacon-top", [0.62, 0.62], beacon_switch);
aircraft.light.new("sim/model/bo105/lighting/beacon-bottom", [0.63, 0.63], beacon_switch);


# nav lights ========================================================
var nav_light_switch = props.globals.getNode("controls/lighting/nav-lights", 1);
var visibility = props.globals.getNode("environment/visibility-m", 1);
var sun_angle = props.globals.getNode("sim/time/sun-angle-rad", 1);
var nav_lights = props.globals.getNode("sim/model/bo105/lighting/nav-lights", 1);

var nav_light_loop = func {
	if (nav_light_switch.getValue()) {
		nav_lights.setValue(visibility.getValue() < 5000 or sun_angle.getValue() > 1.4);
	} else {
		nav_lights.setValue(0);
	}
	settimer(nav_light_loop, 3);
}

settimer(nav_light_loop, 0);



# doors =============================================================
var Doors = {
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
var collective = props.globals.getNode("controls/engines/engine[0]/throttle");
var turbine = props.globals.getNode("sim/model/bo105/turbine-rpm-pct", 1);
var torque_pct = props.globals.getNode("sim/model/bo105/torque-pct", 1);
var stall = props.globals.getNode("rotors/main/stall", 1);
var stall_filtered = props.globals.getNode("rotors/main/stall-filtered", 1);


# 0 off
# 1 startup sound in progress
# 2 sound loop
# 3 shutdown sound in progress

var engines = func {
	crashed and return;
	var s = state.getValue();
	if (arg[0] == 1) {
		if (s == 0) {
			turbine_timer.start();
			state.setValue(1);				# engines started
			settimer(func { rotor.setValue(1) }, 3);
			interpolate(turbine, 100, 25);
			settimer(func { state.setValue(2) }, 10.5);	# -> engines running
		}
	} else {
		if (s == 2) {
			turbine_timer.stop();
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

var update_torque = func(dt) {
	var f = dt / (0.2 + dt);
	torque_val = torque.getValue() * f + torque_val * (1 - f);
	torque_pct.setDoubleValue(torque_val / 5300);
}



# blade vibration absorber pendulum
var pendulum = props.globals.getNode("/sim/model/bo105/absorber-angle-deg", 1);
var update_absorber = func {
	pendulum.setDoubleValue(90 * clamp(abs(rotor_rpm.getValue()) / 90));
}



# sound =============================================================

# stall sound
var stall_val = 0;
stall.setDoubleValue(0);

var update_stall = func(dt) {
	var s = stall.getValue();
	if (s < stall_val) {
		var f = dt / (0.3 + dt);
		stall_val = s * f + stall_val * (1 - f);
	} else {
		stall_val = s;
	}
	var c = collective.getValue();
	stall_filtered.setDoubleValue(stall_val + 0.006 * (1 - c));
}



# skid slide sound
var Skid = {
	new : func(n) {
		var m = { parents : [Skid] };
		var soundN = props.globals.getNode("sim/sound", 1).getChild("slide", n, 1);
		var gearN = props.globals.getNode("gear", 1).getChild("gear", n, 1);

		m.compressionN = gearN.getNode("compression-norm", 1);
		m.rollspeedN = gearN.getNode("rollspeed-ms", 1);
		m.frictionN = gearN.getNode("ground-friction-factor", 1);
		m.wowN = gearN.getNode("wow", 1);
		m.volumeN = soundN.getNode("volume", 1);
		m.pitchN = soundN.getNode("pitch", 1);

		m.compressionN.setDoubleValue(0);
		m.rollspeedN.setDoubleValue(0);
		m.frictionN.setDoubleValue(0);
		m.volumeN.setDoubleValue(0);
		m.pitchN.setDoubleValue(0);
		m.wowN.setBoolValue(1);
		m.self = n;
		return m;
	},
	update : func {
		me.wowN.getBoolValue() or return;
		var rollspeed = abs(me.rollspeedN.getValue());
		me.pitchN.setDoubleValue(rollspeed * 0.6);

		var s = normatan(20 * rollspeed);
		var f = clamp((me.frictionN.getValue() - 0.5) * 2);
		var c = clamp(me.compressionN.getValue() * 2);
		me.volumeN.setDoubleValue(s * f * c * 2);
		#if (!me.self) {
		#	cprint("33;1", sprintf("S=%0.3f  F=%0.3f  C=%0.3f  >>  %0.3f", s, f, c, s * f * c));
		#}
	},
};

var skid = [];
for (var i = 0; i < 4; i += 1) {
	append(skid, Skid.new(i));
}

var update_slide = func {
	forindex (var i; skid) {
		skid[i].update();
	}
}



# crash handler =====================================================
#var load = nil;
var crash = func {
	if (arg[0]) {
		# crash
		setprop("sim/model/bo105/tail-angle-deg", 35);
		setprop("sim/model/bo105/shadow", 0);
		setprop("sim/model/bo105/doors/door[0]/position-norm", 0.2);
		setprop("sim/model/bo105/doors/door[1]/position-norm", 0.9);
		setprop("sim/model/bo105/doors/door[2]/position-norm", 0.2);
		setprop("sim/model/bo105/doors/door[3]/position-norm", 0.6);
		setprop("sim/model/bo105/doors/door[4]/position-norm", 0.1);
		setprop("sim/model/bo105/doors/door[5]/position-norm", 0.05);
		setprop("rotors/main/rpm", 0);
		setprop("rotors/main/blade[0]/flap-deg", -60);
		setprop("rotors/main/blade[1]/flap-deg", -50);
		setprop("rotors/main/blade[2]/flap-deg", -40);
		setprop("rotors/main/blade[3]/flap-deg", -30);
		setprop("rotors/main/blade[0]/incidence-deg", -30);
		setprop("rotors/main/blade[1]/incidence-deg", -20);
		setprop("rotors/main/blade[2]/incidence-deg", -50);
		setprop("rotors/main/blade[3]/incidence-deg", -55);
		setprop("rotors/tail/rpm", 0);
		strobe_switch.setValue(0);
		beacon_switch.setValue(0);
		nav_light_switch.setValue(0);
		rotor.setValue(0);
		turbine.setValue(0);
		torque_pct.setValue(torque_val = 0);
		stall_filtered.setValue(stall_val = 0);
		state.setValue(0);

	} else {
		# uncrash (for replay)
		setprop("sim/model/bo105/tail-angle-deg", 0);
		setprop("sim/model/bo105/shadow", 1);
		doors.reset();
		setprop("rotors/tail/rpm", 2219);
		setprop("rotors/main/rpm", 442);
		for (i = 0; i < 4; i += 1) {
			setprop("rotors/main/blade[" ~ i ~ "]/flap-deg", 0);
			setprop("rotors/main/blade[" ~ i ~ "]/incidence-deg", 0);
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
var blade1_pos = props.globals.getNode("rotors/main/blade[0]/position-deg", 1);
var blade2_pos = props.globals.getNode("rotors/main/blade[1]/position-deg", 1);
var blade3_pos = props.globals.getNode("rotors/main/blade[2]/position-deg", 1);
var blade4_pos = props.globals.getNode("rotors/main/blade[3]/position-deg", 1);
var rotorangle = 0;

var rotoranim_loop = func {
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

var init_rotoranim = func {
	if (rotor_step.getValue() >= 0.0) {
		settimer(rotoranim_loop, 0.1);
	}
}



# Red Cross emblem ==================================================
var determine_emblem = func {
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



var Variant = {
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
		var dir = getprop("/sim/fg-root") ~ "/Aircraft/bo105/Models/Variants";
		foreach (var f; directory(dir)) {
			if (substr(f, -4) != ".xml")
				continue;

			var tmp = me.self.getNode("tmp", 1);
			printlog("info", "bo105: loading ", dir ~ "/" ~ f);
			me.load(dir ~ "/" ~ f);
			tmp.getNode("filename", 1).setValue(f);
			var index = tmp.getNode("index");
			if (index != nil)
				index = index.getValue();

			printlog("info", "       #", index, " -- ", tmp.getNode("desc", 1).getValue());
			if (index == nil or index < 0) {
				for (index = 1000; 1; index += 1)
					if (me.variantN.getChild("variant", index, 0) == nil)
						break;

			}
			props.copy(tmp, me.variantN.getChild("variant", index, 1));
			tmp.removeChildren();
		}
		me.list = me.variantN.getChildren("variant");
		if (me.index < 0 or me.index >= size(me.list))
			me.index = 0;

		me.reset();
	},
	set : func(i) {
		var s = size(me.list);
		while (i < 0)
			i += s;

		while (i >= s)
			i -= s;

		me.index = i;
		me.reset();
	},
	next : func {
		me.set(me.index + 1);
		me.reset();
	},
	previous : func {
		me.set(me.index - 1);
		me.reset();
	},
	load : func(file) {
		fgcommand("loadxml", props.Node.new({"filename": file, "targetnode": "sim/model/bo105/tmp"}));
	},
	reset : func {
		props.copy(me.list[me.index], me.self);
		var emblem = me.self.getNode("emblem", 1).getValue();
		if (emblem == "$MED")
			emblem = me.emblem_medevac;
		elsif (emblem == "$MIL")
			emblem = me.emblem_military;
		elsif (emblem == "")
			emblem = "empty.rgb";

		me.self.getNode("material/emblem/texture", 1).setValue(emblem);

		if (weapons != nil) {
			weapons.disable();
			weapons = nil;
		}

		if (me.self.getNode("missiles", 1).getBoolValue())
			weapons = HOT;
		elsif (me.self.getNode("miniguns", 1).getBoolValue())
			weapons = MG;

		if (weapons != nil)
			weapons.enable();

		me.self.getNode("variant", 1).setIntValue(me.index);

		# setup multiplayer properties
		var filename = me.list[me.index].getNode("filename").getValue();
		if (substr(filename, -4) == ".xml")
			filename = substr(filename, 0, size(filename) - 4);
		if (substr(emblem, 0, 8) == "Emblems/")
			emblem = substr(emblem, 8);
		if (substr(emblem, -4) == ".rgb")
			emblem = substr(emblem, 0, size(emblem) - 4);
		setprop("sim/multiplay/generic/string[0]", filename);
		setprop("sim/multiplay/generic/string[1]", emblem);
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
var Weapon = {
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
var WeaponSystem = {
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
var TRIGGER = -1;

var init_weapons = func {
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
		settimer(func { wp.fire(0) }, 1.5);
		weight = wp.weightN.getValue();
		wp.weightN.setValue(weight + 300);	# shake the bo
		settimer(func { wp.weightN.setValue(weight) }, 0.3);
		me.select += 1;
	}

	setlistener("/sim/model/bo105/weapons/impact/HOT", func(n) {
		var node = props.globals.getNode(n.getValue(), 1);
		var impact = geo.Coord.new().set_latlon(
				node.getNode("impact/latitude-deg").getValue(),
				node.getNode("impact/longitude-deg").getValue(),
				node.getNode("impact/elevation-m").getValue());

		geo.put_model("Aircraft/bo105/Models/hot.ac", impact,
		#geo.put_model("Models/fgfsdb/coolingtower.xml", impact,
				node.getNode("impact/heading-deg").getValue(),
				node.getNode("impact/pitch-deg").getValue(),
				node.getNode("impact/roll-deg").getValue());
		screen.log.write(sprintf("%.3f km",
				geo.aircraft_position().distance_to(impact) / 1000), 1, 0.9, 0.9);

		fgcommand("play-audio-sample", props.Node.new({
			path : getprop("/sim/fg-root") ~ "/Aircraft/bo105/Sounds",
			file : "HOT.wav",
			volume : 0.2,
		}));
	});

	#setlistener("/sim/model/bo105/weapons/impact/MG", func(n) {
	#	var node = props.globals.getNode(n.getValue(), 1);
	#	geo.put_model("Models/Airport/ils.xml",
	#			node.getNode("impact/latitude-deg").getValue(),
	#			node.getNode("impact/longitude-deg").getValue(),
	#			node.getNode("impact/elevation-m").getValue(),
	#			node.getNode("impact/heading-deg").getValue(),
	#			node.getNode("impact/pitch-deg").getValue(),
	#			node.getNode("impact/roll-deg").getValue());
	#});

	setlistener("controls/armament/trigger", func(n) {
		if (weapons != nil) {
			var t = n.getBoolValue();
			if (t != TRIGGER)
				weapons.fire(TRIGGER = t);
		}
	});

	controls.applyBrakes = func(v) {
		setprop("controls/armament/trigger", v);
	}
}


# called from Dialogs/config.xml
var get_ammunition = func {
	weapons != nil ? weapons.getammo() ~ " " ~ weapons.ammodesc() : "";
}


var reload = func {
	if (weapons != nil)
		weapons.reload();
}



# view management ===================================================

var elapsedN = props.globals.getNode("/sim/time/elapsed-sec", 1);
var flap_mode = 0;
var down_time = 0;
controls.flapsDown = func(v) {
	if (!flap_mode) {
		if (v < 0) {
			down_time = elapsedN.getValue();
			flap_mode = 1;
			dynamic_view.lookat(
					5,     # heading left
					-20,   # pitch up
					0,     # roll right
					0.2,   # right
					0.6,   # up
					0.85,  # back
					0.2,   # time
					55,    # field of view
			);
		} elsif (v > 0) {
			flap_mode = 2;
			aircraft.autotrim.start();
		}

	} else {
		if (flap_mode == 1) {
			if (elapsedN.getValue() < down_time + 0.2) {
				return;
			}
			dynamic_view.resume();
		} elsif (flap_mode == 2) {
			aircraft.autotrim.stop();
		}
		flap_mode = 0;
	}
}


# register function that may set me.heading_offset, me.pitch_offset, me.roll_offset,
# me.x_offset, me.y_offset, me.z_offset, and me.fov_offset
#
dynamic_view.register(func {
	var lowspeed = 1 - normatan(me.speedN.getValue() / 50);
	var r = sin(me.roll) * cos(me.pitch);

	me.heading_offset =						# heading change due to
		(me.roll < 0 ? -50 : -30) * r * abs(r);			#    roll left/right

	me.pitch_offset =						# pitch change due to
		(me.pitch < 0 ? -50 : -50) * sin(me.pitch) * lowspeed	#    pitch down/up
		+ 15 * sin(me.roll) * sin(me.roll);			#    roll

	me.roll_offset =						# roll change due to
		-15 * r * lowspeed;					#    roll
});




# main() ============================================================
var delta_time = props.globals.getNode("/sim/time/delta-sec", 1);
var adf_rotation = props.globals.getNode("/instrumentation/adf/rotation-deg", 1);
var hi_heading = props.globals.getNode("/instrumentation/heading-indicator/indicated-heading-deg", 1);

var main_loop = func {
	adf_rotation.setDoubleValue(hi_heading.getValue());

	var dt = delta_time.getValue();
	update_torque(dt);
	update_stall(dt);
	update_slide();
	update_absorber();
	settimer(main_loop, 0);
}


var crashed = 0;
var variant = nil;
var doors = nil;
var config_dialog = nil;


# initialization
setlistener("/sim/signals/fdm-initialized", func {
	config_dialog = gui.Dialog.new("/sim/gui/dialogs/bo105/config/dialog",
			"Aircraft/bo105/Dialogs/config.xml");

	init_rotoranim();
	init_weapons();

	doors = Doors.new();
	variant = Variant.new();
	collective.setDoubleValue(1);

	setlistener("/sim/signals/reinit", func(n) {
		n.getBoolValue() and return;
		cprint("32;1", "reinit");
		turbine_timer.stop();
		collective.setDoubleValue(1);
		variant.scan();
		crashed = 0;
	});

	setlistener("sim/crashed", func(n) {
		cprint("31;1", "crashed ", n.getValue());
		turbine_timer.stop();
		if (n.getBoolValue())
			crash(crashed = 1);
	});

	setlistener("/sim/freeze/replay-state", func(n) {
		cprint("33;1", n.getValue() ? "replay" : "pause");
		if (crashed)
			crash(!n.getBoolValue())
	});

	# the attitude indicator needs pressure
	settimer(func { setprop("engines/engine/rpm", 3000) }, 8);

	main_loop();
});


