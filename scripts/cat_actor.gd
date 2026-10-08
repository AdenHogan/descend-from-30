extends Node2D

# VIVIANNE'S CAT, in the world (owner round 37: "on the standard Y plane on some building_floor scenes to add a little more life… the cat
# never dies"). A small black cat on the corridor plane (feet on 419): it sits and flicks its tail, now and then meows (positional), wanders
# a little, bolts when the player gets close, and is otherwise left alone. It is an INVISIBLE-TO-EVERYTHING-ELSE actor — no collision body,
# not in `zombie` / `resident_target` / any group a weapon, fire, spit or noise reads — so it can't be hit, burned, shoved or block anyone,
# and it never dies. Its art (tools/art/cat.py) is a body strip + an UNSHADED eyes strip (two amber glints that stay lit in the dark).
# `CatActor.frames()` builds the SpriteFrames for both this and the HUD's foreground dash (fg_cat.gd).
#
# Seen once in a run by Vivianne it turns her quest over (CharacterStory.on_cat_seen). `bolt_to_x` makes a one-off cameo: the cat
# runs to that X when the player nears and VANISHES there (floor 30's stairwell) — the hook that sends her down.

const FRAME := Vector2i(28, 18)
const SCALE := 2.0
const ANIMS := {"walk": 4, "run": 4, "sit": 2, "meow": 2}
const FPS := {"walk": 8.0, "run": 14.0, "sit": 2.0, "meow": 5.0}
const MEOWS := ["res://assets/audio/cat/meow_1.wav", "res://assets/audio/cat/meow_2.wav", "res://assets/audio/cat/meow_3.wav"]
const WALK_SPEED := 34.0
const RUN_SPEED := 175.0
const FLEE_RANGE := 100.0
const SEEN_RANGE := 190.0                # half the view's width: it counts as seen once it's on screen

static var _body_frames: SpriteFrames = null
static var _eye_frames: SpriteFrames = null

var feet_y: float = 419.0
var bounds: Vector2 = Vector2(150.0, 1190.0)
var bolt_to_x: float = -1.0              # >= 0: the cameo — run here when the player nears, then vanish
var bolted: bool = false
var state: String = "sit"
var state_time: float = 0.0
var state_len: float = 3.0
var target_x: float = 0.0
var dir: float = 1.0
var _meow_in: float = 6.0
var _flee_cool: float = 0.0
var _seen: bool = false
var body: AnimatedSprite2D = null
var eyes: AnimatedSprite2D = null
var voice: AudioStreamPlayer2D = null
var _rng := RandomNumberGenerator.new()


## The shared SpriteFrames (every anim of the body strip, or of the eyes-only strip), built once from assets/cat/.
static func frames(eyes_only: bool = false) -> SpriteFrames:
	if _body_frames == null:
		_body_frames = _build("cat_%s.png")
		_eye_frames = _build("cat_eyes_%s.png")
	return _eye_frames if eyes_only else _body_frames


static func _build(pattern: String) -> SpriteFrames:
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	for anim in ANIMS:
		sf.add_animation(anim)
		sf.set_animation_speed(anim, float(FPS[anim]))
		sf.set_animation_loop(anim, true)
		var tex = load("res://assets/cat/" + pattern % anim)
		if tex == null:
			continue
		for k in int(ANIMS[anim]):
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(k * FRAME.x, 0, FRAME.x, FRAME.y)
			sf.add_frame(anim, at)
	return sf


static func art_present() -> bool:
	return ResourceLoader.exists("res://assets/cat/cat_walk.png") and ResourceLoader.exists("res://assets/cat/cat_eyes_walk.png")


func _ready() -> void:
	add_to_group("cat")                  # the ONLY group — never `zombie` / `resident_target`: nothing can hurt it
	z_index = 1
	_rng.randomize()
	position.y = feet_y                  # (parent-relative: the floor it stands on may not be at the origin)
	body = _sprite(false)
	eyes = _sprite(true)
	voice = AudioStreamPlayer2D.new()
	voice.max_distance = 560.0
	voice.volume_db = -5.0
	add_child(voice)
	target_x = global_position.x
	_set_state("sit", _rng.randf_range(2.0, 6.0))
	_meow_in = _rng.randf_range(4.0, 12.0)


