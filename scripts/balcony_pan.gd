extends Node

# Autoload: seamless balcony descent (THREE_RUN_ARC balcony route), modeled on
# StairPan but vertical between two apartments:
#
#   * The apartment BELOW is built as a PASSIVE room.tscn backdrop (modules +
#     balcony art, no player/door/loot/enemies — room.gd passive mode) and
#     placed exactly ONE FLOOR down (STACK_OFFSET), so 2501 sits DIRECTLY above
#     2401 with the two contiguous — no grey void between them.
#   * The room camera rides the Player, so moving the player pans the view: over
#     the rail, down the rope (shimmy) or a fast fall, and off the lower balcony
#     onto its corridor line — the exact frame the fresh room.tscn "balcony"
#     spawn loads into, so the commit (change_scene) is invisible.
#   * THE SHRED: while the player passes the wall BETWEEN the two balconies they
#     must go BEHIND the scene, not in front of it. A band-discard shader clips
#     every pixel of the sprite between the two red lines (SHRED_TOP world Y down
#     to SHRED_BOTTOM), so they vanish behind the building wall and re-emerge at
#     the balcony below. No z tricks (StairPan proved those pop wrong).
#   * If anything is missing, callers fall back to the plain fade — a descent
#     must never soft-lock.

const ENABLED := true
# ONE apartment down: the room's visible interior is 160px tall (tilemap y
# 207..367, measured), so the lower apartment sits DIRECTLY beneath the upper one
# with the two contiguous — no grey seam. Nudge if a hairline shows.
const STACK_OFFSET := 160.0
const PLANE_Y := 296.0         # the balcony plane (player stands here, out on it)
const RAIL_Y := 281.0          # the balcony's far rail — climb up onto it, then over
# THE RED LINES (world Y). The player is drawn IN FRONT above SHRED_TOP and below
# SHRED_BOTTOM, and BEHIND the scene (clipped) between them — so they slip behind
# the building wall on the way down. SHRED_TOP is the upper balcony floor (slice
# out); SHRED_BOTTOM the lower balcony floor (slice back in). The shred is armed
# AFTER the rail hop, so the player is never hidden while still on the balcony.
# Placed by eye — nudge against the art.
const SHRED_TOP := 272.0
# Re-emerge at the TOP of the lower balcony opening (its sky-top: module y 224 +
# art offset 18 + one floor down), so the player slides in from the top of the
# window rather than popping out low at the rail. Nudge against the art.
const SHRED_BOTTOM := STACK_OFFSET + 224.0 + 18.0   # = 402, the lower sky-top
const RAIL_HOP_TIME := 0.45
const ROPE_TIME := 1.6         # shimmying down one floor on a rope
const JUMP_TIME := 0.6         # a fall is fast
const LAND_TIME := 0.3
const LEFT_WALL_X := 113.0
const MODULE_WIDTH := 320.0
# The apartment interior band (matches room.gd ROOM_BAND_*): the live room locks
# the camera to this; the descent extends the bottom by one floor.
const ROOM_BAND_TOP := 207.0
const ROOM_BAND_H := 160.0

const SHRED_SHADER := """
shader_type canvas_item;
uniform float band_top = -999999.0;
uniform float band_bottom = 999999.0;
varying float wy;
void vertex() { wy = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).y; }
void fragment() { if (wy > band_top && wy < band_bottom) discard; }
"""

var panning := false

# PREFETCH: the lower apartment is built the instant the player steps ONTO the
# balcony (enter_balcony_plane), NOT when they commit to the drop — so the floor
# below is already visible under them "in motion" while they decide, and is
# torn down if they step back inside. pan_down reuses whatever prefetch built.
var _pref_lower: Node = null
var _pref_facade: ColorRect = null
var _pref_apartment := ""


func can_pan() -> bool:
	if not ENABLED or panning:
		return false
	var scene = get_tree().current_scene
	if scene == null or scene.scene_file_path != "res://scenes/room.tscn":
		return false
	return get_tree().get_first_node_in_group("player") != null


