extends Node

# Headless test for the heavy-stairwell-horde data model + Crowbar item (035).
# Covers: item flags, seeded blocking (determinism + exemptions), clearing,
# per-run keying, crowbar has/consume, and save/load round-trip.
# Run:  godot --headless res://tests/stair_block_test.tscn

var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== stair-block / crowbar test ===")
	_test_crowbar_item()
	_test_block_seeding()
	_test_clearing()
	_test_per_run_keying()
	_test_crowbar_inventory()
	_test_shift_building()
	_test_crossing()
	_test_cross_floor_pull()
	_test_dev_force_hazards()
	_test_item_icons()
	_test_save_load()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _test_crowbar_item() -> void:
	print("[crowbar item]")
	var d = ItemData.get_item("035")
	check(not d.is_empty(), "item 035 exists")
	check(d.get("name", "") == "Crowbar", "035 is named Crowbar")
	check(d.get("is_crowbar", false), "035 has is_crowbar flag")
	check(d.get("is_tool", false), "035 is a tool")
	check(not d.get("is_weapon", false), "035 is NOT a weapon (tool only)")
	check(d.get("single_use", false), "035 is single use (consumed)")


func _test_block_seeding() -> void:
	print("[block seeding]")
	WorldState.master_seed = 1337
	WorldState.current_run = 1
	WorldState.stair_blocks_cleared.clear()
	# Deterministic: same floor/run/seed returns the same answer every call.
	var a = WorldState.is_stair_blocked(15)
	var b = WorldState.is_stair_blocked(15)
	check(a == b, "is_stair_blocked is deterministic per floor")
	# Exemptions: tutorial floor and the last step to the lobby never block.
	check(not WorldState.is_stair_blocked(30), "floor 30 (tutorial) never blocked")
	check(not WorldState.is_stair_blocked(1), "floor 1 (to lobby) never blocked")
	check(not WorldState.is_stair_blocked(0), "floor 0 never blocked")
	# The seed must actually produce SOME blocks across the run range, but never
	# block every floor (that would be unplayable).
	var blocked := 0
	for run in range(1, 4):
		WorldState.current_run = run
		for f in range(2, 30):
			if WorldState.is_stair_blocked(f):
				blocked += 1
	check(blocked > 0, "seed produces at least one blocked stairwell across runs")
	check(blocked < 28 * 3, "not every stairwell is blocked")
	WorldState.current_run = 1


func _test_clearing() -> void:
	print("[clearing]")
	WorldState.master_seed = 1337
	WorldState.current_run = 1
	WorldState.stair_blocks_cleared.clear()
	# Find a floor this seed actually blocks, then pry it open.
	var target := -1
	for f in range(2, 30):
		if WorldState.is_stair_blocked(f):
			target = f
			break
	check(target != -1, "found a blocked floor to clear")
	if target != -1:
		WorldState.clear_stair_block(target)
		check(WorldState.is_stair_block_cleared(target), "cleared flag is set")
		check(not WorldState.is_stair_blocked(target), "a cleared stairwell is no longer blocked")


func _test_per_run_keying() -> void:
	print("[per-run keying]")
	WorldState.stair_blocks_cleared.clear()
	WorldState.current_run = 1
	WorldState.clear_stair_block(12)
	check(WorldState.is_stair_block_cleared(12), "run 1: floor 12 reads cleared")
	WorldState.current_run = 2
	check(not WorldState.is_stair_block_cleared(12), "run 2: floor 12 is NOT cleared (per-run)")
	WorldState.current_run = 1


func _test_crowbar_inventory() -> void:
	print("[crowbar inventory]")
	WorldState.inventory.clear()
	check(not WorldState.has_crowbar(), "no crowbar when inventory empty")
	WorldState.add_to_inventory("002")   # a hammer, not a crowbar
	check(not WorldState.has_crowbar(), "hammer is not a crowbar")
	WorldState.add_to_inventory("035")
	check(WorldState.has_crowbar(), "has_crowbar true after picking one up")
	check(WorldState.consume_crowbar(), "consume_crowbar succeeds")
	check(not WorldState.has_crowbar(), "crowbar is gone after consumption")
	check(not WorldState.consume_crowbar(), "consume_crowbar fails with none left")
	WorldState.inventory.clear()


func _test_shift_building() -> void:
	print("[shift_building]")
	WorldState.master_seed = 4242
	WorldState.apartment_layouts["1501"] = ["kitchen", "bedroom", "study"]
	WorldState.anchor_items["1501:anchor_x"] = "005"
	WorldState.shift_building()
	check(WorldState.master_seed != 4242, "shift re-rolls the master seed")
	check(WorldState.apartment_layouts.is_empty(), "shift clears cached apartment layouts")
	check(WorldState.anchor_items.is_empty(), "shift clears cached anchor rolls")


