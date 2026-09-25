extends Node2D

# APARTMENT LAMPS (owner round 14 — "lamps… some will be on with real lighting in evening and night
# scenes. Flickering, cutting out, turning back on, especially in the night scenes. Not always… lighting
# can't match room to room… having light sources in apartments including ceiling lights is important").
#
# One per room module. The module art draws its fixtures unlit (tools/art/furn.py lamp helpers) and the
# module scene carries a `Lights` container of Node2D markers at each bulb (metadata/kind). This node
# decides — seeded per apartment + slot + fixture + RUN, so the same flat is stable on re-entry but no two
# flats match — whether the flat has power and whether each fixture is on, and how it behaves:
#   steady   on and still
#   flicker  on, the light wavering (a loose connection / a dying bulb)
#   cutout   on for a while, then DARK for a moment, then stutters back on (the building's wiring failing)
#   blink    a failing fluorescent tube: long on, short dark stutters (tubes only)
# MORNING (run 1) is daylight — nothing is on. The AFTERNOON (run 2) has a few flats lit, mostly steady;
# the NIGHT (run 3) more, and far more of them flickering and cutting out. A flat that burned (BLAZE /
# CHARRED) has no power at all; a battery LANTERN ignores the flat's power. Each lit fixture is a REAL
# PointLight2D (a round pool for lamps on furniture, a downward cone for ceiling lights — the corridor
# lamps' cookie) plus a small ADDITIVE glow on the shade, so the source reads, not just the pool.
# Built on live rooms AND the passive balcony-pan backdrop (the flat below is lit the same way).

const FloorLighting = preload("res://scripts/floor_lighting.gd")

const CONE_KINDS := ["pendant", "bulb", "flush", "tube", "chandelier"]
const KIND := {
	# kind: texture scale (reach), colour, glow size
	"table": [0.42, Color(1.00, 0.78, 0.45), 0.055],
	"desk": [0.36, Color(1.00, 0.84, 0.55), 0.045],
	"floor": [0.55, Color(1.00, 0.78, 0.45), 0.065],
	"lava": [0.30, Color(0.95, 0.45, 0.85), 0.045],
	"lantern": [0.50, Color(0.88, 0.94, 1.00), 0.050],
	"pendant": [0.62, Color(1.00, 0.80, 0.50), 0.060],
	"bulb": [0.60, Color(1.00, 0.86, 0.58), 0.050],
	"flush": [0.66, Color(1.00, 0.88, 0.66), 0.060],
	"tube": [0.72, Color(0.86, 0.94, 1.00), 0.060],
	"chandelier": [0.66, Color(1.00, 0.82, 0.55), 0.070],
}
# Brightness per run (morning / afternoon / night). 2D lights ADD, so these sit in the corridor lamps'
# budget: modest in the afternoon's 0.42 ambient, stronger in the night's near-black.
const ENERGY_ROUND := [0.0, 0.70, 1.20]
const ENERGY_CONE := [0.0, 0.85, 1.50]
# How likely a flat has power, and a fixture in a powered flat is on, per run.
const POWER_CHANCE := [0.0, 0.72, 0.62]
const ON_CHANCE := [0.0, 0.55, 0.70]
const LANTERN_ON := [0.0, 0.45, 0.80]
# Behaviour mix per run: [steady, flicker, cutout] (tubes turn flicker into blink).
const MODE_MIX := [[1.0, 0.0, 0.0], [0.62, 0.22, 0.16], [0.30, 0.32, 0.38]]

var _lamps: Array = []


static func flat_powered(apt: String, run: int, fire_stage: int) -> bool:
	if fire_stage == WorldState.FIRE_BLAZE or fire_stage == WorldState.FIRE_CHARRED:
		return false
	var r := clampi(run - 1, 0, 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(WorldState.master_seed) + "aptpower" + apt + str(run))
	return rng.randf() < POWER_CHANCE[r]


