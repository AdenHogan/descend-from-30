extends Node

# LYING BODIES HAVE DEPTH IN A FLAT (owner round 37: "there's a clipping situation with this corpse position. If it's a little higher then we
# can have player walk behind the corpse, as it would cover the player's lower legs"). A flat's second walking line is the BACK plane (a
# player stepped up at set-back furniture stands 14 px further back than the lane); a body lying on the lane is nearer than that player, so
# it now sits `CorpseDepth.RISE` px back from the lane and draws IN FRONT of them (z 2) while they are behind it, and under them (z 0, as ever)
# on the lane. Three kinds of body: a live enemy that died here, the static sprite a re-entered flat lays for a recorded kill, and the BAKED
# dead of a breach / corpse story (their own layer since tools/art/nest.py split them out of the overlay). Corridors keep their bodies on the
# player's row (enemy_variety_test). Run: godot --headless res://tests/corpse_depth_test.tscn

const RoomScript := preload("res://scripts/room.gd")
const EnemyFeet := preload("res://scripts/enemy_feet.gd")

var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== corpse depth test ===")
	_test_rule_and_constants()
	await _test_live_corpse()
	await _test_static_corpses()
	await _test_baked_dead()
	await _test_near_masks()
	await _test_corridor_unchanged()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _room(apt: String) -> Node:
	WorldState.new_game()
	WorldState.master_seed = 4242
	WorldState.is_first_run = false
	WorldState.current_run = 1
	WorldState.current_apartment_id = apt
	WorldState.current_floor = int(apt.substr(0, 2))
	WorldState.spawn_source = ""
	WorldState.god_mode = true
	WorldState.is_scavenge_mode = true
	var room = load("res://scenes/room.tscn").instantiate()
	add_child(room)
	await _built(room)
	return room


## Wait until the room has finished building (its depth node is the last of the live pieces this suite needs), then clear its enemies.
func _built(room: Node) -> void:
	for i in range(120):
		await get_tree().physics_frame
		if room.get_node_or_null("CorpseDepth") != null:
			break
	for z in get_tree().get_nodes_in_group("zombie"):
		if room.is_ancestor_of(z):
			z.free()


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame


## Put the player on the lane (feet 353) or up on the back plane (feet 339), as stepping up at furniture does.
func _plane(p: Node, up: bool) -> void:
	var lane_y: float = float(p.get_meta("lane_y", p.global_position.y))
	p.set_meta("lane_y", lane_y)
	p.global_position.y = lane_y - (14.0 if up else 0.0)


# --- the rule --------------------------------------------------------------------------------------------------------

func _test_rule_and_constants() -> void:
	print("[the rule, and the art's constant]")
	var CD = load("res://scripts/corpse_depth.gd")
	check(CD.in_front_of(353.0, 339.0), "a body on the lane is in front of a player on the back plane")
	check(not CD.in_front_of(353.0, 353.0), "…not in front of a player on the lane (they still draw over it)")
	check(not CD.in_front_of(339.0, 353.0), "…and a body behind the player never is")
	check(not CD.in_front_of(352.0, 353.0) and CD.in_front_of(359.0, 353.0), "the gap must be real (%.0f px), not a pixel's difference" % CD.FRONT_GAP)
	check(CD.FRONT_Z > 1, "in front means over the actor layer (z 1)")
	# the art bakes the same rise into the dead layers: one number, two files
	var nest_py: String = FileAccess.get_file_as_string("res://tools/art/nest.py")
	var rise_line := ""
	for line in nest_py.split("\n"):
		if line.begins_with("BODY_RISE"):
			rise_line = line
	var art_rise: int = int(rise_line.split("=")[1].strip_edges().split(" ")[0]) if rise_line != "" else -1
	check(art_rise == int(CD.RISE), "tools/art/nest.py BODY_RISE (%d) = corpse_depth.gd RISE (%d)" % [art_rise, int(CD.RISE)])


