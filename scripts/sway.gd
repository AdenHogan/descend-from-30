extends RefCounted

## WIND SWAY (owner round 26 — "animations for certain items like the dripping milk or flowers moving
## in the wind"). A tiny canvas_item shader that leans a sprite's upper part side to side, PINNED at its
## foot, in WHOLE-TEXEL steps so it stays pixel art (no smeared resampling). Used by the corridor's
## potted plants today; the same call will drive curtains, hanging things and flower stems as the art
## for them is split out (docs/MOTION.md).
##
## How it works: the sprite gets a per-sprite ShaderMaterial (Compatibility has no per-instance
## uniforms) sharing ONE Shader. The texture is re-made with a few transparent columns either side so a
## leaning frond isn't cut off at the old edge; the sprite is shifted left by the same amount, so where
## it stands on the floor doesn't change by a pixel.
##
## The wind is GUSTS, not a constant sway (owner round 34 — "a small potted plant with no leaves… no reason whatsoever that it
## should be swaying… we just want some leaves, or cloths, or things that might drape to interact with the wind sometimes… we
## also don't need the pixel jump on the animation to be so extreme. The plant looked like it was cut up when it swayed"):
##   * only things that CAN move in a draught move — leafy plants, hanging vines, (later) cloth and drapes. A dead or dry plant,
##     ivy stuck to a wall, a dense bush, roots, moss and fungus never do (growth.json marks them pin "none");
##   * it is still most of the time: a slow envelope (`gust`) opens for a few seconds now and then, and only then do leaves
##     flutter — a breath of wind, not a fan;
##   * the lean is at most ONE texel for everything that stands (`MAX_STAND`), two for a long hanging vine (`MAX_HANG`) — a
##     bigger jump tore thin stems into disconnected rows. The offsets are still whole texels, so it stays pixel art.
## Seeded per sprite so no two plants gust together, and windier later in the day — a morning draught, a rising afternoon
## wind, a night storm (the same storm the apartment windows already show): later runs gust more often, never harder.

const PAD := 4                                  # transparent columns added each side of the texture

# The most a sprite ever leans, in texels, whatever the wind: 1 for anything that stands, 2 for a hanging vine.
const MAX_STAND := 1.45                         # < 1.5, so the rounding below can never reach a second texel
const MAX_HANG := 2.45

# base decal name -> {amp: tip travel in texels at wind 1.0, base: fraction of the height (from the foot)
# that stays put — the pot / the stand, speed: flutter rate}. Corridor planters only: a DEAD planter (`plant_dead`) is
# not listed — it has nothing to catch the wind.
const KINDS := {
	"plant_tall": {"amp": 1.25, "base": 0.34, "speed": 1.1},
	"plant_stand": {"amp": 1.1, "base": 0.55, "speed": 1.3},
}
const WIND_BY_RUN := [0.6, 1.0, 1.7]            # morning / afternoon / night

# OVERGROWTH sprites (tools/art/growth.py) by kind: hanging vines swing from the ceiling with a wave that
# travels down them (`lag`), the rest lean from the foot. `pin` top|bottom. Only kinds with LEAVES (or a drape) are listed:
# ivy that clings to a wall (creeper) and dense bushes (shrub) are rigid, roots / moss / fungus are static, and growth.py marks
# every dry or dead sprite pin "none" even in a listed kind — `growth_spec` below is the one gate.
const GROWTH := {
	"hang": {"amp": 2.0, "base": 0.0, "speed": 0.8, "pin": "top", "lag": 2.0, "max": MAX_HANG},
	"tuft": {"amp": 1.1, "base": 0.1, "speed": 1.5, "pin": "bottom", "lag": 0.6},
	"flower": {"amp": 1.25, "base": 0.15, "speed": 1.2, "pin": "bottom", "lag": 0.8},
	"fern": {"amp": 1.1, "base": 0.1, "speed": 1.0, "pin": "bottom", "lag": 1.0},
	"potted": {"amp": 1.25, "base": 0.35, "speed": 1.0, "pin": "bottom", "lag": 1.0},
}

# THE GUST: a slow envelope, mostly shut. e = two slow sines (periods ~30 s and ~17 s); the envelope opens when e climbs past
# GUST_OPEN (lower in a windier run, so night gusts more often) and is fully open at GUST_FULL. The shader and `gust_at`
# below are the same maths, built from the same constants — the test samples the CPU copy.
const GUST_OPEN := 0.45
const GUST_OPEN_PER_WIND := 0.10                # the threshold drops by this much per unit of wind
const GUST_FULL := 0.92

const _SHADER_TEMPLATE := """
shader_type canvas_item;
uniform float amp = 1.0;
uniform float max_amp = %s;
uniform float base = 0.3;
uniform float speed = 1.1;
uniform float phase = 0.0;
uniform float wind = 1.0;
uniform float pin_top = 0.0;
uniform float lag = 0.0;
float gust(float t) {
	float e = sin(t * 0.21 + phase) * 0.6 + sin(t * 0.37 + phase * 2.3 + 1.1) * 0.4;
	return smoothstep(%s - %s * wind, %s, e);
}
void fragment() {
	float from_foot = clamp(((1.0 - UV.y) - base) / max(1.0 - base, 0.001), 0.0, 1.0);
	float from_top = clamp((UV.y - base) / max(1.0 - base, 0.001), 0.0, 1.0);
	float h = pin_top > 0.5 ? from_top : from_foot;
	float t = TIME * speed + phase + h * lag;
	float w = (sin(t) * 0.7 + sin(t * 2.3 + 1.7) * 0.3) * gust(TIME);
	float a = min(amp * wind, max_amp);
	float off = floor(w * a * h * h + 0.5);
	COLOR = texture(TEXTURE, UV + vec2(off * TEXTURE_PIXEL_SIZE.x, 0.0));
}
"""


