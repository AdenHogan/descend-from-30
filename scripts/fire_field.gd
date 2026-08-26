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
# Halved from 0.10/0.085 to slow the creep by ~half (5 min was covering most of the
# floor) while KEEPING the margin positive, so the spread still happens — just at
# half pace (~30s/cell for an average cell, slower for the ragged ones).
const SPREAD_RATE := 0.05         # heat/sec a burning cell pushes to each neighbour
const COOL_RATE := 0.0425         # heat/sec a non-burning cell loses
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
	# A blast of extinguisher: put out only the cells that were actually BURNING, turning
	# them SPENT (ash + smoke — the AFTERMATH marks where fire WAS, not where the spray
	# landed). A COOL cell in the blast is left untouched, so spraying bare floor leaves NO
	# fake ash/smoke. The burnt-out (SPENT) cells act as firebreaks, so the doused patch
	# can't re-ignite from a neighbour.
	var a := cell_at(x - radius)
	var b := cell_at(x + radius)
	for i in range(a, b + 1):
		if state_of(i) == BURNING:
			heat[i] = 0.0
			fuel[i] = 0.0


func is_burning_at(x: float) -> bool:
	return state_of(cell_at(x)) == BURNING


# How close (px) the player must be to a VISIBLE flame to take the burn. Tight — a
# player standing anywhere in a burning tile cell (42px wide) is within this of its
# centre, but a step off the fire is not.
const DAMAGE_REACH := 26.0


func fire_hot_at(x: float) -> bool:
	# TIGHT player-damage test (see building_floors fire damage). The SIM burns a wider,
	# GAPPIER span than the patchy RENDER shows, so is_burning_at() cooked the player while
	# they stood over a bare GAP with no visible flame. Here the burn only lands when a
	# burning cell that actually RENDERS a fire tile (kind 0/1, not a gap) sits within
	# DAMAGE_REACH of the player — i.e. they're essentially standing IN the flames.
	var c := cell_at(x)
	for i in range(maxi(c - 1, 0), mini(c + 2, cell_count)):
		if state_of(i) == BURNING and _cell_kind(cell_x(i)) != 2 and absf(cell_x(i) - x) <= DAMAGE_REACH:
			return true
	return false


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
	var spent := 0
	for i in range(cell_count):
		if state_of(i) == SPENT:
			spent += 1
	# Active fire smokes most; doused/charred (spent) ground SMOULDERS at a lower weight
	# but still hazes — so a floor you've just put out, and a fully charred ruin, stay
	# smoky rather than snapping clear.
	var frac := (float(burning_count()) + float(spent) * 0.7) / float(cell_count)
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
const SMOKE_FRAMES := 6
const SMOKE_FPS := 8.0
const CHAR_COL := Color(0.09, 0.08, 0.08)
const FIRE_LAYER := preload("res://scripts/fire_layer.gd")
var _tile_tex: Array = []           # Fire_tiles variants (folder 2) — the floor bed
var _flame_tex: Array = []          # Flame variants (folder 3) — mid single flames
var _bonfire_tex: Texture2D = null  # 1 Fire/Idle (folder 1) — big tall bonfire
var _smoke_reg: Array = []          # Cycled_smoke (128²) — a wispy plume for smaller patches
var _smoke_long: Array = []         # Cycled_smoke_long (32×129) — tall column for big patches


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
	var sm := "res://assets/smoke-effects-pixel-art/PNG/"
	for i in range(1, SMOKE_FRAMES + 1):
		var r = load(sm + "Cycled_smoke/Cycled_smoke%d.png" % i)
		if r != null:
			_smoke_reg.append(r)
		var lg = load(sm + "Cycled_smoke_long/Cycled_smoke_long%d.png" % i)
		if lg != null:
			_smoke_long.append(lg)
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


