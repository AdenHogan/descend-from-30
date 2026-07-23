extends Node

# Autoload. Coordinates the first-run Floor 30 tutorial: player dialogue
# prompts, the gameplay-PAUSE teaching beats, and the stairwell descent gate.
# The 3003 encounter's frame-by-frame choreography lives in room.gd (it is
# scene-coupled); this singleton owns the cross-scene pieces — the dialogue
# UI hand-off, the paused "press-a-key" prompts, and whether the stairs are
# unlocked yet. See docs/TUTORIAL.md.
#
# PROCESS_MODE_ALWAYS so the prompt poll keeps ticking while the tree is paused
# (a paused beat waits here for the player's key, then resumes the game).

# The scripted zombies' fixed spawn keys. Both persist in killed_zombies, so
# the descent gate's milestones survive save/load and re-entry for free.
const TUTORIAL_ZOMBIE_KEY := "3003:tutorial"
const HALLWAY_ZOMBIE_KEY := "30hall:tutorial"

# ==========================================================================
# ALL TUTORIAL DIALOGUE LIVES HERE — this is the single place to edit the
# player's spoken lines. They are placeholders; rewrite the strings freely
# (keep the keys). Nothing else needs to change. Referenced as
# TutorialManager.LINES["<key>"] from hallway.gd / room.gd.
# ==========================================================================
const LINES := {
	# --- Opener (black-screen intro, first run) ---
	"opener_1": "Huh? What the hell's going on out there?",
	"opener_2": "— the door! No, no, no —",
	"opener_3": "Locked myself out. Brilliant.",
	"opener_4": "Come on, open up! ...Anyone in there?",
	"opener_5": "No answer. ...The spare. The neighbour in 3003 keeps a spare key — I need to get in there.",
	# --- 3003 scripted encounter ---
	"3003_curiosity": "Mrs Delacroix…? Are you okay in there?",
	"3003_push": "It's on me — shove it back!",
	"3003_weapon": "That won't hold it — I need a weapon. Search the room!",
	"3003_weapon_go": "Anything I can swing — hurry!",
	"3003_combat": "A club — good. Time to swing until it goes down.",
	"3003_combat_go": "Two solid hits.",
	"3003_heal": "It got me back there — I should patch up with those bandages.",
	"3003_key": "Wait… this isn't my spare key. It's for next door — 3002. Worth a look.",
	# --- 3002 reward room ---
	"3002_entry": "So this is what the key kept safe. Take what helps — then find the stairs. It's a long way down.",
	# --- Misc tutorial one-shots ---
	"first_cash": "I left my wallet back in my room. Maybe I'll find another one on the way down.",
	"no_return": "No. I need to get to the lobby — going home isn't an option any more.",
	# --- 3004 barricade beat ---
	"3004_hint": "This one's barricaded. I could tear it down — probably faster if I pry at it with a weapon.",
	"hall_zombie": "Something heard that — it's coming up the stairs!",
	"hall_choice": "That lock looks forceable — but this club's nearly spent. Enough for ONE more job: force 3004 and take the room, OR put the thing down and take whatever it's carrying. Not both.",
	"hall_force_break": "Damn — it snapped. Get inside, fast.",
	# --- Staged stairs gate ---
	"stairs_key": "The stairwell's a death trap empty-handed — the neighbour in 3003 might have a spare key. Check there first.",
	"stairs_apts": "Not yet — I should search the other apartments before I go down.",
	"stairs_choice": "Not with that thing loose — deal with it, or get through 3004.",
}

var _awaiting: bool = false
var _await_action: String = ""
var _await_cb: Callable = Callable()
var _await_strict: bool = false
# The key that dismisses a paused prompt (usually E) is still "just pressed" the
# frame the game resumes, so polling handlers (door enter, stair use) would fire
# on that same press — a single tap doing two things. After a resume we mark a
# brief guard window that those handlers check.
var _interact_guard_msec: int = 0
const INTERACT_GUARD_MS := 300


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_active() -> bool:
	# The scripted tutorial only runs on the very first character's Floor 30.
	return WorldState.is_first_run and WorldState.current_floor == 30


