extends Node2D
## FLOOR SIGNS (owner round 23 — "the corridor should have a variety of notices for the building, signs
## for things like elevators and stairwells, signs next to apartments with the apartment number… to show
## that the floors are actually distinct despite being a cut and paste of building_floors").
##
## The corridor art is shared by many floors, so everything that says WHICH floor this is is drawn here,
## live, in the building's 3x5 pixel capitals (the same letters the room art uses — tools/art/furn.py
## FONT3), crisp at the game's zoom:
##   - by each stairwell: a green STAIRS sign over the opening, with an arrow and the floor it leads to
##     (the down side from WorldState.stair_down_side — a pure function of the floor);
##   - beside each stairwell: the floor's number engraved in a clean brushed-steel sheet (every floor);
##   - over the lift: its floor indicator (lit amber only while the lift has power).
## Each apartment door carries its own number plate (door.gd, `DoorPlate` below) so floor 30's doors
## get one too. Drawn at z 0 (the backdrop), after the corridor art, under every actor.

const FONT3 := {
	"A": ["010", "101", "111", "101", "101"], "B": ["110", "101", "110", "101", "110"],
	"C": ["011", "100", "100", "100", "011"], "D": ["110", "101", "101", "101", "110"],
	"E": ["111", "100", "110", "100", "111"], "F": ["111", "100", "110", "100", "100"],
	"G": ["011", "100", "101", "101", "011"], "H": ["101", "101", "111", "101", "101"],
	"I": ["1", "1", "1", "1", "1"], "J": ["001", "001", "001", "101", "010"],
	"K": ["101", "101", "110", "101", "101"], "L": ["100", "100", "100", "100", "111"],
	"M": ["10001", "11011", "10101", "10001", "10001"], "N": ["1001", "1101", "1011", "1001", "1001"],
	"O": ["010", "101", "101", "101", "010"], "P": ["110", "101", "110", "100", "100"],
	"Q": ["010", "101", "101", "110", "011"], "R": ["110", "101", "110", "101", "101"],
	"S": ["011", "100", "010", "001", "110"], "T": ["111", "010", "010", "010", "010"],
	"U": ["101", "101", "101", "101", "111"], "V": ["101", "101", "101", "101", "010"],
	"W": ["10001", "10001", "10101", "11011", "10001"], "X": ["101", "101", "010", "101", "101"],
	"Y": ["101", "101", "010", "010", "010"], "Z": ["111", "001", "010", "100", "111"],
	"0": ["111", "101", "101", "101", "111"], "1": ["01", "11", "01", "01", "01"],
	"2": ["110", "001", "010", "100", "111"], "3": ["110", "001", "010", "001", "110"],
	"4": ["101", "101", "111", "001", "001"], "5": ["111", "100", "110", "001", "110"],
	"6": ["011", "100", "110", "101", "010"], "7": ["111", "001", "010", "010", "010"],
	"8": ["010", "101", "010", "101", "010"], "9": ["010", "101", "011", "001", "110"],
	" ": ["0", "0", "0", "0", "0"], "-": ["00", "00", "11", "00", "00"], ".": ["0", "0", "0", "0", "1"],
	"^": ["00100", "01110", "10101", "00100", "00100"], "v": ["00100", "00100", "10101", "01110", "00100"],
}

# world geometry (scenes/building_floors.tscn; the corridor art sits at (115, 243))
const STAIR_X := {"left": 171.0, "right": 1179.0}     # the staircase openings' centres
const STAIR_SIGN_Z := 2                                 # the STAIRS signs' layer — in front of the actors (z 1)
const OPENING_TOP := 259.0                            # the top of the openings (corridor.py RECESS, y 16)
const FLOOR_PLATE_X := {"left": 246.0, "right": 1100.0}   # the floor number, on the wall beside each stairwell
const FLOOR_PLATE_Y := 290.0
const LIFT_X := 1030.0                                # the lift's centre (corridor.py ELEVATOR 880..950)
const LIFT_PANEL_Y := 296.0                           # just over its doors (they start at y ~307)

var floor_num := 1
var section := "mid"
var lift_lit := false
var sides: Array = ["left", "right"]   # which stairwells this floor has (the endpoint floors have ONE)
var number_plate := true              # the engraved floor number (the lobby has no number to engrave)


