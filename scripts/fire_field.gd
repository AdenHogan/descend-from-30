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

const IGNITE_THRESHOLD := 0.55
const SPREAD_RATE := 0.6          # heat/sec a burning cell pushes to each neighbour
const BURN_RATE := 0.05           # fuel/sec a burning cell consumes (~20s per cell)
const COOL_RATE := 0.20           # heat/sec a non-burning cell loses
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


# --- render (pixelated flames; flicker is cosmetic only) --------------------

const FLAME_LOW := Color(0.85, 0.20, 0.05)
const FLAME_MID := Color(0.98, 0.55, 0.10)
const FLAME_TOP := Color(1.0, 0.85, 0.25)
const CHAR_COL := Color(0.10, 0.09, 0.09)
const SMOKE_COL := Color(0.25, 0.24, 0.24, 0.35)


func _draw() -> void:
	for i in range(cell_count):
		var cx := cell_x(i)
		var st := state_of(i)
		if st == SPENT:
			# Charred floor patch + a faint wisp of smoke.
			draw_rect(Rect2(cx - CELL_W / 2.0 + 1.0, FIRE_BASE_Y - 8.0, CELL_W - 2.0, 10.0), CHAR_COL)
			continue
		if st != BURNING:
			# A hot-but-unlit cell glows faintly at the base.
			if heat[i] > 0.15:
				var a := clampf(heat[i], 0.0, 0.4)
				draw_rect(Rect2(cx - CELL_W / 2.0 + 4.0, FIRE_BASE_Y - 6.0, CELL_W - 8.0, 6.0), Color(FLAME_LOW.r, FLAME_LOW.g, FLAME_LOW.b, a))
			continue
		# BURNING: a blocky, flickering flame stack rising from the floor.
		var intensity := clampf(fuel[i], 0.15, 1.0)
		var h := lerpf(26.0, 64.0, intensity)
		var flick := sin(_t * 9.0 + float(i) * 1.7) * 4.0 + sin(_t * 15.0 + float(i)) * 2.0
		var top_y := FIRE_BASE_Y - h - flick
		# base (wide, dark-orange), mid, tip (narrow, bright)
		draw_rect(Rect2(cx - CELL_W / 2.0 + 2.0, FIRE_BASE_Y - h * 0.45, CELL_W - 4.0, h * 0.45), FLAME_LOW)
		draw_rect(Rect2(cx - CELL_W / 2.0 + 6.0, FIRE_BASE_Y - h * 0.8, CELL_W - 12.0, h * 0.45), FLAME_MID)
		draw_rect(Rect2(cx - 6.0, top_y, 12.0, h * 0.4), FLAME_TOP)
		# smoke puff rising above
		var sy := FIRE_BASE_Y - h - 18.0 - fmod(_t * 22.0 + float(i) * 30.0, 40.0)
		draw_rect(Rect2(cx - 9.0, sy, 18.0, 12.0), SMOKE_COL)
