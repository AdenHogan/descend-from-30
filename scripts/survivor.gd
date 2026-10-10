class_name Survivor
extends Area2D

# A SURVIVOR — one of the people the building still has (docs/NPC_AI.md). Who, where and with what: scripts/
# survivor_plan.gd (seeded, settled into WorldState.survivors, saved). How they THINK is here, and it is meant to
# be read: every frame the survivor perceives (the dead near it, the player), DECIDES one of a short list of NAMED
# behaviours by priority, and ACTS on it — and the behaviour it is in is shown as a tell (!, ?, …) and written in
# `behaviour`, so the player (and a test) can see exactly what it is doing and why.
#
#   DEFENDER (armed, corridor)      hold → alert → engage ⇄ help → (retreat → wounded) → return → hold
#   HIDER    (unarmed-ish, in a flat) hide → peek → trust ⇄ freeze → panic → relieved
#   WAITER   (by the lift)          wait (+ bangs in threes) → startle → calm ⇄ flee
#
# THEY FIGHT AT HALF YOUR DAMAGE (scripts/ally_combat.gd): the player must still be the one who takes initiative.
# The dead fight back — zombies pick a survivor as prey when it is the nearer meal (AllyCombat / the zombie's
# _pick_prey) and bite it for their ordinary damage; a survivor can die, and stays dead.
#
# SOFTLOCK-SAFE by construction, like a resident: an Area2D with NO collision layers — it never blocks or shoves
# the player, whatever it does. It is not in the "zombie" group, so no zombie system (memory, crowds, cans) treats
# it as one; zombies find it through the "survivor_prey" group instead.

const ENEMY_PLANE := preload("res://scripts/enemy_plane.gd")
const UI_FONT := preload("res://assets/fonts/PixelOperator8.ttf")
const GUNSHOT := preload("res://assets/audio/gunshot.wav")
const ART := "res://assets/homeless-character-pixel-art-pack/%d/%s.png"
const FRAME := 48
const SPRITE_SCALE := 1.6
const WALK := 42.0
const RUN := 100.0
const FEET_ROOM := 353.0           # room.ROOM_FEET_Y
const FEET_CORRIDOR := 419.0       # the corridor floor line (docs/Y_PLANES.md)
const BOUNDS_CORRIDOR := Vector2(150.0, 1190.0)

# --- shared timings / ranges ---
const HURT_TIME := 0.35
const BUBBLE_MIN := 1.6
const TALK_RANGE := 66.0
const CORNERED_GAP := 52.0         # a zombie this close forces a fight, whatever the nerve
# --- defender ---
const SENSE := 340.0               # sees the dead this far along the lane
const LEASH := 250.0               # engages anything within this of its post …
const HELP_LEASH := 400.0          # … or this far when it is going to the player's aid
const HELP_NEAR_PLAYER := 330.0    # the player must be this close for it to bother
const REACT_TIME := 0.55           # from spotting one to committing (the "!" beat)
const WINDUP := 0.35
const RETREAT_FRAC := 0.35         # below this share of its health it falls back
const RECOVER_QUIET := 6.0         # calm for this long and a wounded one gets back up
const SCAN_MIN := 3.5
const SCAN_MAX := 6.0
const GUN_STAND_OFF := 150.0       # a gun-holder likes this much room, and backs off if closed on
const SHOT_NOISE := 900.0          # a survivor's gunshot carries this far (the floor hears; other floors do not)
const MELEE_NOISE := 120.0
# --- hider ---
const PEEK_RANGE := 170.0
const TRUST_NEAR := 84.0
const TRUST_TIME_SCAV := 1.4       # you came in with your weapon down
const TRUST_TIME_COMBAT := 3.2     # you came in with it drawn
const FREEZE_RANGE := 230.0
const PANIC_RANGE := 84.0
const SCREAM_NOISE := 380.0
const SCREAM_COOLDOWN := 7.0
# --- waiter ---
const BANG_MIN := 22.0
const BANG_MAX := 34.0
const BANG_GAP := 0.55
const BANG_NOISE := 300.0
const STARTLE_RANGE := 96.0
const CALM_TIME := 1.2
const FLEE_RANGE := 200.0

var rec: Dictionary = {}
var key: String = ""
var role: String = "hider"
var weapon: String = ""
var kind: String = "fists"            # AllyCombat.kind_of(weapon)
var ammo: int = 0
var current_hp: int = 3
var max_hp: int = 3
var is_dead: bool = false
var look: int = 1
var post: float = 0.0
var feet_y: float = FEET_ROOM
var scenery: bool = false              # a pan backdrop's frozen copy: visible, does nothing until wake()
var on_fire: bool = false              # (never set — fire code that asks finds a field)
# the balcony-plane fields every actor carries (scripts/enemy_plane.gd reads them) — a survivor is always on the floor
var on_balcony_plane: bool = false
var balcony_center_x: float = 0.0
@warning_ignore("unused_private_class_variable")
var _plane_climb: int = 0

var behaviour: String = ""             # the named behaviour it is in right now (tests, tells and the journal read this)
var target: Node2D = null              # whom it is fighting
var last_moment: String = ""
var last_line: String = ""

