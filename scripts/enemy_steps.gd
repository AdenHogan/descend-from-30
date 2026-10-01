extends RefCounted
class_name EnemySteps

# ZOMBIE SHUFFLE (docs/SOUND_STEALTH.md open task — "add shuffle/drag loops while zombies walk"): a
# dragging, scuffing footfall played from a positional player on the enemy while it is actually MOVING,
# at a rate that follows its speed. Together with the moans it's the off-screen presence cue — you hear
# the dead coming before you see them. Three generated one-shots (tools/gen_zombie_steps.py, CC0).
# One static `tick` called from each enemy's physics step; state rides on the enemy as meta so there's
# no node bookkeeping, and the stream player is created lazily (an enemy that never moves never pays).

const STREAMS := [
	preload("res://assets/audio/zombie/shuffle_1.wav"),
	preload("res://assets/audio/zombie/shuffle_2.wav"),
	preload("res://assets/audio/zombie/shuffle_3.wav"),
]
const MIN_SPEED := 6.0            # slower than this it's standing, not walking
const STRIDE := 24.0              # px between footfalls (interval = STRIDE / speed)
const MIN_GAP := 0.38             # never faster than this, however quick it runs
const MAX_GAP := 1.25
const MAX_DISTANCE := 320.0       # quieter + nearer than the moans: you hear a shuffle only when they're close
# Owner round 33: the shuffle was "very loud and scratchy… it even overwhelms the moaning". It's a soft brush now
# (tools/gen_zombie_steps.py) and sits at least MOAN_HEADROOM dB under the moans (moan_player -2 dB), so it's a presence, never
# the loudest thing in the corridor.
const DEFAULT_DB := -20.0
const MOAN_HEADROOM := 14.0


## Advance one enemy's step timer; plays a footfall when due. `pitch` = its voice/size pitch
## (big ones are lower), `db` = its loudness trim.
static func tick(e: CharacterBody2D, delta: float, pitch: float = 1.0, db: float = DEFAULT_DB) -> void:
	if not is_instance_valid(e) or e.is_dead:
		return
	var wall = e.get("wall_mode")                   # crawlers only: "" on the floor, else clinging / dropping
	if e.get("stair_mode") == true or (wall != null and str(wall) != ""):
		return                                      # lurking on the steps / clinging to a wall: no footsteps
	var speed := absf(e.velocity.x)
	if speed < MIN_SPEED:
		e.set_meta("step_t", 0.0)
		return
	var t: float = float(e.get_meta("step_t", 0.0)) - delta
	if t > 0.0:
		e.set_meta("step_t", t)
		return
	e.set_meta("step_t", clampf(STRIDE / speed, MIN_GAP, MAX_GAP))
	var p: AudioStreamPlayer2D = e.get_node_or_null("StepPlayer")
	if p == null:
		p = AudioStreamPlayer2D.new()
		p.name = "StepPlayer"
		p.max_distance = MAX_DISTANCE
		if AudioServer.get_bus_index(Game.ENEMY_BUS) != -1:
			p.bus = Game.ENEMY_BUS
		e.add_child(p)
	p.volume_db = db
	p.stream = STREAMS[randi() % STREAMS.size()]
	p.pitch_scale = pitch * randf_range(0.92, 1.08)
	p.play()
