extends Node2D

# A few SMALL flames stuck across an enemy's body while it's standing in flame (or lit by a fire weapon). Purely
# cosmetic — the gameplay (double damage + burn DoT) lives on the enemy. Added as a child at the enemy's torso when it
# catches, removed when it steps clear OR dies (the parent enemy clears it). NO collision/physics — it never blocks the
# player. Drawn from OUR fire strips (`small_<v>`, scripts/fire_art.gd) at native size, unshaded so a burning body glows
# even in the night-dark; 3 flames at different spots on the body, each out of step.

var _t: float = 0.0
# Each flame: local pos of its BASE (relative to the fx origin at ~torso), which small_<v> variant, animation phase.
# A lower-torso flame, a chest flame, and a shoulder lick, so it reads as fire clinging to the body, not a bonfire.
var _globs: Array = [
	{"pos": Vector2(-4.0, 6.0), "v": "small_1", "ph": 0.0, "flip": false},
	{"pos": Vector2(5.0, -6.0), "v": "small_2", "ph": 0.37, "flip": true},
	{"pos": Vector2(-3.0, -16.0), "v": "small_3", "ph": 0.71, "flip": false},
]


func _ready() -> void:
	z_index = 2
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST      # crisp pixels, no blur
	material = FireArt.material()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	for g in _globs:
		FireArt.draw(self, str(g["v"]), _t, float(g["ph"]), g["pos"], 1.0, bool(g["flip"]))
