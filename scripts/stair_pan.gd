extends Node

# Autoload: seamless stair transition between two mid-building floors.
#
# The trick that removes BOTH the grey void and the hard cut:
#   * Every floor scene draws its floor at the SAME world coordinates, so a plain
#     change_scene() snaps the world back to origin — that snap IS the hard cut.
#   * We instead load the neighbour floor as a passive backdrop stacked EXACTLY
#     one floor-height away (contiguous, no gap → no grey between floors), then
#     move the player + a standalone camera RIGIDLY TOGETHER by one floor. The
#     player stays fixed on screen while the two stacked floors scroll past
#     (reads as descending/ascending).
#   * The pan ends on the precise framing the destination scene will load into,
#     so when we finally change_scene the first new frame is pixel-identical to
#     the last pan frame — the commit is invisible.
#
# ENABLED is THE switch. If anything is missing it falls back to a plain cut so a
# descent never soft-locks. Pace is tunable via STEP_TIME + STEP_HEIGHT (the
# camera's pan duration is derived from them, so it always matches the player).

const ENABLED := true
const TURN_TIME := 0.40      # crossing the landing between flights (horizontal leg)
# Stairs are climbed STEP BY STEP at walking pace, not glided. One step per tile
# of height, each taking STEP_TIME — so the climb's duration follows the distance
# instead of being squeezed into a fixed budget, and every step is the same size.
# Stand-in for the real stair animation; it reads as footfalls.
const STEP_HEIGHT := 16.0          # one tile per step
const STEP_TIME := 0.13            # seconds per step
const STEP_MOVE_FRACTION := 0.6    # of each step spent moving; the rest is the beat between
# How much of the first flight the player spends at normal z, sinking behind the
# StairPit* front layer step by step — this is what "sliced away bit by bit"
# looks like. Only AFTER that do they drop behind the scene entirely for the
# hidden turn. It is high on purpose: the pit does the hiding, gradually, rather
# than a z-flip blinking them out.
const VISIBLE_FLIGHT := 0.85
# How far the player walks up INTO the stairwell mouth before slipping behind the
# scene — same beat as player.approach_door before a door fade.
const STAIR_APPROACH := 14.0
# Behind the corridor art. Actors sit at z_index 1 and the backdrop at 0, so -1
# tucks the player BEHIND the floor and wall tiles: they leave the corridor
# inside the stairwell instead of sliding across the front of the scene.
# IMPORTANT: the corridor tilemap is solid across every column, so this hides the
# player COMPLETELY. It must only be applied once they are past the visible part
# of the flight — applying it on entry made the whole climb invisible.
const Z_BEHIND_SCENE := -1
# DEPTH. A stairwell recedes away from the camera, so the player should read as
# stepping INTO the scene rather than sliding across a flat plane. Same idea as
# player.APPROACH_DEPTH at doors, with two more cues stacked on: they shrink a
# little (further away) and dim a little (the stairwell is unlit). Applied to the
# SPRITE, never the body — scaling a CharacterBody2D would scale its collision.
const DEPTH_SCALE := 0.82    # size at the back of the stairwell (1.0 = no depth)
const DEPTH_DIM := 1.0       # no dimming: fading read as a ghost over the front
                             # of the scene. Depth comes from OCCLUSION + shrink.
# The legs derive from the floor height and the destination spawn, so there is
# nothing to hand-tune here: half a floor up, across the landing, half a floor
# more. StairFrontLeft/Right in building_floors.tscn are the FRONT LAYER of the
# stair art (the near half of the same PNG, drawn at z_index 2 above the player's
# z 1) — adjust their region_rect in the editor to control exactly how much of
# the stairwell hides the player.
# Nudge only if two floors don't quite meet (a 1-tile seam): + pushes the next
# floor further away, − brings it closer. Should stay 0 (floors are FLOOR_BAND_H
# tall and stack exactly).
const SPACING_ADJUST := 0.0

# building_floors spawn points (must match building_floors.gd) — where the player
# lands on the destination floor, and therefore the exact frame we pan toward.
const SPAWN_LEFT_TOP := Vector2(148, 391)
const SPAWN_LEFT_BOTTOM := Vector2(188, 391)
const SPAWN_RIGHT_TOP := Vector2(1201, 391)
const SPAWN_RIGHT_BOTTOM := Vector2(1162, 391)

