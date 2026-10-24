extends Node2D

# THE TITLE'S LIVE HALL (owner round 48g: "live scenes inside the building, hallways looking ominous, blinking lights, bloody walls, enemies
# shambling, darkness, etc."; docs/OPENING.md "Title"). The opening already shows the OUTSIDE of the tower, so the title lives INSIDE it: one
# corridor of the real building, in the dark of the third night, seen at the game's own zoom.
#
# It is built from the game's own pieces, never redrawn: the corridor's painted art (`BuildingFloors.add_corridor_art`), its seeded dressing and
# horror (`CorridorDecals.add_to` — blood, handprints, claw gouges, the dead on the floor), the apartment doors with their number plates, the wall
# sconces (`FloorLighting` — some steady, some flickering, some BLINKING, some dead, real PointLight2Ds) and the standard dead (the real sprite
# frames of `enemy_zombie_standard.tscn`, driven here by a tiny shamble state machine — no AI, no body, no groups, nothing that can touch the game).
# On top of that the hall adds what only a title needs: now and then a BLACKOUT (every lamp cuts out, stutters, comes back) and an odd distant moan.
# The CAMERA IS STILL (owner round 48h: "we don't need the scene to move… it looks juddery" — a slow pan at whole-pixel steps stutters): only the lamps,
# the dead and the fade move.
#
# It reads WorldState while it builds (the seeds + the run decide which dressing, which lamps are dead) so it swaps in its OWN fixed seed and run for
# that one synchronous stretch and puts the player's values back: the title looks the same every time the game opens, whatever state is loaded.

const BuildingFloors := preload("res://scripts/building_floors.gd")
const Decals := preload("res://scripts/corridor_decals.gd")
const Lighting := preload("res://scripts/floor_lighting.gd")
const Door := preload("res://scripts/door.gd")
const DoorPlate := preload("res://scripts/door_plate.gd")
const EnemyFeet := preload("res://scripts/enemy_feet.gd")
const ZOMBIE_SCENE := preload("res://scenes/enemy_zombie_standard.tscn")

const FLOOR := 22                       # the faded-hotel section (21-29): a red runner, damask, brass sconces — in the dark, with blood on it
const RUN := 3                          # the night: the most lamps dead, the most horror laid
const SEED := 11                      # the title's own building (a fixed seed → the same dressing and the same dead lamps every launch)
const HORROR_BOOST := 0.9               # extra horror on top of the night's own (corridor_decals: more blood, claw marks, scrawls on the walls in view)
const AMBIENT := Color(0.10, 0.11, 0.19)   # the world's darkness; only lamps, glows and what they touch show
const BAND_H := 192.0                   # the corridor band the camera frames (docs/Y_PLANES.md)
const CAM_Y := 339.0                    # the band's centre (243 + 96)
const CAM_X := 566.0                    # where the camera stands, for good; the menu + logo cover the screen's left ~40 % (~140 world px), the dressing lives right of it
const DOOR_Y := 363.0                   # an apartment door's centre (321..405)
const DOOR_FRAME := Rect2(0, 0, 46, 84) # frame 0 of a door strip: closed
const FADE_IN := 1.8                    # seconds from black to the hall
const BLACKOUT_MIN := 9.0
const BLACKOUT_MAX := 21.0
const MOAN_MIN := 16.0
const MOAN_MAX := 34.0
const MOAN_DB := -19.0
const MOANS := ["res://assets/audio/zombie/moan_1.wav", "res://assets/audio/zombie/moan_2.wav", "res://assets/audio/zombie/moan_3.wav", "res://assets/audio/zombie/moan_4.wav"]
# [x to start, low end, high end of the stretch of corridor it keeps to] — three shamblers. The hall's bicycle stands in the lamp's pool at x 602..666 (the first thing the title shows —
# owner round 48h: it must read on its own), so no stretch crosses it: one dead keeps to the left of it, one to the right, one down by the menu (title_test checks the gap).
const DEAD := [[530.0, 470.0, 575.0], [780.0, 690.0, 880.0], [430.0, 380.0, 460.0]]
const BIKE_CLEAR := 24.0               # a dead's centre keeps at least this far (px) from the bicycle's rect: its sprite is ~30 px wide, so it never covers the bike

var build_ok: bool = false
var t: float = 0.0
var camera: Camera2D = null
var lights: Node = null                 # the FloorLighting node
var dead: Array = []                    # the _Dead shamblers
var grade: CanvasModulate = null
var fade: ColorRect = null              # a full-screen black that lifts in the first seconds (a CanvasLayer of its own, above the hall)
var blackouts: int = 0                  # how many have played (tests + the capture tool read it)
var _rng := RandomNumberGenerator.new()
var _blackout_in: float = 6.0
var _blackout_steps: Array = []         # [[seconds, power]] still to play
var _moan_in: float = 8.0
var _moan: AudioStreamPlayer = null


