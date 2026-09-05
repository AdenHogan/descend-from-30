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
	# where it got to when you come back. Save under the floor THIS scene built
	# (_built_floor) — NOT WorldState.current_floor, which a stair transition has
	# already advanced to the destination by the time _exit_tree fires (that bug
	# saved the fire under the wrong floor, so it was gone on return).
	if HUD.has_method("set_smoke_fog"):
		HUD.set_smoke_fog(false)
	if _fire_field != null and is_instance_valid(_fire_field):
		var floor_num: int = _built_floor if _built_floor >= 0 else (setup_floor if setup_floor >= 0 else WorldState.current_floor)
		WorldState.set_fire_cells(floor_num, _fire_field.export_state())


var _built_floor: int = -1             # the floor THIS scene built (for _exit_tree save)


func _ready() -> void:
	var floor_num = setup_floor if setup_floor >= 0 else WorldState.current_floor
	_built_floor = floor_num
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
		# Register the elevator fire-extinguisher BEFORE _spawn_world_drops so it renders
		# in the backdrop too — otherwise a floor first reached via the seamless stair PAN
		# (which builds passively then go_live's) had no extinguisher until a full _ready.
		_place_elevator_kit(floor_num)
		_spawn_maintenance_door(floor_num)
		_spawn_world_drops(floor_num)
		# Spawn the FIRE in the backdrop too, so a floor you're panning UP toward shows
		# its fire AS IT SCROLLS INTO VIEW, not popping in only after the commit. It's
		# visual/sim only (no collision), so _make_inert leaves it alone; go_live sees
		# it's already here and doesn't re-spawn.
		_spawn_fire(floor_num)
		_spawn_door_fire(floor_num)
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
	elif WorldState.spawn_source == "elevator":
		# Stepped out of the lift — stand right by the elevator doors.
		player.global_position = Vector2(ELEVATOR_X, 388.0)

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
	_spawn_maintenance_door(floor_num)
	_spawn_world_drops(floor_num)
	_spawn_merchant(floor_num)
	_spawn_barricade_visuals(floor_num)
	_spawn_stair_hordes(floor_num)
	_spawn_fire(floor_num)
	_spawn_door_fire(floor_num)
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


# A stairwell "horde" is nothing special — just 3-4 STANDARD zombies that happen to be
# clustered at a stairwell. They spawn like any other enemy (normal AI, solid, chase),
# in the stair_horde group so kills there persist. Being live enemies near the steps,
# they block the crossing (stairwell.gd _horde_blocking) until cleared or lured off.
const STAIR_HORDE_MIN := 3
const STAIR_HORDE_MAX := 4
const HORDE_ECHO := preload("res://scripts/horde_echo.gd")
const CORRIDOR_PLANE_Y := 391.0        # the corridor walking line (== SPAWN_*_*.y)


# Stairwells (this floor) that carry a live-enemy hazard: {x, side}. Read by the
# approach-warning check in _process.
var _horde_warn_targets: Array = []


# --- Stairwell-shaft placement, derived from the visible staircase sprite ---
# The staircase art (353x443 tex) sits centred at ~(171, 348.6) left / (1179, …)
# right, scaled down to a ~80x115 world box: x[131,211], y[291,406], with the
# corridor standing line at 391. The x-band + top clip come straight from that
# sprite; the vertical SLICE + depth use the player's own transition constants
# (StairPan.DOWN_STAIR_APPROACH / DOWN_SHRED_FOOT / DOWN_DEPTH_SCALE) — no invented
# slice numbers. STACK_SPAN / BOB_AMP are only how the bunch is spread / how far it
# shuffles (motion, not slice geometry).
const STAIR_STACK_SPAN := 40.0       # how far up the steps the bunch is spread
const STAIR_BOB_AMP := 10.0          # how far each one shuffles up/down its spot


func _stair_art_box(on_left: bool) -> Dictionary:
	# The visible staircase sprite's world box (Hallway_Staircase_* when the side
	# goes DOWN, Lobby_* when it goes UP — exactly one is visible per side, set by
	# _apply_stair_visuals just before this runs). Returns {} if neither is found.
	var names: Array = ["HallwayStaircaseLeft", "LobbyLeft"] if on_left \
		else ["HallwayStaircaseRight", "LobbyRight"]
	for n in names:
		var s := get_node_or_null(n) as Sprite2D
		if s != null and s.visible and s.texture != null:
			var hw: float = s.texture.get_width() * absf(s.scale.x) * 0.5
			var hh: float = s.texture.get_height() * absf(s.scale.y) * 0.5
			return {
				"center_x": s.global_position.x,
				"half_w": hw,
				"top_y": s.global_position.y - hh,
			}
	return {}


