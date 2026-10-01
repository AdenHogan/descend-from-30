extends Area2D

# A RESIDENT — a survivor still holed up behind a locked door (owner round 32: "shout at the player
# when inside demanding the player leaves, moving towards, running around, even threatening with
# weapons. If player scavenges items, NPCs can beg not to, might get violent, or offer to trade").
#
# Who lives where, their temper, weapon and pockets: WorldState "RESIDENTS" (seeded per flat + run,
# saved). Every word they say: data/npc_dialogue.json (owner-authored pools, picked at random).
#
# Three tempers:
#   SCARED  — keeps away from you, RUNS when you come close, cowers in a corner (and, cornered too
#             long, some lash out once or dash past you to the other side); begs when you search.
#   HOSTILE — armed; squares up at arm's length, paces, shouts, brandishes the weapon. Searching
#             gets ONE warning; a second search, taking anything, or crowding them = they attack.
#   TRADER  — wary, keeps its distance; when you start going through their things it offers a swap
#             (their goods for something in your pack) — [Trade] / [No] in its speech bubble, or the
#             interact key. Rob them after an offer and some turn on you.
# Hit any of them and they react (scared flee or snap, the others fight). They can die; they drop
# their weapon and what's in their pockets.
#
# SOFTLOCK-SAFE by construction: an Area2D with no collision layers — it never blocks or shoves the
# player, whatever it does. It is a melee / gun / push target through the "resident_target" group
# (player._combat_targets), never the "zombie" group, so no zombie system (memory, crowds, noise,
# cans) ever touches it.

const ENEMY_PLANE := preload("res://scripts/enemy_plane.gd")
const UI_FONT := preload("res://assets/fonts/PixelOperator8.ttf")
const ART := "res://assets/homeless-character-pixel-art-pack/%d/%s.png"
const FRAME := 48
const SPRITE_SCALE := 1.6          # the pack is drawn taller than the player's rig: 1.6x stands them level (~54 px)
const FEET_Y := 353.0              # room.ROOM_FEET_Y — the flat's walking line
const WALK := 40.0
const RUN := 95.0
const STANDOFF := 72.0             # a hostile resident squares up this far from you
const TRADER_KEEP := 92.0          # a trader keeps you this far off
const KEEP_AWAY := 150.0           # a scared one runs if you come nearer than this
const TOO_CLOSE := 44.0
const REACH := 30.0
const WINDUP := 0.45
const ATTACK_CD := 1.4
const CLOSE_GRACE := 1.6           # warned hostile: stay this long within TOO_CLOSE and it swings
const CORNER_TIME := 2.2           # a scared one cornered this long snaps (or dashes past)
const HURT_TIME := 0.4
const SHOUT_MIN := 4.5
const SHOUT_MAX := 7.5
const CALM_AFTER := 4              # this many "get out"s with nothing happening, then it goes quiet
const THREAT_MIN := 6.0
const THREAT_MAX := 9.0
const OFFER_RANGE := 140.0         # how close you must be to take a trade
const OFFER_NEAR := 56.0           # a trader with a deal on comes this close to make it
const BUBBLE_MIN_TIME := 1.8
const ENTER_DELAY := 0.45
const WANT_SCORE := {"007": 9, "006": 8, "016": 7, "010": 7, "005": 6, "011": 5, "036": 5, "035": 5,
	"009": 4, "021": 4, "019": 4, "020": 4, "034": 3, "018": 3, "015": 3, "008": 2, "039": 4, "024": 1}

var apartment_id: String = ""
var rec: Dictionary = {}
var temper: String = "scared"
var weapon: String = ""
var look: int = 1
var current_hp: int = 3
var is_dead: bool = false
var violent: bool = false
var state: String = "wary"          # wary | flee | cower | dash | windup | hurt | dead
var on_fire: bool = false           # (never set — kept so fire code that asks finds a field)

var animated_sprite: AnimatedSprite2D = null
var _weapon_sprite: Sprite2D = null
var _bubble_layer: CanvasLayer = null
var _bubble: PanelContainer = null
var _bubble_label: Label = null
var _offer_row: HBoxContainer = null
var _bubble_t: float = 0.0

