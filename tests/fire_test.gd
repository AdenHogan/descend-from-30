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
	_test_spread_cap()
	_test_memory()
	_test_smoke()
	_test_spawn_and_apartments()
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


func _test_spread_cap() -> void:
	# A run-1 LIGHT fire is CAPPED: it holds as a small patch instead of creeping over
	# the whole floor within the run (escalation is across runs). Set a low cap, run a
	# long time, and it must stop growing at the cap — but stay lit (persist).
	print("[spread cap — run-1 fire stays a contained patch]")
	var ff = _make_field()
	var mid: int = ff.cell_count / 2
	for dc in [-2, 0, 2]:
		ff.ignite_span(ff.cell_x(mid + dc), ff.cell_x(mid + dc))
	ff.spread_cap = maxi(ff.burning_count(), 7)
	_ticks(ff, 1500)   # ~150s — plenty of time to creep the whole floor if uncapped
	check(ff.burning_count() <= 7, "capped fire never exceeds its cap (%d <= 7)" % ff.burning_count())
	check(ff.burning_count() < ff.cell_count, "capped fire does NOT fill the floor (%d of %d cells)" % [ff.burning_count(), ff.cell_count])
	check(ff.any_burning(), "a capped fire still burns (it persists, just doesn't spread)")


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
	_ticks(ff, 40)   # ~4s
	check(ff.state_of(mid - 1) == ff.COOL and ff.state_of(mid + 1) == ff.COOL,
		"fire does NOT race — neighbours still cool after a few seconds")

	# The front is RAGGED, not a uniform wall: tick on and one neighbour catches
	# before the other (their per-cell catch factors differ), instead of both
	# igniting on the same step.
	var caught_uneven := false
	var both := false
	for step in range(4000):
		ff.tick(ff.SIM_DT)
		var l: bool = ff.state_of(mid - 1) == ff.BURNING
		var r: bool = ff.state_of(mid + 1) == ff.BURNING
		if l != r:
			caught_uneven = true
		if l and r:
			both = true
			break
	check(caught_uneven, "the front is ragged — one neighbour catches before the other")
	check(both, "given long enough the fire does creep to both neighbours")
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


func _test_memory() -> void:
	print("[fire remembers its spread across a visit]")
	var ff = _make_field()
	# Spread it out a bit, then snapshot.
	ff.ignite_span(ff.cell_x(ff.cell_count / 2), ff.cell_x(ff.cell_count / 2))
	_ticks(ff, 900)
	var burned: int = ff.burning_count()
	check(burned >= 3, "fire spread to several cells before leaving (%d)" % burned)
	var snap: Array = ff.export_state()
	ff.free()
	# A FRESH field (as if the floor was rebuilt on re-entry) restores the snapshot
	# instead of resetting to the spawn pattern.
	var ff2 = _make_field()
	ff2.import_state(snap)
	check(ff2.burning_count() == burned, "re-entering restores the same spread (%d vs %d)" % [ff2.burning_count(), burned])
	# WorldState round-trips it per (floor, run).
	WorldState.fire_cells.clear()
	WorldState.current_run = 1
	WorldState.set_fire_cells(24, snap)
	check(WorldState.has_fire_cells(24), "WorldState stores the fire spread for the floor/run")
	check(WorldState.get_fire_cells(24).size() == snap.size(), "stored spread matches")
	WorldState.current_run = 2
	check(not WorldState.has_fire_cells(24), "the spread is per-run (a new run starts fresh)")
	WorldState.current_run = 1
	WorldState.fire_cells.clear()
	ff2.free()


func _test_smoke() -> void:
	print("[smoke coverage + stage scaling]")
	var ff = _make_field()
	var mid: int = ff.cell_count / 2
	ff.ignite_span(ff.cell_x(mid), ff.cell_x(mid))
	# Smoke sits over the fire and drifts a FEW cells past it — not the whole floor.
	check(ff.smoke_at(ff.cell_x(mid)), "smoke sits over the fire")
	check(ff.smoke_at(ff.cell_x(mid + ff.SMOKE_MARGIN_CELLS)), "smoke drifts a few cells past the flames")
	check(not ff.smoke_at(ff.cell_x(mid + ff.SMOKE_MARGIN_CELLS + 2)), "smoke doesn't blanket the whole floor")
	# Stage scales flame size AND how low the smoke hangs — small/high on LIGHT,
	# big/low (head height, must crouch) on a BLAZE.
	ff.stage = ff.STAGE_LIGHT
	var light_scale: float = ff.flame_scale()
	var light_bottom: float = ff.smoke_bottom_y()
	ff.stage = ff.STAGE_BLAZE
	check(ff.flame_scale() > light_scale, "flames are bigger on a BLAZE than a LIGHT fire")
	check(ff.smoke_bottom_y() > light_bottom, "smoke sinks to head height on a BLAZE (crouch under it)")
	# A charred ruin has no live fire, so no smoke.
	ff.char_all()
	check(not ff.smoke_at(ff.cell_x(mid)), "a charred ruin has no smoke")
	ff.free()


