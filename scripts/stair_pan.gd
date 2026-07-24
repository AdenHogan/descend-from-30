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
const PAN_TIME := 0.9        # the camera slide between floors
const WALK_TIME := 0.45      # player walks onto/down the stairs BEFORE the pan
const PLAYER_SLIDE := 0.30   # how far (fraction of a floor) the player drifts
# Nudge if the two floors don't quite line up (a 1-tile seam): + pushes the
# next floor further away, − brings it closer.
const SPACING_ADJUST := 0.0
var panning := false   # true only WHILE a pan runs; if it starts true, can_pan() never fires

func _ready() -> void:
	panning = false   # defensive: never boot with the guard stuck on


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

	var down = direction == "down"

	# The target floor as a passive backdrop, wrapped in a Node2D — building_
	# floors' root is a plain Node with no transform, so its CanvasItem children
	# inherit the holder's offset. Add it first so its tilemap exists to measure.
	var holder = Node2D.new()
	scene.add_child(holder)
	var backdrop = load("res://scenes/building_floors.tscn").instantiate()
	backdrop.setup_floor = target_floor
	backdrop.passive = true
	holder.add_child(backdrop)

	# The offset is the FLOOR's height (the tilemap), NOT one screen — that's
	# what makes the next floor sit directly above/below with no grey gap.
	var spacing = _floor_spacing(backdrop)
	if spacing <= 0.0:
		spacing = get_viewport().get_visible_rect().size.y / cam.zoom.y  # fallback
	spacing += SPACING_ADJUST
	var floor_offset = spacing * (1.0 if down else -1.0)
	holder.position = Vector2(0, floor_offset)

	# A standalone camera takes over and pans across both floors.
	var pan_cam = Camera2D.new()
	pan_cam.zoom = cam.zoom
	pan_cam.global_position = cam.get_screen_center_position()
	scene.add_child(pan_cam)
	pan_cam.make_current()

	# 1) Walk onto the stairs first (a short drift, no camera move — placeholder
	#    for the stair-walk animation).
	var walk = create_tween()
	walk.tween_property(player, "global_position:y",
		player.global_position.y + floor_offset * PLAYER_SLIDE * 0.5, WALK_TIME)
	await walk.finished

	# 2) Halfway down/up the stairs, pan the camera to the next floor while the
	#    player keeps drifting.
	var tw = create_tween().set_parallel(true)
	tw.tween_property(pan_cam, "global_position:y", pan_cam.global_position.y + floor_offset, PAN_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(player, "global_position:y",
		player.global_position.y + floor_offset * PLAYER_SLIDE * 0.5, PAN_TIME)
	await tw.finished

	panning = false
	_commit(target_floor)


func _floor_spacing(bf: Node) -> float:
	# One floor's world height, from its tilemap — the vertical distance between
	# equivalent points on adjacent (identical) floors.
	var tm = bf.get_node_or_null("TileMapLayer")
	if tm == null or tm.tile_set == null:
		return 0.0
	var cell_y: float = float(tm.tile_set.tile_size.y)
	return tm.get_used_rect().size.y * cell_y * tm.scale.y


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
