extends Node

var apartment_id: String = WorldState.current_apartment_id
var interactables: Array = []
var selected_index: int = 0
# BalconyPan backdrop mode: build THIS apartment (instead of the current one) as
# passive scenery — modules + balcony art, no player/door/loot/enemies. Set both
# BEFORE add_child(), like building_floors' setup_floor/passive.
var setup_apartment: String = ""
var passive: bool = false

# --- 3003 scripted tutorial (first run only) ------------------------------
# The neighbour encounter is a hand-paced state machine driven from _process:
# see the zombie → it lunges (pause → PUSH intro) → pause → find a weapon →
# three nodes reveal → scavenge under a slow approach → pause → attack (2-hit
# kill) → key drops → pause → heal prompt. Beats that pause the game are run
# through TutorialManager (dialogue + press-a-key resume). docs/TUTORIAL.md.
enum TutStep { INTRO, APPROACH, PUSH, WEAPON, SCAVENGE, COMBAT, HEAL, DONE }
# Low on purpose. Budget across the tutorial: 6 → −2 (3003 zombie) → −2 (3004
# barricade, teaching that barricades drain durability too) → 2 left for the
# hallway choice, where forcing the 3004 lock (−1) OR fighting the corridor
# zombie (−2, breaks the club) is a real either/or.
const TUT_CLUB_DURABILITY = 6
# The neighbour stands almost at the back wall; with the trigger at 200px the
# curiosity beat fires when the player is about a quarter into the final room.
const TUT_SEE_RANGE = 200.0     # player gets this close → curiosity + turn + release
# Matches the zombie's ATTACK_RANGE (30): the beat fires the instant she
# lunges (she stops to attack at 30, so waiting for closer would never
# trigger), and the taught push (range 40) connects with margin.
const TUT_LUNGE_RANGE = 30.0    # zombie this close → the scripted first lunge
var tut_step: int = -1          # -1 = not the tutorial apartment
var tut_zombie: Node = null
var tut_nodes: Array = []       # the three hidden anchors (junk / health / club)

const MODULE_SCENES = {
	"bedroom": "res://scenes/Room_Modules/bedroom.tscn",
	"bathroom": "res://scenes/Room_Modules/bathroom.tscn",
	"study": "res://scenes/Room_Modules/study.tscn",
	"kitchen": "res://scenes/Room_Modules/kitchen.tscn",
	"living_room": "res://scenes/Room_Modules/living_room.tscn",
	"dining_room": "res://scenes/Room_Modules/dining_room.tscn"
}

# Fixed first-run tutorial layouts. These use the REAL room modules (which
# carry the search anchors) with a deterministic room-type per slot, instead
# of the old Tutorial/ stub scenes (which had no anchors, so nothing could be
# searched — the tutorial's core loop was dead). 3003 is the scripted first
# apartment (living room / kitchen / bedroom); its three nodes and the paced
# neighbour encounter are set up in _setup_tutorial() / _tutorial_process().
const TUTORIAL_LAYOUTS = {
	"3002": ["living_room", "bedroom", "bathroom"],
	"3003": ["living_room", "kitchen", "bedroom"],
	"3004": ["study", "kitchen", "bathroom"],
	"3005": ["living_room", "dining_room", "kitchen"],
}

const MODULE_WIDTH = 320
const LEFT_WALL_X = 113
const CLICK_RADIUS = 10.0
const UI_FONT = preload("res://assets/fonts/PixelOperator8.ttf")

# The apartment interior in world space (tilemap measured y 207..367 = 160px
# tall; x comes from the tilemap per scene). The camera is LOCKED to this band
# (StairPan.apply_floor_camera) so it stops at the walls/ceiling instead of
# drifting into the grey void beside or above the apartment — same treatment
# building_floors gives a corridor. The tight band zooms the view in to fill it.
const ROOM_BAND_TOP := 207.0
const ROOM_BAND_H := 160.0

# Interior fire (Hazard 3 inside apartments). apartment_fire.gd is a no-sim, procedurally
# placed fire keyed to WorldState.apartment_active_fire_stage(floor,apt): LIGHT near the
# entrance, BLAZE across the room, CHARRED = scorch + smoke (no fire). See docs.
const APARTMENT_FIRE := preload("res://scripts/apartment_fire.gd")
const FIRE_BASE_Y_ROOM := 356.0        # room floor line the interior fire rises from (feet ~321+)
const FIRE_DMG_INTERVAL := 1.1         # a health hit this often while standing in interior flame
var _apt_fire = null
var _apt_fire_was_burning: bool = false
var _fire_dmg_acc: float = 0.0

const ANCHOR_RANGES = {
	"bedroom": [2, 5],
	"bathroom": [2, 5],
	"kitchen": [2, 5],
	"dining_room": [2, 4],
	"living_room": [2, 5],
	"study": [2, 4]
}

