extends Node

var apartment_id: String = WorldState.current_apartment_id

const MODULE_SCENES = {
	"bedroom": "res://scenes/Room_Modules/bedroom.tscn",
	"bathroom": "res://scenes/Room_Modules/bathroom.tscn",
	"study": "res://scenes/Room_Modules/study.tscn",
	"kitchen": "res://scenes/Room_Modules/kitchen.tscn",
	"living_room": "res://scenes/Room_Modules/living_room.tscn",
	"dining_room": "res://scenes/Room_Modules/dining_room.tscn"
}

const TUTORIAL_SCENES = {
	"3002": [
		"res://scenes/Room_Modules/Tutorial/3002_M1_living_room.tscn",
		"res://scenes/Room_Modules/Tutorial/3002_M2_bedroom.tscn",
		"res://scenes/Room_Modules/Tutorial/3002_M3_bathroom.tscn"
	],
	"3003": [
		"res://scenes/Room_Modules/Tutorial/3003_M1_living_room.tscn",
		"res://scenes/Room_Modules/Tutorial/3003_M2_kitchen.tscn",
		"res://scenes/Room_Modules/Tutorial/3003_M3_bedroom.tscn"
	],
	"3004": [
		"res://scenes/Room_Modules/Tutorial/3004_M1_study.tscn",
		"res://scenes/Room_Modules/Tutorial/3004_M2_kitchen.tscn",
		"res://scenes/Room_Modules/Tutorial/3004_M3_bathroom.tscn"
	],
	"3005": [
		"res://scenes/Room_Modules/Tutorial/3005_M1_living_room.tscn",
		"res://scenes/Room_Modules/Tutorial/3005_M2_dining_room.tscn",
		"res://scenes/Room_Modules/Tutorial/3005_M3_kitchen.tscn"
	]
}

const MODULE_WIDTH = 320
const LEFT_WALL_X = 113

func _ready() -> void:
	var door = $Area2D
	var player = $Player
	var entrance_side = WorldState.get_entrance_side(apartment_id)
	var layout = WorldState.get_apartment_layout(apartment_id)
	var left_wall = $LeftWall
	var right_wall = $RightWall

	if entrance_side == "left":
		left_wall.process_mode = Node.PROCESS_MODE_DISABLED
		right_wall.process_mode = Node.PROCESS_MODE_ALWAYS
	else:
		right_wall.process_mode = Node.PROCESS_MODE_DISABLED
		left_wall.process_mode = Node.PROCESS_MODE_ALWAYS

	# Spawn modules — tutorial fixed or procedural
	for i in range(3):
		var scene_path: String
		if WorldState.is_first_run and TUTORIAL_SCENES.has(apartment_id):
			var module_index = i if entrance_side == "left" else 2 - i
			scene_path = TUTORIAL_SCENES[apartment_id][module_index]
		else:
			scene_path = MODULE_SCENES[layout[i]]
		var scene = load(scene_path)
		var instance = scene.instantiate()
		instance.position.x = LEFT_WALL_X + (i * MODULE_WIDTH)
		instance.position.y = 224
		instance.add_to_group("room_module")
		add_child(instance)

	# Position door and player
	if entrance_side == "left":
		door.position.x = 96
		player.position.x = 140
		player.get_node("AnimatedSprite2D").flip_h = false
	else:
		door.position.x = 1072
		player.position.x = 1050
		player.get_node("AnimatedSprite2D").flip_h = true

	# Spawn apartment zombies
	if not (WorldState.is_first_run and WorldState.current_floor == 30):
		var zombie_count = WorldState.get_apartment_zombie_count(apartment_id)
		if zombie_count > 0:
			var apt_rng = RandomNumberGenerator.new()
			apt_rng.seed = hash(str(WorldState.master_seed) + "aptpos" + apartment_id)
			var zombie_scene = preload("res://scenes/enemy_zombie_standard.tscn")
			var positions = WorldState.get_zombie_positions(zombie_count, apt_rng, 150.0, 1030.0, 321.0)
			for pos in positions:
				var zombie = zombie_scene.instantiate()
				zombie.global_position = pos
				add_child(zombie)

	# Assign items and attach interactable scripts
	var apt_rng_items = RandomNumberGenerator.new()
	apt_rng_items.seed = hash(str(WorldState.master_seed) + "items" + apartment_id)
	var is_paradise = WorldState.is_paradise_apartment(apartment_id)
	var interactable_script = load("res://scripts/interactable.gd")

	for module in get_tree().get_nodes_in_group("room_module"):
		for anchor in module.get_children():
			if not anchor is Marker2D:
				continue
			anchor.set_script(interactable_script)
			anchor.apartment_id = apartment_id
			anchor._ready()
			var spawn_chance: float
			if is_paradise:
				spawn_chance = 0.65
			else:
				match WorldState.current_run:
					1: spawn_chance = 0.15
					2: spawn_chance = 0.10
					3: spawn_chance = 0.08
					_: spawn_chance = 0.10
			if apt_rng_items.randf() > spawn_chance:
				continue
			var valid_items = WorldState.get_items_for_anchor(anchor.name, apartment_id)
			if valid_items.is_empty():
				continue
			var item_id = valid_items[apt_rng_items.randi() % valid_items.size()]
			WorldState.set_anchor_item(apartment_id, anchor.name, item_id)