var panning := false   # true only WHILE a pan runs; if it starts true, can_pan() never fires


func _ready() -> void:
	panning = false   # defensive: never boot with the guard stuck on


func can_pan(target_floor: int) -> bool:
	if not ENABLED or panning:
		return false
	# Only pan between real mid-building floors (1..29). The lobby (0) and the
	# hallway (30) are structurally different scenes → they keep the plain fade.
	if target_floor <= 0 or target_floor >= 30:
		return false
	var scene = get_tree().current_scene
	if scene == null:
		return false
	var p = scene.scene_file_path
	return p.contains("building_floors") or p.contains("hallway")


func dest_spawn(down: bool) -> Vector2:
	# Mirror building_floors.gd's stair-arrival spawn selection.
	if WorldState.stair_spawn_side == "left":
		return SPAWN_LEFT_BOTTOM if down else SPAWN_LEFT_TOP
	return SPAWN_RIGHT_BOTTOM if down else SPAWN_RIGHT_TOP


func pan_targets(spawn: Vector2, cam_offset: Vector2, floor_offset: float) -> Dictionary:
	# The destination scene will place the player at `spawn` with its camera at
	# `spawn + cam_offset`. During the pan the same floor lives one floor-offset
	# away (on the backdrop), so we drive player + camera to those points shifted
	# by the offset. Because both shift by the same delta, the player holds a
	# fixed screen position and the world scrolls; because the end framing equals
	# the destination framing (shifted), the change_scene is seamless.
	#
	# The stair spawn X differs between floors (left-down lands at x=188, not 148);
	# that difference becomes the HORIZONTAL leg of the dog-leg — the landing turn
	# — never a diagonal drift.
	var delta := Vector2(0, floor_offset)
	return {
		"player_target": spawn + delta,
		"cam_target": spawn + cam_offset + delta,
		"delta": delta,
	}


