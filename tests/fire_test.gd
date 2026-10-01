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
	_test_fire_warning()
	_test_wall_fire()
	_test_apartment_fire_state()
	_test_extinguish_aftermath()
	_test_fire_hot_at()
	_test_stair_fire()
	await _test_stair_douse_on_floor()
	_test_snapshot_stage()
	_test_off_span_douse()
	_test_my_fire_field()
	await _test_apartment_fire_lights()
	await _test_hit_flash_clears()
	await _test_burnt_breach()
	_test_full_pack_key_drop()
	await _test_soft_smoke()
	_test_fire_art()
	_test_fire_layout()
	_test_fire_extensions()
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
	# The third plane: set_stair_fire arms a fire on the down-stairwell. It burns only when the
	# fire has REACHED the stairwell — a cell in its zone is burning — and goes out when those
	# cells are doused. (It used to draw whenever ANYTHING on the floor burned, so spraying it
	# did nothing while a patch down the corridor was still alight — owner playtest.)
	print("[stair fire — the stairwell's own cells]")
	for side in ["right", "left"]:
		var ff = _make_field()
		if side == "right":
			ff.set_stair_fire(1203.0, 26.0, 1114.0, 1249.0)
		else:
			ff.set_stair_fire(146.0, 26.0, 100.0, 235.0)
		var sx: float = ff._stair_fire_x
		var zone: Array = []
		for i in range(ff.cell_count):
			if ff._in_stair_keepout(ff.cell_x(i)):
				zone.append(i)
		check(zone.size() >= 2, "%s: the stairwell zone holds fire cells (%s)" % [side, str(zone)])
		ff.ignite_span(600.0, 600.0)
		check(ff.any_burning() and not ff.stair_fire_lit(), "%s: fire down the corridor does NOT light the stairwell" % side)
		check(not ff.is_burning_at(sx) and not ff.fire_hot_at(sx), "%s: …and nothing burns you at the stairs" % side)
		ff.ignite_span(ff.cell_x(zone[0]), ff.cell_x(zone[0]))
		check(ff.stair_fire_lit(), "%s: the fire reaching the stairwell's zone lights it" % side)
		check(ff.is_burning_at(sx) and ff.fire_hot_at(sx), "%s: …and standing in the shaft's flames burns (player + enemy)" % side)
		# In the zone but clear of the shaft there are no flames drawn — so none that burn.
		var beside: float = sx + (-(ff._stair_half + ff.STAIR_HEAT_MARGIN + 20.0) if side == "right" else (ff._stair_half + ff.STAIR_HEAT_MARGIN + 20.0))
		check(ff._in_stair_keepout(beside) and not ff.is_burning_at(beside), "%s: beside the shaft (no flames drawn there) nothing burns" % side)
		ff.extinguish_span(sx - 60.0, sx + 60.0)
		check(not ff.stair_fire_lit(), "%s: spraying the stairs puts the stairwell fire OUT…" % side)
		check(ff.any_burning(), "%s: …while the corridor fire further off still burns" % side)
		ff.free()
	var nf = _make_field()
	nf.set_stair_fire(-1.0)
	nf.ignite_span(nf.FIRE_MIN_X, nf.FIRE_MAX_X)
	check(nf._stair_fire_x < 0.0 and not nf.stair_fire_lit(), "a floor with no down-stair fire clears to -1 and never lights it")
	nf.free()


