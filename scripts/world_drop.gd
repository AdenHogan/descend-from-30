extends Area2D

const PICKUP_RANGE = 40.0
const GLOW_RANGE = 80.0

var item_id: String = ""
var target_apartment: String = ""
var drop_key: String = ""
var amount: int = 0  # Bank Notes bundle size; 0 = roll default on pickup

var player: Node2D = null
var player_nearby: bool = false

@onready var proximity_label: Label = $ProximityLabel


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	proximity_label.visible = false
	add_to_group("world_drop")
	player = get_tree().get_first_node_in_group("player")


func _update_label() -> void:
	if target_apartment != "":
		proximity_label.text = "Key — Apt " + target_apartment + "  [Click] Take"
	else:
		var item_data = ItemData.get_item(item_id)
		var display_name = item_data.get("name", "Item") if not item_data.is_empty() else "Item"
		proximity_label.text = display_name + "  [Click] Take"


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = body
		player_nearby = true
		_update_label()
		proximity_label.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_nearby = false
		proximity_label.visible = false


func _input(event: InputEvent) -> void:
	if not player_nearby:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _is_mouse_over_orb():
			_try_pickup()


func _process(_delta: float) -> void:
	queue_redraw()
	if not player_nearby:
		return
	if Input.is_action_just_pressed("interact"):
		_try_pickup()


func _is_mouse_over_orb() -> bool:
	var p = get_tree().get_first_node_in_group("player")
	if p == null:
		return false
	var cam = p.get_node_or_null("Camera2D")
	if cam == null:
		return false
	var mouse_world = cam.get_screen_center_position() + \
		(get_viewport().get_mouse_position() - get_viewport().get_visible_rect().size / 2) / cam.zoom
	return global_position.distance_to(mouse_world) <= PICKUP_RANGE


func _try_pickup() -> void:
	var added: bool
	if target_apartment != "":
		added = WorldState.add_key_to_inventory(target_apartment)
		if added:
			HUD.show_feedback("Key — Apt " + target_apartment + " picked up.")
			HUD.refresh_inventory()
		else:
			HUD.show_feedback("Inventory full.")
			return
	else:
		added = WorldState.add_to_inventory(item_id, amount)
		if added:
			var item_data = ItemData.get_item(item_id)
			HUD.show_feedback(item_data.get("name", "Item") + " picked up.")
			HUD.refresh_inventory()
		else:
			HUD.show_feedback("Inventory full.")
			return
	if drop_key != "":
		WorldState.remove_world_drop(drop_key)
	queue_free()


func _draw() -> void:
	if player == null:
		return
	var dist = global_position.distance_to(player.global_position)
	if dist > GLOW_RANGE:
		return
	var alpha = 1.0 - clamp((dist - PICKUP_RANGE) / (GLOW_RANGE - PICKUP_RANGE), 0.0, 1.0)
	if target_apartment != "":
		draw_circle(Vector2.ZERO, 6.0, Color(1.0, 0.85, 0.1, alpha))
	else:
		draw_circle(Vector2.ZERO, 5.0, Color(1.0, 0.65, 0.0, alpha))
