extends Node2D

# Hazard 3 — a fire that SPREADS along the corridor over time. The floor is a row
# of cells; a BURNING cell pushes heat into its neighbours, a cell ignites once
# its heat passes a threshold, burns while it has fuel, then chars out (SPENT).
# Left unchecked it creeps across the whole floor. The spread is deterministic
# (RNG-free) so it's testable; only the flame RENDER flickers. Damage to the
# player and the extinguisher are driven by callers (building_floors / player).
#
# Model per cell: heat (0..~1.2) and fuel (1→0). State is derived:
#   fuel<=0            -> SPENT   (charred; can't burn again, no spread)
#   heat>=IGNITE       -> BURNING (consumes fuel, heats neighbours)
#   else               -> COOL    (heat slowly bleeds off)

const FIRE_MIN_X := 150.0
const FIRE_MAX_X := 1200.0
const CELL_W := 42.0
const FIRE_BASE_Y := 426.0        # floor line the flames rise from (sits on the feet/bodies)

const IGNITE_THRESHOLD := 0.5
# SPREAD is a SLOW, RAGGED creep. A burning cell's heat only just outpaces a cool
# cell's loss, and how well each cell CATCHES varies per-cell (_spread_mult), so
# the front advances unevenly — some cells take, others resist for ages — instead
# of a uniform wall marching across. Net ~= SPREAD_RATE*mult - COOL_RATE.
const SPREAD_RATE := 0.10         # heat/sec a burning cell pushes to each neighbour
const COOL_RATE := 0.085          # heat/sec a non-burning cell loses
# A fire does NOT burn itself out within a run — it stays lit until the player
# puts it out (or a run-3 char_all makes a ruin). So fuel never depletes from
# burning (BURN_RATE 0); only extinguish_at / char_all zero it. This is what
# makes a small fire CONSISTENT: ignore it and it's still there (worse next run).
const BURN_RATE := 0.0
const SIM_DT := 0.1               # fixed simulation step
const MAX_HEAT := 1.2

enum { COOL, BURNING, SPENT }

# Stage (set by building_floors from WorldState.fire_intensity): 0 LIGHT / 1 BLAZE
# / 2 CHARRED. It scales how BIG the flames are and how choking/low the smoke is —
# flames only get big and smoke only forces a crouch on a run-2 BLAZE.
const STAGE_LIGHT := 0
const STAGE_BLAZE := 1
const STAGE_CHARRED := 2

# Smoke billows past the flames and pools at the ceiling; on a BLAZE it sinks to
# head height (crouch under it). SMOKE_MARGIN_CELLS = how far past the flames the
# choking smoke drifts.
const SMOKE_MARGIN_CELLS := 3
const CEILING_Y := 30.0                 # top of the corridor (smoke gathers here)
const SMOKE_BOTTOM_LIGHT := 150.0       # LIGHT: hugs the ceiling — breathable below
const SMOKE_BOTTOM_BLAZE := 350.0       # BLAZE: sinks to head height — crouch under it

# Render layers (child CanvasItems at different z so the player stands INSIDE the
# fire): back-wall glow behind actors, main flames level with them, an ADDITIVE
# front glow + licks in front, and smoke on top.
const LYR_BACK := 0
const LYR_FRONT := 1
const LYR_SMOKE := 2

var cell_count: int = 0
var heat: PackedFloat32Array = PackedFloat32Array()
var fuel: PackedFloat32Array = PackedFloat32Array()
var floor_num: int = -1
var stage: int = STAGE_LIGHT
# Cap on how many cells the fire may reach by SPREAD within a run — set by the
# caller per stage. A run-1 LIGHT fire holds as a small patch (it persists, but
# does NOT creep across the whole floor within the run); the escalation to a
# floor-wide blaze happens across RUNS, not within one. Default = effectively off
# (raw sim / tests spread freely).
var spread_cap: int = 1000000
var _acc: float = 0.0
var _t: float = 0.0               # render clock (flicker only)


