extends Node2D

const SPAWN_LEFT_TOP = Vector2(148, 391)
const SPAWN_LEFT_BOTTOM = Vector2(188, 391)
const SPAWN_RIGHT_TOP = Vector2(1201, 391)
const SPAWN_RIGHT_BOTTOM = Vector2(1162, 391)

# Stair-pan support: a building_floors can be built as a PASSIVE backdrop for a
# specific floor — no player, enemies, corpses, drops, or merchant — so the
# seamless pan (StairPan) can show the adjacent floor beside the live one. Set
# these BEFORE add_child(). setup_floor -1 = use WorldState.current_floor.
var setup_floor: int = -1
var passive: bool = false

# Where a zombie actually RESTS after move_and_slide resolves its spawn overlap
# with the floor (spawn y is 388; recovery lifts it to ~370). Scenery zombies on
# a pan backdrop have no physics step, so they must be placed here directly or
# they sit sunk in the floor and warp upward on arrival.
const ZOMBIE_SETTLED_Y := 370.0


func _ready() -> void:
	var floor_num = setup_floor if setup_floor >= 0 else WorldState.current_floor
	var player = get_node("Player")

	# Strip the junk row(s) above the ceiling so a floor is exactly its solid
	# content — floors then stack flush and the camera can frame one exactly.
	_strip_junk()

	# A passive backdrop instance carries no live PLAYER, but it DOES show the
	# floor's enemies: during a stair pan the player must see what's waiting on
	# the next floor as it scrolls into view, instead of it materialising out of
	# thin air the instant the floor commits. They're seeded identically to the
	# live spawn, so the same zombies stay in the same places across the commit.
	if passive:
		player.queue_free()
		player = null
		_apply_doors(floor_num)
		_apply_stair_visuals()
		_spawn_zombies(floor_num, true)
		_spawn_corpses(floor_num)
		_spawn_world_drops(floor_num)
		_make_inert()
		return

	var hallway_staircase_left = get_node("HallwayStaircaseLeft")
	var lobby_left = get_node("LobbyLeft")
	var hallway_staircase_right = get_node("HallwayStaircaseRight")
	var lobby_right = get_node("LobbyRight")
	var left_down = get_node("stair_left_down_trigger")
	var left_up = get_node("stair_left_up_trigger")
	var right_down = get_node("stair_right_down_trigger")
	var right_up = get_node("stair_right_up_trigger")

	if WorldState.spawn_source == "stair":
		if WorldState.stair_spawn_side == "left":
			if WorldState.stair_direction == "down":
				player.global_position = SPAWN_LEFT_BOTTOM
			elif WorldState.stair_direction == "up":
				player.global_position = SPAWN_LEFT_TOP
		elif WorldState.stair_spawn_side == "right":
			if WorldState.stair_direction == "down":
				player.global_position = SPAWN_RIGHT_BOTTOM
			elif WorldState.stair_direction == "up":
				player.global_position = SPAWN_RIGHT_TOP
	elif WorldState.spawn_source == "door" and WorldState.exit_spawn_x != 0.0:
		player.global_position.x = WorldState.exit_spawn_x
		player.global_position.y = 388.0

	if WorldState.saved_player_x != 0.0:
		player.global_position = Vector2(WorldState.saved_player_x, WorldState.saved_player_y)
		WorldState.saved_player_x = 0.0
		WorldState.saved_player_y = 0.0

	_apply_stair_visuals()

	if WorldState.stair_spawn_side == "left":
		if WorldState.stair_direction == "down":
			left_down.process_mode = Node.PROCESS_MODE_DISABLED
			left_up.process_mode = Node.PROCESS_MODE_ALWAYS
			right_down.process_mode = Node.PROCESS_MODE_ALWAYS
			right_up.process_mode = Node.PROCESS_MODE_DISABLED
		else:
			left_up.process_mode = Node.PROCESS_MODE_DISABLED
			left_down.process_mode = Node.PROCESS_MODE_ALWAYS
			right_up.process_mode = Node.PROCESS_MODE_ALWAYS
			right_down.process_mode = Node.PROCESS_MODE_DISABLED
	elif WorldState.stair_spawn_side == "right":
		if WorldState.stair_direction == "down":
			right_down.process_mode = Node.PROCESS_MODE_DISABLED
			right_up.process_mode = Node.PROCESS_MODE_ALWAYS
			left_down.process_mode = Node.PROCESS_MODE_ALWAYS
			left_up.process_mode = Node.PROCESS_MODE_DISABLED
		else:
			right_up.process_mode = Node.PROCESS_MODE_DISABLED
			right_down.process_mode = Node.PROCESS_MODE_ALWAYS
			left_up.process_mode = Node.PROCESS_MODE_ALWAYS
			left_down.process_mode = Node.PROCESS_MODE_DISABLED

	# Assign apartment IDs and apply correct door states AFTER IDs are set
	_apply_doors(floor_num)

	_spawn_zombies(floor_num, false)
	_spawn_corpses(floor_num)
	_spawn_world_drops(floor_num)
	_spawn_merchant(floor_num)
	_frame_camera(player)