func _spawn_stair_hordes(floor_num: int) -> void:
	# A horde is just 3-4 STANDARD zombies that spawn UP INSIDE the stairwell shaft
	# rather than out on the corridor. They shuffle on the steps, sliced to the
	# staircase opening (enemy enter_stairwell_mode, using the player's own stair
	# shredder), and come DOWN to chase the moment the player is near or a noise/can
	# pulls them — ordinary enemies from then on. Kills persist via stable per-floor
	# keys; while any is still IN the shaft it holds the crossing (stairwell.gd).
	var zombie_scene = preload("res://scenes/enemy_zombie_standard.tscn")
	for tname in _BARRICADE_TRIGGERS:
		var t = get_node_or_null(tname)
		if t == null or t.process_mode == Node.PROCESS_MODE_DISABLED:
			continue
		var choke: int = floor_num + int(_BARRICADE_TRIGGERS[tname])
		if not WorldState.is_stair_horde(choke):
			continue
		var on_left: bool = t.global_position.x < 600.0
		var box := _stair_art_box(on_left)
		# Centre the bunch in the staircase art; fall back to the trigger if the
		# sprite is missing for some reason (never leave a horde floor empty).
		var shaft_x: float = box.get("center_x", t.global_position.x)
		var half_w: float = box.get("half_w", 40.0)
		var shaft_min: float = shaft_x - half_w          # the staircase art's own x-extent
		var shaft_max: float = shaft_x + half_w
		var clip_top: float = box.get("top_y", CORRIDOR_PLANE_Y - 100.0)
		# The player's own mouth cut — the fixed line their descent is sliced through
		# (line just above the standing spot, plus the foot offset). Reused verbatim.
		var cut_y: float = (CORRIDOR_PLANE_Y - StairPan.DOWN_STAIR_APPROACH) + StairPan.DOWN_SHRED_FOOT
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(str(WorldState.master_seed) + "stairhordepos" + str(choke) + str(WorldState.current_run))
		var count: int = STAIR_HORDE_MIN + (rng.randi() % (STAIR_HORDE_MAX - STAIR_HORDE_MIN + 1))
		var step: float = STAIR_STACK_SPAN / float(maxi(count - 1, 1))
		# Add furthest-up FIRST so the lowest (nearest) is added last and draws on
		# top — "lower on the steps reads in front" without a per-frame z sort.
		for i in range(count - 1, -1, -1):
			var key := "%d:horde:%d:%d" % [floor_num, choke, i]
			if WorldState.killed_zombies.has(key):
				continue
			var rest_y: float = CORRIDOR_PLANE_Y - 6.0 - float(i) * step
			var z = zombie_scene.instantiate()
			z.global_position = Vector2(shaft_x + rng.randf_range(-3.0, 3.0), rest_y)
			z.spawn_key = key
			z.add_to_group("stair_horde")
			add_child(z)
			# A zombie met before (memory) comes back where it was left, on the
			# corridor — don't re-cage it in the shaft. Only fresh ones start up there.
			var restored = WorldState.apply_saved_zombie(z)
			if not restored:
				z.enter_stairwell_mode(rest_y, CORRIDOR_PLANE_Y, STAIR_BOB_AMP, cut_y,
					shaft_min, shaft_max, clip_top, on_left)
		# Colored danger cue radiating from the steps, and a warn target so the
		# player gets a first-time "I can hear them ahead" beat on approach.
		var echo = HORDE_ECHO.new()
		echo.global_position = Vector2(shaft_x, 320.0)
		add_child(echo)
		_horde_warn_targets.append({"x": shaft_x, "side": "left" if on_left else "right", "primed": false})


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
	# Fire memory: snapshot the fire's spread PERIODICALLY (not only in _exit_tree),
	# keyed by the floor THIS scene built. _exit_tree alone proved unreliable across a
	# stair transition (the fire came back empty), so we also keep a fresh snapshot on
	# a short cadence — leaving the floor any way keeps a ≤0.6s-old, correctly-keyed
	# copy, which _spawn_fire re-imports on return.
	if _fire_field != null and is_instance_valid(_fire_field):
		_fire_save_acc += delta
		if _fire_save_acc >= 0.6:
			_fire_save_acc = 0.0
			WorldState.set_fire_cells(_built_floor, _fire_field.export_state())
	# Fire damage: standing in flame costs health on a cadence (move or burn). You
	# can always walk THROUGH fire (it never blocks), you just take the burn.
	if _fire_field != null and player.has_method("receive_hit"):
		_fire_line_cd = maxf(_fire_line_cd - delta, 0.0)
		if _fire_field.fire_hot_at(player.global_position.x):
			_fire_dmg_acc += delta
			if _fire_dmg_acc >= FIRE_DMG_INTERVAL:
				_fire_dmg_acc = 0.0
				player.receive_hit(1)                     # the HUD portrait shows the health drop
				_say_fire_line()
		else:
			_fire_dmg_acc = 0.0
		# Smoke = ATMOSPHERE ONLY now. A fire fills the air with a gradually thickening,
		# slightly washed-out haze — no crouch, no choke damage, no world-space smoke
		# clouds (proper smoke art is coming). The fire itself is the threat. Strength
		# eases up with how much of the floor is alight; the HUD lerps it in, so it
		# builds gradually rather than snapping on.
		if HUD.has_method("set_smoke_fog"):
			# Haze lingers while the floor still SMOULDERS (doused or charred), not only
			# while it's actively burning — a burnt-out floor stays smoky.
			var smoky: bool = _fire_field.any_burning() or _fire_field.has_smoulder()
			HUD.set_smoke_fog(smoky, clampf(_fire_field.smoke_intensity(), 0.0, 1.0))
		# Enemies standing in the flames CATCH FIRE: a flame overlay + DOUBLE-damage
		# attacks. They go out the moment they step clear.
		for z in get_tree().get_nodes_in_group("zombie"):
			# A DEAD corpse doesn't burn — clear any flame it still carries (so the fire
			# vanishes the instant it dies) and never re-light it while it lingers.
			if ("is_dead" in z) and z.is_dead:
				if ("on_fire" in z) and z.on_fire:
					z.on_fire = false
				continue
			var z_inflame: bool = _fire_field.is_burning_at(z.global_position.x)
			if "on_fire" in z:
				z.on_fire = z_inflame
			# Fire damages enemies too — stand one in the flames and it burns down and
			# dies, same as the player would (driven here, where we know the fire).
			if z_inflame and z.has_method("burn_tick"):
				z.burn_tick(delta)
		# Door-frame flames are separate decals; clear each the moment the corridor fire
		# beside its door is doused, so no fire is left stacked by a door once it's out.
		# Only THIS floor's own decals (the group is global; a pan may hold two floors).
		for df in get_tree().get_nodes_in_group("door_fire"):
			if df.get_parent() == self and not _fire_field.burning_near(df.global_position.x, 44.0):
				df.queue_free()
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

	# Merchant sheltering behind the elevator doors while the floor burns: a one-time,
	# NON-interrupting line as the player nears the elevator, so the shut doors read as
	# the merchant's choice ("put the fire out first"), not a bug.
	if _merchant_pending_fire and not _merchant_shelter_line_shown \
			and absf(player.global_position.x - 1029.5) < 170.0:
		_merchant_shelter_line_shown = true
		HUD.show_dialogue("Merchant: Not a chance — I'm not opening these doors with the floor on fire. Put it out and we'll trade.", "", false, 4.5)

	_elevator_ride_process(player)


