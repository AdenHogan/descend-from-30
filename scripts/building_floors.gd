extends Node2D

const SPAWN_LEFT_TOP = Vector2(148, 391)
const SPAWN_LEFT_BOTTOM = Vector2(188, 391)
const SPAWN_RIGHT_TOP = Vector2(1201, 391)
const SPAWN_RIGHT_BOTTOM = Vector2(1162, 391)

# Stair-pan support: a building_floors can be built as a PASSIVE backdrop for a
# specific floor — no player, enemies, corpses, drops, or merchant — so the
# seamless pan (StairPan) can show the adjacent floor beside the live one. Set
# these BEFORE add_child(). setup_floor -1 = use WorldState.current_floor.
var setup_floor: int = -1
var passive: bool = false

# Where a zombie actually RESTS after move_and_slide resolves its spawn overlap
# with the floor (spawn y is 388; recovery lifts it to ~370). Scenery zombies on
# a pan backdrop have no physics step, so they must be placed here directly or
# they sit sunk in the floor and warp upward on arrival.
const ZOMBIE_SETTLED_Y := 370.0


func _exit_tree() -> void:
	# Leaving the floor: clear the screen-space smoke fog so it doesn't linger on
	# the next (fire-free) floor, and SNAPSHOT the fire's spread so it's exactly
	# where it got to when you come back.
	if HUD.has_method("set_smoke_fog"):
		HUD.set_smoke_fog(false)
	if _fire_field != null and is_instance_valid(_fire_field):
		var floor_num: int = setup_floor if setup_floor >= 0 else WorldState.current_floor
		WorldState.set_fire_cells(floor_num, _fire_field.export_state())


func _ready() -> void:
	var floor_num = setup_floor if setup_floor >= 0 else WorldState.current_floor
	var player = get_node("Player")

	# Strip the junk row(s) above the ceiling so a floor is exactly its solid
	# content — floors then stack flush and the camera can frame one exactly.
	_strip_junk()

	# A passive backdrop instance carries no live PLAYER, but it DOES show the
	# floor's enemies: during a stair pan the player must see what's waiting on
	# the next floor as it scrolls into view, instead of it materialising out of
	# thin air the instant the floor commits. They're seeded identically to the
	# live spawn, so the same zombies stay in the same places across the commit.
	if passive:
		player.queue_free()
		player = null
		_apply_doors(floor_num)
		_apply_stair_visuals()
		_spawn_zombies(floor_num, true)
		_spawn_corpses(floor_num)
		_spawn_world_drops(floor_num)
		_make_inert()
		return

	if WorldState.spawn_source == "stair":
		if WorldState.stair_spawn_side == "left":
			if WorldState.stair_direction == "down":
				player.global_position = SPAWN_LEFT_BOTTOM
			elif WorldState.stair_direction == "up":
				player.global_position = SPAWN_LEFT_TOP
		elif WorldState.stair_spawn_side == "right":
			if WorldState.stair_direction == "down":
				player.global_position = SPAWN_RIGHT_BOTTOM
			elif WorldState.stair_direction == "up":
				player.global_position = SPAWN_RIGHT_TOP
	elif WorldState.spawn_source == "door" and WorldState.exit_spawn_x != 0.0:
		player.global_position.x = WorldState.exit_spawn_x
		player.global_position.y = 388.0

	if WorldState.saved_player_x != 0.0:
		player.global_position = Vector2(WorldState.saved_player_x, WorldState.saved_player_y)
		WorldState.saved_player_x = 0.0
		WorldState.saved_player_y = 0.0

	_apply_stair_visuals()
	_enable_stair_triggers()

	# Assign apartment IDs and apply correct door states AFTER IDs are set
	_apply_doors(floor_num)

	_spawn_zombies(floor_num, false)
	_spawn_corpses(floor_num)
	_place_elevator_kit(floor_num)
	_spawn_world_drops(floor_num)
	_spawn_merchant(floor_num)
	_spawn_barricade_visuals(floor_num)
	_spawn_stair_hordes(floor_num)
	_spawn_fire(floor_num)
	_frame_camera(player)
	# Keep the HUD floor counter honest for EVERY way of landing on a floor — not
	# just stair transitions. A dev jump / F2 rebuild used to leave it stale (e.g.
	# reading 30 while you stood on floor 24).
	HUD.update_floor_label()


