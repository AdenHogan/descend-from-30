class_name StealthFx
extends CanvasLayer

# THE WASHED-OUT SCREEN while the player hides (owner round 49o: "the screen should go very washed out and dark, with only the player really being
# visible, then the enemy passing the player which we can see, but once it moves past the enemy is washed out faded just like everything else. We can even
# zoom in on the player during this effect so it looks claustrophobic").
#
# A child of the Player (so it dies with them — a death, a scene change or a freed player can never leave it on), drawn on canvas layer 0 above the world and
# BELOW the HUD (layer 1): its shader samples the screen, desaturates it to a cool dim grey with lifted blacks, and keeps colour inside soft SPOTLIGHTS — one on
# the player, one on each living dead thing near them, whose strength follows its horizontal gap to the player (Stealth.focus_for_gap: it comes into the light
# as it nears and washes out again as it moves off). The camera closes in by Stealth.ZOOM_IN. All of it is a function of `intensity` (0..1), eased toward
# `target` — so the state any test or pause can see is always a number.

const MAX_FOCI := 4                  # the player + up to three of the dead
const PLAYER_RADIUS := 44.0          # world px: the player's own height, so the figure and a little of the floor round it stay in colour
const ENEMY_RADIUS := 52.0
const SOFT := 0.4                    # the spotlight is solid inside SOFT * radius and falls off to the edge
const EASE_IN := 1.0 / Stealth.FADE_TIME
const HEART := preload("res://assets/audio/heartbeat.wav")
const HEART_PERIOD := 1.1
const HEART_DB := -26.0

