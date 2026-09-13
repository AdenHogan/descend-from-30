extends Node2D

# REAL corridor lighting (GL Compatibility PointLight2D). Ceiling lamps cast DOWNWARD
# CONES (like sunlight/a spotlight from the fixture), not a flat blanket. Some sway gently
# side-to-side, some flicker, some BLINK (a failing tube), and some are DEAD — with MORE
# dead the deeper you go and the LATER the run (run 2 loses lamps, run 3 loses more), so
# the low/late building is genuinely dark and tense. At night the ambient is near-black
# (WorldState.ambient_color), so ONLY these cones — plus fire, the player aura, and the
# stairwell window daylight — light the scene, and enemies lurk unseen in the gaps until
# you walk into them. Deterministic per (floor, run, master_seed) so a floor looks the
# same on re-entry and a pan backdrop matches its live commit.
#
# building_floors installs one of these (live _ready, the passive backdrop, and go_live).
# Fire adds its own light (fire_field); the player carries a faint aura (player.gd);
# apartments add a balcony-window light (room.gd) via make_window_light().

const LIGHT_Y := 250.0                       # ceiling: the cone apex (bulb) sits here
const X_START := 200.0
const X_END := 1150.0
const COUNT := 6
const WARM := Color(1.0, 0.78, 0.45)          # a RICH cozy amber — warm pools vs a cool dark
const LAMP_SCALE := 1.15                       # cone reach (texture_scale)
# ADDITIVE light energy per run. 2D lights ADD on top of the ambient. By DAY the ambient
# still carries the scene, but the pools are PUNCHY enough to read as cozy warm islands
# against a cooler dusk; at NIGHT the ambient is near-black so the lamps are bright, defined
# shafts in the dark. (The budget: ambient + peak add ≈ 1.0 in the pool, no white blowout.)
const LAMP_ENERGY_BY_RUN := [0.34, 0.95, 1.9]  # morning / afternoon / night

# Stairwell windows — daylight spills in beside the stairs (moonlit at night).
const STAIR_WINDOW_LEFT_X := 171.0
const STAIR_WINDOW_RIGHT_X := 1179.0
const STAIR_WINDOW_Y := 300.0

# Natural light through a window: cool DAYLIGHT (keeps the pane's blue), warm lower
# afternoon, dim blue MOONLIGHT at night. Energy is the ADDITIVE amount over the ambient —
# SMALL by day (the scene is already lit; a big value blows the pane to white) and modest
# at night. A soft, fairly tight pool so it reads as light through a window, not a floodlight.
const WINDOW_CAST := [Color(0.80, 0.88, 1.00), Color(1.00, 0.90, 0.76), Color(0.55, 0.68, 1.00)]
const WINDOW_ENERGY := [0.16, 0.28, 0.30]
const WINDOW_SCALE := 1.6

static var _cone: Texture2D = null
static var _radial: Texture2D = null

var _lamps: Array = []


static func light_texture() -> Texture2D:
	# Soft ROUND cookie — fire, the player aura, and window fill.
	if _radial == null:
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
		_radial = gt
	return _radial


static func cone_texture() -> Texture2D:
	# A DOWNWARD cone/spotlight cookie, apex at the texture CENTRE — so a PointLight2D at
	# the fixture rotates the cone about the bulb when it sways. The top half is transparent
	# (no light above the bulb); the bottom half fans out and fades with depth + toward the
	# edges. Built once, shared by every ceiling lamp.
	if _cone == null:
		var w := 192
		var h := 384
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		var cx := float(w) * 0.5
		var apex_y := float(h) * 0.5
		var max_depth := float(h) * 0.5
		var top_half := 10.0                  # cone half-width at the bulb
		var bot_half := cx - 6.0              # cone half-width at full reach
		for y in range(h):
			var d := float(y) - apex_y
			if d <= 0.0:
				continue                      # nothing above the bulb
			var vf := d / max_depth           # 0 at bulb .. 1 at full reach
			var half := lerpf(top_half, bot_half, vf)
			var vfall := clampf(1.0 - vf, 0.0, 1.0)
			vfall = vfall * vfall             # dims faster with distance
			for x in range(w):
				var dx := absf(float(x) - cx)
				var a := 0.0
				if dx <= half:
					# A CRISPER edge (pow 1.6) so the shaft reads as a defined pool, not a
					# fuzzy wash — more contrast between the cone and the dark beside it.
					var hf := dx / half       # 0 centre .. 1 edge
					a = vfall * pow(1.0 - hf * hf, 1.6)
				# A soft round glow right at the bulb so the source itself reads (kept in
				# check so the apex doesn't burn out to white when it adds over a lit scene).
				var rd := sqrt((float(x) - cx) * (float(x) - cx) + d * d)
				if rd < 24.0:
					a = maxf(a, (1.0 - rd / 24.0) * 0.6)
				img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
		_cone = ImageTexture.create_from_image(img)
	return _cone


