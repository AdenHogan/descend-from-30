extends Control

# THE OPENING SHOT (owner round 35 — "a nice pixel art exterior image of our building, clouds in the sky, city scape in the
# background. Camera pans up the building, then the title of the game, fade to black, then the run information"; round 35b —
# "three versions for different run times… a player loading a file might be on a run 2 or 3 save… that exterior can also be used to
# show more damage and disaster outside").
#
# A run begins here: from black, the street, then the camera climbs the tower floor by floor to the roof and the sky, (the title
# comes up over it on a NEW GAME or a LOAD — a later run's cold open has no title), and the whole picture fades to black — which is
# where intro_overlay carries on with the time card ("MORNING / Joe / …") and the cold open. intro_overlay owns this node on a run's
# start (stage "exterior"); `opening_sequence.gd` owns it for a LOAD. Either drives `tick(delta)` and reads `done`.
#
# THREE LOOKS, one building: run 1 MORNING (the sun low, a clear sky, a few smoke columns), run 2 AFTERNOON (a violet-orange dusk, lamps
# on, more broken glass, a wrecked street with fires, fires up in the city), run 3 NIGHT (stars and a moon, rain and lightning, the
# city burning, a breach in the wall, boards and bodies at the door). The art is drawn by tools/art/opening.py (assets/opening/,
# `<layer>_<run>.png`, native 288x162 shown at 4x = the screen) as parallax layers: sky 0.30 / far city 0.50 / mid city 0.75 / the
# building + street 1.0 / foreground wires 1.30, plus a cloud atlas the game drifts; `opening_meta_<run>.json` lists everything in each
# layer's own pixel coordinates.
#
# THE BURNT FLOORS ARE THIS PLAYTHROUGH'S OWN: `burn_plan()` reads `WorldState.fire_intensity(floor)` for this run (the same sim that
# lights the corridors: LIGHT / BLAZE / CHARRED, climbing the building run by run) and lays `burn.png`'s charred windows + soot on those
# floors, with animated flames and smoke on the ones still alight — a load on run 3 shows exactly the floors you will meet burning.
#
# THE TIMELINE is a pure function of `t` (a clock `tick` advances), so a test can walk it: fade in from black, a still beat on the
# street, the climb (an ease in and out), the title (if there is one), a hold, the fade to black. A key hurries it (`hurry`): during
# the climb it speeds up (it never cuts — the picture still earns its read), once the title is up (or the climb is over, with no title)
# it goes straight to the fade-out. If any art is missing `load_ok` is false and the caller falls back — an opening must never strand a
# new game or a load.

const DIR := "res://assets/opening/"
const CITY_DIR := "res://assets/city/"
const AUDIO_DIR := "res://assets/audio/opening/"
const THUNDER := ["res://assets/audio/ambience/thunder_1.wav", "res://assets/audio/ambience/thunder_2.wav"]

const VIEW_W := 288.0
const VIEW_H := 162.0
const PIXEL := 4.0                      # native px -> screen px (288x162 -> 1152x648)

# the timeline (seconds)
const T_FADE_IN := 1.4                  # black -> the street
const T_STILL := 0.9                    # the street, held, before the climb
const T_PAN := 12.5                     # the climb (with a title to land)
const T_PAN_SHORT := 8.5                # the climb of a later run's cold open (no title)
const T_TITLE_AT := 0.74                # the title starts to come up this far (0..1) through the climb
const T_TITLE_FADE := 1.8
const T_HOLD := 2.9                     # after the climb ends, before the fade out
const T_HOLD_SHORT := 0.9
const T_FADE_OUT := 1.4                 # picture + title -> black
const HURRY_SPEED := 5.0

const TITLE_COLOR := Color(0.72, 0.05, 0.05)
const GLASS_DARK := Color(0.24, 0.26, 0.32)

