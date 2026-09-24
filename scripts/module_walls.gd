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
const OUTSIDE_COL := Color(0.05, 0.045, 0.05)
const CORRIDOR_FLOOR := Color(0.16, 0.12, 0.09)   # a glimpse of the corridor floor through the door
const THRESHOLD := Color(0.46, 0.36, 0.24)

const FLOOR_STRIP := 32      # module FLOORS repeat every 32px (tools/art: planks/carpet/tiles) — the
                             # wedge below continues a floor by tiling its last/first 32 columns
var boundaries: Array = []     # [{x, left_mod, right_mod, door, outside}]
var _strips: Dictionary = {}   # module instance id + side → ImageTexture of its floor edge strip
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
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED   # the floor strips tile across the wedges
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


func _cam_x() -> float:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return 0.0
	return to_local(cam.get_screen_center_position()).x


# A back-plane point (x, y) pushed out to depth scale s (1 = on the back wall), perspective about
# the vanishing point (camera x, horizon VY).
func _p(cx: float, x: float, y: float, s: float) -> Vector2:
	return Vector2(cx + (x - cx) * s, VY + (y - VY) * s)


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
	var cx := _cam_x()
	var s_front := _s_for_floor(FRONT_FLOOR)
	var s_door := _s_for_floor(DOOR_FLOOR)
	# FLOORS first (owner round 9: "when the player moves between modules the boundary line on the
	# floor, just like the wall above, needs to move from one side to the other"). Where two rooms
	# meet, their floors part along the wall's BASE LINE in perspective — not the module's vertical
	# edge — so the floor of the room whose wall face we see runs on past the edge to that line,
	# and flips sides as the camera crosses the wall. Doorways get a threshold along it.
	for b in boundaries:
		var room_f = facing_room(b, cx)
		if room_f != null:
			_floor_wedge(cx, float(b["x"]), room_f, cx < float(b["x"]))
			if b["door"] and not b["outside"]:
				_threshold(cx, float(b["x"]))
	for b in boundaries:
		var xb: float = b["x"]
		# Which face points at the camera: camera LEFT of the wall → the wall's left face, i.e. the
		# right wall of the LEFT room (and vice versa). Straight on → nothing but the cut shows.
		var cam_left: bool = cx < xb
		var room = facing_room(b, cx)
		var face_x: float = xb - HALF_T if cam_left else xb + HALF_T
		var cols: Array = _column(room, cam_left) if room != null else []
		if room == null:
			continue      # looking at an end wall from outside the room — never happens in play
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


func _floor_wedge(cx: float, xb: float, room: Node, room_is_left: bool) -> void:
	# The triangle between the module edge (x = xb) and the wall's base line x_w(y) = cx + (xb−cx)·s(y)
	# — zero at the seam, widest at the front — belongs to `room` (the room on the camera's side of
	# the wall). Paint it with that room's own floor, tiled on from its edge strip so the pattern
	# carries straight on (module floors repeat every FLOOR_STRIP px).
	var strip: Texture2D = _floor_strip(room, room_is_left)
	var rows := float(MOD_ROWS - ROWS)
	var bot := minf(TOP + float(MOD_ROWS), BAND_BOTTOM)
	var xw := cx + (xb - cx) * _s_for_floor(bot)
	var vb := (bot - SEAM) / rows
	var p := float(strip.get_width())
	draw_polygon(PackedVector2Array([Vector2(xb, SEAM), Vector2(xb, bot), Vector2(xw, bot)]),
		PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE]),
		PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.0, vb), Vector2((xw - xb) / p, vb)]), strip)


func _threshold(cx: float, xb: float) -> void:
	# A doorway's saddle: a strip of wood along the floor boundary where the opening is.
	var a := Vector2(cx + (xb - cx) * _s_for_floor(DOOR_FLOOR), DOOR_FLOOR)
	var b := Vector2(cx + (xb - cx) * _s_for_floor(FRONT_FLOOR), FRONT_FLOOR)
	draw_line(a, b, TRIM_COL, 2.0)
	draw_line(a + Vector2(1, 0), b + Vector2(1, 0), TRIM_LT, 1.0)


func floor_boundary_x(xb: float, cam_x: float, floor_y: float) -> float:
	# Where two rooms' floors meet at a given floor depth (the wall's base line) — for tests/tools.
	return cam_x + (xb - cam_x) * _s_for_floor(floor_y)


func _floor_strip(mod: Node, right_edge: bool) -> Texture2D:
	# The module's floor (rows below the seam), FLOOR_STRIP px wide, from its right or left edge.
	var key := str(mod.get_instance_id()) + (":fr" if right_edge else ":fl")
	if _strips.has(key):
		return _strips[key]
	var h := MOD_ROWS - ROWS
	var out: Image = null
	var art = mod.get_node_or_null("Art")
	if art is Sprite2D and art.texture != null:
		# Prefer the module's FLOOR-ONLY export (tools/art: <name>_floor.png, rows below the seam, no
		# furniture) so nothing standing near the edge — a bin, a lamp's shadow — is tiled into the
		# next room; fall back to the art's own floor rows.
		var floor_path: String = art.texture.resource_path.get_basename() + "_floor.png"
		var img: Image = null
		var y0 := ROWS
		if art.texture.resource_path != "" and ResourceLoader.exists(floor_path):
			img = (load(floor_path) as Texture2D).get_image()
			y0 = 0
		else:
			img = art.texture.get_image()
		if img != null and img.get_width() >= FLOOR_STRIP and img.get_height() >= y0 + h:
			if img.is_compressed():
				img.decompress()
			var x0: int = img.get_width() - FLOOR_STRIP if right_edge else 0
			out = img.get_region(Rect2i(x0, y0, FLOOR_STRIP, h))
	if out == null:
		# a placeholder module: its flat colour
		out = Image.create(1, h, false, Image.FORMAT_RGBA8)
		var flat := Color(0.4, 0.4, 0.4)
		var rect = mod.get_node_or_null("ColorRect")
		if rect is ColorRect:
			flat = rect.color
		out.fill(flat)
	var tex := ImageTexture.create_from_image(out)
	_strips[key] = tex
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