func _ready() -> void:
	# PASSIVE BACKDROP MODE (BalconyPan): build another apartment's interior as
	# scenery — modules + balcony art only, no player/door/loot/enemies — so the
	# apartment below can be stacked under this one during the descent pan.
	# Mirrors building_floors' setup_floor/passive pattern.
	if setup_apartment != "":
		apartment_id = setup_apartment
	if passive:
		_build_modules(WorldState.get_entrance_side(apartment_id), false)
		# The scene's own Player carries the room Camera2D — kill the camera
		# FIRST or it hijacks the view the frame this backdrop enters the tree.
		var pcam = get_node_or_null("Player/Camera2D")
		if pcam != null:
			pcam.enabled = false
		for dead_name in ["Player", "Area2D", "LootUI"]:
			var n = get_node_or_null(dead_name)
			if n != null:
				n.queue_free()
		# Populate the backdrop with the SAME enemies/bodies the live apartment
		# below will show, so they're already there during the descent pan instead
		# of popping in on landing. Frozen (no AI) — the real scene, with identical
		# deterministic spawns, replaces this within ~2s.
		_populate_passive_backdrop()
		return

	# MAINTENANCE ROOM (maintenance.tscn): a small SAFE room — NO enemies, no apartment
	# modules, just 2 scavenge anchors (toolbox/fuse-weighted) + a spot to rest. Reuses
	# this scene's Player / camera / exit-door and the scavenge interaction layer below.
	if _is_maintenance():
		_setup_maintenance()
		return

	var door = $Area2D
	var player = $Player
	var entrance_side = WorldState.get_entrance_side(apartment_id)
	var left_wall = $LeftWall
	var right_wall = $RightWall

	if entrance_side == "left":
		left_wall.process_mode = Node.PROCESS_MODE_DISABLED
		right_wall.process_mode = Node.PROCESS_MODE_ALWAYS
	else:
		right_wall.process_mode = Node.PROCESS_MODE_DISABLED
		left_wall.process_mode = Node.PROCESS_MODE_ALWAYS

	_build_modules(entrance_side, true)

	if entrance_side == "left":
		door.position.x = 96
		player.position.x = 140
		player.get_node("AnimatedSprite2D").flip_h = false
	else:
		door.position.x = 1072
		player.position.x = 1050
		player.get_node("AnimatedSprite2D").flip_h = true

	# Arrived by climbing DOWN a balcony (see player.begin_balcony_descent): land
	# OUT ON this apartment's balcony plane (not back on the corridor), so the
	# player can move along it, step back inside with S, or re-access it later.
	if WorldState.spawn_source == "balcony":
		var bslot = WorldState.balcony_slot_in_apartment(apartment_id)
		if bslot < 0:
			bslot = 0
		var bx = LEFT_WALL_X + bslot * MODULE_WIDTH + 50
		player.position.x = bx
		player.get_node("AnimatedSprite2D").flip_h = false
		if player.has_method("arrive_on_balcony_plane"):
			player.arrive_on_balcony_plane(bx)
		# A hard/roped-slip landing replays the hurt pose (HP already spent).
		if WorldState.balcony_arrival_hurt and player.has_method("flash_hurt"):
			player.flash_hurt()
		WorldState.balcony_arrival_hurt = false
		WorldState.spawn_source = ""

	# Spawn enemies — breached rooms use separate system with Big Zombie boss
	var door_state = WorldState.get_door_state(apartment_id)
	if door_state == WorldState.DoorState.BREACHED:
		_spawn_breached_enemies()
	elif WorldState.is_first_run and apartment_id == "3003":
		# The scripted first encounter: one zombie at the BACK of 3003 (the
		# GDD's weaponless first fight). Other tutorial apartments stay empty so
		# the player can learn to search in peace.
		tut_zombie = _spawn_tutorial_zombie(entrance_side)
	elif not (WorldState.is_first_run and WorldState.current_floor == 30):
		# Fire changes who's here (derived stage — a doused room's occupants still died in
		# the blaze that killed them): CHARRED = a dead ruin, no enemies; BLAZE = everyone
		# burned, so a couple of smouldering corpses instead of live enemies; LIGHT/none =
		# normal live spawn (they'll catch fire if they wander into the interior flames).
		var afs := WorldState.apartment_fire_stage(_apt_floor(), _apt_index())
		if afs == WorldState.FIRE_CHARRED:
			pass   # burnt-out ruin — no enemies
		elif afs == WorldState.FIRE_BLAZE:
			_spawn_burnt_corpses(1 + (hash(apartment_id) % 2))   # 1-2 burned corpses
		else:
			var zombie_count = WorldState.get_apartment_zombie_count(apartment_id)
			if zombie_count > 0:
				var apt_rng = RandomNumberGenerator.new()
				apt_rng.seed = hash(str(WorldState.master_seed) + "aptpos" + apartment_id)
				var zombie_scene = preload("res://scenes/enemy_zombie_standard.tscn")
				var positions = WorldState.get_zombie_positions(zombie_count, apt_rng, 150.0, 1030.0, 321.0)
				for pos in positions:
					var key = str(WorldState.current_floor) + ":" + str(snappedf(pos.x, 1.0)) + ":" + str(snappedf(pos.y, 1.0))
					if WorldState.killed_zombies.has(key):
						continue
					var zombie = zombie_scene.instantiate()
					zombie.global_position = pos
					zombie.spawn_key = key
					add_child(zombie)
					# Living-enemy memory: position + facing + health + alert (was
					# position only). See WorldState.apply_saved_zombie.
					WorldState.apply_saved_zombie(zombie)

	# Interior fire (after enemies, so burning enemies can already be in the room).
	_spawn_apartment_fire()

	# Charred ruin: a one-time (per game) non-interrupting line so the empty, burnt-out
	# room reads as "the fire got here first" — context for why there's nothing to scavenge.
	if WorldState.is_apartment_charred(_apt_floor(), _apt_index()) and not WorldState.charred_intro_shown:
		WorldState.charred_intro_shown = true
		HUD.show_dialogue("The fire gutted this place — everything's burned down to scrap and cinders.", "", false, 4.5)

	if WorldState.saved_player_x != 0.0:
		player.global_position = Vector2(WorldState.saved_player_x, WorldState.saved_player_y)
		WorldState.saved_player_x = 0.0
		WorldState.saved_player_y = 0.0
		# Loaded a save taken while OUT on a balcony plane: re-establish that plane
		# (held Y line + depth scale) so the player doesn't drift onto the default
		# line. bx mirrors the balcony-arrival branch above.
		if WorldState.saved_on_balcony_plane and player.has_method("restore_balcony_plane"):
			var rslot = WorldState.balcony_slot_in_apartment(apartment_id)
			if rslot < 0:
				rslot = 0
			player.restore_balcony_plane(LEFT_WALL_X + rslot * MODULE_WIDTH + 50)
		WorldState.saved_on_balcony_plane = false

	_after_modules_ready()
	_frame_camera(player)


func _frame_camera(player: Node) -> void:
	# Lock the view to the apartment's own bounds (see StairPan.apply_floor_camera,
	# shared with building_floors): horizontal extent from this scene's tilemap,
	# vertical to the measured interior band — so the camera never shows the grey
	# beyond the walls or above the ceiling, and zooms in to fill the apartment.
	if player == null:
		return
	var cam = player.get_node_or_null("Camera2D")
	var tm = get_node_or_null("TileMapLayer")
	if cam == null or tm == null:
		return
	var b = StairPan.clean_bounds(tm)
	var band = Rect2(Vector2(b.position.x, ROOM_BAND_TOP), Vector2(b.size.x, ROOM_BAND_H))
	StairPan.apply_floor_camera(cam, band)


func _exit_tree() -> void:
	# Don't leave the interior-fire haze lingering over the next scene.
	if HUD.has_method("set_smoke_fog"):
		HUD.set_smoke_fog(false)


