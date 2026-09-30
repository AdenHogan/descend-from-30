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
	_spawn_layers()
	_spawn_fire_lights()
	add_to_group("fire_field")


# --- fire as a REAL light source --------------------------------------------
# A burning corridor throws orange light — but LOCALISED to the flames, a tight warm
# glow that hugs the fire, NOT a floor-wide wash. A pool of small flickering PointLight2D
# ride the BURNING span (repositioned each frame); only as MANY are lit as the span is
# wide (FIRE_LIGHT_SPACING), so a small fire is ONE tight glow instead of four piled on
# the same spot blowing the area out. They wink out when nothing's burning.
const FIRE_LIGHT_COUNT := 4
const FIRE_LIGHT_SPACING := 150.0     # px of burning span per lit glow
const FIRE_LIGHT_COLOR := Color(1.0, 0.52, 0.16)
const FLOOR_LIGHTING := preload("res://scripts/floor_lighting.gd")
var _fire_lights: Array = []


func _spawn_fire_lights() -> void:
	for i in range(FIRE_LIGHT_COUNT):
		var lt := PointLight2D.new()
		lt.texture = FLOOR_LIGHTING.light_texture()
		lt.color = FIRE_LIGHT_COLOR
		lt.energy = 0.0                  # dark until it rides a burning cell
		lt.z_index = 0
		add_child(lt)
		_fire_lights.append(lt)


func _update_fire_lights() -> void:
	if _fire_lights.is_empty():
		return
	# Collect the burning span.
	var lo := -1
	var hi := -1
	for i in range(cell_count):
		if state_of(i) == BURNING:
			if lo < 0:
				lo = i
			hi = i
	if lo < 0:
		for lt in _fire_lights:
			lt.energy = 0.0
		return
	var x0 := cell_x(lo)
	var x1 := cell_x(hi)
	var span := x1 - x0
	# A SMALL, tight glow that hugs the flames (scale ~1.0-1.3 → ~128-166px radius), not the
	# old floor-flooding 2.4-3.4. Only light as many points as the span is wide, so a small
	# fire is a single localised pool and a floor-wide blaze gets a few spaced glows.
	var base_energy: float = 0.7 if stage >= STAGE_BLAZE else 0.5
	var glow_scale: float = 1.3 if stage >= STAGE_BLAZE else 1.0
	var want: int = clampi(int(round(span / FIRE_LIGHT_SPACING)), 1, _fire_lights.size())
	for i in range(_fire_lights.size()):
		var lt: PointLight2D = _fire_lights[i]
		if i >= want:
			lt.energy = 0.0            # unused this frame — keep dark, don't wash the floor
			continue
		var f: float = 0.5 if want == 1 else float(i) / float(want - 1)
		lt.position = Vector2(lerpf(x0, x1, f), FIRE_BASE_Y - 34.0)
		lt.texture_scale = glow_scale
		# Per-light flicker, out of phase, plus a little jitter.
		var flick: float = 0.80 + 0.16 * sin(_t * 11.0 + float(i) * 1.7) + randf_range(-0.05, 0.05)
		lt.energy = base_energy * flick


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
	extinguish_span(x - radius, x + radius)


func extinguish_span(x0: float, x1: float) -> void:
	# A blast of extinguisher over [x0, x1]: put out only the cells that were actually BURNING,
	# turning them SPENT (ash + smoke — the AFTERMATH marks where fire WAS, not where the spray
	# landed). A COOL cell in the blast is left untouched, so spraying bare floor leaves NO
	# fake ash/smoke. The burnt-out (SPENT) cells act as firebreaks, so the doused patch
	# can't re-ignite from a neighbour. The stairwell's fire is its zone's cells, so a spray
	# at the stairs puts that out too (see stair_fire_lit).
	var r := _cells_in(x0, x1)
	for i in range(r.x, r.y + 1):
		if state_of(i) == BURNING:
			heat[i] = 0.0
			fuel[i] = 0.0


# The cells a world-x RANGE actually overlaps, as Vector2i(first, last) — (0, -1) (an empty loop)
# when the range lies wholly off the fire span. The clamped cell_at() snapped an off-span range onto
# the edge cell, so a spray aimed past the end of the corridor still doused the end cell, and a
# door decal past the span read the edge cell as "burning near" (same bug class as the old
# is_burning_at clamp — see cell_of_unclamped).
func _cells_in(x0: float, x1: float) -> Vector2i:
	var a := cell_of_unclamped(minf(x0, x1))
	var b := cell_of_unclamped(maxf(x0, x1))
	if b < 0 or a >= cell_count:
		return Vector2i(0, -1)
	return Vector2i(maxi(a, 0), mini(b, cell_count - 1))


