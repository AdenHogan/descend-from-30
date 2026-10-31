extends Node2D

# A small LIVE detail in a room module's art (owner round 19 — "a sprite animation showing a bottle
# of milk or something else on its side dripping milk down to the ground… active storytelling").
# Written into the module scene by tools/art (pixlib.anim → modscene `Anims`), one node per detail,
# drawn in pixels so it matches the art. Its timing is seeded by its position, so no two tick in step.
#   drip   — a drop swells here, lets go, falls `fall` px, splashes; the next one swells
#   drop   — the same, slow (an IV drip chamber: one drop every few seconds, a short fall)
#   blink  — a w×h light on / off (a standby LED, a cursor left blinking)
#   static — a w×h screen of TV snow, now and then a bar rolling down it (a set left on)
#   spin   — a glint going round a w×h ellipse (a record still turning on the platter)
#   flies  — a few flies buzzing about a w×h patch (over what's left in a breach room)
#   lava   — a lava lamp (owner round 49f): three blobs of wax (`color`) rising, stretching and sinking in a tapered w×h glass at their own slow paces;
#            on the NIGHT run it glows a little (`LAVA_GLOW_BY_RUN`: the wax is drawn unshaded and a small coloured light breathes with the blobs)
#   smoke  — a cigarette left in an ashtray: its tip glows and breathes at (0, 0) and a thread of smoke (`color`) curls up `h` px, swaying `w` px, in little puffs that fade
#   pendulum — a clock's pendulum: a rod `fall` px long hung from (0, 0) with a bob `w` px wide, swinging one way every second (a two-second period), the pivot fixed
#   tv     — a big flat screen, struck (owner round 22): snow under a spider-web CRACK from an impact
#            with a dead black patch round it and coloured lines bleeding down from it; now and then a
#            bright FLASH; every so often it goes badly wrong for a second — rows torn sideways, bars of
#            colour smeared across (the w×h screen from its top-left)
#
# SOUND (owner round 22 — "when getting closer to the TV that is on, there should be some very mild
# static, and with the turntable… a small bit of music playing, get caught, then loop back"): a screen
# (static / tv) hisses softly, only when you're close; the turning record (spin) plays its stuck ten
# seconds — the needle catches, a scratch, back to the start — across the module. Loudness follows
# the PLAYER's distance (not the camera's), fading out by `reach`. Silent on a passive backdrop.

const FloorLighting = preload("res://scripts/floor_lighting.gd")

const SOUNDS := {
	"static": ["res://assets/audio/ambience/tv_static.wav", -31.0, 24.0, 160.0],     # a LOW HUM, even up close (owner round 34)
	"tv": ["res://assets/audio/ambience/tv_static.wav", -31.0, 24.0, 160.0],
	"spin": ["res://assets/audio/ambience/record_stuck.wav", -9.0, 90.0, 330.0],
}   # kind -> [stream, loudest dB, full-volume radius px, silent past px]

var kind := "drip"
var fall := 20.0
var col := Color(0.95, 0.94, 0.89)
var w := 1
var h := 1
var _t := 0.0
var _period := 1.8
var _snow := 0.0
var _rng := RandomNumberGenerator.new()
var _sound: AudioStreamPlayer = null
var _loud := 0.0
var _near := 0.0
var _reach := 0.0
var _glow: PointLight2D = null

## How strongly a lava lamp glows by run (owner round 49f: "if it's a night run, the lava lamp can glow a bit"): none by day or at dusk, a modest coloured pool at night.
const LAVA_GLOW_BY_RUN := [0.0, 0.0, 0.0, 0.55]       # index = WorldState.current_run (1..3)
const LAVA_GLOW_SCALE := 0.26                         # the round cookie is 256 px: 0.26 -> a ~67 px pool, a bit more than the lamp's own height


