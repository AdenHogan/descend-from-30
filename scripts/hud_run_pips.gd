extends Control

# Three small squares under the time of day: which of the session's three characters this is.
# Filled amber up to the current run.

const COUNT := 3
const PIP := 14.0
const GAP := 6.0

var run: int = 1


static func width() -> float:
	return COUNT * PIP + (COUNT - 1) * GAP


func set_run(r: int) -> void:
	run = clampi(r, 1, COUNT)
	queue_redraw()


func _draw() -> void:
	for i in range(COUNT):
		var r := Rect2(Vector2(float(i) * (PIP + GAP), 0.0), Vector2(PIP, PIP))
		draw_rect(r, Color(0, 0, 0, 1))
		var inner := r.grow(-1.0)
		draw_rect(inner, Color(0.89, 0.647, 0.247, 1.0) if i < run else Color(0.17, 0.16, 0.18, 1.0))
