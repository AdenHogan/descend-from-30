class_name AiMind
extends RefCounted

# THE SHARED SENSES of every thinking thing in the building — survivors AND the dead (docs/NPC_AI.md).
#
# One rule for the whole AI layer: perceive → decide → act, and the decision is always one of a short list of
# NAMED behaviours the player can learn to read (each shows a "tell" — scripts/ai_tell.gd). Nothing here is
# random in a way that hides the pattern; the few dice that exist (a hider's nerve, a gun's aim) are seeded.
#
# These are pure helpers over plain nodes, so they are unit-testable without a scene:
#   gap()      horizontal distance between two actors on the SAME plane (INF when they can't touch)
#   nearest()  the closest living candidate within a gap
#   facing()   -1 / +1 toward a point

const ENEMY_PLANE := preload("res://scripts/enemy_plane.gd")

## Actors in a corridor or a flat share one walking LANE, so the vertical origin gap between rigs (the player
## 386, a standard zombie 370, a homeless-pack survivor 419 …) must never count — only the plane does.
const NO_REACH := INF


## True when `n` can be fought / seen right now: a live actor that is not riding the stairs, not lying as a
## riser, not clinging to a wall, not mid-way through a pack-plane step.
static func present(n: Node) -> bool:
	if not is_instance_valid(n) or not (n is Node2D):
		return false
	if n.get("is_dead") == true:
		return false
	if n.get("stair_mode") == true:
		return false
	var ph = n.get("riser_phase")
	if ph != null and str(ph) != "":
		return false
	if n.get("on_wall") == true:
		return false
	return true


## Horizontal gap between two actors, or NO_REACH when they are not on one plane (room floor vs balcony, or
## mid-step) or either is not present. Lane-only: the vertical origin gap between rigs is ignored.
static func gap(a: Node, b: Node) -> float:
	if not present(a) or not present(b):
		return NO_REACH
	if not ENEMY_PLANE.same_plane(a, b):
		return NO_REACH
	return absf((a as Node2D).global_position.x - (b as Node2D).global_position.x)


## The nearest of `nodes` that `me` can reach within `max_gap` (null = none). Ties go to the lower instance id,
## so the choice is stable frame to frame (no flicker between two equidistant targets).
static func nearest(me: Node, nodes: Array, max_gap: float) -> Node2D:
	var best: Node2D = null
	var best_gap := INF
	for n in nodes:
		if n == me:
			continue
		var g := gap(me, n)
		if g > max_gap:
			continue
		if g < best_gap - 0.5 or (absf(g - best_gap) <= 0.5 and best != null and n.get_instance_id() < best.get_instance_id()):
			best_gap = g
			best = n
	return best


## -1 (left) or +1 (right) from `from_x` toward `to_x`; keeps `keep` when they are level.
static func facing(from_x: float, to_x: float, keep: float = 1.0) -> float:
	var d := to_x - from_x
	return keep if absf(d) < 0.5 else signf(d)


## Moves `x` toward `target` by at most `step` without overshooting; returns the new x.
static func step_toward(x: float, target: float, step: float) -> float:
	var d := target - x
	if absf(d) <= step:
		return target
	return x + signf(d) * step