# The owner's report, end to end on a REAL floor: a fire at the down stairwell, sprayed from the
# stairs with the extinguisher. The stairwell must go out, the jet must beat the flames back from
# the nozzle outward (near first, far last), and it must put out an enemy set alight by a weapon.
func _test_stair_douse_on_floor() -> void:
	print("[extinguisher at the stairwell — real floor]")
	WorldState.new_game()
	WorldState.tutorial_completed = true
	WorldState.is_first_run = false
	WorldState.god_mode = true
	WorldState.dev_hazard_mode = WorldState.DEV_HAZARD_FIRE2
	WorldState.dev_fire_origin = 15
	WorldState.current_floor = 15
	WorldState.spawn_source = ""
	WorldState.fire_cells.clear()
	WorldState.fire_origin_x.clear()
	var fl = load("res://scenes/building_floors.tscn").instantiate()
	add_child(fl)
	for i in range(6):
		await get_tree().physics_frame
	var ff = fl._fire_field
	check(ff != null and ff._stair_fire_x > 0.0, "the floor's fire has its down-stairwell armed")
	if ff == null:
		fl.free()
		return
	ff.set_process(false)
	var sx: float = ff._stair_fire_x
	var right: bool = sx > 600.0
	var dir := -1.0 if right else 1.0               # face along the corridor, away from the end wall
	# the stairwell alight + the whole corridor from it on
	ff.ignite_span(ff.FIRE_MIN_X, ff.FIRE_MAX_X)
	check(ff.stair_fire_lit(), "the stairwell is alight")
	var p = fl.get_node("Player")
	for z in get_tree().get_nodes_in_group("zombie"):
		if fl.is_ancestor_of(z):
			z.free()
	var zombie = load("res://scenes/enemy_zombie_standard.tscn").instantiate()
	fl.add_child(zombie)
	zombie.set_physics_process(false)
	p.global_position.x = sx - dir * 10.0
	zombie.global_position = Vector2(p.global_position.x + dir * 100.0, 370.0)
	WeaponAffliction.ignite(zombie)
	check(zombie.weapon_lit, "an enemy set alight by a fire weapon, in the jet's path")
	p.animated_sprite.flip_h = dir < 0.0
	WorldState.inventory.clear()
	WorldState.add_to_inventory("036", 1)
	var nozzle: float = p.global_position.x
	p.use_item(0)
	var sprays := 0
	for n in fl.get_children():
		if n.get_script() == load("res://scripts/extinguisher_spray.gd"):
			sprays += 1
	check(sprays == 1, "the spray jet lives in the player's own floor scene")
	await get_tree().create_timer(0.5).timeout
	check(not ff.is_burning_at(nozzle + dir * 30.0), "after ~0.5s the flames nearest the nozzle are out")
	check(ff.is_burning_at(nozzle + dir * 160.0), "…but the far end of the jet's reach still burns (beaten back, not switched off)")
	await get_tree().create_timer(0.8).timeout
	var reach_out := true
	for x in range(int(nozzle - dir * 60.0), int(nozzle + dir * 165.0), int(dir * 7.0)):
		if ff.state_of(ff.cell_of_unclamped(float(x))) == ff.BURNING and not ff._in_stair_keepout(float(x)):
			reach_out = false
	check(reach_out, "after ~1s everything in the jet's reach is out")
	check(not ff.stair_fire_lit(), "the STAIRWELL's fire is out (the owner's bug)")
	check(ff.any_burning(), "…while the corridor beyond the jet still burns")
	check(not zombie.weapon_lit and not zombie.on_fire, "the jet put out the weapon-lit enemy")
	WorldState.dev_hazard_mode = WorldState.DEV_HAZARD_NONE
	WorldState.dev_fire_origin = -1
	WorldState.god_mode = false
	WorldState.inventory.clear()
	fl.free()
	await get_tree().process_frame


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