var title_text: String = "DESCEND FROM 30"
var run: int = 0                        # 0 = the run the game is on (WorldState.current_run)
var own_input: bool = false             # a key hurries it (the cold open's overlay does this itself)
var with_title: bool = true
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
var flash: ColorRect = null
var rain: Control = null
var flickers: Array = []                # [{"rect": ColorRect, "next": float, "off": bool}]
var beacons: Array = []                 # [{"node": CanvasItem, "phase": float}]
var flames: Array = []                  # [{"glow": Sprite2D, "phase": float}] — the glows over every fire, pulsing
var burning: Array = []                 # burn_plan() as laid on the building
var birds: Node2D = null
var runner: Node2D = null               # the one thing crossing the garden (a black cat in the morning, a person fleeing in the afternoon)
var survivors: Node2D = null            # the little people at lit windows (meta "survivors"), animated off `t`
var _rng := RandomNumberGenerator.new()
var _hum: AudioStreamPlayer = null
var _siren: AudioStreamPlayer = null
var _swell: AudioStreamPlayer = null
var _thunder: AudioStreamPlayer = null
var _siren_played := false
var _swell_played := false
var _bolt_in: float = 5.0               # seconds to the next lightning (night)
var _boom_in: float = -1.0              # seconds to its thunder
var _glow_tex: Texture2D = null


# ---- the timeline: pure functions of t -------------------------------------------------------------------------------
static func pan_len(wt: bool = true) -> float:
	return T_PAN if wt else T_PAN_SHORT


static func t_pan0() -> float:
	return T_FADE_IN + T_STILL


static func t_pan_end(wt: bool = true) -> float:
	return t_pan0() + pan_len(wt)


static func t_title_in(wt: bool = true) -> float:
	return t_pan0() + T_PAN * T_TITLE_AT if wt else t_pan_end(false)


static func t_out(wt: bool = true) -> float:
	return t_pan_end(wt) + (T_HOLD if wt else T_HOLD_SHORT)


static func t_end(wt: bool = true) -> float:
	return t_out(wt) + T_FADE_OUT


## 0..1 through the climb, eased in and out (the camera sets off gently and settles on the roof).
static func pan_u(tt: float, wt: bool = true) -> float:
	var u := clampf((tt - t_pan0()) / pan_len(wt), 0.0, 1.0)
	return 0.5 - 0.5 * cos(PI * u)


static func black_alpha(tt: float, wt: bool = true) -> float:
	if tt < T_FADE_IN:
		return 1.0 - clampf(tt / T_FADE_IN, 0.0, 1.0)
	return clampf((tt - t_out(wt)) / T_FADE_OUT, 0.0, 1.0)


static func title_alpha(tt: float, wt: bool = true) -> float:
	if not wt:
		return 0.0
	var a := clampf((tt - t_title_in(true)) / T_TITLE_FADE, 0.0, 1.0)
	return a * a * (3.0 - 2.0 * a)


## The whole-picture fade to black also takes the title (it leaves with it).
static func title_visible(tt: float, wt: bool = true) -> float:
	return title_alpha(tt, wt) * (1.0 - clampf((tt - t_out(wt)) / (T_FADE_OUT * 0.7), 0.0, 1.0))


func camera() -> float:
	return scroll * pan_u(t, with_title)


# ---- which floors burn: THIS playthrough's fire ------------------------------------------------------------------------
## [{floor, stage, bays}] for every floor the fire sim has alight THIS run (WorldState.fire_intensity — LIGHT / BLAZE / CHARRED), with
## which of the floor's 8 window bays show it: a light fire is a window or two, a blaze most of the face, a burnt-out floor nearly all.
static func burn_plan() -> Array:
	var out: Array = []
	for fl in range(2, 30):
		var st: int = WorldState.fire_intensity(fl)
		if st < 0:
			continue
		var r := RandomNumberGenerator.new()
		r.seed = hash(str(WorldState.master_seed) + "openburn" + str(fl))
		var n: int
		match st:
			WorldState.FIRE_LIGHT:
				n = r.randi_range(1, 2)
			WorldState.FIRE_BLAZE:
				n = r.randi_range(3, 5)
			_:
				n = r.randi_range(6, 8)
		var bays: Array = [0, 1, 2, 3, 4, 5, 6, 7]
		for i in range(bays.size() - 1, 0, -1):
			var j: int = r.randi_range(0, i)
			var tmp = bays[i]
			bays[i] = bays[j]
			bays[j] = tmp
		var pick: Array = bays.slice(0, n)
		pick.sort()
		out.append({"floor": fl, "stage": st, "bays": pick})
	return out


# ---- build -----------------------------------------------------------------------------------------------------------
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_rng.seed = 3510
	if run <= 0:
		run = WorldState.current_run
	run = clampi(run, 1, 3)
	with_title = title_text != ""
	load_ok = _build()
	if load_ok:
		_apply(0.0)


