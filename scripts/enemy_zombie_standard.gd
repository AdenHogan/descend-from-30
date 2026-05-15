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

var max_hp: int = 3
var current_hp: int = 3
var is_dead: bool = false

func _ready() -> void:
	animated_sprite = $AnimatedSprite2D
	animated_sprite.play("Idle")
	player = get_tree().get_first_node_in_group("player")
	add_to_group("zombie")
	_set_hp_from_floor()

func _set_hp_from_floor() -> void:
	var floor_num = WorldState.current_floor
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(str(WorldState.master_seed) + str(global_position) + str(floor_num))
	# Lower floors = higher HP range
	# Floor 30 (top): 1-2 HP, Floor 1 (bottom): 4-7 HP, with variance throughout
	var base = lerp(7.0, 1.0, float(floor_num - 1) / 29.0)
	var variance = rng.randi() % 3 - 1  # -1, 0, or +1
	max_hp = clamp(int(base) + variance, 1, 8)
	current_hp = max_hp

func receive_push(force: float) -> void:
	if state == "hit" or state == "recovering" or state == "knockdown" or is_dead:
		return
	velocity.x = clamp(force, -200.0, 200.0)
	state = "hit"
	state_timer = HIT_DURATION
	animated_sprite.play("Hit")
	set_collision_layer_value(1, false)
	set_collision_layer_value(2, true)
	set_collision_mask_value(1, false)

func receive_damage(amount: int, damage_type: String) -> void:
	if is_dead or state == "knockdown":
		return
	current_hp -= amount
	if current_hp <= 0:
		# Bladed weapons have a chance to kill outright
		if damage_type == "blade":
			var rng = RandomNumberGenerator.new()
			rng.seed = hash(str(WorldState.master_seed) + str(global_position) + str(Time.get_ticks_msec()))
			if rng.randf() < 0.6:
				_die()
				return
			else:
				current_hp = 1  # survived but barely
		else:
			_die()
			return
	# Bludgeon has a chance to knock down even without killing
	if damage_type == "bludgeon":
		var rng = RandomNumberGenerator.new()
		rng.seed = hash(str(WorldState.master_seed) + str(global_position) + str(Time.get_ticks_msec()))
		if rng.randf() < 0.55:
			_knockdown()
			return
	# Standard hit reaction
	animated_sprite.play("Hit")

func _knockdown() -> void:
	state = "knockdown"
	state_timer = KNOCKDOWN_DURATION
	velocity.x = 0
	animated_sprite.play("Hit")  # placeholder until knockdown animation exists
	set_collision_layer_value(1, false)
	set_collision_layer_value(2, true)
	set_collision_mask_value(1, false)

func _die() -> void:
	is_dead = true
	state = "dead"
	velocity.x = 0
	animated_sprite.play("Death")  # death animation
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	# Remove after a short delay
	await get_tree().create_timer(1.5).timeout
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

	match state:
		"knockdown":
			velocity.x = 0
			state_timer -= delta
			if state_timer <= 0:
				# Chance to get back up
				var rng = RandomNumberGenerator.new()
				rng.seed = hash(str(WorldState.master_seed) + str(global_position) + str(Time.get_ticks_msec()))
				if rng.randf() < 0.6:
					state = "chase"
					set_collision_layer_value(1, true)
					set_collision_layer_value(2, false)
					set_collision_mask_value(1, true)
					animated_sprite.play("Walk")
				else:
					_die()
		"hit":
			velocity.x *= PUSH_FRICTION
			state_timer -= delta
			if state_timer <= 0:
				state = "recovering"
				state_timer = RECOVER_DURATION
				set_collision_layer_value(2, false)
				set_collision_layer_value(1, true)
				set_collision_mask_value(1, true)
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
			if player == null:
				player = get_tree().get_first_node_in_group("player")
			if player != null:
				var distance = global_position.distance_to(player.global_position)
				if distance <= ATTACK_RANGE:
					state = "attack"
					state_timer = 0.8
					animated_sprite.play("Attack")
				elif distance <= DETECTION_RANGE:
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
