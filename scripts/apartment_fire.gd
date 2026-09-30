extends Node2D

# Interior apartment fire — a NO-SIM, procedurally-placed fire built from the purchased
# craftpix sprites (same look as the corridor fire_field, different placement). It does
# NOT spread: room.gd hands it a stage + geometry and it scatters burning SPOTS once —
# LIGHT = a few small spots near the entrance; BLAZE = many, larger, across the whole
# room; CHARRED = no fire, just scorch + heavy smoulder smoke. Seeded per (apartment,run)
# so it never looks the same but is stable on re-entry.
#
# It implements the SAME interface the extinguisher + burn code already use
# (is_burning_at / any_burning / extinguish_at / smoke_intensity / has_smoulder) and joins
# the "fire_field" group, so those systems find it inside a room with zero extra wiring.

const FIRE_LAYER := preload("res://scripts/fire_layer.gd")

const STAGE_LIGHT := 0
const STAGE_BLAZE := 1
const STAGE_CHARRED := 2

const LYR_BACK := 0
const LYR_FRONT := 2

const SPOT_RADIUS := 34.0          # how wide a spot "burns" for is_burning_at / dousing
const CHAR_COL := Color(0.09, 0.08, 0.08, 0.9)

# --- geometry + config, set by room.gd BEFORE add_child --------------------
var stage: int = STAGE_LIGHT
var span0: float = 130.0           # left x of the fire region (interior)
var span1: float = 1055.0          # right x
var base_y: float = 356.0          # the room floor line fire rises from (feet ~321+)
var entrance_x: float = 150.0      # LIGHT clusters near the door the fire crept in from
var seed_salt: String = ""         # apartment id, for the per-apartment seed

var _spots: Array = []             # [{x, sz}] actively burning patches
var _scars: Array = []             # [x] doused/charred patches → scorch + smoulder smoke
var _t: float = 0.0



func _ready() -> void:
	_load_textures()
	_build_spots()
	_spawn_layers()
	add_to_group("fire_field")


func _process(delta: float) -> void:
	_t += delta
	_update_lights()
	_smoke_sync_t -= delta
	if _smoke_sync_t <= 0.0:
		_smoke_sync_t = 0.25
		_sync_smoke()


# SMOKE: the same soft particle smoke as the corridor (scripts/soft_smoke.gd) — a burning spot smokes,
# a doused one billows then smoulders, a charred room smoulders. Keyed by the spot's x, so dousing a
# spot turns its fire smoke into a billow + smoulder in place.
const SOFT_SMOKE := preload("res://scripts/soft_smoke.gd")
var _smoke_nodes: Dictionary = {}
var _smoke_sync_t: float = 0.0
var _smoke_synced_once: bool = false
var _back_layer: Node2D = null


func _sync_smoke() -> void:
	if _back_layer == null or not is_instance_valid(_back_layer):
		return
	var wanted := {}
	for sp in _spots:
		var x: float = float(sp["x"])
		wanted[int(round(x))] = {"kind": "fire", "x": x, "y": base_y - 10.0,
			"w": 40.0 * float(sp["sz"]) * (1.4 if stage >= STAGE_BLAZE else 1.0)}
	for x in _scars:
		var k := int(round(float(x)))
		if not wanted.has(k):
			wanted[k] = {"kind": "smoulder", "x": float(x), "y": base_y - 6.0, "w": 44.0}
	SOFT_SMOKE.sync(_back_layer, _smoke_nodes, wanted, not _smoke_synced_once)
	_smoke_synced_once = true


# Burning spots throw a small flickering orange glow, like the corridor fire (fire_field): without
# it an apartment fire at night was dull unlit sprites in the dark. One light per spot, gone the
# moment the spot is doused.
const FIRE_LIGHT_COLOR := Color(1.0, 0.52, 0.16)
const FLOOR_LIGHTING := preload("res://scripts/floor_lighting.gd")
var _lights: Array = []


func _update_lights() -> void:
	while _lights.size() < _spots.size():
		var lt := PointLight2D.new()
		lt.texture = FLOOR_LIGHTING.light_texture()
		lt.color = FIRE_LIGHT_COLOR
		lt.z_index = 0
		add_child(lt)
		_lights.append(lt)
	for i in range(_lights.size()):
		var lt: PointLight2D = _lights[i]
		if i >= _spots.size():
			lt.energy = 0.0
			continue
		lt.position = Vector2(float(_spots[i]["x"]), base_y - 28.0)
		lt.texture_scale = 0.8 if stage >= STAGE_BLAZE else 0.6
		lt.energy = (0.55 if stage >= STAGE_BLAZE else 0.42) * (0.82 + 0.15 * sin(_t * 10.0 + float(i) * 1.9))


func _load_textures() -> void:
	pass       # our fire art loads lazily through FireArt (scripts/fire_art.gd)


func _rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash(str(WorldState.master_seed) + "aptfire" + seed_salt + str(WorldState.current_run))
	return r


