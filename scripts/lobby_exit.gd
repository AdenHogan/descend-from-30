extends Area2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		WorldState.mark_tutorial_completed()   # a full run: definitely not a new player
		WorldState.record_run_survived()
		WorldState.set_run_outcome(WorldState.current_run, "survived")
		WorldState.new_game()
		Transition.to_scene("res://scenes/hallway.tscn")
