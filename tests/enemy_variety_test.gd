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
	_test_mix_totals_valid()
	await _test_new_type_scenes()
	await _test_new_types_settle()
	_test_all_types_appear_run3()
	await _test_spitter_spits()
	await _test_spit_crouch_dodge()
	_test_variety_and_flavor()
	await _test_corridor_boss()
	await _test_run_opening_grace()
	await _test_crawler_behaviour()
	await _test_enemy_reach()
	await _test_standard_key_full_pockets()
	await _test_hurt_state()
	await _test_hurt_targeting()
	await _test_burning_big_doubles()
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
	# Drop the floor's Player so the test enemy has no target to beat to death — a
	# player death would fire the death->time-skip flow (change_scene) and free THIS
	# test scene mid-run (a hang). We only care that the body settles on its line.
	var _pl = bf.get_node_or_null("Player")
	if _pl != null:
		_pl.queue_free()
	for i in range(6):
		await get_tree().process_frame
	var big = load("res://scenes/enemy_zombie_big.tscn").instantiate()
	bf.add_child(big)
	big.global_position = Vector2(640, 388.0)      # overlapping the floor, as a live spawn does
	for i in range(80):                            # fully settles by ~frame 60 (measured)
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


const NEW_TYPES := {
	"zombie_crawler": ["res://scenes/enemy_zombie_crawler.tscn", "crawler"],
	"zombie_longarm": ["res://scenes/enemy_zombie_longarm.tscn", "longarm"],
	"zombie_spitter": ["res://scenes/enemy_zombie_spitter.tscn", "spitter"],
}


func _test_mix_totals_valid() -> void:
	# A mis-tune that pushes the special chances past 1.0 for any (band,run) would make
	# some slots impossible / the standard vanish. Guard the whole table stays < 1.
	print("[mix totals stay under 1.0]")
	var worst := 0.0
	for band in range(3):
		for r in range(3):
			var total: float = WorldState.HEAVY_CHANCE[band][r] + WorldState.CRAWLER_CHANCE[band][r] \
				+ WorldState.LONGARM_CHANCE[band][r] + WorldState.SPITTER_CHANCE[band][r]
			worst = maxf(worst, total)
	check(worst < 1.0, "every (band,run) leaves room for standards (worst sum %.2f)" % worst)


func _test_new_type_scenes() -> void:
	# Each new scene instantiates, joins the shared zombie group + its own, and carries
	# the full animation set the AI plays.
	print("[new type scenes]")
	WorldState.new_game()
	for id in NEW_TYPES:
		var scene = load(NEW_TYPES[id][0])
		check(scene != null, "%s scene loads" % id)
		var z = scene.instantiate()
		add_child(z)
		await get_tree().process_frame
		check(z.is_in_group("zombie"), "%s is in the shared 'zombie' group" % id)
		check(z.is_in_group(NEW_TYPES[id][1]), "%s is in its own group" % id)
		var spr = z.get_node_or_null("AnimatedSprite2D")
		var ok := spr != null
		if ok:
			for anim in ["Idle", "Walk", "Attack", "Hit", "Death"]:
				if not spr.sprite_frames.has_animation(anim):
					ok = false
		check(ok, "%s has Idle/Walk/Attack/Hit/Death animations" % id)
		z.queue_free()
		await get_tree().process_frame


func _test_new_types_settle() -> void:
	# Each new rig's feet land on the 419 floor line (origin 374) — no float, no sink,
	# so a pan-backdrop copy placed at ENEMY_SETTLED_Y doesn't warp on arrival. One floor
	# shared for all three; each settles within a handful of physics frames (break early).
	print("[new types settle on the floor line]")
	WorldState.new_game()
	WorldState.current_floor = 12
	var bf = load("res://scenes/building_floors.tscn").instantiate()
	bf.setup_floor = 12
	add_child(bf)
	# Drop the Player so the test enemies can't kill it (death -> time-skip -> scene
	# change would free this test scene mid-run). We only measure their settle line.
	var _pl = bf.get_node_or_null("Player")
	if _pl != null:
		_pl.queue_free()
	for i in range(4):
		await get_tree().process_frame
	for id in NEW_TYPES:
		var z = load(NEW_TYPES[id][0]).instantiate()
		bf.add_child(z)
		z.global_position = Vector2(640, 388.0)
		for i in range(80):                 # fully settles by ~frame 60 (measured)
			await get_tree().process_frame
		var want: float = bf.ENEMY_SETTLED_Y[id]
		check(absf(z.global_position.y - want) <= 1.5, "%s settles on its line (%.1f vs %.1f)" % [id, z.global_position.y, want])
		z.queue_free()
		await get_tree().process_frame
	bf.queue_free()
	await get_tree().process_frame


