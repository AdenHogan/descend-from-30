extends Node

# Cross-run memory / chronicle (owner: "connecting memory across the three runs"): each run
# records its character, fate, deepest floor (records + permanent-upgrade hook), the traces it
# left, and the thoughts collected about it. Recovering a body unlocks that character's memory
# and appends the finder's comment. This locks the data spine + persistence.
# Run: godot --headless res://tests/run_memory_test.tscn

var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== run memory / chronicle test ===")
	_test_character_and_depth()
	_test_traces()
	_test_outcome_and_advance()
	_test_recover_memory()
	_test_names()
	_test_journal_stats()
	await _test_stair_pan_arrival()
	await _test_endpoints_recorded()
	_test_save_load()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _test_character_and_depth() -> void:
	print("[character stamped + deepest floor tracked]")
	WorldState.new_game()
	# best_depth is a PERMANENT profile record (only ever lowers), so a prior playthrough/test
	# may have left it below 30 — reset it here so this test controls the record from a known top.
	WorldState.best_depth = 30
	check(WorldState.run_chronicle.size() == 3, "chronicle has three run slots")
	var e = WorldState.chronicle_entry(1)
	check(String(e["character"]) == WorldState.current_character(), "run 1 slot stamped with its character")
	check(int(e["deepest_floor"]) == 30, "deepest starts at the top (30)")
	WorldState.current_floor = 18
	WorldState.note_floor_reached(18)
	check(int(WorldState.chronicle_entry(1)["deepest_floor"]) == 18, "descending to 18 records it")
	check(WorldState.best_depth == 18, "best_depth record updated to 18")
	WorldState.note_floor_reached(25)          # going back UP must not un-deepen
	check(int(WorldState.chronicle_entry(1)["deepest_floor"]) == 18, "a shallower floor does not raise deepest")
	WorldState.note_floor_reached(10)
	check(WorldState.best_depth == 10, "a new record lowers best_depth to 10")


func _test_traces() -> void:
	print("[world traces recorded per run]")
	WorldState.new_game()
	WorldState.add_run_trace("a forced door on floor 12")
	WorldState.add_run_trace("a forced door on floor 12")   # dup
	WorldState.add_run_trace("a doused fire on floor 9")
	var traces: Array = WorldState.chronicle_entry(1)["traces"]
	check(traces.size() == 2, "duplicate traces are de-duped (2 kept)")
	check("a doused fire on floor 9" in traces, "the trace text is stored")


func _test_outcome_and_advance() -> void:
	print("[outcome mirrored + memory survives the time skip]")
	WorldState.new_game()
	WorldState.current_floor = 14
	WorldState.note_floor_reached(14)
	var run1_char = WorldState.current_character()
	WorldState.set_run_outcome(1, "dead")
	check(String(WorldState.chronicle_entry(1)["outcome"]) == "fell", "a death reads as 'fell' in the chronicle")
	var arc_over = WorldState.advance_run()
	check(not arc_over, "advanced to run 2")
	check(String(WorldState.chronicle_entry(1)["character"]) == run1_char, "run 1's character is remembered after the skip")
	check(int(WorldState.chronicle_entry(1)["deepest_floor"]) == 14, "run 1's depth is remembered after the skip")
	check(String(WorldState.chronicle_entry(2)["character"]) != "", "run 2's slot is stamped with the new character")


func _test_recover_memory() -> void:
	print("[recovering a body unlocks memory + leaves a thought]")
	WorldState.new_game()
	WorldState.current_floor = 20
	WorldState.note_floor_reached(20)
	WorldState.set_run_outcome(1, "dead")
	WorldState.advance_run()                    # now run 2, run 1 is a predecessor
	check(not bool(WorldState.chronicle_entry(1)["recovered"]), "predecessor starts un-recovered")
	var thought = WorldState.make_finder_thought(1)
	check(thought.length() > 0, "a finder thought is generated")
	WorldState.recover_run_memory(1, thought)
	check(bool(WorldState.chronicle_entry(1)["recovered"]), "recovering marks the memory unlocked")
	check(WorldState.chronicle_entry(1)["thoughts"].size() == 1, "the finder's comment is appended")
	WorldState.recover_run_memory(1, thought)   # same thought again
	check(WorldState.chronicle_entry(1)["thoughts"].size() == 1, "the same comment isn't duplicated")


func _test_names() -> void:
	print("[canonical character names]")
	check(WorldState.character_display_name("blond_man") == "The Tenant", "known id maps to its name")
	check(WorldState.character_display_name("someone_else").length() > 0, "unknown id falls back to a readable name")