# OWNER ROUND 45: "the corpse drops below the Y plane then clumsily moves back up". The 6 px rise used to wait for the Death animation to
# END and then slide (0.3 s) — a visible hop. It is now spread over the fall, whole pixels, and nothing moves once the body has landed.
func _test_no_hop(room: Node) -> void:
	var z = load("res://scenes/enemy_zombie_standard.tscn").instantiate()
	z.spawn_key = ""
	room.add_child(z)
	z.global_position = Vector2(700.0, 321.0)
	await _frames(40)
	var spr: AnimatedSprite2D = z.get_node("AnimatedSprite2D")
	z.receive_damage(999, "melee")
	var last_y: float = spr.position.y
	var biggest := 0.0
	var after_landing := 0.0
	var landed := false
	var settle_frames := 2
	for i in range(160):
		await get_tree().physics_frame
		var step: float = absf(spr.position.y - last_y)
		last_y = spr.position.y
		biggest = maxf(biggest, step)
		if landed and settle_frames <= 0:
			after_landing = maxf(after_landing, step)
		if landed:
			settle_frames -= 1
		if spr.animation == "Death" and spr.frame == spr.sprite_frames.get_frame_count("Death") - 1:
			landed = true                       # (the depth node ticks on the idle frame: give its last pixel two frames)
	check(landed and biggest <= 1.01, "the body never moves more than a pixel in a frame (biggest step %.2f px)" % biggest)
	check(after_landing == 0.0, "…and nothing moves once it has landed (%.2f px)" % after_landing)
	z.free()


# --- a live enemy that died in the flat ---------------------------------------------------------------------------------

func _test_live_corpse() -> void:
	print("[a live corpse: sits back, and goes in front of a player behind it]")
	var CD = load("res://scripts/corpse_depth.gd")
	var room = await _room("1001")
	var p = room.get_node("Player")
	check(room.get_node_or_null("CorpseDepth") != null, "a flat has the depth node")
	var z = load("res://scenes/enemy_zombie_standard.tscn").instantiate()
	z.spawn_key = ""
	room.add_child(z)
	z.global_position = Vector2(560.0, 321.0)
	await _frames(40)
	var spr: AnimatedSprite2D = z.get_node("AnimatedSprite2D")
	var alive_rise: float = spr.position.y
	z.receive_damage(999, "melee")
	await _frames(150)
	var lane_feet: float = p.feet_position().y
	check(z.is_dead and spr.animation == "Death" and spr.frame == spr.sprite_frames.get_frame_count("Death") - 1, "it has died and finished falling")
	check(absf(float(z.get_meta("cd_rise", 0.0)) - CD.RISE) < 0.01 and absf(spr.position.y - (alive_rise - CD.RISE)) < 0.01,
		"the body has eased back %.0f px from the lane (sprite y %.1f -> %.1f)" % [CD.RISE, alive_rise, spr.position.y])
	check(z.z_index == 0, "the player on the lane (feet %.0f): the body stays under them (z %d), as it always did" % [lane_feet, z.z_index])
	await _test_no_hop(room)
	_plane(p, true)
	await _frames(4)
	check(absf(p.feet_position().y - 339.0) < 0.6, "the player up on the back plane (feet %.0f)" % p.feet_position().y)
	check(z.z_index == CD.FRONT_Z, "…the body now draws OVER them (z %d)" % z.z_index)
	# it reaches up over the player's lower legs: the body's top row is above the player's drawn feet
	var tex: Texture2D = spr.sprite_frames.get_frame_texture("Death", spr.sprite_frames.get_frame_count("Death") - 1)
	var img: Image = tex.get_image()
	if img.is_compressed():
		img.decompress()
	var top_row := -1
	for yy in range(img.get_height()):
		for xx in range(img.get_width()):
			if img.get_pixel(xx, yy).a > 0.5:
				top_row = yy
				break
		if top_row >= 0:
			break
	var body_top: float = z.global_position.y + spr.position.y + (spr.offset.y - float(img.get_height()) * 0.5 + float(top_row)) * spr.scale.y
	var player_feet_drawn: float = p.feet_position().y - EnemyFeet.PLAYER_DRAWN_ABOVE_COLLISION
	check(body_top <= player_feet_drawn - 4.0, "…and reaches %.0f px up over their feet (body top %.0f, their drawn feet %.0f)" % [player_feet_drawn - body_top, body_top, player_feet_drawn])
	_plane(p, false)
	await _frames(4)
	check(z.z_index == 0, "back on the lane: under them again")
	room.free()
	await get_tree().process_frame