func _ready() -> void:
	z_index = 1
	cell_count = int((FIRE_MAX_X - FIRE_MIN_X) / CELL_W) + 1
	heat.resize(cell_count)
	fuel.resize(cell_count)
	for i in range(cell_count):
		heat[i] = 0.0
		fuel[i] = 1.0
	_load_fire_textures()
	_spawn_layers()
	add_to_group("fire_field")


# --- geometry ---------------------------------------------------------------

func cell_at(x: float) -> int:
	return clampi(int((x - FIRE_MIN_X) / CELL_W), 0, cell_count - 1)


func cell_x(i: int) -> float:
	return FIRE_MIN_X + (float(i) + 0.5) * CELL_W


func state_of(i: int) -> int:
	if i < 0 or i >= cell_count:
		return COOL
	if fuel[i] <= 0.0:
		return SPENT
	if heat[i] >= IGNITE_THRESHOLD:
		return BURNING
	return COOL


# --- ignition / control -----------------------------------------------------

func ignite_span(x0: float, x1: float) -> void:
	# Light the cells between x0 and x1 (the seed of the fire — a stairwell, say).
	var a := cell_at(minf(x0, x1))
	var b := cell_at(maxf(x0, x1))
	for i in range(a, b + 1):
		if fuel[i] > 0.0:
			heat[i] = MAX_HEAT


func char_all() -> void:
	# Run-3 "charred ruin": the floor already burnt out — no active fire, no fuel.
	for i in range(cell_count):
		heat[i] = 0.0
		fuel[i] = 0.0


func extinguish_at(x: float, radius: float) -> void:
	# A blast of extinguisher: kill the heat AND wet the fuel (fuel->0) so those
	# cells are OUT, not merely cooled — they can't re-ignite from a neighbour.
	var a := cell_at(x - radius)
	var b := cell_at(x + radius)
	for i in range(a, b + 1):
		heat[i] = 0.0
		fuel[i] = 0.0


func is_burning_at(x: float) -> bool:
	return state_of(cell_at(x)) == BURNING


func any_burning() -> bool:
	for i in range(cell_count):
		if state_of(i) == BURNING:
			return true
	return false


func export_state() -> Array:
	# A snapshot of every cell's state (0 cool / 1 burning / 2 spent) so the fire's
	# SPREAD survives leaving and re-entering the floor (see WorldState.fire_cells).
	var out: Array = []
	out.resize(cell_count)
	for i in range(cell_count):
		out[i] = state_of(i)
	return out


func import_state(states: Array) -> void:
	# Restore a snapshot: burning cells re-lit, doused/charred cells stay out.
	for i in range(mini(states.size(), cell_count)):
		match int(states[i]):
			BURNING:
				heat[i] = MAX_HEAT
				fuel[i] = 1.0
			SPENT:
				heat[i] = 0.0
				fuel[i] = 0.0
			_:
				heat[i] = 0.0
				fuel[i] = 1.0


func burning_count() -> int:
	var n := 0
	for i in range(cell_count):
		if state_of(i) == BURNING:
			n += 1
	return n


# --- smoke (choking layer; crouch under it) ---------------------------------

func _smoke_col(i: int) -> bool:
	# A column carries choking smoke if a burning cell is within the drift margin
	# (smoke billows wider than the flames themselves).
	for d in range(-SMOKE_MARGIN_CELLS, SMOKE_MARGIN_CELLS + 1):
		var j := i + d
		if j >= 0 and j < cell_count and state_of(j) == BURNING:
			return true
	return false


func smoke_at(x: float) -> bool:
	# Is there choking smoke in this column right now? (Gameplay reads this; the
	# STANDING/crouch decision + the LIGHT-is-harmless rule live in building_floors.)
	return _smoke_col(cell_at(x))


func smoke_intensity() -> float:
	# 0..1 — how THICK the smoke is. Scales with how much of the floor is burning
	# AND the stage, so a small fire barely smokes but a floor-wide one is choking
	# even at the LIGHT stage (smoke builds as the fire grows / you ignore it).
	if cell_count == 0:
		return 0.0
	var frac := float(burning_count()) / float(cell_count)
	return clampf(frac * (1.6 + float(stage) * 1.3), 0.0, 1.0)