func _test_all_types_appear_run3() -> void:
	# Night, deep down: over a big sample, ALL FOUR special types show up (the mix is
	# actually wired, not just the heavy).
	print("[all types appear at night, deep down]")
	WorldState.new_game()
	WorldState.current_run = 3
	var seen := {}
	for i in range(600):
		seen[WorldState.enemy_type_for(4, "4:%d:388" % (150 + i * 2))] = true
	for id in ["zombie_big", "zombie_crawler", "zombie_longarm", "zombie_spitter", "zombie_standard"]:
		check(seen.has(id), "%s appears in the run-3 deep mix" % id)


func _test_spitter_spits() -> void:
	# The Spitter's attack beat launches a projectile toward the player (ranged), not a
	# melee hit — and the projectile travels. Standalone (no floor build): a dummy target
	# stands in for the player so the spit has a direction to fly.
	print("[spitter launches a projectile]")
	WorldState.new_game()
	var holder := Node2D.new()
	add_child(holder)
	var target := Node2D.new()
	target.global_position = Vector2(700, 374.0)
	holder.add_child(target)
	var sp = load("res://scenes/enemy_zombie_spitter.tscn").instantiate()
	holder.add_child(sp)
	sp.global_position = Vector2(400, 374.0)
	await get_tree().process_frame
	sp.player = target
	var before := _count_spit(holder)
	sp._deliver_attack(250.0)
	await get_tree().process_frame
	var after := _count_spit(holder)
	check(after > before, "a spit projectile is launched on the attack beat (%d -> %d)" % [before, after])
	var proj = _first_spit(holder)
	if proj != null:
		var x0: float = proj.global_position.x
		for i in range(8):
			await get_tree().process_frame
			if not is_instance_valid(proj):
				break
		check(not is_instance_valid(proj) or proj.global_position.x > x0, "the spit travels toward the player (+x)")
	holder.queue_free()
	await get_tree().process_frame


func _test_spit_crouch_dodge() -> void:
	# A CROUCHING player ducks under the spit (it sails over — a ranged dodge); STANDING takes
	# the hit. Uses a minimal player-group stub so we can count receive_hit precisely.
	print("[spit crouch dodge]")
	var StubScript := GDScript.new()
	StubScript.source_code = "extends Node2D\nvar is_crouching := false\nvar hits := 0\nfunc receive_hit(_d): hits += 1\n"
	StubScript.reload()
	for crouching in [true, false]:
		var target = StubScript.new()
		target.add_to_group("player")
		add_child(target)
		target.global_position = Vector2(700, 374.0)
		target.is_crouching = crouching
		await get_tree().process_frame
		var proj = load("res://scripts/spit_projectile.gd").new()
		proj.launch(1.0)
		add_child(proj)
		proj.global_position = Vector2(650, 374.0)   # left of target, flies right through its x
		for i in range(40):
			await get_tree().physics_frame
			if not is_instance_valid(proj):
				break
		if crouching:
			check(target.hits == 0, "crouching player DUCKS the spit (hits %d)" % target.hits)
		else:
			check(target.hits == 1, "standing player is HIT by the spit (hits %d)" % target.hits)
		if is_instance_valid(proj):
			proj.queue_free()
		target.queue_free()
		await get_tree().process_frame


