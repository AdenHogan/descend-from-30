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
const T_TEXT_FADE := 1.1                # the title is the LOGO (owner round 48n): the lettering fades in first…
const T_HAND_BEAT := 0.2                # …a held beat with only the words…
const T_HAND_FADE := 1.6                # …then the bloody handprint behind them comes up
const T_HOLD := 2.9                     # after the climb ends, before the fade out
const T_HOLD_SHORT := 0.9
const T_FADE_OUT := 1.4                 # picture + title -> black
const HURRY_SPEED := 5.0

const LOGO_DIR := "res://assets/logo/"
const LOGO_HAND := LOGO_DIR + "logo_layer_hand_dark.png"     # the print (tools/art/logo.py writes both layers on ONE canvas: put them at the same place)
const LOGO_TEXT := LOGO_DIR + "logo_layer_text_dark.png"     # the worn lettering with its strikes of blood
const LOGO_SCALE := 0.25                # 2400 px wide -> 600 px on the 1152 x 648 screen
const LOGO_CENTRE := Vector2(576.0, 195.0)
const TEXT_RISE := 10.0                 # the words settle this far (px) as they fade in
const SHADOW_DROP := 3.0                # the lettering casts a soft shadow (no panel behind the logo): cream words would wash into a bright morning sky and its clouds
const SHADOW_SHADER_CODE := "shader_type canvas_item;
// the lettering's own shape, blurred by sampling its mipmaps (the texture is 2400 px shown at ~600, so level 3 is ~2 px of screen and level 5 ~8 px), tinted night-dark.
// The shadow is only ever AROUND the letters: it is taken out under their solid bodies (sampled where the lettering really stands, `drop_texels` above this
// sprite), so while the words fade in the cream is never laid over something dark (that read as black letters that then turned cream).
uniform float tight_lod = 3.0;
uniform float wide_lod = 5.0;
uniform float tight_gain = 1.5;
uniform float wide_gain = 1.6;
uniform float strength = 0.62;
uniform float halo = 0.30;
uniform float drop_texels = 12.0;
void fragment() {
	float tight = clamp(textureLod(TEXTURE, UV, tight_lod).a * tight_gain, 0.0, 1.0);
	float wide = clamp(textureLod(TEXTURE, UV, wide_lod).a * wide_gain, 0.0, 1.0);
	float body = smoothstep(0.80, 1.0, textureLod(TEXTURE, UV + vec2(0.0, drop_texels * TEXTURE_PIXEL_SIZE.y), 2.0).a);
	COLOR = vec4(0.02, 0.012, 0.035, clamp(tight * strength + wide * halo, 0.0, 0.85) * (1.0 - body));
}
"
const GLASS_DARK := Color(0.24, 0.26, 0.32)
const BIRDS_TAKE_OFF := 2.0              # the crows on the wire go this far into the opening (the held street, just before the climb sets off)

var title_text: String = "DESCEND FROM 30"   # non-empty = this cut has the title; what is drawn is the logo (round 48n), never this string
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
var title: Control = null               # the logo: the group's alpha is its fade to black; the two layers carry their own fade-in
var title_hand: Sprite2D = null         # behind
var title_shadow: Sprite2D = null       # the lettering's soft shadow, over the hand and under the words
var title_words: Sprite2D = null        # in front
var shade: ColorRect = null
var flash: ColorRect = null
var rain: Control = null
var bolt: Control = null                # a pixel bolt of lightning (night)
var flickers: Array = []                # [{"rect": ColorRect, "next": float, "off": bool}]
var beacons: Array = []                 # [{"node": CanvasItem, "phase": float}]
var flames: Array = []                  # [{"glow": Sprite2D, "phase": float}] — the glows over every fire, pulsing
var burning: Array = []                 # burn_plan() as laid on the building
var birds: Node2D = null                # the flock wheeling over the roof (day)
var wire_birds: Node2D = null           # the crows on the telephone wire, which startle and fly off
var runner: Node2D = null               # the one thing crossing the garden (a black cat in the morning, a person fleeing in the afternoon)
var survivors: Node2D = null            # the little people at lit windows (meta "survivors"), animated off `t`
var _rng := RandomNumberGenerator.new()
var _hum: AudioStreamPlayer = null
var _siren: AudioStreamPlayer = null
var _swell: AudioStreamPlayer = null
var _thunder: AudioStreamPlayer = null
var _siren_played := false
var _flutter: AudioStreamPlayer = null
var _flutter_played := false
var _swell_played := false
var _bolt_in: float = 5.0               # seconds to the next lightning (night)
var _flicker_in: float = -1.0
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


## The title is the logo, in two layers: the LETTERING fades in first (`text_alpha`), a beat later the HANDPRINT behind it (`hand_alpha`).
static func t_hand_in(wt: bool = true) -> float:
	return t_title_in(wt) + T_TEXT_FADE + T_HAND_BEAT


## When the whole logo is up.
static func t_title_up(wt: bool = true) -> float:
	return t_hand_in(wt) + T_HAND_FADE


static func _ease(a: float) -> float:
	a = clampf(a, 0.0, 1.0)
	return a * a * (3.0 - 2.0 * a)


static func text_alpha(tt: float, wt: bool = true) -> float:
	return _ease((tt - t_title_in(true)) / T_TEXT_FADE) if wt else 0.0


static func hand_alpha(tt: float, wt: bool = true) -> float:
	return _ease((tt - t_hand_in(true)) / T_HAND_FADE) if wt else 0.0


## The lettering's shadow comes in BEHIND the words (the square of their fade): it only holds the words up against a bright sky, so it must never lead them.
static func shadow_alpha(tt: float, wt: bool = true) -> float:
	var a := text_alpha(tt, wt)
	return a * a


## How much of the title is up: 1 once the last part of it (the hand) has landed.
static func title_alpha(tt: float, wt: bool = true) -> float:
	return hand_alpha(tt, wt)


