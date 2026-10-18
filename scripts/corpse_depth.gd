class_name CorpseDepth
extends Node

# LYING BODIES HAVE DEPTH IN A FLAT (owner round 37 playtest: "there's a clipping situation with this corpse position. If it's a little
# higher then we can have player walk behind the corpse, as it would cover the player's lower legs, which gives the scene a little depth").
#
# A flat has a second walking line: stepping UP at set-back furniture (back_plane_spot.gd) puts the player's feet 14 px behind the lane. A
# body lying on the lane is NEARER than that player, but corpses draw on the floor layer (z 0, under every actor — the rule that stops a
# player on the lane standing with their legs poking out from under a body) so the player's legs were painted straight over it, and a
# lying body is only 15 px tall, so even drawn in front it would barely reach their feet. Two things, both for FLATS only (this node is
# added by room.gd; corridors have no second line and keep their bodies on the player's row — enemy_variety_test):
#   1. a body SITS `RISE` px further back than the lane (its sprite eased up WHILE it falls — a pixel at a time, with the Death animation's
#      progress — so it reads as lying back from the walking line and reaches up over a back-plane player's lower legs; owner round 45:
#      it used to settle on the lane and THEN slide up 6 px, "drops below the Y plane then clumsily moves back up");
#   2. a body draws IN FRONT of the player (z `FRONT_Z`) only while it is nearer than them by `FRONT_GAP` px — i.e. while they are up on the
#      back plane (or the balcony) behind it. On the lane (same line, or further forward than the body) the player still draws over it, as before.
#
# Three kinds of body: a live enemy that died here (`is_dead`, a CharacterBody2D in group `zombie`); the static sprite a re-entered flat lays
# for a recorded kill (group `room_corpse`, meta `feet_y` = its collision-bottom row, set by room._spawn_corpses); and the BAKED dead of a
# breach / corpse story (group `nest_dead`, one sprite a body cut from `<module>_nest_<role>_dead.png`, meta `feet_off`) — those are drawn
# already `RISE` px back by tools/art/nest.py (BODY_RISE), so only the sort applies to them.

const EnemyFeet = preload("res://scripts/enemy_feet.gd")

const RISE := 6.0                 # how far back from the lane a body lies (px)
const FRONT_GAP := 6.0            # a body is "nearer" when its feet row is at least this much lower than the player's
const FRONT_Z := 2                # actors are z 1; the body goes just over them

# THINGS NEARER THAN A BODY (owner round 45: "enemy corpses are resting on top of floor art assets… needs adjustment so there is no overlap"):
# a body lies with its drawn bottom at local row 122 (tools/art/pixlib.py NEAR_LINE); a toppled chair or a torn gift box whose silhouette
# reaches below that is NEARER than it, so the body must go BEHIND it — but the art is one baked image under every actor. The art tool
# exports a 1-bit mask of such pieces (`<art>_near.png`, `_near_r2/_r3` if a run look moves them, `_near_strip.png` for the balcony-strip
# part) and this shader clips a corpse's sprite where the mask is set, so the baked piece shows through in front of it.
const NEAR_SHADER_CODE := """
shader_type canvas_item;
uniform sampler2D near_a : filter_nearest;
uniform sampler2D near_b : filter_nearest;
uniform vec2 origin = vec2(0.0);
uniform vec2 module_size = vec2(320.0, 144.0);
varying vec2 world_pos;
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
void fragment() {
	vec2 uv = (world_pos - origin) / module_size;
	float m = 0.0;
	if (uv.x >= 0.0 && uv.x < 1.0 && uv.y >= 0.0 && uv.y < 1.0) {
		m = max(texture(near_a, uv).a, texture(near_b, uv).a);
	}
	COLOR.a *= 1.0 - step(0.5, m);
}
"""
static var _near_shader: Shader = null
static var _blank_mask: Texture2D = null

var room: Node = null


func _process(delta: float) -> void:
	if room == null or not is_instance_valid(room):
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var player_feet: float = INF
	if player != null and player.has_method("feet_position"):
		player_feet = player.feet_position().y
	for z in get_tree().get_nodes_in_group("zombie"):
		if is_instance_valid(z) and room.is_ancestor_of(z) and bool(z.get("is_dead")):
			_tend_live(z, delta, player_feet)
	for c in get_tree().get_nodes_in_group("room_corpse"):
		if is_instance_valid(c) and room.is_ancestor_of(c):
			_tend_static(c, player_feet)
	for d in get_tree().get_nodes_in_group("nest_dead"):
		if is_instance_valid(d) and room.is_ancestor_of(d):
			var spr := d as Node2D
			var feet: float = spr.global_position.y + float(spr.get_meta("feet_off", 0.0)) * spr.global_scale.y
			spr.z_index = FRONT_Z if in_front_of(feet, player_feet) else 0


