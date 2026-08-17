extends Node2D

# A small flame effect drawn OVER an enemy that's standing in fire. Purely
# cosmetic — the gameplay (double damage) lives on the enemy. Added as a child at
# the enemy's body when it catches, removed when it steps clear. z above the body.

var _t: float = 0.0


func _ready() -> void:
	z_index = 2


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _col(frac: float) -> Color:
	if frac < 0.3:
		return Color(1.0, 0.9, 0.45)
	elif frac < 0.62:
		return Color(1.0, 0.55, 0.13)
	return Color(0.82, 0.2, 0.05)


func _draw() -> void:
	# a soft glow + a handful of small flame tongues licking up the body
	draw_circle(Vector2(0, -6), 16.0, Color(1.0, 0.5, 0.15, 0.12))
	for k in range(6):
		var hx := fmod(absf(sin(float(k + 1) * 12.9898) * 43758.5453), 1.0)
		var x := (hx - 0.5) * 30.0
		var h := 14.0 + hx * 14.0 + sin(_t * 9.0 + float(k)) * 3.0
		var rows := int(h / 3.0)
		for r in range(rows):
			var frac := float(r) / float(rows)
			var w := 5.0 * (1.0 - frac)
			if w < 1.0:
				w = 1.0
			var lean := sin(_t * 7.0 + float(k) + frac * 3.0) * 3.0 * frac
			draw_rect(Rect2(x + lean - w * 0.5, -float(r) * 3.0 - 4.0, w, 3.5), _col(frac))
