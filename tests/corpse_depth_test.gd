extends Node

# THE DEAD LIE IN FRONT OF WHOEVER STANDS LEVEL WITH THEM (owner round 48h: "I am standing on top of bodies in an over clipping way, both for NPCs and
# enemies… have those elements in front of players feet… so it looks like player is walking behind them"). Every body used to draw UNDER the living (z 0), so a
# player level with a body had their legs painted over it. Now each body is sorted by its FEET ROW (corpse_depth.gd): level with the player or nearer (up to REACH)
# it draws IN FRONT (z 2); clearly behind them it stays under. Nothing is shifted any more (round 37's 6 px "sit back" is gone, tools/art/nest.py BODY_RISE is 0).
# Kinds: a live enemy that died, a riser still lying, a resident / survivor that died, the static sprite a re-entered flat lays, the baked dead of a story, a
# corridor's baked dead, and a previous character's body — in flats AND corridors. Run: godot --headless res://tests/corpse_depth_test.tscn

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
	await _test_lane_rule()
	await _test_other_kinds()
	await _test_corridor()
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
	check(CD.in_front_of(353.0, 353.0), "a body level with the player (same feet row) is in front of them")
	check(CD.in_front_of(353.0, 339.0), "…a body on the lane is in front of a player up on the back plane")
	check(CD.in_front_of(351.0, 353.0) and not CD.in_front_of(349.0, 353.0), "…a body just behind them (within %.0f px) still counts as level; further back it is behind them" % CD.SAME)
	check(not CD.in_front_of(330.0, 353.0), "…a body clearly behind the player stays under them (a player in front of it draws over it)")
	check(CD.in_front_of(353.0 + CD.REACH, 353.0) and not CD.in_front_of(353.0 + CD.REACH + 1.0, 353.0), "…and one far in front can't overlap them, so it is left alone (REACH %.0f px: another floor in a pan stays out)" % CD.REACH)
	check(CD.Z > 1, "in front means over the actor layer (z 1)")
	# the art bakes its bodies on the row they were placed on: one number, two files
	var nest_py: String = FileAccess.get_file_as_string("res://tools/art/nest.py")
	var rise_line := ""
	for line in nest_py.split("\n"):
		if line.begins_with("BODY_RISE"):
			rise_line = line
	var art_rise: int = int(rise_line.split("=")[1].strip_edges().split(" ")[0]) if rise_line != "" else -1
	check(art_rise == int(CD.BAKED_RISE) and art_rise == 0, "tools/art/nest.py BODY_RISE (%d) = corpse_depth.gd BAKED_RISE (%d) = 0: no body sits behind its row" % [art_rise, int(CD.BAKED_RISE)])
	check(not ("RISE" in CD) and not ("FRONT_GAP" in CD), "the old sit-back constants are gone")


# --- a live enemy that died in the flat ---------------------------------------------------------------------------------