func _apartment_fire_process(delta: float) -> void:
	# Interior fire, mirroring building_floors: standing in flame burns the player and any
	# enemies (they can walk into it and die), the HUD hazes while it burns/smoulders, and
	# fully dousing it records the apartment as OUT for this run (persists on re-entry).
	if passive:
		return   # a BalconyPan backdrop just RENDERS its fire; no damage/haze/douse
	if _apt_fire == null or not is_instance_valid(_apt_fire):
		return
	var player = get_node_or_null("Player")
	if player != null and player.has_method("receive_hit"):
		if _apt_fire.is_burning_at(player.global_position.x):
			_fire_dmg_acc += delta
			if _fire_dmg_acc >= FIRE_DMG_INTERVAL:
				_fire_dmg_acc = 0.0
				player.receive_hit(1)
		else:
			_fire_dmg_acc = 0.0
	# Enemies catch fire in the room too (skip dead corpses so they never re-light).
	for z in get_tree().get_nodes_in_group("zombie"):
		if ("is_dead" in z) and z.is_dead:
			if ("on_fire" in z) and z.on_fire:
				z.on_fire = false
			continue
		var inflame: bool = _apt_fire.is_burning_at(z.global_position.x)
		if "on_fire" in z:
			z.on_fire = inflame
		if inflame and z.has_method("burn_tick"):
			z.burn_tick(delta)
	if HUD.has_method("set_smoke_fog"):
		var smoky: bool = _apt_fire.any_burning() or _apt_fire.has_smoulder()
		HUD.set_smoke_fog(smoky, clampf(_apt_fire.smoke_intensity(), 0.0, 1.0))
	# Fully put out (was burning, now not) → record this apartment doused for the run.
	if _apt_fire_was_burning and not _apt_fire.any_burning():
		_apt_fire_was_burning = false
		WorldState.mark_apartment_fire_out(_apt_floor(), _apt_index())
		HUD.show_feedback("The fire's out.")


func _is_maintenance() -> bool:
	# The scene's own source path — set whether it's the live current_scene or instantiated
	# in a test harness, so both take the maintenance branch.
	return scene_file_path.ends_with("maintenance.tscn")


func _maintenance_key() -> String:
	# Per (floor, run) so its two anchors' searched/looted state persists on re-entry,
	# like an apartment's. Not a real apartment id (won't collide with "FF0A" ids).
	return "MAINT:" + str(WorldState.current_floor) + ":" + str(WorldState.current_run)


func _maintenance_loot(rng: RandomNumberGenerator) -> String:
	# A maintenance room is where you find repair gear and spare parts: heavily weighted
	# to Toolbox (019) and Fuse (020), with the odd bank-notes bundle; sometimes empty.
	var r := rng.randf()
	if r < 0.40:
		return "019"   # Toolbox (repairs)
	elif r < 0.70:
		return "020"   # Fuse (powers the elevator)
	elif r < 0.85:
		return "033"   # Bank Notes
	return ""          # empty this time


func _setup_maintenance() -> void:
	var player = $Player
	# Small enclosed room: both walls solid, player + exit door at fixed spots.
	$LeftWall.process_mode = Node.PROCESS_MODE_ALWAYS
	$RightWall.process_mode = Node.PROCESS_MODE_ALWAYS
	apartment_id = _maintenance_key()
	player.position = Vector2(300, 321)     # centre of the one-module room
	if WorldState.saved_player_x != 0.0:
		player.global_position = Vector2(WorldState.saved_player_x, WorldState.saved_player_y)
		WorldState.saved_player_x = 0.0
		WorldState.saved_player_y = 0.0
	# Set up the 2 scavenge anchors — toolbox/fuse-weighted loot, seeded + persistent.
	var interactable_script = load("res://scripts/interactable.gd")
	var mrng = RandomNumberGenerator.new()
	mrng.seed = hash(str(WorldState.master_seed) + "maint" + apartment_id)
	for child in get_children():
		if child is Marker2D and str(child.name).begins_with("anchor"):
			child.set_script(interactable_script)
			child.apartment_id = apartment_id
			child._ready()
			interactables.append(child)
			var passed = mrng.randf() <= 0.85   # most anchors have something here
			if not WorldState.is_anchor_searched(apartment_id, child.name):
				var item := _maintenance_loot(mrng)
				if passed and item != "":
					WorldState.set_anchor_item(apartment_id, child.name, item)
	_frame_camera(player)
	HUD.update_floor_label()


func _apt_floor() -> int:
	return int(apartment_id.left(apartment_id.length() - 2))


func _apt_index() -> int:
	return int(apartment_id.substr(apartment_id.length() - 2))


func _spawn_apartment_fire() -> void:
	# Interior fire, gated by the SAME predicate as the corridor door-frame fire
	# (apartment_active_fire_stage): only a burning apartment (door frame alight) has
	# interior fire; a charred one shows scorch + smoke; a doused-this-run or non-burning
	# one shows nothing. Placed with room geometry; joins the "fire_field" group so the
	# extinguisher + burn code find it here.
	var stage := WorldState.apartment_active_fire_stage(_apt_floor(), _apt_index())
	if stage < 0:
		return
	_apt_fire = APARTMENT_FIRE.new()
	_apt_fire.stage = stage
	_apt_fire.span0 = 140.0
	_apt_fire.span1 = 1040.0
	_apt_fire.base_y = FIRE_BASE_Y_ROOM
	var eside := WorldState.get_entrance_side(apartment_id)
	_apt_fire.entrance_x = 200.0 if eside == "left" else 980.0
	_apt_fire.seed_salt = apartment_id
	add_child(_apt_fire)
	_apt_fire_was_burning = _apt_fire.any_burning()


func _spawn_burnt_corpses(count: int) -> void:
	# A BLAZE-stage apartment: whoever was here burned. Spawn a couple of dead, smouldering
	# zombie corpses (no AI, no collision, no loot) instead of live enemies.
	var zombie_scene = preload("res://scenes/enemy_zombie_standard.tscn")
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(WorldState.master_seed) + "burntcorpse" + apartment_id)
	for k in range(count):
		var z = zombie_scene.instantiate()
		z.global_position = Vector2(280.0 + rng.randf() * 620.0, 321.0)
		add_child(z)
		if z.has_method("make_burnt_corpse"):
			z.make_burnt_corpse()