## Where the signs + door plates + wall sconces sit, in the corridor art's LOCAL space (world − (115, 243)), so the
## per-floor decals (corridor_decals.plan) never paint over them.
static func taken_local() -> Array:
	var out: Array = [Rect2(12, 12, 88, 26), Rect2(1020, 12, 88, 26),     # the STAIRS signs
		Rect2(112, 32, 56, 50), Rect2(950, 32, 54, 50),                      # the floor numbers (room to hang askew)
		Rect2(898, 48, 34, 16)]                                               # the lift indicator
	for d in [201, 329, 455, 581, 714]:                                       # every door's plate
		out.append(Rect2(d - 50, 90, 26, 18))
	out.append(Rect2(814 - 56, 90, 32, 18))                                   # the maintenance door's (STAFF is wider)
	for x in load("res://scripts/floor_lighting.gd").SCONCE_X:               # the wall sconces (the floor's lights)
		out.append(Rect2(float(x) - 115.0 - 10.0, 43, 20, 24))
	return out


static func text_width(s: String, scale: int = 1) -> int:
	var w := 0
	for ch in s:
		w += (FONT3.get(ch, FONT3[" "])[0] as String).length() + 1
	return maxi(0, w - 1) * scale


static func draw_text(ci: CanvasItem, pos: Vector2, s: String, col: Color, scale: int = 1) -> void:
	var x := pos.x
	for ch in s:
		var g: Array = FONT3.get(ch, FONT3[" "])
		for gy in range(g.size()):
			var row: String = g[gy]
			for gx in range(row.length()):
				if row[gx] == "1":
					ci.draw_rect(Rect2(x + gx * scale, pos.y + gy * scale, scale, scale), col)
		x += ((g[0] as String).length() + 1) * scale


static func floor_label(f: int) -> String:
	return "LOBBY" if f <= 0 else str(f)


var front: Node2D = null                # the STAIRS signs' own layer (StairSignsFront)


func setup(f: int, sec: String, only_sides: Array = ["left", "right"], with_number := true) -> void:
	name = "FloorSigns"
	floor_num = f
	section = sec
	sides = only_sides
	number_plate = with_number
	lift_lit = WorldState.elevator_powered or f in WorldState.MERCHANT_FLOORS
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS   # only the number is a texture (its smooth edges)
	# The STAIRS signs hang in the stairwell openings, IN FRONT of anything climbing the stairs behind them (owner round 31k:
	# "make the stairs sign the most forward… heads always go up behind it"): they draw on their own layer above the actors
	# (z STAIR_SIGN_Z; actors are z 1). Nothing in the corridor reaches that high, so only stair climbers pass behind them.
	if front == null:
		front = Node2D.new()
		front.name = "StairSignsFront"
		front.z_index = STAIR_SIGN_Z
		front.draw.connect(_draw_stair_signs)
		add_child(front)
	front.queue_redraw()
	queue_redraw()


## Which way each stairwell goes from this floor, and to where: {"left": [dir, floor], "right": ...}.
func stair_targets() -> Dictionary:
	var down := WorldState.stair_down_side(floor_num)
	var up := "left" if down == "right" else "right"
	var out := {}
	out[down] = ["v", floor_num - 1]
	if floor_num < 30:
		out[up] = ["^", floor_num + 1]
	return out


## The STAIRS signs' rectangles (local = world: this node sits at the origin), for the front layer and the tests.
func stair_sign_rects() -> Array:
	var out: Array = []
	var t := stair_targets()
	for side in t:
		if side in sides and int(t[side][1]) >= 0:
			out.append(_stair_sign_rect(float(STAIR_X[side]), str(t[side][0]), int(t[side][1])))
	return out


func _draw_stair_signs() -> void:
	var t := stair_targets()
	for side in t:
		if side in sides and int(t[side][1]) >= 0:
			_stair_sign(front, float(STAIR_X[side]), str(t[side][0]), int(t[side][1]))


func _draw() -> void:
	if number_plate:
		for side in sides:
			_floor_number(float(FLOOR_PLATE_X[side]), side)
	_lift_panel()


func _stair_sign_rect(cx: float, arrow: String, to_floor: int) -> Rect2:
	var w := maxi(text_width("STAIRS"), text_width(arrow + " " + floor_label(to_floor))) + 6
	return Rect2(roundf(cx - w / 2.0), OPENING_TOP + 3.0, w, 15)