## The title group's own visibility: the whole-picture fade to black also takes the title (it leaves a little ahead of the shade).
static func title_visible(tt: float, wt: bool = true) -> float:
	if not wt:
		return 0.0
	return 1.0 - clampf((tt - t_out(wt)) / (T_FADE_OUT * 0.7), 0.0, 1.0)


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
	for f in ["sky", "far", "mid", "scene", "garden", "fore", "clouds"]:
		if not ResourceLoader.exists("%s%s_%d.png" % [DIR, f, for_run]):
			return false
	return ResourceLoader.exists(DIR + "burn.png") and ResourceLoader.exists(DIR + "birds.png") and FileAccess.file_exists("%sopening_meta_%d.json" % [DIR, for_run]) \
		and ResourceLoader.exists(LOGO_HAND) and ResourceLoader.exists(LOGO_TEXT)


func _tex(name: String) -> Texture2D:
	var r = load(DIR + name)
	return r if r is Texture2D else null


## One layer of the logo: both are the same size and sit at the same place, so stacked they ARE the logo. Linear + mipmaps: a 2400 px picture shrunk 4x.
func _logo_layer(node_name: String, path: String) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.name = node_name
	sp.texture = load(path) as Texture2D
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sp.scale = Vector2(LOGO_SCALE, LOGO_SCALE)
	sp.position = LOGO_CENTRE
	sp.modulate.a = 0.0
	title.add_child(sp)
	return sp


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
	# the garden is its OWN plane, sliding faster than the building (2.5D, owner round 36j) — with the afternoon's fog banks either side of it
	var fog_on: bool = bool(meta.get("look", {}).get("fog", false)) and ResourceLoader.exists("%sfog_%d.png" % [DIR, run])
	if fog_on:
		_add_layer("fog", spec)
	_add_layer("garden", spec)
	_decorate_garden()
	if fog_on:
		_add_layer("fogf", spec)
	_add_layer("fore", spec)
	_decorate_fore()

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

	bolt = _Bolt.new()
	bolt.name = "Bolt"
	bolt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bolt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bolt)

	flash = ColorRect.new()
	flash.name = "Flash"
	flash.color = Color(0.82, 0.88, 1.0, 1.0)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.modulate.a = 0.0
	add_child(flash)

	title = Control.new()
	title.name = "Title"
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.visible = with_title
	add_child(title)
	title_hand = _logo_layer("TitleHand", LOGO_HAND)
	title_shadow = _logo_layer("TitleShadow", LOGO_TEXT)
	var sh_mat := ShaderMaterial.new()
	var sh_code := Shader.new()
	sh_code.code = SHADOW_SHADER_CODE
	sh_mat.shader = sh_code
	sh_mat.set_shader_parameter("drop_texels", SHADOW_DROP / LOGO_SCALE)
	title_shadow.material = sh_mat
	title_words = _logo_layer("TitleText", LOGO_TEXT)

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
		"lift": float(d.get("lift", 0.0)), "drift": float(d.get("drift", 0.0)), "w": float(tex.get_width() if tex != null else VIEW_W)}
	if float(d.get("drift", 0.0)) > 0.0 and tex != null:          # a bank of fog: two copies side by side, slid along and wrapped
		var s2 := Sprite2D.new()
		s2.centered = false
		s2.texture = tex
		s2.position.x = float(tex.get_width())
		n.add_child(s2)


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
	# the breach (night): the flat torn open is burning inside — two flames on the floor slab with their glow, and a smoke column out of the hole
	var br: Dictionary = m.get("breach", {})
	if not br.is_empty():
		var bx := float(br["cx"])
		var bf := float(br["floor_y"])
		_flame(node, Vector2(bx - 7.0, bf - 1.0), 1.1, 1.7)
		_flame(node, Vector2(bx + 6.0, bf - 1.0), 0.85, 1.5)
		_smoke_sprite(node, Vector2(bx - 1.0, bf - 12.0), 1.2, Color(1, 1, 1, 0.9))
	# survivors at some of the lit windows: a wave, pacing, peering out, swaying
	var sv: Array = m.get("survivors", [])
	if not sv.is_empty():
		survivors = _Survivors.new()
		survivors.name = "Survivors"
		survivors.people = sv
		survivors.run = run
		# in some of the OTHER lit windows a shadow passes behind the curtain now and then
		var taken := {}
		for pp in sv:
			taken["%d:%d" % [int(pp.get("floor", 0)), int(pp.get("bay", 0))]] = true
		for w in m.get("lit", []):
			var key := "%d:%d" % [int(w.get("floor", 0)), int(w.get("bay", 0))]
			if taken.has(key) or int(w.get("floor", 0)) == 30:
				continue
			var fl := int(w.get("floor", 0))
			var bay := int(w.get("bay", 0))
			if (fl * 13 + bay * 7 + run * 5) % 3 == 0:                      # about a third of them, the same ones every time
				survivors.passers.append({"x": float(w["x"]), "y": float(w["y"]), "phase": fposmod(float(fl) * 0.37 + float(bay) * 0.19, 1.0), "period": 7.0 + float((fl * 3 + bay) % 7)})
		node.add_child(survivors)
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
	# birds wheeling over the roof, flapping (not at night — they have gone)
	if run < 3:
		var art := _bird_art()
		if art != null:
			birds = _Birds.new()
			birds.name = "Birds"
			birds.art = art
			birds.tint = Color(0.82, 0.80, 0.80) if run == 2 else Color(1, 1, 1)
			var bld: Dictionary = meta.get("building", {})
			birds.position = Vector2((float(bld.get("x0", 78)) + float(bld.get("x1", 209))) * 0.5, -26.0)
			node.add_child(birds)


## The sheet of birds (assets/opening/birds.png), or null if it is missing.
func _bird_art() -> _BirdArt:
	var tex := _tex("birds.png")
	if tex == null:
		return null
	return _BirdArt.make(tex, meta.get("birds", {}))


