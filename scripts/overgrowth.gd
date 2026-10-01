extends RefCounted

## OVERGROWTH — the building changing (owner round 26: "in lower level rooms we want actual overgrown
## areas… I want this to not just be monsters but the building changing").
##
## The outbreak isn't the only thing loose in the building: left alone, it is being taken back. Damp,
## no maintenance, no light — so growth follows DEPTH (the lower floors are far gone from the first
## morning) and TIME (every run, the same building reads greener). This file is the one place that says
## HOW MUCH; scripts/corridor_growth.gd and scripts/room_growth.gd say where and what.
##
## Everything is a pure function of (master_seed, floor[, apartment], run) — no state to save. What
## grew in run 1 is still there in run 2, with more added (the same prefix trick the corridor's
## horror decals use), and a floor / flat is always the same on re-entry.
##
##   level(floor, run)          0..1 across a corridor
##   room_level(floor, apt, run) the same for one flat — some are jungles, a few are still clear
##
## Fire wins: a floor that is burning or has burnt (WorldState.fire_intensity) grows nothing — the
## plants went up with everything else (a LIGHT fire only holds it back).

# Owner round 33: "The overgrowth in the building should not set in till at least floor 12. We need the top to still have an
# element of normalcy that changes and distorts and gets steadily worse… as we descend." Above GROWTH_TOP_FLOOR nothing wild
# grows (a resident's houseplant or a potted balcony shrub is normal life, not overgrowth); from it down the curve runs over
# just those floors, so floor 12 is barely touched and floor 1 is a jungle.
const GROWTH_TOP_FLOOR := 12
const DEPTH_POWER := 1.2
const FLOOR_BASE := 0.02
const DEPTH_SPAN := 0.58
const RUN_STEP := 0.12                 # per run after the first, scaled up with depth (see level())
const JITTER := 0.10                   # a floor is a little greener or barer than its depth says
const APT_SPREAD := 0.22


static func _rng(purpose: String, a: int, b: int = 0) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash(str(WorldState.master_seed) + "overgrowth" + purpose + str(a) + "/" + str(b))
	return r


## How overgrown floor `floor_num` is at `run` (1..3), 0..1. Nothing above floor 12; from there the lower floors are green
## from run 1 and a jungle by run 3.
static func level(floor_num: int, run: int) -> float:
	if floor_num >= 30 or floor_num < 1:
		return 0.0
	if WorldState.dev_overgrowth >= 0.0:
		return WorldState.dev_overgrowth                # the F1 menu's override, for looking at a level anywhere
	if floor_num > GROWTH_TOP_FLOOR:
		return 0.0
	var depth: float = float(GROWTH_TOP_FLOOR - floor_num + 1) / float(GROWTH_TOP_FLOOR)   # 1/12 at floor 12 → 1 at floor 1
	var jitter: float = _rng("floor", floor_num).randf_range(-JITTER, JITTER)
	var l: float = FLOOR_BASE + DEPTH_SPAN * pow(depth, DEPTH_POWER) + jitter * (0.4 + depth)
	l += RUN_STEP * float(maxi(run, 1) - 1) * (1.0 + depth * 1.2)
	l = clampf(l, 0.0, 1.0)
	# fire is read for the CURRENT run (that is what fire_intensity knows); asking about another run
	# — a preview, a test — gets the plain curve
	var fire: int = WorldState.fire_intensity(floor_num) if run == WorldState.current_run else -1
	if fire >= WorldState.FIRE_BLAZE:
		return 0.0                                     # burning or burnt out: nothing green left
	if fire >= WorldState.FIRE_LIGHT:
		l *= 0.4
	return l


## One flat's overgrowth: its floor's level, moved by the flat itself — a few are still clear (someone
## kept it up), a few are choked. Seeded per (floor, flat) only, so it doesn't change between runs
## except by the floor's own rise.
static func room_level(floor_num: int, apartment_id: String, run: int, fire_stage: int = -1) -> float:
	if fire_stage >= WorldState.FIRE_BLAZE:
		return 0.0                                     # this very flat has burnt (or is burning)
	var l: float = level(floor_num, run)
	if l <= 0.0:
		return 0.0
	var r := _rng("apt", floor_num, hash(apartment_id))
	var roll: float = r.randf()
	var shift: float = r.randf_range(-0.06, 0.06)
	if roll < 0.14:
		shift -= APT_SPREAD                            # kept up
	elif roll > 0.86:
		shift += APT_SPREAD                            # choked
	return clampf(l + shift, 0.0, 1.0)


## A human word for a level — for the journal / a character's line.
static func word(l: float) -> String:
	if l < 0.12:
		return "clear"
	if l < 0.35:
		return "creeping"
	if l < 0.65:
		return "overgrown"
	return "choked"
