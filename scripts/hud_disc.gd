extends Control

# A circular clipping window: it draws a white disc as its own alpha and clips its children to it
# (CLIP_CHILDREN_ONLY — the disc itself never shows), so the portrait inside reads as a round bust.

func _ready() -> void:
	clip_children = CanvasItem.CLIP_CHILDREN_ONLY


func _draw() -> void:
	draw_circle(size * 0.5, minf(size.x, size.y) * 0.5, Color(1, 1, 1, 1))