func _build_modules(entrance_side: String, live: bool) -> void:
	# The three interior modules + balcony art. `live` also spawns the balcony
	# descent zone (interactive) — passive backdrops get art only.
	var layout = WorldState.get_apartment_layout(apartment_id)
	for i in range(3):
		var scene_path: String
		if WorldState.is_first_run and TUTORIAL_LAYOUTS.has(apartment_id):
			var module_index = i if entrance_side == "left" else 2 - i
			scene_path = MODULE_SCENES[TUTORIAL_LAYOUTS[apartment_id][module_index]]
		else:
			scene_path = MODULE_SCENES[layout[i]]
		var scene = load(scene_path)
		var instance = scene.instantiate()
		instance.position.x = LEFT_WALL_X + (i * MODULE_WIDTH)
		instance.position.y = 224
		instance.add_to_group("room_module")
		add_child(instance)
		# The module's background ColorRect (+ its Label) is a Control that
		# defaults to MOUSE_FILTER_STOP, so it swallows every world click over
		# the apartment — click-to-move dies inside rooms (works in hallways,
		# whose backdrop is a Sprite). Make all module Controls click-through.
		for ctrl in _all_controls(instance):
			ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# The room-type label (e.g. "Study") is a big default-font Label that reads
		# huge and blurry once the camera zooms in — swap to the small pixel font.
		var room_label = instance.get_node_or_null("ColorRect/Label")
		if room_label != null:
			room_label.add_theme_font_override("font", UI_FONT)
			room_label.add_theme_font_size_override("font_size", 10)
		# Study/dining modules carry a Balcony node; reveal it only on a real
		# balcony slot (seeded pairs). Art shows on BOTH halves of a pair; only
		# the TOP gets a descent trigger, so descent is one-and-done.
		var bal_node = instance.get_node_or_null("Balcony")
		if bal_node != null:
			var show_balcony = WorldState.is_balcony_slot(apartment_id, i)
			bal_node.visible = show_balcony
			# The "BALCONY" tag → crisp pixel font (default font blurs when zoomed).
			var bal_tag = bal_node.get_node_or_null("Tag")
			if bal_tag != null:
				bal_tag.add_theme_font_override("font", UI_FONT)
			# A zone on EVERY revealed balcony (top AND bottom of a pair): the top
			# offers the descent, the bottom just lets the player step out onto its
			# plane / listen — the zone gates the actual climb-down on
			# is_balcony_descendable, so a bottom balcony is a viewpoint dead-end.
			if live and show_balcony:
				var zone = preload("res://scenes/balcony_zone.tscn").instantiate()
				zone.apartment_id = apartment_id
				zone.slot = i
				zone.position = Vector2(LEFT_WALL_X + i * MODULE_WIDTH + 50, 334)
				add_child(zone)


func _after_modules_ready() -> void:
	# Room tutorial hints: place BloodText nodes (scenes/blood_text.tscn) into
	# the Tutorial room modules in the editor — those modules only load on the
	# first run, so they're first-run-gated automatically. Any tagged
	# "tutorial_blood" here is hidden on later runs to be safe.
	if not WorldState.is_first_run:
		for hint in get_tree().get_nodes_in_group("tutorial_blood"):
			hint.visible = false

	var is_paradise = WorldState.is_paradise_apartment(apartment_id)
	var interactable_script = load("res://scripts/interactable.gd")

	# First-run tutorial apartments are FULLY scripted — a fixed set of clean
	# nodes, no random seeding, no repeats/extra "nothing found". Skip the normal
	# per-anchor loop for them; _setup_tutorial() (3003 encounter) and
	# _setup_tutorial_room() (3002/3004/3005) place exactly what's specified.
	var tutorial_apartment = WorldState.is_first_run and apartment_id in ["3002", "3003", "3004", "3005"]

	for module in (get_tree().get_nodes_in_group("room_module") if not tutorial_apartment else []):
		var room_type = ""
		for rt in MODULE_SCENES.keys():
			if module.get_node_or_null("ColorRect") != null:
				var label = module.get_node_or_null("ColorRect/Label")
				if label and label.text.to_lower().replace(" ", "_") == rt:
					room_type = rt
					break

		var all_anchors = []
		for child in module.get_children():
			if child is Marker2D:
				all_anchors.append(child)

		var anchor_rng = RandomNumberGenerator.new()
		anchor_rng.seed = hash(str(WorldState.master_seed) + apartment_id + room_type)
		for i in range(all_anchors.size() - 1, 0, -1):
			var j = anchor_rng.randi() % (i + 1)
			var temp = all_anchors[i]
			all_anchors[i] = all_anchors[j]
			all_anchors[j] = temp

		var range_data = ANCHOR_RANGES.get(room_type, [2, all_anchors.size()])
		var min_active = range_data[0]
		var max_active = min(range_data[1], all_anchors.size())
		var active_count = min_active + (anchor_rng.randi() % (max_active - min_active + 1))
		var active_anchors = all_anchors.slice(0, active_count)

		var apt_rng_items = RandomNumberGenerator.new()
		apt_rng_items.seed = hash(str(WorldState.master_seed) + "items" + apartment_id)

		# Per-apartment loot modifiers, computed once.
		# Barricaded doors are a time/stamina investment, so reward them with a
		# spawn-chance bonus (stacks with the locked bonus when both apply).
		var apt_door_state = WorldState.get_door_state(apartment_id)
		var is_barricaded = apt_door_state == WorldState.DoorState.BARRICADED_FORCEABLE or \
							 apt_door_state == WorldState.DoorState.BARRICADED_LOCKED
		var barricade_bonus = 0.12 if is_barricaded else 0.0
		# High enemy density burns through weapons and ammo, so bias the item pool
		# toward combat gear and thin out junk. tier 0 = quiet, 1-3 = denser.
		var zcount = WorldState.get_apartment_zombie_count(apartment_id)
		var density_tier = 0
		if zcount >= 10:
			density_tier = 3
		elif zcount >= 3:
			density_tier = 2
		elif zcount >= 1:
			density_tier = 1

		for anchor in active_anchors:
			anchor.set_script(interactable_script)
			anchor.apartment_id = apartment_id
			anchor._ready()

			# Determine spawn chance based on room type and door state
			var spawn_chance: float
			var locked = WorldState.is_locked_apartment(apartment_id)
			var key_opened = WorldState.was_key_opened(apartment_id)
			if key_opened:
				spawn_chance = 0.60  # Key-opened doors: best loot
			elif is_paradise:
				spawn_chance = 0.70
			elif locked:
				spawn_chance = 0.50  # Locked bonus even if forced
			else:
				match WorldState.current_run:
					1: spawn_chance = 0.40
					2: spawn_chance = 0.33
					3: spawn_chance = 0.27
					_: spawn_chance = 0.33

			spawn_chance = min(spawn_chance + barricade_bonus + WorldState.get_scavenge_bonus(), 0.95)

			# A CHARRED apartment is a burnt-out husk — nothing left to scavenge. Zero
			# the chance (the anchor still consumes its RNG draw so the seeded sequence
			# stays identical for un-charred re-entries).
			var _fnum := int(apartment_id.left(apartment_id.length() - 2))
			var _anum := int(apartment_id.substr(apartment_id.length() - 2))
			if WorldState.is_apartment_charred(_fnum, _anum):
				spawn_chance = 0.0

			# An anchor the player has already searched is settled — its item state
			# is whatever they left it as. We must NOT re-roll it (that's the dupe
			# exploit) and must NOT re-enable it via set_process if _ready() hid it.
			# But the seeded RNG sequence has to stay identical across re-entries, so
			# we still consume the exact same draws this anchor would have consumed,
			# then discard the result.
			var already_searched = WorldState.is_anchor_searched(apartment_id, anchor.name)

			if not already_searched:
				anchor.set_process(true)

			var passed_spawn_roll = apt_rng_items.randf() <= spawn_chance

			# Check if this anchor should spawn a key instead of a regular item
			var floor_num = int(apartment_id.left(apartment_id.length() - 2))
			if WorldState.should_anchor_spawn_key(apartment_id, anchor.name):
				var key_target = WorldState.get_key_target_for_anchor(floor_num, anchor.name)
				if passed_spawn_roll and not already_searched:
					WorldState.set_anchor_key(apartment_id, anchor.name, key_target)
			else:
				var valid_items = WorldState.get_items_for_anchor_weighted(anchor.name, apartment_id, density_tier)
				if valid_items.is_empty():
					continue
				var item_id = valid_items[apt_rng_items.randi() % valid_items.size()]
				if passed_spawn_roll and not already_searched:
					WorldState.set_anchor_item(apartment_id, anchor.name, item_id)

	# Gun/bullet pairing (balance): an apartment that rolled a Gun gets a 40%
	# seeded chance to convert one junk anchor into Bullets, so finding the
	# weapon usually means the means to feed it isn't far away.
	_pair_bullets_with_gun(apartment_id)

	# Tutorial rooms: 3003 = the scripted encounter (3 hidden nodes); 3002/3004/
	# 3005 = a fixed clean set of nodes (exact items/amounts, no repeats).
	if tutorial_apartment:
		if apartment_id == "3003":
			_setup_tutorial()
		else:
			_setup_tutorial_room(apartment_id)

	# 3002 is the tutorial's reward room — first entry is also the EARLIEST
	# place descent gets mentioned (never inside 3003).
	if WorldState.is_first_run and apartment_id == "3002":
		TutorialManager.say_once("3002_entry", TutorialManager.LINES["3002_entry"])

	# First floor-29 apartment on a tutorial run: guarantee a melee weapon so
	# the player is armed again after the club's gone (once only).
	if WorldState.is_first_run and WorldState.current_floor == 29 \
			and not WorldState.tutorial_f29_weapon_granted:
		_seed_tutorial_f29_weapon()

	await get_tree().process_frame
	WorldState.interaction_handled = false

	for module in get_tree().get_nodes_in_group("room_module"):
		for anchor in module.get_children():
			if anchor.has_method("try_interact") and anchor.visible:
				interactables.append(anchor)

	_spawn_corpses(WorldState.current_floor, WorldState.current_apartment_id)
	_spawn_world_drops(WorldState.current_floor)

