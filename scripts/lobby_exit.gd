extends Area2D

# THE WAY OUT (owner): at the lobby door the player presses [E] — steps up into the doorway (the
# same depth walk as an apartment door) — the screen blooms WHITE: "YOU SURVIVED", who, and the
# run's stats — then fades to black and the next character's run begins (or the arc ends). Before
# stepping up they choose: scrap the whole kit at the door for Valour, or leave ONE item by the door
# for their NEXT game (WorldState "THE DOOR STASH") and forfeit its worth.
# Walking past the door no longer ends the run by accident; leaving is a choice.

var _leaving := false          # the exit runs ONCE
var _player_near := false

const PROMPT := "[{interact}] Leave the building"
const DOORWAY_X := 654.0        # the entrance's centre column (LobbyExitFx.CENTER_X)
const WALK_RISE := 27.0         # the feet climb from the lane to the vestibule floor (steps + 16 px of floor)
const WALK_DEPTH := 0.76        # drawn depth scale in the vestibule (the balcony's uses 0.74)
const WALK_TIME := 1.6          # the glare's swell (a little longer than the walk itself)


func _ready() -> void:
	add_to_group("lobby_exit")


func _process(_delta: float) -> void:
	if _leaving:
		return
	# "Is the player at the door" is asked of the physics every frame, not kept from enter / exit signals matched by the node's
	# NAME: any other body called "Player" leaving the area (a freed or swapped player node) flipped that flag off while the real
	# player stood in the doorway — no prompt, no way out (an intermittent run_bookends_test failure).
	var p = get_tree().get_first_node_in_group("player")
	var near: bool = p is PhysicsBody2D and is_instance_valid(p) and overlaps_body(p)
	if near != _player_near:
		_player_near = near
		if not near:
			HUD.hide_world_prompt(self)
	if not near:
		return
	if p.is_dead or p.is_cutscene:
		HUD.hide_world_prompt(self)
		return
	HUD.show_world_prompt(self, PROMPT, global_position + Vector2(0, -78))
	if Input.is_action_just_pressed("interact") and not TutorialManager.interact_guarded():
		leave()


func _exit_tree() -> void:
	HUD.hide_world_prompt(self)


func leave() -> void:
	if _leaving:
		return
	_leaving = true
	HUD.hide_world_prompt(self)
	var player = get_tree().get_first_node_in_group("player")
	if player != null:
		player.escaping = true             # committed: no hit or dying countdown can undo it now
	# THE DOOR: the kit is scrapped for Valour (+ a bonus for leaving nothing behind), or ONE item is
	# left by the door for a FUTURE game (the stash) — forfeiting its worth. Nothing to leave = braved.
	var left: String = await _offer_handoff()
	WorldState.note_door_scrap(left == "")   # the rest of the kit is scrapped at the door for Valour
	# Walk UP into the doorway — across the lane to its centre, up the marble steps, into the vestibule,
	# shrinking with distance while the light outside swells to meet them (the white card takes over).
	var fx = get_parent().get_node_or_null("LobbyExitFx") if get_parent() != null else null
	var surge = null
	if fx != null and fx.has_method("surge"):
		surge = fx.surge(WALK_TIME)
	if player != null and is_instance_valid(player) and player.has_method("walk_up_and_out"):
		await player.walk_up_and_out(DOORWAY_X, WALK_RISE, WALK_DEPTH)
	elif player != null and is_instance_valid(player) and player.has_method("approach_door"):
		await player.approach_door(global_position)   # (an old player without the new walk)
	if surge != null and surge.is_running():
		await surge.finished
	# Reaching the lobby and stepping out ENDS this character's story — a success. They take their
	# notes and inventory OUT of the building (no corpse; escaping is the selfish outcome — see
	# docs/THREE_RUN_ARC.md). Same time skip a death triggers.
	WorldState.mark_tutorial_completed()   # a full run: definitely not a new player
	WorldState.record_run_survived()
	WorldState.set_run_outcome(WorldState.current_run, "survived")
	var who: String = WorldState.character_display_name(WorldState.current_character())
	var line := "%s walked out into the %s." % [who, WorldState.run_name(WorldState.current_run).to_lower()]
	# WHITE card with the run's stats, then white → black; the screen stays black so the run's world
	# mutation (advance_run) never shows on the old scene.
	if not await Transition.survived_card(TutorialManager.LINES["end_survived"], line,
			WorldState.run_summary(left), WorldState.escape_art()):
		await Transition.cover()
	var arc_over: bool = WorldState.advance_run()
	# Past the point of no return: the door stash goes into the profile NOW, beside the save that
	# drops the item from the pockets (a quit during the card never duplicates or loses it).
	WorldState.commit_door_stash()
	if arc_over:
		# The THIRD character walked out — the whole playthrough is complete.
		WorldState.finish_session()      # score the session → Descent Valour + the perk offer
		WorldState.delete_save()
		HUD.hide_hud()
		get_tree().change_scene_to_file("res://scenes/game_over.tscn")
		await get_tree().process_frame
		await get_tree().process_frame
		await Transition.reveal()
		return
	# Persist the fresh run WITHOUT recording the lobby's zombies into it, then time-skip into the
	# next character's Floor 30 cold open.
	WorldState.save_game("res://scenes/hallway.tscn", false)
	Transition.to_run_start("res://scenes/hallway.tscn")   # → the cold open's time card


# Ask which item to leave behind (if there's anything to leave). Returns its name, "" for none.
func _offer_handoff() -> String:
	if WorldState.handoff_candidates().is_empty():
		return ""
	var ui = preload("res://scripts/handoff_ui.gd").new()
	get_tree().root.add_child(ui)
	ui.open()
	var slot: int = await ui.decided
	ui.queue_free()
	return WorldState.leave_for_next(slot) if slot >= 0 else ""
