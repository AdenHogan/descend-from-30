extends CharacterBody2D

const SPEED = 25.0
const DETECTION_RANGE = 130.0
const DETECTION_VARIANCE = 45.0   # +/- band for per-zombie aggro variance
const SEPARATION_RADIUS = 14.0    # small: allow tight overlap, just avoid perfect stacking
const SEPARATION_STRENGTH = 12.0
const ATTACK_RANGE = 50.0
const PUSH_FRICTION = 0.70
const HIT_DURATION = 0.6
# No knockdown state — big zombie cannot be knocked down

var animated_sprite: AnimatedSprite2D
var player: Node2D = null
var state = "idle"
var state_timer = 0.0
var spawn_key: String = ""
var drops_key: bool = false
var key_target_apartment: String = ""
var key_dropped: bool = false  # Guard against double drops

var max_hp: int = 20
var current_hp: int = 20
var is_dead: bool = false
var detection_range: float = DETECTION_RANGE
# Gunfire (and future noise sources) override detection range while this runs.
var alert_timer: float = 0.0

# Deep-pitched moans — the big one sounds heavier and carries further.
const MOAN_STREAMS = [
	preload("res://assets/audio/zombie/moan_1.wav"),
	preload("res://assets/audio/zombie/moan_2.wav"),
	preload("res://assets/audio/zombie/moan_4.wav"),
]
var moan_player: AudioStreamPlayer2D = null
var moan_timer: float = 0.0


func alert_to_noise(duration: float = 6.0) -> void:
	alert_timer = max(alert_timer, duration)


func _ready() -> void:
	# ACTOR LAYER (z 1) — always in front of wall/door backdrop (z 0).
	z_index = 1
	animated_sprite = $AnimatedSprite2D
	animated_sprite.play("Idle")
	player = get_tree().get_first_node_in_group("player")
	add_to_group("zombie")
	add_to_group("big_zombie")
	_set_hp_from_floor()
	_register_zombie_exceptions()
	moan_player = AudioStreamPlayer2D.new()
	moan_player.name = "MoanPlayer"
	moan_player.volume_db = 0.0
	moan_player.max_distance = 800.0
	add_child(moan_player)
	moan_timer = randf_range(2.0, 7.0)


func _register_zombie_exceptions() -> void:
	# Swarm fix: zombies ignore collisions with each other (mutually), so a group
	# converges and overlaps instead of queueing behind the front one. No layer or
	# mask changes anywhere — walls, player, doors, stairs all untouched.
	for other in get_tree().get_nodes_in_group("zombie"):
		if other != self and other is PhysicsBody2D:
			add_collision_exception_with(other)
			other.add_collision_exception_with(self)


func _set_hp_from_floor() -> void:
	var floor_num = WorldState.current_floor
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(str(WorldState.master_seed) + str(global_position) + str(floor_num))
	var base = lerp(15.0, 8.0, float(floor_num - 1) / 29.0)
	var variance = rng.randi() % 3 - 1
	max_hp = clamp(int(base) + variance, 6, 20)
	current_hp = max_hp
	var aggro_roll = rng.randf() * 2.0 - 1.0
	detection_range = DETECTION_RANGE + aggro_roll * DETECTION_VARIANCE


func receive_push(_force: float) -> void:
	# The boss cannot be pushed — pushing should not work on the big zombie.
	return


func receive_damage(amount: int, damage_type: String) -> void:
	if is_dead:
		return
	var effective_amount = amount
	match damage_type:
		"bludgeon": effective_amount = max(1, amount - 1)
		"blade":    effective_amount = amount
		"bullet":   effective_amount = amount + 1
	current_hp -= effective_amount
	if current_hp <= 0:
		_die()
		return
	# Enter hit stagger state
	state = "hit"
	state_timer = HIT_DURATION
	animated_sprite.play("Hit")


