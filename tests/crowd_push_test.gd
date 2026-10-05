extends Node

# Headless test for pushing through a CROWD (owner round 36e: "if a player pushes an enemy and there is another directly
# behind, the player might not be able to reach and push the next enemy, however that one does have the attack range to hurt
# the player… a soft lock where the player cannot progress through use of push alone"). Run:
#   godot --headless res://tests/crowd_push_test.tscn

var failures: int = 0
const STANDARD := "res://scenes/enemy_zombie_standard.tscn"
const LONGARM := "res://scenes/enemy_zombie_longarm.tscn"
const BIG := "res://scenes/enemy_zombie_big.tscn"


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== crowd / push test ===")
	await _test_reach_matches_strike()
	await _test_spent_target_skipped()
	await _test_push_through_crowd(STANDARD, [650.0, 660.0, 672.0, 684.0], "four standard zombies")
	await _test_push_through_crowd(LONGARM, [650.0, 660.0, 672.0], "three long-arms")
	await _test_push_through_crowd(BIG, [650.0, 665.0], "two big zombies")
	await _test_mixed_aggro()
	await _test_make_way_is_temporary()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


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


func _spawn(bf: Node, scene: String, x: float) -> Node:
	var z = load(scene).instantiate()
	z.global_position = Vector2(x, 370.0 if scene == STANDARD else 374.0)
	bf.add_child(z)
	return z


func _finish(bf: Node) -> void:
	Input.action_release("move_right")
	WorldState.god_mode = false
	bf.free()
	await get_tree().process_frame


func _test_reach_matches_strike() -> void:
	# Anything that can strike the player from where it stands can be shoved from there.
	print("[push reach: what can hit me can be shoved]")
	var bf = await _corridor()
	var p = bf.get_node("Player")
	p.global_position = Vector2(600, 386)
	WorldState.is_scavenge_mode = false
	p.animated_sprite.flip_h = false
	var la = _spawn(bf, LONGARM, 666.0)             # 66 away: inside its 62-reach strike (+ margin), far outside a plain 40 px shove
	await get_tree().physics_frame
	la.set_physics_process(false)
	check(la.strike_reach() >= 60.0, "a long-arm strikes from 60+ px (%.0f)" % la.strike_reach())
	check(p.push_target() == la, "…so the shove reaches it")
	la.global_position.x = 740.0
	check(p.push_target() == null, "a body far outside its own strike reach is still out of range")
	la.free()
	# a plain body whose strike reaches well past a 40 px shove (the long-arm's wide capsule would pass on edge distance alone)
	var long_std = _spawn(bf, STANDARD, 656.0)
	await get_tree().physics_frame
	long_std.set_physics_process(false)
	long_std.ATTACK_RANGE = 58.0
	var edge: float = 56.0 - p._zombie_body_radius(long_std)
	check(edge > p.PUSH_RANGE and long_std.strike_reach() >= 58.0, "(a body 56 px off, edge %.0f px — past a plain 40 px shove, inside its own strike)" % edge)
	check(p.push_target() == long_std, "…is shoveable because it can strike from there")
	long_std.global_position.x = 700.0
	check(p.push_target() == null, "…and not once it is out of its own strike")
	long_std.free()
	# a body standing back in a crowd (rank 2 strikes from reach + 26)
	var zs := []
	for x in [630.0, 643.0, 656.0]:
		var z = _spawn(bf, STANDARD, x)
		z.alert_timer = 60.0
		zs.append(z)
	await get_tree().physics_frame
	for z in zs:
		z.set_physics_process(false)
	var back = zs[2]
	var dx: float = back.global_position.x - p.global_position.x
	check(p._can_strike_me(back, dx) == (absf(dx) <= back.strike_reach() + p.PUSH_STRIKE_SLACK), "the reach rule is exactly 'within its own strike reach'")
	await _finish(bf)


func _test_spent_target_skipped() -> void:
	# A shove on a body already reeling does nothing: aim at the next one.
	print("[push target: never wasted on one already staggered]")
	var bf = await _corridor()
	var p = bf.get_node("Player")
	p.global_position = Vector2(600, 386)
	WorldState.is_scavenge_mode = false
	var a = _spawn(bf, STANDARD, 630.0)
	var b = _spawn(bf, STANDARD, 643.0)
	await get_tree().physics_frame
	a.set_physics_process(false)
	b.set_physics_process(false)
	check(p.push_target() == a, "the nearest is the target")
	a.receive_push(100.0)
	check(a.push_spent(), "a shoved body is spent")
	check(p.push_target() == b, "the next shove goes to the one behind it (%s)" % str(p.push_target()))
	b.receive_push(100.0)
	check(p.push_target() != null, "with everyone spent a shove still has a target (it just wastes itself)")
	await _finish(bf)