func _test_crawler_behaviour() -> void:
	# The Crawler is SLOW and hits for DOUBLE. A push is now a GENERAL push on it too
	# (real knockback, like every other enemy — the old Crawler-only kick-stun was
	# dropped). Plus its run-1 frequency is ~3:1 standards across the building.
	print("[crawler behaviour: slow, double dmg, general push, 3:1]")
	WorldState.new_game()
	var std = load("res://scenes/enemy_zombie_standard.tscn").instantiate()
	add_child(std)
	await get_tree().process_frame
	var std_speed: float = std.SPEED
	std.queue_free()
	var cr = load("res://scenes/enemy_zombie_crawler.tscn").instantiate()
	add_child(cr)
	await get_tree().process_frame
	check(cr.SPEED < std_speed, "crawler is slower than a standard (%.0f < %.0f)" % [cr.SPEED, std_speed])
	check(cr.ATTACK_DAMAGE == 2, "crawler bite does DOUBLE damage (ATTACK_DAMAGE=%d)" % cr.ATTACK_DAMAGE)
	# General push: a shove now imparts real knockback velocity (not a rooted stun).
	check(cr.has_method("receive_push"), "crawler supports a general push")
	cr.receive_push(150.0)
	check(absf(cr.velocity.x) > 0.01, "a push knocks the crawler back (vel=%.1f)" % cr.velocity.x)
	# Its collision box is TALLER now so the shove connects even into the blank space
	# above the low body (measured against the standard's box height).
	var cr_shape = cr.get_node_or_null("CollisionShape2D")
	check(cr_shape != null and cr_shape.shape is RectangleShape2D and cr_shape.shape.size.y >= 50.0,
		"crawler collision box is taller (%.0f px)" % (cr_shape.shape.size.y if cr_shape != null and cr_shape.shape is RectangleShape2D else -1.0))
	cr.queue_free()
	await get_tree().process_frame
	# Run-1 frequency ~3:1 through the mid/deep floors. Sample ACROSS many LOW+MID floors (all
	# 0.25 crawler in run 1, clean of the top taper) so the fraction converges to ~0.25 regardless
	# of seed — enemy_type_for's per-slot RNG (one draw off a per-key hash) can bias a single
	# floor's small sample otherwise.
	WorldState.current_run = 1
	var craw := 0
	var total := 0
	for f in range(3, 19):
		for i in range(45):
			total += 1
			if WorldState.enemy_type_for(f, "%d:%d:388" % [f, 150 + i * 7]) == "zombie_crawler":
				craw += 1
	var frac := float(craw) / float(total)
	check(frac >= 0.18 and frac <= 0.32, "run-1 crawlers are ~1-in-4 through the mid/deep floors (%.2f)" % frac)
	# Run-1 TOP is mostly regulars: the 2nd floor down (29) carries FAR fewer crawlers than the
	# deep swarm, so two landing side-by-side up top is highly unlikely (owner ask).
	var top := 0
	var deep := 0
	for i in range(600):
		if WorldState.enemy_type_for(29, "29:%d:388" % (150 + i * 2)) == "zombie_crawler":
			top += 1
		if WorldState.enemy_type_for(5, "5:%d:388" % (150 + i * 2)) == "zombie_crawler":
			deep += 1
	check(float(top) / 600.0 < 0.10, "run-1 top (floor 29) is light on crawlers (%.3f)" % (float(top) / 600.0))
	check(deep > top * 3, "the crawler swarm concentrates deep, not up top (%d deep vs %d top)" % [deep, top])


func _special_share(band: int, run: int) -> float:
	return WorldState.HEAVY_CHANCE[band][run] + WorldState.CRAWLER_CHANCE[band][run] \
		+ WorldState.LONGARM_CHANCE[band][run] + WorldState.SPITTER_CHANCE[band][run]


func _run3_lead(band: int) -> String:
	# Which special type is most common in this band at night (the band's "flavour").
	var best := ""
	var best_v := -1.0
	for pair in [["big", WorldState.HEAVY_CHANCE], ["crawler", WorldState.CRAWLER_CHANCE], ["longarm", WorldState.LONGARM_CHANCE], ["spitter", WorldState.SPITTER_CHANCE]]:
		var v: float = pair[1][band][2]
		if v > best_v:
			best_v = v
			best = String(pair[0])
	return best


