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
var searched_anchors: Dictionary = {}
var player_health: int = 0
var is_dying: bool = false
var dying_timer: float = 0.0
var interaction_handled: bool = false
var is_scavenge_mode: bool = false
var inventory: Array = []
var stamina: float = 100.0
var max_stamina: float = 100.0
var last_rest_floor: int = 30
var rest_available: bool = true
var rest_count: int = 0
var active_upgrades: Array = []
var available_upgrades: Array = []
var saved_player_x: float = 0.0
var saved_player_y: float = 0.0
var killed_zombies: Dictionary = {}

# Dev tools
var god_mode: bool = false

# --- Door system ---
enum DoorState {
	OPEN,
	SHUT_JIMMYABLE,
	SHUT_LOCKED,
	BARRICADED_JIMMYABLE,
	BARRICADED_LOCKED,
	BREACHED
}

var door_states: Dictionary = {}
var door_keys_consumed: Dictionary = {}
var floor_states_seeded: Dictionary = {}
var barricade_progress: Dictionary = {}  # apartment_id -> seconds_completed


func new_game() -> void:
	master_seed = randi()
	apartment_layouts.clear()
	anchor_items.clear()
	searched_anchors.clear()
	inventory.clear()
	current_floor = 30
	current_run = 1
	player_health = 0
	is_dying = false
	dying_timer = 0.0
	is_scavenge_mode = false
	stamina = 100.0
	max_stamina = 100.0
	last_rest_floor = 30
	rest_available = true
	rest_count = 0
	active_upgrades.clear()
	available_upgrades.clear()
	initialize_paradise_apartments()
	spawn_source = ""
	stair_spawn_side = ""
	stair_direction = ""
	exit_spawn_x = 0.0
	saved_player_x = 0.0
	saved_player_y = 0.0
	killed_zombies.clear()
	door_states.clear()
	door_keys_consumed.clear()
	floor_states_seeded.clear()
	barricade_progress.clear()
	god_mode = false


func on_floor_arrived(floor_num: int) -> void:
	if floor_num in [25, 20, 15, 10, 5]:
		rest_available = true
	seed_floor_door_states(floor_num)


func add_to_inventory(item_id: String) -> bool:
	if inventory.size() >= MAX_INVENTORY_SLOTS:
		return false
	var instance = ItemInstance.new()
	instance.setup(item_id)
	inventory.append(instance)
	return true


func remove_from_inventory(slot_index: int) -> void:
	if slot_index >= 0 and slot_index < inventory.size():
		inventory.remove_at(slot_index)


func get_item_id_at(slot_index: int) -> String:
	if slot_index < 0 or slot_index >= inventory.size():
		return ""
	return inventory[slot_index].item_id


func get_instance_at(slot_index: int) -> ItemInstance:
	if slot_index < 0 or slot_index >= inventory.size():
		return null
	return inventory[slot_index]


func mark_anchor_searched(apartment_id: String, anchor_name: String) -> void:
	var key = apartment_id + ":" + anchor_name
	searched_anchors[key] = true


func is_anchor_searched(apartment_id: String, anchor_name: String) -> bool:
	var key = apartment_id + ":" + anchor_name
	return searched_anchors.get(key, false)


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


func get_corpse_positions_for_floor(floor_num: int, scene_path: String) -> Array:
	var result = []
	for key in killed_zombies:
		var data = killed_zombies[key]
		if data["floor"] == floor_num and data["scene"] == scene_path:
			result.append(Vector2(data["x"], data["y"]))
	return result


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


# ============================================================
# DOOR SYSTEM
# ============================================================

func _get_door_weights(run_num: int) -> Array:
	# Indices match DoorState enum: [OPEN, SHUT_JIMMYABLE, SHUT_LOCKED, BARRICADED_JIMMYABLE, BARRICADED_LOCKED, BREACHED]
	# OPEN weight is 0 here — open slots are assigned separately as guaranteed slots
	match run_num:
		1: return [0, 40, 28, 14, 10, 8]
		2: return [0, 30, 24, 16, 12, 18]
		3: return [0, 22, 20, 16, 12, 30]
	return [0, 40, 28, 14, 10, 8]


func _pick_door_state(rng: RandomNumberGenerator, weights: Array) -> int:
	var total = 0
	for w in weights:
		total += w
	var roll = rng.randi() % total
	var cumulative = 0
	for i in range(weights.size()):
		cumulative += weights[i]
		if roll < cumulative:
			return i
	return DoorState.SHUT_JIMMYABLE


