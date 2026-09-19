extends Marker2D

const GLOW_DISTANCE = 80.0
const INTERACT_DISTANCE = 50.0

const FL = preload("res://scripts/floor_lighting.gd")

# --- Scavenge marker: a small shiny SPHERE -----------------------------------
# Replaces the old flat circle. A small, appealing glowing BALL with real volume: a properly
# SHADED SPHERE (baked from sphere-normal lighting, a smooth gradient from a lit upper-left
# crest to a soft dark terminator — NOT concentric discs, which read as an "Among Us" visor),
# a tiny drifting specular glint (gentle rotation + shine), a small bob, and a TIGHT little
# glow. A modest REAL PointLight2D gives it presence without flooding the room. GOLDEN while
# it still holds an untaken item you HAVEN'T searched; once SEARCHED-but-not-emptied it turns
# pale WHITE/colourless — drained but still glowing + distinct so a looked-in node reads apart.
# Only two colours matter now: the sphere BODY tint and the SPEC/GLOW/LIGHT accent.
const GOLD := {
	"body": Color(1.00, 0.80, 0.22), "spec": Color(1.00, 0.98, 0.86),
	"glow": Color(1.00, 0.80, 0.30), "light": Color(1.00, 0.78, 0.34),
}
const PALE := {
	"body": Color(0.86, 0.89, 0.95), "spec": Color(1.00, 1.00, 1.00),
	"glow": Color(0.88, 0.92, 1.00), "light": Color(0.88, 0.92, 1.00),
}

static var _sphere_tex: Texture2D = null

var apartment_id: String = ""
var player: Node = null
var is_in_range: bool = false
var is_selected: bool = false

var _t: float = 0.0
var _tex: Texture2D = null
var _light: PointLight2D = null


static func sphere_texture() -> Texture2D:
	# A baked, smoothly-shaded sphere (white; tint it when drawing). Diffuse from an upper-left
	# key light over a low ambient, so the ball has a bright crest fading to a soft dark edge —
	# a real 3D read, no hard rings. Soft anti-aliased alpha at the rim.
	if _sphere_tex == null:
		var w := 64
		var img := Image.create(w, w, false, Image.FORMAT_RGBA8)
		var c := (w - 1) / 2.0
		var half := w / 2.0
		var lightdir := Vector3(-0.5, -0.6, 0.62).normalized()
		for y in range(w):
			for x in range(w):
				var nx := (float(x) - c) / half
				var ny := (float(y) - c) / half
				var r2 := nx * nx + ny * ny
				if r2 >= 1.0:
					img.set_pixel(x, y, Color(0, 0, 0, 0))
					continue
				var nz := sqrt(1.0 - r2)
				var diff: float = maxf(0.0, Vector3(nx, ny, nz).dot(lightdir))
				var shade: float = 0.28 + 0.72 * diff        # ambient floor so the dark side isn't black
				var edge: float = clampf((1.0 - r2) / 0.08, 0.0, 1.0)   # soft AA rim
				img.set_pixel(x, y, Color(shade, shade, shade, edge))
		_sphere_tex = ImageTexture.create_from_image(img)
	return _sphere_tex


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	_tex = FL.light_texture()          # soft round cookie — used for the tight glow + glint softness
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR   # smooth the scaled-down sphere/glow
	# A MODEST real light so the orb has presence — small pool, not a floodlight (an earlier
	# version's big halo read as a giant glow). Driven per-frame in _process; 0 when not
	# scavenging / out of range so it never lights a room you're not searching.
	_light = PointLight2D.new()
	_light.texture = _tex
	_light.color = GOLD["light"]
	_light.energy = 0.0
	_light.texture_scale = 0.06
	_light.z_index = 0
	add_child(_light)
	_check_should_hide()


func _check_should_hide() -> void:
	# Hide if already searched AND nothing left at this anchor
	if not WorldState.is_anchor_searched(apartment_id, name):
		return
	var has_item = WorldState.get_anchor_item(apartment_id, name) != "" or \
				   WorldState.is_anchor_a_key(apartment_id, name)
	if not has_item:
		_hide_permanently()


func _hide_permanently() -> void:
	visible = false
	set_process(false)
	is_in_range = false
	if _light != null:
		_light.energy = 0.0


