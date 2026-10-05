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

# [action, label, centre, radius, hold, context]. Viewport is 1152x648. `hold` = held while the finger is down;
# the rest are a press the moment the finger lands. `context` says when it is on screen:
#   "always"  — a main verb;   "primary" — THE big button: it follows what is in hand (`HUD.hand_context()` — a weapon is
#   HIT / SHOOT / DRAW, a first aid kit HEAL, an extinguisher SPRAY, a can THROW …) and presses the matching action;
#   "prompt"  — only while a world prompt offers it (Force a door, Listen at a stairwell).
# Owner round 36d, on the first phone's layout: no RUN button (the stick's rim is run — see STICK_SPRINT_ON), no second stance
# switch (the HUD's SCAVENGE / COMBAT pill is the one) and no tiny ITEM button (the big button IS the item button).
# The bag is the HUD's own backpack button (bottom-right), not a copy here; tapping the in-hand box uses what is in hand.
const BUTTONS := [
	["attack", "HIT", Vector2(1040, 500), 58.0, false, "primary"],
	["interact", "USE", Vector2(1040, 366), 42.0, false, "always"],
	["push", "PUSH", Vector2(916, 520), 40.0, false, "always"],
	["crouch_toggle", "DUCK", Vector2(1112, 290), 24.0, false, "always"],
	["listen", "LISTEN", Vector2(1112, 220), 24.0, false, "prompt"],
	["item_context", "FORCE", Vector2(1112, 150), 24.0, false, "prompt"],
	["pause", "PAUSE", Vector2(52, 48), 22.0, false, "always"],
	["open_journal", "JOURNAL", Vector2(108, 48), 22.0, false, "always"],
]
const STICK_CENTRE := Vector2(140, 500)
const STICK_R := 82.0
const STICK_DEAD := 0.22                # across the stick: below this, no walk
const STICK_FLICK := 0.6                # up / down past this = move_up / move_down
# HOW HARD you push is how fast you go (owner round 36d): from the dead zone to STICK_SPRINT_ON the walk eases from a creep to a
# full walk (no stamina cost); pushing out to the rim holds sprint (the game's own rules still apply — combat stance, not
# ducking, stamina). Two thresholds so a thumb resting on the rim doesn't flicker it on and off.
const STICK_SPRINT_ON := 0.92
const STICK_SPRINT_OFF := 0.80

var widgets: Array = []                 # the TouchWidget controls (buttons + the stick area)
var _touch_widget: Dictionary = {}      # finger index -> widget
var _held: Dictionary = {}              # action -> strength currently sent (so only changes are sent)
var stick_vec: Vector2 = Vector2.ZERO   # -1..1, for the thumb drawing + tests
var stick_down: bool = false
var sprinting: bool = false             # the stick is out at the rim → the sprint action is held (the thumb draws brighter)
var _down_action: Dictionary = {}       # widget -> the action its press sent (the big button's action changes with the hand)


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
	var ctx: Dictionary = HUD.hand_context()
	for w in widgets:
		var show: bool = _widget_wanted(w, beat, ctx)
		if w.visible and not show and _touch_widget.values().has(w):
			_release_widget(w)
		w.visible = show
		if w.context == "primary" and not ctx.is_empty():
			w.label = String(ctx["label"])        # the big button names what it will do with what is in hand
		w.pulse = beat != "" and _action_for(w, ctx) == beat


## The action a widget presses. The big button's follows the hand (attack for a weapon, item_use for a usable item).
func _action_for(w: Control, ctx: Dictionary = {}) -> String:
	if w.kind != "button":
		return ""
	if w.context == "primary":
		if ctx.is_empty():
			ctx = HUD.hand_context()
		return String(ctx.get("action", w.action))
	return w.action


func _widget_wanted(w: Control, beat: String, ctx: Dictionary) -> bool:
	if beat != "":
		return w.kind == "button" and _action_for(w, ctx) == beat and (w.context != "primary" or not ctx.is_empty())
	match w.context:
		"primary":
			return not ctx.is_empty()
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
		var act: String = _action_for(w)
		_down_action[w] = act
		_send(act, true)


func _up(w: Control) -> void:
	w.pressed_now = false
	if w.kind == "stick":
		stick_down = false
		stick_vec = Vector2.ZERO
		_apply_stick()
	else:
		_send(String(_down_action.get(w, w.action)), false)
		_down_action.erase(w)


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
		var s: float = clampf((ax - STICK_DEAD) / (STICK_SPRINT_ON - STICK_DEAD), 0.0, 1.0)
		s = maxf(s, 0.35)
		if x < 0.0:
			left = s
		else:
			right = s
	# the rim = run: held while the thumb stays out there (hysteresis), never from a vertical flick
	if sprinting:
		sprinting = ax >= STICK_SPRINT_OFF
	else:
		sprinting = ax >= STICK_SPRINT_ON
	_send("sprint", sprinting)
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
	sprinting = false
	_down_action.clear()
	for w in widgets:
		w.pressed_now = false


func _exit_tree() -> void:
	release_all()
