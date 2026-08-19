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
	# ONE flame drawn as LAYERED JAGGED POLYGONS — a red body, an orange layer, a
	# yellow layer, and a white-hot core inset toward the base — each with the SAME
	# ragged multi-lick top so it reads as a real flame (like classic pixel fire),
	# not a smooth cone or blob. Variety comes from proportions: width, height, how
	# many licks, lean and tip-curl all vary per seed — but every one is a flame.
	# Aspect varies a lot: some tall + narrow, some broad mounds of fire (not all
	# pointy triangles). Base y jitters a hair so a row of flames has no clean line.
	var w := (14.0 + _hash01(float(s) * 1.3) * 22.0) * sc
	var h := (18.0 + _hash01(float(s) * 2.1) * 26.0) * sc
	var peaks := 2 + int(_hash01(float(s) * 4.9) * 2.9)      # 2..4 licks
	var by := base_y - _hash01(float(s) * 0.7) * 2.0
	_flame_poly(canvas, s, x, by, w, h, peaks, Color(0.82, 0.16, 0.04), alpha)          # red body
	_flame_poly(canvas, s, x, by, w * 0.7, h * 0.82, peaks, Color(1.0, 0.46, 0.09), alpha)  # orange
	_flame_poly(canvas, s, x, by, w * 0.44, h * 0.60, peaks, Color(1.0, 0.80, 0.24), alpha)  # yellow
	_flame_poly(canvas, s, x, by, w * 0.20, h * 0.36, peaks, Color(1.0, 0.96, 0.80), alpha)  # white core


func _flame_poly(canvas: CanvasItem, s: int, x: float, base_y: float, w: float, h: float,
		peaks: int, col: Color, alpha: float) -> void:
	# One color band of a flame. The flame stays UPRIGHT (fire rises) — it does NOT
	# sway left/right as a rigid cone. Instead each point of the ragged top edge
	# FLICKERS fast and independently (two quick octaves), so the licks dart up and
	# down and dance in place like real fire. Same s/k across bands so they nest.
	var lx := x - w * 0.5
	var rx := x + w * 0.5
	# Steps scale with width so tiny flames don't crowd the points (which used to
	# make the top edge cross itself -> "triangulation failed" errors).
	var steps := clampi(int(w / 3.5), 4, 15)
	var pts := PackedVector2Array()
	pts.append(Vector2(lx, base_y + 2.0))
	var prev_x := lx + 0.4
	for k in range(steps + 1):
		var u := float(k) / float(steps)                       # 0 left → 1 right
		var arch := sin(u * PI)                                 # overall envelope
		var phase := float(s) * 1.3 + float(k) * 2.7
		var lick := 0.4 + 0.6 * absf(sin(u * float(peaks) * PI + float(s) * 0.7))   # WHICH points peak (static)
		# GENTLE flicker — slow + small so the flame dances without STROBING its
		# brightness (the old fast/large flicker read as a strobe light).
		var flick := 0.9 + 0.08 * sin(_t * 4.5 + phase) + 0.05 * sin(_t * 7.0 + phase * 1.6)
		var noise := 0.82 + 0.36 * _hash01(float(s) * 5.0 + float(k) * 3.1)
		var hh := maxf(h * arch * lick * flick * noise, 0.0)
		# tiny horizontal dance, scaled to width so small flames never self-cross,
		# then forced strictly-increasing + inside [lx,rx] -> always a valid polygon.
		var jx := sin(_t * 5.0 + phase * 1.4) * w * 0.03
		var lo := minf(prev_x, rx - 0.4)
		var px := clampf(x + (u - 0.5) * w + jx, lo, rx - 0.4)
		prev_x = px + 0.3
		pts.append(Vector2(px, base_y - hh))
	pts.append(Vector2(rx, base_y + 2.0))
	canvas.draw_colored_polygon(pts, Color(col.r, col.g, col.b, alpha))


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