func _test_live_corpse() -> void:
	print("[a live corpse: stays where it fell, and draws in front of a player level with it]")
	var CD = load("res://scripts/corpse_depth.gd")
	var room = await _room("1001")
	var p = room.get_node("Player")
	check(room.get_node_or_null("CorpseDepth") is CorpseDepth, "a flat has the sorter")
	var z = load("res://scenes/enemy_zombie_standard.tscn").instantiate()
	z.spawn_key = ""
	room.add_child(z)
	z.global_position = Vector2(560.0, 321.0)
	await _frames(40)
	var spr: AnimatedSprite2D = z.get_node("AnimatedSprite2D")
	var alive_y: float = spr.position.y
	z.receive_damage(999, "melee")
	await _frames(150)
	check(z.is_dead and spr.animation == "Death" and spr.frame == spr.sprite_frames.get_frame_count("Death") - 1, "it has died and finished falling")
	check(absf(spr.position.y - alive_y) < 0.01, "the body has not been shifted: it lies where it fell (sprite y %.1f -> %.1f)" % [alive_y, spr.position.y])
	check(z.z_index == CD.Z, "the player on the lane, level with it: the body draws OVER them (z %d)" % z.z_index)
	_plane(p, true)
	await _frames(4)
	check(absf(p.feet_position().y - 339.0) < 0.6, "the player up on the back plane (feet %.0f)" % p.feet_position().y)
	check(z.z_index == CD.Z, "…the body is nearer than them: over them (z %d)" % z.z_index)
	# it hides the player's feet: the body's drawn bottom is at (or below) the lane row the player's feet stand on
	var drawn_bottom: float = z.global_position.y + EnemyFeet.drawn_bottom(spr)     # (drawn_bottom is in the body's own space)
	check(drawn_bottom >= RoomScript.ROOM_FEET_Y - EnemyFeet.PLAYER_DRAWN_ABOVE_COLLISION - 0.6, "its drawn bottom (%.1f) is on the player's row: their lower legs go behind it" % drawn_bottom)
	_plane(p, false)
	p.global_position.y += 12.0                          # a player standing NEARER than the body (in front of it)
	await _frames(4)
	check(z.z_index == 0, "a player standing in front of it (12 px nearer): the body stays under them (z %d)" % z.z_index)
	p.global_position.y -= 12.0
	await _frames(4)
	check(z.z_index == CD.Z, "back level with it: over them again")
	room.free()
	await get_tree().process_frame


# --- the static bodies a re-entered flat lays ----------------------------------------------------------------------------

func _test_static_corpses() -> void:
	print("[static corpses: the same row as the body that died, in front]")
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
	var want: float = RoomScript.ROOM_FEET_Y - EnemyFeet.PLAYER_DRAWN_ABOVE_COLLISION
	for c in bodies:
		var bottom: float = EnemyFeet.drawn_bottom(c)      # (the corpse IS the sprite: its position is already in it)
		var kind: String = "big" if c.sprite_frames.has_animation("Death") and not c.sprite_frames.has_animation("Dead_Dead") else "standard"
		check(absf(bottom - want) < 0.6, "%s: drawn bottom %.1f = the lane row %.0f (no sit-back)" % [kind, bottom, want])
	await _frames(4)
	for c in bodies:
		check(c.z_index == CD.Z, "player on the lane, level with it: the body is over them")
	_plane(p, true)
	await _frames(4)
	for c in bodies:
		check(c.z_index == CD.Z, "player on the back plane: the body is over them")
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


