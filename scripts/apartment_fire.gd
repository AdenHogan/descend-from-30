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
const SMOKE_FRAMES := 6
const SMOKE_FPS := 8.0

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
var _smoke_reg: Array = []


func _ready() -> void:
	_load_textures()
	_build_spots()
	_spawn_layers()
	add_to_group("fire_field")


func _process(delta: float) -> void:
	_t += delta


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
	var sm := "res://assets/smoke-effects-pixel-art/PNG/Cycled_smoke/Cycled_smoke%d.png"
	for i in range(1, SMOKE_FRAMES + 1):
		var r = load(sm % i)
		if r != null:
			_smoke_reg.append(r)


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
			# Fire all across the room — many patches, larger globs, with gaps.
			var x := span0 + 20.0
			while x < span1:
				if rng.randf() < 0.6:
					_spots.append({"x": x, "sz": 1.0 + rng.randf() * 0.7})
				x += 66.0 + rng.randf() * 44.0
			if _spots.is_empty():
				_spots.append({"x": (span0 + span1) * 0.5, "sz": 1.2})
		_:
			# LIGHT outbreak: a few small patches near the entrance the fire crept in from.
			var n := 2 + (rng.randi() % 3)     # 2-4
			for k in range(n):
				var sx: float = clampf(entrance_x + (rng.randf() - 0.5) * 200.0, span0, span1)
				_spots.append({"x": sx, "sz": 0.6 + rng.randf() * 0.35})


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


func draw_layer(canvas: CanvasItem, which: int) -> void:
	if which == LYR_BACK:
		_draw_tall_flames(canvas)     # tall flames rise BEHIND the player
		_draw_smoulder(canvas)        # smoulder smoke off scorched patches
		_draw_smoke(canvas)           # active-fire smoke plumes
	else:
		_draw_char_scars(canvas)      # scorch on the floor, in front
		_draw_beds(canvas)            # fire tile bed at the player's feet (walk through)


func _hash01(v: float) -> float:
	return fmod(absf(sin(v * 12.9898) * 43758.5453), 1.0)


func _tile_scale() -> float:
	return 2.3 if stage >= STAGE_BLAZE else 1.5


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
		# tile a couple across for wider spots
		var reps := 2 if float(s["sz"]) > 1.1 else 1
		for r in range(reps):
			var x0 := cx - w * 0.5 + float(r) * (w * 0.8)
			canvas.draw_texture_rect_region(tex, Rect2(x0, base_y - target_h - 4.0, w, target_h), src)


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
	for x in _scars:
		var xf: float = float(x)
		for k in range(3):
			var hx: float = _hash01(xf * 2.0 + float(k) * 1.3)
			canvas.draw_circle(Vector2(xf + (hx - 0.5) * 30.0, base_y - 1.0 + hx * 3.0), 4.0 + hx * 3.5, CHAR_COL)


func _draw_smoke(canvas: CanvasItem) -> void:
	# A plume rising off each burning spot (bigger on a BLAZE).
	if _smoke_reg.is_empty():
		return
	for s in _spots:
		var cx: float = float(s["x"])
		var sd: float = cx * 0.31
		var frame: int = int(_t * SMOKE_FPS + sd) % SMOKE_FRAMES
		var sc: float = (0.45 if stage >= STAGE_BLAZE else 0.32) + 0.25 * _hash01(sd)
		_blit_smoke(canvas, _smoke_reg[frame], cx, sc, 0.7)


func _draw_smoulder(canvas: CanvasItem) -> void:
	# Grey smoulder off scorched/charred patches — a doused or burnt-out room stays smoky.
	if _smoke_reg.is_empty():
		return
	for x in _scars:
		var xf: float = float(x)
		var sd: float = xf * 0.53
		if _hash01(sd) > 0.7:
			continue
		var frame: int = int(_t * SMOKE_FPS + sd) % SMOKE_FRAMES
		_blit_smoulder(canvas, _smoke_reg[frame], xf, 0.4 + 0.3 * _hash01(sd * 1.7))


func _blit_smoke(canvas: CanvasItem, tex: Texture2D, cx: float, sc: float, alpha: float) -> void:
	if tex == null:
		return
	var w := 128.0 * sc
	var h := 128.0 * sc
	canvas.draw_texture_rect(tex, Rect2(cx - w * 0.5, base_y - 10.0 - h, w, h), false, Color(1.0, 1.0, 1.0, alpha))


func _blit_smoulder(canvas: CanvasItem, tex: Texture2D, cx: float, sc: float) -> void:
	if tex == null:
		return
	var w := 128.0 * sc
	var h := 128.0 * sc
	canvas.draw_texture_rect(tex, Rect2(cx - w * 0.5, base_y - 6.0 - h, w, h), false, Color(0.62, 0.60, 0.58, 0.5))
