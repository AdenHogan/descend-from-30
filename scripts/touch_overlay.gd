extends Control

# ON-SCREEN CONTROLS for phones / tablets (Android first). A fixed thumb-stick bottom-left, the action
# buttons bottom-right, a few small ones up the right edge, pause + journal top-left. Everything presses the
# SAME actions the keyboard and pad do (InputEventAction), so no game system knows touch exists.
# Taps anywhere ELSE are ordinary clicks (the emulated mouse) — tap the floor to walk, tap a node to
# scavenge, tap a zombie to hit it (smart-click) — which is why the widgets are small and the world is left alone.
#
# Shown when SettingsManager.touch_ui_wanted() (a touchscreen in use, or forced on in Settings), while the HUD is
# up and the game isn't paused. docs/CONTROLS.md. Multi-touch: every finger is tracked by its own index.

const Stick := preload("res://scripts/touch_stick.gd")

# [action, label, centre, radius, hold, context]. Viewport is 1152x648. `hold` = held while the finger is down (sprint);
# the rest are a press the moment the finger lands. `context` says when it is on screen:
#   "always"  — a main verb;   "item" — only with something in hand;   "prompt" — only while a world prompt offers it
#   (Force a door, Listen at a stairwell). Owner round 36b: ten buttons at once on the right was "too much going on", so
#   the main hand has FOUR (HIT / USE / PUSH / RUN), a quiet edge column holds the rest, and the situational ones only
#   appear when they would do something. The bag is the HUD's own backpack button (bottom-right), not a copy here.
const BUTTONS := [
	["attack", "HIT", Vector2(1040, 500), 58.0, false, "always"],
	["interact", "USE", Vector2(1040, 366), 42.0, false, "always"],
	["push", "PUSH", Vector2(916, 520), 40.0, false, "always"],
	["sprint", "RUN", Vector2(922, 404), 34.0, true, "always"],
	["mode_toggle", "SCAV", Vector2(1110, 330), 26.0, false, "always"],
	["crouch_toggle", "DUCK", Vector2(1110, 270), 24.0, false, "always"],
	["item_use", "ITEM", Vector2(1110, 210), 24.0, false, "item"],
	["listen", "LISTEN", Vector2(1110, 150), 24.0, false, "prompt"],
	["item_context", "FORCE", Vector2(1110, 90), 24.0, false, "prompt"],
	["pause", "PAUSE", Vector2(52, 48), 22.0, false, "always"],
	["open_journal", "JOURNAL", Vector2(108, 48), 22.0, false, "always"],
]
const STICK_CENTRE := Vector2(140, 500)
const STICK_R := 82.0
const STICK_DEAD := 0.22                # across the stick: below this, no walk
const STICK_FLICK := 0.6                # up / down past this = move_up / move_down

var widgets: Array = []                 # the TouchWidget controls (buttons + the stick area)
var _touch_widget: Dictionary = {}      # finger index -> widget
var _held: Dictionary = {}              # action -> strength currently sent (so only changes are sent)
var stick_vec: Vector2 = Vector2.ZERO   # -1..1, for the thumb drawing + tests
var stick_down: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_to_group("touch_overlay")
	_build()
	SettingsManager.device_changed.connect(func(_k): refresh())
	visibility_changed.connect(func(): if not is_visible_in_tree(): release_all())
	set_process(true)


func _build() -> void:
	var st: Control = Stick.new()
	st.name = "Stick"
	st.setup("stick", "", STICK_CENTRE, STICK_R)
	add_child(st)
	widgets.append(st)
	for b in BUTTONS:
		var w: Control = Stick.new()
		w.name = "Btn_" + String(b[0])
		w.setup(String(b[0]), String(b[1]), b[2], float(b[3]))
		w.hold = bool(b[4])
		w.context = String(b[5])
		add_child(w)
		widgets.append(w)


