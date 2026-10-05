extends CanvasLayer

# CONTROLS menu (reachable from the title and the pause menu). Every action, grouped, with its FOUR
# slots — keyboard/mouse, alternate, gamepad, gamepad alternate (docs/CONTROLS.md). Click (or press A on)
# a slot, then press the key / mouse button / pad button you want; Del clears it, Esc cancels. A button
# another action already uses is swapped, never doubled. Saves through SettingsManager.

const Scheme := preload("res://scripts/input_scheme.gd")

const SCREEN_W = 1152.0
const SCREEN_H = 648.0
const COL_W := 150.0
const LABEL_W := 220.0

var rows: VBoxContainer = null
var listening_action: String = ""
var listening_slot: int = -1
var listening_button: Button = null
var bind_buttons: Dictionary = {}      # "action:slot" -> Button
var note_label: Label = null
var pad_style_pick: OptionButton = null
var touch_pick: OptionButton = null
var first_focus: Control = null
var pad_override = null                # tests only: an axis event stands in for the pad
const AXIS_CAPTURE := 0.6


func _ready() -> void:
	layer = 3
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()
	SettingsManager.bindings_changed.connect(_refresh_labels)


func _build() -> void:
	var dim = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.03, 0.97)
	add_child(dim)

	var panel = PanelContainer.new()
	panel.position = Vector2(SCREEN_W / 2 - 480, 22)
	panel.custom_minimum_size = Vector2(960, SCREEN_H - 44)
	add_child(panel)

	var margin = MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	var title = Label.new()
	title.text = "CONTROLS"
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)
	var hint = Label.new()
	hint.text = "Pick a slot, then press the key, mouse button or pad button you want.   Del clears it · Esc cancels · a button another action uses is swapped."
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))
	vbox.add_child(hint)

	# --- options -------------------------------------------------------------------------------
	var opts = HBoxContainer.new()
	opts.add_theme_constant_override("separation", 12)
	vbox.add_child(opts)
	var l1 = Label.new()
	l1.text = "Controller buttons"
	opts.add_child(l1)
	pad_style_pick = OptionButton.new()
	for t in ["Auto-detect", "Xbox", "PlayStation", "Nintendo"]:
		pad_style_pick.add_item(t)
	pad_style_pick.item_selected.connect(func(i: int): SettingsManager.set_pad_style(["auto", "xbox", "playstation", "nintendo"][i]))
	opts.add_child(pad_style_pick)
	var l2 = Label.new()
	l2.text = "   Touch controls"
	opts.add_child(l2)
	touch_pick = OptionButton.new()
	for t in ["Auto", "Always on", "Off"]:
		touch_pick.add_item(t)
	touch_pick.item_selected.connect(func(i: int): SettingsManager.set_touch_mode(["auto", "on", "off"][i]))
	opts.add_child(touch_pick)
	vbox.add_child(HSeparator.new())

	# --- column heads ----------------------------------------------------------------------------
	var head = HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	vbox.add_child(head)
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(LABEL_W, 0)
	head.add_child(spacer)
	for s in Scheme.SLOTS:
		var h = Label.new()
		h.text = Scheme.SLOT_TITLES[s]
		h.custom_minimum_size = Vector2(COL_W, 0)
		h.add_theme_font_size_override("font_size", 12)
		h.add_theme_color_override("font_color", Color(0.89, 0.647, 0.247))
		head.add_child(h)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, SCREEN_H - 250)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 2)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)

	var group := ""
	for a in Scheme.ACTIONS:
		if a["group"] != group:
			group = a["group"]
			var g = Label.new()
			g.text = group.to_upper()
			g.add_theme_font_size_override("font_size", 12)
			g.add_theme_color_override("font_color", Color(0.55, 0.75, 0.6))
			rows.add_child(g)
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var label = Label.new()
		label.text = a["label"]
		label.add_theme_font_size_override("font_size", 13)
		label.custom_minimum_size = Vector2(LABEL_W, 0)
		row.add_child(label)
		for slot in range(4):
			var btn = Button.new()
			btn.custom_minimum_size = Vector2(COL_W, 24)
			btn.clip_text = true
			btn.pressed.connect(_on_bind_pressed.bind(a["id"], slot, btn))
			row.add_child(btn)
			bind_buttons["%s:%d" % [a["id"], slot]] = btn
			if first_focus == null:
				first_focus = btn
		rows.add_child(row)

	note_label = Label.new()
	note_label.add_theme_font_size_override("font_size", 12)
	note_label.add_theme_color_override("font_color", Color(0.95, 0.8, 0.45))
	note_label.text = " "
	vbox.add_child(note_label)

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
	back.name = "BackButton"
	_refresh_labels()


