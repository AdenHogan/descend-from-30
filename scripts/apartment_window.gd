extends Node2D

# A NON-balcony apartment module's WALL WINDOW: natural light plus, at night, a small
# patch of rain seen "through" the glass. Placed by room._build_modules at a seeded
# LEFT or RIGHT wall position (WorldState.apartment_window_side) — the two slots are the
# hook a future module-art pass uses to vary which walls carry a window (one / both /
# none), so apartments never read samey.
#
# NO OVERLAP WITH SCAVENGE NODES (owner ask): the scavenge anchors sit at module-local
# y >= 76 (world >= ~300, furniture level); this window rides the anchor-free TOP wall
# band at world y ~252, so its light/rain/art never collide with a search anchor's glow.
#
# The light itself (bright cool day / warm afternoon / dim blue moonlight at night) comes
# from FloorLighting.make_window_light, the same source the stairwell + balcony windows
# use, so all glazing in the building reads consistently by time of day. On night runs the
# apartment_storm node brightens every window's light together for a lightning flash.

const FL = preload("res://scripts/floor_lighting.gd")
const APARTMENT_WINDOW_ENERGY_SCALE := 1.3   # a flat has no ceiling lamps — windows carry it

# Placeholder pane box (drawn until real module art frames the window). Half-extents.
const PANE_HALF_W := 22.0
const PANE_HALF_H := 26.0

var light: PointLight2D = null
var _night := false


func setup(pos: Vector2, live: bool) -> void:
	position = pos
	z_index = 0
	_night = WorldState.current_run == 3
	light = FL.make_window_light(Vector2.ZERO, APARTMENT_WINDOW_ENERGY_SCALE)
	# The storm driver finds every window this way to flash them as one lightning event.
	light.add_to_group("apt_window_light")
	# Remember the run's base energy so a flash can return to it exactly.
	light.set_meta("base_energy", light.energy)
	add_child(light)
	queue_redraw()   # draw the placeholder pane
	# Rain is OUTSIDE the glass — only on live night runs (no rain on a passive backdrop).
	if live and _night:
		_add_rain()


func _draw() -> void:
	# A simple placeholder window: a framed pane of "sky" you can see through, so the window
	# reads AS a window in-editor before real module art exists (the art pass replaces this).
	# Glass tint tracks the time of day so a night pane reads dark/moonlit, a day pane bright.
	var glass := Color(0.16, 0.20, 0.34, 0.75) if _night else Color(0.62, 0.78, 0.98, 0.65)
	var frame := Color(0.10, 0.10, 0.12, 0.95)
	var rect := Rect2(-PANE_HALF_W, -PANE_HALF_H, PANE_HALF_W * 2.0, PANE_HALF_H * 2.0)
	draw_rect(rect, glass, true)                       # glass
	draw_rect(rect, frame, false, 3.0)                 # outer frame
	draw_line(Vector2(0, -PANE_HALF_H), Vector2(0, PANE_HALF_H), frame, 2.0)   # mullion |
	draw_line(Vector2(-PANE_HALF_W, 0), Vector2(PANE_HALF_W, 0), frame, 2.0)   # mullion -


func _add_rain() -> void:
	# A small patch of falling streaks confined to the pane, drawn behind actors (z0) so it
	# reads as rain seen THROUGH the window, not rain in the room. Placeholder until window art.
	var rain := CPUParticles2D.new()
	rain.texture = _streak_texture()
	rain.z_index = 0
	rain.amount = 16
	rain.lifetime = 0.55
	rain.preprocess = 0.55                       # start mid-fall, no empty first beat
	rain.local_coords = false
	rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	rain.emission_rect_extents = Vector2(PANE_HALF_W - 2.0, 3.0)
	rain.position = Vector2(0, -PANE_HALF_H + 2.0)   # emit at the top of the pane
	rain.direction = Vector2(0.12, 1.0)          # a slight wind-driven slant
	rain.spread = 0.0
	rain.gravity = Vector2(0, 900)
	rain.initial_velocity_min = 220.0
	rain.initial_velocity_max = 300.0
	rain.scale_amount_min = 0.8
	rain.scale_amount_max = 1.2
	rain.color = Color(0.62, 0.72, 0.95, 0.55)   # cool, translucent
	add_child(rain)


func _streak_texture() -> Texture2D:
	# A thin vertical raindrop streak (2x12), fading top-to-bottom.
	var img := Image.create(2, 12, false, Image.FORMAT_RGBA8)
	for y in range(12):
		var a := 0.25 + 0.6 * (float(y) / 11.0)
		for x in range(2):
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)
