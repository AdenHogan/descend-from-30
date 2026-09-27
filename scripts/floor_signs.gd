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
const OPENING_TOP := 259.0                            # the top of the openings (corridor.py RECESS, y 16)
const FLOOR_PLATE_X := {"left": 246.0, "right": 1100.0}   # the floor number, on the wall beside each stairwell
const FLOOR_PLATE_Y := 290.0
const LIFT_X := 1030.0                                # the lift's centre (corridor.py ELEVATOR 880..950)
const LIFT_PANEL_Y := 296.0                           # just over its doors (they start at y ~307)

var floor_num := 1
var section := "mid"
var lift_lit := false


## Where the signs + door plates + wall sconces sit, in the corridor art's LOCAL space (world − (115, 243)), so the
## per-floor decals (corridor_decals.plan) never paint over them.
static func taken_local() -> Array:
	var out: Array = [Rect2(12, 12, 88, 26), Rect2(1020, 12, 88, 26),     # the STAIRS signs
		Rect2(112, 32, 38, 40), Rect2(966, 32, 38, 40),                      # the floor numbers
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


func setup(f: int, sec: String) -> void:
	name = "FloorSigns"
	floor_num = f
	section = sec
	lift_lit = WorldState.elevator_powered or f in WorldState.MERCHANT_FLOORS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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


func _draw() -> void:
	var t := stair_targets()
	for side in t:
		_stair_sign(float(STAIR_X[side]), str(t[side][0]), int(t[side][1]))
	for side in ["left", "right"]:
		_floor_number(float(FLOOR_PLATE_X[side]))
	_lift_panel()


func _stair_sign(cx: float, arrow: String, to_floor: int) -> void:
	# a green safety sign hung over the stairwell opening: STAIRS, then the arrow + where it goes
	var top_line := "STAIRS"
	var bottom := arrow + " " + floor_label(to_floor)
	var w := maxi(text_width(top_line), text_width(bottom)) + 6
	var r := Rect2(roundf(cx - w / 2.0), OPENING_TOP + 3.0, w, 15)
	draw_rect(Rect2(r.position.x + 3, OPENING_TOP, 1, 3), Color(0.16, 0.16, 0.16))              # its hangers
	draw_rect(Rect2(r.end.x - 4, OPENING_TOP, 1, 3), Color(0.16, 0.16, 0.16))
	draw_rect(r, Color(0.12, 0.3, 0.19))
	draw_rect(r.grow(-1), Color(0.18, 0.46, 0.28))
	var ink := Color(0.93, 0.96, 0.92)
	draw_text(self, Vector2(roundf(cx - text_width(top_line) / 2.0), r.position.y + 2), top_line, ink)
	draw_text(self, Vector2(roundf(cx - text_width(bottom) / 2.0), r.position.y + 8), bottom, ink)


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


func _floor_number(cx: float) -> void:
	var num := floor_label(floor_num)
	var r := sign_rect(num, cx)
	draw_rect(Rect2(r.position + Vector2(0.5, 0.8), r.size), Color(0, 0, 0, 0.3))           # sits flat on the wall
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
	var m := 2.2                                                                                  # flush screws, symmetric
	for sp in [face.position + Vector2(m, m), Vector2(face.end.x - m, face.position.y + m),
			Vector2(face.position.x + m, face.end.y - m), face.end - Vector2(m, m)]:
		draw_circle(sp, 0.85, STEEL.darkened(0.4))
		draw_circle(sp + Vector2(-0.25, -0.25), 0.4, Color(1, 1, 1, 0.85))
	# the number, its INK centred on the sheet both ways
	var at := number_origin(num, r)
	draw_stroke_text(self, at + Vector2(0.0, 0.55), num, SIGN_NUM_H, Color(1, 1, 1, 0.6), SIGN_STROKE, false)   # the lip
	draw_stroke_text(self, at, num, SIGN_NUM_H, ENGRAVE, SIGN_STROKE)                                  # the cut


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