func _stair_sign(ci: CanvasItem, cx: float, arrow: String, to_floor: int) -> void:
	# a green safety sign hung over the stairwell opening: STAIRS, then the arrow + where it goes
	var top_line := "STAIRS"
	var bottom := arrow + " " + floor_label(to_floor)
	var r := _stair_sign_rect(cx, arrow, to_floor)
	ci.draw_rect(Rect2(r.position.x + 3, OPENING_TOP, 1, 3), Color(0.16, 0.16, 0.16))              # its hangers
	ci.draw_rect(Rect2(r.end.x - 4, OPENING_TOP, 1, 3), Color(0.16, 0.16, 0.16))
	ci.draw_rect(r, Color(0.12, 0.3, 0.19))
	ci.draw_rect(r.grow(-1), Color(0.18, 0.46, 0.28))
	var ink := Color(0.93, 0.96, 0.92)
	draw_text(ci, Vector2(roundf(cx - text_width(top_line) / 2.0), r.position.y + 2), top_line, ink)
	draw_text(ci, Vector2(roundf(cx - text_width(bottom) / 2.0), r.position.y + 8), bottom, ink)


# --- THE FLOOR SIGN (owner round 24b — "a clean metal sheet with engraved floor numbers on it, not too
# protruding from the scene, but a clearly built sign… the number could be fine all by itself… clean font
# too"): ONE design on every floor — a thin brushed-steel sheet on the wall (a hairline edge, the barest
# shadow, four flush screws) with the number ENGRAVED in it: dark cut strokes with round ends, a light
# lip along their lower edge where the cut catches the light. The type is drawn as smooth antialiased
# STROKES on a 6x10 grid (a clean geometric sans), not pixel capitals.
const STROKE := {
	"0": [["E", 3.0, 5.0, 3.0, 5.0]],
	"1": [[[1.8, 1.8], [3.6, 0.0], [3.6, 10.0]]],
	"2": [["A", 3.0, 3.0, 3.0, 180.0, 395.0], [[5.46, 4.72], [0.0, 10.0], [6.0, 10.0]]],
	"3": [["A", 3.0, 2.6, 2.6, 195.0, 450.0], ["A", 3.0, 7.4, 2.6, 270.0, 525.0]],
	"4": [[[4.4, 10.0], [4.4, 0.0], [0.0, 7.0], [6.2, 7.0]]],
	"5": [[[5.6, 0.0], [0.9, 0.0], [0.6, 4.4]], ["A", 3.0, 6.8, 3.2, 232.0, 520.0]],
	"6": [["A", 3.0, 7.0, 3.0, 0.0, 360.0], ["A", 7.0, 7.0, 7.0, 245.0, 180.0]],
	"7": [[[0.0, 0.0], [6.0, 0.0], [2.2, 10.0]]],
	"8": [["A", 3.0, 2.6, 2.4, 0.0, 360.0], ["A", 3.0, 7.4, 2.6, 0.0, 360.0]],
	"9": [["A", 3.0, 3.0, 3.0, 0.0, 360.0], ["A", -1.0, 3.0, 7.0, 0.0, 65.0]],
}
const SIGN_NUM_H := 15.0              # the number's height, world px
const SIGN_STROKE := 2.1
const STEEL := Color(0.72, 0.74, 0.76)
const ENGRAVE := Color(0.16, 0.17, 0.19)


static func _stroke_polys(ch: String) -> Array:
	var out: Array = []
	for part in STROKE.get(ch, []):
		var pts := PackedVector2Array()
		if part[0] is String:
			var cx: float = part[1]
			var cy: float = part[2]
			var rx: float = part[3]
			var ry: float = part[4] if part[0] == "E" else part[3]
			var t0: float = 0.0 if part[0] == "E" else part[4]
			var t1: float = 360.0 if part[0] == "E" else part[5]
			var steps := 32
			for i in range(steps + 1):
				var t := deg_to_rad(lerpf(t0, t1, float(i) / steps))
				pts.append(Vector2(cx + rx * cos(t), cy + ry * sin(t)))
		else:
			for q in part:
				pts.append(Vector2(q[0], q[1]))
		out.append(pts)
	return out