func _elevator_ride_process(player) -> void:
	# The corridor elevator is rideable once powered (3 fuses fitted at a maintenance
	# fuse box). On a MERCHANT floor the merchant has the car — the static Elevator
	# sprite is hidden and no ride is offered (they reclaimed it). Show an [E] Ride
	# prompt near the doors and cut to the interior on E.
	if _elevator_boarding:
		return
	if not WorldState.can_ride_elevator():
		HUD.hide_world_prompt(self)
		return
	var elevator = get_node_or_null("Elevator")
	if elevator == null or not elevator.visible:
		HUD.hide_world_prompt(self)
		return
	if absf(player.global_position.x - ELEVATOR_X) < ELEVATOR_RIDE_RANGE:
		HUD.show_world_prompt(self, "Elevator (powered)  [E] Ride", Vector2(ELEVATOR_X, 300.0))
		if Input.is_action_just_pressed("interact") and not TutorialManager.interact_guarded():
			HUD.hide_world_prompt(self)
			_board_elevator(elevator)
	else:
		HUD.hide_world_prompt(self)


var _elevator_boarding: bool = false
const ELEVATOR_TEX := preload("res://assets/Elevator.png")

func _board_elevator(elevator) -> void:
	# Immersion beat: the corridor doors slide open with a ding (like the merchant's),
	# THEN we cut to the interior — not an instant shift. Mirrors merchant.gd's door
	# tween (two halves of Elevator.png sliding apart + collapsing into the frame).
	_elevator_boarding = true
	_play_elevator_ding()
	var ex: float = elevator.global_position.x
	var ey: float = elevator.global_position.y
	elevator.visible = false
	# A dark interior behind the doors so the opening reveals the car's DEPTH (matching
	# the merchant's elevator, which draws the same recess behind its sliding doors).
	var interior := Polygon2D.new()
	interior.polygon = PackedVector2Array([Vector2(-29, -43), Vector2(29, -43), Vector2(29, 44), Vector2(-29, 44)])
	interior.color = Color(0.09, 0.09, 0.11)
	interior.global_position = Vector2(ex, ey)
	interior.z_index = 0
	add_child(interior)
	var dl := _make_door_half(Rect2(0, 0, 33, 88), Vector2(ex - 15.75, ey))
	var dr := _make_door_half(Rect2(33, 0, 33, 88), Vector2(ex + 15.75, ey))
	add_child(dl)
	add_child(dr)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(dl, "position:x", ex - 29.0, 0.45)
	tw.tween_property(dr, "position:x", ex + 29.0, 0.45)
	tw.tween_property(dl, "scale:x", 0.06, 0.45)
	tw.tween_property(dr, "scale:x", 0.06, 0.45)
	await tw.finished
	await get_tree().create_timer(0.2, false).timeout
	Transition.to_scene("res://scenes/elevator_interior.tscn")


