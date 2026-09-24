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
	_build_survive_card()


func _build_survive_card() -> void:
	survive_art = TextureRect.new()
	survive_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	survive_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	survive_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	survive_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST     # crisp pixel art at any scale
	survive_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	survive_art.visible = false
	add_child(survive_art)
	survive_box = VBoxContainer.new()
	survive_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	survive_box.alignment = BoxContainer.ALIGNMENT_CENTER
	survive_box.add_theme_constant_override("separation", 14)
	survive_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	survive_box.visible = false
	add_child(survive_box)
	survive_title = _card_label(TITLE_FONT, 64, SURVIVE_HEADING)
	survive_box.add_child(survive_title)
	survive_sub = _card_label(SUB_FONT, 22, SURVIVE_INK)
	survive_box.add_child(survive_sub)
	# The stats: a two-column table (labels right-aligned, values left) centred under the heading.
	var centre := CenterContainer.new()
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	survive_box.add_child(centre)
	survive_stats = GridContainer.new()
	survive_stats.columns = 2
	survive_stats.add_theme_constant_override("h_separation", 26)
	survive_stats.add_theme_constant_override("v_separation", 8)
	survive_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.add_child(survive_stats)
	survive_hint = _card_label(SUB_FONT, 14, SURVIVE_DIM)
	survive_hint.text = "[continue]"
	survive_box.add_child(survive_hint)