func _all_controls(node: Node) -> Array:
	var out: Array = []
	if node is Control:
		out.append(node)
	for child in node.get_children():
		out.append_array(_all_controls(child))
	return out


func _spawn_tutorial_zombie(entrance_side: String) -> Node:
	# One guaranteed zombie at the BACK of 3003 (far from the entrance), unless
	# already killed. Fixed spawn_key so leaving and returning doesn't respawn
	# it. Scripted: frozen until the player draws near, slow once released,
	# 2-hit kill, and it yields the 3002 key on death.
	var key = "3003:tutorial"
	if WorldState.killed_zombies.has(key):
		return null
	var zombie = preload("res://scenes/enemy_zombie_standard.tscn").instantiate()
	# Almost at the back wall (the far wall from the entrance door).
	var back_x = 1035.0 if entrance_side == "left" else 155.0
	zombie.global_position = Vector2(back_x, 321)
	zombie.spawn_key = key
	zombie.tutorial_scripted = true
	zombie.tutorial_frozen = true
	zombie.drops_key = true
	zombie.key_target_apartment = "3002"
	if WorldState.zombie_positions.has(key):
		var saved = WorldState.zombie_positions[key]
		zombie.global_position = Vector2(saved["x"], saved["y"])
	add_child(zombie)
	# She starts FACING THE WALL — she only turns when the player calls out
	# (the chase logic flips her toward the player on release).
	zombie.animated_sprite.flip_h = entrance_side != "left"
	return zombie


func _setup_tutorial() -> void:
	# Place the three scripted nodes on real furniture anchors — junk, bandages,
	# golf club — hidden until the reveal beat. If the neighbour is already dead
	# (a return visit), skip the choreography and just expose whatever's left.
	var interactable_script = load("res://scripts/interactable.gd")
	var already_cleared = WorldState.killed_zombies.has("3003:tutorial")

	# Placement is SPATIAL, not furniture-flavoured: the player retreats from
	# the encounter at the back toward the entrance, so the nodes line up along
	# that path — junk (025, the panicked wasted search) is met first, then
	# bandages (006) mid-apartment, then the golf club (012) nearest the
	# entrance. Interior spans x 113..1073; targets mirror for a right-side
	# entrance (x' = 1186 - x). The spread also sets the pacing: three 3s
	# searches + walking against the neighbour's post-push shamble.
	var entrance_side = WorldState.get_entrance_side(apartment_id)
	var wants = [
		{"tag": "025", "x": 690.0},
		{"tag": "006", "x": 480.0},
		{"tag": "012", "x": 300.0},
	]
	var anchors: Array = []
	for module in get_tree().get_nodes_in_group("room_module"):
		for child in module.get_children():
			if child is Marker2D:
				anchors.append(child)

	for want in wants:
		var target_x: float = want["x"] if entrance_side == "left" else 1186.0 - want["x"]
		var chosen: Node = _pick_anchor(anchors, target_x)
		if chosen != null:
			_place_tutorial_item(chosen, want["tag"], interactable_script, not already_cleared)

	if already_cleared:
		tut_step = TutStep.DONE
	else:
		tut_step = TutStep.INTRO


func _pick_anchor(anchors: Array, target_x: float) -> Node:
	# The free anchor closest to the target x — real furniture, controlled
	# geometry.
	var best: Node = null
	var best_dist := INF
	for anchor in anchors:
		if anchor.get_meta("tutorial_used", false):
			continue
		var d: float = absf(anchor.global_position.x - target_x)
		if d < best_dist:
			best_dist = d
			best = anchor
	return best


