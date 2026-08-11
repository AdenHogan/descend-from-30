extends Node

var items: Dictionary = {}
var room_spawn_pools: Dictionary = {}
var item_textures: Dictionary = {}

func _ready() -> void:
	_load_data()
	_load_textures()

func _load_textures() -> void:
	# Icons are addressed by item id. Prefer an exact "<id>.png"; otherwise accept
	# a descriptive "<id> - Name.png" / "<id>-Name.png" so the assets folder can
	# stay human-readable (e.g. "035 - Crowbar.png") without breaking the lookup.
	var descriptive := _index_descriptive_icons()
	for id in items:
		var exact = "res://assets/Items/" + id + ".png"
		if ResourceLoader.exists(exact):
			item_textures[id] = load(exact)
		elif descriptive.has(id):
			var path = "res://assets/Items/" + descriptive[id]
			if ResourceLoader.exists(path):
				item_textures[id] = load(path)


func _index_descriptive_icons() -> Dictionary:
	# Map "<id>" -> "<id> - Name.png" for any descriptively-named icon in the
	# folder, keyed by the leading 3-digit id. The id must be followed by a
	# separator (space or dash) so "003" can never grab a longer id's file.
	var out := {}
	var dir := DirAccess.open("res://assets/Items")
	if dir == null:
		return out
	for f in dir.get_files():
		if not f.ends_with(".png"):
			continue          # skip .import metadata and non-images
		var cut := f.length()
		var dash := f.find("-")
		var space := f.find(" ")
		if dash >= 0:
			cut = mini(cut, dash)
		if space >= 0:
			cut = mini(cut, space)
		var id := f.substr(0, cut).strip_edges()
		if id.length() == 3 and id.is_valid_int() and not out.has(id):
			out[id] = f
	return out

func get_texture(id: String) -> Texture2D:
	return item_textures.get(id, null)

func _load_data() -> void:
	var file = FileAccess.open("res://data/Items.json", FileAccess.READ)
	if not file:
		push_error("Could not open items.json")
		return
	
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	file.close()
	
	if error != OK:
		push_error("Failed to parse items.json")
		return
	
	var data = json.get_data()
	
	for id in data["ITEMS"]:
		var raw = data["ITEMS"][id]
		var properties = _parse_properties(raw["VALUE_PROPERTY"])
		var durability_data = _parse_durability(raw["PROPERTY_DURABILITY"])
		
		items[id] = {
			"id": id,
			"name": raw["ITEM_NAME"],
			"description": raw["ITEM_DESCRIPTION"],
			"rarity": raw["PROPERTY_SPAWN_RARITY"],
			"is_weapon": properties.has("is_weapon"),
			"is_tool": properties.has("is_tool"),
			"is_key": properties.has("is_key"),
			"can_force_lock": properties.has("can_force_lock"),
			"is_health_item": properties.has("is_health_item"),
			"is_throwable": properties.has("is_throwable"),
			"is_ammo": properties.has("is_ammo"),
			"can_repair": properties.has("can_repair"),
			"is_speed_boost": properties.has("is_speed_boost"),
			"is_junk": properties.has("is_junk"),
			"is_money": properties.has("is_money"),
			"is_rope": properties.has("is_rope"),
			"is_clothes": properties.has("is_clothes"),
			"is_crowbar": properties.has("is_crowbar"),
			"single_use": durability_data["single_use"],
			"max_durability": durability_data["max_durability"],
			"heals_states": durability_data["heals_states"],
			"requires_battery": raw["ITEM_NAME"] == "Flashlight"
		}
	
	for item_name in data["ROOM_SPAWN_POOLS"]:
		room_spawn_pools[item_name] = data["ROOM_SPAWN_POOLS"][item_name]

func _parse_properties(prop_string: String) -> Array:
	var props = []
	for p in prop_string.split(","):
		props.append(p.strip_edges())
	return props

func _parse_durability(durability_string: String) -> Dictionary:
	var result = {
		"single_use": false,
		"max_durability": -1,
		"heals_states": 0
	}
	
	var lower = durability_string.to_lower()
	
	if lower.contains("single use"):
		result["single_use"] = true
	
	if lower.contains("heals 1 state"):
		result["heals_states"] = 1
	elif lower.contains("heals 2 state"):
		result["heals_states"] = 2
	elif lower.contains("heals 3 state"):
		result["heals_states"] = 3
	
	var regex = RegEx.new()
	regex.compile("(\\d+) uses")
	var regex_match = regex.search(lower)
	if regex_match:
		result["max_durability"] = int(regex_match.get_string(1))
	
	return result

func get_item(id: String) -> Dictionary:
	return items.get(id, {})

func get_spawn_pool_for_room(room_type: String) -> Dictionary:
	var pool = {}
	for item_name in room_spawn_pools:
		var weight = room_spawn_pools[item_name].get(room_type, 0)
		if weight > 0:
			pool[item_name] = weight
	return pool

func get_item_id_by_name(item_name: String) -> String:
	for id in items:
		if items[id]["name"] == item_name:
			return id
	return ""
