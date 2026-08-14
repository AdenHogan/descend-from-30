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
	_test_spread_across_runs()
	_test_dealt_with()
	_test_exclusivity()
	_test_dev_mode()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


# An origin floor with no other origin within 2 floors, so its spread across runs
# is unambiguous. Rolls master_seed until it finds one (deterministic per seed).
func _isolated_origin() -> int:
	for f in range(5, 27):
		if not WorldState._fire_origin_seeded(f):
			continue
		var isolated := true
		for g in range(f - 2, f + 3):
			if g != f and WorldState._fire_origin_seeded(g):
				isolated = false
				break
		if isolated:
			return f
	return -1


func _seed_for_isolated_origin() -> int:
	for s in range(1, 600):
		WorldState.master_seed = s
		WorldState.fire_dealt_with.clear()
		var o := _isolated_origin()
		if o != -1:
			return o
	return -1


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

	# The spread is a SLOW creep now: after a short moment the neighbours have NOT
	# caught yet (it doesn't race across the floor).
	_ticks(ff, 30)   # ~3s
	check(ff.state_of(mid - 1) == ff.COOL and ff.state_of(mid + 1) == ff.COOL,
		"fire does NOT race — neighbours still cool after a few seconds")

	# Given long enough it does creep to both neighbours.
	_ticks(ff, 220)   # ~22s more
	check(ff.state_of(mid - 1) == ff.BURNING and ff.state_of(mid + 1) == ff.BURNING,
		"fire creeps to both neighbours over time")
	check(ff.burning_count() >= 3, "the burn front is growing (%d cells)" % ff.burning_count())

	# It does NOT burn itself out — a lit cell stays lit until it's put out.
	_ticks(ff, 600)   # ~60s more
	check(ff.state_of(mid) == ff.BURNING, "a fire stays lit indefinitely (never self-extinguishes)")
	check(ff.any_burning(), "left alone, the fire is still going")

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
	print("[fire seeding — run-1 outbreak]")
	WorldState.master_seed = 1337
	WorldState.current_run = 1
	WorldState.dev_hazard_mode = WorldState.DEV_HAZARD_NONE
	WorldState.fire_dealt_with.clear()
	check(WorldState.is_stair_fire(15) == WorldState.is_stair_fire(15), "is_stair_fire is deterministic")
	check(not WorldState.is_stair_fire(30), "floor 30 (tutorial) never a fire")
	check(not WorldState.is_stair_fire(1), "floor 1 never a fire")
	# Run 1 = the outbreak: every fire floor is exactly its origin at LIGHT stage.
	var fires := 0
	for f in range(2, 30):
		if WorldState.is_stair_fire(f):
			fires += 1
			check(WorldState._fire_origin_seeded(f), "run-1 fire floor %d is an origin" % f)
			check(WorldState.fire_intensity(f) == WorldState.FIRE_LIGHT,
				"run-1 fire floor %d starts LIGHT" % f)
	check(fires > 0 and fires < 28, "some (not all) floors are outbreak origins (%d/28)" % fires)
	# Origins are stable across runs (NOT re-rolled per run) — the same floor still
	# burns next run (hotter), which is what lets the fire persist and spread.
	var run1_origins := []
	for f in range(2, 30):
		if WorldState._fire_origin_seeded(f):
			run1_origins.append(f)
	WorldState.current_run = 2
	var run2_origins := []
	for f in range(2, 30):
		if WorldState._fire_origin_seeded(f):
			run2_origins.append(f)
	check(run1_origins == run2_origins, "fire origins are stable across runs")
	WorldState.current_run = 1


