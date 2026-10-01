extends RefCounted

# DRAWN FEET ON THE PLAYER'S LINE (owner round 33 — "corpse bodies are below the player y plane. it needs adjusting").
# Every actor STANDS on the same collision line (353 in a flat, 419 in a corridor), but the enemy art drew its lowest pixels
# 2-3 px BELOW its collision feet while the player's rig draws 1 px above — so a standing zombie sat 3-4 px under the player,
# and a body lying flat (all its mass on that bottom row) read as lying in FRONT of the floor. lift_sprite() moves an enemy's
# sprite up so its drawn bottom is where the player's is: PLAYER_DRAWN_ABOVE_COLLISION over the collision feet. Measured from
# the Idle art once per SpriteFrames (cached); the death frames end on the same row (they lie where they stood).

const PLAYER_DRAWN_ABOVE_COLLISION := 1.0      # the player rig: collision bottom 353, drawn bottom 352

static var _bottom_rows: Dictionary = {}       # SpriteFrames -> lowest opaque row (texels) of Idle frame 0


static func collision_bottom(body: Node) -> float:
	var col := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col == null or col.shape == null:
		return 0.0
	if col.shape is RectangleShape2D:
		return col.position.y + (col.shape as RectangleShape2D).size.y * 0.5
	if col.shape is CapsuleShape2D:
		return col.position.y + (col.shape as CapsuleShape2D).height * 0.5
	if col.shape is CircleShape2D:
		return col.position.y + (col.shape as CircleShape2D).radius
	return col.position.y


## The sprite's drawn bottom in its body's space (the lowest opaque pixel of Idle frame 0).
static func drawn_bottom(spr: AnimatedSprite2D) -> float:
	if spr == null or spr.sprite_frames == null or not spr.sprite_frames.has_animation("Idle"):
		return 0.0
	var tex: Texture2D = spr.sprite_frames.get_frame_texture("Idle", 0)
	if tex == null:
		return 0.0
	var h: float = float(tex.get_height())
	var row: int = int(_bottom_rows.get(spr.sprite_frames, -1))
	if row < 0:
		var img: Image = tex.get_image()
		if img == null:
			return 0.0
		if img.is_compressed():
			img.decompress()
		row = int(h) - 1
		var found := false
		for y in range(img.get_height() - 1, -1, -1):
			for x in img.get_width():
				if img.get_pixel(x, y).a > 0.5:
					row = y
					found = true
					break
			if found:
				break
		_bottom_rows[spr.sprite_frames] = row
	var top_left: float = -h * 0.5 if spr.centered else 0.0
	return spr.position.y + (spr.offset.y + top_left + float(row + 1)) * spr.scale.y


## Raise `spr` so its drawn feet sit where the player's do. Returns the lift applied (px, whole).
static func lift_sprite(body: Node, spr: AnimatedSprite2D) -> float:
	if body == null or spr == null:
		return 0.0
	var want: float = collision_bottom(body) - PLAYER_DRAWN_ABOVE_COLLISION
	var lift: float = roundf(drawn_bottom(spr) - want)
	if lift != 0.0:
		spr.position.y -= lift
	return lift
