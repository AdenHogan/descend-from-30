extends Node2D

# A small LIVE detail in a room module's art (owner round 19 — "a sprite animation showing a bottle
# of milk or something else on its side dripping milk down to the ground… active storytelling").
# Written into the module scene by tools/art (pixlib.anim → modscene `Anims`), one node per detail,
# drawn in pixels so it matches the art. Its timing is seeded by its position, so no two tick in step.
#   drip   — a drop swells here, lets go, falls `fall` px, splashes; the next one swells
#   drop   — the same, slow (an IV drip chamber: one drop every few seconds, a short fall)
#   blink  — a w×h light on / off (a standby LED, a cursor left blinking)
#   static — a w×h screen of TV snow, now and then a bar rolling down it (a set left on)
#   spin   — a glint going round a w×h ellipse (a record still turning on the platter)

var kind := "drip"
var fall := 20.0
var col := Color(0.95, 0.94, 0.89)
var w := 1
var h := 1
var _t := 0.0
var _period := 1.8
var _snow := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	kind = str(get_meta("kind", "drip"))
	fall = float(get_meta("fall", 20))
	col = Color(str(get_meta("color", "f2efe4")))
	w = maxi(1, int(get_meta("w", 1)))
	h = maxi(1, int(get_meta("h", 1)))
	var seed_ := absi(int(position.x * 7.0 + position.y * 13.0))
	_rng.seed = seed_
	match kind:
		"drop":
			_period = 3.2 + float(seed_ % 120) / 100.0
		"blink":
			_period = 0.9 + float(seed_ % 60) / 100.0
		"spin":
			_period = 1.8
		"static":
			_period = 4.0 + float(seed_ % 200) / 100.0
		_:
			_period = 1.5 + float(seed_ % 90) / 100.0
	_t = float(seed_ % 100) / 100.0 * _period
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	_t = fmod(_t + delta, _period)
	_snow += delta
	queue_redraw()


func _draw() -> void:
	match kind:
		"drip", "drop":
			_draw_drip()
		"blink":
			if _t < _period * 0.5:
				draw_rect(Rect2(0, 0, w, h), col)
		"static":
			_draw_static()
		"spin":
			var a := TAU * _t / _period
			var p := Vector2(roundf(cos(a) * float(w)), roundf(sin(a) * float(h)))
			draw_rect(Rect2(p.x, p.y, 1, 1), col)
			draw_rect(Rect2(-p.x, -p.y, 1, 1), Color(col, 0.5))


func _draw_drip() -> void:
	var fall_t := 0.35 if kind == "drip" else 0.25
	var swell := _period - fall_t - 0.2
	if _t < swell:
		var k := _t / swell
		draw_rect(Rect2(0, 0, 1, 1), Color(col, 0.5 + 0.5 * k))
		if k > 0.6:
			draw_rect(Rect2(0, 1, 1, 1), Color(col, k))
	elif _t < swell + fall_t:
		var f := (_t - swell) / fall_t
		draw_rect(Rect2(0, floorf(fall * f * f), 1, 2), col)
	else:
		var s := (_t - swell - fall_t) / 0.2
		if s < 1.0:
			var a := 1.0 - s
			var spread := floorf(s * 2.0)
			draw_rect(Rect2(-1 - spread, fall - 1, 1, 1), Color(col, a))
			draw_rect(Rect2(1 + spread, fall - 1, 1, 1), Color(col, a))
			draw_rect(Rect2(0, fall - 2 - spread, 1, 1), Color(col, a * 0.8))


func _draw_static() -> void:
	# new snow every ~70 ms; a darker bar rolls down the screen for the first second of each period
	_rng.seed = int(_snow / 0.07) * 7919 + int(position.x)
	for y in range(h):
		for x in range(w):
			var v := _rng.randf()
			var g := 0.25 + 0.7 * v * v
			draw_rect(Rect2(x, y, 1, 1), Color(col.r * g, col.g * g, col.b * g, 0.9))
	if _t < 1.0:
		var by := floorf(_t * float(h + 3)) - 2.0
		draw_rect(Rect2(0, clampf(by, 0.0, float(h - 1)), w, minf(2.0, float(h))), Color(0, 0, 0, 0.35))
