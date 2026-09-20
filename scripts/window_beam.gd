extends Node2D

# A natural light BEAM (god-ray shaft) slanting in through a window or balcony door — the
# owner's "beams of light through these windows". TWO parts so it reads in ANY ambient:
#   * a VISIBLE volumetric shaft — an ADDITIVE soft-edged sprite (FL.beam_texture) tinted by
#     time of day, so the beam shows even in a bright DAY room (a PointLight2D alone ADDS over
#     the ambient and washes out when the room is already lit);
#   * a REAL PointLight2D beam (same cookie) so the shaft actually LIGHTS the floor and
#     anything that walks through it — genuinely dynamic, not just a painted overlay.
# The sun's ANGLE + COLOUR come from the run: a warm morning beam slanting one way, a warm
# afternoon beam the other, a near-vertical cool MOONBEAM at night (FL.BEAM_* tables). Each
# window also gets a STABLE per-window jitter (angle / length / brightness) off its world
# position so the beams don't read copy-pasted. (No dust motes — they read as indoor snow.)
# A slow shimmer + micro angle-drift keep it alive. Drawn at z0 (behind actors) so the beam
# lands on the wall/floor and never washes the player.

const FL = preload("res://scripts/floor_lighting.gd")

var _shaft: Sprite2D = null
var _light: PointLight2D = null
var _base_alpha := 0.0
var _base_energy := 0.0
var _base_rot := 0.0
var _t := 0.0


func setup(pos: Vector2, length_scale: float = 1.0, energy_scale: float = 1.0, _live: bool = true) -> void:
	position = pos
	z_index = 0
	add_to_group("window_beam")
	var i: int = clampi(WorldState.current_run - 1, 0, 2)
	var tint: Color = FL.BEAM_TINT[i]

	# STABLE per-window variation so beams aren't uniform copy-paste: seed off this window's
	# world position (each window is a distinct, reproducible seed). Jitter the slant, length
	# and brightness a little — no two windows cast an identical shaft.
	var wp := global_position
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(int(round(wp.x))) + "_" + str(int(round(wp.y))) + "beam")
	var slant: float = FL.BEAM_SLANT_BY_RUN[i] + rng.randf_range(-0.16, 0.16)
	var len_scale: float = length_scale * rng.randf_range(0.82, 1.20)
	var bright: float = rng.randf_range(0.80, 1.15)
	_base_rot = slant

	# The VISIBLE shaft: an additive sprite so it reads over any ambient (a plain light would
	# wash out in a bright day room). len_scale stretches it to reach the floor per placement.
	_shaft = Sprite2D.new()
	_shaft.texture = FL.beam_texture()
	_shaft.rotation = slant
	_shaft.scale = Vector2(1.0, len_scale)
	_shaft.z_index = 0
	_shaft.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_shaft.material = mat
	_base_alpha = FL.BEAM_ALPHA[i] * energy_scale * bright
	_shaft.modulate = Color(tint.r, tint.g, tint.b, _base_alpha)
	add_child(_shaft)

	# The REAL cast light — a modest beam so the shaft actually lights the floor / a passer-by.
	_light = PointLight2D.new()
	_light.texture = FL.beam_texture()
	_light.color = tint
	_light.energy = FL.BEAM_LIGHT_ENERGY[i] * energy_scale * bright
	_light.rotation = slant
	_light.z_index = 0
	_base_energy = _light.energy
	add_child(_light)


func _process(delta: float) -> void:
	_t += delta
	var s := 0.90 + 0.10 * sin(_t * 0.7)          # gentle brightness shimmer
	var drift := 0.015 * sin(_t * 0.3)            # micro angle drift (a lazy sunbeam)
	if is_instance_valid(_shaft):
		_shaft.modulate.a = _base_alpha * s
		_shaft.rotation = _base_rot + drift
	if is_instance_valid(_light):
		_light.energy = _base_energy * s
		_light.rotation = _base_rot + drift
