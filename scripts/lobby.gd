extends Node

func _ready() -> void:
	var player = get_node("Player")
	if WorldState.spawn_source == "stair":
		if WorldState.stair_spawn_side == "left":
			if WorldState.stair_direction == "down":
				player.global_position = Vector2(188, 388.0)
			elif WorldState.stair_direction == "up":
				player.global_position = Vector2(148, 388.0)
		elif WorldState.stair_spawn_side == "right":
			if WorldState.stair_direction == "down":
				player.global_position = Vector2(1162, 388.0)
			elif WorldState.stair_direction == "up":
				player.global_position = Vector2(1201, 388.0)
				
# Spawn lobby zombies
	var lobby_rng = RandomNumberGenerator.new()
	lobby_rng.seed = (WorldState.master_seed ^ (1 * 2246822519)) & 0xFFFFFFFF
	var zombie_count = WorldState.get_floor_zombie_count(1)
	if zombie_count > 0:
		var zombie_scene = preload("res://scenes/enemy_zombie_standard.tscn")
		var positions = WorldState.get_zombie_positions(zombie_count, lobby_rng, 50.0, 1300.0, 388.0)
		for pos in positions:
			var zombie = zombie_scene.instantiate()
			zombie.global_position = pos
			add_child(zombie)
