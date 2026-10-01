class_name MolotovFire
extends Node2D

# The SPLASH FIRE a Molotov Cocktail leaves where it bursts (item 039; owner round 30: "when it hits enemies or areas it breaks and
# creates flame… their fire AOE will work the same as fire now, only it will be a splash spread"). A short-lived patch of flame that
# bursts OUT from the impact (SPREAD_TIME), burns for LIFETIME, then dies back — drawn from the same cleaned craftpix fire as the
# corridor blaze (FireArt: a clean-capped RUN along the floor with tongues behind it), unshaded + a real orange light.
#
# It plays by the SAME rules as the floor fire:
#   • an enemy standing in it CATCHES (WeaponAffliction.ignite — the burning enemy hits twice as hard and burns down, exactly what a
#     fire weapon does, and the same mechanism the extinguisher already puts out);
#   • the PLAYER standing / walking in it takes 1 hp per BURN_INTERVAL (1.1 s, building_floors' FIRE_DMG_INTERVAL); running (sprint)
#     THROUGH it takes none — "sprint the gauntlet or walk and take the hits";
#   • it never blocks anything (no collision at all);
#   • the fire extinguisher puts it out (`douse`, wired through player.douse_span).
# It lives in the scene it was thrown in (never `current_scene` — robustness rule 3) and frees itself; leaving the scene frees it too.

const FIRE_LAYER := preload("res://scripts/fire_layer.gd")
const FLOOR_LIGHTING := preload("res://scripts/floor_lighting.gd")

const RADIUS := 105.0               # half-width of the full splash (px) — about an apartment doorway either side
const SPREAD_TIME := 0.55           # the burst: from the impact point out to RADIUS
const LIFETIME := 12.0
const FADE_TIME := 3.5              # the last stretch: the flames sink and the patch shrinks
const DOUSE_TIME := 0.5
const BURN_INTERVAL := 1.1          # player damage cadence in the fire (== building_floors.FIRE_DMG_INTERVAL)
const PLANE_TOL := 46.0             # an actor's feet within this of the floor line are IN the fire
const TICK := 0.25                  # how often enemies are checked

var _t: float = 0.0
var _dmg_acc: float = 0.0
var _tick_acc: float = 0.0
var _douse_t: float = -1.0          # >= 0 while being put out
var _light: PointLight2D = null
var _seed: float = 0.0
var _back: Node2D = null
var _front: Node2D = null


## Burst a splash fire at `at` (world position ON the floor line) inside `parent`.
static func spawn(parent: Node, at: Vector2) -> MolotovFire:
	if parent == null or not is_instance_valid(parent):
		return null
	var f := MolotovFire.new()
	parent.add_child(f)
	f.global_position = at
	return f


func _ready() -> void:
	add_to_group("molotov_fire")
	_seed = fmod(absf(global_position.x) * 0.173, 1.0)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for spec in [[0, 0], [1, 2]]:
		var lyr = FIRE_LAYER.new()
		lyr.field = self
		lyr.layer = int(spec[0])
		lyr.z_as_relative = false
		lyr.z_index = int(spec[1])
		lyr.material = FireArt.material()
		lyr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(lyr)
		if int(spec[0]) == 0:
			_back = lyr
		else:
			_front = lyr
	_light = PointLight2D.new()
	_light.texture = FLOOR_LIGHTING.light_texture()
	_light.color = Color(1.0, 0.52, 0.16)
	_light.energy = 0.0
	_light.position = Vector2(0, -14)
	add_child(_light)


## How far the fire reaches either side right now (0 before the burst, RADIUS at full, shrinking as it dies / is doused).
func extent() -> float:
	var spread: float = clampf(_t / SPREAD_TIME, 0.0, 1.0)
	spread = 1.0 - pow(1.0 - spread, 3.0)                 # fast out, easing in
	var life: float = 1.0
	if _t > LIFETIME - FADE_TIME:
		life = clampf((LIFETIME - _t) / FADE_TIME, 0.0, 1.0)
		life = 0.35 + 0.65 * life
	if _douse_t >= 0.0:
		life *= clampf(1.0 - _douse_t / DOUSE_TIME, 0.0, 1.0)
	return RADIUS * spread * life


