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
## The wind itself is a sum of slow sines (a gentle sway plus a slower gust), seeded per sprite so no
## two plants move in step, and STRONGER later in the day — a morning draught, a rising afternoon
## wind, a night storm (the same storm the apartment windows already show).

const PAD := 4                                  # transparent columns added each side of the texture

# base decal name -> {amp: tip travel in texels at wind 1.0, base: fraction of the height (from the foot)
# that stays put — the pot / the stand, speed: sway rate}
const KINDS := {
	"plant_tall": {"amp": 1.7, "base": 0.34, "speed": 1.1},
	"plant_stand": {"amp": 1.3, "base": 0.55, "speed": 1.3},
	"plant_dead": {"amp": 0.9, "base": 0.30, "speed": 0.9},
}
const WIND_BY_RUN := [0.6, 1.0, 1.7]            # morning / afternoon / night

const SHADER_CODE := """
shader_type canvas_item;
uniform float amp = 1.5;
uniform float base = 0.3;
uniform float speed = 1.1;
uniform float phase = 0.0;
uniform float wind = 1.0;
void fragment() {
	float h = clamp(((1.0 - UV.y) - base) / max(1.0 - base, 0.001), 0.0, 1.0);
	float t = TIME * speed + phase;
	float w = sin(t) * 0.6 + sin(t * 2.3 + 1.7) * 0.25 + sin(TIME * 0.31 + phase) * 0.5;
	float off = floor(w * wind * amp * h * h + 0.5);
	COLOR = texture(TEXTURE, UV + vec2(off * TEXTURE_PIXEL_SIZE.x, 0.0));
}
"""

static var _shader: Shader = null
static var _padded: Dictionary = {}             # texture path -> padded ImageTexture


static func wind_for_run(run: int) -> float:
	return float(WIND_BY_RUN[clampi(run - 1, 0, WIND_BY_RUN.size() - 1)])


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
	if spec.is_empty() or s.texture == null or s.get_meta("sway", false):
		return false
	s.texture = padded_texture(s.texture)
	s.position.x -= float(PAD)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var m := ShaderMaterial.new()
	m.shader = shader()
	m.set_shader_parameter("amp", float(spec["amp"]))
	m.set_shader_parameter("base", float(spec["base"]))
	m.set_shader_parameter("speed", float(spec["speed"]) * rng.randf_range(0.85, 1.15))
	m.set_shader_parameter("phase", rng.randf() * TAU)
	m.set_shader_parameter("wind", wind_for_run(run))
	s.material = m
	s.set_meta("sway", true)
	return true