static func art_present(for_run: int = 1) -> bool:
	for f in ["sky", "far", "mid", "scene", "fore", "clouds"]:
		if not ResourceLoader.exists("%s%s_%d.png" % [DIR, f, for_run]):
			return false
	return ResourceLoader.exists(DIR + "burn.png") and FileAccess.file_exists("%sopening_meta_%d.json" % [DIR, for_run])


func _tex(name: String) -> Texture2D:
	var r = load(DIR + name)
	return r if r is Texture2D else null


func _build() -> bool:
	if not art_present(run):
		return false
	var f := FileAccess.open("%sopening_meta_%d.json" % [DIR, run], FileAccess.READ)
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
	for key in ["sky", "far", "mid"]:
		_add_layer(key, spec)
	_add_clouds()                                   # in the sky, behind the towers
	_decorate_city("far")
	_decorate_city("mid")
	_add_layer("scene", spec)
	_decorate_scene()
	_add_layer("fore", spec)

	if bool(meta.get("look", {}).get("rain", false)):
		rain = _Rain.new()
		rain.name = "Rain"
		rain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		rain.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rain)

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

	flash = ColorRect.new()
	flash.name = "Flash"
	flash.color = Color(0.82, 0.88, 1.0, 1.0)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.modulate.a = 0.0
	add_child(flash)

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
	title.visible = with_title
	add_child(title)

	shade = ColorRect.new()
	shade.name = "Shade"
	shade.color = Color(0, 0, 0, 1)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	_build_audio()
	return true


func _add_layer(key: String, spec: Dictionary) -> void:
	var tex := _tex("%s_%d.png" % [key, run])
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
	var atlas := _tex("clouds_%d.png" % run)
	if atlas == null:
		return
	var cells: Array = meta.get("clouds_atlas", [])
	var holder := Node2D.new()
	holder.name = "Clouds"
	world.add_child(holder)
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
	world.move_child(holder, 1)                     # clouds draw right after the sky (behind the cities)


## A horizontal strip PNG from assets/city (frames side by side, `fw` wide) as an animated sprite whose FOOT sits at `at`.
func _strip_sprite(parent: Node, file: String, fw: int, fps: float, at: Vector2, scl: float = 1.0, tint: Color = Color(1, 1, 1, 1)) -> AnimatedSprite2D:
	var tex = load(CITY_DIR + file)
	if not (tex is Texture2D):
		return null
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", fps)
	frames.set_animation_loop("default", true)
	var count := int(tex.get_width() / fw)
	for k in count:
		var at_ := AtlasTexture.new()
		at_.atlas = tex
		at_.region = Rect2(k * fw, 0, fw, tex.get_height())
		frames.add_frame("default", at_)
	var a := AnimatedSprite2D.new()
	a.sprite_frames = frames
	a.centered = true
	a.offset = Vector2(0, -tex.get_height() * 0.5)          # the foot is at the position
	a.position = at
	a.scale = Vector2(scl, scl)
	a.modulate = tint
	a.frame = _rng.randi() % maxi(1, count)
	a.play("default")
	parent.add_child(a)
	return a


func _smoke_sprite(parent: Node, at: Vector2, scl: float = 1.0, tint: Color = Color(1, 1, 1, 1)) -> AnimatedSprite2D:
	return _strip_sprite(parent, "smoke_%d.png" % run, 14, 6.0, at, scl, tint)


## A flame at `at` (its foot) with a warm additive glow round it that pulses — over the city, the street and the burning floors.
func _flame(parent: Node, at: Vector2, scl: float = 1.0, glow: float = 1.0) -> void:
	_strip_sprite(parent, "fire.png", 9, 10.0, at, scl)
	var g := Sprite2D.new()
	g.texture = _glow()
	g.position = at + Vector2(0, -5.0 * scl)
	g.scale = Vector2(glow, glow)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	g.material = m
	var base := 0.5 if run == 3 else 0.38
	g.modulate = Color(1.0, 0.5, 0.18, base)
	parent.add_child(g)
	flames.append({"glow": g, "phase": _rng.randf() * 6.0, "base": base})


