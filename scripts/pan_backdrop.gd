class_name PanBackdrop
extends RefCounted

# Shared plumbing for the floor-30 hallway and the lobby to act as a STAIR-PAN BACKDROP,
# the same way building_floors does (see StairPan): built passive (drawn, but no physics,
# no triggers, no AI) while it scrolls into view, then woken in place by go_live() once the
# player has walked onto it. building_floors keeps its own copy of this (older, and locked
# by its own tests); the two endpoint scenes share this one.


# Strip every collision body / trigger under `root` so a stacked neighbour floor can't
# block, teleport or pick input from the live floor. Returns what it changed, so
# restore() can put back EXACTLY what was there. Scenery zombies (group pan_scenery) keep
# processing so their idle animation plays as they scroll in (their AI is off separately).
static func make_inert(root: Node) -> Array:
	var dormant: Array = []
	_inert(root, dormant)
	return dormant


static func _inert(node: Node, dormant: Array) -> void:
	if node is CollisionObject2D:
		dormant.append({
			"node": node,
			"layer": node.collision_layer,
			"mask": node.collision_mask,
			"monitoring": node.monitoring if node is Area2D else false,
			"monitorable": node.monitorable if node is Area2D else false,
			"pickable": node.input_pickable,
			"process_mode": node.process_mode,
		})
		node.collision_layer = 0
		node.collision_mask = 0
		if node is Area2D:
			node.monitoring = false
			node.monitorable = false
		node.input_pickable = false
		if not node.is_in_group("pan_scenery"):
			node.process_mode = Node.PROCESS_MODE_DISABLED
	for child in node.get_children():
		_inert(child, dormant)


static func restore(dormant: Array) -> void:
	for e in dormant:
		var n = e["node"]
		if not is_instance_valid(n):
			continue
		n.collision_layer = e["layer"]
		n.collision_mask = e["mask"]
		if n is Area2D:
			n.monitoring = e["monitoring"]
			n.monitorable = e["monitorable"]
		n.input_pickable = e["pickable"]
		n.process_mode = e["process_mode"]
	dormant.clear()


# Turn this floor's frozen scenery zombies into live ones (collision already restored).
static func wake_scenery(root: Node) -> void:
	for z in root.get_tree().get_nodes_in_group("pan_scenery"):
		if root.is_ancestor_of(z):
			z.remove_from_group("pan_scenery")
			z.set_physics_process(true)


# A backdrop has no live player: drop the scene's own Player node NOW (out of the
# "player" group first, so nothing resolving the player this frame can grab the doomed one).
static func drop_scene_player(root: Node) -> void:
	var p = root.get_node_or_null("Player")
	if p == null:
		return
	p.remove_from_group("player")
	root.remove_child(p)
	p.queue_free()


# The shared corridor framing — identical on every floor, so a pan lands on the exact
# view the destination would load into.
static func frame_camera(root: Node, player: Node) -> void:
	if player == null:
		return
	var cam = player.get_node_or_null("Camera2D")
	var tm = root.get_node_or_null("TileMapLayer")
	if cam == null or tm == null:
		return
	StairPan.apply_floor_camera(cam, StairPan.floor_band(tm))
