extends Node

# BURNT-OUT APARTMENTS (owner round 34: "the burned out apartment looked mostly normal… a text box with the player
# saying the apartment is burned out, everything here is likely scrap… we should [not] need to search those nodes —
# say what it is"): a CHARRED flat shows burnt module art, says so once, and its scrap nodes are identified and taken
# on the spot; nodes with nothing are gone.
# Run: godot --headless res://tests/burnt_apartment_test.tscn

const ROOM_TYPES := ["living_room", "bedroom", "kitchen", "bathroom", "study", "dining_room"]
const VARIANTS := ["", "_b", "_c", "_d", "_e"]
var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== burnt apartment test ===")
	_test_art_files()
	_test_apply()
	await _test_charred_room()
	await _test_normal_room()
	_test_intro_line()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _mean_lum(img: Image) -> float:
	var tot := 0.0
	var n := 0
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			var c := img.get_pixel(x, y)
			if c.a > 0.5:
				tot += c.r * 0.299 + c.g * 0.587 + c.b * 0.114
				n += 1
	return tot / maxf(1.0, float(n))


func _test_art_files() -> void:
	var missing := 0
	var not_darker := 0
	var bad_size := 0
	var ext_missing := 0
	var total := 0
	for t in ROOM_TYPES:
		for v in VARIANTS:
			var name: String = t + v
			total += 1
			var src: String = "res://assets/rooms/%s_r3.png" % name
			var burnt: String = "res://assets/rooms/%s_burnt.png" % name
			if not ResourceLoader.exists(burnt):
				missing += 1
				continue
			var b: Image = (load(burnt) as Texture2D).get_image()
			var a: Image = (load(src) as Texture2D).get_image()
			if b.get_width() != 320 or b.get_height() != 144:
				bad_size += 1
			if _mean_lum(b) > _mean_lum(a) * 0.75:
				not_darker += 1
				print("    not burnt enough: ", name, " ", _mean_lum(b), " vs ", _mean_lum(a))
			if not ResourceLoader.exists("res://assets/rooms/%s_burnt_floor_ext.png" % name):
				ext_missing += 1
	check(total == 30 and missing == 0, "every one of the 30 module variants has burnt art (%d missing)" % missing)
	check(bad_size == 0, "each is the module's 320x144")
	check(not_darker == 0, "each is clearly darker than its run-3 look (a charred room can't read as normal)")
	check(ext_missing == 0, "each has the burnt floor strip the end walls read")
	check(ResourceLoader.exists("res://assets/rooms/balcony_burnt.png"), "the balcony has burnt art too")


func _test_apply() -> void:
	var m: Node2D = load("res://scenes/Room_Modules/study.tscn").instantiate()
	add_child(m)
	var before: String = (m.get_node("Art") as Sprite2D).texture.resource_path
	load("res://scripts/room.gd").apply_burnt_art(m)
	var art: Sprite2D = m.get_node("Art")
	check(art.texture.resource_path.ends_with("study_burnt.png"), "apply_burnt_art swaps the module art (%s → %s)" % [before.get_file(), art.texture.resource_path.get_file()])
	var strip = m.get_node_or_null("StripArt")
	check(strip == null or (strip as Sprite2D).texture.resource_path.ends_with("_burnt_strip.png"), "…and the balcony-strip furniture")
	m.queue_free()
	# run-3 art swaps too (the charred stage is a run-3 thing)
	var m2: Node2D = load("res://scenes/Room_Modules/kitchen_d.tscn").instantiate()
	add_child(m2)
	load("res://scripts/room.gd").apply_run_art(m2, 3)
	load("res://scripts/room.gd").apply_burnt_art(m2)
	check((m2.get_node("Art") as Sprite2D).texture.resource_path.ends_with("kitchen_d_burnt.png"), "a run-3 module goes to its burnt art")
	m2.queue_free()


func _charred_apartment(f: int) -> String:
	WorldState.dev_fire_origin = f
	WorldState.dev_hazard_mode = WorldState.DEV_HAZARD_FIRE3
	for i in range(1, 6):
		if WorldState.apartment_fire_stage(f, i) == WorldState.FIRE_CHARRED:
			return str(f) + "0" + str(i)
	return ""


