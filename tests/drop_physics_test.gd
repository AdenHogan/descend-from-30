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
	_test_registered_drops_rest_on_the_floor()
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


# Owner round 34: a Flashlight "hanging in the air, named and collectable, with no dead enemy there". Old builds
# REGISTERED a discard at the player's ORIGIN (~33 px above the feet) and zombie loot at the zombie's origin
# (~49 px up); the live drop was tossed onto the floor but the saved record came back floating on re-entry.
func _test_registered_drops_rest_on_the_floor() -> void:
	WorldState.new_game()
	WorldState.current_floor = 12
	WorldState.world_drops.clear()
	var room_scene := "res://scenes/room.tscn"
	var rest := Vector2(500.0, 346.0)
	# a zombie's loot is registered where the drop RESTS, and the live drop's key forgets that very record
	var found := {}
	for x in range(0, 400):
		var f: Dictionary = WorldState.roll_zombie_loot(Vector2(float(x), rest.y), 12, room_scene)
		if not f.is_empty():
			found = f
			break
	check(not found.is_empty(), "a standard zombie rolls loot for some position")
	if not found.is_empty():
		var rec: Dictionary = WorldState.world_drops.get(String(found["key"]), {})
		check(not rec.is_empty() and float(rec["y"]) == rest.y, "its record sits on the floor line (y %s)" % str(rec.get("y")))
		check(bool(rec.get("rested", false)), "and is marked rested")
		check(String(rec.get("scene", "")) == room_scene, "in the scene it was made in, not current_scene")
		WorldState.remove_world_drop(String(found["key"]))
		check(not WorldState.world_drops.has(String(found["key"])), "picking it up forgets the record (no duplicate on re-entry)")
	# an OLD record at the origin line (no "rested" marker) is lifted down onto the floor once; a balcony drop isn't touched
	WorldState.world_drops.clear()
	WorldState.world_drops["12:100:321"] = {"item_id": "015", "x": 100.0, "y": 321.0, "floor": 12, "scene": room_scene, "apartment_id": "1204", "target_apartment": "", "amount": 0, "instance": {}}
	WorldState.world_drops["12:200:312"] = {"item_id": "015", "x": 200.0, "y": 312.0, "floor": 12, "scene": room_scene, "apartment_id": "1204", "target_apartment": "", "amount": 0, "instance": {}}
	WorldState.world_drops["12:300:304"] = {"item_id": "006", "x": 300.0, "y": 304.0, "floor": 12, "scene": room_scene, "apartment_id": "1204", "target_apartment": "", "amount": 0, "instance": {}}
	var got: Dictionary = WorldState.get_world_drops_for_floor(12, room_scene, "1204")
	check(float(got["12:100:321"]["y"]) == 346.0, "a legacy discard saved at the player's origin (321) comes back ON the floor (%s)" % str(got["12:100:321"]["y"]))
	check(float(got["12:300:304"]["y"]) == 346.0, "a legacy zombie drop saved at its origin (304) too (%s)" % str(got["12:300:304"]["y"]))
	check(float(got["12:200:312"]["y"]) == 312.0, "a legacy drop on the balcony line (312) is left alone (%s)" % str(got["12:200:312"]["y"]))
	check(not WorldState.heal_legacy_drop(got["12:100:321"]), "healing happens once")
	WorldState.world_drops.clear()
