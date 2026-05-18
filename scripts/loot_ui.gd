extends CanvasLayer

@onready var item_name_label = $Panel/VBoxContainer/ItemName
@onready var item_desc_label = $Panel/VBoxContainer/ItemDescription
@onready var take_button = $Panel/VBoxContainer/HBoxContainer/TakeButton
@onready var leave_button = $Panel/VBoxContainer/HBoxContainer/LeaveButton

const REVEAL_TIME = 3.0
var reveal_timer = 0.0
var is_revealing = false
var current_item_id = ""
var current_key_target = ""   # Non-empty if this anchor holds a key
var current_anchor_name = ""
var current_apartment_id = ""
var anchor_node: Node = null

func _ready() -> void:
	visible = false
	take_button.pressed.connect(_on_take)
	leave_button.pressed.connect(_on_leave)

func open(item_id: String, anchor_name: String, apartment_id: String) -> void:
	is_revealing = false
	current_item_id = item_id
	current_anchor_name = anchor_name
	current_apartment_id = apartment_id
	current_key_target = ""
	anchor_node = get_tree().get_root().find_child(anchor_name, true, false)

	# Check if this anchor holds a key
	if WorldState.is_anchor_a_key(apartment_id, anchor_name):
		current_key_target = WorldState.get_anchor_key_target(apartment_id, anchor_name)
		current_item_id = "022"  # Apartment Key item ID

	if WorldState.is_anchor_searched(apartment_id, anchor_name):
		_reveal_item_immediate()
		return

	reveal_timer = 0.0
	is_revealing = true
	item_name_label.text = "Searching..."
	item_desc_label.text = ""
	take_button.visible = false
	leave_button.text = "Stop"
	visible = true

func _reveal_item_immediate() -> void:
	if current_item_id == "":
		item_name_label.text = "Nothing found."
		item_desc_label.text = ""
		leave_button.text = "Close"
		take_button.visible = false
	else:
		var item_data = ItemData.get_item(current_item_id)
		if item_data.is_empty():
			item_name_label.text = "Nothing found."
			item_desc_label.text = ""
			leave_button.text = "Close"
			take_button.visible = false
		else:
			if current_key_target != "":
				item_name_label.text = "Key — Apt " + current_key_target
			else:
				item_name_label.text = item_data["name"]
			item_desc_label.text = item_data["description"]
			take_button.visible = true
			leave_button.text = "Leave"
	visible = true

func _process(delta: float) -> void:
	if visible and anchor_node != null and is_instance_valid(anchor_node):
		var player = get_tree().get_first_node_in_group("player")
		if player != null:
			var dist = anchor_node.global_position.distance_to(player.global_position)
			if dist > anchor_node.INTERACT_DISTANCE * 1.5:
				_close()
				return

	if not is_revealing:
		return
	reveal_timer += delta
	if reveal_timer >= REVEAL_TIME:
		is_revealing = false
		_reveal_item()

func _reveal_item() -> void:
	WorldState.mark_anchor_searched(current_apartment_id, current_anchor_name)
	if current_item_id == "":
		item_name_label.text = "Nothing found."
		item_desc_label.text = ""
		leave_button.text = "Close"
		return
	var item_data = ItemData.get_item(current_item_id)
	if item_data.is_empty():
		item_name_label.text = "Nothing found."
		item_desc_label.text = ""
		leave_button.text = "Close"
		return
	if current_key_target != "":
		item_name_label.text = "Key — Apt " + current_key_target
	else:
		item_name_label.text = item_data["name"]
	item_desc_label.text = item_data["description"]
	take_button.visible = true
	leave_button.text = "Leave"

func _on_take() -> void:
	WorldState.interaction_handled = true
	if current_item_id != "":
		var added: bool
		if current_key_target != "":
			added = WorldState.add_key_to_inventory(current_key_target)
		else:
			added = WorldState.add_to_inventory(current_item_id)

		if added:
			WorldState.clear_anchor_item(current_apartment_id, current_anchor_name)
			HUD.refresh_inventory()
		else:
			item_name_label.text = "Inventory full."
			item_desc_label.text = "Drop something first."
			take_button.visible = false
			leave_button.text = "Close"
			return
	_close()

func _on_leave() -> void:
	WorldState.interaction_handled = true
	_close()

func _close() -> void:
	is_revealing = false
	visible = false
	anchor_node = null
	current_key_target = ""
