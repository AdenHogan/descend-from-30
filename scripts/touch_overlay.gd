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
#   "prompt"  — only while a world prompt offers it (Use a door in combat, Force a door, Listen at a stairwell);
#   "stairs"  — the STAIRS button: walks to this floor's DOWN stairwell and takes it (stairwell.request_auto_descend).
# Owner round 36f, on the second phone playtest: a COLOUR-CODED stance button (green SCAVENGE / red COMBAT) above the big button, PUSH
# beside it, DUCK moved INTO the stick (push down = crouch, back up = stand — letting go never stands you), and the journal / avatar
# live top-left (the portrait IS the journal button; PAUSE is top-right).
# Owner round 37 ("too spaced apart on the right, some feel too small especially for larger fingers, don't always feel responsive; the
# stick makes it hard to descend a staircase"): everything is BIGGER and PACKED round the big button in one thumb arc — the sizes are
# set for the worst case, the Godot Android editor's letterboxed game window (1 canvas px is ~0.09 mm, so a 100 px target is ~9 mm, the
# smallest a thumb can hit reliably); the context buttons (STAIRS / USE / FORCE / LISTEN) take the next free slot of PROMPT_SLOTS as
# they appear instead of a column up the screen edge; and a STAIRS button walks to the down stairwell for you (on even floors that
# staircase is bottom-LEFT, right under the stick and the thumb that holds it).
# Earlier (round 36d): no RUN button (the stick's far ring is run — see STICK_SPRINT_ON) and no tiny ITEM button (the big button IS it).
# The bag is the HUD's own backpack button (bottom-right), not a copy here; tapping the in-hand box uses what is in hand.
const BUTTONS := [
	["attack", "HIT", Vector2(985, 440), 70.0, false, "primary"],
	["push", "PUSH", Vector2(845, 468), 50.0, false, "combat"],
	["mode_toggle", "COMBAT", Vector2(985, 316), 38.0, false, "always"],
	["stairs", "STAIRS", Vector2(822, 340), 44.0, false, "stairs"],
	["interact", "USE", Vector2(822, 340), 44.0, false, "prompt"],
	["item_context", "FORCE", Vector2(822, 340), 44.0, false, "prompt"],
	["listen", "LISTEN", Vector2(822, 340), 44.0, false, "prompt"],
	["pause", "PAUSE", Vector2(1104, 112), 38.0, false, "always"],
]
const MODE_PILL_HALF_W := 84.0
## Where the context buttons sit as they appear, nearest the thumb first (the first visible one takes slot 0, and so on).
const PROMPT_SLOTS := [Vector2(822, 340), Vector2(985, 212), Vector2(822, 232), Vector2(700, 410)]
const PROMPT_ORDER := ["stairs", "interact", "item_context", "listen"]
const COL_SCAV := Color(0.55, 0.9, 0.5)
const COL_COMBAT := Color(0.95, 0.4, 0.34)
const STICK_CENTRE := Vector2(160, 484)
const STICK_R := 100.0
const STICK_DEAD := 0.18                # across the stick: below this, no walk
const STICK_FLICK := 0.55               # up / down past this = move_up / move_down (and crouch / stand)
const STICK_FLICK_OFF := 0.38           # back inside this = the zone is left (so a thumb on the line doesn't chatter)
# HOW HARD you push is how fast you go (owner round 36d): from the dead zone to the rim the walk eases from a creep to a full walk (no
# stamina cost); SPRINT is a deliberate push PAST the rim, onto the dashed ring drawn outside the stick (owner round 36f: "you can run
# way too easily on mobile") — 1.3 radii = ~107 px from the centre. The game's own rules still apply (combat stance, not ducking,
# stamina). Two thresholds so a thumb resting on the ring doesn't flicker it on and off. Measured on the RAW offset (not clamped).
const STICK_SPRINT_ON := 1.3
const STICK_SPRINT_OFF := 1.12
const TAP_TIME := 0.12                  # a tapped action (crouch / stand) is held this long so a physics tick always sees the press
# RESPONSIVENESS (owner round 37: "they don't always feel responsive to touch"): a quick tap can put the touch DOWN and UP into one frame
# on a slow phone, and a press that is already let go when the game POLLS (`Input.is_action_just_pressed` in a _process / physics tick —
# doors, stairs, interact) is never seen. Every pressed action is therefore held at least MIN_HOLD before its release goes out (the
# analog walk / run axes excepted), and a second tap inside that window re-presses cleanly.
const MIN_HOLD := 0.11
const NO_MIN_HOLD := ["move_left", "move_right", "sprint"]
const SLIDE_CONTEXTS := ["primary", "combat"]    # a thumb sliding between HIT and PUSH switches; it never slides onto the stance pill / pause

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
var _pressed_ms: Dictionary = {}        # action -> when its press went out (msec)
var _release_in: Dictionary = {}        # action -> seconds until a release that was held back by MIN_HOLD goes out


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
	var stair: Node = _live_down_stair()
	for w in widgets:
		var show: bool = _widget_wanted(w, beat, ctx, stair)
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
		elif w.action == "stairs":
			var going: bool = stair != null and bool(stair.get("touch_auto"))
			w.label = "STOP" if going else "STAIRS"
			w.sub_label = "WALKING" if going else ""
			w.tint = Color(0.95, 0.75, 0.3)
			w.pulse = going
		w.pulse = w.pulse if w.action == "stairs" else (beat != "" and _action_for(w, ctx) == beat)
	_assign_prompt_slots()


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