# THE WALKING LINE (owner round 45b: "the chair is way too close so it looks like player is clipping through", "player standing on the paint cans
# that are flat on the floor"). The player and every enemy draw over ALL baked art, so a piece standing / lying on the lane reads as walked over.
# The art tool refuses one (tools/art/pixlib.py `_lane_violations`: a piece is wholly behind row 122 or wholly in front of row 131), nest.py keeps
# dropped objects at row 122 or higher up, and a piece wholly IN FRONT is laid over the actors as an `<art>_over.png` layer (room._add_over_art).
func _test_lane_rule() -> void:
	print("[the walking line: nothing baked on it; anything in front is an over layer]")
	var rooms := "res://assets/rooms/"
	check(RoomScript.over_art_candidate(rooms + "dining_room_e.png") == rooms + "dining_room_e_over.png", "an over layer is named <art>_over.png")
	check(RoomScript.over_art_candidate(rooms + "dining_room_e_r2.png") == rooms + "dining_room_e_over_r2.png"
			and RoomScript.over_art_candidate(rooms + "dining_room_e_r3.png") == rooms + "dining_room_e_over_r3.png", "…one per run look")
	check(RoomScript.over_art_candidate(rooms + "dining_room_e_burnt.png") == "", "a burnt flat has none")
	check(RoomScript.OVER_ART_Z > load("res://scripts/corpse_depth.gd").Z and RoomScript.OVER_ART_Z > 1,
		"an over layer draws over the actors AND over a body in front of a back-plane player (z %d)" % RoomScript.OVER_ART_Z)
	# nothing in the art is in front of the lane today: the chairs and the torn box that were moved BEHIND it must not leave a layer (or its .import) behind
	var over_files := []
	var near_files := []
	for fn in DirAccess.get_files_at("res://assets/rooms"):
		if fn.contains("_over") and fn.ends_with(".png"):
			over_files.append(fn)
		if fn.contains("_near"):
			near_files.append(fn)
	check(near_files.is_empty(), "the corpse-clip masks (_near) are gone with the pieces that needed them (%s)" % str(near_files.slice(0, 3)))
	for fn in over_files:
		var oi: Image = load(rooms + fn).get_image()
		var ai: Image = load(rooms + fn.replace("_over", "")).get_image()
		var top := 999
		var n := 0
		var same := true
		for y in range(oi.get_height()):
			for x in range(oi.get_width()):
				var px := oi.get_pixel(x, y)
				if px.a > 0.5:
					n += 1
					top = mini(top, y)
					if not px.is_equal_approx(ai.get_pixel(x, y)):
						same = false
		check(n > 20 and top >= 131 and same and oi.get_size() == ai.get_size(),
			"%s: %d px of its own art, wholly in front of the lane (highest row %d >= 131)" % [fn, n, top])
	# a generated PNG removed by the art tool must take its .import with it: an orphan makes ResourceLoader.exists() say yes to a file that
	# is gone, and the engine draws the OLD texture from its cache (dining E's chair lived on that way)
	var orphans := []
	for fn in DirAccess.get_files_at("res://assets/rooms"):
		if fn.ends_with(".png.import") and not FileAccess.file_exists("res://assets/rooms/" + fn.trim_suffix(".import")):
			orphans.append(fn)
	check(orphans.is_empty(), "no orphaned .import file under assets/rooms (%s)" % str(orphans.slice(0, 3)))
	# the art tool's own rule, read from its source so a loosened rule fails here
	var pix: String = FileAccess.get_file_as_string("res://tools/art/pixlib.py")
	check(pix.contains("LANE_CLEAR_ROW = 122") and pix.contains("LANE_FRONT_ROW = 131"),
		"pixlib.py holds the lane rule: behind row 122 or in front of row 131")
	var nest: String = FileAccess.get_file_as_string("res://tools/art/nest.py")
	check(nest.contains("OBJECT_BASE_MAX = 122"), "nest.py keeps dropped objects at row 122 or higher up")
	# in a real flat nothing is laid over the actors today
	var room = await _room("2703")
	for m in room.get_children():
		if m.is_in_group("room_module") and m.get_node_or_null("OverArt") != null:
			check(false, "no module has art in front of the lane today, yet one got an OverArt layer: " + String(m.scene_file_path))
	room.free()
	await get_tree().process_frame


# --- the baked dead of a corpse / breach story -----------------------------------------------------------------------------

func _test_baked_dead() -> void:
	print("[the baked dead: their own layer, on their row, sorted]")
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
		check(d.z_index == (CD.Z if CD.in_front_of(feet, p.feet_position().y) else 0), "player on the lane: z %d for a body whose feet are at %.0f (player %.0f)" % [d.z_index, feet, p.feet_position().y])
		any_over_lane = any_over_lane or d.z_index == CD.Z
	_plane(p, true)
	await _frames(4)
	for d in dead_sprites:
		var feet2: float = d.global_position.y + float(d.get_meta("feet_off")) * d.global_scale.y
		check(CD.in_front_of(feet2, p.feet_position().y) == (d.z_index == CD.Z), "player on the back plane: z %d (feet %.0f vs theirs %.0f)" % [d.z_index, feet2, p.feet_position().y])
	check(any_over_lane, "a body lying level with the lane draws over a player standing on it")
	# the search spot sits on the body, and ABOVE it (a body in front of the player is z 2 — its star must not be hidden behind it)
	var search_ok := false
	var star_over := false
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
				if a.z_index > d.z_index and a.z_index > CD.Z:
					star_over = true
	check(search_ok, "its search spot is on the body")
	check(star_over, "…and its star draws above the body (z %d > %d)" % [CD.Z + 1, CD.Z])
	# a charred / backdrop room has no sorter: its sprites just stay under the player
	room.free()
	await get_tree().process_frame


# --- the other kinds: a riser lying, a resident / survivor that died, a previous character's body --------------------------------

