extends CanvasLayer

# First-run opener (docs/TUTORIAL.md item: the cold open). A black screen with
# rapid banging, then the player realises they're locked out and remembers the
# 3003 spare key — before control hands to the hallway. Self-contained: pauses
# the tree, drives a sequence of E-advanced lines over black, plays SFX on
# beats, then fades to gameplay. Placeholder text lives in
# TutorialManager.LINES["opener_*"]; rewrite there.

const BANG_STREAMS = [
	preload("res://assets/audio/impacts/impactWood_heavy_000.ogg"),
	preload("res://assets/audio/impacts/impactWood_heavy_001.ogg"),
	preload("res://assets/audio/impacts/impactWood_heavy_002.ogg"),
]
const SLAM_STREAM = preload("res://assets/audio/doors/metalLatch.ogg")

const SCREEN_W = 1152.0
const SCREEN_H = 648.0
const FADE_TIME = 0.8
const KNOCK_INTERVAL = 0.42

var beats: Array = []
var idx: int = 0
var black: ColorRect = null
var label: Label = null
var hint: Label = null
var sfx: AudioStreamPlayer = null
var knocking: bool = false
var knock_timer: float = 0.0
var fading: bool = false
var fade_t: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 5  # above HUD (1) and the listen overlay (2)

	black = ColorRect.new()
	black.color = Color(0, 0, 0, 1)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)

	label = Label.new()
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.position = Vector2(SCREEN_W * 0.15, SCREEN_H * 0.4)
	label.size = Vector2(SCREEN_W * 0.7, 120)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

	hint = Label.new()
	hint.text = "[E]"
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(1.0, 0.9, 0.35))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(SCREEN_W * 0.15, SCREEN_H * 0.4 + 130)
	hint.size = Vector2(SCREEN_W * 0.7, 24)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)

	sfx = AudioStreamPlayer.new()
	add_child(sfx)

	# Each beat: the line key + optional SFX cue. "knock" loops banging under
	# the line; "slam" fires once.
	beats = [
		{"key": "opener_1", "knock": true},
		{"key": "opener_2", "slam": true},
		{"key": "opener_3"},
		{"key": "opener_4", "knock": true},
		{"key": "opener_5"},
	]
	get_tree().paused = true
	_show(0)


func _show(i: int) -> void:
	var beat = beats[i]
	label.text = TutorialManager.LINES.get(beat["key"], "...")
	knocking = beat.get("knock", false)
	knock_timer = 0.0
	if beat.get("slam", false):
		_play(SLAM_STREAM, 0.0)


func _play(stream: AudioStream, vol: float) -> void:
	sfx.stream = stream
	sfx.volume_db = vol
	sfx.pitch_scale = randf_range(0.92, 1.08)
	sfx.play()


func _process(delta: float) -> void:
	if fading:
		fade_t += delta
		var a = 1.0 - clampf(fade_t / FADE_TIME, 0.0, 1.0)
		black.color.a = a
		if fade_t >= FADE_TIME:
			get_tree().paused = false
			queue_free()
		return

	if knocking:
		knock_timer -= delta
		if knock_timer <= 0.0:
			knock_timer = KNOCK_INTERVAL
			_play(BANG_STREAMS.pick_random(), -3.0)

	if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("jump"):
		# Guard the interact so this same press can't drive a door/stair the
		# instant control returns.
		TutorialManager.guard_interact()
		_advance()


func _advance() -> void:
	idx += 1
	if idx >= beats.size():
		_begin_fade()
	else:
		_show(idx)


func _begin_fade() -> void:
	fading = true
	fade_t = 0.0
	knocking = false
	label.visible = false
	hint.visible = false