func smoke_bottom_y() -> float:
	# How low the smoke hangs (render + reference): a LIGHT fire's smoke hugs the
	# ceiling; a BLAZE's sinks to head height.
	return SMOKE_BOTTOM_BLAZE if stage >= STAGE_BLAZE else SMOKE_BOTTOM_LIGHT


func flame_scale() -> float:
	# Flames are only BIG on a run-2+ BLAZE; a run-1 LIGHT fire stays small.
	return 1.9 if stage >= STAGE_BLAZE else 1.0


# --- simulation -------------------------------------------------------------

func _spread_mult(i: int) -> float:
	# Per-cell "terrain": how readily this cell CATCHES fire from a neighbour.
	# Deterministic (RNG-free) so the sim stays testable, but varied per cell (and
	# per floor) so the front is ragged — low cells resist and hold the fire back,
	# high cells take fast. Range ~[0.85, 1.8].
	var h := fmod(absf(sin(float(i + 1) * 12.9898 + float(floor_num) * 3.137) * 43758.5453), 1.0)
	return 0.9 + 0.6 * h              # ~[0.9, 1.5]: slowest cells ~100s, fastest ~8s


func tick(dt: float) -> void:
	# One deterministic spread step. Burning cells push heat outward (scaled by the
	# NEIGHBOUR's catch factor, so the front is uneven); cool cells bleed heat off.
	# Neighbour heat is written to a copy so the step doesn't cascade within a tick.
	var new_heat := heat.duplicate()
	# Once the fire has reached its cap, it stops CREEPING (but keeps burning — it
	# doesn't go out). This is what keeps a run-1 patch contained.
	var can_spread := burning_count() < spread_cap
	for i in range(cell_count):
		match state_of(i):
			BURNING:
				fuel[i] = maxf(fuel[i] - BURN_RATE * dt, 0.0)
				if can_spread:
					var push := SPREAD_RATE * dt
					if i > 0 and fuel[i - 1] > 0.0:
						new_heat[i - 1] = minf(new_heat[i - 1] + push * _spread_mult(i - 1), MAX_HEAT)
					if i < cell_count - 1 and fuel[i + 1] > 0.0:
						new_heat[i + 1] = minf(new_heat[i + 1] + push * _spread_mult(i + 1), MAX_HEAT)
			COOL:
				new_heat[i] = maxf(new_heat[i] - COOL_RATE * dt, 0.0)
	heat = new_heat


func _process(delta: float) -> void:
	_t += delta
	_acc += delta
	while _acc >= SIM_DT:
		_acc -= SIM_DT
		tick(SIM_DT)
	queue_redraw()


# --- render (layered pixel flames + additive glow + choking smoke) ----------
# The fire draws across FOUR CanvasItems so the player stands INSIDE it:
#   z0  back-wall flames (dim, small — depth behind the actors)
#   z1  the field itself: the main flames at floor level (with the actors)
#   z2  an ADDITIVE glow + foreground licks (this is what makes it POP)
#   z4  smoke, pooling from the ceiling down (choking — crouch under it)
# Flames scale with the stage (small on a LIGHT fire, big on a BLAZE); smoke
# sinks to head height on a BLAZE. The flicker is cosmetic; the sim is elsewhere.

# Real pixel-fire SPRITES (craftpix "Fire_tiles" — an artist-drawn animated fire
# tile, seamlessly tileable across the corridor). The tile is 32x32 per frame, 6
# frames across the sheet; four variants for horizontal variety. "Flame" (also 6x
# 32x32) gives taller single flames for the big licks on a BLAZE.
const TILE_PX := 32
const BONFIRE_PX := 64              # "1 Fire" frame size (big bonfire flame)
const TILE_FRAMES := 6
const TILE_FPS := 12.0
const CHAR_COL := Color(0.09, 0.08, 0.08)
const FIRE_LAYER := preload("res://scripts/fire_layer.gd")
var _tile_tex: Array = []           # Fire_tiles variants (folder 2) — the floor bed
var _flame_tex: Array = []          # Flame variants (folder 3) — mid single flames
var _bonfire_tex: Texture2D = null  # 1 Fire/Idle (folder 1) — big tall bonfire


