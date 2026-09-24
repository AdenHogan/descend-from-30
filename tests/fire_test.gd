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
	_test_apartment_fire_state()
	_test_extinguish_aftermath()
	_test_fire_hot_at()
	_test_stair_fire()
	_test_snapshot_stage()
	_test_off_span_douse()
	_test_my_fire_field()
	await _test_apartment_fire_lights()
	await _test_hit_flash_clears()
	await _test_burnt_breach()
	await _test_full_pack_key_drop()
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


func _test_fire_hot_at() -> void:
	# The PLAYER-damage test burns whenever the player's OWN cell is a BURNING cell — ANY kind,
	# tile OR gap. (Gap cells are exactly where the big TALL FLAMES rise, so excluding them left
	# the player unburned while standing in the most visible fire — the owner's bug.) It's still
	# TIGHT: DAMAGE_REACH < half a cell, so at a cell centre only that cell decides it, and a
	# player off the fire is never cooked.
	print("[fire_hot_at — player damage in any burning cell]")
	var ff = _make_field()
	ff.floor_num = 7
	ff.ignite_span(ff.FIRE_MIN_X + 40.0, ff.FIRE_MAX_X - 40.0)
	check(not ff.fire_hot_at(ff.FIRE_MIN_X - 60.0), "no burn standing off the fire")
	# At a cell CENTRE the neighbours are a full cell (>DAMAGE_REACH) away, so the burn is
	# decided by the player's OWN cell: hot iff it's burning — regardless of tile/gap.
	var exact := true
	var found_hot_gap := false
	for i in range(ff.cell_count):
		var cx: float = ff.cell_x(i)
		var hot: bool = ff.fire_hot_at(cx)
		var burning: bool = ff.state_of(i) == ff.BURNING
		if hot != burning:
			exact = false
		if hot and ff._cell_kind(cx) == 2:
			found_hot_gap = true
	check(exact, "at a cell centre, burn iff standing on a burning cell (any kind)")
	check(found_hot_gap, "standing on a burning GAP cell (where the tall flames are) NOW burns")
	ff.free()

	# PARITY (the "no damage on the left, but corpses appeared" bug): the player-burn test
	# (fire_hot_at) and the enemy-burn test (is_burning_at) must AGREE everywhere, including OFF
	# the ends of the fire span. cell_at() clamps+truncates, so an x just left of FIRE_MIN_X used
	# to read the burning edge cell as "burning" for the enemy while the player was spared — so
	# enemies cooked to death (leaving corpses) on the left where the player took no damage.
	print("[fire_hot_at — left/right off-span parity (player == enemy)]")
	var pf = _make_field()
	pf.floor_num = 7
	pf.ignite_span(pf.FIRE_MIN_X, pf.FIRE_MIN_X)          # only the very first (leftmost) cell
	var parity := true
	var phantom_left := false
	# Sweep from well left of the span through the first cell.
	for x in range(int(pf.FIRE_MIN_X) - 80, int(pf.FIRE_MIN_X) + 60, 3):
		var pfx := float(x)
		if pf.fire_hot_at(pfx) != pf.is_burning_at(pfx):
			parity = false
		# Nothing should burn (player OR enemy) a clear step LEFT of the span.
		if pfx <= pf.FIRE_MIN_X - pf.CELL_W and (pf.fire_hot_at(pfx) or pf.is_burning_at(pfx)):
			phantom_left = true
	check(parity, "player-burn and enemy-burn agree across the left edge")
	check(not phantom_left, "nothing burns a full cell left of the fire span (no phantom corpses)")
	# The lit leftmost cell DOES still burn both when you stand on it.
	check(pf.is_burning_at(pf.cell_x(0)) and pf.fire_hot_at(pf.cell_x(0)), "the lit edge cell still burns both")
	pf.free()


