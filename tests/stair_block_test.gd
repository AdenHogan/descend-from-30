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
	WorldState.cross_blocked_stair(target)
	check(WorldState.is_stair_block_cleared(target), "crossing clears the stairwell for the run")
	check(not WorldState.is_stair_blocked(target), "crossed stairwell is no longer blocked")
	check(not WorldState.rest_available, "crossing forfeits the next rest (costs a rest slot)")
	check(WorldState.master_seed != seed_before, "crossing shifts the building (enemies move)")
	check(WorldState.pending_pry_arrival_floor == target - 1, "arrival floor is flagged for milling")


func _test_save_load() -> void:
	print("[save/load]")
	WorldState.new_game()
	WorldState.current_run = 1
	WorldState.stair_blocks_cleared.clear()
	WorldState.clear_stair_block(7)
	WorldState.save_game("res://scenes/building_floors.tscn")
	# Wipe the in-memory copy, then reload and confirm it came back.
	WorldState.stair_blocks_cleared.clear()
	check(not WorldState.is_stair_block_cleared(7), "in-memory clear wiped")
	WorldState.load_game()
	check(WorldState.is_stair_block_cleared(7), "stair_blocks_cleared survives save/load")
	WorldState.delete_save()