func _test_charred_room() -> void:
	WorldState.new_game()
	WorldState.is_first_run = false
	WorldState.master_seed = 4242
	WorldState.current_run = 3
	var f := 12
	var apt := _charred_apartment(f)
	check(apt != "", "found a charred apartment (%s)" % apt)
	if apt == "":
		return
	WorldState.current_floor = f
	WorldState.current_apartment_id = apt
	WorldState.spawn_source = ""
	var room = load("res://scenes/room.tscn").instantiate()
	add_child(room)
	for i in range(6):
		await get_tree().process_frame
	var player = get_tree().get_first_node_in_group("player")      # the room's own player
	var burnt_mods := 0
	var anims := 0
	for module in get_tree().get_nodes_in_group("room_module"):
		var art: Sprite2D = module.get_node("Art")
		if art.texture.resource_path.contains("_burnt"):
			burnt_mods += 1
		if module.get_node_or_null("Anims") != null and not module.get_node("Anims").is_queued_for_deletion():
			anims += 1
	check(burnt_mods == 3, "all three modules show their BURNT art (%d of 3)" % burnt_mods)
	check(anims == 0, "no live details (a dripping fridge, a humming TV) survive in the ruin")
	check(WorldState.charred_intro_seen.has(apt + ":3"), "the player said the flat is burned out")
	var ruin: Array = []
	var live_other := 0
	for module in get_tree().get_nodes_in_group("room_module"):
		for c in module.get_children():
			if c is Marker2D and c.has_method("try_interact") and c.visible:
				if c.has_meta("ruin_scrap"):
					ruin.append(c)
				else:
					live_other += 1
	check(not ruin.is_empty(), "the ruin holds scrap nodes (%d)" % ruin.size())
	check(live_other == 0, "and nothing else: a node with nothing in it is gone (%d left)" % live_other)
	var all_scrap := true
	for n in ruin:
		all_scrap = all_scrap and WorldState.get_anchor_item(apt, n.name) == "037" and WorldState.get_anchor_amount(apt, n.name) > 0
	check(all_scrap, "every one holds a scrap bag with an amount, known up front")
	if ruin.is_empty():
		return
	# approach: it says what it is, with no search
	var node: Node2D = ruin[0]
	for n in ruin:
		if n.back_spot == null:          # a set-back node is only in reach from its own step-up spot; test one on the walking line
			node = n
			break
	check(node.back_spot == null, "a ruin node on the walking line to test with")
	WorldState.is_scavenge_mode = true
	player.global_position = node.global_position + Vector2(0, 20)
	for i in range(6):
		await get_tree().physics_frame
		await get_tree().process_frame
	var said := ""
	for id in HUD._world_prompts:
		var e = HUD._world_prompts[id]
		if e["panel"].visible and String(e["label"].text).begins_with("Scrap"):
			said = String(e["label"].text)
	check(said != "", "up close the node says what it is: %s" % said)
	# taking it: scrap goes up at once, the node is spent, it was never "searched" by the panel
	var amount: int = WorldState.get_anchor_amount(apt, node.name)
	var before: int = WorldState.scrap
	WorldState.interaction_handled = false
	node.try_interact()
	check(WorldState.scrap == before + amount and amount > 0, "one press takes it: scrap +%d (%d → %d)" % [amount, before, WorldState.scrap])
	check(not node.visible and not node.has_meta("ruin_scrap"), "the node is spent and gone")
	check(not WorldState.loot_open, "no loot panel, no search")
	check(WorldState.get_anchor_item(apt, node.name) == "", "the record is cleared (no second helping on re-entry)")
	room.queue_free()
	await get_tree().process_frame
	WorldState.dev_hazard_mode = WorldState.DEV_HAZARD_NONE
	WorldState.dev_fire_origin = -1


func _test_normal_room() -> void:
	WorldState.new_game()
	WorldState.is_first_run = false
	WorldState.master_seed = 4242
	WorldState.current_run = 1
	var apt := "1205"
	WorldState.current_floor = 12
	WorldState.current_apartment_id = apt
	WorldState.spawn_source = ""
	var room = load("res://scenes/room.tscn").instantiate()
	add_child(room)
	for i in range(6):
		await get_tree().process_frame
	var burnt := 0
	var ruin := 0
	for module in get_tree().get_nodes_in_group("room_module"):
		if (module.get_node("Art") as Sprite2D).texture.resource_path.contains("_burnt"):
			burnt += 1
		for c in module.get_children():
			if c is Marker2D and c.has_meta("ruin_scrap"):
				ruin += 1
	check(burnt == 0 and ruin == 0, "an ordinary flat is untouched (burnt %d, ruin nodes %d)" % [burnt, ruin])
	check(not WorldState.charred_intro_seen.has(apt + ":1"), "and says nothing about a fire")
	room.queue_free()
	await get_tree().process_frame


func _test_intro_line() -> void:
	WorldState.new_game()
	WorldState.current_run = 3
	check(WorldState.take_charred_intro("1203"), "the first entry says the line")
	check(not WorldState.take_charred_intro("1203"), "a second entry the same run says nothing")
	check(WorldState.take_charred_intro("1204"), "a different burnt flat says it again")
	WorldState.current_run = 2
	check(WorldState.take_charred_intro("1203"), "and a new run does too")
	var line := WorldState.charred_intro_line("1203")
	check(line.to_lower().contains("scrap"), "the line sets the expectation: scrap (%s)" % line)
