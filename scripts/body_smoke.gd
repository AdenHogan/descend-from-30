extends Node2D

# A soft smoke wisp rising off a BURNED corpse — a zombie that died while on fire keeps
# smouldering. Purely cosmetic, NO collision. Loops the purchased Cycled_smoke sprite,
# small and faint. Added as a child of the corpse (freed with it) when it dies alight.

const FRAMES := 6
const FPS := 7.0

var _t: float = 0.0
var _tex: Array = []


func _ready() -> void:
	z_index = 2
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var base := "res://assets/smoke-effects-pixel-art/PNG/Cycled_smoke/Cycled_smoke%d.png"
	for i in range(1, FRAMES + 1):
		var t = load(base % i)
		if t != null:
			_tex.append(t)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if _tex.is_empty():
		return
	var fr := int(_t * FPS) % _tex.size()
	# two faint offset wisps so it reads as a body smouldering, not one stamped puff
	var w := 44.0
	var h := 46.0
	draw_texture_rect(_tex[fr], Rect2(-4.0 - w * 0.5, -h, w, h), false, Color(0.62, 0.60, 0.58, 0.5))
	var fr2 := int(_t * FPS + 3.0) % _tex.size()
	draw_texture_rect(_tex[fr2], Rect2(6.0 - w * 0.35, -h * 0.8, w * 0.7, h * 0.7), false, Color(0.6, 0.58, 0.56, 0.4))
