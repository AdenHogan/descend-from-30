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
const VY := 190.0           # the horizon (eye height): above the room — we look down on the floor
const FRONT_FLOOR := 360.0  # the near cut plane's floor line (just in front of the feet line 353)
const DOOR_FLOOR := 338.0   # the doorway starts this deep (floor y) — the lane runs through it
const DOOR_ROWS := 42       # the lintel: back-plane rows 0..41 are wall above the doorway
const HALF_T := 2.0         # half the wall's thickness (back-plane px)
const FACE_SHADE := 0.82    # a turned surface reads a little darker (ambient only)
const CUT_COL := Color(0.24, 0.18, 0.13)   # the cut section: warm plaster-brown, not a black bar
const TRIM_COL := Color(0.30, 0.21, 0.14)
const TRIM_LT := Color(0.40, 0.29, 0.19)
const OUTSIDE_COL := Color(0.05, 0.045, 0.05)

var boundaries: Array = []     # [{x, left_mod, right_mod, door, outside}]
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
	for r in range(ROWS):
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
		if b["door"]:
			_face(cx, face_x, 1.0, s_door, 0, ROWS, cols, FACE_SHADE)          # the stub to the back wall
			_face(cx, face_x, s_door, s_front, 0, DOOR_ROWS, cols, FACE_SHADE) # the lintel
			if b["outside"]:
				# the entrance: through it, the dark of the corridor
				draw_colored_polygon(PackedVector2Array([_p(cx, face_x, TOP + DOOR_ROWS, s_door),
					_p(cx, face_x, TOP + DOOR_ROWS, s_front), _p(cx, face_x, SEAM, s_front),
					_p(cx, face_x, SEAM, s_door)]), OUTSIDE_COL)
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
