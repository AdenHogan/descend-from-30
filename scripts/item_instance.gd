extends Resource
class_name ItemInstance

var item_id: String = ""
var current_durability: int = 0
var is_depleted: bool = false
var target_apartment: String = ""  # Only used for is_key items — "Key — Apt XXXX"
var count: int = 1  # Only used for stackable items (Bank Notes, Bullets)
# Guns: loaded rounds + damage state (forcing doors with a gun damages it —
# worse accuracy, smaller magazine — until repaired with a toolbox).
var mag_count: int = 0
var is_damaged: bool = false

const MAG_CAP = 18          # Met-issue Glock: 17+1
const MAG_CAP_DAMAGED = 10


func get_mag_cap() -> int:
	return MAG_CAP_DAMAGED if is_damaged else MAG_CAP


func setup(id: String) -> void:
	item_id = id
	var data = ItemData.items.get(id, {})
	if data.is_empty():
		push_error("Item ID not found: " + id)
		return
	if data["single_use"]:
		current_durability = 1
	elif data["max_durability"] > 0:
		current_durability = data["max_durability"]
	else:
		current_durability = -1  # ammo-dependent or battery-dependent


func setup_key(id: String, apartment_id: String) -> void:
	setup(id)
	target_apartment = apartment_id


func get_display_name() -> String:
	var data = get_data()
	if data.get("is_key", false) and target_apartment != "":
		return "Key — Apt " + target_apartment
	return data.get("name", "Unknown")


func get_data() -> Dictionary:
	return ItemData.items.get(item_id, {})


func use() -> bool:
	if is_depleted:
		return false
	if current_durability == -1:
		return true  # gun/flashlight, handled externally
	current_durability -= 1
	if current_durability <= 0:
		is_depleted = true
	return true


func repair(amount: int) -> void:
	var data = get_data()
	if data.get("single_use", false):
		return
	var max_d = data.get("max_durability", -1)
	if max_d <= 0:
		return
	current_durability = min(current_durability + amount, max_d)
	is_depleted = false


func get_item_name() -> String:
	return get_display_name()
