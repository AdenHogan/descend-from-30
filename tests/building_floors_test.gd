extends Node

# Headless test for the stair-pan groundwork: building_floors can be built as a
# PASSIVE backdrop for a specific floor (no player/enemies/merchant, correct
# door IDs) — what StairPan instances beside the live floor. Also checks the
# StairPan safety guard (disabled by default → never pans).
# Run:  godot --headless res://tests/building_floors_test.tscn

var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== building_floors passive / StairPan test ===")
	await _test_passive_backdrop()
	_test_stairpan_guard()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _test_passive_backdrop() -> void:
	print("[passive backdrop]")
	WorldState.new_game()
	WorldState.current_floor = 25          # live floor is elsewhere
	WorldState.seed_floor_door_states(27)  # backdrop floor
	var bf = load("res://scenes/building_floors.tscn").instantiate()
	bf.setup_floor = 27
	bf.passive = true
	add_child(bf)
	for i in range(6):
		await get_tree().process_frame

	check(bf.get_node_or_null("Player") == null, "passive backdrop drops its Player node")
	var zombies := 0
	for z in get_tree().get_nodes_in_group("zombie"):
		zombies += 1
	check(zombies == 0, "passive backdrop spawns no enemies (%d)" % zombies)
	# Doors carry the backdrop floor's apartment IDs.
	var d1 = bf.get_node_or_null("apartment01")
	check(d1 != null and d1.apartment_id == "2701", "doors use the backdrop floor's IDs (%s)" % (d1.apartment_id if d1 else "nil"))
	check(bf.get_node_or_null("Merchant") == null, "no merchant on a passive backdrop")
	bf.queue_free()
	await get_tree().process_frame


func _test_stairpan_guard() -> void:
	print("[StairPan guard]")
	var sp = get_node_or_null("/root/StairPan")
	check(sp != null, "StairPan is an autoload singleton")
	if sp == null:
		return
	# Enabled: pans between real floors (not into the lobby / past the top).
	check(sp.ENABLED, "StairPan is enabled")
	check(not sp.can_pan(0), "no pan into the lobby (floor 0)")
	check(not sp.can_pan(30), "no pan up to the hallway (floor 30)")
