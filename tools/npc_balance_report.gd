extends Node

# NPC BALANCE REPORT — measures what survivors, quests and the dead's new brain actually do, with the real scenes and the
# real rules, so the numbers in docs/NPC_AI.md and docs/QUESTS.md can be judged against data. Headless:
#   godot --headless res://tools/npc_balance_report.tscn -- --only=quests,census,loot,fights,waiter --trials=12
# Sections (default: quests,census,loot — the quick ones; `fights` and `waiter` run real physics and take minutes):
#   quests  where Johnny / Ethel end up over many seeds — does every playthrough have them, on which floors
#   census  how many survivors a full descent meets, by role and run
#   loot    bullets in the real apartments (Johnny asks for 10, then 20 more)
#   fights  a defender against 1-4 dead, by weapon and by Johnny's own loadout; and the gunshot "magnet"
#   waiter  a waiter at the lift with the dead about it: how long it lives, what gathers
#   floors  ordinary defenders on the REAL floors (the natural dead, real types and counts), 60 s with the player passive
#   johnny  Johnny on his real floor, 90 s with the player passive — does the quest giver live to be met?
# Runs in the test sandbox (res://tools/ → WorldState.data_dir()), never the player's saves.

const STANDARD := "res://scenes/enemy_zombie_standard.tscn"
const FEET := 419.0

var _only: Array = ["quests", "census", "loot"]
var _trials := 12
var _speed := 8                     # physics runs this many times faster than real time (the per-step delta stays 1/60 s)
var _bf: Node = null


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			_only = a.substr(7).split(",")
		elif a.begins_with("--trials="):
			_trials = maxi(1, int(a.substr(9)))
		elif a.begins_with("--speed="):
			_speed = clampi(int(a.substr(8)), 1, 16)
	await get_tree().process_frame
	# The fights this tool measures are the REAL half-damage ones (the maths behind the show); survivors fight for show in the shipped
	# game (AllyCombat.performative, round 41), where there is nothing to measure — every fight is a draw by design.
	AllyCombat.performative = false
	# Headless physics is paced in real time; raising the tick rate AND the time scale together keeps each step's delta at
	# exactly 1/60 s (so every rule behaves as in play) while running `_speed` times faster.
	Engine.physics_ticks_per_second = 60 * _speed
	Engine.max_physics_steps_per_frame = 64
	Engine.time_scale = float(_speed)
	if "quests" in _only:
		_quests()
	if "census" in _only:
		_census()
	if "loot" in _only:
		await _loot()
	if "fights" in _only:
		await _fights()
	if "waiter" in _only:
		await _waiter()
	if "floors" in _only:
		await _natural_floors()
	if "johnny" in _only:
		await _johnny_floor()
	print("=== done ===")
	get_tree().quit(0)


func _fresh_world(seed_value: int, run: int = 1) -> void:
	WorldState.dev_seed = seed_value
	WorldState.new_game()
	WorldState.dev_seed = 0
	WorldState.is_first_run = false
	WorldState.tutorial_completed = true
	WorldState.survivor_rule = true
	WorldState.dev_survivors = 0
	WorldState.current_run = run


# --- quests -----------------------------------------------------------------------------------

func _quests() -> void:
	print("\n[QUEST SITES over 400 seeds]")
	var found := {"johnny": 0, "ethel": 0}
	var floors := {"johnny": {}, "ethel": {}}
	var kinds := {"stairs": 0, "door": 0}
	for s in range(1, 401):
		_fresh_world(s)
		for q in ["johnny", "ethel"]:
			var site: Dictionary = Quests.site(q)
			if site.is_empty():
				continue
			found[q] += 1
			var f: int = int(site["floor"])
			floors[q][f] = int(floors[q].get(f, 0)) + 1
			if q == "johnny":
				kinds[str(site["post_kind"])] += 1
	for q in ["johnny", "ethel"]:
		var ks: Array = floors[q].keys()
		ks.sort()
		var parts := []
		for k in ks:
			parts.append("%d:%d" % [k, floors[q][k]])
		print("  %-7s present in %d / 400 playthroughs (%.1f%%). floors  %s" % [q, found[q], found[q] / 4.0, " ".join(parts)])
	print("  johnny post: stairs %d  door %d" % [kinds["stairs"], kinds["door"]])


