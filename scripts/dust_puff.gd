extends Node2D

## A few pixels of dust, lint or paper rising from a node the moment its search begins (scripts/node_reaction.gd). Drawn in module pixels
## (1 art px = 1 unit, the camera scales it), so it matches the art; frees itself. Seeded by position so no two puffs are alike.

const LIFE := 0.9

var count := 6
var color := Color(0.62, 0.56, 0.48)
var spread := 7.0          # how far sideways the specks drift
var rise := 9.0            # how far up they get
var _t := 0.0
var _specks: Array = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(int(global_position.x * 13.0 + global_position.y * 7.0)) + int(Time.get_ticks_msec() % 997)
	for i in range(count):
		_specks.append({
			"x": rng.randf_range(-spread * 0.4, spread * 0.4), "dx": rng.randf_range(-spread, spread),
			"dy": rng.randf_range(rise * 0.4, rise), "d": rng.randf_range(0.0, 0.18), "big": rng.randf() < 0.35,
		})
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 1


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE + 0.2:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	for s in _specks:
		var k := clampf((_t - float(s["d"])) / LIFE, 0.0, 1.0)
		if k <= 0.0 or k >= 1.0:
			continue
		var ease_k := 1.0 - pow(1.0 - k, 2.0)
		var p := Vector2(roundf(float(s["x"]) + float(s["dx"]) * ease_k), roundf(-float(s["dy"]) * ease_k))
		var a := (1.0 - k) * 0.9
		var sz := 2.0 if (bool(s["big"]) and k < 0.6) else 1.0
		draw_rect(Rect2(p, Vector2(sz, sz)), Color(color.r, color.g, color.b, a))
