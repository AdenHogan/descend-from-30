extends Node

# THE BANISTER (owner round 31e): "If it's a down stairwell rather than having a wall we should have a bannister that players can
# jump down just like with a balcony. If they jump down they can get hurt but their landing would be in the correct position for
# arrival on the next floor down." Checks: every DOWN stairwell carries a banister zone exactly over the floor below's arrival
# spot; the jump needs two presses; it's refused in the same states as the stairs (and by a barricade); a real jump pans down a
# floor, lands on the arrival spot, hurts 1-2 (none in god mode), takes no follower and hands control back clean.
# Run: godot --headless res://tests/banister_test.tscn

var failures: int = 0
const SW := preload("res://scripts/stairwell.gd")


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== banister test ===")
	WorldState.new_game()
	WorldState.is_first_run = false
	WorldState.opener_seen = true
	_test_banister_over_arrival()
	_test_fall_geometry()
	_test_one_hint_at_a_time()
	await _test_live_vault()
	Engine.time_scale = 1.0
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _live_down(root: Node, fnum: int = -1) -> Node:
	# The floor's real DOWN stairwell: by its side (a passive build has every trigger switched off, so not by process mode).
	for n in root.get_children():
		if n is Area2D and n.get_script() == SW and n.direction == "down":
			if fnum >= 0 and n.stair_side != WorldState.stair_down_side(fnum):
				continue
			if fnum < 0 and n.process_mode == Node.PROCESS_MODE_DISABLED:
				continue
			return n
	return null


func _shown(owner: Node) -> String:
	var p: Panel = HUD.world_prompt_panel(owner)
	if p == null or not p.visible:
		return ""
	return (p.find_children("*", "Label", true, false)[0] as Label).text


## Owner round 33: "the text for listen and jump over overlap… we also don't need both texts to be there. Players can have it
## once in tutorial, one followed by the other. Doesn't always need both when descending."
func _test_one_hint_at_a_time() -> void:
	print("[stair hints: never both, listen then jump, each taught once]")
	var saved: Dictionary = WorldState.hints_taught.duplicate()
	WorldState.hints_taught = {}
	var bf = load("res://scenes/building_floors.tscn").instantiate()
	bf.setup_floor = 15
	bf.passive = true
	WorldState.current_floor = 15
	add_child(bf)
	var t = _live_down(bf, 15)
	check(t != null and t.banister != null, "floor 15 has a down stairwell with a banister")
	if t == null or t.banister == null:
		bf.free()
		WorldState.hints_taught = saved
		return
	# First pass at the half-wall (you cross it before the steps): listen not yet taught → no jump hint.
	t.player_on_banister = true
	t._update_hint(0.1)
	check(_shown(t.banister) == "" and _shown(t) == "", "first visit to the half-wall: no hint before listening is taught")
	t.player_on_banister = false
	t._on_banister_exited(_fake_player())
	# The steps: the listen hint, alone.
	t.player_nearby = true
	t._update_hint(0.1)
	check(_shown(t).contains("Listen below") and _shown(t.banister) == "", "at the steps: the listen hint, alone")
	t._update_hint(1.0)
	check(not WorldState.hint_taught(t.HINT_LISTEN), "not taught after 1.1 s")
	t._update_hint(2.0)
	check(WorldState.hint_taught(t.HINT_LISTEN), "taught after 3 s up")
	check(_shown(t).contains("Listen below"), "…but it stays up until you leave the steps")
	t._on_body_exited(_fake_player())
	check(_shown(t) == "", "leaving the steps hides it")
	# Now the half-wall: the jump hint, alone.
	t.player_on_banister = true
	t._update_hint(0.1)
	check(_shown(t.banister).contains("Jump over the wall") and _shown(t) == "", "then at the half-wall: the jump hint, alone")
	t._update_hint(3.0)
	check(WorldState.hint_taught(t.HINT_JUMP), "the jump is taught after 3 s up")
	t._on_banister_exited(_fake_player())
	check(_shown(t.banister) == "", "leaving the half-wall hides it")
	# Both taught: a later descent shows neither, in either zone.
	t.player_nearby = true
	t._update_hint(0.1)
	check(_shown(t) == "" and _shown(t.banister) == "", "later visit to the steps: no hint")
	t._on_body_exited(_fake_player())
	t.player_on_banister = true
	t._update_hint(0.1)
	check(_shown(t) == "" and _shown(t.banister) == "", "later visit to the half-wall: no hint")
	t._on_banister_exited(_fake_player())
	# Using the key teaches it too, and the profile keeps it.
	WorldState.hints_taught = {}
	WorldState.note_hint_taught(t.HINT_LISTEN)
	WorldState.load_profile()
	check(WorldState.hint_taught(t.HINT_LISTEN) and not WorldState.hint_taught(t.HINT_JUMP), "taught hints survive a profile reload")
	bf.free()
	_fake.free()
	WorldState.hints_taught = saved
	WorldState.save_profile()


