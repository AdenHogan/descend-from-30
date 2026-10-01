extends Node

# HEIGHTS AT THE TOP OF THE STAIRS (owner round 31k): "test enemy and player heights at the top of the yellow staircases. Do they
# A, reach and clip beyond the ceiling, and B, do they clip the stairs sign. Perhaps make the stairs sign the most forward… so heads
# always go up behind it." Measured from the real sprites' drawn pixels (every frame), not from guessed heights:
#   * the player at the top of the flight (the turn into the slice) stays under the opening's top (the lintel line);
#   * stair enemies on an UP flight stand ON it (feet never above the top step, bob included) — three stacked, the worst case — and
#     anything of them above the opening's top is clipped (the flight runs on behind the wall);
#   * the STAIRS signs draw on a layer in FRONT of every actor, so a head that reaches them goes behind.
# Run: godot --headless res://tests/stair_heights_test.tscn

var failures := 0
const BF := preload("res://scripts/building_floors.gd")


func check(c: bool, m: String) -> void:
	print(("  PASS  " if c else "  FAIL  ") + m)
	if not c:
		failures += 1


## The topmost drawn (alpha > 0) world y of an AnimatedSprite2D over every frame of `anims`, as it stands now.
static func drawn_top(spr: AnimatedSprite2D, anims: Array) -> float:
	var top := INF
	for a in anims:
		if not spr.sprite_frames.has_animation(a):
			continue
		for f in spr.sprite_frames.get_frame_count(a):
			var tex: Texture2D = spr.sprite_frames.get_frame_texture(a, f)
			var used := tex.get_image().get_used_rect()
			var ly: float = used.position.y + spr.offset.y - (tex.get_size().y * 0.5 if spr.centered else 0.0)
			top = minf(top, (spr.global_transform * Vector2(0, ly)).y)
	return top


func _ready() -> void:
	print("=== stair heights test ===")
	WorldState.new_game()
	await _test_player_at_the_top()
	await _test_up_stair_enemies()
	WorldState.dev_force_stair_enemies = false
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _test_player_at_the_top() -> void:
	print("[the player at the top of the flight: under the lintel, behind the STAIRS sign]")
	WorldState.current_floor = 14
	var bf = load("res://scenes/building_floors.tscn").instantiate()
	bf.setup_floor = 14
	add_child(bf)
	for i in 4:
		await get_tree().process_frame
	var p = bf.get_node("Player")
	var spr: AnimatedSprite2D = p.get_node("AnimatedSprite2D")
	var up_side: String = WorldState.canonical_stair_arrival_side(14)       # floor 14's UP stair
	p.global_position = Vector2(188.0 if up_side == "left" else 1162.0, 386.0 - StairPan.UP_TURN_HEIGHT)
	var top: float = drawn_top(spr, ["walk", "idle"])
	check(top >= BF.STAIR_OPENING_TOP, "at the turn the player's head (%.0f) is under the opening's top (%.0f) — nothing over the ceiling" % [top, BF.STAIR_OPENING_TOP])
	var signs = bf.get_node_or_null("FloorSigns")
	var front = signs.get_node_or_null("StairSignsFront") if signs != null else null
	check(front != null and front.z_index > p.z_index and front.z_index > 1,
		"the STAIRS signs draw IN FRONT of the actors (z %s vs player %d, enemies 1)" % [str(front.z_index) if front else "-", p.z_index])
	# ...and it matters: at the turn the head really does reach up behind a sign.
	var hit := false
	if signs != null:
		for r in signs.stair_sign_rects():
			if top < r.end.y and absf(p.global_position.x - r.get_center().x) < r.size.x * 0.5 + 12.0:
				hit = true
	check(hit, "(the head at the turn does reach the sign's band — this is the case the front layer covers)")
	bf.free()
	await get_tree().process_frame


func _test_up_stair_enemies() -> void:
	print("[enemies waiting up an UP flight: on the steps, never over the ceiling — three stacked, the worst case]")
	# A building where some floor's UP staircase (choke = floor + 1) naturally rolls three.
	var found := -1
	for sd in range(1, 4000):
		WorldState.master_seed = sd
		for f in range(2, 28):
			if WorldState.stair_enemy_count(f + 1) == 3 and not WorldState.is_stair_blocked(f + 1) and WorldState.fire_intensity(f) <= 0:
				found = f
				break
		if found >= 0:
			break
	check(found >= 0, "found a staircase with three enemies on it (floor %d)" % found)
	if found < 0:
		return
	WorldState.current_floor = found
	var bf = load("res://scenes/building_floors.tscn").instantiate()
	bf.setup_floor = found
	add_child(bf)
	for i in 4:
		await get_tree().process_frame
	var ups: Array = []
	for z in get_tree().get_nodes_in_group("stair_enemy"):
		if bf.is_ancestor_of(z) and z.stair_mode and z._stair_up:
			ups.append(z)
	check(ups.size() == 3, "three enemies up the flight (%d)" % ups.size())
	var top_step_feet: float = 419.0 - StairPan.UP_TURN_HEIGHT
	# The worst roll for the third in a stack (the spawner's own function): still on the flight at the top of its bob.
	for i in 3:
		var worst: float = BF.stair_up_rest(i, 45.0) - BF.STAIR_BOB_AMP + BF.STAIR_FEET_BELOW_ORIGIN
		check(worst >= top_step_feet - 0.01, "enemy %d up the flight, highest roll + bob: feet %.0f on the flight (top step %.0f)" % [i, worst, top_step_feet])
	for z in ups:
		var highest_origin: float = z._stair_rest_y - z._stair_bob_amp
		var feet: float = highest_origin + BF.STAIR_FEET_BELOW_ORIGIN
		check(feet >= top_step_feet - 0.01, "%s: at its highest its feet (%.0f) stay on the flight (top step %.0f)" % [z.spawn_key, feet, top_step_feet])
		var spr: AnimatedSprite2D = z.get_node("AnimatedSprite2D")
		var top_now: float = drawn_top(spr, ["Idle", "Walk", "Attack"])
		var top_highest: float = top_now + (highest_origin - z.global_position.y)
		var mat = spr.material
		var clip: float = float(mat.get_shader_parameter("shaft_top")) if mat is ShaderMaterial else -1.0e9
		var shown_top: float = maxf(top_highest, clip)
		check(is_equal_approx(clip, BF.STAIR_OPENING_TOP), "%s: clipped at the opening's top (%.0f)" % [z.spawn_key, clip])
		check(shown_top >= BF.STAIR_OPENING_TOP - 0.01, "%s: nothing of it shows above the opening (drawn top %.0f, shown from %.0f)" % [z.spawn_key, top_highest, shown_top])
	# Stepping off, the clip comes off with the stair material.
	if not ups.is_empty():
		var z0 = ups[0]
		z0._exit_stairwell_mode()
		var m0 = z0.get_node("AnimatedSprite2D").material
		check(m0 == null, "off the stairs, the clip is gone (%s)" % str(m0))
	bf.free()
	await get_tree().process_frame
