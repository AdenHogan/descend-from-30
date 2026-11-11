extends Node

# DEPTH AND LIGHT (owner round 49s: "look at shapes, depth, and most importantly, lighting... deeper lived in looking space"):
#   - the SHADE a room keeps where light does not reach (scripts/room_depth.gd): under the ceiling, in the flat's end corners, along the floor's near edge, away from its daylight -
#     and not gloom: by the window in the morning the wall is all but untouched;
#   - a planned room's CAST SHADOWS: every piece on the wall plane, every picture and everything standing on a surface throws its silhouette behind the furniture, away from the light;
#   - a baked (story / tutorial) room gets the shade and no cast shadows (its furniture is one picture);
#   - a corridor's art is shaded too (darker under the ceiling, dimmer away from the stairwell windows) and its standing props throw shadows; the TITLE hall is left as approved;
#   - a flat's WINDOW LIGHT is a wash by day and a pool round the glass at dusk and by night (FloorLighting.make_room_window_light); the stairwell's light is unchanged;
#   - every actor has a CONTACT SHADOW under its feet (scripts/ground_shadow.gd) that hides when it is not plainly standing on a floor.
# Run: godot --headless res://tests/room_depth_test.tscn

const RD := preload("res://scripts/room_depth.gd")
const FL := preload("res://scripts/floor_lighting.gd")
const GS := preload("res://scripts/ground_shadow.gd")
const ModuleGeo := preload("res://scripts/module_geo.gd")