# --- census -----------------------------------------------------------------------------------

func _census() -> void:
	print("\n[CENSUS: what one full descent (floors 28 → 1) meets, 200 seeds]")
	for run in [1, 2, 3]:
		var def := 0
		var wait := 0
		var by_weapon := {}
		var quest_givers := 0
		for s in range(1, 201):
			_fresh_world(s, run)
			for f in range(1, 29):
				for r in SurvivorPlan.corridor_records(f):
					if str(r.get("quest", "")) != "":
						quest_givers += 1
						continue
					if r["role"] == "defender":
						def += 1
						by_weapon[r["weapon"]] = int(by_weapon.get(r["weapon"], 0)) + 1
					elif r["role"] == "waiter":
						wait += 1
		var armed_gun := int(by_weapon.get("004", 0))
		print("  run %d: defenders %.2f  (with a gun %.2f)   waiters %.2f   quest givers %.2f  per descent" %
			[run, def / 200.0, armed_gun / 200.0, wait / 200.0, quest_givers / 200.0])


# --- loot -------------------------------------------------------------------------------------

func _loot() -> void:
	print("\n[BULLETS in the real apartments — Johnny asks for 10, then 20 more]")
	for run in [1, 2, 3]:
		var flats := 0
		var nodes_with_item := 0
		var bullets := 0
		var bullet_nodes := 0
		var guns := 0
		var per_flat: Array = []
		for s in range(1, 9):
			_fresh_world(s, run)
			WorldState.survivor_rule = false
			for f in [4, 7, 9, 11, 13, 16, 18, 21, 24, 26]:
				WorldState.seed_floor_door_states(f)
				for col in [1, 3, 5]:
					var apt := "%d%02d" % [f, col]
					var r := await _flat_loot(apt, f)
					flats += 1
					nodes_with_item += int(r["items"])
					bullet_nodes += int(r["bullet_nodes"])
					bullets += int(r["bullets"])
					guns += int(r["guns"])
					per_flat.append(int(r["bullets"]))
		per_flat.sort()
		var zero := 0
		for b in per_flat:
			if b == 0:
				zero += 1
		print("  run %d: %d flats  items/flat %.1f  guns/flat %.2f  bullet nodes/flat %.2f  BULLETS/flat %.2f  (flats with none: %d%%, best flat %d)" %
			[run, flats, nodes_with_item / float(flats), guns / float(flats), bullet_nodes / float(flats), bullets / float(flats),
			int(100.0 * zero / float(flats)), per_flat[per_flat.size() - 1]])
		var per10 := bullets / float(flats) * 10.0
		print("         → searching 10 flats yields ~%.1f bullets; Johnny wants 10 (then 20) = ~%.0f flats (then ~%.0f)" %
			[per10, 10.0 / maxf(bullets / float(flats), 0.001), 30.0 / maxf(bullets / float(flats), 0.001)])


func _flat_loot(apt: String, floor_num: int) -> Dictionary:
	WorldState.current_floor = floor_num
	WorldState.current_apartment_id = apt
	WorldState.spawn_source = ""
	var room = load("res://scenes/room.tscn").instantiate()
	add_child(room)
	await get_tree().process_frame
	var r := {"items": 0, "bullets": 0, "bullet_nodes": 0, "guns": 0}
	var prefix := apt + ":"
	for key in WorldState.anchor_items.keys():
		if not String(key).begins_with(prefix):
			continue
		var item: String = str(WorldState.anchor_items[key])
		if item == "":
			continue
		r["items"] += 1
		if item == "004":
			r["guns"] += 1
		if item == "016":
			r["bullet_nodes"] += 1
			var amount: int = WorldState.get_anchor_amount(apt, String(key).substr(prefix.length()))
			if amount <= 0:
				amount = _ammo_bundle(apt, String(key).substr(prefix.length()))
			r["bullets"] += amount
	room.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	return r