## The crows on the telephone wire (runs 1 and 2): children of the foreground layer, so they sit on the wire as it slides; when they startle
## they leave the wire for the sky and keep their own course on the screen.
func _decorate_fore() -> void:
	var perches: Array = meta.get("fore", {}).get("perches", [])
	var art := _bird_art()
	if art == null or perches.is_empty():
		return
	var node: Node2D = layers["fore"]["node"]
	wire_birds = _WireBirds.new()
	wire_birds.name = "WireBirds"
	wire_birds.art = art
	wire_birds.perches = perches
	wire_birds.go_at = BIRDS_TAKE_OFF
	wire_birds.tint = Color(0.86, 0.82, 0.80) if run == 2 else Color(1, 1, 1)
	wire_birds.layer_y = Callable(self, "fore_y_at")
	node.add_child(wire_birds)


## The foreground layer's y at time `tt` — its position is a pure function of the clock, so a bird that left the wire at `tt` can be put
## where it took off from and flown on from there.
func fore_y_at(tt: float) -> float:
	var l: Dictionary = layers["fore"]
	return VIEW_H - float(l["h"]) + float(l["lift"]) + float(l["p"]) * scroll * pan_u(tt, with_title)


## The garden plane: its fires and the one figure crossing it (children of the garden layer, so they slide with it).
func _decorate_garden() -> void:
	var node: Node2D = layers["garden"]["node"]
	var g: Dictionary = meta.get("garden", {})
	# fires in the garden
	for f in g.get("fires", []):
		var at := Vector2(float(f["x"]), float(f["y"]))
		_smoke_sprite(node, at + Vector2(0, -8), 1.0, Color(1, 1, 1, 0.95))
		_flame(node, at, float(f.get("scale", 1.0)) * 1.2, 1.5)
	# the garden's one moving figure: a cat / someone running in fear (none at night — only the dead are there)
	var rn: Dictionary = g.get("runner", {})
	if String(rn.get("kind", "")) != "":
		runner = _Runner.new()
		runner.name = "Runner"
		runner.setup(rn)
		node.add_child(runner)


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
	_flutter = _player(AUDIO_DIR + "flutter.wav", false, -9.0)
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
		if float(l.get("drift", 0.0)) > 0.0:
			var w: float = float(l["w"])
			var dx: float = -floorf(fposmod(float(l["drift"]) * t, w))
			(l["node"] as Node2D).get_child(0).position.x = dx
			(l["node"] as Node2D).get_child(1).position.x = dx + w
	for cl in clouds:
		# drifts slowly right, wrapping round just off both edges
		var cw: float = float(cl["w"])
		var span: float = VIEW_W + 2.0 * cw + 40.0
		var x: float = fposmod(float(cl["x"]) + float(cl["v"]) * t + cw + 20.0, span) - cw - 20.0
		var y: float = float(cl["y"]) + float(cl["p"]) * c
		(cl["node"] as Sprite2D).position = Vector2(_snap(x), _snap(y))
	if rain != null:
		var gy: float = (float(layers["garden"]["node"].position.y) + 482.0) * PIXEL
		rain.set("ground_y", gy if gy < 648.0 else -1.0)
	shade.color.a = black_alpha(t, with_title)
	title.modulate.a = title_visible(t, with_title)
	var wa := text_alpha(t, with_title)
	title_words.modulate.a = wa
	title_words.position = LOGO_CENTRE + Vector2(0.0, TEXT_RISE * (1.0 - wa))
	title_shadow.modulate.a = shadow_alpha(t, with_title)
	title_shadow.position = title_words.position + Vector2(0.0, SHADOW_DROP)
	title_hand.modulate.a = hand_alpha(t, with_title)
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
	if birds != null:
		birds.clock = t
		birds.queue_redraw()
	if wire_birds != null:
		wire_birds.clock = t
		wire_birds.queue_redraw()
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
	if not _flutter_played and wire_birds != null and t >= BIRDS_TAKE_OFF and _flutter != null and _flutter.stream != null:
		_flutter_played = true                              # the crows leave the wire
		_flutter.play()
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
	if _flicker_in >= 0.0:                                 # the second, weaker flash a beat after the first (lightning stutters)
		_flicker_in -= dt
		if _flicker_in < 0.0:
			flash.modulate.a = maxf(flash.modulate.a, 0.28)
	flash.modulate.a = maxf(0.0, flash.modulate.a - dt * 2.6)
	_bolt_in -= dt
	if _bolt_in <= 0.0:
		flash.modulate.a = 0.5
		_flicker_in = 0.11
		if bolt != null:
			bolt.strike(_rng, _rng.randf() < 0.5)
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
	for p in [_hum, _siren, _swell, _thunder, _flutter]:
		if p != null:
			p.stop()


func _exit_tree() -> void:
	_stop_audio()


# ---- crows circling the roof -----------------------------------------------------------------------------------------
# ---- the birds ---------------------------------------------------------------------------------------------------------------
# One sheet (assets/opening/birds.png, drawn by tools/art/opening_birds.py): NEAR crows for the wire, FAR birds for the sky. Every pose is a
# pure function of the opening's clock (nothing accumulates), so a test or a capture can walk it.
class _BirdArt:
	var tex: Texture2D = null
	var near: Dictionary = {}       # name -> Rect2 on the sheet
	var far: Dictionary = {}

	static func make(texture: Texture2D, m: Dictionary) -> _BirdArt:
		var a := _BirdArt.new()
		a.tex = texture
		for e in m.get("near", []):
			a.near[String(e["name"])] = Rect2(float(e["x"]), float(e["y"]), float(e["w"]), float(e["h"]))
		for e in m.get("far", []):
			a.far[String(e["name"])] = Rect2(float(e["x"]), float(e["y"]), float(e["w"]), float(e["h"]))
		return a

	## The wing cycle of a crow: `phase` counts whole beats. Six poses, so the stroke eases (down, level, raised, up, raised, level).
	static func near_beat(phase: float) -> String:
		var cyc := ["down", "level", "raised", "up", "raised", "level"]
		return cyc[int(floor(fposmod(phase, 1.0) * 6.0)) % 6]

	static func far_beat(phase: float) -> String:
		var cyc := ["down", "level", "up", "level"]
		return cyc[int(floor(fposmod(phase, 1.0) * 4.0)) % 4]