func _test_stair_fire() -> void:
	# The third plane: set_stair_fire arms a fire on the down-stairwell; it only draws while
	# the floor still has live fire (gated by any_burning), and clears with -1.
	print("[stair fire — third plane]")
	var ff = _make_field()
	ff.set_stair_fire(165.0)
	check(ff._stair_fire_x == 165.0, "set_stair_fire records the down-stair x")
	check(not ff.any_burning(), "no fire yet - stair fire would not draw")
	ff.ignite_span(600.0, 600.0)
	check(ff.any_burning(), "a lit floor - stair fire draws on the step")
	ff.set_stair_fire(-1.0)
	check(ff._stair_fire_x < 0.0, "a floor with no down-stair fire clears to -1")
	ff.free()


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
			if WorldState.is_stair_fire(f) and WorldState.is_stair_blocked(f):
				overlaps += 1
	check(overlaps == 0, "no floor is ever a fire AND a barricade (%d overlaps)" % overlaps)
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
		if WorldState.is_stair_blocked(f):
			other = true
	check(not other, "dev fire mode suppresses barricades")
	# lv1 (DEV_HAZARD_FIRE): ONLY the origin burns (LIGHT); its neighbours do NOT.
	check(WorldState.fire_intensity(15) == WorldState.FIRE_LIGHT, "lv1: origin is LIGHT")
	check(not WorldState.is_stair_fire(14) and not WorldState.is_stair_fire(16), "lv1: neighbours are NOT on fire")
	check(not WorldState.is_stair_fire(20), "lv1: a far floor is NOT on fire")
	# lv2 (DEV_HAZARD_FIRE2): origin BLAZE, both neighbours LIGHT, two-out still clear.
	WorldState.dev_hazard_mode = WorldState.DEV_HAZARD_FIRE2
	check(WorldState.fire_intensity(15) == WorldState.FIRE_BLAZE, "lv2: origin is BLAZE")
	check(WorldState.fire_intensity(14) == WorldState.FIRE_LIGHT and WorldState.fire_intensity(16) == WorldState.FIRE_LIGHT, "lv2: neighbours catch at LIGHT")
	check(not WorldState.is_stair_fire(13) and not WorldState.is_stair_fire(17), "lv2: two floors out still clear")
	# lv3 (DEV_HAZARD_FIRE3): origin CHARRED, neighbours BLAZE, two-out LIGHT, three-out clear.
	WorldState.dev_hazard_mode = WorldState.DEV_HAZARD_FIRE3
	check(WorldState.fire_intensity(15) == WorldState.FIRE_CHARRED, "lv3: origin is CHARRED")
	check(WorldState.fire_intensity(14) == WorldState.FIRE_BLAZE and WorldState.fire_intensity(16) == WorldState.FIRE_BLAZE, "lv3: neighbours are BLAZE")
	check(WorldState.fire_intensity(13) == WorldState.FIRE_LIGHT and WorldState.fire_intensity(17) == WorldState.FIRE_LIGHT, "lv3: two floors out are LIGHT")
	check(not WorldState.is_stair_fire(12) and not WorldState.is_stair_fire(18), "lv3: three floors out still clear")
	# The level is scroll-driven, not run-driven: same result on a different run.
	WorldState.current_run = 1
	check(WorldState.fire_intensity(15) == WorldState.FIRE_CHARRED, "lv3 holds regardless of run (run-independent)")
	WorldState.dev_hazard_mode = WorldState.DEV_HAZARD_NONE
	WorldState.dev_fire_origin = -1


func _test_apartment_fire_state() -> void:
	print("[apartment fire: active stage + doused-out persistence]")
	WorldState.new_game()
	WorldState.master_seed = 4242
	var f := 12
	# lv2 dev fire (BLAZE origin) so the floor is on fire and near apartments catch.
	WorldState.dev_hazard_mode = WorldState.DEV_HAZARD_FIRE2
	WorldState.dev_fire_origin = f
	WorldState.current_run = 1
	# At least one apartment is burning on a BLAZE floor (rank 0/1 by the origin).
	var burning_apt := -1
	for a in [1, 2, 3, 4, 5]:
		if WorldState.is_apartment_burning(f, a):
			burning_apt = a
			break
	check(burning_apt != -1, "a BLAZE floor has at least one burning apartment")
	if burning_apt != -1:
		check(WorldState.apartment_active_fire_stage(f, burning_apt) == WorldState.apartment_fire_stage(f, burning_apt),
			"active stage == derived stage before dousing")
		check(WorldState.apartment_active_fire_stage(f, burning_apt) >= WorldState.FIRE_LIGHT,
			"burning apartment reports an active fire stage")
		# Douse it → no active interior fire this run.
		WorldState.mark_apartment_fire_out(f, burning_apt)
		check(WorldState.is_apartment_fire_out(f, burning_apt), "apartment marked doused-out")
		check(WorldState.apartment_active_fire_stage(f, burning_apt) == -1,
			"a doused apartment shows no active fire this run")
		# Doused-out is PER-RUN: next run (source still burning) it's back.
		WorldState.current_run = 2
		check(not WorldState.is_apartment_fire_out(f, burning_apt),
			"doused-out does not carry to the next run (source still governs)")
		WorldState.current_run = 1
	# A CHARRED floor: every apartment is a charred ruin, and charred can't be 'doused out'.
	WorldState.dev_hazard_mode = WorldState.DEV_HAZARD_FIRE3
	var all_charred := true
	for a in [1, 2, 3, 4, 5]:
		if not WorldState.is_apartment_charred(f, a):
			all_charred = false
	check(all_charred, "every apartment on a charred floor is charred")
	WorldState.mark_apartment_fire_out(f, 1)
	check(WorldState.apartment_active_fire_stage(f, 1) == WorldState.FIRE_CHARRED,
		"a charred apartment stays charred (cannot be doused out)")
	WorldState.dev_hazard_mode = WorldState.DEV_HAZARD_NONE
	WorldState.dev_fire_origin = -1
	WorldState.apartment_fire_out.clear()