static func fixture_state(apt: String, slot: int, idx: int, kind: String, run: int, powered: bool) -> Dictionary:
	# {on, mode} for one fixture — a pure function of the seed, so a room and its re-entry agree.
	var r := clampi(run - 1, 0, 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(WorldState.master_seed) + "aptlamp" + apt + ":" + str(slot) + ":" + str(idx) + ":" + str(run))
	var on_roll := rng.randf()
	var on: bool
	if kind == "lantern":
		on = on_roll < LANTERN_ON[r]
	else:
		on = powered and on_roll < ON_CHANCE[r]
	var mix: Array = MODE_MIX[r]
	var m := rng.randf()
	var mode := "steady"
	if m >= mix[0] + mix[1]:
		mode = "cutout"
	elif m >= mix[0]:
		mode = "flicker"
	if kind == "tube" and mode == "flicker":
		mode = "blink"
	if kind == "lantern" and mode == "cutout":
		mode = "flicker"                    # a battery doesn't cut out, it gutters
	return {"on": on, "mode": mode}


func setup(module: Node2D, apt: String, slot: int, run: int, fire_stage: int, has_balcony: bool) -> void:
	position = module.position
	var holder := module.get_node_or_null("Lights")
	if holder == null:
		return
	var powered := flat_powered(apt, run, fire_stage)
	var r := clampi(run - 1, 0, 2)
	var i := 0
	for m in holder.get_children():
		if not (m is Node2D):
			continue
		var idx := i
		i += 1
		if has_balcony and bool(m.get_meta("balcony_strip", false)):
			continue                        # its furniture is gone on a balcony slot
		var kind := str(m.get_meta("kind", "table"))
		var st := fixture_state(apt, slot, idx, kind, run, powered)
		if not st["on"]:
			continue
		var spec: Array = KIND.get(kind, KIND["table"])
		var cone: bool = kind in CONE_KINDS
		var base: float = (ENERGY_CONE if cone else ENERGY_ROUND)[r]
		var lt := PointLight2D.new()
		lt.texture = FloorLighting.cone_texture() if cone else FloorLighting.light_texture()
		lt.texture_scale = spec[0]
		lt.color = spec[1]
		lt.energy = base
		lt.position = m.position
		add_child(lt)
		var glow := Sprite2D.new()
		glow.texture = FloorLighting.light_texture()
		glow.position = m.position
		glow.scale = Vector2(spec[2], spec[2])
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glow.material = mat
		glow.modulate = Color(spec[1].r, spec[1].g, spec[1].b, 0.8)
		add_child(glow)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(str(WorldState.master_seed) + "aptlampfx" + apt + str(slot) + str(idx) + str(run))
		_lamps.append({"light": lt, "glow": glow, "base": base, "mode": st["mode"], "kind": kind,
			"phase": rng.randf() * TAU, "speed": rng.randf_range(5.0, 11.0),
			"on": true, "t": rng.randf_range(1.5, 7.0), "stutter": 0})
	set_process(not _lamps.is_empty())


func lamp_count() -> int:
	return _lamps.size()


func lamps() -> Array:
	return _lamps


func _process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	# (public so a test can drive time without waiting on frames)
	for e in _lamps:
		var lt: PointLight2D = e["light"]
		if not is_instance_valid(lt):
			continue
		var f := 1.0
		match e["mode"]:
			"flicker":
				e["phase"] += delta * e["speed"]
				f = 0.80 + 0.14 * sin(e["phase"]) + randf_range(-0.06, 0.06)
			"blink":
				e["t"] -= delta
				if e["t"] <= 0.0:
					e["on"] = not e["on"]
					e["t"] = randf_range(1.5, 5.0) if e["on"] else randf_range(0.05, 0.3)
				f = 1.0 if e["on"] else 0.03
			"cutout":
				# On for a while → DARK for a moment → stutters back on (2-4 quick blinks) → on.
				e["t"] -= delta
				if e["t"] <= 0.0:
					if e["stutter"] > 0:
						e["stutter"] -= 1
						e["on"] = not e["on"]
						e["t"] = randf_range(0.04, 0.12)
						if e["stutter"] == 0:
							e["on"] = true
							e["t"] = randf_range(2.5, 9.0)
					elif e["on"]:
						e["on"] = false
						e["t"] = randf_range(0.4, 3.5)
					else:
						e["stutter"] = 2 * randi_range(1, 2) + 1
						e["on"] = true
						e["t"] = randf_range(0.04, 0.12)
				f = 1.0 if e["on"] else 0.0
		lt.energy = e["base"] * f
		lt.enabled = f > 0.001
		var g = e["glow"]
		if is_instance_valid(g):
			g.visible = f > 0.001
			g.modulate.a = clampf(0.8 * f, 0.0, 1.0)
