extends Node

# NODE REACTIONS (owner round 34 + 45c): a drawer opens / a door swings / a glass tips / a screen goes dark the moment the player PRESSES interact on
# its node (not when the search ends), every other node puffs + makes a sound for what it is made of, and a search walked away from leaves it open.
# (Round 34's note follows.) A drawer opens / a door swings once its node has been
# searched. tools/art/openables.py bakes the frames; scripts/open_furniture.gd lays them over the module
# art. This locks the data (every opening matches an anchor on that furniture and fits the module), the
# wiring (closed until searched, plays on the search, open on re-entry, run looks) and that the loot
# panel's search really triggers it.
# Run: godot --headless res://tests/open_furniture_test.tscn

const OF := preload("res://scripts/open_furniture.gd")
var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== open furniture test ===")
	_test_meta()
	await _test_attach_and_open()
	await _test_loot_panel_triggers()
	await _test_press_starts_it()
	await _test_generic_reaction()
	await _test_new_kinds()
	await _test_special_sounds()
	await _test_critters()
	await _test_toilet_roll()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _test_meta() -> void:
	var meta: Dictionary = OF.meta()
	check(not meta.is_empty(), "open_meta.json loads (%d arts)" % meta.size())
	var total := 0
	var all_ok := true
	var near_ok := true
	var run_files := true
	for art in meta.keys():
		var scene: Node = load("res://scenes/Room_Modules/%s.tscn" % art).instantiate()
		for anchor in meta[art].keys():
			total += 1
			var d: Dictionary = meta[art][anchor]
			var fits: bool = int(d["x"]) >= 0 and int(d["y"]) >= 0 and int(d["x"]) + int(d["w"]) <= 320 and int(d["y"]) + int(d["h"]) <= 144
			var tex: Texture2D = OF._texture_for(art, anchor, 1)
			if not fits or tex == null or tex.get_width() != int(d["w"]) * int(d["frames"]) or tex.get_height() != int(d["h"]):
				all_ok = false
				print("    bad opening ", art, " ", anchor, " ", d)
			var a: Node = scene.get_node_or_null(String(anchor))
			if a == null:
				near_ok = false
				print("    no anchor ", art, " ", anchor)
			else:
				var p: Vector2 = a.position
				var kind := String(d.get("kind", "drawer"))
				if kind in ["drawer", "door_h", "door_drop"]:
					# the node sits ON the furniture that opens: inside its patch (give or take the frame)
					if p.x < d["x"] - 6 or p.x > d["x"] + d["w"] + 6 or p.y < d["y"] - 6 or p.y > d["y"] + d["h"] + 6:
						near_ok = false
						print("    anchor not on its furniture ", art, " ", anchor, " ", p, " ", d)
				else:
					# a thing that tips / a screen / a lid belongs to the node of the piece it stands on or hangs over: the same piece, so within a
					# hand's reach sideways (the node may be lower — a screen hangs over its sofa, a glass stands on its table)
					if p.x < d["x"] - 30 or p.x > d["x"] + d["w"] + 30:
						near_ok = false
						print("    node too far from what it moves ", art, " ", anchor, " ", p, " ", d)
			for r in [2, 3]:
				if OF._texture_for(art, anchor, r) == null:
					run_files = false
		scene.free()
	var kinds := {}
	for art in meta.keys():
		for anchor in meta[art].keys():
			var k := String(meta[art][anchor].get("kind", ""))
			kinds[k] = int(kinds.get(k, 0)) + 1
	var known := ["drawer", "door_h", "door_drop", "lid", "topple", "shift", "screen_off"]
	var unknown := []
	for k in kinds.keys():
		if not known.has(k):
			unknown.append(k)
	check(unknown.is_empty(), "every opening has a known kind (%s)" % str(kinds))
	check(int(kinds.get("screen_off", 0)) >= 6 and int(kinds.get("topple", 0)) >= 8 and int(kinds.get("door_h", 0)) >= 8 and int(kinds.get("lid", 0)) >= 3,
		"the round-45c reactions are in: screens, things that tip over, doors and lids (%s)" % str(kinds))
	check(total >= 45, "at least 45 nodes have a specific animation — the rest puff and sound (%d)" % total)
	check(all_ok, "every opening fits its 320x144 module and its sheet is frames x patch size")
	check(near_ok, "every opening belongs to a real anchor sitting on that furniture")
	check(run_files, "every opening has a look for runs 2 and 3 (they fall back to run 1 at worst)")


