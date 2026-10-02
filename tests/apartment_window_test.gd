extends Node

# Apartment WALL WINDOWS: every non-balcony module gets one window at a seeded LEFT/RIGHT
# wall slot, sitting in the anchor-free top wall band (no overlap with scavenge nodes).
# Natural light by run; night adds the rain/lightning storm. Run:
#   godot --headless res://tests/apartment_window_test.tscn

var failures: int = 0
const APT := "1501"


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== apartment window test ===")
	_test_seeded_side()
	await _test_windows_day()
	await _test_windows_night()
	await _test_city_outside()
	await _test_city_parallax()
	await _test_exit_through_door()
	_test_floor_boundary()
	_test_module_variants()
	await _test_module_sounds()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _test_seeded_side() -> void:
	WorldState.new_game()
	# Deterministic + stable: same call, same answer; independent of run.
	var a := WorldState.apartment_window_side(APT, 0)
	WorldState.current_run = 3
	var b := WorldState.apartment_window_side(APT, 0)
	check(a == b, "window side is stable across runs (%s == %s)" % [a, b])
	check(a in ["left", "right"], "side is left or right (%s)" % a)
	# Both sides occur across the building (not all one side).
	var lefts := 0
	var rights := 0
	for f in range(1, 30):
		for col in range(1, 6):
			var apt := str(f) + "0" + str(col)
			for slot in range(3):
				if WorldState.apartment_window_side(apt, slot) == "left":
					lefts += 1
				else:
					rights += 1
	check(lefts > 0 and rights > 0, "both left and right windows occur (L %d / R %d)" % [lefts, rights])


func _balcony_count(apt: String) -> int:
	var n := 0
	for slot in range(3):
		if WorldState.is_balcony_slot(apt, slot):
			n += 1
	return n


func _expected_windows(apt: String) -> int:
	var n := 0
	for slot in range(3):
		if not WorldState.is_balcony_slot(apt, slot):
			n += 1
	return n


