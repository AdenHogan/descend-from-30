extends Node2D
# The drawn interior of the elevator car (used by elevator_interior.gd). Drawn in
# WORLD space at a fixed design rect centred on the origin, so the manager's Camera2D
# can frame it and RUMBLE the whole view (car + the player standing inside) together —
# a self-contained little instance you ride in, Silksong-bench style. While
# `phase == "moving"` bright light bars stream past the side walls to sell the travel,
# their direction set by `direction` (+1 up / -1 down). There's headroom beside the
# player for a future NPC beat (the closed car is a free one-off encounter spot).

const HALF_W := 240.0
const HALF_H := 138.0

var phase: String = "idle"          # "idle" | "moving" | "arriving"
var direction: int = -1             # -1 down, +1 up
var _streak: float = 0.0            # scrolling offset for the motion bars


func _process(delta: float) -> void:
	if phase == "moving":
		_streak += delta * 300.0     # bar scroll speed
	queue_redraw()


func _draw() -> void:
	var l := -HALF_W
	var r := HALF_W
	var t := -HALF_H
	var b := HALF_H
	var w := r - l
	var h := b - t

	# Car shell (metal walls).
	draw_rect(Rect2(l, t, w, h), Color(0.20, 0.21, 0.24))

	# Side walls (darker) — the motion bars scroll on these.
	var sw := w * 0.16
	draw_rect(Rect2(l, t, sw, h), Color(0.14, 0.15, 0.18))
	draw_rect(Rect2(r - sw, t, sw, h), Color(0.14, 0.15, 0.18))

	# Back wall (lighter, inset for depth).
	var bl := l + sw
	var br := r - sw
	var bw := br - bl
	draw_rect(Rect2(bl, t + h * 0.03, bw, h * 0.9), Color(0.27, 0.28, 0.31))

	# Ceiling light panel + a soft warm wash beneath it.
	draw_rect(Rect2(bl + bw * 0.22, t + h * 0.05, bw * 0.56, h * 0.04), Color(1.0, 0.95, 0.72))
	draw_rect(Rect2(bl, t + h * 0.09, bw, h * 0.14), Color(1.0, 0.9, 0.62, 0.05))

	# Closed doors on the back wall (two panels + centre seam).
	var dtop := t + h * 0.34
	var dbot := b - h * 0.14
	var ddl := bl + bw * 0.15
	var ddw := bw * 0.70
	var dcx := ddl + ddw * 0.5
	draw_rect(Rect2(ddl, dtop, ddw, dbot - dtop), Color(0.23, 0.24, 0.27))
	draw_line(Vector2(dcx, dtop), Vector2(dcx, dbot), Color(0.09, 0.09, 0.11), 2.5)
	draw_line(Vector2(ddl, dtop), Vector2(ddl, dbot), Color(0.12, 0.12, 0.14), 1.5)
	draw_line(Vector2(ddl + ddw, dtop), Vector2(ddl + ddw, dbot), Color(0.12, 0.12, 0.14), 1.5)

	# Handrail across the back wall.
	var ry := dtop - h * 0.02
	draw_line(Vector2(bl + 8, ry), Vector2(br - 8, ry), Color(0.46, 0.48, 0.52), 3.0)

	# Floor plate (the player stands on this).
	draw_rect(Rect2(l, b - h * 0.10, w, h * 0.10), Color(0.12, 0.13, 0.15))

	# Motion: bright bars streaming past the side walls (parallax = opposite the travel).
	if phase == "moving":
		_draw_streaks(l, sw, t, h)
		_draw_streaks(r - sw, sw, t, h)


func _draw_streaks(x0: float, w: float, y0: float, span: float) -> void:
	# Evenly spaced glowing bars scrolling along a side wall. Going UP the bars fall
	# (floor lights slide down as you rise); going DOWN they rise.
	var spacing := 78.0
	var n := int(span / spacing) + 2
	var scroll := _streak if direction > 0 else -_streak
	for i in range(n):
		var yy := y0 + fposmod(i * spacing + scroll, span)
		# A soft outer glow, a warm bar, then a hot core — a rushing light passing by.
		draw_rect(Rect2(x0 + w * 0.16, yy - 3, w * 0.68, 20.0), Color(1.0, 0.9, 0.5, 0.16))
		draw_rect(Rect2(x0 + w * 0.24, yy, w * 0.52, 14.0), Color(1.0, 0.93, 0.6, 0.7))
		draw_rect(Rect2(x0 + w * 0.24, yy + 4, w * 0.52, 5.0), Color(1.0, 1.0, 0.92, 0.92))
