extends "res://scripts/enemy_zombie_standard.gd"

# The Long Arm: ordinary pace, but a LONG reach — it lands its swing from much
# further back than any other zombie, so simply backing off a step isn't safe. A
# touch tougher than a standard. Reuses the standard AI (docs/THREE_RUN_ARC.md).

func _ready() -> void:
	super()
	SPEED = 38.0
	DETECTION_RANGE = 120.0
	ATTACK_RANGE = 62.0          # the reach threat — standard is 30
	max_hp += 1                  # slightly sturdier
	current_hp = max_hp
	add_to_group("longarm")
