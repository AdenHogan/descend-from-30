extends Node2D
# The inside of the elevator car (docs/MAINTENANCE_ELEVATOR.md — RECOMMENDED
# approach B: an interior cut, not a 5-floor pan). The player has fitted 3 fuses at
# a maintenance-room fuse box and stepped into the powered lift. Press UP or DOWN to
# ride 5 floors that way; the ride SPENDS the charge (single-use — 3 more fuses for
# the next trip) and lets the player out on the destination floor.
#
# A closed box shows no floors scrolling by (a real elevator you can't see out of),
# so this is a self-contained UI beat: pick a direction → a brief "the car
# descends/rises" caption → arrive on the destination floor's building_floors.

const DING := preload("res://assets/audio/elevator_ding.wav")

var _riding: bool = false          # guard so a held key can't fire two rides
@onready var _origin_floor: int = WorldState.current_floor


func _ready() -> void:
	_build_ui()
	_play_ding()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ElevatorUI"
	add_child(layer)

	# Dark car interior filling the screen.
	var bg := ColorRect.new()
	bg.color = Color(0.11, 0.12, 0.14)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)

	# A lit floor-indicator panel above the doors.
	var panel := VBoxContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_theme_constant_override("separation", 14)
	panel.position = Vector2(-180, -110)
	panel.custom_minimum_size = Vector2(360, 0)
	layer.add_child(panel)

	var font := preload("res://assets/fonts/PixelOperator8.ttf")

	var title := Label.new()
	title.text = "ELEVATOR — Floor %d" % _origin_floor
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	panel.add_child(title)

	var up_dest := WorldState.elevator_destination(1)
	var down_dest := WorldState.elevator_destination(-1)

	var up_line := Label.new()
	up_line.text = ("[ ↑ ]  Go UP to floor %d" % up_dest) if up_dest != _origin_floor \
		else "[ ↑ ]  — already near the top"
	up_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	up_line.add_theme_font_override("font", font)
	up_line.add_theme_font_size_override("font_size", 14)
	up_line.add_theme_color_override("font_color",
		Color(0.85, 0.9, 0.95) if up_dest != _origin_floor else Color(0.45, 0.45, 0.48))
	panel.add_child(up_line)

	var down_line := Label.new()
	down_line.text = ("[ ↓ ]  Go DOWN to floor %d" % down_dest) if down_dest != _origin_floor \
		else "[ ↓ ]  — already near the bottom"
	down_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	down_line.add_theme_font_override("font", font)
	down_line.add_theme_font_size_override("font_size", 14)
	down_line.add_theme_color_override("font_color",
		Color(0.85, 0.9, 0.95) if down_dest != _origin_floor else Color(0.45, 0.45, 0.48))
	panel.add_child(down_line)

	var hint := Label.new()
	hint.text = "Powered by 3 fuses — this ride spends them."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_override("font", font)
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.64))
	panel.add_child(hint)


func _process(_delta: float) -> void:
	if _riding:
		return
	if Input.is_action_just_pressed("move_up"):
		_ride(1)
	elif Input.is_action_just_pressed("move_down"):
		_ride(-1)


func _ride(direction: int) -> void:
	var dest := WorldState.elevator_destination(direction)
	if dest == _origin_floor:
		# Clamped — a 5-floor jump this way would overshoot the ends. Stay put and let
		# the player pick the other direction instead of trapping them.
		HUD.show_feedback("The elevator can't go that far — try the other way.")
		return
	_riding = true
	WorldState.consume_elevator_power()          # single-use: gather 3 more fuses next time
	WorldState.current_floor = dest
	WorldState.on_floor_arrived(dest)
	WorldState.spawn_source = "elevator"          # building_floors lets us out by the lift
	WorldState.stair_spawn_side = ""
	WorldState.stair_direction = ""
	WorldState.exit_spawn_x = 0.0
	HUD.update_floor_label()
	var caption := ("The car rises." if direction > 0 else "The car descends.") \
		+ "\nDoors open on floor %d." % dest
	Transition.to_scene_shift("res://scenes/building_floors.tscn", caption, 1.2)


func _play_ding() -> void:
	var p := AudioStreamPlayer.new()
	p.stream = DING
	p.volume_db = -5.0
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
