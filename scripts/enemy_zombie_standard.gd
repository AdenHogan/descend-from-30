extends CharacterBody2D

const SPEED = 40.0
const DETECTION_RANGE = 100.0
const ATTACK_RANGE = 30.0
const PUSH_FRICTION = 0.85
const HIT_DURATION = 2
const RECOVER_DURATION = 0.5
const KNOCKDOWN_DURATION = 3.0

# --- Tutorial (scripted 3003 zombie) --------------------------------------
# The first-run neighbour is hand-tuned, not RNG: it starts frozen at the back
# of the apartment, approaches SLOWLY once released, dies in exactly two golf-
# club swings, and stays staggered longer after the scripted push so the
# player gets real breathing room. See room.gd / docs/TUTORIAL.md.
const TUTORIAL_SPEED = 20.0
const TUTORIAL_HITS_TO_DIE = 2
const TUTORIAL_PUSH_FREEZE = 4.0
var tutorial_scripted: bool = false
var tutorial_frozen: bool = false   # idle until room.gd releases it
var tutorial_hits: int = 0
# Key drop (tutorial neighbour yields the 3002 key on death — matching the big
# zombie's drop pattern).
var drops_key: bool = false
var key_target_apartment: String = ""
var key_dropped: bool = false

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
# Thrown-can distraction: overrides chase; the zombie walks to the sound.
var is_distracted: bool = false
var distraction_target: Vector2 = Vector2.ZERO
# Chance a zombie loses interest (de-aggros) once it reaches the can.
const DISTRACTION_DEAGGRO_CHANCE = 0.5


func be_distracted(pos: Vector2) -> void:
	if is_dead or state in ["hit", "recovering", "knockdown"]:
		return
	is_distracted = true
	distraction_target = pos
	alert_timer = 0.0  # the can wins over prior gunfire/sight aggro
	state = "distracted"
	animated_sprite.play("Walk")

# Off-screen presence: positional moans/shuffles the player can HEAR before
# seeing (docs/SOUND_STEALTH.md — this is why roaming listen isn't needed).
const MOAN_STREAMS = [
	preload("res://assets/audio/zombie/moan_1.wav"),
	preload("res://assets/audio/zombie/moan_2.wav"),
	preload("res://assets/audio/zombie/moan_3.wav"),
	preload("res://assets/audio/zombie/moan_4.wav"),
]
var moan_player: AudioStreamPlayer2D = null
var moan_timer: float = 0.0
# Each zombie gets its own voice (pitch offset) so a crowd never choruses.
var voice_pitch: float = 1.0


func alert_to_noise(duration: float = 6.0) -> void:
	alert_timer = max(alert_timer, duration)

func _ready() -> void:
	# ACTOR LAYER: player + enemies render one z-layer above the corridor
	# backdrop (walls, static doors, the merchant's elevator doors, and any
	# future dynamic door art at z 0), so nothing on the wall ever clips over
	# a living body. Backdrop stays at z 0; actors at z 1.
	z_index = 1
	animated_sprite = $AnimatedSprite2D
	animated_sprite.play("Idle")
	player = get_tree().get_first_node_in_group("player")
	add_to_group("zombie")
	_set_hp_from_floor()
	_register_zombie_exceptions()
	moan_player = AudioStreamPlayer2D.new()
	moan_player.name = "MoanPlayer"
	moan_player.volume_db = -2.0
	moan_player.max_distance = 650.0
	add_child(moan_player)
	voice_pitch = randf_range(0.82, 1.22)
	moan_timer = randf_range(0.5, 9.0)

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

func tutorial_release() -> void:
	# room.gd releases the frozen neighbour into its slow approach.
	tutorial_frozen = false


func tutorial_stagger() -> void:
	# The scripted push freezes the neighbour longer than a normal shove, and
	# lets the player slip past it while it recovers.
	state = "recovering"
	state_timer = TUTORIAL_PUSH_FREEZE
	velocity.x = 0
	animated_sprite.play("Idle")
	_make_passable_to_player()


func receive_damage(amount: int, damage_type: String) -> void:
	if is_dead or state == "knockdown":
		return
	# Scripted combat: no luck. Exactly two golf-club hits put the neighbour
	# down, no knockdown/instakill rolls, whatever the weapon's raw damage.
	if tutorial_scripted:
		tutorial_hits += 1
		if tutorial_hits >= TUTORIAL_HITS_TO_DIE:
			_die()
		else:
			state = "hit"
			state_timer = HIT_DURATION
			animated_sprite.play("Hit")
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

	# Tutorial neighbour yields the 3002 key on death (its scripted reward);
	# it doesn't also roll the random consumable drop.
	if drops_key and key_target_apartment != "" and not key_dropped:
		key_dropped = true
		_drop_key()
		await animated_sprite.animation_finished
		animated_sprite.pause()
		await get_tree().create_timer(300).timeout
		queue_free()
		return

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

func _drop_key() -> void:
	var added = WorldState.add_key_to_inventory(key_target_apartment)
	if added:
		HUD.show_feedback("Key — Apt " + key_target_apartment + " found!")
	else:
		WorldState.add_world_drop("022", global_position, WorldState.current_floor, {"target_apartment": key_target_apartment})
		HUD.show_feedback("Key dropped nearby — inventory full.")


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
		moan_timer = randf_range(3.0, 14.0)
		moan_player.stream = MOAN_STREAMS.pick_random()
		moan_player.pitch_scale = voice_pitch * randf_range(0.95, 1.05)
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
		"distracted":
			_try_resolidify()
			var to_can = distraction_target.x - global_position.x
			if abs(to_can) <= 20.0:
				# Reached the can — investigate, then some lose interest.
				is_distracted = false
				velocity.x = 0
				if randf() < DISTRACTION_DEAGGRO_CHANCE:
					state = "idle"
					animated_sprite.play("Idle")
				else:
					state = "chase"
					animated_sprite.play("Walk")
			else:
				var dir = signf(to_can)
				velocity.x = dir * SPEED
				animated_sprite.flip_h = dir < 0
				animated_sprite.play("Walk")
		"chase", "idle":
			_try_resolidify()
			# Scripted neighbour: stays put until room.gd releases it, then
			# closes in at a slow, telegraphed pace so the player can scavenge.
			if tutorial_scripted and tutorial_frozen:
				velocity.x = 0
				animated_sprite.play("Idle")
				move_and_slide()
				return
			if player == null:
				player = get_tree().get_first_node_in_group("player")
			if player != null:
				var move_speed = TUTORIAL_SPEED if tutorial_scripted else SPEED
				var distance = global_position.distance_to(player.global_position)
				var effective_detection = DETECTION_RANGE if alert_timer <= 0 else 2000.0
				if tutorial_scripted:
					effective_detection = 2000.0  # always aware once released
				if distance <= ATTACK_RANGE:
					state = "attack"
					state_timer = 0.8
					animated_sprite.play("Attack")
				elif distance <= effective_detection:
					state = "chase"
					var direction = sign(player.global_position.x - global_position.x)
					velocity.x = direction * move_speed
					animated_sprite.flip_h = direction < 0
					animated_sprite.play("Walk")
				else:
					state = "idle"
					velocity.x = 0
					animated_sprite.play("Idle")
	move_and_slide()
