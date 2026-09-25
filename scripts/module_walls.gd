extends Node2D

# MODULE WALLS — the apartment reads as the inside of a cube (owner round 9: "the module is a
# clear hard location… build a boundary wall… so when you move through the door frame to the next
# module it still looks geometrically accurate rather than inverted").
#
# Every module boundary is a wall running from the BACK wall toward the viewer, drawn LIVE in
# perspective from the camera: the face you see is always the one turned toward the camera, so it
# flips naturally as you walk through the doorway into the next room — never a painted,
# one-sided (and therefore half-the-time inverted) wall. Purely visual: no collision.
#
#   * Interior boundaries: a partition with a DOORWAY near the front, over the walking lane (the
#     player walks through it), a wooden jamb + lintel trim, the lintel above the opening.
#   * The two end walls: solid; the ENTRANCE end gets the same doorway (dark — the corridor beyond).
#   * Each face wears ITS OWN room's wall: every back-plane row samples that module's art at its
#     edge column (wallpaper, chair rail, panelling, skirting line up exactly), a touch darker as a
#     turned surface (ambient form only — the engine lights it). Placeholder modules use their flat
#     colour. Works for every module and every future variant with no per-art wiring.
#   * A dark CUT at the wall's front edge (a dollhouse section) keeps it reading as a solid slab
#     even when you look straight along it.
# Positions are the room's LOCAL space (a BalconyPan backdrop sits a floor down; live, local==world).

const TOP := 224.0          # module top (back-plane row 0) — room.gd places modules at y 224
const SEAM := 324.0         # where the back wall meets the floor (module-local 100)
const ROWS := 100           # back-plane rows from TOP to SEAM
const VY := 224.0           # the horizon (eye height) = the CEILING line (owner round 9: the old 190
                            # tipped every wall top down into a heavy slab wedge — "ceilings too low").
                            # Wall tops stay level on the ceiling; only the floor recedes.
const FRONT_FLOOR := 360.0  # the near cut plane's floor line (just in front of the feet line 353)
const DOOR_FLOOR := 338.0   # the doorway starts this deep (floor y) — the lane runs through it
const DOOR_ROWS := 18       # the lintel: back-plane rows 0..17 are wall above the doorway — high enough
                            # that the tallest enemy (spitter, drawn top 257) walks under it at the lane
const ENTRANCE_FRONT := 356.0  # the FRONT door's near jamb (floor y): wall stands between it and
                               # the front cut, so it reads as a door IN the wall
const MOD_ROWS := 144       # the module's full height (wall + floor) — the floor rows are sampled too
const BAND_BOTTOM := 375.0  # room.ROOM_BAND_TOP + 160: never draw into the flat below (a balcony pan stacks them)
const HALF_T := 2.0         # half the wall's thickness (back-plane px)
const FACE_SHADE := 0.82    # a turned surface reads a little darker (ambient only)
const CUT_COL := Color(0.24, 0.18, 0.13)   # the cut section: warm plaster-brown, not a black bar
const TRIM_COL := Color(0.30, 0.21, 0.14)
const TRIM_LT := Color(0.40, 0.29, 0.19)
const SADDLE_COL := Color(0.47, 0.34, 0.21)     # a doorway's wooden threshold strip (_threshold)
const SADDLE_LT := Color(0.62, 0.47, 0.30)
const SADDLE_DK := Color(0.24, 0.16, 0.10)
const SADDLE_GRAIN := Color(0.40, 0.28, 0.17)
const OUTSIDE_COL := Color(0.05, 0.045, 0.05)
const CORRIDOR_FLOOR := Color(0.16, 0.12, 0.09)   # a glimpse of the corridor floor through the door
const THRESHOLD := Color(0.46, 0.36, 0.24)

const MODULE_W := 320.0      # a module's width (room.MODULE_WIDTH)
const FLOOR_EXT_M := 96.0    # how far past each edge a module's <name>_floor_ext.png runs (tools/art pixlib)
var boundaries: Array = []     # [{x, left_mod, right_mod, door, outside}]
var _exts: Dictionary = {}     # module instance id + texture path → its perspective floor export
var _kx := 0.0                 # a horizontal shift every projected point takes (_pivot_kx)
var _cols: Dictionary = {}     # module instance id + side → Array[Color] (ROWS rows)


