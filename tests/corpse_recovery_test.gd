extends Node

# Player-corpse recovery (STORE_DESIGN step 7): a dead character's wallet notes + items are
# recorded at the death spot and the NEXT character can loot the body. This locks the data +
# recovery logic: record on death, survive advance_run (cross-run) + save/load, correct
# floor/scene/apartment matching, notes-to-wallet + item restore with durability preserved,
# partial recovery (leftover stays for a return trip), and the interactable spawns/dedupes.
# Run: godot --headless res://tests/corpse_recovery_test.tscn

const BUILDING := "res://scenes/building_floors.tscn"
var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== player-corpse recovery test ===")
	_test_record_and_survive_run()
	_test_matching()
	_test_recover_credits_and_restores()
	_test_partial_recovery()
	_test_save_load_roundtrip()
	await _test_spawn_node()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _fresh_character_with_loot() -> void:
	WorldState.new_game()
	WorldState.wallet_unlocked = true
	WorldState.wallet_balance = 120
	WorldState.current_run = 1
	WorldState.current_floor = 12
	WorldState.current_apartment_id = ""
	WorldState.inventory.clear()
	WorldState.add_to_inventory("002")           # Hammer (weapon w/ durability)
	WorldState.add_to_inventory("006")           # Bandages (consumable)
	# Give the hammer a partial durability so we can prove it's preserved on recovery.
	WorldState.inventory[0].current_durability = 3


func _test_record_and_survive_run() -> void:
	print("[record on death, survive the time skip]")
	_fresh_character_with_loot()
	WorldState.record_player_corpse(12, BUILDING, "", Vector2(640, 400))
	check(WorldState.player_corpses.has("1"), "corpse recorded under the dead run's key")
	var rec = WorldState.player_corpses["1"]
	check(int(rec["notes"]) == 120, "notes captured from the wallet (120)")
	check(rec["items"].size() == 2, "both carried items captured")
	# The time skip wipes the character but must KEEP the corpse (cross-run).
	var arc_over = WorldState.advance_run()
	check(not arc_over, "advance to run 2 (arc not over)")
	check(WorldState.player_corpses.has("1"), "corpse SURVIVES advance_run (cross-run)")
	check(WorldState.wallet_balance == 0 and WorldState.inventory.is_empty(),
		"the new character starts broke and empty")


func _test_matching() -> void:
	print("[floor / scene / apartment matching]")
	# (state carries from the previous test: a run-1 corpse on floor 12, corridor.)
	check(not WorldState.get_player_corpse_for(12, BUILDING, "").is_empty(), "found on the right floor+scene")
	check(WorldState.get_player_corpse_for(11, BUILDING, "").is_empty(), "not found on a different floor")
	check(WorldState.get_player_corpse_for(12, "res://scenes/room.tscn", "").is_empty(),
		"not found in a different scene")
	check(WorldState.get_player_corpse_for(12, BUILDING, "05").is_empty(),
		"a corridor corpse does not match an apartment query")


func _test_recover_credits_and_restores() -> void:
	print("[recover: notes -> wallet, items -> inventory, durability kept]")
	WorldState.wallet_balance = 0
	WorldState.inventory.clear()
	var summary = WorldState.recover_player_corpse("1")
	check(int(summary["notes"]) == 120, "summary reports the recovered notes")
	check(int(summary["items_taken"]) == 2, "both items recovered")
	check(WorldState.wallet_balance == 120, "notes credited to the wallet")
	check(WorldState.inventory.size() == 2, "items back in inventory")
	var hammer = null
	for it in WorldState.inventory:
		if it.item_id == "002":
			hammer = it
	check(hammer != null and hammer.current_durability == 3, "recovered hammer keeps its saved durability (3)")
	check(not WorldState.player_corpses.has("1"), "emptied body clears its record")


func _test_partial_recovery() -> void:
	print("[partial: leftover items stay on the body for a return trip]")
	WorldState.new_game()
	WorldState.wallet_unlocked = true
	WorldState.current_run = 2
	WorldState.current_floor = 8
	# A corpse holding 3 items.
	WorldState.player_corpses["1"] = {
		"floor": 8, "scene": BUILDING, "apartment_id": "", "x": 500, "y": 400,
		"notes": 40,
		"items": [
			{"item_id": "006", "current_durability": 0, "is_depleted": false, "target_apartment": "", "count": 1, "mag_count": 0, "is_damaged": false},
			{"item_id": "007", "current_durability": 0, "is_depleted": false, "target_apartment": "", "count": 1, "mag_count": 0, "is_damaged": false},
			{"item_id": "009", "current_durability": 0, "is_depleted": false, "target_apartment": "", "count": 1, "mag_count": 0, "is_damaged": false},
		],
	}
	# Pre-fill inventory so only ONE slot is free (5 slots default; fill 4).
	WorldState.inventory.clear()
	for id in ["002", "006", "007", "009"]:
		WorldState.add_to_inventory(id)
	var summary = WorldState.recover_player_corpse("1")
	check(int(summary["notes"]) == 40, "notes still fully credited (they never need a slot)")
	check(int(summary["items_taken"]) == 1, "only the one that fit was taken")
	check(int(summary["items_left"]) == 2, "the rest stay on the body")
	check(WorldState.player_corpses.has("1"), "partly-looted body is NOT cleared")
	check(int(WorldState.player_corpses["1"]["notes"]) == 0, "but its notes are spent")


func _test_save_load_roundtrip() -> void:
	print("[save / load round-trip]")
	WorldState.new_game()
	WorldState.player_corpses["2"] = {
		"floor": 15, "scene": BUILDING, "apartment_id": "", "x": 700, "y": 400,
		"notes": 55, "items": [],
	}
	WorldState.save_game(BUILDING, false)
	WorldState.player_corpses.clear()
	WorldState.load_game()
	check(WorldState.player_corpses.has("2"), "corpse restored from save")
	check(int(WorldState.player_corpses["2"]["notes"]) == 55, "its notes survived the round-trip")
	WorldState.delete_save()


func _test_spawn_node() -> void:
	print("[the interactable body spawns + dedupes]")
	WorldState.new_game()
	WorldState.player_corpses["1"] = {
		"floor": 9, "scene": BUILDING, "apartment_id": "", "x": 555, "y": 410,
		"notes": 10, "items": [],
	}
	var parent := Node2D.new()
	add_child(parent)
	WorldState.spawn_player_corpse_into(parent, 9, BUILDING, "")
	await get_tree().process_frame
	var bodies = get_tree().get_nodes_in_group("player_corpse")
	check(bodies.size() == 1, "a corpse body was placed")
	check(bodies.size() > 0 and str(bodies[0].corpse_key) == "1", "the body carries the record key")
	# Idempotent — a second spawn (passive backdrop + go_live) must not double it.
	WorldState.spawn_player_corpse_into(parent, 9, BUILDING, "")
	await get_tree().process_frame
	check(get_tree().get_nodes_in_group("player_corpse").size() == 1, "a second spawn does not duplicate the body")
	parent.queue_free()
	await get_tree().process_frame