## The mask files for a module's art texture: [main, strip] (a path is "" when there is none). A run look uses its own mask when
## the art tool wrote one (it moved a piece), else the first look's; a burnt flat has none (its art is its own husk).
static func mask_paths(art_path: String, strip_on: bool) -> Array:
	var base: String = art_path.get_basename()
	if base.ends_with("_burnt"):
		return ["", ""]
	var run := ""
	for sfx in ["_r3", "_r2"]:
		if base.ends_with(sfx):
			run = sfx
			base = base.left(base.length() - sfx.length())
			break
	var out: Array = []
	for part in ["", "_strip"]:
		var found := ""
		if part == "" or strip_on:
			for cand in [base + "_near" + run + part + ".png", base + "_near" + part + ".png"]:
				if ResourceLoader.exists(cand):
					found = cand
					break
		out.append(found)
	return out


## The material that tucks a body behind this module's near pieces, or null when the module has none. Cached on the module.
func _near_material(module: Node) -> ShaderMaterial:
	if module.has_meta("cd_near"):
		return module.get_meta("cd_near") as ShaderMaterial
	var mat: ShaderMaterial = null
	var art := module.get_node_or_null("Art") as Sprite2D
	if art != null and art.texture != null and art.texture.resource_path != "":
		var strip_node := module.get_node_or_null("FrontStrip")
		if strip_node == null:
			strip_node = module.get_node_or_null("StripArt")
		var strip_on: bool = strip_node is CanvasItem and (strip_node as CanvasItem).visible
		var paths := mask_paths(art.texture.resource_path, strip_on)
		if paths[0] != "" or paths[1] != "":
			if _near_shader == null:
				_near_shader = Shader.new()
				_near_shader.code = NEAR_SHADER_CODE
			if _blank_mask == null:
				var blank := Image.create(1, 1, false, Image.FORMAT_RGBA8)
				_blank_mask = ImageTexture.create_from_image(blank)
			mat = ShaderMaterial.new()
			mat.shader = _near_shader
			mat.set_shader_parameter("near_a", load(paths[0]) if paths[0] != "" else _blank_mask)
			mat.set_shader_parameter("near_b", load(paths[1]) if paths[1] != "" else _blank_mask)
			var size: Vector2 = art.texture.get_size() * art.scale
			mat.set_shader_parameter("module_size", size)
			mat.set_shader_parameter("origin", (module as Node2D).global_position + art.position - (size * 0.5 if art.centered else Vector2.ZERO))
	module.set_meta("cd_near", mat)
	return mat


## The module of this flat whose x-range holds `x` (world), or null.
func _module_at(x: float) -> Node:
	for m in room.get_children():
		if m.is_in_group("room_module") and m is Node2D:
			var gx: float = (m as Node2D).global_position.x
			if x >= gx and x < gx + 320.0:
				return m
	return null


## Clip a body's sprite behind its module's near pieces, once. A sprite already wearing another material (a hurt flash, which clears
## itself) is tried again next frame.
func _tuck(body: Node, spr: AnimatedSprite2D, world_x: float) -> void:
	if body.has_meta("cd_tucked"):
		return
	var module := _module_at(world_x)
	var mat: ShaderMaterial = _near_material(module) if module != null else null
	if mat == null:
		body.set_meta("cd_tucked", true)
		return
	if spr.material == null:
		spr.material = mat
		body.set_meta("cd_tucked", true)


## Is a body whose feet are on row `body_feet` drawn in front of a player standing on row `player_feet`?
static func in_front_of(body_feet: float, player_feet: float) -> bool:
	return body_feet - player_feet >= FRONT_GAP


## How far back a body's sprite should be by now: the whole RISE once it lies there, and a share of it, in WHOLE pixels, while its
## Death animation plays (frame k of n puts it floor(RISE * k / (n-1)) px back), so there is never a slide after it has landed.
static func rise_for(spr: AnimatedSprite2D) -> float:
	if spr == null or spr.sprite_frames == null:
		return 0.0
	if _settled(spr):
		return RISE
	if spr.animation == "Death" and spr.sprite_frames.has_animation("Death"):
		var last: int = maxi(spr.sprite_frames.get_frame_count("Death") - 1, 1)
		return floorf(RISE * clampf(float(spr.frame) / float(last), 0.0, 1.0))
	return 0.0


static func _settled(spr: AnimatedSprite2D) -> bool:
	if spr == null or spr.sprite_frames == null:
		return false
	if spr.animation == "Dead_Dead":
		return true
	return spr.animation == "Death" and spr.frame >= spr.sprite_frames.get_frame_count("Death") - 1


func _tend_live(z: Node2D, delta: float, player_feet: float) -> void:
	var spr := z.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if spr == null:
		return
	var col := z.get_node_or_null("CollisionShape2D")
	var feet: float = z.global_position.y + (EnemyFeet.collision_bottom(z) if col != null else 0.0)
	_tuck(z, spr, z.global_position.x)
	var want: float = rise_for(spr)
	var done: float = float(z.get_meta("cd_rise", 0.0))
	if want > done:
		spr.position.y -= want - done
		z.set_meta("cd_rise", want)
	z.z_index = FRONT_Z if in_front_of(feet, player_feet) else 0


func _tend_static(c: Node2D, player_feet: float) -> void:
	if c is AnimatedSprite2D:
		_tuck(c, c as AnimatedSprite2D, c.global_position.x)
	var feet: float = float(c.get_meta("feet_y", c.global_position.y + 48.0))
	c.z_index = FRONT_Z if in_front_of(feet, player_feet) else 0
