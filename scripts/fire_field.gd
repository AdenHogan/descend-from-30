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
const FIRE_BASE_Y := 430.0        # floor line the flames rise from

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
	for i in range(cell_count):
		match state_of(i):
			BURNING:
				fuel[i] = maxf(fuel[i] - BURN_RATE * dt, 0.0)
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

const ROW_H := 3.0                 # pixel-chunk height per flame row
const CHAR_COL := Color(0.09, 0.08, 0.08)
const EMBER_COL := Color(1.0, 0.80, 0.35, 0.9)
const FIRE_LAYER := preload("res://scripts/fire_layer.gd")


func _spawn_layers() -> void:
	# Extra draw surfaces at fixed absolute z so the player sits between the back
	# glow and the front licks. Each just calls back into draw_layer().
	for spec in [[LYR_BACK, 0, false], [LYR_FRONT, 2, true], [LYR_SMOKE, 4, false]]:
		var lyr = FIRE_LAYER.new()
		lyr.field = self
		lyr.layer = int(spec[0])
		lyr.z_as_relative = false
		lyr.z_index = int(spec[1])
		if bool(spec[2]):
			var mat := CanvasItemMaterial.new()
			mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD   # glow
			lyr.material = mat
		add_child(lyr)


func draw_layer(canvas: CanvasItem, which: int) -> void:
	match which:
		LYR_BACK: _draw_back(canvas)
		LYR_FRONT: _draw_front(canvas)
		LYR_SMOKE: _draw_smoke(canvas)


func _flame_color(frac: float) -> Color:
	# frac 0 = base (hottest), 1 = tip (coolest). A real flame's gradient.
	if frac < 0.12:
		return Color(1.0, 0.96, 0.78)      # white-hot core at the base
	elif frac < 0.34:
		return Color(1.0, 0.83, 0.30)      # yellow
	elif frac < 0.60:
		return Color(1.0, 0.55, 0.13)      # orange
	elif frac < 0.83:
		return Color(0.90, 0.32, 0.07)     # deep orange
	return Color(0.68, 0.15, 0.04)         # red, flickering tip


func _hash01(a: float) -> float:
	# Cheap deterministic pseudo-random in [0,1) for organic (non-uniform) jitter.
	return fmod(absf(sin(a * 12.9898) * 43758.5453), 1.0)


func _tongue(canvas: CanvasItem, cx: float, base_y: float, h: float, base_w: float, phase: float, alpha: float) -> void:
	# One tapered, leaning flame tongue rising from base_y, onto `canvas`.
	var rows := int(h / ROW_H)
	if rows < 1:
		return
	for r in range(rows):
		var frac := float(r) / float(rows)
		var w := base_w * pow(1.0 - frac, 0.7)   # taper to a point
		if w < 1.0:
			w = 1.0
		var lean := sin(_t * 6.5 + phase + frac * 3.4) * base_w * 0.4 * frac
		var y := base_y - float(r + 1) * ROW_H
		var c := _flame_color(frac)
		canvas.draw_rect(Rect2(cx + lean - w * 0.5, y, w, ROW_H + 0.5), Color(c.r, c.g, c.b, c.a * alpha))


func _flame(canvas: CanvasItem, s: int, x: float, base_y: float, sc: float, alpha: float) -> void:
	# ONE flame — its SHAPE is picked from the seed too, so the fire is a mix of
	# looks (pointed tongues, rounded blobs, curling wisps, little fireballs) rather
	# than a row of identical conical tufts.
	var kind := _hash01(float(s) * 5.9)
	if kind < 0.42:
		_flame_tongue(canvas, s, x, base_y, sc, alpha)
	elif kind < 0.68:
		_flame_round(canvas, s, x, base_y, sc, alpha)
	elif kind < 0.88:
		_flame_curl(canvas, s, x, base_y, sc, alpha)
	else:
		_flame_ball(canvas, s, x, base_y, sc, alpha)


