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
	check(can.velocity.x > 0 and can.velocity.y < 0, "launch gives forward+up velocity")
	can._land()
	check(z.is_distracted, "landing distracts a nearby zombie")
	can.queue_free()
	z.queue_free()