func _test_wall_fire() -> void:
	# A BLAZE climbs the walls: tongues over burning cells, never at a doorway or in the stair zone,
	# spaced apart, nothing on a LIGHT outbreak.
	print("[wall fire — a blaze climbs the walls]")
	WorldState.master_seed = 1337
	var ff = _make_field()
	ff.floor_num = 15
	ff.stage = ff.STAGE_BLAZE
	ff.ignite_span(ff.FIRE_MIN_X, ff.FIRE_MAX_X)
	var spots: Array = ff.wall_fire_spots()
	check(spots.size() >= 3, "a floor-wide blaze climbs the wall in several places (%d)" % spots.size())
	var bad_door := 0
	var bad_gap := 0
	var prev := -1.0e9
	for sp in spots:
		if ff._near_door(float(sp["x"])):
			bad_door += 1
		if float(sp["x"]) - prev < ff.WALL_FIRE_GAP:
			bad_gap += 1
		prev = float(sp["x"])
	check(bad_door == 0, "none across a doorway")
	check(bad_gap == 0, "spaced at least %d px apart" % int(ff.WALL_FIRE_GAP))
	ff.set_stair_fire(146.0, 26.0, 100.0, 235.0)
	for sp in ff.wall_fire_spots():
		check(not ff._in_stair_keepout(float(sp["x"])), "none inside the stair zone (x %.0f)" % float(sp["x"]))
	ff.extinguish_span(ff.FIRE_MIN_X, ff.FIRE_MAX_X)
	check(ff.wall_fire_spots().is_empty(), "doused: the walls stop burning")
	var lt = _make_field()
	lt.floor_num = 15
	lt.stage = lt.STAGE_LIGHT
	lt.ignite_span(lt.FIRE_MIN_X, lt.FIRE_MAX_X)
	check(lt.wall_fire_spots().is_empty(), "a LIGHT outbreak doesn't reach the walls")
	ff.free()
	lt.free()


func _test_fire_warning() -> void:
	# The building warns you a fire is coming: heard at the down stairwell (the report's own `fire_line`,
	# leaving the count line untouched), smelt once per floor per run as you step up to the steps.
	print("[fire approach warning]")
	WorldState.master_seed = 1337
	WorldState.current_run = 1
	WorldState.fire_warned.clear()
	WorldState.dev_hazard_mode = WorldState.DEV_HAZARD_FIRE
	WorldState.dev_fire_origin = 14               # floor 14 burns (LIGHT); floor 15 stands above it
	WorldState.current_floor = 15
	var rep: Dictionary = WorldState.get_listen_report_for_floor_below()
	check(str(rep.get("fire_line", "")) == str(WorldState.FIRE_WARN_LINES[WorldState.FIRE_LIGHT]), "the stairwell report carries the smoke line (%s)" % str(rep.get("fire_line")))
	check(WorldState.LISTEN_LINES_BELOW.values().has(rep["line"]) or WorldState.has_trait_flag("exact_hearing"), "...while the count line is untouched")
	var w1: String = WorldState.take_fire_warning(15)
	check(w1 == str(WorldState.FIRE_WARN_LINES[WorldState.FIRE_LIGHT]), "stepping up to the steps: a whiff of smoke")
	check(WorldState.take_fire_warning(15) == "", "...once per floor, not every time")
	check(WorldState.take_fire_warning(16) == "", "a floor above a clear one says nothing")
	WorldState.current_floor = 16
	check(str(WorldState.get_listen_report_for_floor_below().get("fire_line", "x")) == "", "no fire below, no fire line")
	# it escalates with the fire below
	WorldState.dev_hazard_mode = WorldState.DEV_HAZARD_FIRE2
	WorldState.dev_fire_origin = 14
	check(WorldState.fire_warning_line(14) == str(WorldState.FIRE_WARN_LINES[WorldState.FIRE_BLAZE]), "a blaze below: heat")
	WorldState.dev_hazard_mode = WorldState.DEV_HAZARD_FIRE3
	check(WorldState.fire_warning_line(14) == str(WorldState.FIRE_WARN_LINES[WorldState.FIRE_CHARRED]), "a burnt-out floor below: cold ash")
	# a new run is a new warning
	WorldState.dev_hazard_mode = WorldState.DEV_HAZARD_FIRE
	WorldState.current_run = 2
	check(WorldState.take_fire_warning(15) != "", "the next run warns again")
	WorldState.fire_warned.clear()
	WorldState.dev_hazard_mode = WorldState.DEV_HAZARD_NONE
	WorldState.dev_fire_origin = -1
	WorldState.current_run = 1
	WorldState.current_floor = 30


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


func _kinds_under(n: Node) -> Dictionary:
	var out := {}
	for c in n.find_children("*", "CPUParticles2D", true, false):
		if c.get("kind") != null and (c.emitting or c.kind == "billow"):
			out[c.kind] = int(out.get(c.kind, 0)) + 1
	return out