func seed_floor_door_states(floor_num: int) -> void:
	if floor_states_seeded.get(floor_num, false):
		return
	floor_states_seeded[floor_num] = true

	var rng = RandomNumberGenerator.new()
	rng.seed = hash(str(master_seed) + "doors" + str(floor_num) + str(current_run))

	var apartments = []
	for i in range(1, 6):
		apartments.append(str(floor_num) + "0" + str(i))

	# Shuffle so guaranteed open doors aren't always apartment 01/02
	for i in range(apartments.size() - 1, 0, -1):
		var j = rng.randi() % (i + 1)
		var temp = apartments[i]
		apartments[i] = apartments[j]
		apartments[j] = temp

	# Guarantee 1-2 open doors — never overwrite cross-run player changes
	var open_count = 1 + (rng.randi() % 2)
	for i in range(open_count):
		var apt_id = apartments[i]
		if not door_states.has(apt_id):
			door_states[apt_id] = DoorState.OPEN

	# Assign remaining from weighted pool
	var weights = _get_door_weights(current_run)
	for i in range(open_count, apartments.size()):
		var apt_id = apartments[i]
		if not door_states.has(apt_id):
			door_states[apt_id] = _pick_door_state(rng, weights)


func get_door_state(apartment_id: String) -> int:
	var floor_num = int(apartment_id.left(apartment_id.length() - 2))
	seed_floor_door_states(floor_num)
	return door_states.get(apartment_id, DoorState.SHUT_JIMMYABLE)


func set_door_state(apartment_id: String, state: int) -> void:
	door_states[apartment_id] = state


func consume_key_for_apartment(apartment_id: String) -> void:
	door_keys_consumed[apartment_id] = true
	set_door_state(apartment_id, DoorState.OPEN)


func mutate_door_states_for_new_run() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(str(master_seed) + "mutate" + str(current_run))

	for apt_id in door_states.keys():
		var state = door_states[apt_id]
		var roll = rng.randf()

		match state:
			DoorState.SHUT_JIMMYABLE:
				if roll < 0.15:
					door_states[apt_id] = DoorState.BREACHED
			DoorState.SHUT_LOCKED:
				if roll < 0.12:
					door_states[apt_id] = DoorState.BREACHED
				elif roll < 0.14:
					door_states[apt_id] = DoorState.SHUT_JIMMYABLE
			DoorState.BARRICADED_JIMMYABLE:
				if roll < 0.20:
					door_states[apt_id] = DoorState.SHUT_JIMMYABLE
				elif roll < 0.25:
					door_states[apt_id] = DoorState.BREACHED
			DoorState.BARRICADED_LOCKED:
				if roll < 0.15:
					door_states[apt_id] = DoorState.SHUT_LOCKED
				elif roll < 0.20:
					door_states[apt_id] = DoorState.BREACHED
			DoorState.OPEN:
				pass
			DoorState.BREACHED:
				pass

	floor_states_seeded.clear()
	barricade_progress.clear()


func is_locked_apartment(apartment_id: String) -> bool:
	var state = get_door_state(apartment_id)
	return state == DoorState.SHUT_LOCKED or state == DoorState.BARRICADED_LOCKED


func was_key_opened(apartment_id: String) -> bool:
	return door_keys_consumed.get(apartment_id, false)


func get_breached_room_enemies(apartment_id: String, min_x: float, max_x: float, y: float) -> Array:
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(str(master_seed) + "breached" + apartment_id + str(current_run))

	var count = 4 + (rng.randi() % 6)  # 4-9 enemies

	var enemies = []
	var center_x = rng.randf_range(min_x + 60, min_x + 200)
	var spread = rng.randf_range(60, 200)

	for i in range(count):
		var pos_x = clamp(center_x + rng.randf_range(-spread, spread), min_x, max_x)
		enemies.append({
			"type": "zombie_standard",
			"position": Vector2(pos_x, y)
		})

	return enemies


# ============================================================
# KEY SYSTEM
# ============================================================

# Returns the apartment ID that a key should target, seeded for
# a given floor and anchor. Keys spawn 4-5 floors away from their door.
func get_key_target_for_anchor(floor_num: int, anchor_name: String) -> String:
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(str(master_seed) + "key" + str(floor_num) + anchor_name)

	var offset = 4 + (rng.randi() % 2)  # 4 or 5
	var direction = 1 if rng.randf() < 0.5 else -1
	var target_floor = clamp(floor_num + (offset * direction), 2, 29)

	var apt_num = "0" + str((rng.randi() % 5) + 1)
	return str(target_floor) + apt_num


# Called by room.gd when seeding items — determines if an anchor
# should spawn a key instead of a regular item
func should_anchor_spawn_key(apartment_id: String, anchor_name: String) -> bool:
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(str(master_seed) + "keyspawn" + apartment_id + anchor_name)
	# Keys are rare — roughly 3% chance per anchor
	return rng.randf() < 0.03


# Add a key with a specific target apartment to inventory
func add_key_to_inventory(target_apartment: String) -> bool:
	if inventory.size() >= MAX_INVENTORY_SLOTS:
		return false
	var instance = ItemInstance.new()
	instance.setup_key("022", target_apartment)
	inventory.append(instance)
	return true


# Get the target apartment from a key in inventory at a given slot
func get_key_target_at(slot_index: int) -> String:
	if slot_index < 0 or slot_index >= inventory.size():
		return ""
	return inventory[slot_index].target_apartment


func set_anchor_key(apartment_id: String, anchor_name: String, target_apartment: String) -> void:
	var key = apartment_id + ":" + anchor_name
	anchor_items[key] = "KEY:" + target_apartment