func _ready() -> void:
	add_to_group("module_anim")
	kind = str(get_meta("kind", "drip"))
	fall = float(get_meta("fall", 20))
	col = Color(str(get_meta("color", "f2efe4")))
	w = maxi(1, int(get_meta("w", 1)))
	h = maxi(1, int(get_meta("h", 1)))
	var seed_ := absi(int(position.x * 7.0 + position.y * 13.0))
	_rng.seed = seed_
	match kind:
		"drop":
			_period = 3.2 + float(seed_ % 120) / 100.0
		"blink":
			_period = 0.9 + float(seed_ % 60) / 100.0
		"spin":
			_period = 1.8
		"static":
			_period = 4.0 + float(seed_ % 200) / 100.0
		"tv":
			_period = 11.0 + float(seed_ % 400) / 100.0
			_build_crack()
		_:
			_period = 1.5 + float(seed_ % 90) / 100.0
	_t = float(seed_ % 100) / 100.0 * _period
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if SOUNDS.has(kind) and not _in_backdrop():
		_start_sound(SOUNDS[kind])
	if kind == "lava":
		_start_glow()


## A screen under this live detail was switched off (open_furniture.gd, kind `screen_off`): the snow / the struck picture / the blinking light stops.
func screen_off(rect: Rect2) -> void:
	if kind in ["static", "tv", "blink"] and rect.has_point(global_position):
		visible = false
		set_process(false)
		if _sound != null:
			_sound.stop()
			_sound.queue_free()
			_sound = null


## Night: the wax is the lamp's own light, so it ignores the room's darkness, and a small coloured light sits in the glass.
func lava_glow_strength() -> float:
	return float(LAVA_GLOW_BY_RUN[clampi(int(WorldState.current_run), 0, LAVA_GLOW_BY_RUN.size() - 1)])


func _start_glow() -> void:
	if lava_glow_strength() <= 0.0:
		return
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
	if _in_backdrop():
		return                                           # a pan backdrop shows the lit wax, not a second light
	_glow = PointLight2D.new()
	_glow.name = "LavaGlow"
	_glow.texture = FloorLighting.light_texture()
	_glow.texture_scale = LAVA_GLOW_SCALE
	_glow.color = Color(minf(col.r * 1.15 + 0.1, 1.0), minf(col.g * 1.15 + 0.05, 1.0), minf(col.b * 1.15 + 0.1, 1.0))
	_glow.energy = lava_glow_strength()
	_glow.position = Vector2(float(w) * 0.5, float(h) * 0.5)
	add_child(_glow)


func _in_backdrop() -> bool:
	var n := get_parent()
	while n != null:
		if "passive" in n and bool(n.get("passive")):
			return true
		n = n.get_parent()
	return false


func _start_sound(spec: Array) -> void:
	var s = load(str(spec[0]))
	if not (s is AudioStream):
		return
	if s is AudioStreamWAV:
		var wav := s as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * float(wav.mix_rate))
	_loud = float(spec[1])
	_near = float(spec[2])
	_reach = float(spec[3])
	_sound = AudioStreamPlayer.new()
	_sound.name = "Sound"
	_sound.stream = s
	_sound.bus = "Master"
	_sound.volume_db = -80.0
	add_child(_sound)
	_sound.play(randf() * float(s.get_length()))     # two flats' records never in step


## 0..1: how loud this detail's sound is for a player at `at` (full inside `_near`, silent past `_reach`).
func sound_level(at: Vector2) -> float:
	if _reach <= 0.0:
		return 0.0
	var centre := global_position + Vector2(float(w), float(h)) * 0.5
	var d := at.distance_to(centre)
	var k := clampf((_reach - d) / maxf(1.0, _reach - _near), 0.0, 1.0)
	return k * k


func _update_sound() -> void:
	var player := get_tree().get_first_node_in_group("player")
	var k := 0.0
	if player is Node2D and is_visible_in_tree():
		k = sound_level((player as Node2D).global_position)
	_sound.volume_db = _loud + linear_to_db(maxf(k, 0.0001))


func _process(delta: float) -> void:
	_t = fmod(_t + delta, _period)
	_snow += delta
	if _sound != null:
		_update_sound()
	if _glow != null:
		_glow.energy = lava_glow_strength() * (0.85 + 0.15 * sin(_snow * 0.9 + float(position.x)))     # it breathes with the wax, no two lamps in step
	queue_redraw()


