extends RefCounted
class_name FireArt

# OUR fire (owner round 29 — "good animated fire that fits our vision"; generator tools/art/fire.py, sheet preview
# docs/art_reference/fire.png). Every fire in the game draws from these horizontal strips at integer 2x (v2, round 29b: CHUNKY
# pixel fire — fat pixels, round-topped licks, colour shells — the owner rejected the smooth v1; the purchased craftpix
# fire's floor tiles were CROPPED mid-flame). One helper so the floor fire, the apartment fire, the door-frame flames and the burning-enemy
# overlay all read as one fire:
#   draw(canvas, name, t, phase, bottom_centre)  — one frame of strip `name`, bottom-centre anchored, never cropped;
#   material()                                   — the shared UNSHADED material: flames are their own light, so the
#                                                  world's night-dark CanvasModulate never snuffs them out.

const DIR := "res://assets/fire/"
const META_PATH := "res://assets/fire/fire_meta.json"
const FPS := 10.0
const STAGE_NAMES := ["light", "blaze"]

static var _cache: Dictionary = {}
static var _meta: Dictionary = {}
static var _material: CanvasItemMaterial = null


static func meta() -> Dictionary:
	if _meta.is_empty() and FileAccess.file_exists(META_PATH):
		var d = JSON.parse_string(FileAccess.get_file_as_string(META_PATH))
		if d is Dictionary:
			_meta = d
	return _meta


static func material() -> CanvasItemMaterial:
	if _material == null:
		_material = CanvasItemMaterial.new()
		_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _material


## {tex, fw, fh, frames, scale} for a strip (fw/fh = the NATIVE frame size; `scale` = the integer the strip is drawn at, so
## the chunky half-res pixels sit on the game's own grid), or {} if the art isn't there (callers draw nothing rather than crash).
static func sheet(name: String) -> Dictionary:
	if _cache.has(name):
		return _cache[name]
	var out := {}
	var info: Dictionary = meta().get("sheets", {}).get(name, {})
	var path := DIR + name + ".png"
	if not info.is_empty() and ResourceLoader.exists(path):
		var fr: Array = info.get("frame", [0, 0])
		out = {"tex": load(path), "fw": int(fr[0]), "fh": int(fr[1]), "frames": int(info.get("frames", 8)),
			"scale": maxi(1, int(info.get("scale", 1)))}
	_cache[name] = out
	return out


## The sheet's frame size IN THE WORLD (scale applied; Vector2.ZERO if missing) — for layout maths.
static func frame_size(name: String) -> Vector2:
	var s := sheet(name)
	return Vector2(float(s["fw"]), float(s["fh"])) * float(s["scale"]) if not s.is_empty() else Vector2.ZERO


## Variant names "<prefix>_1" … "<prefix>_<n>" that exist.
static func variants(prefix: String, n: int = 3) -> Array:
	var out: Array = []
	for i in range(1, n + 1):
		if not sheet("%s_%d" % [prefix, i]).is_empty():
			out.append("%s_%d" % [prefix, i])
	return out


## The frame showing at time `t` for a flame whose animation is offset by `phase` (0..1 of the loop).
static func frame_at(t: float, phase: float, frames: int) -> int:
	return posmod(int(t * FPS + phase * float(frames)), maxi(1, frames))


## Draw one frame of strip `name`, bottom-centre on `at`. `flip` mirrors it; `alpha` fades it.
static func draw(canvas: CanvasItem, name: String, t: float, phase: float, at: Vector2, alpha: float = 1.0, flip: bool = false) -> void:
	var s := sheet(name)
	if s.is_empty():
		return
	var fw: float = float(s["fw"])
	var fh: float = float(s["fh"])
	var k: float = float(s["scale"])
	var fr := frame_at(t, phase, int(s["frames"]))
	var src := Rect2(float(fr) * fw, 0.0, fw, fh)
	var dw := fw * k
	var dh := fh * k
	var x := at.x - dw * 0.5
	var dst := Rect2(x + dw, at.y - dh, -dw, dh) if flip else Rect2(x, at.y - dh, dw, dh)
	canvas.draw_texture_rect_region(s["tex"], dst, src, Color(1.0, 1.0, 1.0, alpha))