# Which floor's down-stair choke each trigger represents. A choke sits on the
# staircase between two floors, keyed by the upper floor's down-stair, so a
# down-trigger checks this floor and an up-trigger checks the floor above.
const _BARRICADE_TRIGGERS := {
	"stair_left_down_trigger": 0, "stair_right_down_trigger": 0,
	"stair_left_up_trigger": 1, "stair_right_up_trigger": 1,
}
const BARRICADE_PROP := preload("res://scripts/barricade_prop.gd")
# The floor line the crate pile GROUNDS on (its bottom row sits here; the stair
# trigger sits up the opening at y 391). Tune here if the pile floats or sinks.
const BARRICADE_FLOOR_Y := 418.0


func _spawn_barricade_visuals(floor_num: int) -> void:
	# A crate prop at EACH active stairwell (both usable sides — up and down). Each
	# is told its choke floor and keeps ITSELF visible only while that stairwell is
	# barricaded (is_stair_blocked), so the crates can never disagree with the block
	# — they vanish the instant it's pried, and F2 shows/hides them live on both
	# sides. Disabled twins overlap the active one, so skip them (no double stack).
	for tname in _BARRICADE_TRIGGERS:
		var t = get_node_or_null(tname)
		if t == null or t.process_mode == Node.PROCESS_MODE_DISABLED:
			continue
		var prop = BARRICADE_PROP.new()
		prop.choke_floor = floor_num + int(_BARRICADE_TRIGGERS[tname])
		prop.global_position = Vector2(t.global_position.x, BARRICADE_FLOOR_Y)
		add_child(prop)


const STAIR_HORDE_MIN := 4
const STAIR_HORDE_MAX := 7
const HORDE_ECHO := preload("res://scripts/horde_echo.gd")
# Stairwells (this floor) that carry a live-enemy hazard: {x, side}. Read by the
# approach-warning check in _process.
var _horde_warn_targets: Array = []


func _spawn_stair_hordes(floor_num: int) -> void:
	# Hazard 2: a cluster of live zombies packed in front of a horde stairwell,
	# guarding it (both landings, so it blocks either direction). Kills persist via
	# stable per-floor keys, so clearing them sticks; luring them off (a thrown can)
	# frees the steps while they're away. See stairwell.gd for the block check.
	var zombie_scene = preload("res://scenes/enemy_zombie_standard.tscn")
	for tname in _BARRICADE_TRIGGERS:
		var t = get_node_or_null(tname)
		if t == null or t.process_mode == Node.PROCESS_MODE_DISABLED:
			continue
		var choke: int = floor_num + int(_BARRICADE_TRIGGERS[tname])
		if not WorldState.is_stair_horde(choke):
			continue
		var stair_x: float = t.global_position.x
		var on_left: bool = stair_x < 600.0
		# Pack them ONTO the stairwell — tight at the stair mouth and spilling only a
		# little into the corridor, so they read as a horde ON the steps rather than
		# milling out by the elevator. Left steps sit ~x120-200, right ~x1150-1230.
		var band_min: float = 120.0 if on_left else 1055.0
		var band_max: float = 300.0 if on_left else 1235.0
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(str(WorldState.master_seed) + "stairhordepos" + str(choke) + str(WorldState.current_run))
		var count: int = STAIR_HORDE_MIN + (rng.randi() % (STAIR_HORDE_MAX - STAIR_HORDE_MIN + 1))
		var positions = WorldState.get_zombie_positions(count, rng, band_min, band_max, 388.0)
		for i in range(positions.size()):
			var key := "%d:horde:%d:%d" % [floor_num, choke, i]
			if WorldState.killed_zombies.has(key):
				continue
			var z = zombie_scene.instantiate()
			# Pile them up the steps: the nearer the stairwell mouth, the higher they
			# sit (as if standing on higher stairs), so the cluster climbs into the
			# stairwell instead of standing in a flat row.
			var p: Vector2 = positions[i]
			p.y = 388.0 - clampf(58.0 - absf(p.x - stair_x) * 0.32, 0.0, 30.0)
			z.global_position = p
			z.spawn_key = key
			z.add_to_group("stair_horde")
			add_child(z)
			WorldState.apply_saved_zombie(z)
		# Colored danger cue radiating from the steps, and a warn target so the
		# player gets a first-time "I can hear them ahead" beat on approach.
		var echo = HORDE_ECHO.new()
		echo.global_position = Vector2(stair_x, 320.0)
		add_child(echo)
		_horde_warn_targets.append({"x": stair_x, "side": "left" if on_left else "right", "primed": false})


