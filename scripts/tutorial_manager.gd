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

var _awaiting: bool = false
var _await_action: String = ""
var _await_cb: Callable = Callable()
var _await_strict: bool = false


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
			return {"line": "The stairwell's a death trap empty-handed — the neighbour in 3003 might have a spare key. Check there first.",
					"target_x": 570.0}
		"apts":
			var target = 696.0 if not WorldState.was_key_opened("3002") else 444.0
			return {"line": "Not yet — I should search the other apartments before I go down.",
					"target_x": target}
		"choice":
			# The zombie is live in the corridor — no herding INTO it, just
			# the refusal.
			return {"line": "Not with that thing loose — deal with it, or get through 3004.",
					"target_x": -1.0}
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


func _process(_delta: float) -> void:
	if not _awaiting:
		return
	var pressed = Input.is_action_just_pressed(_await_action)
	if not _await_strict:
		# Loose beats also take a generic continue (E / Space).
		pressed = pressed or Input.is_action_just_pressed("interact") \
				or Input.is_action_just_pressed("jump")
	if pressed:
		_resume()


func _resume() -> void:
	_awaiting = false
	get_tree().paused = false
	HUD.hide_dialogue()
	var cb := _await_cb
	_await_cb = Callable()
	if cb.is_valid():
		cb.call()


func cancel() -> void:
	# Safety: drop any pending prompt (e.g. if the scene is torn down).
	_awaiting = false
	_await_cb = Callable()
	if get_tree() != null:
		get_tree().paused = false
	HUD.hide_dialogue()
