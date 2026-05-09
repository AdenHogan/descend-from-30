extends Area2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		WorldState.is_first_run = false
		WorldState.new_game()
		get_tree().change_scene_to_file.call_deferred("res://scenes/hallway.tscn")
