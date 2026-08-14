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


func _tongue(canvas: CanvasItem, cx: float, h: float, base_w: float, phase: float, alpha: float) -> void:
	# One tapered, leaning flame tongue rising from FIRE_BASE_Y, onto `canvas`.
	var rows := int(h / ROW_H)
	if rows < 1:
		return
	for r in range(rows):
		var frac := float(r) / float(rows)
		var w := base_w * pow(1.0 - frac, 0.7)   # taper to a point
		if w < 1.0:
			w = 1.0
		var lean := sin(_t * 6.5 + phase + frac * 3.4) * base_w * 0.4 * frac
		var y := FIRE_BASE_Y - float(r + 1) * ROW_H
		var c := _flame_color(frac)
		canvas.draw_rect(Rect2(cx + lean - w * 0.5, y, w, ROW_H + 0.5), Color(c.r, c.g, c.b, c.a * alpha))


func _cluster(canvas: CanvasItem, i: int, cx: float, sc: float, alpha: float) -> void:
	# The 3-tongue flame cluster for one burning cell, sized by `sc`.
	var flick := sin(_t * 8.0 + float(i) * 1.7) * 2.5 + sin(_t * 13.0 + float(i) * 0.7) * 1.5
	_tongue(canvas, cx - 11.0 * sc, (15.0 + flick) * sc, 7.0 * sc, float(i) * 2.1 + 1.0, alpha)
	_tongue(canvas, cx + 2.0 * sc, (26.0 + flick) * sc, 10.0 * sc, float(i) * 1.9, alpha)
	_tongue(canvas, cx + 12.0 * sc, (13.0 - flick) * sc, 6.0 * sc, float(i) * 2.7 + 2.0, alpha)


func _draw() -> void:
	# MAIN layer (z1): full flames at floor level, sized by stage.
	var sc := flame_scale()
	for i in range(cell_count):
		var cx := cell_x(i)
		var st := state_of(i)
		if st == SPENT:
			draw_rect(Rect2(cx - CELL_W / 2.0 + 1.0, FIRE_BASE_Y - 5.0, CELL_W - 2.0, 6.0), CHAR_COL)
			continue
		if st != BURNING:
			if heat[i] > 0.12:
				var g := clampf(heat[i] / IGNITE_THRESHOLD, 0.0, 1.0)
				_tongue(self, cx, lerpf(3.0, 9.0, g), 5.0, float(i) * 1.3, 1.0)
			continue
		_cluster(self, i, cx, sc, 1.0)
		# embers drifting up off the flame
		var ey := FIRE_BASE_Y - 22.0 - fmod(_t * 34.0 + float(i) * 21.0, 30.0 * sc)
		var ex := cx + sin(_t * 3.0 + float(i)) * 6.0
		draw_rect(Rect2(ex, ey, 2.0, 2.0), EMBER_COL)


func _draw_back(canvas: CanvasItem) -> void:
	# BACK layer (z0, behind the actors): dimmer, smaller flames for depth.
	var sc := flame_scale() * 0.72
	for i in range(cell_count):
		if state_of(i) == BURNING:
			_cluster(canvas, i, cell_x(i), sc, 0.7)


func _draw_front(canvas: CanvasItem) -> void:
	# FRONT layer (z2, ADDITIVE, in front of the actors): a radial glow that makes
	# the fire pop, plus a couple of translucent foreground licks so the player
	# reads as standing amid the flames.
	var sc := flame_scale()
	for i in range(cell_count):
		if state_of(i) != BURNING:
			continue
		var cx := cell_x(i)
		var soft := 0.06 * sin(_t * 4.0 + float(i))
		canvas.draw_circle(Vector2(cx, FIRE_BASE_Y - 12.0 * sc), 24.0 * sc, Color(1.0, 0.48, 0.14, 0.09 + soft))
		canvas.draw_circle(Vector2(cx, FIRE_BASE_Y - 5.0), 12.0 * sc, Color(1.0, 0.72, 0.28, 0.13 + soft))
		var flick := sin(_t * 10.0 + float(i) * 1.3) * 3.0
		_tongue(canvas, cx + 4.0, (28.0 + flick) * sc, 6.0 * sc, float(i) * 1.4, 0.5)


func _draw_smoke(canvas: CanvasItem) -> void:
	# SMOKE layer (z4, on top): translucent billows pooling from the ceiling down
	# to smoke_bottom_y — thin and high on a LIGHT fire, thick and low (head
	# height) on a BLAZE. Choking is enforced in building_floors (crouch under it).
	if stage >= STAGE_CHARRED:
		return
	var bottom := smoke_bottom_y()
	var dense := 1.0 if stage >= STAGE_BLAZE else 0.5
	for i in range(cell_count):
		if not _smoke_col(i):
			continue
		var cx := cell_x(i)
		var y := CEILING_Y
		var idx := 0
		while y < bottom:
			var frac := (y - CEILING_Y) / maxf(bottom - CEILING_Y, 1.0)
			var drift := sin(_t * 0.9 + float(i) * 0.5 + frac * 4.0) * (8.0 + frac * 16.0)
			var swirl := cos(_t * 0.6 + float(i) * 0.7 + float(idx)) * 4.0
			var rad := 16.0 + (1.0 - frac) * 10.0
			var a := (0.05 + (1.0 - frac) * 0.15) * dense
			canvas.draw_circle(Vector2(cx + drift + swirl, y), rad, Color(0.16, 0.15, 0.15, a))
			y += 16.0
			idx += 1
