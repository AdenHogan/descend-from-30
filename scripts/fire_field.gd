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

const FLAME_ROW := 3.0             # pixel-chunk row height for a flame
const FLAME_STRIDE := 15.0         # spacing of flame tongues along the fire strip
const CHAR_COL := Color(0.09, 0.08, 0.08)
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


func _tongue_outer(f: float) -> Color:
	# The outer skin / SILHOUETTE of a flame, base(0) -> tip(1): a pale-hot foot
	# through yellow and orange to a dark-red curling tip (matches the reference
	# pixel fire — hot low, red up top).
	if f < 0.08:
		return Color(1.0, 0.95, 0.72)
	elif f < 0.30:
		return Color(1.0, 0.78, 0.24)
	elif f < 0.55:
		return Color(1.0, 0.50, 0.13)
	elif f < 0.78:
		return Color(0.85, 0.27, 0.07)
	return Color(0.60, 0.12, 0.045)


func _tongue_inner(f: float) -> Color:
	# The bright HEART up the lower centre of a flame — white-hot low, cooling to
	# yellow. Only the lower body has a heart; tips are all outer red. This is what
	# gives each flame its own white core (colour by within-flame height, NOT screen
	# height — so there are no horizontal colour stripes across the whole fire).
	if f < 0.10:
		return Color(1.0, 1.0, 0.94)
	elif f < 0.32:
		return Color(1.0, 0.94, 0.60)
	return Color(1.0, 0.78, 0.28)


func _hash01(a: float) -> float:
	# Cheap deterministic pseudo-random in [0,1) for organic (non-uniform) jitter.
	return fmod(absf(sin(a * 12.9898) * 43758.5453), 1.0)


func _draw_tongue(canvas: CanvasItem, cx: float, base_y: float, h: float, base_w: float, seed: float, alpha: float) -> void:
	# ONE flame: a teardrop with a bright heart and a dark curling tip, built from
	# stacked rows (robust — no polygons, so no triangulation errors). Colour is by
	# height WITHIN this flame, so every flame has its own white-hot base and red tip.
	# Only the TIP curls/flicks (wobble scaled by f); the body stays put, so it dances
	# instead of swaying like a worm.
	var rows := int(h / FLAME_ROW)
	if rows < 2:
		rows = 2
	var lean := (_hash01(seed * 1.7) - 0.5) * base_w * 0.7     # this flame's own drift
	var fph := seed * 6.1
	for r in range(rows):
		var f := float(r) / float(rows)                         # 0 base .. 1 tip
		# teardrop: full-bodied low, pinched to a point at the tip
		var w := base_w * pow(sin((1.0 - f) * (PI * 0.5)), 0.62)
		if w < 1.3:
			w = 1.3
		# gentle lean that grows toward the tip + a small upward-travelling flicker
		# concentrated at the tip — the TIP licks, the body holds
		var curl := lean * f * f + sin(_t * 8.0 + fph + f * 5.5) * (2.0 * f)
		var y := base_y - f * h
		var oc := _tongue_outer(f)
		canvas.draw_rect(Rect2(cx + curl - w * 0.5, y - FLAME_ROW, w, FLAME_ROW + 0.6), Color(oc.r, oc.g, oc.b, oc.a * alpha))
		if f < 0.66:                                            # bright heart, lower body only
			var iw := w * 0.5
			var ic := _tongue_inner(f)
			canvas.draw_rect(Rect2(cx + curl - iw * 0.5, y - FLAME_ROW, iw, FLAME_ROW + 0.6), Color(ic.r, ic.g, ic.b, ic.a * alpha))


# --- the fire strip: a packed row of independently-dancing flame tongues --------
# Along the burning span, tongues sit ~FLAME_STRIDE apart (dense, like a real bed
# of fire), each with its own width, height and — crucially — its own flicker FREQ
# and PHASE, so they never rise and fall together (that shared rhythm was the "EDM
# pulse"). Heights vary a lot (many mid, a few tall spikes) so the crown is ragged,
# not a row of matching cones. Identity is seeded by x, so a spreading fire's
# flames stay put as new ground catches.