func _load_fire_textures() -> void:
	var base := "res://assets/fire-pixel-art-animation-sprites/"
	for n in ["1", "2", "3", "4"]:
		var t = load(base + "2 Fire_tiles/" + n + ".png")
		if t != null:
			_tile_tex.append(t)
		var fl = load(base + "3 Flame/" + n + ".png")
		if fl != null:
			_flame_tex.append(fl)
	_bonfire_tex = load(base + "1 Fire/Idle.png")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # crisp pixels, no blur


func _spawn_layers() -> void:
	# Extra draw surfaces at fixed absolute z so the player stands INSIDE the fire:
	# the ground fire is drawn dim BEHIND the actors (z0) and, partial, IN FRONT of
	# their feet (z2). Each just calls back into draw_layer(). Nearest filtering so
	# the pixel art stays crisp.
	for spec in [[LYR_BACK, 0], [LYR_FRONT, 2], [LYR_SMOKE, 4]]:
		var lyr = FIRE_LAYER.new()
		lyr.field = self
		lyr.layer = int(spec[0])
		lyr.z_as_relative = false
		lyr.z_index = int(spec[1])
		lyr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(lyr)


func draw_layer(canvas: CanvasItem, which: int) -> void:
	match which:
		LYR_BACK: _draw_back(canvas)
		LYR_FRONT: _draw_front(canvas)
		LYR_SMOKE: _draw_smoke(canvas)


func _hash01(a: float) -> float:
	# Cheap deterministic pseudo-random in [0,1) for organic (non-uniform) jitter.
	return fmod(absf(sin(a * 12.9898) * 43758.5453), 1.0)


func _tile_scale() -> float:
	# The fire tile is small (32px); scale it up — modest on a LIGHT fire, big on a
	# run-2+ BLAZE.
	return 2.7 if stage >= STAGE_BLAZE else 1.6


func _variant_for(pool_size: int, salt: float) -> int:
	# A stable tile/flame variant per floor (so a floor's fire looks consistent, and
	# different floors differ).
	if pool_size <= 0:
		return 0
	return int(_hash01(float(floor_num) + salt) * float(pool_size)) % pool_size


# Patchy fire: real fire clumps — some here, some there — never a solid unbroken
# line. A low-frequency seeded mask turns the bed on/off in runs ~PATCH_CLUMP wide;
# a different `salt` per layer means the front bed, back bed and tall flames gap in
# DIFFERENT places, so the whole thing reads as scattered clumps of fire.
const PATCH_CLUMP := 92.0


func _patch_on(x: float, salt: float) -> bool:
	# A run-1 LIGHT outbreak carves up HARDER (more gaps) so it reads as a scattered
	# breakout, not a lengthy strip; a full BLAZE is denser.
	var thresh := 0.46 if stage < STAGE_BLAZE else 0.36
	return _hash01(floori(x / PATCH_CLUMP) * 3.17 + salt + float(floor_num) * 0.7) > thresh


