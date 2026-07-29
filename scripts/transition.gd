extends CanvasLayer

# Autoload. A reasonably-timed fade-to-black between gameplay scenes so
# entering/leaving apartments and taking stairs isn't a hard cut. Lives on its
# own high CanvasLayer above everything (HUD, listen overlay, intro overlay),
# persists across scene changes, and processes while paused. Call
# Transition.to_scene(path) instead of get_tree().change_scene_to_file(path).

const FADE_OUT := 0.2
const FADE_IN := 0.24

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


const CROSS_FADE := 0.2


func cross_fade_scene(path: String, dur: float = CROSS_FADE) -> void:
	# Swap scenes UNDERNEATH a still frame of the one being left, then dissolve
	# that frame away. For the stair pan, whose whole conceit is that the backdrop
	# it panned to is identical to the floor about to be built for real: any
	# residual difference — a stair arrow re-triggering as the player spawns on
	# it, a corpse seeded a pixel out, the load hitch itself — was a visible flash
	# at the instant of the swap. Under a dissolve, a difference fades in instead
	# of popping. Unlike to_scene() the screen never goes black, so it stays a
	# continuous move between floors rather than a cut.
	if busy:
		return
	busy = true
	var snap := await _snapshot()
	get_tree().change_scene_to_file(path)
	if snap == null:
		busy = false
		return
	# Let the new scene's _ready place the player and frame the camera before any
	# of it is uncovered.
	await get_tree().process_frame
	await get_tree().process_frame
	var tw := create_tween()
	tw.tween_property(snap, "modulate:a", 0.0, dur)
	await tw.finished
	snap.queue_free()
	busy = false


func _snapshot() -> TextureRect:
	# Headless has no framebuffer to read, and nothing to look at either.
	if DisplayServer.get_name() == "headless":
		return null
	await RenderingServer.frame_post_draw
	var vp := get_viewport()
	if vp == null or vp.get_texture() == null:
		return null
	var img := vp.get_texture().get_image()
	if img == null or img.is_empty():
		return null
	var tr := TextureRect.new()
	tr.texture = ImageTexture.create_from_image(img)
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE   # never eat clicks
	add_child(tr)
	return tr


func _fade(target_alpha: float, dur: float) -> void:
	var tw = create_tween()
	tw.tween_property(rect, "color:a", target_alpha, dur)
	await tw.finished
