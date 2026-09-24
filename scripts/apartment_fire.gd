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

const TILE_PX := 32
const BONFIRE_PX := 64
const FLAME_PX := 32
const TILE_FRAMES := 6
const TILE_FPS := 12.0

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

var _tile_tex: Array = []
var _flame_tex: Array = []
var _bonfire_tex: Texture2D = null


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
	var base := "res://assets/fire-pixel-art-animation-sprites/"
	for n in ["1", "2", "3", "4"]:
		var t = load(base + "2 Fire_tiles/" + n + ".png")
		if t != null:
			_tile_tex.append(t)
		var fl = load(base + "3 Flame/" + n + ".png")
		if fl != null:
			_flame_tex.append(fl)
	_bonfire_tex = load(base + "1 Fire/Idle.png")


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


func _tile_scale() -> float:
	return 1.8 if stage >= STAGE_BLAZE else 1.3


func _draw_beds(canvas: CanvasItem) -> void:
	# A short fire tile bed (folder 2) at each spot, on the floor, up to ~waist — the
	# player walks THROUGH it. Sized by the spot + stage.
	if _tile_tex.is_empty():
		return
	var fr := int(_t * TILE_FPS) % TILE_FRAMES
	for s in _spots:
		var cx: float = float(s["x"])
		var sc: float = _tile_scale() * float(s["sz"])
		var tex: Texture2D = _tile_tex[int(_hash01(cx * 0.13) * float(_tile_tex.size())) % _tile_tex.size()]
		var w: float = float(TILE_PX) * sc
		var target_h: float = (30.0 if stage >= STAGE_BLAZE else 22.0) * float(s["sz"])
		var src := Rect2(float(fr * TILE_PX), float(TILE_PX) - float(TILE_PX) * 0.6, float(TILE_PX), float(TILE_PX) * 0.6)
		# ONE bed per spot — spots are already spaced so beds stay distinct (no widening
		# that would bridge into a neighbour).
		canvas.draw_texture_rect_region(tex, Rect2(cx - w * 0.5, base_y - target_h - 4.0, w, target_h), src)


func _draw_tall_flames(canvas: CanvasItem) -> void:
	# The rising flame globs behind the player — mid flames (folder 3), and a big bonfire
	# (folder 1) on the largest BLAZE spots. Small on LIGHT, larger on BLAZE.
	for s in _spots:
		var cx: float = float(s["x"])
		var sz: float = float(s["sz"])
		var sd: float = cx * 0.7
		if stage >= STAGE_BLAZE and _bonfire_tex != null and _hash01(sd * 3.3) > 0.45:
			_blit_anim(canvas, _bonfire_tex, BONFIRE_PX, cx, base_y, (0.5 + 0.35 * _hash01(sd)) * sz, int(sd) % 6, sd)
		elif not _flame_tex.is_empty():
			var tex: Texture2D = _flame_tex[int(_hash01(sd * 1.7) * float(_flame_tex.size())) % _flame_tex.size()]
			_blit_anim(canvas, tex, FLAME_PX, cx, base_y, (0.7 + 0.5 * _hash01(sd)) * sz, int(sd) % 6, sd)


func _blit_anim(canvas: CanvasItem, tex: Texture2D, px: int, cx: float, by: float, sc: float, col: int, sd: float) -> void:
	if tex == null:
		return
	var fr := (int(_t * TILE_FPS) + col * 2) % TILE_FRAMES
	var src := Rect2(float(fr * px), 0.0, float(px), float(px))
	var w := float(px) * sc
	var h := float(px) * sc
	var jx := (_hash01(sd * 2.1) - 0.5) * 18.0
	canvas.draw_texture_rect_region(tex, Rect2(cx + jx - w * 0.5, by - h, w, h), src, Color(1.0, 1.0, 1.0, 1.0))


func _draw_char_scars(canvas: CanvasItem) -> void:
	# Thin ragged SOOT STREAKS on the floor where fire was (the corridor's look, fire_field._char_scar)
	# — never blobs: circles, then flat ellipses, both read as rows of black balls (owner round 8).
	for x in _scars:
		var xf: float = float(x)
		SOFT_SMOKE.draw_soot(canvas, xf, base_y - 2.0, 52.0, xf * 0.37)