var animated_sprite: AnimatedSprite2D = null
var tell: AiTell = null
var _weapon_sprite: Sprite2D = null
var _bubble_layer: CanvasLayer = null
var _bubble: PanelContainer = null
var _bubble_label: Label = null
var _bubble_t: float = 0.0
var _choice_box: VBoxContainer = null
var _choices_open: bool = false
var _gun_player: AudioStreamPlayer2D = null
var _melee_player: AudioStreamPlayer2D = null
var _last_by_moment: Dictionary = {}

var _t: float = 0.0
var _b_t: float = 0.0                  # time in the current behaviour
var _cd: float = 0.0                   # attack cooldown
var _wind: float = -1.0                # >= 0 while winding up a strike
var _carry: float = 0.0                # the fraction of damage carried between swings (AllyCombat.take_swing)
var _react: float = 0.0                # defender: the alert beat
var _scan_t: float = 3.0
var _face: float = 1.0
var _quiet_t: float = 0.0              # time with no threat in sense
var _said: Dictionary = {}             # one-shot lines this encounter (reset when the threat clears)
var _hurt_t: float = 0.0
var _trust_t: float = 0.0
var _scream_cd: float = 0.0
var _bang_t: float = 12.0
var _bangs_left: int = 0
var _bang_gap: float = 0.0
var _calm_t: float = 0.0
var _retreat_x: float = 0.0
var _push_v: float = 0.0
var _rng := RandomNumberGenerator.new()
var _talk_near: bool = false
var _met_logged: bool = false
var knocks: int = 0                    # how many times the waiter has knocked (tests count the threes)
## Set by a quest (scripts/quests.gd): when non-empty, talking to this person is the quest's conversation.
var quest_id: String = ""


## Lays a survivor into `parent` from its record. `feet` is the walking line of the place (353 in a flat, 419 in the
## corridor); `x` < 0 uses the record's own spot. `as_scenery` = a pan backdrop's frozen copy.
static func spawn(parent: Node, record: Dictionary, feet: float, x: float = -1.0, as_scenery: bool = false) -> Survivor:
	var n := Survivor.new()
	n.name = "Survivor_" + str(record.get("role", "x"))
	n.rec = record
	n.feet_y = feet
	var px: float = x if x >= 0.0 else float(record.get("x", -1.0))
	if px < 0.0:
		px = float(record.get("post", 600.0))
	n.position = Vector2(px, feet)
	n.scenery = as_scenery
	parent.add_child(n)
	return n


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false
	z_index = 1
	add_to_group("survivor")
	key = str(rec.get("key", ""))
	role = str(rec.get("role", "hider"))
	weapon = str(rec.get("weapon", ""))
	ammo = int(rec.get("ammo", 0))
	look = int(rec.get("look", 1))
	max_hp = int(rec.get("max_hp", 3))
	current_hp = int(rec.get("hp", max_hp))
	post = float(rec.get("post", global_position.x))
	quest_id = str(rec.get("quest", "")) if Quests.is_giver(rec) else ""
	kind = AllyCombat.kind_of(weapon)
	if kind == "gun" and ammo <= 0:
		kind = "fists"
	_rng.seed = hash(key + str(WorldState.master_seed))
	_scan_t = _rng.randf_range(SCAN_MIN, SCAN_MAX)
	_bang_t = _rng.randf_range(BANG_MIN * 0.5, BANG_MAX * 0.5)
	_face = -1.0 if post > 600.0 else 1.0
	# a stand-in shape: drop_item_from reads the feet off it (like a resident). No layers, so it can touch nothing.
	var cs := CollisionShape2D.new()
	cs.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, 48)
	cs.shape = shape
	cs.position = Vector2(0, -24)
	add_child(cs)
	_build_sprite()
	_build_weapon()
	_build_audio()
	_build_bubble()
	tell = AiTell.attach(self, 70.0)
	if bool(rec.get("dead", false)):
		_lie_dead()
		return
	if role != "patient":
		add_to_group("survivor_prey")                 # (a bitten man on his back is not a meal the dead go for)
	_set_behaviour({"hider": "hide", "waiter": "wait", "host": "plead", "patient": "lie"}.get(role, "hold"))
	if scenery:
		add_to_group("pan_scenery")        # building_floors._make_inert keeps scenery processing (the idle animation)
		set_physics_process(false)
		set_process(false)


## A pan backdrop has committed: the frozen copy becomes a real survivor.
func wake() -> void:
	if not scenery:
		return
	scenery = false
	if not is_dead:
		set_physics_process(true)
		set_process(true)


# --- building the body ---------------------------------------------------------------------------

func _build_sprite() -> void:
	animated_sprite = AnimatedSprite2D.new()
	animated_sprite.name = "AnimatedSprite2D"
	animated_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	animated_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	animated_sprite.offset = Vector2(0, -FRAME * 0.5)       # the frame's bottom row (the feet) on the origin
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
	# The look with a stick carries its bat in its own art; anyone else holding something shows its icon small in hand.
	if weapon == "" or look == SurvivorPlan.STICK_LOOK:
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


func _build_audio() -> void:
	_gun_player = AudioStreamPlayer2D.new()
	_gun_player.name = "Gunshot"
	_gun_player.stream = GUNSHOT
	_gun_player.volume_db = -9.0
	_gun_player.max_distance = 900.0
	add_child(_gun_player)
	_melee_player = AudioStreamPlayer2D.new()
	_melee_player.name = "Melee"
	_melee_player.volume_db = -8.0
	_melee_player.max_distance = 500.0
	add_child(_melee_player)


