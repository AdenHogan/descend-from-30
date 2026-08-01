extends Area2D

# Balcony descent trigger (THREE_RUN_ARC balcony route). Walk under a revealed
# balcony and a yellow up-arrow bobs — W (move_up) is otherwise unused in this
# side-on game, so this is one of the few places pressing UP does something.
# Press W to lash a rope and climb down into the apartment directly below; press
# R first to listen to what's down there. Mirrors the stairwell's arrow/prompt.
# room.gd instantiates one per revealed balcony and sets apartment_id + slot.

var apartment_id: String = ""
var slot: int = 0

const ARROW_FONT = preload("res://assets/fonts/PixelOperator8.ttf")
const ARROW_BASE_Y = -85.0

var player_nearby := false
var bounce_time := 0.0
var arrow: Label = null
var prompt: Label = null
var listen_label: Label = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	# Match the stairwell arrow exactly (building_floors.tscn): a "↑" in
	# PixelOperator8 at 38px, z 1, bobbing when the player is near.
	arrow = Label.new()
	arrow.text = "↑"
	arrow.add_theme_font_override("font", ARROW_FONT)
	arrow.add_theme_font_size_override("font_size", 38)
	arrow.z_index = 1
	arrow.position = Vector2(-17, ARROW_BASE_Y)
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.visible = false
	add_child(arrow)
	prompt = _make_label(Vector2(-48, -48), 96, 12)
	listen_label = _make_label(Vector2(-56, -32), 112, 11)
	listen_label.text = "[R] Listen below"


func _make_label(pos: Vector2, width: float, size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.position = pos
	l.size = Vector2(width, 18)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.visible = false
	# Never eat world clicks (click-to-move regression, see room.gd).
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player_nearby = true
		_refresh()


func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		player_nearby = false
		arrow.visible = false
		prompt.visible = false
		listen_label.visible = false


func _refresh() -> void:
	var has_below := WorldState.balcony_below(apartment_id) != ""
	arrow.visible = has_below
	prompt.visible = has_below
	listen_label.visible = has_below
	if not has_below:
		return
	if WorldState.is_balcony_roped(apartment_id, slot) or WorldState.has_descent_rope():
		prompt.text = "[W] Climb down"
	else:
		prompt.text = "[W] Jump down"


func _process(delta: float) -> void:
	if not player_nearby:
		return
	bounce_time += delta
	arrow.position.y = ARROW_BASE_Y - absf(sin(bounce_time * 4.0)) * 8.0
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	if Input.is_action_just_pressed("move_up") and player.has_method("begin_balcony_descent"):
		player.begin_balcony_descent(apartment_id, slot, global_position)
	elif Input.is_action_just_pressed("listen") and player.has_method("start_listen"):
		var below := WorldState.balcony_below(apartment_id)
		if below != "":
			player.start_listen(global_position, WorldState.get_listen_report_for_apartment(below))
