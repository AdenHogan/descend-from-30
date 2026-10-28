extends Area2D

const PICKUP_RANGE = 40.0
const GLOW_RANGE = 80.0

const ORB := preload("res://scripts/interactable.gd")   # shared glowing-orb renderer + palette
const FL := preload("res://scripts/floor_lighting.gd")

# Toss physics for a fresh enemy drop: it flies out of the corpse, falls, bounces a little,
# and settles ON the floor plane near the corpse (never suspended in the air).
const GRAVITY := 900.0
const REST_LIFT := 7.0        # orb centre rests this far above the floor line so it sits ON it
const ORB_BASE_R := 8.0
const THROWN_SPEED := Vector2(170.0, 230.0)   # px/s sideways for an item thrown out of the pack (it comes to rest ~80-155 px away)
const WALL_GAP := 8.0         # a drop comes to rest this far in front of a wall

var item_id: String = ""
var target_apartment: String = ""
var drop_key: String = ""
var amount: int = 0  # Bank Notes bundle size; 0 = roll default on pickup
var instance_data: Dictionary = {}  # a DISCARDED item's full state — picked up as that same item

var player: Node2D = null
var player_nearby: bool = false

var _t: float = 0.0
var _tex: Texture2D = null
var _light: PointLight2D = null
# Toss state
var _tossing: bool = false
var _vel: Vector2 = Vector2.ZERO
var _rest_y: float = 0.0
var _bounces: int = 0
var _x_lo: float = -1.0e9      # the nearest wall each side of the corpse: a tossed drop never passes it
var _x_hi: float = 1.0e9
var _hud_checked: bool = false  # has this drop been moved out from under a HUD widget yet (see _clear_of_hud)

@onready var proximity_label: Label = $ProximityLabel


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	# The prompt is drawn by the HUD in SCREEN space (crisp, in-bounds), not by
	# this world-space Label — hide the old one entirely.
	proximity_label.visible = false
	add_to_group("world_drop")
	player = get_tree().get_first_node_in_group("player")
	if item_id == "036" and ResourceLoader.exists(EXTINGUISHER_ART):
		_ext_tex = load(EXTINGUISHER_ART)
	# The glowing-orb pickup (matches the scavenge marker). The extinguisher (036) is a wall
	# fixture, not an orb, so it gets no orb light.
	if item_id != "036":
		_tex = FL.light_texture()
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		material = ORB.unshaded_material()      # the star shows as drawn, day or night (the fixture below stays lit)
		z_index = CorpseDepth.Z + 1             # over a body lying in front of the player (z 2): loot tossed out of a corpse must not land behind it
		_light = PointLight2D.new()
		_light.texture = _tex
		_light.color = ORB.STAR["light"]
		_light.energy = 0.0
		_light.texture_scale = 0.06
		_light.z_index = 0
		add_child(_light)


func toss(from_pos: Vector2, land_y: float, dir_x: float, thrown: bool = false) -> void:
	# Start a fresh drop flying out of the corpse; it settles at the floor line near it. `thrown`: an item the player dragged out of the pack to one side
	# (owner round 48h) goes FAR enough to clear what lies at their feet - a corpse's loot just falls out beside it.
	global_position = from_pos
	_rest_y = land_y - REST_LIFT
	if global_position.y >= _rest_y:
		global_position.y = _rest_y - 2.0   # nudge above the floor so it visibly drops
	var speed: float = randf_range(THROWN_SPEED.x, THROWN_SPEED.y) if thrown else randf_range(45.0, 95.0)
	_vel = Vector2(dir_x * speed, -randf_range(150.0, 220.0))
	_bounces = 0
	_find_walls(from_pos)
	_tossing = true
	_hud_checked = false