func _kitchen_module(apt: String, run: int) -> Node2D:
	var m: Node2D = load("res://scenes/Room_Modules/kitchen.tscn").instantiate()
	add_child(m)
	OF.attach(m, apt, run)
	return m


func _test_attach_and_open() -> void:
	WorldState.new_game()
	var m := _kitchen_module("o1", 1)
	var fridge: Sprite2D = m.get_node_or_null("Open_anchor_centre_fridge")
	var oven: Sprite2D = m.get_node_or_null("Open_anchor_centre_oven")
	check(fridge != null and oven != null, "the kitchen's fridge and oven get an opening each")
	if fridge == null or oven == null:
		return
	check(not fridge.visible and not oven.visible, "closed until searched")
	var art: Node = m.get_node("Art")
	check(fridge.get_index() == art.get_index() + 1 or fridge.get_index() == art.get_index() + 2,
		"laid just above the art, under the scavenge orbs (index %d, art %d)" % [fridge.get_index(), art.get_index()])
	WorldState.mark_anchor_searched("o1", "anchor_centre_fridge")
	get_tree().call_group("open_furniture", "on_searched", "o1", "anchor_centre_fridge")
	check(fridge.visible and not oven.visible, "searching the fridge's node opens ONLY the fridge")
	check(fridge.frame == 0, "it starts at the first frame (the door just moving)")
	await get_tree().create_timer(OF.STEP * (fridge.frames_total + 2)).timeout
	check(fridge.frame == fridge.frames_total - 1, "…and rests on the last frame (%d)" % fridge.frame)
	# another apartment's identical module is unaffected
	var m2 := _kitchen_module("o2", 1)
	check(not m2.get_node("Open_anchor_centre_fridge").visible, "another flat's fridge stays shut")
	m.queue_free(); m2.queue_free()
	await get_tree().process_frame
	# a re-entry / load: already searched → open at once, no animation
	var m3 := _kitchen_module("o1", 1)
	var f3: Sprite2D = m3.get_node("Open_anchor_centre_fridge")
	check(f3.visible and f3.frame == f3.frames_total - 1, "a searched node's furniture is already open on re-entry")
	m3.queue_free()
	# the aged run looks load their own sheets
	var m4 := _kitchen_module("o3", 3)
	var f4: Sprite2D = m4.get_node("Open_anchor_centre_fridge")
	check(f4.texture != null and f4.texture.resource_path.ends_with("_r3.png"), "run 3 uses the run-3 sheet (%s)" % f4.texture.resource_path)
	m4.queue_free()
	# a module with no openings (a variant) attaches nothing and never errors
	var v: Node2D = load("res://scenes/Room_Modules/living_room_e.tscn").instantiate()
	add_child(v)
	check(OF.attach(v, "o4", 1).is_empty(), "a module without openings gets none")
	v.queue_free()


func _interactive(module: Node, anchor: String, apt: String) -> Node2D:
	# the room gives each anchor the interactable script at build time; do the same here
	var a: Node2D = module.get_node(anchor)
	a.set_script(load("res://scripts/interactable.gd"))
	a.apartment_id = apt
	a._ready()
	return a


