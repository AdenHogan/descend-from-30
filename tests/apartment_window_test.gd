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
	await _test_exit_through_door()
	_test_floor_boundary()
	_test_module_variants()
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
	# Rain particles hang off the windows at night.
	var rain_found := false
	for w in get_tree().get_nodes_in_group("apt_window_light"):
		var parent = w.get_parent()
		for c in parent.get_children():
			if c is CPUParticles2D:
				rain_found = true
	check(rain_found, "night windows carry rain particles")
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
					check(str(a.get_meta("kind", "")) in ["drip", "drop", "blink", "static", "spin"], "%s: %s has a known kind" % [nm, a.name])
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
