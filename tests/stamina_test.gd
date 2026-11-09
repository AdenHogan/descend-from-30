extends Node

# What moving costs in stamina (owner round 49d: "stamina is no longer a thing to be overly concerned about… bump degeneration for running by
# 20%… moving in combat should also hit stamina, but it needs to be a gradual reduction considering that it is a faster movement pace").
#   • sprinting drains STAMINA_SPRINT_DRAIN a second — 20 % more than the old 12;
#   • walking at the COMBAT pace drains STAMINA_COMBAT_WALK_DRAIN a second — gradual (about a fifth of a sprint) — and nothing comes back while it does;
#   • the slow scavenge walk, a crouch and god mode cost nothing (and the first two recover);
#   • every rate runs through the character's / the upgrades' sprint-drain multiplier, so the check reads it (a random cast deals any of the four).
# And the SHOVE (owner round 49q: "why hide when you can just push? push should come at a cost"): from floor 25 down (the descent ramp, `WorldState.descent_ramp`) a shove needs a FULL
# bar (a character with two charges: half a bar), wipes it out (or half), and the bar then waits a long beat before it fills again — a bar that has refilled to 99 % does not shove. Joe
# (the Tenant) has two charges, the Brawler perk gives another character two; everyone else one. The first floors (30, 29) keep the old numbers exactly.
# Run: godot --headless res://tests/stamina_test.tscn

var failures: int = 0
var p = null


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== stamina test ===")
	await _setup()
	_test_numbers()
	await _test_sprint_cost()
	await _test_combat_walk()
	await _test_free_movement()
	await _test_empty_bar()
	await _test_sprint_floor()
	await _test_push_easy_floors()
	await _test_push_deep()
	await _test_push_charges()
	WorldState.dev_ramp_override = -1
	Input.action_release("move_right")
	Input.action_release("sprint")
	p.queue_free()
	WorldState.god_mode = false
	WorldState.is_scavenge_mode = false
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _setup() -> void:
	WorldState.new_game()
	WorldState.god_mode = false
	WorldState.is_scavenge_mode = false
	WorldState.inventory.clear()
	p = load("res://scenes/player.tscn").instantiate()
	add_child(p)
	p.global_position = Vector2(300, 386)
	for i in range(3):
		await get_tree().physics_frame


## Run the physics for `sec` seconds; returns the time that really passed.
func _run(sec: float) -> float:
	var t := 0.0
	while t < sec:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	return t


## Start a fresh measurement: this much stamina, no recovery delay pending, back at the start of the corridor.
func _reset(stam: float) -> void:
	WorldState.stamina = stam
	p.stamina_recovery_timer = 0.0
	p.global_position = Vector2(300, 386)
	p.velocity = Vector2.ZERO


func _test_numbers() -> void:
	print("[the numbers]")
	var P = load("res://scripts/player.gd")
	check(is_equal_approx(P.STAMINA_SPRINT_DRAIN, 12.0 * 1.2), "a sprint costs 20 %% more than the old 12 a second (%.1f)" % P.STAMINA_SPRINT_DRAIN)
	check(P.STAMINA_COMBAT_WALK_DRAIN > 0.0 and P.STAMINA_COMBAT_WALK_DRAIN * 3.0 < P.STAMINA_SPRINT_DRAIN, "walking in combat costs something, but gradually — under a third of a sprint (%.1f)" % P.STAMINA_COMBAT_WALK_DRAIN)


func _test_sprint_cost() -> void:
	print("[sprinting]")
	var mult: float = WorldState.get_sprint_drain_mult()
	_reset(WorldState.get_max_stamina())
	Input.action_press("move_right")
	Input.action_press("sprint")
	var s0: float = WorldState.stamina
	var t: float = await _run(1.0)
	var rate: float = (s0 - WorldState.stamina) / t
	Input.action_release("sprint")
	Input.action_release("move_right")
	check(p.velocity.x > 200.0 or WorldState.stamina < s0, "it really sprinted")
	check(absf(rate - 14.4 * mult) <= 14.4 * mult * 0.08, "a sprint drains %.1f a second (expected %.1f with this character's multiplier %.2f)" % [rate, 14.4 * mult, mult])


