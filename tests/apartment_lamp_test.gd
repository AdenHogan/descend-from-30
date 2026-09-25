extends Node

# APARTMENT LAMPS (scripts/apartment_lights.gd, owner round 14): the rooms' drawn fixtures are lit for
# real in the afternoon and at night — seeded per flat, steady / flickering / cutting out — never in
# the morning, never in a burnt flat (a battery lantern excepted). Run:
#   godot --headless res://tests/apartment_lamp_test.tscn

const AL = preload("res://scripts/apartment_lights.gd")
const TYPES := ["living_room", "bedroom", "kitchen", "bathroom", "study", "dining_room"]
const KINDS := ["table", "desk", "floor", "lava", "lantern", "pendant", "bulb", "flush", "tube", "chandelier"]

var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== apartment lamp test ===")
	_test_fixtures_in_modules()
	_test_states()
	await _test_room_lit_at_night()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _test_fixtures_in_modules() -> void:
	print("[the module scenes carry their fixtures]")
	var total := 0
	var with_lights := {}
	var da := DirAccess.open("res://scenes/Room_Modules")
	for f in da.get_files():
		if not f.ends_with(".tscn"):
			continue
		var m = load("res://scenes/Room_Modules/" + f).instantiate()
		var t := ""
		for tt in TYPES:
			if f.begins_with(tt) and tt.length() > t.length():
				t = tt
		for ch in m.get_children():
			if ch is Marker2D and not str(ch.name).begins_with("anchor_"):
				check(false, "%s: a non-anchor Marker2D (%s) would be taken for a scavenge node" % [f, ch.name])
		var holder = m.get_node_or_null("Lights")
		if holder != null:
			for l in holder.get_children():
				total += 1
				with_lights[t] = with_lights.get(t, 0) + (1 if l.get_index() == 0 else 0)
				var ok: bool = l is Node2D and not (l is Marker2D) and str(l.get_meta("kind", "")) in KINDS \
					and l.position.x >= 0 and l.position.x < 320 and l.position.y >= 0 and l.position.y < 144
				if not ok:
					check(false, "%s: fixture %s is a Node2D with a known kind inside the module" % [f, l.name])
		m.free()
	check(total >= 30, "the rooms carry %d light fixtures" % total)
	for t in TYPES:
		check(with_lights.get(t, 0) >= 4, "%s: %d of 5 variants have a fixture" % [t, with_lights.get(t, 0)])


func _test_states() -> void:
	print("[who's lit: seeded, by run]")
	WorldState.new_game()
	WorldState.master_seed = 777
	var apts: Array = []
	for fl in range(1, 30):
		for col in range(1, 6):
			apts.append(str(fl) + "0" + str(col))
	var lit_morning := 0
	var counts := {2: [0, 0], 3: [0, 0]}          # run -> [on, total] (mains fixtures)
	var modes := {2: {}, 3: {}}
	var patterns := {}
	var tube_flicker := false
	var lantern_cut := false
	var lantern_on_unpowered := false
	for apt in apts:
		for run in [1, 2, 3]:
			var powered: bool = AL.flat_powered(apt, run, -1)
			var pattern := ""
			for slot in range(3):
				for idx in range(2):
					for kind in ["table", "tube", "pendant"]:
						var st: Dictionary = AL.fixture_state(apt, slot, idx, kind, run, powered)
						check_same(st, AL.fixture_state(apt, slot, idx, kind, run, powered))
						if run == 1:
							lit_morning += int(st["on"])
							continue
						counts[run][1] += 1
						if st["on"]:
							counts[run][0] += 1
							modes[run][st["mode"]] = modes[run].get(st["mode"], 0) + 1
							if kind == "tube" and st["mode"] == "flicker":
								tube_flicker = true
						if kind == "table":            # on/off doesn't depend on the kind: 6 bits a flat
							pattern += "1" if st["on"] else "0"
					var ls: Dictionary = AL.fixture_state(apt, slot, idx, "lantern", run, false)
					if ls["mode"] == "cutout":
						lantern_cut = true
					if run > 1 and ls["on"]:
						lantern_on_unpowered = true
			if run == 3:
				patterns[pattern] = patterns.get(pattern, 0) + 1
	check(lit_morning == 0, "the MORNING is daylight — no lamp is on (%d)" % lit_morning)
	var f2: float = float(counts[2][0]) / counts[2][1]
	var f3: float = float(counts[3][0]) / counts[3][1]
	check(f2 > 0.20 and f2 < 0.60, "the afternoon lights some of them (%.2f)" % f2)
	check(f3 > 0.25 and f3 < 0.70, "the night lights some of them (%.2f)" % f3)
	var cut2: float = float(modes[2].get("cutout", 0)) / maxi(counts[2][0], 1)
	var cut3: float = float(modes[3].get("cutout", 0)) / maxi(counts[3][0], 1)
	check(cut3 > cut2 and cut3 > 0.25, "far more cut out at night (%.2f vs %.2f)" % [cut3, cut2])
	check(modes[3].get("flicker", 0) > 0 and modes[3].get("steady", 0) > 0, "night lamps flicker AND hold steady")
	check(modes[3].get("blink", 0) > 0 and not tube_flicker, "a failing tube blinks (never the lamp flicker)")
	check(not lantern_cut, "a battery lantern gutters, never cuts out")
	check(lantern_on_unpowered, "a battery lantern can be on in a flat with no power")
	# 145 flats over 6 fixture slots (64 possible patterns): plenty of variety, and no one LIT pattern
	# repeated flat after flat (all-dark = a flat with no power, which is meant to be common).
	var top_lit := 0
	for p in patterns:
		if p.contains("1"):
			top_lit = maxi(top_lit, patterns[p])
	check(patterns.size() >= 30, "flats don't light alike (%d distinct night patterns of 64)" % patterns.size())
	@warning_ignore("integer_division")
	check(top_lit <= apts.size() / 10, "no lit pattern repeats flat after flat (most common: %d of %d)" % [top_lit, apts.size()])
	var burnt_powered := 0
	for apt in apts:
		burnt_powered += int(AL.flat_powered(apt, 3, WorldState.FIRE_BLAZE)) + int(AL.flat_powered(apt, 3, WorldState.FIRE_CHARRED))
	check(burnt_powered == 0, "a burnt flat (blaze / charred) has no power")