# How close (px) to a horde stairwell the first-approach warning fires. The
# "primed" gate means it only fires on an actual approach FROM a distance, not
# when you spawn straight onto a horde stairwell (you can already see that one).
const APPROACH_WARN_DIST := 400.0
# Only HORDE stairwells warn on approach — a barricade shows nothing until you
# get close and see the crates (owner's call). Fire will warn here too when built.
func _process(delta: float) -> void:
	var player = get_node_or_null("Player")
	if player == null:
		return
	var floor_num: int = setup_floor if setup_floor >= 0 else WorldState.current_floor
	# Horde approach warning (first time, from a distance).
	for target in _horde_warn_targets:
		var dist: float = absf(player.global_position.x - float(target["x"]))
		if not bool(target["primed"]):
			if dist > APPROACH_WARN_DIST:
				target["primed"] = true
			continue
		if dist <= APPROACH_WARN_DIST and not WorldState.hazard_warned(floor_num, target["side"]):
			WorldState.mark_hazard_warned(floor_num, target["side"])
			_warn_hazard("Wait — I can hear them ahead. The stairwell's crawling with them. Careful now.")
	# Fire damage: standing in flame costs health on a cadence (move or burn). You
	# can always walk THROUGH fire (it never blocks), you just take the burn.
	if _fire_field != null and player.has_method("receive_hit"):
		_fire_line_cd = maxf(_fire_line_cd - delta, 0.0)
		if _fire_field.is_burning_at(player.global_position.x):
			_fire_dmg_acc += delta
			# A run-1 LIGHT fire scorches at HALF the rate of a run-2+ BLAZE — you can
			# cross a small fire and only smart, a full blaze eats you fast.
			var burn_interval: float = FIRE_DMG_INTERVAL if _fire_field.stage >= _fire_field.STAGE_BLAZE else FIRE_DMG_INTERVAL * 2.0
			if _fire_dmg_acc >= burn_interval:
				_fire_dmg_acc = 0.0
				player.receive_hit(1)                     # the HUD portrait shows the health drop
				_say_fire_line()
		else:
			_fire_dmg_acc = 0.0
		# Smoke choke: thick smoke fills the upper air. Stand in it and you choke for
		# HALF the fire's damage-over-time; CROUCH under it to breathe (and to see —
		# it also fogs the view). Independent of the burn, so you can crouch-walk a
		# blaze, breathing but still scorched by the flames at your feet. Thickness
		# scales with how much of the floor is alight (a spread fire chokes at any stage).
		var thick_smoke: bool = _fire_field.smoke_intensity() > SMOKE_CHOKE_THRESHOLD and _fire_field.smoke_at(player.global_position.x)
		if thick_smoke and not player.is_crouching:
			_smoke_dmg_acc += delta
			if _smoke_dmg_acc >= SMOKE_DMG_INTERVAL:
				_smoke_dmg_acc = 0.0
				player.receive_hit(1)
				_say_smoke_line()
		else:
			_smoke_dmg_acc = 0.0
		# Standing in thick smoke FOGS your view (crouch under it to see). Screen-space,
		# so the overlay lives on the HUD; its strength scales with the smoke.
		if HUD.has_method("set_smoke_fog"):
			HUD.set_smoke_fog(thick_smoke and not player.is_crouching, _fire_field.smoke_intensity())
		# Enemies standing in the flames CATCH FIRE: a flame overlay + DOUBLE-damage
		# attacks. They go out the moment they step clear.
		for z in get_tree().get_nodes_in_group("zombie"):
			if "on_fire" in z:
				z.on_fire = _fire_field.is_burning_at(z.global_position.x)
		# The moment the WHOLE floor's fire is out (not just a path doused), it's
		# dealt with: record it cross-run so it can't re-ignite/escalate, and let
		# a sheltering merchant finally come out. A path-spray leaves cells burning,
		# so it does NOT count — ignore the fire and it comes back worse next run.
		if _fire_was_burning and not _fire_field.any_burning():
			_fire_was_burning = false
			WorldState.mark_fire_dealt_with(floor_num)
			if _merchant_pending_fire:
				_merchant_pending_fire = false
				_do_spawn_merchant()
				HUD.show_feedback("The fire's out — the merchant steps out to trade.")


