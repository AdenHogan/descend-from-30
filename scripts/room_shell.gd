extends Node2D

# ROOM SHELL — the apartment's frame, drawn as a clean building CROSS-SECTION (owner round 9: "a
# cleaner ceiling looking boundary just above the module so that it fits across the entire apartment
# scene and bordering for the walls and front door"). Replaces the old stone-block tiles, which are
# HIDDEN, not deleted: the camera framing still reads the tilemap's used rect (StairPan.clean_bounds),
# and the tiles never carried collision (the walls/floor are separate StaticBodies).
#
# It completes module_walls.gd's dollhouse: the partitions are cut at the FRONT plane, so the frame is
# cut there too —
#   * the CEILING SLAB spans the whole flat above the modules, its underside at the front plane's
#     ceiling line (a plaster skim + crown edge, the flat above's floorboards along its top);
#   * the two END WALLS are solid section from their front cut outward (they move with the camera,
#     like every cut edge, so the box keeps its depth);
#   * the band stays inside the room's own 160px (ROOM_BAND_TOP..+160), so two flats stacked in a
#     balcony pan meet flush: the lower flat's slab IS the floor under the upper one.
# Purely visual, local space (a BalconyPan backdrop sits a floor down).

const MW := preload("res://scripts/module_walls.gd")

const BAND_TOP := 215.0      # room.ROOM_BAND_TOP — the camera's top edge
const BAND_BOTTOM := 375.0   # BAND_TOP + ROOM_BAND_H — never draw into the flat below
const MODULE_BOTTOM := 368.0 # the modules end here: below is this flat's FLOOR, cut (the band's last 7px)
const SECTION_SHOW := 5.0    # how much of each end wall's section the camera shows past its cut
const SIDE_REACH := 96.0     # draw this far past the tile bounds (past any camera limit)

const WALK_FEET_Y := 353.0   # room.ROOM_FEET_Y — the lane every actor stands on

const SECTION := Color(0.16, 0.13, 0.11)      # the cut mass (concrete / brick in section)
const SECTION_LT := Color(0.22, 0.18, 0.15)   # a faint inner line so the mass isn't a flat hole
const PLASTER := Color(0.66, 0.61, 0.53)      # the ceiling / wall plaster skim, seen cut
const PLASTER_LO := Color(0.47, 0.43, 0.37)
const BOARD := Color(0.36, 0.25, 0.16)        # the floor of the flat above, in section
const BOARD_LO := Color(0.25, 0.17, 0.11)
const EDGE := Color(0.07, 0.06, 0.05)         # the contact line where the cut meets the room

var left_x := 97.0           # tile bounds (the camera's horizontal limits before the margin)
var right_x := 1089.0
var ends: Array = []         # the two end-wall x positions (module_walls boundaries 0 and n)


func setup(tile_bounds: Rect2, end_walls: Array) -> void:
	left_x = tile_bounds.position.x
	right_x = tile_bounds.position.x + tile_bounds.size.x
	ends = end_walls
	z_index = 0
	var tm = get_parent().get_node_or_null("TileMapLayer")
	if tm is CanvasItem:
		tm.visible = false
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


static func front_scale() -> float:
	return MW._s_for_floor(MW.FRONT_FLOOR)


static func camera_limits_x(inner_left: float, inner_right: float, half_view: float) -> Vector2:
	# The room camera's horizontal limits: pinned at an end, the view shows the end wall's face and
	# just SECTION_SHOW px of section past its front cut — no wasted dark band (owner round 9).
	# Solves  cut(cx = L + half_view) − L = SECTION_SHOW  for L (and mirrored for R).
	var s := front_scale()
	var reach := (SECTION_SHOW - half_view * (1.0 - s)) / s
	return Vector2(inner_left - reach, inner_right + reach)


static func wall_foot_x(inner_x: float, cam_x: float) -> float:
	# Where an end wall's face meets the floor at the walking lane (feet 353), for a camera at cam_x
	# — the point the player's body should stop at, so it's stopped by the wall it SEES.
	return cam_x + (inner_x - cam_x) * MW._s_for_floor(WALK_FEET_Y)


static func door_face_x(inner_x: float, cam_x: float, floor_y: float) -> float:
	# The entrance wall's face (where the front door is cut) at a given floor depth.
	return cam_x + (inner_x - cam_x) * MW._s_for_floor(floor_y)


