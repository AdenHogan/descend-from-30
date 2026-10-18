extends Marker2D

const GLOW_DISTANCE = 80.0
const INTERACT_DISTANCE = 50.0

const FL = preload("res://scripts/floor_lighting.gd")
# Prying a gun cabinet open breaks its glass (owner round 45: "there was no glass smashing SFX when opening the gun cabinet with a crowbar").
const CABINET_SMASH_STREAMS := [
	preload("res://assets/audio/impacts/glass_smash_0.wav"),
	preload("res://assets/audio/impacts/glass_smash_1.wav"),
	preload("res://assets/audio/impacts/glass_smash_2.wav"),
]
const CABINET_CRACK_STREAMS := [
	preload("res://assets/audio/impacts/impactWood_heavy_000.ogg"),
	preload("res://assets/audio/impacts/impactWood_heavy_001.ogg"),
	preload("res://assets/audio/impacts/impactWood_heavy_002.ogg"),
]
const GLASS_SHARDS := preload("res://scripts/glass_shards.gd")

# --- Scavenge marker: a STAR (unsearched) / a FLARE (searched, not emptied) -------------------
# Round 45 (owner: "the kitchen nodes are hard to see against white / mint walls"; five mocks, picked "C for unsearched and E for
# searched but not picked up"). The old pale-gold orb was ADDED light, so on a bright wall it was the wall's own colour and vanished.
# What reads on any wall is saturation, a DARK RIM, motion and a silhouette:
#   STAR  (unsearched): a hot-magenta body inside a dark plum rim, a white-hot core, three slowly turning diffraction spikes, a halo that
#                       breathes, and ten motes of dust that rise, drift and fade.
#   FLARE (searched, but something is still in it): a cream disc in a dark ring with a gold band, a cyan / magenta chromatic fringe, a
#                       cross of spikes and four lens ghosts on a diagonal - clearly NOT the unsearched star, so a looked-in node
#                       reads as 'been here, something is left'.
# Both are drawn UNSHADED (see unshaded_material): lit, they were multiplied by the night ambient and sank into the furniture. The
# real PointLight2D stays (a TIGHT cast pool) so the star still tints what is near it. World drops (enemy / floor loot) use the star.
# Palette = body / spec / glow / rim / light colours + a `style`.
const ORB_LIGHT_GAIN := 1.2
const STAR := {
	"style": "star",
	"body": Color(0.98, 0.18, 0.62), "spec": Color(1.00, 0.96, 1.00),
	"glow": Color(0.95, 0.12, 0.75), "rim": Color(0.25, 0.02, 0.22), "light": Color(1.00, 0.30, 0.75),
	"spike": Color(1.00, 0.75, 0.95), "dust": Color(1.00, 0.62, 0.95),
}
const FLARE := {
	"style": "flare",
	"body": Color(1.00, 0.97, 0.88), "spec": Color(1.00, 1.00, 1.00),
	"glow": Color(1.00, 0.97, 0.85), "rim": Color(0.12, 0.10, 0.20), "light": Color(0.92, 0.94, 1.00),
	"band": Color(1.00, 0.78, 0.20), "fringe_l": Color(0.10, 0.80, 1.00), "fringe_r": Color(1.00, 0.30, 0.60),
}
const DUST_COUNT := 10
const DUST_PERIOD := 2.4           # seconds a mote takes to rise and fade

var apartment_id: String = ""
var player: Node = null
var is_in_range: bool = false
var is_selected: bool = false
var back_spot: Node = null     # set by back_plane_spot.gd: a set-back node, reachable only from that spot

