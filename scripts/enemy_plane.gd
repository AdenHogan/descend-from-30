extends RefCounted

# THE BALCONY PLANE, for enemies (docs/THREE_RUN_ARC.md balcony route). An apartment's balcony is
# a second walkable line RISE px above the room floor (the player's own: player.enter_balcony_plane).
# Enemies live on one plane or the other:
#   * They only fight what shares their plane — a zombie on the room floor can't hit a player out on
#     the balcony (and the player can't hit it back) until it CLIMBS UP too. Different planes don't
#     collide either, so the balcony never walls anyone off.
#   * An aggro'd enemy walks to the balcony doorway and steps UP after a player out there; one on the
#     balcony steps DOWN after a player who went back inside.
#   * Idle ones sometimes wander up or down on their own, and some are seeded ALREADY out on the
#     balcony (WorldState.balcony_spawn_pick) — the player listens from the balcony above first.
# Shared by the standard family and the big zombie (static helpers over the enemy's own fields:
# on_balcony_plane, balcony_center_x, _plane_floor_y, _plane_climb, _plane_idle_t, _plane_scale0,
# _plane_pos0, plus state / alert_timer / player / animated_sprite / is_dead / _drop_feet_y()).
# Positions are LOCAL (the room root): a BalconyPan backdrop sits a floor down, and in a live room
# local == world.

# The balcony's geometry is shared with the player, the art and the descent (scripts/balcony_geo.gd).
const BalconyGeo = preload("res://scripts/balcony_geo.gd")
const RISE := BalconyGeo.RISE              # feet go from 353 to 319 in a room
const HALF_WIDTH := BalconyGeo.HALF_WIDTH  # how far either side of the centre an enemy may stand
const SCALE := BalconyGeo.SCALE            # drawn smaller: the balcony is further back
const CLIMB_SPEED := 80.0       # px/s: one step up/down takes ~0.4s
const IDLE_MIN := 5.0
const IDLE_MAX := 12.0
const IDLE_CHANCE := 0.3        # per idle check, the odds an idle enemy wanders up/down
const NO_CLIMB_STATES := ["hit", "knockdown", "recovering", "dead", "distracted"]


# The balcony centre(s) of the room this enemy is in (room.balcony_centers), [] anywhere else.
static func centers(e: Node) -> Array:
	var root = WorldState.owning_scene_root(e)
	if root == null:
		return []
	var c = root.get("balcony_centers")
	return c if c is Array else []


static func player_on_plane(p) -> bool:
	# A test/scene may put a plain node in the player group — anything without the field is "floor".
	if not is_instance_valid(p):
		return false
	var v = p.get("on_balcony_plane")
	return v is bool and v


# True when the enemy and the player stand on the SAME line (both on the room floor, or both out
# on the same balcony). A climb in progress counts as neither — nobody fights mid-step.
static func same_plane(e: Node, p) -> bool:
	if not is_instance_valid(p) or not is_instance_valid(e):
		return false
	var climb = e.get("_plane_climb")
	if climb != null and int(climb) != 0:
		return false
	var e_on := bool(e.get("on_balcony_plane")) if e.get("on_balcony_plane") != null else false
	if e_on != player_on_plane(p):
		return false
	if e_on and absf(float(e.get("balcony_center_x")) - float(p.get("balcony_center_x") if p.get("balcony_center_x") != null else 0.0)) > 1.0:
		return false
	return true


static func _feet_off(e: Node) -> float:
	return float(e._drop_feet_y()) - e.global_position.y


# Scale the sprite toward the balcony depth about the FEET, so the feet stay on the line as it shrinks.
static func _apply_depth(e: Node, frac: float) -> void:
	var spr = e.animated_sprite
	if spr == null or not is_instance_valid(spr):
		return
	if e._plane_scale0 == Vector2.ZERO:
		e._plane_scale0 = spr.scale
		e._plane_pos0 = spr.position
	var s := lerpf(1.0, SCALE, clampf(frac, 0.0, 1.0))
	spr.scale = e._plane_scale0 * s
	var feet := _feet_off(e)
	spr.position.y = e._plane_pos0.y + (feet - e._plane_pos0.y) * (1.0 - s)


