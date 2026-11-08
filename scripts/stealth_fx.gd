class_name StealthFx
extends CanvasLayer

# THE GREY WHILE THE PLAYER HIDES (owner round 49o, fourth pass). History: a dark vignette → a black circular hole → TV static, each rejected. The owner's words for what they want:
# "I just wanted it to be really grey so that you can't see anything except for basically just the player as they hide, then the shadow or silhouette of the enemy as it passes
# by. We want the tension" — and "there's a really weird zoom", "the static is bad". So:
#
#   - the whole picture goes to ONE flat, pale grey (a touch darker toward the screen's edges) with only the barest ghost of the room's lights and darks left in it;
#   - the PLAYER stays exactly as drawn, in colour: the layer redraws the player's own sprite frame on top of the grey (the world under the grey cannot be told apart from the
#     player by a shader, so the layer carries a COPY of the sprite, on the same screen place, frame and flip). The piece they hide in (the bath's lip, the shower curtain) is
#     copied the same way, grey, so it still stands between them and the room;
#   - a dead thing near them is a dark SILHOUETTE: a black copy of its own sprite frame that fades in as it nears and out as it goes (Stealth.focus_for_gap);
#   - NOTHING moves the camera. The close-up zoom is gone.
#
# A child of the Player (so it dies with them — a death, a scene change or a freed player can never leave it on), on canvas layer 0: above the world, BELOW the HUD (layer 1).
# All of it is a function of `intensity` (0..1), eased toward `target`, so the state any test or pause can see is a number.

const FOG_NEAR := Color(0.60, 0.61, 0.63)      # the grey round the player
const FOG_FAR := Color(0.40, 0.41, 0.43)       # …a little darker at the screen's edges
const GHOST := 0.045
const SILHOUETTE := Color(0.03, 0.03, 0.04)    # a dead thing, as a shadow
# On the grey screen a shower curtain is thinner than it is in the room: the figure behind it has to read (it is the one thing meant to be seen).
const CURTAIN_MAX_ALPHA := 0.58
const COVER_GREY := 0.85                       # how far the hiding piece's colour is taken out of its copy
const MAX_DEAD := 4                            # silhouettes at once (the nearest)
const FADE_SPEED := 4.0                        # a silhouette's alpha per second toward its target
const EASE_IN := 1.0 / Stealth.FADE_TIME
const HEART := preload("res://assets/audio/heartbeat.wav")
const HEART_PERIOD := 1.1
const HEART_DB := -26.0