func _flame_tongue(canvas: CanvasItem, s: int, x: float, base_y: float, sc: float, alpha: float) -> void:
	# Pointed, tapered tongues (1-3), wobbling base, leaning.
	var v2 := _hash01(float(s) * 3.3)
	var by := base_y - _hash01(float(s) * 0.9) * 3.0 + sin(_t * 2.3 + float(s)) * 1.2
	var flick := sin(_t * 8.0 + float(s) * 1.7) * 2.5 + sin(_t * 13.0 + float(s) * 0.7) * 1.5
	_tongue(canvas, x, by, (20.0 + flick) * sc, 8.0 * sc, float(s) * 1.9, alpha)
	if v2 > 0.35:
		_tongue(canvas, x - 6.5 * sc, by, (11.0 + flick) * sc, 5.0 * sc, float(s) * 2.1 + 1.0, alpha)
	if v2 > 0.72:
		_tongue(canvas, x + 7.0 * sc, by, (9.0 - flick) * sc, 4.0 * sc, float(s) * 2.7 + 2.0, alpha)


func _flame_round(canvas: CanvasItem, s: int, x: float, base_y: float, sc: float, alpha: float) -> void:
	# A bulbous, ROUNDED flame (teardrop/onion): overlapping circles that bulge low
	# and round up to a soft point, with a hot core — reads soft, not spiky.
	var flick := sin(_t * 7.0 + float(s) * 1.6) * 2.0
	var h := (20.0 + flick) * sc
	var maxw := 9.0 * sc
	for k in range(9):
		var frac := float(k) / 9.0
		var wf := sin((0.12 + frac * 0.88) * PI)        # peak in the lower-middle
		var rad := maxw * (0.45 + 0.65 * wf) * (1.0 - frac * 0.3)
		var lean := sin(_t * 5.0 + float(s) + frac * 2.0) * 3.0 * frac
		var c := _flame_color(frac)
		canvas.draw_circle(Vector2(x + lean, base_y - frac * h), maxf(rad, 1.5), Color(c.r, c.g, c.b, c.a * alpha))
	canvas.draw_circle(Vector2(x, base_y - h * 0.3), maxw * 0.5, Color(1.0, 0.95, 0.72, alpha))


func _flame_curl(canvas: CanvasItem, s: int, x: float, base_y: float, sc: float, alpha: float) -> void:
	# A thin CURLING wisp: narrow segments following a curved path that licks to one
	# side — a lighter, flickery look between the fuller flames.
	var h := (24.0 + sin(_t * 8.0 + float(s)) * 3.0) * sc
	var dirn := 1.0 if _hash01(float(s) * 2.2) > 0.5 else -1.0
	var steps := int(h / 3.0)
	for k in range(steps):
		var frac := float(k) / float(maxi(steps, 1))
		var cx := x + dirn * sin(frac * 2.4 + _t * 4.0 + float(s)) * 11.0 * sc * frac
		var w := 4.0 * sc * (1.0 - frac * 0.8)
		if w < 1.0:
			w = 1.0
		var c := _flame_color(frac)
		canvas.draw_rect(Rect2(cx - w * 0.5, base_y - float(k) * 3.0, w, 3.5), Color(c.r, c.g, c.b, c.a * alpha))


func _flame_ball(canvas: CanvasItem, s: int, x: float, base_y: float, sc: float, alpha: float) -> void:
	# A small ROUND fireball: concentric circles (red→orange→hot core), pulsing,
	# with a stubby tip so it isn't a pure disc — good for scattered flare-ups.
	var pulse := 0.85 + 0.15 * sin(_t * 6.0 + float(s))
	var y := base_y - 8.0 * sc
	var r := 8.5 * sc * pulse
	canvas.draw_circle(Vector2(x, y), r * 1.15, Color(0.8, 0.2, 0.05, 0.7 * alpha))
	canvas.draw_circle(Vector2(x, y), r * 0.8, Color(1.0, 0.5, 0.12, 0.85 * alpha))
	canvas.draw_circle(Vector2(x, y), r * 0.45, Color(1.0, 0.9, 0.5, alpha))
	var c := _flame_color(0.4)
	canvas.draw_rect(Rect2(x - 2.0 * sc, y - r - 5.0 * sc, 4.0 * sc, 7.0 * sc), Color(c.r, c.g, c.b, c.a * alpha))


