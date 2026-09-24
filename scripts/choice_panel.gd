class_name ChoicePanel
extends CanvasLayer

# Shared base for the small PAUSING choice panels (run boons, legacy): a dimmed screen, a dark card
# in the workbench's style, pixel fonts, ESC/✕ to close, and the pause restored on close. Joins
# "modal_panel" so Game._input closes it on ESC before the pause menu opens.

const INK := Color(0.93, 0.90, 0.84)
const DIM := Color(0.62, 0.60, 0.56)
const GOLD := Color(1.0, 0.82, 0.30)
const BAD := Color(0.95, 0.45, 0.38)
const FONT := preload("res://assets/fonts/PixelOperator8.ttf")
const FONT_BOLD := preload("res://assets/fonts/PixelOperator8-Bold.ttf")

var card: Panel = null
var _prev_paused := false
var _was_open := false


func build_card(title: String, w: float, h: float, border: Color = Color(0.55, 0.38, 0.22)) -> void:
	layer = 21
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("modal_panel")
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	card = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.11, 0.10, 0.97)
	sb.border_color = border
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(4)
	card.add_theme_stylebox_override("panel", sb)
	card.size = Vector2(w, h)
	card.position = Vector2((1152.0 - w) * 0.5, (648.0 - 120.0 - h) * 0.5 + 10.0)
	add_child(card)
	var t := label(title, 22, GOLD, FONT_BOLD)
	t.position = Vector2(24, 16)
	card.add_child(t)
	var x := Button.new()
	x.text = "✕"
	x.position = Vector2(w - 44, 12)
	x.size = Vector2(30, 30)
	x.pressed.connect(close)
	card.add_child(x)
	visible = false


func label(text: String, size: int, col: Color, font: Font = FONT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func choice_button(title: String, desc: String, w: float, h: float) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(w, h)
	b.text = "%s\n\n%s" % [title, desc]
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", 13)
	return b


func show_panel() -> void:
	if not _was_open:
		_prev_paused = get_tree().paused
	_was_open = true
	get_tree().paused = true
	visible = true


func close() -> void:
	if not visible:
		return
	visible = false
	_was_open = false
	get_tree().paused = _prev_paused


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