var last_moment: String = ""       # the last moment it spoke (tests read these)
var last_line: String = ""
var _last_by_moment: Dictionary = {}

var _t: float = 0.0
var _state_t: float = 0.0
var _attack_cd: float = 0.0
var _shout_t: float = 3.0
var _shouts: int = 0
var _calmed: bool = false
var _threat_t: float = 5.0
var _close_t: float = 0.0
var _said_close: bool = false
var _corner_t: float = 0.0
var _said_corner: bool = false
var _lashing: bool = false
var _dash_to: float = 0.0
var _push_v: float = 0.0
var _enter_t: float = ENTER_DELAY
var offer: Dictionary = {}          # {"give": {id, amount}, "get": ItemInstance} while a swap is on the table
var _pace_phase: float = 0.0
var _met_before: int = 0


## Lays a resident into `room` from its record. `x` < 0 = its seeded spot, at the far end from the door.
static func spawn(room: Node, apt_id: String, record: Dictionary, entrance_side: String) -> Node:
	var n = load("res://scripts/resident_npc.gd").new()
	n.name = "Resident"
	n.apartment_id = apt_id
	n.rec = record
	var x: float = float(record.get("x", -1.0))
	if x < 0.0:
		# The far module from the front door (they keep away from it), somewhere in its middle.
		var far_mod := 2 if entrance_side == "left" else 0
		x = 113.0 + far_mod * 320.0 + 70.0 + float(record.get("spot", 0.5)) * 180.0
	n.position = Vector2(x, FEET_Y)
	room.add_child(n)
	return n


func _ready() -> void:
	add_to_group("resident_npc")
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false
	z_index = 1
	temper = str(rec.get("temper", "scared"))
	weapon = str(rec.get("weapon", ""))
	look = int(rec.get("look", 1))
	current_hp = int(rec.get("hp", WorldState.RESIDENT_HP.get(temper, 3)))
	violent = bool(rec.get("violent", false))
	_pace_phase = float(rec.get("spot", 0.0)) * TAU
	var cs := CollisionShape2D.new()
	cs.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, 48)
	cs.shape = shape
	cs.position = Vector2(0, -24)       # feet on the origin: drop_item_from reads the feet off this
	add_child(cs)
	_build_sprite()
	_build_weapon()
	_build_bubble()
	if bool(rec.get("dead", false)):
		_lie_dead()
		return
	add_to_group("resident_target")
	_met_before = int(rec.get("met", 0))
	WorldState.update_resident(apartment_id, {"met": _met_before + 1})


func _build_sprite() -> void:
	animated_sprite = AnimatedSprite2D.new()
	animated_sprite.name = "AnimatedSprite2D"
	animated_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	animated_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	animated_sprite.offset = Vector2(0, -FRAME * 0.5)      # the frame's bottom row (the feet) on the origin
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for spec in [["Idle", 6.0, true], ["Walk", 10.0, true], ["Special", 11.0, false], ["Hurt", 6.0, false], ["Death", 9.0, false]]:
		var path := ART % [look, spec[0]]
		if not ResourceLoader.exists(path):
			continue
		var tex: Texture2D = load(path)
		sf.add_animation(spec[0])
		sf.set_animation_speed(spec[0], spec[1])
		sf.set_animation_loop(spec[0], spec[2])
		for i in int(float(tex.get_width()) / FRAME):
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * FRAME, 0, FRAME, FRAME)
			sf.add_frame(spec[0], at)
	animated_sprite.sprite_frames = sf
	add_child(animated_sprite)
	_play("Idle")


func _build_weapon() -> void:
	# The look with a stick carries its bat in its own art; anyone else holding something shows it in
	# hand (the item's icon, small — placeholder until resident art exists).
	if weapon == "" or look == WorldState.RESIDENT_STICK_LOOK:
		return
	var tex = ItemData.get_texture(weapon)
	if tex == null:
		return
	_weapon_sprite = Sprite2D.new()
	_weapon_sprite.name = "Weapon"
	_weapon_sprite.texture = tex
	_weapon_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_weapon_sprite.scale = Vector2(0.3, 0.3)
	_weapon_sprite.visible = false
	add_child(_weapon_sprite)


