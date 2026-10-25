class_name LampRows
extends Control

## A found weapon's numbers, set beside the one in hand (ItemCompare.card): "Damage 3 ▲ +2" per row, in the Lamplight board's own comparison box — a darker well under a small caption
## ("VS KNIFE"). Drawn here, with drawn ▲ / ▼, so the marks are the same on every machine. `text` is a plain dump of what it says (tests, and anything that wants to read it).

const ROW_H := 26.0
const HEAD_H := 24.0

var rows: Array = []
var versus: String = ""
var text: String = ""


## Show an ItemCompare card (an empty one clears and hides it).
func set_card(c: Dictionary) -> void:
	rows = c.get("rows", [])
	versus = String(c.get("vs", ""))
	var lines: PackedStringArray = []
	if versus != "":
		lines.append("vs " + versus)
	for r in rows:
		lines.append("%s  %s  %s" % [r["label"], r["text"], r["delta"]])
	text = "\n".join(lines)
	custom_minimum_size.y = height()
	queue_redraw()


func height() -> float:
	if rows.is_empty():
		return 0.0
	return (HEAD_H if versus != "" else 6.0) + ROW_H * float(rows.size()) + 6.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if rows.is_empty():
		return
	var box := Rect2(Vector2.ZERO, Vector2(size.x, maxf(size.y, height())))
	Lamp.card(self, box, Lamp.WELL, Color(0.231, 0.176, 0.094))                      # #3b2d18, the board's comparison box
	var y := 3.0
	if versus != "":
		Lamp.text(self, "label", Vector2(12.0, 17.0), "VS " + versus.to_upper(), 12, Lamp.LABEL, size.x - 24.0)
		y = HEAD_H - 3.0
		draw_rect(Rect2(1.0, HEAD_H - 4.0, size.x - 2.0, 1.0), Color(0.231, 0.176, 0.094))
	for i in range(rows.size()):
		Lamp.row(self, 12.0, y + ROW_H * float(i), size.x - 24.0, rows[i], 1.0, 112.0, 20, ROW_H)
		if i < rows.size() - 1:
			draw_rect(Rect2(1.0, y + ROW_H * float(i + 1) - 1.0, size.x - 2.0, 1.0), Lamp.EDGE_DIM)
