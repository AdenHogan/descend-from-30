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
##   - beside each stairwell: the floor's number, big, in the section's style (a brass plaque in the
##     hotel floors, an enamel plate in the residential ones, stencilled on the wall in the low ones);
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


# --- THE FLOOR SIGN (owner round 24 — "a bit too pixel art and doesn't look well designed. The square
# should have some metallic edges to it so it looks like a building sign"): a bevelled, brushed-metal
# plate with four screws, the type drawn as smooth antialiased STROKES (below, on a 6x10 grid) rather
# than blocky pixel capitals — engraved on the hotel's brass, white on a blue enamel panel on the
# residential aluminium, black on a bolted steel plate with a hazard strip down in the low floors.
const STROKE := {
	"0": [["E", 3.0, 5.0, 3.0, 5.0]],
	"1": [[[2.0, 1.6], [3.8, 0.0], [3.8, 10.0]]],
	"2": [["A", 3.0, 3.0, 3.0, 180.0, 395.0], [[5.3, 5.0], [0.0, 10.0], [6.0, 10.0]]],
	"3": [["A", 3.0, 2.5, 2.5, 200.0, 450.0], ["A", 3.0, 7.5, 2.5, 270.0, 520.0]],
	"4": [[[4.6, 10.0], [4.6, 0.0], [0.0, 7.0], [6.2, 7.0]]],
	"5": [[[5.6, 0.0], [0.9, 0.0], [0.6, 4.4]], ["A", 3.0, 6.8, 3.2, 232.0, 520.0]],
	"6": [["A", 3.0, 7.0, 3.0, 0.0, 360.0], [[4.9, 0.0], [0.4, 6.2]]],
	"7": [[[0.0, 0.0], [6.0, 0.0], [2.2, 10.0]]],
	"8": [["A", 3.0, 2.6, 2.4, 0.0, 360.0], ["A", 3.0, 7.4, 2.6, 0.0, 360.0]],
	"9": [["A", 3.0, 3.0, 3.0, 0.0, 360.0], [[5.9, 3.8], [2.0, 10.0]]],
	"F": [[[5.6, 0.0], [0.0, 0.0], [0.0, 10.0]], [[0.0, 5.0], [4.4, 5.0]]],
	"L": [[[0.0, 0.0], [0.0, 10.0], [5.4, 10.0]]],
	"O": [["E", 3.0, 5.0, 3.0, 5.0]],
	"R": [[[0.0, 10.0], [0.0, 0.0], [3.2, 0.0]], ["A", 3.2, 2.6, 2.6, 270.0, 450.0], [[3.2, 5.2], [0.0, 5.2]], [[2.6, 5.2], [5.8, 10.0]]],
}


const ADVANCE := 9.0                  # one glyph + its gap, in grid units


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
			var steps := 28
			for i in range(steps + 1):
				var t := deg_to_rad(lerpf(t0, t1, float(i) / steps))
				pts.append(Vector2(cx + rx * cos(t), cy + ry * sin(t)))
		else:
			for q in part:
				pts.append(Vector2(q[0], q[1]))
		out.append(pts)
	return out


## Width of `s` in the stroke type at `h` px tall (glyphs are 6 units wide + a 3-unit gap).
static func stroke_width(s: String, h: float) -> float:
	var u := h / 10.0
	return (s.length() * ADVANCE - 3.0) * u


static func draw_stroke_text(ci: CanvasItem, pos: Vector2, s: String, h: float, col: Color, w: float) -> void:
	var u := h / 10.0
	var x := pos.x
	for ch in s:
		for pts in _stroke_polys(ch):
			var tp := PackedVector2Array()
			for p in pts:
				tp.append(Vector2(x, pos.y) + p * u)
			ci.draw_polyline(tp, col, w, true)
		x += ADVANCE * u


func _screw(p: Vector2, metal: Color) -> void:
	draw_circle(p + Vector2(0.3, 0.4), 1.25, Color(0, 0, 0, 0.35))
	draw_circle(p, 1.15, metal.darkened(0.35))
	draw_circle(p + Vector2(-0.3, -0.3), 0.7, metal.lightened(0.35))
	draw_line(p + Vector2(-0.8, 0.5), p + Vector2(0.8, -0.5), metal.darkened(0.6), 0.45, true)


