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
# Where the descent begins: the player steps UP to the line where the stairs
# drop away (the owner's red line), this far above their standing spot. Small
# on purpose — they were rising far too high before pressing into the stairwell.
const STAIR_APPROACH := 10.0
# The dog-leg bend, measured above a floor's standing line. This is the single
# height that BOTH directions turn at: descending you emerge and turn here on
# the floor below, ascending you turn here on your own floor before vanishing.
# Halfway (96) was far too high; 48 put the emergence too low - this sits near
# the top of the visible yellow steps, matching the owner's red line.
const TURN_HEIGHT := 72.0
# Sprite extent above/below its origin, for sweeping the cut through the whole
# body when dissolving or rematerialising.
const SHRED_TOP := 52.0
const SHRED_BOTTOM := 40.0
# How far BELOW the destination's standing line the player starts when arriving
# on an upper floor. They climb this last stretch in full view, rising out of
# the stairwell — without it the arrival was one step long and read as being
# spawned from thin air.
const EMERGE_RISE := 64.0
# Where the cut sits relative to the player's origin. This must land on the
# YELLOW STEPS, not the floor below them — cutting at the true foot line made it
# look like the player was clipping through the floor rather than descending
# stairs that start higher up.
const SHRED_FOOT := 20.0
# THE SHREDDER. Clips away every pixel of the player sprite below cut_y (world
# space). Descending through the stair line feeds them through it - feet first,
# sliced in staggered stages - no z tricks, no painted boxes, no art rebuild.
const SHRED_SHADER := """
shader_type canvas_item;
uniform float cut_y = 999999.0;
// +1 discards BELOW the line (descending: sliced away feet first)
// -1 discards ABOVE the line (ascending: sliced away head first)
uniform float clip_dir = 1.0;
varying float world_y;
void vertex() {
	world_y = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).y;
}
void fragment() {
	if ((world_y - cut_y) * clip_dir > 0.0) {
		discard;
	}
}
"""
# NOTE: hiding via z_index is deliberately NOT used any more. It left the player
# visible behind the corridor and then popped them in FRONT of it once past the
# floor divider. Both directions now hide by CLIPPING every pixel (the shredder),
# which cannot do either. Actors stay at their normal z throughout.
# DEPTH. A stairwell recedes away from the camera, so the player should read as
# stepping INTO the scene rather than sliding across a flat plane. Same idea as
# player.APPROACH_DEPTH at doors, with two more cues stacked on: they shrink a
# little (further away) and dim a little (the stairwell is unlit). Applied to the
# SPRITE, never the body — scaling a CharacterBody2D would scale its collision.
const DEPTH_SCALE := 0.82    # size at the back of the stairwell (1.0 = no depth)
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

	# A real staircase is a DOG-LEG: flight, landing, flight - three
	# AXIS-ALIGNED legs, never a diagonal. The bend sits TURN_HEIGHT above the
	# LOWER of the two floors' standing lines: descending you turn mid-staircase
	# on the floor below, ascending you turn at the top of your own flight.
	var turn_x: float = targets["player_target"].x
	var start_y: float = player.global_position.y
	var dest_y: float = targets["player_target"].y
	var turn_y: float = maxf(start_y, dest_y) - TURN_HEIGHT

	var sprite: Node = player.get_node_or_null("AnimatedSprite2D")
	var base_scale := Vector2.ONE
	var base_mod := Color(1, 1, 1, 1)
	if sprite != null:
		base_scale = sprite.scale
		base_mod = sprite.modulate
	var base_z: int = player.z_index

	if down:
		await _descend(player, sprite, pan_cam, base_scale, floor_offset,
			turn_x, turn_y, dest_y)
	else:
		await _ascend(player, sprite, pan_cam, base_scale, floor_offset,
			turn_x, turn_y, dest_y, base_z)

	# Never leave the player shredded, shrunk, or hidden - the destination scene
	# builds a fresh player, but an aborted pan must not strand this one.
	if is_instance_valid(pan_cam):
		pan_cam.global_position.x = hold_x
	if is_instance_valid(player):
		player.z_index = base_z
	if sprite != null and is_instance_valid(sprite):
		sprite.scale = base_scale
		sprite.modulate = base_mod
		_clear_shred(sprite)

	_commit(target_floor)