static func _make_shader_code() -> String:
	return _SHADER_TEMPLATE % [str(MAX_STAND), str(GUST_OPEN), str(GUST_OPEN_PER_WIND), str(GUST_FULL)]


static var SHADER_CODE: String = _make_shader_code()

static var _shader: Shader = null
static var _padded: Dictionary = {}             # texture path -> padded ImageTexture


static func wind_for_run(run: int) -> float:
	return float(WIND_BY_RUN[clampi(run - 1, 0, WIND_BY_RUN.size() - 1)])


## 0..1: how open the gust envelope is at time `t` for a sprite with this `phase`, in a run with this `wind`.
static func gust_at(t: float, phase: float, wind: float) -> float:
	var e: float = sin(t * 0.21 + phase) * 0.6 + sin(t * 0.37 + phase * 2.3 + 1.1) * 0.4
	return smoothstep(GUST_OPEN - GUST_OPEN_PER_WIND * wind, GUST_FULL, e)


## The whole-texel lean of the row at `h` (0 at the pinned end .. 1 at the free tip) at time `t` — the shader's offset.
static func offset_at(t: float, spec: Dictionary, phase: float, wind: float, h: float) -> int:
	var tt: float = t * float(spec["speed"]) + phase + h * float(spec.get("lag", 0.0))
	var w: float = (sin(tt) * 0.7 + sin(tt * 2.3 + 1.7) * 0.3) * gust_at(t, phase, wind)
	var a: float = minf(float(spec["amp"]) * wind, float(spec.get("max", MAX_STAND)))
	return int(floor(w * a * h * h + 0.5))


## The spec a growth sprite sways with, or {} if it doesn't (`entry` = its growth.json record {kind, pin, …}). A sprite
## sways only if its kind has leaves or a drape AND the art tool didn't mark it still (dead, dry, wall-bound, rigid).
static func growth_spec(entry: Dictionary) -> Dictionary:
	if str(entry.get("pin", "none")) == "none":
		return {}
	return GROWTH.get(str(entry.get("kind", "")), {})


static func spec_for(base_name: String) -> Dictionary:
	return KINDS.get(base_name, {})


static func shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER_CODE
	return _shader


## `tex` with PAD transparent columns on both sides (cached — every plant of a kind shares one).
static func padded_texture(tex: Texture2D) -> Texture2D:
	var key: String = tex.resource_path if tex.resource_path != "" else str(tex.get_instance_id())
	if _padded.has(key):
		return _padded[key]
	var src: Image = tex.get_image()
	if src.is_compressed():
		src.decompress()
	src.convert(Image.FORMAT_RGBA8)
	var dst := Image.create(src.get_width() + PAD * 2, src.get_height(), false, Image.FORMAT_RGBA8)
	dst.blit_rect(src, Rect2i(0, 0, src.get_width(), src.get_height()), Vector2i(PAD, 0))
	var out := ImageTexture.create_from_image(dst)
	_padded[key] = out
	return out


## Make `s` (a top-left-anchored Sprite2D) sway like the decal `base_name`. Returns false if that
## kind doesn't sway. Where the sprite stands is unchanged (its texture grows by PAD each side and
## the node moves left by PAD).
static func apply(s: Sprite2D, base_name: String, seed_: int, run: int) -> bool:
	var spec: Dictionary = spec_for(base_name)
	if spec.is_empty():
		return false
	return apply_spec(s, spec, seed_, run)


## As apply(), for any spec {amp, base, speed, pin?, lag?} — the overgrowth sprites use this.
static func apply_spec(s: Sprite2D, spec: Dictionary, seed_: int, run: int) -> bool:
	if s.texture == null or s.get_meta("sway", false):
		return false
	s.texture = padded_texture(s.texture)
	s.position.x -= float(PAD)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var m := ShaderMaterial.new()
	m.shader = shader()
	m.set_shader_parameter("amp", float(spec["amp"]))
	m.set_shader_parameter("max_amp", float(spec.get("max", MAX_STAND)))
	m.set_shader_parameter("base", float(spec["base"]))
	m.set_shader_parameter("speed", float(spec["speed"]) * rng.randf_range(0.85, 1.15))
	m.set_shader_parameter("phase", rng.randf() * TAU)
	m.set_shader_parameter("wind", wind_for_run(run))
	m.set_shader_parameter("pin_top", 1.0 if str(spec.get("pin", "bottom")) == "top" else 0.0)
	m.set_shader_parameter("lag", float(spec.get("lag", 0.0)))
	s.material = m
	s.set_meta("sway", true)
	return true
