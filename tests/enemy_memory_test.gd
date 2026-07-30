extends Node

# LIVING-ENEMY MEMORY. A floor's zombies are re-seeded from the master seed every
# visit, so a zombie mid-chase used to snap back to its spawn the instant the
# player took the stairs or stepped into an apartment. WorldState.record_zombie
# snapshots a live zombie (position/facing/health/alert, keyed by its stable
# spawn_key) and apply_saved_zombie re-applies it onto the fresh instance on
# return. Enemies fire record_zombie from _exit_tree, so EVERY leave path is
# covered without a call site to forget.
# Run:  godot --headless res://tests/enemy_memory_test.tscn

const ZOMBIE := "res://scenes/enemy_zombie_standard.tscn"

var fails := 0

func chk(c: bool, m: String) -> void:
	print(("  PASS  " if c else "  FAIL  ") + m)
	if not c:
		fails += 1


func _spawn(key: String) -> Node:
	var z = load(ZOMBIE).instantiate()
	add_child(z)          # _ready runs here: AnimatedSprite2D is wired up
	z.spawn_key = key
	return z


func _ready() -> void:
	print("=== living-enemy memory ===")
	_test_roundtrip()
	_test_guards()
	_test_exit_tree()
	_test_backward_compat()
	await _test_backdrop_restores()
	print("=== %s (%d failures) ===" % ["ALL PASSED" if fails == 0 else "FAILED", fails])
	get_tree().quit(1 if fails > 0 else 0)


func _test_roundtrip() -> void:
	print("[record -> apply]")
	WorldState.zombie_positions.clear()
	var z = _spawn("mem:a")
	z.global_position = Vector2(500, 370)
	z.current_hp = 2
	z.alert_timer = 3.5
	z.get_node("AnimatedSprite2D").flip_h = true
	WorldState.record_zombie(z)
	var s = WorldState.zombie_positions.get("mem:a", {})
	chk(s.get("x") == 500 and s.get("y") == 370, "position recorded (%s)" % str(s.get("x")))
	chk(s.get("facing") == true, "facing recorded")
	chk(s.get("hp") == 2, "health recorded")
	chk(absf(float(s.get("alert", 0.0)) - 3.5) < 0.01, "alert recorded")
	z.free()

	# A fresh instance re-adopts every field.
	var z2 = _spawn("mem:a")
	z2.global_position = Vector2(100, 370)   # its seeded spot, to be overridden
	var ok = WorldState.apply_saved_zombie(z2)
	chk(ok, "apply reports memory found")
	chk(z2.global_position == Vector2(500, 370), "returns to the remembered spot, not the seed")
	chk(z2.current_hp == 2, "returns as hurt as it was")
	chk(absf(z2.alert_timer - 3.5) < 0.01, "returns still alert")
	chk(z2.get_node("AnimatedSprite2D").flip_h == true, "returns facing the same way")
	z2.free()


func _test_guards() -> void:
	print("[what must NOT be recorded]")
	WorldState.zombie_positions.clear()
	var dead = _spawn("g:dead"); dead.is_dead = true
	WorldState.record_zombie(dead)
	chk(not WorldState.zombie_positions.has("g:dead"), "dead zombie not recorded (killed_zombies owns it)")
	dead.free()

	var scenery = _spawn("g:scenery"); scenery.add_to_group("pan_scenery")
	WorldState.record_zombie(scenery)
	chk(not WorldState.zombie_positions.has("g:scenery"), "pan-backdrop scenery not recorded")
	scenery.free()

	var keyless = _spawn(""); WorldState.record_zombie(keyless)
	chk(WorldState.zombie_positions.is_empty(), "keyless zombie not recorded")
	keyless.free()


func _test_exit_tree() -> void:
	print("[_exit_tree captures every leave path]")
	WorldState.zombie_positions.clear()
	var z = _spawn("exit:a")
	z.global_position = Vector2(600, 370)
	remove_child(z)          # leaving the tree — the real scene-change signal
	chk(WorldState.zombie_positions.has("exit:a"), "leaving the tree records the zombie")
	chk(WorldState.zombie_positions.get("exit:a", {}).get("x") == 600, "at its live position, not a seed")
	z.free()


func _test_backward_compat() -> void:
	print("[old saves: position-only entries still apply]")
	WorldState.zombie_positions.clear()
	WorldState.zombie_positions["old:key"] = {"x": 300, "y": 350}   # pre-upgrade shape
	var z = _spawn("old:key"); z.current_hp = 3
	var ok = WorldState.apply_saved_zombie(z)
	chk(ok and z.global_position == Vector2(300, 350), "x/y-only memory still restores position")
	chk(z.current_hp == 3, "missing fields leave the fresh value untouched")
	z.free()


func _test_backdrop_restores() -> void:
	# The real path: a corridor floor, re-seeded on every build, now honours memory.
	print("[corridor floor restores remembered zombies]")
	WorldState.new_game()
	var f := 27
	for i in range(1, 30):
		if WorldState.get_floor_zombie_count(i) > 0:
			f = i
			break
	WorldState.current_floor = (f + 2) % 29 + 1
	WorldState.seed_floor_door_states(f)

	var bf = load("res://scenes/building_floors.tscn").instantiate()
	bf.setup_floor = f; bf.passive = true
	add_child(bf)
	for i in range(4): await get_tree().process_frame

	var scenery = get_tree().get_nodes_in_group("pan_scenery")
	chk(scenery.size() > 0, "floor %d seeds zombies to remember (%d)" % [f, scenery.size()])
	if scenery.is_empty():
		bf.queue_free()
		return
	var key: String = scenery[0].spawn_key
	var seeded: Vector2 = scenery[0].global_position
	# Pretend that zombie wandered 120px right, took a hit, turned around.
	WorldState.zombie_positions[key] = {
		"x": seeded.x + 120.0, "y": seeded.y, "facing": true, "hp": 1, "alert": 2.0}
	bf.queue_free()
	await get_tree().process_frame

	var bf2 = load("res://scenes/building_floors.tscn").instantiate()
	bf2.setup_floor = f; bf2.passive = true
	add_child(bf2)
	for i in range(4): await get_tree().process_frame

	var restored: Node = null
	for z in get_tree().get_nodes_in_group("pan_scenery"):
		if z.spawn_key == key:
			restored = z
			break
	chk(restored != null, "the same zombie is rebuilt on return")
	if restored != null:
		chk(absf(restored.global_position.x - (seeded.x + 120.0)) < 1.0,
			"it stands where it was left, not its seed (%.0f vs seed %.0f)"
				% [restored.global_position.x, seeded.x])
		chk(restored.current_hp == 1, "still carrying its wound")
		chk(restored.get_node("AnimatedSprite2D").flip_h == true, "still facing where it turned")
	bf2.queue_free()
	await get_tree().process_frame