func _test_soft_smoke() -> void:
	# Owner round 8: the aftermath was "very ugly" (black circles) with "no smoke really". Smoke is now
	# soft particle emitters: burning ground smokes, a doused stretch BILLOWS then smoulders, bare
	# ground has none; the sprite plumes and blob scorch are gone.
	print("[soft smoke: fire smokes, doused billows + smoulders, bare is clean]")
	var ff = load("res://scripts/fire_field.gd").new()
	ff.stage = WorldState.FIRE_BLAZE
	ff.spread_cap = 1000000
	add_child(ff)
	ff.set_process(false)
	ff._sync_smoke()
	check(_kinds_under(ff).is_empty(), "no fire, no smoke")
	var mid: int = ff.cell_count / 2
	ff.ignite_span(ff.cell_x(mid - 2), ff.cell_x(mid + 2))
	ff._sync_smoke()
	var k1 := _kinds_under(ff)
	check(int(k1.get("fire", 0)) >= 2 and not k1.has("smoulder"), "burning cells smoke (%s)" % str(k1))
	ff.extinguish_at(ff.cell_x(mid), 300.0)
	ff._sync_smoke()
	var k2 := _kinds_under(ff)
	check(int(k2.get("billow", 0)) >= 1, "dousing billows (%s)" % str(k2))
	check(int(k2.get("smoulder", 0)) >= 1, "then it smoulders (%s)" % str(k2))
	check(not k2.has("fire") or int(k2.get("fire", 0)) == 0, "no fire smoke once it's out (%s)" % str(k2))
	check(not ff.has_method("_draw_smoke_plumes"), "the sprite smoke plumes are gone")
	ff.free()
	# Apartment fire: same smoke.
	var af = load("res://scripts/apartment_fire.gd").new()
	af.stage = WorldState.FIRE_BLAZE
	af.seed_salt = "1502"
	add_child(af)
	af.set_process(false)
	af._sync_smoke()
	var a1 := _kinds_under(af)
	check(int(a1.get("fire", 0)) == af._spots.size() and af._spots.size() > 0, "each burning spot smokes (%s)" % str(a1))
	af.extinguish_at(600.0, 2000.0)
	af._sync_smoke()
	var a2 := _kinds_under(af)
	check(int(a2.get("billow", 0)) >= 1 and int(a2.get("smoulder", 0)) >= 1, "a doused room billows + smoulders (%s)" % str(a2))
	af.free()
	# A corpse that died alight smoulders with the same soft smoke (not the old sprite blob).
	var bs = load("res://scripts/body_smoke.gd").new()
	add_child(bs)
	check(_kinds_under(bs).get("body", 0) == 1, "a burnt corpse smoulders softly")
	bs.free()
	await get_tree().process_frame