## loot_ui._roll_ammo_bundle, verbatim.
func _ammo_bundle(apt: String, anchor: String) -> int:
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(str(WorldState.master_seed) + "ammobundle" + apt + anchor)
	var weights = [30, 22, 16, 12, 9, 7, 4]
	var roll = rng.randi() % 100
	var acc = 0
	for i in range(weights.size()):
		acc += weights[i]
		if roll < acc:
			return i + 2
	return 2


# --- fights -----------------------------------------------------------------------------------

func _corridor(floor_num: int = 12) -> void:
	_fresh_world(1)
	WorldState.survivor_rule = false
	WorldState.god_mode = true
	for step in [0, 2, -2, 4, -4]:                  # a floor with no fire of its own (same stairwell side)
		if floor_num + step >= 2 and WorldState.fire_intensity(floor_num + step) < 0:
			floor_num += step
			break
	WorldState.current_floor = floor_num
	WorldState.seed_floor_door_states(floor_num)
	_bf = load("res://scenes/building_floors.tscn").instantiate()
	add_child(_bf)
	await get_tree().physics_frame
	_clear_scene()


func _clear_scene() -> void:
	for z in get_tree().get_nodes_in_group("zombie"):
		if _bf.is_ancestor_of(z):
			z.free()
	for s in get_tree().get_nodes_in_group("survivor"):
		if _bf.is_ancestor_of(s):
			s.free()
	for d in get_tree().get_nodes_in_group("world_drop"):
		if _bf.is_ancestor_of(d):
			d.free()


func _rec(role: String, weapon: String, ammo: int, hp: int, post: float, tag: String) -> Dictionary:
	var key := "bal:%s:%s" % [tag, role]
	var rec := {
		"key": key, "role": role, "floor": 12, "apt": "", "look": 3, "weapon": weapon, "ammo": ammo,
		"gift": "", "gift_n": 0, "hp": hp, "max_hp": hp, "dead": false,
		"x": -1.0, "post": post, "post_kind": "stairs", "spot": 0.5, "met": 0, "aided": false, "calm": false,
		"gave": false, "quest": "",
	}
	WorldState.survivors[key] = rec
	return rec


func _zombie(x: float, hp: int, scene: String = STANDARD) -> Node:
	var z = load(scene).instantiate()
	z.global_position = Vector2(x, 370.0 if scene == STANDARD else 374.0)
	_bf.add_child(z)
	if hp > 0:
		z.max_hp = hp
		z.current_hp = hp
	return z


## One fight. `xs` = where the dead stand. Returns {alive, hp, kills, frames, shots, peak_near}.
func _fight(weapon: String, ammo: int, hp: int, xs: Array, rng: RandomNumberGenerator, tag: String, zhp: Array = [3, 5], scene: String = STANDARD) -> Dictionary:
	_clear_scene()
	WorldState.master_seed = rng.randi()
	var post := 300.0
	var s: Survivor = Survivor.spawn(_bf, _rec("defender", weapon, ammo, hp, post, tag + str(rng.randi())), FEET, post)
	var p = _bf.get_node("Player")
	var zs: Array = []
	for x in xs:
		zs.append(_zombie(float(x), rng.randi_range(int(zhp[0]), int(zhp[1])) if not zhp.is_empty() else 0, scene))
	var frames := 0
	var peak_near := 0
	while frames < 2700:
		await get_tree().physics_frame
		frames += 1
		p.global_position = Vector2(1150.0, 386.0)
		p.velocity = Vector2.ZERO
		var near := 0
		var alive_z := 0
		for z in zs:
			if is_instance_valid(z) and not z.is_dead:
				alive_z += 1
				if absf(z.global_position.x - s.global_position.x) < 160.0:
					near += 1
		peak_near = maxi(peak_near, near)
		if s.is_dead or alive_z == 0:
			break
	var kills := 0
	for z in zs:
		if is_instance_valid(z) and z.is_dead:
			kills += 1
	var out := {"alive": not s.is_dead, "hp": s.current_hp, "kills": kills, "frames": frames,
		"shots": ammo - s.ammo, "peak_near": peak_near}
	return out