func _test_loot_panel_triggers() -> void:
	WorldState.new_game()
	var m := _kitchen_module("o5", 1)
	var oven: Sprite2D = m.get_node("Open_anchor_centre_oven")
	var node := _interactive(m, "anchor_centre_oven", "o5")
	var loot = load("res://scenes/loot_ui.tscn").instantiate()
	add_child(loot)
	await get_tree().process_frame
	WorldState.is_scavenge_mode = true
	WorldState.set_anchor_item("o5", "anchor_centre_oven", "")
	check(not oven.visible, "shut before anything is pressed")
	loot.open("", "anchor_centre_oven", "o5")
	check(oven.visible, "PRESSING interact (the search begins) opens the oven — not the end of the search (owner round 45c)")
	check(not WorldState.is_anchor_searched("o5", "anchor_centre_oven"), "…while the node is still unsearched")
	loot._process(loot.REVEAL_TIME + 0.1)
	check(oven.visible and WorldState.is_anchor_searched("o5", "anchor_centre_oven"), "finishing the search leaves it open (and searched)")
	loot.queue_free(); m.queue_free()
	await get_tree().process_frame


func _test_press_starts_it() -> void:
	print("[the press starts it; a search walked away from leaves it open; it is remembered]")
	WorldState.new_game()
	var m := _kitchen_module("p1", 1)
	var fridge: Sprite2D = m.get_node("Open_anchor_centre_fridge")
	var node := _interactive(m, "anchor_centre_fridge", "p1")
	var loot = load("res://scenes/loot_ui.tscn").instantiate()
	add_child(loot)
	await get_tree().process_frame
	WorldState.is_scavenge_mode = true
	loot.open("", "anchor_centre_fridge", "p1")
	check(fridge.visible and fridge.frame == 0, "the fridge door starts moving at the press (frame %d)" % fridge.frame)
	check(WorldState.opened_anchors.has("p1:anchor_centre_fridge"), "…and the node is remembered as opened")
	await get_tree().create_timer(OF.STEP * (fridge.frames_total + 1)).timeout
	check(fridge.frame == fridge.frames_total - 1, "…the door finishes swinging while the bar is still filling (frame %d)" % fridge.frame)
	loot._process(0.3)
	check(loot.is_revealing, "…the search is still running")
	loot.leave()                                       # walked away mid-search
	check(fridge.visible and not WorldState.is_anchor_searched("p1", "anchor_centre_fridge"), "walking away leaves the fridge open and the node UNSEARCHED")
	loot.queue_free(); m.queue_free()
	await get_tree().process_frame
	var m2 := _kitchen_module("p1", 1)
	check(m2.get_node("Open_anchor_centre_fridge").visible, "a re-entry shows the fridge still open")
	m2.queue_free()
	await get_tree().process_frame
	# it survives a save and a load
	WorldState.note_anchor_opened("p2", "anchor_x")
	WorldState.save_game("res://scenes/room.tscn", false)
	WorldState.opened_anchors.clear()
	WorldState.load_game()
	check(WorldState.opened_anchors.has("p2:anchor_x"), "…and comes back from a load (%s)" % str(WorldState.opened_anchors.keys()))
	# a new game forgets it
	WorldState.new_game()
	check(WorldState.opened_anchors.is_empty(), "a new game starts with nothing open")


