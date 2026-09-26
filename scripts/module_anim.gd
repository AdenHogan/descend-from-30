extends Node2D

# A small LIVE detail in a room module's art (owner round 19 — "a sprite animation showing a bottle
# of milk or something else on its side dripping milk down to the ground… active storytelling").
# Written into the module scene by tools/art (pixlib.anim → modscene `Anims`), one node per detail,
# drawn in pixels so it matches the art.
#   kind "drip": a drop swells at this point, lets go, falls `fall` px, splashes, and the next one
#   starts to swell — never in step with any other drip (the period is seeded by its position).

var kind := "drip"
var fall := 20.0
var col := Color(0.95, 0.94, 0.89)
var _t := 0.0
var _period := 1.8


func _ready() -> void:
	kind = str(get_meta("kind", "drip"))
	fall = float(get_meta("fall", 20))
	col = Color(str(get_meta("color", "f2efe4")))
	var h := absi(int(global_position.x * 7.0 + global_position.y * 13.0))
	_period = 1.5 + float(h % 90) / 100.0
	_t = float(h % 100) / 100.0 * _period
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	_t = fmod(_t + delta, _period)
	queue_redraw()


func _draw() -> void:
	if kind != "drip":
		return
	var swell := _period - 0.55                      # the drop swells, then falls in ~0.35 s, then splashes
	if _t < swell:
		var k := _t / swell
		draw_rect(Rect2(0, 0, 1, 1), col)
		if k > 0.5:
			draw_rect(Rect2(0, 1, 1, 1), Color(col, 0.6 + 0.4 * k))
	elif _t < swell + 0.35:
		var f := (_t - swell) / 0.35
		var y := floorf(fall * f * f)
		draw_rect(Rect2(0, y, 1, 2), col)
	else:
		var s := (_t - swell - 0.35) / 0.2
		if s < 1.0:
			var a := 1.0 - s
			draw_rect(Rect2(-1 - floorf(s * 2.0), fall - 1, 1, 1), Color(col, a))
			draw_rect(Rect2(1 + floorf(s * 2.0), fall - 1, 1, 1), Color(col, a))
			draw_rect(Rect2(0, fall - 2 - floorf(s * 2.0), 1, 1), Color(col, a * 0.8))
