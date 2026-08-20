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


func _hash01(a: float) -> float:
	# Cheap deterministic pseudo-random in [0,1) for organic (non-uniform) jitter.
	return fmod(absf(sin(a * 12.9898) * 43758.5453), 1.0)


# --- continuous fire (one connected mass, not separate flames) --------------
# The fire is drawn as a CONTINUOUS HEIGHT FIELD sampled in vertical columns
# across the whole burning span, so it reads as one connected sheet of fire (no
# separate "worms"). Its silhouette = a low glowing BODY wherever there's fuel,
# plus a handful of TONGUES (moving peaks) that rise, flicker, reach out and die
# back over time — the oxygen-fed dance of real fire. Columns are coloured by
# ABSOLUTE height, so the base is a white-hot line and only the tall licks cool
# to red at the tip, exactly like classic pixel fire.
const COL_STEP := 3.0
const FIRE_ROW := 2.5


func _fuel_at(x: float) -> float:
	# 0..1 fuel at this x: 1 inside a burning run, tapering to 0 at its OUTER edges
	# so the fire ends in tapered flames instead of a hard vertical cut.
	var c := cell_at(x)
	if state_of(c) != BURNING:
		return 0.0
	var within := (x - (FIRE_MIN_X + float(c) * CELL_W)) / CELL_W      # 0..1 across the cell
	var f := 1.0
	if c <= 0 or state_of(c - 1) != BURNING:
		f = minf(f, smoothstep(0.0, 0.55, within))
	if c >= cell_count - 1 or state_of(c + 1) != BURNING:
		f = minf(f, smoothstep(0.0, 0.55, 1.0 - within))
	return f


func _tongues_at(x: float, sc: float) -> float:
	# The tallest tongue reaching this x. Tongues are seeded ~46px apart; each rises
	# and falls on its own cycle (sometimes to nothing → it vanishes, then returns).
	var region := floori(x / 46.0)
	var best := 0.0
	for d in range(-1, 2):
		var tid := region + d
		var seed := float(tid) * 12.9898
		var cx := (float(tid) + 0.5) * 46.0 + (_hash01(seed) - 0.5) * 26.0 + sin(_t * 0.5 + seed) * 6.0
		var speed := 1.6 + 2.4 * _hash01(seed * 1.7)
		var life := 0.5 + 0.5 * sin(_t * speed + seed * 3.0) + 0.25 * sin(_t * (speed * 1.9) + seed)
		var reach := clampf(life * 1.4 - 0.35, 0.0, 1.3)               # occasional 0 = gone
		var height := (18.0 + 30.0 * _hash01(seed * 2.3)) * sc * reach
		var width := 7.0 + 6.0 * _hash01(seed * 3.1)
		var dd := (x - cx) / width
		best = maxf(best, height * exp(-dd * dd))
	return best


func _fire_ramp(y_abs: float, sc: float) -> Color:
	# Colour by ABSOLUTE height above the floor: white-hot base line up to red tips.
	var y := y_abs / maxf(sc, 0.5)
	if y < 5.0:
		return Color(1.0, 0.97, 0.86)      # white-hot base
	elif y < 13.0:
		return Color(1.0, 0.85, 0.34)      # yellow
	elif y < 26.0:
		return Color(1.0, 0.52, 0.13)      # orange
	elif y < 42.0:
		return Color(0.88, 0.26, 0.06)     # deep orange
	return Color(0.70, 0.15, 0.05)         # red tip