static func ceiling_cut_y() -> float:
	# The back wall's top (module row 0) projected to the front cut plane: where the slab's underside
	# sits, so the partitions' front cuts rise straight into it.
	return MW.VY + (MW.TOP - MW.VY) * MW._s_for_floor(MW.FRONT_FLOOR)


func end_cut_x(end_x: float, cam_x: float) -> float:
	# An end wall's front cut at the front plane — its INNER edge, where the wall's face (turned to
	# the room) ends, so the section covers module_walls' own thin cut there. Follows the camera.
	var s := MW._s_for_floor(MW.FRONT_FLOOR)
	var cut := cam_x + (end_x - cam_x) * s
	var inward := 1.0 if end_x < (left_x + right_x) * 0.5 else -1.0
	return cut + inward * MW.HALF_T * s


func _cam_x() -> float:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return (left_x + right_x) * 0.5
	return to_local(cam.get_screen_center_position()).x


func _draw() -> void:
	var x0 := left_x - SIDE_REACH
	var x1 := right_x + SIDE_REACH
	var yc := floorf(ceiling_cut_y())
	# --- the ceiling slab (the flat above's floor seen from below — just its mass, the boards are
	# drawn by THAT flat's own floor cut, so a balcony pan never doubles them) ---
	draw_rect(Rect2(x0, BAND_TOP, x1 - x0, yc - BAND_TOP), SECTION)
	# --- this flat's floor, cut: the boards on top, then the mass, under the whole width ---
	draw_rect(Rect2(x0, MODULE_BOTTOM, x1 - x0, BAND_BOTTOM - MODULE_BOTTOM), SECTION)
	draw_rect(Rect2(x0, MODULE_BOTTOM, x1 - x0, 2.0), BOARD)
	draw_rect(Rect2(x0, MODULE_BOTTOM + 2.0, x1 - x0, 1.0), BOARD_LO)
	var bx := x0 + 7.0
	while bx < x1:                                  # board ends, staggered — reads as a floor
		draw_rect(Rect2(bx, MODULE_BOTTOM, 1.0, 2.0), BOARD_LO)
		bx += 23.0 if int(bx) % 2 == 0 else 31.0
	# The plaster ceiling (cut) runs between the two end walls' cuts, turning down into their skims.
	var cx := _cam_x()
	var in0 := x0
	var in1 := x1
	for e in ends:
		var c := roundf(end_cut_x(e, cx))
		if e < (left_x + right_x) * 0.5:
			in0 = c - 5.0
		else:
			in1 = c + 5.0
	draw_rect(Rect2(in0, yc - 5.0, in1 - in0, 1.0), PLASTER_LO)
	draw_rect(Rect2(in0, yc - 4.0, in1 - in0, 3.0), PLASTER)
	draw_rect(Rect2(in0, yc - 1.0, in1 - in0, 1.0), EDGE)          # its crisp underside
	# --- the end walls, solid section outward of their front cut ---
	for e in ends:
		var ex: float = e
		var cut := end_cut_x(ex, cx)
		var outward := -1.0 if ex < (left_x + right_x) * 0.5 else 1.0
		var far := x0 if outward < 0.0 else x1
		cut = roundf(cut)
		draw_rect(Rect2(minf(cut, far), yc, absf(far - cut), BAND_BOTTOM - yc), SECTION)
		# From the room outward: the contact line, the wall's plaster skim (cut), a shadow line, then
		# the mass with one faint inner line — the same profile as the ceiling's edge.
		_strip(cut, outward, 0.0, 1.0, yc, EDGE)
		_strip(cut, outward, 1.0, 3.0, yc, PLASTER)
		_strip(cut, outward, 4.0, 1.0, yc, PLASTER_LO)
		_strip(cut, outward, 9.0, 1.0, yc + 5.0, SECTION_LT)


func _strip(cut: float, outward: float, off: float, w: float, top: float, col: Color) -> void:
	# A vertical strip `off`..`off+w` px OUTWARD of an end wall's cut, down to the band bottom.
	var x := cut + off if outward > 0.0 else cut - off - w
	draw_rect(Rect2(x, top, w, BAND_BOTTOM - top), col)