func _test_push_through_crowd(scene: String, xs: Array, label: String) -> void:
	# A player who only ever pushes and walks (holding the move key, shoving whenever a body is in reach) gets through.
	print("[push-only player gets through ", label, "]")
	var bf = await _corridor()
	var p = bf.get_node("Player")
	WorldState.god_mode = true
	WorldState.is_scavenge_mode = false
	p.global_position = Vector2(600, 386)
	var zs := []
	for x in xs:
		zs.append(_spawn(bf, scene, x))
	await get_tree().physics_frame
	for z in zs:
		z.alert_timer = 120.0
		z.current_hp = 999
	Input.action_press("move_right")
	var t := 0.0
	var last_push := -9.0
	var pushes := 0
	var got_through_at := -1.0
	var front := float(xs[xs.size() - 1])
	var blocked_for := 0.0
	var prev_x: float = p.global_position.x
	for f in range(60 * 20):
		await get_tree().physics_frame
		t += 1.0 / 60.0
		# a push-only player: walk (the key is held) and shove only when something stops them
		blocked_for = blocked_for + 1.0 / 60.0 if (absf(p.global_position.x - prev_x) < 0.2 and not p.is_pushing) else 0.0
		prev_x = p.global_position.x
		if blocked_for > 0.25 and not p.is_pushing and p.push_target() != null:
			p._do_push()
			pushes += 1
			blocked_for = 0.0
		if f % 120 == 0 and OS.get_environment("CROWD_DEBUG") != "":
			var line := "t=%4.1f p.x=%.0f push=%d |" % [t, p.global_position.x, pushes]
			for z in zs:
				line += " %.0f(%s%s)" % [z.global_position.x, z.get("state"), ",P" if (z.get("passable_to_player") == true or (z.has_method("is_push_passable") and z.is_push_passable())) else ""]
			print(line)
		if got_through_at < 0.0 and p.global_position.x > front + 20.0:
			got_through_at = t
			break
	check(got_through_at > 0.0, "the player is past the whole line within 20 s (%s, x=%.0f, %d pushes)" % [
		("%.1fs" % got_through_at) if got_through_at > 0.0 else "never", p.global_position.x, pushes])
	await _finish(bf)


func _test_mixed_aggro() -> void:
	# A low-aggro body that stops pursuing must not hold a high-aggro one behind it.
	print("[mixed aggro: nobody is held behind a body that stopped]")
	var bf = await _corridor()
	var p = bf.get_node("Player")
	WorldState.god_mode = true
	p.global_position = Vector2(600, 386)
	var a = _spawn(bf, STANDARD, 700.0)
	var b = _spawn(bf, STANDARD, 760.0)
	await get_tree().physics_frame
	a.DETECTION_RANGE = 60.0          # barely notices anyone — it idles where it is
	b.DETECTION_RANGE = 400.0
	b.alert_timer = 60.0
	var reached := false
	for f in range(60 * 8):
		await get_tree().physics_frame
		p.velocity = Vector2.ZERO
		if absf(b.global_position.x - p.global_position.x) <= b.strike_reach() + 2.0:
			reached = true
			break
	check(reached, "the keen one reaches striking range past the idle one (b at %.0f, a at %.0f, a %s)" % [b.global_position.x, a.global_position.x, a.state])
	await _finish(bf)


func _test_make_way_is_temporary() -> void:
	# The bodies a shove let the player past turn solid again once the player is clear (no permanent walk-through).
	print("[make way: solid again behind the player]")
	var bf = await _corridor()
	var p = bf.get_node("Player")
	WorldState.god_mode = true
	p.global_position = Vector2(600, 386)
	var a = _spawn(bf, STANDARD, 630.0)
	var b = _spawn(bf, STANDARD, 650.0)
	await get_tree().physics_frame
	a.alert_timer = 60.0
	b.alert_timer = 60.0
	var behind = _spawn(bf, STANDARD, 540.0)
	var far = _spawn(bf, STANDARD, 720.0)
	await get_tree().physics_frame
	p.animated_sprite.flip_h = false
	WorldState.is_scavenge_mode = false
	p._do_push()
	check(a.state == "hit" and a.push_spent(), "the shove stunned the nearest body")
	check(b.passable_to_player, "…and the next one in the line stops walling the player in")
	check(not behind.passable_to_player, "…a body on the OTHER side is untouched")
	check(not far.passable_to_player, "…and so is one beyond the shove's make-way range")
	b.passable_to_player = false
	b.remove_collision_exception_with(p)
	p.remove_collision_exception_with(b)
	b.make_way()
	check(b.passable_to_player, "make_way lets the player through")
	p.global_position.x = 800.0         # well clear of it
	for i in range(30):
		await get_tree().physics_frame
	check(not b.passable_to_player, "…and it is solid again once the player is clear")
	await _finish(bf)
