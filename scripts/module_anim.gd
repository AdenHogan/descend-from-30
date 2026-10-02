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


func _ready() -> void:
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