func _frame_camera(player: Node) -> void:
	# Lock the view to the floor itself (see StairPan.apply_floor_camera): the
	# camera stops at the end walls instead of drifting past them into grey.
	if player == null:
		return
	var cam = player.get_node_or_null("Camera2D")
	var tm = get_node_or_null("TileMapLayer")
	if cam == null or tm == null:
		return
	StairPan.apply_floor_camera(cam, StairPan.floor_band(tm))

func _apply_stair_visuals() -> void:
	# WHICH staircase art each side shows.
	#
	# Art meaning (from where each is used): Lobby_* is the UP stairwell — the
	# lobby is the bottom of the building and can only go up. Hallway_Staircase_*
	# is the DOWN stairwell — floor 30 is the top and can only go down.
	#
	# The rule mirrors the stair TRIGGERS enabled in _ready: the side you arrived
	# on offers the way BACK (you came down it, so from here it goes up), and the
	# far side continues your journey. Exactly one side is up and one is down, so
	# the descent zig-zags across the corridor.
	#
	# The old version ignored stair_direction for left arrivals, so the left was
	# always drawn as an up-staircase — floor 25 and 26 showed the same art, and
	# a side whose trigger said "up" could be drawn descending.
	var hl := get_node_or_null("HallwayStaircaseLeft") as Sprite2D
	var ll := get_node_or_null("LobbyLeft") as Sprite2D
	var hr := get_node_or_null("HallwayStaircaseRight") as Sprite2D
	var lr := get_node_or_null("LobbyRight") as Sprite2D
	if hl == null or ll == null or hr == null or lr == null:
		return
	var came_down: bool = WorldState.stair_direction == "down"
	var arrived_left: bool = WorldState.stair_spawn_side != "right"
	# Arrival side goes back the way you came; the other side carries on.
	var left_goes_up: bool = came_down if arrived_left else not came_down
	var right_goes_up: bool = not left_goes_up

	ll.visible = left_goes_up          # Lobby_Left  = UP
	hl.visible = not left_goes_up      # Hallway_Staircase_Left = DOWN
	lr.visible = right_goes_up
	hr.visible = not right_goes_up

	# NOTE: there is no front-layer occluder here, and adding one back is a
	# mistake. See _apply_stair_visuals's history / docs/STAIRWELL_LAYERS.md:
	# re-cutting the top of the staircase art and drawing it at z 2 draws the
	# DARK SHAFT over the corridor as a black box. The shredder hides the player,
	# not an occluder.


func _spawn_zombies(floor_num: int, as_scenery: bool) -> void:
	# Same seed either way, so a backdrop's zombies and the committed floor's
	# zombies are the SAME zombies in the same places — that's what makes them
	# scroll into view during the pan rather than pop in on arrival.
	var floor_rng = RandomNumberGenerator.new()
	floor_rng.seed = (WorldState.master_seed ^ (floor_num * 2246822519)) & 0xFFFFFFFF
	var zombie_count = WorldState.get_floor_zombie_count(floor_num)
	var zombie_scene = preload("res://scenes/enemy_zombie_standard.tscn")
	# Keep clear of both stairwells (the corridor runs 115..1235): a zombie spawned
	# behind the stair art was effectively invisible until it moved.
	var positions = WorldState.get_zombie_positions(zombie_count, floor_rng, 265.0, 1105.0, 388.0)
	for pos in positions:
		var key = str(floor_num) + ":" + str(snappedf(pos.x, 1.0)) + ":" + str(snappedf(pos.y, 1.0))
		if WorldState.killed_zombies.has(key):
			continue
		var zombie = zombie_scene.instantiate()
		zombie.global_position = pos
		zombie.spawn_key = key
		if as_scenery:
			zombie.add_to_group("pan_scenery")
		add_child(zombie)
		# Living-enemy memory: a zombie met before comes back exactly where it was
		# left — facing, health and alert too — instead of its seeded spawn. Only
		# when it has NO memory does the scenery-settle below apply.
		var restored = WorldState.apply_saved_zombie(zombie)
		if as_scenery:
			# A live zombie spawns overlapping the floor and move_and_slide lifts
			# it to rest; a scenery zombie has no physics step, so it would stay
			# sunk ~18px and then visibly WARP up the moment the floor commits.
			# Place a FRESH one where the live one ends up (guarded by
			# building_floors_test); a restored one already carries a settled Y.
			if not restored:
				zombie.global_position.y = ZOMBIE_SETTLED_Y
			# Visible, but no AI and no noise — it must not hunt the player, who
			# is still a whole floor away. Disabled AFTER add_child so the
			# zombie's own _ready can't turn its physics step back on.
			# _make_inert() strips its collision separately.
			zombie.set_physics_process(false)


