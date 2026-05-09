extends Area2D

@export var room_scene: String = "res://scenes/room.tscn"
@export var apartment_id: String = "3001"

var player_nearby = false

@onready var proximity_label = $ProximityLabel

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	proximity_label.visible = false

func update_label() -> void:
	proximity_label.text = apartment_id

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player_nearby = true
		update_label()
		proximity_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		player_nearby = false
		proximity_label.visible = false

func _process(_delta: float) -> void:
	if player_nearby and Input.is_action_just_pressed("interact"):
		if not WorldState.interaction_handled:
			WorldState.interaction_handled = true
			WorldState.current_apartment_id = apartment_id
			WorldState.spawn_source = "door"
			WorldState.exit_spawn_x = global_position.x
			get_tree().change_scene_to_file(room_scene)
