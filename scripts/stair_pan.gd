extends Node

# Autoload: seamless stair transition. Instead of a hard cut between floors,
# load the ADJACENT floor as a passive backdrop one screen away, pan a
# standalone camera across as the player walks the stairs, then commit the real
# floor. Gives the sense of descending the building.
#
# ENABLED toggles it (this is THE switch). While it's on, mid-building stair
# trips pan; if anything's missing it falls back to the plain fade so a descent
# never soft-locks. Timing/feel is tunable via PAN_TIME + the player slide.

const ENABLED := true
const PAN_TIME := 1.05

var panning := false


func can_pan(target_floor: int) -> bool:
	if not ENABLED or panning:
		return false
	# Only descend/ascend between real floors (not into the lobby, not up past
	# the top). Both hallway (floor 30) and building_floors departures pan.
	if target_floor <= 0 or target_floor >= 30:
		return false
	var scene = get_tree().current_scene
	if scene == null:
		return false
	var p = scene.scene_file_path
	return p.contains("building_floors") or p.contains("hallway")


func pan_to_floor(target_floor: int, direction: String) -> void:
	var scene = get_tree().current_scene
	var player = get_tree().get_first_node_in_group("player")
	var cam = player.get_node_or_null("Camera2D") if player != null else null
	if scene == null or player == null or cam == null:
		_commit(target_floor)   # can't pan — plain cut, never soft-lock
		return

	panning = true
	player.is_cutscene = true   # freeze normal control during the pan

	# One screen of world height (down = +Y below, up = −Y above), accounting
	# for the camera zoom (floors are identical geometry, so one screen offset
	# lines the next floor up exactly).
	var view_h = get_viewport().get_visible_rect().size.y / cam.zoom.y
	var floor_offset = view_h * (1.0 if direction == "down" else -1.0)

	# The target floor as a passive backdrop, offset one screen away. It's
	# wrapped in a Node2D — building_floors' root is a plain Node with no
	# transform, so its CanvasItem children inherit the holder's offset.
	var holder = Node2D.new()
	holder.position = Vector2(0, floor_offset)
	scene.add_child(holder)
	var backdrop = load("res://scenes/building_floors.tscn").instantiate()
	backdrop.setup_floor = target_floor
	backdrop.passive = true
	holder.add_child(backdrop)

	# A standalone camera takes over and pans across both floors.
	var pan_cam = Camera2D.new()
	pan_cam.zoom = cam.zoom
	pan_cam.global_position = cam.get_screen_center_position()
	scene.add_child(pan_cam)
	pan_cam.make_current()

	var tw = create_tween().set_parallel(true)
	tw.tween_property(pan_cam, "global_position:y", pan_cam.global_position.y + floor_offset, PAN_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# The player drifts down/up the stairs as the view moves (placeholder for a
	# stair-walk animation).
	tw.tween_property(player, "global_position:y", player.global_position.y + floor_offset * 0.35, PAN_TIME)
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