func setup(module_nodes: Array, left_x: float, width: float, entrance_side: String) -> void:
	# module_nodes = the room's three modules in order (left → right).
	boundaries.clear()
	var n := module_nodes.size()
	for i in range(n + 1):
		var x := left_x + width * float(i)
		var lm = module_nodes[i - 1] if i > 0 else null
		var rm = module_nodes[i] if i < n else null
		var is_end := lm == null or rm == null
		var entrance := is_end and ((i == 0 and entrance_side == "left") or (i == n and entrance_side != "left"))
		boundaries.append({"x": x, "left": lm, "right": rm, "door": (not is_end) or entrance, "outside": entrance})
	z_index = 0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _column(mod: Node, right_edge: bool) -> Array:
	# The module's wall, one colour per back-plane row, sampled a few px in from the given edge.
	var key := str(mod.get_instance_id()) + (":r" if right_edge else ":l")
	if _cols.has(key):
		return _cols[key]
	var out: Array = []
	var art = mod.get_node_or_null("Art")
	var img: Image = null
	if art is Sprite2D and art.texture != null:
		img = art.texture.get_image()
	var flat := Color(0.4, 0.4, 0.4)
	var rect = mod.get_node_or_null("ColorRect")
	if rect is ColorRect:
		flat = rect.color
	for r in range(MOD_ROWS):
		if img != null:
			var sx: int = img.get_width() - 4 if right_edge else 3
			out.append(img.get_pixel(sx, clampi(r, 0, img.get_height() - 1)))
		else:
			out.append(flat)
	_cols[key] = out
	return out


# How far the camera may sit from an INTERIOR wall, for drawing it (owner round 14 — "depending on
# where you stand, it makes the floor look like it's growing or shrinking as you move towards another
# room"): the rooms' art is flat, so a wall in full live perspective swept its face ~100px across a
# floor that doesn't move with it. Clamped, a wall shows a small face while you're anywhere in a room
# and only turns as you pass through its doorway. End walls (the front door) keep the real camera —
# the walk-out follows them.
const PARALLAX_MAX := 40.0


static func _eff_cam(cx: float, xb: float) -> float:
	return xb + clampf(cx - xb, -PARALLAX_MAX, PARALLAX_MAX)


static func _pivot_kx(cx: float, xb: float) -> float:
	# The shift that pins an interior wall's doorway JAMB (x = xb at the doorway's depth) in place: the
	# wall then turns about the jamb, which stands on the fixed floor join between the two rooms.
	return (xb - cx) * (1.0 - _s_for_floor(DOOR_FLOOR))


func _cam_x() -> float:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return 0.0
	return to_local(cam.get_screen_center_position()).x


# A back-plane point (x, y) pushed out to depth scale s (1 = on the back wall), perspective about
# the vanishing point (camera x, horizon VY).
func _p(cx: float, x: float, y: float, s: float) -> Vector2:
	return Vector2(cx + (x - cx) * s + _kx, VY + (y - VY) * s)


static func _s_for_floor(floor_y: float) -> float:
	return (floor_y - VY) / (SEAM - VY)


func _face(cx: float, x: float, s0: float, s1: float, r0: int, r1: int, cols: Array, shade: float) -> void:
	for r in range(r0, r1):
		var y0 := TOP + float(r)
		var col: Color = cols[r] if cols.size() > r else Color(0.4, 0.4, 0.4)
		col = Color(col.r * shade, col.g * shade, col.b * shade, 1.0)
		draw_colored_polygon(PackedVector2Array([_p(cx, x, y0, s0), _p(cx, x, y0, s1),
			_p(cx, x, y0 + 1.0, s1), _p(cx, x, y0 + 1.0, s0)]), col)


func _slab(cx: float, x: float, s: float, r0: int, r1: int, col: Color) -> void:
	# The wall's thickness seen end-on at depth s (its cut section / jamb).
	draw_colored_polygon(PackedVector2Array([_p(cx, x - HALF_T, TOP + r0, s), _p(cx, x + HALF_T, TOP + r0, s),
		_p(cx, x + HALF_T, TOP + r1, s), _p(cx, x - HALF_T, TOP + r1, s)]), col)


# Which room's face of boundary `b` points at a camera at local x `cam_x`: camera LEFT of the wall →
# the wall's left face = the right wall of the LEFT room (and vice versa). Never the far side.
func facing_room(b: Dictionary, cam_x: float):
	return b["left"] if cam_x < float(b["x"]) else b["right"]


