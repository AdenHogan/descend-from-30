extends Node2D

# A natural light BEAM (god-ray shaft) slanting in through a window or balcony door — the
# owner's "beams of light through these windows". TWO parts so it reads in ANY ambient:
#   * a VISIBLE volumetric shaft — an ADDITIVE soft-edged sprite (FL.beam_texture) tinted by
#     time of day, so the beam shows even in a bright DAY room (a PointLight2D alone ADDS over
#     the ambient and washes out when the room is already lit);
#   * a REAL PointLight2D beam (same cookie) so the shaft actually LIGHTS the floor and
#     anything that walks through it — genuinely dynamic, not just a painted overlay.
# The sun's ANGLE + COLOUR come from the run: a warm morning beam slanting one way, a warm
# afternoon beam the other, a near-vertical cool MOONBEAM at night (FL.BEAM_* tables). Faint
# DUST MOTES drift down the shaft (live only) and a slow shimmer + micro-drift keep it alive.
# Drawn at z0 (behind actors) so the beam lands on the wall/floor and never washes the player.

const FL = preload("res://scripts/floor_lighting.gd")

var _shaft: Sprite2D = null
var _light: PointLight2D = null
var _base_alpha := 0.0
var _base_energy := 0.0
var _base_rot := 0.0
var _t := 0.0


func setup(pos: Vector2, length_scale: float = 1.0, energy_scale: float = 1.0, live: bool = true) -> void:
	position = pos
	z_index = 0
	add_to_group("window_beam")
	var i: int = clampi(WorldState.current_run - 1, 0, 2)
	var slant: float = FL.BEAM_SLANT_BY_RUN[i]
	var tint: Color = FL.BEAM_TINT[i]
	_base_rot = slant

	# The VISIBLE shaft: an additive sprite so it reads over any ambient (a plain light would
	# wash out in a bright day room). Length_scale stretches it to reach the floor per placement.
	_shaft = Sprite2D.new()
	_shaft.texture = FL.beam_texture()
	_shaft.rotation = slant
	_shaft.scale = Vector2(1.0, length_scale)
	_shaft.z_index = 0
	_shaft.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_shaft.material = mat
	_base_alpha = FL.BEAM_ALPHA[i] * energy_scale
	_shaft.modulate = Color(tint.r, tint.g, tint.b, _base_alpha)
	add_child(_shaft)

	# The REAL cast light — a modest beam so the shaft actually lights the floor / a passer-by.
	_light = PointLight2D.new()
	_light.texture = FL.beam_texture()
	_light.color = tint
	_light.energy = FL.BEAM_LIGHT_ENERGY[i] * energy_scale
	_light.rotation = slant
	_light.z_index = 0
	_base_energy = _light.energy
	add_child(_light)

	if live:
		_add_motes(slant, tint)


func _add_motes(slant: float, tint: Color) -> void:
	# Faint dust drifting slowly DOWN the beam — the "alive" tell of a real sunbeam.
	var motes := CPUParticles2D.new()
	motes.texture = _mote_texture()
	motes.z_index = 0
	motes.amount = 9
	motes.lifetime = 4.0
	motes.preprocess = 4.0                        # already mid-drift, no empty first beat
	motes.local_coords = false
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(22.0, 10.0)
	var dir := Vector2(sin(slant), cos(slant))    # straight down, rotated by the slant
	motes.direction = dir
	motes.spread = 14.0
	motes.gravity = dir * 6.0                      # a lazy downward drift
	motes.initial_velocity_min = 3.0
	motes.initial_velocity_max = 9.0
	motes.scale_amount_min = 0.5
	motes.scale_amount_max = 1.2
	motes.color = Color(tint.r, tint.g, tint.b, 0.5)
	motes.position = dir * 26.0                    # seed them a little down into the shaft
	add_child(motes)


func _mote_texture() -> Texture2D:
	var img := Image.create(3, 3, false, Image.FORMAT_RGBA8)
	for y in range(3):
		for x in range(3):
			var d := Vector2(x - 1, y - 1).length() / 1.5
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


func _process(delta: float) -> void:
	_t += delta
	var s := 0.90 + 0.10 * sin(_t * 0.7)          # gentle brightness shimmer
	var drift := 0.015 * sin(_t * 0.3)            # micro angle drift (dust in a lazy sunbeam)
	if is_instance_valid(_shaft):
		_shaft.modulate.a = _base_alpha * s
		_shaft.rotation = _base_rot + drift
	if is_instance_valid(_light):
		_light.energy = _base_energy * s
		_light.rotation = _base_rot + drift
