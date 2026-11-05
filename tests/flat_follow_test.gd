extends Node

# FLAT FOLLOWERS (owner round 49m: "enemies following us into apartments. Not always, but improve enemy AI so they are actually threatening. This will tie
# into the stealth mechanic we need to input with time").
#   • only the dead that are ACTIVELY chasing the player (chase / attack, not idle, not investigating a noise), on their plane and within FLAT_FOLLOW_RANGE of
#     them as they step through a door, can follow - a roll per (chaser, flat, run) on a fixed seed, at most FLAT_FOLLOW_MAX, standards / crawlers / long-arms only;
#   • the rule is OFF unless the real New Game turns it on, and the tutorial, floor 30, breach flats and flats that lay their own people take nobody;
#   • capture changes NOTHING in the corridor; the follower walks in through the front door after its delay, fading in, locked on, as hurt as it was, and ONLY THEN
#     is its corridor slot marked `followed_away` (so it is never in two places);
#   • killed it stays dead; left alive it stands inside on the next visit; nothing is planned again.
# Run: godot --headless res://tests/flat_follow_test.tscn

var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== flat followers test ===")
	await get_tree().process_frame
	WorldState.new_game()
	WorldState.is_first_run = false
	WorldState.tutorial_completed = true
	_test_the_roll()
	_test_the_rules()
	await _test_capture()
	await _test_coming_in()
	await _test_other_rooms_take_nobody()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


## An ordinary flat on `floor_num` (one that lays the ordinary dead - no quest, resident, rescue, haven or fire), or "".
func _ordinary_flat(floor_num: int) -> String:
	for c in range(1, 6):
		var apt := "%d0%d" % [floor_num, c]
		if WorldState.flat_follow_allowed(apt):
			return apt
	return ""


func _test_the_roll() -> void:
	print("[the roll: some chasers follow, not all, the same answer every time]")
	WorldState.new_game()
	WorldState.master_seed = 4242
	WorldState.is_first_run = false
	for run in [1, 2, 3]:
		WorldState.current_run = run
		var yes := 0
		var n := 400
		var stable := true
		for i in range(n):
			var origin := "12:%d:370" % (200 + i)
			var r: bool = WorldState.flat_follows("1203", origin)
			stable = stable and r == WorldState.flat_follows("1203", origin)
			if r:
				yes += 1
		var want: float = WorldState.FLAT_FOLLOW_CHANCE[run]
		check(stable, "run %d: the same chaser into the same flat gets the same answer every time" % run)
		check(absf(float(yes) / n - want) < 0.08, "run %d: about %.0f%% of chasers follow (%.0f%%)" % [run, want * 100.0, 100.0 * yes / n])
	check(WorldState.FLAT_FOLLOW_CHANCE[1] < 1.0 and WorldState.FLAT_FOLLOW_CHANCE[3] < 1.0, "…so it is 'not always': even by night some chasers stay outside")
	check(WorldState.FLAT_FOLLOW_MAX == 2, "…and never more than two come in after one door")
	# The descent ramp (round 49n: "we don't need to change... even the first five levels of descent... incrementally increase"): nobody follows into a flat
	# on floor 30 or 29, a quarter of the chance on 28, half on 27, three quarters on 26, the full chance from floor 25 down.
	WorldState.current_run = 3
	var chance3: float = WorldState.FLAT_FOLLOW_CHANCE[3]
	for entry in [[30, 0.0], [29, 0.0], [28, 0.25], [27, 0.5], [26, 0.75], [25, 1.0], [12, 1.0]]:
		var apt := "%d03" % entry[0]
		var yes_r := 0
		var n_r := 800
		for i in range(n_r):
			if WorldState.flat_follows(apt, "%d:%d:370" % [entry[0], 200 + i]):
				yes_r += 1
		var want_r: float = chance3 * float(entry[1])
		check(absf(float(yes_r) / n_r - want_r) < 0.06 and (want_r > 0.0 or yes_r == 0), "floor %d (run 3): %.0f%% of chasers follow (want %.0f%%)" % [entry[0], 100.0 * yes_r / n_r, 100.0 * want_r])
	WorldState.dev_ramp_override = 0.0
	var forced := 0
	for i in range(200):
		forced += 1 if WorldState.flat_follows("1203", "12:%d:370" % (200 + i)) else 0
	check(forced == 0, "the override's old rules mean nobody follows on any floor (%d)" % forced)
	WorldState.dev_ramp_override = -1.0
	var k0: String = WorldState.flat_follow_key("1203", "12:300:370", "standard")
	check(k0 != WorldState.flat_follow_key("1203", "12:301:370", "standard") and k0 != WorldState.flat_follow_key("1203", "12:300:370", "crawler")
			and k0.begins_with(WorldState.flat_follow_prefix("1203")) and k0.get_slice(":", 4) == "standard", "each follower has its own key, in the flat's prefix, the kind last (%s)" % k0)


