extends CharacterBody2D
const SPEED = 40.0
const DETECTION_RANGE = 100.0
const ATTACK_RANGE = 30.0
const PUSH_FRICTION = 0.85
const HIT_DURATION = 2
const RECOVER_DURATION = 0.5
var animated_sprite: AnimatedSprite2D
var player: Node2D = null
var state = "idle"
var state_timer = 0.0
func _ready() -> void:
	animated_sprite = $AnimatedSprite2D
	animated_sprite.play("Idle")
	player = get_tree().get_first_node_in_group("player")
	add_to_group("zombie")
func receive_push(force: float) -> void:
	if state == "hit" or state == "recovering":
		return
	velocity.x = clamp(force, -200.0, 200.0)
	state = "hit"
	state_timer = HIT_DURATION
	animated_sprite.play("Hit")
	set_collision_layer_value(1, false)
	set_collision_layer_value(2, true)
	set_collision_mask_value(1, false)
func _physics_process(delta: float) -> void:
	match state:
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
