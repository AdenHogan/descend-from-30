extends Node

# Enemy/world drops must TOSS out of the corpse, bounce, and SETTLE on the floor plane near
# it — never suspended in the air. Also each pickup carries the shared orb light (except the
# wall extinguisher). Run: godot --headless res://tests/drop_physics_test.tscn

var failures: int = 0

func check(c: bool, m: String) -> void:
	print(("  PASS  " if c else "  FAIL  ") + m)
	if not c: failures += 1


func _ready() -> void:
	print("=== drop physics test ===")
	await _test_toss_settles()
	await _test_extinguisher_has_no_orb_light()
	await _test_discard_spawns_live()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _test_toss_settles() -> void:
	WorldState.new_game()
	var drop = load("res://scenes/world_drop.tscn").instantiate()
	drop.item_id = "005"
	add_child(drop)
	await get_tree().process_frame
	var from_pos := Vector2(600.0, 360.0)   # up at corpse-origin height
	var land_y := 419.0                      # corridor floor line
	drop.toss(from_pos, land_y, 1.0)
	check(drop.global_position.y < land_y, "starts ABOVE the floor (tossed, y=%.0f)" % drop.global_position.y)
	var peaked := false
	for i in range(200):
		await get_tree().physics_frame
		if drop.global_position.y < from_pos.y - 4.0:
			peaked = true                    # it flew UP out of the corpse first
	var rest_y: float = land_y - drop.REST_LIFT
	check(peaked, "the drop arcs UP out of the corpse before falling")
	check(not drop._tossing, "the drop comes to REST (stops tossing)")
	check(absf(drop.global_position.y - rest_y) < 1.0, "rests ON the floor plane (y %.1f ~= %.1f)" % [drop.global_position.y, rest_y])
	check(absf(drop.global_position.x - from_pos.x) < 90.0, "settles NEAR the corpse (dx %.0f)" % (drop.global_position.x - from_pos.x))
	var has_light := false
	for c in drop.get_children():
		if c is PointLight2D: has_light = true
	check(has_light, "an item drop carries the orb's glow light")
	drop.queue_free()
	await get_tree().process_frame


func _test_extinguisher_has_no_orb_light() -> void:
	var ext = load("res://scenes/world_drop.tscn").instantiate()
	ext.item_id = "036"
	add_child(ext)
	await get_tree().process_frame
	var has_light := false
	for c in ext.get_children():
		if c is PointLight2D: has_light = true
	check(not has_light, "the wall extinguisher is a fixture, not a glowing orb (no orb light)")
	ext.queue_free()
	await get_tree().process_frame


func _test_discard_spawns_live() -> void:
	print("[a discarded item appears at once]")
	WorldState.new_game()
	WorldState.current_floor = 12
	var world = Node2D.new()
	world.scene_file_path = "res://scenes/building_floors.tscn"
	add_child(world)
	var player = load("res://scenes/player.tscn").instantiate()
	world.add_child(player)
	await get_tree().process_frame
	player.global_position = Vector2(500.0, 386.0)
	WorldState.inventory.clear()
	WorldState.add_to_inventory("002")
	WorldState.add_to_inventory("005")
	WorldState.add_to_inventory("005")
	var before := WorldState.world_drops.size()
	HUD._discard_slot(0)
	var live: Array = []
	for c in world.get_children():
		if c.get_script() == load("res://scripts/world_drop.gd"):
			live.append(c)
	check(WorldState.world_drops.size() == before + 1, "the discard is remembered (registered)")
	check(live.size() == 1, "...and a LIVE pickup appears in the scene straight away (was: invisible until re-entry)")
	if live.size() == 1:
		var d = live[0]
		check(d.item_id == "002" and WorldState.world_drops.has(d.drop_key), "it is the hammer, tied to its registered key")
		for i in range(120):
			await get_tree().physics_frame
		check(not d._tossing and absf(d.global_position.x - 500.0) < 160.0, "it tosses out and comes to rest near the player")
		var rest: Vector2 = Vector2(WorldState.world_drops[d.drop_key]["x"], WorldState.world_drops[d.drop_key]["y"])
		check(absf(d.global_position.y - rest.y) < 1.5, "its registered position is the RESTED one (re-entry matches what you saw)")
		check(WorldState.world_drops[d.drop_key]["scene"] == "res://scenes/building_floors.tscn", "tagged with the scene it was dropped in")
	# a stack comes back whole
	var cans_before := WorldState.world_drops.size()
	HUD._discard_slot(0)
	var stack_key := ""
	for k in WorldState.world_drops:
		if WorldState.world_drops[k]["item_id"] == "005":
			stack_key = k
	check(WorldState.world_drops.size() == cans_before + 1 and stack_key != "" and int(WorldState.world_drops[stack_key]["amount"]) == 2, "a stack of two cans drops as one x2 pickup")
	world.queue_free()
