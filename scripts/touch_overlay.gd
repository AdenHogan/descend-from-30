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

# [action, label, centre, radius, hold]. Viewport is 1152x648. `hold` = held while the finger is down
# (sprint); the rest are a press the moment the finger lands.
const BUTTONS := [
	["attack", "HIT", Vector2(1030, 520), 52.0, false],
	["interact", "USE", Vector2(1030, 404), 38.0, false],
	["push", "PUSH", Vector2(924, 548), 34.0, false],
	["sprint", "RUN", Vector2(924, 452), 32.0, true],
	["crouch_toggle", "DUCK", Vector2(826, 584), 26.0, false],
	["item_context", "FORCE", Vector2(1108, 176), 24.0, false],
	["listen", "LISTEN", Vector2(1108, 232), 24.0, false],
	["mode_toggle", "MODE", Vector2(1108, 288), 24.0, false],
	["open_pack", "PACK", Vector2(1108, 344), 24.0, false],
	["item_use", "ITEM", Vector2(1108, 400), 24.0, false],
	["pause", "PAUSE", Vector2(52, 48), 22.0, false],
	["open_journal", "JOURNAL", Vector2(108, 48), 22.0, false],
]
const STICK_CENTRE := Vector2(140, 505)
const STICK_R := 85.0
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
		add_child(w)
		widgets.append(w)


## Show / hide for the device in use and the state of the game; always lets go of everything when it hides.
func refresh() -> void:
	var want: bool = SettingsManager.touch_ui_wanted() and HUD.visible and not get_tree().paused
	if want != visible:
		visible = want
	if not want:
		release_all()


func _process(_delta: float) -> void:
	refresh()
	for w in widgets:
		w.queue_redraw()


func widget_at(pos: Vector2) -> Control:
	for w in widgets:
		if w.contains(pos):
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