func stair_stage() -> String:
	# The Floor-30 descent gate is STAGED along the mandatory path:
	#   "key"    — 3003 neighbour still up: go get the spare key.
	#   "apts"   — key gotten, 3004 barricade still standing: search the
	#              other apartments (leads the player into the barricade beat).
	#   "choice" — barricade down, the noise-drawn zombie is live and 3004 is
	#              still shut: resolve the force-vs-fight choice first.
	#   "open"   — free to descend.
	if not is_active():
		return "open"
	if not WorldState.killed_zombies.has(TUTORIAL_ZOMBIE_KEY):
		return "key"
	var d3004 = WorldState.get_door_state("3004")
	if d3004 == WorldState.DoorState.BARRICADED_LOCKED or d3004 == WorldState.DoorState.BARRICADED_FORCEABLE:
		return "apts"
	if d3004 != WorldState.DoorState.OPEN and not WorldState.killed_zombies.has(HALLWAY_ZOMBIE_KEY):
		return "choice"
	return "open"


func stairs_locked() -> bool:
	return stair_stage() != "open"


func stair_block_info() -> Dictionary:
	# What the stairwell should say + where to herd the player, per stage.
	# target_x are hallway door positions (3002=696, 3003=570, 3004=444).
	# Empty dict = descent is open.
	match stair_stage():
		"key":
			return {"line": LINES["stairs_key"], "target_x": 570.0}
		"apts":
			var target = 696.0 if not WorldState.was_key_opened("3002") else 444.0
			return {"line": LINES["stairs_apts"], "target_x": target}
		"choice":
			# The zombie is live in the corridor — no herding INTO it, just
			# the refusal.
			return {"line": LINES["stairs_choice"], "target_x": -1.0}
	return {}


# --- Dialogue -------------------------------------------------------------

func say(text: String) -> void:
	# A transient first-person line (auto-hides). No pause.
	HUD.show_dialogue(text)


var _said_once: Dictionary = {}

func say_once(tag: String, text: String) -> void:
	# A one-shot line keyed by tag (first entry to a room, etc.). Resets per
	# app run — fine for placeholder dialogue.
	if _said_once.get(tag, false):
		return
	_said_once[tag] = true
	say(text)


func prompt(text: String, action: String, cb: Callable, hint: String = "", strict: bool = false) -> void:
	# A teaching beat: freeze the game, show the line + an action hint, and wait
	# for `action`. When the player presses it, unpause and run `cb`. `strict`
	# beats (e.g. the push intro) accept ONLY their action; loose beats also
	# take a generic "continue" so the player is never stuck.
	HUD.show_dialogue(text, hint if hint != "" else _default_hint(action), true)
	_await_action = action
	_await_cb = cb
	_await_strict = strict
	_awaiting = true
	get_tree().paused = true


func _default_hint(action: String) -> String:
	match action:
		"push": return "[Push]"
		"interact": return "[E]"
		"attack": return "[Attack]"
		_: return "[Continue]"


func _input(event: InputEvent) -> void:
	if not _awaiting:
		return
	var advance := false
	if _await_strict:
		# A teaching beat (the push intro) still needs its own action.
		if event.is_action_pressed(_await_action):
			advance = true
	else:
		# "Press-any-key" convenience: any key OR mouse click continues.
		if (event is InputEventKey and event.pressed and not event.echo) \
				or (event is InputEventMouseButton and event.pressed):
			advance = true
	if advance:
		get_viewport().set_input_as_handled()
		_resume()


func _resume() -> void:
	_awaiting = false
	get_tree().paused = false
	HUD.hide_dialogue()
	_interact_guard_msec = Time.get_ticks_msec()
	var cb := _await_cb
	_await_cb = Callable()
	if cb.is_valid():
		cb.call()


func guard_interact() -> void:
	# Public: start the brief interact-guard window (used by the opener so the
	# closing E doesn't drive a door/stair the frame control returns).
	_interact_guard_msec = Time.get_ticks_msec()


func interact_guarded() -> bool:
	# True briefly after a prompt resume: the dismissing key press must not also
	# drive a door/stair on the same frame.
	return Time.get_ticks_msec() - _interact_guard_msec < INTERACT_GUARD_MS


func cancel() -> void:
	# Safety: drop any pending prompt (e.g. if the scene is torn down).
	_awaiting = false
	_await_cb = Callable()
	if get_tree() != null:
		get_tree().paused = false
	HUD.hide_dialogue()