func _test_journal_stats() -> void:
	print("[journal stats + map memory]")
	WorldState.new_game()
	check(WorldState.run_kills == 0 and WorldState.run_scavenged == 0, "fresh run starts with zero tallies")
	WorldState.note_kill(); WorldState.note_kill()
	WorldState.note_scavenge("1201")
	WorldState.note_scavenge("1201")            # same apartment again
	WorldState.note_scavenge("1503")
	check(WorldState.run_kills == 2, "kills counted (2)")
	check(WorldState.run_scavenged == 3, "scavenged items counted (3)")
	check(WorldState.run_apartments_looted.size() == 2, "distinct apartments looted (2)")
	check(WorldState.health_word() == "Healthy", "condition reads in words (Healthy at full health)")
	WorldState.player_health = 4
	check(WorldState.health_word() == "Severely Wounded", "condition tracks the health stage")
	# Map memory.
	WorldState.note_floor_visited(30)
	WorldState.note_floor_visited(18)
	WorldState.note_enemies_on_floor(18)
	check(WorldState.visited_floors.has("18") and not WorldState.visited_floors.has("5"),
		"map remembers visited floors only")
	check(WorldState.floors_enemy_seen.has("18"), "map remembers where enemies were seen")
	# Per-run tallies reset on the time skip; map memory persists across runs.
	WorldState.advance_run()
	check(WorldState.run_kills == 0 and WorldState.run_apartments_looted.is_empty(),
		"the next character's tallies reset")
	check(WorldState.visited_floors.has("18"), "map memory carries across the run (cross-run)")


func _test_stair_pan_arrival() -> void:
	# The MAIN way down is the stairs, which build the next floor as a passive backdrop and
	# promote it with go_live() — NOT the live _ready. Journal memory must record there too.
	print("[arriving by STAIRS (backdrop → go_live) records depth, map + sightings]")
	WorldState.new_game()
	WorldState.best_depth = 30
	WorldState.current_floor = 14
	WorldState.spawn_source = "stair"
	WorldState.stair_direction = "down"
	WorldState.stair_spawn_side = "left"
	WorldState.pending_pry_arrival_floor = -1
	WorldState.seed_floor_door_states(14)
	var bf = load("res://scenes/building_floors.tscn").instantiate()
	bf.setup_floor = 14
	bf.passive = true
	add_child(bf)
	for i in range(4):
		await get_tree().process_frame
	check(not WorldState.visited_floors.has("14"), "a backdrop still a floor away records nothing yet")
	bf.go_live()
	await get_tree().process_frame
	check(WorldState.visited_floors.has("14"), "arriving by stairs reveals the floor on the map")
	check(int(WorldState.chronicle_entry(1)["deepest_floor"]) == 14, "arriving by stairs records the depth")
	check(WorldState.best_depth == 14, "arriving by stairs updates the permanent record")
	check(WorldState.floors_enemy_seen.has("14") == bf._has_own_live_zombies(),
		"an enemy sighting is recorded exactly when this floor has its own dead")
	# A zombie belonging to ANOTHER floor (the one just left, still in the tree mid-pan) must not
	# count as this floor's.
	var before: bool = bf._has_own_live_zombies()
	var stranger = load("res://scenes/enemy_zombie_standard.tscn").instantiate()
	add_child(stranger)
	await get_tree().process_frame
	check(bf._has_own_live_zombies() == before, "another floor's zombie isn't credited to this floor")
	stranger.free()
	bf.free()
	await get_tree().process_frame


func _test_endpoints_recorded() -> void:
	# Floor 30 (where every run starts) and the lobby (0, the exit) aren't building_floors scenes —
	# they must still feed the journal map + depth.
	print("[floor 30 and the lobby are recorded too]")
	WorldState.new_game()
	WorldState.best_depth = 30
	var root := Node2D.new()
	add_child(root)
	WorldState.note_floor_arrival(root, 30)
	check(WorldState.visited_floors.has("30"), "floor 30 is revealed on the map")
	WorldState.note_floor_arrival(root, 0)
	check(WorldState.visited_floors.has("0"), "the lobby is revealed on the map")
	check(WorldState.best_depth == 0, "reaching the lobby is the deepest record (0)")
	# A zombie under THIS scene marks a sighting; none → no sighting.
	check(not WorldState.floors_enemy_seen.has("0"), "no zombies in the scene → no sighting")
	var z = load("res://scenes/enemy_zombie_standard.tscn").instantiate()
	root.add_child(z)
	await get_tree().process_frame
	WorldState.note_floor_arrival(root, 0)
	check(WorldState.floors_enemy_seen.has("0"), "a zombie in the scene → a sighting")
	root.free()
	# The real scenes are wired: the lobby records itself on arrival.
	WorldState.visited_floors.clear()
	var lobby = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().process_frame
	check(WorldState.visited_floors.has("0"), "arriving in the lobby scene records it")
	lobby.free()
	await get_tree().process_frame


func _test_save_load() -> void:
	print("[chronicle survives save/load; best_depth is a permanent record]")
	WorldState.new_game()
	WorldState.current_floor = 7
	WorldState.note_floor_reached(7)
	WorldState.add_run_trace("a forced door on floor 7")
	WorldState.save_game("res://scenes/building_floors.tscn", false)
	# Wipe the in-memory chronicle, then load it back.
	WorldState.run_chronicle.clear()
	WorldState.load_game()
	check(WorldState.run_chronicle.size() == 3, "chronicle restored from save")
	check(int(WorldState.chronicle_entry(1)["deepest_floor"]) == 7, "depth restored")
	check("a forced door on floor 7" in WorldState.chronicle_entry(1)["traces"], "traces restored")
	# best_depth is a PROFILE record (permanent) — reload the profile and it's still there.
	WorldState.best_depth = 30
	WorldState.load_profile()
	check(WorldState.best_depth <= 7, "best_depth persisted to the profile record (<=7)")
	WorldState.delete_save()
