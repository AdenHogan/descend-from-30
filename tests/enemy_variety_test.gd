extends Node

# Headless test for the enemy-variety escalation table (docs/THREE_RUN_ARC.md):
# heavies (Big Zombie) migrate UPWARD across the three runs, the type roll is
# deterministic (backdrop == live commit), and a corridor heavy settles on the
# measured floor line. Run:  godot --headless res://tests/enemy_variety_test.tscn

var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== enemy variety / escalation test ===")
	_test_table_shape()
	_test_determinism()
	await _test_run1_confined_low()
	await _test_run3_reaches_high()
	await _test_big_settle_y()
	await _test_backdrop_matches_live()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _test_table_shape() -> void:
	# The infestation only ever gets WORSE run to run, and is always heaviest deep
	# (LOW) and lightest up high (HIGH). Morning's upper floors carry no heavies.
	print("[table shape]")
	WorldState.new_game()
	var low := [WorldState.HEAVY_CHANCE[0][0], WorldState.HEAVY_CHANCE[0][1], WorldState.HEAVY_CHANCE[0][2]]
	var monotonic := true
	for band in range(3):
		for r in range(1, 3):
			if WorldState.HEAVY_CHANCE[band][r] < WorldState.HEAVY_CHANCE[band][r - 1]:
				monotonic = false
	check(monotonic, "heavy chance never decreases across runs (per band)")
	var depth_ordered := true
	for r in range(3):
		if not (WorldState.HEAVY_CHANCE[0][r] >= WorldState.HEAVY_CHANCE[1][r] and WorldState.HEAVY_CHANCE[1][r] >= WorldState.HEAVY_CHANCE[2][r]):
			depth_ordered = false
	check(depth_ordered, "heavies are always densest deep (LOW >= MID >= HIGH)")
	check(low[0] > 0.0, "run 1 already has some heavies deep down (%.2f)" % low[0])
	WorldState.current_run = 1
	check(WorldState.heavy_chance(25) == 0.0, "run 1 upper floors carry NO heavies")
	check(WorldState.heavy_chance(15) == 0.0, "run 1 mid floors carry NO heavies")


func _test_determinism() -> void:
	# The type of a slot is a pure function of (floor, position key, run): identical
	# on repeat, and it re-rolls when the run advances (fresh infestation).
	print("[determinism]")
	WorldState.new_game()
	WorldState.current_run = 2
	var a := WorldState.enemy_type_for(8, "8:600:388")
	var b := WorldState.enemy_type_for(8, "8:600:388")
	check(a == b, "same (floor,key,run) yields the same type every time")
	var seen := {}
	for i in range(40):
		seen[WorldState.enemy_type_for(6, "6:%d:388" % (200 + i * 20))] = true
	check(seen.has("zombie_standard"), "the mix still includes standards")


func _test_run1_confined_low() -> void:
	# Run 1: heavies appear ONLY on low floors. A big sample of a high floor's slots
	# is pure standard; a low floor's sample contains at least one heavy.
	print("[run 1 heavies confined to low floors]")
	WorldState.new_game()
	WorldState.current_run = 1
	var high_heavies := 0
	for i in range(200):
		if WorldState.enemy_type_for(27, "27:%d:388" % (200 + i * 4)) == "zombie_big":
			high_heavies += 1
	check(high_heavies == 0, "no heavies on a high floor in the morning (%d)" % high_heavies)
	var low_heavies := 0
	for i in range(200):
		if WorldState.enemy_type_for(3, "3:%d:388" % (200 + i * 4)) == "zombie_big":
			low_heavies += 1
	check(low_heavies > 0, "some heavies deep down in the morning (%d of 200)" % low_heavies)
	await get_tree().process_frame


func _test_run3_reaches_high() -> void:
	# Run 3 (night): heavies have climbed — even high floors now carry some.
	print("[run 3 heavies reach the upper floors]")
	WorldState.new_game()
	WorldState.current_run = 3
	var high_heavies := 0
	for i in range(300):
		if WorldState.enemy_type_for(27, "27:%d:388" % (200 + i * 3)) == "zombie_big":
			high_heavies += 1
	check(high_heavies > 0, "night heavies reach the top of the building (%d of 300)" % high_heavies)
	await get_tree().process_frame


func _test_big_settle_y() -> void:
	# Guards BIG_ZOMBIE_SETTLED_Y: a live big zombie physically rests where the
	# constant says (its feet on the 419 floor line), so a pan-backdrop heavy placed
	# at that constant doesn't warp on arrival. Fails HERE if the collision changes.
	print("[big zombie settles on the measured line]")
	WorldState.new_game()
	WorldState.current_floor = 12
	var bf = load("res://scenes/building_floors.tscn").instantiate()
	bf.setup_floor = 12
	add_child(bf)
	for i in range(6):
		await get_tree().process_frame
	var big = load("res://scenes/enemy_zombie_big.tscn").instantiate()
	bf.add_child(big)
	big.global_position = Vector2(640, 388.0)      # overlapping the floor, as a live spawn does
	for i in range(180):
		await get_tree().process_frame
	check(absf(big.global_position.y - bf.BIG_ZOMBIE_SETTLED_Y) <= 1.0,
		"a live big zombie rests at BIG_ZOMBIE_SETTLED_Y (%.1f vs %.1f)" % [big.global_position.y, bf.BIG_ZOMBIE_SETTLED_Y])
	bf.queue_free()
	await get_tree().process_frame


func _test_backdrop_matches_live() -> void:
	# The pan backdrop and the live commit must pick the SAME types (else a heavy pops
	# in / vanishes at the commit). Build both for a run-3 low floor and compare the
	# set of heavy spawn keys.
	print("[backdrop type mix matches live]")
	WorldState.new_game()
	WorldState.tutorial_completed = true
	WorldState.is_first_run = false
	WorldState.current_run = 3
	# Find a deep floor that actually spawns a heavy this seed, so the parity check
	# isn't satisfied by two empty sets.
	var f := -1
	var live_keys: Array = []
	for cand in range(1, 11):
		WorldState.current_floor = cand
		WorldState.seed_floor_door_states(cand)
		var ks := await _heavy_keys(cand, false)
		if ks.size() > 0:
			f = cand
			live_keys = ks
			break
	check(f > 0, "a deep night floor spawns at least one heavy to compare (floor %d, %d heavies)" % [f, live_keys.size()])
	if f > 0:
		var back_keys := await _heavy_keys(f, true)
		check(live_keys == back_keys, "backdrop heavies match live heavies (%s vs %s)" % [str(live_keys), str(back_keys)])


func _heavy_keys(floor_num: int, passive: bool) -> Array:
	var bf = load("res://scenes/building_floors.tscn").instantiate()
	bf.setup_floor = floor_num
	bf.passive = passive
	add_child(bf)
	for i in range(4):
		await get_tree().process_frame
	var keys: Array = []
	for z in get_tree().get_nodes_in_group("big_zombie"):
		if bf.is_ancestor_of(z):
			keys.append(z.spawn_key)
	keys.sort()
	bf.queue_free()
	await get_tree().process_frame
	return keys