func _flame_strip(canvas: CanvasItem, base_y: float, sc: float, alpha: float, size_mul: float, spark: bool) -> void:
	var x := FIRE_MIN_X
	while x <= FIRE_MAX_X:
		if is_burning_at(x):
			var region := floori(x / FLAME_STRIDE)
			var seed := float(region) * 2.399 + float(floor_num) * 0.73
			var jx := (_hash01(seed * 1.1) - 0.5) * FLAME_STRIDE * 0.8
			var base_w := (7.0 + 7.0 * _hash01(seed * 2.3)) * sc
			var hb := 15.0 + 32.0 * _hash01(seed * 3.7)
			if _hash01(seed * 5.1) > 0.83:
				hb *= 1.7                                       # occasional tall spike
			# INDEPENDENT flicker: small, fast, per-flame freq+phase (dances, no pump)
			var freq := 6.0 + 6.0 * _hash01(seed * 4.3)
			var flick := 1.0 + 0.16 * sin(_t * freq + seed * 7.0) + 0.09 * sin(_t * (freq * 1.7) + seed * 3.0)
			var h := hb * sc * size_mul * clampf(flick, 0.7, 1.35)
			_draw_tongue(canvas, x + jx, base_y, h, base_w, seed, alpha)
			# a spark detaching from the tip and rising, then fading — real fire sheds
			if spark and _hash01(seed * 6.6) > 0.62:
				var p := fmod(_t * 0.85 + _hash01(seed * 7.7), 1.0)
				var srad := (2.6 - 2.2 * p) * sc
				if srad > 0.5:
					var sy := base_y - h - p * 26.0 * sc
					canvas.draw_circle(Vector2(x + jx + sin(_t * 3.0 + seed) * 4.0, sy), srad, Color(1.0, 0.52, 0.16, (1.0 - p) * 0.85 * alpha))
		x += FLAME_STRIDE


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


func _ember_base(canvas: CanvasItem, sc: float, alpha: float) -> void:
	# A low, STABLE white-hot ember bed the tongues rise from — slightly uneven along
	# its top and barely shimmering (so the BASE never bobs). Gives the fire a hot,
	# continuous foot instead of separate flames floating on the floor line.
	var x := FIRE_MIN_X
	while x <= FIRE_MAX_X:
		if is_burning_at(x):
			var region := floori(x / 8.0)
			var seed := float(region) * 1.77 + float(floor_num) * 0.5
			var eh := (6.0 + 5.0 * _hash01(seed * 2.1)) * sc
			eh *= 0.9 + 0.1 * sin(_t * 3.0 + seed)              # tiny shimmer, not a pump
			var rows := int(eh / FLAME_ROW)
			for r in range(rows):
				var f := float(r) / float(maxi(rows, 1))
				var c := _tongue_inner(f * 0.5)                 # white/yellow hot foot
				canvas.draw_rect(Rect2(x - 4.5, FIRE_BASE_Y - float(r + 1) * FLAME_ROW, 9.0, FLAME_ROW + 0.6), Color(c.r, c.g, c.b, c.a * alpha))
		x += 8.0


func _draw() -> void:
	# MAIN layer (z1, with the actors): the stable ember bed + the packed flame strip,
	# on the floor line. Char scars where the fire has burnt out.
	var sc := flame_scale()
	for i in range(cell_count):
		if state_of(i) == SPENT:
			_char_scar(self, i, cell_x(i))
	_ember_base(self, sc, 1.0)
	_flame_strip(self, FIRE_BASE_Y, sc, 1.0, 1.0, true)


func _draw_back(canvas: CanvasItem) -> void:
	# BACK layer (z0, BEHIND the actors): the same flames a touch shorter, dimmer and
	# a hair behind, so the player stands AMONG the fire. Grounded on the floor (no
	# flames floating up the wall / stairwell shaft — those read as hanging mid-air).
	_flame_strip(canvas, BASE_BACK, flame_scale() * 0.82, 0.5, 0.9, false)


func _draw_front(canvas: CanvasItem) -> void:
	# FRONT layer (z2, ADDITIVE): a soft warm glow so the fire pops (additive brightens
	# rather than browns), plus a few low close licks in front of the actors' feet.
	var sc := flame_scale()
	var x := FIRE_MIN_X
	while x <= FIRE_MAX_X:
		if is_burning_at(x):
			canvas.draw_circle(Vector2(x, FIRE_BASE_Y - 12.0 * sc), 17.0 * sc, Color(1.0, 0.45, 0.12, 0.05))
		x += 34.0
	_flame_strip(canvas, BASE_FRONT, sc * 0.55, 0.4, 0.6, false)


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
