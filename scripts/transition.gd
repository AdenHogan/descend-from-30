extends CanvasLayer

# Autoload. A reasonably-timed fade-to-black between gameplay scenes so
# entering/leaving apartments and taking stairs isn't a hard cut. Lives on its
# own high CanvasLayer above everything (HUD, listen overlay, intro overlay),
# persists across scene changes, and processes while paused. Call
# Transition.to_scene(path) instead of get_tree().change_scene_to_file(path).

const FADE_OUT := 0.2
const FADE_IN := 0.24

var rect: ColorRect = null
var label: Label = null
var busy: bool = false

# Time-skip title card (to_run_shift): a centred MORNING / AFTERNOON / NIGHT over a
# one-line subtitle, in the game's pixel font, tinted by time of day.
const TITLE_FONT := preload("res://assets/fonts/PixelOperator8-Bold.ttf")
const SUB_FONT := preload("res://assets/fonts/PixelOperator8.ttf")
# Warm gold morning → deep orange afternoon → cold blue night (the word's colour).
const TIME_WORD_COLORS := [
	Color(1.00, 0.86, 0.45),
	Color(1.00, 0.66, 0.30),
	Color(0.58, 0.72, 1.00),
]
var run_box: VBoxContainer = null
var run_title: Label = null
var run_sub: Label = null


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	rect = ColorRect.new()
	rect.color = Color(0, 0, 0, 0)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE  # never eat clicks
	rect.visible = false
	add_child(rect)
	# A centred caption shown only during a "time passes" hold (see to_scene_shift).
	label = Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9, 1.0))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.modulate.a = 0.0
	add_child(label)
	_build_run_card()


func _build_run_card() -> void:
	# The time-skip card: a big time-of-day word over a small subtitle, stacked and
	# centred, faded in as a group. Hidden until to_run_shift drives it.
	run_box = VBoxContainer.new()
	run_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	run_box.alignment = BoxContainer.ALIGNMENT_CENTER          # vertically centred
	run_box.add_theme_constant_override("separation", 18)
	run_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	run_box.modulate.a = 0.0
	run_box.visible = false
	add_child(run_box)

	run_title = Label.new()
	run_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	run_title.add_theme_font_override("font", TITLE_FONT)
	run_title.add_theme_font_size_override("font_size", 78)
	run_title.add_theme_constant_override("outline_size", 10)
	run_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	run_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	run_box.add_child(run_title)

	run_sub = Label.new()
	run_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	run_sub.add_theme_font_override("font", SUB_FONT)
	run_sub.add_theme_font_size_override("font_size", 20)
	run_sub.add_theme_color_override("font_color", Color(0.78, 0.80, 0.86, 1.0))
	run_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	run_box.add_child(run_sub)


# THE TIME SKIP between characters (docs/THREE_RUN_ARC.md). A slow fade to black,
# then the time-of-day card (MORNING / AFTERNOON / NIGHT) drifts up and holds so the
# passage of time is unmistakable, then the scene swaps and fades in on the new run.
# `run_index` is the run we're arriving INTO (2 or 3).
func cover(dur: float = 0.7) -> bool:
	# Fade the screen to FULL BLACK and hold it. Returns false if a transition is already
	# running. Used before a run-advance so that ALL run-3 world mutation / spawns happen
	# BEHIND black (the owner caught run-3 boxes popping in over the run-2 death scene when
	# advance_run() ran while the old floor was still visible). Pair with to_run_shift(...,
	# already_covered=true) to continue, or reveal() to fade back in on a fresh scene.
	if busy:
		return false
	busy = true
	rect.visible = true
	await _fade(1.0, dur)
	return true


func reveal(dur: float = 0.6) -> void:
	# Fade the black cover back out (after cover() + a scene swap). Clears busy.
	await _fade(0.0, dur)
	rect.visible = false
	busy = false


func to_run_shift(path: String, run_index: int, hold: float = 2.0, already_covered: bool = false) -> void:
	# already_covered = the caller already ran cover() (screen is black, busy is set) so the
	# run-advance happened out of sight; skip the initial fade and continue from black.
	if already_covered:
		if not busy:
			return
	else:
		if busy:
			return
		busy = true
		rect.visible = true
		await _fade(1.0, 0.7)                                  # slow — hours pass

	var i: int = clampi(run_index - 1, 0, WorldState.RUN_NAMES.size() - 1)
	run_title.text = WorldState.RUN_NAMES[i].to_upper()
	run_title.add_theme_color_override("font_color", TIME_WORD_COLORS[i])
	run_sub.text = WorldState.TIME_SUBTITLES[i]
	run_box.visible = true
	run_box.modulate.a = 0.0
	run_box.position.y = 24.0                                  # start low, drift up

	var t_in = create_tween().set_parallel(true)
	t_in.tween_property(run_box, "modulate:a", 1.0, 0.6)
	t_in.tween_property(run_box, "position:y", 0.0, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await t_in.finished
	await get_tree().create_timer(hold, true).timeout

	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame

	var t_out = create_tween().set_parallel(true)
	t_out.tween_property(run_box, "modulate:a", 0.0, 0.4)
	t_out.tween_property(run_box, "position:y", -20.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await t_out.finished
	run_box.visible = false
	await _fade(0.0, 0.6)
	rect.visible = false
	busy = false


# A heavier transition for a real TIME SKIP (the crowbar crossing): a longer fade
# to black, a held "time passes / the building shifts" caption, then the scene
# swap and fade-in — so the building shift reads as work done, not a hard cut.
func to_scene_shift(path: String, caption: String, hold: float = 1.6) -> void:
	if busy:
		return
	busy = true
	rect.visible = true
	await _fade(1.0, 0.6)                       # slower fade — it's a passage of time
	label.text = caption
	var t_in = create_tween()
	t_in.tween_property(label, "modulate:a", 1.0, 0.35)
	await t_in.finished
	await get_tree().create_timer(hold, true).timeout
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	var t_out = create_tween()
	t_out.tween_property(label, "modulate:a", 0.0, 0.3)
	await t_out.finished
	await _fade(0.0, 0.5)
	rect.visible = false
	busy = false


func to_scene(path: String) -> void:
	# Fade out → swap scene → fade in. Fire-and-forget; a second call while a
	# transition is running is ignored (prevents double-loads from stacked input).
	if busy:
		return
	busy = true
	rect.visible = true
	await _fade(1.0, FADE_OUT)
	get_tree().change_scene_to_file(path)
	# Let the new scene's _ready run (spawn player, HUD, etc.) before revealing.
	await get_tree().process_frame
	await get_tree().process_frame
	await _fade(0.0, FADE_IN)
	rect.visible = false
	busy = false


func _fade(target_alpha: float, dur: float) -> void:
	var tw = create_tween()
	tw.tween_property(rect, "color:a", target_alpha, dur)
	await tw.finished
