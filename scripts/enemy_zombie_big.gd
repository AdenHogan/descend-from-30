extends CharacterBody2D

const SPEED = 25.0
const DETECTION_RANGE = 130.0
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


func _ready() -> void:
	animated_sprite = $AnimatedSprite2D
	animated_sprite.play("Idle")
	player = get_tree().get_first_node_in_group("player")
	add_to_group("zombie")
	add_to_group("big_zombie")
	_set_hp_from_floor()


func _set_hp_from_floor() -> void:
	var floor_num = WorldState.current_floor
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(str(WorldState.master_seed) + str(global_position) + str(floor_num))
	var base = lerp(15.0, 8.0, float(floor_num - 1) / 29.0)
	var variance = rng.randi() % 3 - 1
	max_hp = clamp(int(base) + variance, 6, 20)
	current_hp = max_hp


func receive_push(force: float) -> void:
	if is_dead:
		return
	var reduced_force = force * 0.4
	velocity.x = clamp(reduced_force, -80.0, 80.0)
	state_timer = max(state_timer, 0.3)


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
			"apartment_id": WorldState.current_apartment_id
		}

	if drops_key and key_target_apartment != "" and not key_dropped:
		key_dropped = true
		_drop_key()

	await animated_sprite.animation_finished
	animated_sprite.pause()
	await get_tree().create_timer(300).timeout
	queue_free()


func _drop_key() -> void:
	var added = WorldState.add_key_to_inventory(key_target_apartment)
	if added:
		HUD.show_feedback("Key — Apt " + key_target_apartment + " found!")
	else:
		# Inventory full — spawn as world drop at corpse position
		WorldState.add_world_drop("022", global_position, WorldState.current_floor, {"target_apartment": key_target_apartment})
		HUD.show_feedback("Key dropped nearby — inventory full.")


func _physics_process(delta: float) -> void:
	if is_dead:
		return

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
						player.receive_hit()
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
					state_timer = 1.2
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
	