func _test_spread_across_runs() -> void:
	print("[fire spreads up/down the building across runs]")
	var o := _seed_for_isolated_origin()
	check(o != -1, "found an isolated outbreak origin to trace (floor %d)" % o)
	if o == -1:
		return
	WorldState.dev_hazard_mode = WorldState.DEV_HAZARD_NONE
	WorldState.fire_dealt_with.clear()
	# Run 1: only the origin burns, and only at LIGHT.
	WorldState.current_run = 1
	check(WorldState.fire_intensity(o) == WorldState.FIRE_LIGHT, "run 1: origin is LIGHT")
	check(WorldState.fire_intensity(o - 1) == -1 and WorldState.fire_intensity(o + 1) == -1,
		"run 1: neighbours are not yet alight")
	# Run 2: origin climbs to BLAZE, fire has crept to both neighbours at LIGHT.
	WorldState.current_run = 2
	check(WorldState.fire_intensity(o) == WorldState.FIRE_BLAZE, "run 2: origin is a BLAZE")
	check(WorldState.fire_intensity(o - 1) == WorldState.FIRE_LIGHT
		and WorldState.fire_intensity(o + 1) == WorldState.FIRE_LIGHT,
		"run 2: both neighbours catch at LIGHT")
	# Run 3: origin is a CHARRED ruin, neighbours BLAZE, the next ring out LIGHT.
	WorldState.current_run = 3
	check(WorldState.fire_intensity(o) == WorldState.FIRE_CHARRED, "run 3: origin is CHARRED")
	check(WorldState.is_floor_charred(o), "run 3: origin reads as charred")
	check(WorldState.fire_intensity(o - 1) == WorldState.FIRE_BLAZE
		and WorldState.fire_intensity(o + 1) == WorldState.FIRE_BLAZE,
		"run 3: neighbours are now BLAZES")
	check(WorldState.fire_intensity(o - 2) == WorldState.FIRE_LIGHT
		and WorldState.fire_intensity(o + 2) == WorldState.FIRE_LIGHT,
		"run 3: the fire has reached two floors out at LIGHT")
	WorldState.current_run = 1


func _test_dealt_with() -> void:
	print("[dealing with the source halts the chain]")
	var o := _seed_for_isolated_origin()
	if o == -1:
		return
	WorldState.dev_hazard_mode = WorldState.DEV_HAZARD_NONE
	WorldState.fire_dealt_with.clear()
	WorldState.current_run = 1
	check(WorldState.is_stair_fire(o), "origin is on fire in run 1")
	# Put the source out in run 1.
	WorldState.mark_fire_dealt_with(o)
	check(not WorldState.is_stair_fire(o), "once dealt with, the origin stops burning")
	# It never comes back or spreads in later runs.
	WorldState.current_run = 2
	check(WorldState.fire_intensity(o) == -1, "run 2: a dealt-with origin does not re-ignite")
	check(WorldState.fire_intensity(o - 1) == -1 and WorldState.fire_intensity(o + 1) == -1,
		"run 2: neighbours never catch — the chain is broken")
	WorldState.current_run = 3
	check(WorldState.fire_intensity(o) == -1 and WorldState.fire_intensity(o + 2) == -1,
		"run 3: still nothing — laziness avoided")
	# Dousing a SPREAD floor (not the source) does not count.
	WorldState.fire_dealt_with.clear()
	WorldState.current_run = 3
	check(WorldState.fire_intensity(o + 1) == WorldState.FIRE_BLAZE, "spread floor is ablaze again")
	WorldState.mark_fire_dealt_with(o + 1)
	check(not WorldState.fire_dealt_with.has(str(o + 1)),
		"dousing a non-source floor is not recorded (must kill the source)")
	WorldState.fire_dealt_with.clear()
	WorldState.current_run = 1


func _test_exclusivity() -> void:
	print("[hazards never double up]")
	WorldState.master_seed = 1337
	WorldState.dev_hazard_mode = WorldState.DEV_HAZARD_NONE
	WorldState.fire_dealt_with.clear()
	var overlaps := 0
	for run in [1, 2, 3]:
		WorldState.current_run = run
		for f in range(2, 30):
			if WorldState.is_stair_fire(f) and (WorldState.is_stair_blocked(f) or WorldState.is_stair_horde(f)):
				overlaps += 1
	check(overlaps == 0, "no floor is ever a fire AND a barricade/horde (%d overlaps)" % overlaps)
	WorldState.current_run = 1


func _test_dev_mode() -> void:
	print("[dev FIRE cycle]")
	WorldState.master_seed = 1337
	WorldState.current_run = 1
	WorldState.dev_hazard_mode = WorldState.DEV_HAZARD_FIRE
	var all_fire := true
	var other := false
	for f in range(2, 30):
		if not WorldState.is_stair_fire(f):
			all_fire = false
		if WorldState.is_stair_blocked(f) or WorldState.is_stair_horde(f):
			other = true
	check(all_fire, "dev fire mode makes every eligible floor a fire")
	check(not other, "dev fire mode suppresses barricades and hordes")
	WorldState.dev_hazard_mode = WorldState.DEV_HAZARD_NONE