func _make_door_half(region: Rect2, pos: Vector2) -> Sprite2D:
	var d := Sprite2D.new()
	d.texture = ELEVATOR_TEX
	d.region_enabled = true
	d.region_rect = region
	d.scale = Vector2(0.95454395, 1.011364)
	d.global_position = pos
	d.z_index = 0
	return d


func _play_elevator_ding() -> void:
	var p := AudioStreamPlayer.new()
	p.stream = preload("res://assets/audio/elevator_ding.wav")
	p.volume_db = -5.0
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


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
var _fire_save_acc: float = 0.0        # throttles the periodic fire-memory snapshot
var _fire_was_burning: bool = false    # to catch the moment the floor's fire goes out
const FIRE_DMG_INTERVAL := 1.1         # a health hit this often while standing in flame
# Throttle the player's fire voice lines so they don't spam every damage tick.
var _fire_line_cd: float = 0.0
const FIRE_LINE_COOLDOWN := 3.5
const FIRE_LINES := ["Agh! Burning!", "The flames — argh!", "It's burning me!", "Aah — too hot!"]


func _say_fire_line() -> void:
	if _fire_line_cd > 0.0:
		return
	_fire_line_cd = FIRE_LINE_COOLDOWN
	if HUD.has_method("show_speech"):
		HUD.show_speech(FIRE_LINES[randi() % FIRE_LINES.size()])
