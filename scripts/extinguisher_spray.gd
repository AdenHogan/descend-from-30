extends Node2D

# The white cloud that jets out of the fire extinguisher — the purchased Horisontal_smoke
# sheet (12 frames, 128²), resized and pushed OUT in the direction the player faces so it
# blows OVER the fire. A one-shot: plays through once, drifting a little further out each
# frame, then frees itself. Cosmetic, no collision. Drawn in FRONT of the fire (z3) so the
# spray reads as landing on top of the flames.

const FRAMES := 12
const FPS := 15.0

var direction: float = 1.0     # +1 facing right, -1 facing left (set before add_child)
var _t: float = 0.0
var _tex: Array = []


func _ready() -> void:
	z_index = 3
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Flip the whole node for a leftward spray, then always draw toward +x (outward).
	scale.x = -1.0 if direction < 0.0 else 1.0
	var base := "res://assets/smoke-effects-pixel-art/PNG/Horisontal_smoke/Horisontal_smoke%d.png"
	for i in range(1, FRAMES + 1):
		var t = load(base % i)
		if t != null:
			_tex.append(t)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _tex.is_empty() or _t * FPS >= float(_tex.size()):
		queue_free()


func _draw() -> void:
	if _tex.is_empty():
		return
	var fr := int(_t * FPS)
	if fr >= _tex.size():
		return
	var w := 104.0
	var h := 60.0
	# Jet outward from the nozzle: starts at the hand, reaches further over the fire as the
	# burst develops; fades as it dissipates near the end of the sheet.
	var adv := 6.0 + _t * 90.0
	var frac := float(fr) / float(_tex.size())
	var alpha := 0.9 * (1.0 - 0.6 * frac)
	draw_texture_rect(_tex[fr], Rect2(adv, -h * 0.5, w, h), false, Color(1.0, 1.0, 1.0, alpha))
