extends "res://scripts/city_view.gd"

# THE CITY BEHIND THE STAIRWELL WINDOWS (owner round 31j — "if it's a downward stairwell we can extend the width of the window
# and bring more light to that area. It'll also make the afternoon and night colours pop more").
#
# The stair art's glass is a HOLE (tools/art/stairwell.py writes its rectangle to assets/stair_window.json): the DOWN stair has a
# wide three-light window, the UP stair a narrow sash. Behind each hole sits the same city the apartments look out on
# (tools/art/cityscape.py `stair_view_<run>_<variant>` — day blue / sunset / the night city), animated by the shared
# scripts/city_fx.gd (fires and smoke at dusk and night, distant blasts, rain at night on the stairwell-sized `rain_stair`
# sheet). It is a child of the stair sprite drawn BEHIND it (`show_behind_parent`), so the sprite's opaque frame and walls mask
# everything but the glass — and it rides the sprite through a stair pan and hides with it. It is a CityView (round 33): the
# city slides a few px as you walk past, clipped to the glass.

const META_PATH := "res://assets/stair_window.json"
const CITY_FX = preload("res://scripts/city_fx.gd")
const VARIANTS := 2

var kind: String = ""
var view: Sprite2D = null
var fx: Node2D = null
var glass_size: Vector2 = Vector2.ZERO        # the hole's size: everything under this node is CLIPPED to it (clip_children)

static var _meta: Dictionary = {}


static func meta() -> Dictionary:
	if _meta.is_empty() and FileAccess.file_exists(META_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(META_PATH))
		if parsed is Dictionary:
			_meta = parsed
	return _meta


## The glass hole's centre in the sprite's LOCAL space (the sprite is centred, scale 1). `mirrored` = a *_Right sprite.
static func glass_centre(kind_: String, mirrored: bool) -> Vector2:
	var m := meta()
	var g = m.get("glass", {}).get(kind_, null)
	if not (g is Array) or g.size() < 4:
		return Vector2.INF
	var w: float = float(m.get("w", 80))
	var h: float = float(m.get("h", 144))
	var cx: float = (float(g[0]) + float(g[2]) + 1.0) * 0.5
	var cy: float = (float(g[1]) + float(g[3]) + 1.0) * 0.5
	if mirrored:
		cx = w - cx
	return Vector2(cx - w * 0.5, cy - h * 0.5)


static func glass_rect_size(kind_: String) -> Vector2:
	var g = meta().get("glass", {}).get(kind_, null)
	if not (g is Array) or g.size() < 4:
		return Vector2.ZERO
	return Vector2(float(g[2]) - float(g[0]) + 1.0, float(g[3]) - float(g[1]) + 1.0)


## Puts the run's city behind `sprite`'s glass. `kind` "up" / "down". Safe to call again (keeps an existing matching one).
static func attach(sprite: Sprite2D, kind_: String, mirrored: bool, variant: int, live: bool = true) -> Node2D:
	if sprite == null or not is_instance_valid(sprite):
		return null
	var old = sprite.get_node_or_null("StairWindow")
	if old != null:
		if old.get("kind") == kind_:
			return old
		old.name = "StairWindowOld"
		old.queue_free()
	var at := glass_centre(kind_, mirrored)
	if at == Vector2.INF:
		return null                                   # no meta: the hole shows the dark recess behind — never a crash
	var node = new()
	node.name = "StairWindow"
	node.kind = kind_
	node.show_behind_parent = true
	node.position = at
	# The city (72x78) is bigger than either hole and the sprite only masks what it covers — it poked out over the lintel and
	# past the UP sprite's edge. So the node draws the glass rectangle as a MASK and clips its children to it.
	node.glass_size = glass_rect_size(kind_)
	sprite.add_child(node)
	node.setup_view(float(CITY_FX.meta().get("_sizes", {}).get("pan", 0)))
	node.set_mask_rect(Rect2(-node.glass_size * 0.5, node.glass_size))
	node._build(clampi(variant, 0, VARIANTS - 1), live)
	return node


func _build(variant: int, live: bool) -> void:
	var run: int = clampi(WorldState.current_run, 1, 3)
	var key := "stair_view_%d_%d" % [run, variant]
	var path := "res://assets/city/%s.png" % key
	if not ResourceLoader.exists(path):
		return
	view = Sprite2D.new()
	view.name = "View"
	view.texture = load(path)
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.material = CITY_FX.unshaded()
	view.modulate = CITY_FX.exposure(1.0)
	far.add_child(view)
	fx = CITY_FX.new()
	fx.name = "CityFx"
	add_child(fx)
	var seed_v: int = hash(str(WorldState.master_seed) + "stairwin" + kind + str(variant))
	fx.setup_window(key, run, live, seed_v, null, view, "rain_stair", far)
