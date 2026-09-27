extends Node2D
## An apartment's NUMBER PLATE (owner round 23 — "there should be door signs next to each apartment on
## the left with the apartment number"), on the wall just left of its door at eye level, in the style
## of the corridor section it's on (a brass plate in the hotel floors, white enamel in the residential
## ones, black plastic in the low ones). The maintenance door says STAFF. A breached door's plate went
## with the frame. Drawn in the building's 3x5 capitals (scripts/floor_signs.gd).

const SIGNS := preload("res://scripts/floor_signs.gd")
const DOOR_HALF_W := 23.0
const EYE_Y := -20.0                 # door-local: about three quarters of the way up the door

var text := ""
var section := "mid"


func setup(t: String, sec: String) -> void:
	name = "Plate"
	text = t
	section = sec
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()


## The plate's face in door-local px (its 1px edge + shadow sit round it).
static func plate_rect(t: String) -> Rect2:
	var w := SIGNS.text_width(t) + 6
	return Rect2(-DOOR_HALF_W - 5.0 - w, EYE_Y - 4.0, w, 9)


func _draw() -> void:
	if text == "":
		return
	var r := plate_rect(text)
	var face: Color
	var ink: Color
	var edge: Color
	match section:
		"high":
			face = Color(0.74, 0.58, 0.28); ink = Color(0.26, 0.16, 0.07); edge = Color(0.3, 0.2, 0.09)
		"mid":
			face = Color(0.93, 0.93, 0.89); ink = Color(0.17, 0.27, 0.52); edge = Color(0.36, 0.4, 0.5)
		_:
			face = Color(0.14, 0.14, 0.15); ink = Color(0.9, 0.9, 0.86); edge = Color(0.06, 0.06, 0.06)
	draw_rect(Rect2(r.position + Vector2(1, 1), r.size), Color(0, 0, 0, 0.35))       # a hair of shadow
	draw_rect(r.grow(1), edge)
	draw_rect(r, face)
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1), face.lightened(0.18))
	SIGNS.draw_text(self, Vector2(r.position.x + 3, r.position.y + 2), text, ink)
	draw_rect(Rect2(r.position.x + 1, r.position.y + 4, 1, 1), edge)                   # its screws
	draw_rect(Rect2(r.end.x - 2, r.position.y + 4, 1, 1), edge)