func _fights() -> void:
	print("\n[FIGHTS — a defender (hp 8) at its post against N dead (3-5 hp each, floor ~12), %d trials a cell]" % _trials)
	print("  (the dead stand 190-280 px from the post — inside its 250 px leash — and idle; the survivor opens the fight. 'win' = every one of the dead killed and it lived.)")
	await _corridor()
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var loadouts := [["knife 001", "001", 0], ["sword 003", "003", 0], ["hammer 002", "002", 0], ["gun 004 x6", "004", 6]]
	for lo in loadouts:
		for n in [1, 2, 3]:
			var xs := []
			for i in n:
				xs.append(490.0 + 30.0 * i)
			var agg := await _run_cell(lo, n, xs, rng, 8)
			print("  %s  %s" % [_row_head(lo[0], n), agg])
	print("\n[JOHNNY — hp 10, a gun, 6 rounds (what quests.json gives him) against N dead]")
	for n in [1, 2, 3, 4]:
		var xs := []
		for i in n:
			xs.append(490.0 + 30.0 * i)
		var agg := await _run_cell(["Johnny (gun x6, hp10)", "004", 6], n, xs, rng, 10)
		print("  N=%d  %s" % [n, agg])
	print("\n[DEEPER FLOORS — the dead are tougher the lower you go: 6-8 hp each (floors ~1-6), N=3]")
	for lo in loadouts:
		var xs3 := [490.0, 520.0, 550.0]
		var aggd := await _run_cell(lo, 3, xs3, rng, 8, [6, 8])
		print("  %s  %s" % [_row_head(lo[0], 3), aggd])
	print("\n[A BIG ZOMBIE (default hp), N=1]")
	for lo in loadouts:
		var aggb := await _run_cell(lo, 1, [490.0], rng, 8, [], "res://scenes/enemy_zombie_big.tscn")
		print("  %s  %s" % [_row_head(lo[0], 1), aggb])
	print("\n[MAGNET — his gunshots carry 900 px: the nearest 190 px away, the rest 400-800 px, all idle]")
	var spread := [490.0, 700.0, 900.0, 1100.0]
	var agg2 := await _run_cell(["Johnny (gun x6, hp10)", "004", 6], 4, spread, rng, 10)
	print("  4 dead spread over the corridor: %s" % agg2)
	var agg3 := await _run_cell(["defender hammer", "002", 0], 4, spread, rng, 8)
	print("  same, a hammer defender (melee is quieter, 120 px): %s" % agg3)
	_bf.free()
	WorldState.god_mode = false


func _row_head(name: String, n: int) -> String:
	return "%-24s N=%d" % [name, n]


func _run_cell(lo: Array, n: int, xs: Array, rng: RandomNumberGenerator, hp: int, zhp: Array = [3, 5], scene: String = STANDARD) -> String:
	var wins := 0
	var alive := 0
	var hp_left := 0.0
	var kills := 0.0
	var secs := 0.0
	var shots := 0.0
	var peak := 0.0
	for t in _trials:
		var r := await _fight(str(lo[1]), int(lo[2]), hp, xs, rng, "t%d" % t, zhp, scene)
		if r["alive"]:
			alive += 1
			hp_left += float(r["hp"])
		if r["alive"] and r["kills"] == n:
			wins += 1
		kills += float(r["kills"])
		secs += float(r["frames"]) / 60.0
		shots += float(r["shots"])
		peak += float(r["peak_near"])
	return "win %3d%%  survives %3d%%  hp left (survivors) %.1f/%d  kills %.1f/%d  %.0fs  shots %.1f  peak dead beside it %.1f" % [
		int(100.0 * wins / _trials), int(100.0 * alive / _trials), hp_left / maxf(alive, 1), hp, kills / _trials, n,
		secs / _trials, shots / _trials, peak / _trials]


