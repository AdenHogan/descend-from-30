extends Node2D

# A standalone looping flame from our fire strips (scripts/fire_art.gd) — for scene fire that isn't the corridor floor
# carpet: flames climbing a burning door frame, and any future feature fire. Origin = the flame's BOTTOM CENTRE, so it
# rises upward from wherever the node is placed. Drawn at native size (never stretched), unshaded. z_index is set by the
# caller so it sits at the right depth (door fire goes behind the player).

var sheet_name: String = "edge_1"     # which strip (FireArt.sheet)
var phase: float = 0.0                # per-flame time offset (0..1 of the loop) so neighbours dance apart
var flip: bool = false
var _t: float = 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	material = FireArt.material()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	FireArt.draw(self, sheet_name, _t, phase, Vector2.ZERO, 1.0, flip)
