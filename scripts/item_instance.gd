extends Resource
class_name ItemInstance

var item_id: String = ""
var current_durability: int = 0
var is_depleted: bool = false

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
		return  # can't repair single use items
	current_durability = min(current_durability + amount, data["max_durability"])
	is_depleted = false

func get_item_name() -> String:
	return get_data().get("name", "Unknown")
