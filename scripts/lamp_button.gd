class_name LampButton
extends Button

## A button in the Lamplight (scripts/lamp.gd): a dark card with a brass edge under the pointer, brass-filled when it is THE action (`solid`) or the chosen tab (`toggle_mode` + pressed),
## letter-spaced capitals in the kit's label face, an optional brass `tag` at the right (a level, a price). A real Button — focus, shortcut and the pad all work; only the drawing is the kit's.
## `looks_off` draws it as unavailable while it stays PRESSABLE: pressing it says why (the owner: "if I press, it doesn't say if I have enough scrap") — a disabled button says nothing.

@export var px: int = Lamp.PX_LABEL
@export var solid: bool = false:
	set(v):
		solid = v
		queue_redraw()
@export var align_left: bool = false:
	set(v):
		align_left = v
		queue_redraw()
@export var tag: String = "":
	set(v):
		tag = v
		queue_redraw()
@export var tone: Color = Color(0, 0, 0, 0):       # a text colour for a warning action (alpha 0 = the normal one)
	set(v):
		tone = v
		queue_redraw()
@export var looks_off: bool = false:
	set(v):
		looks_off = v
		queue_redraw()
@export var pad_x: float = 14.0

var _hover := false
var _lit := 0.0


func _init() -> void:
	flat = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for sb in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(sb, StyleBoxEmpty.new())
	mouse_entered.connect(func():
		_hover = true
		if not disabled:
			Ledger.play("tick", -16.0, 0.07))
	mouse_exited.connect(func(): _hover = false)
	pressed.connect(func(): Ledger.play("tick", -9.0, 0.0))
	toggled.connect(func(_on): queue_redraw())


func _ready() -> void:
	add_theme_font_override("font", Lamp.font("label"))
	add_theme_font_size_override("font_size", px)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color", "font_outline_color"]:
		add_theme_color_override(c, Color(0, 0, 0, 0))              # the Button's own label is invisible: _draw writes it
	if custom_minimum_size.y <= 0.0:
		custom_minimum_size.y = 40.0


## A refused press: the button shivers once and the knock sounds.
func refuse() -> void:
	Ledger.play("deny", -8.0)
	var base := position
	var t := create_tween()
	t.tween_property(self, "position", base + Vector2(3, 0), 0.04)
	t.tween_property(self, "position", base + Vector2(-3, 0), 0.05)
	t.tween_property(self, "position", base, 0.05)


func _process(delta: float) -> void:
	var want := 1.0 if ((_hover or has_focus()) and not disabled) else 0.0
	var n := move_toward(_lit, want, delta * 7.0)
	if n != _lit:
		_lit = n
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var off: bool = disabled or looks_off
	var filled: bool = (solid or (toggle_mode and button_pressed)) and not disabled
	var fill: Color = Lamp.CARD.lerp(Color(0.165, 0.122, 0.075), _lit)
	var edge: Color = Lamp.EDGE.lerp(Lamp.BRASS, _lit)
	var txt: Color = Lamp.TEXT
	if filled and not looks_off:
		fill = Lamp.BRASS.lerp(Lamp.BRASS_HI, _lit)
		edge = Lamp.BRASS_HI
		txt = Lamp.ON_BRASS
	elif off:
		fill = Lamp.WELL
		edge = Lamp.EDGE_DIM.lerp(Lamp.EDGE, _lit * 0.5)
		txt = Lamp.DIM
	elif tone.a > 0.0:
		txt = tone
	Lamp.card(self, r, fill, edge, 1.0)
	if has_focus() and not disabled:
		Lamp.brackets(self, r, Lamp.BRASS_HI, 8.0, 2.0, Lamp.ALL, 0.0)
	var tag_w := 0.0
	var tag_col: Color = Lamp.ON_BRASS if (filled and not looks_off) else (Lamp.BRASS if not off else Lamp.DIM)
	if tag != "":
		tag_w = Lamp.font("label").get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		Lamp.text(self, "label", Vector2(size.x - pad_x - tag_w, size.y * 0.5 + float(px) * 0.33), tag, px, tag_col, tag_w + 2.0)
	var avail: float = size.x - pad_x * 2.0 - (tag_w + 10.0 if tag != "" else 0.0)
	var base_y: float = size.y * 0.5 + float(px) * 0.33
	if align_left:
		Lamp.text(self, "label", Vector2(pad_x, base_y), text.to_upper(), px, txt, avail)
	else:
		Lamp.text(self, "label", Vector2(pad_x, base_y), text.to_upper(), px, txt, avail, HORIZONTAL_ALIGNMENT_CENTER)