func _ready() -> void:
	_rng.seed = SEED
	var keep_seed: int = WorldState.master_seed
	var keep_run: int = WorldState.current_run
	WorldState.master_seed = SEED                  # the build reads these (variant, dressing, which lamps are dead) — put back right after
	WorldState.current_run = RUN
	build_ok = _build()
	WorldState.master_seed = keep_seed
	WorldState.current_run = keep_run
	if build_ok:
		_build_camera()
		_build_fade()
		_build_audio()


## The hall's own build. False if the corridor art is missing (the title then shows its plain dark fallback).
func _build() -> bool:
	var art_path: String = BuildingFloors.corridor_art_path(FLOOR, RUN)
	if not ResourceLoader.exists(art_path):
		return false
	BuildingFloors.add_corridor_art(self, art_path)
	_build_doors()
	# the floor's dressing + its horror (seeded by SEED / RUN above); the doors are already in so the door-face marks land over them
	Decals.add_to(self, FLOOR, RUN, BuildingFloors.corridor_base_name(FLOOR), BuildingFloors.CORRIDOR_ART_POS, [], HORROR_BOOST)
	_strip_interactions()
	lights = Lighting.new()
	lights.name = "FloorLighting"
	add_child(lights)
	lights.setup(FLOOR, [])                         # no stairwell windows: they are off to either end of the corridor
	for i in range(DEAD.size()):
		_add_dead(i)
	grade = CanvasModulate.new()
	grade.name = "WorldGrade"
	grade.color = AMBIENT
	add_child(grade)
	return true


func _build_doors() -> void:
	var section: String = BuildingFloors.corridor_section(FLOOR)
	var styles: Array = Door.DOOR_STYLES[section]
	for apt in [5, 4, 3, 2, 1]:
		var x: float = float(WorldState.APARTMENT_X[apt])
		var d := Node2D.new()
		d.name = "Door%d" % apt
		d.position = Vector2(x, DOOR_Y)
		var style: String = String(styles[(apt + FLOOR) % styles.size()])
		var path := "res://assets/doors/door_%s.png" % style
		if ResourceLoader.exists(path):
			var s := Sprite2D.new()
			s.texture = load(path)
			s.region_enabled = true
			s.region_rect = DOOR_FRAME
			s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			d.add_child(s)
		var plate = DoorPlate.new()
		d.add_child(plate)
		plate.setup("%d0%d" % [FLOOR, apt], section)
		add_child(d)


## The dressing plants a search zone over every body on the floor (corridor_body.gd) and may plant a story trigger; the title has no player to use them.
func _strip_interactions() -> void:
	var wall := get_node_or_null("CorridorDecals")
	if wall == null:
		return
	for n in wall.get_children():
		if String(n.name).begins_with("Body_") or String(n.name).begins_with("Story"):
			n.queue_free()


func _add_dead(i: int) -> void:
	var spec: Array = DEAD[i]
	var inst: Node = ZOMBIE_SCENE.instantiate()      # NOT added to the tree: its script never runs; we only borrow the sprite + the collision for the feet
	var spr := inst.get_node("AnimatedSprite2D") as AnimatedSprite2D
	if spr == null:
		inst.free()
		return
	EnemyFeet.lift_sprite(inst, spr)                 # drawn feet on the player's row, as in the corridor
	inst.remove_child(spr)
	inst.free()
	var z := _Dead.new()
	z.name = "Dead%d" % i
	z.setup(spr, float(spec[0]), float(spec[1]), float(spec[2]), SEED + 31 * (i + 1))
	z.position = Vector2(float(spec[0]), BuildingFloors.ZOMBIE_SETTLED_Y)
	z.z_index = 1                                    # actors sit on z 1, over the corridor backdrop (CLAUDE.md "Render layers")
	add_child(z)
	dead.append(z)


func _build_camera() -> void:
	camera = Camera2D.new()
	camera.name = "Camera"
	camera.zoom = Vector2.ONE * (648.0 / BAND_H)     # the band fills the screen's height, exactly as a corridor does in play
	camera.position_smoothing_enabled = false
	camera.position = Vector2(CAM_X, CAM_Y)          # fixed: nothing ever moves it (a whole-pixel drift judders)
	add_child(camera)
	camera.make_current()


func _build_fade() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Fade"
	layer.layer = 1                                   # over the hall (the default canvas is 0); the title UI is a later layer-1 sibling, so it draws OVER this and stays visible
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 1)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fade)
	add_child(layer)


func _build_audio() -> void:
	_moan = AudioStreamPlayer.new()
	_moan.volume_db = MOAN_DB
	_moan.bus = "Enemies" if AudioServer.get_bus_index("Enemies") != -1 else "Master"
	add_child(_moan)


static func fade_alpha(tt: float) -> float:
	return 1.0 - clampf(tt / FADE_IN, 0.0, 1.0)


func _process(delta: float) -> void:
	if not build_ok:
		return
	delta = minf(delta, 0.1)
	t += delta
	if fade != null:
		fade.color.a = fade_alpha(t)
	for z in dead:
		z.tick(delta)
	_blackout_tick(delta)
	_moan_tick(delta)