func _draw() -> void:
	match kind:
		"drip", "drop":
			_draw_drip()
		"blink":
			if _t < _period * 0.5:
				draw_rect(Rect2(0, 0, w, h), col)
		"static":
			_draw_static()
		"tv":
			_draw_tv()
		"flies":
			for i in range(5):
				var fi := float(i)
				var p := Vector2(sin(_snow * (2.3 + fi * 0.7) + fi * 1.7) * float(w) * 0.5,
					cos(_snow * (3.1 + fi * 0.5) + fi * 2.3) * float(h) * 0.5)
				draw_rect(Rect2(roundf(p.x), roundf(p.y), 1, 1), col)
		"spin":
			var a := TAU * _t / _period
			var p := Vector2(roundf(cos(a) * float(w)), roundf(sin(a) * float(h)))
			draw_rect(Rect2(p.x, p.y, 1, 1), col)
			draw_rect(Rect2(-p.x, -p.y, 1, 1), Color(col, 0.5))
		"lava":
			_draw_lava()
		"smoke":
			_draw_smoke()
		"pendulum":
			_draw_pendulum()


## The swing: one way every second (a two-second period). A pendulum in a glass door a few pixels wide cannot swing a fixed angle and still be seen, so the TIP's sideways reach is set in pixels
## (`PENDULUM_REACH_MIN`..`MAX`, about a quarter of the rod) and the angle follows from the rod's length. Everything is whole pixels from the fixed pivot at (0, 0): the rod, then a bob `w` wide.
const PENDULUM_PERIOD := 2.0
const PENDULUM_REACH_MIN := 1.4
const PENDULUM_REACH_MAX := 2.4


func pendulum_swing(length: float) -> float:
	var reach := clampf(0.28 * length, PENDULUM_REACH_MIN, PENDULUM_REACH_MAX)
	return asin(minf(reach / maxf(1.0, length), 0.95))


func pendulum_angle(at_time: float) -> float:
	return pendulum_swing(maxf(4.0, fall)) * sin(TAU * at_time / PENDULUM_PERIOD + float(absi(int(position.x)) % 7))


## The bob's tip at `at_time`, in whole pixels from the pivot.
func pendulum_tip(at_time: float) -> Vector2i:
	var length: float = maxf(4.0, fall)
	var th := pendulum_angle(at_time)
	return Vector2i(roundi(sin(th) * length), roundi(cos(th) * length))


## The rod's pixels at `at_time`, pivot to tip.
func pendulum_rod(at_time: float) -> Array:
	var length: float = maxf(4.0, fall)
	var th := pendulum_angle(at_time)
	var tip := Vector2(sin(th) * length, cos(th) * length)
	var steps := int(ceilf(length))
	var out: Array = []
	for i in range(steps + 1):
		var q := tip * (float(i) / float(steps))
		var cell := Vector2i(roundi(q.x), roundi(q.y))
		if out.is_empty() or out[out.size() - 1] != cell:
			out.append(cell)
	return out


## The bob's pixels as offsets from its tip: a disc `w` wide.
func pendulum_bob_offsets() -> Array:
	var r := maxf(1.0, float(w) * 0.5)
	var out: Array = []
	for dy in range(-int(r), int(r) + 1):
		for dx in range(-int(r), int(r) + 1):
			if float(dx * dx + dy * dy) <= r * r + 0.6:
				out.append(Vector2i(dx, dy))
	return out


## Every pixel the pendulum covers at `at_time` (pivot-relative): what a test holds against the clock's case.
func pendulum_footprint(at_time: float) -> Array:
	var out: Array = pendulum_rod(at_time)
	var tip := pendulum_tip(at_time)
	for o in pendulum_bob_offsets():
		out.append(tip + o)
	return out


