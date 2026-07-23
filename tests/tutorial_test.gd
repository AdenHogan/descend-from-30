extends Node

# Headless test for the editable blood-text tutorial component + the scene
# changes that make Floor 30 editable (baked hints, pause menu autoloaded).
# Run:  godot --headless res://tests/tutorial_test.tscn

var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== tutorial / blood-text test ===")
	_test_blood_text_component()
	_test_hallway_baked_hints()
	_test_pause_menu_autoload()
	_test_tutorial_manager()
	await _test_opener()
	await _test_barricade_beat()
	await _test_3005_bullets()
	await _test_3003_scripted_content()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _test_blood_text_component() -> void:
	print("[blood text component]")
	var bt = load("res://scenes/blood_text.tscn").instantiate()
	add_child(bt)
	check(bt is Node2D, "blood text is a Node2D you can place")
	check("text" in bt and "font_size" in bt, "exposes editable text + font_size")
	bt.text = "TEST SCRAWL"
	check(bt.text == "TEST SCRAWL", "text setter works")
	check(bt._get_font() is Font, "loads the pixel font for drawing")
	check(bt.z_index == 1, "renders on the foreground layer")
	bt.queue_free()


func _test_hallway_baked_hints() -> void:
	print("[hallway baked hints]")
	var f = FileAccess.open("res://scenes/hallway.tscn", FileAccess.READ)
	var src = f.get_as_text()
	f.close()
	check(src.count("tutorial_blood") >= 5, "several hints baked into hallway.tscn (editable)")
	check(src.contains("scenes/blood_text.tscn"), "hallway references the blood_text scene")
	# Pause menu must be OUT of the world scenes so the editor isn't blanketed.
	check(not src.contains("pause_menu.tscn"), "pause menu removed from hallway.tscn")


func _test_3005_bullets() -> void:
	print("[3005 guaranteed bullets, Floor-29 weapon]")
	WorldState.new_game()  # is_first_run = true
	WorldState.current_floor = 30
	WorldState.current_apartment_id = "3005"
	WorldState.spawn_source = "door"
	WorldState.exit_spawn_x = 316.0
	WorldState.seed_floor_door_states(30)
	var room = load("res://scenes/room.tscn").instantiate()
	add_child(room)
	for i in range(8):
		await get_tree().process_frame
	var has_bullets := false
	var has_weapon := false
	for k in WorldState.anchor_items:
		if String(k).begins_with("3005:"):
			var it = WorldState.anchor_items[k]
			if it == "016":
				has_bullets = true
			if ItemData.get_item(it).get("is_weapon", false):
				has_weapon = true
	check(has_bullets, "Bullets (016) are guaranteed in 3005 for the first run")
	check(not has_weapon, "NO weapon in 3005 (would let the player force 3004)")
	room.queue_free()
	await get_tree().process_frame

	# First Floor-29 apartment (tutorial run): a melee weapon is guaranteed once.
	WorldState.current_floor = 29
	WorldState.current_apartment_id = "2905"
	WorldState.seed_floor_door_states(29)
	check(not WorldState.tutorial_f29_weapon_granted, "f29 weapon not yet granted")
	var r29 = load("res://scenes/room.tscn").instantiate()
	add_child(r29)
	for i in range(8):
		await get_tree().process_frame
	var f29_weapon := false
	for k in WorldState.anchor_items:
		if String(k).begins_with("2905:") and ItemData.get_item(WorldState.anchor_items[k]).get("is_weapon", false):
			f29_weapon = true
	check(f29_weapon, "first Floor-29 apartment guarantees a melee weapon")
	check(WorldState.tutorial_f29_weapon_granted, "the once-only flag is set")
	r29.queue_free()
	await get_tree().process_frame