func _draw() -> void:
	var cam := _cam_x()
	var s_front := _s_for_floor(FRONT_FLOOR)
	var s_door := _s_for_floor(DOOR_FLOOR)
	# FLOORS first. Between two rooms the join is FIXED (owner round 14 — "depending on where you move
	# to the corpse's head is either in one room or the other. The head didn't move, the perspective of
	# the floor moved"): the rooms' floors are painted art that never moves, so their join must not
	# either — each floor runs to its own module edge and a wooden saddle covers the line. Only at the
	# two END walls (no room beyond) does the facing room's floor run on to the wall's live base line.
	for b in boundaries:
		var xb: float = b["x"]
		if b["left"] == null or b["right"] == null:
			var room_f = facing_room(b, cam)
			if room_f != null:
				_floor_wedge(cam, xb, room_f, cam < xb)
		elif b["door"]:
			_threshold(xb)
	for b in boundaries:
		var xb: float = b["x"]
		# An INTERIOR wall is drawn from a clamped camera (_eff_cam) and turns about its DOORWAY JAMB
		# (_pivot_kx): the jamb stands on the fixed floor join whatever the camera does; the stub behind
		# it and the lintel over the opening swing. The END walls keep the real camera (room.gd stops
		# the player at their drawn foot, and the walk-out goes through the front door's face).
		var interior: bool = b["left"] != null and b["right"] != null
		var cx: float = _eff_cam(cam, xb) if interior else cam
		_kx = _pivot_kx(cx, xb) if interior else 0.0
		# Which face points at the camera: camera LEFT of the wall → the wall's left face, i.e. the
		# right wall of the LEFT room (and vice versa). Straight on → nothing but the cut shows.
		var cam_left: bool = cx < xb
		var room = facing_room(b, cx)
		var face_x: float = xb - HALF_T if cam_left else xb + HALF_T
		if room == null:
			continue      # looking at an end wall from outside the room — never happens in play
		var cols: Array = _column(room, cam_left)
		if b["outside"]:
			_front_door(cx, xb, face_x, cols, s_door, s_front)
		elif b["door"]:
			_face(cx, face_x, 1.0, s_door, 0, ROWS, cols, FACE_SHADE)          # the stub to the back wall
			_face(cx, face_x, s_door, s_front, 0, DOOR_ROWS, cols, FACE_SHADE) # the lintel
			# jamb (the stub's front edge) + lintel trim + the lintel's front cut
			_slab(cx, xb, s_door, DOOR_ROWS, ROWS, TRIM_COL)
			draw_line(_p(cx, face_x, TOP + DOOR_ROWS, s_door), _p(cx, face_x, SEAM, s_door), TRIM_LT, 1.0)
			draw_line(_p(cx, face_x, TOP + DOOR_ROWS, s_door), _p(cx, face_x, TOP + DOOR_ROWS, s_front), TRIM_COL, 2.0)
			_slab(cx, xb, s_front, 0, DOOR_ROWS, CUT_COL)
		else:
			_face(cx, face_x, 1.0, s_front, 0, ROWS, cols, FACE_SHADE)
			_slab(cx, xb, s_front, 0, ROWS, CUT_COL)
		# the corner where the wall meets the back wall
		draw_line(_p(cx, face_x, TOP, 1.0), _p(cx, face_x, SEAM, 1.0), Color(0, 0, 0, 0.25), 1.0)
	_kx = 0.0


func _floor_wedge(cx: float, xb: float, room: Node, room_is_left: bool) -> void:
	# An END wall: the triangle between the module edge (x = xb) and the wall's base line
	# x_w(y) = cx + (xb−cx)·s(y) — zero at the seam, widest at the front — is still the room's floor.
	# Painted from the module's perspective floor export, which runs FLOOR_EXT_M px past each edge.
	var ext: Texture2D = _floor_ext(room)
	var bot := minf(TOP + float(MOD_ROWS), BAND_BOTTOM)
	var over := clampf((xb - cx) * (_s_for_floor(bot) - 1.0), -FLOOR_EXT_M, FLOOR_EXT_M)
	var ew := float(ext.get_width())
	var vb := (bot - SEAM) / float(MOD_ROWS - ROWS)
	var u0 := (FLOOR_EXT_M + (MODULE_W if room_is_left else 0.0)) / ew
	draw_polygon(PackedVector2Array([Vector2(xb, SEAM), Vector2(xb, bot), Vector2(xb + over, bot)]),
		PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE]),
		PackedVector2Array([Vector2(u0, 0.0), Vector2(u0, vb), Vector2(u0 + over / ew, vb)]), ext)


func _threshold(xb: float) -> void:
	# A doorway's SADDLE (owner round 14): a wooden strip the wall's width over the FIXED join between
	# the two rooms' floors, from the jamb at the back of the opening to the floor's front edge. It is
	# laid in the floor's own perspective and never moves with the camera — so whatever lies on the
	# floor stays in the room it's in. A lit edge on the left, a shadowed edge on the right, a grain
	# line down it.
	var y0 := DOOR_FLOOR
	var y1 := minf(TOP + float(MOD_ROWS), BAND_BOTTOM)
	var s0 := _s_for_floor(y0)
	var s1 := _s_for_floor(y1)
	var hw := HALF_T + 1.0
	var q := PackedVector2Array([Vector2(xb - hw * s0, y0), Vector2(xb + hw * s0, y0),
		Vector2(xb + hw * s1, y1), Vector2(xb - hw * s1, y1)])
	draw_colored_polygon(q, SADDLE_COL)
	draw_line(q[0], q[3], SADDLE_LT, 1.0)
	draw_line(q[1], q[2], SADDLE_DK, 1.0)
	draw_line((q[0] + q[1]) * 0.5, (q[2] + q[3]) * 0.5, SADDLE_GRAIN, 1.0)
	draw_line(q[0], q[1], SADDLE_DK, 1.0)                         # its back end, against the jamb