func is_burning() -> bool:
	return _douse_t < 0.0 and _t < LIFETIME and extent() > 4.0


## The fire extinguisher: the patch is beaten out (it shrinks away in DOUSE_TIME).
func douse() -> void:
	if _douse_t < 0.0:
		_douse_t = 0.0


func in_fire(x: float, feet_y: float) -> bool:
	return is_burning() and absf(x - global_position.x) <= extent() and absf(feet_y - global_position.y) <= PLANE_TOL


func _physics_process(delta: float) -> void:
	_t += delta
	if _douse_t >= 0.0:
		_douse_t += delta
		if _douse_t >= DOUSE_TIME:
			queue_free()
			return
	if _t >= LIFETIME:
		queue_free()
		return
	if _light != null:
		var k: float = clampf(extent() / RADIUS, 0.0, 1.0)
		_light.energy = (0.55 + 0.12 * sin(_t * 13.0 + _seed * 6.0)) * k
		_light.texture_scale = 0.9 + 1.0 * k
	if not is_burning():
		return
	# the player: standing / walking in it burns, running through it doesn't (same rule as the corridor fire)
	var p = get_tree().get_first_node_in_group("player")
	if p != null and is_instance_valid(p) and WorldState.owning_scene_root(p) == WorldState.owning_scene_root(self) \
			and in_fire(p.global_position.x, p.global_position.y + 33.0) \
			and not (("is_running" in p) and p.is_running):
		_dmg_acc += delta
		if _dmg_acc >= BURN_INTERVAL:
			_dmg_acc = 0.0
			if p.has_method("receive_hit"):
				p.receive_hit(1)
				HUD.show_feedback("It's burning me!")
	else:
		_dmg_acc = 0.0
	# enemies: anything standing in it catches (and keeps catching while it stays)
	_tick_acc += delta
	if _tick_acc >= TICK:
		_tick_acc = 0.0
		ignite_enemies()


## Set alight every live enemy in the fire. Returns how many.
func ignite_enemies() -> int:
	var n := 0
	var root: Node = WorldState.owning_scene_root(self)
	for z in get_tree().get_nodes_in_group("zombie"):
		if not is_instance_valid(z) or WorldState.owning_scene_root(z) != root:
			continue
		var feet: float = float(z._drop_feet_y()) if z.has_method("_drop_feet_y") else z.global_position.y + 45.0
		if in_fire(z.global_position.x, feet) and WeaponAffliction.ignite(z):
			n += 1
	return n


# ---------------------------------------------------------------- drawing (FireArt, the cleaned craftpix fire)

func draw_layer(canvas: CanvasItem, which: int) -> void:
	var ext: float = extent()
	if ext < 4.0:
		return
	var dying: bool = _t > LIFETIME - FADE_TIME or _douse_t >= 0.0
	var kit: String = "light" if dying else "blaze"
	var v: int = 1 + int(_seed * 3.0) % 3
	if which == 1:
		# the carpet along the floor, in front of the player's feet
		if ext >= 48.0:
			FireArt.assemble_run(canvas, kit, v, _t, _seed, 0.0, ext * 2.0, -1.0)
		else:
			FireArt.draw(canvas, "tongue_s_%d" % v, _t, _seed, Vector2(0, -1.0))
		return
	# the flames rising behind it: one medium tongue and a few small ones across the width (a splash, not a bonfire), fewer as it dies down
	var spots: Array = [[0.05, "m"], [-0.62, "s"], [0.6, "s"], [-0.32, "s"], [0.34, "s"]]
	var show: int = spots.size() if not dying else (1 if _douse_t >= 0.0 else 3)
	if ext < 70.0:
		show = mini(show, 2)
	for i in range(show):
		var sp: Array = spots[i]
		var names: Array = FireArt.variants("tongue_" + str(sp[1]))
		if names.is_empty():
			continue
		var x: float = float(sp[0]) * ext
		if absf(x) > ext - 8.0:
			continue
		FireArt.draw(canvas, str(names[(i + v) % names.size()]), _t, fmod(_seed + 0.21 * float(i), 1.0), Vector2(x, -3.0))