func _test_windows_day() -> void:
	WorldState.new_game()
	WorldState.is_first_run = false          # skip tutorial layouts
	WorldState.current_run = 1                # morning / day
	WorldState.current_apartment_id = APT
	WorldState.current_floor = 15
	WorldState.spawn_source = ""
	var room = load("res://scenes/room.tscn").instantiate()
	add_child(room)
	for i in range(5):
		await get_tree().process_frame
	var windows := get_tree().get_nodes_in_group("apt_window_light")
	check(windows.size() == _expected_windows(APT),
		"one window per non-balcony module (%d, expected %d)" % [windows.size(), _expected_windows(APT)])
	# Every window sits on the wallpaper band (world 262 = module-local 38 — above the chair rail
	# at local 70, below the crown moulding), read from the room's own constant.
	var wy: float = room.MODULE_WINDOW_Y
	check(absf(wy - 262.0) < 0.5, "the window line is world 262 (module-local 38)")
	var win_y_ok := true
	for w in windows:
		if absf(w.global_position.y - wy) > 1.0:
			win_y_ok = false
	check(win_y_ok, "windows sit on the wallpaper band (y %.0f)" % wy)
	# The whole pane + frame stays on the wallpaper: above the chair rail (module-local 70), below
	# the crown moulding (local 5).
	var PW = load("res://scripts/apartment_window.gd")
	var top_local: float = wy - 224.0 - PW.PANE_HALF_H - 1.5
	var bot_local: float = wy - 224.0 + PW.PANE_HALF_H + 1.5
	check(top_local >= 6.0 and bot_local <= 69.0, "window spans local %.1f..%.1f, inside the wallpaper band 6..69" % [top_local, bot_local])
	# The window CENTRE sits ABOVE every scavenge node (window higher on the wall than the
	# furniture), so it never obscures a node's interaction point — a node may sit under it.
	var min_anchor_y := 100000.0
	for m in get_tree().get_nodes_in_group("room_module"):
		for c in m.get_children():
			if c is Marker2D:
				min_anchor_y = minf(min_anchor_y, m.global_position.y + c.position.y)
	check(min_anchor_y > wy, "every scavenge node sits below the window centre (lowest %.0f > %.0f)" % [min_anchor_y, wy])
	check(get_tree().get_nodes_in_group("apt_storm").is_empty(), "no storm on a day run")
	# MODULE WALLS (owner round 9): a perspective wall at every boundary, the face toward the camera.
	var mw = room.get_node_or_null("ModuleWalls")
	check(mw != null, "the room builds its module walls")
	if mw != null:
		var bs: Array = mw.boundaries
		check(bs.size() == 4, "4 walls: two ends + two partitions (%d)" % bs.size())
		var interior_doors := 0
		var outside := 0
		for b in bs:
			if b["left"] != null and b["right"] != null and b["door"]:
				interior_doors += 1
			if b["outside"]:
				outside += 1
		check(interior_doors == 2, "both partitions have a doorway (%d)" % interior_doors)
		check(outside == 1, "exactly one end is the entrance (doorway to the corridor) (%d)" % outside)
		var mid: Dictionary = bs[1]
		check(mw.facing_room(mid, float(mid["x"]) - 50.0) == mid["left"], "camera left of a partition sees the LEFT room's wall")
		check(mw.facing_room(mid, float(mid["x"]) + 50.0) == mid["right"], "…and from the right, the RIGHT room's wall (never inverted)")
	# ROOM SHELL (owner round 9): the stone tiles are replaced by a cross-section frame that meets
	# the module walls exactly — the slab's underside where the partitions' front cuts top out, each
	# end section starting where that end wall's face ends — and the camera reaches past the tiles.
	var shell = room.get_node_or_null("RoomShell")
	check(shell != null, "the room builds its shell")
	var tm = room.get_node_or_null("TileMapLayer")
	check(tm != null and not tm.visible, "the old stone tiles are hidden")
	if shell != null and mw != null:
		var MW = load("res://scripts/module_walls.gd")
		var bs: Array = mw.boundaries
		var s_front: float = MW._s_for_floor(MW.FRONT_FLOOR)
		var cx := 600.0
		var part_top: Vector2 = mw._p(cx, float(bs[1]["x"]), MW.TOP, s_front)
		check(absf(shell.ceiling_cut_y() - part_top.y) < 0.01,
			"slab underside %.2f == partition front top %.2f" % [shell.ceiling_cut_y(), part_top.y])
		check(shell.ceiling_cut_y() < room.MODULE_WINDOW_Y - 28.0, "the slab clears the wall windows' top (%.1f)" % shell.ceiling_cut_y())
		var lx: float = bs[0]["x"]
		var rx: float = bs[bs.size() - 1]["x"]
		var l_face: Vector2 = mw._p(cx, lx + MW.HALF_T, MW.TOP, s_front)   # left end's room-side face
		var r_face: Vector2 = mw._p(cx, rx - MW.HALF_T, MW.TOP, s_front)
		check(absf(shell.end_cut_x(lx, cx) - l_face.x) < 0.01, "left section starts at the wall face's front edge")
		check(absf(shell.end_cut_x(rx, cx) - r_face.x) < 0.01, "right section starts at the wall face's front edge")
		var cam = room.get_node("Player/Camera2D")
		var half_view: float = get_viewport().get_visible_rect().size.x / cam.zoom.x / 2.0
		# The camera pinned at an end shows only a sliver of section past the wall's cut (no wasted band).
		var shown_l: float = shell.end_cut_x(lx, float(cam.limit_left) + half_view) - float(cam.limit_left)
		var shown_r: float = float(cam.limit_right) - shell.end_cut_x(rx, float(cam.limit_right) - half_view)
		check(absf(shown_l - shell.SECTION_SHOW) <= 1.0 and absf(shown_r - shell.SECTION_SHOW) <= 1.0,
			"pinned at an end, only ~%.0fpx of section shows (L %.1f / R %.1f)" % [shell.SECTION_SHOW, shown_l, shown_r])
		# The solid walls sit where the DRAWN wall meets the floor at the lane (no invisible wall short of it).
		var lw = room.get_node("LeftWall")
		var lcol = lw.get_node("CollisionShape2D")
		var l_edge: float = lw.position.x + lcol.position.x + lcol.shape.size.x / 2.0
		var rw = room.get_node("RightWall")
		var rcol = rw.get_node("CollisionShape2D")
		var r_edge: float = rw.position.x + rcol.position.x - rcol.shape.size.x / 2.0
		check(absf(l_edge - room.wall_foot_left) < 0.5 and absf(r_edge - room.wall_foot_right) < 0.5,
			"wall collision = the drawn wall's foot (L %.1f/%.1f, R %.1f/%.1f)" % [l_edge, room.wall_foot_left, r_edge, room.wall_foot_right])
		check(room.wall_foot_left < 100.0 and room.wall_foot_right > 1086.0,
			"the player reaches further than the old tile walls (112 / 1074): %.1f / %.1f" % [room.wall_foot_left, room.wall_foot_right])
		var door = room.get_node("Area2D")
		var foot_entry: float = room.wall_foot_left if WorldState.get_entrance_side(APT) == "left" else room.wall_foot_right
		check(absf(door.position.x - foot_entry) <= 2.5, "the exit trigger sits at the drawn front door (%.1f vs %.1f)" % [door.position.x, foot_entry])
		# Doorways are tall enough for the tallest enemy (spitter, drawn top 257 at the lane) to pass under.
		var lintel_y: float = MW.TOP + float(MW.DOOR_ROWS) * MW._s_for_floor(room.ROOM_FEET_Y)
		check(lintel_y < 257.0 - 4.0, "a doorway's lintel at the lane (%.1f) clears the tallest enemy (257)" % lintel_y)
		check(room.ROOM_BAND_TOP == load("res://scripts/balcony_pan.gd").ROOM_BAND_TOP,
			"balcony_pan's band top matches the room's (%.0f)" % room.ROOM_BAND_TOP)
		check(room.ROOM_BAND_TOP + room.ROOM_BAND_H == shell.BAND_BOTTOM, "the shell ends at the band bottom")
		# Walk the player into the solid (non-entrance) end: it stops with its body at the drawn wall.
		var p = room.get_node("Player")
		var solid_left := WorldState.get_entrance_side(APT) != "left"
		p.global_position.x = 200.0 if solid_left else 986.0
		var act := "move_left" if solid_left else "move_right"
		Input.action_press(act)
		for i in range(150):
			await get_tree().physics_frame
		Input.action_release(act)
		var body_edge: float = p.global_position.x - 13.0 if solid_left else p.global_position.x + 13.0
		var foot: float = room.wall_foot_left if solid_left else room.wall_foot_right
		check(absf(body_edge - foot) < 3.0, "walking into the end wall stops the body AT the drawn wall (%.1f vs %.1f)" % [body_edge, foot])
	# Every window / balcony door casts a slanting light BEAM (window_beam.gd) that carries a
	# real PointLight2D — so the shaft actually lights the room, not just a painted overlay.
	var beams := get_tree().get_nodes_in_group("window_beam")
	check(beams.size() >= windows.size(),
		"each window casts a light beam (%d beams >= %d windows)" % [beams.size(), windows.size()])
	var beams_lit := beams.size() > 0
	for b in beams:
		var has_light := false
		for c in b.get_children():
			if c is PointLight2D:
				has_light = true
		beams_lit = beams_lit and has_light
	check(beams_lit, "every beam carries a real cast light")
	room.queue_free()
	await get_tree().process_frame


