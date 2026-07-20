extends CharacterBody2D

const SPEED = 40.0
const DETECTION_RANGE = 100.0
const ATTACK_RANGE = 30.0
const PUSH_FRICTION = 0.85
const HIT_DURATION = 2
const RECOVER_DURATION = 0.5
const KNOCKDOWN_DURATION = 3.0

var animated_sprite: AnimatedSprite2D
var player: Node2D = null
var state = "idle"
var state_timer = 0.0
var spawn_key: String = ""

var max_hp: int = 3
var current_hp: int = 3
var is_dead: bool = false
var passable_to_player: bool = false
# Gunfire (and future noise sources) override detection range while this runs.
var alert_timer: float = 0.0

# Off-screen presence: positional moans/shuffles the player can HEAR before
# seeing (docs/SOUND_STEALTH.md — this is why roaming listen isn't needed).
const MOAN_STREAMS = [
	preload("res://assets/audio/zombie/moan_1.wav"),
	preload("res://assets/audio/zombie/moan_2.wav"),
]
var moan_player: AudioStreamPlayer2D = null
var moan_timer: float = 0.0


func alert_to_noise(duration: float = 6.0) -> void:
	alert_timer = max(alert_timer, duration)

func _ready() -> void:
	animated_sprite = $AnimatedSprite2D
	animated_sprite.play("Idle")
	player = get_tree().get_first_node_in_group("player")
	add_to_group("zombie")
	_set_hp_from_floor()
	_register_zombie_exceptions()
	moan_player = AudioStreamPlayer2D.new()
	moan_player.name = "MoanPlayer"
	moan_player.volume_db = -6.0
	moan_player.max_distance = 650.0
	add_child(moan_player)
	moan_timer = randf_range(1.0, 6.0)

func _register_zombie_exceptions() -> void:
	# Swarm fix: zombies ignore collisions with each other (mutually), so a group
	# converges and overlaps instead of queueing behind the front one. No layer or
	# mask changes anywhere — walls, player, doors, stairs all untouched.
	for other in get_tree().get_nodes_in_group("zombie"):
		if other != self and other is PhysicsBody2D:
			add_collision_exception_with(other)
			other.add_collision_exception_with(self)

func _make_passable_to_player() -> void:
	# A staggered/knocked-down zombie stops blocking the player, so the push
	# mechanic lets you shove past. Uses collision exceptions, not layers.
	if player and not passable_to_player:
		add_collision_exception_with(player)
		player.add_collision_exception_with(self)
		passable_to_player = true

func _try_resolidify() -> void:
	# Restore solidity only once the player is clear, so the zombie never
	# re-solidifies while overlapping the player (which would jam both bodies).
	if not passable_to_player or player == null:
		return
	if global_position.distance_to(player.global_position) > 26.0:
		remove_collision_exception_with(player)
		player.remove_collision_exception_with(self)
		passable_to_player = false

func _set_hp_from_floor() -> void:
	var floor_num = WorldState.current_floor
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(str(WorldState.master_seed) + str(global_position) + str(floor_num))
	var base = lerp(7.0, 1.0, float(floor_num - 1) / 29.0)
	var variance = rng.randi() % 3 - 1
	max_hp = clamp(int(base) + variance, 1, 8)
	current_hp = max_hp

func receive_push(force: float) -> void:
	if state == "hit" or state == "recovering" or state == "knockdown" or is_dead:
		return
	velocity.x = clamp(force, -200.0, 200.0)
	state = "hit"
	state_timer = HIT_DURATION
	animated_sprite.play("Hit")
	_make_passable_to_player()

func receive_damage(amount: int, damage_type: String) -> void:
	if is_dead or state == "knockdown":
		return
	current_hp -= amount
	if current_hp <= 0:
		if damage_type == "blade":
			var rng = RandomNumberGenerator.new()
			rng.seed = hash(str(WorldState.master_seed) + str(global_position) + str(Time.get_ticks_msec()))
			if rng.randf() < 0.6:
				_die()
				return
			else:
				current_hp = 1
		else:
			_die()
			return
	if damage_type == "bludgeon":
		var rng = RandomNumberGenerator.new()
		rng.seed = hash(str(WorldState.master_seed) + str(global_position) + str(Time.get_ticks_msec()))
		if rng.randf() < 0.55:
			_knockdown()
			return
	animated_sprite.play("Hit")

func _knockdown() -> void:
	state = "knockdown"
	state_timer = KNOCKDOWN_DURATION
	velocity.x = 0
	animated_sprite.play("Hit")
	_make_passable_to_player()

func _die() -> void:
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
			"type": "standard"
		}
 
# Roll for loot drop — 18% chance, consumables only
	var loot_id = WorldState.roll_zombie_loot_id(global_position, WorldState.current_floor)
	if loot_id != "":
		var drop_scene = preload("res://scenes/world_drop.tscn")
		var drop = drop_scene.instantiate()
		drop.item_id = loot_id
		drop.drop_key = str(WorldState.current_floor) + ":" + str(snappedf(global_position.x, 1.0)) + ":" + str(snappedf(global_position.y, 1.0))
		drop.global_position = global_position
		get_parent().add_child(drop)
 
	await animated_sprite.animation_finished
	animated_sprite.pause()
	await get_tree().create_timer(300).timeout
	queue_free()

func receive_hit_from_gun(outcome: String) -> void:
	if is_dead:
		return
	match outcome:
		"headshot":
			_die()
		"body":
			receive_damage(2, "bullet")
		"miss":
			pass

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if alert_timer > 0:
		alert_timer -= delta

	moan_timer -= delta
	if moan_timer <= 0.0:
		moan_timer = randf_range(4.0, 10.0)
		moan_player.stream = MOAN_STREAMS.pick_random()
		moan_player.pitch_scale = randf_range(0.9, 1.15)
		moan_player.play()

	match state:
		"knockdown":
			velocity.x = 0
			state_timer -= delta
			if state_timer <= 0:
				var rng = RandomNumberGenerator.new()
				rng.seed = hash(str(WorldState.master_seed) + str(global_position) + str(Time.get_ticks_msec()))
				if rng.randf() < 0.6:
					state = "chase"
					animated_sprite.play("Walk")
				else:
					_die()
		"hit":
			velocity.x *= PUSH_FRICTION
			state_timer -= delta
			if state_timer <= 0:
				state = "recovering"
				state_timer = RECOVER_DURATION
				animated_sprite.play("Idle")
		"recovering":
			velocity.x = move_toward(velocity.x, 0, SPEED)
			state_timer -= delta
			if state_timer <= 0:
				state = "chase"
		"attack":
			velocity.x = 0
			state_timer -= delta
			if state_timer <= 0:
				var distance = global_position.distance_to(player.global_position)
				if distance <= ATTACK_RANGE:
					if player and player.has_method("receive_hit"):
						player.receive_hit()
				state = "chase"
				animated_sprite.play("Walk")
		"chase", "idle":
			_try_resolidify()
			if player == null:
				player = get_tree().get_first_node_in_group("player")
			if player != null:
				var distance = global_position.distance_to(player.global_position)
				var effective_detection = DETECTION_RANGE if alert_timer <= 0 else 2000.0
				if distance <= ATTACK_RANGE:
					state = "attack"
					state_timer = 0.8
					animated_sprite.play("Attack")
				elif distance <= effective_detection:
					state = "chase"
					var direction = sign(player.global_position.x - global_position.x)
					velocity.x = direction * SPEED
					animated_sprite.flip_h = direction < 0
					animated_sprite.play("Walk")
				else:
					state = "idle"
					velocity.x = 0
					animated_sprite.play("Idle")
	move_and_slide()
