extends CanvasLayer

# Autoload. A reasonably-timed fade-to-black between gameplay scenes so
# entering/leaving apartments and taking stairs isn't a hard cut. Lives on its
# own high CanvasLayer above everything (HUD, listen overlay, intro overlay),
# persists across scene changes, and processes while paused. Call
# Transition.to_scene(path) instead of get_tree().change_scene_to_file(path).

const FADE_OUT := 0.28
const FADE_IN := 0.34

var rect: ColorRect = null
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
