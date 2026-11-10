class_name GroundShadow
extends Sprite2D
## THE CONTACT SHADOW UNDER AN ACTOR'S FEET (owner round 49s: "look at shapes, depth, and most importantly, lighting... deeper lived-in looking space"): a small dark ellipse on the
## floor where a body stands. Nothing told the eye that the player and the dead touch the floor - a figure with no shadow reads as pasted over the room. Pure drawing: no collision, no
## groups, no input; it rides its body (a child, drawn BEFORE the body's own sprite, so on the body's layer) and hides itself whenever the body is not plainly standing on a floor
## (on a staircase's slice, clinging to a wall, lying down, hidden in a wardrobe, lashing down a rope, dead).
##
## Three hard tones (no blur, no dither - it is pixel art): a faint rim, a mid ring, a dark core. BLACK with alpha, so the time-of-day ambient and every lamp treat it alike.

const EnemyFeet := preload("res://scripts/enemy_feet.gd")

const CORE := 0.34            # the darkest part, right under the body
const MID := 0.22
const RIM := 0.10
const HEIGHT := 6             # texels, whatever the width
const MIN_W := 16
const MAX_W := 84
const WIDTH_GAIN := 1.25      # the shadow is a little wider than the body's collision box

static var _cache: Dictionary = {}       # width -> ImageTexture

var body: Node2D = null
var rig: CanvasItem = null               # the body's own sprite: the shadow follows its plane scale and its fade
var _base_scale := Vector2.ONE


## The ellipse for a body `width` px wide (cached per width).
static func texture_for(width: int) -> Texture2D:
	var w: int = clampi(width, MIN_W, MAX_W)
	w += w % 2
	if _cache.has(w):
		return _cache[w]
	var img := Image.create(w, HEIGHT, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx: float = (float(w) - 1.0) * 0.5
	var cy: float = (float(HEIGHT) - 1.0) * 0.5
	for y in range(HEIGHT):
		for x in range(w):
			var dx: float = (float(x) - cx) / (float(w) * 0.5)
			var dy: float = (float(y) - cy) / (float(HEIGHT) * 0.5)
			var r: float = dx * dx + dy * dy
			var a := 0.0
			if r <= 0.42:
				a = CORE
			elif r <= 0.74:
				a = MID
			elif r <= 1.0:
				a = RIM
			if a > 0.0:
				img.set_pixel(x, y, Color(0, 0, 0, a))
	var tex := ImageTexture.create_from_image(img)
	_cache[w] = tex
	return tex


## How wide a body's collision box is (its own shape; 20 when it has none).
static func body_width(b: Node) -> float:
	var col := b.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col == null or col.shape == null:
		return 20.0
	if col.shape is RectangleShape2D:
		return (col.shape as RectangleShape2D).size.x
	if col.shape is CapsuleShape2D:
		return (col.shape as CapsuleShape2D).radius * 2.0
	if col.shape is CircleShape2D:
		return (col.shape as CircleShape2D).radius * 2.0
	return 20.0


## Put a shadow under `b` (whose drawn sprite is `spr`). Returns it; a body that already has one keeps it.
static func attach(b: Node2D, spr: CanvasItem) -> GroundShadow:
	if b == null or spr == null:
		return null
	var have := b.get_node_or_null("GroundShadow") as GroundShadow
	if have != null:
		return have
	var s := GroundShadow.new()
	s.name = "GroundShadow"
	s.body = b
	s.rig = spr
	s.texture = texture_for(int(round(body_width(b) * WIDTH_GAIN)))
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.centered = true
	var col := b.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var cx: float = col.position.x if col != null else 0.0
	# every rig's DRAWN feet are one px above its collision bottom (scripts/enemy_feet.gd): the shadow's middle lies on that row
	s.position = Vector2(cx, EnemyFeet.collision_bottom(b) - EnemyFeet.PLAYER_DRAWN_ABOVE_COLLISION)
	if spr is Node2D:
		s._base_scale = (spr as Node2D).scale
	b.add_child(s)
	b.move_child(s, 0)             # before the body's sprite: under it, on the body's own layer
	s.process_mode = Node.PROCESS_MODE_ALWAYS
	s.refresh()
	return s


## Is the body plainly standing on a floor right now? (Duck-typed over the player and every enemy.)
func standing() -> bool:
	if body == null or not is_instance_valid(body) or rig == null or not is_instance_valid(rig):
		return false
	if not rig.visible:
		return false
	if body.get("stair_mode") == true:
		return false                                   # on the steps: the slice hides its legs
	var wm = body.get("wall_mode")
	if wm != null and String(wm) != "":
		return false                                   # a crawler on the wall or the ceiling
	if body.has_method("is_riser_down") and body.is_riser_down():
		return false                                   # one of the dead, still lying there
	if body.get("is_dead") == true or body.get("is_dying") == true:
		return false
	var st = body.get("state")
	if st != null and (String(st) == "dead" or String(st) == "knockdown"):
		return false
	if body.get("hide_spot") != null:
		return false                                   # in the wardrobe / the bath
	if body.get("is_lashing") == true or body.get("escaping") == true:
		return false
	# cut by a staircase / a balcony rail (StairPan.SHRED_SHADER, the one material with a `cut_y`): its legs are out of sight, and so is the floor they stand on
	var mat := rig.material as ShaderMaterial
	if mat != null and mat.get_shader_parameter("cut_y") != null:
		return false
	return true


func refresh() -> void:
	var ok := standing()
	visible = ok
	if not ok:
		return
	if rig is Node2D and _base_scale.y != 0.0:
		var k: float = absf((rig as Node2D).scale.y / _base_scale.y)       # the plane's depth scale (balcony 0.74, a step-up 0.89)
		scale = Vector2(k, k)
	modulate.a = clampf(rig.modulate.a * rig.self_modulate.a, 0.0, 1.0)


func _process(_delta: float) -> void:
	refresh()
