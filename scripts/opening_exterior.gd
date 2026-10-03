extends Control

# THE OPENING SHOT (owner round 35 — "a nice pixel art exterior image of our building, clouds in the sky, city scape in the
# background. Camera pans up the building, then the title of the game, fade to black, then the run information").
#
# A NEW GAME begins here: from black, the street in the morning, then the camera climbs the tower floor by floor to the roof and
# the sky, the title comes up over the clouds, and the whole picture fades to black — which is where intro_overlay carries on with
# the time card ("MORNING / Joe / …") and the cold open. intro_overlay owns this node (stage "exterior"), drives `tick(delta)`
# from its own _process and reads `done`.
#
# THE ART is six parallax layers drawn by tools/art/opening.py (assets/opening/, native 288x162 shown at 4x = the screen):
# sky 0.30 / far city 0.50 / mid city 0.75 / the building + street 1.0 / foreground wires 1.30, plus an atlas of clouds the game
# places + drifts (opening_meta.json lists everything in each layer's own pixel coordinates). Everything on it that MOVES is made here:
# window smoke from the burnt floors and a plume or two over the city, one failing lamp, the roof's red beacon, crows circling the roof.
#
# THE TIMELINE is a pure function of `t` (a clock `tick` advances), so a test can walk it: fade in from black, a still beat on the
# street, the climb (an ease in and out), the title, a hold, the fade to black. A key hurries it (`hurry`): during the climb it
# speeds up (it never cuts — the picture still earns its read), once the title is up it goes straight to the fade-out.
# If any art is missing `load_ok` is false and intro_overlay falls back to the old black title screen — an opening must never
# strand a new game.

const DIR := "res://assets/opening/"
const CITY_DIR := "res://assets/city/"
const AUDIO_DIR := "res://assets/audio/opening/"

const VIEW_W := 288.0
const VIEW_H := 162.0
const PIXEL := 4.0                      # native px -> screen px (288x162 -> 1152x648)

# the timeline (seconds)
const T_FADE_IN := 1.4                  # black -> the street
const T_STILL := 0.9                    # the street, held, before the climb
const T_PAN := 12.5                     # the climb
const T_TITLE_AT := 0.74                # the title starts to come up this far (0..1) through the climb
const T_TITLE_FADE := 1.8
const T_HOLD := 2.9                     # after the climb ends, before the fade out
const T_FADE_OUT := 1.4                 # picture + title -> black
const HURRY_SPEED := 5.0

const TITLE_COLOR := Color(0.72, 0.05, 0.05)
const GLASS_DARK := Color(0.24, 0.26, 0.32)

var title_text: String = "DESCEND FROM 30"
var load_ok: bool = false
var done: bool = false
var t: float = 0.0
var speed: float = 1.0
var meta: Dictionary = {}
var scroll: float = 457.0

var world: Node2D = null
var layers: Dictionary = {}             # name -> {"node": Node2D, "p": float, "h": float, "lift": float}
var clouds: Array = []                  # [{"node": Sprite2D, "x": float, "y": float, "p": float, "v": float, "w": float}]
var title: Label = null
var shade: ColorRect = null
var flickers: Array = []                # [{"rect": ColorRect, "next": float, "off": bool, "seed": float}]
var beacons: Array = []                 # [{"node": CanvasItem, "phase": float}]
var birds: Node2D = null
var _rng := RandomNumberGenerator.new()
var _wind: AudioStreamPlayer = null
var _siren: AudioStreamPlayer = null
var _swell: AudioStreamPlayer = null
var _siren_played := false
var _swell_played := false


# ---- the timeline: pure functions of t -------------------------------------------------------------------------------
static func t_pan0() -> float:
	return T_FADE_IN + T_STILL


static func t_pan_end() -> float:
	return t_pan0() + T_PAN


static func t_title_in() -> float:
	return t_pan0() + T_PAN * T_TITLE_AT


static func t_out() -> float:
	return t_pan_end() + T_HOLD


static func t_end() -> float:
	return t_out() + T_FADE_OUT


## 0..1 through the climb, eased in and out (the camera sets off gently and settles on the roof).
static func pan_u(tt: float) -> float:
	var u := clampf((tt - t_pan0()) / T_PAN, 0.0, 1.0)
	return 0.5 - 0.5 * cos(PI * u)


static func black_alpha(tt: float) -> float:
	if tt < T_FADE_IN:
		return 1.0 - clampf(tt / T_FADE_IN, 0.0, 1.0)
	return clampf((tt - t_out()) / T_FADE_OUT, 0.0, 1.0)


static func title_alpha(tt: float) -> float:
	var a := clampf((tt - t_title_in()) / T_TITLE_FADE, 0.0, 1.0)
	return a * a * (3.0 - 2.0 * a)