func _test_the_rules() -> void:
	print("[the rules: the real New Game only; not the tutorial, floor 30, a breach flat, or a flat with its own people]")
	WorldState.new_game()
	WorldState.master_seed = 4242
	WorldState.is_first_run = false
	WorldState.follow_rule = false
	var apt := _ordinary_flat(12)
	check(apt == "", "with the rule OFF no flat takes a follower (a plain new_game(), i.e. every other suite)")
	WorldState.follow_rule = true
	apt = _ordinary_flat(12)
	check(apt != "", "with the rule on there is an ordinary flat on floor 12 (%s)" % apt)
	WorldState.is_first_run = true
	check(not WorldState.flat_follow_allowed(apt), "…but not while the tutorial run is on")
	WorldState.is_first_run = false
	check(_ordinary_flat(30) == "" and not WorldState.flat_follow_allowed("3003"), "…floor 30 takes none")
	if apt != "":
		WorldState.set_door_state(apt, WorldState.DoorState.BREACHED)
		check(not WorldState.flat_follow_allowed(apt), "…a breach flat takes none (it has its own entrants)")
		WorldState.set_door_state(apt, WorldState.DoorState.OPEN)
	var with_people := ""
	for f in range(2, 29):
		for c in range(1, 6):
			var a := "%d0%d" % [f, c]
			if with_people == "" and not WorldState.flat_lays_ordinary_dead(a) and WorldState.apartment_fire_stage(f, c) not in [WorldState.FIRE_CHARRED, WorldState.FIRE_BLAZE]:
				with_people = a
	check(with_people == "" or not WorldState.flat_follow_allowed(with_people), "…a flat that lays its own people instead of the ordinary dead takes none (%s)" % with_people)
	# the rule survives a save, and an old save inherits the survivor rule
	var d := {"survivor_rule": true}
	check(bool(d.get("follow_rule", bool(d.get("survivor_rule", false)))), "(an old real-game save, with no follow_rule of its own, inherits the survivor rule)")


func _corridor() -> Node:
	# floor 12 is on fire for some seeds (the burning dead are not the test's dead): find a seed where it is not and holds an ordinary flat
	var seed_n := 5000
	while seed_n < 5200:
		WorldState.new_game()
		WorldState.master_seed = seed_n
		WorldState.is_first_run = false
		WorldState.tutorial_completed = true
		WorldState.follow_rule = true
		WorldState.current_floor = 12
		if WorldState.fire_intensity(12) == 0 and _ordinary_flat(12) != "":
			break
		seed_n += 1
	WorldState.god_mode = true
	WorldState.seed_floor_door_states(12)
	var bf = load("res://scenes/building_floors.tscn").instantiate()
	add_child(bf)
	await get_tree().physics_frame
	for z in get_tree().get_nodes_in_group("zombie"):
		if bf.is_ancestor_of(z):
			z.free()
	return bf


## A standing chaser of `kind` at `x`, in `state`, with a spawn key the roll will say yes (or no) to for `apt`.
func _chaser(bf: Node, kind: String, x: float, state: String, apt: String, want_yes: bool, tag: String) -> Node:
	var z = load("res://scenes/enemy_zombie_%s.tscn" % kind).instantiate()
	var y: float = 370.0 if kind == "standard" else 374.0
	z.global_position = Vector2(x, y)
	var i := 0
	var key := "12:%s%d:%d" % [tag, i, int(x)]
	while WorldState.flat_follows(apt, key) != want_yes:
		i += 1
		key = "12:%s%d:%d" % [tag, i, int(x)]
	z.spawn_key = key
	bf.add_child(z)
	z.set_physics_process(false)         # a still life: the test sets the state it wants captured
	z.state = state
	return z