## The flock over the roof: birds that fly BACK AND FORTH across the sky, flapping in bursts and gliding between, banking round at each end.
class _Birds:
	extends Node2D

	const RANGE := 86.0                                # they wander this far either side of the building's middle
	const FLOCK := [
		{"y": -4.0, "v": 15.0, "ph": 0.00, "per": 4.6, "bob": 3.4, "rate": 4.2},
		{"y": -15.0, "v": 19.0, "ph": 0.31, "per": 5.3, "bob": 2.6, "rate": 4.6},
		{"y": 5.0, "v": 12.0, "ph": 0.57, "per": 3.9, "bob": 3.0, "rate": 3.9},
		{"y": -24.0, "v": 17.0, "ph": 0.80, "per": 6.1, "bob": 2.2, "rate": 4.4},
		{"y": 13.0, "v": 21.0, "ph": 0.12, "per": 4.9, "bob": 2.8, "rate": 4.8},
		{"y": -9.0, "v": 13.0, "ph": 0.66, "per": 5.7, "bob": 3.2, "rate": 4.1},
	]
	var art: _BirdArt = null
	var clock := 0.0
	var tint := Color(1, 1, 1, 1)

	## {pos, scale_x, frame}: where bird `i` is at time `t`, which way it faces (scale_x < 0 = leftward; its magnitude shrinks while it banks round), and its pose.
	static func pose(i: int, t: float) -> Dictionary:
		var p: Dictionary = FLOCK[i % FLOCK.size()]
		var span := 2.0 * RANGE
		var v: float = p["v"]
		var s := fposmod(float(p["ph"]) * span * 2.0 + v * t, 2.0 * span)
		var right := s < span
		var along := s if right else s - span                       # how far along this leg
		var x := -RANGE + along if right else RANGE - along
		var to_turn := minf(along, span - along) / v                 # seconds to the nearest turn
		var mag := 1.0 if to_turn >= 0.5 else (0.62 if to_turn >= 0.25 else 0.32)
		var banking := to_turn < 0.5
		var dir := 1.0 if right else -1.0
		var per: float = p["per"]
		var cyc := fposmod(t + float(p["ph"]) * 7.0, per) / per
		var frame := "glide"
		var y: float = float(p["y"]) + float(p["bob"]) * sin(t * 0.7 + float(p["ph"]) * 6.0)
		if not banking and cyc < 0.62:
			var beat := t * float(p["rate"]) + float(p["ph"]) * 3.0
			frame = _BirdArt.far_beat(beat)
			y += (1.0 if frame == "up" else (-1.0 if frame == "down" else 0.0))      # the body rises on the downstroke
		return {"pos": Vector2(roundf(x), roundf(y)), "scale_x": dir * mag, "frame": frame}

	func _draw() -> void:
		if art == null:
			return
		for i in FLOCK.size():
			var q := pose(i, clock)
			var r: Rect2 = art.far.get(q["frame"], art.far.get("glide", Rect2()))
			if r.size == Vector2.ZERO:
				continue
			var sx: float = q["scale_x"]
			draw_set_transform(q["pos"], 0.0, Vector2(sx, 1.0))
			draw_texture_rect_region(art.tex, Rect2(-r.size.x * 0.5, -r.size.y * 0.5, r.size.x, r.size.y), r, tint)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The crows on the telephone wire. They sit on it until something spooks them, then — one after another, the last a beat late — flinch,
