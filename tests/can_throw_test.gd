extends Node

# Headless test for can throwing / distraction (item 17).
# Run:  godot --headless res://tests/can_throw_test.tscn

var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== can throw / distraction test ===")
	_test_distraction_targets()
	_test_boss_ignores()
	_test_arrival()
	_test_can_lands()
	await _test_physics_collision()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _test_distraction_targets() -> void:
	print("[distraction]")
	WorldState.new_game()
	var z = load("res://scenes/enemy_zombie_standard.tscn").instantiate()
	z.global_position = Vector2(100, 388)
	add_child(z)
	check(z.z_index == 1, "zombie renders on the actor layer (z 1, in front of doors)")
	z.alert_to_noise(6.0)  # pretend it was chasing
	WorldState.emit_distraction(Vector2(300, 388), 700.0)
	check(z.is_distracted and z.state == "distracted", "in-range zombie is distracted")
	check(z.alert_timer == 0.0, "distraction overrides prior aggro")
	check(z.distraction_target == Vector2(300, 388), "target is the can")
	z.queue_free()

	var far = load("res://scenes/enemy_zombie_standard.tscn").instantiate()
	far.global_position = Vector2(2000, 388)
	add_child(far)
	WorldState.emit_distraction(Vector2(300, 388), 700.0)
	check(not far.is_distracted, "out-of-earshot zombie is unaffected")
	far.queue_free()


func _test_boss_ignores() -> void:
	print("[boss immunity]")
	WorldState.new_game()
	var big = load("res://scenes/enemy_zombie_big.tscn").instantiate()
	big.global_position = Vector2(200, 388)
	add_child(big)
	WorldState.emit_distraction(Vector2(250, 388), 700.0)
	check(not big.has_method("be_distracted") or not big.get("is_distracted"),
		"big zombie ignores the can")
	big.queue_free()


func _test_arrival() -> void:
	print("[arrival]")
	WorldState.new_game()
	# Force both outcomes by seeding — just verify arrival clears distraction
	# and lands in a valid follow-up state.
	for i in range(20):
		var z = load("res://scenes/enemy_zombie_standard.tscn").instantiate()
		z.global_position = Vector2(300, 388)
		add_child(z)
		z.be_distracted(Vector2(305, 388))  # already basically on top of it
		z._physics_process(0.1)
		check(not z.is_distracted, "arrival clears distraction (run %d)" % i)
		check(z.state in ["idle", "chase"], "arrival -> idle or chase (run %d)" % i)
		z.queue_free()


func _test_can_lands() -> void:
	print("[can landing]")
	WorldState.new_game()
	var z = load("res://scenes/enemy_zombie_standard.tscn").instantiate()
	z.global_position = Vector2(360, 388)
	add_child(z)
	var can = load("res://scenes/thrown_can.tscn").instantiate()
	add_child(can)
	can.launch(1.0, Vector2(300, 388))
	check(can.linear_velocity.x > 0 and can.linear_velocity.y < 0, "launch gives forward+up velocity")
	check(can.collision_mask & 1 != 0, "can collides with the world (layer 1) so it can't pass walls")
	check(can.contact_monitor, "contact monitoring on for bounce thuds")
	can._land()
	check(z.is_distracted, "landing distracts a nearby zombie")
	can.queue_free()
	z.queue_free()


func _test_physics_collision() -> void:
	print("[physics collision]")
	# Build a real floor collider (layer 1, like the world) and drop a can on
	# it. If the RigidBody physics is wired right the can lands and STOPS above
	# the floor instead of passing through it (the bug being fixed).
	var floor_body = StaticBody2D.new()
	floor_body.position = Vector2(0, 420)
	var cs = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(4000, 60)
	cs.shape = rect
	floor_body.add_child(cs)
	add_child(floor_body)

	var can = load("res://scenes/thrown_can.tscn").instantiate()
	add_child(can)
	can.launch(1.0, Vector2(0, 300))
	# Let gravity + collision resolve over ~1.2s of physics.
	for i in range(72):
		await get_tree().physics_frame
	check(can.has_landed, "can made contact with the floor (didn't float)")
	check(can.global_position.y <= 400.0, "can rests ABOVE the floor, not through it (y=%.0f)" % can.global_position.y)
	can.queue_free()
	floor_body.queue_free()