var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== room depth test ===")
	_test_shade_numbers()
	_test_window_light()
	await _test_planned_flat()
	await _test_floor_shadows()
	await _test_baked_flat()
	await _test_corridor()
	await _test_ground_shadow()
	if failures == 0:
		print("=== ALL PASSED (0 failures) ===")
	else:
		print("=== FAILED (%d failures) ===" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _test_shade_numbers() -> void:
	print("[the shade: where it is dark, and where it is not]")
	var w: int = ModuleGeo.WIDTH
	var win := 54.0
	var mid_wall: float = RD.shade_at(120, 60, w, false, false, win, 1)
	var ceiling: float = RD.shade_at(120, 1, w, false, false, win, 1)
	check(ceiling > mid_wall + 0.2, "under the ceiling is much darker than the middle of the wall (%.2f vs %.2f)" % [ceiling, mid_wall])
	var corner: float = RD.shade_at(2, 60, w, true, false, win, 1)
	var partition: float = RD.shade_at(2, 60, w, false, false, win, 1)
	check(corner > partition + 0.1 and partition > RD.shade_at(40, 60, w, false, false, win, 1), "an end-wall corner is darker than a partition's edge, which is darker than open wall (%.2f > %.2f)" % [corner, partition])
	var near: float = RD.shade_at(int(win), 60, w, false, false, win, 1)
	var far: float = RD.shade_at(w - 20, 60, w, false, false, win, 1)
	check(far > near + 0.1, "the wall dims away from the window (%.2f by the glass, %.2f across the room)" % [near, far])
	check(near <= 0.09, "NOT gloom: by the window in the morning the wall is all but untouched (%.3f)" % near)
	check(far <= 0.34, "…and the morning's far wall is still a lit wall (%.2f)" % far)
	check(RD.shade_at(120, 143, w, false, false, win, 1) > RD.shade_at(120, 120, w, false, false, win, 1) + 0.1, "the floor's near edge falls into shadow")
	var dusk_far: float = RD.shade_at(w - 20, 60, w, false, false, win, 2)
	check(dusk_far > far, "the falling-off is stronger at dusk than in the morning (%.2f vs %.2f)" % [dusk_far, far])
	# bands, never an airbrush; never opaque
	var ok_band := true
	var top := 0.0
	for y in range(0, RD.H, 3):
		for x in range(0, w, 5):
			var a: float = RD.shade_at(x, y, w, true, true, win, 3)
			top = maxf(top, a)
			if absf(a / RD.BAND - round(a / RD.BAND)) > 0.001:
				ok_band = false
	check(ok_band and top <= 0.9 and top > 0.4, "the shade is cut into bands and never goes opaque (darkest %.2f)" % top)
	check(RD.seam_at(RD.SEAM_ROW) > RD.seam_at(RD.SEAM_ROW + 9) and RD.seam_at(RD.SEAM_ROW - 2) > RD.seam_at(RD.SEAM_ROW - 13) and RD.seam_at(40) == 0.0,
		"the seam: darkest where the wall meets the floor, nothing up the wall")
	# a corridor: ends by the windows brighter than the middle, the ceiling dark
	check(RD.hall_col_dark(560, ["left", "right"], 1) > RD.hall_col_dark(80, ["left", "right"], 1) + 0.08, "a corridor is dimmer in its middle than by a stairwell window")
	check(RD.hall_col_dark(1000, ["left"], 1) > RD.hall_col_dark(300, ["left"], 1) and RD.hall_col_dark(1000, ["left"], 1) > RD.hall_col_dark(1000, ["left", "right"], 1), "…a floor with ONE stairwell (30, the lobby) is dim at its blind end, where a floor with two has a window")
	check(RD.hall_col_dark(560, [], 1) == 0.0, "…and one with none is even along its length")
	check(RD.hall_row_dark(1) > RD.hall_row_dark(90) + 0.2 and RD.hall_row_dark(191) > RD.hall_row_dark(175), "a corridor is dark under its ceiling and at the floor's near edge")


func _test_window_light() -> void:
	print("[a flat's window light: a wash by day, a pool at dusk and by night]")
	var keep: int = WorldState.current_run
	var reach: Array = []
	var energy: Array = []
	var stair: Array = []
	for run in [1, 2, 3]:
		WorldState.current_run = run
		var lt: PointLight2D = FL.make_room_window_light(Vector2.ZERO, 1.3)
		var st: PointLight2D = FL.make_window_light(Vector2.ZERO, 1.0)
		reach.append(lt.texture_scale)
		energy.append(lt.energy)
		stair.append([st.texture_scale, st.energy])
		lt.free()
		st.free()
	WorldState.current_run = keep
	check(is_equal_approx(reach[0], FL.WINDOW_SCALE) and is_equal_approx(energy[0], FL.WINDOW_ENERGY[0] * 1.3), "the morning is unchanged: the same wide wash at the same strength (x%.2f, %.3f)" % [reach[0], energy[0]])
	check(reach[1] < reach[0] * 0.75 and reach[2] < reach[1], "the light draws in round the glass at dusk and further by night (x%.2f, x%.2f, x%.2f)" % [reach[0], reach[1], reach[2]])
	check(energy[1] > FL.WINDOW_ENERGY[1] * 1.3 and energy[2] > FL.WINDOW_ENERGY[2] * 1.3, "…and is brighter where it does fall")
	check(is_equal_approx(stair[1][0], FL.WINDOW_SCALE) and is_equal_approx(stair[2][1], FL.WINDOW_ENERGY[2]), "the stairwell's window light is what it was (the corridor already had its pools)")


func _flat(apt: String, run: int, first_run: bool) -> Node:
	WorldState.new_game()
	WorldState.master_seed = 4242
	WorldState.is_first_run = first_run
	WorldState.current_run = run
	WorldState.current_apartment_id = apt
	WorldState.current_floor = int(apt.substr(0, 2))
	WorldState.spawn_source = ""
	WorldState.god_mode = true
	var room = load("res://scenes/room.tscn").instantiate()
	add_child(room)
	for i in range(12):
		await get_tree().physics_frame
	for z in get_tree().get_nodes_in_group("zombie"):
		if room.is_ancestor_of(z):
			z.free()
	return room


func _modules(room: Node) -> Array:
	var out: Array = []
	for m in get_tree().get_nodes_in_group("room_module"):
		if room.is_ancestor_of(m):
			out.append(m)
	return out


func _test_planned_flat() -> void:
	print("[a planned flat: the shade, the seam, and every piece's shadow behind the furniture]")
	# an ordinary three-room flat on a fire-free floor that is not a story room
	var apt := ""
	WorldState.new_game()
	WorldState.master_seed = 4242
	WorldState.is_first_run = false
	WorldState.current_run = 1
	for cand in ["2203", "2202", "2204", "2103", "2102", "2003"]:
		var fl := int(cand.substr(0, 2))
		WorldState.seed_floor_door_states(fl)
		if WorldState.apartment_span(cand) == 3 and WorldState.get_door_state(cand) != WorldState.DoorState.BREACHED \
				and not WorldState.is_apartment_charred(fl, int(cand.substr(2, 2))) and WorldState.apartment_corpse(cand).is_empty():
			apt = cand
			break
	check(apt != "", "(setup) an ordinary three-room flat (%s)" % apt)
	if apt == "":
		return
	for run in [1, 2]:
		var room = await _flat(apt, run, false)
		var mods := _modules(room)
		check(mods.size() == 3, "run %d: three rooms built (%d)" % [run, mods.size()])
		var shadows := 0
		var planned := 0
		var all_ok := true
		var why := ""
		var i := 0
		for m in mods:
			var shade: Sprite2D = m.get_node_or_null("DepthShade") as Sprite2D
			if shade == null:
				all_ok = false
				why = "no DepthShade in room %d" % i
				i += 1
				continue
			var mat: CanvasItemMaterial = shade.material as CanvasItemMaterial
			if mat == null or mat.light_mode != CanvasItemMaterial.LIGHT_MODE_UNSHADED:
				all_ok = false
				why = "the shade is lit"
			if shade.texture.get_width() != ModuleGeo.WIDTH or shade.texture.get_height() != RD.H:
				all_ok = false
				why = "the shade is not the room's size"
			# draw order: the seam and every cast shadow BEFORE the first piece of furniture; the shade AFTER the last one and before the scavenge nodes
			var first_furn := -1
			var last_furn := -1
			var last_cast := -1
			var first_anchor := -1
			var k := 0
			for c in m.get_children():
				if c.has_meta("furniture"):
					if first_furn < 0:
						first_furn = k
					last_furn = k
				if c.has_meta("cast_shadow"):
					last_cast = k
					shadows += 1
					var cs: Sprite2D = c as Sprite2D
					if cs.modulate.r > 0.001 or cs.modulate.a < 0.05 or cs.modulate.a > 0.6:
						all_ok = false
						why = "a cast shadow is not a faint black"
				if c is Marker2D and first_anchor < 0:
					first_anchor = k
				k += 1
			if first_furn >= 0:
				planned += 1
				var seam: Node = m.get_node_or_null("DepthSeam")
				if seam == null or seam.get_index() > first_furn:
					all_ok = false
					why = "the seam is not under the furniture (room %d)" % i
				if last_cast > first_furn:
					all_ok = false
					why = "a cast shadow is drawn over a piece of furniture (room %d)" % i
				if shade.get_index() < last_furn:
					all_ok = false
					why = "the shade is under the furniture (room %d)" % i
			if first_anchor >= 0 and shade.get_index() > first_anchor:
				all_ok = false
				why = "the shade is over the scavenge nodes (room %d)" % i
			i += 1
		check(all_ok, "run %d: every room is shaded, unlit, the right size, in the right order%s" % [run, "" if all_ok else " - " + why])
		check(planned >= 1 and shadows >= planned * 4, "run %d: the planned rooms' pieces throw shadows (%d shadows in %d planned rooms)" % [run, shadows, planned])
		# the shadows fall AWAY from the room's light: a piece left of it is thrown left, right of it right
		var dir_ok := true
		var seen := 0
		for m in mods:
			var by_name := {}
			for c in m.get_children():
				if c.has_meta("furniture"):
					by_name[String(c.name)] = c
			var lx := -1.0
			var shade2: Node = m.get_node_or_null("DepthShade")
			if shade2 == null or by_name.is_empty():
				continue
			# the room's light this run is what add_to used: read it back from a fresh call's own helper
			var lamps = room.get_node_or_null("Lamps%d" % mods.find(m))
			var day_x: float = _day_x(room, m, mods.find(m), apt)
			lx = RD.light_x_for(m, lamps, day_x, run, ModuleGeo.WIDTH)
			for c in m.get_children():
				if not c.has_meta("cast_shadow"):
					continue
				var nm := String(c.name)
				var src_name := nm.substr(5, nm.rfind("_") - 5)
				if not by_name.has(src_name):
					continue
				var src: Sprite2D = by_name[src_name] as Sprite2D
				var cx: float = src.position.x + src.texture.get_width() * 0.5
				var dx: float = (c as Sprite2D).position.x - src.position.x
				seen += 1
				if (cx > lx + 30.0 and dx < 0.0) or (cx < lx - 30.0 and dx > 0.0):
					dir_ok = false
		check(dir_ok and seen > 0, "run %d: every shadow falls away from the room's light, never toward it (%d checked)" % [run, seen])
		room.free()
		await get_tree().process_frame


## STANDING furniture lays its shadow on the FLOOR (owner round 49t: "so that the furniture does have its weight from shadow, lighting, that depth").
func _test_floor_shadows() -> void:
	print("[standing furniture throws its shadow on the floor]")
	var total := 0
	var standing := 0
	var ok := true
	var why := ""
	var thrown := 0
	var dir_ok := true
	var apt := ""
	for run in [1, 2]:
		var room = null
		for cand in ["2204", "2201", "1703", "1402", "2503", "2001"]:
			room = await _flat(cand, run, false)
			apt = cand
			var any_planned := false
			for m in _modules(room):
				for c in m.get_children():
					if c.has_meta("furniture"):
						any_planned = true
			if any_planned:
				break
			room.free()
			await get_tree().process_frame
			room = null
		if room == null:
			check(false, "(setup) a planned flat for run %d" % run)
			continue
		var mods := _modules(room)
		for m in mods:
			var by_name := {}
			var first_standing := -1
			var last_rug := -1
			var k := 0
			for c in m.get_children():
				if c.has_meta("furniture"):
					by_name[String(c.name)] = c
					var plane := String(c.get_meta("plane", ""))
					if plane == "rug":
						last_rug = k
					elif first_standing < 0:
						first_standing = k
					if plane in ["front", "floor", "wall"]:
						standing += 1
				k += 1
			if by_name.is_empty():
				continue
			var lamps = room.get_node_or_null("Lamps%d" % mods.find(m))
			var lx: float = RD.light_x_for(m, lamps, _day_x(room, m, mods.find(m), apt), run, ModuleGeo.WIDTH)
			for c in m.get_children():
				if not c.has_meta("floor_shadow"):
					continue
				total += 1
				var fs := c as Sprite2D
				var src: Sprite2D = by_name.get(String(fs.name).substr(6), null) as Sprite2D
				if src == null:
					ok = false
					why = "a floor shadow with no piece (%s)" % fs.name
					continue
				if fs.modulate.r > 0.001 or fs.modulate.a < 0.05 or fs.modulate.a > 0.5 or not (fs.material is CanvasItemMaterial) \
						or (fs.material as CanvasItemMaterial).light_mode != CanvasItemMaterial.LIGHT_MODE_UNSHADED:
					ok = false
					why = "a floor shadow is not a faint unlit black"
				if fs.get_index() > first_standing or (last_rug >= 0 and fs.get_index() < last_rug):
					ok = false
					why = "a floor shadow is not over the rugs and under what stands (%s)" % fs.name
				var h: float = float(src.texture.get_height())
				var w: float = float(src.texture.get_width())
				var foot: float = src.position.y + h
				# where the piece's foot row and its top row land
				var at_foot: Vector2 = fs.transform * Vector2(w * 0.5, h)
				var at_top: Vector2 = fs.transform * Vector2(w * 0.5, 0.0)
				var length: float = at_top.y - at_foot.y
				if absf(at_foot.y - foot) > 0.01 or absf(at_foot.x - (src.position.x + w * 0.5)) > 0.01:
					ok = false
					why = "a shadow does not start at its piece's foot (%s)" % fs.name
				if length < RD.FLOOR_MIN_LEN - 0.01 or length > RD.FLOOR_MAX_LEN + 0.01:
					ok = false
					why = "a shadow is %.1f rows long (%s)" % [length, fs.name]
				var throw: float = at_top.x - at_foot.x
				var cx: float = src.position.x + w * 0.5
				if absf(throw) >= 1.0:
					thrown += 1
				if (cx > lx + 30.0 and throw < 0.0) or (cx < lx - 30.0 and throw > 0.0):
					dir_ok = false
		room.free()
		await get_tree().process_frame
	check(total > 0 and total == standing, "every piece that stands (front / floor / against the wall) lays a shadow on the floor: %d shadows for %d pieces" % [total, standing])
	check(ok, "each starts at its piece's foot, runs %d..%d rows down the floor, a faint unlit black, over the rugs and under the furniture%s" % [int(RD.FLOOR_MIN_LEN), int(RD.FLOOR_MAX_LEN), "" if ok else " - " + why])
	check(dir_ok and thrown > 0, "they lean away from the room's light, never toward it (%d leaning)" % thrown)
	check(float(RD.FLOOR_LEN_BY_RUN[1]) > float(RD.FLOOR_LEN_BY_RUN[0]), "the afternoon's low sun throws them further")


func _day_x(room: Node, m: Node, slot: int, apt: String) -> float:
	if m.get_node_or_null("Balcony") != null and WorldState.is_balcony_slot(apt, slot):
		return 50.0
	for c in m.get_children():
		if c.get_script() != null and String(c.get_script().resource_path).ends_with("apartment_window.gd"):
			return (c as Node2D).position.x
	return ModuleGeo.WIDTH * 0.5


func _test_baked_flat() -> void:
	print("[a baked room (the tutorial's flats): shaded, no cast shadows, no seam]")
	var room = await _flat("3003", 1, true)
	var mods := _modules(room)
	var shaded := 0
	var extra := 0
	for m in mods:
		if m.get_node_or_null("DepthShade") != null:
			shaded += 1
		if m.get_node_or_null("DepthSeam") != null:
			extra += 1
		for c in m.get_children():
			if c.has_meta("cast_shadow"):
				extra += 1
	check(mods.size() >= 2 and shaded == mods.size(), "every room of the tutorial flat is shaded (%d of %d)" % [shaded, mods.size()])
	check(extra == 0, "…and has no seam or cast shadows: its furniture is one picture (%d)" % extra)
	# end walls: the first room's left edge and the last room's right edge are the flat's corners
	var first: Node = null
	var last: Node = null
	for m in mods:
		if first == null or m.position.x < first.position.x:
			first = m
		if last == null or m.position.x > last.position.x:
			last = m
	var fimg: Image = (first.get_node("DepthShade") as Sprite2D).texture.get_image()
	var limg: Image = (last.get_node("DepthShade") as Sprite2D).texture.get_image()
	check(fimg.get_pixel(1, 70).a > fimg.get_pixel(ModuleGeo.WIDTH - 2, 70).a + 0.05 or first == last, "the flat's LEFT corner is darker than the first room's partition side")
	check(limg.get_pixel(ModuleGeo.WIDTH - 2, 70).a > 0.2, "the flat's RIGHT corner is dark (%.2f)" % limg.get_pixel(ModuleGeo.WIDTH - 2, 70).a)
	RD.add_to(first, {"width": ModuleGeo.WIDTH, "run": 1})
	var n := 0
	for c in first.get_children():
		if String(c.name).begins_with("DepthShade"):
			n += 1
	check(n == 1, "asking twice shades once")
	room.free()
	await get_tree().process_frame


func _test_corridor() -> void:
	print("[a corridor: its art shaded, its standing props' shadows; the title hall untouched]")
	WorldState.new_game()
	WorldState.master_seed = 12345
	WorldState.is_first_run = false
	WorldState.tutorial_completed = true
	WorldState.god_mode = true
	WorldState.current_run = 2
	WorldState.current_floor = 22
	WorldState.seed_floor_door_states(22)
	var bf = load("res://scenes/building_floors.tscn").instantiate()
	add_child(bf)
	for i in range(6):
		await get_tree().physics_frame
	var art: Node = bf.get_node_or_null("CorridorArt")
	check(art != null and art.get_node_or_null("DepthRows") != null and art.get_node_or_null("DepthCols") != null, "the corridor's art carries its two shade profiles")
	if art != null and art.get_node_or_null("DepthRows") != null:
		var rows := art.get_node("DepthRows") as Sprite2D
		var cols := art.get_node("DepthCols") as Sprite2D
		check(is_equal_approx(rows.scale.x, 1120.0) and rows.texture.get_height() == 192 and is_equal_approx(cols.scale.y, 192.0) and cols.texture.get_width() == 1120, "…stretched over the whole 1120 x 192 art")
		check((rows.material as CanvasItemMaterial).light_mode == CanvasItemMaterial.LIGHT_MODE_UNSHADED, "…unlit (a lamp never brightens a shadow)")
	var decals: Node = bf.get_node_or_null("CorridorDecals")
	var casts := 0
	var standing := 0
	var order_ok := true
	if decals != null:
		var kids: Array = decals.get_children()
		for k in range(kids.size()):
			var c = kids[k]
			if c.has_meta("cast_shadow"):
				casts += 1
			elif c is Sprite2D and c.has_meta("decal") and c.texture != null and c.position.y < 160.0 and c.position.y + c.texture.get_height() > 160.0 and not c.is_in_group("corridor_dead"):
				standing += 1
				# its shadows are the two children just before it
				if k < 2 or not kids[k - 1].has_meta("cast_shadow") or not kids[k - 2].has_meta("cast_shadow"):
					order_ok = false
	check(standing > 0 and casts == standing * 2 and order_ok, "every standing prop has its two shadows, drawn just under it (%d props, %d shadows)" % [standing, casts])
	bf.free()
	await get_tree().process_frame
	# the title's hall keeps the look the owner approved: no shade, no cast shadows
	var title = load("res://scenes/title_screen.tscn").instantiate()
	add_child(title)
	for i in range(4):
		await get_tree().process_frame
	var hall: Node = title.get_node_or_null("Hall")
	var tart: Node = hall.get_node_or_null("CorridorArt") if hall != null else null
	var tcasts := 0
	if hall != null and hall.get_node_or_null("CorridorDecals") != null:
		for c in hall.get_node("CorridorDecals").get_children():
			if c.has_meta("cast_shadow"):
				tcasts += 1
	check(tart != null and tart.get_node_or_null("DepthRows") == null and tcasts == 0, "the title hall is not shaded and its props cast nothing (the approved look)")
	title.free()
	await get_tree().process_frame


func _test_ground_shadow() -> void:
	print("[the contact shadow under every actor]")
	WorldState.new_game()
	WorldState.is_first_run = false
	WorldState.tutorial_completed = true
	WorldState.god_mode = true
	WorldState.current_run = 1
	WorldState.current_floor = 12
	WorldState.seed_floor_door_states(12)
	var bf = load("res://scenes/building_floors.tscn").instantiate()
	add_child(bf)
	await get_tree().physics_frame
	for z in get_tree().get_nodes_in_group("zombie"):
		if bf.is_ancestor_of(z):
			z.free()
	var p = bf.get_node("Player")
	var sh: Sprite2D = p.get_node_or_null("GroundShadow") as Sprite2D
	check(sh != null and sh.get_index() < p.get_node("AnimatedSprite2D").get_index(), "the player has one, drawn before their own sprite")
	if sh != null:
		await get_tree().process_frame
		check(sh.visible and is_equal_approx(sh.global_position.y, p.feet_position().y - 1.0), "…lying on the row their feet are drawn on (%.1f, feet %.1f)" % [sh.global_position.y, p.feet_position().y])
		check(sh.texture.get_height() == GS.HEIGHT and sh.texture.get_width() >= GS.MIN_W, "…a low wide ellipse (%d x %d)" % [sh.texture.get_width(), sh.texture.get_height()])
		var img: Image = sh.texture.get_image()
		var mid: Color = img.get_pixel(int(img.get_width() / 2.0), int(GS.HEIGHT / 2.0))
		check(mid.r < 0.01 and absf(mid.a - GS.CORE) < 0.01 and img.get_pixel(0, 0).a == 0.0, "…black, darkest in the middle, nothing at its corners")
		p.is_dead = true
		sh.refresh()
		check(not sh.visible, "a dead player casts none")
		p.is_dead = false
		p.is_lashing = true
		sh.refresh()
		check(not sh.visible, "…nor one on a rope")
		p.is_lashing = false
		sh.refresh()
		check(sh.visible, "…and it is back when they stand again")
		check(GS.attach(p, p.get_node("AnimatedSprite2D")) == sh, "asking twice gives the one shadow")
	for scene in ["res://scenes/enemy_zombie_standard.tscn", "res://scenes/enemy_zombie_big.tscn", "res://scenes/enemy_zombie_crawler.tscn"]:
		var z = load(scene).instantiate()
		z.global_position = Vector2(700, 370 if scene.ends_with("standard.tscn") else 374)
		bf.add_child(z)
		await get_tree().physics_frame
		z.set_physics_process(false)
		var zs: Sprite2D = z.get_node_or_null("GroundShadow") as Sprite2D
		var nm: String = scene.get_file().get_basename()
		check(zs != null and zs.visible, "%s has a contact shadow" % nm)
		if zs != null:
			check(zs.texture.get_width() >= int(GS.body_width(z)), "…at least as wide as its body (%d, body %.0f)" % [zs.texture.get_width(), GS.body_width(z)])
			z.state = "dead"
			zs.refresh()
			check(not zs.visible, "…gone once it is dead")
			z.state = "idle"
			if "stair_mode" in z:                  # (the standard family: the big one never stands on the stairs)
				z.stair_mode = true
				zs.refresh()
				check(not zs.visible, "…and none while it stands on a staircase")
				z.stair_mode = false
		z.free()
	bf.free()
	await get_tree().process_frame