static func make_window_light(pos: Vector2) -> PointLight2D:
	# A broad, soft daylight pool from a window (stairwell or apartment balcony). Bright and
	# warm by day, a dim cool MOONLIGHT at night. Uses the round cookie (a window washes a
	# whole area, it isn't a tight spotlight).
	var i: int = clampi(WorldState.current_run - 1, 0, WINDOW_CAST.size() - 1)
	var lt := PointLight2D.new()
	lt.texture = light_texture()
	lt.color = WINDOW_CAST[i]
	lt.energy = WINDOW_ENERGY[i]
	lt.texture_scale = WINDOW_SCALE
	lt.position = pos
	lt.z_index = 0
	return lt


func setup(floor_num: int) -> void:
	z_index = 0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(WorldState.master_seed) + "lights" + str(floor_num) + str(WorldState.current_run))
	# How many lamps are dead: a few up top in the morning, MANY deep at night. Run 2 loses
	# a fifth more, run 3 two-fifths more — the later building is failing.
	var dead_frac: float = clampf(0.06 + WorldState.infection_depth(floor_num) * 0.30 \
		+ float(WorldState.current_run - 1) * 0.20, 0.0, 0.72)
	var lamp_energy: float = LAMP_ENERGY_BY_RUN[clampi(WorldState.current_run - 1, 0, 2)]
	for i in range(COUNT):
		var x: float = lerpf(X_START, X_END, float(i) / float(COUNT - 1))
		var lamp := PointLight2D.new()
		lamp.texture = cone_texture()
		lamp.position = Vector2(x, LIGHT_Y)
		lamp.color = WARM
		lamp.texture_scale = LAMP_SCALE
		lamp.energy = lamp_energy
		add_child(lamp)
		# A small visible fixture/bulb so the source reads, not just the pool.
		var bulb := Sprite2D.new()
		bulb.texture = light_texture()
		bulb.position = Vector2(x, LIGHT_Y)
		bulb.scale = Vector2(0.11, 0.11)
		bulb.modulate = WARM
		add_child(bulb)
		if rng.randf() < dead_frac:
			lamp.visible = false
			bulb.scale = Vector2(0.07, 0.07)          # a small, dark, dead fixture (not a smudge)
			bulb.modulate = Color(0.12, 0.11, 0.10)
			continue
		# Behaviour: mostly steady, some gently flicker, some BLINK (a failing tube).
		var roll: float = rng.randf()
		var mode: String = "steady"
		if roll < 0.22:
			mode = "blink"
		elif roll < 0.55:
			mode = "flicker"
		_lamps.append({
			"light": lamp, "bulb": bulb, "base": lamp_energy, "mode": mode,
			"phase": rng.randf() * TAU, "speed": rng.randf_range(6.0, 12.0),
			# HALF the lamps sway — a very gentle, tight rotation about the bulb.
			"sway": rng.randf() < 0.5,
			"sway_amp": rng.randf_range(0.035, 0.075),
			"sway_speed": rng.randf_range(0.5, 1.1),
			"sway_phase": rng.randf() * TAU,
			"blink_t": rng.randf_range(1.5, 4.0), "on": true,
		})
	# Stairwell windows: natural light in from both stair shafts.
	add_child(make_window_light(Vector2(STAIR_WINDOW_LEFT_X, STAIR_WINDOW_Y)))
	add_child(make_window_light(Vector2(STAIR_WINDOW_RIGHT_X, STAIR_WINDOW_Y)))


func _process(delta: float) -> void:
	for e in _lamps:
		var lt: PointLight2D = e["light"]
		if not is_instance_valid(lt):
			continue
		# SWAY: rotate the cone very gently about the bulb, so its pool drifts side to side.
		if e["sway"]:
			e["sway_phase"] += delta * e["sway_speed"]
			lt.rotation = e["sway_amp"] * sin(e["sway_phase"])
		var energy: float = e["base"]
		match e["mode"]:
			"flicker":
				e["phase"] += delta * e["speed"]
				energy = e["base"] * (0.82 + 0.18 * sin(e["phase"]) + randf_range(-0.05, 0.05))
			"blink":
				e["blink_t"] -= delta
				if e["blink_t"] <= 0.0:
					e["on"] = not e["on"]
					# On for a good while, then a short dark stutter.
					e["blink_t"] = randf_range(1.5, 4.5) if e["on"] else randf_range(0.05, 0.28)
				energy = e["base"] * (1.0 if e["on"] else 0.04)
		lt.energy = energy
		if is_instance_valid(e["bulb"]):
			e["bulb"].modulate = WARM * clampf(energy / e["base"], 0.15, 1.2)