func floor_boundary_x(b: Dictionary, cam_x: float, floor_y: float) -> float:
	# Where the floor on one side of boundary `b` meets the other at a floor depth — for tests/tools.
	# Between two rooms: the module edge, whatever the camera. At an end wall: the wall's base line.
	var xb: float = b["x"]
	if b["left"] != null and b["right"] != null:
		return xb
	return cam_x + (xb - cam_x) * _s_for_floor(floor_y)


func jamb_x(xb: float, cam_x: float) -> float:
	# Where an interior doorway's jamb stands on the floor (its centre, at the doorway's depth).
	var cx := _eff_cam(cam_x, xb)
	return cx + (xb - cx) * _s_for_floor(DOOR_FLOOR) + _pivot_kx(cx, xb)


func _floor_ext(mod: Node) -> Texture2D:
	# The module's perspective floor, FLOOR_EXT_M px past each edge (tools/art: <name>_floor_ext.png —
	# floor only, so nothing standing near the edge is carried on). Each run texture has its own.
	var art = mod.get_node_or_null("Art")
	var path := ""
	if art is Sprite2D and art.texture != null and art.texture.resource_path != "":
		path = art.texture.resource_path.get_basename() + "_floor_ext.png"
	var key := str(mod.get_instance_id()) + ":" + path
	if _exts.has(key):
		return _exts[key]
	var tex: Texture2D = null
	if path != "" and ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	if tex == null:
		# a placeholder module: its flat colour
		var img := Image.create(int(MODULE_W + 2.0 * FLOOR_EXT_M), MOD_ROWS - ROWS, false, Image.FORMAT_RGBA8)
		var flat := Color(0.4, 0.4, 0.4)
		var rect = mod.get_node_or_null("ColorRect")
		if rect is ColorRect:
			flat = rect.color
		img.fill(flat)
		tex = ImageTexture.create_from_image(img)
	_exts[key] = tex
	return tex


func _front_door(cx: float, xb: float, face_x: float, cols: Array, s_door: float, s_front: float) -> void:
	# The flat's FRONT DOOR in the entrance end wall: a real opening with wall on both sides (the
	# stub to the back wall, a jamb between it and the front cut), an architrave round it, a
	# threshold, and the dark corridor beyond with a sliver of its floor.
	var s_ent := _s_for_floor(ENTRANCE_FRONT)
	_face(cx, face_x, 1.0, s_door, 0, ROWS, cols, FACE_SHADE)          # back stub
	_face(cx, face_x, s_door, s_ent, 0, DOOR_ROWS, cols, FACE_SHADE)   # over the door
	_face(cx, face_x, s_ent, s_front, 0, ROWS, cols, FACE_SHADE)       # front jamb
	var top := TOP + DOOR_ROWS
	var q := PackedVector2Array([_p(cx, face_x, top, s_door), _p(cx, face_x, top, s_ent),
		_p(cx, face_x, SEAM, s_ent), _p(cx, face_x, SEAM, s_door)])
	draw_colored_polygon(q, OUTSIDE_COL)
	# the corridor's floor, just visible past the threshold (the bottom few rows of the opening)
	draw_colored_polygon(PackedVector2Array([_p(cx, face_x, SEAM - 5.0, s_door), _p(cx, face_x, SEAM - 5.0, s_ent),
		_p(cx, face_x, SEAM, s_ent), _p(cx, face_x, SEAM, s_door)]), CORRIDOR_FLOOR)
	# architrave: head + both jambs, a light inner edge, and the threshold across the floor
	draw_line(_p(cx, face_x, top - 1.0, s_door), _p(cx, face_x, top - 1.0, s_ent), TRIM_COL, 3.0)
	draw_line(_p(cx, face_x, top - 1.0, s_door), _p(cx, face_x, SEAM, s_door), TRIM_COL, 3.0)
	draw_line(_p(cx, face_x, top - 1.0, s_ent), _p(cx, face_x, SEAM, s_ent), TRIM_COL, 3.0)
	draw_line(_p(cx, face_x, top + 1.0, s_door), _p(cx, face_x, top + 1.0, s_ent), TRIM_LT, 1.0)
	draw_line(_p(cx, face_x, SEAM, s_door), _p(cx, face_x, SEAM, s_ent), THRESHOLD, 2.0)
	_slab(cx, xb, s_front, 0, ROWS, CUT_COL)
