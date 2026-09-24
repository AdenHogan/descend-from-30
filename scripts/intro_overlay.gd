extends CanvasLayer

# The cold open (docs/TUTORIAL.md). Two parts:
#  1) These black screens (below), ending on a door-slam and a fade to the hallway.
#  2) hallway.start_opener_lockout(): the player — visible, not black — steps up
#     and bangs on 3001, gets no answer, and remembers the 3003 spare key.
# Placeholder text is in TutorialManager.LINES; any key / click advances.
#
# EVERY RUN opens this way (owner: all three runs begin/end with the same shape), as separate
# screens on black, over one bloody handprint that stays put throughout:
#   1. TITLE      — "DESCEND FROM 30" on its own (run 1 only; empty title_text skips it).
#   2. TIME CARD  — the big time-of-day word in its own colour (MORNING / AFTERNOON / NIGHT, the
#                   Transition time-card look the owner preferred) + who this is + a subtitle.
#   3. THE LINE   — on CLEAN black (the handprint leaves with the time card): banging, then the character's line ("Who the hell is banging…") + [any key].
# Then the black lifts on the hallway and the visible lockout at 3001 plays. The hallway configures
# it before add_child() (hallway.opener_config). It waits while a Transition still covers the screen.
var title_text: String = "DESCEND FROM 30"
var time_word: String = "MORNING"
var time_color: Color = Color(1.00, 0.86, 0.45)
var name_text: String = ""
var sub_text: String = ""
var line_text: String = ""

const BANG_STREAMS = [
	preload("res://assets/audio/impacts/impactWood_heavy_000.ogg"),
	preload("res://assets/audio/impacts/impactWood_heavy_001.ogg"),
	preload("res://assets/audio/impacts/impactWood_heavy_002.ogg"),
]
const SLAM_STREAM = preload("res://assets/audio/doors/metalLatch.ogg")

const SCREEN_W = 1152.0
const SCREEN_H = 648.0
const CARD_TOP = SCREEN_H * 0.32  # the title and the time word share one line (the handprint's)
const TITLE_FADE = 1.0
const TITLE_HOLD = 1.8     # after fading in
const CARD_FADE = 0.6
const CARD_HOLD = 2.2
const OUT_FADE = 0.45      # a screen's words leaving, before the next screen
const BURST_BANGS = 5      # short, rapid
const BURST_GAP = 0.11     # quick
const LINE_DELAY = 0.75    # the banging lands, THEN the line reacts to it
const FADE_TIME = 0.5      # black → scene
const TEXT_FADE = 0.35     # a beat of clean black after the line, before the scene fades in

var black: ColorRect = null
var gore: Control = null
var title: Label = null
var card: Control = null         # the time card: word + name + subtitle
var word: Label = null
var who: Label = null
var sub: Label = null
var line: Label = null
var hint: Label = null
var sfx: AudioStreamPlayer = null

var stage := "title"             # title → card → line → (fading)
var t: float = 0.0               # time in the current stage
var burst_left: int = BURST_BANGS
var burst_timer: float = 0.0
var line_shown: bool = false
var fading: bool = false
var fade_t: float = 0.0


func _label(text: String, font: Font, size: int, col: Color, y: float, h: float) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(0, y)
	l.size = Vector2(SCREEN_W, h)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 6

	black = ColorRect.new()
	black.color = Color(0, 0, 0, 1)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)

	# Bloody handprint + drips — behind the title, and it STAYS behind the time card after.
	gore = preload("res://scripts/blood_handprint.gd").new()
	var ww: float = Transition.TITLE_FONT.get_string_size(time_word, HORIZONTAL_ALIGNMENT_LEFT, -1, 78).x
	gore.band_left = (SCREEN_W - ww) * 0.5 + 20.0            # drips hang under the time word
	gore.band_right = (SCREEN_W + ww) * 0.5 - 20.0
	gore.drip_baseline_y = CARD_TOP + 70.0
	gore.modulate = Color(1, 1, 1, 0)
	add_child(gore)

	# 1. The game's title — gory red, on its own.
	title = _label(title_text, Transition.TITLE_FONT, 62, Color(0.72, 0.05, 0.05), CARD_TOP, 90)
	title.add_theme_color_override("font_outline_color", Color(0.09, 0.0, 0.0))
	title.add_theme_constant_override("outline_size", 12)
	title.modulate = Color(1, 1, 1, 0)
	add_child(title)

	# 2. The time card — the same look as Transition's time-skip card (big word, its own colour).
	card = Control.new()
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.modulate = Color(1, 1, 1, 0)
	add_child(card)
	word = _label(time_word, Transition.TITLE_FONT, 78, time_color, CARD_TOP - 8, 100)
	word.add_theme_constant_override("outline_size", 10)
	word.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	card.add_child(word)
	who = _label(name_text, Transition.SUB_FONT, 24, Color(0.92, 0.90, 0.86), CARD_TOP + 120, 32)
	card.add_child(who)
	sub = _label(sub_text, Transition.SUB_FONT, 18, Color(0.78, 0.80, 0.86), CARD_TOP + 158, 28)
	card.add_child(sub)

	# 3. The line.
	line = _label("", Transition.SUB_FONT, 20, Color(0.92, 0.92, 0.95), SCREEN_H * 0.6, 90)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.position.x = SCREEN_W * 0.15
	line.size.x = SCREEN_W * 0.7
	line.visible = false
	add_child(line)
	hint = _label("[any key]", Transition.SUB_FONT, 14, Color(1.0, 0.9, 0.35), SCREEN_H * 0.6 + 92, 22)
	hint.position.x = SCREEN_W * 0.15
	hint.size.x = SCREEN_W * 0.7
	hint.visible = false
	add_child(hint)

	sfx = AudioStreamPlayer.new()
	add_child(sfx)

	stage = "title" if title_text != "" else "card"
	get_tree().paused = true


