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
	var next_run: int = WorldState.current_run + 1
	var arc_over: bool = WorldState.advance_run()
	if arc_over:
		# The THIRD character walked out — the whole playthrough is complete.
		WorldState.delete_save()
		HUD.hide_hud()
		get_tree().change_scene_to_file("res://scenes/game_over.tscn")
		return
	# Persist the fresh run WITHOUT recording the lobby's zombies into it, then
	# time-skip into the next character's Floor 30 arrival.
	WorldState.save_game("res://scenes/hallway.tscn", false)
	Transition.to_run_shift("res://scenes/hallway.tscn", next_run)
