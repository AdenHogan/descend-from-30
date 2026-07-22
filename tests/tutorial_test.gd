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
	var vals: Array = []
	for k in WorldState.anchor_items:
		if String(k).begins_with("3003:"):
			vals.append(WorldState.anchor_items[k])
	check("012" in vals, "golf club guaranteed in 3003 (%s)" % str(vals))
	check("006" in vals, "bandages guaranteed in 3003")
	check("KEY:3002" in vals, "key to 3002 guaranteed in 3003 (unlocks the next door)")
	var zombies := 0
	for z in get_tree().get_nodes_in_group("zombie"):
		if not z.is_dead:
			zombies += 1
	check(zombies >= 1, "a zombie spawns inside 3003 (%d)" % zombies)
	# Door states match the GDD's tutorial floor.
	check(WorldState.get_door_state("3003") == WorldState.DoorState.OPEN, "3003 open")
	check(WorldState.get_door_state("3002") == WorldState.DoorState.SHUT_LOCKED, "3002 locked (needs the key)")
	check(WorldState.get_door_state("3004") == WorldState.DoorState.BARRICADED_LOCKED, "3004 barricaded+locked")
	check(WorldState.get_door_state("3005") == WorldState.DoorState.OPEN, "3005 open")
	room.queue_free()


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