## throw themselves off and beat away across the sky. They are children of the foreground layer (so they ride the wire up the screen) but
## once airborne they keep their own course on the SCREEN: `layer_y(t)` is the layer's position at time t, so the takeoff point is exact.
class _WireBirds:
	extends Node2D

	const DELAYS := [0.0, 0.17, 0.36, 0.52]
	const DIRS := [1.0, -1.0, 1.0, -1.0]
	const FLINCH := 0.20                                # the crouch before the jump
	var art: _BirdArt = null
	var perches: Array = []                             # [{x, y}] in the foreground layer's pixels: where each crow's feet are (y = the wire)
	var clock := 0.0
	var go_at := 2.0
	var layer_y: Callable = Callable()
	var tint := Color(1, 1, 1, 1)

	func takeoff_of(i: int) -> float:
		return go_at + float(DELAYS[i % DELAYS.size()])

	## {pos (the sprite's feet, in the layer's local pixels), dir, frame, perched}
	func pose(i: int, t: float) -> Dictionary:
		var pc: Dictionary = perches[i]
		var px := float(pc["x"])
		var py := float(pc["y"])
		var dir: float = DIRS[i % DIRS.size()]
		var u := t - takeoff_of(i)
		if u < -FLINCH:
			return {"pos": Vector2(px, py - 1.0), "dir": dir, "frame": "perched", "perched": true}
		if u < 0.0:
			return {"pos": Vector2(px, py - 1.0), "dir": dir, "frame": "crouch", "perched": true}
		# airborne: screen-space course from the takeoff point (the wire's own position at the moment it left)
		var t0 := takeoff_of(i)
		var ly0: float = layer_y.call(t0) if layer_y.is_valid() else 0.0
		var ly: float = layer_y.call(t) if layer_y.is_valid() else 0.0
		# a startled crow does not climb straight up: it drops a little off the wire, then goes OUT across the sky, rising slowly
		var up := 11.0 * (1.0 - exp(-0.9 * u)) - 5.0 * (1.0 - exp(-7.0 * u))
		var ahead := 26.0 * u + 7.0 * u * u
		var wob := 1.4 * sin(u * 4.6 + float(i))
		var screen := Vector2(px + dir * ahead, ly0 + py - 1.0 - up + wob)
		var beat := 3.0 * u - 0.12 * u * u
		var frame := "crouch" if u < 0.12 else _BirdArt.near_beat(beat)
		if u > 2.4 and fposmod(u + float(i) * 0.6, 1.9) > 1.45:
			frame = "glide"
		return {"pos": Vector2(screen.x, screen.y - ly), "dir": dir, "frame": frame, "perched": false}

	func _draw() -> void:
		if art == null:
			return
		for i in perches.size():
			var q := pose(i, clock)
			var r: Rect2 = art.near.get(q["frame"], Rect2())
			if r.size == Vector2.ZERO:
				continue
			var at: Vector2 = q["pos"]
			var feet := Vector2(roundf(at.x * 4.0) / 4.0, roundf(at.y * 4.0) / 4.0)
			draw_set_transform(feet, 0.0, Vector2(float(q["dir"]), 1.0))
			draw_texture_rect_region(art.tex, Rect2(-8.0, -r.size.y, r.size.x, r.size.y), r, tint)     # origin = the feet, the body centred on x
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---- the runner in the garden --------------------------------------------------------------------------------------------------
# One small figure crosses the lawn while the camera is still near the ground: a black cat (morning), a person running in fear (afternoon).
# It does NOT run along the bottom edge: it comes in from the front and goes DEEPER into the scene along a route planned over free ground
# (tools/art/opening.py `RUNNERS` / `plan_lane` — the art tool checks that nothing standing nearer ever covers it), shrinking with the
# perspective the path's own width follows (`scale_at`) and slowing with it. The cat slips into the dark doorway; the person reaches the
# barricaded door and stands hammering on it. A pure function of the opening's clock, drawn from integer rects so it needs no art.
class _Runner:
	extends Node2D

	var spec: Dictionary = {}
	var clock := 0.0
	var _pts: Array = []            # [Vector2(x, row)] — row 0 is the building's foot, 43 the viewer's edge
	var _t: Array = []              # the time (s, from the start) at each waypoint
	var _dirs: Array = []           # facing of the leg that ENDS at each waypoint (+1 right / -1 left)
	var _skin := Color(0.78, 0.6, 0.48)

	func setup(sp: Dictionary) -> void:
		spec = sp
		_pts = []
		for p in sp.get("path", []):
			_pts.append(Vector2(float(p[0]), float(p[1])))
		_t = [0.0]
		_dirs = [1.0]
		var v0 := float(sp.get("speed", 56.0))
		for i in range(1, _pts.size()):
			var a: Vector2 = _pts[i - 1]
			var b: Vector2 = _pts[i]
			var sc := 0.5 * (scale_at(a.y) + scale_at(b.y))
			_t.append(float(_t[i - 1]) + a.distance_to(b) / maxf(1.0, v0 * sc))
			_dirs.append(signf(b.x - a.x) if absf(b.x - a.x) > 0.01 else float(_dirs[i - 1]))

	func scale_at(row: float) -> float:
		var sc: Array = spec.get("scale", [16.0, 0.82, 43.0])
		return (float(sc[0]) + float(sc[1]) * row) / (float(sc[0]) + float(sc[1]) * float(sc[2]))

	func total() -> float:
		return float(_t[_t.size() - 1]) if not _t.is_empty() else 0.0

	func local_time() -> float:
		return clock - float(spec.get("start", 0.0))

	func active() -> bool:
		return _pts.size() >= 2 and local_time() >= 0.0 and (String(spec.get("end", "")) == "pound" or local_time() <= total() + 0.6)

	## {pos: Vector2 (x, row), dir, done (the route is over)} at the runner's time.
	func pose() -> Dictionary:
		var lt := local_time()
		if lt >= total():
			return {"pos": _pts[_pts.size() - 1], "dir": float(_dirs[_dirs.size() - 1]), "done": true}
		for i in range(1, _t.size()):
			if lt <= float(_t[i]):
				var u := (lt - float(_t[i - 1])) / maxf(0.0001, float(_t[i]) - float(_t[i - 1]))
				var a: Vector2 = _pts[i - 1]
				var b: Vector2 = _pts[i]
				return {"pos": a.lerp(b, u), "dir": float(_dirs[i]), "done": false}
		return {"pos": _pts[0], "dir": 1.0, "done": false}

	## Where its feet are, in the garden layer's pixels (rounded the way it is drawn).
	func feet() -> Vector2:
		var q := pose()
		var p: Vector2 = q["pos"]
		return Vector2(floorf(p.x + 0.5), floorf(float(spec.get("y0", 482.0)) + p.y + 0.5))

	func _r(x: float, y: float, w: float, h: float, col: Color, sc: float) -> void:
		# a rect of the figure's own full-size drawing, scaled to the row it stands on and snapped to whole pixels (never thinner than one)
		var x0 := roundf(x * sc)
		var y0 := roundf(y * sc)
		var x1 := maxf(x0 + 1.0, roundf((x + w) * sc))
		var y1 := maxf(y0 + 1.0, roundf((y + h) * sc))
		draw_rect(Rect2(x0, y0, x1 - x0, y1 - y0), col)

	func _draw() -> void:
		if not active():
			return
		var q := pose()
		var p: Vector2 = q["pos"]
		var sc := scale_at(p.y)
		var f := feet()
		var kind := String(spec.get("kind", ""))
		var dir: float = q["dir"]
		var alpha := 1.0
		if bool(q["done"]) and kind == "cat":
			alpha = clampf(1.0 - (local_time() - total()) / 0.5, 0.0, 1.0)         # gone into the dark doorway
		draw_set_transform(f, 0.0, Vector2(dir, 1.0))                       # facing +x, mirrored for a leftward runner
		for i in range(-5, 6):                                               # a soft shadow on the grass
			_r(float(i), 0.0, 1.0, 1.0, Color(0, 0, 0, 0.26 * (1.0 - absf(float(i)) / 6.0) * alpha), sc)
		if kind == "cat":
			_draw_cat(sc, alpha)
		elif bool(q["done"]) and String(spec.get("end", "")) == "pound":
			draw_set_transform(f, 0.0, Vector2.ONE)
			_draw_pounding(sc)
		else:
			_draw_person(sc)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _draw_cat(sc: float, a: float) -> void:
		var k := Color(0.05, 0.05, 0.07, a)
		var ph := int(clock * 13.0) % 2                                      # two gallop frames
		var bob := -1.0 if ph == 0 else 0.0
		_r(-3.0, -4.0 + bob, 6.0, 3.0, k, sc)                                # body
		_r(3.0, -5.0 + bob, 3.0, 3.0, k, sc)                                 # head
		_r(3.0, -6.0 + bob, 1.0, 1.0, k, sc)                                 # ears
		_r(5.0, -6.0 + bob, 1.0, 1.0, k, sc)
		_r(5.0, -4.0 + bob, 1.0, 1.0, Color(0.78, 0.86, 0.3, a), sc)         # an eye
		_r(-4.0, -5.0 + bob, 1.0, 2.0, k, sc)                                # the tail, up and curling
		_r(-5.0, -6.0 + bob - float(ph), 1.0, 2.0, k, sc)
		if ph == 0:                                                          # legs reaching / pushing off
			_r(3.0, -1.0, 2.0, 1.0, k, sc)
			_r(-4.0, -1.0, 2.0, 1.0, k, sc)
			_r(0.0, -1.0, 1.0, 1.0, k, sc)
		else:
			_r(1.0, -1.0, 1.0, 1.0, k, sc)
			_r(-2.0, -1.0, 1.0, 1.0, k, sc)
			_r(4.0, -1.0, 1.0, 1.0, k, sc)
			_r(-3.0, -1.0, 1.0, 1.0, k, sc)

	func _draw_person(sc: float) -> void:
		var shirt := Color(0.8, 0.28, 0.24)
		var legs := Color(0.16, 0.18, 0.28)
		var ph := int(clock * 9.0) % 2
		var bob := -1.0 if ph == 0 else 0.0
		var lean := 1.0                                                      # leaning into the run
		if ph == 0:                                                          # legs mid-stride, alternating
			_r(-1.0, -4.0, 1.0, 4.0, legs, sc)
			_r(2.0, -3.0, 2.0, 1.0, legs, sc)
			_r(3.0, -2.0, 1.0, 2.0, legs, sc)
		else:
			_r(1.0, -4.0, 1.0, 4.0, legs, sc)
			_r(-3.0, -3.0, 2.0, 1.0, legs, sc)
			_r(-3.0, -2.0, 1.0, 2.0, legs, sc)
		_r(-1.0 + lean, -8.0 + bob, 3.0, 4.0, shirt, sc)                     # torso
		_r(0.0 + lean, -10.0 + bob, 2.0, 2.0, _skin, sc)                     # head
		_r(0.0 + lean, -11.0 + bob, 2.0, 1.0, Color(0.18, 0.12, 0.1), sc)
		_r(-2.0 + lean, -10.0 + bob - float(ph), 1.0, 3.0, _skin, sc)         # arms flung up and back in terror, flailing
		_r(3.0 + lean, -9.0 + bob + float(ph), 1.0, 3.0, _skin, sc)
		if ph == 0:                                                          # a puff of dust at the heels
			_r(-5.0, -1.0, 1.0, 1.0, Color(0.85, 0.8, 0.7, 0.5), sc)
			_r(-7.0, -2.0, 1.0, 1.0, Color(0.85, 0.8, 0.7, 0.3), sc)

	## At the door: seen from behind, both fists going at the boards in turn.
	func _draw_pounding(sc: float) -> void:
		var shirt := Color(0.8, 0.28, 0.24)
		var legs := Color(0.16, 0.18, 0.28)
		var beat := int(clock * 4.0) % 2
		_r(-2.0, -4.0, 2.0, 4.0, legs, sc)
		_r(1.0, -4.0, 2.0, 4.0, legs, sc)
		_r(-2.0, -9.0, 5.0, 5.0, shirt, sc)                                  # the back
		_r(-1.0, -12.0, 3.0, 3.0, Color(0.18, 0.12, 0.1), sc)                # the head, seen from behind: hair
		_r(-4.0, -12.0 - float(beat), 1.0, 4.0, _skin, sc)                   # one arm up on the boards, then the other
		_r(4.0, -12.0 - float(1 - beat), 1.0, 4.0, _skin, sc)


