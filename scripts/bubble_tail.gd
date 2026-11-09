extends Control
## The little tail of a speech bubble: a filled triangle in the bubble's own colour with a border on its two slanting sides, pointing DOWN at the speaker's head (owner round 49q:
## the bubble "is disconnected from everything below" - a bubble with a tail reads as somebody saying it). A pure drawing the HUD places under the bubble's bottom edge and
## hides when the bubble has been stacked up out of reach of the head. It never takes a click.

var fill: Color = Color(0.05, 0.05, 0.06, 0.88)
var edge: Color = Color(0.78, 0.82, 0.92)
var width_px: float = 14.0       # across the base
var height_px: float = 9.0       # from the base to the tip


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 30            # over the bubble's own border (a feedback pill is 29)
	size = Vector2(width_px, height_px)


## Hang the tail so its tip touches `tip` (screen px) and its base sits on the bubble's bottom edge.
func point_at(tip: Vector2) -> void:
	size = Vector2(width_px, height_px)
	position = Vector2(tip.x - width_px * 0.5, tip.y - height_px)
	queue_redraw()


func style_like(bg: Color, border: Color) -> void:
	fill = bg
	edge = border
	queue_redraw()


func _draw() -> void:
	var w := width_px
	var h := height_px
	# the base is drawn over the bubble's 2 px border so the tail grows out of the bubble, not out of its edge
	draw_colored_polygon(PackedVector2Array([Vector2(0, -2), Vector2(w, -2), Vector2(w * 0.5, h)]), fill)
	draw_line(Vector2(0, -2), Vector2(w * 0.5, h), edge, 2.0)
	draw_line(Vector2(w, -2), Vector2(w * 0.5, h), edge, 2.0)
	draw_line(Vector2(2, -3), Vector2(w - 2, -3), fill, 3.0)    # closes the bubble's border across the base