## A drop used to fly straight through the end wall of the corridor (a kill beside the stairwell left cash and a hammer at x 76-111,
## behind the wall at 128 — unreachable; found by the descent bot, round 44). Look for the static wall either side of the corpse
## and clamp the toss to it. Bodies of actors (the player, the dead) are not walls: the ray skips them.
func _find_walls(from: Vector2) -> void:
	_x_lo = -1.0e9
	_x_hi = 1.0e9
	if not is_inside_tree():
		return
	var space := get_world_2d().direct_space_state
	if space == null:
		return
	for sgn in [-1.0, 1.0]:
		var exclude: Array[RID] = []
		for _i in range(8):
			var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(sgn * 240.0, 0.0), 1, exclude)
			var hit: Dictionary = space.intersect_ray(q)
			if hit.is_empty():
				break
			var col = hit["collider"]
			if col is StaticBody2D or col is TileMapLayer:
				if sgn < 0.0:
					_x_lo = float(hit["position"].x) + WALL_GAP
				else:
					_x_hi = float(hit["position"].x) - WALL_GAP
				break
			exclude.append(hit["rid"])


func _physics_process(delta: float) -> void:
	if not _tossing:
		return
	_vel.y += GRAVITY * delta
	global_position += _vel * delta
	if global_position.x < _x_lo or global_position.x > _x_hi:
		global_position.x = clampf(global_position.x, _x_lo, _x_hi)
		_vel.x = 0.0
	if global_position.y >= _rest_y and _vel.y > 0.0:
		global_position.y = _rest_y
		_bounces += 1
		if _bounces >= 3 or absf(_vel.y) < 55.0:
			_tossing = false
			_vel = Vector2.ZERO
			_sync_registered_x()
		else:
			_vel.y = -_vel.y * 0.42     # each bounce loses most of its energy
			_vel.x *= 0.55


# --- never under the HUD (owner round 45) ------------------------------------------------------------------------------------------------
# A drop that came to rest at the far-left wall lay UNDER the portrait: the portrait hid it, and a click there was swallowed by the drop
# (the pickup claims its click), so with a full pack the item could not be taken AND the portrait could not be pressed. A drop is now moved
# out from under any HUD widget when it comes to rest, and a click on a HUD widget is never a pickup's.
const HUD_MARGIN_PX := 40.0     # the orb's own size on screen: its whole disc must clear the widget, not just its centre
const HUD_NUDGE_STEP := 6.0
const HUD_NUDGE_MAX := 90


## Where a world point is on screen (the click maths in reverse); Vector2.INF while there is no camera (a test, a scene change).
func _screen_of(world: Vector2) -> Vector2:
	var p = get_tree().get_first_node_in_group("player")
	var cam = p.get_node_or_null("Camera2D") if p != null else null
	if cam == null or not cam.is_inside_tree():
		return Vector2.INF
	return (world - cam.get_screen_center_position()) * cam.zoom + get_viewport().get_visible_rect().size / 2.0


func _under_hud(world: Vector2) -> bool:
	var sp := _screen_of(world)
	if sp == Vector2.INF:
		return false
	for off in [Vector2.ZERO, Vector2(HUD_MARGIN_PX, 0.0), Vector2(-HUD_MARGIN_PX, 0.0), Vector2(0.0, -HUD_MARGIN_PX)]:
		if HUD.pointer_over_widget(sp + off):
			return true
	return false


## Slide a resting drop sideways (away from the nearer screen edge, never past a wall) until no HUD widget covers it.
## True once it could be judged (there is a camera to judge by).
## The saved record of this drop says where it CAME TO REST (so a re-entry shows what you saw).
func _sync_registered_x() -> void:
	if drop_key != "" and WorldState.world_drops.has(drop_key):
		WorldState.world_drops[drop_key]["x"] = snappedf(global_position.x, 1.0)


func _clear_of_hud() -> bool:
	var sp := _screen_of(global_position)
	if sp == Vector2.INF:
		return false
	if not _under_hud(global_position):
		return true
	if _x_lo < -1.0e8 and _x_hi > 1.0e8:
		_find_walls(global_position)
	var dir: float = 1.0 if sp.x < get_viewport().get_visible_rect().size.x * 0.5 else -1.0
	for _i in range(HUD_NUDGE_MAX):
		var x: float = global_position.x + dir * HUD_NUDGE_STEP
		if x < _x_lo or x > _x_hi:
			break
		global_position.x = x
		if not _under_hud(global_position):
			break
	return true