# --- the static bodies a re-entered flat lays ----------------------------------------------------------------------------

func _test_static_corpses() -> void:
	print("[static corpses: the same row as the body that died, sat back, sorted]")
	var CD = load("res://scripts/corpse_depth.gd")
	WorldState.new_game()
	WorldState.master_seed = 4242
	var apt := "1001"
	var scene_path := "res://scenes/room.tscn"
	WorldState.killed_zombies["t:std"] = {"x": 500.0, "y": 304.0, "floor": 10, "scene": scene_path, "apartment_id": apt, "type": "standard"}
	WorldState.killed_zombies["t:big"] = {"x": 760.0, "y": 308.0, "floor": 10, "scene": scene_path, "apartment_id": apt, "type": "big"}
	var room = await _room_keep_kills(apt)
	var p = room.get_node("Player")
	var bodies := []
	for c in get_tree().get_nodes_in_group("room_corpse"):
		if room.is_ancestor_of(c):
			bodies.append(c)
	check(bodies.size() == 2, "both recorded kills lie in the flat (%d)" % bodies.size())
	var want: float = RoomScript.ROOM_FEET_Y - EnemyFeet.PLAYER_DRAWN_ABOVE_COLLISION - CD.RISE
	for c in bodies:
		var bottom: float = EnemyFeet.drawn_bottom(c)      # (the corpse IS the sprite: its position is already in it)
		var kind: String = "big" if c.sprite_frames.has_animation("Death") and not c.sprite_frames.has_animation("Dead_Dead") else "standard"
		check(absf(bottom - want) < 0.6, "%s: drawn bottom %.1f = the lane row %.0f less the rise (%.1f)" % [kind, bottom, RoomScript.ROOM_FEET_Y - 1.0, want])
	for c in bodies:
		check(c.z_index == 0, "player on the lane: under them")
	_plane(p, true)
	await _frames(4)
	for c in bodies:
		check(c.z_index == CD.FRONT_Z, "player on the back plane: the body is over them")
	room.free()
	await get_tree().process_frame
	WorldState.killed_zombies.erase("t:std")
	WorldState.killed_zombies.erase("t:big")


func _room_keep_kills(apt: String) -> Node:
	var kills: Dictionary = WorldState.killed_zombies.duplicate(true)
	var room = await _room(apt)           # (_room starts a new game — put the recorded kills back, then rebuild)
	room.free()
	await get_tree().process_frame
	WorldState.killed_zombies = kills
	var r2 = load("res://scenes/room.tscn").instantiate()
	add_child(r2)
	await _built(r2)
	return r2


# --- floor pieces nearer than a body (owner round 45) -----------------------------------------------------------------------