func _test_variety_and_flavor() -> void:
	# The rebalance's intent, locked: (1) runs 2/3 carry MORE new enemies, including up
	# the building; (2) no single type dominates (variety); (3) each section has a
	# distinct lead type so descending doesn't feel samey.
	print("[variety + sectional flavour]")
	# (1) more new enemies in runs 2/3 — MID and HIGH are no longer sparse.
	check(_special_share(1, 1) >= 0.30, "MID run2 has a real special share (%.2f)" % _special_share(1, 1))
	check(_special_share(1, 2) >= 0.55, "MID run3 is heavily mixed (%.2f)" % _special_share(1, 2))
	check(_special_share(2, 1) >= 0.18, "HIGH run2 is no longer near-empty (%.2f)" % _special_share(2, 1))
	check(_special_share(2, 2) >= 0.40, "HIGH run3 is well mixed (%.2f)" % _special_share(2, 2))
	# (2) variety in the MIXED runs (2/3) — no special type exceeds a cap in a cell there
	# (was: big at 0.30 dominating). Run 1 is exempt: the crawler is deliberately the
	# run-1 swarm at ~0.25 (see below), which isn't "dominating" — it's 1-in-4 vs standards.
	var peak := 0.0
	for t in [WorldState.HEAVY_CHANCE, WorldState.CRAWLER_CHANCE, WorldState.LONGARM_CHANCE, WorldState.SPITTER_CHANCE]:
		for band in range(3):
			for r in range(1, 3):
				peak = maxf(peak, t[band][r])
	check(peak <= 0.24, "no single special type dominates a run-2/3 cell (peak %.2f <= 0.24)" % peak)
	# (3) sectional flavour at night: LOW = swarm (crawler/big), MID = long-arm bruisers,
	# HIGH = ranged spitters. The lead type differs by section.
	check(_run3_lead(0) in ["crawler", "big"], "LOW night lead is the swarm (%s)" % _run3_lead(0))
	check(_run3_lead(1) == "longarm", "MID night lead is the long-arm bruiser (%s)" % _run3_lead(1))
	check(_run3_lead(2) == "spitter", "HIGH night lead is the ranged spitter (%s)" % _run3_lead(2))
	check(_run3_lead(0) != _run3_lead(2), "the deep floors and the top floors feel different at night")
	# The MIGRATING types (big / long-arm / spitter) only ever grow across runs.
	var mono := true
	for t in [WorldState.HEAVY_CHANCE, WorldState.LONGARM_CHANCE, WorldState.SPITTER_CHANCE]:
		for band in range(3):
			for r in range(1, 3):
				if t[band][r] < t[band][r - 1]:
					mono = false
	check(mono, "the migrating types only grow run to run")
	# The Crawler is FRONT-LOADED: the run-1 early swarm. It concentrates DEEP (LOW/MID ~0.25,
	# where the outbreak is worst) and THINS toward the TOP (HIGH run 1 only occasional), so a
	# fresh character on the first floors down meets mostly regulars — no two-crawler ambush on
	# the 2nd floor down (owner ask). Its run-1 value is its peak per band (front-loaded).
	var craw_ok := true
	if WorldState.CRAWLER_CHANCE[0][0] < 0.20 or WorldState.CRAWLER_CHANCE[1][0] < 0.20:
		craw_ok = false                     # a real run-1 swarm deep (LOW) and mid (MID)
	if WorldState.CRAWLER_CHANCE[2][0] >= WorldState.CRAWLER_CHANCE[0][0]:
		craw_ok = false                     # HIGH (top) run-1 is thinned vs the deep swarm
	for band in range(3):
		if WorldState.CRAWLER_CHANCE[band][0] < WorldState.CRAWLER_CHANCE[band][1]:
			craw_ok = false                 # run 1 is its peak per band (front-loaded, not monotonic)
	check(craw_ok, "crawler front-loaded: run-1 swarm deep, thinned up top, its peak per band")
	# Run 1's OTHER new types stay a deep-only taste (only big, low floors).
	check(WorldState.LONGARM_CHANCE[0][0] == 0.0 and WorldState.SPITTER_CHANCE[0][0] == 0.0, "run 1 has no long-arm/spitter yet")
	check(WorldState.HEAVY_CHANCE[1][0] == 0.0 and WorldState.HEAVY_CHANCE[2][0] == 0.0, "run 1 heavies stay deep only")


