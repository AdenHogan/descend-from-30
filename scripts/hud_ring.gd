extends Control

# The segmented HEALTH RING round the portrait (corner-cluster HUD, owner round 26). Ten pips,
# lit by the portrait's stage (0 Healthy .. 5 Dying) and coloured by how bad it is; the last two
# stages pulse like a heartbeat. Pure display: never takes the mouse (the portrait inside is the button).

const SEGMENTS := 10
const RADIUS := 54.0
const STROKE := 8.0
const GAP := 0.10                                   # radians left open between pips
const LIT_BY_STAGE := [10, 8, 6, 4, 2, 1]
const COLOURS := [Color(0.47, 0.76, 0.44), Color(0.72, 0.8, 0.4), Color(0.93, 0.72, 0.3),
	Color(0.94, 0.5, 0.28), Color(0.9, 0.3, 0.26), Color(0.86, 0.2, 0.22)]
const EMPTY := Color(0.17, 0.16, 0.18, 0.95)

var stage: int = 0
var hot: bool = false
var _pulse_t: float = 0.0


func set_stage(s: int) -> void:
	stage = clampi(s, 0, LIT_BY_STAGE.size() - 1)
	set_process(stage >= 4)
	queue_redraw()


func set_hot(on: bool) -> void:
	hot = on
	queue_redraw()


func lit_segments() -> int:
	return int(LIT_BY_STAGE[stage])


func _ready() -> void:
	set_process(stage >= 4)


func _process(delta: float) -> void:
	# Real time, so the heartbeat keeps its beat while the quick wheel slows the game down.
	_pulse_t += delta / maxf(Engine.time_scale, 0.05)
	queue_redraw()


func _draw() -> void:
	var c: Vector2 = size * 0.5
	draw_circle(c, RADIUS - STROKE * 0.5, Color(0.07, 0.065, 0.08, 0.9))
	var lit: int = lit_segments()
	var col: Color = COLOURS[stage]
	if stage >= 4:
		col = col.lerp(Color(1, 1, 1, 1), 0.18 * (0.5 + 0.5 * sin(_pulse_t * (6.0 if stage == 5 else 4.0))))
	var per: float = TAU / float(SEGMENTS)
	for i in range(SEGMENTS):
		var a0: float = -PI * 0.5 + float(i) * per + GAP * 0.5
		var a1: float = -PI * 0.5 + float(i + 1) * per - GAP * 0.5
		draw_arc(c, RADIUS, a0, a1, 10, col if i < lit else EMPTY, STROKE, true)
	if hot:
		draw_arc(c, RADIUS + STROKE * 0.5 + 3.0, 0.0, TAU, 64, Color(1, 1, 1, 0.85), 2.0, true)
