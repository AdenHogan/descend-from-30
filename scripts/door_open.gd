extends Area2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		WorldState.spawn_source = "door"
		WorldState.last_exited_apartment = int(WorldState.current_apartment_id)
		# Clear the interaction latch on the way out — otherwise it stays true
		# from when we entered this room, and the next door's _enter_apartment()
		# silently refuses (you can't re-enter any room).
		WorldState.interaction_handled = false
		if WorldState.current_floor == 30:
			Transition.to_scene("res://scenes/hallway.tscn")
		else:
			Transition.to_scene("res://scenes/building_floors.tscn")