func cell_of_unclamped(x: float) -> int:
	# Which cell does x fall in, WITHOUT clamping — returns -1 (or >= cell_count) when x is
	# OUTSIDE the fire span. cell_at() clamps AND truncates toward zero, so any x just left of
	# FIRE_MIN_X collapsed onto cell 0; state_of(cell_at(x)) then read the edge cell as
	# "burning" for the whole run-off past the ends of the fire. That phantom made ENEMIES burn
	# to death (and leave corpses) standing LEFT of the flames while the player — saved by the
	# DAMAGE_REACH distance guard — took no damage there (owner: "no damage on the left, but
	# corpses appeared"). floori() (not int()) so a fractional-negative offset lands OUT of range.
	return floori((x - FIRE_MIN_X) / CELL_W)


func is_burning_at(x: float) -> bool:
	# Inside the down-stairwell zone the corridor fire isn't drawn — the only flames there are the
	# stairwell's own, in the shaft — so that's the only place there that burns (what you see is
	# what hurts: no invisible fire beside the stairs).
	if _in_stair_keepout(x):
		return stair_fire_lit() and absf(x - _stair_fire_x) <= _stair_half + STAIR_HEAT_MARGIN
	var i := cell_of_unclamped(x)
	return i >= 0 and i < cell_count and state_of(i) == BURNING


# How close (px) the player must be to a VISIBLE flame to take the burn. Tight — a
# player standing anywhere in a burning tile cell (42px wide) is within this of its
# centre, but a step off the fire is not.
const DAMAGE_REACH := 26.0


func fire_hot_at(x: float) -> bool:
	# Player-damage test (see building_floors fire damage): the player burns when they're
	# standing IN a burning cell — SYMMETRIC with is_burning_at (the enemy-burn test), so
	# anything that cooks an enemy also cooks the player and vice-versa. The old version used
	# the CLAMPED, truncating cell_at() plus a DAMAGE_REACH distance guard; the clamp+truncation
	# put the left approach into a dead-zone where enemies burned but the player didn't (owner:
	# "no damage on the left"). Now: burn iff the player's OWN (unclamped) cell is a BURNING cell
	# — the SAME rule is_burning_at applies to enemies (42px cell granularity: in the flames or
	# not). Off the fire span → never cooked, for player and enemy alike.
	return is_burning_at(x)


func any_burning() -> bool:
	for i in range(cell_count):
		if state_of(i) == BURNING:
			return true
	return false


func burning_near(x: float, radius: float) -> bool:
	# True if any cell within `radius` px of x is BURNING. Used to clear door-frame flames
	# the moment the corridor fire beside that door is doused — so nothing burns where the
	# fire is out.
	var r := _cells_in(x - radius, x + radius)
	for i in range(r.x, r.y + 1):
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
	_update_fire_lights()
	_smoke_sync_t -= delta
	if _smoke_sync_t <= 0.0:
		_smoke_sync_t = 0.25
		_sync_smoke()
	queue_redraw()


# --- SMOKE (scripts/soft_smoke.gd): soft particle smoke, one emitter per pair of cells ----------
# Burning cells smoke dark and steady; a stretch you DOUSE billows once (a pale burst) and then
# smoulders thinly; a charred ruin smoulders. Replaces the smoke-sprite stamps (small, hard,
# dark-outlined blobs — they read as black circles) and the old "no smoke off spent ground" rule
# (owner round 8: the aftermath had "no smoke really" and looked very ugly).
const SOFT_SMOKE := preload("res://scripts/soft_smoke.gd")
var _smoke_nodes: Dictionary = {}
var _smoke_sync_t: float = 0.0
var _smoke_synced_once: bool = false
var _back_layer: Node2D = null