var _merchant_pending_fire: bool = false   # merchant is sheltering until the fire's out
var _merchant_shelter_line_shown: bool = false   # one-time "I won't come out" line per visit


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
	# Jitter the breakout point off the exact stair/mid anchors, seeded per floor, so
	# fires don't always sit at the same three spots (left stair / dead-centre / right
	# stair) floor after floor. Clamped to the walkable corridor.
	var jit := RandomNumberGenerator.new()
	jit.seed = hash(str(WorldState.master_seed) + "fireoriginjit" + str(floor_num))
	origin_x = clampf(origin_x + (jit.randf() - 0.5) * 240.0, 230.0, 1120.0)
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
	_set_stair_fire(_fire_field)                                # the third plane: fire in the down stairwell
	add_child(_fire_field)
	match stage:
		WorldState.FIRE_CHARRED:
			_fire_field.char_all()                              # burnt-out husk — no active fire
		WorldState.FIRE_BLAZE:
			_ignite_blaze_patches(floor_num, origin_x)         # patches across the WHOLE floor
		_:
			_ignite_light_patch(floor_num, origin_x)           # a small, seeded patch at the origin
	# Fire spreading INTO apartments: light flames at each burning apartment's door
	# so the creep is visible (charred floors are already whole-floor char_all'd).
	if stage != WorldState.FIRE_CHARRED:
		for apt in [1, 2, 3, 4, 5]:
			if WorldState.is_apartment_burning(floor_num, apt):
				var ax: float = float(WorldState.APARTMENT_X[apt])
				_fire_field.ignite_span(ax - 22.0, ax + 22.0)
	# Restore the fire's SPREAD from a previous visit this run (so it doesn't reset
	# to the spawn pattern every time you step out and back in). NOT on a CHARRED
	# ruin — a run-3 origin is burnt out, and importing a stale burning snapshot from
	# an earlier level (a real problem when F2-cycling lv1/lv2 -> lv3 in one run) would
	# re-light the ruin. char_all wins; the next periodic snapshot rewrites it clean.
	if stage != WorldState.FIRE_CHARRED and WorldState.has_fire_cells(floor_num):
		_fire_field.import_state(WorldState.get_fire_cells(floor_num))
	# Cap how far it may CREEP within the run. A run-1 LIGHT fire is ALLOWED to creep
	# — slowly (~15s/cell) — across a good chunk of the floor and toward nearby
	# apartments (it's problematic, but small enough to stay extinguishable); it just
	# never becomes the instant floor-wide wall a BLAZE is. A run-2+ BLAZE creeps
	# toward floor-wide (out of control). Escalation is across RUNS, not within one.
	# maxi(...) so a restored bigger state is never forced to shrink.
	var _cap: int = 26 if stage == WorldState.FIRE_BLAZE else 16
	_fire_field.spread_cap = maxi(_fire_field.burning_count(), _cap)
	_fire_was_burning = _fire_field.any_burning()
	_tint_fire_doors(floor_num)


func _ignite_light_patch(floor_num: int, origin_x: float) -> void:
	# LIGHT (a lv1 outbreak): a small patch AT the origin, but seeded per (floor, run)
	# so different floors light different cells (not the same fixed shape everywhere).
	var f = _fire_field
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(WorldState.master_seed) + "firelight" + str(floor_num) + str(WorldState.current_run))
	var c0: int = f.cell_at(origin_x)
	f.ignite_span(f.cell_x(c0), f.cell_x(c0))          # the heart always catches
	# 1-3 nearby cells, chosen by the seed (shuffled offsets), so the patch stays SMALL
	# (total 2-4 cells) but its shape varies floor to floor instead of a fixed stamp.
	var offs := [-2, -1, 1, 2, 3, 4]
	for i in range(offs.size() - 1, 0, -1):
		var j: int = rng.randi() % (i + 1)
		var tmp: int = offs[i]
		offs[i] = offs[j]
		offs[j] = tmp
	var extra: int = 1 + (rng.randi() % 3)             # 1..3 extra cells
	var added: int = 0
	for dc in offs:
		if added >= extra:
			break
		var ci: int = c0 + dc
		if ci >= 0 and ci < f.cell_count:
			f.ignite_span(f.cell_x(ci), f.cell_x(ci))
			added += 1


func _ignite_blaze_patches(floor_num: int, origin_x: float) -> void:
	# BLAZE (a lv2 fire): NOT one localised blob — a floor-WIDE scatter of burning
	# patches with gaps, so the whole corridor reads as ablaze. Seeded per (floor, run)
	# so the pattern is stable on re-entry but different floor to floor / game to game.
	var f = _fire_field
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(WorldState.master_seed) + "fireblaze" + str(floor_num) + str(WorldState.current_run))
	# a guaranteed cluster at the breakout origin (its hottest heart)
	var oc: int = f.cell_at(origin_x)
	for dc in [-1, 0, 1]:
		var hi: int = oc + dc
		if hi >= 0 and hi < f.cell_count:
			f.ignite_span(f.cell_x(hi), f.cell_x(hi))
	# then patches marching across the ENTIRE floor, each a 1-2 cell clump with a
	# 1-2 cell gap after — ~60% of the corridor alight, scattered, never a solid wall.
	var i: int = 0
	while i < f.cell_count:
		if rng.randf() < 0.62:
			var plen: int = 1 + (rng.randi() % 2)
			for k in range(plen):
				var ci: int = i + k
				if ci >= 0 and ci < f.cell_count:
					f.ignite_span(f.cell_x(ci), f.cell_x(ci))
			i += plen + 1 + (rng.randi() % 2)
		else:
			i += 1 + (rng.randi() % 2)


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


