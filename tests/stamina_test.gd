extends Node

# What moving costs in stamina (owner round 49d: "stamina is no longer a thing to be overly concerned about… bump degeneration for running by
# 20%… moving in combat should also hit stamina, but it needs to be a gradual reduction considering that it is a faster movement pace").
#   • sprinting drains STAMINA_SPRINT_DRAIN a second — 20 % more than the old 12;
#   • walking at the COMBAT pace drains STAMINA_COMBAT_WALK_DRAIN a second — gradual (about a fifth of a sprint) — and nothing comes back while it does;
#   • the slow scavenge walk, a crouch and god mode cost nothing (and the first two recover);
#   • every rate runs through the character's / the upgrades' sprint-drain multiplier, so the check reads it (a random cast deals any of the four).
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
