class_name LightSense
extends RefCounted

## HOW LIT IS THIS SPOT? (owner 2026-11-10: "being able to hide in total dark spaces during the night run when lighting may be out on a floor"; docs/TORCH_AND_DARK.md)
##
## The game's light is real: a per-scene ambient (the `WorldGrade` CanvasModulate — 0.95 by morning, 0.42 by afternoon, 0.07 at night, dimmer with depth) and additive
## PointLight2Ds on top (wall sconces, flat lamps, window pools and beams, fire, a torch). This reads the SAME things the renderer does and answers one number for a
## world point: the ambient's luminance plus, for every light whose cookie covers the point, energy x the light's colour x the cookie's own texel there (so a sconce's
## cone, a slanting window shaft and a torch's beam are measured as they are drawn, not as circles).
##
## It is what makes darkness a PLACE: `Stealth` asks it whether the player stands in the dark (the dead see less far; the dark itself can be hidden in) and a dark hiding
## place asks it whether a light has come back on. A pure reading — it changes nothing, and nothing is saved.

const DARK := 0.16           # at or under this a spot is DARK (a night corridor between two dead sconces reads ~0.03-0.10; the edge of a lit pool ~0.2)
const LIT := 0.40            # at or over this it is plainly lit (the afternoon's ambient alone is 0.42: nothing is "dark" before night, bar a deep floor)
const MIN_REACH := 26.0      # a light whose cookie reaches less than this (a scavenge star's glint, a lava lamp's glow) is a marker, not light to be seen by
const LIST_TTL_MSEC := 400   # how long a scene's list of lights is kept before it is gathered again (lights come and go: fire, a torch, a lamp cutting out)

static var _images: Dictionary = {}      # texture instance id -> Image (the cookie, read once)
static var _lists: Dictionary = {}       # root instance id -> {"t": msec, "lights": Array}


static func lum(c: Color) -> float:
	return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b


## The scene's ambient light: the luminance of its `WorldGrade` (1.0 for a scene that has none — fully lit).
static func ambient(root: Node) -> float:
	if root == null or not is_instance_valid(root):
		return 1.0
	var cm := root.get_node_or_null("WorldGrade") as CanvasModulate
	if cm == null or not cm.visible:
		return 1.0
	return lum(cm.color)


## Every PointLight2D under `root` (cached for LIST_TTL_MSEC).
static func lights(root: Node) -> Array:
	if root == null or not is_instance_valid(root):
		return []
	var id: int = root.get_instance_id()
	var now: int = Time.get_ticks_msec()
	var e = _lists.get(id)
	if e != null and now - int(e["t"]) < LIST_TTL_MSEC:
		return e["lights"]
	var found: Array = root.find_children("*", "PointLight2D", true, false)
	_lists[id] = {"t": now, "lights": found}
	if _lists.size() > 24:                      # scenes come and go: never let the cache grow for ever
		for k in _lists.keys():
			if now - int(_lists[k]["t"]) > 5000:
				_lists.erase(k)
	return found


## Forget the cached list for `root` (a test that adds a light and reads the level in the same frame).
static func forget(root: Node) -> void:
	if root != null:
		_lists.erase(root.get_instance_id())


static func _image(tex: Texture2D) -> Image:
	var id: int = tex.get_instance_id()
	if _images.has(id):
		return _images[id]
	var img: Image = tex.get_image()
	if img != null and img.is_compressed():
		img.decompress()
	_images[id] = img
	if _images.size() > 64:
		_images.clear()
		_images[id] = img
	return img


## What ONE light adds at world point `pos`: energy x its colour's luminance x its cookie's texel there. 0 outside the cookie, for a light that is off, and for a marker light.
static func contribution(l: PointLight2D, pos: Vector2) -> float:
	if l == null or not is_instance_valid(l) or not l.is_inside_tree() or not l.enabled or l.energy <= 0.0 or not l.is_visible_in_tree():
		return 0.0
	var tex: Texture2D = l.texture
	if tex == null:
		return 0.0
	var size: Vector2 = tex.get_size()
	var sc: float = maxf(0.001, l.texture_scale)
	var gs: Vector2 = l.global_scale
	if maxf(size.x * absf(gs.x), size.y * absf(gs.y)) * 0.5 * sc < MIN_REACH:
		return 0.0
	var uv: Vector2 = (l.to_local(pos) - l.offset) / sc + size * 0.5
	if uv.x < 0.0 or uv.y < 0.0 or uv.x >= size.x or uv.y >= size.y:
		return 0.0
	var px: Color = texel(tex, uv)
	return l.energy * lum(l.color) * lum(px) * px.a


## The cookie's colour at texel `uv`. A GradientTexture2D (the round cookie every lamp, fire and window fill uses) is read from its gradient and fill — the engine
## renders its image lazily, so `get_image()` is empty until it has been drawn; every other texture is read from its image, once.
static func texel(tex: Texture2D, uv: Vector2) -> Color:
	if tex is GradientTexture2D:
		var gt := tex as GradientTexture2D
		if gt.gradient == null:
			return Color(0, 0, 0, 0)
		var q := Vector2(uv.x / maxf(1.0, float(gt.width)), uv.y / maxf(1.0, float(gt.height)))
		var span: Vector2 = gt.fill_to - gt.fill_from
		var t := 0.0
		if gt.fill == GradientTexture2D.FILL_RADIAL:
			t = (q - gt.fill_from).length() / maxf(0.0001, span.length())
		elif gt.fill == GradientTexture2D.FILL_SQUARE:
			var dq: Vector2 = (q - gt.fill_from).abs()
			t = maxf(dq.x, dq.y) / maxf(0.0001, span.length())
		else:
			t = (q - gt.fill_from).dot(span) / maxf(0.0001, span.length_squared())
		return gt.gradient.sample(clampf(t, 0.0, 1.0))
	var img := _image(tex)
	if img == null or img.is_empty():
		return Color(0, 0, 0, 0)
	return img.get_pixel(clampi(int(uv.x), 0, img.get_width() - 1), clampi(int(uv.y), 0, img.get_height() - 1))


## How lit world point `pos` is in the scene under `root`: the ambient plus every light on it. `skip` (a node) leaves out that node's own lights — the player's
## aura and torch are how THEY see, not light that falls on them from the room.
static func level_at(pos: Vector2, root: Node, skip: Node = null) -> float:
	var total: float = ambient(root)
	for l in lights(root):
		if not is_instance_valid(l):
			continue
		if skip != null and is_instance_valid(skip) and (l == skip or skip.is_ancestor_of(l)):
			continue
		total += contribution(l, pos)
	return total


## 0 = dark .. 1 = plainly lit, smooth between DARK and LIT.
static func lit_share(level: float) -> float:
	return smoothstep(DARK, LIT, level)