var _compare_key: String = ""
var _compare_text: String = ""


func _prompt_text() -> String:
	if target_apartment != "":
		return WorldState.key_display(target_apartment) + "   [Click] Take"
	var item_data = ItemData.get_item(item_id)
	var display_name = item_data.get("name", "Item") if not item_data.is_empty() else "Item"
	var text: String = display_name + "   [Click] Take"
	if item_data.get("is_weapon", false):                                    # what it is against the weapon in hand, in a line (ItemCompare)
		var held = ItemCompare.held_weapon()
		var key: String = "%s|%s|%d|%d" % [item_id, "" if held == null else held.item_id, 0 if held == null else held.current_durability, 0 if held == null else held.level]
		if key != _compare_key:                                              # (this runs every frame: build the line only when the two weapons change)
			_compare_key = key
			var inst := ItemInstance.new()
			inst.setup(item_id)
			_compare_text = ItemCompare.pill_suffix(ItemCompare.card(inst, held))
		if _compare_text != "":
			text += "   ·   " + _compare_text
	return text


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = body
		player_nearby = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_nearby = false
		HUD.hide_world_prompt(self)


func _input(event: InputEvent) -> void:
	if not player_nearby:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if HUD.pointer_over_widget(event.position):
			return                              # that click is the HUD's (the portrait, the pack button): never a pickup's
		if _is_mouse_over_orb(event.position):
			if focus_drop(get_tree(), event.position) != self:
				return                          # a click is ONE pickup's: the nearest to the pointer, not every drop within 40 px of it
			# A scavenge node under the pointer and nearer to it than this drop owns the click (owner round 48i: "this baseball bat item is lower and has taken priority in the
			# selection… Scavenge node is unsearchable as a result"): the drop's reach is 40 px, a node's click circle 10.
			if _node_has_the_click(event.position):
				return
			var vp := get_viewport()
			# Only a pickup that DID something claims the click (nothing behind it — a stairwell, a door — may also act on it). A drop the full bag can't take lets the click go on
			# (to the node under it, to click-to-move), after its "Inventory full." line.
			if _try_pickup():
				vp.set_input_as_handled()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	# Drive the orb's cast light to match its on-screen brightness (proximity fade).
	if _light != null:
		var lvl := _orb_level()
		var pulse := 1.0 + 0.08 * sin(_t * 3.2)
		# TIGHT cast pool that hugs the orb body (matches interactable.gd — no oversized halo).
		_light.energy = lvl * 0.5 * ORB.ORB_LIGHT_GAIN * pulse
		_light.texture_scale = 0.035 + 0.025 * lvl
	if not _tossing and not _hud_checked and item_id != "036":
		_hud_checked = _clear_of_hud()
		if _hud_checked:
			_sync_registered_x()
	if not player_nearby:
		return
	var focused: bool = focus_drop(get_tree()) == self
	if focused:
		HUD.show_world_prompt(self, _prompt_text(), global_position)
	else:
		HUD.hide_world_prompt(self)
	if focused and Input.is_action_just_pressed("interact"):
		_try_pickup()


func _orb_level() -> float:
	# 0..1 brightness by proximity (full inside pickup range, fading out to the glow edge).
	if player == null:
		return 0.0
	var dist := global_position.distance_to(player.global_position)
	if dist > GLOW_RANGE:
		return 0.0
	return 1.0 - clampf((dist - PICKUP_RANGE) / (GLOW_RANGE - PICKUP_RANGE), 0.0, 1.0)


## Where `at` (the click's own position — a touch tap has no resting mouse; default = the pointer) is in the WORLD, or Vector2.INF with no player / camera.
func _pointer_world(at: Vector2 = Vector2.INF) -> Vector2:
	var p = get_tree().get_first_node_in_group("player")
	if p == null:
		return Vector2.INF
	var cam = p.get_node_or_null("Camera2D")
	if cam == null:
		return Vector2.INF
	return cam.get_screen_center_position() + \
		((get_viewport().get_mouse_position() if at == Vector2.INF else at) - get_viewport().get_visible_rect().size / 2) / cam.zoom


