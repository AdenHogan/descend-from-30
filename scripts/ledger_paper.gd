class_name LedgerPaper
extends Control

## A slip of paper that only DRAWS itself: the shadow it throws, a ragged edge, a few fibres, optional tape. Put it as the first child of a container (a PanelContainer, say) and it fills it,
## so a panel whose contents change height — a found item with a comparison under it — stays a sheet of paper whatever it holds. (LedgerSlip is the same paper that also lifts under the
## pointer; this one is for panels that are not buttons.)

@export var seed_value: int = 1
@export var tint: Color = Ledger.PAPER_SLIP
@export var tape: bool = true
@export var tape_tilt: float = -0.02

var _outline: PackedVector2Array = PackedVector2Array()
var _outline_size: Vector2 = Vector2.ZERO


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	if _outline_size != size or _outline.size() < 3:
		_outline = Ledger.ragged(size.x, size.y, 34.0, 1.6, seed_value)
		_outline_size = size
	draw_colored_polygon(Ledger.shifted(_outline, Vector2(4, 6)), Color(0, 0, 0, 0.16))
	draw_colored_polygon(Ledger.shifted(_outline, Vector2(2, 3)), Color(0, 0, 0, 0.24))
	draw_polygon(_outline, Ledger.lit(_outline, size, tint, 0.9))
	var fib := RandomNumberGenerator.new()
	fib.seed = absi(seed_value) * 13 + 1
	for i in 60:
		draw_rect(Rect2(Vector2(fib.randf() * size.x, fib.randf() * size.y), Vector2(fib.randf_range(1.0, 5.0), 1.0)), Color(0.45, 0.30, 0.12, 0.06))
	var closed := PackedVector2Array(_outline)
	closed.append(_outline[0])
	draw_polyline(closed, tint.darkened(0.36), 1.0)
	if tape:
		draw_set_transform(Vector2(size.x * 0.5, 3.0), tape_tilt, Vector2.ONE)
		draw_rect(Rect2(-31, -6, 62, 19), Color(0, 0, 0, 0.12))
		draw_rect(Rect2(-32, -9, 62, 19), Ledger.TAPE)
		draw_rect(Rect2(-32, -9, 3, 19), Color(1, 1, 1, 0.16))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