func _widget_wanted(w: Control, beat: String, ctx: Dictionary, stair: Node = null) -> bool:
	if beat != "":
		return w.kind == "button" and _action_for(w, ctx) == beat
	match w.context:
		"primary":
			return true
		"stairs":
			return stair != null
		"combat":
			return not WorldState.is_scavenge_mode
		"prompt":
			# the big button already IS interact while scavenging — no second USE
			if w.action == "interact" and WorldState.is_scavenge_mode:
				return false
			return HUD.world_prompt_mentions("[%s]" % SettingsManager.action_text(w.action))
	return true


## The next free slot of PROMPT_SLOTS for each context button that is up, in PROMPT_ORDER (stairs first, then use / force / listen).
func _assign_prompt_slots() -> void:
	var slot := 0
	for a in PROMPT_ORDER:
		var w: Control = get_node_or_null("Btn_" + String(a))
		if w != null and w.visible:
			var at: Vector2 = PROMPT_SLOTS[mini(slot, PROMPT_SLOTS.size() - 1)]
			if not w.centre.is_equal_approx(at):
				w.set_centre(at)
			slot += 1


## This floor's live DOWN stairwell, or null: the STAIRS button is up only while there is one to go to and the player could use it
## (not mid-cutscene, dead, escaping, lashing a rope, stepped up on a back plane / the balcony, or in the tutorial before the stairs open).
func _live_down_stair() -> Node:
	var pl = get_tree().get_first_node_in_group("player")
	if pl == null or not is_instance_valid(pl) or pl.is_dead or pl.is_cutscene or pl.escaping or pl.is_lashing:
		return null
	if pl.get("back_spot") != null or pl.get("on_balcony_plane") == true or TutorialManager.stairs_locked():
		return null
	var root: Node = WorldState.owning_scene_root(pl)
	var best: Node = null
	var best_d := INF
	for st in get_tree().get_nodes_in_group("stairwell"):
		if not is_instance_valid(st) or st.get("direction") != "down" or not st.can_process() or WorldState.owning_scene_root(st) != root:
			continue
		var d: float = absf(st.global_position.x - pl.global_position.x)
		if d < best_d:
			best = st
			best_d = d
	return best


