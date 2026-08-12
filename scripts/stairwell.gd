extends Area2D

@export var target_scene: String = "res://scenes/building_floors.tscn"
@export var stair_side: String = "left"
@export var direction: String = "down"

var player_nearby = false
var bounce_time = 0.0
var arrow = null
var _herd_said = false
var _descend_confirm_time = 0.0
const DESCEND_CONFIRM_WINDOW = 4.0

# Heavy-horde crossing: a blocked down-stairwell is levered open with a Crowbar
# over a channeled PRY (loud from the first heave, so the current floor's dead
# come to investigate). Cancels on walking off the steps or any other action.
const PRY_TIME := 6.0   # long enough that the floor's roused dead can close in
var is_prying: bool = false
var pry_timer: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	input_event.connect(_on_click)
	arrow = find_child("Label")
	if arrow:
		arrow.visible = false
	# Down-stairwells offer a listen read of the floor below (SOUND_STEALTH.md).
	# The prompt (and the pry countdown) render through the crisp screen-space HUD
	# system (HUD.show_world_prompt), same as door/loot prompts — no world-space
	# label the camera would magnify and blur.


# Float the pill just above the stairwell arrow (tune here if it sits wrong).
func _prompt_anchor() -> Vector2:
	return global_position + Vector2(0, -34)


func _show_listen_prompt() -> void:
	if direction == "down":
		HUD.show_world_prompt(self, "[R] Listen below", _prompt_anchor())

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player_nearby = true
		if arrow:
			arrow.visible = true
		_show_listen_prompt()
		# Tutorial (first-run Floor 30): the descent is gated until the 3003
		# neighbour is dealt with — nudge the player back toward the apartments.
		if direction == "down" and TutorialManager.stairs_locked():
			_herd_back(body)

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		player_nearby = false
		_herd_said = false
		if is_prying:
			_cancel_pry("You back off the stairwell.")   # walked away mid-pry
		if arrow:
			arrow.visible = false
		HUD.hide_world_prompt(self)

func _process(_delta: float) -> void:
	if is_prying:
		_tick_pry(_delta)
		return
	if player_nearby and arrow:
		bounce_time += _delta
		arrow.position.y = -80 + sin(bounce_time * 4.0) * 8.0
	if player_nearby and direction == "down" and Input.is_action_just_pressed("listen"):
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_method("start_listen"):
			var report = WorldState.get_listen_report_for_floor_below()
			player.start_listen(global_position, report)
			return
	# W (move_up) takes the stairs — same key as stepping up into a balcony, so
	# "up" is the one verb for every vertical transition. (E still opens doors.)
	if player_nearby and Input.is_action_just_pressed("move_up") and not TutorialManager.interact_guarded():
		_use_stairs()


# Clicking to change floors must be a DELIBERATE act: only the narrow column
# under the bouncing arrow counts. Clicking anywhere else in the stairwell —
# including just left or right of the steps — is ordinary click-to-move, so you
# can reposition without being yanked to another floor.
const CLICK_HALF_WIDTH := 16.0   # horizontal window, centred on the arrow
const CLICK_ABOVE := 70.0        # how far above the trigger still counts
const CLICK_BELOW := 40.0


