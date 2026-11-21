extends "res://scripts/enemy_zombie_standard.gd"

# The Flyer (owner 2026-11-17: "a flying enemy that hovers, moves close, moves up and down making melee hard, but gunplay can take it down, otherwise the player needs
# to crouch under to pass, and run away"; then of the first drawing: "no legs, always airborne, seemingly random movements, violent, furry, fuzzy. When it approaches the
# player its maw opens up, screams, spins violently toward the player"). A ball of fur hanging at about head height that NEVER holds still.
#   - HOVER + TWITCH: it bobs (`HOVER_AMP`) and is kicked about by twitches (random impulses that decay), so its height and its sideways wobble are never the same twice.
#   - SURGES: its chase speed comes in bursts and stalls (SPEED is rewritten every frame), so it lurches at you rather than walks.
#   - THE DIVE: inside `DIVE_RANGE` it stops, its maw opens and it SCREAMS (`SCREAM_TIME`, a tell: sprint away or crouch), then it SPINS at you at `DIVE_SPEED` (the sprite whirls
#     `SPIN_RATE` rad/s) and bites where it lands. One dive per `DIVE_COOLDOWN`; a hit or a shove ends it.
#   - MELEE: a swing reaches it only on the low half of the bob (`can_be_meleed`, asked by player._do_melee_attack). A BULLET always lands.
#   - ITS BITE: a standing player is always in reach; a crouching (or rolling) one is bitten only while it is low (`CROUCH_STRIKE_H`).
#   - PASSING: solid to a standing player, passable to a crouching one — crouch (or roll) and go under.
# Same AI as every other kind (this extends the standard); the collision box stays ON the floor (every feet measurement reads it), the SPRITE is lifted and thrown about.

const HOVER_BASE := 44.0           # px of air under the body, level
const HOVER_AMP := 16.0            # the bob: ± this
const HOVER_RATE := 2.3            # rad / s
const TWITCH_KICK := 11.0          # px: how hard a twitch throws it
const MELEE_MAX_H := 50.0          # a swing reaches it only while it is this low or lower
const CROUCH_STRIKE_H := 38.0      # a crouching player is bitten only while it is this low or lower
const FALL_SPEED := 260.0          # px / s: it drops when it dies
const BASE_SPEED := 56.0
const DIVE_RANGE := 190.0          # the dive starts when the gap is inside this...
const SCREAM_TIME := 0.7           # ...it screams for this long (the tell)...
const DIVE_TIME := 0.55            # ...then spins at you for this long
const DIVE_SPEED := 340.0
const SPIN_RATE := 20.0            # rad / s
const DIVE_COOLDOWN := 3.4
const SCREAM_TINT := Color(1.0, 0.8, 0.86)

var _t := 0.0
var _h := HOVER_BASE               # the height drawn now
var _twitch := Vector2.ZERO        # the current kick (x, y px), decaying
var _twitch_cd := 0.4
var _sprite_p0 := Vector2.ZERO
var _phase := Vector2.ZERO         # this one's own phases, so a group does not move as one
var dive: String = ""              # "" | "scream" | "spin"
var _dive_t := 0.0
var _dive_cd := 1.2
var _dive_dir := 1.0


func _ready() -> void:
	super()
	SPEED = BASE_SPEED
	WALK_DESIGN_SPEED = BASE_SPEED          # its fur shivers faster in a surge, slower in a stall
	DETECTION_RANGE = 220.0
	ATTACK_RANGE = 34.0
	ATTACK_DAMAGE = 1
	max_hp = maxi(1, int(round(max_hp * 0.4)))
	current_hp = max_hp
	add_to_group("flyer")
	_phase = Vector2(randf() * TAU, randf() * TAU)
	_t = randf() * 10.0
	_sprite_p0 = animated_sprite.position
	_h = target_height()
	_apply_height()


## Where the bob is wanting the body to be right now (px above the floor); 0 once it is dead.
func target_height() -> float:
	if is_dead:
		return 0.0
	return HOVER_BASE + HOVER_AMP * sin(_t * HOVER_RATE + _phase.x) + 0.4 * _twitch.y


## The height the body is drawn at.
func height() -> float:
	return _h


## Asked by the player's swing: false = the swing goes under it (it is up in the high half of its bob).
func can_be_meleed() -> bool:
	return is_dead or _h <= MELEE_MAX_H