func _test_3003_scripted_content() -> void:
	print("[3003 scripted content]")
	WorldState.new_game()  # is_first_run = true
	WorldState.current_floor = 30
	WorldState.current_apartment_id = "3003"
	WorldState.spawn_source = "door"
	WorldState.exit_spawn_x = 570.0
	WorldState.seed_floor_door_states(30)
	var room = load("res://scenes/room.tscn").instantiate()
	add_child(room)
	for i in range(8):
		await get_tree().process_frame
	# The three scripted nodes are seeded (junk / bandages / golf club). The
	# 3002 key is NOT on an anchor any more — the neighbour drops it on death.
	var vals: Array = []
	for k in WorldState.anchor_items:
		if String(k).begins_with("3003:"):
			vals.append(WorldState.anchor_items[k])
	check("012" in vals, "golf club is one of 3003's nodes (%s)" % str(vals))
	check("006" in vals, "bandages are one of 3003's nodes")
	check("025" in vals, "a junk item is the panic node")
	check(not ("KEY:3002" in vals), "3002 key is NOT on an anchor (zombie yields it)")
	check(vals.size() == 3, "exactly three scavenge nodes in 3003 (%d)" % vals.size())
	# The scripted neighbour: at the BACK, frozen, and the 3002-key carrier.
	var tz = room.tut_zombie
	check(tz != null and is_instance_valid(tz), "the scripted neighbour spawned")
	if tz != null and is_instance_valid(tz):
		check(tz.tutorial_scripted, "neighbour is in scripted (no-RNG) mode")
		check(tz.tutorial_frozen, "neighbour starts frozen until the player nears")
		check(tz.drops_key and tz.key_target_apartment == "3002", "neighbour yields the 3002 key on death")
		var zx = tz.global_position.x
		check(absf(zx - 1035.0) < 10.0 or absf(zx - 155.0) < 10.0,
			"neighbour stands almost at the back wall (x=%.0f)" % zx)
		# Node order along the retreat path: junk is met first (nearest her),
		# the golf club last (nearest the entrance).
		var junk_x := -1.0
		var club_x := -1.0
		for anchor in room.tut_nodes:
			match String(anchor.get_meta("tutorial_tag", "")):
				"025": junk_x = anchor.global_position.x
				"012": club_x = anchor.global_position.x
		check(junk_x >= 0.0 and club_x >= 0.0 and absf(zx - junk_x) < absf(zx - club_x),
			"junk node sits nearer the encounter than the club (junk %.0f, club %.0f)" % [junk_x, club_x])
	check(room.tut_step == room.TutStep.INTRO, "encounter armed at INTRO")
	# The nodes stay hidden until the scripted reveal.
	var hidden_ok := true
	for anchor in room.tut_nodes:
		if anchor.visible:
			hidden_ok = false
	check(hidden_ok and room.tut_nodes.size() == 3, "the three nodes are hidden pre-reveal")
	# Door states match the GDD's tutorial floor.
	check(WorldState.get_door_state("3003") == WorldState.DoorState.OPEN, "3003 open")
	check(WorldState.get_door_state("3002") == WorldState.DoorState.SHUT_LOCKED, "3002 locked (needs the key)")
	check(WorldState.get_door_state("3004") == WorldState.DoorState.BARRICADED_LOCKED, "3004 barricaded+locked")
	check(WorldState.get_door_state("3005") == WorldState.DoorState.OPEN, "3005 open")
	room.queue_free()