func _build_bubble() -> void:
	_bubble_layer = CanvasLayer.new()
	_bubble_layer.name = "Speech"
	_bubble_layer.layer = 2
	add_child(_bubble_layer)
	_bubble = PanelContainer.new()
	_bubble.name = "Bubble"
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.06, 0.86)
	sb.border_color = {"defender": Color(0.45, 0.72, 0.5), "hider": Color(0.75, 0.78, 0.85),
		"waiter": Color(0.88, 0.72, 0.36)}.get(role, Color(0.8, 0.8, 0.8))
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
	_bubble_label.custom_minimum_size = Vector2(230, 0)
	_bubble_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_bubble_label)
	_choice_box = VBoxContainer.new()
	_choice_box.name = "Choices"
	_choice_box.add_theme_constant_override("separation", 4)
	_choice_box.visible = false
	vb.add_child(_choice_box)
	_bubble.visible = false
	_bubble_layer.add_child(_bubble)
	_bubble.add_to_group("hud_widget_extra")          # HUD.pointer_over_widget: a click on a choice is not also a swing / a walk


# --- speech --------------------------------------------------------------------------------------

static var _lines: Dictionary = {}

## The dialogue (data/survivor_dialogue.json), loaded once. Owner-authored.
static func lines() -> Dictionary:
	if _lines.is_empty():
		var path := "res://data/survivor_dialogue.json"
		if FileAccess.file_exists(path):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary:
				_lines = parsed
	return _lines


## Says a line for `moment` (this role's pool, else the shared one); never the same line twice running; "" = silent.
func say(moment: String, hold: float = 0.0) -> String:
	var pool = lines().get(role, {}).get(moment, null)
	if not (pool is Array) or pool.is_empty():
		pool = lines().get("all", {}).get(moment, [])
	if not (pool is Array) or pool.is_empty():
		return ""
	var i: int = _rng.randi() % pool.size()
	if pool.size() > 1 and i == int(_last_by_moment.get(moment, -1)):
		i = (i + 1) % pool.size()
	_last_by_moment[moment] = i
	return _show(moment, str(pool[i]).replace("{player}", WorldState.character_display_name(WorldState.current_character())), hold)


func say_once(moment: String) -> String:
	if _said.has(moment):
		return ""
	_said[moment] = true
	return say(moment)


## A line that is not from the pools (a quest's conversation).
func say_text(moment: String, text: String, hold: float = 0.0) -> String:
	return _show(moment, text.replace("{player}", WorldState.character_display_name(WorldState.current_character())), hold)


func _show(moment: String, line: String, hold: float) -> String:
	last_moment = moment
	last_line = line
	_bubble_label.text = line
	_bubble.visible = true
	_bubble.reset_size()
	_bubble_t = maxf(hold, BUBBLE_MIN + 0.05 * line.length())
	return line


func _update_bubble(delta: float) -> void:
	if not _bubble.visible:
		return
	if _choices_open:
		_bubble_t = maxf(_bubble_t, 0.5)               # an open question stays up
	_bubble_t -= delta
	if _bubble_t <= 0.0:
		_bubble.visible = false
		return
	var head := get_global_transform_with_canvas() * Vector2(0, -66)
	var sz := _bubble.size
	var vp := get_viewport().get_visible_rect().size
	_bubble.position = Vector2(clampf(head.x - sz.x * 0.5, 8.0, vp.x - sz.x - 8.0), clampf(head.y - sz.y, 8.0, vp.y - sz.y - 8.0))


# --- perception ----------------------------------------------------------------------------------

func _player() -> Node2D:
	var p = get_tree().get_first_node_in_group("player")
	return p if p is Node2D and is_instance_valid(p) else null


func _player_gap() -> float:
	var p := _player()
	if p == null or ("is_dead" in p and p.is_dead):
		return INF
	return AiMind.gap(self, p)


## The living dead this survivor can see, nearest first: [{"z": node, "gap": px}], within `rng` along the lane.
func _threats(rng: float) -> Array:
	var out: Array = []
	for z in get_tree().get_nodes_in_group("zombie"):
		if not AiMind.present(z) or z.get("tutorial_scripted") == true:
			continue
		var g := AiMind.gap(self, z)
		if g <= rng:
			out.append({"z": z, "gap": g})
	out.sort_custom(func(a, b): return float(a["gap"]) < float(b["gap"]))
	return out


func _bounds() -> Vector2:
	var room = get_parent()
	if room != null:
		var l = room.get("wall_foot_left")
		var r = room.get("wall_foot_right")
		if l != null and r != null and float(r) > float(l) + 100.0:
			return Vector2(float(l) + 18.0, float(r) - 18.0)
	return BOUNDS_CORRIDOR


func _zombie_half(z: Node) -> float:
	var cs = z.get_node_or_null("CollisionShape2D")
	if cs != null and cs.shape != null:
		if cs.shape is RectangleShape2D:
			return cs.shape.size.x * 0.5
		if cs.shape is CapsuleShape2D or cs.shape is CircleShape2D:
			return cs.shape.radius
	return 10.0


