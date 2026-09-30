extends Node2D

## The corridor's EXIT sign, alive (owner round 26 — motion pass). The sign itself is baked into the
## corridor art (tools/art/fixtures.exit_sign, always lit); this node makes it follow the building's
## decay, the way the sconces already do: it stays steady on healthy floors, STUTTERS on failing ones
## (a dark beat, a buzz), and on the worst goes DEAD (a dark face laid over it, its little green light
## gone). A live green PointLight2D rides with it — a tight pool that matters at night, when the sign
## is one of the few things still glowing. Deterministic per (floor, run): a sign that died in run 1
## stays dead in runs 2 and 3.

const RECT := Rect2(860, 40, 13, 11)            # the sign, in the corridor art's local space
const FACE_DEAD := Color(0.055, 0.085, 0.065, 0.96)
const FACE_RIM := Color(0.02, 0.04, 0.03, 1.0)

var state: String = "steady"                    # steady | flicker | dead
var lit: bool = true
var _t: float = 0.0
var _period: float = 4.0
var _phase: float = 0.0
var _light: PointLight2D = null


## "steady" / "flicker" / "dead" for a floor in a run. One seeded roll per FLOOR (not per run) against
## a threshold that only rises with depth and the run, so decay never un-happens.
static func state_for(floor_num: int, run: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(WorldState.master_seed) + "exitsign" + str(floor_num))
	var r: float = rng.randf()
	var bad: float = clampf(0.04 + WorldState.infection_depth(floor_num) * 0.30 + float(run - 1) * 0.20, 0.0, 0.75)
	if r < bad * 0.5:
		return "dead"
	if r < bad:
		return "flicker"
	return "steady"


func setup(floor_num: int, run: int) -> void:
	state = state_for(floor_num, run)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(WorldState.master_seed) + "exitsignphase" + str(floor_num))
	_period = rng.randf_range(3.2, 5.6)
	_phase = rng.randf() * _period
	z_index = 0
	_light = PointLight2D.new()
	_light.texture = load("res://scripts/floor_lighting.gd").light_texture()
	_light.color = Color(0.45, 1.0, 0.6)
	_light.energy = 0.0 if state == "dead" else 0.4
	_light.texture_scale = 0.2
	_light.position = RECT.position + RECT.size * 0.5
	add_child(_light)
	lit = state != "dead"
	set_process(state == "flicker")
	queue_redraw()


## Is a flickering sign lit at time t? Steady but for a stutter — three quick dropouts — once a period.
static func flicker_lit(t: float, period: float) -> bool:
	var b: float = fposmod(t, period)
	if b < 0.9:
		return int(b * 14.0) % 3 != 0
	return true


func _process(delta: float) -> void:
	_t += delta
	var on: bool = flicker_lit(_t + _phase, _period)
	if on != lit:
		lit = on
		if _light != null:
			_light.energy = 0.4 if on else 0.0
		queue_redraw()


func _draw() -> void:
	if lit:
		return
	draw_rect(RECT.grow(1.0), FACE_RIM)
	draw_rect(RECT, FACE_DEAD)
