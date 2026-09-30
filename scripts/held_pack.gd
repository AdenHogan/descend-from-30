extends Node2D

# The player's BACKPACK, laid on the floor beside them while they kneel to it (docs/BACKPACK.md) — a
# placeholder drawn in code until there is real art (the kneel + open animation itself is an art task).
# A child of the player at the FEET line (local y = feet), a few px in front; the player drives
# `set_open` from the kneel and calls `close()` on the stand-up. Cosmetic: no collision, never lit
# specially, frees itself with the player.

var direction: float = 1.0          # +1 the player faces right (the pack lies on that side)
var open_amount: float = 0.0        # 0 shut .. 1 flap thrown back, mouth open
var _closing: bool = false

const BODY := Color(0.30, 0.34, 0.22)
const BODY_DARK := Color(0.20, 0.23, 0.15)
const BODY_LIGHT := Color(0.40, 0.45, 0.29)
const STRAP := Color(0.14, 0.12, 0.10)
const BUCKLE := Color(0.78, 0.66, 0.30)
const MOUTH := Color(0.05, 0.045, 0.05)


func _ready() -> void:
	z_index = 1                     # in front of the body (the player is z 1 itself)
	scale.x = -1.0 if direction < 0.0 else 1.0


func set_open(v: float) -> void:
	if _closing:
		return
	open_amount = clampf(v, 0.0, 1.0)
	queue_redraw()


func close() -> void:
	_closing = true
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		open_amount = v
		queue_redraw(), open_amount, 0.0, 0.22)


func _draw() -> void:
	# Origin = where the pack meets the floor, centre-bottom. ~18 wide, ~15 tall when shut.
	var w := 18.0
	var h := 15.0
	# soft floor shadow
	draw_rect(Rect2(-w * 0.5 - 1.0, -1.0, w + 2.0, 2.0), Color(0, 0, 0, 0.35))
	# the bag body, a rounded-ish block
	draw_rect(Rect2(-w * 0.5, -h, w, h - 1.0), BODY)
	draw_rect(Rect2(-w * 0.5, -h + 2.0, 2.0, h - 4.0), BODY_LIGHT)
	draw_rect(Rect2(w * 0.5 - 2.0, -h + 2.0, 2.0, h - 4.0), BODY_DARK)
	draw_rect(Rect2(-w * 0.5 + 2.0, -h - 1.0, w - 4.0, 1.0), BODY)
	# front pocket
	draw_rect(Rect2(-w * 0.5 + 3.0, -7.0, w - 6.0, 5.0), BODY_DARK)
	draw_rect(Rect2(-w * 0.5 + 3.0, -7.0, w - 6.0, 1.0), BODY_LIGHT)
	# the mouth, opening as the flap lifts
	var mouth_h: float = 4.0 * open_amount
	if mouth_h > 0.4:
		draw_rect(Rect2(-w * 0.5 + 2.0, -h - 1.0, w - 4.0, mouth_h + 1.0), MOUTH)
		# a glimpse of what's inside: a bandage roll and a can
		if open_amount > 0.6:
			draw_rect(Rect2(-5.0, -h - 3.0, 4.0, 3.0), Color(0.86, 0.82, 0.72))
			draw_rect(Rect2(1.0, -h - 4.0, 3.0, 4.0), Color(0.62, 0.30, 0.22))
	# the flap: lies over the top when shut, hinges back and up when open
	var hinge_y: float = -h - 1.0
	var lift: float = open_amount * 9.0
	var fl_w := w - 2.0
	var top_l := Vector2(-fl_w * 0.5, hinge_y - lift * 0.4)
	var top_r := Vector2(fl_w * 0.5, hinge_y - lift * 0.4)
	var bot_l := Vector2(-fl_w * 0.5, hinge_y + 6.0 * (1.0 - open_amount) - lift)
	var bot_r := Vector2(fl_w * 0.5, hinge_y + 6.0 * (1.0 - open_amount) - lift)
	draw_colored_polygon(PackedVector2Array([top_l, top_r, bot_r, bot_l]), BODY_LIGHT if open_amount > 0.5 else BODY_DARK)
	# buckle strap
	if open_amount < 0.5:
		draw_rect(Rect2(-1.0, hinge_y + 1.0, 2.0, 6.0), STRAP)
		draw_rect(Rect2(-1.5, hinge_y + 5.0, 3.0, 2.0), BUCKLE)
	else:
		draw_rect(Rect2(-1.0, hinge_y - lift, 2.0, 3.0), STRAP)