func _draw_ground_fire(canvas: CanvasItem, base_y: float, alpha: float, y_off: float, bottom_frac: float = 1.0, sc_override: float = -1.0, patch_salt: float = -1.0) -> void:
	# Blit the animated fire TILE across the whole burning span, its bottom on the
	# floor line. The tile tiles seamlessly (uniform frame across columns; the art
	# tiles cleanly with itself, and the big flames on top break any repetition).
	# `bottom_frac` < 1 draws only the LOW part of the tile — used for the FRONT layer
	# so only the hottest flames lap the player's feet instead of burying their legs.
	# `sc_override` > 0 forces a scale (the smaller BACK bed at the wall seam uses it).
	if _tile_tex.is_empty():
		return
	var tex: Texture2D = _tile_tex[_variant_for(_tile_tex.size(), 3.1)]
	var sc := _tile_scale() if sc_override <= 0.0 else sc_override
	var tw := float(TILE_PX) * sc
	var bf := clampf(bottom_frac, 0.05, 1.0)
	var src_h := float(TILE_PX) * bf
	var src_y := float(TILE_PX) - src_h                          # crop to the bottom band
	var th := src_h * sc
	var fr := int(_t * TILE_FPS) % TILE_FRAMES
	var src := Rect2(float(fr * TILE_PX), src_y, float(TILE_PX), src_h)
	var x := FIRE_MIN_X
	while x <= FIRE_MAX_X:
		if is_burning_at(x + tw * 0.5) and (patch_salt < 0.0 or _patch_on(x, patch_salt)):
			var dst := Rect2(x, base_y - th + y_off, tw + 1.0, th)
			canvas.draw_texture_rect_region(tex, dst, src, Color(1.0, 1.0, 1.0, alpha))
		x += tw


func _blit_anim(canvas: CanvasItem, tex: Texture2D, px: int, cx: float, base_y: float, sc: float, col: int, seed: float, alpha: float) -> void:
	# Blit one frame of an animated flame sheet (px-square frames, 6 across), centred
	# on cx with its base on base_y. Per-flame frame offset so they dance out of sync.
	var fr := (int(_t * TILE_FPS) + col * 2) % TILE_FRAMES
	var src := Rect2(float(fr * px), 0.0, float(px), float(px))
	var w := float(px) * sc
	var h := float(px) * sc
	var jx := (_hash01(seed * 2.1) - 0.5) * 26.0
	var dst := Rect2(cx + jx - w * 0.5, base_y - h, w, h)
	canvas.draw_texture_rect_region(tex, dst, src, Color(1.0, 1.0, 1.0, alpha))


func _draw_tall_flames(canvas: CanvasItem) -> void:
	# TALLER flames rising at intervals, drawn BEHIND the player (depth). VARIED SIZES
	# repeated along the whole fire — small + medium "3 Flame" (folder 3) globs with an
	# occasional big "1 Fire" bonfire (folder 1) — so the hazard reads as clumps of
	# fire of different sizes, not one lone glob by the door. Bigger/denser on a BLAZE;
	# on a run-1 LIGHT the big bonfire is rare and everything is smaller.
	if _flame_tex.is_empty():
		return
	var big := stage >= STAGE_BLAZE
	var step := 60.0 if big else 82.0
	var col := 0
	var x := FIRE_MIN_X + 18.0
	while x <= FIRE_MAX_X:
		if is_burning_at(x) and _patch_on(x, 3.0):       # clump the tall flames too — not every spot
			var seed := float(floori(x / step)) + float(floor_num) * 0.7
			var roll := _hash01(seed * 1.9)              # size class for this glob
			var tex3: Texture2D = _flame_tex[int(_hash01(seed * 1.3) * float(_flame_tex.size())) % _flame_tex.size()]
			if roll > (0.78 if big else 0.87) and _bonfire_tex != null:
				_blit_anim(canvas, _bonfire_tex, BONFIRE_PX, x, FIRE_BASE_Y, 1.7 if big else 1.1, col, seed, 1.0)   # BIG glob
			elif roll > 0.45:
				_blit_anim(canvas, tex3, TILE_PX, x, FIRE_BASE_Y, 2.6 if big else 1.9, col, seed, 1.0)             # MEDIUM
			else:
				_blit_anim(canvas, tex3, TILE_PX, x, FIRE_BASE_Y, 1.7 if big else 1.15, col, seed, 1.0)            # SMALL
		x += step
		col += 1


