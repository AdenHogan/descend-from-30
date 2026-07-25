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
	DirAccess.remove_absolute(ProjectSettings.globalize_path(WorldState.PROFILE_PATH))
	WorldState.tutorial_completed = false

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

	print("=== %s (%d failures) ===" % ["ALL PASSED" if fails == 0 else "FAILED", fails])
	get_tree().quit(1 if fails > 0 else 0)
