extends Node2D

# A standalone looping flame drawn from the craftpix fire sheets — for scene fire
# that isn't the corridor floor bed: flames climbing a burning door frame, and any
# future feature fire. The sheets are square frames, 6 across (folder 1 "Fire/Idle"
# is 64px, folder 3 "Flame" is 32px). Origin = the flame's BOTTOM CENTRE, so it
# rises upward from wherever the node is placed. z_index is set by the caller so it
# sits at the right depth (door fire goes behind the player).

var tex: Texture2D = null
var frame_px: int = 32
var frames: int = 6
var fps: float = 12.0
var draw_w: float = 60.0
var draw_h: float = 90.0
var phase: float = 0.0              # per-flame time offset so neighbours dance apart
var _t: float = 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if tex == null:
		return
	var fr := int((_t + phase) * fps) % frames
	var src := Rect2(float(fr * frame_px), 0.0, float(frame_px), float(frame_px))
	draw_texture_rect_region(tex, Rect2(-draw_w * 0.5, -draw_h, draw_w, draw_h), src, Color(1.0, 1.0, 1.0, 1.0))
