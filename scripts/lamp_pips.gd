class_name LampPips
extends Control

## A stat's ranks as boxes (the workbench's Tune tab): brass-filled = set, outlined brass over a dim fill = staged (not yet applied), an empty outline = still to earn.

var have: int = 0
var staged: int = 0
var cap: int = 0
var box: float = 16.0
var gap: float = 5.0


func setup(have_: int, staged_: int, cap_: int) -> void:
	have = have_
	staged = staged_
	cap = cap_
	queue_redraw()


func _draw() -> void:
	var y := (size.y - box) * 0.5
	for i in range(cap):
		var r := Rect2(Vector2(float(i) * (box + gap), y), Vector2(box, box))
		if i < have:
			draw_rect(r, Lamp.BRASS)
			Lamp.outline(self, r, Lamp.BRASS_HI, 1.0)
		elif i < have + staged:
			draw_rect(r, Lamp.fade(Lamp.BRASS_DIM, 0.55))
			Lamp.outline(self, r, Lamp.BRASS, 2.0)
		else:
			draw_rect(r, Lamp.WELL)
			Lamp.outline(self, r, Lamp.EDGE, 1.0)