func _descend(player: Node2D, sprite: Node, pan_cam: Camera2D, base_scale: Vector2,
		floor_offset: float, turn_x: float, turn_y: float, dest_y: float) -> void:
	# (1) Walk up to the LINE where the stairs begin to go down (the red line) -
	#     whole and visible, stepping into the dark mouth of the stairwell.
	var line_center: float = player.global_position.y - STAIR_APPROACH
	var approach := create_tween()
	approach.tween_property(player, "global_position:y", line_center, 0.3) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await approach.finished
	if not is_instance_valid(player) or not is_instance_valid(pan_cam):
		return

	# Camera covers the rest of the trip in one smooth move (it stayed put for
	# the approach - the player was still on this floor).
	var cross_est: float = maxf(_climb_time(absf(turn_x - player.global_position.x)), TURN_TIME)
	var total: float = _climb_time(absf(turn_y - player.global_position.y)) \
		+ cross_est + _climb_time(absf(dest_y - turn_y))
	var cam_tw := create_tween()
	cam_tw.tween_property(pan_cam, "global_position:y",
		pan_cam.global_position.y + floor_offset, total) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# (2) THE SHREDDER. The cut sits on the platform edge under their feet;
	#     dropping step by step feeds them through it - feet, legs, torso, head -
	#     until nothing is left above the line.
	_set_shred(sprite, line_center + SHRED_FOOT)
	if sprite != null:
		var shrink := create_tween()
		shrink.tween_property(sprite, "scale", base_scale * DEPTH_SCALE,
			_climb_time(absf(turn_y - player.global_position.y))) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	var flight1 := _stagger_y(player, player.global_position.y, turn_y)
	await flight1.finished
	if not is_instance_valid(player) or not is_instance_valid(pan_cam):
		return

	# (3) The landing turn, mid-staircase on the floor BELOW - and the shredder
	#     runs in reverse: the cut sweeps down through them as they cross, so
	#     they return to full form during the left/right move.
	# They must be seen WALKING into frame along the staircase, not simply
	# appearing there — that is what sells "came down the stairs and rounded the
	# bend". Linear, at walking pace, with the walk cycle actually playing.
	_play_walk(sprite, turn_x - player.global_position.x)
	var cross_time: float = maxf(_climb_time(absf(turn_x - player.global_position.x)), TURN_TIME)
	var leg2 := create_tween().set_parallel(true)
	leg2.tween_property(player, "global_position:x", turn_x, cross_time) \
		.set_trans(Tween.TRANS_LINEAR)
	if _shred_mat != null:
		leg2.tween_property(_shred_mat, "shader_parameter/cut_y",
			player.global_position.y + SHRED_FOOT + 90.0, cross_time)
	if sprite != null:
		leg2.tween_property(sprite, "scale", base_scale, cross_time) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await leg2.finished
	if not is_instance_valid(player):
		return
	if sprite != null and is_instance_valid(sprite):
		_clear_shred(sprite)

	# (4) The last visible steps down the lower flight to the arrival spot.
	_play_walk(sprite, 0.0)
	var flight2 := _stagger_y(player, player.global_position.y, dest_y)
	await flight2.finished
	_play_idle(sprite)