func _apply_height() -> void:
	if animated_sprite == null:
		return
	var wob_x: float = 4.0 * sin(_t * 7.3 + _phase.y) + 2.5 * sin(_t * 13.1) if not is_dead else 0.0
	animated_sprite.position = Vector2(_sprite_p0.x + wob_x + (_twitch.x if not is_dead else 0.0), _sprite_p0.y - _h)


func _physics_process(delta: float) -> void:
	if not is_dead:
		_t += delta
		_twitch_cd -= delta
		if _twitch_cd <= 0.0:                                   # a twitch: a random kick that dies away
			_twitch_cd = randf_range(0.25, 0.9)
			_twitch = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * TWITCH_KICK
		_twitch = _twitch.move_toward(Vector2.ZERO, 38.0 * delta)
		_dive_cd = maxf(0.0, _dive_cd - delta)
		if dive == "":                                          # it lurches: bursts and stalls (the dive sets its own speed)
			var surge: float = 0.5 + 0.5 * sin(_t * 3.1 + _phase.x) * sin(_t * 1.7 + _phase.y)
			SPEED = BASE_SPEED * (0.25 + 1.5 * surge * surge)
	else:
		_end_dive(false)
	_h = move_toward(_h, target_height(), (FALL_SPEED if is_dead else 150.0) * delta)
	super(delta)
	_apply_height()
	# crouch (or roll) and go under: a crouching player passes through its body (a standing one is stopped by it)
	if not is_dead and is_instance_valid(player) and player is PhysicsBody2D and player.get("is_crouching") == true:
		_make_passable_to_player()


## THE DIVE: scream (the tell), then spin at the player and bite where it lands.
func _ai_override(reach: float, distance: float, detection: float) -> bool:
	var dt := get_physics_process_delta_time()
	if is_dead or wall_mode_blocks() or hurt_timer > 0.0 or state == "hit" or state == "knockdown":
		_end_dive(false)
		return false
	match dive:
		"scream":
			_dive_t -= dt
			velocity.x = 0.0
			if _dive_t <= 0.0:
				dive = "spin"
				_dive_t = DIVE_TIME
				animated_sprite.modulate = Color.WHITE
			return true
		"spin":
			_dive_t -= dt
			velocity.x = _dive_dir * DIVE_SPEED
			animated_sprite.flip_h = _dive_dir < 0.0
			animated_sprite.rotation += _dive_dir * SPIN_RATE * dt
			var landed: bool = reach <= _attack_reach()
			if _dive_t <= 0.0 or landed:
				if landed:
					_deliver_attack(reach)                           # it bites where it lands
				_end_dive(true)
				state = "recovering"
				state_timer = 0.5
				velocity.x = 0.0
			return true
	if _dive_cd <= 0.0 and distance <= detection and reach < INF and reach <= DIVE_RANGE and reach > _attack_reach() + 4.0 and is_instance_valid(player):
		dive = "scream"
		_dive_t = SCREAM_TIME
		_dive_dir = signf(player.global_position.x - global_position.x)
		if _dive_dir == 0.0:
			_dive_dir = 1.0
		animated_sprite.flip_h = _dive_dir < 0.0
		animated_sprite.modulate = SCREAM_TINT
		animated_sprite.play("Attack")
		velocity.x = 0.0
		_scream()
		return true
	return false


func wall_mode_blocks() -> bool:
	return tutorial_scripted or stair_mode


func _scream() -> void:
	if moan_player != null:
		moan_player.stream = MOAN_STREAMS.pick_random()
		moan_player.pitch_scale = 0.55
		moan_player.volume_db = 4.0
		moan_player.play()


## Stop diving (a hit, a shove, the dive done, death). `cool` = start the cooldown.
func _end_dive(cool: bool) -> void:
	if dive == "" and not cool:
		if animated_sprite != null and animated_sprite.rotation != 0.0:
			animated_sprite.rotation = 0.0
		return
	if dive != "" and cool:
		_dive_cd = DIVE_COOLDOWN
	dive = ""
	if animated_sprite != null:
		animated_sprite.rotation = 0.0
		if not is_dead:
			animated_sprite.modulate = Color.WHITE
			animated_sprite.play("Walk")
	if moan_player != null:
		moan_player.volume_db = -2.0


func _deliver_attack(distance: float) -> void:
	if is_instance_valid(player) and player.get("is_crouching") == true and _h > CROUCH_STRIKE_H:
		return                      # it passes over a crouching player: the bite finds nothing
	super(distance)