func _card_label(font: Font, size: int, col: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# The escape: fade to WHITE, show the heading + who + the run's stats, wait for a key (never
# forever — survive_max_wait), then crossfade WHITE → BLACK and leave the screen black + busy, so
# the caller advances the run out of sight and continues with to_run_start / reveal (like
# end_card). Returns false if a transition was already running.
func survived_card(heading: String, line: String, stats: Array, art: Texture2D = null) -> bool:
	# `stats` = [label, value] rows (WorldState.run_summary); `art` = the outside (optional).
	if busy:
		return false
	busy = true
	rect.color = Color(1, 1, 1, 0)
	rect.visible = true
	await _fade(1.0, 1.4)                                   # a slow bloom of daylight
	survive_title.text = heading
	survive_sub.text = line
	for c in survive_stats.get_children():
		survive_stats.remove_child(c)
		c.queue_free()
	for row in stats:
		var k := _card_label(SUB_FONT, 18, SURVIVE_DIM)
		k.text = String(row[0])
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		survive_stats.add_child(k)
		var v := _card_label(SUB_FONT, 18, SURVIVE_INK)
		v.text = String(row[1])
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		survive_stats.add_child(v)
	survive_hint.visible = false
	survive_box.modulate.a = 0.0
	survive_box.visible = true
	var t_in = create_tween()
	t_in.tween_property(survive_box, "modulate:a", 1.0, 0.8)
	await t_in.finished
	await get_tree().create_timer(survive_min_hold, true).timeout
	survive_hint.visible = true
	_continue_pressed = false
	_awaiting_continue = true
	var waited := 0.0
	while not _continue_pressed and waited < survive_max_wait:
		await get_tree().process_frame
		waited += get_process_delta_time()
	_awaiting_continue = false
	if art != null:
		# The stats leave; the white dissolves into the world outside; it lingers; then black.
		var t_fade = create_tween()
		t_fade.tween_property(survive_box, "modulate:a", 0.0, 0.6)
		await t_fade.finished
		survive_box.visible = false
		survive_art.texture = art
		survive_art.modulate.a = 0.0
		survive_art.visible = true
		var t_art = create_tween()
		t_art.tween_property(survive_art, "modulate:a", 1.0, 1.6)
		await t_art.finished
		_continue_pressed = false
		_awaiting_continue = true
		var held := 0.0
		while not _continue_pressed and held < survive_art_hold:
			await get_tree().process_frame
			held += get_process_delta_time()
		_awaiting_continue = false
		var t_black = create_tween().set_parallel(true)
		t_black.tween_property(survive_art, "modulate:a", 0.0, 1.4)
		t_black.tween_property(rect, "color", Color(0, 0, 0, 1), 1.4)
		await t_black.finished
		survive_art.visible = false
		survive_art.texture = null
		return true
	var t_out = create_tween().set_parallel(true)
	t_out.tween_property(survive_box, "modulate:a", 0.0, 0.6)
	t_out.tween_property(rect, "color", Color(0, 0, 0, 1), 1.1)   # white → black
	await t_out.finished
	survive_box.visible = false
	return true


func _input(event: InputEvent) -> void:
	if not _awaiting_continue:
		return
	if (event is InputEventKey and event.pressed and not event.echo) \
			or (event is InputEventMouseButton and event.pressed):
		_continue_pressed = true
		get_viewport().set_input_as_handled()


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


# THE END OF A CHARACTER'S STORY (death or escape) — the bookend to the cold open every run
# begins with. A slow fade to black, then a heading ("YOU DIED" / "YOU ESCAPED") over one line
# of where/how ("Mara Voss fell on Floor 17."), held, then cleared — the screen STAYS black and
# busy, so the caller advances the run out of sight and continues with to_run_shift(...,
# already_covered=true) or swaps to the game-over card + reveal(). Same labels as the
# time-of-day card, so the end of one run flows straight into the start of the next.
# THE ESCAPE CARD (owner): stepping out of the lobby fades to WHITE — "YOU SURVIVED", who, and the
# run's stats — then crossfades to black for the next run. Dark ink on white.
const SURVIVE_INK := Color(0.16, 0.13, 0.10)
const SURVIVE_DIM := Color(0.38, 0.34, 0.30)
const SURVIVE_HEADING := Color(0.62, 0.48, 0.12)
var survive_box: VBoxContainer = null
var survive_title: Label = null
var survive_sub: Label = null
var survive_stats: GridContainer = null
var survive_hint: Label = null
# THE OUTSIDE (owner: "post game art showing how the world is outside the building"): an optional
# full-screen painting that the white card dissolves into before black — the horror-movie ending
# where the survivor walks out and their fate stays uncertain. Only shown when art exists
# (WorldState.escape_art); without it the card goes straight to black, exactly as before.
var survive_art: TextureRect = null
var survive_art_hold := 3.5        # how long the outside lingers (a key moves on sooner)
var survive_min_hold := 2.2        # the stats always read for at least this long…
var survive_max_wait := 20.0       # …then a key continues; after this it continues by itself
var _continue_pressed := false
var _awaiting_continue := false

const END_DIED_COLOR := Color(0.78, 0.08, 0.06)


func end_card(heading: String, line: String, heading_color: Color, hold: float = 2.4) -> bool:
	if busy:
		return false
	busy = true
	rect.visible = true
	await _fade(1.0, 1.1)                                  # slower than a door fade — it's an ending
	run_title.text = heading
	run_title.add_theme_color_override("font_color", heading_color)
	run_sub.text = line
	run_box.visible = true
	run_box.modulate.a = 0.0
	run_box.position.y = 0.0
	var t_in = create_tween()
	t_in.tween_property(run_box, "modulate:a", 1.0, 0.7)
	await t_in.finished
	await get_tree().create_timer(hold, true).timeout
	var t_out = create_tween()
	t_out.tween_property(run_box, "modulate:a", 0.0, 0.5)
	await t_out.finished
	run_box.visible = false
	return true


func reveal(dur: float = 0.6) -> void:
	# Fade the black cover back out (after cover() + a scene swap). Clears busy.
	await _fade(0.0, dur)
	rect.visible = false
	busy = false


# The NEXT CHARACTER's start: from the black the end card left, swap to Floor 30 and lift the
# cover — onto the hallway's own black cold open (intro_overlay), which carries the time-of-day
# card now (with the handprint), so every run starts on the same screens.
func to_run_start(path: String) -> void:
	# Always load the next run — even if the cover somehow isn't up (returning early here would
	# strand the player on the death/escape screen with no way on).
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	if busy:
		await reveal(0.3)


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
