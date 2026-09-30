extends "res://scripts/enemy_zombie_standard.gd"

# The Spitter: hangs back and SPITS. Its ATTACK_RANGE is a long SPIT range, so the
# base AI halts and plays Attack from afar instead of closing to melee; _deliver_attack
# is overridden to launch a projectile toward the player rather than strike. Fires on a
# cooldown so the ~0.8s attack beat doesn't become a firehose (docs/THREE_RUN_ARC.md).

const SPIT := preload("res://scripts/spit_projectile.gd")
const SPIT_COOLDOWN := 1.6

# KITING (docs/THREE_RUN_ARC.md "spitter kiting"): it holds its range. Close in under KITE_MIN and it
# backs away (facing you, a little quicker than its advance) until it has KITE_CLEAR of room again —
# unless it's cornered (a wall, the corridor's end), when it just stands and spits. Sprint at it and
# it gives ground; chase it into a corner and you've got it.
const KITE_MIN := 110.0          # closer than this (horizontal) and it backs off
const KITE_CLEAR := 160.0        # ...until it has this much room (hysteresis: no jitter at the edge)
const KITE_SPEED_MULT := 1.25
const KITE_LEFT_END := 165.0     # x: the left end's last walkable stretch (the walls stand at 128 / 1224)
const KITE_RIGHT_END := 1190.0

var _spit_cd: float = 0.0
var spit_damage: int = 1
var kiting: bool = false


# A BREACH-ROOM LEADER (owner rounds 20/21) — the gun cabinet's key carrier is always one: the
# leader's double HP + key, and its spit hits twice as hard. Called after it's in the tree (its HP is
# set in _ready); a remembered one's HP is restored after this by apply_saved_zombie.
func make_breach_leader(key_target: String) -> void:
	super(key_target)
	spit_damage = WorldState.CABINET_KEY_DAMAGE_MULT
	if key_target.begins_with(WorldState.CABINET_KEY_PREFIX):
		add_to_group("cabinet_key_carrier")

func _ready() -> void:
	super()
	SPEED = 30.0                 # slow — it doesn't need to reach you
	DETECTION_RANGE = 320.0
	ATTACK_RANGE = 300.0         # a SPIT range, NOT a melee reach
	current_hp = max_hp
	add_to_group("spitter")
	_make_passable_to_player()   # a ranged skirmisher never physically WALLS the player

func _try_resolidify() -> void:
	# Never re-solidify against the player: the spitter halts at range and would otherwise
	# stand as an (unlit, at night INVISIBLE) solid wall you can't walk past — a soft-lock.
	# It stays a ranged threat you can walk through / around; the spit is the danger.
	_make_passable_to_player()

func _physics_process(delta: float) -> void:
	if _spit_cd > 0.0:
		_spit_cd -= delta
	super(delta)
	if state != "hit" and state != "knockdown":
		_make_passable_to_player()   # keep it non-blocking every frame

func _ai_override(reach: float, _distance: float, _detection: float) -> bool:
	if stair_mode or tutorial_scripted or is_dead:
		return false
	if kiting and reach >= KITE_CLEAR:
		kiting = false
	elif not kiting and reach < KITE_MIN:
		kiting = true
	if not kiting:
		return false
	var away: float = -signf(player.global_position.x - global_position.x)
	if away == 0.0:
		away = 1.0
	# no room behind it: a wall it just hit (rooms), or the corridor's end (x bounds, floors 1-29)
	var cornered: bool = is_on_wall() or (away < 0.0 and global_position.x < KITE_LEFT_END) \
		or (away > 0.0 and global_position.x > KITE_RIGHT_END)
	if cornered:
		kiting = false             # no room: stand and spit (the base attack choice follows)
		return false
	state = "chase"
	velocity.x = away * SPEED * KITE_SPEED_MULT
	animated_sprite.flip_h = away > 0.0   # backing away: it keeps FACING you
	animated_sprite.play("Walk")
	return true


func _deliver_attack(_distance: float) -> void:
	# The attack beat launches a spit at the player instead of a melee hit. Honour a
	# cooldown so it doesn't spit every 0.8s; an on-cooldown beat is just a feint.
	if _spit_cd > 0.0 or player == null or is_dead:
		return
	_spit_cd = SPIT_COOLDOWN
	var dir := signf(player.global_position.x - global_position.x)
	if dir == 0.0:
		dir = 1.0
	if animated_sprite != null:
		animated_sprite.flip_h = dir < 0
	var proj = SPIT.new()
	proj.launch(dir)
	proj.damage = spit_damage
	# Launch toward the PLAYER'S plane, not the spitter's high mouth: the player rig is much
	# shorter than the spitter, so a spit fired from mouth height (~28px up) flew clean OVER
	# the player and could never connect. Fly it level at the player's body so it actually hits.
	var launch_y: float = player.global_position.y - 8.0 if player != null else global_position.y
	proj.global_position = Vector2(global_position.x + dir * 22.0, launch_y)
	get_parent().add_child(proj)
