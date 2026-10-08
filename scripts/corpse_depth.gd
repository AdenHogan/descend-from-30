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
#   1. a body SITS `RISE` px further back than the lane (its sprite eased up once it has finished falling, so it reads as lying back from
#      the walking line, and reaches up over a back-plane player's lower legs);
#   2. a body draws IN FRONT of the player (z `FRONT_Z`) only while it is nearer than them by `FRONT_GAP` px — i.e. while they are up on the
#      back plane (or the balcony) behind it. On the lane (same line, or further forward than the body) the player still draws over it, as before.
#
# Three kinds of body: a live enemy that died here (`is_dead`, a CharacterBody2D in group `zombie`); the static sprite a re-entered flat lays
# for a recorded kill (group `room_corpse`, meta `feet_y` = its collision-bottom row, set by room._spawn_corpses); and the BAKED dead of a
# breach / corpse story (group `nest_dead`, one sprite a body cut from `<module>_nest_<role>_dead.png`, meta `feet_off`) — those are drawn
# already `RISE` px back by tools/art/nest.py (BODY_RISE), so only the sort applies to them.

const EnemyFeet = preload("res://scripts/enemy_feet.gd")

const RISE := 6.0                 # how far back from the lane a body lies (px)
const RISE_TIME := 0.3            # …eased over this long once the body has finished falling
const FRONT_GAP := 6.0            # a body is "nearer" when its feet row is at least this much lower than the player's
const FRONT_Z := 2                # actors are z 1; the body goes just over them

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


## Is a body whose feet are on row `body_feet` drawn in front of a player standing on row `player_feet`?
static func in_front_of(body_feet: float, player_feet: float) -> bool:
	return body_feet - player_feet >= FRONT_GAP


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
	if _settled(spr):
		var done: float = float(z.get_meta("cd_rise", 0.0))
		if done < RISE:
			var step: float = minf(RISE - done, RISE * delta / RISE_TIME)
			spr.position.y -= step
			z.set_meta("cd_rise", done + step)
	z.z_index = FRONT_Z if in_front_of(feet, player_feet) else 0


func _tend_static(c: Node2D, player_feet: float) -> void:
	var feet: float = float(c.get_meta("feet_y", c.global_position.y + 48.0))
	c.z_index = FRONT_Z if in_front_of(feet, player_feet) else 0