func _build_spots() -> void:
	# Place the fire ONCE, by stage. No spread — the layout is the whole fire.
	_spots.clear()
	_scars.clear()
	var rng := _rng()
	match stage:
		STAGE_CHARRED:
			# A burnt-out husk: no fire, scorch marks + heavy smoulder across the room.
			var x := span0 + 20.0
			while x < span1:
				if rng.randf() < 0.72:
					_scars.append(x)
				x += 58.0 + rng.randf() * 26.0
		STAGE_BLAZE:
			# Fire spread EVENLY across the whole room (all three modules) — one small patch
			# per fixed slot so coverage is consistent, never two thick clumps with bare gaps.
			# Sizes are kept small so neighbouring patches DON'T overlap into a blob.
			var width: float = maxf(span1 - span0, 1.0)
			var n: int = maxi(int(width / 118.0), 3)        # at least 3 patches, ~one per 118px
			var step: float = width / float(n)
			for k in range(n):
				var base: float = span0 + (float(k) + 0.5) * step
				var jx: float = (rng.randf() - 0.5) * step * 0.35
				_spots.append({"x": clampf(base + jx, span0 + 16.0, span1 - 16.0), "sz": 0.7 + rng.randf() * 0.22})
		_:
			# LIGHT outbreak: 2-3 small patches marching in from the entrance the fire crept
			# in from, spaced so they stay distinct (never overlapping).
			var n := 2 + (rng.randi() % 2)         # 2-3
			var dir := 1.0 if entrance_x < (span0 + span1) * 0.5 else -1.0
			for k in range(n):
				var sx: float = clampf(entrance_x + dir * float(k) * 108.0 + (rng.randf() - 0.5) * 30.0, span0, span1)
				_spots.append({"x": sx, "sz": 0.6 + rng.randf() * 0.3})


# --- interface shared with fire_field (extinguisher + burn code call these) ---

func is_burning_at(x: float) -> bool:
	for s in _spots:
		if absf(float(s["x"]) - x) <= SPOT_RADIUS:
			return true
	return false


func any_burning() -> bool:
	return not _spots.is_empty()


func has_smoulder() -> bool:
	return not _scars.is_empty()


func extinguish_span(x0: float, x1: float) -> void:
	extinguish_at((x0 + x1) * 0.5, absf(x1 - x0) * 0.5)


func extinguish_at(x: float, radius: float) -> void:
	# Douse every spot within reach — each becomes a scorched, smouldering patch.
	var kept: Array = []
	for s in _spots:
		if absf(float(s["x"]) - x) <= radius + SPOT_RADIUS:
			_scars.append(float(s["x"]))
		else:
			kept.append(s)
	_spots = kept


func smoke_intensity() -> float:
	# 0..1 haze strength: active fire smokes most, scorched patches smoulder at a lower
	# weight, scaled by stage — a charred room stays hazy.
	var width: float = maxf(span1 - span0, 1.0)
	var frac := (float(_spots.size()) * 90.0 + float(_scars.size()) * 55.0) / width
	return clampf(frac * (1.1 + float(stage) * 0.6), 0.0, 1.0)


# --- render (two depth layers via fire_layer.gd) ---------------------------

func _spawn_layers() -> void:
	for spec in [[LYR_BACK, 0], [LYR_FRONT, 2]]:
		var lyr = FIRE_LAYER.new()
		lyr.field = self
		lyr.layer = int(spec[0])
		lyr.z_as_relative = false
		lyr.z_index = int(spec[1])
		lyr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		lyr.material = FireArt.material()
		add_child(lyr)
		if int(spec[0]) == LYR_BACK:
			_back_layer = lyr


func draw_layer(canvas: CanvasItem, which: int) -> void:
	if which == LYR_BACK:
		_draw_char_scars(canvas)      # soot lies on the floor BEHIND the player (walk over it)
		_draw_tall_flames(canvas)     # tall flames rise BEHIND the player
		# Smoke = the soft particle emitters under this layer (_sync_smoke).
	else:
		_draw_beds(canvas)            # fire tile bed at the player's feet (walk through)


func _hash01(v: float) -> float:
	return fmod(absf(sin(v * 12.9898) * 43758.5453), 1.0)



func _draw_beds(canvas: CanvasItem) -> void:
	# A carpet of flame at each spot, on the floor, up to ~waist — the player walks THROUGH it. Two overlapping whole clumps
	# per spot on a blaze, one on a light fire (our strips, never cropped).
	var kind := "blaze" if stage >= STAGE_BLAZE else "light"
	var names: Array = FireArt.variants("bed_front_" + kind)
	if names.is_empty():
		return
	for s in _spots:
		var cx: float = float(s["x"])
		var offs: Array = [-16.0, 16.0] if stage >= STAGE_BLAZE else [0.0]
		for k in range(offs.size()):
			var sd: float = cx * 0.13 + float(k) * 2.7
			FireArt.draw(canvas, str(names[int(_hash01(sd) * float(names.size())) % names.size()]), _t, _hash01(sd * 3.1), Vector2(cx + float(offs[k]), base_y - 1.0))


func _draw_tall_flames(canvas: CanvasItem) -> void:
	# The flame rising off each spot behind the player: small / medium on a light fire, medium / large on a blaze
	# (bigger spots get the bigger sprite).
	for s in _spots:
		var cx: float = float(s["x"])
		var sd: float = cx * 0.7
		var size := "s"
		if stage >= STAGE_BLAZE:
			size = "l" if float(s["sz"]) > 0.82 or _hash01(sd * 3.3) > 0.6 else "m"
		else:
			size = "m" if float(s["sz"]) > 0.78 else "s"
		var names: Array = FireArt.variants("tongue_" + size)
		if not names.is_empty():
			FireArt.draw(canvas, str(names[int(_hash01(sd * 1.7) * float(names.size())) % names.size()]), _t, _hash01(sd * 2.1), Vector2(cx, base_y - 3.0))




func _draw_char_scars(canvas: CanvasItem) -> void:
	# Thin ragged SOOT STREAKS on the floor where fire was (the corridor's look, fire_field._char_scar)
	# — never blobs: circles, then flat ellipses, both read as rows of black balls (owner round 8).
	for x in _scars:
		var xf: float = float(x)
		SOFT_SMOKE.draw_soot(canvas, xf, base_y - 2.0, 52.0, xf * 0.37)