func _draw_pendulum() -> void:
	for cell in pendulum_rod(_snow):
		draw_rect(Rect2(float(cell.x), float(cell.y), 1, 1), col)
	var r := maxf(1.0, float(w) * 0.5)
	var tip := pendulum_tip(_snow)
	for o in pendulum_bob_offsets():
		var lit := 1.0 + 0.35 * (-float(o.x) - float(o.y)) / maxf(1.0, r * 2.0)        # lit from the upper left
		draw_rect(Rect2(float(tip.x + o.x), float(tip.y + o.y), 1, 1), Color(minf(col.r * lit, 1.0), minf(col.g * lit, 1.0), minf(col.b * lit, 1.0), col.a))


## A lava lamp: a pool of wax at the foot and three blobs rising off it on their own slow tides inside a glass that narrows toward the top (w wide at the foot, h tall). At this size a round
## blob is a plus sign, so each is a little rounded block of whole pixels: width and height in px, a lit corner and a dark underside, its height stretching a pixel as it climbs.
const LAVA_BLOBS := [[4, 3, 11.0, 0.0, 0.7, 0.5, 0.38], [3, 2, 8.3, 2.1, 0.9, 0.75, 0.66], [2, 2, 6.1, 4.0, 1.2, 0.95, 0.5]]      # width px, height px, period s, phase s, sway px, how high it climbs (0..1), where across the glass it lives (0..1)


## The glass's width at row `y` (0 at the top): it tapers from `w` at the foot to a little over half that at the cap.
func lava_glass_width(y: float) -> float:
	return lerpf(float(w), float(w) * 0.55, 1.0 - clampf(y / maxf(1.0, float(h)), 0.0, 1.0))


## Blob `i` at `at_time` as a whole-pixel Rect2i inside the glass: it rises from the pool, stretches a pixel in mid-climb, drifts a little side to side and is never wider than the glass at its top row.
func lava_blob_rect(i: int, at_time: float) -> Rect2i:
	var b: Array = LAVA_BLOBS[i]
	var k := 0.5 - 0.5 * cos(TAU * (at_time + float(b[3])) / float(b[2]))               # 0 resting on the pool .. 1 at the top of its climb, slowly
	var hp := int(b[1]) + (1 if k > 0.3 and k < 0.75 else 0)
	var bottom := float(h) - 2.0 - k * float(b[5]) * (float(h) - 3.0)
	var top := maxi(1, roundi(bottom) - hp)                                              # never into the glass's narrow cap
	var width_here := lava_glass_width(float(top))
	var lo := ceili((float(w) - width_here) * 0.5)                                      # the glass's inside at this height, in whole pixels
	var he := floori((float(w) + width_here) * 0.5)
	var wp := mini(int(b[0]), maxi(1, he - lo))
	var left := roundi(float(w) * float(b[6]) + sin(TAU * (at_time + float(b[3])) / (float(b[2]) * 0.7)) * float(b[4]) - float(wp) * 0.5)
	return Rect2i(clampi(left, lo, maxi(lo, he - wp)), top, wp, hp)


func _draw_lava() -> void:
	var lit := Color(minf(col.r * 1.35, 1.0), minf(col.g * 1.35, 1.0), minf(col.b * 1.35, 1.0), 0.97)
	var body := Color(col.r, col.g, col.b, 0.96)
	var under := Color(col.r * 0.78, col.g * 0.78, col.b * 0.78, 0.96)
	draw_rect(Rect2(1, h - 1, w - 2, 1), under)                                          # the pool: a broad dark foot with a rounder lit head on it
	draw_rect(Rect2(2, h - 2, w - 4, 1), body)
	for i in range(LAVA_BLOBS.size()):
		var r := lava_blob_rect(i, _snow)
		for yy in range(r.size.y):
			for xx in range(r.size.x):
				if r.size.x >= 4 and (yy == 0 or yy == r.size.y - 1) and (xx == 0 or xx == r.size.x - 1):
					continue                                                              # a wide blob has rounded corners
				var c := body
				if yy == 0 and xx == 0 or (yy == 0 and r.size.x <= 2):
					c = lit
				elif yy == r.size.y - 1:
					c = under
				draw_rect(Rect2(r.position.x + xx, r.position.y + yy, 1, 1), c)


