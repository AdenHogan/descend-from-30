extends Node

# THE FOUR PLAYERS' SPRITES (owner 2026-11-14: "start on the core set"; scripts/player_rig.gd, tools/art/player_rigs.py).
#   • every animation NAME the player script plays exists on each character's sprite (a missing one would print an error and freeze a pose);
#   • each keeps the DURATION (frames / speed) the old template sprite had — the script's timers and waits agree;
#   • the cell's bottom edge is on the floor 1 px over the collision feet, and the body's hips on the cell's centre column (flip_h turns it about the body);
#   • the swing is the weapon's own (knife / sword / bat), death does not loop, and a character with no art keeps the old sprite untouched;
#   • the swing's weapon IS in the hand: a swing frame differs from the idle frame by more than an arm's worth of pixels.
# Run: godot --headless res://tests/player_rig_test.tscn

var failures: int = 0
const PLAYED := ["idle", "walk", "run", "crouch_idle", "crouch_walk", "death", "hurt", "punch_jab", "push", "katana_attack_continuous", "sword_attack", "sword_stab",
	"katana_idle", "sword_idle", "katana_walk", "katana_run", "sword_run", "grab", "roll", "air_spin", "gun_idle", "gun_walk", "gun_run", "gun_shoot", "run_aim", "run_shooting"]
const OLD_DURATION := {"idle": 1.25, "walk": 1.333, "run": 1.0, "death": 1.4286, "hurt": 0.5, "punch_jab": 1.0, "katana_attack_continuous": 1.0, "gun_shoot": 0.625}


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== player rig test ===")
	var old_frames: SpriteFrames = (load("res://scenes/player.tscn").instantiate() as Node).get_node("AnimatedSprite2D").sprite_frames
	for character in ["blond_man", "blond_woman", "bald_man", "dark_woman"]:
		var key: String = PlayerRig.key_for(character)
		check(key != "", "%s has art (%s)" % [character, key])
		var player = load("res://scenes/player.tscn").instantiate()
		var spr: AnimatedSprite2D = player.get_node("AnimatedSprite2D")
		check(PlayerRig.apply(player, spr, character), "%s: the sprite is swapped" % character)
		var frames: SpriteFrames = spr.sprite_frames
		var missing: Array = []
		for a in PLAYED:
			if not frames.has_animation(a):
				missing.append(a)
		check(missing.is_empty(), "%s: every animation the game plays is there (%s missing)" % [character, str(missing)])
		var dur_ok := true
		var why := ""
		for a in OLD_DURATION:
			var d: float = float(frames.get_frame_count(a)) / maxf(0.01, frames.get_animation_speed(a))
			if absf(d - float(OLD_DURATION[a])) > 0.08:
				dur_ok = false
				why += " %s %.2f vs %.2f" % [a, d, float(OLD_DURATION[a])]
		check(dur_ok, "%s: the old durations are kept (%s)" % [character, why.strip_edges()])
		check(not frames.get_animation_loop("death") and not frames.get_animation_loop("gun_shoot"), "%s: death and the shot do not loop" % character)
		check(frames.get_frame_count("gun_walk") == 8 and frames.get_frame_count("gun_shoot") == 10, "%s: the gun animations keep their frame counts the tests pin" % character)
		var cell_h: float = float(frames.get_frame_texture("idle", 0).get_height())
		var feet: float = spr.position.y + cell_h * 0.5
		check(is_equal_approx(feet, EnemyFeetRef.collision_bottom(player) - 1.0), "%s: the cell's bottom edge is 1 px over the collision feet (%.1f)" % [character, feet])
		check(PlayerRig.swing_anim(spr, "knife") == "swing_knife" and PlayerRig.swing_anim(spr, "sword") == "swing_sword" and PlayerRig.swing_anim(spr, "bat") == "swing_bat"
			and PlayerRig.swing_anim(spr, "") == "katana_attack_continuous", "%s: each weapon swings its own swing" % character)
		# the weapon is in the hand: a swing frame is not the idle frame
		var idle_img: Image = frames.get_frame_texture("idle", 0).get_image()
		var big := 0
		for a in ["swing_bat", "swing_sword", "swing_knife"]:
			var mid: Image = frames.get_frame_texture(a, frames.get_frame_count(a) / 2).get_image()
			var diff := 0
			for y in range(0, idle_img.get_height(), 2):
				for x in range(0, idle_img.get_width(), 2):
					if idle_img.get_pixel(x, y).a != mid.get_pixel(x, y).a:
						diff += 1
			if diff > 120:
				big += 1
		check(big == 3, "%s: all three swings draw the weapon and the arm (%d of 3 differ from the idle)" % [character, big])
		player.free()
	# a character with no art keeps the old template sprite
	var p2 = load("res://scenes/player.tscn").instantiate()
	var s2: AnimatedSprite2D = p2.get_node("AnimatedSprite2D")
	var before: SpriteFrames = s2.sprite_frames
	check(not PlayerRig.apply(p2, s2, "nobody") and s2.sprite_frames == before and is_equal_approx(s2.scale.x, 2.0), "an unknown character leaves the old sprite alone")
	p2.free()
	print("=== %s (%d failures) ===" % ["ALL PASSED" if failures == 0 else "FAILED", failures])
	get_tree().quit(1 if failures > 0 else 0)


const EnemyFeetRef := preload("res://scripts/enemy_feet.gd")