## Show / hide for the device in use and the state of the game; always lets go of everything when it hides.
## A paused TEACHING beat that waits for an action (the shove intro) keeps ONLY that button up and pulsing — the overlay used to
## vanish on every pause, leaving a phone player staring at "[PUSH] to shove" with nothing to press.
func refresh() -> void:
	var beat: String = TutorialManager.strict_action()
	var want: bool = SettingsManager.touch_ui_wanted() and HUD.visible and (not get_tree().paused or beat != "")
	if want != visible:
		visible = want
	if not want:
		release_all()
		return
	for w in widgets:
		var show: bool = _widget_wanted(w, beat)
		if w.visible and not show and _touch_widget.values().has(w):
			_release_widget(w)
		w.visible = show
		w.pulse = beat != "" and w.action == beat
	var mode_btn = get_node_or_null("Btn_mode_toggle")
	if mode_btn != null:
		mode_btn.label = "SCAV" if WorldState.is_scavenge_mode else "FIGHT"


func _widget_wanted(w: Control, beat: String) -> bool:
	if beat != "":
		return w.kind == "button" and w.action == beat
	match w.context:
		"item":
			var sel: int = HUD.selected_slot
			return sel >= 0 and sel < WorldState.inventory.size()
		"prompt":
			return HUD.world_prompt_mentions("[%s]" % SettingsManager.action_text(w.action))
	return true


func _release_widget(w: Control) -> void:
	for idx in _touch_widget.keys():
		if _touch_widget[idx] == w:
			_touch_widget.erase(idx)
	_up(w)


func _process(_delta: float) -> void:
	refresh()
	for w in widgets:
		if w.visible:
			w.queue_redraw()


func widget_at(pos: Vector2) -> Control:
	for w in widgets:
		if w.visible and w.contains(pos):
			return w
	return null


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			var w := widget_at(event.position)
			if w != null and not _touch_widget.values().has(w):
				_touch_widget[event.index] = w
				_down(w, event.position)
		elif _touch_widget.has(event.index):
			var w2: Control = _touch_widget[event.index]
			_touch_widget.erase(event.index)
			_up(w2)
	elif event is InputEventScreenDrag and _touch_widget.has(event.index):
		var w3: Control = _touch_widget[event.index]
		if w3.kind == "stick":
			_stick_to(event.position)


func _down(w: Control, pos: Vector2) -> void:
	w.pressed_now = true
	if w.kind == "stick":
		stick_down = true
		_stick_to(pos)
	else:
		_send(w.action, true)


func _up(w: Control) -> void:
	w.pressed_now = false
	if w.kind == "stick":
		stick_down = false
		stick_vec = Vector2.ZERO
		_apply_stick()
	else:
		_send(w.action, false)


func _stick_to(pos: Vector2) -> void:
	var v: Vector2 = (pos - STICK_CENTRE) / STICK_R
	stick_vec = v.limit_length(1.0)
	_apply_stick()


func _apply_stick() -> void:
	var x: float = stick_vec.x
	var ax: float = absf(x)
	var left: float = 0.0
	var right: float = 0.0
	if ax >= STICK_DEAD:
		var s: float = clampf((ax - STICK_DEAD) / (1.0 - STICK_DEAD), 0.0, 1.0)
		s = maxf(s, 0.35)
		if x < 0.0:
			left = s
		else:
			right = s
	_send("move_left", left > 0.0, left)
	_send("move_right", right > 0.0, right)
	_send("move_up", stick_vec.y <= -STICK_FLICK)
	_send("move_down", stick_vec.y >= STICK_FLICK)


## Press / release an action as a real input event (so `_input` handlers AND polling see it). Only changes are sent.
func _send(action: String, pressed: bool, strength: float = 1.0) -> void:
	if not InputMap.has_action(action):
		return
	var was: float = float(_held.get(action, 0.0))
	var now: float = strength if pressed else 0.0
	if is_equal_approx(was, now):
		return
	if pressed:
		_held[action] = now
	else:
		_held.erase(action)
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	ev.strength = now
	Input.parse_input_event(ev)


## Let go of everything (hidden, paused, torn down): a held direction must never outlive the overlay.
func release_all() -> void:
	for action in _held.keys():
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = false
		ev.strength = 0.0
		Input.parse_input_event(ev)
	_held.clear()
	_touch_widget.clear()
	stick_vec = Vector2.ZERO
	stick_down = false
	for w in widgets:
		w.pressed_now = false


func _exit_tree() -> void:
	release_all()
