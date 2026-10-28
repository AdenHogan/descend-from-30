class_name LampCard
extends Control

## A card you can choose (an upgrade on offer): dark glass, a brass edge under the pointer, and when it is the chosen one brass brackets and a CHOSEN tab. Put what it says into `content`
## (a VBoxContainer inset by `margin`); a click, or Enter / the pad's accept while it has focus, emits `chosen`. `clickable = false` makes it a plain information card (nothing to pick).
## Drawing only — what choosing MEANS is the screen's (workbench_ui.choose_perk / shop_ui._on_card_chosen).

signal chosen

var held: bool = false:
	set(v):
		held = v
		queue_redraw()
var clickable: bool = true
var tag_word: String = "CHOSEN"
var margin: int = 14
var content: VBoxContainer = null
var _hover := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	var pad := MarginContainer.new()
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pad)
	content = VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 4)
	pad.add_child(content)
	mouse_entered.connect(func():
		_hover = true
		queue_redraw()
		if clickable:
			Ledger.play("tick", -16.0, 0.07))
	mouse_exited.connect(func():
		_hover = false
		queue_redraw())
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func _ready() -> void:
	var pad := get_child(0) as MarginContainer
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, margin)
	if clickable:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		focus_mode = Control.FOCUS_NONE


func _gui_input(event: InputEvent) -> void:
	if not clickable:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		chosen.emit()
		accept_event()
	elif event.is_action_pressed("ui_accept") and has_focus():
		chosen.emit()
		accept_event()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var lit: bool = clickable and (_hover or has_focus())
	var fill: Color = Lamp.CARD
	var edge: Color = Lamp.EDGE
	if held:
		fill = Color(0.145, 0.105, 0.058)
		edge = Lamp.BRASS_HI
	elif lit:
		fill = Color(0.135, 0.100, 0.062)
		edge = Lamp.BRASS
	Lamp.card(self, r, fill, edge, 1.0)
	if held:
		Lamp.outline(self, r.grow(-1.0), Lamp.BRASS_DIM, 1.0)
		Lamp.brackets(self, r, Lamp.BRASS_HI, 12.0, 3.0, Lamp.ALL, 1.0)
		var f := Lamp.font("label")
		var w := f.get_string_size(tag_word, HORIZONTAL_ALIGNMENT_LEFT, -1, Lamp.PX_LABEL - 2).x + 16.0
		var tab := Rect2(Vector2(size.x - w - 10.0, -1.0), Vector2(w, 22.0))
		draw_rect(tab, Lamp.BRASS_HI)
		Lamp.text(self, "label", Vector2(tab.position.x, tab.end.y - 5.0), tag_word, Lamp.PX_LABEL - 2, Lamp.ON_BRASS, w, HORIZONTAL_ALIGNMENT_CENTER)