const INK_GAP := 2.6                  # the space between two glyphs' INK, in grid units (tight, even)


## A glyph's ink extent along x (grid units) — the "1" is a narrow stroke, so spacing and centring go
## by the ink, never by a fixed cell (a fixed cell pushed "21" / "15" off-centre on the plate).
static func _glyph_span(ch: String) -> Vector2:
	var lo := INF
	var hi := -INF
	for pts in _stroke_polys(ch):
		for p in pts:
			lo = minf(lo, p.x)
			hi = maxf(hi, p.x)
	return Vector2(lo, hi) if lo <= hi else Vector2(0.0, 6.0)


## The INK width of `s` in the stroke type at `h` px tall.
static func stroke_width(s: String, h: float) -> float:
	var u := h / 10.0
	var w := 0.0
	for i in range(s.length()):
		var sp := _glyph_span(s[i])
		w += sp.y - sp.x
		if i > 0:
			w += INK_GAP
	return w * u


## Draws `s` as strokes with ROUND ends (a clean sign face, not a pixel font); `pos.x` is the ink's left.
static func draw_stroke_text(ci: CanvasItem, pos: Vector2, s: String, h: float, col: Color, w: float,
		caps: bool = true) -> void:
	var u := h / 10.0
	var x := pos.x
	for ch in s:
		var sp := _glyph_span(ch)
		for pts in _stroke_polys(ch):
			var tp := PackedVector2Array()
			for p in pts:
				tp.append(Vector2(x + (p.x - sp.x) * u, pos.y + p.y * u))
			ci.draw_polyline(tp, col, w, true)
			if caps:
				ci.draw_circle(tp[0], w * 0.5, col)
				ci.draw_circle(tp[tp.size() - 1], w * 0.5, col)
		x += (sp.y - sp.x + INK_GAP) * u


const NUM_SS := 8.0                   # texels per world px in a number's texture (camera zoom ~2.8, + mipmaps)
const NUM_PAD := 2.0                  # world px of margin round the ink in that texture
static var _num_tex := {}


## The number `num` as a white, alpha-antialiased texture: every texel's coverage from its distance to the
## nearest stroke (so the ends and joins are round and the edges soft — no aliased caps, no notched
## corners). Built once per number and shared; drawn tinted, NUM_SS texels to a world pixel.
static func number_texture(num: String) -> Texture2D:
	if _num_tex.has(num):
		return _num_tex[num]
	var u := SIGN_NUM_H / 10.0
	var w := int(ceil((stroke_width(num, SIGN_NUM_H) + 2.0 * NUM_PAD) * NUM_SS))
	var h := int(ceil((SIGN_NUM_H + 2.0 * NUM_PAD) * NUM_SS))
	var dist := PackedFloat32Array()
	dist.resize(w * h)
	dist.fill(1e9)
	var half := SIGN_STROKE * 0.5 * NUM_SS
	var reach := half + 2.0
	var x0 := NUM_PAD
	for ch in num:
		var sp := _glyph_span(ch)
		for pts in _stroke_polys(ch):
			var q := PackedVector2Array()
			for p in pts:
				q.append(Vector2((x0 + (p.x - sp.x) * u) * NUM_SS, (NUM_PAD + p.y * u) * NUM_SS))
			for i in range(q.size() - 1):
				var a: Vector2 = q[i]
				var b: Vector2 = q[i + 1]
				var lo_x := maxi(0, int(floor(minf(a.x, b.x) - reach)))
				var hi_x := mini(w - 1, int(ceil(maxf(a.x, b.x) + reach)))
				var lo_y := maxi(0, int(floor(minf(a.y, b.y) - reach)))
				var hi_y := mini(h - 1, int(ceil(maxf(a.y, b.y) + reach)))
				var ab := b - a
				var len2 := maxf(ab.length_squared(), 1e-6)
				for ty in range(lo_y, hi_y + 1):
					for tx in range(lo_x, hi_x + 1):
						var c := Vector2(tx + 0.5, ty + 0.5)
						var t := clampf((c - a).dot(ab) / len2, 0.0, 1.0)
						var d := c.distance_to(a + ab * t)
						var k := ty * w + tx
						if d < dist[k]:
							dist[k] = d
		x0 += (sp.y - sp.x + INK_GAP) * u
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for ty in range(h):
		for tx in range(w):
			var cov := clampf(half + 0.5 - dist[ty * w + tx], 0.0, 1.0)     # a one-texel soft edge
			img.set_pixel(tx, ty, Color(1, 1, 1, cov))
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_num_tex[num] = tex
	return tex