func _scatter(canvas: CanvasItem, i: int, cx: float, base_y: float, sc_mul: float, alpha: float) -> void:
	# 1-3 flames of RANDOM size/position scattered across the cell, so scale and
	# spacing look natural rather than one uniform flame per grid cell.
	var n := 1 + int(_hash01(float(i) * 1.13) * 2.9)   # 1..3
	for k in range(n):
		var s := i * 11 + k * 7
		var fx := cx + (_hash01(float(s) * 3.7) - 0.5) * CELL_W * 1.15
		var fsc := sc_mul * (0.45 + 1.2 * _hash01(float(s) * 2.9))   # ~0.45..1.65
		if _hash01(float(s) * 4.4) > 0.86:
			fsc *= 1.7                                                # rare tall flare-up
		_flame(canvas, s, fx, base_y, fsc, alpha)


func _char_scar(canvas: CanvasItem, i: int, cx: float) -> void:
	# An irregular charred patch (overlapping blobs, not a clean rect).
	for k in range(3):
		var hx := _hash01(float(i) * 2.0 + float(k) * 1.3)
		canvas.draw_circle(Vector2(cx + (hx - 0.5) * CELL_W * 0.85, FIRE_BASE_Y - 1.0 + hx * 3.0), 4.0 + hx * 3.5, CHAR_COL)


# Depth is faked with staggered rows: BACK flames sit higher up (further into the
# room) + climb the walls, the MAIN row is at the floor line, FRONT licks are lower
# and closer — so the fire has vertical spread, not everything on one line.
const BASE_BACK := FIRE_BASE_Y - 13.0
const BASE_FRONT := FIRE_BASE_Y + 4.0


func _draw() -> void:
	# MAIN row (z1): scattered flames at the floor line, level with the actors.
	var sc := flame_scale()
	for i in range(cell_count):
		var cx := cell_x(i)
		var st := state_of(i)
		if st == SPENT:
			_char_scar(self, i, cx)
			continue
		if st != BURNING:
			if heat[i] > 0.12:
				var g := clampf(heat[i] / IGNITE_THRESHOLD, 0.0, 1.0)
				_tongue(self, cx, FIRE_BASE_Y, lerpf(3.0, 8.0, g), 4.0, float(i) * 1.3, 0.9)
			continue
		_scatter(self, i, cx, FIRE_BASE_Y, sc, 1.0)
		if _hash01(float(i) * 6.1) > 0.5:
			var ey := FIRE_BASE_Y - 20.0 - fmod(_t * 34.0 + float(i) * 21.0, 28.0 * sc)
			draw_rect(Rect2(cx + sin(_t * 3.0 + float(i)) * 6.0, ey, 2.0, 2.0), EMBER_COL)


func _draw_back(canvas: CanvasItem) -> void:
	# BACK row (z0, BEHIND the actors): receding floor flames PLUS fire climbing the
	# back wall at scattered heights and up the corridor end walls — so the blaze
	# has real vertical spread across the scene, not just a strip on the floor.
	var sc := flame_scale()
	for i in range(cell_count):
		if state_of(i) != BURNING:
			continue
		var cx := cell_x(i)
		_scatter(canvas, i, cx + 6.0, BASE_BACK, sc * 0.6, 0.55)      # receding floor row
		# a patch of fire licking UP the back wall at a random height
		if _hash01(float(i) * 7.7) > 0.5:
			var wy := FIRE_BASE_Y - 24.0 - _hash01(float(i) * 5.5) * 80.0
			var wx := cx + (_hash01(float(i) * 9.1) - 0.5) * 26.0
			canvas.draw_circle(Vector2(wx, wy + 8.0), 13.0 * sc, Color(0.85, 0.38, 0.12, 0.09))   # wall-catch glow
			_flame(canvas, i * 17 + 3, wx, wy + 12.0, sc * 0.5, 0.5)
	# Stronger flames climbing the corridor END walls when the ends are alight.
	_wall_column(canvas, 0, FIRE_MIN_X - 2.0, sc)
	_wall_column(canvas, cell_count - 1, FIRE_MAX_X + 2.0, sc)