# "enemy corpses are resting on top of floor art assets… needs adjustment so there is no overlap": a toppled chair (dining B / C / E) and the
# torn gift box (dining E) reach below a body's bottom row, so the body goes BEHIND them — the art tool writes a mask, corpse_depth.gd clips
# the body's sprite where it is set. Only the mechanism is testable headless (the clip itself is a shader — checked by eye under xvfb).
func _test_near_masks() -> void:
	print("[near pieces: a mask per module that has one, and a body clipped by it]")
	var CD = load("res://scripts/corpse_depth.gd")
	var rooms := "res://assets/rooms/"
	check(CD.mask_paths(rooms + "dining_room_e.png", true) == [rooms + "dining_room_e_near.png", rooms + "dining_room_e_near_strip.png"],
		"dining E: its chair mask + its torn-box (strip) mask")
	check(CD.mask_paths(rooms + "dining_room_e.png", false) == [rooms + "dining_room_e_near.png", ""],
		"…and the strip's mask only while the strip is shown (a balcony slot hides the box)")
	check(CD.mask_paths(rooms + "dining_room_c_r3.png", false) == [rooms + "dining_room_c_near.png", ""],
		"a run look with no mask of its own uses the first look's")
	check(CD.mask_paths(rooms + "dining_room_e_burnt.png", true) == ["", ""], "a burnt flat has none (its art is its own husk)")
	check(CD.mask_paths(rooms + "living_room.png", true) == ["", ""], "a module with nothing nearer than a body has none")
	# every mask is a real 1-bit cut of its art: it has pixels, only where the art has pixels, and reaches below a body's bottom row
	for n in ["dining_room_b", "dining_room_c", "dining_room_e"]:
		var m: Image = load(rooms + n + "_near.png").get_image()
		var a: Image = load(rooms + n + ".png").get_image()
		var lowest := -1
		var pixels := 0
		for y in range(m.get_height()):
			for x in range(m.get_width()):
				if m.get_pixel(x, y).a > 0.5:
					pixels += 1
					lowest = maxi(lowest, y)
		check(pixels > 100 and lowest > 122 and m.get_size() == a.get_size(),
			"%s: a mask of %d px reaching row %d (a body's bottom is row 122)" % [n, pixels, lowest])
	# OVER layers (owner round 45b: "that chair could potentially be in front of enemies and player as it's lower on the plane"): a piece
	# whose silhouette reaches BELOW the lane row (129) is nearer than every actor standing on the lane
	check(RoomScript.over_art_path(rooms + "dining_room_e.png") == rooms + "dining_room_e_over.png", "dining E has an over layer (its chair reaches row 131)")
	check(RoomScript.over_art_path(rooms + "dining_room_e_r2.png") == rooms + "dining_room_e_over_r2.png"
			and RoomScript.over_art_path(rooms + "dining_room_e_r3.png") == rooms + "dining_room_e_over_r3.png", "…and one cut from each run look")
	check(RoomScript.over_art_path(rooms + "dining_room_e_burnt.png") == "", "a burnt flat has none")
	check(RoomScript.over_art_path(rooms + "dining_room_c.png") == "", "dining C's chair (row 128) stays behind the lane: no over layer")
	check(RoomScript.over_art_path(rooms + "living_room.png") == "", "a module with nothing below the lane has none")
	var over_files := 0
	for fn in DirAccess.get_files_at("res://assets/rooms"):
		if not (fn.contains("_over") and fn.ends_with(".png")):
			continue
		over_files += 1
		var oi: Image = load(rooms + fn).get_image()
		var art_name := fn.replace("_over", "")
		var ai: Image = load(rooms + art_name).get_image()
		var lowest := -1
		var n := 0
		var same := true
		for y in range(oi.get_height()):
			for x in range(oi.get_width()):
				var px := oi.get_pixel(x, y)
				if px.a > 0.5:
					n += 1
					lowest = maxi(lowest, y)
					if not px.is_equal_approx(ai.get_pixel(x, y)):
						same = false
		check(n > 100 and lowest > 129 and same and oi.get_size() == ai.get_size(),
			"%s: %d px of its own art, reaching row %d (below the 129 lane)" % [fn, n, lowest])
	check(over_files == 3, "exactly three over layers exist today: dining E's, one per look (%d)" % over_files)
	# a real flat: find one showing dining E, kill a body in it, and see the body clipped (and one elsewhere not)
	var apt := ""
	var slot := -1
	WorldState.new_game()
	WorldState.master_seed = 4242
	for f in range(2, 25):
		for i in range(1, 6):
			var cand := str(f) + "0" + str(i)
			var layout: Array = WorldState.get_apartment_layout(cand)
			for sl in range(layout.size()):
				if apt == "" and layout[sl] == "dining_room" and RoomScript.module_scene_for(cand, sl, "dining_room").ends_with("dining_room_e.tscn"):
					apt = cand
					slot = sl
	check(apt != "", "found a flat showing dining E (%s, slot %d)" % [apt, slot])
	if apt == "":
		return
	var room = await _room(apt)
	var module: Node = null
	for m in room.get_children():
		if m.is_in_group("room_module") and String(m.scene_file_path).ends_with("dining_room_e.tscn"):
			module = m
	check(module != null, "that module is in the flat")
	if module == null:
		room.free()
		return
	var other: Node = null
	for m in room.get_children():
		if m.is_in_group("room_module") and m != module and CD.mask_paths((m.get_node("Art") as Sprite2D).texture.resource_path, true) == ["", ""]:
			other = m
	var inside = load("res://scenes/enemy_zombie_standard.tscn").instantiate()
	inside.spawn_key = ""
	room.add_child(inside)
	inside.global_position = Vector2((module as Node2D).global_position.x + 187.0, 304.0)
	var outside = null
	if other != null:
		outside = load("res://scenes/enemy_zombie_standard.tscn").instantiate()
		outside.spawn_key = ""
		room.add_child(outside)
		outside.global_position = Vector2((other as Node2D).global_position.x + 160.0, 304.0)
	await _frames(10)
	inside.receive_damage(999, "melee")
	if outside != null:
		outside.receive_damage(999, "melee")
	await _frames(120)
	var spr: AnimatedSprite2D = inside.get_node("AnimatedSprite2D")
	var mat := spr.material as ShaderMaterial
	check(mat != null and mat.shader != null and mat.shader.code.contains("near_a"), "the body in dining E is clipped by the near shader")
	if mat != null:
		var art := module.get_node("Art") as Sprite2D
		var want_origin: Vector2 = (module as Node2D).global_position + art.position - (art.texture.get_size() * 0.5 if art.centered else Vector2.ZERO)
		check((mat.get_shader_parameter("origin") as Vector2).is_equal_approx(want_origin),
			"…in the module's own coordinates (origin %s)" % str(mat.get_shader_parameter("origin")))
		var ta: Texture2D = mat.get_shader_parameter("near_a")
		check(ta != null and ta.get_width() == 320 and ta.get_height() == 144, "…with the room's chair mask")
	if outside != null:
		check((outside.get_node("AnimatedSprite2D") as AnimatedSprite2D).material == null,
			"a body in a module with nothing nearer than it is left as it was")
	var over := module.get_node_or_null("OverArt") as Sprite2D
	check(over != null and over.z_index > 1 and over.z_index > load("res://scripts/corpse_depth.gd").FRONT_Z,
		"dining E's chair is laid over the actors AND over a body in front of a back-plane player (z %s)" % (str(over.z_index) if over != null else "none"))
	if over != null:
		var art2 := module.get_node("Art") as Sprite2D
		check(over.position == art2.position and over.scale == art2.scale and over.texture.get_size() == art2.texture.get_size(),
			"…registered exactly over the art")
	for m in room.get_children():
		if m.is_in_group("room_module") and m != module and m.get_node_or_null("OverArt") != null:
			check(false, "a module with no over art got an OverArt layer: " + String(m.scene_file_path))
	room.free()
	await get_tree().process_frame