func _test_crossing() -> void:
	print("[crossing]")
	WorldState.master_seed = 1337
	WorldState.current_run = 1
	WorldState.stair_blocks_cleared.clear()
	WorldState.rest_available = true
	WorldState.pending_pry_arrival_floor = -1
	# Find a floor this seed blocks, stand on it, and cross.
	var target := -1
	for f in range(2, 30):
		if WorldState.is_stair_blocked(f):
			target = f
			break
	check(target != -1, "found a blocked floor to cross")
	if target == -1:
		return
	var seed_before = WorldState.master_seed
	WorldState.current_floor = target
	# Branch 1: crossing WITH a banked rest burns it (and sets no forfeit).
	WorldState.rest_available = true
	WorldState.rest_forfeit_pending = false
	WorldState.cross_blocked_stair(target)
	check(WorldState.is_stair_block_cleared(target), "crossing clears the stairwell for the run")
	check(not WorldState.is_stair_blocked(target), "crossed stairwell is no longer blocked")
	check(not WorldState.rest_available, "crossing with a banked rest burns it")
	check(not WorldState.rest_forfeit_pending, "burning a banked rest sets no extra forfeit")
	check(WorldState.master_seed != seed_before, "crossing shifts the building (enemies move)")
	check(WorldState.pending_pry_arrival_floor == target - 1, "arrival floor is flagged for milling")

	# Branch 2: crossing with NO banked rest forfeits the next merchant rest.
	WorldState.rest_available = false
	WorldState.rest_forfeit_pending = false
	WorldState.cross_blocked_stair(target)
	check(not WorldState.rest_available, "crossing with no rest leaves rest unavailable")
	check(WorldState.rest_forfeit_pending, "crossing with no banked rest forfeits the next rest")

	# The forfeit is spent at the next merchant floor: that floor grants no rest.
	WorldState.rest_available = false
	WorldState.rest_forfeit_pending = true
	WorldState.on_floor_arrived(15)   # a merchant floor
	check(not WorldState.rest_available, "a forfeited merchant floor grants no rest")
	check(not WorldState.rest_forfeit_pending, "the forfeit is consumed at that floor")

	# Without a forfeit, a merchant floor grants a rest as normal.
	WorldState.rest_available = false
	WorldState.rest_forfeit_pending = false
	WorldState.on_floor_arrived(15)
	check(WorldState.rest_available, "a normal merchant floor grants a rest")


func _test_cross_floor_pull() -> void:
	print("[cross-floor pull]")
	WorldState.current_run = 1
	WorldState.current_floor = 15
	var stair_pos = Vector2(200.0, 388.0)     # by the LEFT stairwell
	var mid_pos = Vector2(680.0, 388.0)        # mid-corridor
	var gunshot = WorldState.NOISE_RADIUS["gunshot"]
	var run_noise = WorldState.NOISE_RADIUS["run"]

	# Loud + near a stairwell → both adjacent floors' stair-side dead are pulled.
	WorldState.pending_stair_pulls.clear()
	WorldState.note_cross_floor_pull(stair_pos, gunshot)
	check(WorldState.has_stair_pull(14), "gunshot by the stairs pulls the floor below")
	check(WorldState.has_stair_pull(16), "gunshot by the stairs pulls the floor above")
	check(not WorldState.has_stair_pull(15), "the current floor is not self-pulled")

	# Loud but mid-corridor → no cross-floor carry (can't vacuum a floor upstairs).
	WorldState.pending_stair_pulls.clear()
	WorldState.note_cross_floor_pull(mid_pos, gunshot)
	check(not WorldState.has_stair_pull(14), "a gunshot mid-corridor does NOT pull")

	# Near a stairwell but quiet (running) → no pull.
	WorldState.pending_stair_pulls.clear()
	WorldState.note_cross_floor_pull(stair_pos, run_noise)
	check(not WorldState.has_stair_pull(14), "running near the stairs does NOT pull")

	# Consuming clears it (one-shot).
	WorldState.pending_stair_pulls.clear()
	WorldState.note_cross_floor_pull(stair_pos, gunshot)
	WorldState.consume_stair_pull(14)
	check(not WorldState.has_stair_pull(14), "consuming a pull clears it")

	# A building shift wipes stale pulls.
	WorldState.pending_stair_pulls.clear()
	WorldState.note_cross_floor_pull(stair_pos, gunshot)
	WorldState.shift_building()
	check(not WorldState.has_stair_pull(14), "a building shift clears pending pulls")

	# Tutorial floor never seeds cross-floor hordes.
	WorldState.pending_stair_pulls.clear()
	WorldState.current_floor = 30
	WorldState.note_cross_floor_pull(stair_pos, gunshot)
	check(not WorldState.has_stair_pull(29), "noise on floor 30 (tutorial) does not pull")
	WorldState.current_floor = 15


