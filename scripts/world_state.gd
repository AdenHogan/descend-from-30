extends Node

const ROOM_POOL = ["bedroom", "bathroom", "study", "kitchen", "living_room", "dining_room"]
const MAX_INVENTORY_SLOTS = 5

var master_seed: int = 0
var current_apartment_id: String = ""
var apartment_layouts: Dictionary = {}
var exit_spawn_x: float = 0.0
var stair_spawn_side: String = ""
var current_floor: int = 30
var stair_direction: String = ""
var spawn_source: String = ""
var is_first_run: bool = true
var tutorial_zombie_spawned: bool = false
var last_exited_apartment: int = 0
var current_run: int = 1
var paradise_apartments: Array = []
var anchor_items: Dictionary = {}
var player_health: int = 0
var is_dying: bool = false
var dying_timer: float = 0.0
var interaction_handled: bool = false
var is_scavenge_mode: bool = false
var inventory: Array = []

func new_game() -> void:
	master_seed = randi()
	apartment_layouts.clear()
	anchor_items.clear()
	inventory.clear()
	current_floor = 30
	current_run = 1
	player_health = 0
	is_dying = false
	dying_timer = 0.0
	is_scavenge_mode = false
	initialize_paradise_apartments()
	spawn_source = ""
	stair_spawn_side = ""
	stair_direction = ""
	exit_spawn_x = 0.0

func add_to_inventory(item_id: String) -> bool:
	if inventory.size() >= MAX_INVENTORY_SLOTS:
		return false
	inventory.append(item_id)
	return true

func remove_from_inventory(slot_index: int) -> void:
	if slot_index >= 0 and slot_index < inventory.size():
		inventory.remove_at(slot_index)

func _get_apartment_rng(apartment_id: String) -> RandomNumberGenerator:
	var apt_rng := RandomNumberGenerator.new()
	apt_rng.seed = hash(str(master_seed) + apartment_id)
	return apt_rng

func get_entrance_side(apartment_id: String) -> String:
	var apt_rng = _get_apartment_rng(apartment_id)
	return "left" if apt_rng.randi() % 2 == 0 else "right"

func get_apartment_layout(apartment_id: String) -> Array:
	if apartment_layouts.has(apartment_id):
		return apartment_layouts[apartment_id]
	var apt_rng = _get_apartment_rng(apartment_id)
	apt_rng.randi()
	var pool = ROOM_POOL.duplicate()
	for i in range(pool.size() - 1, 0, -1):
		var j = apt_rng.randi() % (i + 1)
		var temp = pool[i]
		pool[i] = pool[j]
		pool[j] = temp
	var layout = [pool[0], pool[1], pool[2]]
	apartment_layouts[apartment_id] = layout
	return layout

func get_floor_zombie_count(floor_num: int) -> int:
	var rng = RandomNumberGenerator.new()
	rng.seed = (master_seed ^ (floor_num * 1000003)) & 0xFFFFFFFF
	var roll = rng.randf()
	if floor_num == 1:
		if roll < 0.05:
			return 0
		elif roll < 0.1:
			return 10
		else:
			return rng.randi() % 10 + 1
	elif floor_num <= 14:
		if roll < 0.08:
			return 0
		elif roll < 0.12:
			return 10
		elif roll < 0.18:
			return 6
		else:
			return rng.randi() % 5 + 1
	else:
		if roll < 0.08:
			return 0
		elif roll < 0.11:
			return 10
		elif roll < 0.17:
			return rng.randi() % 2 + 4
		else:
			return rng.randi() % 3 + 1

func get_apartment_zombie_count(apartment_id: String) -> int:
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(str(master_seed) + "zombies" + apartment_id)
	var roll = rng.randf()
	if roll < 0.30:
		return 0
	elif roll < 0.33:
		return 10
	else:
		return rng.randi() % 4 + 1

