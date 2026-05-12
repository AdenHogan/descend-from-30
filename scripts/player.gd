extends CharacterBody2D

const SPEED = 150.0
const SPRINT_SPEED = 300.0
const CROUCH_SPEED = 60.0
const SCAVENGE_SPEED = 80.0
const PUSH_DURATION = 0.1
const PUSH_RANGE = 35.0
const PUSH_FORCE = 100.0
const MODE_SWITCH_TIME = 0.5

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

enum HealthState {HEALTHY, HURT, INJURED, WOUNDED, SEVERELY_WOUNDED, DYING}
var health_state: HealthState = HealthState.HEALTHY

var is_crouching = false
var is_pushing = false
var push_timer = 0.0
var is_hit = false
var hit_flash_timer = 0.0
const HIT_FLASH_DURATION = 0.5

var is_dying = false
var dying_timer = 0.0
const DYING_TIME = 15.0
var is_dead = false

var is_switching_mode = false
var mode_switch_timer = 0.0

func _ready() -> void:
	add_to_group("player")
	health_state = HealthState.values()[WorldState.player_health]
	is_dying = WorldState.is_dying
	dying_timer = WorldState.dying_timer
	HUD.update_portrait(health_state)
	HUD.update_mode_indicator()

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if is_dying:
		dying_timer -= delta
		WorldState.dying_timer = dying_timer
		if dying_timer <= 0:
			_die()
		var dying_direction = Input.get_axis("move_left", "move_right")
		velocity.x = dying_direction * CROUCH_SPEED * 0.5
		move_and_slide()
		return

	# Mode switch transition
	if is_switching_mode:
		mode_switch_timer -= delta
		velocity.x = 0
		move_and_slide()
		if mode_switch_timer <= 0:
			is_switching_mode = false
			WorldState.is_scavenge_mode = !WorldState.is_scavenge_mode
			animated_sprite.play("idle")
			HUD.update_mode_indicator()
			print("Mode switched to: ", "SCAVENGE" if WorldState.is_scavenge_mode else "COMBAT")
		return

	# F to toggle mode
	if Input.is_action_just_pressed("mode_toggle"):
		is_switching_mode = true
		mode_switch_timer = MODE_SWITCH_TIME
		animated_sprite.play("grab")
		return

	if Input.is_action_just_pressed("crouch_toggle"):
		is_crouching = !is_crouching

	var direction = Input.get_axis("move_left", "move_right")

	# Push only in combat mode
	if not WorldState.is_scavenge_mode:
		if Input.is_action_just_pressed("push") and not is_pushing:
			is_pushing = true
			push_timer = PUSH_DURATION
			animated_sprite.play("push")
			var zombies = get_tree().get_nodes_in_group("zombie")
			for zombie in zombies:
				var dist = global_position.distance_to(zombie.global_position)
				if dist <= PUSH_RANGE:
					var push_dir = sign(zombie.global_position.x - global_position.x)
					zombie.receive_push(push_dir * PUSH_FORCE)

	if is_pushing:
		push_timer -= delta
		if push_timer <= 0:
			is_pushing = false

	if is_hit:
		hit_flash_timer -= delta
		if hit_flash_timer <= 0:
			is_hit = false
			animated_sprite.modulate = Color(1, 1, 1, 1)

	if direction > 0:
		animated_sprite.flip_h = false
	elif direction < 0:
		animated_sprite.flip_h = true

	var current_speed = SPEED
	if WorldState.is_scavenge_mode:
		current_speed = SCAVENGE_SPEED
	elif Input.is_action_pressed("sprint") and not is_crouching:
		current_speed = SPRINT_SPEED
	elif is_crouching:
		current_speed = CROUCH_SPEED

	if is_crouching:
		if direction == 0:
			animated_sprite.play("crouch_idle")
		else:
			animated_sprite.play("crouch_walk")
	elif is_pushing:
		pass
	elif is_hit:
		pass
	else:
		if direction == 0:
			animated_sprite.play("idle")
		elif Input.is_action_pressed("sprint") and not WorldState.is_scavenge_mode:
			animated_sprite.play("run")
		else:
			animated_sprite.play("walk")

	if direction != 0:
		velocity.x = direction * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	move_and_slide()

func receive_hit() -> void:
	if is_dead or is_dying:
		return
	is_hit = true
	hit_flash_timer = HIT_FLASH_DURATION
	animated_sprite.modulate = Color(1, 0, 0, 1)
	animated_sprite.play("hurt")
	take_damage()

func take_damage() -> void:
	if health_state < HealthState.DYING:
		health_state = (health_state + 1) as HealthState
		WorldState.player_health = health_state
	if health_state == HealthState.DYING:
		is_dying = true
		WorldState.is_dying = true
		dying_timer = DYING_TIME
		WorldState.dying_timer = DYING_TIME
	_update_hud()

func _die() -> void:
	is_dead = true
	is_dying = false
	WorldState.is_dying = false
	WorldState.dying_timer = 0.0
	animated_sprite.play("death")
	print("Player died")

func _update_hud() -> void:
	HUD.update_portrait(health_state)