func _is_mouse_over_orb(at: Vector2 = Vector2.INF) -> bool:
	var mouse_world := _pointer_world(at)
	return mouse_world != Vector2.INF and global_position.distance_to(mouse_world) <= PICKUP_RANGE


const NODE_CLICK_RADIUS := 10.0        # room.CLICK_RADIUS: a scavenge node is "under the pointer" inside this

static var _focus_frame: int = -1
static var _focus_at: Vector2 = Vector2.INF
static var _focus: Node = null


## THE drop a click / [interact] would take (owner round 48i: "too much clutter in text and choice" - three pickups lying together each posted their own "[Click] Take" pill, on top of
## one another, and one press took them all). Of the drops in reach it is the one nearest the pointer when the pointer is over any of them (`at` = where a click landed), else the one
## nearest the player. Only that drop shows its prompt; a click or [interact] takes that one and no other. Cached per frame.
static func focus_drop(tree: SceneTree, at: Vector2 = Vector2.INF) -> Node:
	var frame := Engine.get_process_frames()
	if frame == _focus_frame and at == _focus_at and is_instance_valid(_focus):
		return _focus
	var best: Node = null
	var best_d := INF
	var best_pointer := false
	for d in tree.get_nodes_in_group("world_drop"):
		if not is_instance_valid(d) or not d.player_nearby or d.is_queued_for_deletion():
			continue
		var pw: Vector2 = d._pointer_world(at)
		if at == Vector2.INF and SettingsManager.last_device != "kbm":
			pw = Vector2.INF                    # a pad / a phone has no resting pointer: the nearest to the player is the one
		var over: bool = pw != Vector2.INF and d.global_position.distance_to(pw) <= PICKUP_RANGE
		var dist: float = d.global_position.distance_to(pw) if over else (d.global_position.distance_to(d.player.global_position) if d.player != null else INF)
		if (over and not best_pointer) or (over == best_pointer and dist < best_d):
			best = d
			best_d = dist
			best_pointer = over
	_focus_frame = frame
	_focus_at = at
	_focus = best
	return best


## Is a scavenge node in reach under the pointer AND nearer to it than this drop? Then the click is the node's.
func _node_has_the_click(at: Vector2) -> bool:
	var pw := _pointer_world(at)
	if pw == Vector2.INF:
		return false
	var mine := global_position.distance_to(pw)
	for n in get_tree().get_nodes_in_group("scavenge_anchor"):
		if not is_instance_valid(n) or not n.visible or n.get("is_in_range") == false:
			continue
		var d: float = n.global_position.distance_to(pw)
		if d <= NODE_CLICK_RADIUS and d < mine:
			return true
	return false


func _try_pickup() -> bool:
	var added: bool
	if target_apartment != "":
		added = WorldState.add_key_to_inventory(target_apartment)
		if added:
			HUD.show_feedback(WorldState.key_display(target_apartment) + " picked up.")
			HUD.refresh_inventory()
		else:
			HUD.show_feedback("Inventory full.", true)
			return false
	elif not instance_data.is_empty():
		added = WorldState.add_instance_to_inventory(WorldState.instance_from_dict(instance_data))
		if added:
			HUD.show_feedback(ItemData.get_item(item_id).get("name", "Item") + " picked up.")
			HUD.refresh_inventory()
		else:
			HUD.show_feedback("Inventory full.", true)
			return false
	elif ItemData.get_item(item_id).get("is_ammo", false):
		# Bullets that don't wholly fit the pockets load a gun carried (owner round 48h); what fits nowhere stays on the floor.
		var res: Dictionary = WorldState.take_found_ammo(item_id, amount)
		if int(res["left"]) > 0:
			if int(res["to_gun"]) + int(res["to_pack"]) > 0:
				amount = int(res["left"])
				if drop_key != "" and WorldState.world_drops.has(drop_key):
					WorldState.world_drops[drop_key]["amount"] = amount
				HUD.show_feedback(str(res["msg"]))
				HUD.refresh_inventory()
				return true                      # some of it went into the gun / the pack: the click did something, the rest stays on the floor
			HUD.show_feedback("Inventory full.", true)
			return false
		HUD.show_feedback(str(res["msg"]) if str(res["msg"]) != "" else ItemData.get_item(item_id).get("name", "Item") + " picked up.")
		HUD.refresh_inventory()
	else:
		added = WorldState.add_to_inventory(item_id, amount)
		if added:
			var item_data = ItemData.get_item(item_id)
			HUD.show_feedback(item_data.get("name", "Item") + " picked up.")
			HUD.refresh_inventory()
		else:
			HUD.show_feedback("Inventory full.", true)
			return false
	if drop_key != "":
		WorldState.remove_world_drop(drop_key)
	HUD.hide_world_prompt(self)
	queue_free()
	return true