# --- the frame -----------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_update_bubble(delta)
	_update_prompt()


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_t += delta
	_b_t += delta
	_cd = maxf(0.0, _cd - delta)
	_scream_cd = maxf(0.0, _scream_cd - delta)
	if not _met_logged:
		_met_logged = true
		var met: int = int(rec.get("met", 0))
		rec["met"] = met + 1
		WorldState.update_survivor(key, {"met": met + 1})
	if _push_v != 0.0:
		_move_by(_push_v * delta)
		_push_v = move_toward(_push_v, 0.0, 600.0 * delta)
	if _hurt_t > 0.0:
		_hurt_t -= delta
		_play("Hurt")
		if _hurt_t <= 0.0:
			_play("Idle", true)
		return
	match role:
		"defender": _tick_defender(delta)
		"hider": _tick_hider(delta)
		"waiter": _tick_waiter(delta)
		"host": _tick_host(delta)
		"patient": _tick_patient()
		_: _set_behaviour("hold")
	_tick_choices()
	animated_sprite.flip_h = _face < 0.0


## One named behaviour at a time; changing it resets its clock and sets the tell.
func _set_behaviour(b: String) -> void:
	if b == behaviour:
		return
	behaviour = b
	_b_t = 0.0
	match b:
		"alert", "startle":
			tell.show_mark("alert", 0.9)
		"retreat", "wounded", "freeze", "panic", "flee":
			tell.show_mark("fear", 1.6)
		_:
			pass


# =============================== DEFENDER ===============================================
#
# Pattern (what the player learns): it HOLDS its post and scans; the moment one of the dead is sighted it turns,
# marks "!" and calls it (a half-second beat), then goes at whatever is within its leash — preferring the one that is
# on someone (the player, another survivor) over the one that is merely standing there. It does not chase into the
# dark: beyond its leash it only watches, unless the player is in the fight, in which case the leash stretches to
# reach them. Below a third of its health it falls back from the dead and tends its wounds until things are quiet;
# it fights again only if something corners it. A gun-holder keeps its distance, backs off when closed on, and with
# no rounds left becomes a retreater.

func _tick_defender(delta: float) -> void:
	var threats := _threats(SENSE)
	var player_gap := _player_gap()
	var can_fight: bool = kind != "fists" and not (kind == "gun" and ammo <= 0)
	var wounded: bool = float(current_hp) <= float(max_hp) * RETREAT_FRAC
	var cornered: Dictionary = {}
	if not threats.is_empty() and float(threats[0]["gap"]) <= CORNERED_GAP:
		cornered = threats[0]
	if threats.is_empty():
		_quiet_t += delta
		_said.erase("spot")
		_said.erase("help")
	else:
		_quiet_t = 0.0

	# 1. SURVIVE — fall back when hurt or out of rounds (unless something has it pinned).
	if (wounded or not can_fight) and cornered.is_empty():
		_wind = -1.0
		if threats.is_empty():
			if wounded and _quiet_t < RECOVER_QUIET:
				_set_behaviour("wounded")        # tending its wounds until it has been quiet a while
				_show_weapon(false, 0.0)
				_crouch()
				return
			if behaviour in ["wounded", "retreat"]:
				say_once("recovered")
			_idle_at_post(delta, false)          # quiet again: back on its feet at the post
			return
		if behaviour != "retreat":
			_set_behaviour("retreat")
			if wounded:
				say_once("wounded")
		_retreat(threats, delta)
		return

	# 2. FIGHT — choose a target inside the leash.
	var tgt := _pick_target(threats, player_gap, cornered)
	if tgt != null:
		target = tgt
		if behaviour not in ["engage", "help"]:
			# the "!" beat before it commits
			if behaviour != "alert":
				_set_behaviour("alert")
				_react = REACT_TIME
				_face = AiMind.facing(global_position.x, tgt.global_position.x, _face)
				say_once("spot")
				_show_weapon(true, -0.7)
			_react -= delta
			if _react > 0.0 and cornered.is_empty():
				_play("Idle")
				return
		var helping: bool = absf(tgt.global_position.x - post) > LEASH
		_set_behaviour("help" if helping else "engage")
		if helping:
			say_once("help")
		else:
			say_once("engage")
		_fight(tgt, delta)
		return
	target = null

	# 3. WATCH — something in sight but out of leash: face it, stay put.
	_wind = -1.0
	if not threats.is_empty():
		var z: Node2D = threats[0]["z"]
		_face = AiMind.facing(global_position.x, z.global_position.x, _face)
		if behaviour != "alert":
			_set_behaviour("alert")
			_react = REACT_TIME
			say_once("spot")
		_show_weapon(true, -0.7)
		_play("Idle")
		return

	# 4. RETURN / HOLD.
	if behaviour in ["engage", "help", "alert", "retreat", "wounded"]:
		if _quiet_t > 1.0:
			say_once("clear")
		_set_behaviour("return")
	if behaviour == "return":
		if absf(global_position.x - post) > 6.0:
			_face = AiMind.facing(global_position.x, post, _face)
			_walk_to(post, WALK * 1.4, delta)
			_show_weapon(false, 0.0)
			return
		_set_behaviour("hold")
	_idle_at_post(delta, false)
	_hold_chatter()


func _idle_at_post(delta: float, hurt: bool) -> void:
	_set_behaviour("hold" if not hurt else "wounded")
	_show_weapon(false, 0.0)
	if hurt:
		_crouch()
		return
	_play("Idle")
	if absf(global_position.x - post) > 6.0:
		_walk_to(post, WALK, delta)
		return
	_scan_t -= delta
	if _scan_t <= 0.0:
		_scan_t = _rng.randf_range(SCAN_MIN, SCAN_MAX)
		_face = -_face                       # a slow look the other way: the "holding the post" pattern


