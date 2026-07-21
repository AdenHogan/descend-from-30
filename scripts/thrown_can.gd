extends Node2D

# A thrown can of food (item 005) — a scavenge-mode distraction. Manual arc
# physics (deterministic on a flat corridor, no reliance on collision layers):
# it spins through the air, bounces a couple of times, then rolls to a stop.
# On the first landing it emits a loud noise + a distraction that overrides
# all non-boss zombie aggro (docs/GAME_DESIGN_DOC — noise draws enemies).

const GRAVITY = 900.0
const BOUNCE_DAMP = 0.42
const ROLL_FRICTION = 220.0
const SPIN_SPEED = 14.0
const LAND_NOISE_RADIUS = 460.0
const DISTRACTION_RADIUS = 700.0

var velocity: Vector2 = Vector2.ZERO
var floor_y: float = 0.0
var has_landed: bool = false
var settled: bool = false
var life_after_settle: float = 6.0

@onready var body: Polygon2D = $Body


func launch(dir: float, from: Vector2) -> void:
	global_position = from
	floor_y = from.y
	velocity = Vector2(dir * 330.0, -250.0)


func _process(delta: float) -> void:
	if settled:
		life_after_settle -= delta
		if life_after_settle <= 0.0:
			queue_free()
		return

	velocity.y += GRAVITY * delta
	global_position += velocity * delta
	body.rotation += SPIN_SPEED * delta * signf(velocity.x if abs(velocity.x) > 1.0 else 1.0)

	if global_position.y >= floor_y and velocity.y > 0.0:
		global_position.y = floor_y
		if not has_landed:
			has_landed = true
			_land()
		# Bounce, losing energy each time; below a threshold it rolls.
		if velocity.y > 60.0:
			velocity.y = -velocity.y * BOUNCE_DAMP
			velocity.x *= 0.7
		else:
			velocity.y = 0.0
			velocity.x = move_toward(velocity.x, 0.0, ROLL_FRICTION * delta)
			body.rotation += velocity.x * delta * 0.05
			if abs(velocity.x) < 4.0:
				settled = true
				velocity = Vector2.ZERO


func _land() -> void:
	WorldState.emit_noise(global_position, LAND_NOISE_RADIUS, 3.0)
	WorldState.emit_distraction(global_position, DISTRACTION_RADIUS)
