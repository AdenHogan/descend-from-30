extends Control

# VIVIANNE'S CAT IN THE FOREGROUND (owner round 37: "occasionally running in the foreground and meow"). In her run, every minute or
# so, a big black cat streaks across the bottom of the screen — nearer the camera than anything in the world — with a meow halfway,
# and is gone. A HUD-layer child: screen space (not lit, not darkened by the night), mouse-transparent, it only ticks while the game
# runs (pausing freezes it) and only when nothing else has the screen (no dialogue, no cutscene, no transition). The first dash of
# a run turns her quest over (CharacterStory.on_cat_seen). `trigger()` forces one (tests / dev).

const CatActor := preload("res://scripts/cat_actor.gd")
const SCALE := 9.0                       # art px -> screen px (the world cat is 2 x the camera zoom, ~7)
const SPEED := 760.0
const FIRST_IN := Vector2(16.0, 32.0)    # seconds after the quest begins to the first dash
const EVERY := Vector2(55.0, 110.0)

var body: AnimatedSprite2D = null
var eyes: AnimatedSprite2D = null
var voice: AudioStreamPlayer = null
var running: bool = false
var x: float = 0.0
var dir: float = 1.0
var feet: float = 620.0
var meowed: bool = false
var next_in: float = -1.0
var dashes: int = 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	name = "FgCat"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rng.randomize()
	if not CatActor.art_present():
		set_process(false)
		return
	body = _sprite(false)
	eyes = _sprite(true)
	voice = AudioStreamPlayer.new()
	voice.volume_db = -3.0
	add_child(voice)
	body.visible = false
	eyes.visible = false


func _sprite(unshaded: bool) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = CatActor.frames(unshaded)
	s.centered = false
	s.offset = Vector2(-CatActor.FRAME.x * 0.5, -CatActor.FRAME.y)
	s.scale = Vector2(SCALE, SCALE)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(s)
	return s


## Is the screen free for a cat? (Vivianne's run, the quest begun, the world running, nothing talking.)
func eligible() -> bool:
	if not WorldState.story_rule or WorldState.current_character() != CharacterStory.VIVIANNE:
		return false
	if WorldState.run_story_stage < 0 or get_tree().paused or Transition.busy:
		return false
	if HUD.dialogue_panel != null and HUD.dialogue_panel.visible:
		return false
	var pl = get_tree().get_first_node_in_group("player")
	if pl == null or bool(pl.get("is_cutscene")) or WorldState.is_dying:
		return false
	return true


func _screen() -> Vector2:
	return size if size.x > 10.0 and size.y > 10.0 else Vector2(1152.0, 648.0)


func trigger() -> void:
	if running or body == null:
		return
	running = true
	meowed = false
	dashes += 1
	dir = 1.0 if _rng.randf() < 0.5 else -1.0
	var sz: Vector2 = _screen()
	feet = sz.y - _rng.randf_range(14.0, 60.0)
	var w: float = CatActor.FRAME.x * SCALE
	x = -w if dir > 0.0 else sz.x + w
	body.flip_h = dir < 0.0
	eyes.flip_h = body.flip_h
	body.play("run")
	eyes.play("run")
	body.visible = true
	eyes.visible = true
	CharacterStory.on_cat_seen()


func _process(delta: float) -> void:
	if running:
		x += dir * SPEED * delta
		body.position = Vector2(x, feet)
		eyes.position = body.position
		eyes.frame = body.frame
		var sz: Vector2 = _screen()
		if not meowed and absf(x - sz.x * 0.5) < 160.0:
			meowed = true
			var s = load(CatActor.MEOWS[_rng.randi() % CatActor.MEOWS.size()])
			if s is AudioStream:
				voice.stream = s
				voice.pitch_scale = _rng.randf_range(0.95, 1.12)
				voice.play()
		var w: float = CatActor.FRAME.x * SCALE
		if (dir > 0.0 and x > sz.x + w) or (dir < 0.0 and x < -w):
			running = false
			body.visible = false
			eyes.visible = false
			next_in = _rng.randf_range(EVERY.x, EVERY.y)
		return
	if not eligible():
		if WorldState.run_story_stage < 0:
			next_in = -1.0                   # a new run's quest hasn't begun: the first dash is re-rolled when it does
		return
	if next_in < 0.0:
		next_in = _rng.randf_range(FIRST_IN.x, FIRST_IN.y)
	next_in -= delta
	if next_in <= 0.0:
		trigger()