## Every so often every lamp cuts out, stutters and comes back (a failing supply, or something in the walls): off, a flash of light, off longer, on.
func _blackout_tick(delta: float) -> void:
	if not _blackout_steps.is_empty():
		_blackout_steps[0][0] = float(_blackout_steps[0][0]) - delta
		if float(_blackout_steps[0][0]) <= 0.0:
			var step: Array = _blackout_steps.pop_front()
			if lights != null:
				lights.set_power(bool(step[1]))
		return
	_blackout_in -= delta
	if _blackout_in > 0.0:
		return
	_blackout_in = _rng.randf_range(BLACKOUT_MIN, BLACKOUT_MAX)
	blackouts += 1
	# the first step cuts the power now; each following [wait, power] flips it again after its wait
	if lights != null:
		lights.set_power(false)
	_blackout_steps = [[_rng.randf_range(0.10, 0.22), true], [_rng.randf_range(0.05, 0.12), false], [_rng.randf_range(0.30, 0.85), true]]


func _moan_tick(delta: float) -> void:
	_moan_in -= delta
	if _moan_in > 0.0 or _moan == null:
		return
	_moan_in = _rng.randf_range(MOAN_MIN, MOAN_MAX)
	var path: String = String(MOANS[_rng.randi() % MOANS.size()])
	if ResourceLoader.exists(path) and not _moan.playing:
		var s = load(path)
		if s is AudioStream:
			_moan.stream = s
			_moan.pitch_scale = _rng.randf_range(0.80, 0.96)       # low and far
			_moan.play()


# ---- the dead --------------------------------------------------------------------------------------------------------------------
# One shambler: stands, sways, sets off for somewhere along its stretch of corridor at a lurching pace, stands again, now and then lunges at nothing.
# Pure view + a timer — it has no body, no groups and no idea the player exists.
class _Dead:
	extends Node2D

	const WALK_SPEED := 12.0             # world px / s (the game's standard zombie walks faster; this is the dragging half of its gait)
	const LUNGE_CHANCE := 0.22
	const MOVE_CHANCE := 0.70

	var sprite: AnimatedSprite2D = null
	var lo: float = 0.0
	var hi: float = 0.0
	var state: String = "idle"
	var timer: float = 1.0
	var dir: float = 1.0
	var goal: float = 0.0
	var phase: float = 0.0
	var rng := RandomNumberGenerator.new()

	func setup(spr: AnimatedSprite2D, x0: float, lo_x: float, hi_x: float, seed_value: int) -> void:
		sprite = spr
		add_child(sprite)
		lo = lo_x
		hi = hi_x
		rng.seed = seed_value
		phase = rng.randf() * TAU
		dir = 1.0 if rng.randf() < 0.5 else -1.0
		timer = rng.randf_range(0.4, 3.0)
		_play("Idle", 0.7)

	func _play(anim: String, speed: float) -> void:
		if sprite == null or sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(anim):
			return
		sprite.speed_scale = speed
		if sprite.animation != StringName(anim) or not sprite.is_playing():
			sprite.play(anim)

	func tick(delta: float) -> void:
		if sprite == null:
			return
		timer -= delta
		phase += delta
		match state:
			"idle":
				_play("Idle", 0.7)
				if timer <= 0.0:
					_choose()
			"walk":
				# a lurching pace: it surges and nearly stops, never steady
				var surge: float = 0.35 + 0.65 * (0.5 + 0.5 * sin(phase * 2.3))
				position.x += dir * WALK_SPEED * surge * delta
				sprite.flip_h = dir < 0.0
				_play("Walk", 0.55 + 0.35 * surge)
				var arrived: bool = (dir > 0.0 and position.x >= goal) or (dir < 0.0 and position.x <= goal)
				if arrived or timer <= 0.0:
					position.x = clampf(position.x, lo, hi)
					state = "idle"
					timer = rng.randf_range(2.0, 6.5)
			"lunge":
				_play("Attack", 0.45)
				if timer <= 0.0:
					state = "idle"
					timer = rng.randf_range(2.5, 6.0)

	func _choose() -> void:
		var roll: float = rng.randf()
		if roll < MOVE_CHANCE:
			var to: float = rng.randf_range(lo, hi)
			if absf(to - position.x) < 24.0:
				to = clampf(position.x + dir * 60.0, lo, hi)
			dir = 1.0 if to >= position.x else -1.0
			goal = to
			state = "walk"
			timer = absf(to - position.x) / (WALK_SPEED * 0.5) + 2.0     # generous: the surge slows it, so a time-out must not cut a walk short
		elif roll < MOVE_CHANCE + LUNGE_CHANCE:
			state = "lunge"
			sprite.flip_h = dir < 0.0
			timer = rng.randf_range(1.0, 1.8)
		else:
			state = "idle"
			timer = rng.randf_range(2.0, 5.0)