func _smoke_wanted() -> Dictionary:
	var wanted := {}
	var i := 0
	var pair := 0
	while i < cell_count:
		var burning := false
		var spent := false
		for j in [i, i + 1]:
			if j < cell_count:
				var st := state_of(j)
				if st == BURNING:
					burning = true
				elif st == SPENT:
					spent = true
		var cx: float = cell_x(i) + (CELL_W * 0.5 if i + 1 < cell_count else 0.0)
		if (burning or spent) and not _in_stair_keepout(cx):
			wanted[pair] = {"kind": "fire" if burning else "smoulder", "x": cx, "y": FIRE_BASE_Y - 8.0, "w": CELL_W * 2.0}
		i += 2
		pair += 1
	return wanted


func _sync_smoke() -> void:
	if _back_layer == null or not is_instance_valid(_back_layer):
		return
	SOFT_SMOKE.sync(_back_layer, _smoke_nodes, _smoke_wanted(), not _smoke_synced_once)
	_smoke_synced_once = true


# --- render (layered pixel flames + additive glow + choking smoke) ----------
# The fire draws across FOUR CanvasItems so the player stands INSIDE it:
#   z0  back-wall flames (dim, small — depth behind the actors)
#   z1  the field itself: the main flames at floor level (with the actors)
#   z2  an ADDITIVE glow + foreground licks (this is what makes it POP)
#   z4  smoke, pooling from the ceiling down (choking — crouch under it)
# Flames scale with the stage (small on a LIGHT fire, big on a BLAZE); smoke
# sinks to head height on a BLAZE. The flicker is cosmetic; the sim is elsewhere.

# --- the fire's art (tools/art/fire.py → assets/fire/, scripts/fire_art.gd) --------------------------------------
# Drawn 1:1 from our own strips. Beds are tapered CLUMPS (each fades to nothing at both ends) laid overlapping along the
# burning span, so the carpet is continuous yet no sprite is ever cropped or cut by a cell edge; single tongues rise from
# it; a blaze climbs the walls. Everything is drawn through FireArt (unshaded — a fire is its own light).
const SMOKE_FRAMES := 6
const SMOKE_FPS := 8.0
const CHAR_COL := Color(0.09, 0.08, 0.08)
const FIRE_LAYER := preload("res://scripts/fire_layer.gd")
const CLUMP_STEP := 34.0            # bed clumps are 64 wide; laid this far apart they overlap into one carpet


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
		lyr.material = FireArt.material()
		add_child(lyr)
		if int(spec[0]) == LYR_BACK:
			_back_layer = lyr            # the smoke emitters rise from here, behind the actors


func draw_layer(canvas: CanvasItem, which: int) -> void:
	match which:
		LYR_BACK: _draw_back(canvas)
		LYR_FRONT: _draw_front(canvas)
		LYR_SMOKE: _draw_smoke(canvas)


func _hash01(a: float) -> float:
	# Cheap deterministic pseudo-random in [0,1) for organic (non-uniform) jitter.
	return fmod(absf(sin(a * 12.9898) * 43758.5453), 1.0)




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

# HARD BUILDING BORDERS (the blue lines): the corridor's left/right walls. Nothing —
# fire, smoke, globs — may be drawn beyond these. The WorldBoundary colliders (where the
# player physically stops) sit at 128 / 1224; we inset the fire a few px INSIDE them so a
# flame never even touches the wall face, let alone overlaps it.
const BORDER_L := 138.0
const BORDER_R := 1214.0


func _draw_clipped(canvas: CanvasItem, tex: Texture2D, dst: Rect2, src: Rect2, col: Color) -> void:
	# Draw a texture region CLIPPED to the building borders, so no pixel of fire crosses the
	# blue lines. Fully out of bounds → nothing; partly out → the dst is trimmed and the src
	# trimmed proportionally so the sprite is cropped, not squashed.
	if tex == null or dst.size.x <= 0.0:
		return
	var l: float = dst.position.x
	var r: float = dst.position.x + dst.size.x
	if r <= BORDER_L or l >= BORDER_R:
		return
	var nl: float = maxf(l, BORDER_L)
	var nr: float = minf(r, BORDER_R)
	if nr <= nl:
		return
	var fl: float = (nl - l) / dst.size.x
	var fr: float = (nr - l) / dst.size.x
	var ndst := Rect2(nl, dst.position.y, nr - nl, dst.size.y)
	var nsrc := Rect2(src.position.x + fl * src.size.x, src.position.y, (fr - fl) * src.size.x, src.size.y)
	canvas.draw_texture_rect_region(tex, ndst, nsrc, col)


func _near_door(x: float) -> bool:
	for apt in WorldState.APARTMENT_X:
		if absf(x - float(WorldState.APARTMENT_X[apt])) < DOOR_AVOID_HALF:
			return true
	return false


