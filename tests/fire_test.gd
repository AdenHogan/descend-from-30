extends Node

# Headless test for Hazard 3 — the spreading fire simulation + its seeding.
# The spread is deterministic (RNG-free), so we drive it with tick() and assert
# it ignites, creeps to neighbours, and chars out. Run:
#   godot --headless res://tests/fire_test.tscn

var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== fire (Hazard 3) test ===")
	_test_spread()
	_test_seeding()
	_test_stage()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _make_field():
	# add_child runs the field's _ready synchronously (cell_count set); disable its
	# _process so the sim is driven by hand for a deterministic test.
	var ff = load("res://scripts/fire_field.gd").new()
	add_child(ff)
	ff.set_process(false)
	return ff


func _ticks(ff, n: int) -> void:
	for i in range(n):
		ff.tick(ff.SIM_DT)


func _test_spread() -> void:
	print("[spread simulation]")
	var ff = _make_field()
	var mid: int = ff.cell_count / 2
	var x = ff.cell_x(mid)
	ff.ignite_span(x, x)
	check(ff.state_of(mid) == ff.BURNING, "ignited cell is BURNING")
	check(ff.is_burning_at(x), "is_burning_at reports the lit cell")
	check(ff.state_of(mid - 1) == ff.COOL and ff.state_of(mid + 1) == ff.COOL,
		"neighbours start COOL")

	# A few seconds later the fire has crept to both neighbours.
	_ticks(ff, 30)   # ~3s
	check(ff.state_of(mid - 1) == ff.BURNING and ff.state_of(mid + 1) == ff.BURNING,
		"fire spreads to both neighbours over time")
	check(ff.burning_count() >= 3, "the burn front is growing (%d cells)" % ff.burning_count())

	# Left long enough, the origin exhausts its fuel and chars out.
	_ticks(ff, 220)   # ~22s more
	check(ff.state_of(mid) == ff.SPENT, "an old cell burns out to SPENT (char)")

	# Extinguishing kills the fire in a radius (heat + fuel), for good.
	var live := -1
	for i in range(ff.cell_count):
		if ff.state_of(i) == ff.BURNING:
			live = i
			break
	check(live != -1, "found a still-burning cell to douse")
	if live != -1:
		ff.extinguish_at(ff.cell_x(live), ff.CELL_W)
		check(ff.state_of(live) != ff.BURNING, "extinguish_at puts a cell out")
		_ticks(ff, 40)
		check(ff.state_of(live) != ff.BURNING, "a doused cell does not re-ignite")

	# char_all wipes the floor to a ruin (nothing burning, all spent).
	ff.char_all()
	check(not ff.any_burning(), "char_all leaves nothing burning")
	check(ff.state_of(0) == ff.SPENT and ff.state_of(ff.cell_count - 1) == ff.SPENT,
		"char_all marks the whole floor SPENT")
	ff.free()


func _test_seeding() -> void:
	print("[fire seeding]")
	WorldState.master_seed = 1337
	WorldState.current_run = 1
	WorldState.dev_hazard_mode = WorldState.DEV_HAZARD_NONE
	check(WorldState.is_stair_fire(15) == WorldState.is_stair_fire(15), "is_stair_fire is deterministic")
	check(not WorldState.is_stair_fire(30), "floor 30 (tutorial) never a fire")
	check(not WorldState.is_stair_fire(1), "floor 1 never a fire")
	# Mutually exclusive with barricade AND horde; fires occur across the range.
	var fires := 0
	var overlaps := 0
	for f in range(2, 30):
		var fire := WorldState.is_stair_fire(f)
		if fire:
			fires += 1
		if fire and (WorldState.is_stair_blocked(f) or WorldState.is_stair_horde(f)):
			overlaps += 1
	check(fires > 0 and fires < 28, "some (not all) stairwells are fires (%d/28)" % fires)
	check(overlaps == 0, "no stairwell is a fire AND a barricade/horde (%d)" % overlaps)

	# Dev FIRE mode forces fires everywhere and suppresses the others.
	WorldState.dev_hazard_mode = WorldState.DEV_HAZARD_FIRE
	var all_fire := true
	var other := false
	for f in range(2, 30):
		if not WorldState.is_stair_fire(f):
			all_fire = false
		if WorldState.is_stair_blocked(f) or WorldState.is_stair_horde(f):
			other = true
	check(all_fire, "dev fire mode makes every eligible stairwell a fire")
	check(not other, "dev fire mode suppresses barricades and hordes")
	WorldState.dev_hazard_mode = WorldState.DEV_HAZARD_NONE


func _test_stage() -> void:
	print("[fire stage by run]")
	WorldState.current_run = 1
	check(WorldState.fire_stage(15) == WorldState.FIRE_LIGHT, "run 1 = light fire")
	WorldState.current_run = 2
	check(WorldState.fire_stage(15) == WorldState.FIRE_BLAZE, "run 2 = full blaze")
	WorldState.current_run = 3
	check(WorldState.fire_stage(15) == WorldState.FIRE_CHARRED, "run 3 = charred ruin")
	WorldState.current_run = 1