func _warn_hazard(text: String) -> void:
	# A brief beat: freeze, show the player's warning, resume. The timer runs while
	# paused (process_always), so it always unfreezes.
	get_tree().paused = true
	HUD.show_dialogue(text)
	await get_tree().create_timer(0.7, true).timeout
	get_tree().paused = false


const FIRE_FIELD := preload("res://scripts/fire_field.gd")
var _fire_field = null                 # the floor's fire, or null
var _fire_dmg_acc: float = 0.0
var _smoke_dmg_acc: float = 0.0
var _fire_was_burning: bool = false    # to catch the moment the floor's fire goes out
const FIRE_DMG_INTERVAL := 1.1         # a health hit this often in a BLAZE (2x this in a LIGHT fire)
const SMOKE_DMG_INTERVAL := 2.2        # smoke chokes at HALF the fire's damage-over-time
# Smoke only chokes / fogs the view once it's genuinely THICK. Below this a small
# fire's wisp is cosmetic — it must NOT darken the screen or trigger a cough line
# when there's barely any smoke around (that read as a bug).
const SMOKE_CHOKE_THRESHOLD := 0.5
# Throttle the player's fire/smoke voice lines so they don't spam every damage tick.
var _fire_line_cd: float = 0.0
const FIRE_LINE_COOLDOWN := 3.5
const FIRE_LINES := ["Agh! Burning!", "The flames — argh!", "It's burning me!", "Aah — too hot!"]
const SMOKE_LINES := ["*cough* — I need to get under this smoke.", "*hack* — can't... breathe up here.", "*cough cough* — stay low."]


func _say_fire_line() -> void:
	if _fire_line_cd > 0.0:
		return
	_fire_line_cd = FIRE_LINE_COOLDOWN
	if HUD.has_method("show_speech"):
		HUD.show_speech(FIRE_LINES[randi() % FIRE_LINES.size()])


func _say_smoke_line() -> void:
	if _fire_line_cd > 0.0:
		return
	_fire_line_cd = FIRE_LINE_COOLDOWN
	if HUD.has_method("show_speech"):
		HUD.show_speech(SMOKE_LINES[randi() % SMOKE_LINES.size()])
var _merchant_pending_fire: bool = false   # merchant is sheltering until the fire's out


func _fire_origin_for(floor_num: int) -> float:
	# The x the fire breaks out at (persisted once, so it stays put): 40% at the
	# DOWN stair (the way you're heading), 40% MID-hallway, 20% at your ARRIVAL
	# stair (spawn straight into it — panic). Resolves the seeded kind against this
	# floor's actual stair positions.
	if WorldState.fire_origin_x.has(str(floor_num)):
		return WorldState.get_fire_origin_x(floor_num)
	var down_x := 250.0
	var up_x := 950.0
	for tname in _BARRICADE_TRIGGERS:
		var t = get_node_or_null(tname)
		if t == null or t.process_mode == Node.PROCESS_MODE_DISABLED:
			continue
		if int(_BARRICADE_TRIGGERS[tname]) == 0:
			down_x = t.global_position.x
		else:
			up_x = t.global_position.x
	var origin_x := 675.0
	match WorldState.fire_spawn_kind(floor_num):
		WorldState.FIRE_SPAWN_DOWN:
			origin_x = down_x
		WorldState.FIRE_SPAWN_ARRIVAL:
			origin_x = up_x
		_:
			origin_x = 675.0
	WorldState.set_fire_origin_x(floor_num, origin_x)
	return origin_x


