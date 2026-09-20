extends Node

# Regression: the player must NEVER be permanently walled by a body. The flat plane pins Y
# (_move_locked), so a solid body dead ahead is an absolute wall the player can't slide
# around — the softlock class the owner hit at a burning/barricaded door with dying zombies.
# The anti-stuck safety net (player._update_unjam) GUARANTEES escape: if the player is trying
# to walk but hasn't moved for STUCK_UNJAM_TIME, it phases through nearby bodies (player-side
# collision exceptions, universal — works even for the big zombie/boss, which has no passable
# API), then re-solidifies each the instant it's clear.
# Run: godot --headless res://tests/softlock_test.tscn

var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== softlock (anti-stuck safety net) test ===")
	await _test_unstick(load("res://scenes/enemy_zombie_standard.tscn"), "standard zombie")
	await _test_unstick(load("res://scenes/enemy_zombie_big.tscn"), "big zombie / boss (no passable API)")
	await _test_unstick(load("res://scenes/enemy_zombie_crawler.tscn"), "crawler (wide 80px body)")
	await _test_wall_only_no_error()
	await _test_resolidify_clearance()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _test_unstick(scene: PackedScene, label: String) -> void:
	print("[walled by a solid %s at a doorway]" % label)
	WorldState.new_game()
	WorldState.god_mode = true
	var p = load("res://scenes/player.tscn").instantiate()
	add_child(p)
	p.global_position = Vector2(600, 388)
	var z = scene.instantiate()
	add_child(z)
	z.global_position = Vector2(645, 372)   # a solid body a few px ahead, on the player's path
	z.set("state", "idle")
	z.set_physics_process(false)            # a pure, stationary obstacle
	# Let _ready run (groups joined), then confirm it starts SOLID (no player exception yet).
	for i in range(3):
		await get_tree().physics_frame
	var start_x: float = p.global_position.x
	# Drive the player RIGHT, into and past the blocker, via a click-move target beyond it.
	p.set("has_move_target", true)
	p.set("move_target_x", 780.0)
	# Before the net's dwell time elapses, the player should be BLOCKED (proves the body is a
	# real wall, so the later pass-through is the net, not an open lane).
	for f in range(12):                     # ~0.2s < STUCK_UNJAM_TIME (0.5s)
		await get_tree().physics_frame
	var early_x: float = p.global_position.x
	check(early_x < 640.0, "%s: player is genuinely blocked before the net kicks in (x=%.1f)" % [label, early_x])
	# Now give it time: the net must phase the player through.
	p.set("has_move_target", true)
	p.set("move_target_x", 780.0)
	for f in range(150):                    # ~2.5s, ample for the 0.5s dwell + slide-through
		await get_tree().physics_frame
	var end_x: float = p.global_position.x
	check(end_x > 700.0, "%s: player got PAST the wall (x %.1f -> %.1f)" % [label, start_x, end_x])
	# Once clear, the body must re-solidify (exception dropped) — the net is momentary.
	check(not (z in p.get("_phased_bodies")), "%s: body released from the phase list once cleared" % label)
	p.queue_free()
	if is_instance_valid(z):
		z.queue_free()
	WorldState.god_mode = false
	await get_tree().physics_frame


func _test_wall_only_no_error() -> void:
	# Pressing into a real wall (no zombie) must NOT error and must leave the phase list empty
	# (nothing to phase) — the net is a no-op against static geometry.
	print("[pressing into geometry with no zombie nearby]")
	WorldState.new_game()
	WorldState.god_mode = true
	var p = load("res://scenes/player.tscn").instantiate()
	add_child(p)
	p.global_position = Vector2(600, 388)
	for i in range(2):
		await get_tree().physics_frame
	# Fake being stuck by pushing toward a target while something (nothing here) blocks: just
	# drive and confirm no phased bodies accumulate when there are no zombies.
	p.set("has_move_target", true)
	p.set("move_target_x", 780.0)
	for f in range(60):
		await get_tree().physics_frame
	check((p.get("_phased_bodies") as Array).is_empty(), "no zombies -> phase list stays empty")
	p.queue_free()
	WorldState.god_mode = false
	await get_tree().physics_frame


func _test_resolidify_clearance() -> void:
	# The width-aware clearance: a wide crawler kept passable must NOT re-solidify while it
	# still horizontally overlaps the player (the old flat 26px re-solidified mid-overlap and
	# jammed both bodies). Clearance must exceed the crawler's half-width (40) + player half.
	print("[re-solidify clearance is width-aware]")
	var z = load("res://scenes/enemy_zombie_crawler.tscn").instantiate()
	add_child(z)
	await get_tree().physics_frame
	var clr: float = z._resolidify_clearance()
	check(clr > 50.0, "crawler re-solidify clearance covers its wide body (%.1f > 50)" % clr)
	z.queue_free()
	await get_tree().physics_frame
