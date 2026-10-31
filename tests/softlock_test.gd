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
	await _test_net_survives_zombie_resolidify(load("res://scenes/enemy_zombie_standard.tscn"), "standard zombie")
	await _test_net_survives_zombie_resolidify(load("res://scenes/enemy_zombie_big.tscn"), "big zombie")
	await _test_jitter_pin()
	await _test_freed_phased_body_is_quiet()
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


func _test_net_survives_zombie_resolidify(scene: PackedScene, label: String) -> void:
	# The descent bot found the net defeated for good: it phased a zombie, the ZOMBIE then re-solidified itself
	# (taking the mutual collision exception off with its own remove_collision_exception_with — what _try_resolidify does
	# once the player is horizontally clear of it), the player's phase list still listed it, so the net never phased it
	# again and the player stood pinned with the stuck timer climbing. The net must notice the exception is gone.
	print("[the net still frees the player after a %s re-solidifies itself mid-overlap]" % label)
	WorldState.new_game()
	WorldState.god_mode = true
	var p = load("res://scenes/player.tscn").instantiate()
	add_child(p)
	p.global_position = Vector2(600, 388)
	var z = scene.instantiate()
	add_child(z)
	z.global_position = Vector2(645, 372)
	z.set("state", "idle")
	z.set_physics_process(false)
	for i in range(3):
		await get_tree().physics_frame
	p.set("has_move_target", true)
	p.set("move_target_x", 780.0)
	# wait until the net has phased it and the player is sliding INTO the body
	var phased := false
	for f in range(200):
		await get_tree().physics_frame
		p.set("has_move_target", true)
		p.set("move_target_x", 780.0)
		if z in p.get("_phased_bodies") and p.global_position.x >= z.global_position.x - 14.0:
			phased = true
			break
	check(phased, "%s: the net phased it and the player is inside its body (x %.1f, body %.1f)" % [label, p.global_position.x, z.global_position.x])
	# the zombie re-solidifies itself, exactly as _try_resolidify does — the list is NOT told
	z.remove_collision_exception_with(p)
	p.remove_collision_exception_with(z)
	z.set("passable_to_player", false)
	check(z in p.get("_phased_bodies"), "(setup) the player's list still says phased while the body is solid again")
	var x0: float = p.global_position.x
	for f in range(180):                    # 3 s: the 0.5 s dwell, then through
		await get_tree().physics_frame
		p.set("has_move_target", true)
		p.set("move_target_x", 780.0)
	check(p.global_position.x > z.global_position.x + 20.0, "%s: the player still got PAST it (x %.1f -> %.1f, body at %.1f)" % [label, x0, p.global_position.x, z.global_position.x])
	p.queue_free()
	if is_instance_valid(z):
		z.queue_free()
	WorldState.god_mode = false
	await get_tree().physics_frame


