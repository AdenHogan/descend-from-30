extends Node

var apartment_id: String = WorldState.current_apartment_id
var interactables: Array = []
var selected_index: int = 0

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
const CLICK_RADIUS = 10.0

const ANCHOR_RANGES = {
	"bedroom": [2, 5],
	"bathroom": [2, 5],
	"kitchen": [2, 5],
	"dining_room": [2, 4],
	"living_room": [2, 5],
	"study": [2, 4]
}

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

	if entrance_side == "left":
		door.position.x = 96
		player.position.x = 140
		player.get_node("AnimatedSprite2D").flip_h = false
	else:
		door.position.x = 1072
		player.position.x = 1050
		player.get_node("AnimatedSprite2D").flip_h = true

	# Spawn enemies — breached rooms use separate system with Big Zombie boss
	var door_state = WorldState.get_door_state(apartment_id)
	if door_state == WorldState.DoorState.BREACHED:
		_spawn_breached_enemies()
	elif not (WorldState.is_first_run and WorldState.current_floor == 30):
		var zombie_count = WorldState.get_apartment_zombie_count(apartment_id)
		if zombie_count > 0:
			var apt_rng = RandomNumberGenerator.new()
			apt_rng.seed = hash(str(WorldState.master_seed) + "aptpos" + apartment_id)
			var zombie_scene = preload("res://scenes/enemy_zombie_standard.tscn")
			var positions = WorldState.get_zombie_positions(zombie_count, apt_rng, 150.0, 1030.0, 321.0)
			for pos in positions:
				var key = str(WorldState.current_floor) + ":" + str(snappedf(pos.x, 1.0)) + ":" + str(snappedf(pos.y, 1.0))
				if WorldState.killed_zombies.has(key):
					continue
				var zombie = zombie_scene.instantiate()
				zombie.global_position = pos
				zombie.spawn_key = key
				add_child(zombie)

	if WorldState.saved_player_x != 0.0:
		player.global_position = Vector2(WorldState.saved_player_x, WorldState.saved_player_y)
		WorldState.saved_player_x = 0.0
		WorldState.saved_player_y = 0.0

	var is_paradise = WorldState.is_paradise_apartment(apartment_id)
	var interactable_script = load("res://scripts/interactable.gd")

	for module in get_tree().get_nodes_in_group("room_module"):
		var room_type = ""
		for rt in MODULE_SCENES.keys():
			if module.get_node_or_null("ColorRect") != null:
				var label = module.get_node_or_null("ColorRect/Label")
				if label and label.text.to_lower().replace(" ", "_") == rt:
					room_type = rt
					break

		var all_anchors = []
		for child in module.get_children():
			if child is Marker2D:
				all_anchors.append(child)

		var anchor_rng = RandomNumberGenerator.new()
		anchor_rng.seed = hash(str(WorldState.master_seed) + apartment_id + room_type)
		for i in range(all_anchors.size() - 1, 0, -1):
			var j = anchor_rng.randi() % (i + 1)
			var temp = all_anchors[i]
			all_anchors[i] = all_anchors[j]
			all_anchors[j] = temp

		var range_data = ANCHOR_RANGES.get(room_type, [2, all_anchors.size()])
		var min_active = range_data[0]
		var max_active = min(range_data[1], all_anchors.size())
		var active_count = min_active + (anchor_rng.randi() % (max_active - min_active + 1))
		var active_anchors = all_anchors.slice(0, active_count)

		var apt_rng_items = RandomNumberGenerator.new()
		apt_rng_items.seed = hash(str(WorldState.master_seed) + "items" + apartment_id)
		for anchor in active_anchors:
			anchor.set_script(interactable_script)
			anchor.apartment_id = apartment_id
			anchor._ready()
			anchor.set_process(true)

			# Determine spawn chance based on room type and door state
			var spawn_chance: float
			var locked = WorldState.is_locked_apartment(apartment_id)
			var key_opened = WorldState.was_key_opened(apartment_id)
			if key_opened:
				spawn_chance = 0.55  # Key-opened doors: best loot
			elif is_paradise:
				spawn_chance = 0.65
			elif locked:
				spawn_chance = 0.45  # Locked bonus even if forced
			else:
				match WorldState.current_run:
					1: spawn_chance = 0.35
					2: spawn_chance = 0.28
					3: spawn_chance = 0.22
					_: spawn_chance = 0.28

			if apt_rng_items.randf() > spawn_chance:
				continue

			# Check if this anchor should spawn a key instead of a regular item
			var floor_num = int(apartment_id.left(apartment_id.length() - 2))
			if WorldState.should_anchor_spawn_key(apartment_id, anchor.name):
				var key_target = WorldState.get_key_target_for_anchor(floor_num, anchor.name)
				WorldState.set_anchor_key(apartment_id, anchor.name, key_target)
			else:
				var valid_items = WorldState.get_items_for_anchor(anchor.name, apartment_id)
				if valid_items.is_empty():
					continue
				var item_id = valid_items[apt_rng_items.randi() % valid_items.size()]
				WorldState.set_anchor_item(apartment_id, anchor.name, item_id)

	await get_tree().process_frame
	WorldState.interaction_handled = false

	for module in get_tree().get_nodes_in_group("room_module"):
		for anchor in module.get_children():
			if anchor.has_method("try_interact"):
				interactables.append(anchor)

	_spawn_corpses(WorldState.current_floor)
	_spawn_world_drops(WorldState.current_floor)

