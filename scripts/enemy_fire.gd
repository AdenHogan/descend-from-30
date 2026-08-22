extends Node2D

# A few SMALL purchased pixel-fire globs stuck across an enemy's body while it's
# standing in flame. Purely cosmetic — the gameplay (double damage + burn DoT) lives
# on the enemy. Added as a child at the enemy's torso when it catches, removed when it
# steps clear OR dies (the parent enemy clears it). NO collision/physics — it never
# blocks the player. Uses the craftpix "3 Flame" sheets (192x32 = 6 frames of 32x32),
# scaled DOWN to little tongues so they read as fire clinging to the body.

const FRAME_PX := 32
const FRAMES := 6
const FPS := 12.0

var _t: float = 0.0
var _tex: Array = []
# Each glob: local pos (relative to the fx origin at ~torso), scale, animation phase,
# and which flame variant — so the 2-3 globs sit at different spots and flicker out
# of sync instead of looking like one stamped sprite.
var _globs: Array = []


func _ready() -> void:
	z_index = 2
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST      # crisp pixels, no blur
	var base := "res://assets/fire-pixel-art-animation-sprites/3 Flame/"
	for n in ["1", "2", "3"]:
		var t = load(base + n + ".png")
		if t != null:
			_tex.append(t)
	# 2-3 small flames across the body: lower torso, chest, and a shoulder lick. Small
	# scales keep them as clinging tongues, not a bonfire swallowing the enemy.
	_globs = [
		{"pos": Vector2(-4.0, 2.0), "sc": 0.60, "ph": 0.0, "ti": 0},
		{"pos": Vector2(5.0, -12.0), "sc": 0.50, "ph": 2.1, "ti": 1},
		{"pos": Vector2(-3.0, -22.0), "sc": 0.40, "ph": 4.3, "ti": 2},
	]


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if _tex.is_empty():
		return
	for g in _globs:
		var tex: Texture2D = _tex[int(g["ti"]) % _tex.size()]
		var fr := (int(_t * FPS + float(g["ph"]))) % FRAMES
		var w := float(FRAME_PX) * float(g["sc"])
		var h := float(FRAME_PX) * float(g["sc"])
		var p: Vector2 = g["pos"]
		# base of the flame sits on its anchor, tongue rises upward
		var dst := Rect2(p.x - w * 0.5, p.y - h, w, h)
		var src := Rect2(float(fr * FRAME_PX), 0.0, float(FRAME_PX), float(FRAME_PX))
		draw_texture_rect_region(tex, dst, src)