func _patch_on(x: float, salt: float, carve: float = 0.0) -> bool:
	# A run-1 LIGHT outbreak carves up HARDER (more gaps) so it reads as a scattered
	# breakout, not a lengthy strip; a full BLAZE is denser. `carve` adds extra gaps
	# for a layer that wants to be broken up more (the depth/back bed).
	var thresh := (0.46 if stage < STAGE_BLAZE else 0.36) + carve
	return _hash01(floori(x / PATCH_CLUMP) * 3.17 + salt + float(floor_num) * 0.7) > thresh


# Door x's (same on every floor — apartment01..05); the depth/back bed skips a band
# around each so it never runs straight across a doorway (beside a door is fine).
const DOOR_AVOID_HALF := 36.0


func _near_door(x: float) -> bool:
	for apt in WorldState.APARTMENT_X:
		if absf(x - float(WorldState.APARTMENT_X[apt])) < DOOR_AVOID_HALF:
			return true
	return false


# The down-stairwell has its OWN fire (the low element on the yellow step). The corridor
# fire (floor beds + tall flames + scatter) must NOT draw across the stairwell mouth, or
# its tall flames tower up over the step and it looks like fire floating above the stairs.
# This band is kept clear of corridor art so only the stair-fire element shows there.
const STAIR_KEEPOUT_HALF := 66.0


func _in_stair_keepout(cx: float) -> bool:
	return _stair_fire_x >= 0.0 and absf(cx - _stair_fire_x) < STAIR_KEEPOUT_HALF


func _cell_kind(cx: float) -> int:
	# Each burning cell renders EXACTLY ONE of three things, in ~2-cell clumps seeded per
	# floor:
	#   1 = a BACK-seam depth tile (drawn behind the player at the wall/floor seam)
	#   0 = a FRONT floor tile     (drawn in front, lapping the player's feet)
	#   2 = a GAP — NO tile at all
	# Back and front are MUTUALLY EXCLUSIVE, so the tile-set fire can never double into a
	# bloated overlap (where the depth bed draws, the front bed does not, and vice versa).
	# The GAP cells are the ONLY place GLOBS (tall flames / scatter bits) may rise — "globs
	# can generate anywhere the tile set is not actively visible" — so a glob never stacks
	# on top of a rendered tile. DOOR cells are forced to GAP so no tile bed runs across a
	# doorway; globs also skip doors (see `_is_glob_cell`), keeping doorways clear.
	if _near_door(cx):
		return 2
	var clump := floori(cx / (CELL_W * 2.0))
	var h := _hash01(float(clump) * 1.7 + float(floor_num) * 0.9)
	if h < 0.4:
		return 1
	elif h < 0.75:
		return 0
	return 2


func _is_glob_cell(cx: float) -> bool:
	# A GAP cell that isn't a doorway — the free space where globs may rise (tiles aren't
	# visible here, and we keep globs off doors so entrances stay clear).
	return _cell_kind(cx) == 2 and not _near_door(cx)


func _draw_ground_fire(canvas: CanvasItem, base_y: float, alpha: float, y_off: float, bottom_frac: float = 1.0, sc_override: float = -1.0, patch_salt: float = -1.0, avoid_doors: bool = false, patch_carve: float = 0.0, bed_side: int = -1) -> void:
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
		var cx := x + tw * 0.5
		var pass_gate := (patch_salt < 0.0 or _patch_on(x, patch_salt, patch_carve))
		if bed_side >= 0:
			pass_gate = (_cell_kind(cx) == bed_side)   # complementary back(1)/front(0)/gap(2) split
		if is_burning_at(cx) and pass_gate and not (avoid_doors and _near_door(cx)) and not _in_stair_keepout(cx):
			var dst := Rect2(x, base_y - th + y_off, tw + 1.0, th)
			canvas.draw_texture_rect_region(tex, dst, src, Color(1.0, 1.0, 1.0, alpha))
		x += tw


