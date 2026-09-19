extends Marker2D

const GLOW_DISTANCE = 80.0
const INTERACT_DISTANCE = 50.0

const FL = preload("res://scripts/floor_lighting.gd")

# --- Scavenge marker: a glowing TRANSLUCENT orb ------------------------------
# Replaces the old flat circle. A small luminous orb — soft radial layers built from the round
# cookie (bright centre → transparent edge), so it reads as glowing LIGHT you can see through,
# NOT a solid marble (an opaque baked sphere read as a bead). A soft drifting glint gives a
# subtle shine + gentle-rotation cue, a small bob gives weight, and a TIGHT little glow hugs it.
# A modest REAL PointLight2D gives it presence without flooding the room. GOLDEN while it still
# holds an untaken item you HAVEN'T searched; once SEARCHED-but-not-emptied it turns pale
# WHITE/colourless — drained but still glowing + distinct so a looked-in node reads apart.
# Palette = a BODY tint + SPEC/GLOW/LIGHT accents.
const GOLD := {
	"body": Color(1.00, 0.80, 0.22), "spec": Color(1.00, 0.98, 0.86),
	"glow": Color(1.00, 0.80, 0.30), "light": Color(1.00, 0.78, 0.34),
}
const PALE := {
	"body": Color(0.86, 0.89, 0.95), "spec": Color(1.00, 1.00, 1.00),
	"glow": Color(0.88, 0.92, 1.00), "light": Color(0.88, 0.92, 1.00),
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
	_tex = FL.light_texture()          # soft round cookie (bright centre → transparent edge)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR   # smooth the scaled cookie
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
		# A bit brighter/wider than before, still a tight pool — presence, not a floodlight.
		_light.energy = lvl * 0.6 * pulse
		_light.texture_scale = 0.06 + 0.04 * lvl
	queue_redraw()


func _palette() -> Dictionary:
	# GOLD until the anchor has been searched; PALE (colourless) after, if it still holds an item.
	return PALE if WorldState.is_anchor_searched(apartment_id, name) else GOLD


func _draw() -> void:
	var lvl = _activity()
	if lvl <= 0.0:
		return
	# The whole glowing-orb look lives in the shared static draw_orb() so world-drop pickups
	# (enemy/floor loot) render the EXACT same orb. base_r pre-pulse; the helper adds pulse+bob.
	draw_orb(self, _tex, Vector2.ZERO, lerpf(5.5, 8.5, lvl), _palette(), _t, lvl)


# Shared glowing-orb renderer — used by the scavenge marker AND by world_drop.gd so a dropped
# pickup is the same orb. A GLOWING TRANSLUCENT ball: soft radial layers from the round cookie
# (bright centre → transparent edge), see-through, no hard rim; a drifting glint (shine +
# gentle-rotation cue); a small bob for weight. `pal` = {body,spec,glow[,light]}; `lvl` 0..1
# scales overall brightness. Static so callers share one look — tweak here, it updates both.
static func draw_orb(ci: CanvasItem, tex: Texture2D, base_center: Vector2, base_r: float, pal: Dictionary, t: float, lvl: float) -> void:
	if lvl <= 0.0 or tex == null:
		return
	var pulse := 1.0 + 0.06 * sin(t * 3.0)
	var r := base_r * pulse
	var c := base_center + Vector2(0.0, sin(t * 2.0) * 0.9)   # gentle bob (a floating mote of light)
	_orb_layer(ci, tex, c, r * 2.0, pal["glow"], 0.20 * lvl)   # outer glow
	_orb_layer(ci, tex, c, r * 1.25, pal["body"], 0.50 * lvl)  # translucent body (see-through)
	_orb_layer(ci, tex, c, r * 0.72, pal["glow"], 0.58 * lvl)  # inner luminance
	_orb_layer(ci, tex, c, r * 0.36, pal["spec"], 0.98 * lvl)  # bright glowing heart (soft, no rim)
	var gpos := c + Vector2(-0.5, -0.6).normalized() * (r * 0.34) + Vector2(cos(t * 1.1), sin(t * 1.1)) * (r * 0.12)
	_orb_layer(ci, tex, gpos, r * 0.36, pal["spec"], 0.6 * lvl)   # drifting glint


static func _orb_layer(ci: CanvasItem, tex: Texture2D, center: Vector2, radius: float, col: Color, a: float) -> void:
	ci.draw_texture_rect(tex, Rect2(center.x - radius, center.y - radius, radius * 2.0, radius * 2.0),
		false, Color(col.r, col.g, col.b, a))


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
