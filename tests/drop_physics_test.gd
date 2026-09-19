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