func _exit_tree() -> void:
	# Freed while the player was still in range (scene change, etc.) — don't leave
	# the HUD prompt pointing at a gone item.
	if player_nearby:
		HUD.hide_world_prompt(self)


func _draw() -> void:
	# The wall-mounted fire extinguisher is a fixed FIXTURE — drawn always (not a
	# floor glow orb that only shows up close), so you can spot it across the corridor.
	if item_id == "036":
		_draw_extinguisher()
		return
	# Every other pickup is the same glowing orb as a scavenge marker (gold), fading in by
	# proximity. A key drop reads a touch bigger so it stands out as an objective.
	var lvl := _orb_level()
	if lvl <= 0.0:
		return
	var base_r := ORB_BASE_R + (2.0 if target_apartment != "" else 0.0)
	ORB.draw_orb(self, _tex, Vector2.ZERO, base_r, ORB.STAR, _t, lvl)


const EXTINGUISHER_ART := "res://assets/corridor/fixtures/extinguisher_wall.png"   # tools/art/fixtures.py
var _ext_tex: Texture2D = null     # loaded in _ready — a texture first load()ed INSIDE _draw came out a white
                                   # block, and this node only redraws now and then, so it stuck


func _draw_extinguisher() -> void:
	# A wall-mounted extinguisher (drawn art: bracket straps, hose, gauge, lever), its body spanning
	# local y -18..16 up on the wall. Brightens when you're in range. Falls back to plain rects if the art
	# is missing.
	var w := 11.0
	var h := 34.0
	var top := -18.0
	var glow := 0.0
	if player != null:
		var dist := global_position.distance_to(player.global_position)
		glow = 1.0 - clamp((dist - PICKUP_RANGE) / (GLOW_RANGE - PICKUP_RANGE), 0.0, 1.0)
	if _ext_tex != null:
		var tex: Texture2D = _ext_tex
		# the art is 16x44 with its cylinder at x 3..12, y 13..40: put its foot where the old canister's was
		# (local y +16) and centre it on x 0
		draw_texture(tex, Vector2(-8.0, top + h - 40.0))
		if glow > 0.0:
			draw_rect(Rect2(-5.0, top + h - 27.0, 10.0, 28.0), Color(1.0, 1.0, 1.0, 0.30 * glow), false, 2.0)
		return
	# wall bracket behind the canister
	draw_rect(Rect2(-w * 0.5 - 3.0, top + h - 7.0, w + 6.0, 4.0), Color(0.20, 0.20, 0.22))
	# red body
	draw_rect(Rect2(-w * 0.5, top, w, h), Color(0.82, 0.11, 0.11))
	# white label band
	draw_rect(Rect2(-w * 0.5, top + h * 0.34, w, h * 0.30), Color(0.95, 0.95, 0.95))
	# dark handle / nozzle on top
	draw_rect(Rect2(-2.0, top - 6.0, 4.0, 7.0), Color(0.13, 0.13, 0.13))
	# pickable highlight when near
	if glow > 0.0:
		draw_rect(Rect2(-w * 0.5, top, w, h), Color(1.0, 1.0, 1.0, 0.30 * glow), false, 2.0)