## A cigarette's tip and its smoke: ten puffs a few seconds old at a time (close enough to read as one thread), each rising, swaying and fading.
const SMOKE_LIFE := 3.6
const SMOKE_PUFFS := 10


## Puff `i` at `at_time`: x, y (px from the ember at (0, 0), y up is negative) and alpha 0..0.5 — it fades in over the first eighth of its life, then out.
func smoke_puff(i: int, at_time: float) -> Vector3:
	var f := fmod(at_time + SMOKE_LIFE * float(i) / float(SMOKE_PUFFS), SMOKE_LIFE) / SMOKE_LIFE
	var y := -1.0 - f * float(h)
	var x := sin(f * TAU * 1.4 + float(i) * 1.9) * float(w) * (0.25 + 0.75 * f)
	var a := (1.0 - f) * (0.42 if f > 0.12 else 0.42 * f / 0.12)
	return Vector3(x, y, a)


func _draw_smoke() -> void:
	var ember := 0.65 + 0.35 * sin(_snow * 2.1)
	draw_rect(Rect2(0, 0, 1, 1), Color(1.0, 0.45 * ember + 0.1, 0.18, 0.55 + 0.4 * ember))
	for i in range(SMOKE_PUFFS):
		var pf := smoke_puff(i, _snow)
		var f := fmod(_snow + SMOKE_LIFE * float(i) / float(SMOKE_PUFFS), SMOKE_LIFE) / SMOKE_LIFE
		draw_rect(Rect2(roundf(pf.x), roundf(pf.y), 2 if f > 0.45 else 1, 1), Color(col.r, col.g, col.b, pf.z))


func _draw_drip() -> void:
	var fall_t := 0.35 if kind == "drip" else 0.25
	var swell := _period - fall_t - 0.2
	if _t < swell:
		var k := _t / swell
		draw_rect(Rect2(0, 0, 1, 1), Color(col, 0.5 + 0.5 * k))
		if k > 0.6:
			draw_rect(Rect2(0, 1, 1, 1), Color(col, k))
	elif _t < swell + fall_t:
		var f := (_t - swell) / fall_t
		draw_rect(Rect2(0, floorf(fall * f * f), 1, 2), col)
	else:
		var s := (_t - swell - fall_t) / 0.2
		if s < 1.0:
			var a := 1.0 - s
			var spread := floorf(s * 2.0)
			draw_rect(Rect2(-1 - spread, fall - 1, 1, 1), Color(col, a))
			draw_rect(Rect2(1 + spread, fall - 1, 1, 1), Color(col, a))
			draw_rect(Rect2(0, fall - 2 - spread, 1, 1), Color(col, a * 0.8))


func _draw_static() -> void:
	# new snow every ~70 ms; a darker bar rolls down the screen for the first second of each period
	_rng.seed = int(_snow / 0.07) * 7919 + int(position.x)
	for y in range(h):
		for x in range(w):
			var v := _rng.randf()
			var g := 0.25 + 0.7 * v * v
			draw_rect(Rect2(x, y, 1, 1), Color(col.r * g, col.g * g, col.b * g, 0.9))
	if _t < 1.0:
		var by := floorf(_t * float(h + 3)) - 2.0
		draw_rect(Rect2(0, clampf(by, 0.0, float(h - 1)), w, minf(2.0, float(h))), Color(0, 0, 0, 0.35))


# --- the struck TV ('tv') --------------------------------------------------------------------------
var _crack: Array = []          # pixels of the crack lines (Vector2i)
var _dead: Dictionary = {}      # the black patch round the impact
var _bleed_cols: Array = []     # [x, Color] coloured lines bleeding down from the break
var _impact := Vector2.ZERO


