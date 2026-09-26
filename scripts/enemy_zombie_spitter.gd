extends "res://scripts/enemy_zombie_standard.gd"

# The Spitter: hangs back and SPITS. Its ATTACK_RANGE is a long SPIT range, so the
# base AI halts and plays Attack from afar instead of closing to melee; _deliver_attack
# is overridden to launch a projectile toward the player rather than strike. Fires on a
# cooldown so the ~0.8s attack beat doesn't become a firehose (docs/THREE_RUN_ARC.md).

const SPIT := preload("res://scripts/spit_projectile.gd")
const SPIT_COOLDOWN := 1.6

var _spit_cd: float = 0.0
var spit_damage: int = 1


# THE GUN CABINET'S KEY (owner round 20): this spitter carries a cabinet's key in a breach room on
# the cabinet's floor — twice the HP, spits that hit twice as hard. Called after it's in the tree
# (its HP is set in _ready); a remembered one's HP is restored after this by apply_saved_zombie.
func make_cabinet_key_carrier(cabinet_apt: String) -> void:
	drops_key = true
	key_target_apartment = WorldState.CABINET_KEY_PREFIX + cabinet_apt
	max_hp *= WorldState.CABINET_KEY_HP_MULT
	current_hp = max_hp
	spit_damage = WorldState.CABINET_KEY_DAMAGE_MULT
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
