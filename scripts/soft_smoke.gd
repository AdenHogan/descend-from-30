extends CPUParticles2D

# SOFT SMOKE — the fire's smoke and its aftermath, as real particles: soft, translucent puffs that
# rise, swell, drift and fade. Replaces the purchased smoke-sprite stamps, which are small hard-edged
# dark-outlined blobs and read as "black circles" (owner: the doused aftermath was very ugly and
# there was "no smoke really"). One emitter covers a stretch of floor (`width`, centred on the node,
# rising from its y). Kinds:
#   "fire"      — over a BURNING stretch: darker, denser, steady.
#   "billow"    — the moment a stretch is DOUSED: one big pale burst of steam and smoke, then gone.
#   "smoulder"  — a doused or charred stretch: sparse, pale wisps that linger.
#   "body"      — a corpse that died alight: a thin wisp off the body.
# CPU particles, local coords (they ride along with a floor that pans), no collision.

static var _tex: Texture2D = null


static func soft_texture() -> Texture2D:
	# A soft round puff: alpha falls off smoothly from the centre — no outline, no hard edge.
	if _tex != null:
		return _tex
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := (float(n) - 1.0) * 0.5
	for y in range(n):
		for x in range(n):
			var d := Vector2(float(x) - c, float(y) - c).length() / c
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a * (3.0 - 2.0 * a)          # smoothstep
			img.set_pixel(x, y, Color(1, 1, 1, a * 0.9))
	_tex = ImageTexture.create_from_image(img)
	return _tex


var kind: String = "smoulder"
var width: float = 42.0


func configure(p_kind: String, p_width: float) -> CPUParticles2D:
	kind = p_kind
	width = maxf(p_width, 8.0)
	texture = soft_texture()
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	local_coords = true
	emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	direction = Vector2(0, -1)
	gravity = Vector2(0, -6)                 # a gentle updraft
	damping_min = 2.0
	damping_max = 5.0
	angle_min = 0.0
	angle_max = 360.0
	var tint := Color(0.66, 0.64, 0.62)
	var peak := 0.22
	match kind:
		"fire":
			tint = Color(0.24, 0.22, 0.21)
			peak = 0.52
			lifetime = 4.6
			amount = int(clampf(width / 4.0, 8.0, 48.0))
			initial_velocity_min = 20.0
			initial_velocity_max = 34.0
			spread = 16.0
			_scale(1.2, 4.2)
			emission_rect_extents = Vector2(width * 0.5, 4.0)
			preprocess = 3.0
		"billow":
			tint = Color(0.86, 0.85, 0.84)
			peak = 0.78
			lifetime = 3.8
			amount = int(clampf(width / 2.0, 14.0, 80.0))
			one_shot = true
			explosiveness = 0.55
			initial_velocity_min = 18.0
			initial_velocity_max = 42.0
			spread = 40.0
			_scale(1.6, 5.2)
			emission_rect_extents = Vector2(width * 0.5, 5.0)
		"body":
			tint = Color(0.56, 0.54, 0.52)
			peak = 0.4
			lifetime = 3.0
			amount = 5
			initial_velocity_min = 6.0
			initial_velocity_max = 12.0
			spread = 10.0
			_scale(0.5, 1.6)
			emission_rect_extents = Vector2(width * 0.5, 2.0)
			preprocess = 2.0
		_:   # smoulder
			tint = Color(0.58, 0.56, 0.55)
			peak = 0.4
			lifetime = 5.0
			amount = int(clampf(width / 8.0, 4.0, 24.0))
			initial_velocity_min = 9.0
			initial_velocity_max = 18.0
			spread = 12.0
			_scale(1.0, 3.4)
			emission_rect_extents = Vector2(width * 0.5, 3.0)
			preprocess = 3.0
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.18, 0.6, 1.0])
	g.colors = PackedColorArray([Color(tint, 0.0), Color(tint, peak), Color(tint, peak * 0.55), Color(tint, 0.0)])
	color_ramp = g
	emitting = true
	return self