func _test_extinguish_aftermath() -> void:
	# Ash/smoke marks where fire WAS, not where the spray landed: extinguishing empty floor
	# leaves NOTHING (no fake spent cells / smoulder), and extinguishing fire turns the
	# BURNING cells (not untouched cool ones) into spent ash.
	print("[extinguish: aftermath tracks the fire, not the blast]")
	var ff = load("res://scripts/fire_field.gd").new()
	ff.stage = WorldState.FIRE_BLAZE
	ff.spread_cap = 1000000
	add_child(ff)
	ff.set_process(false)
	# Spray bare floor — no fire anywhere.
	ff.extinguish_at(ff.cell_x(ff.cell_count / 2), 130.0)
	var spent_empty := 0
	for i in range(ff.cell_count):
		if ff.state_of(i) == ff.SPENT:
			spent_empty += 1
	check(spent_empty == 0, "dousing bare floor leaves NO ash (spent cells = %d)" % spent_empty)
	check(not ff.has_smoulder(), "dousing bare floor leaves NO smoulder smoke")
	# Now light a patch and douse it — the burning cells become ash.
	var mid: int = ff.cell_count / 2
	ff.ignite_span(ff.cell_x(mid - 3), ff.cell_x(mid + 3))
	var burned: int = ff.burning_count()
	check(burned > 0, "patch is burning before dousing (%d)" % burned)
	ff.extinguish_at(ff.cell_x(mid), 130.0)
	var spent_after := 0
	for i in range(ff.cell_count):
		if ff.state_of(i) == ff.SPENT:
			spent_after += 1
	check(spent_after > 0, "dousing fire leaves ash where it burned (spent = %d)" % spent_after)
	check(ff.has_smoulder(), "doused fire smoulders")
	ff.free()


# --- repair-pass regressions (each locks a shipped fire bug) -----------------

func _test_snapshot_stage() -> void:
	# A fire snapshot only restores onto the SAME stage it was taken at: switching lv1 → lv2 in
	# one run brought the BLAZE back as the lv1 patch (the stale LIGHT snapshot overwrote it).
	print("[fire snapshot is tied to its stage]")
	WorldState.fire_cells.clear()
	WorldState.current_run = 1
	WorldState.set_fire_cells(24, [1, 2, 3], WorldState.FIRE_LIGHT)
	check(WorldState.has_fire_cells(24, WorldState.FIRE_LIGHT), "snapshot restores on the stage it was taken at")
	check(not WorldState.has_fire_cells(24, WorldState.FIRE_BLAZE), "a LIGHT snapshot is REJECTED once the floor is BLAZE")
	check(WorldState.get_fire_cells(24) == [1, 2, 3], "cells read back from the stage-tagged record")
	# Old saves stored a bare array — still accepted for any stage.
	WorldState.fire_cells[WorldState._fire_cells_key(24)] = [4, 5]
	check(WorldState.has_fire_cells(24, WorldState.FIRE_BLAZE), "an old bare-array snapshot is still accepted")
	check(WorldState.get_fire_cells(24) == [4, 5], "an old bare-array snapshot still reads back")
	WorldState.fire_cells.clear()