func open() -> void:
	_refresh_labels()
	visible = true
	if first_focus != null and SettingsManager.last_device == "pad":
		first_focus.grab_focus()


func close() -> void:
	_cancel_listen()
	visible = false


func _slot_text(action: String, slot: int) -> String:
	var spec: String = SettingsManager.slot_spec(action, slot)
	return "—" if spec == "" else SettingsManager.slot_label(action, slot)


func _on_bind_pressed(action: String, slot: int, btn: Button) -> void:
	if listening_button != null:
		listening_button.text = _slot_text(listening_action, listening_slot)
	listening_action = action
	listening_slot = slot
	listening_button = btn
	btn.text = "press…" if slot < 2 else "press a pad button…"
	note_label.text = " "


func _cancel_listen() -> void:
	if listening_button != null and is_instance_valid(listening_button):
		listening_button.text = _slot_text(listening_action, listening_slot)
	listening_action = ""
	listening_slot = -1
	listening_button = null


## What a captured event means for the slot being set: a spec, "" to clear, or null for "not for this slot".
func capture_spec(event: InputEvent, slot: int) -> Variant:
	if event is InputEventKey and event.pressed and not event.echo:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if code == KEY_ESCAPE:
			return null
		if code == KEY_DELETE or code == KEY_BACKSPACE:
			return ""
		return Scheme.event_to_spec(event) if slot < 2 else null
	if slot < 2:
		if event is InputEventMouseButton and event.pressed:
			return Scheme.event_to_spec(event)
		return null
	if event is InputEventJoypadButton and event.pressed:
		return Scheme.event_to_spec(event)
	if event is InputEventJoypadMotion and absf(event.axis_value) >= AXIS_CAPTURE:
		return Scheme.event_to_spec(event)
	return null


func _input(event: InputEvent) -> void:
	if not visible or listening_action == "":
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and (event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE):
		_cancel_listen()
		get_viewport().set_input_as_handled()
		return
	var spec = capture_spec(event, listening_slot)
	if spec == null:
		# Anything else while capturing is swallowed, so a stray press can't drive the menu behind.
		if (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton) and event.pressed:
			get_viewport().set_input_as_handled()
		return
	_apply_capture(String(spec))
	get_viewport().set_input_as_handled()


## Set the slot being listened to (tests call this directly). "" clears it.
func _apply_capture(spec: String) -> void:
	var action := listening_action
	var slot := listening_slot
	var res: Dictionary = SettingsManager.rebind_slot(action, slot, spec)
	listening_action = ""
	listening_slot = -1
	listening_button = null
	_refresh_labels()
	if bool(res.get("ok", false)):
		var sw: Array = res.get("swapped", [])
		if not sw.is_empty():
			var names: Array = []
			for id in sw:
				names.append(String(Scheme.entry(id).get("label", id)))
			note_label.text = "Swapped with: " + ", ".join(names)
		else:
			note_label.text = " "
	elif res.get("reason", "") == "essential":
		note_label.text = "That one can't be left empty — it's needed to play."
	else:
		note_label.text = "That can't go in this slot."


func _refresh_labels() -> void:
	for key in bind_buttons:
		var parts: PackedStringArray = String(key).split(":")
		bind_buttons[key].text = _slot_text(parts[0], int(parts[1]))
	if pad_style_pick != null:
		pad_style_pick.select(["auto", "xbox", "playstation", "nintendo"].find(SettingsManager.pad_style_setting))
	if touch_pick != null:
		touch_pick.select(["auto", "on", "off"].find(SettingsManager.touch_mode))


func _on_reset() -> void:
	SettingsManager.reset_defaults()
	_refresh_labels()
	note_label.text = "Controls reset to the defaults."
