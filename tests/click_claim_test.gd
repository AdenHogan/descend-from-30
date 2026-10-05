extends Node

# Headless test: ONE click does ONE thing (owner round 36e: "clicking a dropped / enemy drop item too close to a stairwell will
# result in the item being picked up and traversal of the stairwell happening in the same click"). A pickup that takes a click
# marks it handled, so a stairwell / door behind it (which act on the unhandled click) never also fire. Run:
#   godot --headless res://tests/click_claim_test.tscn

var failures: int = 0
var unhandled_clicks: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _unhandled_input(event: InputEvent) -> void:
	# stands in for the stairwell / door / click-to-move, all of which act on the click only if nothing claimed it
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		unhandled_clicks += 1


func _ready() -> void:
	print("=== click claim test ===")
	await _test_drop_claims_click()
	await _test_other_pickups_claim_click()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _corridor() -> Node:
	WorldState.new_game()
	WorldState.is_first_run = false
	WorldState.tutorial_completed = true
	WorldState.god_mode = false
	WorldState.current_floor = 12
	WorldState.seed_floor_door_states(12)
	var bf = load("res://scenes/building_floors.tscn").instantiate()
	add_child(bf)
	await get_tree().physics_frame
	for z in get_tree().get_nodes_in_group("zombie"):
		if bf.is_ancestor_of(z):
			z.free()
	return bf


## Click at a WORLD point, as the camera sees it.
func _click_world(p: Node, world: Vector2) -> void:
	var cam: Camera2D = p.get_node("Camera2D")
	var vp: Viewport = get_viewport()
	var screen: Vector2 = (world - cam.get_screen_center_position()) * cam.zoom + vp.get_visible_rect().size / 2.0
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = vp.get_final_transform() * screen
		vp.push_input(ev)
	await get_tree().process_frame
	await get_tree().process_frame


func _test_drop_claims_click() -> void:
	print("[a click on a drop is the drop's alone]")
	var bf = await _corridor()
	var p = bf.get_node("Player")
	p.global_position = Vector2(640, 386)
	await get_tree().physics_frame
	var drop = load("res://scenes/world_drop.tscn").instantiate()
	drop.item_id = "005"
	drop.global_position = Vector2(655, 412)
	bf.add_child(drop)
	for i in range(4):
		await get_tree().physics_frame
	check(drop.player_nearby, "the player is in reach of the drop")
	var before: int = WorldState.inventory.size()
	unhandled_clicks = 0
	await _click_world(p, drop.global_position)
	check(WorldState.inventory.size() == before + 1, "the click picked the item up")
	check(unhandled_clicks == 0, "…and nothing behind it (a stairwell, a door, click-to-move) got the same click (%d)" % unhandled_clicks)
	# control: a click on empty floor is still anyone's
	unhandled_clicks = 0
	await _click_world(p, Vector2(900, 412))
	check(unhandled_clicks == 1, "a click on bare floor still reaches the world (%d)" % unhandled_clicks)
	WorldState.inventory.clear()
	bf.free()
	await get_tree().process_frame


func _test_other_pickups_claim_click() -> void:
	# Every click-to-take thing claims its click: the player's own body, the backpack on the floor, a body in a corridor.
	print("[the other click-to-take things claim their click too]")
	for f in ["res://scripts/world_drop.gd", "res://scripts/backpack_pickup.gd", "res://scripts/corridor_body.gd", "res://scripts/player_corpse.gd"]:
		var src: String = FileAccess.get_file_as_string(f)
		var at: int = src.find("func _input(")
		var body: String = src.substr(at, 700) if at >= 0 else ""
		check(at >= 0 and body.contains("set_input_as_handled()"), "%s claims the click it acts on" % f.get_file())