func pan_to_floor(target_floor: int, direction: String) -> void:
	var scene = get_tree().current_scene
	var player = get_tree().get_first_node_in_group("player")
	var cam = player.get_node_or_null("Camera2D") if player != null else null
	if scene == null or player == null or cam == null:
		_commit(target_floor)   # can't pan — plain cut, never soft-lock
		return

	panning = true
	player.is_cutscene = true   # freeze normal control during the pan

	var down := direction == "down"

	# The neighbour floor as a passive backdrop, wrapped in a Node2D — building_
	# floors' root is a plain Node with no transform, so its CanvasItem children
	# inherit the holder's offset. Add first so its tilemap exists to measure.
	var holder := Node2D.new()
	scene.add_child(holder)
	var backdrop = load("res://scenes/building_floors.tscn").instantiate()
	backdrop.setup_floor = target_floor
	backdrop.passive = true
	holder.add_child(backdrop)

	# Offset = ONE floor's height (the tilemap), so the neighbour sits directly
	# above/below with the two floors contiguous — no grey gap between them.
	var spacing := _floor_spacing(backdrop)
	if spacing <= 0.0:
		spacing = FLOOR_BAND_H   # fallback if the tilemap can't be measured
	spacing += SPACING_ADJUST
	var floor_offset := spacing * (1.0 if down else -1.0)
	holder.position = Vector2(0, floor_offset)

	# Standalone camera copies the live one exactly (same zoom!) and takes over.
	# It inherits the live camera's HORIZONTAL limits so the walls still stop the
	# view sideways, but its vertical limits are opened up — it has to travel a
	# whole floor, which the live camera's vertical clamp deliberately forbids.
	var cam_offset: Vector2 = cam.get_screen_center_position() - player.global_position
	var pan_cam := Camera2D.new()
	pan_cam.zoom = cam.zoom
	pan_cam.limit_left = cam.limit_left
	pan_cam.limit_right = cam.limit_right
	pan_cam.limit_top = -10000000
	pan_cam.limit_bottom = 10000000
	pan_cam.limit_smoothed = false
	pan_cam.global_position = player.global_position + cam_offset
	scene.add_child(pan_cam)
	pan_cam.make_current()

	var targets := pan_targets(dest_spawn(down), cam_offset, floor_offset)

	# The camera NEVER moves horizontally. At a stairwell it is already clamped
	# hard against the end wall, and the destination floor clamps it to the exact
	# same X (same wall, same limits, player arriving at the same stair spawn) —
	# so holding X still is what makes the commit invisible. Sliding it sideways
	# with the player is what made the arrival jump and exposed the cut.
	var hold_x: float = pan_cam.global_position.x

	# A real staircase is a DOG-LEG: one flight, a landing where you turn, then the
	# next flight. So the player's path is three AXIS-ALIGNED legs and never a
	# diagonal — vertical, horizontal, vertical:
	#
	#     26 -> 25 : down, right, down        25 -> 24 : down, left, down
	#     24 -> 25 : up,   right, up          (each trip is the reverse of its twin)
	#
	# The horizontal leg is simply "where I am now" -> "where this floor's stairs
	# put me", which is why the turn direction flips by side and by direction; it
	# needs no special-casing. The whole dog-leg happens behind the occluder.
	var turn_x: float = targets["player_target"].x
	var start_y: float = player.global_position.y
	var half: float = floor_offset * 0.5

	var sprite: Node = player.get_node_or_null("AnimatedSprite2D")
	var base_scale := Vector2.ONE
	var base_mod := Color(1, 1, 1, 1)
	if sprite != null:
		base_scale = sprite.scale
		base_mod = sprite.modulate
	var base_z: int = player.z_index

	# Beat 0 — APPROACH: walk up into the mouth of the stairwell, still in front
	#          of the scene, exactly like approach_door before a door fade. This
	#          is the "walk to the line" beat.
	var approach := create_tween()
	approach.tween_property(player, "global_position:y",
		player.global_position.y - STAIR_APPROACH, TURN_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await approach.finished
	if not is_instance_valid(player) or not is_instance_valid(pan_cam):
		_commit(target_floor)
		return

	start_y = player.global_position.y

	# Every vertical leg is stepped at a fixed pace, so the CAMERA's duration has
	# to follow the player rather than the other way round: one step per tile of
	# height across the whole floor, plus the landing.
	var total: float = _climb_time(absf(floor_offset)) + TURN_TIME
	var cam_tw := create_tween()
	cam_tw.tween_property(pan_cam, "global_position:y",
		pan_cam.global_position.y + floor_offset, total) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Leg 1a — VISIBLE: climbing the steps in full view, one step per tile, while
	#          receding into the stairwell (shrink + dim). This is the beat that
	#          sells the whole thing, so it must NOT be hidden — the corridor
	#          tilemap is solid, so going behind it here erased the climb entirely.
	var visible_end: float = start_y + half * VISIBLE_FLIGHT
	if sprite != null:
		var depth := create_tween().set_parallel(true)
		depth.tween_property(sprite, "scale", base_scale * DEPTH_SCALE,
			_climb_time(absf(visible_end - start_y))) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		depth.tween_property(sprite, "modulate",
			Color(base_mod.r * DEPTH_DIM, base_mod.g * DEPTH_DIM, base_mod.b * DEPTH_DIM, base_mod.a),
			_climb_time(absf(visible_end - start_y))) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	var leg1a := _stagger_y(player, start_y, visible_end)
	await leg1a.finished
	if not is_instance_valid(player) or not is_instance_valid(pan_cam):
		_commit(target_floor)
		return

	# Now they are leaving the corridor — only NOW go behind the scene, so the
	# rest of the trip happens out of sight rather than sliding over the tiles.
	player.z_index = Z_BEHIND_SCENE

	# Leg 1b — the rest of the first flight, hidden.
	var leg1b := _stagger_y(player, visible_end, start_y + half)
	await leg1b.finished
	if not is_instance_valid(player) or not is_instance_valid(pan_cam):
		_commit(target_floor)
		return

	# Leg 2 — HORIZONTAL: the landing. Turn and cross to the next flight.
	var leg2 := create_tween()
	leg2.tween_property(player, "global_position:x", turn_x, TURN_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await leg2.finished
	if not is_instance_valid(player) or not is_instance_valid(pan_cam):
		_commit(target_floor)
		return

	# Leg 3a — the second flight, still hidden, until they reach the point where
	#          the next floor's stairwell would reveal them.
	var reveal_y: float = targets["player_target"].y - half * VISIBLE_FLIGHT
	var leg3a := _stagger_y(player, player.global_position.y, reveal_y)
	await leg3a.finished
	if not is_instance_valid(player) or not is_instance_valid(pan_cam):
		_commit(target_floor)
		return

	# Leg 3b — VISIBLE: step out onto the new floor, coming back toward the camera
	#          as the depth cues unwind, landing exactly where the destination
	#          scene will place the player so the commit is invisible.
	player.z_index = base_z
	if sprite != null:
		var undepth := create_tween().set_parallel(true)
		undepth.tween_property(sprite, "scale", base_scale,
			_climb_time(absf(targets["player_target"].y - reveal_y))) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		undepth.tween_property(sprite, "modulate", base_mod,
			_climb_time(absf(targets["player_target"].y - reveal_y))) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var leg3b := _stagger_y(player, reveal_y, targets["player_target"].y)
	await leg3b.finished
	pan_cam.global_position.x = hold_x
	# Belt-and-braces: the destination scene builds a fresh player, but if this
	# one survives (aborted pan, future reuse) it must not stay shrunk, dim, or
	# stuck behind the scenery.
	if is_instance_valid(player):
		player.z_index = base_z
	if sprite != null and is_instance_valid(sprite):
		sprite.scale = base_scale
		sprite.modulate = base_mod

	_commit(target_floor)


func _climb_time(distance: float) -> float:
	# Walking pace: one step per tile of height. Duration follows distance, so a
	# taller floor simply takes longer rather than the steps getting faster.
	return maxf(_step_count(distance), 1) * STEP_TIME


func _step_count(distance: float) -> int:
	return maxi(int(round(absf(distance) / STEP_HEIGHT)), 1)


func _stagger_y(node: Node2D, from_y: float, to_y: float) -> Tween:
	# Climb in discrete steps instead of gliding: a short move, then a beat of
	# stillness, repeated — footfalls on stairs. A stand-in until the real stair
	# animation exists.
	var tw := create_tween()
	var steps := _step_count(to_y - from_y)
	var dy: float = (to_y - from_y) / float(steps)
	var move_t: float = STEP_TIME * STEP_MOVE_FRACTION
	var hold_t: float = STEP_TIME - move_t
	for i in range(steps):
		tw.tween_property(node, "global_position:y", from_y + dy * float(i + 1), move_t) \
			.set_trans(Tween.TRANS_LINEAR)
		if hold_t > 0.0:
			tw.tween_interval(hold_t)
	return tw


# --- floor geometry -------------------------------------------------------
# The corridor tilemap's TOP row is "junk": a handful of stray tiles (the yellow
# blocks) on an otherwise empty row, sitting above the real ceiling. Counting it
# made a floor measure taller than its solid content — that extra row was
# the dirty seam that showed between stacked floors. We strip those rows so a
# floor is exactly its solid content, then stack/frame against that.
const JUNK_ROW_FILL := 0.5   # a top row less than half-full is junk, not ceiling

# THE floor band, in world Y, shared by every corridor scene. building_floors'
# solid rows are 243..435 (12 tiles — the corridor was raised by two so the
# player has headroom to climb without clipping the ceiling); the hallway's tilemap is taller (243..483 — it carries
# blue filler above AND below the corridor), so deriving the band per-scene gave
# floor 30 a different zoom from floor 29 and showed that blue. Framing every
# corridor to this ONE band keeps the zoom identical across a stair trip and
# clips the filler.
const FLOOR_BAND_TOP := 243.0
const FLOOR_BAND_H := 192.0
# The HUD's opaque background starts at SCREEN_H - BAR_H - 40 (hud.gd), i.e. the
# bar is really 120px tall, not BAR_H's 80. Framing to 80 hid 40px of floor
# behind the inventory; this is the number that keeps the floor tight above it.
const HUD_BAR_H := 120.0


func strip_junk_rows(tm: TileMapLayer) -> int:
	# Erase sparse rows off the TOP of the tilemap. Returns how many were removed.
	if tm == null or tm.tile_set == null:
		return 0
	var removed := 0
	while true:
		var r := tm.get_used_rect()
		if r.size.y <= 1 or r.size.x <= 0:
			break
		var row: int = r.position.y
		var filled := 0
		for col in range(r.position.x, r.position.x + r.size.x):
			if tm.get_cell_source_id(Vector2i(col, row)) != -1:
				filled += 1
		if float(filled) / float(r.size.x) >= JUNK_ROW_FILL:
			break   # a properly solid row — that's the real ceiling, stop
		for col in range(r.position.x, r.position.x + r.size.x):
			tm.erase_cell(Vector2i(col, row))
		removed += 1
	return removed


func clean_bounds(tm: TileMapLayer) -> Rect2:
	# The floor's solid extent in WORLD space (after junk rows are stripped).
	if tm == null or tm.tile_set == null:
		return Rect2()
	var r := tm.get_used_rect()
	var cell := tm.tile_set.tile_size
	var origin := tm.global_position
	var pos := Vector2(
		origin.x + r.position.x * cell.x * tm.scale.x,
		origin.y + r.position.y * cell.y * tm.scale.y)
	var size := Vector2(
		r.size.x * cell.x * tm.scale.x,
		r.size.y * cell.y * tm.scale.y)
	return Rect2(pos, size)


func floor_band(tm: TileMapLayer) -> Rect2:
	# Horizontal extent from the scene's own tilemap (corridors differ in width),
	# vertical extent from the SHARED band so every floor frames identically.
	var b := clean_bounds(tm)
	return Rect2(Vector2(b.position.x, FLOOR_BAND_TOP), Vector2(b.size.x, FLOOR_BAND_H))


func apply_floor_camera(cam: Camera2D, bounds: Rect2, hud_bar_h: float = HUD_BAR_H) -> void:
	# Scene-locked camera (the playtest ask): instead of the view floating freely
	# around the player, it is CLAMPED to the floor's own bounds — so walking to
	# either stairwell pushes the camera up against the end wall and it stops,
	# while the player keeps moving freely into the corner. No grey beside the
	# walls, none above the ceiling, none below the floor.
	#
	# Vertically the floor is framed EXACTLY into the area above the HUD bar, so
	# the limit range equals the view height and the camera simply cannot drift
	# up or down — which is also what keeps the stair pan clean.
	if cam == null or bounds.size.y <= 0.0:
		return
	var view := Vector2(1152.0, 648.0)
	var vp := cam.get_viewport()
	if vp != null:
		var vr := vp.get_visible_rect().size
		if vr.x > 1.0 and vr.y > 1.0:
			view = vr
	var play_h: float = maxf(view.y - hud_bar_h, 1.0)
	var z: float = play_h / bounds.size.y          # floor fills the play area
	cam.zoom = Vector2(z, z)
	var world_view_h: float = view.y / z           # includes the slice behind the HUD
	cam.limit_left = int(floor(bounds.position.x))
	cam.limit_right = int(ceil(bounds.position.x + bounds.size.x))
	cam.limit_top = int(floor(bounds.position.y))
	cam.limit_bottom = int(ceil(bounds.position.y + world_view_h))
	cam.limit_smoothed = false


func _floor_spacing(bf: Node) -> float:
	# One floor's world height, from its tilemap — the vertical distance between
	# equivalent points on adjacent (identical) floors. Junk rows are excluded
	# (they're stripped on build), so this is the SOLID height: floors stacked at
	# this pitch meet flush with no seam.
	var tm = bf.get_node_or_null("TileMapLayer")
	if tm == null or tm.tile_set == null:
		return 0.0
	var cell_y: float = float(tm.tile_set.tile_size.y)
	return tm.get_used_rect().size.y * cell_y * tm.scale.y


func _commit(target_floor: int) -> void:
	panning = false
	WorldState.current_floor = target_floor
	WorldState.on_floor_arrived(target_floor)
	HUD.update_floor_label()
	var path := "res://scenes/building_floors.tscn"
	if target_floor == 30:
		path = "res://scenes/hallway.tscn"
	elif target_floor <= 0:
		path = "res://scenes/lobby.tscn"
	get_tree().change_scene_to_file(path)