func _test_windows_night() -> void:
	WorldState.new_game()
	WorldState.is_first_run = false
	WorldState.current_run = 3                # night
	WorldState.current_apartment_id = APT
	WorldState.current_floor = 15
	WorldState.spawn_source = ""
	var room = load("res://scenes/room.tscn").instantiate()
	add_child(room)
	for i in range(5):
		await get_tree().process_frame
	check(get_tree().get_nodes_in_group("apt_window_light").size() == _expected_windows(APT),
		"windows still spawn at night")
	check(not get_tree().get_nodes_in_group("apt_storm").is_empty(), "a night run adds the storm driver")
	# Looping PIXEL rain plays behind every window's glass at night (assets/city/rain_window.png).
	var rain_nodes := get_tree().get_nodes_in_group("window_rain")
	check(rain_nodes.size() == _expected_windows(APT), "every night window has its pixel-rain loop (%d of %d)" % [rain_nodes.size(), _expected_windows(APT)])
	var rain_ok := not rain_nodes.is_empty()
	for r in rain_nodes:
		rain_ok = rain_ok and r is AnimatedSprite2D and r.is_playing() and r.sprite_frames.get_frame_count("default") == 13 \
			and r.sprite_frames.get_animation_loop("default")
	check(rain_ok, "...a 13-frame looping AnimatedSprite2D that is playing")
	var old_particles := false
	for w in get_tree().get_nodes_in_group("apt_window_light"):
		for c in w.get_parent().get_children():
			if c is CPUParticles2D:
				old_particles = true
	check(not old_particles, "the old particle streaks are gone")
	# the balcony, if this flat has one, has its rain + ripples at night too
	var bal_rain := get_tree().get_nodes_in_group("balcony_rain")
	var has_bal := false
	for sl in range(3):
		if WorldState.is_balcony_slot(APT, sl):
			has_bal = true
	check(bal_rain.size() == (1 if has_bal else 0) * _balcony_count(APT), "night balconies carry the rain sheet (%d)" % bal_rain.size())
	check(get_tree().get_nodes_in_group("balcony_splash").size() == 9 * bal_rain.size(), "...and ripples on the wet tiles")
	room.queue_free()
	await get_tree().process_frame


func _test_exit_through_door() -> void:
	# Owner round 9: the player LEAVES THROUGH the drawn front door — steps into its threshold and out
	# through the opening, fading into the corridor — on either side, whatever module is at that end.
	print("[exit: walk out through the drawn front door, both sides]")
	var done := {}
	for f in range(10, 29):
		for col in range(1, 6):
			var apt := str(f) + "0" + str(col)
			WorldState.new_game()
			var side := WorldState.get_entrance_side(apt)
			if done.has(side):
				continue
			done[side] = true
			WorldState.is_first_run = false
			WorldState.current_run = 1
			WorldState.current_apartment_id = apt
			WorldState.current_floor = f
			WorldState.spawn_source = ""
			WorldState.god_mode = true
			var room = load("res://scenes/room.tscn").instantiate()
			add_child(room)
			for i in range(5):
				await get_tree().physics_frame
			for z in get_tree().get_nodes_in_group("zombie"):
				if room.is_ancestor_of(z):
					z.queue_free()
			var p = room.get_node("Player")
			var door = room.get_node("Area2D")
			var left := side == "left"
			var out := -1.0 if left else 1.0
			var called := [false]
			door.leave_override = func(): called[0] = true
			var pts: Array = room.exit_walk_points(p)
			check(pts.size() == 2, "%s entrance (%s): the room knows where its front door is" % [side, apt])
			if pts.size() != 2:
				room.free()
				continue
			# The walk's door x is where module_walls DRAWS the door (its face at the door's mid-depth).
			var cam = p.get_node("Camera2D")
			var half_view: float = get_viewport().get_visible_rect().size.x / cam.zoom.x / 2.0
			var cam_x: float = (float(cam.limit_left) + half_view) if left else (float(cam.limit_right) - half_view)
			var mw = load("res://scripts/module_walls.gd")
			var inner: float = (float(room.LEFT_WALL_X) + mw.HALF_T) if left else (float(room.LEFT_WALL_X + 3 * room.MODULE_WIDTH) - mw.HALF_T)
			var face: float = cam_x + (inner - cam_x) * mw._s_for_floor(room.exit_door_floor_y())
			check(absf((pts[0].x + pts[1].x) * 0.5 - (face + out * 9.5)) < 0.6,
				"%s: the walk goes through the drawn door (face %.1f; threshold %.1f, beyond %.1f)" % [side, face, pts[0].x, pts[1].x])
			var y0: float = p.global_position.y
			var act := "move_left" if left else "move_right"
			Input.action_press(act)
			var frames := 0
			while not called[0] and frames < 900:
				await get_tree().physics_frame
				frames += 1
			Input.action_release(act)
			check(called[0], "%s: walking into the entrance leaves the room (%d frames)" % [side, frames])
			check((p.global_position.x - face) * out > 10.0, "%s: …having walked out PAST the door's face (%.1f vs %.1f)" % [side, p.global_position.x, face])
			check(p.global_position.y < y0 - 3.0, "%s: …stepping up into the door's depth (y %.1f -> %.1f)" % [side, y0, p.global_position.y])
			check(p.modulate.a < 0.05, "%s: …and fading into the corridor's dark (alpha %.2f)" % [side, p.modulate.a])
			WorldState.god_mode = false
			room.free()
			await get_tree().process_frame
		if done.size() == 2:
			break
	check(done.size() == 2, "both a left and a right entrance were tested (%s)" % str(done.keys()))