# ---- people at the windows ---------------------------------------------------------------------------------------------------
# Tiny pixel people in the glass of some lit windows (9 x 8 px of glass, a figure ~5 wide and 7 tall) — owner round 49: "people at windows
# could be more animated". Each is a little figure (hair, head, torso, arms, legs) doing one thing, a pure function of the clock:
#   wave   — an arm up, waving a pale cloth;       pace   — walking from side to side;         peer — standing at the glass, now and
#   then leaning in to look down;                  sway   — rocking on the spot, arms wrapped round themselves;
#   pound  — both fists on the glass in turn;      shout  — hands cupped at the mouth, head thrown back now and then;
#   huddle — an adult with a child held in;        phone  — a phone to the ear, turning away, its screen a pale dot;
#   slump  — only the head and shoulders above the sill, rocking, now and then looking up.
# And in OTHER lit windows (`passers`) a dim shadow walks across behind the curtain every so often.
class _Survivors:
	extends Node2D

	const SKINS := [Color(0.76, 0.58, 0.46), Color(0.62, 0.45, 0.34), Color(0.88, 0.7, 0.58)]
	const HAIRS := [Color(0.10, 0.07, 0.06), Color(0.30, 0.18, 0.10), Color(0.78, 0.66, 0.38), Color(0.5, 0.5, 0.52)]
	var people: Array = []
	var passers: Array = []                           # lit windows with nobody at them: [{x, y, w, h, phase, period}]
	var clock := 0.0
	var run := 1

	## Where the figure's centre column is, in the glass (0..8).
	func person_x(p: Dictionary) -> float:
		var ph: float = float(p.get("phase", 0.0))
		match String(p.get("kind", "peer")):
			"pace":
				return 4.0 + 2.0 * sin(clock * 0.55 + ph)
			"wave", "shout":
				return 4.0
			"sway", "huddle":
				return 4.0 + 0.6 * sin(clock * 0.7 + ph)
			"phone":
				return 4.0 + 1.2 * sin(clock * 0.45 + ph)
		return 3.0 + float(int(ph * 10.0) % 3)

	func _shade(c: Color, dim: float) -> Color:
		return Color(c.r * dim, c.g * dim, c.b * dim, c.a)

	func _r(gx: float, gy: float, x: float, y: float, w: float, h: float, col: Color) -> void:
		draw_rect(Rect2(gx + x, gy + y, w, h), col)

	func _draw() -> void:
		var dim := 1.0 if run == 1 else (0.82 if run == 2 else 0.7)
		for p in people:
			_draw_person(p, dim)
		for q in passers:
			_draw_passer(q)

	func _draw_person(p: Dictionary, dim: float) -> void:
		var gx: float = float(p["x"])
		var gy: float = float(p["y"])
		var ph: float = float(p.get("phase", 0.0))
		var kind := String(p.get("kind", "peer"))
		var cx := roundf(person_x(p))
		var face := 1.0
		if kind == "pace":
			face = 1.0 if cos(clock * 0.55 + ph) >= 0.0 else -1.0
		var k := int(ph * 100.0)
		var skin := _shade(SKINS[k % SKINS.size()], dim)
		var hair := _shade(HAIRS[(k / 3) % HAIRS.size()], dim)
		var shirt0 := Color.from_string("#" + String(p.get("shirt", "c9605a")), Color(0.8, 0.4, 0.35))
		var shirt := _shade(Color(shirt0.r * 0.8, shirt0.g * 0.8, shirt0.b * 0.8), dim)
		var legs := _shade(Color(0.14, 0.13, 0.18), dim)
		var cloth := _shade(Color(0.92, 0.9, 0.84), dim)
		var by := 0.0                                                       # the whole body's drop (leaning in)
		var t := clock + ph
		match kind:
			"peer":
				if fposmod(t, 3.2) < 0.45:
					by = 1.0
			"slump":
				by = 4.0 + (1.0 if sin(t * 0.9) > 0.5 else 0.0)
			"pound":
				by = 1.0
		# legs and torso (a slump shows only the head and shoulders)
		if kind != "slump":
			var step := 0.0
			if kind == "pace" and int(clock * 3.0) % 2 == 0:
				step = 1.0
			_r(gx, gy, cx - 1.0, 6.0, 1.0, 2.0, legs)
			_r(gx, gy, cx + 1.0 - step, 6.0, 1.0, 2.0 - step, legs)
			_r(gx, gy, cx - 1.0, 3.0 + by, 3.0, 3.0 - by, shirt)
		else:
			_r(gx, gy, cx - 2.0, 5.0 + by, 5.0, 8.0 - 5.0 - by, shirt)
		# head: hair over a face (looking the way it faces)
		var hx := cx - 1.0 + (1.0 if face > 0.0 else 0.0)
		var hy := 1.0 + by
		if kind == "shout" and fposmod(t, 2.6) < 0.7:
			hy -= 1.0                                                        # head thrown back
		_r(gx, gy, hx, hy, 2.0, 2.0, skin)
		_r(gx, gy, hx, hy, 2.0, 1.0, hair)
		# arms
		match kind:
			"wave":
				var up := sin(clock * 8.0 + ph) > 0.0
				var ay := 0.0 if up else 1.0
				_r(gx, gy, cx + 2.0, 1.0 + ay, 1.0, 3.0, skin)
				_r(gx, gy, cx + 2.0, ay, 2.0, 1.0, cloth)                    # the cloth in the hand
				_r(gx, gy, cx - 2.0, 4.0, 1.0, 2.0, shirt)
			"pound":
				var beat := int(clock * 6.0) % 2
				_r(gx, gy, cx - 2.0, 2.0 + float(beat), 1.0, 2.0, skin)
				_r(gx, gy, cx + 2.0, 2.0 + float(1 - beat), 1.0, 2.0, skin)
				if fposmod(clock * 6.0, 1.0) < 0.2:                           # the knock lands: a flash on the glass
					_r(gx, gy, cx - 3.0 + 5.0 * float(beat), 3.0, 1.0, 1.0, Color(1, 1, 1, 0.5))
			"shout":
				_r(gx, gy, cx - 2.0, 2.0, 1.0, 2.0, skin)
				_r(gx, gy, cx + 2.0, 2.0, 1.0, 2.0, skin)
				if fposmod(t, 2.6) < 0.7:
					_r(gx, gy, hx + 0.0, hy + 1.0, 1.0, 1.0, _shade(Color(0.25, 0.08, 0.08), dim))    # the mouth open
			"phone":
				_r(gx, gy, cx + 2.0, 2.0, 1.0, 2.0, skin)
				_r(gx, gy, cx + 1.0, 2.0, 1.0, 1.0, skin)
				_r(gx, gy, cx + 2.0, 1.0, 1.0, 1.0, Color(0.7, 0.85, 1.0, 0.95))          # the screen's pale dot
				_r(gx, gy, cx - 2.0, 4.0, 1.0, 2.0, shirt)
			"sway":
				_r(gx, gy, cx - 2.0, 4.0, 1.0, 1.0, shirt)                   # arms folded across the chest
				_r(gx, gy, cx + 2.0, 4.0, 1.0, 1.0, shirt)
				_r(gx, gy, cx - 1.0, 4.0, 3.0, 1.0, shade_of(shirt, 0.85))
			"huddle":
				_r(gx, gy, cx - 2.0, 4.0, 1.0, 2.0, shirt)
				# the child, held in at the adult's side
				var child := _shade(Color(0.9, 0.75, 0.3), dim)
				_r(gx, gy, cx + 2.0, 4.0, 2.0, 3.0, child)
				_r(gx, gy, cx + 2.0, 3.0, 2.0, 1.0, skin)
				_r(gx, gy, cx + 1.0, 4.0, 1.0, 1.0, skin)                    # the adult's arm round them
			"slump":
				pass
			_:
				_r(gx, gy, cx - 2.0, 4.0, 1.0, 2.0, shirt)
				_r(gx, gy, cx + 2.0, 4.0, 1.0, 2.0, shirt)

	func shade_of(c: Color, f: float) -> Color:
		return Color(c.r * f, c.g * f, c.b * f, c.a)

	## A dim figure crossing behind the curtain of a lit window, once a period; nothing the rest of the time.
	func _draw_passer(q: Dictionary) -> void:
		var period: float = float(q.get("period", 9.0))
		var u := fposmod(clock + float(q.get("phase", 0.0)) * period, period) / 2.4        # 0..1 while it crosses
		if u < 0.0 or u > 1.0:
			return
		var gx: float = float(q["x"])
		var gy: float = float(q["y"])
		var x := roundf(lerpf(-1.0, 9.0, u))
		var step := 1.0 if int(u * 7.0) % 2 == 0 else 0.0
		var col := Color(0.12, 0.08, 0.07, 0.62)
		draw_rect(Rect2(gx + x, gy + 1.0, 2.0, 2.0), col)                                 # head
		draw_rect(Rect2(gx + x - 0.5 + 0.5, gy + 3.0, 2.0, 3.0), col)                     # body
		draw_rect(Rect2(gx + x, gy + 6.0, 1.0, 2.0 - step), col)                          # legs
		draw_rect(Rect2(gx + x + 1.0, gy + 6.0, 1.0, 1.0 + step), col)


