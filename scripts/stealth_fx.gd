class_name StealthFx
extends CanvasLayer

# THE DARK WHILE THE PLAYER HIDES (owner round 49q, sixth pass). History: a dark vignette -> a black hole -> TV static -> grey fog -> a Last-of-Us look made by post-processing the picture
# (a luminance map, the player and the piece they hide in redrawn as copies, the dead as black shapes with a glowing outline). The owner on that one: "reduce the lighting considerably to a
# very dull low light. We want tension here, not this dull lifeless look. Dynamic real lighting is so important because so much of our colour palette looks so lifeless… We need
# lighting, shadows, it makes such a huge difference to the tension and helps with the heavy lifting for these colours. When that works well you don't even need the outline around the
# enemy, because the natural colours of the enemy will be stronger and more striking." So this is LIGHTING, not a filter:
#
#   - the room's AMBIENT light (the world's `WorldGrade` CanvasModulate) is brought down to a very dull, cool, low level (`HIDE_AMBIENT`) — never brighter than it already was, so the night run,
#     which is near-black already, hardly changes — and the REAL lights (a lamp, a window's beam, a sconce, the fire) carve what is left out of it, in colour. The lights themselves are
#     what a morning room is mostly lit by, so the picture is also dimmed in proportion (`post_gain`: the square root of how much the ambient fell — a morning room to about a quarter, an
#     afternoon one to two fifths, a night one not at all), per colour channel with a touch of gamma, so a lit pool stays brighter than the dark round it and every colour stays its own;
#   - the player's own small light (the `PlayerAura` PointLight2D every player carries) is raised to a dim pool (`GLOW_ENERGY`, `GLOW_SCALE`): the player is lit by it like everything else, and a
#     dead thing that walks into it is lit by it too, in ITS OWN colours — nothing is redrawn, nothing is outlined, no copy stands in for anything. Beyond the pool it is simply dark;
#   - a soft vignette closes the edges of the screen in a little: claustrophobic, never grey, never static. (That and the dimming are the whole post-process, and neither moves.)
#   - a SOUND, not a picture, carries the tension (`HIDE_AUDIO`): a slow deep breath as they slip in, then a low heartbeat that goes on while they are still — a little quicker the nearer the
#     dead are — and a breath let go when they come out;
#   - the camera eases IN a little (`ZOOM_IN`) with the player held where they stand on the screen, and back out. 1.0 would switch that off.
#
# Everything it borrows (the ambient colour, the aura's energy and size, the camera) is put back EXACTLY when it ends or the node leaves the tree — a death, a scene change or a freed player can
# never leave the world dark. A child of the Player, on canvas layer 0: above the world, BELOW the HUD (layer 1). All of it is a function of `intensity` (0..1), eased toward `target`, so the
# state any test or pause can see is a number.

const HIDE_AMBIENT := 0.07                     # the luminance the room's ambient light is brought down to (the afternoon's is 0.42, the morning's 0.95, the night's 0.07)
const AMBIENT_TINT := Color(0.66, 0.78, 1.0)   # cool: moonlight under a door, not a cellar light
const GLOW_ENERGY := 0.80                      # the player's own light while they hide: the dim pool a dead thing walks into
const GLOW_SCALE := 1.50                       # ...and how wide it is (the aura's own units; the afternoon's is 1.7, the morning's 1.3)
const VIGNETTE_EDGE := 0.16                    # what is left of the picture at the very edge of the screen...
const VIGNETTE_CENTRE := 1.4                   # ...and how much of it is kept right round the player (the dimming's own lift: the pool the dead walk into)
const POST_GAMMA := 1.25                       # > 1 sinks the dim things a little faster than the lit ones: a pool of light reads as a pool
const POST_GAIN_MIN := 0.22                    # the picture is never dimmed past this (the morning's, the brightest room, lands near 0.27)
const POST_TINT := Color(0.92, 0.96, 1.0)      # a faint cool cast on what is left
const ZOOM_IN := 1.10                          # the camera's slow push-in while hidden (1.0 = none)