# --- waiter -----------------------------------------------------------------------------------

func _waiter() -> void:
	print("\n[WAITER — at the lift, banging in threes; five dead idling about the corridor; 150 s]")
	await _corridor()
	var rng := RandomNumberGenerator.new()
	for trial in 3:
		_clear_scene()
		WorldState.master_seed = 9000 + trial
		var w: Survivor = Survivor.spawn(_bf, _rec("waiter", "", 0, 4, 984.0, "w%d" % trial), FEET, 984.0)
		var p = _bf.get_node("Player")
		var zs: Array = []
		for x in [250.0, 400.0, 560.0, 700.0, 850.0]:
			zs.append(_zombie(x, 4))
		var line := []
		var died_at := -1.0
		for sec in range(0, 150):
			for f in 60:
				await get_tree().physics_frame
				p.global_position = Vector2(150.0, 386.0)
				p.velocity = Vector2.ZERO
			if died_at < 0.0 and w.is_dead:
				died_at = float(sec)
			if sec % 15 == 14:
				var near := 0
				for z in zs:
					if is_instance_valid(z) and not z.is_dead and absf(z.global_position.x - 1000.0) < 180.0:
						near += 1
				line.append("%ds:%d" % [sec + 1, near])
		print("  trial %d: waiter %s  knocks %d   dead within 180 px of the lift (t:count) %s" % [
			trial, ("DIED at %.0fs" % died_at) if died_at >= 0.0 else "alive at 150s", w.knocks, " ".join(line)])
	_bf.free()
	WorldState.god_mode = false


# --- natural floors ---------------------------------------------------------------------------

## Builds the real floor `f` (natural dead, natural survivors) for run `run`, puts the player on the arrival stair and
## keeps them there, passive. Returns the live Survivor nodes by (quest id or role).
func _live_floor(f: int, run: int) -> void:
	WorldState.god_mode = true
	WorldState.current_run = run
	WorldState.current_floor = f
	WorldState.spawn_source = ""
	WorldState.seed_floor_door_states(f)
	_bf = load("res://scenes/building_floors.tscn").instantiate()
	add_child(_bf)
	await get_tree().physics_frame


func _arrival_x(f: int) -> float:
	return 188.0 if WorldState.canonical_stair_arrival_side(f) == "left" else 1162.0


func _step(frames: int, f: int) -> void:
	var p = _bf.get_node("Player")
	for i in frames:
		await get_tree().physics_frame
		p.global_position = Vector2(_arrival_x(f), 386.0)
		p.velocity = Vector2.ZERO


func _zombie_census(near_x: float) -> String:
	var total := 0
	var within := 0
	for z in get_tree().get_nodes_in_group("zombie"):
		if _bf.is_ancestor_of(z) and not z.is_dead:
			total += 1
			if absf(z.global_position.x - near_x) <= 250.0:
				within += 1
	return "%d dead on the floor, %d within its 250 px leash" % [total, within]