var _fake: Node2D = null


func _fake_player() -> Node2D:
	# The stairwell matches its body by name (one stand-in, kept for the whole check — freed ones linger a frame and rename the next).
	if _fake == null:
		_fake = Node2D.new()
		add_child(_fake)
		_fake.name = "Player"
	return _fake


func _test_banister_over_arrival() -> void:
	print("[every DOWN stairwell has a banister, straight over the floor below's arrival spot]")
	for fnum in [30, 29, 16, 15, 2, 1]:
		var scene_path: String = StairPan.scene_for_floor(fnum)
		var s = load(scene_path).instantiate()
		if "setup_floor" in s:
			s.setup_floor = fnum
			s.passive = true
		WorldState.current_floor = fnum
		add_child(s)
		var t = _live_down(s, fnum)
		check(t != null and t.banister != null, "floor %d: the down stairwell has a banister zone" % fnum)
		if t != null and t.banister != null:
			var want: float = StairPan.dest_spawn(fnum - 1, true).x
			check(is_equal_approx(t.banister_x(), want),
				"floor %d: banister at x %.0f = floor %d's arrival x %.0f" % [fnum, t.banister_x(), fnum - 1, want])
			var shape := t.banister.get_child(0) as CollisionShape2D
			check(shape != null and is_equal_approx(t.banister.global_position.x + shape.position.x, want),
				"floor %d: its trigger is centred there too" % fnum)
			check(t.prefers_banister(want) and not t.prefers_banister(t.global_position.x),
				"floor %d: at the banister W jumps, at the steps W takes the stairs" % fnum)
		s.free()
	# The UP stairwells have none.
	var bf = load("res://scenes/building_floors.tscn").instantiate()
	bf.setup_floor = 15
	bf.passive = true
	add_child(bf)
	var ups := 0
	for n in bf.get_children():
		if n is Area2D and n.get_script() == SW and n.direction == "up" and n.banister != null:
			ups += 1
	check(ups == 0, "no UP stairwell has a banister (%d)" % ups)
	bf.free()


func _test_fall_geometry() -> void:
	print("[the fall: the cut flips only while the player is wholly between the two floors]")
	var off: float = StairPan.FLOOR_BAND_H
	var gap: Vector2 = StairPan.vault_gap(off)
	check(gap.x == StairPan.VAULT_RAIL_TOP and gap.y == StairPan.VAULT_OPENING_TOP + off and gap.x < gap.y,
		"hidden from the handrail (%.0f) to the next floor's opening top (%.0f)" % [gap.x, gap.y])
	# The floor below's corridor ceiling starts INSIDE the gap — what's hidden is the slab between the floors, nothing on either.
	check(gap.x < StairPan.FLOOR_BAND_TOP + off and StairPan.FLOOR_BAND_TOP + off < gap.y,
		"the floor-to-floor seam (%.0f) lies inside the hidden band" % (StairPan.FLOOR_BAND_TOP + off))
	# The shader's band is inert by default (the stairs' own slice is untouched by it).
	check(StairPan.SHRED_SHADER.contains("gap_top = 999999.0") and StairPan.SHRED_SHADER.contains("gap_bottom = -999999.0"),
		"the gap band defaults to off")
	# The rail the player climbs is the rail the art draws: the sprite's top + EXT rows + the art's RAIL_Y (66).
	var bf = load("res://scenes/building_floors.tscn").instantiate()
	var spr: Sprite2D = bf.get_node("HallwayStaircaseLeft")
	var top: float = spr.position.y - spr.texture.get_height() * 0.5
	check(is_equal_approx(top, StairPan.VAULT_OPENING_TOP), "the stair art's top is VAULT_OPENING_TOP (%.1f)" % top)
	check(is_equal_approx(top + 29.0 + 66.0, StairPan.VAULT_RAIL_TOP), "VAULT_RAIL_TOP is the drawn cap (%.1f)" % (top + 95.0))
	# ...and measured from the texture: down the column through the half-wall, the first row that isn't the dark well is the cap's
	# top (owner round 31g: a solid half-wall with a timber capping rail, not spindles).
	var img: Image = spr.texture.get_image()
	var cap_row := -1
	for yy in range(62, img.get_height()):   # below the window (its sill ends ~row 60)
		var c: Color = img.get_pixel(60, yy)
		if c.r > 0.45 and c.r > c.b + 0.12:
			cap_row = yy
			break
	check(cap_row >= 0 and is_equal_approx(top + float(cap_row), StairPan.VAULT_RAIL_TOP),
		"the drawn cap's top (world %.0f) is where the jump climbs to (%.0f)" % [top + float(cap_row), StairPan.VAULT_RAIL_TOP])
	var solid := true
	for yy in range(cap_row + 5, cap_row + 24, 3):
		for xx in range(43, 77):                           # the whole width — spindles would leave gaps onto the dark well
			if img.get_pixel(xx, yy).get_luminance() < 0.12:
				solid = false
	check(solid, "below the cap is a solid wall face, not gaps onto the dark well")
	bf.free()


