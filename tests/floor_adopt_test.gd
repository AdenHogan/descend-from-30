extends Node

# THE FLUID HAND-OFF (StairPan adoption). Instead of reloading the destination
# floor at the end of a stair pan — the jarring cut — the backdrop that was
# already built is promoted to the live floor: re-homed to origin, then woken by
# building_floors.go_live(). Headless can't see the pan, but it CAN prove the two
# risky halves: (1) the re-home lands the floor exactly where a freshly loaded
# one sits, and (2) go_live restores a dormant backdrop to a genuinely live floor
# (collision, triggers, live zombies, merchant) — nothing left inert.
# Run:  godot --headless res://tests/floor_adopt_test.tscn

var fails := 0

func chk(c: bool, m: String) -> void:
	print(("  PASS  " if c else "  FAIL  ") + m)
	if not c:
		fails += 1


func _floor_with_zombies(fallback: int) -> int:
	for f in range(1, 30):
		if WorldState.get_floor_zombie_count(f) > 0:
			return f
	return fallback


func _ready() -> void:
	print("=== floor adoption / go_live ===")
	await _test_rehome_lands_at_origin()
	await _test_go_live_wakes_everything()
	await _test_prefetch_buffer()
	print("=== %s (%d failures) ===" % ["ALL PASSED" if fails == 0 else "FAILED", fails])
	get_tree().quit(1 if fails > 0 else 0)


func _test_rehome_lands_at_origin() -> void:
	# A live floor's tilemap sits at a fixed design Y. A backdrop built one floor
	# offset, then re-homed the way _adopt does (reparent out + shift by
	# -floor_offset), must land its tilemap on that SAME Y — otherwise the world
	# jumps on arrival or drifts over repeated trips.
	print("[re-home to the design origin]")
	WorldState.new_game()
	WorldState.current_floor = 25

	var live = load("res://scenes/building_floors.tscn").instantiate()
	live.setup_floor = 24
	add_child(live)
	for i in range(3): await get_tree().process_frame
	var live_tm_y: float = live.get_node("TileMapLayer").global_position.y
	live.free()
	await get_tree().process_frame

	# Build like the pan: backdrop under a holder offset one floor down.
	var floor_offset := 192.0
	var holder := Node2D.new()
	add_child(holder)
	var backdrop = load("res://scenes/building_floors.tscn").instantiate()
	backdrop.setup_floor = 24
	backdrop.passive = true
	holder.add_child(backdrop)
	holder.position = Vector2(0, floor_offset)
	for i in range(3): await get_tree().process_frame
	chk(absf(backdrop.get_node("TileMapLayer").global_position.y - (live_tm_y + floor_offset)) < 0.5,
		"backdrop sits one floor off before re-home")

	# _adopt's re-home: reparent out of the holder (keeps global), shift by -offset.
	backdrop.reparent(self)
	backdrop.position += Vector2(0, -floor_offset)
	await get_tree().process_frame
	chk(absf(backdrop.get_node("TileMapLayer").global_position.y - live_tm_y) < 0.5,
		"re-homed tilemap lands exactly where a live floor's does (%.1f)"
			% backdrop.get_node("TileMapLayer").global_position.y)
	backdrop.free()
	holder.free()
	await get_tree().process_frame


func _test_go_live_wakes_everything() -> void:
	print("[go_live restores a fully live floor]")
	WorldState.new_game()
	var f := _floor_with_zombies(25)
	if not (f in WorldState.MERCHANT_FLOORS):
		f = 25   # 25 both has a merchant and (usually) zombies; fall here for the merchant check
	WorldState.current_floor = (f + 3) % 29 + 1
	WorldState.stair_spawn_side = "left"
	WorldState.stair_direction = "down"
	WorldState.seed_floor_door_states(f)

	# A live reference for what "awake" collision looks like on a door.
	var live = load("res://scenes/building_floors.tscn").instantiate()
	live.setup_floor = f
	add_child(live)
	for i in range(3): await get_tree().process_frame
	var live_layer: int = live.get_node("apartment01").collision_layer
	live.free()
	await get_tree().process_frame

	var backdrop = load("res://scenes/building_floors.tscn").instantiate()
	backdrop.setup_floor = f
	backdrop.passive = true
	add_child(backdrop)
	for i in range(3): await get_tree().process_frame

	# Dormant: the passive build stripped collision to 0 and recorded it.
	var door = backdrop.get_node("apartment01")
	chk(door.collision_layer == 0, "backdrop door starts inert (collision 0)")
	chk(backdrop._dormant.size() > 0, "dormant state was recorded for restore (%d)" % backdrop._dormant.size())

	backdrop.go_live()
	await get_tree().process_frame

	chk(not backdrop.passive, "floor is no longer passive")
	chk(backdrop._dormant.is_empty(), "dormant record consumed on wake")
	chk(door.collision_layer == live_layer,
		"door collision restored to the live value (%d vs %d)" % [door.collision_layer, live_layer])

	# Scenery zombies became real: AI back on, scenery tag gone, collision restored.
	var still_scenery := get_tree().get_nodes_in_group("pan_scenery").size()
	chk(still_scenery == 0, "no zombie left tagged as scenery (%d)" % still_scenery)
	var woke := 0
	for z in get_tree().get_nodes_in_group("zombie"):
		if backdrop.is_ancestor_of(z) and z.is_physics_processing() and z.collision_layer != 0:
			woke += 1
	chk(woke > 0, "backdrop zombies have AI + collision back (%d)" % woke)

	# Merchant floor: the merchant the passive build skipped is now present.
	chk(backdrop.get_node_or_null("Merchant") != null,
		"merchant spawned on a merchant floor during wake")

	# Stair triggers: arriving left-going-down, the left-DOWN return trigger is off
	# (it would send you straight back), the far side carries on.
	var ld = backdrop.get_node("stair_left_down_trigger")
	var lu = backdrop.get_node("stair_left_up_trigger")
	chk(ld.process_mode == Node.PROCESS_MODE_DISABLED, "arrival-side return trigger disabled")
	chk(lu.process_mode == Node.PROCESS_MODE_ALWAYS, "the way onward is live")

	backdrop.free()
	await get_tree().process_frame


func _test_prefetch_buffer() -> void:
	# Building the neighbour on stairwell approach, discarding it on turn-back, and
	# rebuilding when the player switches direction — so at most one is ever held.
	print("[prefetch buffer]")
	WorldState.new_game()
	WorldState.current_floor = 20
	# can_pan() only fires from a real floor scene, so stand one in as current.
	var host = load("res://scenes/building_floors.tscn").instantiate()
	host.setup_floor = 20
	get_tree().root.add_child(host)
	var prev_scene = get_tree().current_scene
	get_tree().current_scene = host
	for i in range(3): await get_tree().process_frame

	StairPan.prefetch(19, true)
	chk(StairPan._pf_backdrop != null and StairPan._pf_floor == 19 and StairPan._pf_down,
		"approach buffers the floor below")
	var first = StairPan._pf_backdrop
	StairPan.prefetch(19, true)
	chk(StairPan._pf_backdrop == first, "same target does not rebuild")

	StairPan.prefetch(21, false)
	await get_tree().process_frame
	chk(StairPan._pf_floor == 21 and StairPan._pf_backdrop != first, "switching direction rebuilds")
	chk(not is_instance_valid(first), "the old buffer is freed on switch (never hold two)")

	StairPan.discard_prefetch()
	chk(StairPan._pf_backdrop == null and StairPan._pf_holder == null, "turn-back discards the buffer")

	get_tree().current_scene = prev_scene
	host.queue_free()
	await get_tree().process_frame