func _blit_anim(canvas: CanvasItem, tex: Texture2D, px: int, cx: float, base_y: float, sc: float, col: int, sd: float, alpha: float) -> void:
	# Blit one frame of an animated flame sheet (px-square frames, 6 across), centred
	# on cx with its base on base_y. Per-flame frame offset so they dance out of sync.
	var fr := (int(_t * TILE_FPS) + col * 2) % TILE_FRAMES
	var src := Rect2(float(fr * px), 0.0, float(px), float(px))
	var w := float(px) * sc
	var h := float(px) * sc
	var jx := (_hash01(sd * 2.1) - 0.5) * 10.0   # small wobble only — must not close the MIN_GAP
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
	# Scan finely, but only PLACE a flame when it clears MIN_GAP from the last one — so
	# globs read as DISTINCT tongues rising off the bed, never piling into one blob. The
	# gap is >= the widest glob below, so no overlap on any seed. The continuous ground
	# bed carries the fire's fullness; these are spaced accents.
	var scan := 24.0
	var min_gap := 108.0 if big else 104.0     # clear air between neighbours (globs are small now)
	var col := 0
	var last_x := -1.0e9
	var x := FIRE_MIN_X + 18.0
	while x <= FIRE_MAX_X:
		if is_burning_at(x) and _is_glob_cell(x) and not _in_stair_keepout(x) and (x - last_x) >= min_gap:
			var sd := float(floori(x / min_gap)) + float(floor_num) * 0.7
			var roll := _hash01(sd * 1.9)              # size class for this glob
			var tex3: Texture2D = _flame_tex[int(_hash01(sd * 1.3) * float(_flame_tex.size())) % _flame_tex.size()]
			if roll > (0.82 if big else 0.92) and _bonfire_tex != null:
				_blit_anim(canvas, _bonfire_tex, BONFIRE_PX, x, FIRE_BASE_Y, 1.2 if big else 0.95, col, sd, 1.0)   # BIG glob (<= ~77px)
			elif roll > 0.5:
				_blit_anim(canvas, tex3, TILE_PX, x, FIRE_BASE_Y, 1.75 if big else 1.4, col, sd, 1.0)             # MEDIUM (<= ~56px)
			else:
				_blit_anim(canvas, tex3, TILE_PX, x, FIRE_BASE_Y, 1.25 if big else 1.0, col, sd, 1.0)             # SMALL
			last_x = x
		x += scan
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
const BACK_SEAM_Y := FIRE_BASE_Y - 22.0   # the wall/floor seam (door base ~404; feet ~419)


func _draw_back(canvas: CanvasItem) -> void:
	# BEHIND the actors (z0):
	#  1) a SMALLER, PATCHY tile bed running along the floor-to-wall SEAM, so the fire
	#     recedes back toward the wall, not just along the front edge — depth.
	#  2) the TALL flames (varied bonfires + mid flames) rising above the player.
	# The player walks in FRONT of all of this. The FULL floor bed is drawn once, in
	# front (below) — not here — so there's no doubling. Different patch salt from the
	# front bed so the gaps don't line up.
	# avoid_doors=true keeps the depth bed OUT of doorways (beside a door is fine, not
	# straight across it); the extra patch_carve breaks up its line into clumps.
	_draw_ground_fire(canvas, BACK_SEAM_Y, 0.9, 0.0, 0.6, _tile_scale() * 0.58, -1.0, true, 0.0, 1)   # DEPTH bed (side 1), avoids doors
	_draw_stair_fire(canvas)        # the THIRD plane — fire on the down-stairwell top step
	_draw_tall_flames(canvas)
	_draw_smoulder_plumes(canvas)   # aftermath smoke (doused + charred), behind the active-fire smoke
	_draw_smoke_plumes(canvas)