func _wall_column(canvas: CanvasItem, cell_i: int, wall_x: float, sc: float) -> void:
	# A stack of flames licking up an end wall (tapering as it climbs).
	if state_of(cell_i) != BURNING:
		return
	for k in range(6):
		var wy := FIRE_BASE_Y - float(k) * 20.0
		canvas.draw_circle(Vector2(wall_x, wy), 11.0 * sc, Color(0.85, 0.38, 0.12, 0.10))
		_flame(canvas, 300 + cell_i * 5 + k, wall_x, wy, sc * (0.6 - float(k) * 0.07), 0.7 - float(k) * 0.1)


func _draw_front(canvas: CanvasItem) -> void:
	# FRONT row (z2, ADDITIVE, in front of the actors): a soft radial glow (the
	# "pop", additive so it brightens rather than browns) plus lower, closer licks.
	var sc := flame_scale()
	for i in range(cell_count):
		if state_of(i) != BURNING:
			continue
		var cx := cell_x(i)
		var soft := 0.05 * sin(_t * 4.0 + float(i))
		canvas.draw_circle(Vector2(cx, FIRE_BASE_Y - 12.0 * sc), 20.0 * sc, Color(1.0, 0.46, 0.13, 0.06 + soft))
		if _hash01(float(i) * 2.4) > 0.45:      # not every cell gets a foreground lick
			var flick := sin(_t * 10.0 + float(i) * 1.3) * 3.0
			_flame(canvas, i * 13 + 5, cx + (_hash01(float(i) * 5.5) - 0.5) * 12.0, BASE_FRONT, sc * (0.5 + 0.5 * _hash01(float(i) * 8.0)), 0.4)


func _draw_smoke(canvas: CanvasItem) -> void:
	# SMOKE layer (z4, on top): puffs that RISE from the flames to the ceiling,
	# growing, drifting on organic turbulence and fading out — overlapping soft
	# blobs read as a billowing column rather than swaying circles. Thin/sparse on
	# a LIGHT fire, thick/dark on a BLAZE. Choke is enforced in building_floors.
	if stage >= STAGE_CHARRED:
		return
	# Smoke is a MIX: thin light wisps and thick dark billows overlapping. On a
	# BLAZE the heavy layer dominates (choking — you must crouch to see under it);
	# a LIGHT fire is mostly thin wisps hugging the ceiling.
	var blaze := stage >= STAGE_BLAZE
	var rise_from := FIRE_BASE_Y - 12.0
	for i in range(cell_count):
		if not _smoke_col(i):
			continue
		var cx := cell_x(i)
		# LIGHT wisps (always) — pale, fast, thin.
		_smoke_puffs(canvas, i, cx, rise_from, 2, 0.30, 0.12, 0.18, 0.16)
		# HEAVY billows (blaze) — dark, slow, big, dropping lower.
		if blaze:
			_smoke_puffs(canvas, i, cx, rise_from, 4, 0.55, 0.30, 0.06, 0.28)


func _smoke_puffs(canvas: CanvasItem, i: int, cx: float, rise_from: float, puffs: int,
		max_alpha: float, dark_lo: float, dark_hi: float, speed: float) -> void:
	for p in range(puffs):
		var phase := _hash01(float(i) * 4.3 + float(p) * 9.1 + float(puffs))
		var prog := fmod(_t * speed + phase, 1.0)                 # 0 at flames → 1 at ceiling
		var y := lerpf(rise_from, CEILING_Y, prog)
		var turb := sin(_t * 1.1 + phase * 12.0 + prog * 4.0) * (6.0 + prog * 20.0) \
			+ sin(_t * 0.5 + phase * 20.0) * (3.0 + prog * 8.0)
		var rad := lerpf(8.0, 34.0, prog) * (0.7 + max_alpha)
		var a := sin(prog * PI) * max_alpha                       # fade in then out
		var shade := lerpf(dark_hi + 0.06, dark_lo, prog)         # darker low, paler high
		for b in range(3):
			var bh := _hash01(phase * 30.0 + float(b) * 3.7)
			var ox := (bh - 0.5) * rad * 0.9
			var oy := (_hash01(phase * 11.0 + float(b)) - 0.5) * rad * 0.7
			canvas.draw_circle(Vector2(cx + turb + ox, y + oy), rad * (0.55 + 0.4 * bh), Color(shade, shade, shade, a * 0.6))
