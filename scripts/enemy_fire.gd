extends Node2D

# FLAMES CLINGING TO A BURNING ENEMY (owner round 30: "the globs of fire on the body are a bit big — smaller, more flashier,
# that then consume just like the current consume-enemies-by-fire system"). Purely cosmetic — the gameplay (double damage + burn
# DoT until it dies) lives on the enemy. Added as a child at the torso when it catches, removed when it steps clear OR dies (the
# parent enemy clears it). NO collision/physics — it never blocks the player.
#
# Now a flurry of SMALL licks instead of three big globs: each is the purchased-fire `small_<v>` strip at NATIVE size (11x17 px —
# half the old 22x34), popping up at a random spot on the body, flickering fast for a fraction of a second, then guttering out and
# re-lighting somewhere else, with a few embers lifting off. The longer the enemy has been alight the more of them there are and the
# faster they churn (`FLAMES_START` -> `FLAMES_MAX` over `BUILD_TIME`) — it is being consumed — and the whole thing is unshaded so a
# burning body glows even in the night-dark.

const FLAMES_START := 3
const FLAMES_MAX := 6
const BUILD_TIME := 4.0             # seconds alight to reach the full flurry (the burn kills a standard zombie in a few ticks)
const LIFE_MIN := 0.28
const LIFE_MAX := 0.62
const FLASH := 0.07                 # a lick's first / last moments show only its base (it flares up / gutters out)
const ANIM_SPEED := 1.9             # the strips' own 10 fps, run faster so it flickers
const EMBER_MAX := 7
const BODY_X := 11.0                # flames may stand this far either side of the torso line
const BODY_Y_TOP := -24.0           # base heights on the body, relative to the fx origin (the torso): shoulders…
const BODY_Y_BOT := 32.0            # …to the knees

var _t: float = 0.0
var _rng := RandomNumberGenerator.new()
var _flames: Array = []             # {pos: Vector2 (base), v: String, ph: float, flip: bool, born: float, life: float}
var _embers: Array = []             # {pos: Vector2, vel: Vector2, life: float, age: float, hot: bool}
var _ember_acc: float = 0.0


func _ready() -> void:
	z_index = 2
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST      # crisp pixels, no blur
	material = FireArt.material()
	_rng.seed = hash(get_instance_id()) ^ 0x5F3A
	for i in range(FLAMES_MAX):
		_flames.append(_new_flame(-_rng.randf() * LIFE_MAX))     # staggered so they don't all pop together


## How many licks are up right now (grows the longer it has been alight).
func flame_count() -> int:
	return FLAMES_START + int(floor(clampf(_t / BUILD_TIME, 0.0, 1.0) * float(FLAMES_MAX - FLAMES_START) + 0.0001))


func _new_flame(born: float) -> Dictionary:
	var churn: float = 1.0 - 0.35 * clampf(_t / BUILD_TIME, 0.0, 1.0)         # later flames live shorter: it churns faster
	return {
		"pos": Vector2(_rng.randf_range(-BODY_X, BODY_X), _rng.randf_range(BODY_Y_TOP, BODY_Y_BOT)),
		"v": "small_%d" % _rng.randi_range(1, 3),
		"ph": _rng.randf(),
		"flip": _rng.randf() < 0.5,
		"born": born,
		"life": _rng.randf_range(LIFE_MIN, LIFE_MAX) * churn,
	}


func _process(delta: float) -> void:
	_t += delta
	for i in range(_flames.size()):
		var f: Dictionary = _flames[i]
		if _t >= float(f["born"]) + float(f["life"]):
			_flames[i] = _new_flame(_t)
	# embers: a few sparks lifting off the body
	_ember_acc += delta * (5.0 + 8.0 * clampf(_t / BUILD_TIME, 0.0, 1.0))
	while _ember_acc >= 1.0:
		_ember_acc -= 1.0
		if _embers.size() < EMBER_MAX:
			_embers.append({
				"pos": Vector2(_rng.randf_range(-BODY_X, BODY_X), _rng.randf_range(BODY_Y_TOP, BODY_Y_BOT * 0.4)),
				"vel": Vector2(_rng.randf_range(-7.0, 7.0), _rng.randf_range(-34.0, -18.0)),
				"life": _rng.randf_range(0.4, 0.8), "age": 0.0, "hot": _rng.randf() < 0.5})
	var keep: Array = []
	for e in _embers:
		e["age"] = float(e["age"]) + delta
		e["pos"] = Vector2(e["pos"]) + Vector2(e["vel"]) * delta
		if float(e["age"]) < float(e["life"]):
			keep.append(e)
	_embers = keep
	queue_redraw()


func _draw() -> void:
	var n: int = flame_count()
	for i in range(mini(n, _flames.size())):
		var f: Dictionary = _flames[i]
		var age: float = _t - float(f["born"])
		if age < 0.0:
			continue
		_lick(f, age)
	for e in _embers:
		var k: float = 1.0 - float(e["age"]) / float(e["life"])
		var p: Vector2 = Vector2(e["pos"]).round()
		var col: Color = Color(1.0, 0.86, 0.35, k) if bool(e["hot"]) else Color(1.0, 0.5, 0.12, k)
		draw_rect(Rect2(p, Vector2(1, 1) if k < 0.45 else Vector2(2, 2)), col)


## One small lick. Its first and last moments show only the base of the flame (flaring up / guttering out), and it rises a hair as it goes.
func _lick(f: Dictionary, age: float) -> void:
	var s: Dictionary = FireArt.sheet(str(f["v"]))
	if s.is_empty():
		return
	var fw: float = float(s["fw"])
	var fh: float = float(s["fh"])
	var life: float = float(f["life"])
	var show: float = 1.0
	if age < FLASH:
		show = 0.45 + 0.55 * age / FLASH
	elif age > life - FLASH:
		show = 0.35 + 0.65 * maxf(0.0, life - age) / FLASH
	var rows: float = maxf(2.0, roundf(fh * show))
	var fr: int = FireArt.frame_at(_t * ANIM_SPEED, float(f["ph"]), int(s["frames"]))
	var base: Vector2 = Vector2(f["pos"]) + Vector2(0.0, -roundf(age * 6.0))
	var x: float = roundf(base.x - fw * 0.5)
	var dst := Rect2(x + (fw if bool(f["flip"]) else 0.0), roundf(base.y) - rows, -fw if bool(f["flip"]) else fw, rows)
	draw_texture_rect_region(s["tex"], dst, Rect2(float(fr) * fw, fh - rows, fw, rows))
