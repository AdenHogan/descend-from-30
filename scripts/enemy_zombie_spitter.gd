extends "res://scripts/enemy_zombie_standard.gd"

# The Spitter: hangs back and SPITS. Its ATTACK_RANGE is a long SPIT range, so the
# base AI halts and plays Attack from afar instead of closing to melee; _deliver_attack
# is overridden to launch a projectile toward the player rather than strike. Fires on a
# cooldown so the ~0.8s attack beat doesn't become a firehose (docs/THREE_RUN_ARC.md).

const SPIT := preload("res://scripts/spit_projectile.gd")
const SPIT_COOLDOWN := 1.6

var _spit_cd: float = 0.0

func _ready() -> void:
	super()
	SPEED = 30.0                 # slow — it doesn't need to reach you
	DETECTION_RANGE = 320.0
	ATTACK_RANGE = 300.0         # a SPIT range, NOT a melee reach
	current_hp = max_hp
	add_to_group("spitter")

func _physics_process(delta: float) -> void:
	if _spit_cd > 0.0:
		_spit_cd -= delta
	super(delta)

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
	proj.global_position = global_position + Vector2(dir * 22.0, -28.0)   # from the mouth
	get_parent().add_child(proj)
