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
# THE POUNCE (enemy AI pass): slow as it is, a crawler that has closed to striking distance GATHERS —
# a half-second coil, flat to the floor, tinted — then LUNGES a short, fast burst at you and bites the
# instant it lands. The tell is the coil: sprint away, shove it, or hit it and the pounce is off; stand
# and let it come and a fast bite follows. One pounce per POUNCE_COOLDOWN, never while hurt, never from
# the wall (that's the drop).
# ---------------------------------------------------------------------------------------------
const POUNCE_MAX := 130.0        # starts when the gap (horizontal) is inside this...
const POUNCE_MIN := 62.0         # ...and outside this (closer than that it simply bites)
const POUNCE_WIND := 0.55        # the coil (the tell)
const POUNCE_TIME := 0.26        # the leap
const POUNCE_SPEED := 330.0
const POUNCE_COOLDOWN := 3.6
const POUNCE_BITE_WIND := 0.25   # the bite after a landed pounce comes quick (a normal bite winds up 0.8s)
const POUNCE_TINT := Color(1.0, 0.72, 0.68)

var pounce: String = ""          # "" | "wind" | "leap"
var _pounce_t := 0.0
var _pounce_cd := 1.0            # the first one isn't instant on sight
var _pounce_dir := 1.0


func _ai_override(reach: float, distance: float, detection: float) -> bool:
	var dt := get_physics_process_delta_time()
	if _pounce_cd > 0.0:
		_pounce_cd -= dt
	if wall_mode != "" or tutorial_scripted or stair_mode or is_dead:
		_end_pounce(false)
		return false
	match pounce:
		"wind":
			_pounce_t -= dt
			velocity.x = 0.0
			animated_sprite.play("Idle")
			if _pounce_t <= 0.0:
				pounce = "leap"
				_pounce_t = POUNCE_TIME
				animated_sprite.modulate = Color.WHITE
				animated_sprite.play("Walk")
			return true
		"leap":
			_pounce_t -= dt
			velocity.x = _pounce_dir * POUNCE_SPEED
			animated_sprite.flip_h = _pounce_dir < 0.0
			var landed: bool = reach <= _attack_reach()
			if _pounce_t <= 0.0 or landed:
				_end_pounce(true)
				if landed:
					state = "attack"                 # it bites the moment it lands
					state_timer = POUNCE_BITE_WIND
					_crowd_bonus = 0.0
					animated_sprite.play("Attack")
					velocity.x = 0.0
			return true
	# not pouncing: start one?
	if _pounce_cd <= 0.0 and hurt_timer <= 0.0 and distance <= detection \
			and reach < INF and reach <= POUNCE_MAX and reach > POUNCE_MIN:
		pounce = "wind"
		_pounce_t = POUNCE_WIND
		_pounce_dir = signf(player.global_position.x - global_position.x)
		if _pounce_dir == 0.0:
			_pounce_dir = 1.0
		animated_sprite.flip_h = _pounce_dir < 0.0
		animated_sprite.modulate = POUNCE_TINT
		velocity.x = 0.0
		state = "chase"
		return true
	return false


## Stop pouncing (a hit, a shove, the leap done, the wall). `cool` = start the cooldown.
func _end_pounce(cool: bool) -> void:
	if pounce == "" and not cool:
		return
	if pounce != "" and cool:
		_pounce_cd = POUNCE_COOLDOWN
	pounce = ""
	if animated_sprite != null and not is_dead:
		animated_sprite.modulate = Color.WHITE


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
	if pounce != "":
		_pounce_cd = POUNCE_COOLDOWN * 0.6
		_end_pounce(false)   # a hit breaks the pounce
	super(amount, damage_type)


func receive_push(force: float) -> void:
	if is_on_wall_mode():
		_begin_drop()
	if pounce != "":
		_pounce_cd = POUNCE_COOLDOWN
		_end_pounce(false)   # a shove breaks it too
	super(force)


func be_distracted(pos: Vector2, duration: float = 6.0) -> void:
	if is_on_wall_mode():
		_begin_drop()
	_end_pounce(false)
	super(pos, duration)


func _die() -> void:
	_end_pounce(false)       # never leave a corpse tinted mid-coil
	super()


func _exit_tree() -> void:
	# Never remember it up the wall or mid-fall: it comes back standing on its floor line.
	if wall_mode != "":
		global_position.y = _wall_floor_y
	super()