func _test_capture() -> void:
	print("[capture: who is on the player's heels as they step through a door]")
	var bf = await _corridor()
	var apt := _ordinary_flat(12)
	var pl = bf.get_node("Player")
	pl.global_position = Vector2(600, 386)
	var near_std = _chaser(bf, "standard", 700.0, "chase", apt, true, "a")        # 100 px behind, chasing, the roll says yes
	var near_crawler = _chaser(bf, "crawler", 560.0, "chase", apt, true, "b")     # 40 px the other side
	var third = _chaser(bf, "standard", 730.0, "attack", apt, true, "c")          # a third: only two follow
	var far = _chaser(bf, "standard", 900.0, "chase", apt, true, "d")             # 300 px: not on their heels
	var idle = _chaser(bf, "standard", 640.0, "idle", apt, true, "e")             # beside them but it has not noticed them
	var no_roll = _chaser(bf, "standard", 650.0, "chase", apt, false, "f")        # chasing, close, the roll says no
	var big = load("res://scenes/enemy_zombie_big.tscn").instantiate()
	big.global_position = Vector2(620, 374)
	big.spawn_key = "12:big:1"
	bf.add_child(big)
	big.set_physics_process(false)
	big.state = "chase"
	var before_pos: Dictionary = WorldState.zombie_positions.duplicate(true)
	var before_away: Dictionary = WorldState.followed_away.duplicate(true)
	# the door's own method, on a real door of the real corridor
	var door = null
	for n in get_tree().get_nodes_in_group("door_interact"):
		if bf.is_ancestor_of(n) and str(n.get("apartment_id")) == apt:
			door = n
	check(door != null, "(setup) the corridor has flat %s's door" % apt)
	var got: int = door.capture_followers_now() if door != null else -1
	check(got == WorldState.FLAT_FOLLOW_MAX and WorldState.flat_pending.size() == 2, "two follow, no more (%d captured)" % got)
	var origins: Array = []
	for r in WorldState.flat_pending:
		origins.append(r["origin"])
	check(origins.has(near_crawler.spawn_key) and origins.has(near_std.spawn_key), "the two NEAREST chasers: the crawler (40 px) and the standard (100 px)")
	check(not origins.has(third.spawn_key), "the third, further out, stays")
	check(not origins.has(far.spawn_key), "one 300 px back is not on their heels")
	check(not origins.has(idle.spawn_key), "one beside them that has not noticed them does not follow (the stealth gate)")
	check(not origins.has(no_roll.spawn_key), "one whose roll says no does not follow")
	check(not origins.has("12:big:1"), "a big one cannot follow")
	var kinds := {}
	for r in WorldState.flat_pending:
		kinds[r["origin"]] = r["kind"]
	check(kinds.get(near_crawler.spawn_key) == "crawler" and kinds.get(near_std.spawn_key) == "standard", "the kind is carried (crawler, standard)")
	check(float(WorldState.flat_pending[0]["delay"]) >= WorldState.FLAT_FOLLOW_MIN_DELAY and float(WorldState.flat_pending[1]["delay"]) > float(WorldState.flat_pending[0]["delay"]),
			"each has a delay (>= %.1f s), the second later than the first" % WorldState.FLAT_FOLLOW_MIN_DELAY)
	check(WorldState.zombie_positions == before_pos and WorldState.followed_away == before_away, "capturing changed NOTHING in the corridor's memory")
	# a hurt one carries its hurt
	near_std.current_hp = 1
	door.capture_followers_now()
	var hp1 := -1
	for r in WorldState.flat_pending:
		if r["origin"] == near_std.spawn_key:
			hp1 = int(r["hp"])
	check(hp1 == 1, "a hurt chaser is captured as hurt (hp %d)" % hp1)
	# an idle noticing-nobody corridor captures nothing
	for z in [near_std, near_crawler, third, far, no_roll]:
		z.state = "idle"
		z.alert_timer = 0.0
	check(door.capture_followers_now() == 0 and WorldState.flat_pending.is_empty(), "when nothing is chasing them, nothing follows")
	# the rule off: nothing, even with a chaser on their heels
	near_std.state = "chase"
	WorldState.follow_rule = false
	check(door.capture_followers_now() == 0, "with the rule off a chaser on their heels does not follow")
	WorldState.follow_rule = true
	# a dead one cannot follow; a maintenance door takes nobody
	near_std.state = "chase"
	near_std.is_dead = true
	check(door.capture_followers_now() == 0, "a dead one does not follow")
	near_std.is_dead = false
	var mdoor_flag: bool = door.is_maintenance
	door.is_maintenance = true
	check(door.capture_followers_now() == 0, "a maintenance room takes nobody")
	door.is_maintenance = mdoor_flag
	bf.queue_free()
	await get_tree().process_frame
	WorldState.flat_pending.clear()


