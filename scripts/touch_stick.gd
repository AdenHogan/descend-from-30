extends Control

# One on-screen control: a round button or the thumb-stick's base (touch_overlay.gd owns the touches).
# It is a real Control in the `hud_widget_extra` group, so `HUD.pointer_over_widget` is true over it and a tap
# on a button never also walks / swings in the world; mouse_filter STOP keeps the emulated click from reaching it.

var kind: String = "button"             # "button" | "stick"
var action: String = ""
var label: String = ""
var centre: Vector2 = Vector2.ZERO
var radius: float = 30.0
var hold: bool = false
var pressed_now: bool = false

var _font: Font = null


func setup(what: String, text: String, at: Vector2, r: float) -> void:
	kind = "stick" if what == "stick" else "button"
	action = what if kind == "button" else ""
	label = text
	centre = at
	radius = r
	position = at - Vector2(r, r)
	size = Vector2(r, r) * 2.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group("hud_widget_extra")
	_font = load("res://assets/fonts/PixelOperator8-Bold.ttf")


func contains(pos: Vector2) -> bool:
	# a touch that lands a little outside the drawn disc still counts — thumbs are not pixel-exact
	return pos.distance_to(centre) <= radius + (10.0 if kind == "button" else 0.0)


func _draw() -> void:
	var c := size * 0.5
	var down: bool = pressed_now
	if kind == "stick":
		draw_circle(c, radius, Color(0.05, 0.05, 0.06, 0.38))
		draw_arc(c, radius - 1.0, 0.0, TAU, 48, Color(0.89, 0.647, 0.247, 0.55), 2.0, true)
		var ov = get_parent()
		var v: Vector2 = ov.stick_vec if ov != null and "stick_vec" in ov else Vector2.ZERO
		draw_circle(c + v * radius * 0.55, radius * 0.38, Color(0.89, 0.647, 0.247, 0.55 if down else 0.38))
		return
	draw_circle(c, radius, Color(0.9, 0.55, 0.2, 0.55) if down else Color(0.05, 0.05, 0.06, 0.42))
	draw_arc(c, radius - 1.0, 0.0, TAU, 40, Color(0.89, 0.647, 0.247, 0.9 if down else 0.6), 2.0, true)
	if _font != null and label != "":
		var fs: int = 11 if radius >= 30.0 else 8
		if label.length() > 5:
			fs = 7
		var w: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(_font, Vector2(c.x - w * 0.5, c.y + fs * 0.4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.96, 0.93, 0.86, 0.95))