## The whole-picture fade to black also takes the title (it leaves with it).
static func title_visible(tt: float) -> float:
	return title_alpha(tt) * (1.0 - clampf((tt - t_out()) / (T_FADE_OUT * 0.7), 0.0, 1.0))


func camera() -> float:
	return scroll * pan_u(t)


# ---- build -----------------------------------------------------------------------------------------------------------
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_rng.seed = 3510
	load_ok = _build()
	if load_ok:
		_apply(0.0)


static func art_present() -> bool:
	for f in ["sky.png", "far.png", "mid.png", "scene.png", "fore.png", "clouds.png"]:
		if not ResourceLoader.exists(DIR + f):
			return false
	return FileAccess.file_exists(DIR + "opening_meta.json")


func _tex(name: String) -> Texture2D:
	var r = load(DIR + name)
	return r if r is Texture2D else null


func _build() -> bool:
	if not art_present():
		return false
	var f := FileAccess.open(DIR + "opening_meta.json", FileAccess.READ)
	if f == null:
		return false
	var parsed = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary):
		return false
	meta = parsed
	scroll = float(meta.get("scroll", 457.0))

	world = Node2D.new()
	world.name = "World"
	world.scale = Vector2(PIXEL, PIXEL)
	world.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(world)

	var spec: Dictionary = meta.get("layers", {})
	for pair in [["sky", "sky.png"], ["far", "far.png"], ["mid", "mid.png"]]:
		_add_layer(pair[0], pair[1], spec)
	_add_clouds()                                   # in the sky, behind the towers
	_decorate_city("far")
	_decorate_city("mid")
	_add_layer("scene", "scene.png", spec)
	_decorate_scene()
	_add_layer("fore", "fore.png", spec)

	# a soft vignette so the corners fall away (cozy horror, not a postcard)
	var vig := ColorRect.new()
	vig.name = "Vignette"
	vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nvoid fragment() {\n\tfloat d = length((UV - vec2(0.5)) * vec2(1.15, 1.0));\n\tCOLOR = vec4(0.03, 0.02, 0.06, smoothstep(0.42, 0.95, d) * 0.5);\n}\n"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	vig.material = mat
	add_child(vig)

	title = Label.new()
	title.name = "Title"
	title.text = title_text
	title.add_theme_font_override("font", preload("res://assets/fonts/PixelOperator8-Bold.ttf"))
	title.add_theme_font_size_override("font_size", 62)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	title.add_theme_color_override("font_outline_color", Color(0.07, 0.0, 0.02))
	title.add_theme_constant_override("outline_size", 14)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	title.add_theme_constant_override("shadow_offset_y", 7)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 120)
	title.size = Vector2(VIEW_W * PIXEL, 100)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.modulate = Color(1, 1, 1, 0)
	add_child(title)

	shade = ColorRect.new()
	shade.name = "Shade"
	shade.color = Color(0, 0, 0, 1)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	_build_audio()
	return true


func _add_layer(key: String, file: String, spec: Dictionary) -> void:
	var tex := _tex(file)
	var n := Node2D.new()
	n.name = key.capitalize()
	var s := Sprite2D.new()
	s.centered = false
	s.texture = tex
	n.add_child(s)
	world.add_child(n)
	var d: Dictionary = spec.get(key, {})
	layers[key] = {"node": n, "p": float(d.get("p", 1.0)), "h": float(d.get("h", tex.get_height() if tex != null else 0)),
		"lift": float(d.get("lift", 0.0))}


func _add_clouds() -> void:
	var atlas := _tex("clouds.png")
	if atlas == null:
		return
	var cells: Array = meta.get("clouds_atlas", [])
	var holder := Node2D.new()
	holder.name = "Clouds"
	world.add_child(holder)
	# the clouds sit in the stack just in front of the mid city: they pass behind the far towers' tops but in front of the sun
	for c in meta.get("clouds", []):
		var i := int(c.get("i", 0))
		if i < 0 or i >= cells.size():
			continue
		var a: Dictionary = cells[i]
		var at := AtlasTexture.new()
		at.atlas = atlas
		at.region = Rect2(float(a["x"]), float(a["y"]), float(a["w"]), float(a["h"]))
		var s := Sprite2D.new()
		s.centered = false
		s.texture = at
		holder.add_child(s)
		clouds.append({"node": s, "x": float(c["x"]), "y": float(c["y"]), "p": float(c["p"]), "v": float(c["v"]), "w": float(a["w"])})
	# clouds draw right after the sky (behind the cities): move the holder to just above the sky
	world.move_child(holder, 1)


