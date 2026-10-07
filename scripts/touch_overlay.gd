extends Control

# ON-SCREEN CONTROLS for phones / tablets (Android first). A fixed thumb-stick bottom-left, the action
# buttons bottom-right, a few small ones up the right edge, pause top-right. Everything presses the
# SAME actions the keyboard and pad do (InputEventAction), so no game system knows touch exists.
# Taps anywhere ELSE are ordinary clicks (the emulated mouse) — tap the floor to walk, tap a node to
# scavenge, tap a zombie to hit it (smart-click) — which is why the widgets are small and the world is left alone.
#
# Shown when SettingsManager.touch_ui_wanted() (a touchscreen in use, or forced on in Settings), while the HUD is
# up and the game isn't paused. docs/CONTROLS.md. Multi-touch: every finger is tracked by its own index.

const Stick := preload("res://scripts/touch_stick.gd")

# [action, label, centre, radius, hold, context]. Viewport is 1152x648. `hold` = held while the finger is down;
# the rest are a press the moment the finger lands. `context` says when it is on screen:
#   "always"  — a main verb;   "primary" — THE big button: it follows the stance. COMBAT: what is in hand (`HUD.hand_context()` — a
#   weapon is HIT / SHOOT, a first aid kit HEAL, an extinguisher SPRAY, a can THROW …) and presses the matching action; SCAVENGE: USE
#   (interact — open / search / take);
#   "combat"  — only in the combat stance (the small PUSH button, left of the big one so the right thumb slides between them);
#   "prompt"  — only while a world prompt offers it (Use a door in combat, Force a door, Listen at a stairwell).
# Owner round 36f, on the second phone playtest: a COLOUR-CODED stance button (green SCAVENGE / red COMBAT) above the big button, PUSH
# beside it, DUCK moved INTO the stick (push down = crouch, back up = stand — letting go never stands you), and the journal / avatar
# live top-left (the portrait IS the journal button; PAUSE is top-right).
# Earlier (round 36d): no RUN button (the stick's far ring is run — see STICK_SPRINT_ON) and no tiny ITEM button (the big button IS it).
# The bag is the HUD's own backpack button (bottom-right), not a copy here; tapping the in-hand box uses what is in hand.
const BUTTONS := [
	["attack", "HIT", Vector2(1030, 478), 56.0, false, "primary"],
	["push", "PUSH", Vector2(926, 522), 34.0, false, "combat"],
	["mode_toggle", "COMBAT", Vector2(1046, 384), 25.0, false, "always"],
	["interact", "USE", Vector2(1112, 300), 26.0, false, "prompt"],
	["listen", "LISTEN", Vector2(1112, 240), 26.0, false, "prompt"],
	["item_context", "FORCE", Vector2(1112, 180), 26.0, false, "prompt"],
	["pause", "PAUSE", Vector2(1112, 116), 22.0, false, "always"],
]
const MODE_PILL_HALF_W := 62.0
const COL_SCAV := Color(0.55, 0.9, 0.5)
const COL_COMBAT := Color(0.95, 0.4, 0.34)
const STICK_CENTRE := Vector2(140, 500)
const STICK_R := 82.0
const STICK_DEAD := 0.22                # across the stick: below this, no walk
const STICK_FLICK := 0.6                # up / down past this = move_up / move_down (and crouch / stand)
const STICK_FLICK_OFF := 0.4            # back inside this = the zone is left (so a thumb on the line doesn't chatter)
# HOW HARD you push is how fast you go (owner round 36d): from the dead zone to the rim the walk eases from a creep to a full walk (no
# stamina cost); SPRINT is a deliberate push PAST the rim, onto the dashed ring drawn outside the stick (owner round 36f: "you can run
# way too easily on mobile") — 1.3 radii = ~107 px from the centre. The game's own rules still apply (combat stance, not ducking,
# stamina). Two thresholds so a thumb resting on the ring doesn't flicker it on and off. Measured on the RAW offset (not clamped).
const STICK_SPRINT_ON := 1.3
const STICK_SPRINT_OFF := 1.12
const TAP_TIME := 0.12                  # a tapped action (crouch / stand) is held this long so a physics tick always sees the press

var widgets: Array = []                 # the TouchWidget controls (buttons + the stick area)
var _touch_widget: Dictionary = {}      # finger index -> widget
var _held: Dictionary = {}              # action -> strength currently sent (so only changes are sent)
var stick_vec: Vector2 = Vector2.ZERO   # -1..1 (clamped to the base), for tests
var stick_raw: Vector2 = Vector2.ZERO   # the thumb's offset in stick radii, NOT clamped (sprint reads it; the knob is drawn from it)
var stick_down: bool = false
var crouch_hint: bool = false           # the player is ducking (the stick's chevrons light)
var _zone_down: bool = false            # the thumb is in the push-down zone (hysteresis)
var _zone_up: bool = false
var _taps: Dictionary = {}              # action -> seconds left to hold a tapped press
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
		if String(b[0]) == "mode_toggle":
			w.make_pill(MODE_PILL_HALF_W)
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
	var ctx: Dictionary = _primary_ctx()
	var scav: bool = WorldState.is_scavenge_mode
	var stance: Color = COL_SCAV if scav else COL_COMBAT
	var pl = get_tree().get_first_node_in_group("player")
	crouch_hint = pl != null and is_instance_valid(pl) and pl.get("is_crouching") == true
	for w in widgets:
		var show: bool = _widget_wanted(w, beat, ctx)
		if w.visible and not show and _touch_widget.values().has(w):
			_release_widget(w)
		w.visible = show
		if w.context == "primary":
			w.label = String(ctx["label"])        # the big button names what it will do right now
			w.tint = stance
		elif w.action == "push":
			w.tint = COL_COMBAT
		elif w.action == "mode_toggle":
			w.label = "SCAVENGE" if scav else "COMBAT"
			w.sub_label = "TAP TO SWITCH"
			w.tint = stance
		w.pulse = beat != "" and _action_for(w, ctx) == beat