func _test_floor_boundary() -> void:
	# Owner round 14: "depending on where you move to the corpse's head is either in one room or the
	# other. The head didn't move, the perspective of the floor moved." Between two rooms the floors
	# meet on a FIXED line (the module edge, under the doorway's saddle) whatever the camera does, and
	# the doorway's jamb stands on it; only an END wall's base line moves with the camera.
	print("[the floor join between rooms is fixed; the jamb stands on it]")
	var MW = load("res://scripts/module_walls.gd")
	var mw = MW.new()
	add_child(mw)
	var xb := 433.0
	var inner := {"x": xb, "left": mw, "right": mw, "door": true, "outside": false}
	for cam in [xb - 300.0, xb - 60.0, xb - 10.0, xb, xb + 10.0, xb + 60.0, xb + 300.0]:
		for fy in [MW.SEAM, 347.0, 353.0, 368.0]:
			check(absf(mw.floor_boundary_x(inner, cam, fy) - xb) < 0.01,
				"camera %.0f, floor %.0f: the join between two rooms stays on the module edge" % [cam, fy])
		check(absf(mw.jamb_x(xb, cam) - xb) < 0.01, "camera %.0f: the doorway's jamb stands on the join (%.2f)" % [cam, mw.jamb_x(xb, cam)])
	var end_b := {"x": xb, "left": mw, "right": null, "door": false, "outside": false}
	check(mw.floor_boundary_x(end_b, xb - 144.0, 353.0) > xb + 10.0, "an END wall's base still runs out past the edge toward the front")
	mw.free()
	# Floors are drawn in PERSPECTIVE (tools/art pixlib.persp): the floor-only export is the floor as the
	# art shows it; the _floor_ext export runs FLOOR_EXT_M px past each edge (the end-wall wedge) and its
	# middle is exactly that floor.
	var m_ext: int = int(MW.FLOOR_EXT_M)
	var RoomScript = load("res://scripts/room.gd")
	for rt in RoomScript.MODULE_VARIANTS:
		for path in RoomScript.MODULE_VARIANTS[rt]:
			var inst = load(path).instantiate()
			var art = inst.get_node_or_null("Art")
			var base: String = art.texture.resource_path.get_basename() if art is Sprite2D and art.texture != null else ""
			inst.free()
			check(base != "", "%s: has art" % path.get_file())
			if base == "":
				continue
			for b2 in [base, base + "_r2", base + "_r3"]:
				var fp: String = b2 + "_floor.png"
				var xp: String = b2 + "_floor_ext.png"
				check(ResourceLoader.exists(fp) and ResourceLoader.exists(xp), "%s: floor + extended floor exports exist" % b2.get_file())
				if not (ResourceLoader.exists(fp) and ResourceLoader.exists(xp)):
					continue
				var fl: Image = _img(fp)
				var ex: Image = _img(xp)
				check(fl.get_width() == 320 and fl.get_height() == 44, "%s: a floor-only export, 320x44" % fp.get_file())
				check(ex.get_width() == 320 + 2 * m_ext and ex.get_height() == 44, "%s: %dx44" % [xp.get_file(), 320 + 2 * m_ext])
				check(ex.get_region(Rect2i(m_ext, 0, 320, 44)).get_data() == fl.get_data(), "%s: its middle IS the room's floor" % xp.get_file())
	# the tiles recede: on the kitchen's checker the tile edges lean toward the middle further forward,
	# so a row near the front is a squeezed-out copy of the back row, not the same row (that read as
	# "standing on glass… the tiles go directly down")
	var kb: Image = _img("res://assets/rooms/kitchen_b_floor.png")
	var same_cols := 0
	for x in range(320):
		if kb.get_pixel(x, 2) == kb.get_pixel(x, 42):
			same_cols += 1
	check(same_cols < 250, "kitchen B's checker isn't the same column all the way down (%d/320 alike)" % same_cols)
	# the end-wall wedge paints from that extended export
	var m = load("res://scenes/Room_Modules/kitchen.tscn").instantiate()
	add_child(m)
	var w2 = MW.new()
	add_child(w2)
	var tex: Texture2D = w2._floor_ext(m)
	check(tex != null and tex.resource_path == "res://assets/rooms/kitchen_floor_ext.png", "the end-wall wedge uses the extended floor (%s)" % (tex.resource_path if tex != null else "null"))
	w2.free()
	m.free()