# The down-stairwell has its OWN fire, confined to the shaft box. The corridor fire (floor
# beds + tall flames + scatter) must NOT draw anywhere in the stairwell zone, or it spills
# beside/over the shaft. That zone is [_stair_keep_lo, _stair_keep_hi].
func _in_stair_keepout(cx: float) -> bool:
	return _stair_keep_hi > _stair_keep_lo and cx >= _stair_keep_lo and cx <= _stair_keep_hi


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
	# Three MUTUALLY-EXCLUSIVE planes in 2-cell clumps, so nothing ever overlaps anything:
	#   1 = BACK-seam tile, 0 = FRONT-floor tile, 2 = GAP (a glob rises here, no tile under it).
	# The gap clumps are the ONLY place tall flames go, so a glob never sits over a tile bed.
	if h < 0.33:
		return 1
	elif h < 0.66:
		return 0
	return 2


func _is_glob_cell(cx: float) -> bool:
	# A GAP cell that isn't a doorway — the free space where globs may rise (tiles aren't
	# visible here, and we keep globs off doors so entrances stay clear).
	return _cell_kind(cx) == 2 and not _near_door(cx)




# --- the floor fire, drawn from our own strips (FireArt) ------------------------------------------------------------
# Pure layout first (so the tests can read what would draw), then the draw calls. Each entry: {x, name, phase}.
func bed_spots(layer: String) -> Array:
	# BED CLUMPS along the burning span ("front": in front of the player's feet, "back": along the wall seam behind
	# them). Clumps are 64 wide and taper to nothing at both ends, laid CLUMP_STEP apart so they overlap into one carpet —
	# a clump is only ever drawn whole (never cropped by a cell edge). Not across a doorway or in the stair zone.
	var out: Array = []
	if stage >= STAGE_CHARRED:
		return out
	var kind: String = "blaze" if stage >= STAGE_BLAZE else "light"
	var names: Array = FireArt.variants("bed_%s_%s" % [layer, kind])
	if names.is_empty():
		return out
	var salt: float = 1.7 if layer == "front" else 5.3
	var x := FIRE_MIN_X + 10.0
	var idx := 0
	while x <= FIRE_MAX_X - 10.0:
		var sd := float(idx) * 3.17 + float(floor_num) * 0.83 + salt
		var cx := x + (_hash01(sd) - 0.5) * CLUMP_STEP * 0.4
		idx += 1
		x += CLUMP_STEP
		if not is_burning_at(cx) or _near_door(cx) or _in_stair_keepout(cx):
			continue
		# the back seam carpet is patchier (depth: not a solid line along the wall)
		if layer == "back" and _hash01(sd * 2.3) < 0.28:
			continue
		out.append({"x": cx, "name": names[int(_hash01(sd * 1.9) * float(names.size())) % names.size()], "phase": _hash01(sd * 4.3)})
	return out


func tongue_spots() -> Array:
	# Single flames rising from the bed, spaced so each reads as its own tongue (a minimum gap a little over the widest
	# sprite drawn); bigger ones on a blaze. [{x, name, phase}]
	var out: Array = []
	if stage >= STAGE_CHARRED:
		return out
	var big := stage >= STAGE_BLAZE
	var min_gap := 70.0 if big else 62.0
	var last_x := -1.0e9
	var x := FIRE_MIN_X + 16.0
	while x <= FIRE_MAX_X - 16.0:
		if is_burning_at(x) and not _near_door(x) and not _in_stair_keepout(x) and (x - last_x) >= min_gap:
			var sd := float(floori(x / 21.0)) + float(floor_num) * 0.7
			var roll := _hash01(sd * 1.9)
			var size := "s"
			if big:
				size = "xl" if roll > 0.86 else ("l" if roll > 0.5 else "m")
			else:
				size = "m" if roll > 0.72 else "s"
			var names: Array = FireArt.variants("tongue_" + size)
			if not names.is_empty():
				out.append({"x": x, "name": names[int(_hash01(sd * 1.3) * float(names.size())) % names.size()], "phase": _hash01(sd * 2.9)})
				last_x = x
		x += 21.0
	return out