func _place_tutorial_item(anchor: Node, tag: String, interactable_script, hidden: bool) -> void:
	if anchor.get_script() == null:
		anchor.set_script(interactable_script)
		anchor.apartment_id = "3003"
		anchor._ready()
	anchor.set_meta("tutorial_used", true)
	anchor.set_meta("tutorial_tag", tag)
	WorldState.set_anchor_item("3003", anchor.name, tag)
	tut_nodes.append(anchor)
	if hidden:
		# Hidden until the scripted reveal: no orb, not searchable, not collected
		# into `interactables` yet.
		anchor.visible = false
		anchor.set_process(false)
	else:
		anchor.visible = true
		anchor.set_process(true)
		interactables.append(anchor)


# Exact node contents for the controlled tutorial rooms (first run only). Each
# entry is one clean node; "" = a "nothing found" node. `amount` pins the
# pickup count for cash (033) / bullets (016). Only these nodes are active in
# the room — every other anchor stays off. (3003 is separate — the encounter.)
const TUT_ROOM_NODES = {
	"3002": [
		{"item": "011"},                 # Ice Pack
		{"item": "033", "amount": 10},   # Cash x10
		{"item": "032"},                 # Broken Umbrella (swapped out of 3004)
		{"item": "006"},                 # Bandages
	],
	"3004": [
		{"item": ""},                    # nothing found
		{"item": ""},                    # nothing found
		{"item": "033", "amount": 8},    # Cash x8
		{"item": "033", "amount": 4},    # Cash x4
		{"item": "034"},                 # Screwdriver — a FORCE-only reward for
		#                                  taking the barricade room; NOT in 3002
		#                                  (would let the key room defeat the
		#                                  force-vs-fight choice).
	],
	"3005": [
		{"item": "016", "amount": 8},    # Bullets x8
		{"item": "016", "amount": 3},    # Bullets x3
		{"item": ""},                    # nothing found
		{"item": ""},                    # nothing found
		{"item": "006"},                 # Bandages
	],
}


func _setup_tutorial_room(apt: String) -> void:
	# Activate exactly the specified nodes (in stable anchor order) and seed
	# their fixed contents. Leaves every other anchor OFF. Items the player has
	# already taken aren't re-seeded (re-entry safe).
	var spec: Array = TUT_ROOM_NODES.get(apt, [])
	if spec.is_empty():
		return
	var interactable_script = load("res://scripts/interactable.gd")
	var anchors: Array = []
	for module in get_tree().get_nodes_in_group("room_module"):
		for child in module.get_children():
			if child is Marker2D:
				anchors.append(child)
	for i in range(min(spec.size(), anchors.size())):
		var anchor = anchors[i]
		var entry: Dictionary = spec[i]
		if anchor.get_script() == null:
			anchor.set_script(interactable_script)
			anchor.apartment_id = apt
			anchor._ready()
		anchor.visible = true
		anchor.set_process(true)
		# (the post-await collection loop adds visible+scripted anchors to
		# `interactables`, so don't append here — would duplicate.)
		# Seed contents once (don't re-add something already taken).
		if not WorldState.is_anchor_searched(apt, anchor.name):
			WorldState.set_anchor_item(apt, anchor.name, entry["item"])
			if entry.has("amount"):
				WorldState.set_anchor_amount(apt, anchor.name, int(entry["amount"]))


func _seed_tutorial_f29_weapon() -> void:
	# Guarantee a melee weapon in the FIRST floor-29 apartment of a tutorial
	# run (post-tutorial kindness — the player just lost/broke the club). Seeded
	# pick from a small pool; sets the once-only flag.
	var pool = ["002", "013", "014", "017"]  # hammer / cricket / baseball / alu bat
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(str(WorldState.master_seed) + "f29weapon")
	var weapon_id = pool[rng.randi() % pool.size()]
	for module in get_tree().get_nodes_in_group("room_module"):
		for anchor in module.get_children():
			if anchor is Marker2D and anchor.get_script() != null and anchor.visible:
				WorldState.set_anchor_item(apartment_id, anchor.name, weapon_id)
				WorldState.tutorial_f29_weapon_granted = true
				return


func _reveal_tutorial_nodes() -> void:
	for anchor in tut_nodes:
		if not is_instance_valid(anchor):
			continue
		anchor.visible = true
		anchor.set_process(true)
		if not interactables.has(anchor):
			interactables.append(anchor)


# --- 3003 scripted state machine ------------------------------------------
# Poll-driven (runs even in combat mode); paused teaching beats hand off to
# TutorialManager, which resumes into the _on_tut_* callbacks below.

func _tutorial_process(_delta: float) -> void:
	if tut_step < 0 or tut_step == TutStep.DONE:
		return
	var player = get_node_or_null("Player")
	if player == null or tut_zombie == null or not is_instance_valid(tut_zombie):
		return
	var dist = player.global_position.distance_to(tut_zombie.global_position)
	match tut_step:
		TutStep.INTRO:
			# Curiosity on approach, then the neighbour stirs and starts closing.
			if dist <= TUT_SEE_RANGE:
				TutorialManager.say(TutorialManager.LINES["3003_curiosity"])
				tut_zombie.tutorial_release()
				tut_step = TutStep.APPROACH
		TutStep.APPROACH:
			if tut_zombie.is_dead:
				tut_step = TutStep.DONE
				return
			# First lunge: a scripted bite, then pause and teach the push.
			if dist <= TUT_LUNGE_RANGE:
				tut_step = TutStep.PUSH
				if player.has_method("receive_hit"):
					player.receive_hit(1)
				TutorialManager.prompt(
					TutorialManager.LINES["3003_push"], "push", _on_tut_push, "[Push]", true)
		TutStep.SCAVENGE:
			if tut_zombie.is_dead:
				tut_step = TutStep.DONE
				return
			# Grabbing the club ends the frantic search and cues the fight.
			if _tut_player_has("012"):
				tut_step = TutStep.COMBAT
				_tut_set_club_durability()
				WorldState.is_scavenge_mode = false
				HUD.update_mode_indicator()
				_tut_equip("012")
				TutorialManager.prompt(
					TutorialManager.LINES["3003_combat"], "interact",
					_on_tut_combat, "[E] to ready up")
		TutStep.COMBAT:
			if tut_zombie.is_dead:
				tut_step = TutStep.HEAL
				TutorialManager.prompt(
					TutorialManager.LINES["3003_heal"], "interact", _on_tut_heal, "[E], then use the bandages")


func _on_tut_push() -> void:
	# The player pushed: shove the neighbour and give it a long stagger, then
	# pause to send them searching for a weapon.
	var player = get_node_or_null("Player")
	if player != null and player.has_method("_do_push"):
		player._do_push()
	if is_instance_valid(tut_zombie):
		tut_zombie.tutorial_stagger()
	TutorialManager.prompt(
		TutorialManager.LINES["3003_weapon"], "interact", _on_tut_weapon, "[E] to continue")


