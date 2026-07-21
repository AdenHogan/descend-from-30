extends Area2D

@export var target_scene: String = "res://scenes/building_floors.tscn"
@export var stair_side: String = "left"
@export var direction: String = "down"

var player_nearby = false
var bounce_time = 0.0
var arrow = null
var listen_label: Label = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	input_event.connect(_on_click)
	arrow = find_child("Label")
	if arrow:
		arrow.visible = false
	# Down-stairwells offer a listen read of the floor below (SOUND_STEALTH.md).
	if direction == "down":
		listen_label = Label.new()
		listen_label.text = "[R] Listen below"
		listen_label.add_theme_font_size_override("font_size", 12)
		listen_label.position = Vector2(-55, -46)
		listen_label.size = Vector2(120, 18)
		listen_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		listen_label.visible = false
		add_child(listen_label)

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player_nearby = true
		if arrow:
			arrow.visible = true
		if listen_label:
			listen_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		player_nearby = false
		if arrow:
			arrow.visible = false
		if listen_label:
			listen_label.visible = false

func _process(_delta: float) -> void:
	if player_nearby and arrow:
		bounce_time += _delta
		arrow.position.y = -80 + sin(bounce_time * 4.0) * 8.0
	if player_nearby and direction == "down" and Input.is_action_just_pressed("listen"):
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_method("start_listen"):
			var report = WorldState.get_listen_report_for_floor_below()
			player.start_listen(global_position, report)
			return
	if player_nearby and Input.is_action_just_pressed("interact"):
		_use_stairs()


func _on_click(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	# Left-click the stairwell to use it, same as E (playtest request). Only
	# when you're standing in it; otherwise the click walks you over instead.
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if not player_nearby:
		return
	get_viewport().set_input_as_handled()
	_use_stairs()


func _use_stairs() -> void:
	WorldState.stair_spawn_side = stair_side
	WorldState.stair_direction = direction
	WorldState.spawn_source = "stair"
	if direction == "down":
		WorldState.current_floor -= 1
	elif direction == "up":
		WorldState.current_floor += 1
	WorldState.on_floor_arrived(WorldState.current_floor)
	HUD.update_floor_label()
	if WorldState.current_floor == 30:
		get_tree().change_scene_to_file("res://scenes/hallway.tscn")
	elif WorldState.current_floor == 0:
		get_tree().change_scene_to_file("res://scenes/lobby.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/building_floors.tscn")