func _test_other_kinds() -> void:
	print("[a riser, the NPC dead, a fallen character: all sorted by their feet]")
	var CD = load("res://scripts/corpse_depth.gd")
	var room = await _room("1001")
	var p = room.get_node("Player")
	var feet: float = p.feet_position().y
	# a riser lying on the lane is a body; once up it is an ordinary zombie again
	var rz = load("res://scenes/enemy_zombie_standard.tscn").instantiate()
	rz.spawn_key = ""
	room.add_child(rz)
	rz.global_position = Vector2(640.0, 321.0)
	rz.start_riser(1.0, "t:riser", 0.0)
	await _frames(6)
	check(rz.is_riser_down() and rz.z_index == CD.Z, "a riser lying level with the player is over them (z %d)" % rz.z_index)
	rz._riser_up()
	await _frames(4)
	check(rz.z_index == 1, "…once up it is an actor again (z %d), never left in front" % rz.z_index)
	rz.free()
	# a resident / survivor that died: anything in those groups with is_dead is a body at its origin (= its feet)
	for g in ["resident_npc", "survivor"]:
		var n := Node2D.new()
		n.set_script(load("res://tests/_dead_stub.gd"))
		room.add_child(n)
		n.add_to_group(g)
		n.global_position = Vector2(700.0, feet)
		n.is_dead = true
		await _frames(4)
		check(n.z_index == CD.Z, "a dead member of group %s level with the player is over them (z %d)" % [g, n.z_index])
		n.global_position.y = feet - 30.0
		await _frames(4)
		check(n.z_index == 0, "…one lying 30 px behind them stays under (z %d)" % n.z_index)
		n.is_dead = false
		n.global_position.y = feet
		await _frames(4)
		check(n.z_index == 0 or n.z_index == 1, "…a living one is never lifted by the sorter (z %d)" % n.z_index)
		n.free()
	# the body of a previous character
	var pc = load("res://scripts/player_corpse.gd").new()
	pc.corpse_key = "t:corpse"
	room.add_child(pc)
	pc.global_position = Vector2(780.0, feet)
	await _frames(4)
	check(pc.z_index == CD.Z, "a fallen character's body level with the player is over them (z %d)" % pc.z_index)
	pc.free()
	room.free()
	await get_tree().process_frame


# --- corridors: the same rule ---------------------------------------------------------------------------------------------------

func _test_corridor() -> void:
	print("[a corridor: the same rule, for its dead zombies and its baked dead]")
	var CD = load("res://scripts/corpse_depth.gd")
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
	check(bf.get_node_or_null("CorpseDepth") is CorpseDepth, "a corridor has the sorter")
	var p = bf.get_node("Player")
	var z = load("res://scenes/enemy_zombie_standard.tscn").instantiate()
	z.spawn_key = ""
	bf.add_child(z)
	z.global_position = Vector2(600.0, 370.0)
	await _frames(40)
	var spr: AnimatedSprite2D = z.get_node("AnimatedSprite2D")
	var before: float = spr.position.y
	z.receive_damage(999, "melee")
	await _frames(150)
	check(z.is_dead and absf(spr.position.y - before) < 0.01, "a dead zombie stays where it fell (sprite y %.1f -> %.1f)" % [before, spr.position.y])
	check(z.z_index == CD.Z, "…and, level with the player's row, draws over them (z %d)" % z.z_index)
	# a baked body (a decal in group corridor_dead): its feet are its sprite's bottom row
	var tex: Texture2D = load("res://assets/corridor/decals/dead_1.png")
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.add_to_group("corridor_dead")
	bf.add_child(s)
	s.global_position = Vector2(300.0, p.feet_position().y - float(tex.get_height()) + 1.0)
	await _frames(4)
	check(s.z_index == CD.Z, "a baked corridor body lying on the player's row is over them (z %d)" % s.z_index)
	s.global_position.y -= 40.0
	await _frames(4)
	check(s.z_index == 0, "…one lying 40 px behind them is under (z %d)" % s.z_index)
	bf.free()
	await get_tree().process_frame
