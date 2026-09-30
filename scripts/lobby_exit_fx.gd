extends Node2D
class_name LobbyExitFx

# THE LOBBY EXIT, drawn (owner round 29; art = tools/art/lobby_exit.py, docs/art_reference/lobby_exit.png):
# a stone entrance set into the lobby wall — arched opening, vestibule, three marble steps, the doors flung
# open, the street outside in glare. This node builds its layers in the scene:
#   ExitView   the street through the back opening — UNSHADED so the world's night-dark CanvasModulate never
#              dims it (the same rule as the window views);
#   ExitFrame  the lit surround + vestibule + steps + debris (its back opening is a transparent hole);
#   ExitGlare  an additive bloom over the opening that breathes, and SURGES while the player walks up into it;
#   ExitBeam   a shaft of the outside light falling across the lobby floor (window_beam.gd) + a real
#              PointLight2D spilling onto the marble and whoever walks up the steps.
# Both sprites sit right above the corridor art (under doors / actors); live + pan-backdrop builds share it.

const FL = preload("res://scripts/floor_lighting.gd")
const DIR := "res://assets/lobby/"
const META_PATH := "res://assets/lobby/exit_meta.json"
const ORIGIN := Vector2(590, 275)          # frame (0,0) in world px: the door's centre column (64) lands on x 654
const CENTER_X := 654.0
const SPILL_COLOR := {1: Color(1.0, 0.98, 0.92), 2: Color(1.0, 0.80, 0.56), 3: Color(0.62, 0.70, 0.95)}
const SPILL_ENERGY := {1: 0.45, 2: 0.65, 3: 0.55}
const GLARE_BASE := {1: 0.10, 2: 0.13, 3: 0.10}

static var _meta: Dictionary = {}

var run := 1
var view_sprite: Sprite2D = null
var frame_sprite: Sprite2D = null
var glare: Sprite2D = null
var spill: PointLight2D = null
var beam: Node2D = null
var _t := 0.0
var _surge := 0.0            # 0..1 — the walk up into the light drives it
var _glare_base := 0.1


static func meta() -> Dictionary:
	if _meta.is_empty() and FileAccess.file_exists(META_PATH):
		var d = JSON.parse_string(FileAccess.get_file_as_string(META_PATH))
		if d is Dictionary:
			_meta = d
	return _meta


## Build the exit under `root` (right after its CorridorArt). Idempotent; returns the node (or null if the art is missing).
static func add_to(root: Node) -> LobbyExitFx:
	var have = root.get_node_or_null("LobbyExitFx")
	if have != null:
		return have
	var fx := LobbyExitFx.new()
	fx.name = "LobbyExitFx"
	root.add_child(fx)
	var art = root.get_node_or_null("CorridorArt")
	if art != null:
		root.move_child(fx, art.get_index() + 1)
	fx.build(WorldState.current_run)
	return fx


func build(for_run: int) -> void:
	run = clampi(for_run, 1, 3)
	var m := meta()
	var back: Array = m.get("back", [40, 88, 50, 62, 112])
	var fp := DIR + "exit_frame_%d.png" % run
	var vp := DIR + "exit_view_%d.png" % run
	if not ResourceLoader.exists(fp) or not ResourceLoader.exists(vp):
		return
	position = Vector2.ZERO
	z_index = 0
	view_sprite = Sprite2D.new()
	view_sprite.name = "ExitView"
	view_sprite.texture = load(vp)
	view_sprite.centered = false
	view_sprite.position = ORIGIN + Vector2(float(back[0]), float(back[2]))
	view_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var un := CanvasItemMaterial.new()
	un.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	view_sprite.material = un
	add_child(view_sprite)
	frame_sprite = Sprite2D.new()
	frame_sprite.name = "ExitFrame"
	frame_sprite.texture = load(fp)
	frame_sprite.centered = false
	frame_sprite.position = ORIGIN
	frame_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(frame_sprite)
	# the bloom: additive, unshaded, over the back opening
	glare = Sprite2D.new()
	glare.name = "ExitGlare"
	glare.texture = _glare_texture()
	glare.position = ORIGIN + Vector2((float(back[0]) + float(back[1])) * 0.5, float(back[2]) + 22.0)
	glare.scale = Vector2(1.1, 1.3)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	glare.material = add
	glare.z_index = 1                       # over the frame's hole edges, under the actors? (actors are z1, later in tree)
	_glare_base = float(GLARE_BASE[run])
	var tint: Color = SPILL_COLOR[run]
	glare.modulate = Color(tint.r, tint.g, tint.b, _glare_base)
	add_child(glare)
	# the real light: a wide soft pool on the marble in front of the steps
	spill = PointLight2D.new()
	spill.name = "ExitSpill"
	spill.texture = FL.light_texture()
	spill.color = tint
	spill.energy = float(SPILL_ENERGY[run])
	spill.texture_scale = 0.95
	spill.position = Vector2(CENTER_X, 408.0)
	add_child(spill)
	# and the shaft of outside light falling into the lobby
	var B = load("res://scripts/window_beam.gd")
	beam = B.new()
	beam.name = "ExitBeam"
	add_child(beam)
	beam.setup(Vector2(CENTER_X, ORIGIN.y + float(back[2]) + 8.0), 1.35, 1.3)


func _process(delta: float) -> void:
	_t += delta
	if glare != null:
		var breathe := 0.85 + 0.15 * sin(_t * 0.9) + 0.04 * sin(_t * 3.1)
		var a: float = lerpf(_glare_base * breathe, 0.85, _surge)
		var tint: Color = SPILL_COLOR[run]
		glare.modulate = Color(tint.r, tint.g, tint.b, a)
		glare.scale = Vector2(1.1, 1.3) * (1.0 + _surge * 1.3)
	if spill != null:
		spill.energy = lerpf(float(SPILL_ENERGY[run]) * (0.92 + 0.08 * sin(_t * 1.3)), 1.6, _surge)


## The walk up into the light: the glare swells over `duration` seconds until it fills the doorway (the white card
## takes over from there). Returns the tween so the caller can await it.
func surge(duration: float) -> Tween:
	var tw := create_tween()
	tw.tween_property(self, "_surge", 1.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	return tw


func _glare_texture() -> Texture2D:
	var size := 96
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var d := Vector2(float(x) - size * 0.5 + 0.5, float(y) - size * 0.5 + 0.5).length() / (size * 0.5)
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a * (3.0 - 2.0 * a)          # smoothstep falloff
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)
