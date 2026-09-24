extends Area2D

# THE WAY OUT (owner): at the lobby door the player presses [E] — steps up into the doorway (the
# same depth walk as an apartment door) — the screen blooms WHITE: "YOU SURVIVED", who, and the
# run's stats — then fades to black and the next character's run begins (or the arc ends). Before
# stepping up they choose: scrap the whole kit at the door for Valour, or leave ONE item by the door
# for their NEXT game (WorldState "THE DOOR STASH") and forfeit its worth.
# Walking past the door no longer ends the run by accident; leaving is a choice.

var _leaving := false          # the exit runs ONCE
var _player_near := false

const PROMPT := "[E] Leave the building"


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		_player_near = true


func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		_player_near = false
		HUD.hide_world_prompt(self)


func _process(_delta: float) -> void:
	if _leaving or not _player_near:
		return
	var p = get_tree().get_first_node_in_group("player")
	if p == null or p.is_dead or p.is_cutscene:
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
	# Step up into the doorway, like any door.
	if player != null and is_instance_valid(player) and player.has_method("approach_door"):
		await player.approach_door(global_position)
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