func _hold_chatter() -> void:
	# Say hello once when the player first comes close; a thanks if they have been fighting alongside.
	var g := _player_gap()
	if g < 140.0 and not _said.has("greet"):
		_said["greet"] = true
		say("greet" if int(rec.get("met", 0)) <= 1 else "greet_again")
		_face = AiMind.facing(global_position.x, _player().global_position.x, _face)


## The threat to fight now, or null. Inside the leash only (stretched when it is helping the player); the dead that
## are on someone come first; a current target is kept while it stays reasonable (no flicker between two).
func _pick_target(threats: Array, player_gap: float, cornered: Dictionary) -> Node2D:
	if not cornered.is_empty():
		return cornered["z"]
	if kind == "fists":
		return null
	var best: Node2D = null
	var best_score := INF
	for t in threats:
		var z: Node2D = t["z"]
		var from_post: float = absf(z.global_position.x - post)
		var leash := LEASH
		if player_gap <= HELP_NEAR_PLAYER and _is_on_someone(z):
			leash = HELP_LEASH
		if from_post > leash:
			continue
		var score: float = float(t["gap"])
		if _is_on_someone(z):
			score -= 140.0
		if z.has_method("is_hurt") and z.is_hurt():
			score += 40.0                    # work through the unhurt first, like the player's own rule
		if z == target:
			score -= 40.0                    # sticky
		if score < best_score:
			best_score = score
			best = z
	return best


## Is this one of the dead currently going for the player or a survivor?
func _is_on_someone(z: Node) -> bool:
	var prey = z.get("prey")
	return prey != null and is_instance_valid(prey) and prey != self


func _fight(z: Node2D, delta: float) -> void:
	var g := AiMind.gap(self, z)
	_face = AiMind.facing(global_position.x, z.global_position.x, _face)
	_show_weapon(true, -0.9)
	if _wind >= 0.0:
		_wind += delta
		_play("Special")
		_show_weapon(true, -1.6 + 2.2 * clampf(_wind / WINDUP, 0.0, 1.0))
		if _wind >= WINDUP:
			_wind = -1.0
			_strike(z)
		return
	if kind == "gun":
		_gun_tactic(z, g, delta)
		return
	var reach := AllyCombat.reach(kind) + _zombie_half(z)
	if g > reach * 0.92:
		# Closing in. If the dead one is already coming and close, let it arrive: stand ground, strike first at reach.
		var coming: bool = z.get("prey") == self or (z.get("state") == "chase" and g < reach + 70.0)
		if coming and g < reach + 70.0:
			_play("Idle")
		else:
			_walk_to(z.global_position.x - signf(z.global_position.x - global_position.x) * (reach * 0.8), WALK * 1.5, delta)
	elif _cd <= 0.0:
		_wind = 0.0
	else:
		_play("Idle")


func _gun_tactic(z: Node2D, g: float, delta: float) -> void:
	if g < GUN_STAND_OFF * 0.55:
		_back_off(z, delta)                      # closed on: give ground, then shoot
		return
	if g > AllyCombat.GUN_RANGE:
		_walk_to(z.global_position.x - signf(z.global_position.x - global_position.x) * (AllyCombat.GUN_RANGE - 20.0), WALK * 1.4, delta)
		return
	if _cd <= 0.0:
		_wind = 0.0
	else:
		_play("Idle")


func _back_off(z: Node2D, delta: float) -> void:
	var b := _bounds()
	var away := -signf(z.global_position.x - global_position.x)
	if away == 0.0:
		away = 1.0
	var wall: float = b.y if away > 0.0 else b.x
	if absf(wall - global_position.x) < 10.0:
		_play("Idle")
		if _cd <= 0.0:
			_wind = 0.0
		return
	_walk_to(wall, RUN * 0.8, delta)


## The moment the swing / shot lands.
func _strike(z: Node2D) -> void:
	if not AiMind.present(z):
		return
	_cd = AllyCombat.cooldown(kind)
	if kind == "gun":
		_shoot(z)
		return
	var g := AiMind.gap(self, z)
	_play_melee_sound()
	WorldState.emit_noise(global_position, MELEE_NOISE, 0.5, false)
	if g > AllyCombat.reach(kind) + _zombie_half(z) + 8.0:
		return                                   # it moved out of reach during the wind-up
	var s := AllyCombat.take_swing(_carry, kind)
	_carry = float(s["carry"])
	var amount: int = int(s["amount"])
	if amount > 0 and z.has_method("receive_damage"):
		z.receive_damage(amount, AllyCombat.damage_type(kind))


func _shoot(z: Node2D) -> void:
	ammo -= 1
	rec["ammo"] = ammo
	WorldState.update_survivor(key, {"ammo": ammo})
	_gun_player.pitch_scale = _rng.randf_range(0.95, 1.05)
	_gun_player.play()
	WorldState.emit_noise(global_position, SHOT_NOISE, 4.0, false)
	var g := AiMind.gap(self, z)
	if AllyCombat.gun_hits(g, _rng.randf()):
		var s := AllyCombat.take_swing(_carry, "gun")
		_carry = float(s["carry"])
		if int(s["amount"]) > 0 and z.has_method("receive_damage"):
			z.receive_damage(int(s["amount"]), "bullet")
	if ammo <= 0:
		kind = "fists"
		say("out_of_ammo")