var _t: float = 0.0
var _tex: Texture2D = null
var _light: PointLight2D = null


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	_tex = FL.light_texture()          # soft round cookie (bright centre → transparent edge)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR   # smooth the scaled cookie
	material = unshaded_material()                      # the star shows as drawn, day or night
	# A MODEST real light so the orb has presence — small pool, not a floodlight (an earlier
	# version's big halo read as a giant glow). Driven per-frame in _process; 0 when not
	# scavenging / out of range so it never lights a room you're not searching.
	_light = PointLight2D.new()
	_light.texture = _tex
	_light.color = STAR["light"]
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
	is_in_range = dist <= INTERACT_DISTANCE and _plane_ok()
	if was_in_range and not is_in_range:
		WorldState.interaction_handled = false
	if has_meta("ruin_scrap"):
		_ruin_prompt(is_in_range)
	# Drive the real light to match the orb, with the same gentle pulse; colour follows the
	# orb's state (hot pink while unsearched, near-white once searched-but-not-emptied).
	var lvl = _activity()
	if _light != null:
		var pal = _palette()
		_light.color = pal["light"]
		var pulse = 1.0 + 0.08 * sin(_t * 3.2)
		# TIGHT cast pool — the 256px cookie at these scales gives a ~7-8px glow radius that hugs
		# the ~8px orb body (an earlier 0.06-0.10 scale threw a ~13px halo bigger than the orb).
		_light.energy = lvl * 0.5 * ORB_LIGHT_GAIN * pulse
		_light.texture_scale = 0.035 + 0.025 * lvl
	queue_redraw()


func _plane_ok() -> bool:
	# A node set back on furniture is only in reach from ITS back-plane spot; every other node only
	# from the walking line (never while stepped up at the bookshelf).
	var ps = player.get("back_spot") if player != null else null
	if back_spot != null:
		return ps == back_spot
	return ps == null


func _palette() -> Dictionary:
	# The STAR until the anchor has been searched; the FLARE after, if it still holds an item.
	return FLARE if WorldState.is_anchor_searched(apartment_id, name) else STAR


func _draw() -> void:
	var lvl = _activity()
	if lvl <= 0.0:
		return
	# The whole glowing-orb look lives in the shared static draw_orb() so world-drop pickups
	# (enemy/floor loot) render the EXACT same orb. base_r pre-pulse; the helper adds pulse+bob.
	draw_orb(self, _tex, Vector2.ZERO, lerpf(5.5, 8.5, lvl), _palette(), _t, lvl)


## One shared unshaded material for every orb node: the star / flare is its own light, so the room's ambient must not dim it.
static var _unshaded: CanvasItemMaterial = null


static func unshaded_material() -> CanvasItemMaterial:
	if _unshaded == null:
		_unshaded = CanvasItemMaterial.new()
		_unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _unshaded


# Shared marker renderer - used by the scavenge marker AND by world_drop.gd so a dropped pickup is the same star. `pal` is STAR or
# FLARE (its `style` picks the drawing); `lvl` 0..1 is the proximity level (size is the caller's `base_r`, brightness is `lvl`).
# Static so callers share one look - tweak here, it updates both. All sizes are fractions of the radius (so they follow `base_r`);
# the small constants below are the mocks' pixel sizes at 4x, divided down to world pixels.
static func draw_orb(ci: CanvasItem, tex: Texture2D, base_center: Vector2, base_r: float, pal: Dictionary, t: float, lvl: float) -> void:
	if lvl <= 0.0 or tex == null:
		return
	var k := minf(lvl * 1.25, 1.0)          # fully strong from 'in reach' (0.82) up; the far edge of the glow still shows at ~40%
	if pal.get("style", "star") == "flare":
		_draw_flare(ci, tex, base_center, base_r, pal, t, k)
	else:
		_draw_star(ci, tex, base_center, base_r, pal, t, k)


## C - the unsearched star.
static func _draw_star(ci: CanvasItem, tex: Texture2D, c: Vector2, base_r: float, pal: Dictionary, t: float, k: float) -> void:
	var r := base_r * 0.76
	var tw := 0.5 + 0.5 * sin(t * 4.1)
	var body: Color = pal["body"]
	var spike: Color = pal["spike"]
	_orb_layer(ci, tex, c, r * 2.3, pal["glow"], _a(0.30 + 0.12 * tw, k))                 # breathing halo
	_ring(ci, c, r * 0.70, r * 0.31, pal["rim"], _a(0.88, k))                             # the DARK RIM - the part that shows on white
	ci.draw_circle(c, r * 0.62, Color(body.r, body.g, body.b, _a(1.0, k)), true, -1.0, true)
	_orb_layer(ci, tex, c, r * 0.62, Color(1.0, 0.62, 0.85), _a(0.60, k))                 # a lighter heart on the body
	for i in range(3):                                                                    # three double-ended spikes = six rays
		_spike(ci, c, t * 0.25 + i * PI / 3.0, r * (1.9 + 0.5 * tw), 0.75, spike, _a(0.95, k))
	_orb_layer(ci, tex, c, r * 0.46, pal["spec"], _a(1.0, k))                             # white-hot core
	var dust: Color = pal["dust"]
	for i in range(DUST_COUNT):                                                           # motes: rise, drift, fade; staggered phases
		var ph := fposmod(t / DUST_PERIOD + float(i) / DUST_COUNT, 1.0)
		var ang := float(i) * 2.399 + t * 0.6
		var p := c + Vector2(cos(ang) * r * (0.5 + 1.5 * ph), -ph * r * 2.4 + sin(ang) * 1.5)
		var fade := sin(ph * PI)
		var tint := Color(dust.r, minf(dust.g + 0.3 * float(i % 2), 1.0), dust.b)
		_orb_layer(ci, tex, p, 1.5, tint, _a(0.95 * fade, k))
		_orb_layer(ci, tex, p, 0.65, Color.WHITE, _a(fade, k))


