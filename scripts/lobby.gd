extends Node2D

# The ground floor (0). Reached by the stairs from floor 1 like any other floor: StairPan
# builds it as a PASSIVE backdrop below floor 1 (drawn, frozen, inert) so it scrolls into
# view during the descent, then promotes it in place with go_live() — no fade, no reload.
# Set setup_floor / passive BEFORE add_child(), same contract as building_floors.
var setup_floor: int = -1
var passive: bool = false
var _dormant: Array = []
const FLOOR_LIGHTING := preload("res://scripts/floor_lighting.gd")
# Where a fresh standard zombie comes to REST (feet on the 419 floor line). A backdrop has
# no physics step to settle it, so it's placed there directly or it would warp up on arrival.
const ZOMBIE_SETTLED_Y := 370.0


func _ready() -> void:
	if passive:
		PanBackdrop.drop_scene_player(self)
		_build_world(true)
		_dormant = PanBackdrop.make_inert(self)
		return
	var player = get_node("Player")
	WorldState.apply_time_tint(self, 0)   # ground floor — the infection is worst here
	if WorldState.spawn_source == "stair":
		# Y 386 = the shared corridor plane origin (feet on 419, level with every enemy).
		if WorldState.stair_spawn_side == "left":
			if WorldState.stair_direction == "down":
				player.global_position = Vector2(188, 386.0)
			elif WorldState.stair_direction == "up":
				player.global_position = Vector2(148, 386.0)
		elif WorldState.stair_spawn_side == "right":
			if WorldState.stair_direction == "down":
				player.global_position = Vector2(1162, 386.0)
			elif WorldState.stair_direction == "up":
				player.global_position = Vector2(1201, 386.0)

	if WorldState.saved_player_x != 0.0:
		player.global_position = Vector2(WorldState.saved_player_x, WorldState.saved_player_y)
		WorldState.saved_player_x = 0.0
		WorldState.saved_player_y = 0.0

	# The same locked framing as every floor above (it used to free-follow the player at a
	# fixed zoom, so the lobby sat a few px lower and slid past its end walls).
	_frame_camera(player)
	_build_world(false)
	# The lobby has zombies, so characters can FALL here too — their body must be recoverable
	# (game_over records it at current_floor 0 against this scene). And reaching the lobby is
	# the deepest a character can go: record it for the journal, the map and best_depth.
	WorldState.note_floor_arrival(self, 0)


func _build_world(as_scenery: bool) -> void:
	# Everything that belongs to the PLACE — identical for a fresh load and a pan backdrop,
	# so the commit shows exactly what already scrolled into view.
	_spawn_zombies(as_scenery)
	_spawn_corpses(1)
	_spawn_world_drops(1)
	WorldState.spawn_player_corpse_into(self, 0, scene_file_path, "")
	if get_node_or_null("FloorLighting") == null:
		var lights = FLOOR_LIGHTING.new()
		lights.name = "FloorLighting"
		add_child(lights)
		lights.setup(0)


func _spawn_zombies(as_scenery: bool) -> void:
	var lobby_rng = RandomNumberGenerator.new()
	lobby_rng.seed = (WorldState.master_seed ^ (1 * 2246822519)) & 0xFFFFFFFF
	var zombie_count = WorldState.get_floor_zombie_count(1)
	if zombie_count <= 0:
		return
	var zombie_scene = preload("res://scenes/enemy_zombie_standard.tscn")
	var positions = WorldState.get_zombie_positions(zombie_count, lobby_rng, 50.0, 1300.0, 388.0)
	for pos in positions:
		var key = str(1) + ":" + str(snappedf(pos.x, 1.0)) + ":" + str(snappedf(pos.y, 1.0))
		if WorldState.killed_zombies.has(key):
			continue
		var zombie = zombie_scene.instantiate()
		zombie.global_position = pos
		zombie.spawn_key = key
		zombie.hp_floor = 0
		if as_scenery:
			zombie.add_to_group("pan_scenery")
		add_child(zombie)
		# Living-enemy memory, same as the corridors and apartments.
		var restored = WorldState.apply_saved_zombie(zombie)
		if as_scenery:
			if not restored:
				zombie.global_position.y = ZOMBIE_SETTLED_Y
			zombie.set_physics_process(false)   # visible, but no AI while a floor away


func _frame_camera(player: Node) -> void:
	PanBackdrop.frame_camera(self, player)


# Wake the passive backdrop into the live lobby, in place (StairPan._adopt reparents the
# live player in first and frames the camera).
func go_live() -> void:
	if not passive:
		return
	passive = false
	PanBackdrop.restore(_dormant)
	PanBackdrop.wake_scenery(self)
	WorldState.apply_time_tint(self, 0)
	WorldState.note_floor_arrival(self, 0)


func _spawn_corpses(floor_num: int) -> void:
	var scene_path = scene_file_path   # THIS scene — a pan backdrop is not the current scene yet
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
	var scene_path = scene_file_path   # THIS scene — a pan backdrop is not the current scene yet
	var drops = WorldState.get_world_drops_for_floor(floor_num, scene_path)
	if drops.is_empty():
		return
	var drop_scene = preload("res://scenes/world_drop.tscn")
	for drop_key in drops:
		var data = drops[drop_key]
		var drop = drop_scene.instantiate()
		drop.item_id = data["item_id"]
		drop.amount = int(data.get("amount", 0))
		drop.drop_key = drop_key
		drop.target_apartment = data.get("target_apartment", "")
		drop.global_position = Vector2(data["x"], data["y"])
		add_child(drop)