func _build_bubble() -> void:
	# Speech in SCREEN space (crisp at any zoom), pinned over the resident's head every frame.
	_bubble_layer = CanvasLayer.new()
	_bubble_layer.name = "Speech"
	_bubble_layer.layer = 2
	add_child(_bubble_layer)
	_bubble = PanelContainer.new()
	_bubble.name = "Bubble"
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.06, 0.86)
	sb.border_color = {"scared": Color(0.75, 0.78, 0.85), "hostile": Color(0.85, 0.32, 0.26),
		"trader": Color(0.88, 0.72, 0.36)}.get(temper, Color(0.8, 0.8, 0.8))
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(5)
	sb.set_content_margin_all(7)
	_bubble.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 6)
	_bubble.add_child(vb)
	_bubble_label = Label.new()
	_bubble_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble_label.add_theme_font_override("font", UI_FONT)
	_bubble_label.add_theme_font_size_override("font_size", 14)
	_bubble_label.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88))
	_bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble_label.custom_minimum_size = Vector2(250, 0)
	_bubble_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_bubble_label)
	_offer_row = HBoxContainer.new()
	_offer_row.name = "Offer"
	_offer_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_offer_row.add_theme_constant_override("separation", 10)
	_offer_row.visible = false
	vb.add_child(_offer_row)
	for spec in [["Trade", accept_trade], ["No", decline_trade]]:
		var b := Button.new()
		b.name = spec[0]
		b.text = spec[0]
		b.add_theme_font_override("font", UI_FONT)
		b.add_theme_font_size_override("font_size", 14)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(spec[1])
		_offer_row.add_child(b)
	_bubble.visible = false
	_bubble_layer.add_child(_bubble)
	_bubble.add_to_group("hud_widget_extra")        # HUD.pointer_over_widget: a click on it isn't a swing / a walk


# --- speech ------------------------------------------------------------------------------------

## Says a line for `moment` from the dialogue file (never the same line twice running). "" = silent.
func say(moment: String, hold: float = 0.0) -> String:
	var pool = WorldState.resident_lines().get(temper, {}).get(moment, [])
	if not (pool is Array) or pool.is_empty():
		return ""
	var i: int = randi() % pool.size()
	if pool.size() > 1 and i == int(_last_by_moment.get(moment, -1)):
		i = (i + 1) % pool.size()
	_last_by_moment[moment] = i
	var line := _fill(str(pool[i]))
	last_moment = moment
	last_line = line
	_bubble_label.text = line
	_bubble.visible = true
	_bubble.reset_size()
	_bubble_t = maxf(hold, BUBBLE_MIN_TIME + 0.05 * line.length())
	return line


func _fill(line: String) -> String:
	if offer.is_empty():
		return line
	return line.replace("{give}", _item_name(offer["give"]["id"])).replace("{get}", _item_name(offer["get"].item_id))


func _item_name(id: String) -> String:
	return str(ItemData.get_item(id).get("name", "that"))


func _update_bubble(delta: float) -> void:
	if not _bubble.visible:
		return
	if not offer.is_empty():
		_bubble_t = maxf(_bubble_t, 0.5)          # an open offer stays up
	_bubble_t -= delta
	if _bubble_t <= 0.0:
		_bubble.visible = false
		return
	var head := get_global_transform_with_canvas() * Vector2(0, -62)
	var sz := _bubble.size
	var vp := get_viewport().get_visible_rect().size
	_bubble.position = Vector2(clampf(head.x - sz.x * 0.5, 8.0, vp.x - sz.x - 8.0), clampf(head.y - sz.y, 8.0, vp.y - sz.y - 8.0))


# --- the frame ---------------------------------------------------------------------------------

func _player() -> Node:
	return get_tree().get_first_node_in_group("player")


func _bounds() -> Vector2:
	var room = get_parent()
	var lo := 150.0
	var hi := 1030.0
	if room != null:
		var l = room.get("wall_foot_left")
		var r = room.get("wall_foot_right")
		if l != null and r != null and float(r) > float(l) + 100.0:
			lo = float(l) + 18.0
			hi = float(r) - 18.0
	return Vector2(lo, hi)