func _img(path: String) -> Image:
	var im: Image = load(path).get_image()
	if im.is_compressed():
		im.decompress()
	return im


func _test_module_variants() -> void:
	# Every room type's ART VARIANTS (room.MODULE_VARIANTS): each loads as its room type, carries
	# its art with the placeholder label hidden, enough nodes of its own, node names no other room
	# type uses (loot memory is keyed apartment:anchor), and on a balcony room the Balcony draws
	# over the art. Every scene in Room_Modules/ is registered; the pick is seeded + spread.
	var RoomScript = load("res://scripts/room.gd")
	var owner_of := {}
	var registered := {}
	var n_anims := 0
	for rt in RoomScript.MODULE_VARIANTS:
		var paths: Array = RoomScript.MODULE_VARIANTS[rt]
		check(paths[0] == RoomScript.MODULE_SCENES[rt], "%s: the base scene is variant 0" % rt)
		for path in paths:
			registered[path] = true
			var inst = load(path).instantiate()
			var nm: String = path.get_file()
			var lbl = inst.get_node_or_null("ColorRect/Label")
			check(lbl != null and lbl.text.to_lower().replace(" ", "_") == rt, "%s: reads as a %s" % [nm, rt])
			check(lbl != null and not lbl.visible, "%s: the placeholder label is hidden" % nm)
			var art = inst.get_node_or_null("Art")
			check(art is Sprite2D and art.texture != null, "%s: an Art sprite with a texture" % nm)
			var bal = inst.get_node_or_null("Balcony")
			var strip_art = inst.get_node_or_null("StripArt")
			if rt in ["study", "dining_room"]:
				check(bal != null and art != null and bal.get_index() > art.get_index(), "%s: the Balcony draws over the art" % nm)
				if strip_art != null:
					check(bal.get_index() > strip_art.get_index(), "%s: …and over the strip furniture" % nm)
			var n_main := 0
			for c in inst.get_children():
				if not (c is Marker2D):
					continue
				check(String(c.name).begins_with("anchor_"), "%s: node %s is an anchor_" % [nm, c.name])
				if not bool(c.get_meta("balcony_strip", false)):
					n_main += 1
				var prev = owner_of.get(String(c.name), rt)
				check(prev == rt, "%s: node %s isn't also a %s node" % [nm, c.name, prev])
				owner_of[String(c.name)] = rt
			check(n_main >= 2, "%s: >= 2 nodes outside the balcony strip (%d)" % [nm, n_main])
			# LIVE DETAILS (owner rounds 19/20): each is a module_anim node of a known kind, inside the
			# module, with a real size — a typo'd kind would silently draw nothing
			var anims = inst.get_node_or_null("Anims")
			if anims != null:
				for a in anims.get_children():
					n_anims += 1
					var sc = a.get_script()
					check(sc != null and sc.resource_path == "res://scripts/module_anim.gd", "%s: %s runs module_anim" % [nm, a.name])
					check(str(a.get_meta("kind", "")) in ["drip", "drop", "blink", "static", "spin", "tv"], "%s: %s has a known kind" % [nm, a.name])
					check(a.position.x >= 0 and a.position.x < 320 and a.position.y >= 0 and a.position.y < 144, "%s: %s sits in the module" % [nm, a.name])
					check(int(a.get_meta("w", 0)) >= 1 and int(a.get_meta("h", 0)) >= 1, "%s: %s has a size" % [nm, a.name])
			inst.free()
	check(n_anims >= 10, "the modules carry live details (%d)" % n_anims)
	var dir := DirAccess.open("res://scenes/Room_Modules")
	for f in dir.get_files():
		if f.ends_with(".tscn"):
			check(registered.has("res://scenes/Room_Modules/" + f), "%s is registered in MODULE_VARIANTS" % f)
	# the runs: every variant has a run-2 and run-3 look (art, floor export, strip), swapped in by run
	for rt in RoomScript.MODULE_VARIANTS:
		for path in RoomScript.MODULE_VARIANTS[rt]:
			var nm2: String = path.get_file()
			for run in [1, 2, 3]:
				var inst = load(path).instantiate()
				var base_art: String = inst.get_node("Art").texture.resource_path
				RoomScript.apply_run_art(inst, run)
				var got: String = inst.get_node("Art").texture.resource_path
				if run == 1:
					check(got == base_art, "%s run 1: the morning art" % nm2)
				else:
					var want: String = base_art.get_basename() + "_r%d.png" % run
					check(got == want, "%s run %d: %s" % [nm2, run, got.get_file()])
					check(ResourceLoader.exists(got.get_basename() + "_floor.png"), "%s run %d: its floor export exists" % [nm2, run])
					var sa = inst.get_node_or_null("StripArt")
					if sa != null:
						check(sa.texture.resource_path.ends_with("_r%d_strip.png" % run), "%s run %d: the strip furniture follows (%s)" % [nm2, run, sa.texture.resource_path.get_file()])
				inst.free()
	# the pick: deterministic, in range, and every variant turns up across a floor's worth of flats
	var n: int = RoomScript.MODULE_VARIANTS["bathroom"].size()
	var seen := {}
	var stable := true
	for f in range(1, 30):
		for col in range(1, 6):
			var apt := str(f) + "0" + str(col)
			var v := WorldState.module_variant_index(apt, 1, "bathroom", n)
			stable = stable and v == WorldState.module_variant_index(apt, 1, "bathroom", n)
			stable = stable and v >= 0 and v < n
			seen[v] = true
	check(stable, "the variant pick is deterministic and in range")
	check(seen.size() == n, "every bathroom variant turns up across the building (%d of %d)" % [seen.size(), n])
	# the balcony strip: hidden with its nodes on a balcony slot, kept otherwise
	var room = RoomScript.new()
	for has_bal in [true, false]:
		var m = load(RoomScript.MODULE_SCENES["study"]).instantiate()
		var before := 0
		for c in m.get_children():
			if c is Marker2D and bool(c.get_meta("balcony_strip", false)):
				before += 1
		room._apply_balcony_strip(m, has_bal)
		var after := 0
		var total := 0
		for c in m.get_children():
			if c is Marker2D:
				total += 1
				if bool(c.get_meta("balcony_strip", false)):
					after += 1
		var sa = m.get_node_or_null("StripArt")
		if has_bal:
			check(before > 0 and after == 0 and total >= 2, "balcony slot: the strip's nodes are removed (%d -> %d), the rest stay (%d)" % [before, after, total])
			check(sa != null and not sa.visible, "balcony slot: the strip furniture is hidden")
		else:
			check(after == before and before > 0, "no balcony: the strip's nodes stay (%d)" % after)
			check(sa != null and sa.visible, "no balcony: the strip furniture shows")
		m.free()
	room.free()