func _smoke_sprite(parent: Node, file: String, at: Vector2, scl: float = 1.0, tint: Color = Color(1, 1, 1, 1)) -> AnimatedSprite2D:
	var tex = load(CITY_DIR + file)
	if not (tex is Texture2D):
		return null
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", 6.0)
	frames.set_animation_loop("default", true)
	var fw := 14
	var count := int(tex.get_width() / fw)
	for k in count:
		var at_ := AtlasTexture.new()
		at_.atlas = tex
		at_.region = Rect2(k * fw, 0, fw, tex.get_height())
		frames.add_frame("default", at_)
	var a := AnimatedSprite2D.new()
	a.sprite_frames = frames
	a.centered = true
	a.offset = Vector2(0, -tex.get_height() * 0.5)          # the plume's FOOT is at its position
	a.position = at
	a.scale = Vector2(scl, scl)
	a.modulate = tint
	a.frame = _rng.randi() % maxi(1, count)
	a.play("default")
	parent.add_child(a)
	return a


func _decorate_city(key: String) -> void:
	var m: Dictionary = meta.get(key, {})
	var node: Node2D = layers[key]["node"]
	var smokes: Array = []
	for sp in m.get("smoke", []):
		if float(sp[0]) >= 110.0:                      # never across the low sun (the sky layer paints it at x ~66)
			smokes.append(sp)
	var picks := 2 if key == "far" else 1
	for k in picks:
		if smokes.is_empty():
			break
		var p = smokes[_rng.randi() % smokes.size()]
		_smoke_sprite(node, "smoke_1.png", Vector2(float(p[0]), float(p[1])), 1.0, Color(0.34, 0.32, 0.38, 0.92))
	for b in m.get("beacon", []):
		_add_beacon(node, Vector2(float(b[0]), float(b[1])))


func _add_beacon(parent: Node, at: Vector2) -> void:
	var r := ColorRect.new()
	r.color = Color(1.0, 0.18, 0.12, 1.0)
	r.size = Vector2(1, 1)
	r.position = at
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	beacons.append({"node": r, "phase": _rng.randf() * 3.0})


func _decorate_scene() -> void:
	var node: Node2D = layers["scene"]["node"]
	var m: Dictionary = meta.get("scene", {})
	# soot-black smoke pouring out of the burnt floors
	for p in m.get("smoke", []):
		if p is Dictionary:
			_smoke_sprite(node, "smoke_3.png", Vector2(float(p["x"]), float(p["y"])), 1.0, Color(1, 1, 1, 0.9))
	for b in m.get("beacon", []):
		if b is Dictionary:
			var r := ColorRect.new()
			r.color = Color(1.0, 0.2, 0.14, 1.0)
			r.size = Vector2(3, 2)
			r.position = Vector2(float(b["x"]) - 1.0, float(b["y"]))
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			node.add_child(r)
			beacons.append({"node": r, "phase": 0.0})
	# a failing lamp or two: a dark pane that comes and goes over a lit window (the floor-30 window you wake in stays steady)
	var lit: Array = m.get("lit", [])
	var pool: Array = []
	for w in lit:
		if int(w.get("floor", 0)) != 30:
			pool.append(w)
	for k in mini(3, pool.size()):
		var w: Dictionary = pool[_rng.randi() % pool.size()]
		var r := ColorRect.new()
		r.color = GLASS_DARK
		r.position = Vector2(float(w["x"]), float(w["y"]))
		r.size = Vector2(float(w["w"]), float(w["h"]))
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.modulate.a = 0.0
		node.add_child(r)
		flickers.append({"rect": r, "next": 0.6 + _rng.randf() * 3.0, "off": false, "burst": 0})
	# crows circling above the roof
	birds = _Birds.new()
	birds.name = "Birds"
	var bld: Dictionary = meta.get("building", {})
	birds.position = Vector2((float(bld.get("x0", 78)) + float(bld.get("x1", 209))) * 0.5, -26.0)
	node.add_child(birds)