const SHADER_CODE := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float intensity = 0.0;
uniform float aspect = 1.7778;
uniform vec2 centre = vec2(0.5, 0.5);
uniform vec3 fog_near = vec3(0.60, 0.61, 0.63);
uniform vec3 fog_far = vec3(0.40, 0.41, 0.43);
uniform float ghost = 0.07;
void fragment() {
	vec4 scr = textureLod(screen_tex, SCREEN_UV, 0.0);
	float lum = dot(scr.rgb, vec3(0.299, 0.587, 0.114));
	float d = length((SCREEN_UV - centre) * vec2(aspect, 1.0));
	vec3 fog = mix(fog_near, fog_far, smoothstep(0.30, 1.05, d));
	// one flat grey; the room is only a ghost in it (its lights and darks, never its colours)
	vec3 world = fog + vec3(lum - 0.35) * ghost;
	COLOR = vec4(mix(scr.rgb, world, intensity), 1.0);
}
"""

# The hiding piece's copy: its colour mostly taken out, so it sits in the grey like everything else but still stands in front of the player.
const COVER_SHADER_CODE := """
shader_type canvas_item;
uniform float amount = 0.85;
void fragment() {
	float l = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
	COLOR.rgb = mix(COLOR.rgb, vec3(l * 0.9 + 0.05), amount);
}
"""

var intensity: float = 0.0
var target: float = 1.0                      # 1 = greying, 0 = clearing (then the node frees itself)
var player: Node2D = null

var _rect: ColorRect = null
var _mat: ShaderMaterial = null
var _stage: Node2D = null                    # the copies: player below, then the piece they hide in, then the dead
var _player_copy: AnimatedSprite2D = null
var _cover_copy: Sprite2D = null
var _cover_mat: ShaderMaterial = null
var _rim_copy: Sprite2D = null               # behind a curtain: the tub's own front, which stays solid under the thin curtain
var _dead: Dictionary = {}                   # instance id -> {"node": AnimatedSprite2D, "w": float (its alpha now)}
var _heart: AudioStreamPlayer = null
var _heart_t: float = 0.0
var _last_state: Dictionary = {"dead": []}


## Grey the screen out round `p`. One per player: asking again returns the one that is there.
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
	_stage = Node2D.new()
	_stage.name = "Stage"
	add_child(_stage)
	var cover_shader := Shader.new()
	cover_shader.code = COVER_SHADER_CODE
	_cover_mat = ShaderMaterial.new()
	_cover_mat.shader = cover_shader
	_cover_mat.set_shader_parameter("amount", COVER_GREY)
	_player_copy = AnimatedSprite2D.new()
	_player_copy.name = "PlayerCopy"
	_player_copy.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_player_copy.visible = false
	_stage.add_child(_player_copy)
	_heart = AudioStreamPlayer.new()
	_heart.stream = HEART
	_heart.volume_db = HEART_DB
	add_child(_heart)
	_apply(0.0)


## Start clearing; the node frees itself once the picture is back.
func end() -> void:
	target = 0.0


func is_clearing() -> bool:
	return target <= 0.0


func _process(delta: float) -> void:
	intensity = move_toward(intensity, target, delta * EASE_IN)
	if player == null or not is_instance_valid(player):
		queue_free()
		return
	_sync_copies(delta)
	_apply(delta)
	if target <= 0.0 and intensity <= 0.0:
		queue_free()


# --- the copies ----------------------------------------------------------------------------------------------------------------------------

## Put `copy` where `src` is on the screen, showing the same frame, flipped the same way.
static func mirror_anim(copy: AnimatedSprite2D, src: AnimatedSprite2D, xf: Transform2D) -> void:
	if copy.sprite_frames != src.sprite_frames:
		copy.sprite_frames = src.sprite_frames
	if copy.animation != src.animation:
		copy.animation = src.animation
	copy.frame = src.frame
	copy.flip_h = src.flip_h
	copy.flip_v = src.flip_v
	copy.centered = src.centered
	copy.offset = src.offset
	copy.transform = xf * src.get_global_transform()


func _sprite_of(n: Node) -> AnimatedSprite2D:
	if n == null or not is_instance_valid(n):
		return null
	var s = n.get("animated_sprite")
	if s is AnimatedSprite2D and is_instance_valid(s) and s.sprite_frames != null:
		return s
	return null


func _sync_copies(delta: float) -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var xf: Transform2D = vp.get_canvas_transform()
	# the player, exactly as drawn
	var ps := _sprite_of(player)
	if ps != null:
		mirror_anim(_player_copy, ps, xf)
		_player_copy.modulate = ps.modulate
		_player_copy.visible = ps.is_visible_in_tree()
	else:
		_player_copy.visible = false
	# the piece they hide in (the bath's lip, the shower curtain): over the player, in grey
	var cover: Sprite2D = null
	var spot = player.get("hide_spot")
	if spot != null and is_instance_valid(spot) and spot.has_method("cover_node"):
		cover = spot.cover_node()
	if cover != null and cover.texture != null:
		if _cover_copy == null:
			_cover_copy = Sprite2D.new()
			_cover_copy.name = "CoverCopy"
			_cover_copy.centered = false
			_cover_copy.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			_cover_copy.material = _cover_mat
			_stage.add_child(_cover_copy)
			_stage.move_child(_cover_copy, 1)
		_cover_copy.texture = cover.texture
		_cover_copy.region_enabled = cover.region_enabled
		_cover_copy.region_rect = cover.region_rect
		_cover_copy.modulate = cover.modulate
		if spot.get("behind_curtain"):
			_cover_copy.modulate.a = minf(cover.modulate.a, CURTAIN_MAX_ALPHA)
		_cover_copy.transform = xf * cover.get_global_transform()
		_cover_copy.visible = true
		# behind a thin curtain the tub's front lip is still solid (the figure sits IN the tub, not through its side)
		if spot.get("behind_curtain") and int(spot.get("rim_from_row")) > 0:
			if _rim_copy == null:
				_rim_copy = Sprite2D.new()
				_rim_copy.name = "RimCopy"
				_rim_copy.centered = false
				_rim_copy.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				_rim_copy.material = _cover_mat
				_stage.add_child(_rim_copy)
				_stage.move_child(_rim_copy, 2)
			var rim_row: int = int(spot.get("rim_from_row"))
			_rim_copy.texture = cover.texture
			_rim_copy.region_enabled = true
			_rim_copy.region_rect = Rect2(0, rim_row, cover.texture.get_width(), cover.texture.get_height() - rim_row)
			_rim_copy.transform = xf * (cover.get_global_transform() * Transform2D(0.0, Vector2(0, rim_row - cover.region_rect.position.y)))
			var solid: float = clampf(cover.modulate.a / maxf(float(spot.get("cover_alpha")), 0.01), 0.0, 1.0)
			_rim_copy.modulate = Color(cover.modulate.r, cover.modulate.g, cover.modulate.b, solid)
			_rim_copy.visible = true
		elif _rim_copy != null:
			_rim_copy.visible = false
	else:
		if _cover_copy != null:
			_cover_copy.visible = false
		if _rim_copy != null:
			_rim_copy.visible = false
	# the dead near them: shadows, nearest first
	var want: Array = []
	for z in get_tree().get_nodes_in_group("zombie"):
		if not AiMind.present(z):
			continue
		var g := AiMind.gap(z, player)
		var w := Stealth.focus_for_gap(g)
		if w > 0.0 and _sprite_of(z) != null:
			want.append([g, z, w])
	want.sort_custom(func(a, b): return a[0] < b[0])
	var seen: Dictionary = {}
	var shown: Array = []
	for i in range(mini(want.size(), MAX_DEAD)):
		var z: Node2D = want[i][1]
		var id := z.get_instance_id()
		seen[id] = true
		var e: Dictionary = _dead.get(id, {})
		if e.is_empty():
			var n := AnimatedSprite2D.new()
			n.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			_stage.add_child(n)
			e = {"node": n, "w": 0.0}
			_dead[id] = e
		e["w"] = move_toward(float(e["w"]), float(want[i][2]), delta * FADE_SPEED)
		var node: AnimatedSprite2D = e["node"]
		mirror_anim(node, _sprite_of(z), xf)
		node.modulate = Color(SILHOUETTE.r, SILHOUETTE.g, SILHOUETTE.b, float(e["w"]))
		node.visible = true
		shown.append({"gap": float(want[i][0]), "w": float(e["w"])})
	for id in _dead.keys():
		if seen.has(id):
			continue
		var e: Dictionary = _dead[id]
		var node = e["node"]
		e["w"] = move_toward(float(e["w"]), 0.0, delta * FADE_SPEED)
		if is_instance_valid(node):
			node.modulate.a = float(e["w"])
		if float(e["w"]) <= 0.0:
			if is_instance_valid(node):
				node.queue_free()
			_dead.erase(id)
	_last_state = {"dead": shown}


func _apply(delta: float) -> void:
	if _mat == null:
		return
	var vp := get_viewport()
	var size: Vector2 = vp.get_visible_rect().size if vp != null else Vector2(1152, 648)
	_mat.set_shader_parameter("intensity", intensity)
	_mat.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
	_mat.set_shader_parameter("fog_near", Vector3(FOG_NEAR.r, FOG_NEAR.g, FOG_NEAR.b))
	_mat.set_shader_parameter("fog_far", Vector3(FOG_FAR.r, FOG_FAR.g, FOG_FAR.b))
	_mat.set_shader_parameter("ghost", GHOST)
	if vp != null and player != null and is_instance_valid(player):
		_mat.set_shader_parameter("centre", (vp.get_canvas_transform() * player.global_position) / size)
	# the copies come in with the grey (the player's own pixels are always there: they are copied, not revealed)
	_stage.modulate.a = clampf(intensity * 1.6, 0.0, 1.0)
	# a slow heartbeat under it all, only once the screen is mostly gone
	if _heart != null:
		if intensity > 0.6 and target > 0.0:
			_heart_t -= delta
			if _heart_t <= 0.0:
				_heart_t = HEART_PERIOD
				_heart.play()
		else:
			_heart_t = 0.0


## What the screen is doing, for tests and tools: intensity, whether the player's copy is on, the piece's copy, and the silhouettes (their gap and alpha now).
func state() -> Dictionary:
	return {"intensity": intensity, "target": target, "player_copy": _player_copy != null and _player_copy.visible,
		"cover_copy": _cover_copy != null and _cover_copy.visible, "dead": _last_state.get("dead", []).duplicate(true)}


## The player's own copy on the grey layer (tests: it must be the same frame, on the same screen place).
func player_copy() -> AnimatedSprite2D:
	return _player_copy
