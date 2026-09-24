extends Area2D

# The apartment's exit. Reaching it, the player WALKS OUT THROUGH the drawn front door (owner round 9:
# "adjust the exit so that player actually leaves through the doorway… regardless of the module in
# place near the front door and regardless of whether the direction is left or right") — the room
# says where its door is (room.exit_walk_points), the player steps into the threshold and out into
# the dark corridor, THEN the scene changes. A room with no drawn door (maintenance) leaves at once.

var leave_override: Callable     # tests: called instead of the scene change
var _leaving := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body.name != "Player" or _leaving:
		return
	_leaving = true
	var room = get_parent()
	if room != null and room.has_method("exit_walk_points") and body.has_method("can_walk_out") and body.can_walk_out():
		var pts: Array = room.exit_walk_points(body)
		if pts.size() == 2:
			body.walk_out_through(pts[0], pts[1], _leave)
			return
	_leave()


func _leave() -> void:
	WorldState.spawn_source = "door"
	WorldState.last_exited_apartment = int(WorldState.current_apartment_id)
	# Clear the interaction latch on the way out — otherwise it stays true
	# from when we entered this room, and the next door's _enter_apartment()
	# silently refuses (you can't re-enter any room).
	WorldState.interaction_handled = false
	if leave_override.is_valid():
		leave_override.call()
		return
	if WorldState.current_floor == 30:
		Transition.to_scene("res://scenes/hallway.tscn")
	else:
		Transition.to_scene("res://scenes/building_floors.tscn")
