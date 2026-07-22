extends Node

# --- Floor-30 tutorial: the 3004 barricade beat (first run only) -----------
# Tearing the 3004 barricade is LOUD; a zombie comes up the left stairs drawn
# by the noise, walks INTO the scene but holds at a distance, and only starts
# closing once the barricade is down — so the player clearly sees the choice:
# force the 3004 lock (1 club use, take the room) or kill the zombie (2 hits,
# the club breaks, the room is lost). See docs/TUTORIAL.md.
const HALL_ZOMBIE_SPAWN_X = 80.0
const HALL_ZOMBIE_HOLD_X = 260.0
var hall_zombie: Node = null
var hall_choice_prompted: bool = false


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

	# (The first-encounter zombie now lives INSIDE 3003 per the GDD — see
	# room.gd _spawn_tutorial_zombie — not out here in the corridor. The
	# corridor's own scripted zombie is the barricade beat below.)

	_spawn_corpses(30)
	_spawn_world_drops(30)

	# Diegetic tutorial: blood-scrawled control hints are baked into the scene
	# (group "tutorial_blood") so they can be positioned/resized in the editor.
	# They only belong on the FIRST run — hide them otherwise.
	if not WorldState.is_first_run:
		for hint in get_tree().get_nodes_in_group("tutorial_blood"):
			hint.visible = false

func _process(_delta: float) -> void:
	if not (WorldState.is_first_run and WorldState.current_floor == 30):
		return
	if WorldState.killed_zombies.has(TutorialManager.HALLWAY_ZOMBIE_KEY):
		return
	var d3004 = WorldState.get_door_state("3004")
	var barricade_up = d3004 == WorldState.DoorState.BARRICADED_LOCKED \
			or d3004 == WorldState.DoorState.BARRICADED_FORCEABLE
	# The noise of barricade work summons it (once any progress is banked);
	# if the barricade is already down (re-entry), it's simply here.
	if hall_zombie == null:
		if WorldState.barricade_progress.get("3004", 0.0) > 0.05 or not barricade_up:
			_spawn_hall_zombie()
		return
	if not is_instance_valid(hall_zombie) or hall_zombie.is_dead:
		return
	# The barricade just came down: pause for the choice, then release it.
	if not barricade_up and hall_zombie.tutorial_frozen and not hall_choice_prompted:
		hall_choice_prompted = true
		if d3004 == WorldState.DoorState.OPEN:
			# 3004 is already open — no choice left to present, just danger.
			_release_hall_zombie()
		else:
			TutorialManager.prompt(
				"It heard everything. Force the lock and take the room — or stand and fight. This club won't do both.",
				"interact", _release_hall_zombie, "[E] to continue")


func _release_hall_zombie() -> void:
	if hall_zombie != null and is_instance_valid(hall_zombie):
		hall_zombie.tutorial_shamble = true
		hall_zombie.tutorial_release()


func _spawn_hall_zombie() -> void:
	var zombie = preload("res://scenes/enemy_zombie_standard.tscn").instantiate()
	zombie.global_position = Vector2(HALL_ZOMBIE_SPAWN_X, 388.0)
	zombie.spawn_key = TutorialManager.HALLWAY_ZOMBIE_KEY
	zombie.tutorial_scripted = true   # deterministic 2-hit kill, no RNG
	zombie.tutorial_frozen = true
	zombie.tutorial_hold_x = HALL_ZOMBIE_HOLD_X
	if WorldState.zombie_positions.has(TutorialManager.HALLWAY_ZOMBIE_KEY):
		var saved = WorldState.zombie_positions[TutorialManager.HALLWAY_ZOMBIE_KEY]
		zombie.global_position = Vector2(saved["x"], saved["y"])
	add_child(zombie)
	hall_zombie = zombie
	TutorialManager.say_once("hall_zombie",
		"Something heard that — it's coming up the stairs!")


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
		drop.amount = int(data.get("amount", 0))
		drop.drop_key = drop_key
		drop.target_apartment = data.get("target_apartment", "")
		drop.global_position = Vector2(data["x"], data["y"])
		add_child(drop)