func _glow() -> Texture2D:
	if _glow_tex == null:
		var gt := GradientTexture2D.new()
		var grad := Gradient.new()
		grad.set_color(0, Color(1, 1, 1, 1))
		grad.set_color(1, Color(1, 1, 1, 0))
		gt.gradient = grad
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 48
		gt.height = 48
		_glow_tex = gt
	return _glow_tex


func _decorate_city(key: String) -> void:
	var m: Dictionary = meta.get(key, {})
	var look: Dictionary = meta.get("look", {})
	var node: Node2D = layers[key]["node"]

	var smokes: Array = []
	for sp in m.get("smoke", []):
		if float(sp[0]) >= 110.0:                      # never across the low sun (the sky layer paints it at x ~66)
			smokes.append(sp)
	var counts: Array = look.get("city_smokes", [2, 1])
	var picks := int(counts[0] if key == "far" else counts[1])
	var tint := Color(0.34, 0.32, 0.38, 0.92) if run == 1 else Color(1, 1, 1, 0.92)
	for k in picks:
		if smokes.is_empty():
			break
		var p = smokes[_rng.randi() % smokes.size()]
		_smoke_sprite(node, Vector2(float(p[0]), float(p[1])), 1.0 if key == "mid" else 0.9, tint)

	# whole towers burning, from the second run on: a fire at the crown with its smoke going up behind it
	var want := int(look.get("city_fires", 0))
	var per_layer := int(ceil(want * (0.4 if key == "far" else 0.6)))
	var tops: Array = m.get("fire", [])
	for k in per_layer:
		if tops.is_empty():
			break
		var p = tops[_rng.randi() % tops.size()]
		var at := Vector2(float(p[0]), float(p[1]))
		_smoke_sprite(node, at + Vector2(0, -6), 1.0, tint)
		_flame(node, at, 1.1 if key == "mid" else 0.85, 1.3)

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
	for b in m.get("beacon", []):
		if b is Dictionary:
			var r := ColorRect.new()
			r.color = Color(1.0, 0.2, 0.14, 1.0)
			r.size = Vector2(3, 2)
			r.position = Vector2(float(b["x"]) - 1.0, float(b["y"]))
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			node.add_child(r)
			beacons.append({"node": r, "phase": 0.0})
	# the floors this playthrough has on fire (from the second run on — the first morning shows no fire anywhere, owner round 36f)
	_lay_burning(node)
	# survivors at some of the lit windows: a wave, pacing, peering out, swaying
	var sv: Array = m.get("survivors", [])
	if not sv.is_empty():
		survivors = _Survivors.new()
		survivors.name = "Survivors"
		survivors.people = sv
		survivors.run = run
		node.add_child(survivors)
	# fires in the street
	for f in m.get("fires", []):
		var at := Vector2(float(f["x"]), float(f["y"]))
		_smoke_sprite(node, at + Vector2(0, -8), 1.0, Color(1, 1, 1, 0.95))
		_flame(node, at, float(f.get("scale", 1.0)) * 1.2, 1.5)
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
		flickers.append({"rect": r, "next": 0.6 + _rng.randf() * 3.0, "off": false})
	# the garden's one moving figure: a cat / someone running in fear (none at night — only the dead are there)
	var rn: Dictionary = m.get("runner", {})
	if String(rn.get("kind", "")) != "":
		runner = _Runner.new()
		runner.name = "Runner"
		runner.spec = rn
		node.add_child(runner)
	# crows circling above the roof (not at night — they have gone)
	if run < 3:
		birds = _Birds.new()
		birds.name = "Birds"
		var bld: Dictionary = meta.get("building", {})
		birds.position = Vector2((float(bld.get("x0", 78)) + float(bld.get("x1", 209))) * 0.5, -26.0)
		node.add_child(birds)