func _test_combat_walk() -> void:
	print("[walking at the combat pace]")
	var mult: float = WorldState.get_sprint_drain_mult()
	WorldState.is_scavenge_mode = false
	p.is_crouching = false
	_reset(WorldState.get_max_stamina())
	Input.action_press("move_right")
	var s0: float = WorldState.stamina
	var t: float = await _run(2.0)
	var rate: float = (s0 - WorldState.stamina) / t
	var moved: float = p.global_position.x - 300.0
	Input.action_release("move_right")
	check(moved > 150.0, "it walked at the combat pace (%.0f px in %.1f s)" % [moved, t])
	check(absf(rate - 3.0 * mult) <= 3.0 * mult * 0.10, "combat walking drains %.2f a second (expected %.2f)" % [rate, 3.0 * mult])
	check(rate * 3.0 < 14.4 * mult, "…gradually: well under a third of a sprint")
	# nothing comes back while it keeps walking: the bar only ever goes down
	_reset(50.0)
	Input.action_press("move_right")
	var lowest_ok := true
	var prev: float = WorldState.stamina
	var elapsed := 0.0
	while elapsed < 2.0:
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
		if WorldState.stamina > prev + 0.001:
			lowest_ok = false
		prev = WorldState.stamina
	Input.action_release("move_right")
	check(lowest_ok and WorldState.stamina < 50.0, "no stamina comes back while it walks in combat mode (50 → %.1f)" % WorldState.stamina)


func _test_free_movement() -> void:
	print("[the slow walk, a crouch and god mode cost nothing]")
	# scavenge walking recovers
	WorldState.is_scavenge_mode = true
	p.is_crouching = false
	_reset(50.0)
	Input.action_press("move_right")
	await _run(2.5)
	Input.action_release("move_right")
	check(WorldState.stamina > 55.0, "walking in scavenge mode costs nothing and the bar recovers (50 → %.1f)" % WorldState.stamina)
	# a crouch walk in combat mode recovers too
	WorldState.is_scavenge_mode = false
	p.is_crouching = true
	_reset(50.0)
	Input.action_press("move_right")
	await _run(2.5)
	Input.action_release("move_right")
	check(WorldState.stamina > 55.0, "crouch-walking in combat mode costs nothing (50 → %.1f)" % WorldState.stamina)
	p.is_crouching = false
	# god mode drains nothing
	WorldState.god_mode = true
	_reset(60.0)
	Input.action_press("move_right")
	await _run(1.5)
	Input.action_press("sprint")
	await _run(1.0)
	Input.action_release("sprint")
	Input.action_release("move_right")
	check(WorldState.stamina >= 59.9, "god mode: walking and sprinting in combat mode drain nothing (%.1f)" % WorldState.stamina)
	WorldState.god_mode = false
	# standing still in combat mode recovers
	_reset(50.0)
	await _run(2.5)
	check(WorldState.stamina > 55.0, "standing still in combat mode recovers (50 → %.1f)" % WorldState.stamina)


func _test_empty_bar() -> void:
	print("[an empty bar]")
	WorldState.is_scavenge_mode = false
	_reset(0.0)
	Input.action_press("move_right")
	await _run(2.0)
	check(WorldState.stamina <= 0.001, "walking on in combat mode keeps it at nothing — it does not creep back (%.2f)" % WorldState.stamina)
	check(p.global_position.x - 300.0 > 150.0, "…and it is no slower: the cost is the bar, not the pace")
	Input.action_release("move_right")
	await _run(2.2)
	check(WorldState.stamina > 3.0, "stop, and it recovers (%.1f)" % WorldState.stamina)


func _test_sprint_floor() -> void:
	print("[the sprint's re-engage floor is where it was: 2.4]")
	var P = load("res://scripts/player.gd")
	check(is_equal_approx(P.STAMINA_SPRINT_MIN, 12.0 * 0.2), "unchanged from the old 12 x 0.2 (%.2f)" % P.STAMINA_SPRINT_MIN)
	WorldState.is_scavenge_mode = false
	_reset(2.0)
	Input.action_press("move_right")
	Input.action_press("sprint")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var low: bool = p.is_running
	Input.action_release("sprint")
	await get_tree().physics_frame
	_reset(4.0)
	Input.action_press("sprint")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var ok: bool = p.is_running
	Input.action_release("sprint")
	Input.action_release("move_right")
	check(not low and ok, "below 2.4 a sprint will not start; above it, it does (low %s, ok %s)" % [str(low), str(ok)])


