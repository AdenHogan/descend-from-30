extends Control

# One on-screen control: a round button, a pill (the mode switch) or the thumb-stick's base (touch_overlay.gd owns the touches).
# It is a real Control in the `hud_widget_extra` group, so `HUD.pointer_over_widget` is true over it and a tap
# on a button never also walks / swings in the world; mouse_filter STOP keeps the emulated click from reaching it.

var kind: String = "button"             # "button" | "stick"
var action: String = ""
var label: String = ""
var sub_label: String = ""              # a smaller second line (the pill: what a tap does)
var centre: Vector2 = Vector2.ZERO
var radius: float = 30.0
var half_w: float = 0.0                 # > radius = a PILL that wide (half-width), `radius` tall
var hold: bool = false
var context: String = "always"          # when it shows: "always" | "primary" | "prompt" | "combat" (touch_overlay decides)
var tint: Color = Color(0.89, 0.647, 0.247)   # the rim colour: amber by default, the stance colour on the mode / attack buttons
var pulse: bool = false                 # a teaching beat is waiting for THIS button: breathe so it can't be missed
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


## Make this button a pill: `hw` is its half-width, the setup radius its half-height.
func make_pill(hw: float) -> void:
	half_w = hw
	position = centre - Vector2(hw, radius)
	size = Vector2(hw, radius) * 2.0


func is_pill() -> bool:
	return half_w > radius


func contains(pos: Vector2) -> bool:
	# a touch that lands a little outside the drawn disc still counts — thumbs are not pixel-exact
	if is_pill():
		return Rect2(centre - Vector2(half_w, radius), Vector2(half_w, radius) * 2.0).grow(8.0).has_point(pos)
	return pos.distance_to(centre) <= radius + (10.0 if kind == "button" else 0.0)


func _draw() -> void:
	var c := size * 0.5
	var down: bool = pressed_now
	if kind == "stick":
		_draw_stick(c, down)
		return
	if pulse:
		var k: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 6.0)
		if is_pill():
			draw_rect(Rect2(Vector2.ZERO, size).grow(5.0 * k), Color(0.95, 0.7, 0.25, 0.25 + 0.25 * k), false, 3.0)
		else:
			draw_circle(c, radius * (1.0 + 0.12 * k), Color(0.95, 0.7, 0.25, 0.25 + 0.25 * k))
	var fill := Color(tint.r * 0.55, tint.g * 0.45, tint.b * 0.35, 0.62) if down else Color(tint.r * 0.16, tint.g * 0.16, tint.b * 0.16, 0.55)
	var rim := Color(tint.r, tint.g, tint.b, 0.95 if down else 0.8)
	if is_pill():
		var box := StyleBoxFlat.new()
		box.bg_color = fill
		box.border_color = rim
		box.set_border_width_all(3)
		box.set_corner_radius_all(int(radius))
		draw_style_box(box, Rect2(Vector2.ZERO, size))
	else:
		draw_circle(c, radius, fill)
		draw_arc(c, radius - 1.5, 0.0, TAU, 40, rim, 3.0 if radius >= 38.0 else 2.0, true)
	if _font == null or label == "":
		return
	var fs: int = 12 if radius >= 38.0 else (10 if radius >= 30.0 else 8)
	if is_pill():
		fs = 10
	elif label.length() > 4:
		fs = mini(fs, 8)
	if not is_pill() and label.length() > 5:
		fs = 7
	var col := Color(0.96, 0.93, 0.86, 0.95)
	if is_pill():
		col = Color(minf(tint.r + 0.25, 1.0), minf(tint.g + 0.25, 1.0), minf(tint.b + 0.25, 1.0), 1.0)
	var w: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var dy: float = fs * 0.4
	if sub_label != "":
		dy = -2.0
	draw_string(_font, Vector2(c.x - w * 0.5, c.y + dy), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	if sub_label != "":
		var sw: float = _font.get_string_size(sub_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		draw_string(_font, Vector2(c.x - sw * 0.5, c.y + 13.0), sub_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.85, 0.82, 0.74, 0.8))


func _draw_stick(c: Vector2, down: bool) -> void:
	draw_circle(c, radius, Color(0.05, 0.05, 0.06, 0.38))
	draw_arc(c, radius - 1.0, 0.0, TAU, 48, Color(0.89, 0.647, 0.247, 0.55), 2.0, true)
	var ov = get_parent()
	var raw: Vector2 = ov.stick_raw if ov != null and "stick_raw" in ov else Vector2.ZERO
	var run: bool = ov != null and "sprinting" in ov and ov.sprinting
	var crouched: bool = ov != null and "crouch_hint" in ov and ov.crouch_hint
	# the RUN ring sits OUTSIDE the base: the thumb has to be pushed past the rim on purpose to sprint (it lights while you do)
	var rr: float = radius * float(ov.STICK_SPRINT_ON) if ov != null and "STICK_SPRINT_ON" in ov else radius * 1.3
	var segs := 36
	for i in range(0, segs, 2):
		var a0: float = TAU * float(i) / segs
		draw_arc(c, rr, a0, a0 + TAU / segs * 0.7, 4, Color(1.0, 0.82, 0.4, 0.85 if run else 0.26), 2.0, true)
	# the DUCK marks: a chevron at the bottom (push there to crouch) and one at the top (back up to stand), lit for the state
	var ccol := Color(1.0, 0.82, 0.4, 0.9) if crouched else Color(1.0, 0.82, 0.4, 0.32)
	var ucol := Color(1.0, 0.82, 0.4, 0.32) if crouched else Color(1.0, 0.82, 0.4, 0.12)
	var d: float = radius * 0.78
	draw_polyline(PackedVector2Array([c + Vector2(-9, d - 5), c + Vector2(0, d + 3), c + Vector2(9, d - 5)]), ccol, 3.0, true)
	draw_polyline(PackedVector2Array([c + Vector2(-9, -d + 5), c + Vector2(0, -d - 3), c + Vector2(9, -d + 5)]), ucol, 3.0, true)
	var kp: Vector2 = c + raw.limit_length(1.5) * radius
	draw_circle(kp, radius * 0.34, Color(1.0, 0.78, 0.3, 0.8) if run else Color(0.89, 0.647, 0.247, 0.55 if down else 0.38))