# --- the third plane: fire on the DOWN stairwell -------------------------------
# building_floors hands us the x of the down-stairwell's top step; we draw a small
# bed + flame there, at the STEP's Y (above the corridor floor line), so the fire
# reads as spilling onto the stairs themselves. Only while the floor still has live
# fire (a doused/charred floor shows none). -1 = no stair fire on this floor.
var _stair_fire_x: float = -1.0
# The DOWN-stairwell's own Y plane: the TOP of the yellow step, INSIDE the shaft (~y386),
# NOT the floor/wall seam below it and NOT floating higher up the shaft. The fire's body is
# centred on this line so it reads as fire on the actual stairs. This is a SEPARATE plane
# from the corridor beds (BACK_SEAM_Y / FIRE_BASE_Y).
const STAIR_STEP_Y := 386.0        # TOP of the yellow step (the owner's red line) — the CAP
const STAIR_STEP_BOTTOM := 401.0   # bottom of the yellow step block (fire sits ON this)


func set_stair_fire(x: float) -> void:
	_stair_fire_x = x


func _draw_stair_fire(canvas: CanvasItem) -> void:
	# Fire sitting ON the yellow step: it fills the step block (STAIR_STEP_BOTTOM up to the
	# step line) and its flames are CAPPED so their tops land at the yellow line — never
	# above it, never up the shaft. The corridor fire is kept out of this band entirely
	# (see _in_stair_keepout), so this compact fire is the ONLY fire on the stairs.
	if _stair_fire_x < 0.0 or _tile_tex.is_empty() or not any_burning():
		return
	var sc := _tile_scale() * 0.5
	var tw := float(TILE_PX) * sc
	var fr := int(_t * TILE_FPS) % TILE_FRAMES
	var tex: Texture2D = _tile_tex[_variant_for(_tile_tex.size(), 4.7)]
	# the bed sits on the step block and its TOP is clamped to the yellow line
	var bed_h: float = STAIR_STEP_BOTTOM - STAIR_STEP_Y            # exactly the step's height
	for k in range(2):
		var cx := _stair_fire_x + (float(k) - 0.5) * tw * 0.75    # two tiles = one bed across the step
		var src := Rect2(float(fr * TILE_PX), float(TILE_PX) * 0.55, float(TILE_PX), float(TILE_PX) * 0.45)
		canvas.draw_texture_rect_region(tex, Rect2(cx - tw * 0.5, STAIR_STEP_Y, tw + 1.0, bed_h), src, Color(1.0, 1.0, 1.0, 0.97))
	# flame tongues whose TOPS are clamped to the yellow line (base on the step block bottom).
	# We size each flame so base − height == STAIR_STEP_Y, i.e. it never pokes above the line.
	if not _flame_tex.is_empty():
		var fh: float = STAIR_STEP_BOTTOM - STAIR_STEP_Y          # top lands exactly on the yellow line
		var fsc: float = fh / float(TILE_PX)
		_blit_anim(canvas, _flame_tex[_variant_for(_flame_tex.size(), 2.3)], TILE_PX, _stair_fire_x - tw * 0.28, STAIR_STEP_BOTTOM, fsc, 1, 4.4, 1.0)
		_blit_anim(canvas, _flame_tex[_variant_for(_flame_tex.size(), 5.1)], TILE_PX, _stair_fire_x + tw * 0.28, STAIR_STEP_BOTTOM, fsc, 2, 7.9, 1.0)


# --- smoke plumes (real smoke-sprite loops rising off the fire) ----------------
# Scan the corridor in FIXED zones; the zones with the MOST fire smoke, each plume
# EMBEDDED at the centroid of that zone's burning cells (so it rises from ON the fire,
# never stuck to a bare patch of wall). The TYPE is fixed by STAGE — a LIGHT fire's
# smoke is always the small `Cycled_smoke` wisp, a BLAZE's always the `Cycled_smoke_long`
# column — so a plume is a DISTINCT thing and never morphs short↔long. Height varies a
# little per zone (stable seed), and the long column is kept short enough to clear the
# ceiling. Drawn BEHIND the player (z0) so it rises up the wall.
const SMOKE_ZONE_W := 180.0        # scan the span in fixed zones this wide (~4 cells)
const SMOKE_ZONE_MIN := 3          # a zone with a few burning cells smokes (more visible stacks)