func receive_hit_from_gun(outcome: String) -> void:
	if is_dead:
		return
	match outcome:
		"headshot": receive_damage(3, "bullet")
		"body":     receive_damage(2, "bullet")
		"miss":     pass


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	state = "dead"
	velocity.x = 0
	animated_sprite.play("Death")
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)

	if spawn_key != "" and not WorldState.killed_zombies.has(spawn_key):
		WorldState.killed_zombies[spawn_key] = {
			"x": snappedf(global_position.x, 1.0),
			"y": snappedf(global_position.y, 1.0),
			"floor": WorldState.current_floor,
			"scene": get_tree().current_scene.scene_file_path,
			"apartment_id": WorldState.current_apartment_id,
			"type": "big"
		}

	# Big Zombie ALWAYS drops a Bank Notes bundle (30-60).
	var money_amount = 30 + randi() % 31
	var money_pos = global_position + Vector2(24, 0)
	var money_key = str(WorldState.current_floor) + ":" + str(snappedf(money_pos.x, 1.0)) + ":" + str(snappedf(money_pos.y, 1.0))
	WorldState.add_world_drop("033", money_pos, WorldState.current_floor, {"amount": money_amount})
	var money_drop = preload("res://scenes/world_drop.tscn").instantiate()
	money_drop.item_id = "033"
	money_drop.amount = money_amount
	money_drop.drop_key = money_key
	money_drop.global_position = money_pos
	get_parent().add_child(money_drop)

	if drops_key and key_target_apartment != "" and not key_dropped:
		key_dropped = true
		_drop_key()

	await animated_sprite.animation_finished
	animated_sprite.pause()


func _drop_key() -> void:
	var added = WorldState.add_key_to_inventory(key_target_apartment)
	if added:
		HUD.show_feedback("Key — Apt " + key_target_apartment + " found!")
	else:
		# Inventory full — spawn as world drop at corpse position
		WorldState.add_world_drop("022", global_position, WorldState.current_floor, {"target_apartment": key_target_apartment})
		HUD.show_feedback("Key dropped nearby — inventory full.")


func _separation_nudge() -> float:
	var nudge := 0.0
	for other in get_tree().get_nodes_in_group("zombie"):
		if other == self or other.is_dead:
			continue
		var dx = global_position.x - other.global_position.x
		var ady = abs(global_position.y - other.global_position.y)
		if ady > SEPARATION_RADIUS:
			continue
		var adx = abs(dx)
		if adx < SEPARATION_RADIUS and adx > 0.01:
			var strength = (1.0 - adx / SEPARATION_RADIUS) * SEPARATION_STRENGTH
			nudge += sign(dx) * strength
	return clamp(nudge, -SEPARATION_STRENGTH, SEPARATION_STRENGTH)


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if alert_timer > 0:
		alert_timer -= delta

	moan_timer -= delta
	if moan_timer <= 0.0:
		moan_timer = randf_range(5.0, 12.0)
		moan_player.stream = MOAN_STREAMS.pick_random()
		moan_player.pitch_scale = randf_range(0.60, 0.72)
		moan_player.play()

	match state:
		"hit":
			velocity.x *= PUSH_FRICTION
			state_timer -= delta
			if state_timer <= 0:
				state = "chase"
				animated_sprite.play("Walk")
		"attack":
			velocity.x = 0
			state_timer -= delta
			if state_timer <= 0:
				var distance = global_position.distance_to(player.global_position)
				if distance <= ATTACK_RANGE:
					if player and player.has_method("receive_hit"):
						player.receive_hit(2)
				state = "chase"
				animated_sprite.play("Walk")
		"chase", "idle":
			if player == null:
				player = get_tree().get_first_node_in_group("player")
			if player != null:
				var distance = global_position.distance_to(player.global_position)
				var effective_detection = detection_range if alert_timer <= 0 else 2000.0
				if distance <= ATTACK_RANGE:
					state = "attack"
					state_timer = 1.2
					animated_sprite.flip_h = (player.global_position.x - global_position.x) < 0
					animated_sprite.play("Attack")
				elif distance <= effective_detection:
					state = "chase"
					var direction = sign(player.global_position.x - global_position.x)
					velocity.x = direction * SPEED + _separation_nudge()
					animated_sprite.flip_h = direction < 0
					animated_sprite.play("Walk")
				else:
					state = "idle"
					velocity.x = 0
					animated_sprite.play("Idle")
	move_and_slide()
