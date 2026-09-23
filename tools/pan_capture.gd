extends Node

# DEV TOOL — renders REAL frames of a stair transition so a pan can be reviewed for seams,
# pops, filler and camera jumps without a playtest. Needs a rendering driver (not --headless):
#
#   xvfb-run -a godot --rendering-driver opengl3 res://tools/pan_capture.tscn -- \
#       --from=30 --dir=down --run=1 --out=/tmp/pan
#
# Writes <out>/f000.png … one frame every CAPTURE_EVERY frames from just before the stair is
# used until a beat after control returns, plus a contact sheet is easy to build from them.

const CAPTURE_EVERY := 4
const SETTLE_FRAMES := 20

var _out := "/tmp/pan"
var _from := 30
var _dir := "down"
var _run := 1
var _frame := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--from="):
			_from = int(a.substr(7))
		elif a.begins_with("--dir="):
			_dir = a.substr(6)
		elif a.begins_with("--run="):
			_run = int(a.substr(6))
		elif a.begins_with("--out="):
			_out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(_out)
	WorldState.new_game()
	WorldState.is_first_run = false        # no cold open / tutorial beats in a capture
	WorldState.opener_seen = true
	WorldState.current_run = _run
	WorldState.current_floor = _from
	WorldState.spawn_source = "stair"
	# Arrive the way a real descent would: on the stair you'd use next is irrelevant — we
	# teleport onto the trigger below.
	WorldState.stair_direction = "down"
	WorldState.stair_spawn_side = WorldState.canonical_stair_arrival_side(_from) if _from < 30 else "left"
	var path := "res://scenes/building_floors.tscn"
	if _from == 30:
		path = "res://scenes/hallway.tscn"
	elif _from == 0:
		path = "res://scenes/lobby.tscn"
	# This node IS the current scene, and change_scene frees the current scene — hand that
	# role to a throwaway node first so the capture survives the swap (and the pan's own).
	var stub := Node.new()
	get_tree().root.add_child.call_deferred(stub)
	await get_tree().process_frame
	get_tree().current_scene = stub
	get_tree().change_scene_to_file(path)
	for i in SETTLE_FRAMES:
		await get_tree().process_frame
	var trig := _find_trigger()
	if trig == null:
		push_error("pan_capture: no %s trigger on floor %d" % [_dir, _from])
		get_tree().quit(1)
		return
	var player = get_tree().get_first_node_in_group("player")
	player.global_position = Vector2(trig.global_position.x, 386.0)
	for i in 6:
		await _shot()
	trig._perform_transition()
	var guard := 0
	while StairPan.panning and guard < 2000:
		await _shot()
		guard += 1
	for i in 40:
		await _shot()
	print("pan_capture: wrote %d frames to %s (scene now %s)" % [_frame, _out, get_tree().current_scene.scene_file_path])
	get_tree().quit(0)


func _find_trigger() -> Node:
	for n in get_tree().current_scene.get_children():
		if n is Area2D and n.get("direction") == _dir and n.process_mode != Node.PROCESS_MODE_DISABLED \
				and n.has_method("_perform_transition"):
			return n
	return null


func _shot() -> void:
	await RenderingServer.frame_post_draw
	if _frame % CAPTURE_EVERY == 0:
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/f%03d.png" % [_out, _frame])
	_frame += 1
	await get_tree().process_frame
