extends Node

# NPC SOAK TEST (docs/NPC_AI.md): populated floors and flats, run for simulated minutes with a roaming player who walks,
# swings, presses interact and picks conversation answers — looking for anything that breaks. Not a rules test (the other
# suites own those): it asserts only INVARIANTS that must hold whatever happens —
#   • no script error (the gate's log scan fails the suite on one),
#   • every position stays finite and inside the place; every living survivor always has a named behaviour,
#   • no zombie is left "investigating" for ever (the unreachable-noise bug),
#   • the player is never held in place — they can always walk (the soft-lock guarantee),
#   • a floor that is torn down mid-fight leaves nothing behind that errors on the next frame.
# Physics runs 8x faster than real time with the per-step delta unchanged (see tools/npc_balance_report.gd), so the
# simulated minutes cost seconds.

const SPEED := 8
const STEPS_PER_RUN := 1200            # 20 s of game time (these scenes cost ~100 physics steps a second, so keep the soak lean)
const FLOORS_PER_SEED := [26, 14, 5]

var failures := 0
var _bf: Node = null


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS  ", msg)
	else:
		print("  FAIL  ", msg)
		failures += 1


func _ready() -> void:
	print("=== npc soak test ===")
	Engine.physics_ticks_per_second = 60 * SPEED
	Engine.max_physics_steps_per_frame = 64
	Engine.time_scale = float(SPEED)
	await get_tree().process_frame
	await _soak_corridors()
	await _soak_unreachable_noise()
	await _soak_flats()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	_release_all()
	get_tree().quit(1 if failures > 0 else 0)


func _release_all() -> void:
	for a in ["move_left", "move_right", "interact", "attack", "push", "crouch"]:
		if InputMap.has_action(a):
			Input.action_release(a)


func _fresh(seed_value: int, run: int) -> void:
	WorldState.dev_seed = seed_value
	WorldState.new_game()
	WorldState.dev_seed = 0
	WorldState.is_first_run = false
	WorldState.tutorial_completed = true
	WorldState.survivor_rule = true
	WorldState.dev_survivors = 1              # every roll succeeds: the densest populations the rules allow
	WorldState.god_mode = true
	WorldState.current_run = run


# --- corridors --------------------------------------------------------------------------------