static func _start(e: Node, dir: int, cx: float) -> void:
	if dir > 0:
		e._plane_floor_y = e.position.y
		e.balcony_center_x = cx
		e.position.x = clampf(e.position.x, cx - HALF_WIDTH, cx + HALF_WIDTH)
	e._plane_climb = dir
	e.velocity.x = 0.0
	if e.animated_sprite != null:
		e.animated_sprite.play("Walk")


# Put an enemy straight onto a balcony (a seeded spawn, or restored from memory). floor_y = the
# origin line it would stand on in the room below the balcony.
static func place(e: Node, cx: float, floor_y: float) -> void:
	e._plane_floor_y = floor_y
	e.balcony_center_x = cx
	e.on_balcony_plane = true
	e._plane_climb = 0
	e.position = Vector2(clampf(e.position.x, cx - HALF_WIDTH, cx + HALF_WIDTH), floor_y - RISE)
	_apply_depth(e, 1.0)


static func _idle_roll(e: Node, delta: float) -> bool:
	e._plane_idle_t -= delta
	if e._plane_idle_t > 0.0:
		return false
	e._plane_idle_t = randf_range(IDLE_MIN, IDLE_MAX)
	return randf() < IDLE_CHANCE


# Called every physics frame BEFORE the enemy's own AI. Returns true while a climb owns the frame
# (the caller skips its AI and movement). Otherwise decides whether to start a climb.
static func tick(e: Node, delta: float) -> bool:
	if e.is_dead:
		return false
	if int(e._plane_climb) != 0:
		var up: bool = int(e._plane_climb) > 0
		var target: float = float(e._plane_floor_y) - (RISE if up else 0.0)
		e.velocity = Vector2.ZERO
		e.position.y = move_toward(e.position.y, target, CLIMB_SPEED * delta)
		var on_frac: float = (float(e._plane_floor_y) - float(e.position.y)) / RISE
		_apply_depth(e, on_frac)
		if absf(e.position.y - target) < 0.01:
			e.position.y = target
			e._plane_climb = 0
			e.on_balcony_plane = up
			_apply_depth(e, 1.0 if up else 0.0)
		return true
	if e.state in NO_CLIMB_STATES:
		return false
	var p = e.player
	var aggro: bool = e.state in ["chase", "attack"] or float(e.alert_timer) > 0.0
	if not bool(e.on_balcony_plane):
		var cs := centers(e)
		if cs.is_empty():
			return false
		if aggro and player_on_plane(p):
			var cx := float(p.balcony_center_x)
			if absf(e.position.x - cx) <= HALF_WIDTH:
				_start(e, 1, cx)
				return true
			# Otherwise the ordinary chase walks it toward the player — i.e. to the doorway.
		elif not aggro and _idle_roll(e, delta):
			for c in cs:
				if absf(e.position.x - float(c)) <= HALF_WIDTH:
					_start(e, 1, float(c))
					return true
	else:
		if aggro and is_instance_valid(p) and not player_on_plane(p):
			_start(e, -1, float(e.balcony_center_x))
			return true
		if not aggro and _idle_roll(e, delta):
			_start(e, -1, float(e.balcony_center_x))
			return true
	return false


# After move_and_slide: keep a balcony enemy on its line, between the rails.
static func hold(e: Node) -> void:
	if not bool(e.on_balcony_plane) or int(e._plane_climb) != 0:
		return
	var cx := float(e.balcony_center_x)
	e.position = Vector2(clampf(e.position.x, cx - HALF_WIDTH, cx + HALF_WIDTH), float(e._plane_floor_y) - RISE)