func _draw_tall_flames(canvas: CanvasItem) -> void:
	# every tongue stands on a low bed of coals (a back carpet clump under it), so no flame ever ends in a flat, cut-off base
	var kind: String = "blaze" if stage >= STAGE_BLAZE else "light"
	var beds: Array = FireArt.variants("bed_back_" + kind)
	for sp in tongue_spots():
		var x: float = float(sp["x"])
		if not beds.is_empty():
			FireArt.draw(canvas, str(beds[int(_hash01(x * 0.11) * float(beds.size())) % beds.size()]), _t, float(sp["phase"]) + 0.5, Vector2(x, FIRE_BASE_Y - 1.0), 0.95)
		FireArt.draw(canvas, str(sp["name"]), _t, float(sp["phase"]), Vector2(x, FIRE_BASE_Y - 3.0))


# --- fire on the WALLS (owner follow-up: "flames on walls/ceiling/doors — corridor flames only today"; the
# door frames already burn, `fire_decal.gd`). Only a BLAZE climbs: tall tongues run UP the wall from the seam
# over the burning cells, behind the actors (z0), never across a doorway or the stair zone, spaced by a
# minimum gap so they read as distinct tongues, and seeded per floor so none move in step. (A ceiling
# version — the same sprites hung upside-down — was tried and dropped: lost in the smoke band it read as
# stray brown chunks. The ceiling gets its fire from the smoke + the soot scars instead.)
const WALL_FIRE_GAP := 104.0


func wall_fire_spots() -> Array:
	# [{x, name, phase}] — pure (no drawing), so the test can read what would draw.
	var out: Array = []
	if stage < STAGE_BLAZE:
		return out
	var names: Array = FireArt.variants("wall")
	if names.is_empty():
		return out
	var last_w := -1.0e9
	var x := FIRE_MIN_X + 30.0
	while x <= FIRE_MAX_X - 30.0:
		if is_burning_at(x) and not _near_door(x) and not _in_stair_keepout(x):
			var sd := float(floori(x / 21.0)) + float(floor_num) * 1.3
			if (x - last_w) >= WALL_FIRE_GAP and _hash01(sd * 2.7) > 0.30 and _cell_kind(x) != 2:
				out.append({"x": x, "name": names[int(_hash01(sd * 3.3) * float(names.size())) % names.size()], "phase": _hash01(sd * 1.7)})
				last_w = x
		x += 21.0
	return out


func _draw_wall_fire(canvas: CanvasItem) -> void:
	for sp in wall_fire_spots():
		FireArt.draw(canvas, str(sp["name"]), _t, float(sp["phase"]), Vector2(float(sp["x"]), BACK_SEAM_Y - 6.0), 0.95)


func _char_scar(canvas: CanvasItem, i: int, cx: float) -> void:
	# Where the fire burnt out: thin ragged SOOT STREAKS along the floor + a few ash flecks. Never
	# blobs — opaque circles, then flat ellipses, both read as rows of black balls (owner round 8).
	SOFT_SMOKE.draw_soot(canvas, cx, FIRE_BASE_Y - 1.0, CELL_W, float(i) * 3.1 + float(floor_num) * 0.37)


func _draw_scorch(canvas: CanvasItem) -> void:
	for i in range(cell_count):
		if state_of(i) == SPENT and not _in_stair_keepout(cell_x(i)):
			_char_scar(canvas, i, cell_x(i))


func _draw() -> void:
	# The field itself (z1, the actors' layer) draws nothing: scorch lies on the floor BEHIND the
	# actors (back layer), the fire sprites on the depth layers so the player sits amongst them.
	pass


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
	_draw_scorch(canvas)            # burnt-out floor first, under everything
	for sp in bed_spots("back"):                     # the carpet along the wall seam, behind the player (depth)
		FireArt.draw(canvas, str(sp["name"]), _t, float(sp["phase"]), Vector2(float(sp["x"]), BACK_SEAM_Y), 0.92)
	_draw_stair_fire(canvas)        # the THIRD plane — fire on the down-stairwell top step
	_draw_tall_flames(canvas)
	_draw_wall_fire(canvas)         # a blaze climbs the walls
	# Smoke is the soft particle emitters under this layer (_sync_smoke) — no sprite plumes.