func _test_generic_reaction() -> void:
	print("[every node reacts: a puff and a sound for what it is made of]")
	var NR = load("res://scripts/node_reaction.gd")
	var cases := {
		"anchor_bedroom_clothes_pile": "cloth", "anchor_study_book_pile": "paper", "anchor_kitchen_tins": "metal",
		"anchor_bathroom_gold_throne": "ceramic", "anchor_bedroom_desk": "wood", "anchor_bed_pillow": "cloth",
		"anchor_centre_oven": "metal", "anchor_left_bookshelf_upper": "paper", "anchor_study_paint_tins": "metal",
	}
	var bad := []
	for k in cases.keys():
		if NR.material_for(k) != cases[k]:
			bad.append("%s=%s" % [k, NR.material_for(k)])
	check(bad.is_empty(), "material_for reads what a node is made of from its name (%s)" % str(bad))
	var all_streams := true
	for mat in NR.SOUNDS.keys():
		for stem in NR.SOUNDS[mat][0]:
			if NR._stream(String(stem)) == null:
				all_streams = false
				print("    missing sound ", stem)
	for kind in NR.KIND_SOUNDS.keys():
		var path: String = String(NR.KIND_SOUNDS[kind][0])
		if path.contains("%d"):
			path = path % 0
		if not ResourceLoader.exists(path):
			all_streams = false
			print("    missing kind sound ", path)
	check(all_streams, "every material and every animation kind has its sound file")
	WorldState.new_game()
	var v: Node2D = load("res://scenes/Room_Modules/bathroom.tscn").instantiate()
	add_child(v)
	var node := _interactive(v, "anchor_bath_left", "g1")
	var before := v.get_child_count()
	node.on_search_begin()
	var puffs := 0
	var sounds := 0
	for c in v.get_children():
		if c.get_script() != null and String(c.get_script().resource_path).ends_with("dust_puff.gd"):
			puffs += 1
		if c is AudioStreamPlayer2D:
			sounds += 1
	check(puffs == 1 and sounds == 1, "a node with no specific animation puffs and sounds at the press (%d puff, %d sound)" % [puffs, sounds])
	check(WorldState.opened_anchors.has("g1:anchor_bath_left"), "…and is noted as opened")
	node.on_search_begin()
	check(v.get_child_count() == before + 2, "pressing it again (a search resumed) does not pile on another puff")
	# the gun cabinet and a burnt flat's scrap keep their own handling
	var cab := Marker2D.new()
	cab.name = WorldState.GUN_CABINET_ANCHOR
	cab.set_script(load("res://scripts/interactable.gd"))
	v.add_child(cab)
	var n_before := v.get_child_count()
	cab.on_search_begin()
	check(v.get_child_count() == n_before, "the gun cabinet makes no generic puff (its glass is its own)")
	v.queue_free()
	await get_tree().process_frame


func _module(art: String, apt: String, run: int = 1) -> Node2D:
	var m: Node2D = load("res://scenes/Room_Modules/%s.tscn" % art).instantiate()
	add_child(m)
	OF.attach(m, apt, run)
	return m


func _test_new_kinds() -> void:
	print("[the new reactions: a glass tips over, a screen goes dark, a lid lifts, a door swings]")
	WorldState.new_game()
	# a glass on a table tips over, over its own frames, the moment its node is pressed
	var m := _module("kitchen_b", "k1")
	var larder: Sprite2D = m.get_node_or_null("Open_anchor_kitchen_larder")
	check(larder != null and larder.kind == "topple" and larder.frames_total == 4, "the larder's jar is a four-frame topple")
	var node := _interactive(m, "anchor_kitchen_larder", "k1")
	check(larder != null and not larder.visible, "the jar stands until the node is pressed")
	node.on_search_begin()
	check(larder.visible and larder.frame == 0, "pressing the node starts the jar tipping")
	await get_tree().create_timer(OF.STEP * (larder.frames_total + 2)).timeout
	check(larder.frame == larder.frames_total - 1, "…and it lies on the shelf (frame %d)" % larder.frame)
	var oven: Sprite2D = m.get_node_or_null("Open_anchor_centre_oven")
	check(oven != null and oven.kind == "door_drop" and not oven.visible, "kitchen B's oven door is its own drop-down opening, shut until pressed")
	m.queue_free()
	# a screen goes dark and the live picture under it stops (living room C's struck TV)
	var c := _module("living_room_c", "k2")
	var tv: Sprite2D = c.get_node_or_null("Open_anchor_centre_sofaleft")
	check(tv != null and tv.kind == "screen_off" and tv.frames_total == 4, "the wall TV is a four-frame screen_off")
	var live: Node = null
	for a in c.get_node("Anims").get_children():
		if str(a.get_meta("kind", "")) == "tv":
			live = a
	check(live != null and live.visible, "the TV's live struck picture is running")
	var pad := _interactive(c, "anchor_centre_sofaleft", "k2")
	pad.on_search_begin()
	await get_tree().create_timer(OF.STEP * (tv.frames_total + 2)).timeout
	check(live != null and not live.visible, "…and goes dark with the screen")
	check(tv.frame == tv.frames_total - 1, "the TV rests on its dead-glass frame")
	c.queue_free()
	# a lid lifts
	var h := _module("bathroom_e", "k3")
	var hamper: Sprite2D = h.get_node_or_null("Open_anchor_bathroom_hamper")
	check(hamper != null and hamper.kind == "lid" and not hamper.visible, "the pink hamper's lid is a lid, shut until pressed")
	var hn := _interactive(h, "anchor_bathroom_hamper", "k3")
	hn.on_search_begin()
	check(hamper.visible, "pressing the hamper lifts the lid")
	h.queue_free()
	# every kind has a sound and the sound goes at the press
	var s2 := _module("study_b", "k4")
	var mon: Sprite2D = s2.get_node_or_null("Open_anchor_centre_desk")
	check(mon != null and mon.kind == "screen_off", "study B's monitor is a screen_off")
	var before := 0
	for ch in s2.get_children():
		if ch is AudioStreamPlayer2D:
			before += 1
	var mn := _interactive(s2, "anchor_centre_desk", "k4")
	mn.on_search_begin()
	var after := 0
	for ch in s2.get_children():
		if ch is AudioStreamPlayer2D:
			after += 1
	check(after == before + 1, "the switch-off click plays at the press (%d -> %d players)" % [before, after])
	s2.queue_free()
	await get_tree().process_frame