func _scale(from: float, to: float) -> void:
	scale_amount_min = 0.8
	scale_amount_max = 1.2
	var c := Curve.new()
	c.min_value = 0.0
	c.max_value = maxf(to, 1.0)
	c.add_point(Vector2(0.0, from))
	c.add_point(Vector2(1.0, to))
	scale_amount_curve = c


func _ready() -> void:
	if kind == "billow":
		# One burst, then clear itself away.
		finished.connect(queue_free)


# --- shared bookkeeping for a fire's smoke (fire_field + apartment_fire) ----------------------
# `wanted` maps a stable key → {"kind": "fire"|"smoulder", "x", "y", "w"}. `reg` is the owner's
# live {key: emitter} map. New keys get an emitter; a stretch that went fire → smoulder (DOUSED)
# gets a one-shot "billow" burst plus the lingering smoulder; keys that vanished are retired
# (stop emitting, freed once their puffs have faded — never popped off). `initial` = first sync
# after the scene built: smoke is already there (preprocessed), no billow.
static func sync(parent: Node, reg: Dictionary, wanted: Dictionary, initial: bool) -> void:
	var script: GDScript = load("res://scripts/soft_smoke.gd")
	for key in reg.keys():
		var cur = reg[key]
		var w = wanted.get(key, null)
		if w == null or not is_instance_valid(cur) or cur.kind != String(w["kind"]):
			var was_fire: bool = is_instance_valid(cur) and cur.kind == "fire"
			_retire(cur)
			reg.erase(key)
			if w != null and was_fire and String(w["kind"]) == "smoulder":
				var b = script.new()
				b.configure("billow", float(w["w"]))
				b.position = Vector2(float(w["x"]), float(w["y"]))
				parent.add_child(b)
	for key in wanted.keys():
		if reg.has(key):
			continue
		var w: Dictionary = wanted[key]
		var e = script.new()
		e.configure(String(w["kind"]), float(w["w"]))
		if not initial:
			e.preprocess = 0.0           # fresh smoke builds up from the spot, it doesn't pop in
		e.position = Vector2(float(w["x"]), float(w["y"]))
		parent.add_child(e)
		reg[key] = e


static func _retire(e) -> void:
	if not is_instance_valid(e):
		return
	e.emitting = false
	var t: SceneTreeTimer = e.get_tree().create_timer(e.lifetime + 0.2) if e.is_inside_tree() else null
	if t != null:
		t.timeout.connect(func(): if is_instance_valid(e): e.queue_free())
	else:
		e.queue_free()


# Burnt floor where fire has been: thin, ragged SOOT STREAKS lying along the floor — no blobs or
# circles (the old scorch read as a row of black balls). `seed` keeps each patch stable.
static func draw_soot(canvas: CanvasItem, cx: float, floor_y: float, soot_w: float, soot_seed: float) -> void:
	var h := func(v: float) -> float: return fmod(absf(sin(v * 12.9898) * 43758.5453), 1.0)
	for k in range(6):
		var r1: float = h.call(soot_seed + float(k) * 1.37)
		var r2: float = h.call(soot_seed * 1.7 + float(k) * 2.11)
		var r3: float = h.call(soot_seed * 2.3 + float(k) * 0.71)
		var ln: float = soot_w * (0.25 + 0.5 * r1)
		var x0: float = cx - soot_w * 0.5 + (soot_w - ln) * r2
		var y: float = floor_y - 1.0 - 7.0 * r3
		canvas.draw_rect(Rect2(x0, y, ln, 1.0 + float(k % 2)), Color(0.10, 0.08, 0.07, 0.16 + 0.12 * r1))
	# a few pale ash flecks (single pixels)
	for k in range(4):
		var a: float = h.call(soot_seed * 3.1 + float(k) * 1.9)
		var b: float = h.call(soot_seed * 0.7 + float(k) * 3.3)
		canvas.draw_rect(Rect2(cx - soot_w * 0.5 + soot_w * a, floor_y - 2.0 - 6.0 * b, 1.0, 1.0), Color(0.55, 0.53, 0.5, 0.35))