func _retreat(threats: Array, delta: float) -> void:
	var b := _bounds()
	var z: Node2D = threats[0]["z"]
	var away := -signf(z.global_position.x - global_position.x)
	if away == 0.0:
		away = 1.0
	_retreat_x = b.y - 30.0 if away > 0.0 else b.x + 30.0
	_face = AiMind.facing(global_position.x, z.global_position.x, _face)    # backs off FACING it
	_show_weapon(false, 0.0)
	if absf(_retreat_x - global_position.x) > 6.0:
		_walk_to(_retreat_x, RUN, delta)
	else:
		_crouch()


func _crouch() -> void:
	_play("Hurt")
	animated_sprite.frame = 1
	animated_sprite.pause()


# =============================== HIDER ==================================================
#
# Pattern: it HIDES — crouched at the back of the flat. Walk in quietly and it PEEKS, then (the sooner the more
# harmless you look: weapon down) comes to TRUST you and will talk. If one of the dead gets within earshot it
# FREEZES, holding its breath — stillness is the clever thing and it knows it. Found (the dead one on it, or
# right on top of it) it PANICS: bolts for the far wall screaming, which the dead hear. Cornered it cowers, and
# a knife, if it has one, comes out. When the dead are gone it is RELIEVED, and trusts.

func _tick_hider(delta: float) -> void:
	var threats := _threats(FREEZE_RANGE * (1.25 if behaviour in ["freeze", "panic", "cower"] else 1.0))     # (hysteresis: no flicker at the edge)
	var player_gap := _player_gap()
	var near_dead: Dictionary = threats[0] if not threats.is_empty() else {}
	var frightened: bool = behaviour in ["freeze", "panic", "cower"]

	# Found: the dead one is on it, or has it as prey.
	var found := false
	if not near_dead.is_empty():
		var z: Node2D = near_dead["z"]
		# Once it has run it keeps running while the dead one is still near (no flicker between running and freezing).
		found = float(near_dead["gap"]) <= PANIC_RANGE or z.get("prey") == self \
			or behaviour in ["panic", "cower"]
	if found:
		_hider_panic(near_dead, delta)
		return
	if not near_dead.is_empty() and (float(near_dead["gap"]) <= FREEZE_RANGE or frightened):
		_set_behaviour("freeze")
		say_once("freeze")
		_face = AiMind.facing(global_position.x, near_dead["z"].global_position.x, _face)
		_crouch()
		return
	if frightened and near_dead.is_empty():
		_said.erase("freeze")
		_set_behaviour("relieved")
		say_once("relieved")
	if behaviour == "relieved":
		_play("Idle")
		if _b_t > 2.4:
			_set_behaviour("trust")
		return
	_said.erase("freeze")

	var scav: bool = WorldState.is_scavenge_mode
	if player_gap <= PEEK_RANGE:
		_face = AiMind.facing(global_position.x, _player().global_position.x, _face)
		if behaviour == "hide":
			_set_behaviour("peek")
			_trust_t = 0.0
			say_once("peek")
		if behaviour == "peek":
			_play("Idle")
			if player_gap <= TRUST_NEAR:
				_trust_t += delta
				if _trust_t >= (TRUST_TIME_SCAV if scav else TRUST_TIME_COMBAT):
					_set_behaviour("trust")
					say_once("trust")
			else:
				_trust_t = maxf(0.0, _trust_t - delta)
		elif behaviour == "trust":
			_play("Idle")
		return
	# the player left: back to hiding (a trusting one just waits)
	if behaviour == "peek":
		_set_behaviour("hide")
		_said.erase("peek")
	if behaviour == "hide":
		_crouch()
	elif behaviour == "trust":
		_play("Idle")


func _hider_panic(near: Dictionary, delta: float) -> void:
	var z: Node2D = near["z"]
	var b := _bounds()
	var away := -signf(z.global_position.x - global_position.x)
	if away == 0.0:
		away = 1.0
	var wall: float = b.y if away > 0.0 else b.x
	_face = AiMind.facing(global_position.x, z.global_position.x, _face)
	if absf(wall - global_position.x) > 8.0:
		_set_behaviour("panic")
		if _scream_cd <= 0.0:
			_scream_cd = SCREAM_COOLDOWN
			say("panic")
			WorldState.emit_noise(global_position, SCREAM_NOISE, 3.0, false)     # the dead hear a scream
		_walk_to(wall, RUN, delta)
		return
	# Cornered: cower — and use the knife if there is one.
	_set_behaviour("cower")
	say_once("cornered")
	if kind != "fists" and kind != "gun" and float(near["gap"]) <= CORNERED_GAP + 12.0:
		target = z
		_fight(z, delta)
	else:
		_crouch()


# =============================== WAITER =================================================
#
# Pattern: it WAITS at the lift, facing the doors, muttering — and every half-minute or so it BANGS on them, three
# knocks half a second apart, which the dead can hear (that is its danger, and its tragedy). Come near and it
# STARTLES (the "!"); stand easy for a moment — weapon down, not rushing — and it CALMS, stops banging, and will
# talk. Anything of the dead near it makes it FLEE for the far end of the corridor.

