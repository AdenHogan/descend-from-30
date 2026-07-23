extends Node

# Headless test for the channeled force action (door.gd): forcing a door or a
# lock is NOT instant — it takes FORCE_TIME, spends durability only on
# completion, and a key still opens instantly.
# Run:  godot --headless res://tests/force_lock_test.tscn

var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== force-lock channel test ===")
	_test_force_lock_channel()
	_test_key_is_instant()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _make_door(apt: String) -> Node:
	var door = load("res://scenes/door.tscn").instantiate()
	door.apartment_id = apt
	add_child(door)
	return door


func _test_force_lock_channel() -> void:
	print("[force lock channels over FORCE_TIME]")
	WorldState.new_game()
	WorldState.current_floor = 30
	WorldState.is_first_run = false  # avoid tutorial door-state overrides
	WorldState.set_door_state("2510", WorldState.DoorState.SHUT_LOCKED)
	WorldState.inventory.clear()
	WorldState.add_to_inventory("012")  # golf club — can_force_lock
	HUD.selected_slot = 0
	var club = WorldState.get_instance_at(0)
	var start_dur = club.current_durability

	var door = _make_door("2510")
	door._attempt_locked()
	check(door.is_forcing, "forcing a lock starts a channel (not instant)")
	check(WorldState.get_door_state("2510") == WorldState.DoorState.SHUT_LOCKED,
		"door is still locked mid-channel")
	check(club.current_durability == start_dur, "durability not spent until it completes")

	# Drive the channel to completion.
	door._tick_force(door.FORCE_TIME + 0.1)
	check(not door.is_forcing, "channel ends after FORCE_TIME")
	check(WorldState.get_door_state("2510") == WorldState.DoorState.OPEN, "lock is forced open on completion")
	check(club.current_durability == start_dur - 1, "exactly one use spent on completion")
	door.queue_free()


func _test_key_is_instant() -> void:
	print("[a key still opens instantly]")
	WorldState.set_door_state("2511", WorldState.DoorState.SHUT_LOCKED)
	WorldState.inventory.clear()
	WorldState.add_key_to_inventory("2511")
	HUD.selected_slot = -1
	var door = _make_door("2511")
	door._attempt_locked()
	check(not door.is_forcing, "using a key does not start a force channel")
	check(WorldState.get_door_state("2511") == WorldState.DoorState.OPEN, "key opens the lock immediately")
	door.queue_free()