# SOUND (owner round 22): the struck TV hisses only up close, the stuck record carries across its
# module, both loop, and a passive backdrop (the flat below during a balcony pan) stays silent.
func _test_module_sounds() -> void:
	var player := Node2D.new()
	player.add_to_group("player")
	add_child(player)
	for spec in [["res://scenes/Room_Modules/living_room_c.tscn", "tv"], ["res://scenes/Room_Modules/dining_room_b.tscn", "spin"]]:
		var inst: Node2D = load(spec[0]).instantiate()
		add_child(inst)
		await get_tree().process_frame
		var a: Node2D = null
		for c in inst.get_node("Anims").get_children():
			if str(c.get_meta("kind", "")) == spec[1]:
				a = c
		check(a != null, "%s has its %s detail" % [spec[0].get_file(), spec[1]])
		if a == null:
			inst.queue_free()
			continue
		var snd: AudioStreamPlayer = a.get_node_or_null("Sound")
		check(snd != null and snd.playing, "%s: the %s plays a sound" % [spec[0].get_file(), spec[1]])
		if snd != null:
			check(snd.stream is AudioStreamWAV and (snd.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD \
				and (snd.stream as AudioStreamWAV).loop_end > 0, "%s: its sound loops" % spec[1])
			var centre: Vector2 = a.global_position + Vector2(int(a.get_meta("w")), int(a.get_meta("h"))) * 0.5
			player.global_position = centre + Vector2(0, 30)
			await get_tree().process_frame
			var near_db := snd.volume_db
			player.global_position = centre + Vector2(420, 0)
			await get_tree().process_frame
			var far_db := snd.volume_db
			check(near_db > -30.0 and far_db < -60.0, "%s: loud near (%.0f dB), silent far (%.0f dB)" % [spec[1], near_db, far_db])
			var mid: float = a.sound_level(centre + Vector2(150, 0))
			if spec[1] == "tv":
				check(mid < 0.1, "tv: the static is only heard up close (%.2f at 150px)" % mid)
			else:
				check(mid > 0.4, "spin: the record carries across the module (%.2f at 150px)" % mid)
		inst.queue_free()
	# a passive backdrop stays silent
	var gs := GDScript.new()
	gs.source_code = "extends Node2D\nvar passive := true\n"
	gs.reload()
	var holder := Node2D.new()
	holder.set_script(gs)
	add_child(holder)
	var bg: Node2D = load("res://scenes/Room_Modules/living_room_c.tscn").instantiate()
	holder.add_child(bg)
	await get_tree().process_frame
	var silent := true
	for c in bg.get_node("Anims").get_children():
		if c.get_node_or_null("Sound") != null:
			silent = false
	check(silent, "a passive backdrop's details make no sound")
	holder.queue_free()
	player.queue_free()
	await get_tree().process_frame


func _test_city_outside() -> void:
	print("[the city outside: skyline, fires, blasts, rain]")
	var CF = load("res://scripts/city_fx.gd")
	var meta: Dictionary = CF.meta()
	check(not meta.has("_empty"), "the city meta loads (views + balcony points)")
	for run in [1, 2, 3]:
		check(ResourceLoader.exists("res://assets/city/window_frame_%d.png" % run), "run %d: a window frame" % run)
		check(ResourceLoader.exists("res://assets/city/smoke_%d.png" % run), "run %d: a smoke plume strip" % run)
		for v in range(4):
			check(meta.has("view_%d_%d" % [run, v]) and ResourceLoader.exists("res://assets/city/view_%d_%d.png" % [run, v]), "run %d variant %d: a skyline + its fire / blast points" % [run, v])
	# the SAME city stands in all three runs: the tower points (fires / blasts) match across the looks
	for v in range(4):
		var a: Array = meta["view_1_%d" % v]["fire"]
		var c: Array = meta["view_3_%d" % v]["fire"]
		check(a == c, "variant %d: the same towers burn-able in the morning and at night (%d points)" % [v, a.size()])
	# weather by run: nothing on fire in the morning; fires at dusk + night; rain + beacon only at night
	var counts := {}
	for run in [1, 2, 3]:
		WorldState.new_game()
		WorldState.is_first_run = false
		WorldState.current_run = run
		var sizes := 0
		var fires := 0
		var rain := 0
		for v in range(4):
			var win = load("res://scripts/apartment_window.gd").new()
			add_child(win)
			win.setup(Vector2(100, 262), true, v)
			await get_tree().process_frame
			for c in win.fx.get_children() + win.city.far.get_children():
				if c is AnimatedSprite2D and c.sprite_frames.get_frame_count("default") == 6 and c.sprite_frames.get_frame_count("default") == 6 and c.sprite_frames.get_frame_texture("default", 0).get_width() == 6:
					fires += 1
			rain += win.fx.get_tree().get_nodes_in_group("window_rain").size() if v == 3 else 0
			check(win.view != null and win.frame != null, "run %d v%d: the window is a framed view, not a coloured rectangle" % [run, v])
			var gw: int = win.view.texture.get_width()
			var gh: int = win.view.texture.get_height()
			var pan: float = win.city.pan
			check(pan >= 4.0 and absf(win.PANE_HALF_W * 2.0 + pan * 2.0 - gw) < 0.1 and absf(win.PANE_HALF_H * 2.0 - gh) < 0.1,
				"run %d v%d: the skyline (%dx%d) is the glass plus %.0f px each side to pan into" % [run, v, gw, gh, pan])
			check(win.city.clip_children == CanvasItem.CLIP_CHILDREN_ONLY and win.city.mask_rect.size == Vector2(win.PANE_HALF_W, win.PANE_HALF_H) * 2.0,
				"run %d v%d: ...clipped to the glass" % [run, v])
			win.queue_free()
			await get_tree().process_frame
		counts[run] = [fires, rain]
	check(counts[1][0] == 0, "morning: no fires out there")
	check(counts[2][0] >= 1, "afternoon: some fires (%d across four windows)" % counts[2][0])
	check(counts[3][0] > counts[2][0] - 1 and counts[3][0] >= 4, "night: more (%d)" % counts[3][0])
	check(counts[1][1] == 0 and counts[2][1] == 0 and counts[3][1] >= 1, "rain only at night")
	# a blast: a one-shot sprite that plays once and frees itself; it kicks the window's own light
	WorldState.new_game()
	WorldState.current_run = 3
	var w2 = load("res://scripts/apartment_window.gd").new()
	add_child(w2)
	w2.setup(Vector2(100, 262), true, 1)
	await get_tree().process_frame
	var base: float = w2.light.energy
	var b = w2.fx.blast(0)
	check(b != null and b.is_playing() and not b.sprite_frames.get_animation_loop("default"), "a blast plays once")
	check(b.get_tree().get_nodes_in_group("city_blast").size() >= 1, "...tagged as a blast")
	for i in range(8):
		await get_tree().process_frame
	check(w2.light.energy > base, "...and the window's light jumps (%.2f > %.2f)" % [w2.light.energy, base])
	var waited := 0.0
	while is_instance_valid(b) and waited < 2.5:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	check(not is_instance_valid(b), "...and the sprite frees itself when the animation ends")
	# lightning brightens the sky behind the glass for a beat, then it settles back
	var before: Color = w2.view.modulate
	w2.fx.lightning_flash()
	await get_tree().process_frame
	await get_tree().process_frame
	check(w2.view.modulate.r > before.r, "a lightning flash brightens the view")
	await get_tree().create_timer(0.6).timeout
	check(absf(w2.view.modulate.r - before.r) < 0.05, "...and it settles back")
	# the exterior is UNSHADED: it shows as drawn, not darkened by the night's ambient or blown out by the room's lights
	check(w2.view.material is CanvasItemMaterial and w2.view.material.light_mode == CanvasItemMaterial.LIGHT_MODE_UNSHADED, "the skyline is unshaded (light from outside, not a lit prop)")
	var unshaded_all := true
	for ch in w2.fx.get_children() + w2.city.far.get_children():
		if ch is CanvasItem and not (ch.material is CanvasItemMaterial and ch.material.light_mode == CanvasItemMaterial.LIGHT_MODE_UNSHADED):
			unshaded_all = false
	check(unshaded_all, "...and so is every fire / smoke / rain sprite over it")
	check(w2.view.modulate.is_equal_approx(Color(1, 1, 1, 1)), "at rest the view is drawn exactly as authored")
	w2.queue_free()
	await get_tree().process_frame


## Owner round 33: "as if the scene of the city remains in place, but because you're passing by the window it looks like it is moving
## in the distance as you walk by… extend the city image a little and then allow for the view to pan slightly… for balcony openings
## too." The city slides with the CAMERA (round 34: not the player), a few whole px, never past the extra it was drawn with; the rain stays on the glass.
func _test_city_parallax() -> void:
	print("[the city pans as you walk past: windows, stairwells, balconies]")
	var CV = load("res://scripts/city_view.gd")
	check(CV.offset_for(500.0, 500.0, 8.0) == 0.0, "standing square to the opening: the city is centred")
	var r: float = CV.offset_for(600.0, 500.0, 8.0)
	var l: float = CV.offset_for(400.0, 500.0, 8.0)
	check(r > 0.0 and l < 0.0 and r == -l and r == roundf(r), "the camera moves right → it drifts right, left → left, in whole px (%.0f / %.0f)" % [r, l])
	check(CV.offset_for(5000.0, 500.0, 8.0) == 8.0 and CV.offset_for(-5000.0, 500.0, 8.0) == -8.0, "never past the extra it was drawn with")
	# a live window: the view + the fires on it slide, the rain doesn't
	WorldState.new_game()
	WorldState.is_first_run = false
	WorldState.current_run = 3
	var win = load("res://scripts/apartment_window.gd").new()
	add_child(win)
	win.setup(Vector2(400, 262), true, 2)
	# The viewer is the CAMERA (owner round 34 — "the city moves when the player moves, not when the camera moves"): the
	# player walks off while the camera stays pinned, and the city must not stir; the camera moving is what slides it.
	var cam := Camera2D.new()
	add_child(cam)
	cam.make_current()
	var player := Node2D.new()
	player.add_to_group("player")
	add_child(player)
	cam.global_position = Vector2(win.global_position.x, 350)
	player.global_position = Vector2(win.global_position.x, 350)
	await get_tree().process_frame
	await get_tree().process_frame
	var centred: float = win.city.far.position.x
	player.global_position = Vector2(win.global_position.x + 300.0, 350)      # the PLAYER walks away; the camera stays fixed
	await get_tree().process_frame
	await get_tree().process_frame
	check(win.city.far.position.x == centred and centred == 0.0, "a player walking past a FIXED camera doesn't move the city (%+.0f)" % win.city.far.position.x)
	cam.global_position = Vector2(win.global_position.x + 300.0, 350)         # the CAMERA moves
	await get_tree().process_frame
	await get_tree().process_frame
	var right: float = win.city.far.position.x
	cam.global_position = Vector2(win.global_position.x - 300.0, 350)
	await get_tree().process_frame
	await get_tree().process_frame
	var left: float = win.city.far.position.x
	check(right == win.city.pan and left == -win.city.pan, "a window's city slides with the camera (%+.0f → %+.0f)" % [right, left])
	check(win.view.get_parent() == win.city.far, "...the skyline rides it")
	var fires_far := 0
	for c in win.city.far.get_children():
		if c is AnimatedSprite2D:
			fires_far += 1
	check(fires_far >= 1, "...and so do the fires / smoke on it (%d)" % fires_far)
	var rain_still := true
	for n in get_tree().get_nodes_in_group("window_rain"):
		if win.is_ancestor_of(n) and (win.city.far.is_ancestor_of(n) or n.global_position.x != win.global_position.x):
			rain_still = false
	check(rain_still, "...while the rain stays on the glass")
	win.queue_free()
	player.queue_free()
	cam.queue_free()
	await get_tree().process_frame
	# a balcony: its city is a clipped layer over the art, covering every bare-view pixel at any slide
	var apt := ""
	for f in range(5, 29):
		for col in range(1, 6):
			var a := str(f) + "0" + str(col)
			for sl in range(3):
				if apt == "" and WorldState.is_balcony_slot(a, sl):
					apt = a
	check(apt != "", "found a flat with a balcony (%s)" % apt)
	if apt == "":
		return
	for run in [1, 3]:
		WorldState.current_run = run
		WorldState.current_apartment_id = apt
		WorldState.current_floor = int(apt.substr(0, apt.length() - 2))
		WorldState.spawn_source = ""
		var room = load("res://scenes/room.tscn").instantiate()
		add_child(room)
		for i in range(3):
			await get_tree().process_frame
		var cities: Array = []
		for b in room.find_children("Balcony", "Node2D", true, false):
			if b.visible and b.get_node_or_null("City") != null:
				cities.append(b.get_node("City"))
		check(cities.size() == _balcony_count(apt), "run %d: every balcony has its panning city (%d)" % [run, cities.size()])
		for cv in cities:
			var mask: Image = cv.mask_tex.get_image() if cv.mask_tex != null else null
			var view: Sprite2D = cv.far.get_node_or_null("View")
			check(mask != null and view != null and cv.clip_children == CanvasItem.CLIP_CHILDREN_ONLY, "run %d: clipped to the bare view, the skyline in FAR" % run)
			if mask == null or view == null:
				continue
			check(str(view.texture.resource_path).ends_with("balcony_city_%d.png" % run), "run %d: the run's own city" % run)
			var used := mask.get_used_rect()
			var vx0: float = view.position.x
			var vx1: float = view.position.x + view.texture.get_width()
			check(used.size.x > 0 and used.position.x >= vx0 + cv.pan and used.end.x <= vx1 - cv.pan
				and used.position.y >= view.position.y and used.end.y <= view.position.y + view.texture.get_height(),
				"run %d: the city covers every bare-view pixel at any slide (mask x %d..%d inside %.0f..%.0f ± %.0f)" % [run, used.position.x, used.end.x, vx0, vx1, cv.pan])
			var bal_art: Node = cv.get_parent().get_node_or_null("BalconyArt")
			check(bal_art != null and cv.get_index() > bal_art.get_index(), "run %d: over the balcony art (the mask keeps the rail in front)" % run)
		room.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