func _test_off_span_douse() -> void:
	# A spray / door check wholly OFF the fire span touches nothing (cell_at clamped it onto the
	# edge cell — spraying past the corridor end doused the end cell).
	print("[extinguish / burning_near off the span]")
	var ff = load("res://scripts/fire_field.gd").new()
	ff.stage = WorldState.FIRE_BLAZE
	ff.spread_cap = 1000000
	add_child(ff)
	ff.set_process(false)
	var last: int = ff.cell_count - 1
	ff.ignite_span(ff.cell_x(0), ff.cell_x(0))
	ff.ignite_span(ff.cell_x(last), ff.cell_x(last))
	var left_x: float = ff.cell_x(0) - ff.CELL_W * 3.0
	var right_x: float = ff.cell_x(last) + ff.CELL_W * 3.0
	check(not ff.burning_near(left_x, 20.0), "burning_near well left of the span is false")
	check(not ff.burning_near(right_x, 20.0), "burning_near well right of the span is false")
	check(ff.burning_near(ff.cell_x(0), 20.0), "burning_near ON the burning edge cell is true")
	ff.extinguish_at(left_x, 20.0)
	ff.extinguish_at(right_x, 20.0)
	check(ff.state_of(0) == ff.BURNING, "a spray left of the span leaves the edge cell burning")
	check(ff.state_of(last) == ff.BURNING, "a spray right of the span leaves the edge cell burning")
	ff.extinguish_at(ff.cell_x(0), 20.0)
	check(ff.state_of(0) == ff.SPENT, "a spray ON the edge cell still douses it")
	ff.free()


func _test_my_fire_field() -> void:
	# The extinguisher sprays the fire in the player's OWN scene — during a pan/backdrop two
	# fire fields exist and the group's first could be the other floor's.
	print("[extinguisher targets the fire under the player's own scene]")
	var other := Node2D.new()
	var mine := Node2D.new()
	add_child(other)
	add_child(mine)
	var ff_other = load("res://scripts/fire_field.gd").new()
	other.add_child(ff_other)
	ff_other.set_process(false)
	var ff_mine = load("res://scripts/fire_field.gd").new()
	mine.add_child(ff_mine)
	ff_mine.set_process(false)
	var p = load("res://scenes/player.tscn").instantiate()
	mine.add_child(p)
	p.set_physics_process(false)
	check(p._my_fire_field() == ff_mine, "picks the fire field under the player's own parent")
	other.free()
	mine.free()


func _test_apartment_fire_lights() -> void:
	# Apartment fire throws real light (it was unlit sprites in the dark at night); a doused spot's
	# light goes dark.
	print("[apartment fire casts light; doused spots go dark]")
	var af = load("res://scripts/apartment_fire.gd").new()
	af.stage = WorldState.FIRE_BLAZE
	af.seed_salt = "1502"
	add_child(af)
	await get_tree().process_frame
	await get_tree().process_frame
	var lights: Array = []
	for c in af.get_children():
		if c is PointLight2D:
			lights.append(c)
	check(af.any_burning(), "a BLAZE apartment fire has burning spots")
	check(lights.size() >= af._spots.size() and lights.size() > 0,
		"one fire light per burning spot (%d lights, %d spots)" % [lights.size(), af._spots.size()])
	var lit := true
	for lt in lights:
		lit = lit and lt.energy > 0.0
	check(lit, "every spot light is on")
	af.extinguish_at(600.0, 2000.0)
	await get_tree().process_frame
	var dark := true
	for lt in lights:
		dark = dark and lt.energy == 0.0
	check(not af.any_burning() and dark, "dousing every spot puts every fire light out")
	af.free()


func _test_hit_flash_clears() -> void:
	# The red hit flash was only ticked AFTER the early returns (cutscene, dying, listening...), so
	# a hit landing in one of those states left the player solid red.
	print("[hit flash clears even through an early-return state]")
	var p = load("res://scenes/player.tscn").instantiate()
	add_child(p)
	await get_tree().physics_frame
	p.flash_hurt()
	p.is_cutscene = true
	check(p.animated_sprite.modulate == Color(1, 0, 0, 1), "hit flash turns the player red")
	var t := 0.0
	while t < p.HIT_FLASH_DURATION + 0.3:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	check(p.animated_sprite.modulate == Color(1, 1, 1, 1), "the flash wears off during a cutscene")
	check(not p.is_hit, "is_hit clears during a cutscene")
	p.free()