func _process(delta: float) -> void:
	_update_bubble(delta)


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_t += delta
	_state_t += delta
	_attack_cd = maxf(0.0, _attack_cd - delta)
	var p = _player()
	if p == null or not is_instance_valid(p):
		_play("Idle")
		return
	if _enter_t > 0.0:
		_enter_t -= delta
		if _enter_t <= 0.0:
			_greet()
	var dx: float = p.global_position.x - global_position.x
	var dist := absf(dx)
	var p_ok: bool = _player_reachable(p)
	_face(signf(dx))
	if _push_v != 0.0:
		_move_by(_push_v * delta)
		_push_v = move_toward(_push_v, 0.0, 600.0 * delta)
	match state:
		"hurt":
			_play("Hurt")
			if _state_t >= HURT_TIME:
				_set_state("flee" if temper == "scared" and not violent else "wary")
			return
		"windup":
			_play("Special")
			_show_weapon(true, -1.6 + 2.2 * clampf(_state_t / WINDUP, 0.0, 1.0))
			if _state_t >= WINDUP:
				_strike(p, dist, p_ok)
			return
	if violent:
		_violent_tick(p, dx, dist, p_ok, delta)
	else:
		match temper:
			"hostile": _hostile_tick(dx, dist, delta)
			"scared": _scared_tick(dx, dist, delta)
			_: _trader_tick(dx, dist, delta)
		_shout_tick(delta, dist)
	if not offer.is_empty() and (violent or not WorldState.inventory.has(offer["get"])):
		_close_offer()                 # what they wanted has left your pack (used, dropped): the deal's off


func _player_reachable(p: Node) -> bool:
	if ("is_dead" in p and p.is_dead) or ("is_dying" in p and p.is_dying) or ("escaping" in p and p.escaping):
		return false
	return ENEMY_PLANE.same_plane(self, p)


func _greet() -> void:
	if _met_before > 0:
		say("enter_again")
	elif WorldState.was_key_opened(apartment_id):
		say("enter_key")
	else:
		say("enter")
	_shout_t = randf_range(SHOUT_MIN, SHOUT_MAX)


func _shout_tick(delta: float, dist: float) -> void:
	_shout_t -= delta
	if _shout_t > 0.0:
		return
	_shout_t = randf_range(SHOUT_MIN, SHOUT_MAX)
	if not offer.is_empty():
		say("trade_reminder")
	elif _shouts < CALM_AFTER:
		_shouts += 1
		say("leave_demand")
	elif not _calmed and dist > TOO_CLOSE:
		_calmed = true
		say("calm")
		_shout_t = randf_range(SHOUT_MAX * 2.0, SHOUT_MAX * 3.0)


## Something happened (a search, a hit, crowding): the shouting starts over.
func _provoked() -> void:
	_shouts = 0
	_calmed = false


func _hostile_tick(dx: float, dist: float, delta: float) -> void:
	# Squares up at arm's length on its own side of you and PACES there, brandishing the weapon now
	# and then. Crowd it after the warning and it swings.
	var side := -signf(dx) if dx != 0.0 else 1.0
	var tx: float = global_position.x + dx + side * STANDOFF + sin(_t * 1.7 + _pace_phase) * 18.0
	var far := absf(tx - global_position.x) > 120.0
	_walk_to(tx, RUN if far else WALK, delta)
	_threat_t -= delta
	if _threat_t <= 0.0 and dist < 200.0:
		_threat_t = randf_range(THREAT_MIN, THREAT_MAX)
		say("threaten")
		_play("Special", true)
		_show_weapon(true, -1.2)
	elif animated_sprite.animation != "Special" or not animated_sprite.is_playing():
		_show_weapon(true, -0.7)
	if dist < TOO_CLOSE:
		_close_t += delta
		if not _said_close:
			_said_close = true
			_provoked()
			say("too_close")
		elif _close_t >= CLOSE_GRACE:
			go_violent("attack")
	else:
		_close_t = maxf(0.0, _close_t - delta)
		if dist > TOO_CLOSE * 2.2:
			_said_close = false


