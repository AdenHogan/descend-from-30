extends Control

# Procedural bloody handprint + drips for the title card (no art asset needed).
# Drawn behind the title text: a smeared palm + splayed fingers with spatter
# and a few drips, plus a row of drips hanging under the title line. All
# positions are tunable exports so the look can be nudged in-editor.

@export var palm_center := Vector2(805, 340)   # behind the "30"
@export var hand_scale := 1.35
@export var drip_baseline_y := 272.0           # just under the title text
@export var band_left := 315.0
@export var band_right := 885.0
@export var blood := Color(0.34, 0.0, 0.0, 0.9)

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rng.seed = 20250723
	queue_redraw()


func _draw() -> void:
	_draw_handprint(palm_center, hand_scale)
	_draw_title_drips(drip_baseline_y, band_left, band_right)


func _shade(a_mult: float) -> Color:
	return Color(blood.r, blood.g, blood.b, blood.a * a_mult)


func _draw_handprint(c: Vector2, s: float) -> void:
	# Palm: overlapping blobs so the edge reads as a smear, not a clean circle.
	draw_circle(c + Vector2(0, 8) * s, 54 * s, blood)
	draw_circle(c + Vector2(0, 44) * s, 46 * s, blood)      # heel
	draw_circle(c + Vector2(-32, 2) * s, 31 * s, blood)
	draw_circle(c + Vector2(32, 2) * s, 31 * s, blood)

	# Four fingers fanning upward (index → pinky), tapered with a rounded tip.
	var fingers = [
		{"base": Vector2(-42, -28), "tip": Vector2(-70, -122), "w": 21.0},
		{"base": Vector2(-15, -40), "tip": Vector2(-22, -150), "w": 23.0},
		{"base": Vector2(16, -40), "tip": Vector2(26, -140), "w": 23.0},
		{"base": Vector2(42, -28), "tip": Vector2(72, -112), "w": 20.0},
	]
	for f in fingers:
		var b = c + f["base"] * s
		var t = c + f["tip"] * s
		draw_line(b, t, blood, f["w"] * s)
		draw_circle(t, f["w"] * 0.5 * s, blood)
	# Thumb, splayed to the LEFT (tucks behind the title; makes a coherent hand).
	draw_line(c + Vector2(-50, 18) * s, c + Vector2(-126, -26) * s, blood, 22 * s)
	draw_circle(c + Vector2(-126, -26) * s, 11 * s, blood)

	# Spatter around the print.
	for i in range(16):
		var ang = _rng.randf() * TAU
		var r = _rng.randf_range(70, 165) * s
		draw_circle(c + Vector2.from_angle(ang) * r, _rng.randf_range(2, 7) * s, _shade(_rng.randf_range(0.35, 0.8)))
	# Drips off the heel of the palm.
	for i in range(4):
		var top = c + Vector2(_rng.randf_range(-42, 42) * s, 62 * s)
		var dl = _rng.randf_range(34, 96) * s
		draw_line(top, top + Vector2(0, dl), blood, _rng.randf_range(3, 6) * s)
		draw_circle(top + Vector2(0, dl), _rng.randf_range(4, 7) * s, blood)


func _draw_title_drips(y: float, x0: float, x1: float) -> void:
	# A row of blood running off the title letters.
	var n = 10
	for i in range(n):
		var x = lerpf(x0, x1, float(i) / float(n - 1)) + _rng.randf_range(-14, 14)
		var dl = _rng.randf_range(12, 58)
		var w = _rng.randf_range(3, 6)
		draw_line(Vector2(x, y), Vector2(x, y + dl), blood, w)
		draw_circle(Vector2(x, y + dl), w * 0.7 + 1.0, blood)
