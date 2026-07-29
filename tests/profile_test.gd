extends Node

# The PLAYER PROFILE: a record of the person, not the playthrough. It lives in
# user://profile.cfg (beside keybinds.cfg) and NOT in savegame.json, so starting
# a new game — or just pressing Play in the editor again — does not re-teach the
# tutorial to someone who has already been through it.
# Run:  godot --headless res://tests/profile_test.tscn

var fails := 0

func chk(c: bool, m: String) -> void:
	print(("  PASS  " if c else "  FAIL  ") + m)
	if not c:
		fails += 1

func _ready() -> void:
	print("=== player profile test ===")
	# Start from a clean slate so the test never depends on the dev machine.
	for slot in range(1, WorldState.SLOT_COUNT + 1):
		WorldState.delete_slot(slot)
	WorldState.use_slot(1)

	# A genuinely new player is taught.
	WorldState.new_game()
	chk(WorldState.is_first_run, "new player: tutorial runs")
	chk(WorldState.profile_status() == "new player", "status reads 'new player'")

	# Leaving floor 30 counts as having been taught.
	WorldState.on_floor_arrived(29)
	chk(WorldState.tutorial_completed, "descending past 30 completes the tutorial")
	chk(WorldState.profile_status() == "returning player", "status reads 'returning player'")

	# THE POINT: a new game no longer replays it.
	WorldState.new_game()
	chk(not WorldState.is_first_run, "new game after the tutorial does NOT replay it")

	# ...and it survives a restart, which a save-file flag would not.
	WorldState.tutorial_completed = false      # simulate a fresh process
	WorldState.load_profile()
	chk(WorldState.tutorial_completed, "profile persists across a restart")
	WorldState.new_game()
	chk(not WorldState.is_first_run, "restarted session still skips the tutorial")

	# Deliberately becoming a new player again (what F7 writes).
	WorldState.set_tutorial_completed(false)
	WorldState.load_profile()
	chk(not WorldState.tutorial_completed, "can reset to 'new player' persistently")
	WorldState.new_game()
	chk(WorldState.is_first_run, "after reset the tutorial runs again")

	# The profile must NOT ride along in the save data.
	var save_keys: Dictionary = WorldState.to_save_dict() if WorldState.has_method("to_save_dict") else {}
	if not save_keys.is_empty():
		chk(not save_keys.has("tutorial_completed"), "profile is not stored in the save file")

	_test_slots()

	print("=== %s (%d failures) ===" % ["ALL PASSED" if fails == 0 else "FAILED", fails])
	get_tree().quit(1 if fails > 0 else 0)


func _test_slots() -> void:
	print("[three independent profiles]")
	for slot in range(1, WorldState.SLOT_COUNT + 1):
		WorldState.delete_slot(slot)

	# An untouched slot is EMPTY, which is what makes it a new player.
	var empty: Dictionary = WorldState.slot_summary(2)
	chk(not empty["exists"], "an untouched slot reads as empty")
	chk(not empty["has_save"], "an empty slot has nothing to continue")

	# Play in slot 1 only.
	WorldState.use_slot(1)
	WorldState.new_game()                 # counts as a run started
	WorldState.on_floor_arrived(24)       # completes the tutorial
	WorldState.current_floor = 24
	WorldState.current_run = 2
	WorldState.save_profile()

	var one: Dictionary = WorldState.slot_summary(1)
	chk(one["exists"], "slot 1 now exists")
	chk(one["runs_made"] >= 1, "slot 1 counted a run started (%d)" % one["runs_made"])
	chk(one["tutorial_completed"], "slot 1 has finished the tutorial")
	chk(one["floor"] == 24, "slot 1 remembers the floor (%d)" % one["floor"])
	chk(one["run"] == 2, "slot 1 remembers which run of the arc (%d)" % one["run"])
	chk(WorldState.run_name(1) == "Morning" and WorldState.run_name(2) == "Afternoon" \
		and WorldState.run_name(3) == "Night", "runs are named morning/afternoon/night")

	# Slots must not bleed into each other.
	chk(not WorldState.slot_summary(2)["exists"], "slot 2 untouched by play in slot 1")
	chk(not WorldState.slot_summary(3)["exists"], "slot 3 untouched by play in slot 1")

	# A fresh slot still teaches the tutorial even though slot 1 is experienced.
	WorldState.use_slot(2)
	WorldState.new_game()
	chk(WorldState.is_first_run, "a fresh profile still gets the tutorial")
	WorldState.use_slot(1)
	WorldState.new_game()
	chk(not WorldState.is_first_run, "the experienced profile still skips it")

	# Surviving a run is counted.
	var before: int = WorldState.slot_summary(1)["runs_successful"]
	WorldState.record_run_survived()
	chk(WorldState.slot_summary(1)["runs_successful"] == before + 1,
		"a survived run is recorded")

	# Delete returns a slot to new-player state.
	WorldState.delete_slot(1)
	chk(not WorldState.slot_summary(1)["exists"], "delete wipes the profile")
	WorldState.use_slot(1)
	WorldState.new_game()
	chk(WorldState.is_first_run, "a deleted profile is a new player again")