## E - the searched-but-not-emptied flare.
static func _draw_flare(ci: CanvasItem, tex: Texture2D, c: Vector2, base_r: float, pal: Dictionary, t: float, k: float) -> void:
	var r := base_r * 0.72
	var tw := 0.5 + 0.5 * sin(t * 3.0)
	var body: Color = pal["body"]
	_orb_layer(ci, tex, c + Vector2(-0.75, 0.0), r * 2.0, pal["fringe_l"], _a(0.22, k))   # chromatic fringe: cyan left, magenta right
	_orb_layer(ci, tex, c + Vector2(0.75, 0.0), r * 2.0, pal["fringe_r"], _a(0.22, k))
	_ring(ci, c, r * 0.80, r * 0.31, pal["rim"], _a(0.88, k))                             # dark ring
	ci.draw_circle(c, r * 0.70, Color(body.r, body.g, body.b, _a(1.0, k)), true, -1.0, true)
	_ring(ci, c, r * 0.52, r * 0.39, pal["band"], _a(0.80, k))                            # gold band
	for i in range(2):                                                                    # a cross of spikes with a slight wobble
		_spike(ci, c, float(i) * PI / 2.0 + 0.2 * sin(t), r * (3.0 + 0.8 * tw), 0.8, Color(1.0, 0.97, 0.85), _a(0.95, k))
	_orb_layer(ci, tex, c, r * 0.9, pal["spec"], _a(0.95, k))                             # white-hot core
	var ghosts := [-1.6, -0.9, 1.1, 1.9]                                                  # lens ghosts along a diagonal through the star
	for i in range(ghosts.size()):
		var f: float = ghosts[i]
		var col: Color = pal["fringe_l"] if i % 2 == 0 else pal["fringe_r"]
		_orb_layer(ci, tex, c + Vector2(f * r * 0.9, f * r * 0.45), 1.25 + 0.75 * float(i % 2), col, _a(0.55 + 0.3 * tw, k))


static func _a(base: float, k: float) -> float:
	return minf(base * k, 1.0)


static func _orb_layer(ci: CanvasItem, tex: Texture2D, center: Vector2, radius: float, col: Color, a: float) -> void:
	ci.draw_texture_rect(tex, Rect2(center.x - radius, center.y - radius, radius * 2.0, radius * 2.0),
		false, Color(col.r, col.g, col.b, a))


static func _ring(ci: CanvasItem, c: Vector2, radius: float, width: float, col: Color, a: float) -> void:
	ci.draw_arc(c, radius, 0.0, TAU, 40, Color(col.r, col.g, col.b, a), width, true)


## A double-ended needle through `c` along `ang`: full strength at the middle, fading to nothing at both tips (a diffraction spike).
static func _spike(ci: CanvasItem, c: Vector2, ang: float, length: float, half_w: float, col: Color, a: float) -> void:
	if a <= 0.0:
		return
	var dir := Vector2.from_angle(ang)
	var nrm := dir.orthogonal()
	var mid := Color(col.r, col.g, col.b, a)
	var tip := Color(col.r, col.g, col.b, 0.0)
	var pts := PackedVector2Array([
		c - dir * length, c - dir * length * 0.12 - nrm * half_w, c + dir * length * 0.12 - nrm * half_w,
		c + dir * length, c + dir * length * 0.12 + nrm * half_w, c - dir * length * 0.12 + nrm * half_w])
	ci.draw_polygon(pts, PackedColorArray([tip, mid, mid, tip, mid, mid]))