func _sprite(unshaded: bool) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = frames(unshaded)
	s.centered = false
	s.offset = Vector2(-FRAME.x * 0.5, -FRAME.y)       # origin = the cat's feet, mid-body
	s.scale = Vector2(SCALE, SCALE)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if unshaded:
		var m := CanvasItemMaterial.new()
		m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		s.material = m                                 # the eyes keep their glint in the dark
	add_child(s)
	return s


func _set_state(s: String, length: float) -> void:
	state = s
	state_time = 0.0
	state_len = length
	var anim: String = s
	body.play(anim)
	eyes.play(anim)


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


func _process(delta: float) -> void:
	if bolted:
		return
	state_time += delta
	_flee_cool = maxf(0.0, _flee_cool - delta)
	eyes.frame = body.frame
	var pl := _player()
	var pdx: float = 9999.0
	if pl != null:
		pdx = pl.global_position.x - global_position.x
	if not _seen and absf(pdx) < SEEN_RANGE and WorldState.run_story_stage >= 0:     # (not while the opening is still playing)
		_seen = true
		CharacterStory.on_cat_seen()                  # Vivianne sees her cat (once a run)
	# the cameo: when the player comes near, bolt for the stairs and be gone
	if bolt_to_x >= 0.0 and state != "run" and absf(pdx) < SEEN_RANGE and WorldState.run_story_stage >= 0:
		_run_to(bolt_to_x)
	# skittish: someone close and it isn't already running
	if bolt_to_x < 0.0 and state != "run" and _flee_cool <= 0.0 and absf(pdx) < FLEE_RANGE and pl != null and absf(pl.global_position.y - global_position.y) < 120.0:
		_flee_from(pdx)
	match state:
		"sit":
			if state_time >= state_len:
				_pick_next()
		"meow":
			if state_time >= state_len:
				_set_state("sit", _rng.randf_range(2.0, 6.0))
		"walk":
			_step(WALK_SPEED, delta)
		"run":
			_step(RUN_SPEED, delta)
	if state == "sit":
		_meow_in -= delta
		if _meow_in <= 0.0:
			_meow_in = _rng.randf_range(8.0, 22.0)
			_meow()


func _step(speed: float, delta: float) -> void:
	var d: float = target_x - global_position.x
	if absf(d) <= speed * delta:
		global_position.x = target_x
		if bolt_to_x >= 0.0 and is_equal_approx(target_x, bolt_to_x):
			_vanish()
			return
		_set_state("sit", _rng.randf_range(3.0, 8.0))
		return
	dir = signf(d)
	body.flip_h = dir < 0.0
	eyes.flip_h = body.flip_h
	global_position.x += dir * speed * delta


func _pick_next() -> void:
	var r: float = _rng.randf()
	if r < 0.55:
		_walk_to(clampf(global_position.x + _rng.randf_range(-260.0, 260.0), bounds.x, bounds.y))
	elif r < 0.7:
		_run_to(clampf(global_position.x + _rng.randf_range(-420.0, 420.0), bounds.x, bounds.y))     # zoomies
	else:
		_set_state("sit", _rng.randf_range(3.0, 7.0))


func _walk_to(x: float) -> void:
	target_x = x
	_set_state("walk", 99.0)


func _run_to(x: float) -> void:
	target_x = x
	_set_state("run", 99.0)


func _flee_from(pdx: float) -> void:
	_flee_cool = 1.4
	var away: float = -1.0 if pdx > 0.0 else 1.0       # pdx > 0: the player is to the right
	var x: float = global_position.x + away * _rng.randf_range(230.0, 380.0)
	if x < bounds.x or x > bounds.y:                   # cornered against an end: dart past instead
		x = global_position.x - away * _rng.randf_range(230.0, 380.0)
	_run_to(clampf(x, bounds.x, bounds.y))
	if _rng.randf() < 0.35:
		_meow()


func _meow() -> void:
	if state == "run":
		return
	_set_state("meow", 0.7)
	var pl := _player()
	if pl != null and absf(pl.global_position.x - global_position.x) > 640.0:
		return                                         # far off: the animation, no sound
	var s = load(MEOWS[_rng.randi() % MEOWS.size()])
	if s is AudioStream:
		voice.stream = s
		voice.pitch_scale = _rng.randf_range(0.92, 1.1)
		voice.play()


func _vanish() -> void:
	bolted = true
	visible = false
	var s = load(MEOWS[0])                              # one last meow from the stairwell, then gone
	if s is AudioStream:
		voice.stream = s
		voice.play()
	# the voice must outlive the sprite for a moment: free once the sound has played
	await get_tree().create_timer(1.2).timeout
	queue_free()