func _test_run_opening_grace() -> void:
	# The descent starts at 30, so 29/28/27 are the fresh-character opening of EVERY run. They
	# get a grace: NO corridor boss, and tough types (heavy/long-arm/spitter) scaled down — so a
	# gearless run-2/3 start isn't walled. Bosses + full-strength tough types resume at floor 26.
	print("[run-opening grace]")
	WorldState.new_game()
	WorldState.master_seed = 20240117          # fixed so the statistical samples are deterministic
	WorldState.tutorial_completed = true
	WorldState.is_first_run = false
	var no_open_boss := true
	for run in [2, 3]:
		WorldState.current_run = run
		for f in [27, 28, 29]:
			if WorldState.floor_has_boss(f):
				no_open_boss = false
	check(no_open_boss, "no corridor boss on the opening floors 27-29 (runs 2/3)")
	check(WorldState.run_opening_ease(29) < WorldState.run_opening_ease(27),
		"the ease deepens toward the top (29 %.2f < 27 %.2f)" % [WorldState.run_opening_ease(29), WorldState.run_opening_ease(27)])
	check(WorldState.run_opening_ease(26) == 1.0, "floor 26 is full strength (past the opening)")
	# Tough types are rarer on floor 29 than floor 26 at night (the ease actually bites).
	WorldState.current_run = 3
	var tough29 := 0
	var tough26 := 0
	for i in range(400):
		var t29: String = WorldState.enemy_type_for(29, "29:%d:388" % (100 + i * 3))
		var t26: String = WorldState.enemy_type_for(26, "26:%d:388" % (100 + i * 3))
		if t29 == "zombie_big" or t29 == "zombie_longarm" or t29 == "zombie_spitter":
			tough29 += 1
		if t26 == "zombie_big" or t26 == "zombie_longarm" or t26 == "zombie_spitter":
			tough26 += 1
	check(tough29 < tough26, "opening floor 29 carries fewer weapon-needing enemies than floor 26 (%d < %d)" % [tough29, tough26])
	# Bosses remain possible below the opening stretch (deterministic table intent — no seed
	# gamble: positive chance at floor 26 and down, forced to zero on the graced 27-29).
	WorldState.current_run = 2
	check(WorldState.floor_boss_chance(26) > 0.0 and WorldState.floor_boss_chance(2) > 0.0,
		"bosses possible below the opening stretch (fl26 %.2f / fl2 %.2f)" % [WorldState.floor_boss_chance(26), WorldState.floor_boss_chance(2)])
	await get_tree().process_frame


