extends Node

const SPAWN_LEFT_TOP = Vector2(148, 391)
const SPAWN_LEFT_BOTTOM = Vector2(188, 391)
const SPAWN_RIGHT_TOP = Vector2(1201, 391)
const SPAWN_RIGHT_BOTTOM = Vector2(1162, 391)

func _ready() -> void:
	var player = get_node("Player")
	var hallway_staircase_left = get_node("HallwayStaircaseLeft")
	var lobby_left = get_node("LobbyLeft")
	var hallway_staircase_right = get_node("HallwayStaircaseRight")
	var lobby_right = get_node("LobbyRight")
	var left_down = get_node("stair_left_down_trigger")
	var left_up = get_node("stair_left_up_trigger")
	var right_down = get_node("stair_right_down_trigger")
	var right_up = get_node("stair_right_up_trigger")

	if WorldState.spawn_source == "stair":
		if WorldState.stair_spawn_side == "left":
			if WorldState.stair_direction == "down":
				player.global_position = SPAWN_LEFT_BOTTOM
			elif WorldState.stair_direction == "up":
				player.global_position = SPAWN_LEFT_TOP
		elif WorldState.stair_spawn_side == "right":
			if WorldState.stair_direction == "down":
				player.global_position = SPAWN_RIGHT_BOTTOM
			elif WorldState.stair_direction == "up":
				player.global_position = SPAWN_RIGHT_TOP
	elif WorldState.spawn_source == "door" and WorldState.exit_spawn_x != 0.0:
		player.global_position.x = WorldState.exit_spawn_x
		player.global_position.y = 388.0

	if WorldState.saved_player_x != 0.0:
		player.global_position = Vector2(WorldState.saved_player_x, WorldState.saved_player_y)
		WorldState.saved_player_x = 0.0
		WorldState.saved_player_y = 0.0

	if WorldState.stair_spawn_side == "left":
		hallway_staircase_left.visible = false
		lobby_left.visible = true
		hallway_staircase_right.visible = true
		lobby_right.visible = false
		if WorldState.stair_direction == "down":
			left_down.process_mode = Node.PROCESS_MODE_DISABLED
			left_up.process_mode = Node.PROCESS_MODE_ALWAYS
			right_down.process_mode = Node.PROCESS_MODE_ALWAYS
			right_up.process_mode = Node.PROCESS_MODE_DISABLED
		else:
			left_up.process_mode = Node.PROCESS_MODE_DISABLED
			left_down.process_mode = Node.PROCESS_MODE_ALWAYS
			right_up.process_mode = Node.PROCESS_MODE_ALWAYS
			right_down.process_mode = Node.PROCESS_MODE_DISABLED
	elif WorldState.stair_spawn_side == "right":
		if WorldState.stair_direction == "down":
			hallway_staircase_right.visible = false
			lobby_right.visible = true
			hallway_staircase_left.visible = true
			lobby_left.visible = false
			right_down.process_mode = Node.PROCESS_MODE_DISABLED
			right_up.process_mode = Node.PROCESS_MODE_ALWAYS
			left_down.process_mode = Node.PROCESS_MODE_ALWAYS
			left_up.process_mode = Node.PROCESS_MODE_DISABLED
		else:
			hallway_staircase_right.visible = true
			lobby_right.visible = false
			hallway_staircase_left.visible = true
			lobby_left.visible = false
			right_up.process_mode = Node.PROCESS_MODE_DISABLED
			right_down.process_mode = Node.PROCESS_MODE_ALWAYS
			left_up.process_mode = Node.PROCESS_MODE_ALWAYS
			left_down.process_mode = Node.PROCESS_MODE_DISABLED

	# Assign apartment IDs and apply correct door states AFTER IDs are set
	var floor_num = WorldState.current_floor
	for i in range(1, 6):
		var node_name = "apartment0" + str(i)
		var apt_id = str(floor_num) + "0" + str(i)
		var door = get_node_or_null(node_name)
		if door:
			door.apartment_id = apt_id
			door._apply_door_state()

	var floor_rng = RandomNumberGenerator.new()
	floor_rng.seed = (WorldState.master_seed ^ (floor_num * 2246822519)) & 0xFFFFFFFF
	var zombie_count = WorldState.get_floor_zombie_count(floor_num)
	var zombie_scene = preload("res://scenes/enemy_zombie_standard.tscn")
	var positions = WorldState.get_zombie_positions(zombie_count, floor_rng, 50.0, 1300.0, 388.0)

	for pos in positions:
		var key = str(floor_num) + ":" + str(snappedf(pos.x, 1.0)) + ":" + str(snappedf(pos.y, 1.0))
		if WorldState.killed_zombies.has(key):
			continue
		var zombie = zombie_scene.instantiate()
		zombie.global_position = pos
		zombie.spawn_key = key
		add_child(zombie)

	_spawn_corpses(floor_num)


func _spawn_corpses(floor_num: int) -> void:
	var scene_path = get_tree().current_scene.scene_file_path
	var corpse_positions = WorldState.get_corpse_positions_for_floor(floor_num, scene_path)
	if corpse_positions.is_empty():
		return
	var zombie_scene = preload("res://scenes/enemy_zombie_standard.tscn")
	var zombie_instance = zombie_scene.instantiate()
	var frames = zombie_instance.get_node("AnimatedSprite2D").sprite_frames
	zombie_instance.queue_free()
	for pos in corpse_positions:
		var corpse = AnimatedSprite2D.new()
		corpse.sprite_frames = frames
		corpse.scale = Vector2(3, 3)
		corpse.animation = "Dead_Dead"
		corpse.autoplay = "Dead_Dead"
		corpse.global_position = pos
		corpse.z_index = 0
		add_child(corpse)