func _test_burnt_breach() -> void:
	# A breached apartment on a charred floor used to still hold a live boss + pack. Now its pack
	# burned: no live enemies, the boss recorded dead, and its key left in the ashes — ONCE.
	print("[a burnt breached apartment: no live pack, key kept]")
	WorldState.new_game()
	WorldState.is_first_run = false
	WorldState.master_seed = 4242
	WorldState.current_run = 1
	var f := 12
	WorldState.dev_hazard_mode = WorldState.DEV_HAZARD_FIRE3      # origin CHARRED → every apt charred
	WorldState.dev_fire_origin = f
	var apt := str(f) + "03"
	check(WorldState.apartment_fire_stage(f, 3) == WorldState.FIRE_CHARRED, "test apartment is charred")
	WorldState.set_door_state(apt, WorldState.DoorState.BREACHED)
	WorldState.current_apartment_id = apt
	WorldState.current_floor = f
	WorldState.spawn_source = ""
	var target: String = WorldState.get_breached_boss_key_target(apt)
	for visit in range(2):
		var room = load("res://scenes/room.tscn").instantiate()
		add_child(room)
		for i in range(4):
			await get_tree().process_frame
		var live := 0
		for z in get_tree().get_nodes_in_group("zombie"):
			if room.is_ancestor_of(z) and not z.is_dead:
				live += 1
		check(live == 0, "visit %d: no live enemies in the charred breach (%d)" % [visit + 1, live])
		var keys := 0
		var drops: Dictionary = WorldState.get_world_drops_for_floor(f, room.scene_file_path, apt)
		var key_on_floor := true
		for k in drops:
			if drops[k]["item_id"] == "022":
				keys += 1
				# Rests on the MEASURED room feet line (353) less REST_LIFT, not 17px under it.
				key_on_floor = key_on_floor and absf(float(drops[k]["y"]) - (353.0 - 7.0)) < 1.5
		check(key_on_floor, "visit %d: the key rests on the room floor line" % [visit + 1])
		if target != "":
			check(keys == 1, "visit %d: exactly one boss key lies in the ashes (%d)" % [visit + 1, keys])
		else:
			check(keys == 0, "visit %d: no key when the boss had no target" % [visit + 1])
		room.free()
		await get_tree().process_frame
	var dead_boss := false
	for k in WorldState.killed_zombies:
		var rec = WorldState.killed_zombies[k]
		if rec is Dictionary and rec.get("apartment_id", "") == apt and rec.get("type", "") == "big":
			dead_boss = absf(float(rec.get("y", 0.0)) - 308.0) < 1.5    # a settled big zombie's origin
	check(dead_boss, "the breach boss is recorded dead (its burnt body lies there)")
	WorldState.dev_hazard_mode = WorldState.DEV_HAZARD_NONE
	WorldState.dev_fire_origin = -1


func _test_full_pack_key_drop() -> void:
	# A boss killed with full pockets only REGISTERED its key (mid-air, at its origin) and spawned no
	# pickup — the key was invisible until you left and came back. Now it lands live on the floor.
	print("[boss key with full pockets lands as a live pickup]")
	WorldState.new_game()
	WorldState.current_floor = 12
	WorldState.inventory.clear()
	for id in ["002", "006", "007", "009", "019"]:
		WorldState.add_to_inventory(id)
	var holder := Node2D.new()
	add_child(holder)
	var big = load("res://scenes/enemy_zombie_big.tscn").instantiate()
	big.global_position = Vector2(600, 374)
	holder.add_child(big)
	big.set_physics_process(false)
	big.key_target_apartment = "1404"
	big._drop_key()
	var live_key = null
	for c in holder.get_children():
		if c != big and c.get("item_id") == "022":
			live_key = c
	check(live_key != null, "a live key pickup is spawned beside the corpse")
	var reg := 0
	var on_floor := true
	for k in WorldState.world_drops:
		var d = WorldState.world_drops[k]
		if d["item_id"] == "022" and d.get("target_apartment", "") == "1404":
			reg += 1
			on_floor = on_floor and float(d["y"]) > 374.0
	check(reg == 1, "the key is registered once (%d)" % reg)
	check(on_floor, "registered at the floor rest spot, not the corpse's mid-air origin")
	if live_key != null:
		check(live_key.drop_key != "", "the live pickup is tied to its saved record")
	holder.free()
	WorldState.inventory.clear()
