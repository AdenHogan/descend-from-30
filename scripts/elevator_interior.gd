extends Node2D
# The inside of the elevator car (docs/MAINTENANCE_ELEVATOR.md — approach B, an
# interior cut). Its own little instance you ride in — Silksong bench-room style: the
# player stands in a drawn metal car, picks a direction, and the car RUMBLES with
# light bars streaming past the walls for a few seconds before a bing-bong lets them
# out five floors away. Not instant — a brief reprieve. The closed car leaves room
# beside the player for a future one-off NPC beat.
#
# Powered by 3 fuses fitted at a maintenance-room fuse box; the ride SPENDS the charge
# (single-use). See building_floors._elevator_ride_process for the corridor entry.

const DING := preload("res://assets/audio/elevator_ding.wav")
const CAR := preload("res://scripts/elevator_car.gd")

var _origin_floor: int = 0
var _dest_floor: int = 0
var _direction: int = 0
var _phase: String = "idle"          # "idle" | "moving" | "arriving" | "done"
var _elapsed: float = 0.0
var _duration: float = 2.4
var _car: Node2D = null
var _cam: Camera2D = null
var _z: float = 2.0                   # camera zoom (car screen size), set in _setup_camera
var _car_center_y: float = 0.0        # screen y of the car's centre (for UI placement)
var _floor_label: Label = null
var _title_label: Label = null
var _choices: VBoxContainer = null


func _ready() -> void:
	_origin_floor = WorldState.current_floor
	_car = CAR.new()
	add_child(_car)
	_spawn_rider()
	_setup_camera()
	_build_ui()


func _spawn_rider() -> void:
	# The player, standing in the car (visual only — strip the movement script and the
	# gameplay camera so it just idles). Leaves space to the right for a future NPC.
	var p = preload("res://scenes/player.tscn").instantiate()
	p.set_script(null)                 # no movement/input — a still passenger
	var cam = p.get_node_or_null("Camera2D")
	if cam:
		cam.queue_free()
	# Stand the rider to the LEFT of centre, feet on the floor plate — leaving room on
	# the right for a future NPC without either of them feeling squeezed.
	p.position = Vector2(-42, 34)
	p.scale = Vector2(1.4, 1.4)
	p.z_index = 5
	add_child(p)
	var spr = p.get_node_or_null("AnimatedSprite2D")
	if spr:
		spr.play("idle")


func _setup_camera() -> void:
	_cam = Camera2D.new()
	add_child(_cam)
	var vp := get_viewport_rect().size
	# Show the cramped car at a sensible fixed on-screen size (~2.4x), clamped down on
	# short screens so it never runs into the HUD. Centre it in the upper-middle, with
	# the black shaft filling the rest of the (landscape) screen around the narrow car.
	var car_h := CAR.HALF_H * 2.0
	_z = minf(2.1, (vp.y - 160.0) / (car_h + 44.0))
	_cam.zoom = Vector2(_z, _z)
	_car_center_y = vp.y * 0.44
	# Camera world-y that puts the car centre (world 0) at _car_center_y on screen.
	_cam.position = Vector2(0, (vp.y * 0.5 - _car_center_y) / _z)
	_cam.make_current()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ElevatorUI"
	add_child(layer)
	var font := preload("res://assets/fonts/PixelOperator8.ttf")

	# UI lives in the black margins AROUND the narrow car: readout above, controls below —
	# the cramped car itself stays clear (the rider nearly fills it).
	var vp := get_viewport_rect().size
	var half_h_px: float = CAR.HALF_H * _z
	var car_top: float = _car_center_y - half_h_px
	var car_bot: float = _car_center_y + half_h_px

	# Big floor readout above the car (ticks through floors during the ride).
	_floor_label = Label.new()
	_floor_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_floor_label.offset_top = car_top - 42.0
	_floor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_floor_label.add_theme_font_override("font", font)
	_floor_label.add_theme_font_size_override("font_size", 26)
	_floor_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.35))
	layer.add_child(_floor_label)

	_title_label = Label.new()
	_title_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_title_label.offset_top = car_top - 62.0
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_override("font", font)
	_title_label.add_theme_font_size_override("font_size", 12)
	_title_label.add_theme_color_override("font_color", Color(0.7, 0.72, 0.78))
	_title_label.text = "ELEVATOR"
	layer.add_child(_title_label)

	# Direction choices below the car (idle only).
	_choices = VBoxContainer.new()
	_choices.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_choices.offset_top = car_bot + 14.0
	_choices.alignment = BoxContainer.ALIGNMENT_CENTER
	_choices.add_theme_constant_override("separation", 6)
	layer.add_child(_choices)

	var up_dest := WorldState.elevator_destination(1)
	var down_dest := WorldState.elevator_destination(-1)
	_choices.add_child(_choice_label(font, "[ ↑ ]  Go UP to floor %d" % up_dest, up_dest != _origin_floor))
	_choices.add_child(_choice_label(font, "[ ↓ ]  Go DOWN to floor %d" % down_dest, down_dest != _origin_floor))
	var hint := _choice_label(font, "3 fuses fitted — this ride spends them.", false)
	hint.add_theme_font_size_override("font_size", 9)
	_choices.add_child(hint)

	_refresh_floor_readout()


