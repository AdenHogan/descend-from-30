extends Node

# THE DIVE ROLL (owner 2026-11-17; docs/ENEMY_MOVEMENT.md): sprint + move + the crouch key = a short, low, committed forward roll.
#   • it needs a sprint, a direction and a FULL bar (what a shove needs); without them the crouch key just crouches;
#   • it takes the bar and starts the stamina's wait (like a shove), moves the player about ROLL_DISTANCE and ends standing;
#   • nothing lands on a rolling player (receive_hit does nothing); a swing and a shove do nothing mid-roll;
#   • the dead within reach let the roller through; a flyer's bite passes over the rolling (= crouching) player.
# Run: godot --headless res://tests/roll_test.tscn

var failures: int = 0
var p = null


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame


func _ready() -> void:
	print("=== roll test ===")
	WorldState.new_game()
	WorldState.god_mode = false
	WorldState.is_scavenge_mode = false
	WorldState.inventory.clear()
	p = load("res://scenes/player.tscn").instantiate()
	add_child(p)
	p.global_position = Vector2(600, 386)
	await _frames(3)
	var full: float = WorldState.get_max_stamina()
	WorldState.stamina = full
	# no sprint, no direction: no roll
	check(not p.can_start_roll(), "standing still with no sprint held: no roll")
	Input.action_press("sprint")
	check(not p.can_start_roll(), "sprint held but not moving: no roll")
	Input.action_press("move_right")
	await _frames(2)
	WorldState.stamina = full
	check(p.can_start_roll(), "sprinting and moving with a full bar: a roll is on offer")
	WorldState.stamina = full * 0.5
	check(not p.can_start_roll(), "half a bar is not enough (a shove's price)")
	WorldState.stamina = full
	# a dead thing in reach lets the roller through
	var z = load("res://scenes/enemy_zombie_standard.tscn").instantiate()
	add_child(z)
	z.global_position = Vector2(680, 370)
	await _frames(2)
	var x0: float = p.global_position.x
	p._start_roll()
	check(p.is_rolling and p.is_crouching, "the roll starts and the player is LOW")
	check(WorldState.stamina <= 0.01, "it takes the bar (stamina %.1f)" % WorldState.stamina)
	check(p.stamina_recovery_timer >= WorldState.push_recovery_delay() - 0.001, "...and the stamina's wait starts, like a shove")
	check(z.passable_to_player, "the thing in reach is made passable to the roller")
	var hp0: int = WorldState.player_health
	p.receive_hit(1)
	check(not p.is_hit and WorldState.player_health == hp0, "nothing lands on a rolling player")
	var swung_before: bool = p.is_attacking
	p._do_push()
	check(not p.is_pushing, "no shove from inside a roll")
	await _frames(int(p.ROLL_TIME * 60.0) + 6)
	check(not p.is_rolling and not p.is_crouching, "the roll ends, standing")
	var dist: float = p.global_position.x - x0
	check(dist > p.ROLL_DISTANCE * 0.6 and dist < p.ROLL_DISTANCE * 1.4, "it carried the player about ROLL_DISTANCE (%.0f px of %.0f)" % [dist, p.ROLL_DISTANCE])
	# without a full bar the crouch key only crouches
	WorldState.stamina = 5.0
	check(not p.can_start_roll(), "an empty bar cannot roll again")
	# a flyer passes over a rolling (crouching) player
	var f = load("res://scenes/enemy_zombie_flyer.tscn").instantiate()
	add_child(f)
	await _frames(2)
	f.player = p
	f._h = 60.0
	p.is_crouching = true
	var hits: int = WorldState.player_health
	f._deliver_attack(0.0)
	check(WorldState.player_health == hits and not p.is_hit, "a flyer high up misses a crouching / rolling player")
	Input.action_release("sprint")
	Input.action_release("move_right")
	p.queue_free()
	z.queue_free()
	f.queue_free()
	await get_tree().process_frame
	print("=== %s ===" % ("ALL PASSED" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(0 if failures == 0 else 1)
