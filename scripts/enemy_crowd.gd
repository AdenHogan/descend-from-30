extends RefCounted

# CROWD SPACING (owner round 9: "five enemies… directly on top of each other… impossible to see how
# many are there"). Enemies deliberately never COLLIDE with each other (the old swarm fix — bodies
# jammed), so without this every chaser converged on the same x and a pack drew as one blob.
#
# Each enemy engaging the player takes a RANK on its side of the player: 0 = nearest. Rank k stands
# k × GAP further back than contact, so a pack fans out into distinct, individually targetable
# bodies — and ranks up to MAX_ATTACK_RANK still strike from their spot (their reach grows by the
# same k × GAP), so a crowd fights together rather than queueing single file. Deeper ranks hold,
# facing the player, and step up the moment a place opens. Ranks are recomputed every frame from
# live positions (ties broken by instance id), so there is nothing to get stuck on: kill, push or
# out-walk the front one and the rest re-rank at once.

const ENEMY_PLANE := preload("res://scripts/enemy_plane.gd")

const GAP := 13.0              # centre spacing between neighbours (world px, ~40% of a body)
const MAX_ATTACK_RANK := 3     # ranks 0..3 on each side may strike (four a side)
const MAX_STAND_RANK := 6      # deeper ranks share the last spot (keeps a huge pack on screen)
const ENGAGE_RANGE := 260.0    # only enemies this close to the player crowd each other
const PLANE_TOLERANCE := 48.0
const ENGAGED_STATES := ["chase", "attack", "hit", "recovering"]


static func engaged(o: Node) -> bool:
	if not is_instance_valid(o) or o.get("is_dead") == true:
		return false
	if o.get("stair_mode") == true or o.get("is_distracted") == true or o.get("tutorial_scripted") == true:
		return false
	return str(o.get("state")) in ENGAGED_STATES


static func rank(me: Node2D, player: Node2D) -> int:
	# My place on my side of the player (0 = nearest). -1 when I'm not in a crowd at all.
	if not is_instance_valid(player) or not ENEMY_PLANE.same_plane(me, player):
		return -1
	var my_dx := me.global_position.x - player.global_position.x
	var my_d := absf(my_dx)
	if my_d > ENGAGE_RANGE:
		return -1
	var side := 1.0 if my_dx >= 0.0 else -1.0
	var r := 0
	for o in me.get_tree().get_nodes_in_group("zombie"):
		if o == me or not (o is Node2D) or not engaged(o):
			continue
		if not ENEMY_PLANE.same_plane(o, player):
			continue
		if absf(o.global_position.y - me.global_position.y) > PLANE_TOLERANCE:
			continue
		var dx: float = o.global_position.x - player.global_position.x
		if (1.0 if dx >= 0.0 else -1.0) != side:
			continue
		var d := absf(dx)
		if d > ENGAGE_RANGE:
			continue
		if d < my_d - 0.5 or (absf(d - my_d) <= 0.5 and o.get_instance_id() < me.get_instance_id()):
			r += 1
	return r


static func reach_bonus(r: int) -> float:
	# Extra striking reach for a rank that may attack from its spot (0 for the front, none for the
	# held-back ranks).
	if r <= 0 or r > MAX_ATTACK_RANK:
		return 0.0
	return GAP * float(r)


static func stand_distance(r: int, attack_reach: float) -> float:
	# How far from the player (centre to centre, horizontally) rank r stands.
	return attack_reach + GAP * float(clampi(r, 0, MAX_STAND_RANK))