func _smoke_zones() -> Array:
	# Eligible zones (enough fire), each with the CENTROID of its burning cells (= the x to
	# rise from), sorted biggest-fire first. Shared by the depth + foreground smoke passes.
	var zones: Array = []
	var zi := 0
	var zx := FIRE_MIN_X + SMOKE_ZONE_W * 0.5
	while zx < FIRE_MAX_X:
		var ca := cell_at(zx - SMOKE_ZONE_W * 0.5)
		var cb := cell_at(zx + SMOKE_ZONE_W * 0.5)
		var burn := 0
		var sumx := 0.0
		for i in range(ca, cb + 1):
			if state_of(i) == BURNING:
				burn += 1
				sumx += cell_x(i)
		if burn >= SMOKE_ZONE_MIN:
			zones.append({"i": zi, "burn": burn, "cx": sumx / float(burn), "zx": zx})
		zx += SMOKE_ZONE_W
		zi += 1
	zones.sort_custom(func(a, b): return int(a["burn"]) > int(b["burn"]))
	return zones


func _draw_smoke_plumes(canvas: CanvasItem) -> void:
	# DEPTH smoke: plumes rising off the fire up the wall, BEHIND the player (z0). Bumped a
	# couple higher so the burning corridor clearly smokes.
	if _smoke_reg.is_empty() and _smoke_long.is_empty():
		return
	var zones := _smoke_zones()
	if zones.is_empty():
		return
	var big := stage >= STAGE_BLAZE
	var cap := mini(7 if big else 5, zones.size())      # a couple more stacks than before
	var tw := float(TILE_PX) * _tile_scale()
	var placed := 0
	var placed_xs: Array = []
	for z in zones:
		if placed >= cap:
			break
		# Snap the plume onto an actually-RENDERED front-bed tile in the zone (the fire is
		# PATCHY, so the sim centroid can sit over a gap) so smoke rises from behind a tile.
		var cx := _front_tile_near(float(z["cx"]), float(z["zx"]) - SMOKE_ZONE_W * 0.5, float(z["zx"]) + SMOKE_ZONE_W * 0.5, tw)
		if cx < 0.0:
			continue
		if _too_close(cx, placed_xs, 150.0):   # never stack plumes — a small fire clusters its zones
			continue
		placed_xs.append(cx)
		var s := float(int(z["i"])) * 5.3 + float(floor_num) * 1.7          # STABLE per zone (no morph)
		var frame := int(_t * SMOKE_FPS + s) % SMOKE_FRAMES
		if big and not _smoke_long.is_empty():
			_blit_smoke(canvas, _smoke_long[frame], 32.0, 129.0, cx, 0.55 + 0.6 * _hash01(s))
		elif not _smoke_reg.is_empty():
			# 128-wide sprite squished into a ~62px-wide dest = a thin rising WISP, not a big
			# blocky square (which read as a dark grid over a clean door).
			_blit_smoke(canvas, _smoke_reg[frame], 62.0, 122.0, cx, 0.5 + 0.42 * _hash01(s))
		placed += 1


func _draw_front_smoke(canvas: CanvasItem) -> void:
	# FOREGROUND smoke: two extra stacks rising IN FRONT of the player (z2), over the
	# nearest/biggest fire, so smoke reads in the foreground too — semi-transparent so it
	# doesn't hide the player. Placed on the LEAST-dense of the top zones so it isn't at the
	# exact x of a depth plume (foreground + depth smoke sit at different spots).
	if _smoke_reg.is_empty():
		return
	var zones := _smoke_zones()
	if zones.is_empty():
		return
	var tw := float(TILE_PX) * _tile_scale()
	var want := 2
	var placed := 0
	var placed_xs: Array = []
	# walk from the SMALLER of the qualifying zones so we don't double the biggest one
	for zi in range(zones.size() - 1, -1, -1):
		if placed >= want:
			break
		var z = zones[zi]
		var cx := _front_tile_near(float(z["cx"]), float(z["zx"]) - SMOKE_ZONE_W * 0.5, float(z["zx"]) + SMOKE_ZONE_W * 0.5, tw)
		if cx < 0.0:
			continue
		if _too_close(cx, placed_xs, 170.0):   # keep foreground stacks apart (no dark pile-up)
			continue
		placed_xs.append(cx)
		var s := float(int(z["i"])) * 3.1 + float(floor_num) * 2.3
		var frame := int(_t * SMOKE_FPS + s) % SMOKE_FRAMES
		var h := 122.0 * (0.5 + 0.3 * _hash01(s))
		var w := h * 0.5                                 # thin rising wisp, not a square blob
		canvas.draw_texture_rect(_smoke_reg[frame], Rect2(cx - w * 0.5, FIRE_BASE_Y - 2.0 - h, w, h), false, Color(1.0, 1.0, 1.0, 0.42))
		placed += 1