const FIRE_DECAL := preload("res://scripts/fire_decal.gd")
const DOOR_FIRE_BASE_Y := 420.0        # floor line the door flames climb from


func _spawn_door_fire(floor_num: int) -> void:
	# The apartment behind a BURNING door is alight, so fire licks OUT around the door
	# FRAME — flames climbing each edge (folder 3), leaving the doorway itself clear so
	# the player can see and enter. Placed at z0 (behind the player). Charred floors are
	# dead — no flame.
	if WorldState.fire_intensity(floor_num) == WorldState.FIRE_CHARRED:
		return
	var base := "res://assets/fire-pixel-art-animation-sprites/"
	var flame3 = load(base + "3 Flame/2.png")
	for apt in [1, 2, 3, 4, 5]:
		# Use the ACTIVE stage (doused-aware): a burning apartment licks flame around its
		# door frame, but one the player has put out this run shows none.
		if not (WorldState.apartment_active_fire_stage(floor_num, apt) in [WorldState.FIRE_LIGHT, WorldState.FIRE_BLAZE]):
			continue
		var door = get_node_or_null("apartment0" + str(apt))
		if door == null:
			continue
		var dx: float = door.global_position.x
		# SMALL flames hugging the base of each door edge, licking a little way UP the
		# frame — like the frame is catching. NOT tall torch pillars flanking the door
		# (that looked like a nightclub entrance). Kept low + tight to the frame so the
		# door stays clearly visible and enterable.
		_add_door_flame(flame3, 32, dx - 26.0, 30.0, 46.0, 1.3)     # left frame lick (low)
		_add_door_flame(flame3, 32, dx + 26.0, 30.0, 46.0, 2.6)     # right frame lick (low)


func _add_door_flame(tex, frame_px: int, x: float, w: float, h: float, phase: float) -> void:
	if tex == null:
		return
	var d = FIRE_DECAL.new()
	d.tex = tex
	d.frame_px = frame_px
	d.draw_w = w
	d.draw_h = h
	d.phase = phase
	d.z_as_relative = false
	d.z_index = 0                                                   # behind the player
	d.global_position = Vector2(x, DOOR_FIRE_BASE_Y)
	d.add_to_group("door_fire")                                     # so the extinguisher can clear it
	add_child(d)


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

func _set_stair_fire(ff) -> void:
	# Confine the down-stairwell fire to the SHAFT box (centre, half-width) and keep the
	# corridor fire out of the whole stair zone [keep_lo, keep_hi]. _apply_stair_visuals has
	# already set which Hallway_Staircase_* (the DOWN art) is visible.
	var hl := get_node_or_null("HallwayStaircaseLeft") as Sprite2D
	var hr := get_node_or_null("HallwayStaircaseRight") as Sprite2D
	if hl != null and hl.visible:
		ff.set_stair_fire(146.0, 26.0, 100.0, 235.0)     # left shaft box x[120,172] (owner-confirmed); zone clear of corridor fire
	elif hr != null and hr.visible:
		ff.set_stair_fire(1203.0, 26.0, 1114.0, 1249.0)  # right shaft (mirror about corridor centre)
	else:
		ff.set_stair_fire(-1.0)


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
	_built_floor = floor_num
	_restore_dormant()
	_apply_stair_visuals()        # arrival direction is only final now
	_enable_stair_triggers()
	_wake_scenery_zombies()
	# The PASSIVE backdrop build skipped every live hazard (they sit after the
	# `if passive: return` in _ready), so arriving via the seamless stair PAN left a
	# floor with NO fire / barricades / hordes — that was the "fire gone after stairs"
	# bug (apartments use the fade path, which runs the full _ready, so they were
	# fine). Spawn them here on adoption, same as a fresh build would. _spawn_fire
	# re-imports the saved spread, so the fire comes back exactly as it was left.
	_spawn_barricade_visuals(floor_num)
	_spawn_stair_hordes(floor_num)
	if _fire_field == null:            # the passive backdrop already built the fire
		_spawn_fire(floor_num)
		_spawn_door_fire(floor_num)
	_spawn_merchant(floor_num)


