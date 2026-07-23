extends Area2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		WorldState.is_first_run = false
		WorldState.new_game()
		Transition.to_scene("res://scenes/hallway.tscn")
