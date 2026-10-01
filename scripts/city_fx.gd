extends Node2D

# THE CITY OUTSIDE, ALIVE (owner round 28 — "pixel rain that loops as an animation behind the window, and on the
# balcony in the night run… small pixel fires and explosions on those buildings in the distance").
#
# One node per window / balcony. The skyline itself is baked art (tools/art/cityscape.py → assets/city/); this node
# plays the small looping animations over it, at the points the art tool recorded (assets/city/city_meta.json,
# balcony_meta.json):
#   * FIRES  — small pixel blazes on the towers (none in the morning, a couple at dusk, several at night), with a
#              smoke plume rising off some;
#   * BLASTS — a distant explosion on a tower every so often (rare by day, every 5-12 s at night): a flash, a
#              fireball, a dark cloud; the window's light jumps a little and a muffled boom follows a beat later;
#   * RAIN   — a looping pixel-rain sheet (night only) behind the glass / beyond the balcony rail, and ripples on the
#              wet balcony tiles.
# Pure visuals: no collision, no groups that gameplay reads. Everything is exposed to undo the world's
# CanvasModulate (the night ambient is near-black) by being UNSHADED, so the exterior reads as light from OUTSIDE, not as a lit prop.

const DIR := "res://assets/city/"
const THUNDER := preload("res://assets/audio/ambience/thunder_1.wav")

const RAIN_FPS := 22.0
const FIRE_FPS := 9.0
const BLAST_FPS := 12.0
const SMOKE_FPS := 6.0
const SPLASH_FPS := 7.0

# night: a blast every BLAST_GAP seconds (min, max); dusk is rarer; the morning has none
const BLAST_GAP := {1: [0.0, 0.0], 2: [24.0, 46.0], 3: [5.5, 12.5]}
const FIRE_COUNT := {1: [0, 0], 2: [1, 2], 3: [2, 4]}
const SMOKE_COUNT := {1: [1, 1], 2: [1, 2], 3: [1, 1]}
const BOOM_MIN_GAP_MS := 2500

static var _meta: Dictionary = {}
static var _unshaded: CanvasItemMaterial = null
static var _last_boom_ms: int = -100000

var run: int = 1
var live: bool = true
var small: bool = true                   # window-sized sprites (vs the balcony's)
var _rng := RandomNumberGenerator.new()
var _blast_pts: Array = []
var _blast_timer: float = -1.0
var _own_light: PointLight2D = null
var _exposed: Array = []                 # [CanvasItem, kind] — re-exposed when the light changes
var _flash_t: float = 0.0
var _view: CanvasItem = null
## Where the things standing ON the city go (fires, smoke, blasts, an aircraft light): a CityView's FAR node, so they slide with
## the skyline as you walk past (round 33). The rain + ripples always stay on this node (weather on the near side). null = self.
var far_holder: Node2D = null


static func meta() -> Dictionary:
	if _meta.is_empty():
		for f in ["city_meta.json", "balcony_meta.json"]:
			var fa := FileAccess.open(DIR + f, FileAccess.READ)
			if fa == null:
				continue
			var parsed = JSON.parse_string(fa.get_as_text())
			if parsed is Dictionary:
				for k in parsed:
					_meta[k] = parsed[k]
		if _meta.is_empty():
			_meta = {"_empty": true}
	return _meta


## The exterior ignores the room's lights AND the night's CanvasModulate: unshaded, it shows as the art drew it.
static func unshaded() -> CanvasItemMaterial:
	if _unshaded == null:
		_unshaded = CanvasItemMaterial.new()
		_unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _unshaded


## A horizontal strip PNG (frames side by side, each `fw` wide) as SpriteFrames.
static func strip_frames(path: String, fw: int, fps: float, loop: bool) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.set_animation_loop("default", loop)
	sf.set_animation_speed("default", fps)
	var tex: Texture2D = load(path)
	if tex == null:
		return sf
	var n: int = int(tex.get_width() / fw)
	for i in n:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * fw, 0, fw, tex.get_height())
		sf.add_frame("default", at)
	return sf


## How bright an exterior item is drawn, as a multiplier of its art (k = 1.0 shows exactly as drawn). The exterior is
## UNSHADED (see unshaded()) — it ignores both the room's lights and the world's night CanvasModulate — so this is just `k`.
## Kept as one function so the look can be tuned in one place (the old version tried to undo the ambient darkness and
## blew the pane out, because unshaded items are never darkened in the first place).
static func exposure(k: float = 1.0) -> Color:
	return Color(k, k, k, 1.0)


func _sprite(path: String, fw: int, fps: float, loop: bool, pos: Vector2, kind: String = "fx") -> AnimatedSprite2D:
	var a := AnimatedSprite2D.new()
	a.sprite_frames = strip_frames(path, fw, fps, loop)
	a.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	a.position = pos
	a.material = unshaded()
	a.modulate = exposure(1.0 if kind != "rain" else 0.7)
	_exposed.append([a, kind])
	_holder(kind).add_child(a)
	return a


func _holder(kind: String) -> Node2D:
	if kind == "rain" or far_holder == null or not is_instance_valid(far_holder):
		return self
	return far_holder


