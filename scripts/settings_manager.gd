extends Node

# Controls: the InputMap is BUILT here from scripts/input_scheme.gd (the defaults) plus the player's
# changes in keybinds.cfg. Four slots per action (keyboard/mouse x2, gamepad x2); touch presses the same
# actions through touch_overlay.gd. Also tracks WHICH device the player is using right now, so every
# on-screen hint can name the right button ("[E]" on a keyboard, "[A]" / "[Cross]" on a pad, "[USE]" on
# a phone). Autoload: SettingsManager (before HUD — the HUD names keys while it builds). docs/CONTROLS.md.

const Scheme := preload("res://scripts/input_scheme.gd")

signal bindings_changed
signal device_changed(kind: String)        # "kbm" | "pad" | "touch"

const VERSION := 2

# keybinds.cfg beside the profiles — a test run gets its own sandbox (WorldState.data_dir), so
# settings_test's reset never wipes the player's real bindings.
func _save_path() -> String:
	return WorldState.data_dir() + "keybinds.cfg"

## [[action, label], …] in menu order — kept for the menu and for tests that list the actions.
var REMAPPABLE: Array = []

var bindings: Dictionary = {}              # action -> Array[String] of 4 specs (Scheme.SLOTS order)

# --- options (saved) -----------------------------------------------------------------------------
var pad_style_setting: String = "auto"     # auto | xbox | playstation | nintendo
var touch_mode: String = "auto"            # auto | on | off

# --- the device in use right now (not saved) -----------------------------------------------------
var last_device: String = "kbm"
var last_pad_id: int = -1

