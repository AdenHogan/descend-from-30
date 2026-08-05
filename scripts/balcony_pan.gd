extends Node

# Autoload: seamless balcony descent (THREE_RUN_ARC balcony route), modeled on
# StairPan but vertical and simpler because room scenes are fixed screens:
#
#   * The apartment BELOW is built as a PASSIVE room.tscn backdrop (modules +
#     balcony art, no player/door/loot/enemies — see room.gd passive mode)
#     stacked EXACTLY one viewport-height under the live room, so 2501 really
#     sits above 2401 while the player descends between them.
#   * The room camera is a child of the Player, so moving the player pans the
#     view for free: over the rail, then a rope shimmy (or a fast fall) one
#     screen down, then a step off the lower balcony onto its corridor line —
#     which is precisely the framing room.tscn loads into for a "balcony"
#     spawn, so the commit (change_scene) is invisible.
#   * If anything is missing, callers fall back to the plain fade — a descent
#     must never soft-lock (same philosophy as StairPan.can_pan).

const ENABLED := true
const SCREEN_H := 648.0
const CORRIDOR_Y := 321.0      # the room walking line (room.tscn player Y)
const RAIL_Y := 285.0          # standing on the rail, about to go over
const PLANE_Y := 296.0         # the lower balcony's plane line
const RAIL_HOP_TIME := 0.45
const ROPE_TIME := 1.8         # shimmying down one floor on a rope
const JUMP_TIME := 0.65        # a fall is fast
const LAND_TIME := 0.3
const LEFT_WALL_X := 113.0
const MODULE_WIDTH := 320.0

var panning := false


func can_pan() -> bool:
	if not ENABLED or panning:
		return false
	var scene = get_tree().current_scene
	if scene == null or scene.scene_file_path != "res://scenes/room.tscn":
		return false
	return get_tree().get_first_node_in_group("player") != null


func pan_down(target_apartment: String, slot: int, roped: bool) -> void:
	# WorldState has ALREADY flipped to the target floor/apartment
	# (descend_from_balcony) — this is pure presentation; the commit reloads
	# room.tscn, whose "balcony" spawn matches the pan's final framing.
	panning = true
	var tree = get_tree()
	var scene = tree.current_scene
	var player = tree.get_first_node_in_group("player") as Node2D

	# The lower apartment, one screen down.
	var lower = load("res://scenes/room.tscn").instantiate()
	lower.passive = true
	lower.setup_apartment = target_apartment
	lower.position = Vector2(0, SCREEN_H)
	scene.add_child(lower)

	# Kill the grey void BETWEEN the two apartments: a balcony descent goes down
	# the BUILDING EXTERIOR, so fill it with a facade behind everything (z -20).
	# The apartments' own opaque backgrounds sit in front, so it only shows in
	# what used to be empty grey. (Full pixel-contiguous stacking + the behind-
	# the-wall shred are the remaining polish — see docs / StairPan SHRED_SHADER.)
	var facade := ColorRect.new()
	facade.color = Color(0.38, 0.37, 0.34)
	facade.position = Vector2(-120, -120)
	facade.size = Vector2(1320, SCREEN_H * 2 + 240)
	facade.z_index = -20
	scene.add_child(facade)

	var x := LEFT_WALL_X + slot * MODULE_WIDTH + 50.0   # the balcony column
	# The lashed line, hanging from the upper rail down to the balcony below.
	if roped:
		var rope := Line2D.new()
		rope.width = 2.0
		rope.default_color = Color(0.76, 0.64, 0.38)
		rope.add_point(Vector2(x + 6.0, RAIL_Y + 8.0))
		rope.add_point(Vector2(x + 6.0, SCREEN_H + PLANE_Y))
		rope.z_index = 0
		scene.add_child(rope)

	player.set("is_cutscene", true)

	# (1) Up and over the rail.
	var hop = scene.create_tween()
	hop.tween_property(player, "global_position", Vector2(x, RAIL_Y), RAIL_HOP_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await hop.finished
	if not is_instance_valid(player):
		panning = false
		return

	# (2) The drop — a controlled shimmy on the rope, or gravity when jumping.
	var slide = scene.create_tween()
	if roped:
		slide.tween_property(player, "global_position",
			Vector2(x, SCREEN_H + PLANE_Y), ROPE_TIME).set_trans(Tween.TRANS_LINEAR)
	else:
		slide.tween_property(player, "global_position",
			Vector2(x, SCREEN_H + PLANE_Y), JUMP_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await slide.finished
	if not is_instance_valid(player):
		panning = false
		return

	# (3) Step off the lower balcony onto its floor — the exact spot the fresh
	# room.tscn places a "balcony" arrival, so the swap can't be seen.
	var land = scene.create_tween()
	land.tween_property(player, "global_position",
		Vector2(x, SCREEN_H + CORRIDOR_Y), LAND_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await land.finished

	panning = false
	tree.change_scene_to_file("res://scenes/room.tscn")
