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
	_test_pan_targets()
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
	# The pan offset comes from the floor's tilemap height (not one screen) —
	# that's what removes the grey gap between floors.
	var sp2 = get_node_or_null("/root/StairPan")
	if sp2 != null:
		var spacing = sp2._floor_spacing(bf)
		check(spacing > 0.0, "floor spacing measured from the tilemap (%.0f)" % spacing)
		check(spacing < 1000.0, "floor spacing is a plausible one-floor height (%.0f)" % spacing)
		print("  INFO  measured floor spacing = %.1f world px" % spacing)
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


func _test_pan_targets() -> void:
	print("[seamless pan targets]")
	var sp = get_node_or_null("/root/StairPan")
	if sp == null:
		return
	# The whole seamlessness rests on one invariant: at the end of the pan the
	# camera-relative-to-player equals the live camera offset, so when the
	# destination scene loads (player at spawn, camera at spawn+offset) the first
	# frame is identical to the last pan frame — no jump, no hard cut.
	var cam_offset := Vector2(6, -19)
	var spawn := Vector2(188, 391)     # SPAWN_LEFT_BOTTOM
	var down_t = sp.pan_targets(spawn, cam_offset, 176.0)
	check(down_t["cam_target"] - down_t["player_target"] == cam_offset,
		"down: end framing matches destination (seamless commit)")
	check(down_t["player_target"] == spawn + Vector2(0, 176.0),
		"down: player ends one floor below on the backdrop")
	var up_t = sp.pan_targets(Vector2(148, 391), cam_offset, -176.0)
	check(up_t["cam_target"] - up_t["player_target"] == cam_offset,
		"up: end framing matches destination (seamless commit)")
	# Player + camera move by the SAME delta → player holds a fixed screen spot.
	var start_player := spawn
	var start_cam := spawn + cam_offset
	var player_delta = down_t["player_target"] - start_player
	var cam_delta = down_t["cam_target"] - start_cam
	check(player_delta == cam_delta, "player and camera slide by an identical delta")
	# Floors are contiguous: the offset is exactly one floor height (no gap).
	check(down_t["delta"] == Vector2(0, 176.0), "floor offset is exactly one floor height")
