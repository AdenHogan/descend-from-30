extends Node2D
# The drawn interior of the elevator car (used by elevator_interior.gd). A snug but
# not cramped car — roomy enough for the rider AND a future NPC without squeezing,
# keeping a believable elevator shape (not a spacious hall). Drawn in WORLD space
# centred on the origin so the manager's Camera2D frames it and RUMBLES the whole view
# (car + occupants) together. A dark shaft fills the screen around it.
#
# Motion (phase == "moving") is shown by soft, dim COOL light bands sweeping down/up the
# BACK WALL — passing-floor light washing through — plus the camera rumble and the
# ticking floor counter. (No bright side-wall bars; those read as tacky signage.)

const HALF_W := 96.0                 # interior 192 wide  (holds two without a squeeze)
const HALF_H := 80.0                 # interior 160 tall

var phase: String = "idle"          # "idle" | "moving" | "arriving"
var direction: int = -1             # -1 down, +1 up
var door_open: float = 0.0          # 0 closed .. 1 fully open (the manager tweens it on arrival)
var _sweep: float = 0.0             # scroll offset for the passing-floor light sweep

# Corridor tileset palette (sampled from Building_Floor Hallway.png) — the glimpse of
# hallway seen through the opening doors: a light tan wall over an orange banded
# wainscot with darker stripes.
const HALL_WALL := Color(0.89, 0.76, 0.59)     # tan wall  (#e4c396)
const HALL_WALL_HI := Color(0.95, 0.86, 0.66)  # lighter tan trim
const HALL_TRIM := Color(0.98, 0.92, 0.74)     # bright moulding line above the wainscot
const HALL_BAND := Color(0.80, 0.52, 0.14)     # orange wainscot  (#cd8521)
const HALL_STRIPE := Color(0.60, 0.29, 0.15)   # dark stripe / baseboard  (#994626)
const DOOR_COL := Color(0.23, 0.24, 0.27)


func _process(delta: float) -> void:
	if phase == "moving":
		_sweep += delta * 150.0
	queue_redraw()


func _draw() -> void:
	# Dark shaft/void filling the screen behind the car.
	draw_rect(Rect2(-4000, -4000, 8000, 8000), Color(0.03, 0.03, 0.04))

	var l := -HALF_W
	var r := HALF_W
	var t := -HALF_H
	var b := HALF_H
	var w := r - l
	var h := b - t

	# Car shell (metal walls).
	draw_rect(Rect2(l, t, w, h), Color(0.20, 0.21, 0.24))

	# Thin side walls (roomy interior).
	var sw := w * 0.09
	draw_rect(Rect2(l, t, sw, h), Color(0.15, 0.16, 0.19))
	draw_rect(Rect2(r - sw, t, sw, h), Color(0.15, 0.16, 0.19))

	# Back wall (lighter, inset for depth).
	var bl := l + sw
	var br := r - sw
	var bw := br - bl
	draw_rect(Rect2(bl, t + h * 0.03, bw, h * 0.9), Color(0.27, 0.28, 0.31))

	# Passing-floor light sweep on the back wall (behind everything else on it).
	if phase == "moving":
		_draw_sweep(bl, bw, t + h * 0.03, h * 0.9)

	# Ceiling light strip + a soft warm wash beneath it.
	draw_rect(Rect2(bl + bw * 0.30, t + h * 0.05, bw * 0.40, h * 0.035), Color(1.0, 0.95, 0.72))
	draw_rect(Rect2(bl, t + h * 0.085, bw, h * 0.11), Color(1.0, 0.9, 0.62, 0.05))

	# Doors on the back wall. Behind them is a glimpse of the hallway beyond (in the
	# corridor palette); the two panels slide apart by `door_open` to reveal it on arrival.
	var dtop := t + h * 0.28
	var dbot := b - h * 0.12
	var ddl := bl + bw * 0.16
	var ddw := bw * 0.68
	var dcx := ddl + ddw * 0.5
	var dh := dbot - dtop
	# The hallway seen through the opening (only worth drawing once the doors crack open).
	if door_open > 0.01:
		_draw_hallway(ddl, dtop, ddw, dh)
	# Two sliding panels; each tucks toward its side wall as the doors open.
	var slide := door_open * (ddw * 0.5)
	var half := ddw * 0.5
	draw_rect(Rect2(ddl - slide, dtop, half, dh), DOOR_COL)
	draw_rect(Rect2(dcx + slide, dtop, half, dh), DOOR_COL)
	draw_line(Vector2(ddl - slide, dtop), Vector2(ddl - slide, dbot), Color(0.12, 0.12, 0.14), 1.0)
	draw_line(Vector2(dcx + slide + half, dtop), Vector2(dcx + slide + half, dbot), Color(0.12, 0.12, 0.14), 1.0)
	if door_open < 0.03:
		draw_line(Vector2(dcx, dtop), Vector2(dcx, dbot), Color(0.09, 0.09, 0.11), 2.0)

	# Handrail across the back wall.
	var ry := dtop - h * 0.02
	draw_line(Vector2(bl + 6, ry), Vector2(br - 6, ry), Color(0.46, 0.48, 0.52), 2.0)

	# Floor plate (the occupants stand on this).
	draw_rect(Rect2(l, b - h * 0.10, w, h * 0.10), Color(0.12, 0.13, 0.15))


func _draw_hallway(x: float, y: float, w: float, hgt: float) -> void:
	# A brief glimpse of the corridor beyond the doors, matching the building tileset:
	# a light tan wall on top, a bright moulding line, then the orange wainscot band
	# with two darker stripes near the floor.
	var wall_h := hgt * 0.52
	var band_h := hgt - wall_h
	draw_rect(Rect2(x, y, w, wall_h), HALL_WALL)
	draw_rect(Rect2(x, y, w, hgt * 0.06), HALL_WALL_HI)               # lighter top trim
	draw_rect(Rect2(x, y + wall_h - 2.0, w, 2.0), HALL_TRIM)          # moulding above the band
	draw_rect(Rect2(x, y + wall_h, w, band_h), HALL_BAND)            # orange wainscot
	draw_rect(Rect2(x, y + wall_h + band_h * 0.36, w, 3.0), HALL_STRIPE)
	draw_rect(Rect2(x, y + hgt - 3.0, w, 3.0), HALL_STRIPE)          # baseboard at the floor


func _draw_sweep(x0: float, w: float, y0: float, span: float) -> void:
	# A couple of soft, dim, cool light bands drifting across the back wall — like the
	# car passing floor lights. Feathered (stacked low-alpha rects), no hard edges.
	var spacing := span * 0.75
	var scroll := _sweep if direction > 0 else -_sweep
	for i in range(3):
		var yy := y0 + fposmod(i * spacing + scroll, span + spacing) - spacing * 0.5
		for k in range(-5, 6):
			var a: float = 0.10 * (1.0 - absf(k) / 6.0)
			draw_rect(Rect2(x0, yy + k * 3.0, w, 3.0), Color(0.72, 0.8, 0.95, a))