func _pick(pts: Array, count: int) -> Array:
	var pool: Array = pts.duplicate()
	var out: Array = []
	while out.size() < count and not pool.is_empty():
		out.append(pool.pop_at(_rng.randi() % pool.size()))
	return out


func _to_v(p) -> Vector2:
	return Vector2(float(p[0]), float(p[1]))


# ---- the window's view ---------------------------------------------------------------------------------------
## `key` = "view_<run>_<variant>" (or a stairwell's "stair_view_<run>_<v>" with `rain_sheet` "rain_stair"); the node's origin is the glass centre. `view` = the sprite drawn under this
## (so lightning can flash it).
func setup_window(key: String, run_: int, live_: bool, seed_: int, window_light: PointLight2D, view_item: CanvasItem,
		rain_sheet: String = "rain_window", far_: Node2D = null) -> void:
	far_holder = far_
	run = run_
	live = live_
	small = true
	_own_light = window_light
	_view = view_item
	_rng.seed = seed_
	add_to_group("city_fx")
	var m: Dictionary = meta().get(key, {})
	var sizes: Dictionary = meta().get("_sizes", {})
	var fires_pts: Array = m.get("fire", [])
	_blast_pts = m.get("blast", [])
	var smoke_pts: Array = m.get("smoke", [])
	var fire_path: String = DIR + "fire_s.png"
	var used: Array = []
	# smoke plumes first (behind the fires)
	var sc: Array = SMOKE_COUNT[clampi(run, 1, 3)]
	for p in _pick(smoke_pts, _rng.randi_range(sc[0], sc[1])):
		var v := _to_v(p)
		var a := _sprite(DIR + "smoke_%d.png" % run, 14, SMOKE_FPS, true, v + Vector2(0, -14))
		a.frame = _rng.randi() % maxi(1, a.sprite_frames.get_frame_count("default"))
		a.play()
	var fc: Array = FIRE_COUNT[clampi(run, 1, 3)]
	for p in _pick(fires_pts, _rng.randi_range(fc[0], fc[1])):
		var v := _to_v(p)
		used.append(v)
		var smk := _sprite(DIR + "smoke_%d.png" % run, 14, SMOKE_FPS, true, v + Vector2(0, -15))
		smk.frame = _rng.randi() % maxi(1, smk.sprite_frames.get_frame_count("default"))
		smk.play()
		var a := _sprite(fire_path, 6, FIRE_FPS, true, v + Vector2(0, -3))
		a.frame = _rng.randi() % 6
		a.speed_scale = _rng.randf_range(0.85, 1.2)
		a.play()
	if run == 3:
		# an aircraft warning light blinking on a tall mast — red, slow
		var beacons: Array = m.get("beacon", [])
		if not beacons.is_empty():
			var b: Array = beacons[_rng.randi() % beacons.size()]
			var dot := ColorRect.new()
			dot.size = Vector2(1, 1)
			dot.position = _to_v(b)
			dot.color = Color(1.0, 0.25, 0.2)
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			dot.material = unshaded()
			dot.modulate = exposure(1.0)
			_holder("fx").add_child(dot)
			_exposed.append([dot, "fx"])
			var tw := create_tween().set_loops()
			tw.tween_property(dot, "modulate:a", 0.15, 0.7)
			tw.tween_property(dot, "modulate:a", 1.0, 0.25)
			tw.tween_interval(0.9)
	# rain: night only, a looping sheet over the whole glass
	if run == 3:
		var r := _sprite(DIR + rain_sheet + ".png", int(sizes.get(rain_sheet, [44])[0]), RAIN_FPS, true, Vector2.ZERO, "rain")
		r.frame = _rng.randi() % 13
		r.play()
		r.add_to_group("window_rain")
	_arm_blasts()