func _tick_waiter(delta: float) -> void:
	var threats := _threats(FLEE_RANGE * (1.5 if behaviour == "flee" else 1.0))     # runs until it is well clear, not one step
	if not threats.is_empty():
		var z: Node2D = threats[0]["z"]
		var b := _bounds()
		var away := -signf(z.global_position.x - global_position.x)
		if away == 0.0:
			away = -1.0
		_face = AiMind.facing(global_position.x, z.global_position.x, _face)
		_set_behaviour("flee")
		say_once("flee")
		var wall: float = b.y - 20.0 if away > 0.0 else b.x + 20.0
		if absf(wall - global_position.x) > 8.0:
			_walk_to(wall, RUN, delta)
		else:
			_crouch()
		return
	_said.erase("flee")
	if behaviour == "flee":
		_set_behaviour("wait" if not bool(rec.get("calm", false)) else "calm")
	var g := _player_gap()
	var calmed: bool = bool(rec.get("calm", false))
	if not calmed and g <= STARTLE_RANGE:
		_face = AiMind.facing(global_position.x, _player().global_position.x, _face)
		if behaviour in ["wait", "bang"]:
			_set_behaviour("startle")
			_bangs_left = 0
			_calm_t = 0.0
			say_once("startle")
		if behaviour == "startle":
			_play("Idle")
			var easy: bool = WorldState.is_scavenge_mode or _player_gap() > STARTLE_RANGE * 0.5
			_calm_t += delta if easy else -delta
			_calm_t = maxf(_calm_t, 0.0)
			if _calm_t >= CALM_TIME:
				_become_calm()
		return
	if behaviour == "startle":
		_set_behaviour("wait")
		_said.erase("startle")
	if calmed:
		_set_behaviour("calm")
		_face = 1.0 if SurvivorPlan.LIFT_X > global_position.x else -1.0
		_play("Idle")
		return
	# waiting: face the lift, mutter now and then, bang in threes
	_face = 1.0 if SurvivorPlan.LIFT_X > global_position.x else -1.0
	if _bangs_left > 0:
		_set_behaviour("bang")
		_bang_gap -= delta
		if _bang_gap <= 0.0:
			_bang_gap = BANG_GAP
			_bangs_left -= 1
			_bang_once()
		return
	_set_behaviour("wait")
	_play("Idle")
	_bang_t -= delta
	if _bang_t <= 0.0:
		_bang_t = _rng.randf_range(BANG_MIN, BANG_MAX)
		_bangs_left = 3
		_bang_gap = 0.0
		say("bang")
	elif _b_t > 9.0 and not _said.has("mutter_%d" % int(_t / 12.0)):
		_said["mutter_%d" % int(_t / 12.0)] = true
		say("mutter")


func _bang_once() -> void:
	knocks += 1
	_play("Special", true)
	_melee_player.stream = AllyCombat.melee_sounds("bat")[0]
	_melee_player.pitch_scale = 0.6
	_melee_player.play()
	WorldState.emit_noise(global_position, BANG_NOISE, 1.5, false)


func _become_calm() -> void:
	rec["calm"] = true
	WorldState.update_survivor(key, {"calm": true})
	_set_behaviour("calm")
	say("calm")


# =============================== HOST + PATIENT (a quest's people) =============================
#
# Pattern: the HOST stays beside the one she will not leave — pleading, facing whoever comes near (or crouched
# and quiet when she mourns). The PATIENT lies where he is. Neither runs; the dead can still take the host.

func _tick_host(_delta: float) -> void:
	if str(rec.get("mood", "")) == "mourn":
		_set_behaviour("mourn")
		_crouch()
		return
	_set_behaviour("plead")
	var g := _player_gap()
	if g < 280.0:
		_face = AiMind.facing(global_position.x, _player().global_position.x, _face)
	_play("Idle")


func _tick_patient() -> void:
	_set_behaviour("lie")
	_crouch()


## Put an end to it (a quest choice): the patient dies without a fight, the way it was asked for.
func mercy_kill() -> void:
	if is_dead:
		return
	WorldState.add_run_trace("Ended a bitten man's suffering.")
	_die()


# --- a question with answers (a quest conversation) -------------------------------------------------

## Shows `list` ([{label, enabled, hint}]) as buttons under the line. Pressing one runs Quests.choose.
func show_choices(list: Array) -> void:
	hide_choices()
	if list.is_empty():
		return
	_choices_open = true
	for i in list.size():
		var c: Dictionary = list[i]
		var b := Button.new()
		b.name = "Choice%d" % i
		b.text = str(c["label"]) + ("" if bool(c["enabled"]) or str(c.get("hint", "")) == "" else "  (%s)" % str(c["hint"]))
		b.disabled = not bool(c["enabled"])
		b.add_theme_font_override("font", UI_FONT)
		b.add_theme_font_size_override("font_size", 14)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_on_choice.bind(i))
		_choice_box.add_child(b)
	_choice_box.visible = true
	_bubble.visible = true
	_bubble.reset_size()


func hide_choices() -> void:
	_choices_open = false
	if _choice_box == null:
		return
	for c in _choice_box.get_children():
		_choice_box.remove_child(c)
		c.queue_free()
	_choice_box.visible = false
	if _bubble != null:
		_bubble.reset_size()


func has_choices() -> bool:
	return _choices_open


func _on_choice(i: int) -> void:
	Quests.choose(self, i)


## Walk away and the question closes by itself.
func _tick_choices() -> void:
	if _choices_open and _player_gap() > TALK_RANGE * 2.6:
		hide_choices()
		_bubble_t = minf(_bubble_t, 1.0)


