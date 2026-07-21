extends CanvasLayer

# Key/mouse rebinding menu (reachable from the pause menu). Click a binding
# to capture the next key or mouse button. Saves via SettingsManager.

const SCREEN_W = 1152.0
const SCREEN_H = 648.0

var rows: VBoxContainer = null
var listening_action: String = ""
var listening_button: Button = null
var bind_buttons: Dictionary = {}  # action -> Button


func _ready() -> void:
	layer = 3
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


func _build() -> void:
	var dim = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.03, 0.96)
	add_child(dim)

	var panel = PanelContainer.new()
	panel.position = Vector2(SCREEN_W / 2 - 300, 30)
	panel.custom_minimum_size = Vector2(600, SCREEN_H - 60)
	add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	var title = Label.new()
	title.text = "CONTROLS"
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)
	var hint = Label.new()
	hint.text = "Click a binding, then press a key or mouse button. Mouse side buttons (4/5) work."
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))
	vbox.add_child(hint)
	vbox.add_child(HSeparator.new())

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, SCREEN_H - 200)
	vbox.add_child(scroll)
	rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 2)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)

	for entry in SettingsManager.REMAPPABLE:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var label = Label.new()
		label.text = entry[1]
		label.add_theme_font_size_override("font_size", 14)
		label.custom_minimum_size = Vector2(240, 0)
		row.add_child(label)
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(180, 26)
		btn.text = SettingsManager.binding_label(entry[0])
		btn.pressed.connect(_on_bind_pressed.bind(entry[0], btn))
		row.add_child(btn)
		bind_buttons[entry[0]] = btn
		rows.add_child(row)

	vbox.add_child(HSeparator.new())
	var footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	vbox.add_child(footer)
	var reset = Button.new()
	reset.text = "Reset to Defaults"
	reset.custom_minimum_size = Vector2(180, 30)
	reset.pressed.connect(_on_reset)
	footer.add_child(reset)
	var back = Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(120, 30)
	back.pressed.connect(close)
	footer.add_child(back)


func open() -> void:
	_refresh_labels()
	visible = true


func close() -> void:
	_cancel_listen()
	visible = false


func _on_bind_pressed(action: String, btn: Button) -> void:
	if listening_button != null:
		listening_button.text = SettingsManager.binding_label(listening_action)
	listening_action = action
	listening_button = btn
	btn.text = "press a key/button…"


func _cancel_listen() -> void:
	if listening_button != null:
		listening_button.text = SettingsManager.binding_label(listening_action)
	listening_action = ""
	listening_button = null


func _input(event: InputEvent) -> void:
	if not visible or listening_action == "":
		return
	var captured: InputEvent = null
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_cancel_listen()
			get_viewport().set_input_as_handled()
			return
		captured = event
	elif event is InputEventMouseButton and event.pressed:
		captured = event
	if captured != null:
		SettingsManager.rebind(listening_action, captured)
		var action = listening_action
		listening_action = ""
		if listening_button != null:
			listening_button.text = SettingsManager.binding_label(action)
		listening_button = null
		get_viewport().set_input_as_handled()


func _refresh_labels() -> void:
	for action in bind_buttons:
		bind_buttons[action].text = SettingsManager.binding_label(action)


func _on_reset() -> void:
	SettingsManager.reset_defaults()
	_refresh_labels()