func _test_fire_art() -> void:
	# OUR fire (tools/art/fire.py → assets/fire/): every sheet the meta lists exists, is a strip of exactly its frames, is
	# lit (a hot heart), loops (first != last), sits on its base row, and beds taper to nothing at both ends.
	print("[fire art: our own strips, never cropped]")
	var meta: Dictionary = FireArt.meta()
	var sheets: Dictionary = meta.get("sheets", {})
	check(sheets.size() >= 30, "the fire meta lists the whole library (%d sheets)" % sheets.size())
	for prefix in ["bed_front_light", "bed_front_blaze", "bed_back_light", "bed_back_blaze", "tongue_s", "tongue_m", "tongue_l", "tongue_xl", "wall", "edge", "small", "runl_light", "run_light", "runr_light", "runl_blaze", "run_blaze", "runr_blaze"]:
		check(FireArt.variants(prefix).size() == 3, "%s has its 3 variants" % prefix)
	check(not FireArt.sheet("stair").is_empty(), "the stair fire strip exists")
	var bad: Array = []
	for name in sheets:
		var sh: Dictionary = FireArt.sheet(str(name))
		if sh.is_empty():
			bad.append(str(name) + ": missing")
			continue
		var img: Image = (sh["tex"] as Texture2D).get_image()
		var fw: int = sh["fw"]
		var fh: int = sh["fh"]
		var frames: int = sh["frames"]
		if img.get_width() != fw * frames or img.get_height() != fh:
			bad.append("%s: %dx%d is not %d frames of %dx%d" % [name, img.get_width(), img.get_height(), frames, fw, fh])
			continue
		var hot := 0
		var lit0 := 0
		var diff := 0
		var base_lit := 0
		for y in range(fh):
			for x in range(fw):
				var c0: Color = img.get_pixel(x, y)
				var c7: Color = img.get_pixel((frames - 1) * fw + x, y)
				if c0.a > 0.5:
					lit0 += 1
					if c0.r > 0.95 and c0.g > 0.8:   # a yellow-or-hotter heart
						hot += 1
				if absf(c0.r - c7.r) + absf(c0.g - c7.g) + absf(c0.a - c7.a) > 0.1:
					diff += 1
		for x in range(fw):
			if img.get_pixel(x, fh - 1).a > 0.5 or img.get_pixel(x, fh - 2).a > 0.5:
				base_lit += 1
		if lit0 < 20 or (hot < 2 and not str(name).begins_with("bed_") and not str(name).begins_with("small") and not str(name).begins_with("run")):   # (carpets are deliberately low + dim, and the burning-enemy flame is a few px — neither has a bright heart)
			bad.append("%s: not a fire (lit %d, hot %d)" % [name, lit0, hot])
		if diff < 6:
			bad.append("%s: doesn't animate (first vs last frame differ in %d px)" % [name, diff])
		if not str(name).begins_with("small") and base_lit < 2:
			bad.append("%s: nothing on its base row (it would float)" % name)
	check(bad.is_empty(), "every strip is well-formed, lit, animated and grounded %s" % str(bad.slice(0, 4)))
	# a bed clump fades out at both ends (so overlapped clumps never leave a cut)
	for v in FireArt.variants("bed_front_blaze"):
		var sh2: Dictionary = FireArt.sheet(str(v))
		var img2: Image = (sh2["tex"] as Texture2D).get_image()
		var edge_h := 0
		var mid_h := 0
		for fr in range(sh2["frames"]):
			for y in range(sh2["fh"]):
				if img2.get_pixel(fr * int(sh2["fw"]) + 0, y).a > 0.5:
					edge_h += 1
				if img2.get_pixel(fr * int(sh2["fw"]) + int(sh2["fw"]) / 2, y).a > 0.5:
					mid_h += 1
		check(edge_h * 2 < mid_h, "%s tapers at its ends (edge column %d lit vs middle %d)" % [v, edge_h, mid_h])
	# the old purchased fire is gone from the code (nothing still reads it)
	for path in ["res://scripts/fire_field.gd", "res://scripts/apartment_fire.gd", "res://scripts/enemy_fire.gd", "res://scripts/building_floors.gd", "res://scripts/fire_decal.gd"]:
		check(not FileAccess.get_file_as_string(path).contains("fire-pixel-art-animation-sprites"), "%s no longer loads the purchased fire" % path.get_file())
	check(FireArt.material().light_mode == CanvasItemMaterial.LIGHT_MODE_UNSHADED, "flames are unshaded (their own light)")