# --- talking -------------------------------------------------------------------------------------

func can_talk() -> bool:
	if is_dead or scenery:
		return false
	if quest_id != "":
		return behaviour in ["hold", "return", "plead", "mourn", "calm", "trust", "wait", "peek", "hide"]      # not mid-fight
	match role:
		"hider": return behaviour == "trust"
		"waiter": return bool(rec.get("calm", false)) and behaviour == "calm"
		"defender": return behaviour in ["hold", "return"]
	return false


func _update_prompt() -> void:
	var near: bool = can_talk() and _player_gap() <= TALK_RANGE and not WorldState.loot_open
	if near != _talk_near:
		_talk_near = near
		if near:
			HUD.show_world_prompt(self, "[{interact}] Talk", global_position + Vector2(0, -60))
		else:
			HUD.hide_world_prompt(self)
	if near and Input.is_action_just_pressed("interact") and not TutorialManager.interact_guarded():
		talk()


## Talk to them. Returns the line said ("" = nothing).
func talk() -> String:
	if not can_talk():
		return ""
	if quest_id != "":
		return Quests.talk(self)
	match role:
		"hider":
			if not bool(rec.get("gave", false)) and rec.get("gift", "") != "":
				return _give_gift()
			return say("thanks")
		"waiter":
			return say("thanks")
		"defender":
			return say("thanks" if bool(rec.get("aided", false)) else "greet_again")
	return ""


func _give_gift() -> String:
	var id: String = str(rec.get("gift", ""))
	var n: int = int(rec.get("gift_n", 0))
	if not WorldState.add_to_inventory(id, n):
		HUD.show_feedback("No room to carry it.")
		return say_text("gift_full", "Come back when you can carry it.")
	rec["gave"] = true
	rec["aided"] = true
	WorldState.update_survivor(key, {"gave": true, "aided": true})
	WorldState.note_npc_aided()
	HUD.refresh_inventory()
	HUD.show_feedback("%s gives you %s." % ["They", str(ItemData.get_item(id).get("name", "something"))])
	return say("gift")


# --- being hurt ----------------------------------------------------------------------------------

func is_hurt() -> bool:
	return _hurt_t > 0.0


## The dead bite (and anything else hurts) — called by zombies as well as the world.
func receive_damage(amount: int, _damage_type: String = "") -> void:
	if is_dead:
		return
	current_hp -= maxi(amount, 0)
	WorldState.update_survivor(key, {"hp": current_hp})
	if current_hp <= 0:
		_die()
		return
	say("hurt")
	_hurt_t = HURT_TIME
	_wind = -1.0
	_play("Hurt", true)


func receive_push(force: float) -> void:
	if is_dead:
		return
	_push_v = clampf(force, -260.0, 260.0)


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	current_hp = 0
	say("death", 2.5)
	remove_from_group("survivor_prey")
	if _talk_near:
		HUD.hide_world_prompt(self)
	z_index = 0
	_play("Death", true)
	_show_weapon(false, 0.0)
	tell.clear()
	WorldState.update_survivor(key, {"dead": true, "hp": 0, "x": global_position.x})
	Quests.on_survivor_died(rec)
	if weapon != "":
		WorldState.drop_item_from(self, weapon)
	var gift: String = str(rec.get("gift", ""))
	if gift != "" and not bool(rec.get("gave", false)):
		WorldState.drop_item_from(self, gift, {"amount": int(rec.get("gift_n", 0))})


func _lie_dead() -> void:
	is_dead = true
	behaviour = "dead"
	z_index = 0
	if animated_sprite.sprite_frames.has_animation("Death"):
		animated_sprite.animation = "Death"
		animated_sprite.frame = animated_sprite.sprite_frames.get_frame_count("Death") - 1
		animated_sprite.pause()


func _exit_tree() -> void:
	if _talk_near:
		HUD.hide_world_prompt(self)
	if not is_dead and key != "" and not scenery:
		WorldState.update_survivor(key, {"x": global_position.x, "hp": current_hp, "ammo": ammo})


# --- helpers -------------------------------------------------------------------------------------

func _play(anim: String, restart: bool = false) -> void:
	if animated_sprite == null or not animated_sprite.sprite_frames.has_animation(anim):
		return
	# a swing / knock plays through before anything else takes over
	if not restart and animated_sprite.animation == "Special" and animated_sprite.is_playing() and anim != "Hurt":
		return
	if restart or animated_sprite.animation != anim or not animated_sprite.is_playing():
		animated_sprite.play(anim)
		if restart:
			animated_sprite.frame = 0


func _move_by(step: float) -> void:
	var b := _bounds()
	global_position.x = clampf(global_position.x + step, b.x, b.y)


## Walks toward x (clamped to the place). True once there.
func _walk_to(x: float, speed: float, delta: float) -> bool:
	var b := _bounds()
	var tx := clampf(x, b.x, b.y)
	var d := tx - global_position.x
	if absf(d) < 2.0:
		_play("Idle")
		return true
	_face = signf(d) if absf(d) > 3.0 else _face
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


func _play_melee_sound() -> void:
	var set: Array = AllyCombat.melee_sounds(kind)
	_melee_player.stream = set[_rng.randi() % set.size()]
	_melee_player.pitch_scale = _rng.randf_range(0.9, 1.1)
	_melee_player.play()
