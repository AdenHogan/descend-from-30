class_name LedgerButton
extends Button

## A button on the ledger: a box ruled in ink — two thin lines that don't quite agree, like a hand-drawn rectangle — with printed capitals inside. Under the pointer it fills with pencil
## hatching (a person shading a box); pressed, the ink floods it; disabled, the box is dotted and the word struck through. Focus (keyboard / pad) is four corner brackets, like a
## proofreader's marks. A tick of pencil on paper when the pointer arrives, a pencil tap when it is pressed; refusals are the owner's (a knock) — `refuse()` plays it.
## It is a real Button (focus, shortcut, the pad all work); only the drawing is the ledger's.

@export var ink: Color = Ledger.INK
@export var seed_value: int = 5
@export var px: int = 20
@export var solid: bool = false           # a filled (inked) box — the one chosen action on a page
@export var align_left: bool = false      # list entries read from the left; actions are centred
@export var pad_x: float = 12.0

var _hover := false
var _hatch: float = 0.0                   # 0..1, how far the shading has got


func _init() -> void:
	flat = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	mouse_entered.connect(func():
		_hover = true
		if not disabled:
			Ledger.play("tick", -16.0, 0.07))
	mouse_exited.connect(func(): _hover = false)
	pressed.connect(func(): Ledger.play("tick", -9.0, 0.0))
	toggled.connect(func(_on): queue_redraw())


func _ready() -> void:
	add_theme_font_override("font", Ledger.font("head"))
	add_theme_font_size_override("font_size", px)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color", "font_outline_color"]:
		add_theme_color_override(c, Color(0, 0, 0, 0))              # the Button's own label is invisible: _draw writes it (so a solid button can take paper-coloured text)
	if custom_minimum_size.y <= 0.0:
		custom_minimum_size.y = 40.0


## The knock for a refused action (can't afford it, won't fit): the button shivers once.
func refuse() -> void:
	Ledger.play("deny", -8.0)
	var base := position
	var t := create_tween()
	t.tween_property(self, "position", base + Vector2(3, 0), 0.04)
	t.tween_property(self, "position", base + Vector2(-3, 0), 0.05)
	t.tween_property(self, "position", base, 0.05)


func _process(delta: float) -> void:
	var want := 1.0 if ((_hover or has_focus()) and not disabled) else 0.0
	var n := move_toward(_hatch, want, delta * 6.0)
	if n != _hatch:
		_hatch = n
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 71 + int(size.x)
	var col := ink if not disabled else Ledger.INK_FAINT
	var filled := (solid or (toggle_mode and button_pressed)) and not disabled
	if filled:
		draw_colored_polygon(Ledger.ragged(size.x, size.y, 24.0, 1.4, seed_value), Color(ink.r, ink.g, ink.b, 0.92))
	elif is_pressed() and not disabled:
		draw_rect(r.grow(-2.0), Color(ink.r, ink.g, ink.b, 0.16))
	# the hand-ruled box: two passes that wander a hair apart
	for pass_i in 2:
		var o := rng.randf_range(-0.9, 0.9)
		var a := Vector2(rng.randf_range(0.0, 2.0), 1.5 + o)
		var b := Vector2(size.x - rng.randf_range(0.0, 2.0), 1.5 - o)
		var c := Vector2(size.x - 1.5 + o, size.y - rng.randf_range(0.0, 2.0))
		var d := Vector2(1.5 - o, size.y - rng.randf_range(0.0, 2.0))
		var line_col := Color(col.r, col.g, col.b, 0.9 if pass_i == 0 else 0.5)
		if disabled:
			_dotted(a, b, line_col)
			_dotted(b, c, line_col)
			_dotted(c, d, line_col)
			_dotted(d, a, line_col)
		else:
			draw_polyline(PackedVector2Array([a, b, c, d, a]), line_col, 1.5 if pass_i == 0 else 1.0, true)
	# the pencil shading, laid in diagonal strokes left to right as the pointer stays
	if _hatch > 0.01 and not filled:
		var reach := size.x * _hatch
		var x := 6.0
		while x < reach + size.y:
			var p0 := Vector2(minf(x, reach), maxf(4.0, size.y - 5.0 - maxf(0.0, x - reach)))
			var p1 := Vector2(maxf(x - size.y + 10.0, 5.0), 5.0)
			if p0.x > p1.x:
				draw_line(p0, p1, Color(Ledger.PENCIL.r, Ledger.PENCIL.g, Ledger.PENCIL.b, 0.20), 1.0)
			x += 7.0
	if has_focus() and not disabled:
		var k := 7.0
		for corner in [Vector2(-3, -3), Vector2(size.x + 3, -3), Vector2(size.x + 3, size.y + 3), Vector2(-3, size.y + 3)]:
			var sx := 1.0 if corner.x < 0 else -1.0
			var sy := 1.0 if corner.y < 0 else -1.0
			draw_polyline(PackedVector2Array([corner + Vector2(sx * k, 0), corner, corner + Vector2(0, sy * k)]), Ledger.RED_INK, 1.6)
	# the label, centred (drawn here so a solid button can take PAPER-coloured text); struck through when disabled
	var f: Font = get_theme_font("font")
	var fs := get_theme_font_size("font_size")
	var shown := text
	var pad := minf(pad_x, size.x * 0.18)                                       # a small box (a + or a ×) takes a small margin
	var room := size.x - 2.0 * pad
	if f.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:            # too long for the box: trim it, the way a clerk abbreviates
		while shown.length() > 1 and f.get_string_size(shown + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
			shown = shown.substr(0, shown.length() - 1)
		shown += "…"
	var tw := f.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var tx := pad if align_left else (size.x - tw) * 0.5
	var ty := size.y * 0.5 + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5
	var tcol := Ledger.PAPER_LIGHT if filled else col
	draw_string(f, Vector2(tx, ty), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tcol)
	if disabled and text != "":
		draw_line(Vector2(tx - 2, size.y * 0.5 + 1), Vector2(tx + tw + 2, size.y * 0.5), Color(col.r, col.g, col.b, 0.8), 1.2)


func _dotted(a: Vector2, b: Vector2, col: Color) -> void:
	var n := maxi(2, int(a.distance_to(b) / 4.0))
	for i in range(0, n, 2):
		draw_line(a.lerp(b, float(i) / n), a.lerp(b, float(i + 1) / n), col, 1.2)