func _play(stream: AudioStream, vol: float) -> void:
	sfx.stream = stream
	sfx.volume_db = vol
	sfx.pitch_scale = randf_range(0.94, 1.06)
	sfx.play()


func _next_stage(to: String) -> void:
	stage = to
	t = 0.0


# Jump straight to the line screen (tests / a skip).
func skip_to_line() -> void:
	title.modulate.a = 0.0
	card.modulate.a = 0.0
	gore.modulate.a = 0.0
	burst_left = 0
	_next_stage("line")
	t = LINE_DELAY


func _process(delta: float) -> void:
	if fading:
		fade_t += delta
		# The black lifts on the hallway (the handprint already left with the time card).
		black.color.a = 1.0 - clampf((fade_t - TEXT_FADE) / FADE_TIME, 0.0, 1.0)
		if fade_t >= TEXT_FADE + FADE_TIME:
			get_tree().paused = false
			_hand_to_hallway()
			queue_free()
		return

	# Hold at the very start while a Transition (the death/escape end card's black) still covers.
	if Transition.busy:
		return
	t += delta
	match stage:
		"title":
			title.modulate.a = _in_hold_out(t, TITLE_FADE, TITLE_HOLD, OUT_FADE)
			gore.modulate.a = minf(t / TITLE_FADE, 1.0)            # stays up as the title leaves
			if t >= TITLE_FADE + TITLE_HOLD + OUT_FADE:
				_next_stage("card")
		"card":
			card.modulate.a = _in_hold_out(t, CARD_FADE, CARD_HOLD, OUT_FADE)
			# The handprint leaves WITH the time card (owner: the line screen is clean — no red).
			var g_in: float = 1.0 if title_text != "" else minf(t / CARD_FADE, 1.0)
			gore.modulate.a = minf(g_in, card.modulate.a) if t >= CARD_FADE + CARD_HOLD else g_in
			card.position.y = 24.0 * (1.0 - minf(t / (CARD_FADE * 1.5), 1.0))    # drifts up, like before
			if t >= CARD_FADE + CARD_HOLD + OUT_FADE:
				_next_stage("line")
		"line":
			# A short, loud burst of banging — then the character reacts to it.
			if burst_left > 0:
				burst_timer -= delta
				if burst_timer <= 0.0:
					burst_timer = BURST_GAP
					_play(BANG_STREAMS.pick_random(), 3.0)
					burst_left -= 1
			if t >= LINE_DELAY and not line_shown:
				line_shown = true
				line.text = line_text if line_text != "" else TutorialManager.LINES["opener_1"]
				line.visible = true
				hint.visible = true


static func _in_hold_out(tt: float, fade_in: float, hold: float, fade_out: float) -> float:
	if tt < fade_in:
		return tt / fade_in
	if tt < fade_in + hold:
		return 1.0
	return 1.0 - clampf((tt - fade_in - hold) / fade_out, 0.0, 1.0)


func _input(event: InputEvent) -> void:
	if fading:
		return
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) \
			or (event is InputEventMouseButton and event.pressed)
	if not pressed:
		return
	if not line_shown:
		# A key during the title / time card hurries it to its fade-out (never skips a screen
		# outright — each still reads).
		if stage == "title" and t < TITLE_FADE + TITLE_HOLD:
			t = TITLE_FADE + TITLE_HOLD
		elif stage == "card" and t < CARD_FADE + CARD_HOLD:
			t = CARD_FADE + CARD_HOLD
		get_viewport().set_input_as_handled()
		return
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