func _test_fire_layout() -> void:
	# The pure layout of the floor fire: clumps / tongues only over burning cells, never across a doorway or the stair
	# zone, tongues spaced, nothing once charred.
	print("[fire layout: clumps, tongues, walls]")
	WorldState.master_seed = 1337
	for st in [0, 1]:
		var ff = _make_field()
		ff.floor_num = 15
		ff.stage = st
		ff.ignite_span(ff.FIRE_MIN_X, ff.FIRE_MAX_X)
		ff.set_stair_fire(146.0, 26.0, 100.0, 235.0)
		var label := "blaze" if st == 1 else "light"
		for layer in ["front", "back"]:
			var spans: Array = ff.run_spans(layer)
			if layer == "back" and st == 0:
				check(spans.is_empty(), "light: no wall-seam carpet (a blaze only)")
				continue
			check(spans.size() >= 2, "%s %s carpet: runs along the burning floor (%d)" % [label, layer, spans.size()])
			var off := 0
			var overlap := 0
			var prev_x1 := -1.0e9
			for sp in spans:
				var x0: float = float(sp["x0"])
				var x1: float = float(sp["x1"])
				if ff._near_door(x0) or ff._near_door(x1) or ff._in_stair_keepout(x0) or ff._in_stair_keepout(x1) or not ff.is_burning_at(x0) or FireArt.sheet("run_%s_%d" % [sp["kit"], sp["v"]]).is_empty():
					off += 1
				if x0 < prev_x1:
					overlap += 1
				prev_x1 = x1
				var lay: Dictionary = FireArt.run_layout(str(sp["kit"]), int(sp["v"]), float(sp["w"]))
				if float(lay["total"]) < float(sp["w"]) - 0.01:
					off += 1
			check(off == 0, "%s %s carpet: each run starts and ends on burning floor off doorways / the stair zone, kit art real, drawn wide enough" % [label, layer])
			check(overlap == 0, "%s %s carpet: runs never overlap (no outline cutting through a neighbour)" % [label, layer])
			var bad_patch := 0
			var long_runs := 0
			var long_with := 0
			for sp in spans:
				if float(sp["x1"]) - float(sp["x0"]) >= ff.PATCH_MIN_SPAN and layer == "front":
					long_runs += 1
					if not (sp["patches"] as Array).is_empty():
						long_with += 1
				for pt in sp["patches"]:
					var px: float = float(pt["x"])
					if px < float(sp["x0"]) + ff.PATCH_END_MARGIN - 0.01 or px > float(sp["x1"]) - ff.PATCH_END_MARGIN + 0.01 or FireArt.sheet(str(pt["name"])).is_empty():
						bad_patch += 1
			check(bad_patch == 0, "%s %s carpet: front patches stay inside their run, off its ends, art real" % [label, layer])
			check(long_with == long_runs, "%s %s carpet: every long run has patches breaking its straight base (%d/%d)" % [label, layer, long_with, long_runs])
			if layer == "back":
				check(spans.all(func(sp): return (sp["patches"] as Array).is_empty()), "the wall-seam carpet takes no patches")
		var tongues: Array = ff.tongue_spots()
		check(tongues.size() >= 4, "%s: tongues rise from the carpet (%d)" % [label, tongues.size()])
		var prev := -1.0e9
		var tight := 0
		for t in tongues:
			if float(t["x"]) - prev < 60.0:
				tight += 1
			prev = float(t["x"])
		check(tight == 0, "%s: tongues are spaced (none closer than 60 px)" % label)
		if st == 1:
			var big := 0
			for t in tongues:
				if str(t["name"]).begins_with("tongue_l") or str(t["name"]).begins_with("tongue_xl"):
					big += 1
			check(big >= 1, "a blaze raises big tongues (%d)" % big)
		else:
			var any_big := false
			for t in tongues:
				if str(t["name"]).begins_with("tongue_l") or str(t["name"]).begins_with("tongue_xl"):
					any_big = true
			check(not any_big, "a light outbreak never raises the big ones")
		ff.extinguish_span(ff.FIRE_MIN_X, ff.FIRE_MAX_X)
		check(ff.run_spans("front").is_empty() and ff.tongue_spots().is_empty(), "%s: doused, nothing draws" % label)
		ff.free()
	var ch = _make_field()
	ch.floor_num = 15
	ch.stage = ch.STAGE_CHARRED
	ch.char_all()
	check(ch.run_spans("front").is_empty() and ch.tongue_spots().is_empty() and ch.wall_fire_spots().is_empty(), "a charred ruin has no live fire")
	ch.free()


# --- the EXTENSION kits: clean joins at the sides and the top (owner round 29b) -------------------------------------
func _col_top(img: Image, fr: int, fw: int, x: int) -> int:
	# the row (0 = top) of the first lit pixel in column x of frame `fr`; img height if the column is empty
	for y in range(img.get_height()):
		if img.get_pixel(fr * fw + x, y).a > 0.5:
			return y
	return img.get_height()