# Depth is faked with two rows, BOTH grounded on the floor (fire is attached to the
# floor, never hanging mid-air): a small/dim BACK row a hair behind and a full MAIN
# row, plus a low FRONT lick. Reads deep without floating flames up the walls.
const BASE_BACK := FIRE_BASE_Y - 2.0
const BASE_FRONT := FIRE_BASE_Y + 3.0


func _floor_flicker(canvas: CanvasItem, i: int, cx: float, sc: float) -> void:
	# A carpet of little flames right on the floor so the BASE dances instead of
	# sitting on a dead flat line (the floor is on fire). Drawn as tapered RECTS —
	# robust for tiny sizes (no polygon triangulation) — with a GENTLE flicker so
	# it doesn't strobe.
	for k in range(5):
		var s := i * 31 + k * 13 + 900
		var fx := cx + (_hash01(float(s) * 3.1) - 0.5) * CELL_W * 1.1
		var flick := 0.75 + 0.25 * sin(_t * 5.5 + float(s) + float(k))       # gentle, slow
		var h := (5.0 + 8.0 * _hash01(float(s) * 2.3)) * sc * flick
		var bw := (4.0 + 3.0 * _hash01(float(s))) * sc
		var rows := int(h / 2.5)
		for r in range(rows):
			var fr := float(r) / float(maxi(rows, 1))
			var ww := bw * (1.0 - fr * 0.8)
			if ww < 1.0:
				ww = 1.0
			var wob := sin(_t * 6.0 + float(s) + fr * 4.0) * 1.2 * fr        # tiny tip wiggle
			var c := _flame_color(fr)
			canvas.draw_rect(Rect2(fx + wob - ww * 0.5, FIRE_BASE_Y - float(r) * 2.5, ww, 2.8), Color(c.r, c.g, c.b, c.a))


func _draw() -> void:
	# MAIN row (z1): scattered flames + a flickering floor carpet, on the floor line.
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
				_floor_flicker(self, i, cx, sc * lerpf(0.3, 0.7, g))
			continue
		_floor_flicker(self, i, cx, sc)
		_scatter(self, i, cx, FIRE_BASE_Y, sc, 1.0)
		if _hash01(float(i) * 6.1) > 0.5:
			var ey := FIRE_BASE_Y - 20.0 - fmod(_t * 34.0 + float(i) * 21.0, 28.0 * sc)
			draw_rect(Rect2(cx + sin(_t * 3.0 + float(i)) * 6.0, ey, 2.0, 2.0), EMBER_COL)


func _draw_back(canvas: CanvasItem) -> void:
	# BACK row (z0, BEHIND the actors): smaller, dimmer flames a hair behind the main
	# row — grounded on the floor (NO flames floating up the walls / stairwell shaft;
	# those read as hanging mid-air). Depth comes from size + dimness, not height.
	var sc := flame_scale()
	for i in range(cell_count):
		if state_of(i) == BURNING:
			_scatter(canvas, i, cell_x(i) + 6.0, BASE_BACK, sc * 0.62, 0.55)


func _draw_front(canvas: CanvasItem) -> void:
	# FRONT row (z2, ADDITIVE, in front of the actors): a soft radial glow (the
	# "pop", additive so it brightens rather than browns) plus lower, closer licks.
	var sc := flame_scale()
	for i in range(cell_count):
		if state_of(i) != BURNING:
			continue
		var cx := cell_x(i)
		# a STEADY warm glow (barely pulsing) so the fire "pops" without flashing
		var soft := 0.02 * sin(_t * 2.5 + float(i))
		canvas.draw_circle(Vector2(cx, FIRE_BASE_Y - 12.0 * sc), 18.0 * sc, Color(1.0, 0.46, 0.13, 0.05 + soft))
		if _hash01(float(i) * 2.4) > 0.5:      # not every cell gets a foreground lick
			_flame(canvas, i * 13 + 5, cx + (_hash01(float(i) * 5.5) - 0.5) * 12.0, BASE_FRONT, sc * (0.5 + 0.5 * _hash01(float(i) * 8.0)), 0.4)


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