## Lay the charred windows / soot / flames for burn_plan() on the building (a child of the scene layer, so it scrolls with it).
func _lay_burning(node: Node2D) -> void:
	if run < 2:
		return                                           # run 1 is the calm before it: no fire on the tower (burn_plan() stays the sim's truth)
	burning = burn_plan()
	if burning.is_empty():
		return
	var sheet := _tex("burn.png")
	var grid: Dictionary = meta.get("scene", {}).get("grid", {})
	var cells: Dictionary = meta.get("burn", {})
	if sheet == null or grid.is_empty() or cells.is_empty():
		return
	var holder := Node2D.new()
	holder.name = "Burning"
	node.add_child(holder)
	var x0 := float(grid["x0"])
	var bw := float(grid["bay_w"])
	var y0 := float(grid["floor0_y"])
	var fh := float(grid["floor_h"])
	var frame: Array = grid["frame"]
	var chars: Array = cells.get("char", [])
	var soots: Array = cells.get("soot", [])
	for e in burning:
		var fl: int = int(e["floor"])
		var st: int = int(e["stage"])
		var top := y0 + float(30 - fl) * fh + float(frame[1])
		var smoked := 0
		for b in e["bays"]:
			var wx: float = x0 + float(b) * bw + float(frame[0])
			var h := hash("%d:%d:%d" % [fl, int(b), run])
			# soot first (up the wall), then the black window over it
			if not soots.is_empty():
				var sc: Dictionary = soots[absi(h) % soots.size()]
				var ss := Sprite2D.new()
				var sat := AtlasTexture.new()
				sat.atlas = sheet
				sat.region = Rect2(float(sc["x"]), float(sc["y"]), float(sc["w"]), float(sc["h"]))
				ss.texture = sat
				ss.centered = false
				ss.position = Vector2(wx, top - float(sc["h"]) + 2.0)
				ss.modulate.a = 0.5 if st == WorldState.FIRE_LIGHT else (0.85 if st == WorldState.FIRE_BLAZE else 1.0)
				holder.add_child(ss)
			if not chars.is_empty():
				var cc: Dictionary = chars[absi(h >> 3) % chars.size()]
				var cs := Sprite2D.new()
				var cat := AtlasTexture.new()
				cat.atlas = sheet
				cat.region = Rect2(float(cc["x"]), float(cc["y"]), float(cc["w"]), float(cc["h"]))
				cs.texture = cat
				cs.centered = false
				cs.position = Vector2(wx, top)
				holder.add_child(cs)
			var foot := Vector2(wx + 5.5, top + 9.0)
			if st == WorldState.FIRE_BLAZE:
				_flame(holder, foot, 0.8, 0.8)
				if smoked % 2 == 0:
					_smoke_sprite(holder, foot + Vector2(0, -8), 0.9, Color(1, 1, 1, 0.9))
				smoked += 1
			elif st == WorldState.FIRE_LIGHT:
				if smoked == 0:
					_smoke_sprite(holder, foot + Vector2(0, -8), 0.7, Color(1, 1, 1, 0.8))
				smoked += 1
			elif smoked == 0:                                # burnt out: a last thread of smoke from the floor
				_smoke_sprite(holder, foot + Vector2(0, -8), 0.6, Color(0.8, 0.8, 0.8, 0.6))
				smoked += 1


