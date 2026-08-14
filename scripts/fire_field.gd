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
# SPREAD is a SLOW creep: a burning cell's heat only just outpaces a cool cell's
# heat loss, so the front advances ~1 cell every ~12s — the fire grows over a
# long visit but stays small and steady on a quick one. Tune these two together
# (net = SPREAD_RATE - COOL_RATE sets the creep speed).
const SPREAD_RATE := 0.14         # heat/sec a burning cell pushes to each neighbour
const COOL_RATE := 0.10           # heat/sec a non-burning cell loses
# A fire does NOT burn itself out within a run — it stays lit until the player
# puts it out (or a run-3 char_all makes a ruin). So fuel never depletes from
# burning (BURN_RATE 0); only extinguish_at / char_all zero it. This is what
# makes a small fire CONSISTENT: ignore it and it's still there (worse next run).
const BURN_RATE := 0.0
const SIM_DT := 0.1               # fixed simulation step
const MAX_HEAT := 1.2

enum { COOL, BURNING, SPENT }

var cell_count: int = 0
var heat: PackedFloat32Array = PackedFloat32Array()
var fuel: PackedFloat32Array = PackedFloat32Array()
var floor_num: int = -1
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


# --- simulation -------------------------------------------------------------

func tick(dt: float) -> void:
	# One deterministic spread step. Burning cells burn down their fuel and push
	# heat outward; cool cells bleed heat off. Neighbour heat is written to a copy
	# so the step doesn't cascade within a single tick.
	var new_heat := heat.duplicate()
	for i in range(cell_count):
		match state_of(i):
			BURNING:
				fuel[i] = maxf(fuel[i] - BURN_RATE * dt, 0.0)
				var push := SPREAD_RATE * dt
				if i > 0 and fuel[i - 1] > 0.0:
					new_heat[i - 1] = minf(new_heat[i - 1] + push, MAX_HEAT)
				if i < cell_count - 1 and fuel[i + 1] > 0.0:
					new_heat[i + 1] = minf(new_heat[i + 1] + push, MAX_HEAT)
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


# --- render (natural pixel flames; flicker is cosmetic only) ----------------
# Each burning cell draws a small cluster of tapered flame TONGUES: chunky pixel
# rows narrowing to a point, hot near the base (near-white/yellow) and cooling to
# orange then red at the flickering tip. Small but clearly fire — not a slab.

const ROW_H := 3.0                 # pixel-chunk height per flame row
const CHAR_COL := Color(0.09, 0.08, 0.08)
const SMOKE_COL := Color(0.22, 0.21, 0.21, 0.28)
const GLOW_COL := Color(1.0, 0.55, 0.15, 0.13)
const EMBER_COL := Color(1.0, 0.80, 0.35, 0.9)


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


func _draw_tongue(cx: float, h: float, base_w: float, phase: float) -> void:
	# One tapered, leaning flame tongue rising from FIRE_BASE_Y.
	var rows := int(h / ROW_H)
	if rows < 1:
		return
	for r in range(rows):
		var frac := float(r) / float(rows)
		var w := base_w * pow(1.0 - frac, 0.7)   # taper to a point
		if w < 1.0:
			w = 1.0
		# Lean/wiggle grows toward the tip so the flame licks sideways.
		var lean := sin(_t * 6.5 + phase + frac * 3.4) * base_w * 0.4 * frac
		var y := FIRE_BASE_Y - float(r + 1) * ROW_H
		draw_rect(Rect2(cx + lean - w * 0.5, y, w, ROW_H + 0.5), _flame_color(frac))


func _draw() -> void:
	for i in range(cell_count):
		var cx := cell_x(i)
		var st := state_of(i)
		if st == SPENT:
			# Charred floor scar (run-3 ruin / a doused patch).
			draw_rect(Rect2(cx - CELL_W / 2.0 + 1.0, FIRE_BASE_Y - 5.0, CELL_W - 2.0, 6.0), CHAR_COL)
			continue
		if st != BURNING:
			# A hot-but-unlit cell: a low ember glow at the base as it catches.
			if heat[i] > 0.12:
				var g := clampf(heat[i] / IGNITE_THRESHOLD, 0.0, 1.0)
				_draw_tongue(cx, lerpf(3.0, 9.0, g), 5.0, float(i) * 1.3)
			continue
		# BURNING: a small cluster of tongues, flickering, staggered across the
		# cell so a run of burning cells reads as one lively fire — kept SHORT.
		var flick := sin(_t * 8.0 + float(i) * 1.7) * 2.5 + sin(_t * 13.0 + float(i) * 0.7) * 1.5
		var soft := 0.13 * sin(_t * 4.0 + float(i))          # gentle base glow pulse
		draw_circle(Vector2(cx, FIRE_BASE_Y - 2.0), 15.0, Color(GLOW_COL.r, GLOW_COL.g, GLOW_COL.b, GLOW_COL.a + soft))
		_draw_tongue(cx - 11.0, 15.0 + flick, 7.0, float(i) * 2.1 + 1.0)   # side tongue
		_draw_tongue(cx + 2.0, 26.0 + flick, 10.0, float(i) * 1.9)         # main tongue
		_draw_tongue(cx + 12.0, 13.0 - flick, 6.0, float(i) * 2.7 + 2.0)   # side tongue
		# A couple of embers drifting up off the flame.
		var ey := FIRE_BASE_Y - 22.0 - fmod(_t * 34.0 + float(i) * 21.0, 30.0)
		var ex := cx + sin(_t * 3.0 + float(i)) * 6.0
		draw_rect(Rect2(ex, ey, 2.0, 2.0), EMBER_COL)
		# A thin wisp of smoke above the tip.
		var sy := FIRE_BASE_Y - 34.0 - fmod(_t * 18.0 + float(i) * 27.0, 34.0)
		draw_rect(Rect2(cx - 5.0, sy, 8.0, 6.0), SMOKE_COL)