func _on_tut_weapon() -> void:
	# Reveal the three nodes and drop into scavenge mode so searching works.
	_reveal_tutorial_nodes()
	WorldState.is_scavenge_mode = true
	HUD.update_mode_indicator()
	TutorialManager.say(TutorialManager.LINES["3003_weapon_go"])
	tut_step = TutStep.SCAVENGE


func _on_tut_combat() -> void:
	# Resumed into combat with the club equipped; the neighbour is 2 hits away.
	TutorialManager.say(TutorialManager.LINES["3003_combat_go"])


func _on_tut_heal() -> void:
	# The key realization — points at 3002, NOT at descending (descent talk
	# comes later, in 3002 / at the stairs).
	TutorialManager.say(TutorialManager.LINES["3003_key"])
	tut_step = TutStep.DONE


func _tut_player_has(item_id: String) -> bool:
	for instance in WorldState.inventory:
		if instance.item_id == item_id:
			return true
	return false


func _tut_equip(item_id: String) -> void:
	for i in range(WorldState.inventory.size()):
		if WorldState.inventory[i].item_id == item_id:
			HUD.selected_slot = i
			HUD._update_slot_highlights()
			return


func _tut_set_club_durability() -> void:
	for instance in WorldState.inventory:
		if instance.item_id == "012":
			instance.current_durability = TUT_CLUB_DURABILITY
			instance.is_depleted = false
			HUD.refresh_inventory()
			return


func _pair_bullets_with_gun(apt_id: String) -> void:
	var has_gun = false
	var junk_keys: Array = []
	for key in WorldState.anchor_items:
		if not key.begins_with(apt_id + ":"):
			continue
		var item_id = WorldState.anchor_items[key]
		if item_id == "004":
			has_gun = true
		elif ItemData.get_item(item_id).get("is_junk", false):
			junk_keys.append(key)
	if not has_gun or junk_keys.is_empty():
		return
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(str(WorldState.master_seed) + "gunpair" + apt_id)
	if rng.randf() < 0.40:
		var target_key = junk_keys[rng.randi() % junk_keys.size()]
		# Only convert anchors the player hasn't already resolved.
		var parts = target_key.split(":")
		if not WorldState.is_anchor_searched(parts[0], parts[1]):
			WorldState.anchor_items[target_key] = "016"


func _populate_passive_backdrop() -> void:
	# BalconyPan scenery: the enemies, corpses and world-drops of the apartment
	# BELOW, so the floor the player is dropping into isn't empty until landing.
	# Floor is derived from the backdrop's own id (not current_floor, which is
	# still the upper floor when this is prefetched on stepping onto the balcony).
	var floor_num = WorldState._apartment_floor(apartment_id)
	if floor_num <= 0:
		return
	var door_state = WorldState.get_door_state(apartment_id)
	if door_state == WorldState.DoorState.BREACHED:
		_spawn_passive_enemies(floor_num, true)
	else:
		_spawn_passive_enemies(floor_num, false)
	_spawn_corpses(floor_num, apartment_id)
	_spawn_world_drops(floor_num, apartment_id)
	# Interior fire in the backdrop too, so it's already there as the pan lands (no pop-in).
	_spawn_apartment_fire()


func _spawn_passive_enemies(floor_num: int, breached: bool) -> void:
	# Same deterministic spawns as the live room, but FROZEN: no player exists in
	# a backdrop, so live AI would chase the real player up in the scene above and
	# drift out of place before the swap. Static poses match the arrival exactly.
	var positions := []
	var big_first := false
	if breached:
		var enemy_list = WorldState.get_breached_room_enemies(apartment_id, 150.0, 1030.0, 321.0)
		for entry in enemy_list:
			positions.append(entry["position"])
		big_first = true
	else:
		var zombie_count = WorldState.get_apartment_zombie_count(apartment_id)
		if zombie_count <= 0:
			return
		var apt_rng = RandomNumberGenerator.new()
		apt_rng.seed = hash(str(WorldState.master_seed) + "aptpos" + apartment_id)
		positions = WorldState.get_zombie_positions(zombie_count, apt_rng, 150.0, 1030.0, 321.0)
	var std_scene = preload("res://scenes/enemy_zombie_standard.tscn")
	var big_scene = preload("res://scenes/enemy_zombie_big.tscn")
	for i in range(positions.size()):
		var pos = positions[i]
		var key = str(floor_num) + ":" + str(snappedf(pos.x, 1.0)) + ":" + str(snappedf(pos.y, 1.0))
		if WorldState.killed_zombies.has(key):
			continue
		var z = (big_scene if (big_first and i == 0) else std_scene).instantiate()
		z.global_position = pos
		z.spawn_key = key
		add_child(z)
		WorldState.apply_saved_zombie(z)
		z.process_mode = Node.PROCESS_MODE_DISABLED   # frozen scenery


func _spawn_world_drops(floor_num: int, apt_override: String = "") -> void:
	var scene_path = get_tree().current_scene.scene_file_path
	var apt := apt_override if apt_override != "" else WorldState.current_apartment_id
	var drops = WorldState.get_world_drops_for_floor(floor_num, scene_path, apt)
	if drops.is_empty():
		return
	var drop_scene = preload("res://scenes/world_drop.tscn")
	for drop_key in drops:
		var data = drops[drop_key]
		var drop = drop_scene.instantiate()
		drop.item_id = data["item_id"]
		drop.amount = int(data.get("amount", 0))
		drop.drop_key = drop_key
		drop.target_apartment = data.get("target_apartment", "")
		drop.global_position = Vector2(data["x"], data["y"])
		add_child(drop)

func _spawn_breached_enemies() -> void:
	var floor_num = WorldState.current_floor
	var enemy_list = WorldState.get_breached_room_enemies(apartment_id, 150.0, 1030.0, 321.0)

	var standard_scene = preload("res://scenes/enemy_zombie_standard.tscn")
	var big_scene = preload("res://scenes/enemy_zombie_big.tscn")

	for i in range(enemy_list.size()):
		var entry = enemy_list[i]
		var key = str(floor_num) + ":" + str(snappedf(entry["position"].x, 1.0)) + ":" + str(snappedf(entry["position"].y, 1.0))
		if WorldState.killed_zombies.has(key):
			continue

		# The boss is permanently bound to list slot 0. Previously the FIRST
		# SURVIVOR was promoted to boss, so killing the boss and revisiting
		# crowned a new one from the remaining zombies. Now a dead boss stays
		# dead and survivors stay standard. (Promotion-on-revisit is noted as a
		# possible deliberate mechanic for run 2/3 difficulty, not for run 1.)
		if i == 0:
			var boss = big_scene.instantiate()
			boss.global_position = entry["position"]
			boss.spawn_key = key
			boss.drops_key = true
			boss.key_target_apartment = WorldState.get_breached_boss_key_target(apartment_id)
			add_child(boss)
			WorldState.apply_saved_zombie(boss)
		else:
			var zombie = standard_scene.instantiate()
			zombie.global_position = entry["position"]
			zombie.spawn_key = key
			add_child(zombie)
			WorldState.apply_saved_zombie(zombie)


