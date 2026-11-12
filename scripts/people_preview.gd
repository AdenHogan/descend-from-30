class_name PeoplePreview
extends Node2D

## DEV PREVIEW ONLY — the look-test neighbours (tools/art/people.py → assets/people) walking about in a real scene, so their size, colour and
## motion can be judged beside the game's own actors and under its lighting (owner 2026-11-12: "Test them in game"). Nothing in the game spawns
## this: `tools/scene_capture.tscn` does, with its `people` step. They have no collision, no AI and no state — each walks a short beat back and
## forth on the feet line, stops, stands, and sets off again.

const DIR := "res://assets/people/"

var who := ""
var feet := Vector2.ZERO          # where its feet stand (world)
var span := Vector2(0, 0)         # the x it walks between
var speed := 26.0
var carry := false
var size_k := 1.0                 # drawn this many times its authored size (a look test of how big a person should be in the world)
var _tex: Texture2D = null
var _meta: Dictionary = {}
var _t := 0.0
var _x := 0.0
var _dir := 1.0
var _rest := 0.0


static func meta() -> Dictionary:
	if not FileAccess.file_exists(DIR + "people.json"):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(DIR + "people.json"))
	return d if d is Dictionary else {}


## Stand the whole cast in `host`, spread between x0 and x1 on the feet line `feet_y`. Returns the nodes.
static func spawn_all(host: Node, feet_y: float, x0: float, x1: float, k: float = 1.0) -> Array:
	var out: Array = []
	var m := meta()
	var names: Array = m.get("people", [])
	for i in names.size():
		var n := PeoplePreview.new()
		n.who = String(names[i])
		n.size_k = k
		n._meta = m
		var cx := lerpf(x0, x1, (float(i) + 0.5) / float(names.size()))
		n.feet = Vector2(cx, feet_y)
		n.span = Vector2(cx - 34.0, cx + 34.0)
		n._x = cx + (float(i % 3) - 1.0) * 14.0
		n._dir = 1.0 if i % 2 == 0 else -1.0
		n._t = float(i) * 0.37
		n.carry = i % 3 == 0
		n.speed = 22.0 + float(i % 4) * 3.0
		n.z_index = 1                                   # the actors' layer
		host.add_child(n)
		out.append(n)
	return out


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(DIR + who + ".png"):
		_tex = load(DIR + who + ".png")


func _process(delta: float) -> void:
	_t += delta
	if _rest > 0.0:
		_rest -= delta
	else:
		_x += _dir * speed * delta
		if _x > span.y or _x < span.x:
			_x = clampf(_x, span.x, span.y)
			_dir = -_dir
			_rest = 1.4
	queue_redraw()


func _draw() -> void:
	if _tex == null or _meta.is_empty():
		return
	var cell: Array = _meta["cell"]
	var w := float(cell[0])
	var h := float(cell[1])
	var kind := "idle" if _rest > 0.0 else ("carry" if carry else "walk")
	var a: Array = _meta["anims"][kind]
	var ms := float(_meta["ms"][kind])
	var fr := int(a[0]) + int(_t * 1000.0 / ms) % int(a[1])
	global_position = Vector2(roundf(_x), feet.y)
	var half := floorf(w * 0.5)
	for i in range(-7, 8):                              # a contact shadow, as the game's actors have
		draw_rect(Rect2(float(i), -1.0, 1.0, 2.0), Color(0, 0, 0, 0.22 if absi(i) < 6 else 0.1))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(_dir * size_k, size_k))
	draw_texture_rect_region(_tex, Rect2(-half, -h + 1.0, w, h), Rect2(float(fr) * w, 0.0, w, h))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
