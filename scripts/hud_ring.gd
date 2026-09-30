extends Control

# The HEALTH RING round the portrait (corner-cluster HUD, owner round 26). ONE thin continuous arc
# (owner: "too many green nodes around the player icon" — it was ten separate pips), swept clockwise
# from the top for the share of health left (the portrait's stage 0 Healthy .. 5 Dying → 10/8/6/4/2/1
# tenths). It is QUIET when healthy — a muted, half-transparent ring — and only gets loud as you get
# hurt (amber → orange → red); the last two stages pulse like a heartbeat. Pure display: never takes
# the mouse (the portrait inside is the button).

const SEGMENTS := 10                                # tenths of the ring (the stage table below)
const RADIUS := 46.0
const STROKE := 5.0
const LIT_BY_STAGE := [10, 8, 6, 4, 2, 1]
const COLOURS := [Color(0.50, 0.66, 0.52, 0.55), Color(0.78, 0.76, 0.42, 0.9), Color(0.93, 0.72, 0.3, 1.0),
	Color(0.94, 0.5, 0.28, 1.0), Color(0.9, 0.3, 0.26, 1.0), Color(0.86, 0.2, 0.22, 1.0)]
const EMPTY := Color(0.17, 0.16, 0.18, 0.7)

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
	var col: Color = COLOURS[stage]
	if stage >= 4:
		col = col.lerp(Color(1, 1, 1, 1), 0.18 * (0.5 + 0.5 * sin(_pulse_t * (6.0 if stage == 5 else 4.0))))
	# the track, then ONE arc for what's left (clockwise from the top)
	draw_arc(c, RADIUS, 0.0, TAU, 96, EMPTY, STROKE, true)
	var frac: float = float(lit_segments()) / float(SEGMENTS)
	draw_arc(c, RADIUS, -PI * 0.5, -PI * 0.5 + TAU * frac, maxi(int(96.0 * frac), 6), col, STROKE, true)
	if hot:
		draw_arc(c, RADIUS + STROKE * 0.5 + 3.0, 0.0, TAU, 64, Color(1, 1, 1, 0.85), 2.0, true)