func _test_special_sounds() -> void:
	print("[round 45d: nodes with a sound of their own]")
	var NR = load("res://scripts/node_reaction.gd")
	var cases := {
		"anchor_centre_toilet": "cistern_0", "anchor_bathroom_gold_throne": "cistern_0", "anchor_wall_sink": "tap_0", "anchor_bathroom_pink_tub": "tap_0",
		"anchor_living_piano": "piano_0", "anchor_dining_grandfather_clock": "clock_0", "anchor_study_radio": "static_0", "anchor_kitchen_microwave": "beep_0",
		"anchor_centre_fridge": "fridge_0", "anchor_study_printer": "printer_0", "anchor_dining_record_player": "needle_0", "anchor_bedroom_beanbag": "pffft_0",
		"anchor_centre_sofaleft": "spring_0", "anchor_bedroom_rocking_horse": "squeak_0", "anchor_bedroom_wheelchair": "roll_0",
	}
	var bad := []
	for k in cases.keys():
		var e: Dictionary = NR.special_for(k)
		if e.is_empty() or not String(e["sounds"][0]).begins_with(String(cases[k]).split("_")[0]):
			bad.append(k)
	check(bad.is_empty(), "special_for maps names to their own sound (%s)" % str(bad))
	check(NR.special_for("anchor_bathroom_toilet_rolls").is_empty() and NR.special_for("anchor_right_sinkcupboard").is_empty(),
		"…but not toilet rolls or a sink CUPBOARD")
	var missing := []
	for e in NR.SPECIAL:
		for stem in e["sounds"]:
			if NR._stream(String(stem)) == null:
				missing.append(stem)
	check(missing.is_empty(), "every special sound file exists (%s)" % str(missing))
	# a toilet node (no specific animation) plays its cistern in place of the material sound, with no dust
	WorldState.new_game()
	var b: Node2D = load("res://scenes/Room_Modules/bathroom.tscn").instantiate()
	add_child(b)
	var toilet := _interactive(b, "anchor_centre_toilet", "s1")
	toilet.on_search_begin()
	var players := 0
	var puffs := 0
	for c in b.get_children():
		if c is AudioStreamPlayer2D:
			players += 1
		if c.get_script() != null and String(c.get_script().resource_path).ends_with("dust_puff.gd"):
			puffs += 1
	check(players == 1 and puffs == 0, "a toilet makes ONE sound (its cistern) and no dust (%d sounds, %d puffs)" % [players, puffs])
	b.queue_free()
	# a microwave opens (door sound) AND beeps
	var k: Node2D = _module("kitchen_d", "s2")
	var mw := _interactive(k, "anchor_kitchen_microwave", "s2")
	mw.on_search_begin()
	var n2 := 0
	for c in k.get_children():
		if c is AudioStreamPlayer2D:
			n2 += 1
	check(n2 == 2, "a microwave's door AND its beep sound at the press (%d players)" % n2)
	k.queue_free()
	await get_tree().process_frame


