extends Control

# The STAMINA BAR (owner round 26: "rather than separate bars, a single dynamic bar that depletes and
# fills… a sort of stamina recharge over time, using the maths we already have"). One continuous bar
# fed the SAME numbers as before (WorldState.stamina / get_max_stamina — nothing about the drain or the
# regen changed): the fill eases toward the true value so it visibly drains while you sprint and refills
# as it recharges; a lighter TAIL trails behind what you just spent and catches up after a beat; a soft
# highlight sweeps along the fill while it's recharging; and it warms to amber → red only as it runs low,
# pulsing when you're spent. Pure display; never takes the mouse.

const EASE_RATE := 9.0                    # how fast the fill follows the true value (per second)
const TAIL_DELAY := 0.28                  # seconds a spent chunk stays lit before the tail catches up
const TAIL_RATE := 4.0                    # how fast the tail closes on the fill once its delay is over (per second)
const LOW := 0.28                         # below this it warms
const SPENT := 0.12                       # below this it pulses

const TRACK := Color(0.09, 0.085, 0.10, 0.92)
const EDGE := Color(0.29, 0.275, 0.32, 1.0)
const CALM := Color(0.86, 0.80, 0.55, 1.0)          # a warm pale gold — not another green
const WARM := Color(0.93, 0.58, 0.22, 1.0)
const HOT := Color(0.90, 0.26, 0.22, 1.0)
const TAIL := Color(1.0, 0.95, 0.80, 0.55)

var target: float = 1.0                   # the true stamina fraction 0..1
var shown: float = 1.0                    # the eased fill
var tail: float = 1.0                     # the lagging "just spent" edge (>= shown)
var _tail_wait: float = 0.0
var _sweep: float = 0.0
var _pulse: float = 0.0
var _prev_target: float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func set_values(current: float, maximum: float) -> void:
	var t: float = clampf(current / maxf(maximum, 0.001), 0.0, 1.0)
	if t < target - 0.0005:
		_tail_wait = TAIL_DELAY                 # spending: hold the tail where it was
	_prev_target = target
	target = t
	queue_redraw()


func is_recharging() -> bool:
	return target > shown + 0.002


func is_spent() -> bool:
	return target < SPENT


## The fill colour for a stamina fraction: calm gold, warming to amber then red only as it runs low.
static func colour_for(frac: float) -> Color:
	if frac >= LOW:
		return CALM
	if frac >= SPENT:
		return WARM.lerp(CALM, clampf((frac - SPENT) / (LOW - SPENT), 0.0, 1.0))
	return HOT.lerp(WARM, clampf(frac / SPENT, 0.0, 1.0))


func _process(delta: float) -> void:
	# Real time: it must keep flowing while the quick wheel slows the game down.
	var dt: float = delta / maxf(Engine.time_scale, 0.05)
	var was: float = shown
	shown = lerpf(shown, target, clampf(dt * EASE_RATE, 0.0, 1.0))
	if absf(shown - target) < 0.0004:
		shown = target
	if _tail_wait > 0.0:
		_tail_wait -= dt
	else:
		tail = lerpf(tail, shown, clampf(dt * TAIL_RATE, 0.0, 1.0))
	if tail < shown:
		tail = shown
	if is_recharging():
		_sweep = fposmod(_sweep + dt * 0.9, 1.0)
	if is_spent():
		_pulse += dt * 5.0
	if absf(shown - was) > 0.00001 or tail > shown + 0.0005 or is_recharging() or is_spent():
		queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	draw_rect(Rect2(0, 0, w, h), TRACK)
	var fill_w: float = maxf((w - 2.0) * shown, 0.0)
	var tail_w: float = maxf((w - 2.0) * tail, 0.0)
	var col: Color = colour_for(shown)
	if is_spent():
		col = col.lerp(Color(1, 1, 1, 1), 0.22 * (0.5 + 0.5 * sin(_pulse)))
	if tail_w > fill_w + 0.5:
		draw_rect(Rect2(1.0 + fill_w, 1.0, tail_w - fill_w, h - 2.0), TAIL)
	if fill_w > 0.0:
		draw_rect(Rect2(1.0, 1.0, fill_w, h - 2.0), col)
		# a thin lighter top edge gives the bar volume without more colours
		draw_rect(Rect2(1.0, 1.0, fill_w, 1.0), Color(1, 1, 1, 0.22))
		if is_recharging():
			# the recharge sweep: a soft highlight travelling along the filled part
			var cx: float = 1.0 + fill_w * _sweep
			var half: float = 9.0
			var x0: float = maxf(cx - half, 1.0)
			var x1: float = minf(cx + half, 1.0 + fill_w)
			if x1 > x0:
				draw_rect(Rect2(x0, 1.0, x1 - x0, h - 2.0), Color(1, 1, 1, 0.22))
		# the leading edge
		draw_rect(Rect2(1.0 + fill_w - 1.0, 1.0, 1.0, h - 2.0), Color(1, 1, 1, 0.5))
	draw_rect(Rect2(0, 0, w, h), EDGE, false, 1.0)