func _too_close(x: float, xs: Array, gap: float) -> bool:
	for px in xs:
		if absf(float(px) - x) < gap:
			return true
	return false


func has_smoulder() -> bool:
	# True if any cell is a doused/charred (SPENT) ruin — i.e. there's smoke to show
	# even though nothing is actively BURNING. Drives the HUD haze on a charred floor.
	for i in range(cell_count):
		if state_of(i) == SPENT:
			return true
	return false


func _draw_smoulder_plumes(canvas: CanvasItem) -> void:
	# Smoke rising from DOUSED / CHARRED (spent) ground — the AFTERMATH of fire. Greyer,
	# thinner and more numerous than active-fire smoke, so a stretch you've just put out
	# (and a fully charred ruin) SMOULDERS heavily instead of leaving bare scorch marks.
	if _smoke_reg.is_empty():
		return
	var i := 0
	while i < cell_count:
		if state_of(i) == SPENT:
			var s := float(i) * 3.7 + float(floor_num) * 1.9
			if _hash01(s) < 0.72:                      # a plume on most spent cells, with gaps
				var cx := cell_x(i)
				var frame := int(_t * SMOKE_FPS + s) % SMOKE_FRAMES
				_blit_smoulder(canvas, _smoke_reg[frame], cx, 0.44 + 0.36 * _hash01(s * 1.7))
			i += 2                                      # step so plumes don't stack every cell
		else:
			i += 1


func _blit_smoulder(canvas: CanvasItem, tex: Texture2D, cx: float, sc: float) -> void:
	if tex == null:
		return
	var w := 128.0 * sc
	var h := 128.0 * sc
	var base_y := FIRE_BASE_Y - 6.0                    # rises off the scorched floor
	# grey + semi-transparent: smoulder, not a fresh fire's warm smoke
	canvas.draw_texture_rect(tex, Rect2(cx - w * 0.5, base_y - h, w, h), false, Color(0.62, 0.60, 0.58, 0.5))


func _front_tile_near(target: float, x0: float, x1: float, tw: float) -> float:
	# The x (tile centre) of the nearest RENDERED tile cell within [x0,x1] — a burning cell
	# that actually draws a tile (front OR back seam, i.e. NOT a gap), so a plume always
	# rises from BEHIND real tile-set fire and never floats over a bare gap. -1 if none.
	var best := -1.0
	var best_d := 1.0e9
	var x := FIRE_MIN_X
	while x <= FIRE_MAX_X:
		var cx := x + tw * 0.5
		if cx >= x0 and cx <= x1 and is_burning_at(cx) and _cell_kind(cx) != 2:
			var d := absf(cx - target)
			if d < best_d:
				best_d = d
				best = cx
		x += tw
	return best


func _blit_smoke(canvas: CanvasItem, tex: Texture2D, fw: float, fh: float, cx: float, sc: float) -> void:
	if tex == null:
		return
	var w := fw * sc
	var h := fh * sc
	var base_y := FIRE_BASE_Y - 14.0                       # rise from the fire bed, a touch higher for visibility but still BEHIND the front tiles (bed spans ~395..421)
	canvas.draw_texture_rect(tex, Rect2(cx - w * 0.5, base_y - h, w, h), false, Color(1.0, 1.0, 1.0, 0.72))


