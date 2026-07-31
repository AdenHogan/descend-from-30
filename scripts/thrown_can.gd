extends RigidBody2D

# A thrown can of food (item 005) — a scavenge-mode distraction. Real physics:
# it arcs, spins, and BOUNCES off the world (walls + floor, collision layer 1),
# rolling to a stop and thudding on each impact so the player clearly hears it
# land somewhere. First landing emits a loud noise + a distraction that
# overrides all non-boss zombie aggro (docs/GAME_DESIGN_DOC — noise draws them).

# Arc: THROW_UP sets the HEIGHT of the arc (clear an enemy's head when thrown
# from a bit of a distance), THROW_SPEED the horizontal reach (~one apartment
# room). A higher arc takes longer to land, so raising THROW_UP without dropping
# THROW_SPEED also throws it further — these two are the tuning dials.
# THROW_SPEED, THROW_UP and GRAVITY are scaled together (v ×k, g ×k²) so the arc
# keeps the SAME shape and landing spot but plays out k× faster — a snappier
# throw. Here k = 1.2 over the original 190/500/1.0.
const THROW_SPEED = 228.0
const THROW_UP = 600.0
const GRAVITY_SCALE = 1.44
const SPIN = 14.0
# Once a landed can slows below this it freezes into a static prop so a zombie
# walking over it can't shove it around (see _physics_process).
const REST_SPEED = 12.0
# A can that hits an enemy IN FLIGHT (arc too low / too close) is a physical
# knock — it damages but never kills. On the FLOOR it never blocks: enemies are
# on a layer this can does not present to (collision_layer 128), so they walk
# straight through it, while it still bounces off walls, floor and — in flight —
# their bodies.
const HIT_DAMAGE = 1
const LAND_NOISE_RADIUS = 460.0
const DISTRACTION_RADIUS = 700.0
const THUD_MIN_SPEED = 55.0      # ignore tiny settling taps
const THUD_MIN_GAP = 0.10        # don't machine-gun thuds while rolling
const DESPAWN_AFTER_LAND = 6.0
# Classic "about to disappear" tell: the can blinks for the last FLASH_WINDOW
# seconds, faster as it runs out, then winks out.
const FLASH_WINDOW = 1.5

const THUD_STREAMS = [
	preload("res://assets/audio/impacts/impactWood_heavy_000.ogg"),
	preload("res://assets/audio/impacts/impactWood_heavy_001.ogg"),
	preload("res://assets/audio/impacts/impactWood_heavy_002.ogg"),
]

var has_landed: bool = false
var thud_timer: float = 0.0
var despawn_timer: float = -1.0
var thud_player: AudioStreamPlayer2D = null
var _hit: Dictionary = {}   # zombies already damaged this throw — never twice
var _frozen_at_rest: bool = false


func _ready() -> void:
	z_index = 1  # actor/foreground layer, in front of the wall backdrop
	gravity_scale = GRAVITY_SCALE
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
	# Rolled to a stop: pin it. Enemies never collide with the can's layer, but a
	# still-live RigidBody would get shoved on contact — freezing it (a static
	# prop) means a zombie walking over it just passes through, no push.
	if has_landed and not _frozen_at_rest and linear_velocity.length() < REST_SPEED:
		freeze = true
		_frozen_at_rest = true
	if despawn_timer > 0.0:
		despawn_timer -= delta
		if despawn_timer <= 0.0:
			queue_free()
		elif despawn_timer <= FLASH_WINDOW:
			# Blink on/off, the interval shrinking (0.22s -> 0.07s) as it runs
			# out — flash…flash…flash-flash-flash, then gone.
			var interval = lerpf(0.07, 0.22, clampf(despawn_timer / FLASH_WINDOW, 0.0, 1.0))
			visible = fmod(despawn_timer, interval * 2.0) < interval


func _on_body_entered(body: Node) -> void:
	# Hit an enemy in FLIGHT: a physical knock — bounce off them (that happens by
	# itself, they're on this can's collision_mask) and deal a little damage, once
	# each, never enough to kill. On the floor they just get bumped, no damage. It
	# is never a landing.
	if body != null and body.is_in_group("zombie"):
		if not has_landed and not _hit.has(body) and body.has_method("receive_damage"):
			_hit[body] = true
			# Never lethal: clamp so the hit always leaves at least 1 HP. A can is
			# a distraction, not a weapon — it softens an enemy, never finishes it.
			var dmg = mini(HIT_DAMAGE, maxi(0, body.current_hp - 1))
			if dmg > 0:
				body.receive_damage(dmg, "thrown")
		return
	# Every real world impact above a speed threshold thuds; the first is the
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
	# The distraction holds for the can's whole life (until it despawns), so
	# zombies stay fixated on it instead of reaggroing the moment they arrive.
	WorldState.emit_noise(global_position, LAND_NOISE_RADIUS, 3.0)
	WorldState.emit_distraction(global_position, DISTRACTION_RADIUS, DESPAWN_AFTER_LAND)