func _scared_tick(dx: float, dist: float, delta: float) -> void:
	var b := _bounds()
	if state == "dash":
		# Bolting PAST you to the other side of the room (it passes through — never blocks).
		_play("Walk")
		_face(signf(_dash_to - global_position.x))
		if _walk_to(_dash_to, RUN * 1.15, delta):
			_set_state("flee")
		return
	_show_weapon(weapon != "" and dist < KEEP_AWAY, 0.4)
	if dist >= KEEP_AWAY:
		_corner_t = 0.0
		_said_corner = false
		_set_state("wary")
		_play("Idle")
		return
	var away := -signf(dx) if dx != 0.0 else 1.0
	var wall: float = b.y if away > 0.0 else b.x
	if absf(wall - global_position.x) > 6.0:
		_set_state("flee")
		_face(away)
		_walk_to(wall, RUN, delta)
		_corner_t = 0.0
		if dist < TOO_CLOSE and not _said_close:
			_said_close = true
			say("too_close")
		return
	# Backed against the wall.
	_set_state("cower")
	_play("Hurt")
	animated_sprite.frame = 1
	animated_sprite.pause()
	if dist < TOO_CLOSE * 1.6:
		_corner_t += delta
		if not _said_corner:
			_said_corner = true
			_provoked()
			say("cornered")
		if _corner_t >= CORNER_TIME:
			_corner_t = 0.0
			if bool(rec.get("lash", false)):
				_lashing = true
				go_violent("lash_out")
			else:
				# Running around: makes a break for it, straight past you.
				_dash_to = clampf(global_position.x + dx + signf(dx) * 160.0, b.x, b.y)
				_set_state("dash")
	else:
		_corner_t = maxf(0.0, _corner_t - delta)


func _trader_tick(dx: float, dist: float, delta: float) -> void:
	# Keeps you at a careful distance; otherwise stands its ground and watches. With a deal on the
	# table it comes over to make it (to arm's length, never closer).
	_show_weapon(weapon != "" and dist < TRADER_KEEP, -0.3)
	if not offer.is_empty():
		if dist > OFFER_NEAR + 8.0:
			_walk_to(global_position.x + dx - signf(dx) * OFFER_NEAR, WALK * 1.5, delta)
		else:
			_play("Idle")
		return
	if dist < TRADER_KEEP:
		var away := -signf(dx) if dx != 0.0 else 1.0
		_walk_to(global_position.x + away * (TRADER_KEEP - dist + 6.0), WALK, delta)
		if dist < TOO_CLOSE and not _said_close:
			_said_close = true
			say("too_close")
	else:
		_play("Idle")
		if dist > TOO_CLOSE * 2.2:
			_said_close = false


func _violent_tick(p: Node, dx: float, dist: float, p_ok: bool, delta: float) -> void:
	_show_weapon(true, -0.9)
	if not p_ok:
		_play("Idle")
		return
	if dist > REACH:
		_walk_to(p.global_position.x - signf(dx) * (REACH - 6.0), RUN, delta)
	elif _attack_cd <= 0.0:
		_set_state("windup")
	else:
		_play("Idle")


func _strike(p: Node, dist: float, p_ok: bool) -> void:
	if p_ok and dist <= REACH + 8.0 and p.has_method("receive_hit"):
		p.receive_hit(1)
	_attack_cd = ATTACK_CD
	if _lashing:
		# A scared one only ever snaps ONCE, then it's running again.
		_lashing = false
		violent = false
		_set_state("flee")
		return
	_set_state("wary")


## Turns on the player (says `moment`, persisted).
func go_violent(moment: String = "attack") -> void:
	if is_dead:
		return
	if not violent:
		say(moment)
	violent = true
	_close_offer()
	if not _lashing:
		WorldState.update_resident(apartment_id, {"violent": true})


# --- the player going through their things ----------------------------------------------------