## The plate: a drop shadow on the wall, a bevelled metal frame (lit top-left, shadowed bottom-right),
## a brushed face, screws in the corners. Returns the inner face rect.
func _metal_plate(r: Rect2, metal: Color, face: Color) -> Rect2:
	draw_rect(Rect2(r.position + Vector2(1.2, 1.6), r.size), Color(0, 0, 0, 0.4))          # on the wall
	draw_rect(r, metal.darkened(0.55))                                                     # its edge
	var bev := r.grow(-0.6)
	draw_rect(bev, metal)
	var hi := metal.lightened(0.45)
	var lo := metal.darkened(0.4)
	draw_rect(Rect2(bev.position, Vector2(bev.size.x, 1.0)), hi)                           # the bevel
	draw_rect(Rect2(bev.position, Vector2(1.0, bev.size.y)), hi.darkened(0.08))
	draw_rect(Rect2(bev.position.x, bev.end.y - 1.0, bev.size.x, 1.0), lo)
	draw_rect(Rect2(bev.end.x - 1.0, bev.position.y, 1.0, bev.size.y), lo)
	var inner := bev.grow(-2.0)
	draw_rect(inner.grow(0.5), metal.darkened(0.3))                                        # the step down
	draw_rect(inner, face)
	var y := inner.position.y + 0.25                                                       # brushed
	var k := 0
	while y < inner.end.y:
		var t := 0.5 + 0.5 * sin(float(k) * 2.3) * cos(float(k) * 0.7)
		draw_rect(Rect2(inner.position.x, y, inner.size.x, 0.5), Color(1, 1, 1, 0.05 + 0.07 * t) if k % 2 == 0 else Color(0, 0, 0, 0.05 * t))
		y += 0.5
		k += 1
	draw_rect(Rect2(inner.position, Vector2(inner.size.x, inner.size.y * 0.4)), Color(1, 1, 1, 0.06))   # sheen
	for c in [bev.position + Vector2(2.4, 2.4), Vector2(bev.end.x - 2.4, bev.position.y + 2.4),
			Vector2(bev.position.x + 2.4, bev.end.y - 2.4), bev.end - Vector2(2.4, 2.4)]:
		_screw(c, metal)
	return inner


func _floor_number(cx: float) -> void:
	var num := floor_label(floor_num)
	var nh := 12.0                                        # the number's height
	var lh := 4.4                                         # "FLOOR"
	var nw := stroke_width(num, nh)
	var lw := stroke_width("FLOOR", lh)
	var w := roundf(maxf(nw, lw) + 14.0)
	var h := 32.0
	var r := Rect2(roundf(cx - w / 2.0), FLOOR_PLATE_Y - 8.0, w, h)
	var metal: Color
	var face: Color
	var ink: Color
	match section:
		"high":                                   # brushed brass, the type engraved
			metal = Color(0.66, 0.5, 0.24)
			face = Color(0.74, 0.58, 0.3)
			ink = Color(0.2, 0.13, 0.06)
		"mid":                                    # aluminium round a blue enamel panel, white type
			metal = Color(0.66, 0.68, 0.7)
			face = Color(0.16, 0.27, 0.5)
			ink = Color(0.95, 0.95, 0.92)
		_:                                        # bolted steel, black type, a hazard strip
			metal = Color(0.46, 0.48, 0.5)
			face = Color(0.8, 0.8, 0.76)
			ink = Color(0.1, 0.1, 0.11)
	var inner := _metal_plate(r, metal, face)
	var lx := roundf(cx - lw / 2.0)
	var ly := inner.position.y + 1.8
	var ny := ly + lh + 4.4
	if section == "low":                          # the hazard strip across the bottom of the face
		var sy := inner.end.y - 3.0
		draw_rect(Rect2(inner.position.x, sy, inner.size.x, 3.0), Color(0.88, 0.72, 0.14))
		var x := inner.position.x - 3.0
		while x < inner.end.x:
			var poly := PackedVector2Array([Vector2(x, sy + 3.0), Vector2(x + 1.6, sy + 3.0),
				Vector2(x + 3.1, sy), Vector2(x + 1.5, sy)])
			var clipped := PackedVector2Array()
			for p in poly:
				clipped.append(Vector2(clampf(p.x, inner.position.x, inner.end.x), p.y))
			draw_colored_polygon(clipped, Color(0.12, 0.12, 0.12))
			x += 3.2
		ny -= 1.2
	if section == "high":                         # engraved: a light lip under each cut
		draw_stroke_text(self, Vector2(lx, ly + 0.45), "FLOOR", lh, face.lightened(0.3), 0.75)
		draw_stroke_text(self, Vector2(roundf(cx - nw / 2.0), ny + 0.6), num, nh, face.lightened(0.3), 1.9)
	draw_stroke_text(self, Vector2(lx, ly), "FLOOR", lh, ink, 0.75)
	draw_stroke_text(self, Vector2(roundf(cx - nw / 2.0), ny), num, nh, ink, 1.9)


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