func _stream(file: String, loop: bool) -> AudioStream:
	var s = load(AUDIO_DIR + file)
	if s is AudioStreamWAV and loop:
		(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		(s as AudioStreamWAV).loop_end = int((s as AudioStreamWAV).data.size() / 2)
	return s if s is AudioStream else null


func _player(file: String, loop: bool, vol: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = _stream(file, loop)
	p.volume_db = vol
	add_child(p)
	return p


func _build_audio() -> void:
	_wind = _player("wind.wav", true, -80.0)
	_siren = _player("siren.wav", false, -17.0)
	_swell = _player("swell.wav", false, -8.0)
	if _wind.stream != null:
		_wind.play()


# ---- per frame -------------------------------------------------------------------------------------------------------
## Called by intro_overlay every frame; advances the clock and applies it.
func tick(delta: float) -> void:
	if not load_ok or done:
		return
	delta = minf(delta, 0.1)                 # a long frame (the scene loading under us) must not eat the fade-in
	t += delta * speed
	if speed > 1.0 and t >= t_title_in():    # a hurried climb still lets the title land at its own pace
		speed = 1.0
	_apply(delta * speed)
	if t >= t_end():
		done = true
		_stop_audio()


## A key during the opening: while the camera is still climbing it speeds the climb up (it never cuts); once the title is up it
## goes straight to the fade out.
func hurry() -> void:
	if done:
		return
	if t < t_title_in():
		speed = HURRY_SPEED
	elif t < t_out():
		t = t_out()


func _apply(dt: float) -> void:
	var c := camera()
	for key in layers:
		var l: Dictionary = layers[key]
		var y: float = VIEW_H - float(l["h"]) + float(l["lift"]) + float(l["p"]) * c
		(l["node"] as Node2D).position = Vector2(0.0, _snap(y))
	for cl in clouds:
		# drifts slowly right, wrapping round just off both edges
		var cw: float = float(cl["w"])
		var span: float = VIEW_W + 2.0 * cw + 40.0
		var x: float = fposmod(float(cl["x"]) + float(cl["v"]) * t + cw + 20.0, span) - cw - 20.0
		var y: float = float(cl["y"]) + float(cl["p"]) * c
		(cl["node"] as Sprite2D).position = Vector2(_snap(x), _snap(y))
	shade.color.a = black_alpha(t)
	var ta := title_visible(t)
	title.modulate.a = ta
	title.position.y = 120.0 + 14.0 * (1.0 - title_alpha(t))
	# the failing lamps
	for f in flickers:
		f["next"] = float(f["next"]) - dt
		if float(f["next"]) <= 0.0:
			var on_dark: bool = not bool(f["off"])
			f["off"] = on_dark
			(f["rect"] as ColorRect).modulate.a = 1.0 if on_dark else 0.0
			f["next"] = (0.05 + _rng.randf() * 0.12) if on_dark else (0.15 + _rng.randf() * 3.2)
	# the beacons blink
	for b in beacons:
		var on: bool = fposmod(t + float(b["phase"]), 2.4) < 0.35
		(b["node"] as CanvasItem).modulate.a = 1.0 if on else 0.12
	# the sounds: wind under the whole thing, a siren far off, a swell under the title
	if _wind != null and _wind.stream != null:
		var wv := -80.0
		var fin := clampf(t / 3.0, 0.0, 1.0)
		var fout := 1.0 - clampf((t - t_out()) / T_FADE_OUT, 0.0, 1.0)
		wv = linear_to_db(maxf(0.0001, 0.5 * fin * fout))
		_wind.volume_db = wv
	if not _siren_played and t >= t_pan0() + 2.5 and _siren != null and _siren.stream != null:
		_siren_played = true
		_siren.play()
	if not _swell_played and t >= t_title_in() and _swell != null and _swell.stream != null:
		_swell_played = true
		_swell.play()


func _snap(v: float) -> float:
	return roundf(v * PIXEL) / PIXEL


func _stop_audio() -> void:
	for p in [_wind, _siren, _swell]:
		if p != null:
			p.stop()


func _exit_tree() -> void:
	_stop_audio()


# ---- crows circling the roof -----------------------------------------------------------------------------------------
class _Birds:
	extends Node2D

	const N := 7
	var clock := 0.0

	func _process(delta: float) -> void:
		clock += delta
		queue_redraw()

	func _draw() -> void:
		for i in N:
			var ph := float(i) * 0.9
			var rx := 52.0 + 11.0 * float(i % 3)
			var ry := 13.0 + 3.0 * float(i % 2)
			var a := clock * (0.42 + 0.03 * float(i % 3)) + ph
			var p := Vector2(cos(a) * rx, sin(a) * ry - 6.0 * float(i % 4))
			var flap := sin(clock * 9.0 + ph * 3.0)
			var col := Color(0.07, 0.07, 0.10, 0.92)
			var wing := 2.0 + flap * 1.3
			var wy := -0.6 * absf(flap)
			# two wing strokes in a V, mirrored; a body pixel
			draw_line(p, p + Vector2(-2.6, -wing * 0.5 + wy), col, 1.0)
			draw_line(p + Vector2(-2.6, -wing * 0.5 + wy), p + Vector2(-4.4, wing * 0.2), col, 1.0)
			draw_line(p, p + Vector2(2.6, -wing * 0.5 + wy), col, 1.0)
			draw_line(p + Vector2(2.6, -wing * 0.5 + wy), p + Vector2(4.4, wing * 0.2), col, 1.0)
			draw_rect(Rect2(p + Vector2(-0.5, -0.5), Vector2(1.5, 1.0)), col)
