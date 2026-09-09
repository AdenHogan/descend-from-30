extends "res://scripts/enemy_zombie_standard.gd"

# The Crawler: low to the ground, SLOW, FRAGILE — but it HITS HARD. It drags itself
# along and drops in a hit or two, yet a bite from it does DOUBLE damage, so letting
# one reach you hurts. Because it's on the ground a shove-back doesn't land — the
# player's push becomes a KICK-STUN on it instead (player._do_push, receive_kick).
# Stat/behaviour reskin of the standard AI; see docs/THREE_RUN_ARC.md enemy variety.

func _ready() -> void:
	super()
	SPEED = 26.0                 # SLOW — it crawls (standard is 40)
	DETECTION_RANGE = 130.0      # still senses you from a fair way and drags over
	ATTACK_RANGE = 30.0
	ATTACK_DAMAGE = 2            # DOUBLE damage per bite — the trade-off for being slow/weak
	max_hp = maxi(1, int(round(max_hp * 0.55)))   # fragile
	current_hp = max_hp
	add_to_group("crawler")
