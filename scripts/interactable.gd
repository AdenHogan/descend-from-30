extends Marker2D

const GLOW_DISTANCE = 80.0
const INTERACT_DISTANCE = 50.0

const FL = preload("res://scripts/floor_lighting.gd")

# --- Mini-sun scavenge marker -------------------------------------------------
# Replaces the old flat yellow/white circle. A small glowing, ROTATING orb with a
# shaded body (fake 3D), a rotating corona of flares, drifting sunspots (spin cue), a
# soft halo, a gentle pulse — and a REAL PointLight2D so it actually casts warm light
# into the room (weight + it plays with the dynamic lighting). Distinct, not overwhelming;
# it grows/brightens as the player nears and is hottest when selected.
const CORE := Color(1.00, 0.97, 0.86)   # white-hot centre
const HOT := Color(1.00, 0.84, 0.42)    # inner amber
const MID := Color(1.00, 0.58, 0.16)    # body orange
const RIM := Color(0.82, 0.33, 0.05)    # cooler rim (edge in shadow → sphere read)
const FLARE := Color(1.00, 0.72, 0.28)  # corona
const SUNSPOT := Color(0.72, 0.26, 0.04)

var apartment_id: String = ""
var player: Node = null
var is_in_range: bool = false
var is_selected: bool = false

var _t: float = 0.0
var _tex: Texture2D = null
var _light: PointLight2D = null


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	_tex = FL.light_texture()   # soft round cookie, shared — used for halo + core glow
	# Real light so the orb has physical presence (a warm pool on the wall/floor). Energy is
	# driven per-frame in _process; 0 when not scavenging / out of range so it never lights
	# a room the player isn't searching.
	_light = PointLight2D.new()
	_light.texture = _tex
	_light.color = Color(1.0, 0.72, 0.34)
	_light.energy = 0.0
	_light.texture_scale = 0.16
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
	# Drive the real light to match the orb's heat, with the same gentle pulse.
	var lvl = _activity()
	if _light != null:
		var pulse = 1.0 + 0.10 * sin(_t * 3.2)
		_light.energy = lvl * 0.75 * pulse
		_light.texture_scale = 0.12 + 0.10 * lvl
	queue_redraw()


func _draw() -> void:
	var lvl = _activity()
	if lvl <= 0.0:
		return
	var pulse = 1.0 + 0.06 * sin(_t * 3.2)
	var r = lerpf(6.0, 10.5, lvl) * pulse

	# Soft glow halo (baked round cookie), so the orb reads as glowing even on unlit art.
	_blit(_tex, r * 3.2, Color(1.0, 0.6, 0.22, 0.10 * lvl))
	_blit(_tex, r * 2.0, Color(1.0, 0.68, 0.28, 0.14 * lvl))

	# Rotating corona flares (spin + flicker).
	var rays = 12
	for i in range(rays):
		var a = _t * 0.6 + float(i) * TAU / float(rays)
		var flick = 0.6 + 0.4 * sin(_t * 4.0 + float(i) * 1.7)
		var dir = Vector2(cos(a), sin(a))
		draw_line(dir * (r * 1.05), dir * (r * (1.35 + 0.55 * flick)),
			Color(FLARE.r, FLARE.g, FLARE.b, 0.5 * lvl * flick), maxf(1.0, r * 0.11))

	# Sphere body: rim -> mid -> hot -> core, each inner disc nudged toward the upper-left
	# "light" so the bright core sits off-centre and the disc reads as a lit sphere, not a flat coin.
	var hl = Vector2(-1, -1).normalized()
	draw_circle(Vector2.ZERO, r, RIM)
	draw_circle(hl * (r * 0.12), r * 0.82, MID)
	draw_circle(hl * (r * 0.30), r * 0.55, HOT)
	# Rotating sunspots (each an ellipse path = a point going around a sphere), BEFORE the
	# core so it still burns brightest on top. Distinct radii / speeds / phases so they scatter
	# as surface mottling and never line up into a symmetric "face".
	for s in [[0.52, 0.26, 1.3, 0.0], [0.32, 0.44, -0.95, 2.4], [0.62, 0.16, 1.75, 4.1]]:
		var sa = _t * s[2] + s[3]
		var sp = Vector2(cos(sa) * r * s[0], sin(sa * 0.7) * r * s[1])
		draw_circle(sp, r * 0.09, Color(SUNSPOT.r, SUNSPOT.g, SUNSPOT.b, 0.38 * lvl))
	draw_circle(hl * (r * 0.5), r * 0.30, CORE)
	# Soft hot bloom on the core.
	_blit(_tex, r * 0.9, Color(1.0, 0.95, 0.8, 0.5 * lvl))


func _blit(tex: Texture2D, radius: float, col: Color) -> void:
	# Draw the round cookie centred at the origin, sized to `radius`.
	draw_texture_rect(tex, Rect2(-radius, -radius, radius * 2.0, radius * 2.0), false, col)


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