func _spawn_fire(floor_num: int) -> void:
	# Hazard 3: fire on THIS floor (an outbreak origin, or a floor the blaze crept
	# onto across runs). Breaks out at its seeded origin (down/mid/arrival), and by
	# proximity has crept into nearby apartments — flames light at their doors.
	if not WorldState.is_stair_fire(floor_num):
		return
	var origin_x := _fire_origin_for(floor_num)
	var stage: int = WorldState.fire_intensity(floor_num)
	_fire_field = FIRE_FIELD.new()
	_fire_field.floor_num = floor_num
	_fire_field.stage = stage                                   # scales flame size + smoke
	add_child(_fire_field)
	match stage:
		WorldState.FIRE_CHARRED:
			_fire_field.char_all()                              # burnt-out husk
		WorldState.FIRE_BLAZE:
			_fire_field.ignite_span(origin_x - 280.0, origin_x + 280.0)   # most of the floor
		_:
			# LIGHT (run 1): a small, patchy fire around the origin (gaps, not a wall).
			var c0: int = _fire_field.cell_at(origin_x)
			for dc in [-2, 0, 2, 4]:
				var ci: int = c0 + dc
				if ci >= 0 and ci < _fire_field.cell_count:
					_fire_field.ignite_span(_fire_field.cell_x(ci), _fire_field.cell_x(ci))
	# Fire spreading INTO apartments: light flames at each burning apartment's door
	# so the creep is visible (charred floors are already whole-floor char_all'd).
	if stage != WorldState.FIRE_CHARRED:
		for apt in [1, 2, 3, 4, 5]:
			if WorldState.is_apartment_burning(floor_num, apt):
				var ax: float = float(WorldState.APARTMENT_X[apt])
				_fire_field.ignite_span(ax - 22.0, ax + 22.0)
	# Restore the fire's SPREAD from a previous visit this run (so it doesn't reset
	# to the spawn pattern every time you step out and back in).
	if WorldState.has_fire_cells(floor_num):
		_fire_field.import_state(WorldState.get_fire_cells(floor_num))
	_fire_was_burning = _fire_field.any_burning()
	_tint_fire_doors(floor_num)


func _tint_fire_doors(floor_num: int) -> void:
	# A burning apartment door glows hot; a charred one is blackened. (Loot is
	# separately suppressed for charred apartments in room.gd.)
	for apt in [1, 2, 3, 4, 5]:
		var door = get_node_or_null("apartment0" + str(apt))
		if door == null:
			continue
		if WorldState.is_apartment_charred(floor_num, apt):
			door.modulate = Color(0.32, 0.30, 0.30)
		elif WorldState.is_apartment_burning(floor_num, apt):
			door.modulate = Color(1.25, 0.85, 0.7)


func _frame_camera(player: Node) -> void:
	# Lock the view to the floor itself (see StairPan.apply_floor_camera): the
	# camera stops at the end walls instead of drifting past them into grey.
	if player == null:
		return
	var cam = player.get_node_or_null("Camera2D")
	var tm = get_node_or_null("TileMapLayer")
	if cam == null or tm == null:
		return
	StairPan.apply_floor_camera(cam, StairPan.floor_band(tm))


func _enable_stair_triggers() -> void:
	# The side you ARRIVED on offers the way back (its return trigger is live); the
	# far side carries your journey on. Exactly one trigger per side is active, so
	# the descent zig-zags. Shared by a live spawn (_ready) and by go_live() when a
	# prefetched backdrop is woken — the arrival direction is only final at that
	# point, so both go through here.
	var left_down = get_node_or_null("stair_left_down_trigger")
	var left_up = get_node_or_null("stair_left_up_trigger")
	var right_down = get_node_or_null("stair_right_down_trigger")
	var right_up = get_node_or_null("stair_right_up_trigger")
	if left_down == null or left_up == null or right_down == null or right_up == null:
		return
	# Default everything on (ALWAYS, as the original did), then disable the one on
	# each side that would send you straight back the way you just came.
	for t in [left_down, left_up, right_down, right_up]:
		t.process_mode = Node.PROCESS_MODE_ALWAYS
	if WorldState.stair_spawn_side == "left":
		if WorldState.stair_direction == "down":
			left_down.process_mode = Node.PROCESS_MODE_DISABLED
			right_up.process_mode = Node.PROCESS_MODE_DISABLED
		else:
			left_up.process_mode = Node.PROCESS_MODE_DISABLED
			right_down.process_mode = Node.PROCESS_MODE_DISABLED
	elif WorldState.stair_spawn_side == "right":
		if WorldState.stair_direction == "down":
			right_down.process_mode = Node.PROCESS_MODE_DISABLED
			left_up.process_mode = Node.PROCESS_MODE_DISABLED
		else:
			right_up.process_mode = Node.PROCESS_MODE_DISABLED
			left_down.process_mode = Node.PROCESS_MODE_DISABLED

