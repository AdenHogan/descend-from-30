extends CanvasLayer

@onready var item_name_label = $Panel/VBoxContainer/ItemName
@onready var item_desc_label = $Panel/VBoxContainer/ItemDescription
@onready var take_button = $Panel/VBoxContainer/HBoxContainer/TakeButton
@onready var leave_button = $Panel/VBoxContainer/HBoxContainer/LeaveButton

const REVEAL_TIME = 3.0
var reveal_timer = 0.0
var is_revealing = false
var current_item_id = ""
var current_anchor_name = ""
var current_apartment_id = ""
var anchor_node: Node = null

func _ready() -> void:
	visible = false
	take_button.pressed.connect(_on_take)
	leave_button.pressed.connect(_on_leave)

func open(item_id: String, anchor_name: String, apartment_id: String) -> void:
	# Cancel any current search cleanly
	is_revealing = false

	current_item_id = item_id
	current_anchor_name = anchor_name
	current_apartment_id = apartment_id
	anchor_node = get_tree().get_root().find_child(anchor_name, true, false)

	# Check if already searched
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
	var item_data = ItemData.get_item(current_item_id)
	if item_data.is_empty():
		item_name_label.text = "Nothing found."
		item_desc_label.text = ""
		leave_button.text = "Close"
		take_button.visible = false
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
	# Mark as searched regardless of result
	WorldState.mark_anchor_searched(current_apartment_id, current_anchor_name)
	var item_data = ItemData.get_item(current_item_id)
	if item_data.is_empty():
		item_name_label.text = "Nothing found."
		item_desc_label.text = ""
		leave_button.text = "Close"
		return
	item_name_label.text = item_data["name"]
	item_desc_label.text = item_data["description"]
	take_button.visible = true
	leave_button.text = "Leave"

func _on_take() -> void:
	WorldState.interaction_handled = true
	if current_item_id != "":
		var added = WorldState.add_to_inventory(current_item_id)
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
