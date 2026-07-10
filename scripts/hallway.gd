extends Node


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

	if WorldState.saved_player_x != 0.0:
		player.global_position = Vector2(WorldState.saved_player_x, WorldState.saved_player_y)
		WorldState.saved_player_x = 0.0
		WorldState.saved_player_y = 0.0

	if WorldState.spawn_source == "door" and WorldState.current_floor == 30:
		if WorldState.last_exited_apartment == 3003 and not WorldState.tutorial_zombie_spawned:
			WorldState.tutorial_zombie_spawned = true
			var zombie_scene = preload("res://scenes/enemy_zombie_standard.tscn")
			var zombie = zombie_scene.instantiate()
			zombie.global_position = Vector2(204, 368)
			zombie.spawn_key = str(30) + ":204.0:368.0"
			add_child(zombie)

	_spawn_corpses(30)
	_spawn_world_drops(30)

func _spawn_corpses(floor_num: int) -> void:
	var scene_path = get_tree().current_scene.scene_file_path
	var corpse_positions = WorldState.get_corpse_positions_for_floor(floor_num, scene_path)
	if corpse_positions.is_empty():
		return
	# Corpse visuals are type-aware: standard zombies have a looping "Dead_Dead"
	# frame; the big zombie has no Dead_Dead, so its corpse shows the final frame
	# of its "Death" animation, paused.
	var std_instance = preload("res://scenes/enemy_zombie_standard.tscn").instantiate()
	var std_frames = std_instance.get_node("AnimatedSprite2D").sprite_frames
	std_instance.queue_free()
	var big_instance = preload("res://scenes/enemy_zombie_big.tscn").instantiate()
	var big_frames = big_instance.get_node("AnimatedSprite2D").sprite_frames
	big_instance.queue_free()
	for entry in corpse_positions:
		var corpse = AnimatedSprite2D.new()
		corpse.scale = Vector2(3, 3)
		if entry["type"] == "big":
			corpse.sprite_frames = big_frames
			corpse.animation = "Death"
			corpse.frame = big_frames.get_frame_count("Death") - 1
		else:
			corpse.sprite_frames = std_frames
			corpse.animation = "Dead_Dead"
			corpse.autoplay = "Dead_Dead"
		corpse.global_position = entry["pos"]
		corpse.z_index = 0
		add_child(corpse)

func _spawn_world_drops(floor_num: int) -> void:
	var scene_path = get_tree().current_scene.scene_file_path
	var drops = WorldState.get_world_drops_for_floor(floor_num, scene_path)
	if drops.is_empty():
		return
	var drop_scene = preload("res://scenes/world_drop.tscn")
	for drop_key in drops:
		var data = drops[drop_key]
		var drop = drop_scene.instantiate()
		drop.item_id = data["item_id"]
		drop.drop_key = drop_key
		drop.target_apartment = data.get("target_apartment", "")
		drop.global_position = Vector2(data["x"], data["y"])
		add_child(drop)
