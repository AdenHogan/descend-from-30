class_name NodeCritter
extends Node2D

## Something small startled out of a node the moment it is searched (round 45d: "more things should move when a node is scavenged… these details
## make the world more alive"): a RAT bolts along the floor, a ROACH scuttles, a MOTH flutters up out of a wardrobe. Pure decoration — no body, no
## collision, not in any enemy group, gone in about a second and a half. Drawn in code (a few pixels, like the dust). Which nodes startle one is
## seeded per (game, flat, node, run) in NodeReaction.critter_for, so a re-entry never replays it (opened_anchors guards the press anyway).

const LIFE := {"rat": 1.5, "roach": 1.2, "moth": 2.0}
const SPEED := {"rat": 130.0, "roach": 95.0, "moth": 38.0}

var kind := "rat"
var dir := 1.0                  # +1 runs right, -1 left
var floor_y := 120.0            # module-local row it lands on and runs along (rat, roach)
var _t := 0.0
var _vy := 0.0
var _phase := 0.0


## Startle one at `at` (global), running `dir_x` (+1 / -1), over the floor row `floor_row` (in `holder`'s own coordinates).
static func spawn(holder: Node, at: Vector2, kind_: String, dir_x: float, floor_row: float) -> Node2D:
	if holder == null or not holder.is_inside_tree():
		return null
	var c := NodeCritter.new()
	c.kind = kind_
	c.dir = 1.0 if dir_x >= 0.0 else -1.0
	c.floor_y = floor_row
	holder.add_child(c)
	c.global_position = at
	return c


func _ready() -> void:
	z_index = 0
	_phase = randf() * TAU
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	_t += delta
	var life: float = LIFE.get(kind, 1.5)
	if _t >= life:
		queue_free()
		return
	var sp: float = SPEED.get(kind, 100.0)
	if kind == "moth":
		position.x += dir * sp * delta + sin(_t * 11.0 + _phase) * 22.0 * delta
		position.y -= (26.0 + 10.0 * sin(_t * 7.0)) * delta
	else:
		position.x += dir * sp * delta * (0.35 if _t < 0.12 else 1.0)       # a beat of freezing, then off
		if position.y < floor_y:                                             # dropped from the node to the floor
			_vy += 520.0 * delta
			position.y = minf(position.y + _vy * delta, floor_y)
		else:
			position.y = floor_y
	modulate.a = clampf((life - _t) / 0.3, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(dir, 1.0))                 # drawn facing right, flipped by the way it runs
	match kind:
		"rat":
			var step := 1.0 if int(_t * 18.0) % 2 == 0 else -1.0
			draw_rect(Rect2(-4.0, -4.0, 8.0, 4.0), Color(0.22, 0.2, 0.19))                                          # body
			draw_rect(Rect2(3.0, -3.0, 3.0, 2.0), Color(0.3, 0.27, 0.25))                                           # head
			draw_rect(Rect2(3.0, -4.0, 1.0, 1.0), Color(0.55, 0.38, 0.38))                                          # ear
			draw_rect(Rect2(5.0, -3.0, 1.0, 1.0), Color(0.9, 0.3, 0.3))                                             # eye
			for i in range(5):                                                                                       # the tail, wiggling
				draw_rect(Rect2(-5.0 - float(i), -2.0 + sin(_t * 30.0 + float(i)) * 0.8, 1.0, 1.0), Color(0.5, 0.38, 0.38))
			draw_rect(Rect2(-2.0 + step, -1.0, 1.0, 1.0), Color(0.12, 0.11, 0.1))                                  # feet
			draw_rect(Rect2(2.0 - step, -1.0, 1.0, 1.0), Color(0.12, 0.11, 0.1))
		"roach":
			var wig := 1.0 if int(_t * 24.0) % 2 == 0 else 0.0
			draw_rect(Rect2(-2.5, -2.0, 5.0, 2.0), Color(0.3, 0.17, 0.1))
			draw_rect(Rect2(2.5, -2.0, 2.0, 1.0), Color(0.2, 0.11, 0.07))
			draw_rect(Rect2(-1.0, -3.0, 2.0, 1.0), Color(0.42, 0.26, 0.14))
			draw_rect(Rect2(-2.0 + wig, 0.0, 1.0, 1.0), Color(0.15, 0.09, 0.06))
			draw_rect(Rect2(1.0 - wig, 0.0, 1.0, 1.0), Color(0.15, 0.09, 0.06))
		"moth":
			var flap := 2.0 + 2.0 * absf(sin(_t * 26.0))
			draw_rect(Rect2(-0.5, -1.5, 1.0, 3.0), Color(0.35, 0.3, 0.26))
			draw_rect(Rect2(-0.5 - flap, -2.0, flap, 3.0), Color(0.72, 0.68, 0.6))
			draw_rect(Rect2(0.5, -2.0, flap, 3.0), Color(0.72, 0.68, 0.6))