func _choice_label(font: Font, text: String, enabled: bool) -> Label:
	var lb := Label.new()
	lb.text = text
	lb.size_flags_horizontal = Control.SIZE_FILL
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.add_theme_font_override("font", font)
	lb.add_theme_font_size_override("font_size", 14)
	lb.add_theme_color_override("font_color", Color(0.86, 0.9, 0.95) if enabled else Color(0.5, 0.5, 0.54))
	return lb


func _refresh_floor_readout() -> void:
	_floor_label.text = "Floor %d" % (_display_floor())


func _display_floor() -> int:
	if _phase == "idle" or _direction == 0:
		return _origin_floor
	var frac: float = clampf(_elapsed / _duration, 0.0, 1.0)
	return int(round(lerpf(float(_origin_floor), float(_dest_floor), frac)))


func _process(delta: float) -> void:
	match _phase:
		"idle":
			if Input.is_action_just_pressed("move_up"):
				_start_ride(1)
			elif Input.is_action_just_pressed("move_down"):
				_start_ride(-1)
		"moving":
			_elapsed += delta
			# Rumble: jitter the camera, ramped in at the start and out at the end so
			# the car settles rather than snapping still.
			var ramp: float = clampf(minf(_elapsed, _duration - _elapsed) / 0.5, 0.0, 1.0)
			var amp: float = 1.6 * ramp
			_cam.offset = Vector2(randf_range(-amp, amp), randf_range(-amp, amp)) \
				+ Vector2(0, sin(_elapsed * 22.0) * 0.6 * ramp)
			_refresh_floor_readout()
			if _elapsed >= _duration:
				_arrive()


func _start_ride(direction: int) -> void:
	var dest := WorldState.elevator_destination(direction)
	if dest == _origin_floor:
		# Clamped — that way would overshoot the ends. Stay and let them pick the other.
		HUD.show_feedback("The elevator can't go that far — try the other way.")
		return
	_direction = direction
	_dest_floor = dest
	_phase = "moving"
	_elapsed = 0.0
	var steps: int = absi(dest - _origin_floor)
	_duration = clampf(steps * 0.55, 1.8, 3.6)
	_car.phase = "moving"
	_car.direction = direction
	_choices.visible = false
	_title_label.text = "▲  GOING UP" if direction > 0 else "▼  GOING DOWN"


func _arrive() -> void:
	_phase = "arriving"
	_car.phase = "arriving"
	_cam.offset = Vector2.ZERO
	_direction = 0
	WorldState.current_floor = _dest_floor
	_floor_label.text = "Floor %d" % _dest_floor
	_title_label.text = "ELEVATOR"
	_choices.visible = false
	# Commit the ride now (single-use: 3 more fuses for the next trip).
	WorldState.consume_elevator_power()
	WorldState.on_floor_arrived(_dest_floor)
	WorldState.spawn_source = "elevator"
	WorldState.stair_spawn_side = ""
	WorldState.stair_direction = ""
	WorldState.exit_spawn_x = 0.0
	HUD.update_floor_label()
	# The doors slide open with the bing-bong — a glimpse of the hallway beyond — then
	# a beat to take it in before stepping out onto the floor.
	_play_bing_bong()
	var tw := create_tween()
	tw.tween_property(_car, "door_open", 1.0, 0.8)
	await tw.finished
	await get_tree().create_timer(0.8, false).timeout
	Transition.to_scene("res://scenes/building_floors.tscn")


func _play_bing_bong() -> void:
	# Arrival chime: a bing, then a lower bong.
	_ding(-3.0, 1.0)
	await get_tree().create_timer(0.34, false).timeout
	if is_inside_tree():
		_ding(-3.0, 0.72)


func _ding(volume_db: float, pitch: float) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = DING
	p.volume_db = volume_db
	p.pitch_scale = pitch
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
