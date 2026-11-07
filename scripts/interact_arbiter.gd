class_name InteractArbiter
extends RefCounted

# ONE rule for "who answers this [interact] press" (round 49n, owner: "fix the other interact overlaps too").
#
# The press is read by every node that can answer it, each in its own _process, and until now each decided alone — so two things whose
# reaches overlapped BOTH answered: floor 15's shop + staff door (round 44), the merchant's shop + the last character's body (round 49n,
# the bot's two 150 s timeouts), a flat door + a body beside it, and the pairs nobody had hit yet (a body + a loose drop, a corridor body + a
# fallen character, the floor-30 backpack + a body, the lobby door + a body, a survivor's [Talk] + any of them, a scavenge node + a drop).
# The fixes were pairwise (`door._other_is_nearer`, `merchant._maintenance_door_is_nearer`, `survivor._door_answers_instead`…); this is the
# general rule they were all instances of:
#
#     of everything that would answer a press RIGHT NOW, the one nearest the player (by x) answers, and exactly one does.
#
# A member joins the group `GROUP` and implements three methods:
#     interact_ready() -> bool   would a press be taken by me right now (the player in my reach, my state allows it)?
#     interact_x() -> float      the world x of the thing the press would act on
#     interact_rank() -> int     the tie-break at equal distance (lower wins): RANK_*
# and asks `take(self)` where it used to read the bare press. `take` is true for the nearest member only, and only once a frame (a winner
# that frees itself mid-frame — a drop picked up — must not hand the same press to the next node processed). Ties: a survivor's [Talk]
# first, then a fallen character's body, then a door, then a lift, then everything else; equal on all of those, the older node.
# `beaten(self)` is the read-only form ("would another member answer instead?") the tests and the older helper names use.

const GROUP := "interact_answer"

const RANK_TALK := 0
const RANK_BODY := 1
const RANK_DOOR := 2
const RANK_LIFT := 3
const RANK_THING := 4

static var _taken_frame: int = -1


## The nearest ready member answers; true for `me` only (and only once a frame). `assume_ready` = `me` is the node a caller has already
## chosen (the Tab-selected scavenge node): its own readiness is not asked again.
static func take(me: Node, assume_ready: bool = false) -> bool:
	if not answers(me, assume_ready):
		return false
	var frame: int = Engine.get_process_frames()
	if _taken_frame == frame:
		return false
	_taken_frame = frame
	return true


## Would `me` be the one to answer right now? (Read-only: claims nothing.)
static func answers(me: Node, assume_ready: bool = false) -> bool:
	if me == null or not is_instance_valid(me):
		return false
	if WorldState.loot_open:
		return false                     # the loot panel is modal: its own [interact] takes the item, and nothing behind it answers too
	if _player_hidden(me):
		return false                     # a hidden player's [interact] brings them OUT (player.gd); it must not also open the door beside the wardrobe
	if not assume_ready and not _ready(me):
		return false
	return _better_than(me) == null


## Is there another member that would answer instead of `me`? (`me` need not be ready itself — the helper names the tests use.)
static func beaten(me: Node) -> bool:
	return me != null and is_instance_valid(me) and _better_than(me) != null


## A member that outranks `me`, or null. Only members of the SAME world compete (a floor, a flat, the hallway…: the nearest ancestor with a Player child), each
## measured from that world's own player — a stair pan's backdrop floor, or a floor left in the tree, is another world and never answers for this one.
static func _better_than(me: Node) -> Node:
	var tree: SceneTree = me.get_tree()
	if tree == null:
		return null
	var world: Node = _world(me)
	var p: Node = _player_of(world, tree)
	if p == null or not is_instance_valid(p):
		return null
	var px: float = p.global_position.x
	var mine := _key(me, px)
	for n in tree.get_nodes_in_group(GROUP):
		if n == me or not is_instance_valid(n) or n.is_queued_for_deletion() or not n.is_inside_tree():
			continue
		if _world(n) != world:
			continue
		if not _ready(n):
			continue
		if _less(_key(n, px), mine):
			return n
	return null


static func _player_hidden(me: Node) -> bool:
	var tree: SceneTree = me.get_tree()
	if tree == null:
		return false
	var pl: Node = _player_of(_world(me), tree)
	return pl != null and Stealth.conceal_of(pl) == Stealth.HIDDEN


## The world a node belongs to: itself or its nearest ancestor that carries the player (every floor, flat, hallway and lobby does); null for a node outside one.
static func _world(n: Node) -> Node:
	var a: Node = n
	while a != null:
		if a.has_node("Player"):
			return a
		a = a.get_parent()
	return null


## The world `n` belongs to (public form of `_world`, for the stealth spots: a hiding place only offers itself to the player of its OWN flat).
static func world_of(n: Node) -> Node:
	return _world(n)


static func _player_of(world: Node, tree: SceneTree) -> Node:
	if world != null:
		var wp: Node = world.get_node_or_null("Player")
		if wp != null:
			return wp
	return tree.get_first_node_in_group("player")


static func _ready(n: Node) -> bool:
	return n.has_method("interact_ready") and bool(n.call("interact_ready"))


## [distance, rank, instance id]
static func _key(n: Node, px: float) -> Array:
	var x: float = float(n.call("interact_x")) if n.has_method("interact_x") else n.global_position.x
	var rank: int = int(n.call("interact_rank")) if n.has_method("interact_rank") else RANK_THING
	return [absf(px - x), rank, n.get_instance_id()]


static func _less(a: Array, b: Array) -> bool:
	for i in range(3):
		if a[i] != b[i]:
			return a[i] < b[i]
	return false
