extends Marker2D

const GLOW_DISTANCE = 80.0
const INTERACT_DISTANCE = 50.0

const FL = preload("res://scripts/floor_lighting.gd")

# --- Scavenge marker: a shiny physical orb -----------------------------------
# Replaces the old flat yellow/white circle. A small, appealing GLOWING SPHERE with real
# volume: a shaded body (rim → body → bright, lit from the upper-left = fake 3D), a soft
# specular glint that slowly ORBITS the surface (reads as gentle rotation + shine), a soft
# glow halo, a gentle bob + pulse (weight) — PLUS a REAL PointLight2D so it casts a warm
# pool into the room. GOLDEN while it still holds an untaken item you HAVEN'T searched;
# once SEARCHED-but-not-emptied (item left behind) it turns pale WHITE/colourless — drained
# of gold but still glowing and distinct so the player knows it's been looked in.
const GOLD := {
	"rim": Color(0.70, 0.50, 0.06), "body": Color(0.96, 0.74, 0.16),
	"bright": Color(1.00, 0.90, 0.46), "spec": Color(1.00, 0.99, 0.90),
	"glow": Color(1.00, 0.80, 0.30), "light": Color(1.00, 0.78, 0.34),
}
const PALE := {
	"rim": Color(0.54, 0.56, 0.60), "body": Color(0.82, 0.85, 0.90),
	"bright": Color(0.95, 0.97, 1.00), "spec": Color(1.00, 1.00, 1.00),
	"glow": Color(0.86, 0.90, 1.00), "light": Color(0.86, 0.90, 1.00),
}

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
	# Drive the real light to match the orb, with the same gentle pulse; colour follows the
	# orb's state (warm gold, or cool white once searched-but-not-emptied).
	var lvl = _activity()
	if _light != null:
		var pal = _palette()
		_light.color = pal["light"]
		var pulse = 1.0 + 0.10 * sin(_t * 3.2)
		_light.energy = lvl * 0.7 * pulse
		_light.texture_scale = 0.12 + 0.10 * lvl
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
	var r = lerpf(6.0, 10.0, lvl) * pulse
	# Gentle vertical bob for weight (a held object floating, breathing).
	var c = Vector2(0.0, sin(_t * 2.0) * 1.3)

	# Soft glow halo (baked round cookie) so the orb reads as glowing even on unlit art.
	_blit(c, r * 2.9, _a(pal["glow"], 0.09 * lvl))
	_blit(c, r * 1.9, _a(pal["glow"], 0.15 * lvl))

	# Shaded sphere: rim -> body -> bright, each inner disc nudged toward the upper-left
	# "light" so the bright side sits off-centre and it reads as a lit ball, not a flat coin.
	var hl = Vector2(-1, -1).normalized()
	draw_circle(c, r, pal["rim"])
	draw_circle(c + hl * (r * 0.14), r * 0.80, pal["body"])
	draw_circle(c + hl * (r * 0.34), r * 0.50, pal["bright"])

	# Specular glint that slowly ORBITS a small path in the upper hemisphere — the shine
	# drifting reads as the ball gently rotating. Soft (cookie) + a tiny hard hotspot.
	var gpos = c + hl * (r * 0.34) + Vector2(cos(_t * 1.1), sin(_t * 1.1)) * (r * 0.14)
	_blit(gpos, r * 0.55, _a(pal["spec"], 0.55 * lvl))
	draw_circle(gpos, r * 0.12, _a(pal["spec"], 0.9 * lvl))


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