## Deal a playthrough whose first run is `cid` (the cast is a seeded draw), with no upgrades.
func _play_as(cid: String) -> void:
	WorldState.new_game()
	WorldState.god_mode = false
	WorldState.is_scavenge_mode = false
	WorldState.active_upgrades.clear()
	for sd in range(1, 5000):
		WorldState.master_seed = sd
		if WorldState.run_character(1) == cid:
			break
	WorldState.current_run = 1
	WorldState.stamina = WorldState.get_max_stamina()
	p.global_position = Vector2(300, 386)
	p.last_push_time = -100.0
	p.stamina_recovery_timer = 0.0
	p.push_count_window = 0
	p.is_pushing = false
	p.push_timer = 0.0


func _shove() -> void:
	p.is_pushing = false
	p.push_timer = 0.0
	p.last_push_time = -100.0
	p._do_push()


## The first floors keep the old numbers EXACTLY: the floor-30 / floor-29 shove costs what it cost, refuses only a spent bar, and the bar waits a short beat.
func _test_push_easy_floors() -> void:
	print("[the first floors (30, 29): the shove is what it was]")
	for who in ["blond_woman", "blond_man"]:
		_play_as(who)
		for fl in [30, 29]:
			WorldState.current_floor = fl
			WorldState.dev_ramp_override = -1
			var bar: float = WorldState.get_max_stamina()
			WorldState.stamina = bar
			p.stamina_recovery_timer = 0.0
			_shove()
			var spent: float = bar - WorldState.stamina
			check(absf(spent - 28.0 * WorldState.get_push_cost_mult()) < 0.01, "%s, floor %d: a shove costs %.1f, the old 28 x the character's push cost" % [who, fl, spent])
			check(p.stamina_recovery_timer >= WorldState.PUSH_RECOVERY_EASY - 0.01 and p.stamina_recovery_timer < 1.5, "…and the bar waits a short beat (%.2f s) before it refills" % p.stamina_recovery_timer)
			WorldState.stamina = 12.0
			var before: float = WorldState.stamina
			_shove()
			check(WorldState.stamina < before, "…and a bar at 12 still has a shove in it (as before)")
			WorldState.stamina = 6.0
			_shove()
			check(WorldState.stamina == 6.0, "…but a nearly spent one does not (%.1f)" % WorldState.stamina)
		check(WorldState.push_min_stamina_for(30) == 10.0 and WorldState.push_min_stamina_for(29) == 10.0, "(the floor a shove needs on floors 30 and 29 is the old 10)")