# ---- the balcony -----------------------------------------------------------------------------------------------
## The node sits at the balcony module's origin (module-local coordinates, like the art).
func setup_balcony(run_: int, live_: bool, seed_: int, far_: Node2D = null) -> void:
	far_holder = far_
	run = run_
	live = live_
	small = true
	_rng.seed = seed_
	add_to_group("city_fx")
	var m: Dictionary = meta()
	var bm: Dictionary = m.get("run_%d" % run, {})
	_blast_pts = bm.get("blast", [])
	var sc: Array = SMOKE_COUNT[clampi(run, 1, 3)]
	for p in _pick(bm.get("smoke", []), _rng.randi_range(sc[0], sc[1])):
		var v := _to_v(p)
		var a := _sprite(DIR + "smoke_%d.png" % run, 14, SMOKE_FPS, true, v + Vector2(0, -14))
		a.frame = _rng.randi() % 10
		a.play()
	var fc: Array = FIRE_COUNT[clampi(run, 1, 3)]
	for p in _pick(bm.get("fire", []), _rng.randi_range(fc[0], fc[1] + (1 if run == 3 else 0))):
		var v := _to_v(p)
		var smk := _sprite(DIR + "smoke_%d.png" % run, 14, SMOKE_FPS, true, v + Vector2(0, -15))
		smk.frame = _rng.randi() % 10
		smk.play()
		var a := _sprite(DIR + "fire_s.png", 6, FIRE_FPS, true, v + Vector2(0, -3))
		a.frame = _rng.randi() % 6
		a.speed_scale = _rng.randf_range(0.85, 1.2)
		a.play()
	if run == 3:
		for b in bm.get("beacon", []).slice(0, 1):
			var dot := ColorRect.new()
			dot.size = Vector2(1, 1)
			dot.position = _to_v(b)
			dot.color = Color(1.0, 0.25, 0.2)
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			dot.material = unshaded()
			dot.modulate = exposure(1.0)
			_holder("fx").add_child(dot)
			_exposed.append([dot, "fx"])
			var tw := create_tween().set_loops()
			tw.tween_property(dot, "modulate:a", 0.15, 0.7)
			tw.tween_property(dot, "modulate:a", 1.0, 0.25)
			tw.tween_interval(0.9)
		var origin: Array = m.get("rain_origin", [10, 16])
		var size: Array = m.get("rain_size", [80, 78])
		var r := _sprite(DIR + "rain_balcony_masked.png", int(size[0]),
			RAIN_FPS, true, Vector2(float(origin[0]) + float(size[0]) * 0.5, float(origin[1]) + float(size[1]) * 0.5), "rain")
		r.frame = _rng.randi() % 13
		r.play()
		r.add_to_group("balcony_rain")
		# ripples on the wet tiles near the far edge (rain blowing in)
		var sp: Dictionary = m.get("splash", {"x0": 21, "x1": 79, "y0": 88, "y1": 97})
		for i in 9:
			var pos := Vector2(_rng.randf_range(float(sp["x0"]), float(sp["x1"])), _rng.randf_range(float(sp["y0"]), float(sp["y1"])))
			var s := _sprite(DIR + "splash.png", 9, SPLASH_FPS, true, pos, "rain")
			s.frame = _rng.randi() % 4
			s.speed_scale = _rng.randf_range(0.5, 1.3)
			s.modulate.a = 0.75
			s.play()
			s.add_to_group("balcony_splash")
	_arm_blasts()


# ---- blasts ----------------------------------------------------------------------------------------------------
func _arm_blasts() -> void:
	var gap: Array = BLAST_GAP[clampi(run, 1, 3)]
	if _blast_pts.is_empty() or gap[1] <= 0.0:
		_blast_timer = -1.0
		set_process(false)
		return
	_blast_timer = _rng.randf_range(float(gap[0]) * 0.3, float(gap[1]))   # the first comes soon after arriving
	set_process(live)


func _process(delta: float) -> void:
	if _blast_timer > 0.0:
		_blast_timer -= delta
		if _blast_timer <= 0.0:
			blast()
			var gap: Array = BLAST_GAP[clampi(run, 1, 3)]
			_blast_timer = _rng.randf_range(float(gap[0]), float(gap[1]))
	if _flash_t > 0.0:
		_flash_t = maxf(0.0, _flash_t - delta)
		if _view != null and is_instance_valid(_view):
			var k: float = _flash_t / 0.4
			var e: Color = exposure(1.0)
			var g := 1.0 + 1.6 * k                      # the sky + skyline jump to ~2.6x for a beat
			_view.modulate = Color(e.r * g, e.g * g, e.b * g * (1.0 + 0.1 * k), 1.0)


## One distant explosion on a tower (also callable by tests).
func blast(at: int = -1) -> AnimatedSprite2D:
	if _blast_pts.is_empty():
		return null
	var p = _blast_pts[at] if at >= 0 and at < _blast_pts.size() else _blast_pts[_rng.randi() % _blast_pts.size()]
	var v := _to_v(p)
	var path: String = DIR + ("explosion_s.png" if small else "explosion.png")
	var w: int = 12 if small else 16
	var a := _sprite(path, w, BLAST_FPS, false, v, "fx")
	a.animation_finished.connect(a.queue_free)
	a.play()
	a.add_to_group("city_blast")
	# the room's window light jumps a little, and the boom arrives a beat later
	if _own_light != null and is_instance_valid(_own_light):
		var base: float = float(_own_light.get_meta("base_energy", _own_light.energy))
		var t := create_tween()
		t.tween_property(_own_light, "energy", base + 0.55, 0.06)
		t.tween_property(_own_light, "energy", base, 0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	get_tree().create_timer(_rng.randf_range(0.5, 1.6), false).timeout.connect(_boom)
	return a


func _boom() -> void:
	var now := Time.get_ticks_msec()
	if not is_inside_tree() or now - _last_boom_ms < BOOM_MIN_GAP_MS:
		return
	_last_boom_ms = now
	var p := AudioStreamPlayer.new()
	p.stream = THUNDER
	p.volume_db = -27.0
	p.pitch_scale = _rng.randf_range(0.42, 0.6)        # low + dull: far away
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


## Lightning (apartment_storm): the sky behind the glass flashes pale for a beat.
func lightning_flash() -> void:
	_flash_t = 0.4
	set_process(live)