func _on_click(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	# Area2D pick path. Kept, but NOT relied on — see _unhandled_input below.
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if not player_nearby:
		return
	get_viewport().set_input_as_handled()
	_use_stairs()


func _unhandled_input(event: InputEvent) -> void:
	# Left-click the stairwell to use it, same as E. This does NOT go through
	# Area2D input_event: physics picking depends on viewport settings and on
	# nothing else having eaten the click first, and it had stopped firing here
	# while E still worked. A plain distance test against the click's world
	# position is immune to all of that.
	if not player_nearby:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var world: Vector2 = get_global_mouse_position()
	if absf(world.x - global_position.x) > CLICK_HALF_WIDTH:
		return   # beside the steps: let the player walk there instead
	if world.y < global_position.y - CLICK_ABOVE or world.y > global_position.y + CLICK_BELOW:
		return
	get_viewport().set_input_as_handled()
	_use_stairs()


func _on_no_return() -> void:
	pass


func _herd_back(body: Node2D) -> void:
	# Say the stage's line once per approach, and steer the player toward the
	# apartment the tutorial wants them in next (no herding while the corridor
	# zombie is live — target_x < 0).
	var info = TutorialManager.stair_block_info()
	if info.is_empty():
		return
	if not _herd_said:
		TutorialManager.say(info["line"])
		_herd_said = true
	if info["target_x"] >= 0.0 and body.has_method("set_move_target"):
		body.set_move_target(info["target_x"])


func _use_stairs() -> void:
	# Tutorial run: no going back UP to Floor 30 (its scripted rooms are a
	# one-way door — actions have consequences). Pause + refuse.
	if direction == "up" and WorldState.is_first_run and WorldState.current_floor == 29:
		TutorialManager.prompt(TutorialManager.LINES["no_return"], "interact", _on_no_return, "[E]")
		return

	# Gate the first-run Floor-30 descent until the 3003 key is in hand.
	if direction == "down" and TutorialManager.stairs_locked():
		var player = get_tree().get_first_node_in_group("player")
		if player != null:
			_herd_back(player)
		return

	# After the key, descending Floor 30 is a ONE-WAY choice (end the tutorial
	# early / leave apartments unsearched). Warn once, then commit on a second
	# use of the stairs; walking away lets the warning lapse.
	if direction == "down" and WorldState.is_first_run and WorldState.current_floor == 30:
		var now = Time.get_ticks_msec() / 1000.0
		if now - _descend_confirm_time > DESCEND_CONFIRM_WINDOW:
			TutorialManager.say(TutorialManager.LINES["stairs_choice"])
			_descend_confirm_time = now
			return
		# second use within the window → confirmed, fall through and descend.

	# A barricaded stairwell blocks the crossing in EITHER direction until it's
	# levered open with a Crowbar — you can't slip up past it any more than down.
	if WorldState.is_stair_blocked(_choke_floor()):
		if is_prying:
			return   # already levering — don't restart the channel
		if not WorldState.has_crowbar():
			TutorialManager.say("Someone's barricaded the stairwell — furniture, planks, the lot, wedged in tight. I'd need a crowbar to lever it apart.")
			return
		_begin_pry()
		return

	# Hazard 2 — a horde packing the steps: no crowbar, you clear them out or draw
	# them off (a thrown can) before the way is yours. Blocks while any live zombie
	# is right on the stairwell.
	if WorldState.is_stair_horde(_choke_floor()) and _horde_blocking():
		TutorialManager.say("The stairwell's swarming — no getting through until I clear them out or draw them off.")
		return

	_perform_transition()


const HORDE_BLOCK_RANGE := 300.0


func _horde_blocking() -> bool:
	# The steps are contested while any live zombie is within range of them.
	# Killing them clears it for good; luring them off (a can) frees it while they
	# are away.
	for z in get_tree().get_nodes_in_group("zombie"):
		if z.is_dead:
			continue
		if z.global_position.distance_to(global_position) <= HORDE_BLOCK_RANGE:
			return true
	return false


func _choke_floor() -> int:
	# Which floor indexes the staircase this traversal uses. A choke sits on the
	# staircase BETWEEN two floors, keyed by the upper floor's down-stair: descending
	# from N uses N; ascending from N uses N+1 (the same steps, from below).
	return WorldState.current_floor if direction == "down" else WorldState.current_floor + 1


func _perform_transition() -> void:
	# Snap ONTO the stairwell before the transition takes over. Triggering from a
	# step or two off-centre used to leave the player half in the stairs and half
	# in the wall for the whole descent.
	var body = get_tree().get_first_node_in_group("player")
	if body != null:
		body.global_position.x = global_position.x

	WorldState.stair_spawn_side = stair_side
	WorldState.stair_direction = direction
	WorldState.spawn_source = "stair"
	var target_floor = WorldState.current_floor + (-1 if direction == "down" else 1)

	# Seamless pan between two mid-building floors when enabled; it commits the
	# floor + scene change itself. Otherwise (and always, while disabled) the
	# plain fade cut below.
	# >>> TO ENABLE THE STAIR PAN: set `const ENABLED := true` at the top of
	#     scripts/stair_pan.gd (that's the toggle — not here / not building_floors).
	if StairPan.can_pan(target_floor):
		StairPan.pan_to_floor(target_floor, direction)
		return

	WorldState.current_floor = target_floor
	WorldState.on_floor_arrived(WorldState.current_floor)
	HUD.update_floor_label()
	if WorldState.current_floor == 30:
		Transition.to_scene("res://scenes/hallway.tscn")
	elif WorldState.current_floor == 0:
		Transition.to_scene("res://scenes/lobby.tscn")
	else:
		Transition.to_scene("res://scenes/building_floors.tscn")


# --- Crowbar pry (heavy stairwell horde) ----------------------------------

func _begin_pry() -> void:
	is_prying = true
	pry_timer = PRY_TIME
	# Loud from the first heave — draws the current floor's dead toward the steps
	# and snaps any can-distracted ones back (same door_work loudness as forcing).
	WorldState.emit_noise(global_position, WorldState.NOISE_RADIUS["door_work"], PRY_TIME)
	HUD.show_world_prompt(self, "Prying... %.1fs" % pry_timer, _prompt_anchor())
	TutorialManager.say("Come on... get the claw in and heave. Almost through...")


func _tick_pry(delta: float) -> void:
	# Any other committed action cancels the pry (no partial progress banked).
	var player = get_tree().get_first_node_in_group("player")
	if player != null and (player.is_attacking or player.is_pushing
			or player.is_switching_mode or player.is_listening):
		_cancel_pry("Prying interrupted.")
		return
	pry_timer -= delta
	HUD.show_world_prompt(self, "Prying... %.1fs" % max(pry_timer, 0.0), _prompt_anchor())
	if pry_timer <= 0.0:
		_commit_pry()


func _cancel_pry(reason: String) -> void:
	if not is_prying:
		return
	is_prying = false
	pry_timer = 0.0
	if player_nearby:
		_show_listen_prompt()
	else:
		HUD.hide_world_prompt(self)
	HUD.show_feedback(reason)


func _commit_pry() -> void:
	is_prying = false
	pry_timer = 0.0
	HUD.hide_world_prompt(self)   # about to transition off this floor
	# Spend the crowbar and commit the crossing (works either direction): opens the
	# stairwell for the run, shifts the building (enemies move, no heal), costs a
	# rest slot, and musters the arrival floor's horde at the stairwell.
	var arrival: int = WorldState.current_floor + (-1 if direction == "down" else 1)
	WorldState.consume_crowbar()
	WorldState.cross_blocked_stair(_choke_floor(), arrival)
	# Make the building shift legible — it's the whole cost of the crossing.
	HUD.show_feedback("The way's open — but the building just shifted. The dead have moved.")
	TutorialManager.say("Through... but I heard them move. Whole place has shifted around me.")
	_perform_transition()
