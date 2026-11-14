class_name PlayerRig
extends RefCounted

## The player's SPRITE, swapped for the new characters' art (owner 2026-11-14: "start on the core set"). assets/players/<joe|vivianne|alex|amina>_frames.tres, made
## by tools/art/player_rigs.py: every animation NAME the player script plays, posed on the people rig — a swing for each weapon with it in hand
## (`swing_bat` / `swing_sword` / `swing_knife`), the shove (`punch_jab` / `push`), hurt, death, a real crouch, the pistol aim and shot — each keeping the DURATION
## the old sprite had, so the script's timers and waits agree. If a character's art is missing the old template sprite is left alone.
## The cell's bottom edge sits 1 px over the collision feet (the way the old rig stood) and the body's hips are on the cell's centre column, so
## flip_h turns it about the body.

const EnemyFeet := preload("res://scripts/enemy_feet.gd")
const DIR := "res://assets/players/"
const KEYS := {"blond_man": "joe", "blond_woman": "vivianne", "bald_man": "alex", "dark_woman": "amina"}


static func key_for(character: String) -> String:
	return String(KEYS.get(character, ""))


## Swap `spr` (the player's AnimatedSprite2D) for `character`'s art. Returns true if it did.
static func apply(player: Node, spr: AnimatedSprite2D, character: String) -> bool:
	var key := key_for(character)
	if key == "" or spr == null or not ResourceLoader.exists(DIR + key + "_frames.tres") or not FileAccess.file_exists(DIR + "players.json"):
		return false
	var meta = JSON.parse_string(FileAccess.get_file_as_string(DIR + "players.json"))
	if not (meta is Dictionary) or not meta.has("cell"):
		return false
	var frames: SpriteFrames = load(DIR + key + "_frames.tres")
	if frames == null:
		return false
	var cell := Vector2(float(meta["cell"][0]), float(meta["cell"][1]))
	spr.sprite_frames = frames
	spr.scale = Vector2.ONE
	spr.centered = true
	spr.offset = Vector2.ZERO
	spr.position = Vector2(0.0, EnemyFeet.collision_bottom(player) - EnemyFeet.PLAYER_DRAWN_ABOVE_COLLISION - cell.y * 0.5)
	spr.play("idle")
	return true


## The swing animation for a melee weapon type ("knife" / "sword" / "bat"): its own if the sprite has one, else the old single swing.
static func swing_anim(spr: AnimatedSprite2D, weapon_type: String) -> String:
	var n := "swing_" + weapon_type
	if spr != null and spr.sprite_frames != null and spr.sprite_frames.has_animation(n):
		return n
	return "katana_attack_continuous"