func _test_jitter_pin() -> void:
	# The descent bot's 30-75 s pins (round 49f): wedged between a solid body and a defender's endless fight, the player did not stand
	# still — depenetration shoved them about ±0.6 px a frame, which beat the old per-frame "moved < 0.5" test every other frame, so the
	# stuck timer never grew and the net never fired. The net must judge NET progress. The player's own physics is switched off so this
	# drives _update_unjam directly with the positions the bot's stall trace recorded (437.0 / 437.6, alternating).
	print("[the net fires for a player jittering ±0.6 px a frame, and not for one who is walking]")
	WorldState.new_game()
	WorldState.god_mode = true
	var p = load("res://scenes/player.tscn").instantiate()
	add_child(p)
	p.global_position = Vector2(437.0, 388)
	var z = load("res://scenes/enemy_zombie_standard.tscn").instantiate()
	add_child(z)
	z.global_position = Vector2(460, 372)
	z.set("state", "idle")
	z.set_physics_process(false)
	for i in range(3):
		await get_tree().physics_frame
	p.set_physics_process(false)             # the test is the only thing moving / judging the player now
	p.set("_stuck_time", 0.0)
	p.set("_unjam_ref_x", p.global_position.x)
	# 1. a real walk (2.5 px a frame = 150 px/s, beside the body) never trips it, however long it goes on
	var x: float = 300.0
	var worst: float = 0.0
	for f in range(120):
		x += 2.5
		p.global_position.x = x
		p.call("_update_unjam", true)
		worst = maxf(worst, float(p.get("_stuck_time")))
		await get_tree().physics_frame
	check(worst < 0.1 and (p.get("_phased_bodies") as Array).is_empty(), "a walking player never builds up stuck time or phases a body (worst %.2f s of %.1f)" % [worst, p.STUCK_UNJAM_TIME])
	# a slow walk is no jitter either: the slowest real walk (crouch 60 px/s x a trait's 0.7 = 0.7 px a frame)
	x = 300.0
	worst = 0.0
	for f in range(240):
		x += 0.7
		p.global_position.x = x
		p.call("_update_unjam", true)
		worst = maxf(worst, float(p.get("_stuck_time")))
		await get_tree().physics_frame
	check(worst < p.STUCK_UNJAM_TIME * 0.5 and (p.get("_phased_bodies") as Array).is_empty(), "the slowest walk (0.7 px a frame) is still progress (worst %.2f s)" % worst)
	# 2. the same wedge, with nobody pressing anything: the net stays out of it
	p.global_position.x = 437.0
	p.set("_stuck_time", 0.0)
	p.set("_unjam_ref_x", 437.0)
	for f in range(90):
		p.global_position.x = 437.0 + (0.6 if f % 2 == 0 else 0.0)
		p.call("_update_unjam", false)
		await get_tree().physics_frame
	check((p.get("_phased_bodies") as Array).is_empty(), "not trying to move -> the net does not phase anything")
	# 3. trying to move, shuffled about by the body: after STUCK_UNJAM_TIME the body is phased
	var fired_at := -1
	for f in range(90):                       # 1.5 s
		p.global_position.x = 437.0 + (0.6 if f % 2 == 0 else 0.0)
		p.call("_update_unjam", true)
		if z in (p.get("_phased_bodies") as Array) and fired_at < 0:
			fired_at = f
		await get_tree().physics_frame
	check(fired_at >= 0, "a jittering player (±0.6 px a frame) trying to walk is freed (phased at frame %d)" % fired_at)
	check(fired_at >= 0 and fired_at <= 40, "...within about the dwell time (0.5 s = 30 frames; got %d)" % fired_at)
	p.queue_free()
	if is_instance_valid(z):
		z.queue_free()
	WorldState.god_mode = false
	await get_tree().physics_frame


## Collects engine errors while a test runs (OS.add_logger): the gate only scans for SCRIPT ERROR / Parse Error, and an engine ERROR line
## would otherwise pass unseen.
class ErrCatch extends Logger:
	var n: int = 0
	var last: String = ""

	func _log_error(function: String, file: String, line: int, _code: String, rationale: String, _editor_notify: bool, _error_type: int, _backtraces: Array[ScriptBacktrace]) -> void:
		n += 1
		last = "%s:%d in %s: %s" % [file, line, function, rationale]


func _test_freed_phased_body_is_quiet() -> void:
	# The net checks that a body it phased is still excepted. Asking the player for get_collision_exceptions() resolved EVERY
	# excepted RID to an object — including those of zombies since freed — and logged "Parameter body is null" once per call, per
	# frame (2469 lines in one bot run). The net must be quiet when a phased neighbour dies and is freed.
	print("[the net is quiet when a body in the player's exception list has been freed]")
	WorldState.new_game()
	WorldState.god_mode = true
	var catcher := ErrCatch.new()
	OS.add_logger(catcher)
	var p = load("res://scenes/player.tscn").instantiate()
	add_child(p)
	p.global_position = Vector2(600, 388)
	var z1 = load("res://scenes/enemy_zombie_standard.tscn").instantiate()
	var z2 = load("res://scenes/enemy_zombie_big.tscn").instantiate()
	add_child(z1)
	add_child(z2)
	z1.global_position = Vector2(640, 372)
	z2.global_position = Vector2(650, 372)
	for z in [z1, z2]:
		z.set("state", "idle")
		z.set_physics_process(false)
	for i in range(3):
		await get_tree().physics_frame
	var both := false
	for f in range(150):
		p.set("has_move_target", true)
		p.set("move_target_x", 780.0)
		await get_tree().physics_frame
		if (p.get("_phased_bodies") as Array).size() >= 2:
			both = true
			break
	check(both, "the net phased both bodies (%d in the list)" % (p.get("_phased_bodies") as Array).size())
	z1.queue_free()                       # one dies and is freed; the other is still in the list
	var before := catcher.n
	for f in range(20):
		p.set("has_move_target", true)
		p.set("move_target_x", 780.0)
		await get_tree().physics_frame
	check(catcher.n == before, "no engine error while a freed body's exception lingers (%d new: %s)" % [catcher.n - before, catcher.last])
	OS.remove_logger(catcher)
	p.queue_free()
	if is_instance_valid(z2):
		z2.queue_free()
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
