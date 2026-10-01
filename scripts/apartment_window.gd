extends Node2D

# A NON-balcony apartment module's WALL WINDOW: a framed pane onto the CITY (tools/art/cityscape.py — a skyline
# that burns a little more each run, with small pixel fires, distant blasts and, at night, looping pixel rain
# behind the glass — scripts/city_fx.gd), plus natural light. Placed by room._build_modules at a seeded
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

# The glass (the art's pane, tools/art/cityscape.py GLASS_W/H): half-extents. The node's origin is the glass centre.
const PANE_HALF_W := 22.0
const PANE_HALF_H := 26.0

const CITY_FX = preload("res://scripts/city_fx.gd")
const CITY_VIEW = preload("res://scripts/city_view.gd")
const VARIANTS := 4

var light: PointLight2D = null
var view: Sprite2D = null
var frame: Sprite2D = null
var fx: Node2D = null
var city: Node2D = null        # the clipped, panning city (scripts/city_view.gd): its FAR holds the skyline + the fires on it
var _night := false


func setup(pos: Vector2, live: bool, variant_seed: int = -1) -> void:
	position = pos
	z_index = 0
	var run: int = clampi(WorldState.current_run, 1, 3)
	_night = run == 3
	light = FL.make_window_light(Vector2.ZERO, APARTMENT_WINDOW_ENERGY_SCALE)
	# The storm driver finds every window this way to flash them as one lightning event.
	light.add_to_group("apt_window_light")
	# Remember the run's base energy so a flash can return to it exactly.
	light.set_meta("base_energy", light.energy)
	add_child(light)
	# THE CITY OUTSIDE: a skyline behind the glass (a stable per-window variant — the same city all three
	# runs, only its light, fires and weather change), the animations over it, then the frame on top.
	var seed_v: int = variant_seed if variant_seed >= 0 else hash(str(int(round(pos.x))) + "_" + str(int(round(pos.y))) + "win")
	var variant: int = absi(seed_v) % VARIANTS
	var key := "view_%d_%d" % [run, variant]
	# The view is drawn wider than the glass and slides a few px as you walk past (round 33 — city_view.gd); clipped to the glass.
	city = CITY_VIEW.new()
	city.name = "City"
	add_child(city)
	city.setup_view(float(CITY_FX.meta().get("_sizes", {}).get("pan", 0)))
	city.set_mask_rect(Rect2(-PANE_HALF_W, -PANE_HALF_H, PANE_HALF_W * 2.0, PANE_HALF_H * 2.0))
	view = Sprite2D.new()
	view.texture = load("res://assets/city/%s.png" % key)
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.material = CITY_FX.unshaded()
	view.modulate = CITY_FX.exposure(1.0)        # the exterior isn't lit by the room's darkness (unshaded)
	city.far.add_child(view)
	fx = CITY_FX.new()
	city.add_child(fx)                           # its rain stays put on the glass; its fires ride the FAR node
	fx.setup_window(key, run, live, seed_v, light, view, "rain_window", city.far)
	# A slanting sunbeam / moonbeam shaft in through the glass (see window_beam.gd) — over the city, under the frame.
	var beam = load("res://scripts/window_beam.gd").new()
	add_child(beam)
	beam.setup(Vector2.ZERO, 0.9, 1.0, live)
	frame = Sprite2D.new()
	var ftex: Texture2D = load("res://assets/city/window_frame_%d.png" % run)
	frame.texture = ftex
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.centered = false
	var fsize: Array = CITY_FX.meta().get("_sizes", {}).get("frame_glass_centre", [27, 31])
	frame.position = -Vector2(float(fsize[0]), float(fsize[1]))   # the glass centre sits on the node origin
	add_child(frame)