func _strip_junk() -> void:
	var tm = get_node_or_null("TileMapLayer")
	if tm != null:
		StairPan.strip_junk_rows(tm)


func _make_inert() -> void:
	# A stacked neighbour floor is SCENERY. Once it's offset into real world space
	# its collision bodies and Area2D triggers would otherwise block/teleport the
	# player on the live floor, so strip all physics + interaction from it and
	# leave only what's drawn.
	_disable_physics_recursive(self)


func _disable_physics_recursive(node: Node) -> void:
	if node is CollisionObject2D:
		# Off every layer/mask: no blocking, no overlaps, no input picking.
		node.collision_layer = 0
		node.collision_mask = 0
		if node is Area2D:
			node.monitoring = false
			node.monitorable = false
		node.input_pickable = false
		# Scenery zombies keep processing so their idle animation still plays as
		# they scroll into view (their AI is already off via set_physics_process).
		if not node.is_in_group("pan_scenery"):
			node.process_mode = Node.PROCESS_MODE_DISABLED
	for child in node.get_children():
		_disable_physics_recursive(child)


func _apply_doors(floor_num: int) -> void:
	for i in range(1, 6):
		var door = get_node_or_null("apartment0" + str(i))
		if door:
			door.apartment_id = str(floor_num) + "0" + str(i)
			door._apply_door_state()


func _spawn_merchant(floor_num: int) -> void:
	if floor_num not in WorldState.MERCHANT_FLOORS:
		return
	# The merchant scene renders its own elevator (interior + sliding doors),
	# so the hallway's static Elevator sprite is hidden on merchant floors.
	var static_elevator = get_node_or_null("Elevator")
	if static_elevator:
		static_elevator.visible = false
	var merchant = preload("res://scenes/merchant.tscn").instantiate()
	merchant.global_position = Vector2(1029.4999, 356.50003)
	add_child(merchant)

func _spawn_world_drops(floor_num: int) -> void:
	var scene_path = get_tree().current_scene.scene_file_path
	var drops = WorldState.get_world_drops_for_floor(floor_num, scene_path)
	if drops.is_empty():
		return
	var drop_scene = preload("res://scenes/world_drop.tscn")
	for drop_key in drops:
		var data = drops[drop_key]
		var drop = drop_scene.instantiate()
		drop.item_id = data["item_id"]
		drop.amount = int(data.get("amount", 0))
		drop.drop_key = drop_key
		drop.target_apartment = data.get("target_apartment", "")
		drop.global_position = Vector2(data["x"], data["y"])
		add_child(drop)

func _spawn_corpses(floor_num: int) -> void:
	var scene_path = get_tree().current_scene.scene_file_path
	var corpse_positions = WorldState.get_corpse_positions_for_floor(floor_num, scene_path)
	if corpse_positions.is_empty():
		return
	# Corpse visuals are type-aware: standard zombies have a looping "Dead_Dead"
	# frame; the big zombie has no Dead_Dead, so its corpse shows the final frame
	# of its "Death" animation, paused.
	var std_instance = preload("res://scenes/enemy_zombie_standard.tscn").instantiate()
	var std_frames = std_instance.get_node("AnimatedSprite2D").sprite_frames
	std_instance.queue_free()
	var big_instance = preload("res://scenes/enemy_zombie_big.tscn").instantiate()
	var big_frames = big_instance.get_node("AnimatedSprite2D").sprite_frames
	big_instance.queue_free()
	for entry in corpse_positions:
		var corpse = AnimatedSprite2D.new()
		corpse.scale = Vector2(3, 3)
		if entry["type"] == "big":
			corpse.sprite_frames = big_frames
			corpse.animation = "Death"
			corpse.frame = big_frames.get_frame_count("Death") - 1
		else:
			corpse.sprite_frames = std_frames
			corpse.animation = "Dead_Dead"
			corpse.autoplay = "Dead_Dead"
		corpse.global_position = entry["pos"]
		corpse.z_index = 0
		add_child(corpse)
