extends Area2D

@export var target_scene: String = "res://scenes/building_floors.tscn"
@export var stair_side: String = "left"
@export var direction: String = "down"

var player_nearby = false
var bounce_time = 0.0
var arrow = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	arrow = find_child("Label")
	if arrow:
		arrow.visible = false

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player_nearby = true
		if arrow:
			arrow.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		player_nearby = false
		if arrow:
			arrow.visible = false

func _process(_delta: float) -> void:
	if player_nearby and arrow:
		bounce_time += _delta
		arrow.position.y = -80 + sin(bounce_time * 4.0) * 8.0
	if player_nearby and Input.is_action_just_pressed("interact"):
		WorldState.stair_spawn_side = stair_side
		WorldState.stair_direction = direction
		WorldState.spawn_source = "stair"
		if direction == "down":
			WorldState.current_floor -= 1
		elif direction == "up":
			WorldState.current_floor += 1
		if WorldState.current_floor == 30:
			get_tree().change_scene_to_file("res://scenes/hallway.tscn")
		elif WorldState.current_floor == 0:
			get_tree().change_scene_to_file("res://scenes/lobby.tscn")
		else:
			get_tree().change_scene_to_file("res://scenes/building_floors.tscn")