## A tap on STAIRS: walk to the down stairwell and take it; a second tap while it is walking stops. (The stairs' own rules all still apply —
## a barricade, the tutorial's gate and the one-way warning, something on the steps — because it ends in the stairwell's own `_use_stairs`.)
func _stairs_pressed() -> void:
	var st: Node = _live_down_stair()
	if st == null:
		return
	if bool(st.get("touch_auto")):
		st.cancel_auto_descend()
	else:
		st.request_auto_descend()


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
			_emit(String(a), false, 0.0)
	for a2 in _release_in.keys():                    # a release MIN_HOLD held back
		_release_in[a2] = float(_release_in[a2]) - delta
		if float(_release_in[a2]) <= 0.0:
			_release_in.erase(a2)
			_emit(String(a2), false, 0.0)
	for w in widgets:
		if w.visible:
			w.queue_redraw()


## The widget a touch at `pos` means: of every visible one whose hit area (the shape + its slop) holds the point, the NEAREST to it — so
## a thumb landing between HIT and PUSH goes to whichever it is closer to rather than to the first one in the list or to the world.
func widget_at(pos: Vector2) -> Control:
	var best: Control = null
	var best_d := INF
	for w in widgets:
		if w.visible and w.contains(pos):
			var d: float = w.edge_distance(pos)
			if d < best_d:
				best = w
				best_d = d
	return best


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
		elif SLIDE_CONTEXTS.has(w3.context):
			# the right thumb slides between HIT and PUSH: moving over the other one lets go of this and presses that
			var nw := widget_at(event.position)
			if nw != null and nw != w3 and nw.kind == "button" and SLIDE_CONTEXTS.has(nw.context) and not _touch_widget.values().has(nw) \
					and nw.edge_distance(event.position) < w3.edge_distance(event.position):
				_touch_widget[event.index] = nw
				_up(w3)
				_down(nw, event.position)


func _down(w: Control, pos: Vector2) -> void:
	w.pressed_now = true
	if w.kind == "stick":
		stick_down = true
		_stick_to(pos)
	else:
		var act: String = _action_for(w)
		_down_action[w] = act
		if act == "stairs":
			_stairs_pressed()
			return
		_send(act, true)


func _up(w: Control) -> void:
	w.pressed_now = false
	if w.kind == "stick":
		stick_down = false
		stick_vec = Vector2.ZERO
		stick_raw = Vector2.ZERO
		_apply_stick()
	else:
		var was: String = String(_down_action.get(w, w.action))
		_down_action.erase(w)
		if was != "stairs":
			_send(was, false)


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


## Press / release an action as a real input event (so `_input` handlers AND polling see it). Only changes are sent. A release that comes
## sooner than MIN_HOLD after its press is held back until MIN_HOLD is up (see above); a press that arrives while such a release is waiting
## lets go first, so the new press is a fresh edge.
func _send(action: String, pressed: bool, strength: float = 1.0) -> void:
	if not InputMap.has_action(action):
		return
	if pressed:
		if _release_in.has(action):
			_release_in.erase(action)
			_emit(action, false, 0.0)
		_emit(action, true, strength)
		return
	if not _held.has(action) or _release_in.has(action):
		return
	if not NO_MIN_HOLD.has(action):
		var age: float = float(Time.get_ticks_msec() - int(_pressed_ms.get(action, 0))) / 1000.0
		if age < MIN_HOLD:
			_release_in[action] = MIN_HOLD - age
			return
	_emit(action, false, 0.0)


## The raw send: only an actual change goes out as an event.
func _emit(action: String, pressed: bool, strength: float) -> void:
	if not InputMap.has_action(action):
		return
	var was: float = float(_held.get(action, 0.0))
	var now: float = strength if pressed else 0.0
	if is_equal_approx(was, now):
		return
	if pressed:
		if was <= 0.0:
			_pressed_ms[action] = Time.get_ticks_msec()
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
	_release_in.clear()
	_pressed_ms.clear()
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
