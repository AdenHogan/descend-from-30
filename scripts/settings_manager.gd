extends Node

# Rebindable controls, persisted to user://keybinds.cfg and applied to the
# InputMap at startup. Supports keyboard keys AND mouse buttons (so combat
# actions can live on gaming-mouse side buttons). Autoload: SettingsManager.

const SAVE_PATH = "user://keybinds.cfg"

# Action -> friendly label. Order here is the menu order.
const REMAPPABLE = [
	["move_left", "Move Left"],
	["move_right", "Move Right"],
	["jump", "Jump"],
	["sprint", "Sprint"],
	["crouch_toggle", "Crouch"],
	["push", "Push"],
	["attack", "Attack"],
	["interact", "Interact / Enter"],
	["item_context", "Force / Barricade"],
	["mode_toggle", "Combat / Scavenge"],
	["rest", "Rest"],
	["listen", "Listen"],
	["item_use", "Use Item"],
	["item_slot_1", "Item Slot 1"],
	["item_slot_2", "Item Slot 2"],
	["item_slot_3", "Item Slot 3"],
	["item_slot_4", "Item Slot 4"],
	["item_slot_5", "Item Slot 5"],
]

var default_events: Dictionary = {}  # action -> Array[InputEvent] (baseline)


func _ready() -> void:
	_ensure_attack_action()
	# Snapshot the project's default bindings BEFORE applying saved overrides,
	# so "reset to defaults" can restore them.
	for entry in REMAPPABLE:
		var action = entry[0]
		if InputMap.has_action(action):
			default_events[action] = InputMap.action_get_events(action).duplicate()
	_load()


func _ensure_attack_action() -> void:
	# 'attack' isn't in project.godot; create it. Default = SPACE, so the left
	# mouse button is free for click-to-move in BOTH modes (playtest choice).
	# Rebindable to a mouse side button etc. via the settings menu.
	if not InputMap.has_action("attack"):
		InputMap.add_action("attack")
		var ev = InputEventKey.new()
		ev.physical_keycode = KEY_SPACE
		InputMap.action_add_event("attack", ev)


func rebind(action: String, event: InputEvent) -> void:
	if not InputMap.has_action(action):
		return
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)
	_save()


func reset_defaults() -> void:
	for action in default_events:
		InputMap.action_erase_events(action)
		for ev in default_events[action]:
			InputMap.action_add_event(action, ev)
	_ensure_attack_action()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


func binding_label(action: String) -> String:
	if not InputMap.has_action(action):
		return "—"
	var events = InputMap.action_get_events(action)
	if events.is_empty():
		return "(unbound)"
	return event_label(events[0])


func event_label(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var code = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
		return OS.get_keycode_string(code)
	elif ev is InputEventMouseButton:
		match ev.button_index:
			MOUSE_BUTTON_LEFT: return "Mouse Left"
			MOUSE_BUTTON_RIGHT: return "Mouse Right"
			MOUSE_BUTTON_MIDDLE: return "Mouse Middle"
			MOUSE_BUTTON_XBUTTON1: return "Mouse 4 (side)"
			MOUSE_BUTTON_XBUTTON2: return "Mouse 5 (side)"
			MOUSE_BUTTON_WHEEL_UP: return "Wheel Up"
			MOUSE_BUTTON_WHEEL_DOWN: return "Wheel Down"
			_: return "Mouse Btn %d" % ev.button_index
	return "?"


func _save() -> void:
	var cfg = ConfigFile.new()
	for entry in REMAPPABLE:
		var action = entry[0]
		var events = InputMap.action_get_events(action)
		if events.is_empty():
			continue
		cfg.set_value("binds", action, _encode(events[0]))
	cfg.save(SAVE_PATH)


func _load() -> void:
	var cfg = ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for entry in REMAPPABLE:
		var action = entry[0]
		if not cfg.has_section_key("binds", action):
			continue
		var ev = _decode(cfg.get_value("binds", action))
		if ev != null and InputMap.has_action(action):
			InputMap.action_erase_events(action)
			InputMap.action_add_event(action, ev)


func _encode(ev: InputEvent) -> Dictionary:
	if ev is InputEventKey:
		return {"type": "key", "physical": ev.physical_keycode, "key": ev.keycode}
	elif ev is InputEventMouseButton:
		return {"type": "mouse", "button": ev.button_index}
	return {}


func _decode(d: Dictionary) -> InputEvent:
	match d.get("type", ""):
		"key":
			var ev = InputEventKey.new()
			ev.physical_keycode = int(d.get("physical", 0))
			ev.keycode = int(d.get("key", 0))
			return ev
		"mouse":
			var ev = InputEventMouseButton.new()
			ev.button_index = int(d.get("button", 1))
			return ev
	return null