func get_zombie_positions(count: int, rng: RandomNumberGenerator, min_x: float, max_x: float, y: float) -> Array:
	var positions = []
	var huddle = rng.randf() < 0.4
	if huddle and count > 1:
		var center_x = rng.randf_range(min_x + 100, max_x - 100)
		var radius = rng.randf_range(40, 120)
		for i in range(count):
			var offset = rng.randf_range(-radius, radius)
			positions.append(Vector2(clamp(center_x + offset, min_x, max_x), y))
	else:
		for i in range(count):
			positions.append(Vector2(rng.randf_range(min_x, max_x), y))
	return positions

func initialize_paradise_apartments() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(str(master_seed) + "paradise")
	var count = rng.randi() % 3 + 1
	var all_apartments = []
	for floor_num in range(2, 30):
		for apt in ["01", "02", "03", "04", "05"]:
			all_apartments.append(str(floor_num) + apt)
	for i in range(all_apartments.size() - 1, 0, -1):
		var j = rng.randi() % (i + 1)
		var temp = all_apartments[i]
		all_apartments[i] = all_apartments[j]
		all_apartments[j] = temp
	paradise_apartments = all_apartments.slice(0, count)

func is_paradise_apartment(apartment_id: String) -> bool:
	return apartment_id in paradise_apartments

func get_room_type_for_anchor(anchor_name: String, apartment_id: String) -> String:
	var layout = get_apartment_layout(apartment_id)
	for room_type in layout:
		var anchors = get_anchors_for_room(room_type)
		if anchor_name in anchors:
			return room_type
	return ""

func get_anchors_for_room(room_type: String) -> Array:
	match room_type:
		"bedroom":
			return ["anchor_wall_left", "anchor_floor_underbed", "anchor_wall_right_lower", "anchor_bed_pillow", "anchor_wall_right_upper", "anchor_bedside"]
		"bathroom":
			return ["anchor_wall_sink", "anchor_wall_cabinet", "anchor_centre_toilet", "anchor_bath_left", "anchor_bath_right", "anchor_wall_shower", "anchor_floor_laundrybag"]
		"kitchen":
			return ["anchor_centre_fridge", "anchor_right_trashcan", "anchor_left_cupboard", "anchor_centre_cupboard", "anchor_centre_oven", "anchor_right_sink", "anchor_right_sinkcupboard"]
		"dining_room":
			return ["anchor_table_left", "anchor_table_right", "anchor_right_upperdrawers", "anchor_right_lowerdrawers"]
		"living_room":
			return ["anchor_left_bookshelf_upper", "anchor_centre_sofaleft", "anchor_centre_sofaright", "anchor_right_chair", "anchor_centre_coffeetable", "anchor_left_bookshelf_lower"]
		"study":
			return ["anchor_centre_bookcaseupper", "anchor_centre_bookcaselower", "anchor_centre_desk", "anchor_right_shelf"]
	return []

func get_items_for_anchor(anchor_name: String, apartment_id: String) -> Array:
	var room_type = get_room_type_for_anchor(anchor_name, apartment_id)
	if room_type == "":
		return []
	var valid_items = []
	var spawn_pools = ItemData.room_spawn_pools
	for item_name in spawn_pools:
		var pool = spawn_pools[item_name]
		var weight = pool.get(room_type, 0)
		if weight > 0:
			var item_id = ItemData.get_item_id_by_name(item_name)
			if item_id != "":
				for i in range(weight):
					valid_items.append(item_id)
	return valid_items

func set_anchor_item(apartment_id: String, anchor_name: String, item_id: String) -> void:
	var key = apartment_id + ":" + anchor_name
	anchor_items[key] = item_id

func get_anchor_item(apartment_id: String, anchor_name: String) -> String:
	var key = apartment_id + ":" + anchor_name
	return anchor_items.get(key, "")

func clear_anchor_item(apartment_id: String, anchor_name: String) -> void:
	var key = apartment_id + ":" + anchor_name
	anchor_items.erase(key)
