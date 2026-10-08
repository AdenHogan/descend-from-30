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
	_fit()
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group("hud_widget_extra")
	_font = load("res://assets/fonts/PixelOperator8-Bold.ttf")


## Make this button a pill: `hw` is its half-width, the setup radius its half-height.
func make_pill(hw: float) -> void:
	half_w = hw
	_fit()


## Move the widget (the prompt buttons take the next free slot in the thumb's arc — touch_overlay.PROMPT_SLOTS).
func set_centre(at: Vector2) -> void:
	centre = at
	_fit()


## The Control covers the drawn shape PLUS its hit slop, so the emulated mouse click of a near-miss is swallowed too (it would otherwise
## walk the player to wherever the thumb landed beside the button).
func _fit() -> void:
	var pad: float = HIT_SLOP if kind == "button" else STICK_SLOP
	var half := (Vector2(half_w, radius) if is_pill() else Vector2(radius, radius)) + Vector2(pad, pad)
	position = centre - half
	size = half * 2.0


func is_pill() -> bool:
	return half_w > radius


## How far `pos` is OUTSIDE the drawn shape (0 inside) — what a near-miss is measured by.
func edge_distance(pos: Vector2) -> float:
	if is_pill():                                       # a stadium: the middle segment, grown by the radius
		var dx: float = maxf(absf(pos.x - centre.x) - (half_w - radius), 0.0)
		return maxf(Vector2(dx, absf(pos.y - centre.y)).length() - radius, 0.0)
	return maxf(pos.distance_to(centre) - radius, 0.0)


## A touch that lands a little outside the drawn shape still counts — thumbs are not pixel-exact (owner round 37: "they don't always
## feel responsive to touch"): the buttons take a generous HIT_SLOP, the stick STICK_SLOP (it is hit with a thumb that has been somewhere
## else a moment ago). `touch_overlay` additionally snaps a near-miss to the NEAREST button (SNAP_DIST).
const HIT_SLOP := 26.0
const STICK_SLOP := 30.0


func contains(pos: Vector2) -> bool:
	return edge_distance(pos) <= (HIT_SLOP if kind == "button" else STICK_SLOP)


func _draw() -> void:
	var c := size * 0.5
	var down: bool = pressed_now
	if kind == "stick":
		_draw_stick(c, down)
		return
	if pulse:
		var k: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 6.0)
		if is_pill():
			draw_rect(Rect2(c - Vector2(half_w, radius), Vector2(half_w, radius) * 2.0).grow(5.0 * k), Color(0.95, 0.7, 0.25, 0.25 + 0.25 * k), false, 3.0)
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
		draw_style_box(box, Rect2(c - Vector2(half_w, radius), Vector2(half_w, radius) * 2.0))
	else:
		draw_circle(c, radius, fill)
		draw_arc(c, radius - 1.5, 0.0, TAU, 48, rim, 4.0 if radius >= 60.0 else 3.0, true)
	if _font == null or label == "":
		return
	var fs: int = 16 if radius >= 60.0 else (12 if radius >= 40.0 else 10)
	if is_pill():
		fs = 12
	elif label.length() > 4:
		fs = mini(fs, 16 if radius >= 60.0 else 12)
	if not is_pill() and label.length() > 6:
		fs = mini(fs, 10 if radius >= 40.0 else 8)
	var col := Color(0.96, 0.93, 0.86, 0.95)
	if is_pill():
		col = Color(minf(tint.r + 0.25, 1.0), minf(tint.g + 0.25, 1.0), minf(tint.b + 0.25, 1.0), 1.0)
	var w: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var dy: float = fs * 0.4
	if sub_label != "":
		dy = -3.0
	draw_string(_font, Vector2(c.x - w * 0.5, c.y + dy), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	if sub_label != "":
		var sw: float = _font.get_string_size(sub_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
		draw_string(_font, Vector2(c.x - sw * 0.5, c.y + 15.0), sub_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.85, 0.82, 0.74, 0.8))


func _draw_stick(c: Vector2, down: bool) -> void:
	# Faint while nobody holds it (owner round 37: on even floors the down staircase is bottom-LEFT, right under this base — it must not
	# hide the steps or the character), strong once a thumb is on it.
	draw_circle(c, radius, Color(0.05, 0.05, 0.06, 0.34 if down else 0.14))
	draw_arc(c, radius - 1.0, 0.0, TAU, 48, Color(0.89, 0.647, 0.247, 0.7 if down else 0.3), 3.0, true)
	var ov = get_parent()
	var raw: Vector2 = ov.stick_raw if ov != null and "stick_raw" in ov else Vector2.ZERO
	var run: bool = ov != null and "sprinting" in ov and ov.sprinting
	var crouched: bool = ov != null and "crouch_hint" in ov and ov.crouch_hint
	# the RUN ring sits OUTSIDE the base: the thumb has to be pushed past the rim on purpose to sprint (it lights while you do)
	var rr: float = radius * float(ov.STICK_SPRINT_ON) if ov != null and "STICK_SPRINT_ON" in ov else radius * 1.3
	var segs := 36
	for i in range(0, segs, 2):
		var a0: float = TAU * float(i) / segs
		draw_arc(c, rr, a0, a0 + TAU / segs * 0.7, 4, Color(1.0, 0.82, 0.4, 0.85 if run else (0.26 if down else 0.12)), 2.0, true)
	# the DUCK marks: a chevron at the bottom (push there to crouch) and one at the top (back up to stand), lit for the state
	var ccol := Color(1.0, 0.82, 0.4, 0.9) if crouched else Color(1.0, 0.82, 0.4, 0.32 if down else 0.18)
	var ucol := Color(1.0, 0.82, 0.4, 0.32) if crouched else Color(1.0, 0.82, 0.4, 0.12 if down else 0.06)
	var d: float = radius * 0.78
	draw_polyline(PackedVector2Array([c + Vector2(-9, d - 5), c + Vector2(0, d + 3), c + Vector2(9, d - 5)]), ccol, 3.0, true)
	draw_polyline(PackedVector2Array([c + Vector2(-9, -d + 5), c + Vector2(0, -d - 3), c + Vector2(9, -d + 5)]), ucol, 3.0, true)
	var kp: Vector2 = c + raw.limit_length(1.5) * radius
	draw_circle(kp, radius * 0.34, Color(1.0, 0.78, 0.3, 0.8) if run else Color(0.89, 0.647, 0.247, 0.6 if down else 0.22))
