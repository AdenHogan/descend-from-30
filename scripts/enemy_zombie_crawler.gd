extends "res://scripts/enemy_zombie_standard.gd"

# The Crawler: low to the ground, FAST, and FRAGILE — a swarmer that closes the gap
# quicker than anything else but drops in a hit or two. Pure stat/look reskin of the
# standard zombie (reuses its whole AI); see docs/THREE_RUN_ARC.md enemy variety.

func _ready() -> void:
	super()
	SPEED = 68.0                 # noticeably faster than a standard (40)
	DETECTION_RANGE = 130.0      # spots you from a bit further, then rushes
	ATTACK_RANGE = 30.0
	max_hp = maxi(1, int(round(max_hp * 0.55)))   # fragile
	current_hp = max_hp
	add_to_group("crawler")
