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

# The 3003 scripted zombie's fixed spawn key. Clearing it (killing it) is the
# milestone that unlocks Floor-30 descent — and it persists in killed_zombies,
# so the gate survives save/load and re-entry for free.
const TUTORIAL_ZOMBIE_KEY := "3003:tutorial"

var _awaiting: bool = false
var _await_action: String = ""
var _await_cb: Callable = Callable()
var _await_strict: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_active() -> bool:
	# The scripted tutorial only runs on the very first character's Floor 30.
	return WorldState.is_first_run and WorldState.current_floor == 30


func stairs_locked() -> bool:
	# Floor-30 descent is gated until the 3003 encounter is cleared (the doc's
	# "player has the 3002 key = cleared 3003" milestone).
	return is_active() and not WorldState.killed_zombies.has(TUTORIAL_ZOMBIE_KEY)


# --- Dialogue -------------------------------------------------------------

func say(text: String) -> void:
	# A transient first-person line (auto-hides). No pause.
	HUD.show_dialogue(text)


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
