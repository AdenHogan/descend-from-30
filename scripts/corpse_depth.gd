class_name CorpseDepth
extends Node

# THE DEAD LIE IN FRONT OF WHOEVER STANDS LEVEL WITH THEM (owner round 48h, on a screenshot of the player's legs painted over a body in a flat: "I am standing
# on top of bodies in an over clipping way, both for NPCs and enemies… have those elements in front of players feet, that's likely the better option so it
# looks like player is walking behind them and they sprawled out in the room").
#
# Every body used to sit on the floor layer (z 0), UNDER the living (z 1), so a player standing on a body's row had their legs drawn straight over it — and, since a
# lying body is only ~15 px tall, the player looked as if they were standing ON it. Now it is sorted by FEET ROW, like everything else in a 2.5D scene:
#   * a body whose feet are level with the player's (within SAME px above them) or nearer (below them, up to REACH) draws IN FRONT (z `Z`, over the actors at z 1) — the
#     player walks behind it, their lower legs hidden by the body, and it lies sprawled out in the room in front of them;
#   * a body clearly BEHIND the player (further up the screen) stays under them, so a player in front of it still draws over it, as anything would.
# A player stepped up onto a back plane (feet 14 px behind the lane) is behind a body on the lane, so the body is over them there too.
#
# One node per world scene (`ensure`: flats, corridors, the hallway, the lobby — each sorts only its own bodies, so a pan's second floor never interferes: a body
# more than REACH below the player cannot overlap them anyway and is left alone). The kinds of body it sorts, all by their own feet row:
#   a live enemy that died here (`is_dead`, group `zombie`) and a RISER still lying (`is_riser_down`), a resident or survivor that died (`is_dead`, groups
#   `resident_npc` / `survivor`), the static sprite a re-entered flat lays for a recorded kill (`room_corpse`, meta `feet_y`), the BAKED dead of a breach / corpse
#   story (`nest_dead`, one sprite a body cut from `<module>_nest_<role>_dead.png`, meta `feet_off`), a corridor's baked dead (`corridor_dead`, a decal: its feet are its
#   bottom row) and the body of a previous character (`player_corpse`).
# Bodies lie where they fell / were placed (round 37's "sit 6 px back" is gone — a body 6 px BEHIND the player's row is exactly what let their legs draw over it;
# tools/art/nest.py BODY_RISE is 0 to match) - but DRAWN `DROP` px lower (owner round 48i: "I can just see the player's feet below the corpse... move the corpses
# a little lower from the Y plane"): a lying body is a ragged shape whose lowest pixels are not all on the row the feet stand on, so with the player behind it a
# sliver of boot showed under it. The drop is only the sprite - the body's position, feet row and sorting are unchanged.

const EnemyFeet = preload("res://scripts/enemy_feet.gd")

const Z := 2                      # actors are z 1; a body in front goes just over them (room.OVER_ART_Z is 3)
const SAME := 3.0                 # a body is "level" with the player when its feet are at most this far ABOVE theirs
const REACH := 40.0               # …and "in front" up to this far below: further forward it cannot overlap the player (and another floor's bodies stay out of it)
const DROP := 4.0                 # a body is drawn this many px lower than the row it lies on, so the feet of whoever stands behind it are hidden
const BAKED_RISE := 0.0           # how far back the art tool sets a baked body (tools/art/nest.py BODY_RISE) — 0: they lie on the row they were placed on

var room: Node = null


## One sorter per world scene. Safe to call twice.
static func ensure(root: Node) -> CorpseDepth:
	var have := root.get_node_or_null("CorpseDepth")
	if have is CorpseDepth:
		return have
	var n := CorpseDepth.new()
	n.name = "CorpseDepth"
	n.room = root
	root.add_child(n)
	return n


## Draw a body's sprite DROP px lower, once. `n` is the body (its own sprite child is moved) or the sprite itself.
static func drop_body(n: Node) -> void:
	if n == null or n.has_meta("cd_dropped"):
		return
	var spr: Node2D = null
	if n is Sprite2D or n is AnimatedSprite2D:
		spr = n as Node2D
	else:
		spr = n.get_node_or_null("AnimatedSprite2D") as Node2D
		if spr == null:
			spr = n.get_node_or_null("Sprite2D") as Node2D
	if spr == null:
		return
	spr.position.y += DROP
	n.set_meta("cd_dropped", true)


## Is a body whose feet are on row `body_feet` drawn in front of a player standing on row `player_feet`?
static func in_front_of(body_feet: float, player_feet: float) -> bool:
	return body_feet >= player_feet - SAME and body_feet <= player_feet + REACH


func _process(_delta: float) -> void:
	if room == null or not is_instance_valid(room) or not is_inside_tree():
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or not player.has_method("feet_position"):
		return
	var pf: float = player.feet_position().y
	for z in get_tree().get_nodes_in_group("zombie"):
		if is_instance_valid(z) and room.is_ancestor_of(z) and (bool(z.get("is_dead")) or (z.has_method("is_riser_down") and z.is_riser_down())):
			if bool(z.get("is_dead")):
				drop_body(z)
			var col := z.get_node_or_null("CollisionShape2D")
			var feet: float = z.global_position.y + (EnemyFeet.collision_bottom(z) if col != null else 0.0)
			z.z_index = Z if in_front_of(feet, pf) else 0
	for g in ["resident_npc", "survivor"]:
		for n in get_tree().get_nodes_in_group(g):
			if is_instance_valid(n) and room.is_ancestor_of(n) and bool(n.get("is_dead")):
				drop_body(n)
				n.z_index = Z if in_front_of(n.global_position.y, pf) else 0
	for c in get_tree().get_nodes_in_group("room_corpse"):
		if is_instance_valid(c) and room.is_ancestor_of(c):
			var f: float = float(c.get_meta("feet_y", c.global_position.y + 48.0))
			drop_body(c)
			c.z_index = Z if in_front_of(f, pf) else 0
	for d in get_tree().get_nodes_in_group("nest_dead"):
		if is_instance_valid(d) and room.is_ancestor_of(d):
			var spr := d as Node2D
			drop_body(spr)
			var f2: float = spr.global_position.y - DROP * spr.global_scale.y + float(spr.get_meta("feet_off", 0.0)) * spr.global_scale.y        # (sorted on the row it lies on, not the drawn drop)
			spr.z_index = Z if in_front_of(f2, pf) else 0
	for k in get_tree().get_nodes_in_group("corridor_dead"):                 # a corridor's baked dead (a decal): its feet are the sprite's bottom row
		if is_instance_valid(k) and room.is_ancestor_of(k) and (k as Sprite2D).texture != null:
			var ks := k as Sprite2D
			drop_body(ks)
			var f3: float = ks.global_position.y - DROP * ks.global_scale.y + float(ks.texture.get_height()) * ks.global_scale.y - 1.0
			ks.z_index = Z if in_front_of(f3, pf) else 0
	for b in get_tree().get_nodes_in_group("player_corpse"):
		if is_instance_valid(b) and room.is_ancestor_of(b):
			b.z_index = Z if in_front_of(b.global_position.y, pf) else 0