## loot_ui calls this for every search in this flat: "start" (opened a node) / "take" (took an item).
func on_scavenge(phase: String, apt_id: String) -> void:
	if is_dead or apt_id != apartment_id:
		return
	_provoked()
	match temper:
		"scared":
			if violent:
				return
			say("scavenge_beg" if phase == "start" else "item_taken")
		"hostile":
			if violent:
				return
			if phase == "take" or int(rec.get("warned", 0)) >= 1:
				go_violent("item_taken" if phase == "take" else "attack")
			else:
				rec["warned"] = 1
				WorldState.update_resident(apartment_id, {"warned": 1})
				say("scavenge_warn")
				_threat_t = 0.8
		_:
			if violent:
				return
			if phase == "take":
				if not offer.is_empty() or bool(rec.get("offered", false)):
					_close_offer()
					if bool(rec.get("turn", false)):
						go_violent("turned_hostile")
					else:
						say("trade_refused")
				return
			if bool(rec.get("traded", false)):
				say("leave_demand")
				return
			make_offer()


## A trader puts a swap on the table: one of its goods for the best thing in your pack it wants.
func make_offer() -> bool:
	var goods: Array = rec.get("goods", [])
	var want = want_from_player()
	rec["offered"] = true                    # they've had their say: taking anything now is robbing them
	if goods.is_empty() or want == null:
		say("no_trade")
		return false
	offer = {"give": goods[0], "get": want}
	_offer_row.visible = true
	say("trade_offer", 6.0)
	return true


## The item in the player's pack this resident would take for its goods (null = nothing it wants).
func want_from_player():
	var best = null
	var best_score := 0
	var goods_ids: Array = []
	for g in rec.get("goods", []):
		goods_ids.append(str(g.get("id", "")))
	for i in WorldState.inventory.size():
		var inst = WorldState.inventory[i]
		if inst == null:
			continue
		var data: Dictionary = ItemData.get_item(inst.item_id)
		if data.get("is_key", false) or data.get("is_money", false) or inst.item_id in goods_ids:
			continue
		var score: int = int(WANT_SCORE.get(inst.item_id, 5 if data.get("is_weapon", false) else 0))
		if inst.is_depleted:
			score = 0
		if score > 0 and i == HUD.selected_slot:
			score -= 2                         # rather not the thing in your hand
		if score > best_score:
			best_score = score
			best = inst
	return best


func accept_trade() -> bool:
	if offer.is_empty() or is_dead:
		return false
	var p = _player()
	if p != null and absf(p.global_position.x - global_position.x) > OFFER_RANGE:
		HUD.show_feedback("Get closer to trade.")
		return false
	var inst = offer["get"]
	var idx: int = WorldState.inventory.find(inst)
	if idx < 0:
		_close_offer()
		return false
	var give: Dictionary = offer["give"]
	WorldState.remove_from_inventory(idx)
	if not WorldState.add_to_inventory(str(give["id"]), int(give.get("amount", 0))):
		WorldState.inventory.insert(idx, inst)          # never destroy the player's things
		HUD.show_feedback("No room for it.")
		HUD.refresh_inventory()
		return false
	if HUD.selected_slot == idx:
		HUD.selected_slot = -1
	elif HUD.selected_slot > idx:
		HUD.selected_slot -= 1
	# A fair swap with a survivor counts as helping them (the session's "NPCs aided" Valour, +4) — once each.
	if not bool(rec.get("traded", false)):
		WorldState.note_npc_aided()
	var goods: Array = rec.get("goods", [])
	for gi in goods.size():
		if goods[gi] is Dictionary and str(goods[gi].get("id", "")) == str(give["id"]):
			goods.remove_at(gi)
			break
	goods.append({"id": inst.item_id, "amount": inst.count if inst.count > 1 else 0})
	rec["goods"] = goods
	rec["traded"] = true
	WorldState.update_resident(apartment_id, {"goods": goods, "traded": true})
	WorldState.sync_overload()
	HUD.refresh_inventory()
	HUD.show_feedback("Traded your %s for %s." % [_item_name(inst.item_id), _item_name(str(give["id"]))])
	_close_offer()
	say("trade_done")
	return true


func decline_trade() -> void:
	if offer.is_empty():
		return
	_close_offer()
	say("trade_declined")


func _close_offer() -> void:
	offer = {}
	if _offer_row != null:
		_offer_row.visible = false
		_bubble.reset_size()


func _unhandled_input(event: InputEvent) -> void:
	# The interact key takes an open offer too (not while the loot panel owns it).
	if offer.is_empty() or WorldState.loot_open or not event.is_action_pressed("interact"):
		return
	if accept_trade():
		get_viewport().set_input_as_handled()