func _test_spawn_and_apartments() -> void:
	print("[fire spawn kind 40/40/20 + apartment spread]")
	WorldState.dev_hazard_mode = WorldState.DEV_HAZARD_NONE
	# Spawn kind roughly 40 down / 40 mid / 20 arrival across seeds.
	var n := {0: 0, 1: 0, 2: 0}
	for s in range(1, 601):
		WorldState.master_seed = s
		n[WorldState.fire_spawn_kind(15)] += 1
	var total := 600.0
	check(n[0] > 180 and n[0] < 300, "~40%% spawn at the down stair (%d)" % n[0])
	check(n[1] > 180 and n[1] < 300, "~40%% spawn mid-hallway (%d)" % n[1])
	check(n[2] > 60 and n[2] < 180, "~20%% spawn at the arrival stair (%d)" % n[2])

	# Apartment spread: with the fire at the LEFT (a left-stair fire), the nearest
	# apartment (2505, x=316) catches first, then 2504, escalating each run.
	WorldState.master_seed = 4242
	WorldState.current_run = 1
	WorldState.fire_dealt_with.clear()
	WorldState.fire_origin_x.clear()
	# force an origin on floor 25 and put the fire at the left stair
	while not WorldState._fire_origin_seeded(25):
		WorldState.master_seed += 1
	WorldState.set_fire_origin_x(25, 150.0)
	check(WorldState.apartment_rank(25, 5) == 0, "apt 5 (leftmost) is nearest a left-stair fire")
	check(WorldState.apartment_rank(25, 1) == 4, "apt 1 (rightmost) is furthest")
	# Run 1: only the nearest apartment catches (light).
	check(WorldState.apartment_fire_stage(25, 5) == WorldState.FIRE_LIGHT, "run 1: nearest apt catches (light)")
	check(WorldState.apartment_fire_stage(25, 4) == -1, "run 1: the next apt is not alight yet")
	# Run 2: nearest is a blaze, the next catches.
	WorldState.current_run = 2
	check(WorldState.apartment_fire_stage(25, 5) == WorldState.FIRE_BLAZE, "run 2: nearest apt is a blaze")
	check(WorldState.apartment_fire_stage(25, 4) == WorldState.FIRE_LIGHT, "run 2: the next apt catches")
	# Run 3: the whole floor is a charred ruin — every apartment lost.
	WorldState.current_run = 3
	var all_charred := true
	for a in [1, 2, 3, 4, 5]:
		if not WorldState.is_apartment_charred(25, a):
			all_charred = false
	check(all_charred, "run 3: every apartment is charred (floor is a total ruin)")
	# Dealing with the source spares the apartments.
	WorldState.current_run = 2
	WorldState.mark_fire_dealt_with(25)
	check(WorldState.apartment_fire_stage(25, 5) == -1, "putting the source out stops the apartment spread")
	WorldState.fire_dealt_with.clear()
	WorldState.fire_origin_x.clear()
	WorldState.current_run = 1


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
	print("[dev FIRE scroll (F2 lv1/lv2)]")
	WorldState.master_seed = 1337
	# The dev fire LEVEL is the F2 scroll step, NOT the run counter — so the level
	# holds no matter which run we're on (F8/advance-run is not needed and is avoided,
	# it being Godot's editor Stop). Pin an off-1 run to prove independence.
	WorldState.current_run = 3
	WorldState.dev_hazard_mode = WorldState.DEV_HAZARD_FIRE
	WorldState.dev_fire_origin = 15               # F2 pressed on floor 15
	# Dev fire suppresses the other hazards everywhere.
	var other := false
	for f in range(2, 30):
		if WorldState.is_stair_blocked(f) or WorldState.is_stair_horde(f):
			other = true
	check(not other, "dev fire mode suppresses barricades and hordes")
	# lv1 (DEV_HAZARD_FIRE): ONLY the origin burns (LIGHT); its neighbours do NOT.
	check(WorldState.fire_intensity(15) == WorldState.FIRE_LIGHT, "lv1: origin is LIGHT")
	check(not WorldState.is_stair_fire(14) and not WorldState.is_stair_fire(16), "lv1: neighbours are NOT on fire")
	check(not WorldState.is_stair_fire(20), "lv1: a far floor is NOT on fire")
	# lv2 (DEV_HAZARD_FIRE2): origin BLAZE, both neighbours LIGHT, two-out still clear.
	WorldState.dev_hazard_mode = WorldState.DEV_HAZARD_FIRE2
	check(WorldState.fire_intensity(15) == WorldState.FIRE_BLAZE, "lv2: origin is BLAZE")
	check(WorldState.fire_intensity(14) == WorldState.FIRE_LIGHT and WorldState.fire_intensity(16) == WorldState.FIRE_LIGHT, "lv2: neighbours catch at LIGHT")
	check(not WorldState.is_stair_fire(13) and not WorldState.is_stair_fire(17), "lv2: two floors out still clear")
	# The level is scroll-driven, not run-driven: same result on a different run.
	WorldState.current_run = 1
	check(WorldState.fire_intensity(15) == WorldState.FIRE_BLAZE, "lv2 holds regardless of run (run-independent)")
	WorldState.dev_hazard_mode = WorldState.DEV_HAZARD_NONE
	WorldState.dev_fire_origin = -1
