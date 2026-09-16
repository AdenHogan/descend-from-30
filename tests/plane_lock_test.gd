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
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


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
