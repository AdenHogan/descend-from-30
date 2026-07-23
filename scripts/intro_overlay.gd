extends CanvasLayer

# First-run opener (docs/TUTORIAL.md). Two parts:
#  1) This black-screen title card: "DESCEND FROM 30" fades in gory red over a
#     SHORT, LOUD burst of banging (a neighbour hammering then bolting), one
#     player line, a door-slam, then it fades to the hallway.
#  2) hallway.start_opener_lockout(): the player — visible, not black — steps up
#     and bangs on 3001, gets no answer, and remembers the 3003 spare key.
# Placeholder text is in TutorialManager.LINES["opener_*"]; any key / click
# advances.

const BANG_STREAMS = [
	preload("res://assets/audio/impacts/impactWood_heavy_000.ogg"),
	preload("res://assets/audio/impacts/impactWood_heavy_001.ogg"),
	preload("res://assets/audio/impacts/impactWood_heavy_002.ogg"),
]
const SLAM_STREAM = preload("res://assets/audio/doors/metalLatch.ogg")

const SCREEN_W = 1152.0
const SCREEN_H = 648.0
const TITLE_FADE = 1.0
const BURST_BANGS = 5      # short, rapid
const BURST_GAP = 0.11     # quick
const FADE_TIME = 0.5      # shorter than before

var black: ColorRect = null
var title: Label = null
var line: Label = null
var hint: Label = null
var sfx: AudioStreamPlayer = null

var t: float = 0.0
var burst_left: int = BURST_BANGS
var burst_timer: float = 0.35
var line_shown: bool = false
var fading: bool = false
var fade_t: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 6

	black = ColorRect.new()
	black.color = Color(0, 0, 0, 1)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)

	title = Label.new()
	title.text = "DESCEND FROM 30"
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(0.62, 0.03, 0.03))   # gory red
	title.add_theme_color_override("font_outline_color", Color(0.15, 0.0, 0.0))
	title.add_theme_constant_override("outline_size", 8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, SCREEN_H * 0.32)
	title.size = Vector2(SCREEN_W, 90)
	title.modulate = Color(1, 1, 1, 0)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)

	line = Label.new()
	line.add_theme_font_size_override("font_size", 22)
	line.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95))
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.position = Vector2(SCREEN_W * 0.15, SCREEN_H * 0.6)
	line.size = Vector2(SCREEN_W * 0.7, 90)
	line.visible = false
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(line)

	hint = Label.new()
	hint.text = "[any key]"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(1.0, 0.9, 0.35))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(SCREEN_W * 0.15, SCREEN_H * 0.6 + 92)
	hint.size = Vector2(SCREEN_W * 0.7, 22)
	hint.visible = false
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)

	sfx = AudioStreamPlayer.new()
	add_child(sfx)

	get_tree().paused = true


func _play(stream: AudioStream, vol: float) -> void:
	sfx.stream = stream
	sfx.volume_db = vol
	sfx.pitch_scale = randf_range(0.94, 1.06)
	sfx.play()


func _process(delta: float) -> void:
	if fading:
		fade_t += delta
		var a = 1.0 - clampf(fade_t / FADE_TIME, 0.0, 1.0)
		black.color.a = a
		title.modulate.a = a
		if fade_t >= FADE_TIME:
			get_tree().paused = false
			_hand_to_hallway()
			queue_free()
		return

	t += delta
	title.modulate.a = minf(t / TITLE_FADE, 1.0)

	# Short loud banging burst up front, then silence (banged and ran).
	if burst_left > 0:
		burst_timer -= delta
		if burst_timer <= 0.0:
			burst_timer = BURST_GAP
			_play(BANG_STREAMS.pick_random(), 3.0)  # louder
			burst_left -= 1

	if t >= TITLE_FADE and not line_shown:
		line_shown = true
		line.text = TutorialManager.LINES["opener_1"]
		line.visible = true
		hint.visible = true


func _input(event: InputEvent) -> void:
	if fading or not line_shown:
		return
	if (event is InputEventKey and event.pressed and not event.echo) \
			or (event is InputEventMouseButton and event.pressed):
		TutorialManager.guard_interact()
		get_viewport().set_input_as_handled()
		_play(SLAM_STREAM, 2.0)  # door slams
		fading = true
		fade_t = 0.0
		line.visible = false
		hint.visible = false


func _hand_to_hallway() -> void:
	var scene = get_tree().current_scene
	if scene != null and scene.has_method("start_opener_lockout"):
		scene.start_opener_lockout()