func try_interact() -> void:
	if not WorldState.is_scavenge_mode:
		return
	if not WorldState.interaction_handled:
		WorldState.interaction_handled = true
		if has_meta("ruin_scrap"):
			_take_ruin_scrap()
			return
		if name == WorldState.GUN_CABINET_ANCHOR and not _open_gun_cabinet():
			return
		if has_meta("dead_body") and not WorldState.is_anchor_searched(apartment_id, name):
			HUD.show_feedback(WorldState.dead_search_line(name))       # searching one of the dead
		_open_loot()


# A burnt-out flat's salvage (room.gd sets `ruin_scrap`): nothing to search — it is scrap, it says so, and one press takes it.
func is_ruin_scrap() -> bool:
	return has_meta("ruin_scrap") and visible


func _take_ruin_scrap() -> void:
	var amount: int = WorldState.get_anchor_amount(apartment_id, name)
	if WorldState.get_anchor_item(apartment_id, name) != "037" or amount <= 0:
		set_meta("ruin_scrap", false)
		remove_meta("ruin_scrap")
		_hide_permanently()
		return
	WorldState.add_to_inventory("037", amount)        # a scrap bag never takes a slot: it just adds to the counter
	WorldState.mark_anchor_searched(apartment_id, name)
	WorldState.clear_anchor_item(apartment_id, name)
	WorldState.note_scavenge(apartment_id)
	HUD.hide_world_prompt(self)
	remove_meta("ruin_scrap")
	_hide_permanently()


func _ruin_prompt(in_reach: bool) -> void:
	if not is_ruin_scrap():
		return
	if in_reach and WorldState.is_scavenge_mode and not WorldState.loot_open:
		HUD.show_world_prompt(self, "Scrap   [{interact}] Take", global_position + Vector2(0, -6))
	else:
		HUD.hide_world_prompt(self)


# A LOCKED gun cabinet (owner round 20): its key opens it, else a crowbar pries it (loud, spent).
# With neither it stays shut and says what it needs. True = open now, go on and search it.
func _open_gun_cabinet() -> bool:
	if WorldState.gun_cabinet_state(apartment_id) != "locked":
		return true
	if WorldState.has_cabinet_key(apartment_id):
		WorldState.open_gun_cabinet(apartment_id, "key")
		HUD.show_feedback("The little key turns. The cabinet swings open.")
	elif WorldState.has_crowbar():
		WorldState.open_gun_cabinet(apartment_id, "pry")
		WorldState.emit_noise(global_position, WorldState.NOISE_RADIUS["door_work"], 2.0)
		smash_cabinet_glass()
		HUD.show_feedback("You lever the door off its hinge. Glass everywhere — and loud.")
	else:
		HUD.show_feedback("Locked. There's a gun inside. It needs its key — or a crowbar.")
		return false
	get_tree().call_group("gun_cabinet_art", "refresh")
	return true


## The glass of a pried-open cabinet: the wood cracks, the pane goes (one of three smashes), and a burst of shards falls to the floor.
## The sound and the shards are separate nodes on this node's parent that free themselves, so they outlast the search panel.
func smash_cabinet_glass() -> void:
	var holder: Node = get_parent()
	if holder == null or not is_inside_tree():
		return
	var glass := AudioStreamPlayer2D.new()
	glass.stream = CABINET_SMASH_STREAMS.pick_random()
	glass.pitch_scale = randf_range(0.92, 1.06)
	glass.volume_db = 2.0
	glass.max_distance = 900.0
	var crack := AudioStreamPlayer2D.new()
	crack.stream = CABINET_CRACK_STREAMS.pick_random()
	crack.pitch_scale = randf_range(0.8, 0.95)
	crack.volume_db = -2.0
	crack.max_distance = 900.0
	for pl in [crack, glass]:
		holder.add_child(pl)
		pl.global_position = global_position
		pl.finished.connect(pl.queue_free)
		pl.play()
	var shards = GLASS_SHARDS.new()
	holder.add_child(shards)
	shards.global_position = global_position
	shards.burst(1.0 if randf() < 0.5 else -1.0)


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