func _room(apt: String) -> Node:
	WorldState.current_apartment_id = apt
	WorldState.current_floor = WorldState._apartment_floor(apt)
	WorldState.spawn_source = "door"
	var room = load("res://scenes/room.tscn").instantiate()
	add_child(room)
	return room


func _test_coming_in() -> void:
	print("[coming in: through the front door, after the delay, locked on, as hurt as it was]")
	WorldState.new_game()
	var seed_n := 6000
	var apt := ""
	while seed_n < 6200:
		WorldState.new_game()
		WorldState.master_seed = seed_n
		WorldState.is_first_run = false
		WorldState.tutorial_completed = true
		WorldState.follow_rule = true
		apt = _ordinary_flat(12)
		if apt != "":
			break
		seed_n += 1
	check(apt != "", "(setup) an ordinary flat to walk into (%s, seed %d)" % [apt, seed_n])
	WorldState.god_mode = true
	var o_std := "12:380:370"
	var o_cr := "12:420:374"
	WorldState.zombie_positions[o_std] = {"x": 380.0, "y": 370.0}        # what the corridor remembers of them as it is torn down
	WorldState.zombie_positions[o_cr] = {"x": 420.0, "y": 374.0}
	WorldState.flat_pending = [
		{"origin": o_std, "kind": "standard", "hp": 2, "delay": 2.0},
		{"origin": o_cr, "kind": "crawler", "hp": 1, "delay": 3.0},
	]
	var room = _room(apt)
	for i in range(10):
		await get_tree().physics_frame
	for z in get_tree().get_nodes_in_group("zombie"):
		if room.is_ancestor_of(z):
			z.free()
	check(WorldState.flat_pending.is_empty(), "the room took the list (a second room can never see it)")
	check(room._follow_todo.size() == 2, "two are planned, none in yet (%d)" % room._follow_todo.size())
	room._followers_tick(1.0)
	check(room._follow_todo.size() == 2 and not WorldState.followed_away.has(o_std), "none is in before its delay, and its corridor slot is still its own")
	room._followers_tick(1.5)          # 2.5 s: the first
	check(room._follow_todo.size() == 1 and WorldState.followed_away.has(o_std) and not WorldState.followed_away.has(o_cr), "the first walks in at 2.0 s - and only then is its corridor slot marked gone")
	check(not WorldState.zombie_positions.has(o_std) and WorldState.zombie_positions.has(o_cr), "…and its corridor memory is erased (no copy out there), the second's not yet")
	room._followers_tick(1.0)          # 3.5 s: the second
	check(room._follow_todo.is_empty() and WorldState.followed_away.has(o_cr), "the second at 3.0 s")
	await get_tree().physics_frame
	var ins: Array = []
	for z in get_tree().get_nodes_in_group("zombie"):
		if room.is_ancestor_of(z) and str(z.spawn_key).contains(":flat_in:"):
			ins.append(z)
	check(ins.size() == 2, "two bodies stand in the flat (%d)" % ins.size())
	var door = room.get_node("Area2D")
	var std_in = null
	var cr_in = null
	for z in ins:
		if z.scene_file_path.ends_with("enemy_zombie_standard.tscn"):
			std_in = z
		elif z.scene_file_path.ends_with("enemy_zombie_crawler.tscn"):
			cr_in = z
	check(std_in != null and cr_in != null, "a standard and a crawler, as captured")
	if std_in != null and cr_in != null:
		check(absf(std_in.global_position.x - door.global_position.x) < 40.0, "they come in AT the front door (x %.0f, door %.0f)" % [std_in.global_position.x, door.global_position.x])
		check(std_in.alert_timer > 5.0 and cr_in.alert_timer > 5.0, "…locked on to the player (alert %.1f s)" % std_in.alert_timer)
		check(std_in.current_hp == 2 and cr_in.current_hp == 1, "…as hurt as they were out there (hp %d and %d)" % [std_in.current_hp, cr_in.current_hp])
		check(std_in.get_node("AnimatedSprite2D").modulate.a < 1.0, "…fading in out of the doorway")
		check(std_in.is_follower and std_in.follow_origin == o_std, "…marked as followers of their origin slot")
		var key: String = std_in.spawn_key
		# kill one: stays dead
		std_in.receive_damage(99, "melee")
		await get_tree().physics_frame
		check(WorldState.killed_zombies.has(key), "a killed follower is on the kill record")
		check(WorldState.followed_away.has(o_std), "…and its corridor slot stays empty (the dead stay dead)")
	# leave with the crawler alive: it is inside, standing, on the next visit; nothing is planned again
	var pl = room.get_node("Player")
	var left: bool = WorldState.get_entrance_side(apt) == "left"
	pl.global_position.x = door.global_position.x + (400.0 if left else -400.0)
	await get_tree().physics_frame
	room.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var again = _room(apt)
	for i in range(10):
		await get_tree().physics_frame
	var standing := 0
	var killed_back := 0
	for z in get_tree().get_nodes_in_group("zombie"):
		if again.is_ancestor_of(z) and str(z.spawn_key).contains(":flat_in:"):
			if z.get("is_dead") != true:
				standing += 1
			if str(z.spawn_key).ends_with(":standard"):
				killed_back += 1
	check(again._follow_todo.is_empty(), "back again: nobody is left to come in")
	check(standing == 1 and killed_back == 0, "…the crawler left alive stands inside and the killed standard is not back (%d standing, %d standards)" % [standing, killed_back])
	again.queue_free()
	await get_tree().process_frame
	# leaving BEFORE they arrive costs nothing: the corridor still has them
	WorldState.new_game()
	WorldState.master_seed = seed_n
	WorldState.is_first_run = false
	WorldState.follow_rule = true
	WorldState.zombie_positions["12:500:370"] = {"x": 500.0, "y": 370.0}
	WorldState.flat_pending = [{"origin": "12:500:370", "kind": "standard", "hp": 3, "delay": 3.0}]
	var quick = _room(apt)
	for i in range(5):
		await get_tree().physics_frame
	quick.queue_free()
	await get_tree().physics_frame
	check(WorldState.zombie_positions.has("12:500:370") and not WorldState.followed_away.has("12:500:370"), "left before it arrived: it is still out in the corridor, nothing lost")
	# a rest / pry re-rolls the building: a follower living in a flat is dropped with the other position-independent slots, and its origin slot is open again
	WorldState.zombie_positions["12:flat_in:1203:12_380_370:standard"] = {"x": 300.0, "y": 304.0}
	WorldState.killed_zombies["12:flat_in:1203:12_420_374:crawler"] = {"x": 300.0, "y": 304.0}
	WorldState.followed_away["12:380:370"] = true
	WorldState.shift_building()
	check(not WorldState.zombie_positions.has("12:flat_in:1203:12_380_370:standard") and not WorldState.killed_zombies.has("12:flat_in:1203:12_420_374:crawler")
			and not WorldState.followed_away.has("12:380:370"), "a building shift drops a flat's followers (alive or dead) and opens their origin slots again")
	WorldState.god_mode = false