# --- the third plane: fire on the DOWN stairwell -------------------------------
# building_floors hands us the x of the down-stairwell's top step; we draw a small
# bed + flame there, at the STEP's Y (above the corridor floor line), so the fire
# reads as spilling onto the stairs themselves. Only while the floor still has live
# fire (a doused/charred floor shows none). -1 = no stair fire on this floor.
var _stair_fire_x: float = -1.0    # shaft CENTRE x (the down-stairwell)
var _stair_half: float = 16.0      # half the shaft width — fire never crosses these x bounds
var _stair_keep_lo: float = 0.0    # corridor fire is excluded across [lo, hi] (the whole stair zone)
var _stair_keep_hi: float = -1.0
# The owner's red HORIZONTAL line — the fire's BASE sits exactly here; flames rise up from
# it into the stairwell shaft (never below it). Confirmed against the editor ruler.
const STAIR_BASE_Y := 415.0


# How far past the shaft's edges its flames still burn you (they lick a little wider than the box).
const STAIR_HEAT_MARGIN := 8.0


func set_stair_fire(cx: float, half: float = 26.0, keep_lo: float = 0.0, keep_hi: float = -1.0) -> void:
	_stair_fire_x = cx
	_stair_half = half
	_stair_keep_lo = keep_lo
	_stair_keep_hi = keep_hi


func stair_fire_lit() -> bool:
	# The stairwell burns when the fire has actually REACHED it: one of the cells in its zone is
	# burning. (It used to draw whenever ANYTHING on the floor burned — so it lit up with the fire
	# 400px away, and spraying it did nothing: owner playtest, "didn't put the flames out… near a
	# stairwell". Now it catches when the fire spreads to it and goes out when you douse it.)
	if _stair_fire_x < 0.0:
		return false
	for i in range(cell_count):
		if _in_stair_keepout(cell_x(i)) and state_of(i) == BURNING:
			return true
	return false


func _draw_stair_fire(canvas: CanvasItem) -> void:
	# Fire INSIDE the stairwell box: base on STAIR_BASE_Y (the red horizontal line), flames rising UP into the shaft,
	# strictly within [cx-half, cx+half] on x (the red verticals). The corridor fire is kept out of the whole stair zone.
	# Drawn whole from our strips (a bed clump + a tongue or two), never cropped: the clump is narrower than the shaft.
	if _stair_fire_x < 0.0 or not stair_fire_lit():
		return
	var l: float = maxf(_stair_fire_x - _stair_half, BORDER_L)   # never past the blue borders
	var r: float = minf(_stair_fire_x + _stair_half, BORDER_R)
	if r - l <= 0.0:
		return
	var cx := (l + r) * 0.5
	FireArt.draw(canvas, "stair", _t, _hash01(float(floor_num) * 1.3), Vector2(cx, STAIR_BASE_Y))
	var size := "m" if stage >= STAGE_BLAZE else "s"
	var names: Array = FireArt.variants("tongue_" + size)
	if not names.is_empty():
		var fw: float = FireArt.frame_size(str(names[0])).x
		var span: float = maxf(0.0, (r - l) - fw)
		for k in range(2):
			var tx: float = l + fw * 0.5 + span * (0.25 + 0.5 * float(k))
			FireArt.draw(canvas, str(names[(k + floor_num) % names.size()]), _t, _hash01(float(k) * 3.1 + float(floor_num)), Vector2(tx, STAIR_BASE_Y - 2.0))


func has_smoulder() -> bool:
	# True if any cell is a doused/charred (SPENT) ruin — i.e. there's smoke to show
	# even though nothing is actively BURNING. Drives the HUD haze on a charred floor.
	for i in range(cell_count):
		if state_of(i) == SPENT:
			return true
	return false



func _draw_front(canvas: CanvasItem) -> void:
	# IN FRONT of the actors (z2): the floor carpet of flame, so the player stands IN it (engulfed to the legs, walks
	# THROUGH it) — the clump height (18 px light / 33 blaze) is feet-to-waist, never the neck. Whole clumps, never cropped.
	for sp in bed_spots("front"):
		FireArt.draw(canvas, str(sp["name"]), _t, float(sp["phase"]), Vector2(float(sp["x"]), FIRE_BASE_Y - 1.0))


func _draw_smoke(_canvas: CanvasItem) -> void:
	# World-space smoke clouds have been REMOVED (they read as black pulsing circles).
	# The only smoke effect now is a subtle gradual screen HAZE driven by the HUD from
	# smoke_intensity() (see building_floors._process / HUD.set_smoke_fog). Proper
	# smoke art will slot in here later. Left as a no-op so the z4 layer draws nothing.
	pass