func _test_tutorial_manager() -> void:
	print("[tutorial manager]")
	var tm = get_node_or_null("/root/TutorialManager")
	check(tm != null, "TutorialManager is an autoload singleton")
	if tm == null:
		return
	# Staged stairs gate along the mandatory path: key → apts → choice → open.
	WorldState.new_game()
	WorldState.current_floor = 30
	WorldState.seed_floor_door_states(30)
	check(tm.stair_stage() == "key" and tm.stairs_locked(), "stage 'key' while the neighbour is up")
	WorldState.killed_zombies["3003:tutorial"] = {"floor": 30}
	check(tm.stair_stage() == "apts" and tm.stairs_locked(), "stage 'apts' with the 3004 barricade standing")
	WorldState.set_door_state("3004", WorldState.DoorState.SHUT_LOCKED)
	check(tm.stair_stage() == "choice" and tm.stairs_locked(), "stage 'choice' once the barricade is down")
	WorldState.killed_zombies["30hall:tutorial"] = {"floor": 30}
	check(tm.stair_stage() == "open" and not tm.stairs_locked(), "killing the corridor zombie opens descent")
	WorldState.killed_zombies.erase("30hall:tutorial")
	WorldState.set_door_state("3004", WorldState.DoorState.OPEN)
	check(tm.stair_stage() == "open", "forcing into 3004 also opens descent")
	check(not tm.stair_block_info().is_empty() == tm.stairs_locked(), "block info matches the lock state")
	WorldState.killed_zombies.erase("3003:tutorial")
	WorldState.is_first_run = false
	check(not tm.stairs_locked(), "gate is inert after the first run")
	WorldState.is_first_run = true


func _test_opener() -> void:
	print("[first-run opener]")
	WorldState.new_game()
	check(not WorldState.opener_seen, "opener unseen after new_game")
	# All opener lines exist to edit.
	var keys_ok := true
	for k in ["opener_1", "opener_2", "opener_3", "opener_4", "opener_5"]:
		if not TutorialManager.LINES.has(k):
			keys_ok = false
	check(keys_ok, "all opener_* lines are in TutorialManager.LINES")
	var intro = preload("res://scripts/intro_overlay.gd").new()
	add_child(intro)
	await get_tree().process_frame
	check(get_tree().paused, "opener pauses the game")
	check(intro.label.text == TutorialManager.LINES["opener_1"], "first opener line shows")
	for i in range(6):
		intro._advance()
	check(intro.fading, "opener fades out after the last line")
	intro._process(1.0)  # drive the fade to completion
	await get_tree().process_frame
	check(not get_tree().paused, "opener unpauses when done")
	get_tree().paused = false  # defensive: never leave the test tree paused
	if is_instance_valid(intro):
		intro.queue_free()
	await get_tree().process_frame


func _test_barricade_beat() -> void:
	print("[hallway barricade beat]")
	WorldState.new_game()
	WorldState.opener_seen = true  # skip the cold-open (it would pause the test tree)
	WorldState.current_floor = 30
	WorldState.seed_floor_door_states(30)
	WorldState.killed_zombies["3003:tutorial"] = {"floor": 30}  # 3003 cleared
	# Barricade work has begun — the noise-drawn zombie must walk in and hold.
	WorldState.barricade_progress["3004"] = 0.4
	var hallway = load("res://scenes/hallway.tscn").instantiate()
	add_child(hallway)
	for i in range(8):
		await get_tree().process_frame
	var hz = hallway.hall_zombie
	check(hz != null and is_instance_valid(hz), "corridor zombie spawns once barricade work starts")
	if hz != null and is_instance_valid(hz):
		check(hz.tutorial_scripted, "corridor zombie is scripted (2-hit, no RNG)")
		check(hz.tutorial_frozen, "it holds (frozen) while the barricade still stands")
		check(hz.tutorial_hold_x > 0.0, "it walks to a hold point, not straight at the player")
		check(hz.spawn_key == "30hall:tutorial", "fixed spawn key (no respawn after the kill)")
		check(hz.tutorial_cash_drop > 0, "fighting it still pays out (drops Bank Notes)")
	hallway.queue_free()
	WorldState.barricade_progress.erase("3004")
	await get_tree().process_frame


func _test_pause_menu_autoload() -> void:
	print("[pause menu autoload]")
	# The autoload node exists globally now (not embedded per scene).
	var pm = get_node_or_null("/root/PauseMenu")
	check(pm != null, "PauseMenu is an autoload singleton")
	for scene in ["building_floors", "lobby", "room"]:
		var f = FileAccess.open("res://scenes/%s.tscn" % scene, FileAccess.READ)
		var src = f.get_as_text()
		f.close()
		check(not src.contains("pause_menu.tscn"), "pause menu removed from %s.tscn" % scene)