func _in_room() -> bool:
	var scene = get_tree().current_scene
	return scene != null and scene.scene_file_path == "res://scenes/room.tscn"


func prefetch(target_apartment: String, _slot: int) -> void:
	# Build (or re-use) the apartment ONE FLOOR down as a passive backdrop the
	# moment the player is out on the balcony, so the descent is already "in
	# motion" and the floor below is loaded before they commit — not popped in
	# on landing. Idempotent for the same target; called every plane refresh.
	if not ENABLED or target_apartment == "":
		return
	if _pref_apartment == target_apartment and is_instance_valid(_pref_lower):
		return
	clear_prefetch()
	if not _in_room():
		return
	var scene = get_tree().current_scene
	_pref_apartment = target_apartment

	# Fill any residual void with the building exterior, behind everything.
	_pref_facade = ColorRect.new()
	_pref_facade.color = Color(0.38, 0.37, 0.34)
	_pref_facade.position = Vector2(-120, -120)
	_pref_facade.size = Vector2(1320, STACK_OFFSET + 900)
	_pref_facade.z_index = -20
	scene.add_child(_pref_facade)

	# The lower apartment, ONE FLOOR down — directly beneath, contiguous.
	_pref_lower = load("res://scenes/room.tscn").instantiate()
	_pref_lower.passive = true
	_pref_lower.setup_apartment = target_apartment
	_pref_lower.position = Vector2(0, STACK_OFFSET)
	scene.add_child(_pref_lower)


func clear_prefetch() -> void:
	# The player stepped back inside without descending — deload the floor below.
	if is_instance_valid(_pref_lower):
		_pref_lower.queue_free()
	if is_instance_valid(_pref_facade):
		_pref_facade.queue_free()
	_pref_lower = null
	_pref_facade = null
	_pref_apartment = ""


