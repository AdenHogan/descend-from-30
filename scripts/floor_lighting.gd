extends Node2D

# REAL corridor lighting (GL Compatibility PointLight2D) — replaces the flat colour
# filter. A row of warm ceiling lamps casts actual light POOLS through the dark ambient
# (WorldState sets the ambient CanvasModulate). Some lamps FLICKER; some are DEAD —
# and the deeper/darker the floor (and the later the run) the more are out, so the
# lower building reads as failing, unlit and tense rather than tinted. Deterministic
# per (floor, run, master_seed) so a floor looks the same on re-entry and a pan
# backdrop matches its live commit.
#
# building_floors installs one of these (live _ready AND go_live). Fire adds its own
# light (fire_field); the player carries a faint aura (player.gd).

const LIGHT_Y := 250.0                       # just under the ceiling
const X_START := 200.0
const X_END := 1150.0
const COUNT := 6
const WARM := Color(1.0, 0.85, 0.60)
const LAMP_SCALE := 3.2                      # pool radius (texture_scale)
const LAMP_ENERGY := 1.05

static var _tex: Texture2D = null

var _lamps: Array = []                        # {light, base, phase, speed, flick}


static func light_texture() -> Texture2D:
	# A soft radial cookie shared by every light (ceiling, fire, player aura).
	if _tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(0.5, 0.0)
		gt.width = 256
		gt.height = 256
		_tex = gt
	return _tex


func setup(floor_num: int) -> void:
	z_index = 0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(WorldState.master_seed) + "lights" + str(floor_num) + str(WorldState.current_run))
	# How many lamps are dead: a few up top in the morning, most of them deep at night.
	var dead_frac: float = clampf(0.06 + WorldState.infection_depth(floor_num) * 0.45 \
		+ float(WorldState.current_run - 1) * 0.12, 0.0, 0.75)
	for i in range(COUNT):
		var x: float = lerpf(X_START, X_END, float(i) / float(COUNT - 1))
		var lamp := PointLight2D.new()
		lamp.texture = light_texture()
		lamp.position = Vector2(x, LIGHT_Y)
		lamp.color = WARM
		lamp.texture_scale = LAMP_SCALE
		lamp.energy = LAMP_ENERGY
		add_child(lamp)
		# A small visible fixture/bulb so the source reads, not just the pool.
		var bulb := Sprite2D.new()
		bulb.texture = light_texture()
		bulb.position = Vector2(x, LIGHT_Y)
		bulb.scale = Vector2(0.12, 0.12)
		bulb.modulate = WARM
		add_child(bulb)
		var dead: bool = rng.randf() < dead_frac
		if dead:
			lamp.visible = false
			bulb.modulate = Color(0.15, 0.14, 0.12)   # a dark, dead fixture
			continue
		var flick: bool = rng.randf() < 0.30
		_lamps.append({
			"light": lamp, "bulb": bulb, "base": LAMP_ENERGY,
			"phase": rng.randf() * TAU, "speed": rng.randf_range(7.0, 15.0), "flick": flick,
		})


func _process(delta: float) -> void:
	for e in _lamps:
		if not e["flick"] or not is_instance_valid(e["light"]):
			continue
		e["phase"] += delta * e["speed"]
		var f: float = 0.80 + 0.20 * sin(e["phase"]) + randf_range(-0.07, 0.07)
		e["light"].energy = e["base"] * f
		if is_instance_valid(e["bulb"]):
			e["bulb"].modulate = WARM * clampf(f, 0.2, 1.2)
