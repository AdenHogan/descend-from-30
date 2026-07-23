extends Node

# Autoload: seamless stair transition (docs/TUTORIAL.md #3). Instead of a hard
# cut between floors, this loads the ADJACENT floor as a passive backdrop one
# screen away, pans a standalone camera across as the player walks the stairs,
# then commits the real floor.
#
# DISABLED by default (ENABLED = false): the pan is a visual effect that needs
# in-editor tuning (offset, timing, the stair-walk slide) and can't be verified
# headless — while off, stairs use the plain fade (Transition). To try it, flip
# ENABLED and route stairwell._use_stairs through StairPan.pan_to_floor() for
# the building_floors↔building_floors case. The building_floors `passive` /
# `setup_floor` parameters it relies on are real and tested (see
# building_floors_test).

const ENABLED := false
const PAN_TIME := 1.1

var panning := false


func can_pan(target_floor: int) -> bool:
	# Only between two mid-building floors (both building_floors). Trips to the
	# hallway (30) or lobby (0) fall back to the fade.
	if not ENABLED or panning:
		return false
	if target_floor <= 0 or target_floor >= 30:
		return false
	var scene = get_tree().current_scene
	return scene != null and scene.scene_file_path.contains("building_floors")


func pan_to_floor(target_floor: int, direction: String) -> void:
	var scene = get_tree().current_scene
	var player = get_tree().get_first_node_in_group("player")
	var cam = player.get_node_or_null("Camera2D") if player != null else null
	if scene == null or player == null or cam == null:
		# Can't pan — fall back to the fade cut.
		_commit(target_floor)
		return

	panning = true
	player.is_cutscene = true  # freeze normal control during the pan

	# One-screen world offset (down = +Y, up = −Y), accounting for camera zoom.
	var view_h = get_viewport().get_visible_rect().size.y / cam.zoom.y
	var floor_offset = view_h * (1.0 if direction == "down" else -1.0)

	# Passive backdrop of the target floor, one screen away.
	var backdrop = load("res://scenes/building_floors.tscn").instantiate()
	backdrop.setup_floor = target_floor
	backdrop.passive = true
	backdrop.position.y = floor_offset
	scene.add_child(backdrop)

	# A standalone camera takes over from the player's and pans across.
	var pan_cam = Camera2D.new()
	pan_cam.zoom = cam.zoom
	pan_cam.global_position = cam.get_screen_center_position()
	scene.add_child(pan_cam)
	pan_cam.make_current()

	var tw = create_tween().set_parallel(true)
	tw.tween_property(pan_cam, "global_position:y", pan_cam.global_position.y + floor_offset, PAN_TIME)
	# The player drifts toward the stairs as the view moves (placeholder for the
	# stair-walk animation).
	tw.tween_property(player, "global_position:y", player.global_position.y + floor_offset * 0.4, PAN_TIME)
	await tw.finished

	panning = false
	_commit(target_floor)


func _commit(target_floor: int) -> void:
	WorldState.current_floor = target_floor
	WorldState.on_floor_arrived(target_floor)
	HUD.update_floor_label()
	var path := "res://scenes/building_floors.tscn"
	if target_floor == 30:
		path = "res://scenes/hallway.tscn"
	elif target_floor <= 0:
		path = "res://scenes/lobby.tscn"
	get_tree().change_scene_to_file(path)
