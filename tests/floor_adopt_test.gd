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
	# Hermetic: pin first-run so procedural floor content doesn't depend on a
	# tutorial-completed profile another suite test left on disk (new_game()
	# derives is_first_run from this and never reloads it).
	WorldState.tutorial_completed = false
	WorldState.is_first_run = true
	await _test_rehome_lands_at_origin()
	await _test_go_live_wakes_everything()
	await _test_go_live_spawns_fire()
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


func _test_go_live_spawns_fire() -> void:
	# The seamless stair PAN builds the destination as a PASSIVE backdrop, which skips
	# every live hazard, then promotes it with go_live(). go_live MUST spawn the fire
	# (it used to not — arriving via stairs left a fire floor with no fire, while an
	# apartment round-trip via the fade path was fine). Force a fire floor and prove
	# the woken backdrop carries a fire field.
	print("[go_live spawns the fire on a fire floor]")
	WorldState.new_game()
	var f := 24
	WorldState.dev_hazard_mode = WorldState.DEV_HAZARD_FIRE   # force a fire floor for the test
	WorldState.dev_fire_origin = f                            # single origin on this floor
	chk(WorldState.is_stair_fire(f), "test floor is on fire")
	var backdrop = load("res://scenes/building_floors.tscn").instantiate()
	backdrop.setup_floor = f
	backdrop.passive = true
	add_child(backdrop)
	for i in range(3): await get_tree().process_frame
	# The passive backdrop now spawns the fire too, so a floor panned UP toward shows
	# its fire as it scrolls in (not popping in after the commit).
	var fires_before := 0
	for n in get_tree().get_nodes_in_group("fire_field"):
		if backdrop.is_ancestor_of(n):
			fires_before += 1
	chk(fires_before == 1, "passive backdrop already shows the fire (pan buffer) (%d)" % fires_before)
	backdrop.go_live()
	await get_tree().process_frame
	var fires_after := 0
	for n in get_tree().get_nodes_in_group("fire_field"):
		if backdrop.is_ancestor_of(n):
			fires_after += 1
	chk(fires_after == 1, "go_live keeps exactly one fire — no double-spawn (%d)" % fires_after)
	backdrop.free()
	await get_tree().process_frame
	WorldState.dev_hazard_mode = WorldState.DEV_HAZARD_NONE
	WorldState.dev_fire_origin = -1


func _test_go_live_wakes_everything() -> void:
	print("[go_live restores a fully live floor]")
	WorldState.new_game()
	var f := _floor_with_zombies(25)
	if not (f in WorldState.MERCHANT_FLOORS):
		f = 25   # 25 both has a merchant and (usually) zombies; fall here for the merchant check
	WorldState.current_floor = (f + 3) % 29 + 1
	WorldState.stair_spawn_side = "left"
	WorldState.stair_direction = "down"
	# A merchant shelters from fire on its floor, so a seed that puts the woken
	# merchant floor on fire would (correctly) skip the merchant. This test is
	# about the wake, not fire — make sure f isn't burning so the merchant spawns.
	if WorldState.is_stair_fire(f):
		WorldState.mark_fire_dealt_with(f)
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
