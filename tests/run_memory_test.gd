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
