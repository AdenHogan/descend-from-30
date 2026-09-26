extends "res://scripts/enemy_zombie_standard.gd"

# The Long Arm: ordinary pace, but a LONG reach — it lands its swing from much
# further back than any other zombie, so simply backing off a step isn't safe. A
# touch tougher than a standard. Reuses the standard AI (docs/THREE_RUN_ARC.md).

# Drawn smaller than the rig (owner round 21: "their attacks… look like the attack goes half over
# the head of the player"): the arm's full reach is 25 frame px above its feet, which at the scene's
# 3x swung ~75px up — over a ~58px-tall player. At SPRITE_SCALE it swings at head height. Scaled
# about the FEET (frame row 80 = 16 px below the frame's centre), so it still stands on its line.
const SPRITE_SCALE := 2.2
const FEET_BELOW_CENTRE := 16.0      # frame px (LongArmZombie sheets: every frame's feet on row 80)
const SCENE_SCALE := 3.0


func _ready() -> void:
	super()
	if animated_sprite != null:
		animated_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
		animated_sprite.position.y += FEET_BELOW_CENTRE * (SCENE_SCALE - SPRITE_SCALE)
	SPEED = 38.0
	DETECTION_RANGE = 120.0
	ATTACK_RANGE = 62.0          # the reach threat — standard is 30
	max_hp += 1                  # slightly sturdier
	current_hp = max_hp
	add_to_group("longarm")