func _build_crack() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = absi(int(position.x * 31.0 + position.y * 17.0)) + 5
	_impact = Vector2(float(w) * r.randf_range(0.55, 0.75), float(h) * r.randf_range(0.25, 0.45))
	# the dead patch: an irregular blot where the panel's gone black
	for y in range(h):
		for x in range(w):
			var d := Vector2(x, y).distance_to(_impact)
			var edge := 3.2 + 1.6 * sin(atan2(float(y) - _impact.y, float(x) - _impact.x) * 5.0 + 1.3)
			if d < edge:
				_dead[Vector2i(x, y)] = true
	# rays out to the edges, jagged, a few branching
	var rays := 9
	for k in range(rays):
		var a := TAU * float(k) / float(rays) + r.randf_range(-0.25, 0.25)
		var p := _impact
		var steps := 0
		while p.x >= 0 and p.x < float(w) and p.y >= 0 and p.y < float(h) and steps < 80:
			_crack.append(Vector2i(int(p.x), int(p.y)))
			a += r.randf_range(-0.18, 0.18)
			p += Vector2(cos(a), sin(a) * 0.8)
			steps += 1
			if steps == 8 and r.randf() < 0.5:                  # a branch
				var b := a + r.randf_range(0.5, 0.9) * (1.0 if r.randf() < 0.5 else -1.0)
				var q := p
				for i in range(r.randi_range(5, 12)):
					q += Vector2(cos(b), sin(b) * 0.8)
					if q.x < 0 or q.x >= float(w) or q.y < 0 or q.y >= float(h):
						break
					_crack.append(Vector2i(int(q.x), int(q.y)))
	# a ring round the impact
	for i in range(28):
		var a := TAU * float(i) / 28.0
		var q := _impact + Vector2(cos(a) * 6.0, sin(a) * 4.5)
		if q.x >= 0 and q.x < float(w) and q.y >= 0 and q.y < float(h):
			_crack.append(Vector2i(int(q.x), int(q.y)))
	var cols := [Color(0.9, 0.2, 0.8), Color(0.2, 0.9, 0.4), Color(0.3, 0.8, 1.0), Color(1.0, 0.9, 0.3)]
	for i in range(r.randi_range(2, 4)):
		_bleed_cols.append([clampi(int(_impact.x) + r.randi_range(-7, 7), 0, w - 1), cols[i % cols.size()]])


func _draw_tv() -> void:
	var frame := int(_snow / 0.07)
	_rng.seed = frame * 7919 + int(position.x)
	var broken := _t > _period - 1.3                               # the bad second
	var flash := fmod(_snow, 3.7) < 0.08 and not broken
	var shift := 0
	for y in range(h):
		if broken and _rng.randf() < 0.25:
			shift = _rng.randi_range(-8, 8)                          # a torn row
		for x in range(w):
			var p := Vector2i(x, y)
			if _dead.has(p):
				continue
			var v := _rng.randf()
			var g := (0.15 + 0.45 * v * v) * (1.8 if flash else 1.0)
			var c := Color(col.r * g, col.g * g, col.b * g, 0.92)
			if broken:
				var sx := posmod(x + shift, w)
				var band := int(float(sx) / float(w) * 6.0 + float(frame % 5)) % 3
				c = Color(0.9 if band == 0 else 0.15, 0.85 if band == 1 else 0.1, 0.9 if band == 2 else 0.2, 0.8) * (0.5 + 0.6 * v)
				c.a = 0.85
			draw_rect(Rect2(x, y, 1, 1), c)
	for b in _bleed_cols:                                            # colour bleeding down from the break
		var x: int = b[0]
		for y in range(int(_impact.y), h):
			var bc: Color = b[1]
			draw_rect(Rect2(x, y, 1, 1), Color(bc.r, bc.g, bc.b, 0.75 if not broken else 1.0))
	for p in _dead:                                                  # the dead black patch
		draw_rect(Rect2(p.x, p.y, 1, 1), Color(0.02, 0.02, 0.025, 1.0))
	for p in _crack:                                                 # the cracked glass over it all
		draw_rect(Rect2(p.x, p.y, 1, 1), Color(0.86, 0.9, 0.92, 0.85))
