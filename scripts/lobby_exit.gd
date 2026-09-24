extends Area2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.name != "Player":
		return
	# Reaching the lobby and stepping out ENDS this character's story — a success.
	# They take their notes and inventory OUT of the building (no corpse to recover;
	# escaping is the selfish outcome — see docs/THREE_RUN_ARC.md). Per the arc, this
	# triggers the same time skip a death does and hands over to the next character.
	WorldState.mark_tutorial_completed()   # a full run: definitely not a new player
	WorldState.record_run_survived()
	WorldState.set_run_outcome(WorldState.current_run, "survived")
	# The END CARD (same bookend as a death), leaving the screen black BEFORE advancing so the
	# run's world mutation never shows on the old scene.
	var who: String = WorldState.character_display_name(WorldState.current_character())
	if not await Transition.end_card(TutorialManager.LINES["end_escaped"],
			"%s made it out of the building." % who, Transition.END_ESCAPED_COLOR):
		await Transition.cover()
	var arc_over: bool = WorldState.advance_run()
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
	# Persist the fresh run WITHOUT recording the lobby's zombies into it, then
	# time-skip into the next character's Floor 30 arrival.
	WorldState.save_game("res://scenes/hallway.tscn", false)
	Transition.to_run_start("res://scenes/hallway.tscn")   # → the cold open's time card
