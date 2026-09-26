extends "res://scripts/enemy_zombie_standard.gd"

# The Crawler: low to the ground, SLOW, FRAGILE — but it HITS HARD. It drags itself
# along and drops in a hit or two, yet a bite from it does DOUBLE damage, so letting
# one reach you hurts. A push is a GENERAL push on it like every other enemy (real
# knockback); its collision box (scene) is TALLER than the sprite is low, so the shove
# connects even into the blank space above the body instead of whiffing on the floor.
# Stat/behaviour reskin of the standard AI; see docs/THREE_RUN_ARC.md enemy variety.

func _ready() -> void:
	super()
	SPEED = 26.0                 # SLOW — it crawls (standard is 40)
	DETECTION_RANGE = 130.0      # still senses you from a fair way and drags over
	ATTACK_RANGE = 30.0
	ATTACK_DAMAGE = 2            # DOUBLE damage per bite — the trade-off for being slow/weak
	max_hp = maxi(1, int(round(max_hp * 0.55)))   # fragile
	current_hp = max_hp
	add_to_group("crawler")


# ---------------------------------------------------------------------------------------------
# ON THE WALL (owner round 21 — "some crawlers climbing the walls when you enter and dropping down to
# attack"). A crawler in a breach-room NEST can start clinging to the back wall (body upright, head
# up or down) or the ceiling (upside down). Up there it is OFF the plane: no body collision, can't
# reach you, can't be reached by a swing. It creeps a little; when you come close — or it's hit,
# shoved, distracted or a loud noise goes off — it twitches and DROPS: falls under gravity, turning
# the right way up, lands on its floor line and comes for you. Never stuck: every one of those drops
# it, and it's remembered on the floor, never up the wall (_exit_tree).
# ---------------------------------------------------------------------------------------------
const WALL_BODY_OFFSET := Vector2(-5.5, -12.0)   # frame px: centres the drawn body (x 54..85, y 72..80) on the node
const WALL_DEPTH_SCALE := 0.85                   # on the back wall it's further away than the lane
const WALL_DROP_RANGE := 95.0                    # |dx| that sets it off (+ a seeded jitter)
const WALL_GRAVITY := 900.0
const WALL_LAND_STUN := 0.35

var wall_mode: String = ""          # "" | "wall" | "ceiling" | "drop"
var _wall_floor_y := 0.0
var _wall_trigger := 0.0            # >0 = counting down to the drop
var _wall_range := WALL_DROP_RANGE
var _wall_vy := 0.0
var _wall_rot0 := 0.0
var _wall_t := 0.0
var _wall_home_x := 0.0
var _wall_scale0 := Vector2.ONE


func start_on_wall(kind: String, floor_y: float, seed_text: String) -> void:
	if animated_sprite == null or is_dead:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_text)
	wall_mode = kind
	_wall_floor_y = floor_y
	_wall_home_x = global_position.x
	_wall_range = WALL_DROP_RANGE + rng.randf_range(-25.0, 35.0)
	_wall_t = rng.randf() * 10.0
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	z_index = 0                                           # on the wall: behind everything on the lane
	_wall_scale0 = animated_sprite.scale
	animated_sprite.scale = _wall_scale0 * WALL_DEPTH_SCALE
	animated_sprite.offset = WALL_BODY_OFFSET
	animated_sprite.flip_h = rng.randf() < 0.5
	if kind == "ceiling":
		animated_sprite.flip_v = true
		animated_sprite.rotation = 0.0
		global_position.y = floor_y - 70.0 - rng.randf_range(0.0, 6.0)
	else:
		var head_up := rng.randf() < 0.7
		var r := -PI / 2.0 if head_up else PI / 2.0
		animated_sprite.rotation = -r if animated_sprite.flip_h else r
		global_position.y = floor_y - 38.0 - rng.randf_range(0.0, 14.0)
	_wall_rot0 = animated_sprite.rotation
	animated_sprite.play("Walk")
	animated_sprite.speed_scale = 0.35
	velocity = Vector2.ZERO
	add_to_group("wall_crawler")


func is_on_wall_mode() -> bool:
	return wall_mode == "wall" or wall_mode == "ceiling"


func drop_from_wall(delay: float = 0.0) -> void:
	if not is_on_wall_mode():
		return
	if delay <= 0.0:
		_begin_drop()
	elif _wall_trigger <= 0.0:
		_wall_trigger = delay


func _begin_drop() -> void:
	_wall_trigger = 0.0
	wall_mode = "drop"
	_wall_vy = -40.0 if animated_sprite.flip_v else 0.0   # off the ceiling it kicks free first
	animated_sprite.flip_v = false
	animated_sprite.speed_scale = 1.0
	animated_sprite.play("Attack")
	if moan_player != null:
		moan_player.pitch_scale = voice_pitch * 1.35
		moan_player.play()


func _land() -> void:
	wall_mode = ""
	global_position.y = _wall_floor_y
	base_walk_y = _wall_floor_y
	animated_sprite.rotation = 0.0
	animated_sprite.offset = Vector2.ZERO
	animated_sprite.scale = _wall_scale0
	z_index = 1
	set_collision_layer_value(1, true)
	set_collision_mask_value(1, true)
	passable_to_player = false
	_make_passable_to_player()                 # solid again only once clear (never lodges you)
	remove_from_group("wall_crawler")
	state = "hit"                              # a beat to gather itself after the fall...
	state_timer = WALL_LAND_STUN
	alert_timer = maxf(alert_timer, 8.0)       # ...then it's coming for you
	animated_sprite.play("Hit")


func _wall_tick(delta: float) -> void:
	_wall_t += delta
	if wall_mode == "drop":
		_wall_vy += WALL_GRAVITY * delta
		global_position.y += _wall_vy * delta
		if is_instance_valid(player):
			global_position.x = move_toward(global_position.x, player.global_position.x, 40.0 * delta)
		animated_sprite.rotation = lerp_angle(animated_sprite.rotation, 0.0, minf(1.0, 10.0 * delta))
		animated_sprite.offset = animated_sprite.offset.lerp(Vector2.ZERO, minf(1.0, 10.0 * delta))
		if global_position.y >= _wall_floor_y:
			_land()
		return
	# creeping about up there
	global_position.x = _wall_home_x + sin(_wall_t * 0.4) * 6.0
	if _wall_trigger > 0.0:
		_wall_trigger -= delta
		animated_sprite.rotation = _wall_rot0 + sin(_wall_t * 40.0) * 0.05       # it twitches
		if _wall_trigger <= 0.0:
			_begin_drop()
		return
	if is_instance_valid(player) and absf(player.global_position.x - global_position.x) < _wall_range:
		drop_from_wall(0.15 + fposmod(_wall_t * 7.3, 0.45))
	elif alert_timer > 0.0:
		drop_from_wall(0.2)


func _physics_process(delta: float) -> void:
	if wall_mode != "" and not is_dead:
		_wall_tick(delta)
		return
	super(delta)


func receive_damage(amount: int, damage_type: String) -> void:
	if wall_mode != "":
		_land()              # hit up there / mid-fall: it's on the floor NOW (a kill never leaves it in the air)
	super(amount, damage_type)


func receive_push(force: float) -> void:
	if is_on_wall_mode():
		_begin_drop()
	super(force)


func be_distracted(pos: Vector2, duration: float = 6.0) -> void:
	if is_on_wall_mode():
		_begin_drop()
	super(pos, duration)


func _exit_tree() -> void:
	# Never remember it up the wall or mid-fall: it comes back standing on its floor line.
	if wall_mode != "":
		global_position.y = _wall_floor_y
	super()