# ---- rain over the whole picture (night) --------------------------------------------------------------------------------
# PIXEL rain (owner round 36j: "pixel animated rain"): every drop is a short run of whole game-pixels (4x4 on screen) stepping left as it
# falls, in two depths — a dim, slow, small far sheet and a brighter, faster, longer near one — so it reads as the same pixel art as the
# picture instead of anti-aliased lines laid over it. Ripples (two-pixel splashes) pop on the garden's ground while it is on screen.
class _Rain:
	extends Control

	const PX := 4.0
	const N_FAR := 170
	const N_NEAR := 100
	var drops: Array = []
	var splashes: Array = []                # [{"x": float (0..1), "y": float (screen px), "age": float}]
	var clock := 0.0
	var ground_y := -1.0                    # screen y of the garden's ground line (set by the opening each frame; < 0 = off screen)
	var _splash_in := 0.0

	func _ready() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = 77
		for i in N_FAR:
			drops.append({"x": r.randf(), "y": r.randf(), "v": 0.55 + r.randf() * 0.35, "segs": 2, "a": 0.20 + r.randf() * 0.12})
		for i in N_NEAR:
			drops.append({"x": r.randf(), "y": r.randf(), "v": 1.05 + r.randf() * 0.55, "segs": 3 + (i % 2), "a": 0.38 + r.randf() * 0.22})

	func _process(delta: float) -> void:
		clock += delta
		for d in drops:
			d["y"] = float(d["y"]) + delta * float(d["v"]) * 1.25
			d["x"] = float(d["x"]) - delta * float(d["v"]) * 0.10
			if float(d["y"]) > 1.0:
				d["y"] = -0.05
				d["x"] = fposmod(float(d["x"]) + 0.37, 1.0)
			if float(d["x"]) < -0.02:
				d["x"] = 1.02
		_splash_in -= delta
		if _splash_in <= 0.0 and ground_y >= 0.0 and ground_y < size.y - 40.0 and splashes.size() < 40:    # ripples on the garden while it is on screen
			_splash_in = 0.04 + randf() * 0.05
			var top := ground_y + 24.0
			var bottom := minf(size.y - 8.0, ground_y + 172.0)
			splashes.append({"x": randf(), "y": top + randf() * maxf(1.0, bottom - top), "age": 0.0})
		for sp in splashes:
			sp["age"] = float(sp["age"]) + delta
		splashes = splashes.filter(func(sp): return float(sp["age"]) < 0.22)
		queue_redraw()

	func _snap(v: float) -> float:
		return floorf(v / PX) * PX

	func _draw() -> void:
		var w := size.x
		var h := size.y
		for d in drops:
			var x := _snap(float(d["x"]) * w)
			var y := _snap(float(d["y"]) * h)
			var col := Color(0.74, 0.82, 0.97, float(d["a"]))
			for k in int(d["segs"]):
				draw_rect(Rect2(x - float(k / 2) * PX, y + float(k) * PX, PX, PX), col)
		for sp in splashes:
			var a := 1.0 - float(sp["age"]) / 0.22
			var x := _snap(float(sp["x"]) * w)
			var y := _snap(float(sp["y"]))
			var col := Color(0.78, 0.86, 1.0, 0.45 * a)
			draw_rect(Rect2(x - PX, y, PX, PX), col)
			draw_rect(Rect2(x + PX, y, PX, PX), col)


