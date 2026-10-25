class_name LedgerRule
extends Control

## A line drawn across the page with a pen — it wanders a hair, thins at the ends, never a ruler's. `double` draws the bookkeeper's pair (a thick and a thin) that closes a column.

@export var seed_value: int = 1
@export var double: bool = false
@export var colour: Color = Ledger.INK_SOFT


func _init() -> void:
	custom_minimum_size = Vector2(0, 8)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var y := size.y * 0.5 - (2.0 if double else 0.0)
	draw_polyline(Ledger.pen_line(Vector2(2, y), Vector2(size.x - 2, y), seed_value, 0.7), Color(colour.r, colour.g, colour.b, 0.8 if double else 0.55), 1.6 if double else 0.9, true)
	if double:
		draw_polyline(Ledger.pen_line(Vector2(8, y + 3.5), Vector2(size.x - 14, y + 3.5), seed_value + 3, 0.6), Color(colour.r, colour.g, colour.b, 0.55), 0.9, true)