func _test_corridor_boss() -> void:
	# Corridor bosses appear only in runs 2/3, are tougher, drop NO key but better loot,
	# and stand on the floor line. Deterministic per (floor, run).
	print("[corridor boss]")
	WorldState.new_game()
	WorldState.tutorial_completed = true
	WorldState.is_first_run = false
	# Run 1: NEVER (deterministic — BOSS_CHANCE run-1 column is all 0, so floor_boss_chance
	# is 0 and the roll can't pass). Not a seed gamble.
	WorldState.current_run = 1
	var r1 := 0
	for f in range(2, 30):
		if WorldState.floor_has_boss(f):
			r1 += 1
	check(r1 == 0, "no corridor bosses in run 1 (%d)" % r1)
	# Runs 2/3 CAN set bosses (deterministic table intent — no seed gamble): positive
	# chances, and run 3 is at least as likely as run 2 per band.
	var boss_intent := true
	for band in range(3):
		if WorldState.BOSS_CHANCE[band][1] <= 0.0 or WorldState.BOSS_CHANCE[band][2] <= 0.0:
			boss_intent = false
		if WorldState.BOSS_CHANCE[band][2] < WorldState.BOSS_CHANCE[band][1]:
			boss_intent = false
	check(boss_intent, "runs 2/3 can set bosses; run 3 >= run 2 per band")
	# Find an actual boss floor across runs 2 and 3 (P(none in either) is negligible) to
	# inspect a live one.
	var boss_floor := -1
	var boss_run := 2
	for run in [2, 3]:
		WorldState.current_run = run
		for f in range(2, 30):
			if WorldState.floor_has_boss(f):
				boss_floor = f
				boss_run = run
				break
		if boss_floor > 0:
			break
	check(boss_floor > 0, "a boss floor exists to inspect (floor %d, run %d)" % [boss_floor, boss_run])
	WorldState.current_run = boss_run
	# Determinism.
	if boss_floor > 0:
		check(WorldState.floor_has_boss(boss_floor) == WorldState.floor_has_boss(boss_floor), "floor_has_boss is deterministic")
	# The loot roll returns a valid pool id.
	var pool_ids := {}
	for entry in WorldState.BOSS_LOOT_POOL:
		pool_ids[String(entry[0])] = true
	check(pool_ids.has(WorldState.boss_loot_item("boss:%d:%d" % [boss_floor, boss_run])), "boss loot is drawn from the good-loot pool")
	# Spawn the boss floor and inspect the live boss.
	if boss_floor < 0:
		return
	WorldState.current_floor = boss_floor
	var bf = load("res://scenes/building_floors.tscn").instantiate()
	bf.setup_floor = boss_floor
	add_child(bf)
	var _pl = bf.get_node_or_null("Player")
	if _pl != null:
		_pl.queue_free()                    # no target — don't let the boss trigger a death/skip
	for i in range(80):
		await get_tree().process_frame
	var bosses := get_tree().get_nodes_in_group("corridor_boss")
	var mine := []
	for b in bosses:
		if bf.is_ancestor_of(b):
			mine.append(b)
	check(mine.size() == 1, "exactly one corridor boss on a boss floor (%d)" % mine.size())
	if mine.size() == 1:
		var boss = mine[0]
		check(not boss.drops_key, "the corridor boss drops NO key")
		check(boss.is_in_group("big_zombie"), "it's a Big Zombie under the hood")
		check(boss.max_hp >= 12, "it's a real wall of HP (%d)" % boss.max_hp)
		check(absf(boss.global_position.y - bf.BIG_ZOMBIE_SETTLED_Y) <= 1.5, "it stands on the floor line (%.1f)" % boss.global_position.y)
	bf.queue_free()
	await get_tree().process_frame


func _count_spit(node: Node) -> int:
	var n := 0
	for c in node.get_children():
		if c.get_script() != null and str(c.get_script().resource_path).ends_with("spit_projectile.gd"):
			n += 1
		n += _count_spit(c)
	return n


func _first_spit(node: Node):
	for c in node.get_children():
		if c.get_script() != null and str(c.get_script().resource_path).ends_with("spit_projectile.gd"):
			return c
		var r = _first_spit(c)
		if r != null:
			return r
	return null


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


# --- repair pass: enemy reach -------------------------------------------------------------

func _hits_on_still_player(kind: String) -> Dictionary:
	# A real corridor floor, one enemy walking at a STILL, solid player for 5s. Returns the
	# closest horizontal approach and the damage dealt.
	WorldState.new_game()
	WorldState.is_first_run = false
	WorldState.tutorial_completed = true
	WorldState.god_mode = false
	WorldState.current_floor = 12
	WorldState.seed_floor_door_states(12)
	var bf = load("res://scenes/building_floors.tscn").instantiate()
	add_child(bf)
	await get_tree().physics_frame
	for z in get_tree().get_nodes_in_group("zombie"):
		if bf.is_ancestor_of(z):
			z.free()
	var p = bf.get_node("Player")
	p.global_position = Vector2(600, 386)
	var z = load("res://scenes/enemy_zombie_%s.tscn" % kind).instantiate()
	z.global_position = Vector2(680, 370 if kind == "standard" else 374)
	bf.add_child(z)
	var dmg := 0
	var mind := 9999.0
	for i in range(60 * 5):
		await get_tree().physics_frame
		p.velocity = Vector2.ZERO
		mind = minf(mind, absf(z.global_position.x - p.global_position.x))
		if p.health_state != 0:
			dmg += int(p.health_state)
			p.health_state = 0
			WorldState.player_health = 0
			p.is_dying = false
			WorldState.is_dying = false
	var out := {"dmg": dmg, "min_dx": mind, "reach": z._attack_reach() if z.has_method("_attack_reach") else float(z.ATTACK_RANGE)}
	bf.free()
	await get_tree().process_frame
	return out