func _natural_floors() -> void:
	print("\n[ORDINARY DEFENDERS on the real floors — the natural dead, the player standing passive on the arrival stair, 60 s]")
	for run in [1, 3]:
		var by_weapon := {}
		var n := 0
		for s in range(1, _trials * 3 + 1):
			_fresh_world(s, run)
			WorldState.survivor_rule = true
			var cands: Array = []
			for f in range(3, 28):
				if WorldState.fire_intensity(f) >= 0:
					continue
				for r in SurvivorPlan.corridor_records(f):
					if str(r.get("quest", "")) == "" and r["role"] == "defender":
						cands.append(f)
			if cands.is_empty():
				continue
			var f: int = cands[s % cands.size()]
			WorldState.survivors.erase(SurvivorPlan.corridor_key(f, "waiter"))       # (a waiter's bangs would muddy the read)
			await _live_floor(f, run)
			var d: Survivor = null
			for sv in get_tree().get_nodes_in_group("survivor"):
				if _bf.is_ancestor_of(sv) and sv.role == "defender":
					d = sv
			if d == null:
				_bf.free()
				continue
			var start_hp := d.current_hp
			var weapon_kind: String = d.kind
			var census := _zombie_census(d.post)
			var weapon_id := d.weapon
			await _step(3600, f)
			var key := "%s%s" % [weapon_kind, "" if weapon_kind != "gun" else " x%d" % int(SurvivorPlan.AMMO_MIN)]
			var row: Dictionary = by_weapon.get(key, {"n": 0, "alive": 0, "hp": 0.0, "ammo_out": 0})
			row["n"] += 1
			if not d.is_dead:
				row["alive"] += 1
				row["hp"] += float(d.current_hp) / float(maxi(start_hp, 1))
			if weapon_kind == "gun" and d.ammo <= 0:
				row["ammo_out"] += 1
			by_weapon[key] = row
			n += 1
			_bf.free()
			await get_tree().process_frame
			WorldState.god_mode = false
		print("  run %d (%d floors):" % [run, n])
		for k in by_weapon:
			var r: Dictionary = by_weapon[k]
			print("     %-10s %2d defenders  survive %3d%%  mean hp left %3d%%  %s" % [k, r["n"],
				int(100.0 * r["alive"] / float(r["n"])), int(100.0 * r["hp"] / float(maxi(r["alive"], 1))),
				("emptied the gun %d×" % r["ammo_out"]) if k.begins_with("gun") else ""])


func _johnny_floor() -> void:
	print("\n[JOHNNY on his real floor — run 1, natural dead, player passive on the arrival stair, 90 s]")
	var alive := 0
	var total := 0
	var emptied := 0
	var by_kind := {"stairs": [0, 0], "door": [0, 0]}
	var quiet_floor := 0
	for s in range(1, _trials * 3 + 1):
		_fresh_world(s, 1)
		WorldState.survivor_rule = true
		var site: Dictionary = Quests.site("johnny")
		if site.is_empty():
			continue
		var f: int = int(site["floor"])
		await _live_floor(f, 1)
		var j: Survivor = null
		for sv in get_tree().get_nodes_in_group("survivor"):
			if _bf.is_ancestor_of(sv) and sv.quest_id == "johnny":
				j = sv
		if j == null:
			_bf.free()
			continue
		var census := _zombie_census(j.post)
		await _step(5400, f)
		total += 1
		var kind: String = str(site["post_kind"])
		by_kind[kind][1] += 1
		if not j.is_dead:
			alive += 1
			by_kind[kind][0] += 1
		if j.ammo <= 0:
			emptied += 1
		if s <= 6:
			print("   seed %d: floor %d post %s x%.0f — %s → Johnny %s (hp %d, rounds left %d)" % [s, f, kind, j.post, census,
				"ALIVE" if not j.is_dead else "DEAD", j.current_hp, j.ammo])
		_bf.free()
		await get_tree().process_frame
		WorldState.god_mode = false
	print("  Johnny alive after 90 s: %d / %d (%.0f%%); emptied his gun in %d. at the stairs %d/%d, at a door %d/%d" % [
		alive, total, 100.0 * alive / float(maxi(total, 1)), emptied, by_kind["stairs"][0], by_kind["stairs"][1],
		by_kind["door"][0], by_kind["door"][1]])
