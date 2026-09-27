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


## Where the signs + door plates sit, in the corridor art's LOCAL space (world − (115, 243)), so the
## per-floor decals (corridor_decals.plan) never paint over them.
static func taken_local() -> Array:
	var out: Array = [Rect2(12, 12, 88, 26), Rect2(1020, 12, 88, 26),     # the STAIRS signs
		Rect2(112, 32, 38, 40), Rect2(966, 32, 38, 40),                      # the floor numbers
		Rect2(898, 48, 34, 16)]                                               # the lift indicator
	for d in [201, 329, 455, 581, 714]:                                       # every door's plate
		out.append(Rect2(d - 50, 90, 26, 18))
	out.append(Rect2(814 - 56, 90, 32, 18))                                   # the maintenance door's (STAFF is wider)
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


func _floor_number(cx: float) -> void:
	var num := floor_label(floor_num)
	var scale := 3
	var w := text_width(num, scale)
	var x := roundf(cx - w / 2.0)
	match section:
		"high":                                    # a brass plaque on the wall, FLOOR over the number
			var r := Rect2(x - 5, FLOOR_PLATE_Y - 9, w + 10, 15 + 14)
			draw_rect(r.grow(1), Color(0.24, 0.16, 0.08))
			draw_rect(r, Color(0.72, 0.56, 0.26))
			draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1), Color(0.88, 0.74, 0.42))
			draw_text(self, Vector2(roundf(cx - text_width("FLOOR") / 2.0), r.position.y + 2), "FLOOR", Color(0.28, 0.18, 0.08))
			draw_text(self, Vector2(x, FLOOR_PLATE_Y), num, Color(0.28, 0.18, 0.08), scale)
		"mid":                                     # an enamel plate, blue on white
			var r := Rect2(x - 4, FLOOR_PLATE_Y - 9, w + 8, 15 + 13)
			draw_rect(r.grow(1), Color(0.2, 0.26, 0.4))
			draw_rect(r, Color(0.92, 0.92, 0.88))
			draw_text(self, Vector2(roundf(cx - text_width("FLOOR") / 2.0), r.position.y + 2), "FLOOR", Color(0.2, 0.3, 0.55))
			draw_text(self, Vector2(x, FLOOR_PLATE_Y), num, Color(0.16, 0.26, 0.52), scale)
		_:                                         # stencilled straight on the wall, a stripe under it
			draw_text(self, Vector2(x, FLOOR_PLATE_Y - 2), num, Color(0.12, 0.12, 0.12, 0.9), scale + 1)
			var sw := text_width(num, scale + 1)
			var y := FLOOR_PLATE_Y - 2 + 5 * (scale + 1) + 2
			for i in range(0, sw + 4, 4):          # yellow-black hazard stripe
				draw_rect(Rect2(x - 2 + i, y, 2, 3), Color(0.86, 0.72, 0.16, 0.9))
				draw_rect(Rect2(x + i, y, 2, 3), Color(0.12, 0.12, 0.12, 0.9))


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
