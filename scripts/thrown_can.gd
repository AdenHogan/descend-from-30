extends RigidBody2D

# A thrown can of food (item 005) — a scavenge-mode distraction. Real physics:
# it arcs, spins, and BOUNCES off the world (walls + floor, collision layer 1),
# rolling to a stop and thudding on each impact so the player clearly hears it
# land somewhere. First landing emits a loud noise + a distraction that
# overrides all non-boss zombie aggro (docs/GAME_DESIGN_DOC — noise draws them).

const THROW_SPEED = 300.0
const THROW_UP = 280.0
const SPIN = 12.0
const LAND_NOISE_RADIUS = 460.0
const DISTRACTION_RADIUS = 700.0
const THUD_MIN_SPEED = 55.0      # ignore tiny settling taps
const THUD_MIN_GAP = 0.10        # don't machine-gun thuds while rolling
const DESPAWN_AFTER_LAND = 6.0

const THUD_STREAMS = [
	preload("res://assets/audio/impacts/impactWood_heavy_000.ogg"),
	preload("res://assets/audio/impacts/impactWood_heavy_001.ogg"),
	preload("res://assets/audio/impacts/impactWood_heavy_002.ogg"),
]

var has_landed: bool = false
var thud_timer: float = 0.0
var despawn_timer: float = -1.0
var thud_player: AudioStreamPlayer2D = null


func _ready() -> void:
	z_index = 1  # actor/foreground layer, in front of the wall backdrop
	gravity_scale = 1.0
	body_entered.connect(_on_body_entered)
	thud_player = AudioStreamPlayer2D.new()
	thud_player.max_distance = 700.0
	add_child(thud_player)


func launch(dir: float, from: Vector2) -> void:
	global_position = from
	linear_velocity = Vector2(dir * THROW_SPEED, -THROW_UP)
	angular_velocity = dir * SPIN
	# Don't collide with the thrower on spawn.
	var player = get_tree().get_first_node_in_group("player")
	if player != null:
		add_collision_exception_with(player)


func _physics_process(delta: float) -> void:
	if thud_timer > 0.0:
		thud_timer -= delta
	if despawn_timer > 0.0:
		despawn_timer -= delta
		if despawn_timer <= 0.0:
			queue_free()


func _on_body_entered(_body: Node) -> void:
	# Every real impact above a speed threshold thuds; the first one is the
	# landing that pulls the horde.
	var impact = linear_velocity.length()
	if impact >= THUD_MIN_SPEED and thud_timer <= 0.0:
		thud_timer = THUD_MIN_GAP
		thud_player.stream = THUD_STREAMS.pick_random()
		thud_player.volume_db = clampf(-14.0 + impact / 40.0, -14.0, 0.0)
		thud_player.pitch_scale = randf_range(0.9, 1.1)
		thud_player.play()
	if not has_landed:
		has_landed = true
		despawn_timer = DESPAWN_AFTER_LAND
		_land()


func _land() -> void:
	WorldState.emit_noise(global_position, LAND_NOISE_RADIUS, 3.0)
	WorldState.emit_distraction(global_position, DISTRACTION_RADIUS)