func get_anchor_key_target(apartment_id: String, anchor_name: String) -> String:
	var key = apartment_id + ":" + anchor_name
	var val = anchor_items.get(key, "")
	if val.begins_with("KEY:"):
		return val.substr(4)
	return ""


func is_anchor_a_key(apartment_id: String, anchor_name: String) -> bool:
	var key = apartment_id + ":" + anchor_name
	return anchor_items.get(key, "").begins_with("KEY:")


# Returns the apartment ID that the breached room boss key opens.
# Seeded — same boss always drops the same key on a given run.
func get_breached_boss_key_target(apartment_id: String) -> String:
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(str(master_seed) + "bosskey" + apartment_id)
	var floor_num = int(apartment_id.left(apartment_id.length() - 2))
	var offset = 1 + (rng.randi() % 3)
	var direction = 1 if rng.randf() < 0.5 else -1
	var target_floor = clamp(floor_num + (offset * direction), 2, 29)
	var apt_num = "0" + str((rng.randi() % 5) + 1)
	return str(target_floor) + apt_num


# ============================================================
# SAVE / LOAD
# ============================================================

const SAVE_PATH = "user://savegame.json"

func save_game(scene_path: String) -> void:
	var save_data = {
		"scene_path": scene_path,
		"master_seed": master_seed,
		"current_floor": current_floor,
		"current_apartment_id": current_apartment_id,
		"spawn_source": spawn_source,
		"stair_spawn_side": stair_spawn_side,
		"stair_direction": stair_direction,
		"exit_spawn_x": exit_spawn_x,
		"is_first_run": is_first_run,
		"current_run": current_run,
		"player_health": player_health,
		"is_dying": is_dying,
		"dying_timer": dying_timer,
		"is_scavenge_mode": is_scavenge_mode,
		"stamina": stamina,
		"max_stamina": max_stamina,
		"last_rest_floor": last_rest_floor,
		"rest_available": rest_available,
		"rest_count": rest_count,
		"paradise_apartments": paradise_apartments,
		"anchor_items": anchor_items,
		"searched_anchors": searched_anchors,
		"apartment_layouts": apartment_layouts,
		"active_upgrades": active_upgrades,
		"inventory": _serialize_inventory(),
		"tutorial_zombie_spawned": tutorial_zombie_spawned,
		"last_exited_apartment": last_exited_apartment,
		"saved_player_x": saved_player_x,
		"saved_player_y": saved_player_y,
		"killed_zombies": killed_zombies,
		"door_states": door_states,
		"door_keys_consumed": door_keys_consumed,
		"floor_states_seeded": floor_states_seeded,
		"barricade_progress": barricade_progress,
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()


func load_game() -> String:
	if not FileAccess.file_exists(SAVE_PATH):
		return ""
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return ""
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	file.close()
	if error != OK:
		return ""
	var data = json.get_data()
	master_seed = data["master_seed"]
	current_floor = data["current_floor"]
	current_apartment_id = data["current_apartment_id"]
	spawn_source = data["spawn_source"]
	stair_spawn_side = data["stair_spawn_side"]
	stair_direction = data["stair_direction"]
	exit_spawn_x = data["exit_spawn_x"]
	is_first_run = data["is_first_run"]
	current_run = data["current_run"]
	player_health = data["player_health"]
	is_dying = data["is_dying"]
	dying_timer = data["dying_timer"]
	is_scavenge_mode = data["is_scavenge_mode"]
	stamina = data["stamina"]
	max_stamina = data["max_stamina"]
	last_rest_floor = data["last_rest_floor"]
	rest_available = data["rest_available"]
	rest_count = data["rest_count"]
	paradise_apartments = data["paradise_apartments"]
	anchor_items = data["anchor_items"]
	searched_anchors = data["searched_anchors"]
	apartment_layouts = data["apartment_layouts"]
	active_upgrades = data["active_upgrades"]
	tutorial_zombie_spawned = data["tutorial_zombie_spawned"]
	last_exited_apartment = data["last_exited_apartment"]
	saved_player_x = data["saved_player_x"]
	saved_player_y = data["saved_player_y"]
	killed_zombies = data["killed_zombies"]
	door_states = data["door_states"]
	door_keys_consumed = data["door_keys_consumed"]
	floor_states_seeded = data["floor_states_seeded"]
	barricade_progress = data.get("barricade_progress", {})
	_deserialize_inventory(data["inventory"])
	return data["scene_path"]


func save_exists() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


func _serialize_inventory() -> Array:
	var result = []
	for instance in inventory:
		result.append({
			"item_id": instance.item_id,
			"current_durability": instance.current_durability,
			"is_depleted": instance.is_depleted,
			"target_apartment": instance.target_apartment
		})
	return result


func _deserialize_inventory(data: Array) -> void:
	inventory.clear()
	for entry in data:
		var instance = ItemInstance.new()
		instance.item_id = entry["item_id"]
		instance.current_durability = entry["current_durability"]
		instance.is_depleted = entry["is_depleted"]
		instance.target_apartment = entry.get("target_apartment", "")
		inventory.append(instance)
