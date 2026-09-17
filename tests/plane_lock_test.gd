extends Node

# Regression: the player must NEVER be pushed off the flat walking plane by a crowd, in ANY
# movement state. move_and_slide's depenetration rode the player UP onto piled enemies; the
# fix pins Y via _move_locked() in EVERY move path (main, listen, mode-switch, lashing,
# dying). This exercises an EARLY-RETURN state (is_switching_mode) that previously skipped
# the pin, under a heavy overlapping crowd, and asserts the player's Y never drifts.
# Run: godot --headless res://tests/plane_lock_test.tscn

var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== plane lock test ===")
	await _test_crowd_cannot_push_off_plane()
	await _test_player_feet_on_enemy_plane()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _test_player_feet_on_enemy_plane() -> void:
	# The player must rest on the EXACT plane the enemies do — feet (collision-bottom)
	# on the shared floor line 419, never above or below. The old stair spawn (origin
	# 391) sat the player 5px LOW (feet 424), so it stood under the enemies and its legs
	# poked beneath corpses. A real floor arrival must land it feet-on-419.
	WorldState.new_game()
	WorldState.current_floor = 15
	WorldState.spawn_source = "stair"
	WorldState.stair_direction = "down"
	var bf = load("res://scenes/building_floors.tscn").instantiate()
	add_child(bf)
	for i in range(40):
		await get_tree().physics_frame
	var p = bf.get_node_or_null("Player")
	var cs = p.get_node_or_null("CollisionShape2D")
	var player_feet: float = p.global_position.y + cs.position.y + cs.shape.height * 0.5
	check(absf(player_feet - 419.0) < 1.5, "player feet rest on the floor line 419 (got %.1f)" % player_feet)
	# Find a GROUNDED corridor zombie (not a stair-shaft lurker, which sits deliberately
	# off-plane in the shaft) and assert its feet match the player's exactly.
	var matched := false
	for z in get_tree().get_nodes_in_group("zombie"):
		var zs = z.get_node_or_null("CollisionShape2D")
		if zs == null:
			continue
		if z.is_in_group("stair_enemy") or z.is_in_group("stair_horde") or z.is_in_group("pan_scenery"):
			continue
		if ("stair_mode" in z) and z.stair_mode:
			continue
		var zh: float = zs.shape.height * 0.5 if zs.shape is CapsuleShape2D else zs.shape.size.y * 0.5
		var zfeet: float = z.global_position.y + zs.position.y + zh
		if absf(zfeet - 419.0) > 30.0:
			continue   # not resting on the corridor plane (still settling / off-floor)
		check(absf(zfeet - player_feet) < 1.5, "a %s's feet sit on the SAME plane as the player (dz %.2f)" % [z.name, zfeet - player_feet])
		matched = true
		break
	check(matched, "there was a grounded corridor enemy to compare planes against")
	bf.free()
	await get_tree().physics_frame


func _test_crowd_cannot_push_off_plane() -> void:
	WorldState.new_game()
	WorldState.god_mode = true
	var p = load("res://scenes/player.tscn").instantiate()
	add_child(p)
	p.global_position = Vector2(600, 388)
	await get_tree().physics_frame
	var y0: float = p.global_position.y
	# Pile aggro zombies overlapping the player (capsules whose slide pushes upward).
	for i in range(14):
		var z = load("res://scenes/enemy_zombie_standard.tscn").instantiate()
		add_child(z)
		z.global_position = Vector2(588 + i * 4, 370)
		z.set("state", "chase")
	# Force the mode-switch early-return path (previously skipped the Y-pin).
	p.set("is_switching_mode", true)
	p.set("mode_switch_timer", 999.0)
	var max_drift: float = 0.0
	for f in range(150):
		await get_tree().physics_frame
		max_drift = maxf(max_drift, absf(p.global_position.y - y0))
	check(p.get("is_switching_mode"), "stayed in the mode-switch path the whole test")
	check(max_drift < 1.0, "player Y never drifts off the plane under a 14-zombie crowd (max drift %.2f px)" % max_drift)
	# And in the normal path too, once the switch clears.
	p.set("is_switching_mode", false)
	p.set("mode_switch_timer", 0.0)
	var y1: float = p.global_position.y
	var drift2: float = 0.0
	for f in range(80):
		await get_tree().physics_frame
		drift2 = maxf(drift2, absf(p.global_position.y - y1))
	check(drift2 < 1.0, "player Y also holds in the normal move path (max drift %.2f px)" % drift2)
	p.queue_free()
	WorldState.god_mode = false
	await get_tree().physics_frame
