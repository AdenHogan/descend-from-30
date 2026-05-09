extends Node

var last_exited_apartment: int = 0

func _ready() -> void:
	if WorldState.master_seed == 0:
		WorldState.new_game()
	var player = get_node("Player")
	if WorldState.spawn_source == "stair":
		if WorldState.stair_spawn_side == "left":
			player.global_position = Vector2(148, 388.0)
		elif WorldState.stair_spawn_side == "right":
			player.global_position = Vector2(1202, 388.0)
			
	elif WorldState.spawn_source == "door" and WorldState.exit_spawn_x != 0.0:
		player.global_position.x = WorldState.exit_spawn_x

	if WorldState.spawn_source == "door" and WorldState.current_floor == 30:
		if WorldState.last_exited_apartment == 3003 and not WorldState.tutorial_zombie_spawned:
			WorldState.tutorial_zombie_spawned = true
			var zombie_scene = preload("res://scenes/enemy_zombie_standard.tscn")
			var zombie = zombie_scene.instantiate()
			zombie.global_position = Vector2(204, 368)  # adjust X to your test zombie position
			add_child(zombie)

# if spawn_source is empty, player stays at default scene position