func _apply_doors(floor_num: int) -> void:
	for i in range(1, 6):
		var door = get_node_or_null("apartment0" + str(i))
		if door:
			door.apartment_id = str(floor_num) + "0" + str(i)
			door._apply_door_state()


func _place_elevator_kit(floor_num: int) -> void:
	# A wall fire-extinguisher by the elevator — but NOT on every floor. Like a real
	# building, some floors are missing one (seeded per floor), so the nearest canister may
	# be a floor or two away. A charred ruin is a dead husk — no kit. Persisted per (floor,
	# run) so it doesn't respawn after you take it.
	if WorldState.is_floor_charred(floor_num):
		return
	# Maintenance floors NEVER mount one — the door takes that wall. Clear any wall-mounted
	# extinguisher (y ~360) persisted here from before, even if a fire is on this floor;
	# it's on the player to go up/down for a canister.
	if WorldState.is_maintenance_floor(floor_num):
		for k in WorldState.world_drops.keys():
			var d = WorldState.world_drops[k]
			if int(d.get("floor", -1)) == floor_num and d.get("item_id", "") == "036" \
					and absf(float(d.get("y", 0.0)) - 360.0) < 8.0:
				WorldState.remove_world_drop(k)
		return
	var key := str(floor_num) + ":" + str(WorldState.current_run)
	if WorldState.elevator_kit_placed.get(key, false):
		return
	WorldState.elevator_kit_placed[key] = true
	# This floor may simply not have one — like a real building. If not, no canister here.
	if not WorldState.floor_has_extinguisher(floor_num):
		return
	# Mounted on the wall to the LEFT of the elevator, halfway between apartment 01
	# (x 829) and the elevator (x 1029.5) → x 929; y 360 sits it up on the wall at
	# door height (world_drop draws the extinguisher prop; pickup is the usual walk-up).
	WorldState.add_world_drop("036", Vector2(929.0, 360.0), floor_num)


const MAINT_DOOR_SCENE := preload("res://scenes/door.tscn")
const MAINT_DOOR_X := 929.0       # the old extinguisher wall spot (between apartment 01 and the elevator)
const ELEVATOR_X := 1029.5        # the corridor elevator sprite (building_floors.tscn)
const ELEVATOR_RIDE_RANGE := 80.0 # how close to the doors the [E] Ride prompt shows


func _spawn_maintenance_door(floor_num: int) -> void:
	# Every third floor gets a maintenance-room door in the wall between the elevator and
	# the right stairwell (where the extinguisher would otherwise mount). It's a plain,
	# always-open door that leads into maintenance.tscn — no lock/barricade.
	if not WorldState.is_maintenance_floor(floor_num):
		return
	if get_node_or_null("MaintenanceDoor") != null:
		return
	var d = MAINT_DOOR_SCENE.instantiate()
	d.name = "MaintenanceDoor"
	d.is_maintenance = true
	d.room_scene = "res://scenes/maintenance.tscn"
	d.apartment_id = "MAINT" + str(floor_num)
	d.global_position = Vector2(MAINT_DOOR_X, 364.0)   # apartment-door height
	add_child(d)


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
	# Rode the lift onto the merchant's own floor — they reclaim their elevator and
	# grumble about it (docs/MAINTENANCE_ELEVATOR.md), then trade as normal.
	if WorldState.spawn_source == "elevator":
		HUD.show_dialogue("Merchant: You rode MY elevator? Cheeky. Fine — you're here now. Let's trade.", "", false, 4.5)

func _spawn_world_drops(floor_num: int) -> void:
	var scene_path = get_tree().current_scene.scene_file_path
	var drops = WorldState.get_world_drops_for_floor(floor_num, scene_path)
	if drops.is_empty():
		return
	var drop_scene = preload("res://scenes/world_drop.tscn")
	var is_maint := WorldState.is_maintenance_floor(floor_num)
	for drop_key in drops:
		var data = drops[drop_key]
		# A maintenance floor NEVER shows a wall extinguisher — the door owns that wall.
		# Block it at the render layer too, so a canister persisted in an old save (or added
		# by any path) can never appear here regardless of the data-layer cleanup.
		if is_maint and data["item_id"] == "036":
			continue
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
