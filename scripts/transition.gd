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
