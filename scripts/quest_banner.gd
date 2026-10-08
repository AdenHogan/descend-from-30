extends PanelContainer

# The QUEST BANNER (owner round 37): when a run's personal quest begins, and each time its objective turns over, a small
# plate comes down at the top of the screen — a gold kicker ("NEW QUEST" / "OBJECTIVE UPDATED"), the quest's title, the
# objective — holds a few seconds and fades. Pure display (never swallows a click), runs while the game is paused so a
# line that pauses can't strand it. `show_banner` is the one entry (HUD.show_quest_banner → here).

const FONT := preload("res://assets/fonts/PixelOperator8.ttf")
const FONT_BOLD := preload("res://assets/fonts/PixelOperator8-Bold.ttf")
const WIDTH := 600.0
const TOP := 8.0                 # (the dialogue plate sits at y 96 — the banner stays clear above it)
const FADE := 0.45
const HOLD := 5.5

var kicker_label: Label = null
var title_label: Label = null
var objective_label: Label = null
var age: float = 0.0
var active: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	name = "QuestBanner"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.07, 0.86)
	style.border_color = Color(0.89, 0.647, 0.247, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(9)
	add_theme_stylebox_override("panel", style)
	position = Vector2((1152.0 - WIDTH) * 0.5, TOP)
	custom_minimum_size = Vector2(WIDTH, 0)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 3)
	add_child(box)
	kicker_label = _label(FONT, 12, Color(0.89, 0.647, 0.247))
	title_label = _label(FONT_BOLD, 20, Color(0.96, 0.95, 0.9))
	objective_label = _label(FONT, 14, Color(0.8, 0.82, 0.88))
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.custom_minimum_size = Vector2(WIDTH - 18.0, 0)
	for l in [kicker_label, title_label, objective_label]:
		box.add_child(l)
	visible = false
	modulate.a = 0.0


func _label(font: Font, size: int, col: Color) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func show_banner(kicker: String, title_text: String, objective: String) -> void:
	kicker_label.text = SettingsManager.localize(kicker)
	title_label.text = SettingsManager.localize(title_text)
	objective_label.text = SettingsManager.localize(objective)
	age = 0.0
	active = true
	visible = true
	modulate.a = 0.0
	reset_size()
	position = Vector2((1152.0 - WIDTH) * 0.5, TOP)


func _process(delta: float) -> void:
	if not active:
		return
	age += delta
	var a: float = clampf(age / FADE, 0.0, 1.0)
	if age > FADE + HOLD:
		a = 1.0 - clampf((age - FADE - HOLD) / FADE, 0.0, 1.0)
	modulate.a = a
	position.y = TOP - 10.0 * (1.0 - clampf(age / FADE, 0.0, 1.0))      # settles down into place
	if age >= FADE * 2.0 + HOLD:
		active = false
		visible = false
