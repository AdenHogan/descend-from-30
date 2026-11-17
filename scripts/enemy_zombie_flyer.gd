extends "res://scripts/enemy_zombie_standard.gd"

# The Flyer (owner 2026-11-17: "a flying enemy that hovers, moves close, moves up and down making melee hard, but gunplay can take it down, otherwise the
# player needs to crouch under to pass, and run away"). It hangs in the air at about head height and BOBS: the whole body rises and sinks a hand's breadth
# every second or so.
#   - MELEE: a swing only reaches it on the low half of the bob (`can_be_meleed`, asked by player._do_melee_attack). On the high half the swing goes
#     under it: you have to time it, which is the point. A BULLET always lands.
#   - ITS BITE: a standing player is always in reach; a CROUCHING one is bitten only while it dives below CROUCH_STRIKE_H.
#   - PASSING: its body is solid to a standing player (it fills the corridor at head height) and passable to a crouching one — crouch and go under.
#   - It is fragile (40 % of a standard's health) and quick (SPEED 58, standard 40) and senses from a long way off.
# Same AI as every other kind (this extends the standard); only the height, the bite and the swing's reach are its own. The collision box stays ON the floor
# (everything measures feet from it); the SPRITE is lifted by `height()`.

const HOVER_BASE := 40.0           # px of air under the body, level
const HOVER_AMP := 16.0            # the bob: ± this
const HOVER_RATE := 2.3            # rad / s  (a bob about every 2.7 s)
const MELEE_MAX_H := 46.0          # a swing reaches it only while it is this low or lower
const CROUCH_STRIKE_H := 34.0      # a crouching player is bitten only while it is this low or lower
const FALL_SPEED := 260.0          # px / s: it drops when it dies

var _hover_t := 0.0
var _h := HOVER_BASE               # the height drawn now
var _sprite_y0 := 0.0


func _ready() -> void:
	super()
	SPEED = 58.0
	DETECTION_RANGE = 200.0
	ATTACK_RANGE = 34.0
	ATTACK_DAMAGE = 1
	max_hp = maxi(1, int(round(max_hp * 0.4)))
	current_hp = max_hp
	add_to_group("flyer")
	_hover_t = randf() * TAU
	_sprite_y0 = animated_sprite.position.y
	_h = target_height()
	_apply_height()


## Where the bob is wanting the body to be right now (px above the floor); 0 once it is dead.
func target_height() -> float:
	if is_dead:
		return 0.0
	return HOVER_BASE + HOVER_AMP * sin(_hover_t)


## The height the body is drawn at.
func height() -> float:
	return _h


## Asked by the player's swing: false = the swing goes under it (it is up in the high half of its bob).
func can_be_meleed() -> bool:
	return is_dead or _h <= MELEE_MAX_H


func _apply_height() -> void:
	if animated_sprite != null:
		animated_sprite.position.y = _sprite_y0 - _h


func _physics_process(delta: float) -> void:
	if not is_dead:
		_hover_t += delta * HOVER_RATE
	_h = move_toward(_h, target_height(), (FALL_SPEED if is_dead else 140.0) * delta)
	super(delta)
	_apply_height()
	# crouch and go under: a crouching player passes through its body (a standing one is stopped by it)
	if not is_dead and is_instance_valid(player) and player is PhysicsBody2D and player.get("is_crouching") == true:
		_make_passable_to_player()


func _deliver_attack(distance: float) -> void:
	if is_instance_valid(player) and player.get("is_crouching") == true and _h > CROUCH_STRIKE_H:
		return                      # it passes over a crouching player: the bite finds nothing
	super(distance)