func _draw_scatter_bits(canvas: CanvasItem) -> void:
	# Pepper small RESIZED fragments of fire around the outbreak — bonfire bits
	# (folder 1) and tile chunks (folder 2) — to break up the strip and make the
	# breakout look scattered/organic. They sit ON THE FLOOR (a touch lower than the
	# main bed) and IN FRONT of the player (z2), so the player walks BEHIND them — NOT
	# floating up on the wall. Seeded, so they're stable per floor.
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
	# Walk the burning span in fixed SLOTS and drop at most one small bit per slot (with a
	# little in-slot jitter), so the fragments are SPACED — density scales with the fire's
	# width and they never clump on top of each other, on any seed or fire size.
	var slot := 128.0 if stage >= STAGE_BLAZE else 145.0   # spaced front bits — accents, not a second fire
	var col := 0
	var x := span0
	while x <= span1 + 12.0:
		var sd := float(col) * 7.31 + float(floor_num) * 1.9
		var bx := x + (_hash01(sd * 1.1) - 0.5) * slot * 0.5   # jitter within the slot (< slot/2)
		col += 1
		x += slot
		# ONLY over an actually-burning GAP cell — a bit vanishes the moment its cell is out
		# (they used to strew across the whole span, stranding wisps on doused ground), and
		# it only sits where the tile bed ISN'T drawn, so a glob never overlaps a front tile.
		if not is_burning_at(bx) or not _is_glob_cell(bx) or _in_stair_keepout(bx):
			continue
		# On the floor, a little LOWER than the main bed (nearer the camera), never up
		# the wall — a small spread of extra flames the player walks behind.
		var y := FIRE_BASE_Y - 6.0 + 6.0 * _hash01(sd * 2.7)   # lifted a fraction off the UI (still below the player)
		if _bonfire_tex != null and _hash01(sd * 3.3) > 0.5:
			_blit_anim(canvas, _bonfire_tex, BONFIRE_PX, bx, y, 0.38 + 0.30 * _hash01(sd * 4.1), col, sd, 0.9)
		else:
			var tex: Texture2D = _tile_tex[int(_hash01(sd * 5.3) * float(_tile_tex.size())) % _tile_tex.size()]
			_blit_anim(canvas, tex, TILE_PX, bx, y, 0.7 + 0.5 * _hash01(sd * 6.1), col, sd, 0.9)


func _draw_front(canvas: CanvasItem) -> void:
	# IN FRONT of the actors (z2): the floor fire bed, drawn ONCE, up to about waist
	# height, so the player is engulfed to the legs and walks THROUGH it (fire lower
	# than the player reads in front). Torso/head stay above it. A fixed pixel height
	# (not a tile fraction) keeps the engulf consistent across stage scales. The
	# scattered floor globs also go here (in front, on the floor — player walks behind).
	var sc := _tile_scale()
	var target_h := 34.0 if stage >= STAGE_BLAZE else 26.0    # feet-to-waist, not to the neck
	var bf := clampf(target_h / (float(TILE_PX) * sc), 0.06, 1.0)
	_draw_ground_fire(canvas, FIRE_BASE_Y, 1.0, -5.0, bf, -1.0, -1.0, true, 0.0, 0)   # FRONT bed (side 0), complementary to the depth bed, also avoids doors
	_draw_scatter_bits(canvas)
	_draw_front_smoke(canvas)     # a couple foreground smoke stacks (in front of the player)


func _draw_smoke(_canvas: CanvasItem) -> void:
	# World-space smoke clouds have been REMOVED (they read as black pulsing circles).
	# The only smoke effect now is a subtle gradual screen HAZE driven by the HUD from
	# smoke_intensity() (see building_floors._process / HUD.set_smoke_fog). Proper
	# smoke art will slot in here later. Left as a no-op so the z4 layer draws nothing.
	pass