func _char_scar(canvas: CanvasItem, i: int, cx: float) -> void:
	# An irregular charred patch (overlapping blobs, not a clean rect).
	for k in range(3):
		var hx := _hash01(float(i) * 2.0 + float(k) * 1.3)
		canvas.draw_circle(Vector2(cx + (hx - 0.5) * CELL_W * 0.85, FIRE_BASE_Y - 1.0 + hx * 3.0), 4.0 + hx * 3.5, CHAR_COL)


func _draw() -> void:
	# The field itself (z1) only marks char scars where the fire burnt out; the fire
	# sprites are drawn on the depth layers so the player sits amongst them.
	for i in range(cell_count):
		if state_of(i) == SPENT:
			_char_scar(self, i, cell_x(i))


# The floor-to-wall seam sits a little above the front floor line; a smaller fire
# bed runs along it BEHIND the player, so the fire recedes toward the back wall
# (depth). This offset places it ON the seam — tune if the wall art moves.
const BACK_SEAM_Y := FIRE_BASE_Y - 6.0


func _draw_back(canvas: CanvasItem) -> void:
	# BEHIND the actors (z0):
	#  1) a SMALLER, PATCHY tile bed running along the floor-to-wall SEAM, so the fire
	#     recedes back toward the wall, not just along the front edge — depth.
	#  2) the TALL flames (varied bonfires + mid flames) rising above the player.
	# The player walks in FRONT of all of this. The FULL floor bed is drawn once, in
	# front (below) — not here — so there's no doubling. Different patch salt from the
	# front bed so the gaps don't line up.
	_draw_ground_fire(canvas, BACK_SEAM_Y, 0.9, 0.0, 0.6, _tile_scale() * 0.58, 7.0)
	_draw_tall_flames(canvas)
	_draw_scatter_bits(canvas)


func _draw_scatter_bits(canvas: CanvasItem) -> void:
	# Pepper small RESIZED fragments of fire around the outbreak — bonfire bits
	# (folder 1) and tile chunks (folder 2) — some on the floor, a few up on the wall,
	# to break up the strip and make the breakout look scattered/organic. Behind the
	# player (z0). Seeded, so they're stable per floor.
	if _tile_tex.is_empty() and _bonfire_tex == null:
		return
	var span0 := FIRE_MAX_X
	var span1 := FIRE_MIN_X
	for i in range(cell_count):
		if state_of(i) == BURNING:
			span0 = minf(span0, cell_x(i))
			span1 = maxf(span1, cell_x(i))
	if span1 < span0:
		return
	var n := 9 if stage >= STAGE_BLAZE else 6
	for k in range(n):
		var seed := float(k) * 7.31 + float(floor_num) * 1.9
		var x := lerpf(span0 - 24.0, span1 + 24.0, _hash01(seed * 1.1))
		# Keep bits LOW — near the floor and only creeping a little way up the wall — so
		# they complement the outbreak without floating in mid-air at head height.
		var up := _hash01(seed * 2.7)
		var y := FIRE_BASE_Y - up * up * 40.0
		if _bonfire_tex != null and _hash01(seed * 3.3) > 0.5:
			_blit_anim(canvas, _bonfire_tex, BONFIRE_PX, x, y, 0.38 + 0.32 * _hash01(seed * 4.1), k, seed, 0.9)
		else:
			var tex: Texture2D = _tile_tex[int(_hash01(seed * 5.3) * float(_tile_tex.size())) % _tile_tex.size()]
			_blit_anim(canvas, tex, TILE_PX, x, y, 0.7 + 0.6 * _hash01(seed * 6.1), k, seed, 0.9)


func _draw_front(canvas: CanvasItem) -> void:
	# IN FRONT of the actors (z2): the floor fire bed, drawn ONCE, up to about waist
	# height, so the player is engulfed to the legs and walks THROUGH it (fire lower
	# than the player reads in front). Torso/head stay above it. A fixed pixel height
	# (not a tile fraction) keeps the engulf consistent across stage scales.
	var sc := _tile_scale()
	var target_h := 34.0 if stage >= STAGE_BLAZE else 26.0    # feet-to-waist, not to the neck
	var bf := clampf(target_h / (float(TILE_PX) * sc), 0.06, 1.0)
	_draw_ground_fire(canvas, FIRE_BASE_Y, 1.0, 0.0, bf, -1.0, 0.0)   # patchy (salt 0)