# ---- a bolt of lightning (night) ---------------------------------------------------------------------------------------------------
# A jagged pixel bolt that cracks down through the sky beside the tower, lit for a few frames with the flash; the shape is re-rolled for each strike.
class _Bolt:
	extends Control

	const PX := 4.0
	var pts: Array = []                     # whole-pixel cells of the bolt, screen coords
	var life := 0.0

	func strike(rng: RandomNumberGenerator, left_side: bool) -> void:
		pts.clear()
		var x := (60.0 + rng.randf() * 160.0) if left_side else (880.0 + rng.randf() * 200.0)
		var y := 0.0
		var limit := 300.0 + rng.randf() * 160.0
		while y < limit:
			pts.append(Vector2(floorf(x / PX) * PX, floorf(y / PX) * PX))
			y += PX
			x += PX * float(rng.randi_range(-1, 1)) * (1.0 if rng.randf() < 0.55 else 0.0)
			if rng.randf() < 0.07 and y > 80.0:                       # a short fork
				var fx := x
				var fy := y
				var dir := -1.0 if rng.randf() < 0.5 else 1.0
				for j in rng.randi_range(3, 7):
					fx += PX * dir
					fy += PX * (1.0 if j % 2 == 0 else 0.0)
					pts.append(Vector2(floorf(fx / PX) * PX, floorf(fy / PX) * PX))
		life = 0.20

	func _process(delta: float) -> void:
		if life > 0.0:
			life = maxf(0.0, life - delta)
			queue_redraw()

	func _draw() -> void:
		if life <= 0.0:
			return
		var a := clampf(life / 0.20, 0.0, 1.0)
		for p in pts:
			draw_rect(Rect2(p - Vector2(PX, 0.0), Vector2(PX * 3.0, PX)), Color(0.55, 0.65, 1.0, 0.30 * a))
			draw_rect(Rect2(p, Vector2(PX, PX)), Color(0.96, 0.98, 1.0, a))