const SHADER_CODE := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float intensity = 0.0;
uniform float aspect = 1.7778;
uniform vec4 f0 = vec4(0.5, 0.5, 0.0, 0.0);
uniform vec4 f1 = vec4(0.5, 0.5, 0.0, 0.0);
uniform vec4 f2 = vec4(0.5, 0.5, 0.0, 0.0);
uniform vec4 f3 = vec4(0.5, 0.5, 0.0, 0.0);
// xy = the spotlight's centre (screen uv), z = its radius in SCREEN HEIGHTS, w = how strongly it keeps its colour (0..1)
float spot(vec2 uv, vec4 f) {
	if (f.w <= 0.001 || f.z <= 0.0) {
		return 0.0;
	}
	float d = length((uv - f.xy) * vec2(aspect, 1.0));
	return (1.0 - smoothstep(f.z * 0.4, f.z, d)) * f.w;
}
void fragment() {
	vec4 scr = textureLod(screen_tex, SCREEN_UV, 0.0);
	float lum = dot(scr.rgb, vec3(0.299, 0.587, 0.114));
	// washed out, not merely dark: the colour is almost gone, what is left is a cool dim grey with its blacks lifted
	vec3 washed = vec3(lum) * 0.25 + scr.rgb * 0.04 + vec3(0.034, 0.039, 0.048);
	float lit = clamp(spot(SCREEN_UV, f0) + spot(SCREEN_UV, f1) + spot(SCREEN_UV, f2) + spot(SCREEN_UV, f3), 0.0, 1.0);
	vec3 kept = scr.rgb * 1.05;
	COLOR = vec4(mix(scr.rgb, mix(washed, kept, lit), intensity), 1.0);
}
"""

var intensity: float = 0.0
var target: float = 1.0                      # 1 = washing out, 0 = clearing (then the node frees itself)
var player: Node2D = null

var _rect: ColorRect = null
var _mat: ShaderMaterial = null
var _cam: Camera2D = null
var _base_zoom: Vector2 = Vector2.ONE
var _last_zoom: Vector2 = Vector2.ZERO
var _k: float = 1.0
var _enemy_str: Dictionary = {}              # instance id -> the strength it is lit at now (eased, so nothing pops)
var _foci: Array = []                        # what the shader was last given: [{"pos": Vector2 (uv), "r": float, "w": float, "who": "player"/"enemy"}]
var _heart: AudioStreamPlayer = null
var _heart_t: float = 0.0
var _t: float = 0.0


## Wash the screen out around `p`. One per player: asking again returns the one that is there.
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
	var shader := Shader.new()
	shader.code = SHADER_CODE
	_mat = ShaderMaterial.new()
	_mat.shader = shader
	_rect.material = _mat
	add_child(_rect)
	if player != null and is_instance_valid(player):
		_cam = player.get_node_or_null("Camera2D") as Camera2D
		if _cam != null:
			_base_zoom = _cam.zoom
			_last_zoom = _cam.zoom
	_heart = AudioStreamPlayer.new()
	_heart.stream = HEART
	_heart.volume_db = HEART_DB
	add_child(_heart)
	_apply(0.0)


## Start clearing; the node frees itself once the picture and the camera are back.
func end() -> void:
	target = 0.0


func is_clearing() -> bool:
	return target <= 0.0


func _process(delta: float) -> void:
	_t += delta
	intensity = move_toward(intensity, target, delta * EASE_IN)
	if player == null or not is_instance_valid(player):
		_restore_camera()
		queue_free()
		return
	_ease_camera()
	_update_foci(delta)
	_apply(delta)
	if target <= 0.0 and intensity <= 0.0:
		_restore_camera()
		queue_free()


func _ease_camera() -> void:
	if _cam == null or not is_instance_valid(_cam):
		return
	# something else moved the zoom under us (a window resize re-fitting the room): that is the new base
	if _last_zoom != Vector2.ZERO and _cam.zoom.distance_to(_last_zoom) > 0.001:
		_base_zoom = _cam.zoom / maxf(_k, 0.01)
	var e := intensity * intensity * (3.0 - 2.0 * intensity)
	_k = lerpf(1.0, Stealth.ZOOM_IN, e)
	_cam.zoom = _base_zoom * _k
	_last_zoom = _cam.zoom


func _restore_camera() -> void:
	if _cam != null and is_instance_valid(_cam) and _last_zoom != Vector2.ZERO:
		_cam.zoom = _base_zoom
	_k = 1.0
	_last_zoom = Vector2.ZERO


func _update_foci(delta: float) -> void:
	_foci.clear()
	var vp := get_viewport()
	if vp == null:
		return
	var size: Vector2 = vp.get_visible_rect().size
	if size.y <= 1.0:
		return
	var xf: Transform2D = vp.get_canvas_transform()
	var zoom: float = xf.get_scale().x
	_foci.append({"pos": (xf * player.global_position) / size, "r": PLAYER_RADIUS * zoom / size.y, "w": 1.0, "who": "player"})
	# the dead near the hiding player, nearest first
	var want: Array = []
	for z in get_tree().get_nodes_in_group("zombie"):
		if not AiMind.present(z):
			continue
		var g := AiMind.gap(z, player)
		var s := Stealth.focus_for_gap(g)
		if s > 0.0:
			want.append([g, z, s])
	want.sort_custom(func(a, b): return a[0] < b[0])
	var seen: Dictionary = {}
	for i in range(mini(want.size(), MAX_FOCI - 1)):
		var z: Node2D = want[i][1]
		var id := z.get_instance_id()
		seen[id] = true
		var cur: float = float(_enemy_str.get(id, 0.0))
		cur = move_toward(cur, float(want[i][2]), delta * 4.0)
		_enemy_str[id] = cur
		_foci.append({"pos": (xf * z.global_position) / size, "r": ENEMY_RADIUS * zoom / size.y, "w": cur, "who": "enemy"})
	for id in _enemy_str.keys():
		if not seen.has(id):
			_enemy_str[id] = move_toward(float(_enemy_str[id]), 0.0, delta * 4.0)
			if float(_enemy_str[id]) <= 0.0:
				_enemy_str.erase(id)


func _apply(delta: float) -> void:
	if _mat == null:
		return
	var vp := get_viewport()
	var size: Vector2 = vp.get_visible_rect().size if vp != null else Vector2(1152, 648)
	_mat.set_shader_parameter("intensity", intensity)
	_mat.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
	var breath := 1.0 + 0.03 * sin(_t * 1.7)
	for i in range(MAX_FOCI):
		var v := Vector4(0.5, 0.5, 0.0, 0.0)
		if i < _foci.size():
			var f: Dictionary = _foci[i]
			var r: float = float(f["r"]) * (breath if str(f["who"]) == "player" else 1.0)
			v = Vector4(f["pos"].x, f["pos"].y, r, float(f["w"]))
		_mat.set_shader_parameter("f%d" % i, v)
	# a slow heartbeat under it all, only once the screen is mostly gone
	if _heart != null:
		if intensity > 0.6 and target > 0.0:
			_heart_t -= delta
			if _heart_t <= 0.0:
				_heart_t = HEART_PERIOD
				_heart.play()
		else:
			_heart_t = 0.0


## What the screen is doing, for tests and tools: intensity, the zoom factor and the spotlights last handed to the shader.
func state() -> Dictionary:
	return {"intensity": intensity, "target": target, "zoom_k": _k, "foci": _foci.duplicate(true)}


func _exit_tree() -> void:
	_restore_camera()