func _ascend(player: Node2D, sprite: Node, pan_cam: Camera2D, base_scale: Vector2,
		floor_offset: float, turn_x: float, turn_y: float, dest_y: float,
		base_z: int) -> void:
	# EXACT REVERSE OF THE DESCENT. Run the descent's beats backwards:
	#
	#   descend:  step to red line -> dissolve -> hidden -> turn -> walk down
	#   ascend:   walk up -> turn -> dissolve -> hidden -> step down from red line
	#
	# Crucially this uses the SHREDDER for hiding, never z_index. The z-flip was
	# leaving the player visible behind the corridor and then popping them in
	# front of it once past the floor divider; clipping every pixel cannot do
	# either, and it is what the descent already does.
	var stand_y: float = player.global_position.y
	var bend_y: float = stand_y - TURN_HEIGHT
	var reveal_y: float = dest_y + EMERGE_RISE   # below the new floor, in the stairwell

	var cross_est: float = maxf(_climb_time(absf(turn_x - player.global_position.x)), TURN_TIME)
	var total: float = _climb_time(absf(bend_y - stand_y)) + cross_est \
		+ _climb_time(absf(reveal_y - bend_y)) + _climb_time(EMERGE_RISE)
	var cam_tw := create_tween()
	cam_tw.tween_property(pan_cam, "global_position:y",
		pan_cam.global_position.y + floor_offset, total) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# (1) Walk UP the visible steps to the bend — the mirror of the descent's
	#     final visible walk down. Shrinking into the stairwell as they go.
	_play_walk(sprite, 0.0)
	if sprite != null:
		var shrink := create_tween()
		shrink.tween_property(sprite, "scale", base_scale * DEPTH_SCALE,
			_climb_time(absf(bend_y - stand_y))) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	var flight1 := _stagger_y(player, stand_y, bend_y)
	await flight1.finished
	if not is_instance_valid(player) or not is_instance_valid(pan_cam):
		return

	# (2) Turn left/right ON the stairs at the bend, dissolving as they go —
	#     the mirror of the descent's turn-and-rematerialise. clip_dir -1
	#     discards everything ABOVE the cut, so sweeping the cut DOWN through
	#     them eats the body head first.
	_play_walk(sprite, turn_x - player.global_position.x)
	_set_shred(sprite, player.global_position.y - SHRED_TOP, -1.0)
	var leg2 := create_tween().set_parallel(true)
	leg2.tween_property(player, "global_position:x", turn_x, cross_est) \
		.set_trans(Tween.TRANS_LINEAR)
	if _shred_mat != null:
		leg2.tween_property(_shred_mat, "shader_parameter/cut_y",
			player.global_position.y + SHRED_BOTTOM, cross_est)
	await leg2.finished
	if not is_instance_valid(player):
		return

	# (3) Fully clipped now (the cut sits below their feet, so every pixel is
	#     above it and discarded): the hidden climb up the second flight.
	var flight2 := _stagger_y(player, player.global_position.y, reveal_y)
	await flight2.finished
	if not is_instance_valid(player):
		return

	# (4) Rise INTO VIEW out of the stairwell on the new floor. The cut is
	#     parked at the stair line with clip_dir +1 (everything below it hidden),
	#     so climbing up through it reveals the player head first, over several
	#     steps. It then sweeps below their feet so nothing is clipped on
	#     arrival. Previously this was a single 10px step down from above, which
	#     read as materialising out of thin air.
	_set_shred(sprite, reveal_y - SHRED_TOP, 1.0)
	_play_walk(sprite, 0.0)
	if sprite != null and is_instance_valid(sprite):
		var rise := create_tween().set_parallel(true)
		rise.tween_property(_shred_mat, "shader_parameter/cut_y",
			dest_y + SHRED_BOTTOM + 8.0, _climb_time(EMERGE_RISE))
		rise.tween_property(sprite, "scale", base_scale, _climb_time(EMERGE_RISE)) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var flight3 := _stagger_y(player, reveal_y, dest_y)
	await flight3.finished
	_clear_shred(sprite)
	_play_idle(sprite)


func _play_walk(sprite: Node, dir: float) -> void:
	# The pan owns the body (is_cutscene), so the normal movement code is not
	# driving animation — play it explicitly, or the player slides/appears
	# without ever looking like they walked.
	if sprite == null or not is_instance_valid(sprite):
		return
	sprite.flip_h = dir < 0.0
	sprite.play("walk")


func _play_idle(sprite: Node) -> void:
	if sprite != null and is_instance_valid(sprite):
		sprite.play("idle")


var _shred_mat: ShaderMaterial = null
var _shred_saved: Material = null


func _set_shred(sprite: Node, cut_y: float, clip_dir: float = 1.0) -> void:
	if sprite == null:
		return
	if _shred_mat == null:
		var sh := Shader.new()
		sh.code = SHRED_SHADER
		_shred_mat = ShaderMaterial.new()
		_shred_mat.shader = sh
	_shred_saved = sprite.material
	_shred_mat.set_shader_parameter("cut_y", cut_y)
	_shred_mat.set_shader_parameter("clip_dir", clip_dir)
	sprite.material = _shred_mat


func _clear_shred(sprite: Node) -> void:
	if sprite != null and is_instance_valid(sprite) and sprite.material == _shred_mat:
		sprite.material = _shred_saved
	_shred_saved = null


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