func _apply_stair_visuals() -> void:
	# WHICH staircase art each side shows.
	#
	# Art meaning (from where each is used): Lobby_* is the UP stairwell — the
	# lobby is the bottom of the building and can only go up. Hallway_Staircase_*
	# is the DOWN stairwell — floor 30 is the top and can only go down.
	#
	# The rule mirrors the stair TRIGGERS enabled in _ready: the side you arrived
	# on offers the way BACK (you came down it, so from here it goes up), and the
	# far side continues your journey. Exactly one side is up and one is down, so
	# the descent zig-zags across the corridor.
	#
	# The old version ignored stair_direction for left arrivals, so the left was
	# always drawn as an up-staircase — floor 25 and 26 showed the same art, and
	# a side whose trigger said "up" could be drawn descending.
	var hl := get_node_or_null("HallwayStaircaseLeft") as Sprite2D
	var ll := get_node_or_null("LobbyLeft") as Sprite2D
	var hr := get_node_or_null("HallwayStaircaseRight") as Sprite2D
	var lr := get_node_or_null("LobbyRight") as Sprite2D
	if hl == null or ll == null or hr == null or lr == null:
		return
	var came_down: bool = WorldState.stair_direction == "down"
	var arrived_left: bool = WorldState.stair_spawn_side != "right"
	# Arrival side goes back the way you came; the other side carries on.
	var left_goes_up: bool = came_down if arrived_left else not came_down
	var right_goes_up: bool = not left_goes_up

	ll.visible = left_goes_up          # Lobby_Left  = UP
	hl.visible = not left_goes_up      # Hallway_Staircase_Left = DOWN
	lr.visible = right_goes_up
	hr.visible = not right_goes_up

	# NOTE: there is no front-layer occluder here, and adding one back is a
	# mistake. See _apply_stair_visuals's history / docs/STAIRWELL_LAYERS.md:
	# re-cutting the top of the staircase art and drawing it at z 2 draws the
	# DARK SHAFT over the corridor as a black box. The shredder hides the player,
	# not an occluder.


