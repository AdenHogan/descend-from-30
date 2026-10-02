extends Node2D

# THE CITY, CLIPPED AND PANNING (owner round 33 — "walking past the window, the image in the background is static. I think there
# should be a bit of movement back there, as if the scene of the city remains in place, but because you're passing by the window
# it looks like it is moving in the distance as you walk by. You could extend the city image a little and then allow for the view
# to pan slightly as you go left to right and back. This should be implemented for balcony openings too.")
#
# A clip parent: it draws its MASK (the glass rectangle, or a mask texture — the balcony's bare-view pixels) and clips its
# children to it. FAR holds the skyline sprite and everything standing on it (fires, smoke, blasts, an aircraft light —
# scripts/city_fx.gd puts them there); the rain is NOT in FAR — it's weather on the near side of the glass, it stays put.
# Every view is drawn `pan` px wider than its opening on each side (tools/art/cityscape.py PAN), and FAR slides with the
# viewer: offset = (viewer x - the opening's x) x PARALLAX, in whole pixels (pixel art stays crisp), clamped to ±pan — a far
# scene seen through a hole drifts as your view of it changes. The viewer is the CAMERA, not the player (owner round 34 — "the
# city moves when the player moves, not when the camera moves. It's jarring when entering an apartment where the camera is
# still fixed to the left"): parallax is what the eye sees, so with the camera pinned at an end wall and the player walking, the
# city stays put; it only drifts when the picture itself scrolls. Pure visuals.

const PARALLAX := 0.06

var far: Node2D = null
var pan: float = 0.0                   # max slide each way, px
var centre_local := Vector2.ZERO       # the opening's centre in this node's space (the window's glass / the balcony doorway)
var mask_rect := Rect2()               # a rectangular mask (a window's glass) …
var mask_tex: Texture2D = null         # … or a texture's opaque pixels (the balcony's bare view)
var mask_at := Vector2.ZERO            # where the mask texture's top-left sits


func setup_view(pan_px: float, centre: Vector2 = Vector2.ZERO) -> void:
	pan = maxf(0.0, pan_px)
	centre_local = centre
	clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	if far == null:
		far = Node2D.new()
		far.name = "Far"
		add_child(far)
	queue_redraw()


func set_mask_rect(r: Rect2) -> void:
	mask_rect = r
	mask_tex = null
	queue_redraw()


func set_mask_texture(t: Texture2D, at: Vector2) -> void:
	mask_tex = t
	mask_at = at
	queue_redraw()


## The slide for a viewer at world x, for an opening at world x: whole pixels, never past ±pan.
static func offset_for(viewer_x: float, opening_x: float, pan_px: float) -> float:
	if pan_px <= 0.0:
		return 0.0
	return clampf(roundf((viewer_x - opening_x) * PARALLAX), -pan_px, pan_px)


func _process(_delta: float) -> void:
	if far == null:
		return
	far.position.x = offset_now()


## The slide right now: the active camera's centre against this opening's (0 with no camera — a headless / mid-change moment).
func offset_now() -> float:
	var cam := get_viewport().get_camera_2d() if is_inside_tree() else null
	if cam == null:
		return 0.0
	return offset_for(cam.get_screen_center_position().x, to_global(centre_local).x, pan)


func _draw() -> void:
	# The clip mask (never shown itself — CLIP_CHILDREN_ONLY).
	if mask_tex != null:
		draw_texture(mask_tex, mask_at)
	elif mask_rect.size != Vector2.ZERO:
		draw_rect(mask_rect, Color.WHITE)
