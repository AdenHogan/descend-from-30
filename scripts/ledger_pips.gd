class_name LedgerPips
extends Control

## A row of tally boxes on the page: ranks already set are inked solid, ranks staged but not yet set are pencilled (hatched, in the pen's blue), the rest are empty boxes drawn with a ruler.
## (The workbench's tuning column; a rank is one box.)

var have: int = 0
var staged: int = 0
var cap: int = 0
@export var box: float = 14.0
@export var gap: float = 5.0
@export var ink: Color = Ledger.INK


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(have_n: int, staged_n: int, cap_n: int) -> void:
	have = have_n
	staged = staged_n
	cap = cap_n
	custom_minimum_size.x = maxf(custom_minimum_size.x, cap * (box + gap))
	queue_redraw()


func _draw() -> void:
	var y := (size.y - box) * 0.5
	for i in range(cap):
		var r := Rect2(Vector2(2.0 + i * (box + gap), y), Vector2(box, box))
		if i < have:
			draw_rect(r, Color(ink.r, ink.g, ink.b, 0.9))
		elif i < have + staged:
			draw_rect(r, Color(Ledger.BLUE_INK.r, Ledger.BLUE_INK.g, Ledger.BLUE_INK.b, 0.12))
			for k in range(4, int(box * 2.0), 4):                                     # diagonal pencil strokes, clipped to the box
				var a := Vector2(minf(float(k), box), maxf(0.0, float(k) - box))
				var b := Vector2(maxf(0.0, float(k) - box), minf(float(k), box))
				draw_line(r.position + a, r.position + b, Ledger.BLUE_INK, 1.0)
			draw_rect(r, Ledger.BLUE_INK, false, 1.4)
		else:
			draw_rect(r, Color(ink.r, ink.g, ink.b, 0.5), false, 1.2)