const HIDE_AUDIO := "res://assets/audio/stealth/"
const BREATH_IN_S := 1.5
const HEART_DB := -7.0                         # the heart under everything: felt more than heard
const HEART_RATE_NEAR := 1.22                  # its pace when a dead thing is right there (1.0 when none is)
const EASE_IN := 1.0 / Stealth.FADE_TIME

# The post-process: the picture dimmed (per colour channel, so every colour stays its own) and closed in toward the edges, round the player. Nothing in it moves.
const SHADER_CODE := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float intensity = 0.0;
uniform float aspect = 1.7778;
uniform vec2 centre = vec2(0.5, 0.5);
uniform float edge = 0.16;
uniform float boost = 1.4;
uniform float gain = 0.3;
uniform float gamma = 1.25;
uniform vec3 tint = vec3(0.92, 0.96, 1.0);
void fragment() {
	vec3 c = textureLod(screen_tex, SCREEN_UV, 0.0).rgb;
	float d = length((SCREEN_UV - centre) * vec2(aspect, 1.0));
	float v = 1.0 - smoothstep(0.30, 1.05, d);
	vec3 dark = pow(max(c, vec3(0.0)), vec3(gamma)) * gain * tint * mix(edge, boost, v);
	COLOR = vec4(mix(c, dark, intensity), 1.0);
}
"""

var intensity: float = 0.0
var target: float = 1.0                      # 1 = dark, 0 = clearing (then the node frees itself)
var player: Node2D = null

var _rect: ColorRect = null
var _mat: ShaderMaterial = null
var _breath: AudioStreamPlayer = null
var _heart: AudioStreamPlayer = null
var _heart_delay: float = 0.0
var _heart_on: bool = false
var _cam: Camera2D = null
var _cam_zoom0 := Vector2.ONE
var _cam_off0 := Vector2.ZERO
var _cam_set := Vector2.ZERO                 # the zoom we last put on the camera (if it is not that any more, something else has taken the camera over)
var _zoom_now: float = 1.0
var _nearest_gap: float = INF
# the room's ambient light and the player's own light: borrowed, and given back exactly
var _grade: CanvasModulate = null
var _grade_base: Color = Color.WHITE
var _grade_set: Color = Color(-1, -1, -1, -1)
var post_gain: float = 0.3                   # how much of the picture's light is left (set from how far the ambient fell)
var _aura: PointLight2D = null
var _aura_energy0: float = 0.0
var _aura_scale0: float = 1.0


## Darken the room round `p`. One per player: asking again returns the one that is there.
static func begin(p: Node2D) -> StealthFx:
	if p == null or not is_instance_valid(p):
		return null
	for c in p.get_children():
		if c is StealthFx:
			c.target = 1.0
			return c
	var fx := StealthFx.new()
	fx.name = "StealthFx"
	fx.player = p
	p.add_child(fx)
	return fx


func _ready() -> void:
	layer = 0
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = _material(SHADER_CODE)
	_rect.material = _mat
	add_child(_rect)
	_borrow_light()
	_start_sounds()
	_apply(0.0)


static func _material(code: String) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = code
	var m := ShaderMaterial.new()
	m.shader = shader
	return m


## Take hold of the room's ambient light and the player's own light (when they exist: a scene without them is simply not dimmed).
func _borrow_light() -> void:
	var world: Node = InteractArbiter.world_of(player) if player != null else null
	if world != null:
		_grade = world.get_node_or_null("WorldGrade") as CanvasModulate
	if _grade != null:
		_grade_base = _grade.color
		post_gain = gain_for(_grade_base)
	_aura = player.get_node_or_null("PlayerAura") as PointLight2D if player != null else null
	if _aura != null:
		_aura_energy0 = _aura.energy
		_aura_scale0 = _aura.texture_scale


## The ambient colour the room is brought to: the cool dull level, but never brighter than the room's own (a night that is already darker stays as it was).
static func dark_ambient(base: Color) -> Color:
	var lum: float = AMBIENT_TINT.r * 0.299 + AMBIENT_TINT.g * 0.587 + AMBIENT_TINT.b * 0.114
	var k: float = HIDE_AMBIENT / maxf(lum, 0.001)
	return Color(minf(base.r, AMBIENT_TINT.r * k), minf(base.g, AMBIENT_TINT.g * k), minf(base.b, AMBIENT_TINT.b * k), base.a)


## How much of the picture's light is left: the square root of how far the ambient falls (never past POST_GAIN_MIN, never a brightening). A morning room (0.95 -> 0.07) keeps about a quarter,
## an afternoon one (0.42) two fifths, a night one (already below HIDE_AMBIENT) all of it.
static func gain_for(base: Color) -> float:
	var lum: float = base.r * 0.299 + base.g * 0.587 + base.b * 0.114
	return clampf(sqrt(HIDE_AMBIENT / maxf(lum, 0.001)), POST_GAIN_MIN, 1.0)


## The breath in, then (once it has been drawn) the heart. Both are quiet, on the master bus, and live and die with this node.
func _start_sounds() -> void:
	var bi = load(HIDE_AUDIO + "breath_in.wav")
	var hb = load(HIDE_AUDIO + "heartbeat_deep.wav")
	if bi != null:
		_breath = AudioStreamPlayer.new()
		_breath.stream = bi
		_breath.volume_db = -9.0
		add_child(_breath)
		_breath.play()
	if hb != null:
		var loop: AudioStream = hb.duplicate()
		if loop is AudioStreamWAV:
			loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
			loop.loop_begin = 0
			loop.loop_end = int(loop.data.size() / 2)         # (mono, 16-bit: two bytes a frame)
		_heart = AudioStreamPlayer.new()
		_heart.stream = loop
		_heart.volume_db = HEART_DB
		add_child(_heart)
		_heart_delay = BREATH_IN_S * 0.55                      # it comes in under the end of the breath: drawn in, then held, then the heart


## Start clearing; the node frees itself once the room is back.
func end() -> void:
	target = 0.0
	if _heart != null and _heart.playing:
		_heart.stop()
	_heart_on = false
	_heart_delay = -1.0
	_breath_out()


## A breath let go, on a one-shot player that outlives this node (it is freed when it ends).
func _breath_out() -> void:
	var out = load(HIDE_AUDIO + "breath_out.wav")
	if out == null or player == null or not is_instance_valid(player) or player.get_parent() == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = out
	p.volume_db = -9.0
	p.finished.connect(p.queue_free)
	player.get_parent().add_child(p)
	p.play()


func is_clearing() -> bool:
	return target <= 0.0


func _process(delta: float) -> void:
	intensity = move_toward(intensity, target, delta * EASE_IN)
	if player == null or not is_instance_valid(player):
		_give_back()
		queue_free()
		return
	_measure_dead()
	_apply(delta)
	_drive_light()
	_drive_camera()
	_drive_heart(delta)
	if target <= 0.0 and intensity <= 0.0:
		_give_back()
		queue_free()


func _exit_tree() -> void:
	_give_back()


# --- the light: the room's ambient brought down, the player's own pool raised -----------------------------------------------------------------------

func _drive_light() -> void:
	var k: float = smoothstep(0.0, 1.0, intensity)
	if _grade != null and is_instance_valid(_grade):
		if _grade_set.r >= 0.0 and not _grade.color.is_equal_approx(_grade_set):
			_grade_base = _grade.color                          # something re-graded the room while we hid (a floor going live): that is the new light to come back to
		var dark := dark_ambient(_grade_base)
		_grade.color = _grade_base.lerp(dark, k)
		_grade_set = _grade.color
	if _aura != null and is_instance_valid(_aura):
		_aura.energy = lerpf(_aura_energy0, maxf(_aura_energy0, GLOW_ENERGY), k)
		_aura.texture_scale = lerpf(_aura_scale0, maxf(_aura_scale0, GLOW_SCALE), k)


## Everything borrowed goes back exactly as it was.
func _give_back() -> void:
	if _grade != null and is_instance_valid(_grade) and _grade_set.r >= 0.0:
		if _grade.color.is_equal_approx(_grade_set):
			_grade.color = _grade_base
	_grade_set = Color(-1, -1, -1, -1)
	if _aura != null and is_instance_valid(_aura):
		_aura.energy = _aura_energy0
		_aura.texture_scale = _aura_scale0
	_restore_camera()


# --- the camera: a slow push-in with the player held where they stand on the screen ---------------------------------------------------------------

func _drive_camera() -> void:
	var vp := get_viewport()
	var cam: Camera2D = vp.get_camera_2d() if vp != null else null
	if cam == null or not is_instance_valid(cam):
		return
	if _cam != cam:
		_restore_camera()
		_cam = cam
		_cam_zoom0 = cam.zoom
		_cam_off0 = cam.offset
		_cam_set = cam.zoom
	elif not cam.zoom.is_equal_approx(_cam_set):
		return                                              # something else re-fitted the camera since we last touched it (a scene, a pan): leave it alone
	_zoom_now = lerpf(1.0, ZOOM_IN, smoothstep(0.0, 1.0, intensity))
	if is_equal_approx(_zoom_now, 1.0):
		cam.zoom = _cam_zoom0
		cam.offset = _cam_off0
		_cam_set = cam.zoom
		return
	# keep the player where they are on the screen: the centre moves toward them by (1 - 1/zoom) of the way
	var c0: Vector2 = cam.get_screen_center_position() - (cam.offset - _cam_off0)
	var delta_c: Vector2 = (player.global_position - c0) * (1.0 - 1.0 / _zoom_now)
	cam.zoom = _cam_zoom0 * _zoom_now
	cam.offset = _cam_off0 + delta_c
	_cam_set = cam.zoom


## Back to exactly what the camera was before (only if it is still ours: a re-fit since then is not undone).
func _restore_camera() -> void:
	if _cam != null and is_instance_valid(_cam) and _cam.zoom.is_equal_approx(_cam_set):
		_cam.zoom = _cam_zoom0
		_cam.offset = _cam_off0
	_cam = null
	_zoom_now = 1.0


# --- the heart (a sound, not a picture) ----------------------------------------------------------------------------------------------------------

## How near the nearest dead thing on the player's plane is (what the heart answers to).
func _measure_dead() -> void:
	_nearest_gap = INF
	for z in get_tree().get_nodes_in_group("zombie"):
		if AiMind.present(z):
			_nearest_gap = minf(_nearest_gap, AiMind.gap(z, player))


func _drive_heart(delta: float) -> void:
	if _heart == null or target <= 0.0:
		return
	if not _heart_on:
		_heart_delay -= delta
		if _heart_delay <= 0.0:
			_heart.play()
			_heart_on = true
	if _heart_on:
		var near: float = Stealth.focus_for_gap(_nearest_gap)                 # 0 when nothing is near, 1 when it is right there
		_heart.pitch_scale = lerpf(1.0, HEART_RATE_NEAR, near)
		_heart.volume_db = HEART_DB + 4.0 * near


func _apply(_delta: float) -> void:
	if _mat == null:
		return
	var vp := get_viewport()
	var size: Vector2 = vp.get_visible_rect().size if vp != null else Vector2(1152, 648)
	_mat.set_shader_parameter("intensity", intensity)
	_mat.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
	_mat.set_shader_parameter("edge", VIGNETTE_EDGE)
	_mat.set_shader_parameter("boost", VIGNETTE_CENTRE)
	_mat.set_shader_parameter("gain", post_gain)
	_mat.set_shader_parameter("gamma", POST_GAMMA)
	_mat.set_shader_parameter("tint", Vector3(POST_TINT.r, POST_TINT.g, POST_TINT.b))
	if vp != null and player != null and is_instance_valid(player):
		_mat.set_shader_parameter("centre", (vp.get_canvas_transform() * player.global_position) / size)


## What the dark is doing, for tests and tools: intensity, the camera's push-in, whether the heart is on, how near the nearest dead thing is, and the room's ambient light and the player's own now.
func state() -> Dictionary:
	return {"intensity": intensity, "target": target, "zoom": _zoom_now, "post_gain": post_gain, "heart": _heart_on, "nearest_gap": _nearest_gap,
		"ambient": _grade.color if _grade != null and is_instance_valid(_grade) else Color(-1, -1, -1),
		"glow_energy": _aura.energy if _aura != null and is_instance_valid(_aura) else -1.0,
		"glow_scale": _aura.texture_scale if _aura != null and is_instance_valid(_aura) else -1.0}