func _test_dev_force_hazards() -> void:
	print("[dev: force hazards every floor]")
	WorldState.master_seed = 1337
	WorldState.current_run = 1
	WorldState.stair_blocks_cleared.clear()
	WorldState.dev_all_hazards = true
	# Every eligible floor is now blocked — testable in a vacuum.
	var all_blocked := true
	for f in range(2, 30):
		if not WorldState.is_stair_blocked(f):
			all_blocked = false
	check(all_blocked, "dev flag blocks every eligible floor (2..29)")
	# Exemptions still hold even with the dev flag on.
	check(not WorldState.is_stair_blocked(30), "dev flag still exempts floor 30")
	check(not WorldState.is_stair_blocked(1), "dev flag still exempts floor 1")
	# A cleared stairwell stays open even under the dev flag.
	WorldState.clear_stair_block(7)
	check(not WorldState.is_stair_blocked(7), "a cleared stairwell stays open under the dev flag")
	# Turning it off returns to seeded behaviour (not every floor blocked).
	WorldState.dev_all_hazards = false
	WorldState.stair_blocks_cleared.clear()
	var seeded_blocked := 0
	for f in range(2, 30):
		if WorldState.is_stair_blocked(f):
			seeded_blocked += 1
	check(seeded_blocked < 28, "flag off: back to seeded (not every floor)")
	# The flag also forces barricaded doors on newly-seeded floors.
	WorldState.dev_all_hazards = true
	WorldState.door_states.clear()
	WorldState.floor_states_seeded.clear()
	WorldState.seed_floor_door_states(18)
	var all_barricaded := true
	for i in range(1, 6):
		if WorldState.get_door_state("180" + str(i)) != WorldState.DoorState.BARRICADED_FORCEABLE:
			all_barricaded = false
	check(all_barricaded, "dev flag barricades every apartment on a seeded floor")
	# The tutorial floor keeps its hardcoded doors even under the dev flag.
	WorldState.door_states.clear()
	WorldState.floor_states_seeded.clear()
	WorldState.seed_floor_door_states(30)
	check(WorldState.get_door_state("3003") == WorldState.DoorState.OPEN,
		"dev flag does not override the tutorial floor's doors")

	# new_game clears the dev flag (session-only, like god_mode).
	WorldState.dev_all_hazards = true
	WorldState.new_game()
	check(not WorldState.dev_all_hazards, "new_game resets the dev hazard flag")
	WorldState.door_states.clear()
	WorldState.floor_states_seeded.clear()
	WorldState.master_seed = 1337
	WorldState.current_run = 1


func _test_item_icons() -> void:
	# The icon loader accepts both bare "<id>.png" and descriptive
	# "<id> - Name.png". Verified against files actually in the repo: 001.png
	# (bare) and "034 - Screwdriver.png" (descriptive). The Crowbar's
	# "035 - Crowbar.png" will resolve the same way once the art lands.
	print("[item icons]")
	check(ItemData.get_texture("001") != null, "bare-name icon (001.png) loads")
	check(ItemData.get_texture("034") != null, "descriptive icon (034 - Screwdriver.png) loads")
	check(ItemData.get_texture("035") != null, "crowbar icon (035 - Crowbar.png) loads")


func _test_save_load() -> void:
	print("[save/load]")
	WorldState.new_game()
	WorldState.current_run = 1
	WorldState.stair_blocks_cleared.clear()
	WorldState.clear_stair_block(7)
	WorldState.saved_on_balcony_plane = true
	WorldState.save_game("res://scenes/building_floors.tscn")
	# Wipe the in-memory copy, then reload and confirm it came back.
	WorldState.stair_blocks_cleared.clear()
	WorldState.saved_on_balcony_plane = false
	check(not WorldState.is_stair_block_cleared(7), "in-memory clear wiped")
	WorldState.load_game()
	check(WorldState.is_stair_block_cleared(7), "stair_blocks_cleared survives save/load")
	check(WorldState.saved_on_balcony_plane, "balcony-plane flag survives save/load")
	WorldState.delete_save()
