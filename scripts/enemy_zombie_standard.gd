extends CharacterBody2D

const SPEED = 40.0
const DETECTION_RANGE = 100.0
const DETECTION_VARIANCE = 45.0   # +/- band for per-zombie aggro variance
const SEPARATION_RADIUS = 10.0    # small: allow tight overlap, just avoid perfect stacking
const SEPARATION_STRENGTH = 14.0
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
var detection_range: float = DETECTION_RANGE

func _ready() -> void:
	animated_sprite = $AnimatedSprite2D
	animated_sprite.play("Idle")
	player = get_tree().get_first_node_in_group("player")
	add_to_group("zombie")
	_set_hp_from_floor()
	# Collision model: zombies live on layer 3 and mask layer 1 (walls + player).
	# They do NOT mask layer 3, so zombies pass through each other — letting a
	# group stand shoulder-to-shoulder and all reach the player, instead of the
	# front one walling the rest off. Push/attack use group lookups, not layers,
	# so they're unaffected.
	set_collision_layer_value(1, false)
	set_collision_layer_value(3, true)
	set_collision_mask_value(1, true)
	set_collision_mask_value(3, false)

func _set_hp_from_floor() -> void:
	var floor_num = WorldState.current_floor
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(str(WorldState.master_seed) + str(global_position) + str(floor_num))
	var base = lerp(7.0, 1.0, float(floor_num - 1) / 29.0)
	var variance = rng.randi() % 3 - 1
	max_hp = clamp(int(base) + variance, 1, 8)
	current_hp = max_hp
	# Per-zombie aggro variance — moderate spread so a group has a mix of zombies
	# that wake early and others that only notice the player up close. Seeded off
	# position so it's deterministic for a given spawn.
	var aggro_roll = rng.randf() * 2.0 - 1.0   # -1..1
	detection_range = DETECTION_RANGE + aggro_roll * DETECTION_VARIANCE

func receive_push(force: float) -> void:
	if state == "hit" or state == "recovering" or state == "knockdown" or is_dead:
		return
	velocity.x = clamp(force, -200.0, 200.0)
	state = "hit"
	state_timer = HIT_DURATION
	animated_sprite.play("Hit")
	set_collision_layer_value(3, false)
	set_collision_layer_value(2, true)

func receive_damage(amount: int, damage_type: String) -> void:
	if is_dead:
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
	set_collision_layer_value(3, false)
	set_collision_layer_value(2, true)

func _die() -> void:
	is_dead = true
	state = "dead"
	velocity.x = 0
	animated_sprite.play("Death")
	# Clear BOTH layers — a zombie pushed (layer 2) that then dies must not leave
	# a corpse lingering on layer 2.
	set_collision_layer_value(1, false)
	set_collision_layer_value(2, false)
	set_collision_layer_value(3, false)
	set_collision_mask_value(1, false)
	if spawn_key != "" and not WorldState.killed_zombies.has(spawn_key):
		WorldState.killed_zombies[spawn_key] = {
			"x": snappedf(global_position.x, 1.0),
			"y": snappedf(global_position.y, 1.0),
			"floor": WorldState.current_floor,
			"scene": get_tree().current_scene.scene_file_path,
			"apartment_id": WorldState.current_apartment_id
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
 
	# Play the death animation, then leave the corpse as a static frame. Corpse
	# persistence is handled by killed_zombies + _spawn_corpses on scene reload, so
	# we don't need a delayed queue_free (the old 300s timer outlived scene changes
	# and resumed on freed nodes).
	await animated_sprite.animation_finished
	animated_sprite.pause()

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

func _separation_nudge() -> float:
	# Sum a soft sideways push away from nearby living zombies so a group presses
	# in as a mass instead of single-filing. Purely additive to velocity — no
	# collision-layer changes, so push/death/world collision are untouched.
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

	match state:
		"knockdown":
			velocity.x = 0
			state_timer -= delta
			if state_timer <= 0:
				var rng = RandomNumberGenerator.new()
				rng.seed = hash(str(WorldState.master_seed) + str(global_position) + str(Time.get_ticks_msec()))
				if rng.randf() < 0.6:
					state = "chase"
					set_collision_layer_value(3, true)
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
				set_collision_layer_value(3, true)
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
						player.receive_hit(1)
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
					animated_sprite.flip_h = (player.global_position.x - global_position.x) < 0
					animated_sprite.play("Attack")
				elif distance <= detection_range:
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
