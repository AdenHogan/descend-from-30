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
	await _test_drop_never_under_the_hud()
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


## OWNER ROUND 45: a drop at the far-left wall lay UNDER the portrait. The portrait hid it, and a click there was swallowed by the drop (with a
## full pack: "Inventory full", the press claimed) - the item could not be taken AND the portrait could not be pressed.
func _test_drop_never_under_the_hud() -> void:
	print("[a drop never rests under a HUD widget, and never eats a click on one]")
	var bf = await _corridor()
	var p = bf.get_node("Player")
	HUD.show_hud()
	p.global_position = Vector2(230, 386)
	for i in range(6):
		await get_tree().physics_frame
	var cam: Camera2D = p.get_node("Camera2D")
	var vp: Viewport = get_viewport()
	var half: Vector2 = vp.get_visible_rect().size / 2.0
	var port_screen: Vector2 = HUD.portrait.get_global_rect().get_center()
	var port_world: Vector2 = cam.get_screen_center_position() + (port_screen - half) / cam.zoom
	check(HUD.portrait.visible and HUD.pointer_over_widget(port_screen), "(setup) the portrait is a HUD widget at screen %s" % str(port_screen))
	# 1. a drop tossed into the left wall comes to rest clear of every widget
	var drop = load("res://scenes/world_drop.tscn").instantiate()
	drop.item_id = "005"
	bf.add_child(drop)
	drop.toss(Vector2(150.0, 370.0), 419.0, -1.0)
	drop._vel.x = -95.0
	for i in range(260):
		await get_tree().physics_frame
	check(not drop._tossing, "the toss comes to rest")
	check(drop.global_position.x > 128.0, "...in front of the wall (x %.0f)" % drop.global_position.x)
	var rest_screen: Vector2 = (drop.global_position - cam.get_screen_center_position()) * cam.zoom + half
	var covered := false
	for off in [Vector2.ZERO, Vector2(40, 0), Vector2(-40, 0), Vector2(0, -40)]:
		covered = covered or HUD.pointer_over_widget(rest_screen + off)
	check(not covered, "...and clear of every HUD widget (screen %s)" % str(rest_screen))
	var edge_drop_x: float = drop.global_position.x
	drop.queue_free()
	# 2. a drop that IS under the portrait (put there by hand, the nudge switched off) does not eat a click on the portrait
	var under = load("res://scenes/world_drop.tscn").instantiate()
	under.item_id = "005"
	under.set("_hud_checked", true)               # (the nudge switched off: this one is put under the portrait by hand)
	under.global_position = Vector2(port_world.x, 412.0)
	bf.add_child(under)
	p.global_position = Vector2(port_world.x + 20.0, 386.0)
	for i in range(6):
		await get_tree().physics_frame
	check(under.player_nearby, "(setup) the player is in reach of the drop that lies under the portrait")
	var before: int = WorldState.inventory.size()
	var tf: Transform2D = vp.get_final_transform()
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = tf * port_screen
		vp.push_input(ev)
	await get_tree().process_frame
	await get_tree().process_frame
	check(WorldState.inventory.size() == before and is_instance_valid(under) and not under.is_queued_for_deletion(), "a click on the portrait is not a pickup")
	check(HUD.character_panel != null and HUD.character_panel.visible, "...it opens the journal, as the portrait should")
	if HUD.character_panel != null and HUD.character_panel.visible:
		HUD.character_panel.close()
	# 3. the interact key still takes it
	Input.action_press("interact")
	await get_tree().process_frame
	Input.action_release("interact")
	await get_tree().process_frame
	await get_tree().physics_frame
	check(WorldState.inventory.size() == before + 1, "...and [interact] still picks it up (%d items)" % WorldState.inventory.size())
	check(edge_drop_x > 128.0, "(the wall drop's rest x was %.0f)" % edge_drop_x)
	WorldState.inventory.clear()
	bf.free()
	await get_tree().process_frame