func _soak_corridors() -> void:
	print("[SOAK: populated corridors — 4 seeds × 3 floors × 20 s, walking, swinging, talking]")
	var runs := 0
	var errors_free := true
	var stuck_investigators := 0
	var bad_positions := 0
	var nameless := 0
	var held_player := 0
	var talked := 0
	var injected := 0
	var injected_gave_up := 0
	for s in range(1, 5):
		var run := 1 + (s % 3)
		for f in FLOORS_PER_SEED:
			_fresh(s * 7, run)
			if WorldState.fire_intensity(f) >= 0:
				continue                            # (a burning floor is the fire suites' business)
			WorldState.current_floor = f
			WorldState.seed_floor_door_states(f)
			_bf = load("res://scenes/building_floors.tscn").instantiate()
			add_child(_bf)
			await get_tree().physics_frame
			var p = _bf.get_node("Player")
			# every other run, one of the dead is told of a noise BEYOND the corridor's end wall — a spot it can never reach
			var lost_one: Node = null
			if s % 2 == 0:
				lost_one = load("res://scenes/enemy_zombie_standard.tscn").instantiate()
				lost_one.global_position = Vector2(1000.0, 370.0)
				_bf.add_child(lost_one)
				lost_one.max_hp = 50
				lost_one.current_hp = 50
				await get_tree().physics_frame
				EnemyMind.hear(lost_one, 1500.0)
				injected += 1
			var x_min := 99999.0
			var x_max := -99999.0
			var dir := 1.0
			var leg := 0
			for step in STEPS_PER_RUN:
				await get_tree().physics_frame
				# the roaming player: sweep the corridor, swing now and then, press interact beside anyone who will talk
				if step % 240 == 0:
					dir = -dir
					leg += 1
				Input.action_press("move_right" if dir > 0.0 else "move_left")
				Input.action_release("move_left" if dir > 0.0 else "move_right")
				if step % 45 == 0:
					Input.action_press("attack")
				elif step % 45 == 6:
					Input.action_release("attack")
				var near_talker := false
				for sv in get_tree().get_nodes_in_group("survivor"):
					if _bf.is_ancestor_of(sv) and sv._talk_near:      # (only when Talk is really on offer — elsewhere E is a door)
						near_talker = true
						if sv.has_choices() and step % 90 == 0:
							Quests.choose(sv, 0)         # take the first answer on offer
				if near_talker and step % 30 == 0:
					Input.action_press("interact")
					talked += 1
				elif step % 30 == 4:
					Input.action_release("interact")
				if step % 30 == 0:
					x_min = minf(x_min, p.global_position.x)
					x_max = maxf(x_max, p.global_position.x)
					# invariants
					for n in get_tree().get_nodes_in_group("survivor") + get_tree().get_nodes_in_group("zombie") + [p]:
						if not is_instance_valid(n) or not _bf.is_ancestor_of(n) and n != p:
							continue
						var pos: Vector2 = n.global_position
						if not (is_finite(pos.x) and is_finite(pos.y)) or pos.x < 60.0 or pos.x > 1300.0 or pos.y < 200.0 or pos.y > 700.0:
							bad_positions += 1
							print("      bad position: %s at %s (floor %d)" % [n.name, str(pos), f])
					for sv in get_tree().get_nodes_in_group("survivor"):
						if _bf.is_ancestor_of(sv) and not sv.is_dead and str(sv.behaviour) == "":
							nameless += 1
					for z in get_tree().get_nodes_in_group("zombie"):
						if not _bf.is_ancestor_of(z) or z.is_dead:
							continue
						# its time to reach the noise ran out long ago and it is STILL walking at it = pushing at a wall for ever
						if str(z.get("mind")) == "investigate" and float(z.get("mind_t")) < -2.0:
							stuck_investigators += 1
			_release_all()
			# resolved = it gave up, or newer news (the player's footsteps, a survivor's fight) sent it somewhere else
			if lost_one != null and is_instance_valid(lost_one) \
					and (str(lost_one.get("mind")) != "investigate" or absf(float(lost_one.get("mind_x")) - 1500.0) > 1.0):
				injected_gave_up += 1
			if x_max - x_min < 250.0:
				held_player += 1
				print("      the player was held: x %.0f..%.0f over 40 s on floor %d (seed %d)" % [x_min, x_max, f, s])
			runs += 1
			_bf.free()                              # torn down mid-fight, as a scene change does
			await get_tree().process_frame
			await get_tree().process_frame
	check(runs >= 8, "(setup) %d populated floors were soaked" % runs)
	check(injected > 0 and injected_gave_up == injected, "(busy floor) an unreachable noise never held a zombie at the wall: given up on, or overtaken by newer news (%d of %d) — the isolated run below is what proves the give-up" % [injected_gave_up, injected])
	check(bad_positions == 0, "every body stayed finite and inside the place (%d out of bounds)" % bad_positions)
	check(nameless == 0, "every living survivor always had a named behaviour (%d frames without)" % nameless)
	check(stuck_investigators == 0, "(busy floor) no zombie was left investigating past its time (%d)" % stuck_investigators)
	check(held_player == 0, "the player could always walk the corridor (%d runs held)" % held_player)
	print("      (interact pressed beside a talker %d times)" % talked)


# --- the unreachable noise, alone -----------------------------------------------------------------
# On a busy floor a zombie told of an unreachable noise is soon overtaken by newer news (the player's footsteps, a fight), so
# the checks above can pass without the give-up rule. Here ONE zombie is alone with a still player at the far end of the
# corridor: nothing can retarget it, so it either gives up in the time the rule allows or it stands at the wall for ever.