func _test_enemy_reach() -> void:
	# The AI measured reach ORIGIN-to-origin (euclidean), folding the rigs' origin gap into
	# every check, and never allowed for body width: the 80px crawler is stopped 53px from the
	# player by collision, beyond its 30px range — it could NEVER bite a solid player.
	print("[enemy reach: horizontal, never shorter than contact]")
	for kind in ["standard", "crawler", "longarm", "big"]:
		var r: Dictionary = await _hits_on_still_player(kind)
		check(r["dmg"] > 0, "%s lands hits on a still, solid player (dmg %d, closest %.1f, reach %.1f)" % [kind, r["dmg"], r["min_dx"], r["reach"]])
		check(r["min_dx"] <= r["reach"] + 0.5, "%s's reach covers the gap it can close to" % kind)
	# Reach numbers: designed range kept, contact + 7 for wide bodies.
	var std = load("res://scenes/enemy_zombie_standard.tscn").instantiate()
	add_child(std)
	check(absf(std._attack_reach() - 30.0) < 0.01, "standard reach stays its designed 30 (%.1f)" % std._attack_reach())
	std.free()
	var la = load("res://scenes/enemy_zombie_longarm.tscn").instantiate()
	add_child(la)
	check(absf(la._attack_reach() - 62.0) < 0.01, "long-arm reach stays its designed 62 (%.1f)" % la._attack_reach())
	la.free()


func _test_standard_key_full_pockets() -> void:
	# A standard zombie carrying a key (the tutorial neighbour's 3002 key) killed with full
	# pockets only REGISTERED it mid-air — no pickup until re-entry, and that key gates the stairs.
	print("[a key-carrier killed with full pockets drops a live key]")
	WorldState.new_game()
	WorldState.current_floor = 30
	WorldState.inventory.clear()
	for id in ["002", "006", "007", "009", "019"]:
		WorldState.add_to_inventory(id)
	var holder := Node2D.new()
	add_child(holder)
	var z = load("res://scenes/enemy_zombie_standard.tscn").instantiate()
	z.global_position = Vector2(500, 370)
	holder.add_child(z)
	z.set_physics_process(false)
	z.key_target_apartment = "3002"
	z._drop_key()
	var live = null
	for c in holder.get_children():
		if c != z and c.get("item_id") == "022":
			live = c
	check(live != null, "the key lands as a live pickup")
	var on_floor := false
	for k in WorldState.world_drops:
		var d = WorldState.world_drops[k]
		if d["item_id"] == "022" and d.get("target_apartment", "") == "3002":
			on_floor = float(d["y"]) > 400.0      # rests by the feet (419 - REST_LIFT), not mid-air at 370
	check(on_floor, "it's registered on the floor, not at the corpse's origin")
	holder.free()
	WorldState.inventory.clear()


# --- the HURT state (scripts/enemy_hurt.gd) -------------------------------------------------

func _corridor() -> Node:
	WorldState.new_game()
	WorldState.is_first_run = false
	WorldState.tutorial_completed = true
	WorldState.god_mode = false
	WorldState.current_floor = 12
	WorldState.seed_floor_door_states(12)
	var bf = load("res://scenes/building_floors.tscn").instantiate()
	add_child(bf)
	await get_tree().physics_frame
	for z in get_tree().get_nodes_in_group("zombie"):
		if bf.is_ancestor_of(z):
			z.free()
	return bf