func _test_critters() -> void:
	print("[round 45d: something small bolts out of a node now and then]")
	WorldState.new_game()
	var NR = load("res://scripts/node_reaction.gd")
	# eligibility is by NAME, the roll is seeded: the same node answers the same way every time and about CRITTER_CHANCE of them are due one
	var hits := 0
	var total := 0
	var again_same := true
	for i in range(400):
		var apt := "c%d" % i
		var a: String = NR.critter_for(apt, "anchor_bedroom_clothes_pile")
		total += 1
		if a != "":
			hits += 1
		if NR.critter_for(apt, "anchor_bedroom_clothes_pile") != a:
			again_same = false
	check(again_same, "the same node answers the same way every time (seeded, never re-rolled)")
	check(hits > total * 0.07 and hits < total * 0.24, "about %d%% of piles are due a rat (%d of %d)" % [int(NR.CRITTER_CHANCE * 100.0), hits, total])
	check(NR.critter_for("c1", "anchor_study_desk_drawer") == "" and NR.critter_for("c1", "anchor_living_piano") == "", "a drawer or a piano never hides one")
	var kinds := {}
	for i in range(400):
		for nm in ["anchor_bedroom_clothes_pile", "anchor_kitchen_tins", "anchor_bedroom_wardrobe"]:
			var k: String = NR.critter_for("c%d" % i, nm)
			if k != "":
				kinds[k] = true
	check(kinds.has("rat") and kinds.has("roach") and kinds.has("moth"), "piles give rats, food and damp give roaches, a wardrobe gives moths (%s)" % str(kinds.keys()))
	# a due node really lets one out at the press, and it is harmless decoration that frees itself
	var apt := ""
	for i in range(400):
		if NR.critter_for("d%d" % i, "anchor_bedroom_clothes_pile") == "rat":
			apt = "d%d" % i
			break
	check(apt != "", "found a flat whose clothes pile hides a rat")
	var m: Node2D = _module("bedroom_b", apt)
	var node := _interactive(m, "anchor_bedroom_clothes_pile", apt)
	node.on_search_begin()
	var crit: Node2D = null
	for c in m.get_children():
		if c is NodeCritter:
			crit = c
	check(crit != null and crit.kind == "rat", "pressing the pile lets a rat out")
	if crit != null:
		check(not (crit is CollisionObject2D) and not crit.is_in_group("zombie") and not crit.is_in_group("survivor_prey"),
			"…which has no body and is in no enemy group (it cannot block, bite or be bitten)")
		var x0 := crit.position.x
		await get_tree().create_timer(0.5).timeout
		check(is_instance_valid(crit) and absf(crit.position.x - x0) > 20.0, "…it runs (moved %.0f px)" % absf(crit.position.x - x0))
		await get_tree().create_timer(1.6).timeout
		check(not is_instance_valid(crit), "…and is gone again by itself")
	node.on_search_begin()
	var n2 := 0
	for c in m.get_children():
		if c is NodeCritter:
			n2 += 1
	check(n2 == 0, "pressing the same node again lets nothing else out")
	m.queue_free()
	await get_tree().process_frame


func _solid_in_cell(img: Image, cell: int, cells: int) -> int:
	var cw := img.get_width() / cells
	var n := 0
	for y in range(img.get_height()):
		for x in range(cell * cw, (cell + 1) * cw):
			if img.get_pixel(x, y).a > 0.5:
				n += 1
	return n