func _stream(path: String, loop: bool) -> AudioStream:
	var s = load(path)
	if s is AudioStreamWAV and loop:
		(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		(s as AudioStreamWAV).loop_end = int((s as AudioStreamWAV).data.size() / 2)
	return s if s is AudioStream else null


func _player(path: String, loop: bool, vol: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = _stream(path, loop)
	p.volume_db = vol
	add_child(p)
	return p


func _build_audio() -> void:
	_hum = _player(AUDIO_DIR + "hum.wav", true, -80.0)
	_siren = _player(AUDIO_DIR + "siren.wav", false, -17.0 if run == 1 else -13.0)
	_swell = _player(AUDIO_DIR + "swell.wav", false, -8.0)
	_thunder = _player(THUNDER[0], false, -6.0)
	if _hum.stream != null:
		_hum.play()


# ---- per frame -------------------------------------------------------------------------------------------------------
## Called every frame by whoever owns the opening; advances the clock and applies it.
func tick(delta: float) -> void:
	if not load_ok or done:
		return
	delta = minf(delta, 0.1)                 # a long frame (the scene loading under us) must not eat the fade-in
	t += delta * speed
	if speed > 1.0 and t >= t_title_in(with_title):    # a hurried climb still lets the title land at its own pace
		speed = 1.0
	_apply(delta * speed)
	if t >= t_end(with_title):
		done = true
		_stop_audio()


## A key during the opening: while the camera is still climbing it speeds the climb up (it never cuts); once the title is up (or the
## climb is over, with no title) it goes straight to the fade out.
func hurry() -> void:
	if done:
		return
	if t < t_title_in(with_title):
		speed = HURRY_SPEED
	elif t < t_out(with_title):
		t = t_out(with_title)


func _input(event: InputEvent) -> void:
	if not own_input or done or not load_ok:
		return
	if SettingsManager.is_any_press(event):
		hurry()
		get_viewport().set_input_as_handled()


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
	shade.color.a = black_alpha(t, with_title)
	var ta := title_visible(t, with_title)
	title.modulate.a = ta
	title.position.y = 120.0 + 14.0 * (1.0 - title_alpha(t, with_title))
	# the failing lamps
	for f in flickers:
		f["next"] = float(f["next"]) - dt
		if float(f["next"]) <= 0.0:
			var on_dark: bool = not bool(f["off"])
			f["off"] = on_dark
			(f["rect"] as ColorRect).modulate.a = 1.0 if on_dark else 0.0
			f["next"] = (0.05 + _rng.randf() * 0.12) if on_dark else (0.15 + _rng.randf() * 3.2)
	# the beacons blink; the fires breathe
	for b in beacons:
		var on: bool = fposmod(t + float(b["phase"]), 2.4) < 0.35
		(b["node"] as CanvasItem).modulate.a = 1.0 if on else 0.12
	for fl in flames:
		var k: float = 0.78 + 0.22 * sin(t * 7.0 + float(fl["phase"])) * sin(t * 3.1 + float(fl["phase"]) * 1.7)
		(fl["glow"] as Sprite2D).modulate.a = float(fl["base"]) * k
	if survivors != null:
		survivors.clock = t
		survivors.queue_redraw()
	if runner != null:
		runner.clock = t
		runner.queue_redraw()
	_lightning(dt)
	# the sounds: a low tonal hum under the whole thing (no noise — it read as static; a touch fuller at night), a siren far off, a swell under the title
	if _hum != null and _hum.stream != null:
		var fin := clampf(t / 3.0, 0.0, 1.0)
		var fout := 1.0 - clampf((t - t_out(with_title)) / T_FADE_OUT, 0.0, 1.0)
		_hum.volume_db = linear_to_db(maxf(0.0001, (0.5 if run == 3 else 0.38) * fin * fout))
	if not _siren_played and t >= t_pan0() + 2.5 and _siren != null and _siren.stream != null:
		_siren_played = true
		_siren.play()
	if with_title and not _swell_played and t >= t_title_in(true) and _swell != null and _swell.stream != null:
		_swell_played = true
		_swell.play()


## Night: a flash that lights the whole picture, then the thunder a beat behind it.
func _lightning(dt: float) -> void:
	if run != 3 or flash == null:
		return
	flash.modulate.a = maxf(0.0, flash.modulate.a - dt * 2.6)
	_bolt_in -= dt
	if _bolt_in <= 0.0:
		flash.modulate.a = 0.5
		_bolt_in = 4.5 + _rng.randf() * 6.0
		_boom_in = 0.5 + _rng.randf() * 1.0
	if _boom_in >= 0.0:
		_boom_in -= dt
		if _boom_in < 0.0 and _thunder != null:
			var s = load(THUNDER[_rng.randi() % THUNDER.size()])
			if s is AudioStream:
				_thunder.stream = s
				_thunder.play()


func _snap(v: float) -> float:
	return roundf(v * PIXEL) / PIXEL


func _stop_audio() -> void:
	for p in [_hum, _siren, _swell, _thunder]:
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


# ---- the runner in the garden --------------------------------------------------------------------------------------------------
# One small figure crosses the lawn while the camera is still on the ground floor: a black cat (morning), a person running in fear
# (afternoon). A pure function of the opening's clock, in scene pixel coordinates (4x on screen), drawn from rects so it needs no art.
class _Runner:
	extends Node2D

	var spec: Dictionary = {}
	var clock := 0.0

	func progress() -> float:
		return (clock - float(spec.get("start", 0.0))) / maxf(0.1, float(spec.get("dur", 5.0)))

	func position_x() -> float:
		var u := progress()
		return lerpf(float(spec.get("x0", 0.0)), float(spec.get("x1", 0.0)), clampf(u, 0.0, 1.0))

	func active() -> bool:
		var u := progress()
		return u >= 0.0 and u <= 1.0

	func _draw() -> void:
		if not active():
			return
		var kind := String(spec.get("kind", ""))
		var x := roundf(position_x())
		var y := float(spec.get("y", 500.0))
		var dir := float(spec.get("dir", 1))
		draw_set_transform(Vector2(x, y), 0.0, Vector2(dir, 1.0))        # draw facing +x, mirrored for a leftward runner
		for i in range(-5, 6):                                            # a soft shadow on the grass
			draw_rect(Rect2(float(i) + 1.0, 0.0, 1.0, 1.0), Color(0, 0, 0, 0.26 * (1.0 - absf(float(i)) / 6.0)))
		if kind == "cat":
			_draw_cat()
		else:
			_draw_person()
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _draw_cat() -> void:
		var k := Color(0.05, 0.05, 0.07)
		var ph := int(clock * 13.0) % 2                                   # two gallop frames
		var bob := -1.0 if ph == 0 else 0.0
		draw_rect(Rect2(-3.0, -4.0 + bob, 6.0, 3.0), k)                   # body
		draw_rect(Rect2(3.0, -5.0 + bob, 3.0, 3.0), k)                    # head
		draw_rect(Rect2(3.0, -6.0 + bob, 1.0, 1.0), k)                    # ears
		draw_rect(Rect2(5.0, -6.0 + bob, 1.0, 1.0), k)
		draw_rect(Rect2(5.0, -4.0 + bob, 1.0, 1.0), Color(0.78, 0.86, 0.3))   # an eye
		draw_rect(Rect2(-4.0, -5.0 + bob, 1.0, 2.0), k)                   # the tail, up and curling
		draw_rect(Rect2(-5.0, -6.0 + bob - float(ph), 1.0, 2.0), k)
		if ph == 0:                                                       # legs reaching / pushing off
			draw_rect(Rect2(3.0, -1.0, 2.0, 1.0), k)
			draw_rect(Rect2(-4.0, -1.0, 2.0, 1.0), k)
			draw_rect(Rect2(0.0, -1.0, 1.0, 1.0), k)
		else:
			draw_rect(Rect2(1.0, -1.0, 1.0, 1.0), k)
			draw_rect(Rect2(-2.0, -1.0, 1.0, 1.0), k)
			draw_rect(Rect2(4.0, -1.0, 1.0, 1.0), k)
			draw_rect(Rect2(-3.0, -1.0, 1.0, 1.0), k)

	func _draw_person() -> void:
		var skin := Color(0.78, 0.6, 0.48)
		var shirt := Color(0.8, 0.28, 0.24)
		var legs := Color(0.16, 0.18, 0.28)
		var ph := int(clock * 9.0) % 2
		var bob := -1.0 if ph == 0 else 0.0
		var lean := 1.0                                                   # leaning into the run
		# legs mid-stride, alternating
		if ph == 0:
			draw_rect(Rect2(-1.0, -4.0, 1.0, 4.0), legs)
			draw_rect(Rect2(2.0, -3.0, 2.0, 1.0), legs)
			draw_rect(Rect2(3.0, -2.0, 1.0, 2.0), legs)
		else:
			draw_rect(Rect2(1.0, -4.0, 1.0, 4.0), legs)
			draw_rect(Rect2(-3.0, -3.0, 2.0, 1.0), legs)
			draw_rect(Rect2(-3.0, -2.0, 1.0, 2.0), legs)
		draw_rect(Rect2(-1.0 + lean, -8.0 + bob, 3.0, 4.0), shirt)        # torso
		draw_rect(Rect2(0.0 + lean, -10.0 + bob, 2.0, 2.0), skin)         # head
		draw_rect(Rect2(0.0 + lean, -11.0 + bob, 2.0, 1.0), Color(0.18, 0.12, 0.1))
		# arms flung up and back in terror, flailing
		draw_rect(Rect2(-2.0 + lean, -10.0 + bob - float(ph), 1.0, 3.0), skin)
		draw_rect(Rect2(3.0 + lean, -9.0 + bob + float(ph), 1.0, 3.0), skin)
		if ph == 0:                                                       # a puff of dust at the heels
			draw_rect(Rect2(-5.0, -1.0, 1.0, 1.0), Color(0.85, 0.8, 0.7, 0.5))
			draw_rect(Rect2(-7.0, -2.0, 1.0, 1.0), Color(0.85, 0.8, 0.7, 0.3))


# ---- survivors at the windows ------------------------------------------------------------------------------------------------
# Tiny pixel people (3 px wide, 7 tall) at some lit windows, in the glass's own coordinates: one waves, one paces from side to side,
# one stands and now and then leans to look out, one sways. A pure function of the clock, so a test can walk it.
class _Survivors:
	extends Node2D

	var people: Array = []
	var clock := 0.0
	var run := 1

	func person_x(p: Dictionary) -> float:
		var ph: float = float(p.get("phase", 0.0))
		match String(p.get("kind", "peer")):
			"pace":
				return 4.0 + 2.2 * sin(clock * 0.55 + ph)
			"wave":
				return 5.0
			"sway":
				return 4.0 + 0.7 * sin(clock * 0.7 + ph)
		return 3.0 + float(int(ph * 10.0) % 3)

	func _draw() -> void:
		var dim := 1.0 if run == 1 else (0.82 if run == 2 else 0.7)
		for p in people:
			var gx: float = float(p["x"])
			var gy: float = float(p["y"])
			var ph: float = float(p.get("phase", 0.0))
			var kind := String(p.get("kind", "peer"))
			var cx := roundf(person_x(p))
			var face := 1.0
			if kind == "pace":
				face = 1.0 if cos(clock * 0.55 + ph) >= 0.0 else -1.0
			var x := gx + cx
			var bob := 0.0
			if kind == "peer" and fposmod(clock + ph, 3.2) < 0.3:
				bob = 1.0                                   # leans in to look out
			var shirt := Color.from_string("#" + String(p.get("shirt", "c9605a")), Color(0.8, 0.4, 0.35))
			shirt = Color(shirt.r * 0.8 * dim, shirt.g * 0.8 * dim, shirt.b * 0.8 * dim)
			var skin := Color(0.62 * dim, 0.47 * dim, 0.38 * dim)
			var legs := Color(0.14 * dim, 0.13 * dim, 0.18 * dim)
			var step := 0.0
			if kind == "pace" and int(clock * 3.0) % 2 == 0:
				step = 1.0
			draw_rect(Rect2(x - 1.0, gy + 6.0, 1.0, 2.0), legs)                      # legs (a step in a pace)
			draw_rect(Rect2(x + 1.0 - step, gy + 6.0, 1.0, 2.0 - step), legs)
			draw_rect(Rect2(x - 1.0, gy + 3.0 + bob, 3.0, 3.0 - bob), shirt)         # torso
			var hx := x - 1.0 + (1.0 if face > 0.0 else 0.0)
			draw_rect(Rect2(hx, gy + 1.0 + bob, 2.0, 2.0), skin)                     # head
			if kind == "wave":
				var up := sin(clock * 7.0 + ph) > 0.0
				draw_rect(Rect2(x + 2.0, gy + (1.0 if up else 2.0), 1.0, 2.0), skin)   # the raised arm, waving
				draw_rect(Rect2(x - 2.0, gy + 4.0, 1.0, 2.0), shirt)
			else:
				draw_rect(Rect2(x - 2.0, gy + 4.0, 1.0, 2.0), shirt)
				draw_rect(Rect2(x + 2.0, gy + 4.0, 1.0, 2.0), shirt)


# ---- rain over the whole picture (night) --------------------------------------------------------------------------------
class _Rain:
	extends Control

	const N := 150
	var drops: Array = []
	var clock := 0.0

	func _ready() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = 77
		for i in N:
			drops.append({"x": r.randf(), "y": r.randf(), "v": 0.9 + r.randf() * 0.9, "len": 7.0 + r.randf() * 9.0, "a": 0.18 + r.randf() * 0.22})

	func _process(delta: float) -> void:
		clock += delta
		for d in drops:
			d["y"] = float(d["y"]) + delta * float(d["v"]) * 1.15
			d["x"] = float(d["x"]) - delta * float(d["v"]) * 0.12
			if float(d["y"]) > 1.05:
				d["y"] = -0.05
				d["x"] = fposmod(float(d["x"]) + 0.37, 1.0)
			if float(d["x"]) < -0.02:
				d["x"] = 1.02
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		for d in drops:
			var p := Vector2(float(d["x"]) * w, float(d["y"]) * h)
			draw_line(p, p + Vector2(-2.0, float(d["len"])), Color(0.72, 0.8, 0.95, float(d["a"])), 2.0)
