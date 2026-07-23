extends Node

# Headless regression test for left-click-to-move: a synthesized LMB press
# must reach the player's _unhandled_input (nothing may swallow it) and set a
# move target — in the hallway and inside a room, tutorial active or not.
# Run:  godot --headless res://tests/click_move_test.tscn

var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== click-to-move test ===")
	await _test_hallway_click()
	await _test_room_click()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _click(at: Vector2 = Vector2(300, 300)) -> void:
	# Prime the viewport's cached mouse position first — headless has no real
	# cursor, and _is_mouse_over_hud()/_mouse_world_pos() read the cache.
	var mv = InputEventMouseMotion.new()
	mv.position = at
	get_viewport().push_input(mv)
	var ev = InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = at
	get_viewport().push_input(ev)
	var up = InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = at
	get_viewport().push_input(up)


func _test_hallway_click() -> void:
	print("[hallway: LMB sets a move target]")
	WorldState.new_game()
	WorldState.opener_seen = true  # skip the cold-open (would pause the test tree)
	WorldState.current_floor = 30
	WorldState.seed_floor_door_states(30)
	var hallway = load("res://scenes/hallway.tscn").instantiate()
	add_child(hallway)
	for i in range(5):
		await get_tree().process_frame
	var player = get_tree().get_first_node_in_group("player")
	check(player != null, "player exists in hallway")
	if player == null:
		hallway.queue_free()
		return
	# Scavenge mode (LMB is attack in combat by default — that's by design).
	WorldState.is_scavenge_mode = true
	player.has_move_target = false
	_click()
	# push_input is synchronous — check before physics can "arrive" and clear it.
	check(player.has_move_target, "LMB click reaches the player (scavenge, no dialogue)")
	# A dialogue line must NOT block world clicks — including a click that lands
	# directly ON the dialogue panel (upper-centre), the real playtest failure.
	player._clear_move_target()
	HUD.show_dialogue("A fairly long tutorial line that fills the whole dialogue panel width so a click lands on it.")
	await get_tree().process_frame
	_click(Vector2(576, 128))  # over the dialogue panel
	check(player.has_move_target, "LMB works even clicking ON the dialogue panel")
	HUD.hide_dialogue()
	hallway.queue_free()
	await get_tree().process_frame


func _test_room_click() -> void:
	print("[room 3003: LMB sets a move target]")
	WorldState.current_apartment_id = "3003"
	WorldState.spawn_source = "door"
	WorldState.exit_spawn_x = 570.0
	var room = load("res://scenes/room.tscn").instantiate()
	add_child(room)
	for i in range(8):
		await get_tree().process_frame
	var player = get_tree().get_first_node_in_group("player")
	check(player != null, "player exists in 3003")
	if player == null:
		room.queue_free()
		return
	WorldState.is_scavenge_mode = true
	player.has_move_target = false
	_click()
	check(player.has_move_target, "LMB ground click walks (tutorial room, nodes hidden)")
	# After the reveal the nodes are clickable interactables.
	room._reveal_tutorial_nodes()
	check(room.interactables.size() >= 3, "revealed nodes joined interactables (%d)" % room.interactables.size())
	var all_visible = true
	for anchor in room.tut_nodes:
		if not anchor.visible or not anchor.is_processing():
			all_visible = false
	check(all_visible, "revealed nodes are visible + processing (clickable)")
	room.queue_free()
	await get_tree().process_frame