func _draw_fire_span(canvas: CanvasItem, base_y: float, sc: float, alpha: float, body_mul: float) -> void:
	var x := FIRE_MIN_X
	while x <= FIRE_MAX_X:
		var fuel := _fuel_at(x)
		if fuel > 0.02:
			# body: a low glowing base wherever there's fuel, gently jagged + alive
			var jag := 0.6 + 0.4 * _hash01(floorf(x / 6.0))
			var body := (9.0 + 6.0 * jag) * sc * body_mul
			body *= 0.9 + 0.12 * sin(_t * 4.0 + x * 0.14)
			var h := (body + _tongues_at(x, sc)) * fuel
			var rows := int(h / FIRE_ROW)
			for r in range(rows):
				var y_abs := float(r) * FIRE_ROW
				var c := _fire_ramp(y_abs, sc)
				canvas.draw_rect(Rect2(x - COL_STEP * 0.5, base_y - y_abs - FIRE_ROW, COL_STEP + 0.6, FIRE_ROW + 0.4),
					Color(c.r, c.g, c.b, c.a * alpha))
		x += COL_STEP


func _char_scar(canvas: CanvasItem, i: int, cx: float) -> void:
	# An irregular charred patch (overlapping blobs, not a clean rect).
	for k in range(3):
		var hx := _hash01(float(i) * 2.0 + float(k) * 1.3)
		canvas.draw_circle(Vector2(cx + (hx - 0.5) * CELL_W * 0.85, FIRE_BASE_Y - 1.0 + hx * 3.0), 4.0 + hx * 3.5, CHAR_COL)


# Depth: three sheets of the SAME continuous fire at different depths so the
# player stands AMONG it — a TALLER dim BACK sheet behind the actors (flames rise
# behind the player), the full MAIN sheet at their feet, and a short ADDITIVE
# FRONT sheet with glow in front. All grounded on the floor (no mid-air fire).
const BASE_FRONT := FIRE_BASE_Y + 3.0


func _draw() -> void:
	var sc := flame_scale()
	for i in range(cell_count):
		if state_of(i) == SPENT:
			_char_scar(self, i, cell_x(i))
	_draw_fire_span(self, FIRE_BASE_Y, sc, 1.0, 1.0)          # MAIN sheet
	# embers drifting up off the fire
	for i in range(cell_count):
		if state_of(i) == BURNING and _hash01(float(i) * 6.1) > 0.4:
			var cx := cell_x(i)
			var ey := FIRE_BASE_Y - 24.0 - fmod(_t * 34.0 + float(i) * 21.0, 34.0 * sc)
			draw_rect(Rect2(cx + sin(_t * 3.0 + float(i)) * 7.0, ey, 2.0, 2.0), EMBER_COL)


func _draw_back(canvas: CanvasItem) -> void:
	# BACK sheet (z0, BEHIND the actors): a TALLER, dimmer sheet so flames rise
	# behind the player and they stand amongst the fire — grounded, not floating.
	_draw_fire_span(canvas, FIRE_BASE_Y - 3.0, flame_scale() * 1.18, 0.5, 1.25)


func _draw_front(canvas: CanvasItem) -> void:
	# FRONT sheet (z2, ADDITIVE, in front of the actors): a low sheet of close licks
	# + a steady warm glow along the fire so it "pops" and reads in front of you.
	var sc := flame_scale()
	var x := FIRE_MIN_X
	while x <= FIRE_MAX_X:
		if _fuel_at(x) > 0.25:
			canvas.draw_circle(Vector2(x, FIRE_BASE_Y - 10.0 * sc), 15.0 * sc, Color(1.0, 0.46, 0.13, 0.045))
		x += 38.0
	_draw_fire_span(canvas, BASE_FRONT, sc * 0.62, 0.4, 0.6)


# The smoke bank's lowest edge at full intensity — a HIGH ceiling of haze with a
# clear breathable band beneath it to crouch into (the choke/fog is decoupled).
const SMOKE_FLOOR_Y := FIRE_BASE_Y - 100.0
const SMOKE_STEP := 26.0                # horizontal spacing of haze nodes


