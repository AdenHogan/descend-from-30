extends Area2D

# WorldDrop — a pickup that appears in the world when:
# - A zombie drops loot on death
# - A boss drops a key and inventory is full
# - The player discards an item
#
# Scene structure:
#   WorldDrop (Area2D)
#     CollisionShape2D  (CircleShape2D radius=12)
#     Sprite2D          (optional icon — or just draw_circle)
#     ProximityLabel    (Label, visible=false by default)
#
# Placed at res://scenes/world_drop.tscn

const PICKUP_RANGE = 40.0
const GLOW_RANGE = 80.0

var item_id: String = ""         # Regular item ID, or "" for key drops
var item_type: String = "item"   # "item" or "key"
var key_target: String = ""      # Apartment ID if item_type == "key"
var drop_key: String = ""        # WorldState.world_drops key for persistence

var player: Node2D = null
var player_nearby: bool = false

@onready var proximity_label: Label = $ProximityLabel


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	proximity_label.visible = false
	add_to_group("world_drop")


func setup(p_item_id: String, p_item_type: String, p_key_target: String, p_drop_key: String) -> void:
	item_id = p_item_id
	item_type = p_item_type
	key_target = p_key_target
	drop_key = p_drop_key
	player = get_tree().get_first_node_in_group("player")
	_update_label()


func _update_label() -> void:
	if item_type == "key":
		proximity_label.text = "Key — Apt " + key_target + "  [E] Take"
	else:
		var item_data = ItemData.get_item(item_id)
		var name = item_data.get("name", "Item") if not item_data.is_empty() else "Item"
		proximity_label.text = name + "  [E] Take"


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = body
		player_nearby = true
		proximity_label.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_nearby = false
		proximity_label.visible = false


func _process(_delta: float) -> void:
	queue_redraw()
	if not player_nearby:
		return
	if Input.is_action_just_pressed("interact"):
		_try_pickup()


func _try_pickup() -> void:
	var added: bool
	if item_type == "key":
		added = WorldState.add_key_to_inventory(key_target)
		if added:
			HUD.show_feedback("Key — Apt " + key_target + " picked up.")
		else:
			HUD.show_feedback("Inventory full.")
			return
	else:
		added = WorldState.add_to_inventory(item_id)
		if added:
			var item_data = ItemData.get_item(item_id)
			HUD.show_feedback(item_data.get("name", "Item") + " picked up.")
			HUD.refresh_inventory()
		else:
			HUD.show_feedback("Inventory full.")
			return

	# Remove from WorldState persistence
	if drop_key != "":
		WorldState.remove_world_drop(drop_key)
	queue_free()


func _draw() -> void:
	if player == null:
		return
	var dist = global_position.distance_to(player.global_position)
	if dist > GLOW_RANGE:
		return
	# Yellow-gold glow for world drops — distinct from white orb of anchors
	var alpha = 1.0 - clamp((dist - PICKUP_RANGE) / (GLOW_RANGE - PICKUP_RANGE), 0.0, 1.0)
	if item_type == "key":
		draw_circle(Vector2.ZERO, 6.0, Color(1.0, 0.85, 0.1, alpha))
	else:
		draw_circle(Vector2.ZERO, 5.0, Color(1.0, 0.65, 0.0, alpha))