func _spawn_corpses(floor_num: int, apt_id: String = "") -> void:
	var scene_path = get_tree().current_scene.scene_file_path
	var corpse_positions = WorldState.get_corpse_positions_for_floor(floor_num, scene_path, apt_id)
	if corpse_positions.is_empty():
		return
	# Corpse visuals are type-aware: standard zombies have a looping "Dead_Dead"
	# frame; the big zombie has no Dead_Dead, so its corpse shows the final frame
	# of its "Death" animation, paused.
	var std_instance = preload("res://scenes/enemy_zombie_standard.tscn").instantiate()
	var std_frames = std_instance.get_node("AnimatedSprite2D").sprite_frames
	std_instance.queue_free()
	var big_instance = preload("res://scenes/enemy_zombie_big.tscn").instantiate()
	var big_frames = big_instance.get_node("AnimatedSprite2D").sprite_frames
	big_instance.queue_free()
	for entry in corpse_positions:
		var corpse = AnimatedSprite2D.new()
		corpse.scale = Vector2(3, 3)
		if entry["type"] == "big":
			corpse.sprite_frames = big_frames
			corpse.animation = "Death"
			corpse.frame = big_frames.get_frame_count("Death") - 1
		else:
			corpse.sprite_frames = std_frames
			corpse.animation = "Dead_Dead"
			corpse.autoplay = "Dead_Dead"
		corpse.global_position = entry["pos"]
		corpse.z_index = 0
		add_child(corpse)


# An anchor that's already been searched but still holds an item is known loot —
# the player should be able to re-access it by standing near it, without having to
# turn to face it. Unsearched anchors still require facing (discovery).
func _is_anchor_selectable(anchor: Node) -> bool:
	if not anchor.is_in_range:
		return false
	if WorldState.is_anchor_searched(anchor.apartment_id, anchor.name):
		var has_item = WorldState.get_anchor_item(anchor.apartment_id, anchor.name) != "" or \
					   WorldState.is_anchor_a_key(anchor.apartment_id, anchor.name)
		if has_item:
			return true
	return _is_player_facing_anchor(anchor)


func _is_player_facing_anchor(anchor: Node) -> bool:
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return false
	var sprite = player.get_node_or_null("AnimatedSprite2D")
	if sprite == null:
		return false
	var diff = anchor.global_position.x - player.global_position.x
	if abs(diff) < 8.0:
		return true
	if not sprite.flip_h and diff > 0:
		return true
	if sprite.flip_h and diff < 0:
		return true
	return false


func _process(_delta: float) -> void:
	_tutorial_process(_delta)
	_apartment_fire_process(_delta)

	if not WorldState.is_scavenge_mode:
		for i in interactables:
			if is_instance_valid(i):
				i.is_selected = false
		return

	var nearby: Array = []
	for i in interactables:
		if not is_instance_valid(i):
			continue
		if _is_anchor_selectable(i):
			nearby.append(i)

	for i in interactables:
		if is_instance_valid(i):
			i.is_selected = false

	if nearby.is_empty():
		selected_index = 0
		return

	selected_index = clamp(selected_index, 0, nearby.size() - 1)

	if Input.is_action_just_pressed("ui_focus_next"):
		selected_index = (selected_index + 1) % nearby.size()
	if Input.is_action_just_pressed("ui_focus_prev"):
		selected_index = (selected_index - 1 + nearby.size()) % nearby.size()

	nearby[selected_index].is_selected = true


func _input(event: InputEvent) -> void:
	if WorldState.loot_open:
		return  # the loot panel owns input while it's open (take with E / click)
	if not WorldState.is_scavenge_mode:
		return

	var nearby: Array = []
	for i in interactables:
		if not is_instance_valid(i):
			continue
		if _is_anchor_selectable(i):
			nearby.append(i)

	# Left-click scavenge must work even when no anchor is in range yet — that's
	# exactly when you click a FAR anchor to walk over to it. So handle LMB
	# before the nearby-empty guard; unhandled clicks fall through to the
	# player's own click-to-move in _unhandled_input.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_world = _get_mouse_world_pos()
		var player = get_tree().get_first_node_in_group("player")
		var clicked_index = _get_clicked_interactable(nearby, mouse_world) if not nearby.is_empty() else -1
		if clicked_index >= 0:
			selected_index = clicked_index
			WorldState.interaction_handled = false
			if player != null and player.has_method("auto_stance_for_anchor"):
				player.auto_stance_for_anchor(nearby[selected_index].global_position.y)
			nearby[selected_index].try_interact()
			get_viewport().set_input_as_handled()
			return
		# Distant anchor under the cursor: walk over and loot on arrival.
		for anchor in interactables:
			if not is_instance_valid(anchor) or not anchor.visible:
				continue
			if anchor.global_position.distance_to(mouse_world) <= 30.0:
				if player != null and player.has_method("set_move_target"):
					player.set_move_target(anchor.global_position.x, anchor)
					get_viewport().set_input_as_handled()
				return
		# Empty ground: let the player's _unhandled_input walk there.
		return

	if nearby.is_empty():
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			selected_index = (selected_index + 1) % nearby.size()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			selected_index = (selected_index - 1 + nearby.size()) % nearby.size()
			return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_E:
			WorldState.interaction_handled = false
			nearby[clamp(selected_index, 0, nearby.size() - 1)].try_interact()
			return


func _get_mouse_world_pos() -> Vector2:
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return Vector2.ZERO
	var cam = player.get_node_or_null("Camera2D")
	if cam == null:
		return Vector2.ZERO
	return cam.get_screen_center_position() + (get_viewport().get_mouse_position() - get_viewport().get_visible_rect().size / 2) / cam.zoom


func _get_clicked_interactable(nearby: Array, mouse_world: Vector2) -> int:
	var best_index = -1
	var best_dist = CLICK_RADIUS
	for i in range(nearby.size()):
		var d = nearby[i].global_position.distance_to(mouse_world)
		if d <= best_dist:
			best_dist = d
			best_index = i
	return best_index
