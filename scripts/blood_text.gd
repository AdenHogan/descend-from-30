@tool
extends Node2D
class_name BloodText

# Diegetic tutorial text scrawled in blood on the walls (Floor 30, first run).
# @tool so it renders live in the editor — drop a BloodText node into a scene,
# type the message and set the size/tilt in the Inspector, and drag it exactly
# where you want it on the wall. Draws the text + procedural drips itself (no
# child nodes), so what you see in the editor is what ships.

const BLOOD = Color(0.52, 0.05, 0.04, 1.0)
const BLOOD_DARK = Color(0.14, 0.01, 0.01, 1.0)
const DRIP = Color(0.42, 0.03, 0.02, 0.92)

@export_multiline var text: String = "THEY ARE HERE":
	set(v):
		text = v
		queue_redraw()
@export var font_size: int = 22:
	set(v):
		font_size = max(1, v)
		queue_redraw()
@export_range(0.0, 1.0) var drip_density: float = 1.0:
	set(v):
		drip_density = v
		queue_redraw()

var _font: Font = null


func _ready() -> void:
	z_index = 1  # actor/foreground scrawl sits above the wall backdrop
	queue_redraw()


func _get_font() -> Font:
	if _font == null:
		_font = load("res://assets/fonts/PixelOperator8-Bold.ttf")
	return _font


func _draw() -> void:
	var font = _get_font()
	if font == null or text == "":
		return
	var baseline = Vector2(0, font_size)
	# Heavy dark outline first, blood-red fill on top.
	draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, BLOOD_DARK)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, BLOOD)

	# Drips fall from just under the letters; seeded off the text so they stay
	# put between redraws instead of crawling around while you edit.
	var width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(text)
	var count = int(max(2.0, width / 45.0) * drip_density)
	var base_y = float(font_size) + 2.0
	for i in range(count):
		var x = rng.randf() * width
		var length = rng.randf_range(5.0, 30.0) if rng.randf() < 0.4 else rng.randf_range(3.0, 10.0)
		var wd = rng.randf_range(1.5, 3.2)
		draw_line(Vector2(x, base_y), Vector2(x, base_y + length), DRIP, wd)
		draw_circle(Vector2(x, base_y + length), wd * 0.85, DRIP)