func check_same(a: Dictionary, b: Dictionary) -> void:
	if a != b:
		check(false, "the same fixture decides the same way twice")


func _expected_on(room) -> int:
	# The lamps a room SHOULD light, recomputed from its modules with the same rules.
	var n := 0
	var fire: int = WorldState.apartment_fire_stage(room._apt_floor(), room._apt_index())
	for m in room.get_tree().get_nodes_in_group("room_module"):
		var slot: int = int(round((m.position.x - 113.0) / 320.0))
		var holder = m.get_node_or_null("Lights")
		if holder == null:
			continue
		var powered: bool = AL.flat_powered(room.apartment_id, WorldState.current_run, fire)
		var has_bal: bool = m.get_node_or_null("Balcony") != null and WorldState.is_balcony_slot(room.apartment_id, slot)
		var i := 0
		for l in holder.get_children():
			var idx := i
			i += 1
			if has_bal and bool(l.get_meta("balcony_strip", false)):
				continue
			if AL.fixture_state(room.apartment_id, slot, idx, str(l.get_meta("kind")), WorldState.current_run, powered)["on"]:
				n += 1
	return n


func _room(apt: String, run: int):
	WorldState.is_first_run = false
	WorldState.current_run = run
	WorldState.current_apartment_id = apt
	WorldState.current_floor = int(apt.left(apt.length() - 2))
	WorldState.spawn_source = ""
	var room = load("res://scenes/room.tscn").instantiate()
	add_child(room)
	for i in range(4):
		await get_tree().process_frame
	return room


func _lamp_nodes(room) -> Array:
	var out: Array = []
	for c in room.get_children():
		if c.get_script() == AL:
			out.append(c)
	return out


func _test_room_lit_at_night() -> void:
	print("[a night flat: real lights, flickering / cutting out]")
	WorldState.new_game()
	WorldState.master_seed = 777
	var room = null
	var lamps: Array = []
	for fl in range(4, 26):
		for col in range(1, 6):
			var apt := str(fl) + "0" + str(col)
			var r = await _room(apt, 3)
			var want: int = _expected_on(r)
			var got := 0
			for n in _lamp_nodes(r):
				got += n.lamp_count()
			if want != got:
				check(false, "%s: lights %d lamps, the rules say %d" % [apt, got, want])
			var has_cut := false
			for n in _lamp_nodes(r):
				for e in n.lamps():
					if e["mode"] == "cutout":
						has_cut = true
			if got >= 2 and has_cut and room == null:
				room = r
				for n in _lamp_nodes(r):
					lamps += n.lamps()
				break
			r.free()
			await get_tree().process_frame
		if room != null:
			break
	check(room != null, "a night flat with lamps on, one of them cutting out")
	if room == null:
		return
	print("  (apartment %s, %d lamps)" % [room.apartment_id, lamps.size()])
	for e in lamps:
		check(e["light"] is PointLight2D and e["light"].energy > 0.0, "a lit %s is a real PointLight2D" % e["kind"])
	# Drive time: a cutout lamp goes fully dark, then comes back to full.
	var cut: Dictionary = {}
	var steady: Dictionary = {}
	for e in lamps:
		if e["mode"] == "cutout" and cut.is_empty():
			cut = e
		if e["mode"] == "steady" and steady.is_empty():
			steady = e
	var saw_dark := false
	var back_on := false
	var steady_same := true
	var holders: Array = _lamp_nodes(room)
	for i in range(1200):                      # 60 s in 0.05 s steps
		for h in holders:
			h.tick(0.05)
		if not steady.is_empty() and absf(steady["light"].energy - steady["base"]) > 0.001:
			steady_same = false
		if cut["light"].energy <= 0.0001 and not cut["light"].enabled:
			saw_dark = true
		elif saw_dark and absf(cut["light"].energy - cut["base"]) < 0.001:
			back_on = true
	check(saw_dark, "a cutout lamp goes fully dark")
	check(back_on, "…and comes back on")
	check(steady_same, "a steady lamp holds its brightness (checked: %s)" % ("yes" if not steady.is_empty() else "no steady lamp here"))
	var room_apt: String = room.apartment_id
	room.free()
	await get_tree().process_frame
	# The same flat in the MORNING: daylight, nothing on.
	var morning = await _room(room_apt, 1)
	var lit := 0
	for n in _lamp_nodes(morning):
		lit += n.lamp_count()
	check(lit == 0, "the same flat in the MORNING lights nothing (%d)" % lit)
	morning.free()
	await get_tree().process_frame