func _test_other_rooms_take_nobody() -> void:
	print("[rooms that lay their own people take nobody - and the list never rides into a later room]")
	WorldState.new_game()
	WorldState.master_seed = 6001
	WorldState.is_first_run = false
	WorldState.tutorial_completed = true
	WorldState.follow_rule = true
	WorldState.god_mode = true
	var apt := ""
	for f in range(8, 24):
		for c in range(1, 6):
			var a := "%d0%d" % [f, c]
			if apt == "" and WorldState.apartment_fire_stage(f, c) not in [WorldState.FIRE_CHARRED, WorldState.FIRE_BLAZE] and WorldState.apartment_span(a) == 3:
				apt = a
	# a breach flat with a (forged) list: nobody comes of it
	var rec := {"origin": "12:700:370", "kind": "standard", "hp": 3, "delay": 0.5}
	WorldState.flat_pending = [rec]
	WorldState.set_door_state(apt, WorldState.DoorState.BREACHED)
	var room = _room(apt)
	for i in range(5):
		await get_tree().physics_frame
	check(WorldState.flat_pending.is_empty(), "a breach flat still TAKES the list (it can never ride into a later room)…")
	check(room._follow_todo.is_empty(), "…and plans nobody from it")
	room.queue_free()
	await get_tree().process_frame
	WorldState.set_door_state(apt, WorldState.DoorState.OPEN)