func _test_hurt_state() -> void:
	# Owner: a hurt enemy blinks white and doesn't attack — but is NEVER immune (a knocked-down one
	# used to shrug off every hit for 3s).
	print("[hurt: blink, no attacks, never immune]")
	var bf = await _corridor()
	var p = bf.get_node("Player")
	p.global_position = Vector2(600, 386)
	var z = load("res://scenes/enemy_zombie_standard.tscn").instantiate()
	z.global_position = Vector2(620, 370)
	bf.add_child(z)
	await get_tree().physics_frame
	z.current_hp = 20
	z.receive_damage(1, "blade")
	check(z.is_hurt() and z.state == "hit", "a non-lethal hit leaves it HURT (state %s)" % z.state)
	check(load("res://scripts/enemy_hurt.gd").is_blinking(z), "it blinks white")
	check(z.passable_to_player, "it can be slipped past while hurt")
	# Right next to the player, it does NOT attack for the hurt window.
	var dmg := 0
	for i in range(int(z.HURT_TIME * 60.0) - 2):
		await get_tree().physics_frame
		p.velocity = Vector2.ZERO
		dmg += int(p.health_state)
		p.health_state = 0
	check(dmg == 0, "no attacks while hurt (%d)" % dmg)
	# Knocked down: still takes damage.
	z._knockdown()
	var hp1: int = z.current_hp
	z.receive_damage(2, "blade")
	check(z.current_hp == hp1 - 2, "a knocked-down enemy still takes hits (%d -> %d)" % [hp1, z.current_hp])
	check(z.state == "knockdown", "and stays down")
	bf.free()
	await get_tree().process_frame


func _test_hurt_targeting() -> void:
	# A swing prefers an UNHURT enemy in reach over a nearer hurt one; hammering hurt ones in a row
	# costs up to +10% accuracy (5%, then 10%).
	print("[hurt: target priority + miss ramp]")
	var bf = await _corridor()
	var p = bf.get_node("Player")
	p.global_position = Vector2(600, 386)
	p.animated_sprite.flip_h = false
	var near = load("res://scenes/enemy_zombie_standard.tscn").instantiate()
	near.global_position = Vector2(625, 370)
	bf.add_child(near)
	var far = load("res://scenes/enemy_zombie_standard.tscn").instantiate()
	far.global_position = Vector2(640, 370)
	bf.add_child(far)
	await get_tree().physics_frame
	for z in [near, far]:
		z.set_physics_process(false)
		z.current_hp = 20
	near.hurt_timer = 0.5            # the nearer one is already hurt
	var w := ItemInstance.new()
	w.setup("003")
	WorldState.inventory = [w]
	WorldState.stamina = WorldState.get_max_stamina()
	p._hurt_streak = 0
	p.is_attacking = false
	p._do_melee_attack(w, 0)
	check(far.current_hp < 20 and near.current_hp == 20, "the swing takes the UNHURT one, not the nearer hurt one (near %d, far %d)" % [near.current_hp, far.current_hp])
	# Miss ramp (roll injected).
	p._hurt_streak = 0
	check(not p._hurt_miss(near, 0.051) and p._hurt_streak == 1, "1st hit on a hurt enemy: 5%% (0.051 lands)")
	p._hurt_streak = 0
	check(p._hurt_miss(near, 0.049), "1st hit on a hurt enemy: 5%% (0.049 misses)")
	check(p._hurt_miss(near, 0.099), "2nd in a row: 10%% (0.099 misses)")
	check(not p._hurt_miss(near, 0.101), "3rd in a row: capped at 10%% (0.101 lands)")
	far.hurt_timer = 0.0
	far.state = "idle"
	check(not p._hurt_miss(far, 0.0) and p._hurt_streak == 0, "an unhurt target never misses this way, and resets the streak")
	WorldState.inventory = []
	bf.free()
	await get_tree().process_frame


func _test_burning_big_doubles() -> void:
	# Every enemy alight hits twice as hard — the big zombie too (it used to stay at 2).
	print("[a burning big zombie hits double]")
	var bf = await _corridor()
	var p = bf.get_node("Player")
	p.global_position = Vector2(600, 386)
	var big = load("res://scenes/enemy_zombie_big.tscn").instantiate()
	big.global_position = Vector2(640, 374)
	bf.add_child(big)
	await get_tree().physics_frame
	big.on_fire = true
	big.player = p
	big.state = "attack"
	big.state_timer = 0.0
	p.health_state = 0
	await get_tree().physics_frame
	check(int(p.health_state) == 4, "an alight big hits for 4 (got %d)" % int(p.health_state))
	p.health_state = 0
	p.is_dying = false
	WorldState.is_dying = false
	bf.free()
	await get_tree().process_frame