func _draw_smoke(canvas: CanvasItem) -> void:
	# SMOKE layer (z4, on top). A BLAZE puts up a THICK, oppressive bank of smoke —
	# a dense churning mass of heavily-overlapping dark blobs, near-opaque low and
	# only thinning toward the ceiling (crouch under it to see; the screen fog is
	# separate). A LIGHT fire only gives thin pale wisps hugging the ceiling.
	if stage >= STAGE_CHARRED:
		return
	var intensity := smoke_intensity()
	if intensity < 0.05:
		return
	# One smoke model, density scaled CONTINUOUSLY by intensity (no threshold snap
	# from "nothing" to "wall of smoke"). It also HANGS HIGHER when the fire is
	# small and only creeps down toward head height as it grows — always leaving a
	# breathable band at the floor to crouch into.
	for i in range(cell_count):
		if _smoke_col(i):
			_smoke_bank(canvas, cell_x(i), i, intensity)


# The smoke never comes below this — a breathable band at the floor for crouching.
const SMOKE_FLOOR_Y := FIRE_BASE_Y - 90.0


func _smoke_bank(canvas: CanvasItem, cx: float, i: int, intensity: float) -> void:
	# A column of churning smoke: rows of big overlapping dark blobs reading as one
	# roiling mass. DENSITY and how LOW it hangs both scale with `intensity`, so a
	# small fire is a faint high haze and a floor-wide one is an oppressive bank
	# down near head height (but never to the floor).
	var bottom := lerpf(CEILING_Y + 70.0, SMOKE_FLOOR_Y, clampf(intensity, 0.0, 1.0))
	var rows := 15
	for r in range(rows):
		var frac := float(r) / float(rows)                       # 0 bottom → 1 ceiling
		var y := lerpf(bottom, CEILING_Y, frac)
		var ph := float(i) * 2.3 + float(r) * 1.7
		var churn := sin(_t * 0.7 + ph) * (8.0 + frac * 30.0) + sin(_t * 0.35 + ph * 1.7) * (4.0 + frac * 14.0)
		var boil := sin(_t * 1.3 + ph * 2.1) * 3.0               # small vertical roil
		var rad := (26.0 + 16.0 * _hash01(ph)) + frac * 8.0
		var a := lerpf(0.5, 0.16, frac) * clampf(intensity * 1.25, 0.0, 1.15)   # scales from 0 (no snap)
		var shade := 0.09 + 0.05 * _hash01(ph * 1.3)
		canvas.draw_circle(Vector2(cx + churn, y + boil), rad, Color(shade, shade, shade, a))
		canvas.draw_circle(Vector2(cx + churn - rad * 0.7, y + 4.0 + boil), rad * 0.85, Color(shade, shade, shade, a * 0.9))
		canvas.draw_circle(Vector2(cx + churn + rad * 0.62, y - 3.0 + boil), rad * 0.72, Color(shade, shade, shade, a * 0.85))


func _smoke_wisps(canvas: CanvasItem, i: int, cx: float) -> void:
	# Thin pale wisps rising and fading — a LIGHT fire barely smokes.
	for p in range(2):
		var phase := _hash01(float(i) * 4.3 + float(p) * 9.1)
		var prog := fmod(_t * 0.16 + phase, 1.0)
		var y := lerpf(FIRE_BASE_Y - 14.0, CEILING_Y + 30.0, prog)
		var turb := sin(_t * 1.1 + phase * 12.0 + prog * 4.0) * (6.0 + prog * 18.0)
		var rad := lerpf(7.0, 22.0, prog)
		var a := sin(prog * PI) * 0.16
		canvas.draw_circle(Vector2(cx + turb, y), rad, Color(0.2, 0.19, 0.18, a))