func _spawn_zombies(floor_num: int, as_scenery: bool) -> void:
	# Same seed either way, so a backdrop's zombies and the committed floor's
	# zombies are the SAME zombies in the same places — that's what makes them
	# scroll into view during the pan rather than pop in on arrival.
	var floor_rng = RandomNumberGenerator.new()
	floor_rng.seed = (WorldState.master_seed ^ (floor_num * 2246822519)) & 0xFFFFFFFF
	var zombie_count = WorldState.get_floor_zombie_count(floor_num)
	var zombie_scene = preload("res://scenes/enemy_zombie_standard.tscn")
	# A pried crossing dumps you onto a floor whose dead have gathered at the
	# stairwell you just tore open: cluster this floor's horde by the arrival
	# stairs and rouse them (below), instead of the usual even corridor spread.
	var pried_arrival: bool = (not as_scenery) and WorldState.pending_pry_arrival_floor == floor_num
	# Cross-floor noise pull: loud noise you made near this floor's stairwell has
	# roused the dead SEEDED NEAR that same stairwell (only them). They keep their
	# seeded spots (so kill/memory keys stay stable) but wake and converge.
	var stair_pull: bool = (not as_scenery) and not pried_arrival and WorldState.has_stair_pull(floor_num)
	var arrived_left: bool = WorldState.stair_spawn_side != "right"
	var pull_near_x: float = 265.0 + WorldState.STAIR_PULL_NEAR if arrived_left else 1105.0 - WorldState.STAIR_PULL_NEAR
	# Keep clear of both stairwells (the corridor runs 115..1235): a zombie spawned
	# behind the stair art was effectively invisible until it moved.
	var positions: Array
	if pried_arrival:
		var band_min: float = 245.0 if arrived_left else 895.0
		var band_max: float = 470.0 if arrived_left else 1105.0
		positions = WorldState.get_zombie_positions(zombie_count, floor_rng, band_min, band_max, 388.0)
	else:
		positions = WorldState.get_zombie_positions(zombie_count, floor_rng, 265.0, 1105.0, 388.0)
	for pos in positions:
		var key = str(floor_num) + ":" + str(snappedf(pos.x, 1.0)) + ":" + str(snappedf(pos.y, 1.0))
		if WorldState.killed_zombies.has(key):
			continue
		var zombie = zombie_scene.instantiate()
		zombie.global_position = pos
		zombie.spawn_key = key
		if as_scenery:
			zombie.add_to_group("pan_scenery")
		add_child(zombie)
		# Living-enemy memory: a zombie met before comes back exactly where it was
		# left — facing, health and alert too — instead of its seeded spawn. Only
		# when it has NO memory does the scenery-settle below apply.
		var restored = WorldState.apply_saved_zombie(zombie)
		if as_scenery:
			# A live zombie spawns overlapping the floor and move_and_slide lifts
			# it to rest; a scenery zombie has no physics step, so it would stay
			# sunk ~18px and then visibly WARP up the moment the floor commits.
			# Place a FRESH one where the live one ends up (guarded by
			# building_floors_test); a restored one already carries a settled Y.
			if not restored:
				zombie.global_position.y = ZOMBIE_SETTLED_Y
			# Visible, but no AI and no noise — it must not hunt the player, who
			# is still a whole floor away. Disabled AFTER add_child so the
			# zombie's own _ready can't turn its physics step back on.
			# _make_inert() strips its collision separately.
			zombie.set_physics_process(false)
		elif pried_arrival:
			# Roused by the racket you made levering through: aware and converging
			# on the stairwell instead of dozing in the corridor.
			zombie.alert_to_noise(12.0)
		elif stair_pull:
			# Only the dead seeded near the arrival stairwell heard you through it.
			var near_stair: bool = (arrived_left and pos.x <= pull_near_x) \
				or ((not arrived_left) and pos.x >= pull_near_x)
			if near_stair:
				zombie.alert_to_noise(12.0)
	# Both muster effects are one-shots: consume them so a later ordinary visit
	# to this floor spawns the plain, dozing corridor spread again.
	if pried_arrival:
		WorldState.pending_pry_arrival_floor = -1
	if stair_pull:
		WorldState.consume_stair_pull(floor_num)


func _strip_junk() -> void:
	var tm = get_node_or_null("TileMapLayer")
	if tm != null:
		StairPan.strip_junk_rows(tm)


# Each CollisionObject2D this floor put dormant, with its ORIGINAL values, so a
# prefetched backdrop can be woken back to a fully live floor exactly as it was
# (see go_live). Empty on a live floor.
var _dormant: Array = []


func _make_inert() -> void:
	# A stacked neighbour floor is SCENERY. Once it's offset into real world space
	# its collision bodies and Area2D triggers would otherwise block/teleport the
	# player on the live floor, so strip all physics + interaction from it and
	# leave only what's drawn — recording each change so go_live can restore it.
	_dormant.clear()
	_disable_physics_recursive(self)


func _disable_physics_recursive(node: Node) -> void:
	if node is CollisionObject2D:
		var scenery := node.is_in_group("pan_scenery")
		_dormant.append({
			"node": node,
			"layer": node.collision_layer,
			"mask": node.collision_mask,
			"monitoring": node.monitoring if node is Area2D else false,
			"monitorable": node.monitorable if node is Area2D else false,
			"pickable": node.input_pickable,
			"process_mode": node.process_mode,
		})
		# Off every layer/mask: no blocking, no overlaps, no input picking.
		node.collision_layer = 0
		node.collision_mask = 0
		if node is Area2D:
			node.monitoring = false
			node.monitorable = false
		node.input_pickable = false
		# Scenery zombies keep processing so their idle animation still plays as
		# they scroll into view (their AI is already off via set_physics_process).
		if not scenery:
			node.process_mode = Node.PROCESS_MODE_DISABLED
	for child in node.get_children():
		_disable_physics_recursive(child)