## Where the number's ink starts on plate `r` (its ink centred on the sheet both ways).
static func number_origin(num: String, r: Rect2) -> Vector2:
	var c := r.get_center()
	return Vector2(c.x - stroke_width(num, SIGN_NUM_H) / 2.0, c.y - SIGN_NUM_H / 2.0 - 0.3)


## The drawn ink's x extent (min, max) of `s` set at `pos` — the stroke centres, as draw_stroke_text lays them.
static func ink_extent(pos: Vector2, s: String, h: float) -> Vector2:
	var u := h / 10.0
	var x := pos.x
	var lo := INF
	var hi := -INF
	for ch in s:
		var sp := _glyph_span(ch)
		for pts in _stroke_polys(ch):
			for p in pts:
				var px: float = x + (p.x - sp.x) * u
				lo = minf(lo, px)
				hi = maxf(hi, px)
		x += (sp.y - sp.x + INK_GAP) * u
	return Vector2(lo, hi)


## The sign's plate rect for this floor's number (world), centred on `cx`.
static func sign_rect(num: String, cx: float) -> Rect2:
	var w := roundf(maxf(stroke_width(num, SIGN_NUM_H) + 14.0, 28.0))
	if int(w) % 2 == 1:
		w += 1.0                                         # an even width, so it centres on a whole pixel
	return Rect2(roundf(cx) - w / 2.0, FLOOR_PLATE_Y - 9.0, w, 27.0)


# --- WEAR on the floor signs (owner round 24d — "a little blood smearing to some of them on random floors…
# by run three, some of them can even be hanging down as if they have been attacked or hit"). Per sign,
# seeded: a BLOOD threshold the floor's decay climbs past (deeper + later = more), so a sign bloodied in
# the morning is still bloodied at night and more join it; and from run 3 a HIT one hangs off its one
# remaining screw (the others gone, their holes in the wall and a clean patch where it hung). It swings
# away from the stairwell (left sign on its right screw, right sign on its left) by 20-34°, inside the
# spot corridor.py / taken_local keep clear for it.
const HANG_MIN := 20.0
const HANG_MAX := 34.0
const SCREW_M := 2.7                  # a screw's centre from the plate's corner (world px)
const BLOOD := Color(0.36, 0.05, 0.04, 0.88)
const BLOOD_DK := Color(0.22, 0.02, 0.02, 0.92)


## {blood: bool, hang: angle in radians (0 = hanging straight), pivot: "left"/"right", seed: int}
static func sign_wear(f: int, run: int, side: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(WorldState.master_seed) + "signwear" + str(f) + side)
	var blood_thr := rng.randf()
	var hang_thr := rng.randf()
	var deg := rng.randf_range(HANG_MIN, HANG_MAX)
	var sd := rng.randi()
	var wear := float(load("res://scripts/building_floors.gd").corridor_wear(f))
	var p_blood := clampf(0.08 + 0.1 * wear + 0.16 * float(run - 1), 0.0, 0.7)
	var pivot := "right" if side == "left" else "left"
	var hang := 0.0
	if run >= 3 and hang_thr < 0.1 + 0.05 * wear:
		hang = deg_to_rad(deg) * (-1.0 if pivot == "right" else 1.0)
	return {"blood": blood_thr < p_blood, "hang": hang, "pivot": pivot, "seed": sd}


## The pivot screw's world position for plate `r` hanging from `pivot`.
static func pivot_point(r: Rect2, pivot: String) -> Vector2:
	return Vector2(r.end.x - SCREW_M, r.position.y + SCREW_M) if pivot == "right" \
		else r.position + Vector2(SCREW_M, SCREW_M)


## The four corners of plate `r` as drawn with `wear` (rotated about its pivot when it hangs).
static func sign_corners(r: Rect2, wear: Dictionary) -> PackedVector2Array:
	var out := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	var ang: float = wear["hang"]
	if ang == 0.0:
		return out
	var pv := pivot_point(r, wear["pivot"])
	for i in out.size():
		out[i] = pv + (out[i] - pv).rotated(ang)
	return out