func _spawn_world_drops(floor_num: int) -> void:
	var drops = WorldState.get_world_drops_for_floor(floor_num)
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

func _spawn_breached_enemies() -> void:
	var floor_num = WorldState.current_floor
	var enemy_list = WorldState.get_breached_room_enemies(apartment_id, 150.0, 1030.0, 321.0)

	var standard_scene = preload("res://scenes/enemy_zombie_standard.tscn")
	var big_scene = preload("res://scenes/enemy_zombie_big.tscn")

	var boss_spawned = false

	for i in range(enemy_list.size()):
		var entry = enemy_list[i]
		var key = str(floor_num) + ":" + str(snappedf(entry["position"].x, 1.0)) + ":" + str(snappedf(entry["position"].y, 1.0))
		if WorldState.killed_zombies.has(key):
			continue

		# First enemy in the list is always the Big Zombie boss
		if not boss_spawned and entry["type"] == "zombie_standard":
			var boss = big_scene.instantiate()
			boss.global_position = entry["position"]
			boss.spawn_key = key
			boss.drops_key = true
			boss.key_target_apartment = WorldState.get_breached_boss_key_target(apartment_id)
			add_child(boss)
			boss_spawned = true
		else:
			var zombie = standard_scene.instantiate()
			zombie.global_position = entry["position"]
			zombie.spawn_key = key
			add_child(zombie)


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


func _is_player_facing_anchor(anchor: Node) -> bool:
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return false
	var sprite = player.get_node_or_null("AnimatedSprite2D")
	if sprite == null:
		return false
	var diff = anchor.global_position.x - player.global_position.x
	if abs(diff) < 8.0:
		return true
	if not sprite.flip_h and diff > 0:
		return true
	if sprite.flip_h and diff < 0:
		return true
	return false


func _process(_delta: float) -> void:
	if not WorldState.is_scavenge_mode:
		for i in interactables:
			if is_instance_valid(i):
				i.is_selected = false
		return

	var nearby: Array = []
	for i in interactables:
		if not is_instance_valid(i):
			continue
		if i.is_in_range and _is_player_facing_anchor(i):
			nearby.append(i)

	for i in interactables:
		if is_instance_valid(i):
			i.is_selected = false

	if nearby.is_empty():
		selected_index = 0
		return

	selected_index = clamp(selected_index, 0, nearby.size() - 1)

	if Input.is_action_just_pressed("ui_focus_next"):
		selected_index = (selected_index + 1) % nearby.size()
	if Input.is_action_just_pressed("ui_focus_prev"):
		selected_index = (selected_index - 1 + nearby.size()) % nearby.size()

	nearby[selected_index].is_selected = true


func _input(event: InputEvent) -> void:
	if not WorldState.is_scavenge_mode:
		return

	var nearby: Array = []
	for i in interactables:
		if not is_instance_valid(i):
			continue
		if i.is_in_range and _is_player_facing_anchor(i):
			nearby.append(i)

	if nearby.is_empty():
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			selected_index = (selected_index + 1) % nearby.size()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			selected_index = (selected_index - 1 + nearby.size()) % nearby.size()
			return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_E:
			WorldState.interaction_handled = false
			nearby[clamp(selected_index, 0, nearby.size() - 1)].try_interact()
			return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_world = _get_mouse_world_pos()
		var clicked_index = _get_clicked_interactable(nearby, mouse_world)
		if clicked_index >= 0:
			selected_index = clicked_index
			WorldState.interaction_handled = false
			nearby[selected_index].try_interact()


func _get_mouse_world_pos() -> Vector2:
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return Vector2.ZERO
	var cam = player.get_node_or_null("Camera2D")
	if cam == null:
		return Vector2.ZERO
	return cam.get_screen_center_position() + (get_viewport().get_mouse_position() - get_viewport().get_visible_rect().size / 2) / cam.zoom


func _get_clicked_interactable(nearby: Array, mouse_world: Vector2) -> int:
	var best_index = -1
	var best_dist = CLICK_RADIUS
	for i in range(nearby.size()):
		var d = nearby[i].global_position.distance_to(mouse_world)
		if d <= best_dist:
			best_dist = d
			best_index = i
	return best_index