## From floor 25 down: a full bar, all of it gone, a long wait, and a bar at 99 % does not do.
func _test_push_deep() -> void:
	print("[floor 25 and below: a shove needs a FULL bar, wipes it, and the bar waits]")
	_play_as("blond_woman")                                  # (one charge: not the Tenant, no perk)
	WorldState.current_floor = 20
	WorldState.dev_ramp_override = -1
	check(WorldState.descent_ramp(20) == 1.0 and WorldState.get_push_charges() == 1, "(setup) floor 20, full ramp, one charge (%d)" % WorldState.get_push_charges())
	var bar: float = WorldState.get_max_stamina()
	check(is_equal_approx(WorldState.push_cost_for(20), bar) and WorldState.push_min_stamina_for(20) > bar - 0.01 and WorldState.push_min_stamina_for(20) < bar, "a shove costs the whole bar (%.1f of %.1f) and needs all of it" % [WorldState.push_cost_for(20), bar])
	WorldState.stamina = bar
	p.stamina_recovery_timer = 0.0
	_shove()
	check(WorldState.stamina <= 0.001, "a shove from a full bar leaves nothing (%.2f)" % WorldState.stamina)
	check(p.stamina_recovery_timer >= WorldState.PUSH_RECOVERY_DEEP - 0.01, "…and stamina does not start to come back for a long beat (%.2f s, the old rest was %.1f)" % [p.stamina_recovery_timer, p.STAMINA_RECOVERY_DELAY])
	# the beat is real: it refills only after it
	var t0: float = WorldState.stamina
	await _run(1.5)
	check(WorldState.stamina <= t0 + 0.5, "…and for the first second and a half there is none (%.2f)" % WorldState.stamina)
	# a bar that has refilled to 99 % does not shove; a full one does
	WorldState.stamina = bar * 0.99
	var shown_before := HUD.feedback_label.text
	_shove()
	check(is_equal_approx(WorldState.stamina, bar * 0.99), "a bar at 99 %% will not shove: it needs ALL of it, regenerating or not (%.2f of %.2f)" % [WorldState.stamina, bar])
	check(HUD.feedback_label.text == "I need my wind back to shove.", "…and says why ('%s')" % HUD.feedback_label.text)
	WorldState.stamina = 5.0
	_shove()
	check(HUD.feedback_label.text == "Too exhausted to push.", "…a spent bar says it is spent ('%s')" % HUD.feedback_label.text)
	WorldState.stamina = bar
	_shove()
	check(WorldState.stamina <= 0.001, "…and a full bar shoves again")
	# repeated shoves are not doubled deep down: the bar itself is the limit
	WorldState.stamina = bar
	p.push_count_window = 5
	p.last_push_time = Time.get_ticks_msec() / 1000.0
	p.is_pushing = false
	p._do_push()
	check(WorldState.stamina <= 0.001, "(a quick second shove from a full bar takes the bar, not a doubled bar)")
	# god mode pays nothing
	WorldState.god_mode = true
	WorldState.stamina = 3.0
	HUD.feedback_label.text = ""
	_shove()
	check(WorldState.stamina == 3.0 and not HUD.feedback_label.text.begins_with("Too exhausted"), "god mode shoves from anything, for nothing")
	WorldState.god_mode = false
	# the ramp: floor 28 is a quarter of the way, floor 25 all the way
	WorldState.dev_ramp_override = -1
	check(is_equal_approx(WorldState.push_cost_for(28), lerpf(28.0 * WorldState.get_push_cost_mult(), bar, 0.25)) and is_equal_approx(WorldState.push_cost_for(25), bar), "the cost climbs with the descent: a quarter of the way at 28 (%.1f), all of it at 25 (%.1f)" % [WorldState.push_cost_for(28), WorldState.push_cost_for(25)])


## Two charges (Joe; the Brawler perk for anyone): two shoves from a full bar, none from half of one.
func _test_push_charges() -> void:
	print("[two charges: Joe, and the Brawler perk]")
	_play_as("blond_man")
	WorldState.current_floor = 20
	var bar: float = WorldState.get_max_stamina()
	check(WorldState.get_push_charges() == 2, "Joe (the Tenant) has two shoves in a full bar")
	check(is_equal_approx(WorldState.push_cost_for(20), bar * 0.5), "…each half the bar (%.1f)" % WorldState.push_cost_for(20))
	WorldState.stamina = bar
	_shove()
	check(absf(WorldState.stamina - bar * 0.5) < 0.01, "the first takes half (%.1f left)" % WorldState.stamina)
	_shove()
	check(WorldState.stamina <= 0.001, "…the second takes the rest, with no refill between")
	_shove()
	check(WorldState.stamina <= 0.001, "…and there is no third")
	WorldState.stamina = bar * 0.49
	var before: float = WorldState.stamina
	_shove()
	check(is_equal_approx(WorldState.stamina, before), "less than half a bar will not shove (%.1f)" % WorldState.stamina)
	WorldState.stamina = bar * 0.5
	_shove()
	check(WorldState.stamina <= 0.5, "…half a bar will")
	# another character, one charge — and the Brawler perk makes it two
	_play_as("dark_woman")
	WorldState.current_floor = 20
	check(WorldState.get_push_charges() == 1, "everyone else has one")
	WorldState.active_upgrades = ["B_brawler"]
	check(WorldState.get_push_charges() == 2, "…the Brawler perk gives them a second")
	bar = WorldState.get_max_stamina()
	WorldState.stamina = bar
	_shove()
	check(absf(WorldState.stamina - bar * 0.5) < 0.01, "…and a shove then takes half the bar (%.1f left)" % WorldState.stamina)
	WorldState.active_upgrades.clear()
	_play_as("blond_man")
	WorldState.active_upgrades = ["B_brawler"]
	check(WorldState.get_push_charges() == 3, "Joe with the Brawler has three: the charges add")
	WorldState.active_upgrades.clear()