func _soak_unreachable_noise() -> void:
	print("[SOAK: an unreachable noise, one zombie alone — it must give up, not push at the wall for ever]")
	var trials := 0
	var gave_up := 0
	var reached_wall := 0
	var nearly_stuck := 0
	for floor_n in [20, 21]:                        # one floor of each stairwell parity: the player arrives on opposite ends
		for s in range(1, 12):
			_fresh(s * 5, 1)
			if WorldState.fire_intensity(floor_n) >= 0:
				continue
			WorldState.current_floor = floor_n
			WorldState.seed_floor_door_states(floor_n)
			_bf = load("res://scenes/building_floors.tscn").instantiate()
			add_child(_bf)
			await get_tree().physics_frame
			var p = _bf.get_node("Player")
			for n in get_tree().get_nodes_in_group("zombie") + get_tree().get_nodes_in_group("survivor"):
				if is_instance_valid(n) and _bf.is_ancestor_of(n):
					n.queue_free()
			await get_tree().physics_frame
			await get_tree().physics_frame
			var east: bool = floor_n == 21                      # one run each way: the zombie at the east end, then the west
			p.global_position.x = 190.0 if east else 1160.0     # the still player stands at the far end from it
			var z = load("res://scenes/enemy_zombie_standard.tscn").instantiate()
			z.global_position = Vector2(1150.0 if east else 200.0, 370.0)
			_bf.add_child(z)
			z.max_hp = 50
			z.current_hp = 50
			await get_tree().physics_frame
			var noise_x := 1400.0 if east else -50.0           # 250 px beyond a wall it can never cross
			EnemyMind.hear(z, noise_x)
			var wall_x: float = 1235.0 if east else 115.0
			var budget: float = float(z.get("mind_t"))
			var pinned := false
			var steps := int((budget + 3.0) * 60.0)           # ... and 3 s past the time the rule allows
			for step in steps:
				await get_tree().physics_frame
				if step % 30 == 0 and str(z.get("mind")) == "investigate" and absf(z.global_position.x - wall_x) < 40.0:
					pinned = true
				if step % 30 == 0 and str(z.get("mind")) == "investigate" and float(z.get("mind_t")) < -2.0:
					nearly_stuck += 1
			if pinned:
				reached_wall += 1
			if str(z.get("mind")) != "investigate":
				gave_up += 1
			else:
				print("      still investigating at x %.0f after %.0f s (floor %d, seed %d)" % [z.global_position.x, steps / 60.0, floor_n, s])
			trials += 1
			_bf.free()
			await get_tree().process_frame
			await get_tree().process_frame
			break
	check(trials == 2, "(setup) both stairwell parities were run (%d)" % trials)
	check(reached_wall == trials, "the zombie really did walk to the wall and press on it before giving up (%d of %d) — the test can fail" % [reached_wall, trials])
	check(gave_up == trials, "it gave up on the unreachable noise within the rule's time (%d of %d)" % [gave_up, trials])
	check(nearly_stuck == 0, "it was never left investigating more than 2 s past its time (%d)" % nearly_stuck)


# --- flats ------------------------------------------------------------------------------------

func _soak_flats() -> void:
	print("[SOAK: flats with a hider and with a quest — 4 flats × 15 s]")
	var flats := 0
	var bad := 0
	var held := 0
	for s in range(1, 5):
		var run := 1 + (s % 3)
		_fresh(s * 11, run)
		var apt := ""
		if s % 2 == 0:
			var site: Dictionary = Quests.site("ethel")
			apt = str(site.get("apt", ""))
		else:
			for f in range(3, 20):
				WorldState.seed_floor_door_states(f)
				for col in range(1, 6):
					var a := "%d%02d" % [f, col]
					if SurvivorPlan.hider_flat_ok(a) and not SurvivorPlan.hider_for(a).is_empty():
						apt = a
						break
				if apt != "":
					break
		if apt == "":
			continue
		WorldState.set_door_state(apt, WorldState.DoorState.OPEN)
		WorldState.current_apartment_id = apt
		WorldState.current_floor = WorldState._apartment_floor(apt)
		WorldState.spawn_source = ""
		WorldState.saved_player_x = 0.0
		var room = load("res://scenes/room.tscn").instantiate()
		add_child(room)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var p = get_tree().get_first_node_in_group("player")
		var x_min := 99999.0
		var x_max := -99999.0
		var inward := 1.0 if WorldState.get_entrance_side(apt) == "left" else -1.0     # the front door is the way OUT of the flat
		for step in 900:
			await get_tree().physics_frame
			# forward 200 steps, back 100: always working inward, never back out of the front door
			var dir: float = inward if (step % 300) < 200 else -inward
			Input.action_press("move_right" if dir > 0.0 else "move_left")
			Input.action_release("move_left" if dir > 0.0 else "move_right")
			var talker_near := false
			for sv in get_tree().get_nodes_in_group("survivor"):
				if is_instance_valid(sv) and room.is_ancestor_of(sv) and sv._talk_near:
					talker_near = true
					if sv.has_choices() and step % 90 == 0:
						Quests.choose(sv, 0)
			if talker_near and step % 60 == 0:
				Input.action_press("interact")       # (elsewhere E would be the front door, and the scene would change)
			elif step % 60 == 5:
				Input.action_release("interact")
			if step % 30 == 0 and is_instance_valid(p):
				x_min = minf(x_min, p.global_position.x)
				x_max = maxf(x_max, p.global_position.x)
				for n in get_tree().get_nodes_in_group("survivor"):
					if is_instance_valid(n) and room.is_ancestor_of(n):
						var pos: Vector2 = n.global_position
						if not (is_finite(pos.x) and is_finite(pos.y)) or pos.x < 60.0 or pos.x > 1200.0:
							bad += 1
		_release_all()
		if x_max - x_min < 100.0:
			held += 1
			print("      the player was held in %s: x %.0f..%.0f" % [apt, x_min, x_max])
		flats += 1
		room.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	check(flats >= 3, "(setup) %d flats were soaked" % flats)
	check(bad == 0, "no survivor left the flat or went non-finite (%d)" % bad)
	check(held == 0, "the player could always walk the flat (%d held)" % held)
