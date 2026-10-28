class_name LampNeeds
extends Control

## The checklist under an action (the workbench's UPGRADE): what it needs and what you have, one row each — a drawn tick or cross, the thing, what it takes, and at the right what you have.
## Green when you have it, red when you do not ("you have 20 — need 10 more" is the owner's own ask: "if I press, it doesn't say if I have enough scrap").
## Rows are plain dictionaries {label, need, have, ok}; drawing only (scripts/lamp.gd), no logic. `text` is a plain dump of what it says (tests, and anything that wants to read it).

const ROW_H := 30.0
const HAVE_W := 200.0                # the right-hand column: what you have

var rows: Array = []
var text: String = ""


func set_rows(r: Array) -> void:
	rows = r
	var lines: PackedStringArray = []
	for row in rows:
		lines.append("%s  %s  %s" % [row["label"], row["need"], row["have"]])
	text = "\n".join(lines)
	custom_minimum_size.y = ROW_H * float(rows.size())
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	for i in range(rows.size()):
		var r: Dictionary = rows[i]
		var ok: bool = bool(r["ok"])
		var col: Color = Lamp.GREEN if ok else Lamp.RED
		var y: float = float(i) * ROW_H
		var mid := Vector2(11.0, y + ROW_H * 0.5)
		if ok:
			draw_polyline(PackedVector2Array([mid + Vector2(-6, 0), mid + Vector2(-2, 5), mid + Vector2(6, -5)]), col, 3.0)
		else:
			draw_line(mid + Vector2(-5, -5), mid + Vector2(5, 5), col, 3.0)
			draw_line(mid + Vector2(-5, 5), mid + Vector2(5, -5), col, 3.0)
		var base := y + ROW_H * 0.5 + 6.0
		Lamp.text(self, "label", Vector2(30.0, base), String(r["label"]), Lamp.PX_LABEL, Lamp.LABEL, 96.0)
		Lamp.text(self, "body", Vector2(134.0, base), String(r["need"]), Lamp.PX_BODY, Lamp.TEXT, size.x - 134.0 - HAVE_W - 12.0)
		Lamp.text(self, "body", Vector2(size.x - HAVE_W, base), String(r["have"]), Lamp.PX_BODY, col, HAVE_W, HORIZONTAL_ALIGNMENT_RIGHT)
