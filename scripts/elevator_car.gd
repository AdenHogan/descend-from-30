extends Node2D
# The drawn interior of the elevator car (used by elevator_interior.gd). Sized to the
# real corridor elevator doors (Elevator.png ~63x89 on-screen) — a CRAMPED portrait
# box just a bit wider and taller than the doors, NOT a spacious room. Drawn in WORLD
# space centred on the origin so the manager's Camera2D frames it and RUMBLES the whole
# view (car + rider) together. A dark shaft fills the screen around the narrow car.
# While `phase == "moving"` bright light bars stream past the side walls to sell travel,
# their direction set by `direction` (+1 up / -1 down).

const HALF_W := 58.0                 # interior 116 wide  (corridor doors are ~63)
const HALF_H := 80.0                 # interior 160 tall  (corridor doors are ~89)

var phase: String = "idle"          # "idle" | "moving" | "arriving"
var direction: int = -1             # -1 down, +1 up
var _streak: float = 0.0            # scrolling offset for the motion bars


func _process(delta: float) -> void:
	if phase == "moving":
		_streak += delta * 190.0     # bar scroll speed
	queue_redraw()


func _draw() -> void:
	# Dark shaft/void filling the screen behind the narrow car.
	draw_rect(Rect2(-4000, -4000, 8000, 8000), Color(0.03, 0.03, 0.04))

	var l := -HALF_W
	var r := HALF_W
	var t := -HALF_H
	var b := HALF_H
	var w := r - l
	var h := b - t

	# Car shell (metal walls).
	draw_rect(Rect2(l, t, w, h), Color(0.20, 0.21, 0.24))

	# Side walls (darker) — the motion bars scroll on these.
	var sw := w * 0.15
	draw_rect(Rect2(l, t, sw, h), Color(0.14, 0.15, 0.18))
	draw_rect(Rect2(r - sw, t, sw, h), Color(0.14, 0.15, 0.18))

	# Back wall (lighter, inset for depth).
	var bl := l + sw
	var br := r - sw
	var bw := br - bl
	draw_rect(Rect2(bl, t + h * 0.03, bw, h * 0.9), Color(0.27, 0.28, 0.31))

	# Ceiling light strip + a soft warm wash beneath it.
	draw_rect(Rect2(bl + bw * 0.24, t + h * 0.05, bw * 0.52, h * 0.035), Color(1.0, 0.95, 0.72))
	draw_rect(Rect2(bl, t + h * 0.085, bw, h * 0.11), Color(1.0, 0.9, 0.62, 0.06))

	# Closed doors on the back wall (~door-sized: two panels + centre seam).
	var dtop := t + h * 0.28
	var dbot := b - h * 0.12
	var ddl := bl + bw * 0.10
	var ddw := bw * 0.80
	var dcx := ddl + ddw * 0.5
	draw_rect(Rect2(ddl, dtop, ddw, dbot - dtop), Color(0.23, 0.24, 0.27))
	draw_line(Vector2(dcx, dtop), Vector2(dcx, dbot), Color(0.09, 0.09, 0.11), 2.0)
	draw_line(Vector2(ddl, dtop), Vector2(ddl, dbot), Color(0.12, 0.12, 0.14), 1.0)
	draw_line(Vector2(ddl + ddw, dtop), Vector2(ddl + ddw, dbot), Color(0.12, 0.12, 0.14), 1.0)

	# Handrail across the back wall.
	var ry := dtop - h * 0.02
	draw_line(Vector2(bl + 5, ry), Vector2(br - 5, ry), Color(0.46, 0.48, 0.52), 2.0)

	# Floor plate (the rider stands on this).
	draw_rect(Rect2(l, b - h * 0.10, w, h * 0.10), Color(0.12, 0.13, 0.15))

	# Motion: bright bars streaming past the side walls (parallax = opposite the travel).
	if phase == "moving":
		_draw_streaks(l, sw, t, h)
		_draw_streaks(r - sw, sw, t, h)


func _draw_streaks(x0: float, w: float, y0: float, span: float) -> void:
	# Evenly spaced glowing bars scrolling along a side wall. Going UP the bars fall
	# (floor lights slide down as you rise); going DOWN they rise.
	var spacing := 34.0
	var n := int(span / spacing) + 2
	var scroll := _streak if direction > 0 else -_streak
	for i in range(n):
		var yy := y0 + fposmod(i * spacing + scroll, span)
		draw_rect(Rect2(x0 + w * 0.14, yy - 1, w * 0.72, 8.0), Color(1.0, 0.9, 0.5, 0.18))
		draw_rect(Rect2(x0 + w * 0.22, yy, w * 0.56, 6.0), Color(1.0, 0.93, 0.6, 0.75))
		draw_rect(Rect2(x0 + w * 0.22, yy + 2, w * 0.56, 2.0), Color(1.0, 1.0, 0.92, 0.95))