func _activity() -> float:
	# 0 = not shown; else how "hot" the orb is (drives size, brightness, light energy).
	if player == null or not WorldState.is_scavenge_mode:
		return 0.0
	var dist = global_position.distance_to(player.global_position)
	if dist > GLOW_DISTANCE:
		return 0.0
	if is_selected:
		return 1.0
	if dist <= INTERACT_DISTANCE:
		return 0.82
	# Fading in from the far edge of the glow radius.
	var f = 1.0 - ((dist - INTERACT_DISTANCE) / (GLOW_DISTANCE - INTERACT_DISTANCE))
	return 0.34 + 0.28 * clampf(f, 0.0, 1.0)


func _process(delta: float) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			return
	_t += delta
	var dist = global_position.distance_to(player.global_position)
	var was_in_range = is_in_range
	is_in_range = dist <= INTERACT_DISTANCE
	if was_in_range and not is_in_range:
		WorldState.interaction_handled = false
	# Drive the real light to match the orb, with the same gentle pulse; colour follows the
	# orb's state (warm gold, or cool white once searched-but-not-emptied).
	var lvl = _activity()
	if _light != null:
		var pal = _palette()
		_light.color = pal["light"]
		var pulse = 1.0 + 0.08 * sin(_t * 3.2)
		# Modest, tight pool — presence, not a floodlight.
		_light.energy = lvl * 0.45 * pulse
		_light.texture_scale = 0.045 + 0.03 * lvl
	queue_redraw()


func _palette() -> Dictionary:
	# GOLD until the anchor has been searched; PALE (colourless) after, if it still holds an item.
	return PALE if WorldState.is_anchor_searched(apartment_id, name) else GOLD


func _draw() -> void:
	var lvl = _activity()
	if lvl <= 0.0:
		return
	var pal = _palette()
	var pulse = 1.0 + 0.05 * sin(_t * 3.0)
	# SMALL ball (an earlier version read far too big). Radius in world px.
	var r = lerpf(4.0, 6.5, lvl) * pulse
	# A little vertical bob for weight (a held object floating).
	var c = Vector2(0.0, sin(_t * 2.0) * 0.8)

	# TIGHT glow, hugging the ball — just enough to read as glowing, never a big halo.
	_blit(c, r * 1.5, _a(pal["glow"], 0.16 * lvl))

	# The shaded sphere itself (baked smooth gradient, tinted). Real 3D read, no crescent.
	var d = r * 2.0
	draw_texture_rect(sphere_texture(), Rect2(c.x - r, c.y - r, d, d), false, pal["body"])

	# A tiny specular glint drifting near the lit crest — subtle shine + a gentle-rotation cue.
	var hl = Vector2(-1, -1).normalized()
	var gpos = c + hl * (r * 0.38) + Vector2(cos(_t * 1.1), sin(_t * 1.1)) * (r * 0.10)
	_blit(gpos, r * 0.42, _a(pal["spec"], 0.30 * lvl))
	draw_circle(gpos, r * 0.14, _a(pal["spec"], 0.85 * lvl))


func _a(col: Color, alpha: float) -> Color:
	return Color(col.r, col.g, col.b, alpha)


func _blit(center: Vector2, radius: float, col: Color) -> void:
	# Draw the round cookie centred at `center`, sized to `radius`.
	draw_texture_rect(_tex, Rect2(center.x - radius, center.y - radius, radius * 2.0, radius * 2.0), false, col)


func try_interact() -> void:
	if not WorldState.is_scavenge_mode:
		return
	if not WorldState.interaction_handled:
		WorldState.interaction_handled = true
		_open_loot()


func _open_loot() -> void:
	var item_id = WorldState.get_anchor_item(apartment_id, name)
	var loot_ui = get_tree().get_root().find_child("LootUI", true, false)
	if loot_ui == null:
		push_error("LootUI not found")
		return
	loot_ui.open(item_id, name, apartment_id)


# Called by loot_ui after the interaction resolves
func on_loot_closed(_item_was_taken: bool) -> void:
	if not WorldState.is_anchor_searched(apartment_id, name):
		return
	var has_item = WorldState.get_anchor_item(apartment_id, name) != "" or \
				   WorldState.is_anchor_a_key(apartment_id, name)
	if not has_item:
		_hide_permanently()
