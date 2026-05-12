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

func _ready() -> void:
	visible = false
	take_button.pressed.connect(_on_take)
	leave_button.pressed.connect(_on_leave)

func open(item_id: String, anchor_name: String, apartment_id: String) -> void:
	current_item_id = item_id
	current_anchor_name = anchor_name
	current_apartment_id = apartment_id
	reveal_timer = 0.0
	is_revealing = true
	item_name_label.text = "Searching..."
	item_desc_label.text = ""
	take_button.visible = false
	leave_button.text = "Stop"
	visible = true

func _process(delta: float) -> void:
	if not is_revealing:
		return
	reveal_timer += delta
	if reveal_timer >= REVEAL_TIME:
		is_revealing = false
		_reveal_item()

func _reveal_item() -> void:
	var item_data = ItemData.get_item(current_item_id)
	if item_data.is_empty():
		item_name_label.text = "Nothing found."
		leave_button.text = "Close"
		return
	item_name_label.text = item_data["name"]
	item_desc_label.text = item_data["description"]
	take_button.visible = true
	leave_button.text = "Leave"

func _on_take() -> void:
	print("Taking item: ", current_item_id)
	WorldState.clear_anchor_item(current_apartment_id, current_anchor_name)
	visible = false

func _on_leave() -> void:
	is_revealing = false
	visible = false