# --- being hit ---------------------------------------------------------------------------------

func is_hurt() -> bool:
	return state == "hurt"


func receive_damage(amount: int, _damage_type: String = "") -> void:
	if is_dead:
		return
	current_hp -= maxi(amount, 0)
	WorldState.update_resident(apartment_id, {"hp": current_hp})
	if current_hp <= 0:
		_die()
		return
	say("hurt")
	_set_state("hurt")
	_hit_reaction()


func receive_hit_from_gun(outcome: String) -> void:
	match outcome:
		"headshot": receive_damage(99, "gun")
		"body": receive_damage(2, "gun")
		_: _hit_reaction()


func receive_push(force: float) -> void:
	if is_dead:
		return
	_push_v = clampf(force, -260.0, 260.0)
	_set_state("hurt")
	_hit_reaction()


func _hit_reaction() -> void:
	_provoked()
	_close_offer()
	if temper == "scared":
		if bool(rec.get("lash", false)) and not violent:
			_lashing = true
			violent = true
		return
	if not violent:
		violent = true
		if temper == "trader":
			say("turned_hostile")
		WorldState.update_resident(apartment_id, {"violent": true})


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	current_hp = 0
	_close_offer()
	say("death", 2.5)
	remove_from_group("resident_target")
	z_index = 0
	_play("Death", true)
	_show_weapon(false, 0.0)
	WorldState.update_resident(apartment_id, {"dead": true, "hp": 0, "x": global_position.x})
	WorldState.add_run_trace("Killed someone still alive behind a locked door.")
	WorldState.note_resident_killed(apartment_id, global_position.x)   # they'll be back (a revenant, next run)
	# What they had: the weapon, then their pockets (what they traded you is in there too).
	if weapon != "":
		WorldState.drop_item_from(self, weapon)
	for g in rec.get("goods", []):
		WorldState.drop_item_from(self, str(g.get("id", "")), {"amount": int(g.get("amount", 0))})


func _lie_dead() -> void:
	is_dead = true
	state = "dead"
	z_index = 0
	if animated_sprite.sprite_frames.has_animation("Death"):
		animated_sprite.animation = "Death"
		animated_sprite.frame = animated_sprite.sprite_frames.get_frame_count("Death") - 1
		animated_sprite.pause()


func _exit_tree() -> void:
	if not is_dead and apartment_id != "":
		WorldState.update_resident(apartment_id, {"x": global_position.x, "hp": current_hp})


# --- helpers -----------------------------------------------------------------------------------

func _set_state(s: String) -> void:
	if s != state:
		state = s
		_state_t = 0.0


func _play(anim: String, restart: bool = false) -> void:
	if animated_sprite == null or not animated_sprite.sprite_frames.has_animation(anim):
		return
	# A threat / swing plays through before anything else takes over.
	if not restart and animated_sprite.animation == "Special" and animated_sprite.is_playing() and anim != "Hurt":
		return
	if restart or animated_sprite.animation != anim or not animated_sprite.is_playing():
		animated_sprite.play(anim)
		if restart:
			animated_sprite.frame = 0


func _face(dir: float) -> void:
	if dir != 0.0 and animated_sprite != null:
		animated_sprite.flip_h = dir < 0.0       # the pack's art faces right


func _move_by(step: float) -> void:
	var b := _bounds()
	global_position.x = clampf(global_position.x + step, b.x, b.y)


## Walks toward x (clamped to the room). True once there.
func _walk_to(x: float, speed: float, delta: float) -> bool:
	var b := _bounds()
	var tx := clampf(x, b.x, b.y)
	var d := tx - global_position.x
	if absf(d) < 2.0:
		_play("Idle")
		return true
	_move_by(signf(d) * minf(absf(d), speed * delta))
	_play("Walk")
	return false


func _show_weapon(on: bool, angle: float) -> void:
	if _weapon_sprite == null:
		return
	_weapon_sprite.visible = on
	var f := -1.0 if animated_sprite.flip_h else 1.0
	_weapon_sprite.position = Vector2(6.0 * f, -24.0)
	_weapon_sprite.flip_h = animated_sprite.flip_h
	_weapon_sprite.rotation = angle * f
