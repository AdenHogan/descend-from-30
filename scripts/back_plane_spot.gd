extends Node2D

# BACK (SCAVENGE) PLANE — a spot in front of SET-BACK furniture (the bookshelf, the chest of drawers)
# whose scavenge nodes sit against the back wall, out of reach from the walking line (owner round 9:
# "the player would be searching the bookshelf from what looks like rather far away").
#
# Near it in scavenge mode, W (or clicking one of its nodes) steps the player UP into the scene to
# stand at the furniture (player.enter_back_plane) — the same depth as a balcony plane, drawn a touch
# smaller. Up there only this spot's nodes are in reach; the player can search / take / leave each
# (Tab / wheel / click picks between them). Nothing sends you back down — S steps back to the
# walking line, just like leaving a balcony. It is NOT a movement plane: no walking left/right up
# here (clicking elsewhere steps you down first, then walks).
#
# room.gd builds one per cluster of flagged nodes (Marker2D metadata `back_plane = true`) that
# actually spawned this seed. Position = (the cluster's centre x, the plane's feet line), room-local.

const ARROW_FONT = preload("res://assets/fonts/PixelOperator8.ttf")
const REACH := 26.0            # how close (horizontally, beyond the cluster) W / the arrow work
const ARROW_BASE_Y := -70.0

var anchors: Array = []        # the scavenge nodes (interactables) this spot reaches
var rise: float = 25.0         # lane feet − plane feet: how far UP into the scene the step goes
var plane_scale: float = 0.88  # the player's sprite scale up here (same depth as a balcony plane)
var half_span: float = 0.0     # half the cluster's width

var _arrow: Label = null
var _t := 0.0


func setup(nodes: Array, step_rise: float, scale_up_here: float) -> void:
	anchors = nodes
	rise = step_rise
	plane_scale = scale_up_here
	var lo := INF
	var hi := -INF
	for a in anchors:
		lo = minf(lo, a.global_position.x)
		hi = maxf(hi, a.global_position.x)
		a.set("back_spot", self)
	half_span = (hi - lo) * 0.5 if lo <= hi else 0.0
	add_to_group("back_plane_spot")


func _ready() -> void:
	_arrow = Label.new()
	_arrow.text = "↑"
	_arrow.add_theme_font_override("font", ARROW_FONT)
	_arrow.add_theme_font_size_override("font_size", 24)
	_arrow.position = Vector2(-11, ARROW_BASE_Y)
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow.z_index = 1
	_arrow.visible = false
	add_child(_arrow)


func has_live_node() -> bool:
	# Worth stepping up to: at least one of its nodes still shows (not emptied + hidden).
	for a in anchors:
		if is_instance_valid(a) and a.visible:
			return true
	return false


func player_near(player: Node2D) -> bool:
	return absf(player.global_position.x - global_position.x) <= half_span + REACH


func _process(delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player == null or not (player is Node2D):
		return
	var can_offer: bool = WorldState.is_scavenge_mode and has_live_node() and player.get("back_spot") == null \
		and player.get("on_balcony_plane") != true and player.get("is_cutscene") != true and player_near(player)
	_arrow.visible = can_offer
	if not can_offer:
		return
	_t += delta
	_arrow.position.y = ARROW_BASE_Y - absf(sin(_t * 4.0)) * 6.0
	if Input.is_action_just_pressed("move_up") and player.has_method("enter_back_plane") and not WorldState.loot_open:
		player.enter_back_plane(self)