# --- the baked dead of a corpse / breach story -----------------------------------------------------------------------------

func _test_baked_dead() -> void:
	print("[the baked dead: their own layer, drawn back, sorted]")
	var CD = load("res://scripts/corpse_depth.gd")
	var meta := RoomScript.nest_meta()
	# every story overlay that has bodies has its dead layer, with sane rects
	var with_dead := 0
	var missing := []
	var bad_rects := []
	for key in meta:
		var dead: Array = meta[key].get("dead", [])
		if dead.is_empty():
			continue
		with_dead += 1
		if not ResourceLoader.exists("res://assets/rooms/%s_dead.png" % key):
			missing.append(key)
		for r in dead:
			if not (r.size() == 5 and r[0] >= 0 and r[1] >= 0 and r[2] < 320 and r[3] < 144 and r[0] <= r[2] and r[1] <= r[3] and r[1] <= r[4] and r[4] <= r[3]):
				bad_rects.append(key)
	check(with_dead > 150 and missing.is_empty(), "%d story overlays have a dead layer, none missing a file (%s)" % [with_dead, str(missing.slice(0, 3))])
	check(bad_rects.is_empty(), "every body rect is inside its module and holds its feet row (%s)" % str(bad_rects.slice(0, 3)))
	var stale := []
	for key in meta:
		if meta[key].get("dead", []).is_empty() and ResourceLoader.exists("res://assets/rooms/%s_dead.png" % key):
			stale.append(key)
	check(stale.is_empty(), "no dead layer is left over for a story without bodies (%s)" % str(stale.slice(0, 3)))
	# a flat with one of the dead: its sprites, sorted by the player's plane
	var room = null
	for f in range(10, 29):
		for col in range(1, 6):
			var apt := str(f) + "0" + str(col)
			WorldState.new_game()
			WorldState.master_seed = 4242
			if WorldState.apartment_corpse(apt).is_empty():
				continue
			room = await _room(apt)
			break
		if room != null:
			break
	check(room != null, "a flat with one of the dead turns up")
	if room == null:
		return
	var dead_sprites := []
	for d in get_tree().get_nodes_in_group("nest_dead"):
		if room.is_ancestor_of(d):
			dead_sprites.append(d)
	check(not dead_sprites.is_empty(), "its body is laid as a sprite of its own (%d)" % dead_sprites.size())
	var p = room.get_node("Player")
	await _frames(4)
	var any_over_lane := false
	for d in dead_sprites:
		var feet: float = d.global_position.y + float(d.get_meta("feet_off")) * d.global_scale.y
		check(d.z_index == (CD.FRONT_Z if CD.in_front_of(feet, p.feet_position().y) else 0), "player on the lane: z %d for a body whose feet are at %.0f" % [d.z_index, feet])
		any_over_lane = any_over_lane or d.z_index == CD.FRONT_Z
	_plane(p, true)
	await _frames(4)
	for d in dead_sprites:
		var feet2: float = d.global_position.y + float(d.get_meta("feet_off")) * d.global_scale.y
		check(CD.in_front_of(feet2, p.feet_position().y) == (d.z_index == CD.FRONT_Z), "player on the back plane: z %d (feet %.0f vs theirs %.0f)" % [d.z_index, feet2, p.feet_position().y])
		check(CD.in_front_of(feet2, p.feet_position().y) or feet2 < 339.0 + CD.FRONT_GAP, "(a body further forward than the lane would be over them: %.0f)" % feet2)
	check(any_over_lane or dead_sprites.size() > 0, "(at least one body checked)")
	# the search node sits on the raised body, not under it
	var search_ok := false
	for d in get_tree().get_nodes_in_group("nest_dead"):
		if not room.is_ancestor_of(d):
			continue
		var module: Node = d.get_parent()
		for ch in module.get_children():
			if str(ch.name).begins_with("dead_") and ch.has_meta("dead_body"):
				var a: Node2D = ch
				var top: float = d.position.y
				var h: float = (d.texture as AtlasTexture).region.size.y
				if a.position.y >= top - 2.0 and a.position.y <= top + h + 2.0:
					search_ok = true
	check(search_ok, "its search spot is on the (raised) body")
	# a charred / backdrop room has no sorter: its sprites just stay under the player
	room.free()
	await get_tree().process_frame