# Old (v1) first bindings — a saved v1 entry equal to one of these was never really CHANGED (the old menu
# wrote every action on any rebind), so it must not pin a slot against the new defaults.
const V1_DEFAULTS := {
	"move_left": "k:Left", "move_right": "k:Right", "move_up": "k:Up", "move_down": "k:Down", "sprint": "k:Shift",
	"crouch_toggle": "k:C", "push": "m:2", "attack": "k:Space", "interact": "k:E", "item_context": "k:X",
	"mode_toggle": "k:F", "rest": "k:T", "listen": "k:R", "item_use": "k:Q", "open_pack": "k:B",
	"item_slot_1": "k:1", "item_slot_2": "k:2", "item_slot_3": "k:3", "item_slot_4": "k:4", "item_slot_5": "k:5",
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in Scheme.ACTIONS:
		REMAPPABLE.append([a["id"], a["label"]])
	_set_defaults()
	_load()
	apply()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	if OS.has_feature("android") or OS.has_feature("ios"):
		last_device = "touch"            # a phone starts on the touch controls until a pad / keyboard is used
	for id in Input.get_connected_joypads():
		last_pad_id = id
		break


func _set_defaults() -> void:
	bindings.clear()
	for a in Scheme.ACTIONS:
		bindings[a["id"]] = Scheme.defaults_for(a["id"])


# --- building the InputMap -----------------------------------------------------------------------

## Rebuild every game action in the InputMap from `bindings`, and give the pad the menu actions.
func apply() -> void:
	for a in Scheme.ACTIONS:
		var id: String = a["id"]
		if not InputMap.has_action(id):
			InputMap.add_action(id, float(a.get("dead", 0.5)))
		else:
			InputMap.action_set_deadzone(id, float(a.get("dead", 0.5)))
		InputMap.action_erase_events(id)
		for spec in bindings.get(id, []):
			var ev := Scheme.spec_to_event(spec)
			if ev == null:
				continue
			ev.device = -1                 # any keyboard / any pad
			InputMap.action_add_event(id, ev)
	for ui in Scheme.UI_KEYS:
		for spec in Scheme.UI_KEYS[ui]:
			var kev := Scheme.spec_to_event(spec)
			if kev != null and InputMap.has_action(ui) and not InputMap.action_has_event(ui, kev):
				InputMap.action_add_event(ui, kev)
	for ui in Scheme.UI_PAD:
		if not InputMap.has_action(ui):
			continue
		for spec in Scheme.UI_PAD[ui]:
			var ev := Scheme.spec_to_event(spec)
			if ev != null:
				ev.device = -1
				if not InputMap.action_has_event(ui, ev):
					InputMap.action_add_event(ui, ev)
	bindings_changed.emit()


# --- changing a binding --------------------------------------------------------------------------

## Put `spec` in one slot of one action. A binding another action already has (on the same kind of
## device) is SWAPPED — that action takes this slot's old binding — so nothing is ever left silently
## dead and no two actions share a button. Returns {ok, reason, swapped: [action…]}.
func rebind_slot(action: String, slot: int, spec: String) -> Dictionary:
	if not bindings.has(action) or slot < 0 or slot > 3:
		return {"ok": false, "reason": "unknown", "swapped": []}
	var row: Array = bindings[action]
	var want: int = 1 if Scheme.slot_is_pad(slot) else 0
	if spec != "" and Scheme.family_of(spec) != want:
		return {"ok": false, "reason": "wrong_device", "swapped": []}
	if spec == "":
		if action in Scheme.ESSENTIAL and _count_family(row, want) <= 1 and row[slot] != "":
			return {"ok": false, "reason": "essential", "swapped": []}
		row[slot] = ""
		_commit()
		return {"ok": true, "reason": "", "swapped": []}
	var old: String = row[slot]
	var swapped: Array = []
	for other in bindings:
		if other == action:
			continue
		var orow: Array = bindings[other]
		for s in range(4):
			if (s >= 2) != (want == 1) or orow[s] != spec:
				continue
			# it takes this slot's old binding — unless it already holds that one in the same family
			orow[s] = old if (old != "" and not _row_has(orow, old, want)) else ""
			if not swapped.has(other):
				swapped.append(other)
	# the same button in another slot of THIS action is just a move
	for s in range(4):
		if s != slot and row[s] == spec:
			row[s] = ""
	row[slot] = spec
	_commit()
	return {"ok": true, "reason": "", "swapped": swapped}


func clear_slot(action: String, slot: int) -> Dictionary:
	return rebind_slot(action, slot, "")


## Old single-binding call: the event REPLACES the action's bindings on its kind of device.
func rebind(action: String, event: InputEvent) -> void:
	if not bindings.has(action):
		return
	var spec := Scheme.event_to_spec(event)
	if spec == "":
		return
	var base: int = 2 if Scheme.family_of(spec) == 1 else 0
	bindings[action][base + 1] = ""
	rebind_slot(action, base, spec)


func reset_action(action: String) -> void:
	if bindings.has(action):
		bindings[action] = Scheme.defaults_for(action)
		_commit()


func reset_defaults() -> void:
	_set_defaults()
	if FileAccess.file_exists(_save_path()):
		DirAccess.remove_absolute(_save_path())
	apply()


## Tests: forget the in-memory bindings WITHOUT touching the saved file (to prove a load restores them).
func reset_defaults_in_memory_for_test() -> void:
	_set_defaults()
	apply()


func _commit() -> void:
	apply()
	_save()


func _count_family(row: Array, family: int) -> int:
	var n := 0
	for s in range(4):
		if (s >= 2) == (family == 1) and row[s] != "":
			n += 1
	return n


func _row_has(row: Array, spec: String, family: int) -> bool:
	for s in range(4):
		if (s >= 2) == (family == 1) and row[s] == spec:
			return true
	return false


# --- reading a binding ---------------------------------------------------------------------------

func slot_spec(action: String, slot: int) -> String:
	return bindings[action][slot] if bindings.has(action) else ""


func slot_label(action: String, slot: int) -> String:
	return Scheme.spec_label(slot_spec(action, slot), pad_style())


## Every action now bound to this event spec on the same kind of device (menu conflict hints).
func actions_using(spec: String) -> Array:
	var out: Array = []
	var fam := Scheme.family_of(spec)
	for a in bindings:
		for s in range(4):
			if bindings[a][s] == spec and (s >= 2) == (fam == 1):
				out.append(a)
				break
	return out


## First keyboard/mouse binding as readable text ("Left-click", "E") — what the device-blind callers use.
func binding_label(action: String) -> String:
	if not bindings.has(action):
		return "—"
	for s in [0, 1]:
		if bindings[action][s] != "":
			return Scheme.spec_label(bindings[action][s])
	return "(unbound)"


func event_label(ev: InputEvent) -> String:
	var spec := Scheme.event_to_spec(ev)
	return Scheme.spec_label(spec, pad_style()) if spec != "" else "?"


# --- hints that name the device in use -------------------------------------------------------------

func pad_style() -> String:
	if pad_style_setting != "auto":
		return pad_style_setting
	if last_pad_id >= 0:
		return Scheme.pad_style_for(Input.get_joy_name(last_pad_id))
	return "xbox"


## The button for `action` on the device the player is using right now, as a word ("Left-click", "E",
## "A", "Cross", "USE"). `short` = the wall-text form ("LMB").
func action_text(action: String, short: bool = false) -> String:
	if not bindings.has(action):
		return action.to_upper()
	var row: Array = bindings[action]
	var order: Array = [0, 1, 2, 3]
	match last_device:
		"pad": order = [2, 3, 0, 1]
		"touch":
			var t: String = String(Scheme.entry(action).get("touch", ""))
			if t != "":
				return t
	for s in order:
		if row[s] != "":
			var style := pad_style()
			return Scheme.spec_short(row[s], style) if short else Scheme.spec_label(row[s], style)
	return "(unbound)"


func action_short(action: String) -> String:
	return action_text(action, true)


## Prompt text is written with the ACTION in braces — "[{interact}] Enter" — and becomes whatever the player
## really presses on the device they're using: "[E] Enter", "[A] Enter", "[USE] Enter". (HUD.show_world_prompt /
## show_dialogue / show_feedback run every line through this.) Braces that aren't an action are left alone.
func localize(text: String) -> String:
	if not text.contains("{"):
		return text
	for action in bindings:
		var token := "{%s}" % action
		if text.contains(token):
			text = text.replace(token, action_text(action))
	return text


# --- the device in use ---------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	var kind := ""
	if event is InputEventKey and event.pressed:
		kind = "kbm"
	elif event is InputEventMouseButton:
		kind = "touch" if event.device == -1 else "kbm"      # a touch's emulated mouse click has device -1
	elif event is InputEventMouseMotion:
		# A real mouse moving (not a touch's emulated one, not jitter) puts the player back on keyboard + mouse.
		if event.device == -1:
			kind = "touch"
		elif event.relative.length() >= 3.0:
			kind = "kbm"
	elif event is InputEventJoypadButton and event.pressed:
		kind = "pad"
		last_pad_id = event.device
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		kind = "pad"
		last_pad_id = event.device
	elif event is InputEventScreenTouch or event is InputEventScreenDrag:
		kind = "touch"
	if kind != "" and kind != last_device:
		note_device(kind)
	# A pad (or a Back key) on a menu with nothing focused would do nothing — focus the first button.
	if (kind == "pad" or last_device == "pad") and _is_menu_nav(event):
		ensure_menu_focus()


func _is_menu_nav(event: InputEvent) -> bool:
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return false
	for a in ["ui_up", "ui_down", "ui_left", "ui_right", "ui_accept"]:
		if event.is_action_pressed(a):
			return true
	return false


## Where the pad's menu cursor starts: when a menu is up (the game paused, or no HUD = title / profile screens)
## and nothing is focused, focus the first button of the top-most menu layer. No-op in play.
func ensure_menu_focus() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var owner_ := vp.gui_get_focus_owner()
	if owner_ != null and owner_.is_visible_in_tree():
		return
	if not (get_tree().paused or not HUD.visible or WorldState.loot_open):
		return
	var best: Control = null
	var best_layer := -1000000
	var stack: Array = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if not (n is BaseButton) or not n.is_visible_in_tree() or n.disabled or n.focus_mode == Control.FOCUS_NONE:
			continue
		var layer := 0
		var p: Node = n.get_parent()
		while p != null:
			if p is CanvasLayer:
				layer = p.layer
				break
			p = p.get_parent()
		if layer > best_layer or (layer == best_layer and best != null and _before(n, best)):
			best = n
			best_layer = layer
	if best != null:
		best.grab_focus()


## Tree order: is `a` earlier than `b` under the same layer (so "first button" means top-left-most in the scene).
func _before(a: Control, b: Control) -> bool:
	var ra := a.get_global_rect().position
	var rb := b.get_global_rect().position
	return ra.y < rb.y or (is_equal_approx(ra.y, rb.y) and ra.x < rb.x)


## "Press any button" for every device: a key, a mouse button, a pad button or a tap. (Pad sticks and bare
## mouse motion don't count — drift must not skip a card.)
static func is_any_press(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo
	# (A tap is its emulated mouse click — counting the touch as well would dismiss two prompts per tap.)
	if event is InputEventMouseButton or event is InputEventJoypadButton:
		return event.pressed
	return false


func note_device(kind: String) -> void:
	if kind == last_device:
		return
	last_device = kind
	device_changed.emit(kind)


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		last_pad_id = device
		bindings_changed.emit()          # the style (A vs Cross) may have changed
	elif device == last_pad_id:
		last_pad_id = -1
		if last_device == "pad":
			note_device("kbm")


## Whether the on-screen touch controls should be up right now.
func touch_ui_wanted() -> bool:
	match touch_mode:
		"on": return true
		"off": return false
	return last_device == "touch"


# --- saving --------------------------------------------------------------------------------------

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", VERSION)
	# Only what differs from the defaults is saved, so a later better default reaches everyone who never changed it.
	for a in Scheme.ACTIONS:
		var id: String = a["id"]
		if bindings[id] != Scheme.defaults_for(id):
			cfg.set_value("binds2", id, PackedStringArray(bindings[id]))
	cfg.set_value("options", "pad_style", pad_style_setting)
	cfg.set_value("options", "touch_mode", touch_mode)
	cfg.save(_save_path())


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_save_path()) != OK:
		return
	pad_style_setting = String(cfg.get_value("options", "pad_style", "auto"))
	if not pad_style_setting in ["auto", "xbox", "playstation", "nintendo"]:
		pad_style_setting = "auto"
	touch_mode = String(cfg.get_value("options", "touch_mode", "auto"))
	if not touch_mode in ["auto", "on", "off"]:
		touch_mode = "auto"
	if cfg.has_section("binds2"):
		for id in cfg.get_section_keys("binds2"):
			if not bindings.has(id):
				continue
			var arr = cfg.get_value("binds2", id)
			if not (arr is PackedStringArray or arr is Array) or arr.size() != 4:
				continue
			var row: Array = []
			for i in range(4):
				var spec := String(arr[i])
				var okay: bool = spec == "" or (Scheme.spec_to_event(spec) != null and Scheme.family_of(spec) == (1 if i >= 2 else 0))
				row.append(spec if okay else Scheme.defaults_for(id)[i])
			bindings[id] = row
	elif cfg.has_section("binds"):
		_migrate_v1(cfg)


## The v1 file kept ONE event per action. A binding the player really changed becomes the first keyboard
## slot (the second is cleared, as v1's rebind replaced everything); an unchanged one takes the new default.
func _migrate_v1(cfg: ConfigFile) -> void:
	for id in cfg.get_section_keys("binds"):
		if not bindings.has(id):
			continue
		var d = cfg.get_value("binds", id)
		if not (d is Dictionary):
			continue
		var spec := _v1_spec(d)
		if spec == "" or spec == String(V1_DEFAULTS.get(id, "")):
			continue
		bindings[id] = [spec, "", bindings[id][2], bindings[id][3]]
	_save()


func _v1_spec(d: Dictionary) -> String:
	match d.get("type", ""):
		"key":
			var code := int(d.get("physical", 0))
			if code == 0:
				code = int(d.get("key", 0))
			return "k:" + OS.get_keycode_string(code) if code != 0 else ""
		"mouse":
			return "m:%d" % int(d.get("button", 1))
	return ""


func set_pad_style(s: String) -> void:
	pad_style_setting = s
	_save()
	bindings_changed.emit()


func set_touch_mode(m: String) -> void:
	touch_mode = m
	_save()
	device_changed.emit(last_device)