func _row_span(img: Image, fr: int, fw: int, y: int) -> Vector2i:
	# [first lit x, last lit x] in row y of frame `fr`; (-1, -1) if the row is empty
	var lo := -1
	var hi := -1
	for x in range(fw):
		if img.get_pixel(fr * fw + x, y).a > 0.5:
			if lo < 0:
				lo = x
			hi = x
	return Vector2i(lo, hi)


func _test_fire_extensions() -> void:
	print("[fire extensions: the run kit joins cleanly]")
	for stage in ["light", "blaze", "back"]:
		for v in [1, 2, 3]:
			var l: Dictionary = FireArt.sheet("runl_%s_%d" % [stage, v])
			var m: Dictionary = FireArt.sheet("run_%s_%d" % [stage, v])
			var r: Dictionary = FireArt.sheet("runr_%s_%d" % [stage, v])
			check(not l.is_empty() and not m.is_empty() and not r.is_empty(), "run kit %s_%d: cap, middle, cap all exist" % [stage, v])
			if l.is_empty() or m.is_empty() or r.is_empty():
				continue
			var w: int = m["fw"]
			var h: int = m["fh"]
			check(int(l["fw"]) == w and int(r["fw"]) == w and int(l["fh"]) == h and int(r["fh"]) == h, "run kit %s_%d: one piece size" % [stage, v])
			var il: Image = (l["tex"] as Texture2D).get_image()
			var im: Image = (m["tex"] as Texture2D).get_image()
			var ir: Image = (r["tex"] as Texture2D).get_image()
			var worst := 0
			var natural := 0                       # the steepest step between neighbouring columns INSIDE the tile (its own licks)
			var top_clear := true
			var l_end := 0
			var r_end := 0
			for fr in range(int(m["frames"])):
				for x in range(w - 1):
					natural = maxi(natural, absi(_col_top(im, fr, w, x) - _col_top(im, fr, w, x + 1)))
				# the middle tiles to itself: its right edge meets its own left edge
				worst = maxi(worst, absi(_col_top(im, fr, w, w - 1) - _col_top(im, fr, w, 0)))
				# a cap's join edge IS the middle's edge: l's right meets m's left, m's right meets r's left
				worst = maxi(worst, absi(_col_top(il, fr, w, w - 1) - _col_top(im, fr, w, 0)))
				worst = maxi(worst, absi(_col_top(im, fr, w, w - 1) - _col_top(ir, fr, w, 0)))
				# clean top: nothing touches row 0 in any piece
				for img in [il, im, ir]:
					for x in range(w):
						if img.get_pixel(fr * w + x, 0).a > 0.5:
							top_clear = false
				# the caps die to nothing at their open ends
				for y in range(h):
					if il.get_pixel(fr * w, y).a > 0.5:
						l_end += 1
					if ir.get_pixel(fr * w + w - 1, y).a > 0.5:
						r_end += 1
			check(worst <= natural, "run kit %s_%d: no join is steeper than the flame's own licks (join %d <= natural %d px)" % [stage, v, worst, natural])
			check(top_clear, "run kit %s_%d: nothing touches the top row (never cropped)" % [stage, v])
			check(l_end <= 8 * 3 and r_end <= 8 * 3, "run kit %s_%d: caps taper to nothing at their open ends (%d, %d)" % [stage, v, l_end, r_end])
	# layout maths: runs always cover the width (>= both caps)
	var lay: Dictionary = FireArt.run_layout("light", 1, 10.0)
	check(int(lay["n"]) == 0 and float(lay["total"]) >= 2.0 * float(lay["pw"]), "a run narrower than its caps is just the two caps")
	for want in [100.0, 150.0, 333.0]:
		var lay2: Dictionary = FireArt.run_layout("blaze", 2, want)
		check(float(lay2["total"]) >= want and float(lay2["total"]) < want + float(lay2["pw"]) + 0.01, "a run for %d px covers it with < one piece spare" % int(want))