func _test_toilet_roll() -> void:
	print("[round 48k: the toilet roll is an object, and its sheet comes off when it is searched]")
	var NR = load("res://scripts/node_reaction.gd")
	check(NR.KIND_SOUNDS.has("unroll") and ResourceLoader.exists(String(NR.KIND_SOUNDS["unroll"][0])), "the unrolling has a sound of its own")
	check(NR.material_for("anchor_bathroom_toilet_rolls") == "paper", "a toilet-roll node is paper (not the toilet's ceramic)")
	var rec: Dictionary = FurniturePlanner.piece("toilet")
	var op = rec.get("opens", null)
	check(op != null and String(op["kind"]) == "unroll" and String(op["anchor"]) == "toilet_rolls", "the planned toilet's roll opens with the `unroll` animation")
	var grown: Array = []
	var no_node: Array = []
	for vid in ["white", "avocado", "pink"]:
		var v: Dictionary = rec["variants"][vid]
		var has_node := false
		for a in v["anchors"]:
			if String(a["name"]) == "toilet_rolls":
				has_node = true
		if not has_node:
			no_node.append(vid)
		var sp: Dictionary = v["sprites"][v["sprites"].size() / 2]
		var tex := RoomFurniture.texture("open/" + String(sp.get("open_file", "")))
		if tex == null:
			grown.append(vid + " (no strip)")
			continue
		var img := tex.get_image()
		var cells := 1 + int(op["frames"])
		var first := _solid_in_cell(img, 0, cells)
		var last := _solid_in_cell(img, cells - 1, cells)
		var mid := _solid_in_cell(img, cells / 2, cells)
		if not (last > mid and mid > first):
			grown.append("%s %d/%d/%d" % [vid, first, mid, last])
	check(no_node.is_empty(), "every toilet that hangs a roll gives it a node (%s without)" % str(no_node))
	check(grown.is_empty(), "…and the sheet gets LONGER frame by frame (more drawn paper from the first cell to the last) %s" % str(grown))
	for vid in ["gold", "wet"]:
		var has := false
		for a in rec["variants"][vid]["anchors"]:
			if String(a["name"]) == "toilet_rolls":
				has = true
		check(not has, "the %s toilet hangs no roll, so it has no roll node" % vid)
	# a spare roll stands ON the cistern (a surface), never anywhere else
	var spare: Dictionary = FurniturePlanner.piece("toilet_roll_spare")
	check(spare["plane"] == "top" and "cistern" in spare["on"] and FurniturePlanner.home_issue(spare, "bathroom") == "" and FurniturePlanner.home_issue(spare, "kitchen") != "",
		"a spare roll is a surface piece that stands on a cistern, kept in a bathroom only")
	var slot_ok := false
	for sl in rec["variants"]["white"]["slots"]:
		if bool(sl.get("top", false)) and "cistern" in sl["kinds"]:
			slot_ok = true
	check(slot_ok, "the toilet's cistern is a surface (a slot that takes small things)")
	# a REAL planned bathroom: the roll's node exists, starts closed, and pressing interact unrolls it (the overlay plays through every frame and stays)
	var found := false
	for seed_ in range(1, 60):
		var pl := FurniturePlanner.plan("bathroom", "tub", seed_, {"window": "left"})
		var has_node := false
		for a in pl["anchors"]:
			if String(a["name"]) == "anchor_bathroom_toilet_rolls":
				has_node = true
		if not has_node:
			continue
		var module := Node2D.new()
		add_child(module)
		WorldState.new_game()
		var made: Dictionary = RoomFurniture.build(module, pl, "9996", 1)
		var ov: Sprite2D = null
		for o in made["opens"]:
			if String(o.name) == "Open_anchor_bathroom_toilet_rolls":
				ov = o
		check(ov != null and ov.kind == "unroll" and not ov.visible, "a planned bathroom's toilet roll starts closed, as an `unroll` overlay (seed %d)" % seed_)
		if ov != null:
			ov.play()
			await get_tree().create_timer(float(ov.frames_total) * 0.11 + 0.3).timeout
			check(ov.visible and ov.frame == ov.frames_total - 1, "…pressing interact on it plays the sheet off the roll through all %d frames and leaves it out" % ov.frames_total)
		module.queue_free()
		found = true
		break
	check(found, "some planned tub bathroom carries a hanging roll to test")