func _restore_dormant() -> void:
	# Exact inverse of _make_inert: put every recorded property back to what it was
	# on the built floor, so a woken backdrop is indistinguishable from a floor
	# that spawned live.
	for e in _dormant:
		var n = e["node"]
		if not is_instance_valid(n):
			continue
		n.collision_layer = e["layer"]
		n.collision_mask = e["mask"]
		if n is Area2D:
			n.monitoring = e["monitoring"]
			n.monitorable = e["monitorable"]
		n.input_pickable = e["pickable"]
		n.process_mode = e["process_mode"]
	_dormant.clear()


func _wake_scenery_zombies() -> void:
	# Turn the pan backdrop's frozen scenery zombies into real ones: their
	# collision came back via _restore_dormant, so here just give them their AI
	# and drop the scenery tag. Step 1's memory already placed them correctly.
	for z in get_tree().get_nodes_in_group("pan_scenery"):
		if not is_ancestor_of(z):
			continue
		z.remove_from_group("pan_scenery")
		z.set_physics_process(true)


# Wake a floor that was BUILT as a passive/inert backdrop into a fully live one,
# WITHOUT re-running _ready (so no current_scene-null crash). Restores everything
# _make_inert stripped, does the live-only setup the passive build skipped
# (merchant, camera stays with the caller), and re-derives the direction-
# dependent bits now that the arrival is final. The live player is reparented in
# by the caller before this runs.
func go_live() -> void:
	if not passive:
		return
	passive = false
	var floor_num = setup_floor if setup_floor >= 0 else WorldState.current_floor
	_restore_dormant()
	_apply_stair_visuals()        # arrival direction is only final now
	_enable_stair_triggers()
	_wake_scenery_zombies()
	_spawn_merchant(floor_num)


func _apply_doors(floor_num: int) -> void:
	for i in range(1, 6):
		var door = get_node_or_null("apartment0" + str(i))
		if door:
			door.apartment_id = str(floor_num) + "0" + str(i)
			door._apply_door_state()


func _place_elevator_kit(floor_num: int) -> void:
	# A fire extinguisher mounted on the wall by the elevator — on EVERY floor,
	# like a real building. A persisted world-drop placed ONCE per (floor, run) so
	# it doesn't respawn after you take it (added before _spawn_world_drops so its
	# pickup renders now). A charred ruin is a dead husk — no kit there. Spreading
	# fire may outrun one canister, so the point is you can backtrack for more.
	if WorldState.is_floor_charred(floor_num):
		return
	var key := str(floor_num) + ":" + str(WorldState.current_run)
	if WorldState.elevator_kit_placed.get(key, false):
		return
	WorldState.elevator_kit_placed[key] = true
	WorldState.add_world_drop("036", Vector2(915.0, 388.0), floor_num)


func _spawn_merchant(floor_num: int) -> void:
	if floor_num not in WorldState.MERCHANT_FLOORS:
		return
	# A fire on the merchant's floor keeps them behind the doors — they won't come
	# out to trade until it's dealt with. If the player puts it out this run, the
	# merchant emerges (see _process); if it's left to burn, they simply don't
	# appear on this floor across runs (too dangerous) while other merchant floors
	# still trade normally.
	if WorldState.is_stair_fire(floor_num):
		_merchant_pending_fire = true
		return
	_do_spawn_merchant()


func _do_spawn_merchant() -> void:
	# The merchant scene renders its own elevator (interior + sliding doors),
	# so the hallway's static Elevator sprite is hidden on merchant floors.
	var static_elevator = get_node_or_null("Elevator")
	if static_elevator:
		static_elevator.visible = false
	var merchant = preload("res://scenes/merchant.tscn").instantiate()
	merchant.global_position = Vector2(1029.4999, 356.50003)
	add_child(merchant)

func _spawn_world_drops(floor_num: int) -> void:
	var scene_path = get_tree().current_scene.scene_file_path
	var drops = WorldState.get_world_drops_for_floor(floor_num, scene_path)
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

func _spawn_corpses(floor_num: int) -> void:
	var scene_path = get_tree().current_scene.scene_file_path
	var corpse_positions = WorldState.get_corpse_positions_for_floor(floor_num, scene_path)
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
