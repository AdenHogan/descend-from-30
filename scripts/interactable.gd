extends Marker2D

const GLOW_DISTANCE = 80.0
const INTERACT_DISTANCE = 50.0

var apartment_id: String = ""
var player: Node = null
var is_in_range: bool = false
var is_selected: bool = false

func _ready() -> void:
	print("Interactable ready at: ", global_position, " name: ", name)
	player = get_tree().get_first_node_in_group("player")

func _process(_delta: float) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			return
	var dist = global_position.distance_to(player.global_position)
	var was_in_range = is_in_range
	is_in_range = dist <= INTERACT_DISTANCE
	if was_in_range and not is_in_range:
		WorldState.interaction_handled = false
	queue_redraw()
	if not WorldState.is_scavenge_mode:
		return
	if Input.is_action_just_pressed("interact"):
		print("E pressed, is_in_range: ", is_in_range, " player: ", player)
	if is_in_range and Input.is_action_just_pressed("interact"):
		if not WorldState.interaction_handled:
			WorldState.interaction_handled = true
			_open_loot()

func _draw() -> void:
	if player == null:
		return
	if not WorldState.is_scavenge_mode:
		return
	var dist = global_position.distance_to(player.global_position)
	if dist > GLOW_DISTANCE:
		return
	if is_selected:
		draw_circle(Vector2.ZERO, 7.0, Color(1, 1, 0, 1.0))
	elif dist <= INTERACT_DISTANCE:
		draw_circle(Vector2.ZERO, 6.0, Color(1, 1, 1, 1.0))
	else:
		var alpha = 1.0 - ((dist - INTERACT_DISTANCE) / (GLOW_DISTANCE - INTERACT_DISTANCE))
		draw_circle(Vector2.ZERO, 4.0, Color(1, 1, 1, alpha * 0.6))

func try_interact() -> void:
	if not WorldState.is_scavenge_mode:
		return
	if not WorldState.interaction_handled:
		WorldState.interaction_handled = true
		_open_loot()

func _open_loot() -> void:
	var item_id = WorldState.get_anchor_item(apartment_id, name)
	var loot_ui = get_tree().get_root().find_child("LootUI", true, false)
	if loot_ui == null:
		push_error("LootUI not found")
		return
	loot_ui.open(item_id, name, apartment_id)