func pan_down(target_apartment: String, slot: int, roped: bool) -> void:
	# WorldState has ALREADY flipped to the target floor/apartment
	# (descend_from_balcony) — this is pure presentation; the commit reloads
	# room.tscn, whose "balcony" spawn matches the pan's final framing.
	panning = true
	var tree = get_tree()
	var scene = tree.current_scene
	var player = tree.get_first_node_in_group("player") as Node2D
	var sprite = player.get_node_or_null("AnimatedSprite2D")

	# Re-use the backdrop prefetch already built when the player stepped onto the
	# balcony; only build now if the prefetch is missing (fell out of sync).
	if not (_pref_apartment == target_apartment and is_instance_valid(_pref_lower)):
		clear_prefetch()
		var lower = load("res://scenes/room.tscn").instantiate()
		lower.passive = true
		lower.setup_apartment = target_apartment
		lower.position = Vector2(0, STACK_OFFSET)
		scene.add_child(lower)

		var facade := ColorRect.new()
		facade.color = Color(0.38, 0.37, 0.34)
		facade.position = Vector2(-120, -120)
		facade.size = Vector2(1320, STACK_OFFSET + 900)
		facade.z_index = -20
		scene.add_child(facade)
	# The prefetch nodes belong to this scene and are freed with it on commit.
	_pref_lower = null
	_pref_facade = null
	_pref_apartment = ""

	var x := LEFT_WALL_X + slot * MODULE_WIDTH + 50.0

	# The lashed rope, from the upper rail down to the balcony below.
	if roped:
		var rope := Line2D.new()
		rope.width = 2.0
		rope.default_color = Color(0.76, 0.64, 0.38)
		rope.add_point(Vector2(x + 6.0, RAIL_Y))
		rope.add_point(Vector2(x + 6.0, STACK_OFFSET + PLANE_Y + 10.0))
		rope.z_index = -1   # the rope hangs on the wall, behind the player
		scene.add_child(rope)

	player.set("is_cutscene", true)

	# Open the camera for the descent: the live room locked it to the UPPER
	# apartment (room._frame_camera), which would clamp the view and leave the
	# player behind as they drop. Keep the horizontal wall limits (no grey beside
	# the apartment) and the upper ceiling as the top (no grey above), but extend
	# the bottom one whole floor so the camera rides the player down into the
	# lower apartment. The arrival scene re-locks to the lower apartment.
	var cam = player.get_node_or_null("Camera2D") as Camera2D
	if cam != null:
		var view_h: float = 648.0 / maxf(cam.zoom.y, 0.01)
		cam.limit_top = int(ROOM_BAND_TOP)
		cam.limit_bottom = int(ROOM_BAND_TOP + STACK_OFFSET + ROOM_BAND_H + view_h)
		cam.limit_smoothed = false

	# (1) Up and over the rail (still fully visible, in front).
	var hop = scene.create_tween()
	hop.tween_property(player, "global_position", Vector2(x, RAIL_Y), RAIL_HOP_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await hop.finished
	if not is_instance_valid(player):
		panning = false
		return

	# THE SHRED (armed now, over the rail): clip the sprite between the two red
	# lines so the descent goes BEHIND the wall and re-emerges at the balcony
	# below — never hidden while still standing on the balcony.
	if sprite != null:
		var mat := ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = SHRED_SHADER
		mat.shader = sh
		mat.set_shader_parameter("band_top", SHRED_TOP)
		mat.set_shader_parameter("band_bottom", SHRED_BOTTOM)
		sprite.material = mat

	# (2) The drop — a rope shimmy, or gravity when jumping — behind the wall.
	var slide = scene.create_tween()
	if roped:
		slide.tween_property(player, "global_position",
			Vector2(x, STACK_OFFSET + PLANE_Y), ROPE_TIME).set_trans(Tween.TRANS_LINEAR)
	else:
		slide.tween_property(player, "global_position",
			Vector2(x, STACK_OFFSET + PLANE_Y), JUMP_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await slide.finished
	if not is_instance_valid(player):
		panning = false
		return

	# (3) Land ON the lower balcony's plane (the slide already brought us here) and
	# settle the camera onto the lower apartment's locked framing — the exact
	# frame the fresh room re-locks to (room._frame_camera), so the held-frame
	# hand-off is seamless. The player stays out on the plane; the arrival scene
	# puts its player on the same plane (arrive_on_balcony_plane).
	if cam != null:
		var view_h: float = 648.0 / maxf(cam.zoom.y, 0.01)
		var lock_center: float = ROOM_BAND_TOP + STACK_OFFSET + view_h / 2.0
		var settle = scene.create_tween()
		settle.tween_property(cam, "position:y", lock_center - player.global_position.y, LAND_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await settle.finished
	await RenderingServer.frame_post_draw   # make sure the final pose is on screen

	# HOLD THE LAST FRAME across the scene swap. change_scene_to_file frees the
	# old scene and instantiates the new one on the next idle frame, and that gap
	# renders one blank (grey) frame — the "flash" on arrival. We snapshot the
	# final pan frame (the lower apartment, framed exactly as the fresh room will
	# re-lock it) and hold it over the swap, dropping it only once the new scene
	# has rendered its first framed frame. No fade, no cut — just no blank.
	var cover := _hold_last_frame(scene)
	panning = false
	tree.change_scene_to_file("res://scenes/room.tscn")
	if cover != null:
		# Let the new scene build (_ready frames + locks its camera) and paint a
		# frame, then reveal it.
		await tree.process_frame
		await tree.process_frame
		await RenderingServer.frame_post_draw
		cover.queue_free()


func _hold_last_frame(scene: Node) -> CanvasLayer:
	# Snapshot the current viewport into a top-most overlay parented to THIS
	# autoload, so it survives change_scene and masks the blank frame beneath it.
	var vp := scene.get_viewport()
	if vp == null:
		return null
	var img := vp.get_texture().get_image()
	if img == null:
		return null
	var layer := CanvasLayer.new()
	layer.layer = 128   # above the HUD and everything else
	var tr := TextureRect.new()
	tr.texture = ImageTexture.create_from_image(img)
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(tr)
	add_child(layer)
	return layer