func _floor_number(cx: float, side: String = "left") -> void:
	var num := floor_label(floor_num)
	var r := sign_rect(num, cx)
	var wear := sign_wear(floor_num, WorldState.current_run, side)
	var ang: float = wear["hang"]
	var pv := pivot_point(r, wear["pivot"])
	if ang != 0.0:
		# where it hung: a cleaner patch of wall, the empty screw holes
		draw_rect(r, Color(1, 1, 1, 0.07))
		for sp in [r.position + Vector2(SCREW_M, SCREW_M), Vector2(r.end.x - SCREW_M, r.position.y + SCREW_M),
				Vector2(r.position.x + SCREW_M, r.end.y - SCREW_M), r.end - Vector2(SCREW_M, SCREW_M)]:
			if sp.distance_to(pv) > 1.0:
				draw_circle(sp, 0.7, Color(0.08, 0.07, 0.06, 0.85))
		draw_set_transform(pv, ang, Vector2.ONE)
		r.position -= pv
	draw_rect(Rect2(r.position + Vector2(0.5, 0.8), r.size), Color(0, 0, 0, 0.3 if ang == 0.0 else 0.4))   # its shadow
	draw_rect(r, STEEL.darkened(0.45))                                                      # its hairline edge
	var face := r.grow(-0.5)
	# polished steel: lighter at the top, a touch darker at the foot...
	draw_polygon(PackedVector2Array([face.position, Vector2(face.end.x, face.position.y), face.end,
		Vector2(face.position.x, face.end.y)]),
		PackedColorArray([STEEL.lightened(0.3), STEEL.lightened(0.22), STEEL.darkened(0.14), STEEL.darkened(0.08)]))
	var y := face.position.y                                                                # ...a fine brushed grain...
	var k := 0
	while y < face.end.y:
		var t := 0.5 + 0.5 * sin(float(k) * 2.9) * cos(float(k) * 0.53)
		draw_rect(Rect2(face.position.x, y, face.size.x, 0.5),
			Color(1, 1, 1, 0.03 + 0.04 * t) if k % 2 == 0 else Color(0, 0, 0, 0.02 + 0.03 * t))
		y += 0.5
		k += 1
	# ...and the SHINE: two soft diagonal streaks of reflected light across the sheet
	var span := face.size.x + face.size.y * 0.8
	for cy in range(int(face.size.y)):
		for cx2 in range(int(face.size.x)):
			var d := (float(cx2) + float(cy) * 0.8) / span
			var a := 0.55 * exp(-pow((d - 0.3) / 0.09, 2.0)) + 0.25 * exp(-pow((d - 0.5) / 0.035, 2.0)) \
				+ 0.12 * exp(-pow((d - 0.8) / 0.06, 2.0))
			if a > 0.01:
				draw_rect(Rect2(face.position + Vector2(cx2, cy), Vector2.ONE), Color(1, 1, 1, a))
	draw_rect(Rect2(face.position.x, face.position.y, face.size.x, 0.5), Color(1, 1, 1, 0.75))   # the lit edges
	draw_rect(Rect2(face.position.x, face.position.y, 0.5, face.size.y), Color(1, 1, 1, 0.45))
	draw_rect(Rect2(face.position.x, face.end.y - 0.5, face.size.x, 0.5), STEEL.darkened(0.35))
	draw_rect(Rect2(face.end.x - 0.5, face.position.y, 0.5, face.size.y), STEEL.darkened(0.3))
	var m := SCREW_M - 0.5                                                                        # flush screws, symmetric
	var keep := face.position + Vector2(m, m) if wear["pivot"] == "left" else Vector2(face.end.x - m, face.position.y + m)
	for sp in [face.position + Vector2(m, m), Vector2(face.end.x - m, face.position.y + m),
			Vector2(face.position.x + m, face.end.y - m), face.end - Vector2(m, m)]:
		if ang != 0.0 and sp != keep:
			draw_circle(sp, 0.75, Color(0.1, 0.1, 0.1, 0.9))                                   # torn out: just the hole
			continue
		draw_circle(sp, 0.85, STEEL.darkened(0.4))
		draw_circle(sp + Vector2(-0.25, -0.25), 0.4, Color(1, 1, 1, 0.85))
	# the number, its INK centred on the sheet both ways
	var at := number_origin(num, r)
	# the number is a smooth distance-field texture (number_texture): round ends, round joins, soft edges
	var tex := number_texture(num)
	var box := Rect2(at - Vector2(NUM_PAD, NUM_PAD), Vector2(tex.get_size()) / NUM_SS)
	draw_texture_rect(tex, Rect2(box.position + Vector2(0.0, 0.55), box.size), false, Color(1, 1, 1, 0.6))   # the lip
	draw_texture_rect(tex, box, false, ENGRAVE)                                                               # the cut
	if wear["blood"]:
		_blood_smear(r, int(wear["seed"]), ang == 0.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A bloody hand that slid DOWN the sheet: a palm print where it first struck (smudged, uneven), the
## fingers' streaks dragged down from it (thinning, fading out), a few flecks; on a sign still hanging
## straight, drips run off its bottom edge down the wall.
func _blood_smear(r: Rect2, sd: int, drips: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = sd
	var palm := Vector2(r.position.x + rng.randf_range(7.0, r.size.x - 7.0), r.position.y + rng.randf_range(4.0, 8.0))
	var dir := Vector2(rng.randf_range(-0.35, 0.35), 1.0).normalized()        # it slid down, a little aslant
	var across := Vector2(dir.y, -dir.x)
	var tilt := rng.randf_range(-0.3, 0.3)
	for k in range(7):                                                         # the palm: an uneven smudge
		var o := across * rng.randf_range(-2.4, 2.4) + dir * rng.randf_range(-1.4, 1.6)
		draw_circle(palm + o, rng.randf_range(1.0, 1.7), Color(BLOOD.r, BLOOD.g, BLOOD.b, rng.randf_range(0.55, 0.85)))
	for f in range(4):                                                         # the fingers, dragged down
		var base := palm + across.rotated(tilt) * (float(f) - 1.5) * 1.35 + dir * 1.2
		var ln := rng.randf_range(8.0, 15.0) * (0.8 if f == 0 or f == 3 else 1.0)
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		for k in range(10):
			var t := float(k) / 9.0
			pts.append(base + dir * ln * t + across * sin(t * 2.5 + float(f) * 1.7) * 0.25)
			cols.append(Color(BLOOD.r, BLOOD.g, BLOOD.b, BLOOD.a * (1.0 - t * 0.85)))
		draw_polyline_colors(pts, cols, 0.85 - 0.1 * float(f % 2), true)
	for k in range(rng.randi_range(3, 6)):                                     # flecks
		var p := r.position + Vector2(rng.randf_range(2.0, r.size.x - 2.0), rng.randf_range(2.0, r.size.y - 2.0))
		draw_circle(p, rng.randf_range(0.3, 0.65), BLOOD_DK)
	if drips:
		for k in range(rng.randi_range(1, 2)):                                 # running off the bottom edge
			var x := clampf(palm.x + rng.randf_range(-4.0, 4.0), r.position.x + 3.0, r.end.x - 3.0)
			var dl := rng.randf_range(3.0, 8.0)
			draw_line(Vector2(x, r.end.y - 1.0), Vector2(x, r.end.y + dl), BLOOD, 0.75, true)
			draw_circle(Vector2(x, r.end.y + dl), 0.6, BLOOD_DK)


func _lift_panel() -> void:
	# the lift's floor indicator: a dark box, the up / down arrows and this floor, amber when it has power
	var num := floor_label(floor_num)
	var w := text_width(num) + 16
	var r := Rect2(roundf(LIFT_X - w / 2.0), LIFT_PANEL_Y, w, 9)
	draw_rect(r.grow(1), Color(0.5, 0.5, 0.52))
	draw_rect(r, Color(0.06, 0.05, 0.05))
	var lit := Color(1.0, 0.66, 0.2) if lift_lit else Color(0.28, 0.2, 0.14)
	var dim := Color(0.34, 0.24, 0.14) if lift_lit else Color(0.2, 0.15, 0.11)
	draw_text(self, Vector2(r.position.x + 2, r.position.y + 2), "^", dim)
	draw_text(self, Vector2(roundf(LIFT_X - text_width(num) / 2.0), r.position.y + 2), num, lit)
	draw_text(self, Vector2(r.end.x - 7, r.position.y + 2), "v", dim)
