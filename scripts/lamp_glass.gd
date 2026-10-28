class_name LampGlass
extends Control

## The dark glass behind a panel (scripts/lamp.gd): first child of a container, it only DRAWS — so a panel that changes height is still one pane whatever it holds (the found-item panel).
## `corners` picks the brass brackets (the board's found-item panel has two: top-left and bottom-right).

var corners: int = Lamp.TL | Lamp.BR
var accent: Color = Lamp.BRASS


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)      # offsets too: in a plain Control (not a container) the pane would otherwise stay 0 x 0 until the parent resizes
	resized.connect(queue_redraw)


func _draw() -> void:
	Lamp.panel(self, Rect2(Vector2.ZERO, size), 1.0, corners, 16.0, accent, Lamp.BRASS_DIM)
