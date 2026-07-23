extends CanvasLayer

@onready var item_name_label = $Panel/VBoxContainer/ItemName
@onready var item_desc_label = $Panel/VBoxContainer/ItemDescription
@onready var take_button = $Panel/VBoxContainer/HBoxContainer/TakeButton
@onready var leave_button = $Panel/VBoxContainer/HBoxContainer/LeaveButton

const REVEAL_TIME = 3.0
var reveal_timer = 0.0
var is_revealing = false
var current_item_id = ""
var current_key_target = ""
var current_anchor_name = ""
var current_apartment_id = ""
var anchor_node: Node = null


func _ready() -> void:
	visible = false
	take_button.pressed.connect(_on_take)
	leave_button.pressed.connect(_on_leave)


func open(item_id: String, anchor_name: String, apartment_id: String) -> void:
	WorldState.loot_open = true
	is_revealing = false
	current_item_id = item_id
	current_anchor_name = anchor_name
	current_apartment_id = apartment_id
	current_key_target = ""
	anchor_node = get_tree().get_root().find_child(anchor_name, true, false)

	if WorldState.is_anchor_a_key(apartment_id, anchor_name):
		current_key_target = WorldState.get_anchor_key_target(apartment_id, anchor_name)
		current_item_id = "022"

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
				_close(false)
				return

	if not is_revealing:
		return
	# Searching demands both hands: switching out of scavenge mode (or the
	# mode-switch spin itself) cancels the search — the timer never runs on.
	if not WorldState.is_scavenge_mode:
		_close(false)
		return
	var searcher = get_tree().get_first_node_in_group("player")
	if searcher != null and (searcher.is_switching_mode or searcher.is_pushing or searcher.is_attacking):
		_close(false)
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
		# Nothing found — hide the orb immediately
		_notify_anchor_closed(false)
		return
	var item_data = ItemData.get_item(current_item_id)
	if item_data.is_empty():
		item_name_label.text = "Nothing found."
		item_desc_label.text = ""
		leave_button.text = "Close"
		_notify_anchor_closed(false)
		return
	if current_key_target != "":
		item_name_label.text = "Key — Apt " + current_key_target
	else:
		item_name_label.text = item_data["name"]
	item_desc_label.text = item_data["description"]
	take_button.visible = true
	leave_button.text = "Leave"


func _input(event: InputEvent) -> void:
	# Convenience (playtest): once an item is revealed, TAKE it with E or a
	# left-click too — not only the Take button. (Walking away already leaves.)
	if not visible or is_revealing or not take_button.visible:
		return
	var take = false
	if event.is_action_pressed("interact"):
		take = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# A click on the Leave button still leaves; anywhere else takes.
		if not leave_button.get_global_rect().has_point(event.position):
			take = true
	if take:
		get_viewport().set_input_as_handled()
		_on_take()


func _on_take() -> void:
	WorldState.interaction_handled = true
	if current_item_id != "":
		var added: bool
		if current_key_target != "":
			added = WorldState.add_key_to_inventory(current_key_target)
		else:
			# A scripted node can PIN the exact pickup amount (cash / bullets);
			# otherwise ammo rolls a random bundle and money rolls in add_to_inventory.
			var amount = WorldState.get_anchor_amount(current_apartment_id, current_anchor_name)
			if amount <= 0 and ItemData.get_item(current_item_id).get("is_ammo", false):
				amount = _roll_ammo_bundle()
			added = WorldState.add_to_inventory(current_item_id, amount)

		if added:
			WorldState.clear_anchor_item(current_apartment_id, current_anchor_name)
			HUD.refresh_inventory()
		else:
			item_name_label.text = "Inventory full."
			item_desc_label.text = "Drop something first."
			take_button.visible = false
			leave_button.text = "Close"
			return
	_close(true)


func _on_leave() -> void:
	WorldState.interaction_handled = true
	_close(false)


func _roll_ammo_bundle() -> int:
	# Seeded per anchor so re-searching can't reroll. Weights fall off with
	# size: 2 is common, 8 is a lucky day.
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(str(WorldState.master_seed) + "ammobundle" + current_apartment_id + current_anchor_name)
	var weights = [30, 22, 16, 12, 9, 7, 4]  # sizes 2..8
	var total = 100
	var roll = rng.randi() % total
	var acc = 0
	for i in range(weights.size()):
		acc += weights[i]
		if roll < acc:
			return i + 2
	return 2


func _close(item_taken: bool) -> void:
	is_revealing = false
	visible = false
	WorldState.loot_open = false
	_notify_anchor_closed(item_taken)
	anchor_node = null
	current_key_target = ""
	var player = get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("restore_stance"):
		player.restore_stance()


func _notify_anchor_closed(item_taken: bool) -> void:
	if anchor_node != null and is_instance_valid(anchor_node) and anchor_node.has_method("on_loot_closed"):
		anchor_node.on_loot_closed(item_taken)