func _draw_smoke(canvas: CanvasItem) -> void:
	# SMOKE layer (z4, on top). NOT a stack of hard circles — a soft, DIFFUSE haze:
	# many small, low-alpha, LIGHT-grey puffs on a jittered grid that overlap into a
	# continuous misty veil and DRIFT slowly sideways (advection) rather than pulsing
	# in place. It hangs as a high ceiling of haze, densest just under its lower edge
	# and thinning both up to the ceiling and (feathered) down into clear air, so
	# there's always a breathable band to crouch into. Density and how low it hangs
	# grow CONTINUOUSLY with intensity — a small fire barely hazes, a blaze chokes.
	if stage >= STAGE_CHARRED:
		return
	var intensity := smoke_intensity()
	if intensity < 0.05:
		return
	var bottom := lerpf(CEILING_Y + 55.0, SMOKE_FLOOR_Y, clampf(intensity, 0.0, 1.0))
	# The smoke spans a margin past the burning cells (it billows wider than the flame).
	var x0 := FIRE_MAX_X
	var x1 := FIRE_MIN_X
	for i in range(cell_count):
		if _smoke_col(i):
			x0 = minf(x0, cell_x(i) - float(SMOKE_MARGIN_CELLS) * CELL_W)
			x1 = maxf(x1, cell_x(i) + float(SMOKE_MARGIN_CELLS) * CELL_W)
	if x1 <= x0:
		return
	_draw_haze(canvas, x0, x1, bottom, intensity)


var _puff_tex: Texture2D = null


func _make_puff() -> void:
	# A soft radial puff: white with a gaussian ALPHA falloff to fully transparent at
	# the rim. Drawn many times and tinted grey, these SOFT edges blend seamlessly —
	# so the smoke reads as continuous mist, never a field of hard-edged discs.
	var sz := 64
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var c := float(sz) * 0.5
	for yy in range(sz):
		for xx in range(sz):
			var d := Vector2(float(xx) - c + 0.5, float(yy) - c + 0.5).length() / c
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a * (3.0 - 2.0 * a)                          # smoothstep falloff
			img.set_pixel(xx, yy, Color(1.0, 1.0, 1.0, a))
	_puff_tex = ImageTexture.create_from_image(img)


func _draw_haze(canvas: CanvasItem, x0: float, x1: float, bottom: float, intensity: float) -> void:
	if _puff_tex == null:
		_make_puff()
	var x := x0
	var col := 0
	while x <= x1:
		# Feather the two ENDS of the bank so it dissolves into air, not a wall.
		var edge := smoothstep(0.0, 110.0, x - x0) * smoothstep(0.0, 110.0, x1 - x)
		var rows := 10
		for r in range(rows):
			var frac := float(r) / float(rows)                   # 0 bottom edge → 1 ceiling
			var y := lerpf(bottom, CEILING_Y, frac)
			var ph := float(col) * 1.9 + float(r) * 0.7
			# slow lateral drift (advection) — the haze slides, it does NOT throb
			var drift := sin(_t * 0.22 + ph) * 12.0 + sin(_t * 0.11 + ph * 0.6) * 7.0
			var jx := (_hash01(ph) - 0.5) * SMOKE_STEP
			var jy := (_hash01(ph * 1.7) - 0.5) * 12.0
			# fade IN above the bottom edge (soft underside, no hard line); densest low
			var vfade := smoothstep(0.0, 0.22, frac)
			# drifting thick/thin patches so the mist ROILS instead of sitting flat-grey
			var cloud := 0.55 + 0.45 * sin(x * 0.013 + _t * 0.25 + float(r) * 0.6) * cos(y * 0.02 - _t * 0.16 + float(col) * 0.4)
			var dens := lerpf(1.0, 0.35, frac) * edge * vfade * clampf(cloud, 0.2, 1.0) * clampf(intensity * 1.15, 0.0, 1.1)
			if dens < 0.02:
				continue
			var shade := 0.46 + 0.07 * _hash01(ph * 0.9)         # LIGHT grey mist, not black
			var a := 0.15 * dens
			var sz := (78.0 + 34.0 * _hash01(ph * 2.3))          # big soft puffs = seamless overlap
			var pos := Vector2(x + drift + jx, y + jy)
			canvas.draw_texture_rect(_puff_tex, Rect2(pos - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), false, Color(shade, shade, shade, a))
		x += SMOKE_STEP
		col += 1