# --- corridors don't change --------------------------------------------------------------------------------------------------

func _test_corridor_unchanged() -> void:
	print("[a corridor keeps its bodies on the player's row]")
	WorldState.new_game()
	WorldState.tutorial_completed = true
	WorldState.is_first_run = false
	WorldState.current_floor = 15
	WorldState.spawn_source = "stairs"
	WorldState.stair_spawn_side = WorldState.canonical_stair_arrival_side(15)
	WorldState.stair_direction = "down"
	var bf = load("res://scenes/building_floors.tscn").instantiate()
	bf.setup_floor = 15
	add_child(bf)
	await _frames(6)
	check(bf.get_node_or_null("CorpseDepth") == null, "no depth node in a corridor")
	var z = load("res://scenes/enemy_zombie_standard.tscn").instantiate()
	z.spawn_key = ""
	bf.add_child(z)
	z.global_position = Vector2(600.0, 370.0)
	await _frames(40)
	var spr: AnimatedSprite2D = z.get_node("AnimatedSprite2D")
	var before: float = spr.position.y
	z.receive_damage(999, "melee")
	await _frames(150)
	check(z.is_dead and absf(spr.position.y - before) < 0.01 and z.z_index == 0, "a dead zombie stays where it fell (sprite y %.1f -> %.1f, z %d)" % [before, spr.position.y, z.z_index])
	bf.free()
	await get_tree().process_frame