func _test_live_vault() -> void:
	print("[a real jump from floor 15: two presses, a pan down, landed on the arrival spot, hurt]")
	for sd in range(5150, 6150):
		WorldState.master_seed = sd
		if not WorldState.is_stair_blocked(15) and WorldState.fire_intensity(15) <= 0 and WorldState.fire_intensity(14) <= 0 \
				and WorldState.stair_enemy_count(15) == 0:
			break
	WorldState.god_mode = false
	WorldState.current_floor = 15
	WorldState.spawn_source = "stair"
	WorldState.stair_spawn_side = WorldState.canonical_stair_arrival_side(15)
	var stub := Node.new()
	get_tree().root.add_child.call_deferred(stub)
	await get_tree().process_frame
	get_tree().current_scene = stub
	get_tree().change_scene_to_file("res://scenes/building_floors.tscn")
	for i in 6:
		await get_tree().process_frame
	var t = _live_down(get_tree().current_scene)
	check(t != null, "floor 15 has a live down stairwell")
	if t == null:
		return
	var player = get_tree().get_first_node_in_group("player")
	player.global_position = Vector2(t.banister_x(), 386.0)
	# Refusals — no side effects, no jump.
	player.is_dead = true
	check(t.vault_refusal(player) == "busy", "refused while dead")
	player.is_dead = false
	player.is_cutscene = true
	check(t.vault_refusal(player) == "busy", "refused mid-cutscene")
	player.is_cutscene = false
	WorldState.dev_hazard_mode = WorldState.DEV_HAZARD_BARRICADE
	check(t.vault_refusal(player) == "barricade", "refused while the stairwell is barricaded (the crowbar keeps its job)")
	check(not t.vault_banister() and not StairPan.panning, "a barricaded banister doesn't jump")
	WorldState.dev_hazard_mode = WorldState.DEV_HAZARD_NONE
	check(t.vault_refusal(player) == "", "free to jump otherwise")
	# Two presses.
	t._vault_confirm_time = -100.0
	check(not t.vault_banister(), "the first press only warns")
	check(not StairPan.panning and WorldState.current_floor == 15, "…and nothing moves")
	var hp0: int = player.health_state
	var scale0: Vector2 = player.get_node("AnimatedSprite2D").scale
	Engine.time_scale = 4.0
	check(t.vault_banister(), "the second press jumps")
	check(StairPan.panning, "the jump is a pan (no fade)")
	var guard := 0
	while (StairPan.panning or Transition.busy) and guard < 3000:
		await get_tree().process_frame
		guard += 1
	var hurt: int = player.health_state - hp0 if is_instance_valid(player) else -1
	await get_tree().create_timer(StairPan.VAULT_LAND_TIME + 0.1).timeout
	Engine.time_scale = 1.0
	var scene = get_tree().current_scene
	check(WorldState.current_floor == 14 and scene != null and scene.get("setup_floor") != null, "landed on floor 14")
	var players := get_tree().get_nodes_in_group("player")
	check(players.size() == 1 and players[0] == player, "the same player, only one")
	var arrive: Vector2 = StairPan.dest_spawn(14, true)
	check(player.global_position.distance_to(arrive) < 1.0,
		"on the arrival spot %s (at %s)" % [arrive, player.global_position])
	check(hurt >= SW.VAULT_INJURY_MIN and hurt <= SW.VAULT_INJURY_MAX, "hurt by the fall (%d)" % hurt)
	check(not player.is_cutscene, "control handed back")
	var spr: AnimatedSprite2D = player.get_node("AnimatedSprite2D")
	check(spr.material == null or not (spr.material is ShaderMaterial and spr.material.shader.code.contains("cut_y")),
		"the fall's cut is off the sprite")
	check(spr.scale.is_equal_approx(scale0), "the sprite is back to full size (%s)" % spr.scale)
	check(WorldState.follower_node == null, "nothing followed the jump")
	WorldState.god_mode = true
