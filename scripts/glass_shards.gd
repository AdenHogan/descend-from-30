extends Node2D

# The shards of a smashed bottle: a burst of small glass slivers that fly out from the impact, fall under
# gravity, skitter once and then lie on the floor until the pile winks out. Pure visual — no collision, never
# blocks anything — so it can't become an obstacle. The floor is found by a ray straight down from the impact
# (world layer 1), falling back to a short drop if nothing is below.

const COUNT = 16
const GRAVITY = 900.0
const LIFETIME = 6.0
const FLASH_WINDOW = 1.5
const FALLBACK_DROP = 40.0
const TINTS = [Color(0.62, 0.86, 0.72, 0.92), Color(0.78, 0.94, 0.86, 0.95), Color(0.46, 0.72, 0.58, 0.92),
		Color(0.9, 0.98, 0.94, 0.98)]

var shards: Array = []        # {p, v, rot, spin, size, tint, rest}
var floor_y: float = 0.0
var age: float = 0.0
var all_rested: bool = false


func burst(dir: float = 1.0) -> void:
	floor_y = _find_floor_y()
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	shards.clear()
	for i in COUNT:
		var ang = rng.randf_range(-PI * 0.95, -PI * 0.05)            # an upward fan
		var spd = rng.randf_range(40.0, 170.0)
		shards.append({
			"p": Vector2(rng.randf_range(-3, 3), rng.randf_range(-4, 3)),
			"v": Vector2(cos(ang) * spd + dir * 25.0, sin(ang) * spd * 0.9),
			"rot": rng.randf() * TAU, "spin": rng.randf_range(-14.0, 14.0),
			"size": rng.randf_range(2.0, 4.4), "tint": TINTS[rng.randi() % TINTS.size()],
			"rest": false, "bounced": false})
	set_process(true)
	queue_redraw()


func _find_floor_y() -> float:
	var space = get_world_2d().direct_space_state if is_inside_tree() else null
	if space != null:
		var q = PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0, 240.0), 1)
		var hit = space.intersect_ray(q)
		if not hit.is_empty():
			return hit["position"].y - global_position.y
	return FALLBACK_DROP


func _process(delta: float) -> void:
	age += delta
	if age >= LIFETIME:
		queue_free()
		return
	if age >= LIFETIME - FLASH_WINDOW:
		var interval = lerpf(0.07, 0.22, clampf((LIFETIME - age) / FLASH_WINDOW, 0.0, 1.0))
		visible = fmod(LIFETIME - age, interval * 2.0) < interval
	if all_rested:
		return
	var moving = false
	for s in shards:
		if s["rest"]:
			continue
		s["v"].y += GRAVITY * delta
		s["p"] += s["v"] * delta
		s["rot"] += s["spin"] * delta
		if s["p"].y >= floor_y:
			s["p"].y = floor_y
			if not s["bounced"] and absf(s["v"].y) > 90.0:
				s["bounced"] = true                                   # one small skitter, then it lies still
				s["v"] = Vector2(s["v"].x * 0.5, -absf(s["v"].y) * 0.3)
			else:
				s["rest"] = true
				s["v"] = Vector2.ZERO
				s["spin"] = 0.0
		else:
			moving = true
		if not s["rest"]:
			moving = true
	all_rested = not moving
	queue_redraw()


func _draw() -> void:
	for s in shards:
		var sz: float = s["size"]
		var r: float = s["rot"]
		var a = s["p"] + Vector2(cos(r), sin(r)) * sz
		var b = s["p"] + Vector2(cos(r + 2.3), sin(r + 2.3)) * sz * 0.7
		var c = s["p"] + Vector2(cos(r + 4.0), sin(r + 4.0)) * sz * 0.5
		draw_colored_polygon(PackedVector2Array([a, b, c]), s["tint"])
		draw_line(a, b, Color(1, 1, 1, 0.7), 1.0)
