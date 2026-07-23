extends Area2D

@export var target_scene: String = "res://scenes/building_floors.tscn"
@export var stair_side: String = "left"
@export var direction: String = "down"

var player_nearby = false
var bounce_time = 0.0
var arrow = null
var listen_label: Label = null
var _herd_said = false

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
		# Tutorial (first-run Floor 30): the descent is gated until the 3003
		# neighbour is dealt with — nudge the player back toward the apartments.
		if direction == "down" and TutorialManager.stairs_locked():
			_herd_back(body)

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		player_nearby = false
		_herd_said = false
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
	if player_nearby and Input.is_action_just_pressed("interact") and not TutorialManager.interact_guarded():
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


func _on_no_return() -> void:
	pass


func _herd_back(body: Node2D) -> void:
	# Say the stage's line once per approach, and steer the player toward the
	# apartment the tutorial wants them in next (no herding while the corridor
	# zombie is live — target_x < 0).
	var info = TutorialManager.stair_block_info()
	if info.is_empty():
		return
	if not _herd_said:
		TutorialManager.say(info["line"])
		_herd_said = true
	if info["target_x"] >= 0.0 and body.has_method("set_move_target"):
		body.set_move_target(info["target_x"])


func _use_stairs() -> void:
	# Tutorial run: no going back UP to Floor 30 (its scripted rooms are a
	# one-way door — actions have consequences). Pause + refuse.
	if direction == "up" and WorldState.is_first_run and WorldState.current_floor == 29:
		TutorialManager.prompt(TutorialManager.LINES["no_return"], "interact", _on_no_return, "[E]")
		return

	# Gate the first-run Floor-30 descent until the 3003 encounter is cleared.
	if direction == "down" and TutorialManager.stairs_locked():
		var player = get_tree().get_first_node_in_group("player")
		if player != null:
			_herd_back(player)
		return
	WorldState.stair_spawn_side = stair_side
	WorldState.stair_direction = direction
	WorldState.spawn_source = "stair"
	var target_floor = WorldState.current_floor + (-1 if direction == "down" else 1)

	# Seamless pan between two mid-building floors when enabled; it commits the
	# floor + scene change itself. Otherwise (and always, while disabled) the
	# plain fade cut below.
	# >>> TO ENABLE THE STAIR PAN: set `const ENABLED := true` at the top of
	#     scripts/stair_pan.gd (that's the toggle — not here / not building_floors).
	if StairPan.can_pan(target_floor):
		StairPan.pan_to_floor(target_floor, direction)
		return

	WorldState.current_floor = target_floor
	WorldState.on_floor_arrived(WorldState.current_floor)
	HUD.update_floor_label()
	if WorldState.current_floor == 30:
		Transition.to_scene("res://scenes/hallway.tscn")
	elif WorldState.current_floor == 0:
		Transition.to_scene("res://scenes/lobby.tscn")
	else:
		Transition.to_scene("res://scenes/building_floors.tscn")
