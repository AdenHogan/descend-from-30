extends Node2D

# Diegetic tutorial text scrawled on the walls in blood (Floor 30, first run).
# A styled Label plus procedurally drawn drips so it reads as hand-smeared
# rather than a UI popup. Call setup() before adding to the tree.

const BLOOD = Color(0.52, 0.05, 0.04, 1.0)
const BLOOD_DARK = Color(0.20, 0.01, 0.01, 1.0)
const DRIP = Color(0.42, 0.03, 0.02, 0.92)

var text: String = ""
var font_size: int = 20
var _label: Label = null
var _drips: Array = []
var _width: float = 0.0


func setup(t: String, size: int = 20) -> void:
	text = t
	font_size = size


func _ready() -> void:
	z_index = 1
	var font = load("res://assets/fonts/PixelOperator8-Bold.ttf")
	_label = Label.new()
	_label.text = text
	if font != null:
		_label.add_theme_font_override("font", font)
	_label.add_theme_font_size_override("font_size", font_size)
	_label.add_theme_color_override("font_color", BLOOD)
	_label.add_theme_color_override("font_outline_color", BLOOD_DARK)
	_label.add_theme_constant_override("outline_size", 4)
	# Slight hand-scrawled tilt, seeded off the text so it's stable per hint.
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(text)
	_label.rotation = deg_to_rad(rng.randf_range(-2.5, 2.5))
	_label.position = Vector2.ZERO
	add_child(_label)
	await get_tree().process_frame
	_width = _label.size.x
	# Drips fall from under the letters — a few long, several short.
	var count = max(2, int(_width / 45.0))
	for i in range(count):
		_drips.append({
			"x": rng.randf() * _width,
			"len": rng.randf_range(5.0, 30.0) if rng.randf() < 0.4 else rng.randf_range(3.0, 10.0),
			"wd": rng.randf_range(1.5, 3.2),
		})
	queue_redraw()


func _draw() -> void:
	var base_y = float(font_size) * 1.0
	for d in _drips:
		var start = Vector2(d["x"], base_y)
		var end = Vector2(d["x"], base_y + d["len"])
		draw_line(start, end, DRIP, d["wd"])
		draw_circle(end, d["wd"] * 0.85, DRIP)  # bead at the tip
