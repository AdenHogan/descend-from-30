extends Node2D

# Colored danger cue for a HORDE stairwell: red "sound-wave" rings expanding
# outward from the steps (ground zero), so the swarm reads from across the floor
# even when NOT in listen mode. Purely decorative — the block/clear logic lives
# on the stairwell + the horde zombies. Spawned by building_floors at each horde
# stairwell. z 2 so the waves sit over the corridor and actors without eating
# clicks (Node2D draws only, no input).

const WAVE_COLOR := Color(0.92, 0.16, 0.13)   # in-colour red (not the grey listen overlay)
const N_WAVES := 3
const WAVE_PERIOD := 1.7        # seconds for one ring to travel out
const MIN_RADIUS := 24.0
const MAX_RADIUS := 250.0
const RING_WIDTH := 3.0

var _t := 0.0


func _ready() -> void:
	z_index = 2
	add_to_group("horde_echo")


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	# Several rings at staggered phases so a new one is always setting out as the
	# last fades — a steady pulse radiating from the stairwell.
	for i in range(N_WAVES):
		var phase: float = fmod(_t / WAVE_PERIOD + float(i) / float(N_WAVES), 1.0)
		var r: float = lerpf(MIN_RADIUS, MAX_RADIUS, phase)
		var a: float = (1.0 - phase) * 0.5           # fade as it expands
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(WAVE_COLOR.r, WAVE_COLOR.g, WAVE_COLOR.b, a), RING_WIDTH, true)