## What the big button does. Scavenging it is USE (the search / open / take verb — nodes and doors can also be tapped in the world);
## in combat it follows the hand (HIT with nothing, SHOOT, HEAL …).
func _primary_ctx() -> Dictionary:
	if WorldState.is_scavenge_mode:
		return {"label": "USE", "action": "interact"}
	var ctx: Dictionary = HUD.hand_context()
	if ctx.is_empty():
		ctx = {"label": "HIT", "action": "attack"}
	return ctx


## The action a widget presses. The big button's follows the stance + hand.
func _action_for(w: Control, ctx: Dictionary = {}) -> String:
	if w.kind != "button":
		return ""
	if w.context == "primary":
		if ctx.is_empty():
			ctx = _primary_ctx()
		return String(ctx.get("action", w.action))
	return w.action


func _widget_wanted(w: Control, beat: String, ctx: Dictionary) -> bool:
	if beat != "":
		return w.kind == "button" and _action_for(w, ctx) == beat
	match w.context:
		"primary":
			return true
		"combat":
			return not WorldState.is_scavenge_mode
		"prompt":
			# the big button already IS interact while scavenging — no second USE
			if w.action == "interact" and WorldState.is_scavenge_mode:
				return false
			return HUD.world_prompt_mentions("[%s]" % SettingsManager.action_text(w.action))
	return true


func _release_widget(w: Control) -> void:
	for idx in _touch_widget.keys():
		if _touch_widget[idx] == w:
			_touch_widget.erase(idx)
	_up(w)


func _process(delta: float) -> void:
	refresh()
	for a in _taps.keys():
		_taps[a] = float(_taps[a]) - delta
		if float(_taps[a]) <= 0.0:
			_taps.erase(a)
			_send(String(a), false)
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
		stick_raw = Vector2.ZERO
		_apply_stick()
	else:
		_send(String(_down_action.get(w, w.action)), false)
		_down_action.erase(w)


func _stick_to(pos: Vector2) -> void:
	stick_raw = (pos - STICK_CENTRE) / STICK_R
	stick_vec = stick_raw.limit_length(1.0)
	_apply_stick()


func _apply_stick() -> void:
	var x: float = clampf(stick_raw.x, -1.0, 1.0)
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
	# the far ring = run: held while the thumb stays out there (hysteresis), never from a vertical flick
	var rax: float = absf(stick_raw.x)
	if sprinting:
		sprinting = rax >= STICK_SPRINT_OFF
	else:
		sprinting = rax >= STICK_SPRINT_ON
	_send("sprint", sprinting)
	_send("move_left", left > 0.0, left)
	_send("move_right", right > 0.0, right)
	# up / down: the actions (stairs, the balcony, back-plane steps, the lift) AND the duck. Only the ENTRY into a zone ducks or
	# stands — pushing down crouches, pushing back up stands, and letting go of the stick does NOTHING (owner round 36f).
	var down_now: bool = stick_raw.y >= (STICK_FLICK_OFF if _zone_down else STICK_FLICK)
	var up_now: bool = stick_raw.y <= -(STICK_FLICK_OFF if _zone_up else STICK_FLICK)
	if down_now and not _zone_down:
		_duck_edge(true)
	if up_now and not _zone_up:
		_duck_edge(false)
	_zone_down = down_now
	_zone_up = up_now
	_send("move_up", up_now)
	_send("move_down", down_now)


## The stick crossing into its down / up zone: crouch / stand — unless the player is on a plane where that same push already means
## something else (stepping down off the back plane / the balcony, standing up from the pack), or is already in the asked-for stance.
func _duck_edge(want_crouch: bool) -> void:
	var pl = get_tree().get_first_node_in_group("player")
	if pl == null or not is_instance_valid(pl):
		return
	if (pl.get("is_crouching") == true) == want_crouch:
		return
	if pl.get("back_spot") != null or pl.get("on_balcony_plane") == true or str(pl.get("pack_phase")) not in ["", "<null>"]:
		return
	_tap("crouch_toggle")


## A press that lets go by itself a moment later (the duck / stand toggle) — held long enough that the player's physics tick sees it.
func _tap(action: String) -> void:
	_send(action, true)
	_taps[action] = TAP_TIME


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
	_taps.clear()
	_touch_widget.clear()
	stick_vec = Vector2.ZERO
	stick_raw = Vector2.ZERO
	_zone_down = false
	_zone_up = false
	stick_down = false
	sprinting = false
	_down_action.clear()
	for w in widgets:
		w.pressed_now = false


func _exit_tree() -> void:
	release_all()
