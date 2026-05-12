extends Marker2D

const GLOW_DISTANCE = 80.0
const INTERACT_DISTANCE = 24.0

var apartment_id: String = ""
var player: Node = null
var dot: Node2D = null
var is_in_range: bool = false

func _ready() -> void:
	print("Interactable ready at: ", global_position, " name: ", name)
	player = get_tree().get_first_node_in_group("player")
	_create_dot()

func _create_dot() -> void:
	dot = Node2D.new()
	dot.visible = false
	add_child(dot)

func _process(_delta: float) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			return
	var dist = global_position.distance_to(player.global_position)
	if dist > GLOW_DISTANCE:
		is_in_range = false
	elif dist > INTERACT_DISTANCE:
		is_in_range = false
	else:
		is_in_range = true
	queue_redraw()
	if Input.is_action_just_pressed("interact"):
		print("E pressed, is_in_range: ", is_in_range, " player: ", player)
	if is_in_range and Input.is_action_just_pressed("interact"):
		if not WorldState.interaction_handled:
			WorldState.interaction_handled = true
			_open_loot()


func _draw() -> void:
	if player == null:
		return
	var dist = global_position.distance_to(player.global_position)
	if dist > GLOW_DISTANCE:
		return
	elif dist > INTERACT_DISTANCE:
		var alpha = 1.0 - ((dist - INTERACT_DISTANCE) / (GLOW_DISTANCE - INTERACT_DISTANCE))
		draw_circle(Vector2.ZERO, 4.0, Color(1, 1, 1, alpha * 0.6))
	else:
		draw_circle(Vector2.ZERO, 6.0, Color(1, 1, 1, 1.0))

func _open_loot() -> void:
	var item_id = WorldState.get_anchor_item(apartment_id, name)
	var loot_ui = get_tree().get_root().find_child("LootUI", true, false)
	if loot_ui == null:
		push_error("LootUI not found")
		return
	loot_ui.open(item_id, name, apartment_id)
