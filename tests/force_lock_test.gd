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
	await _test_barricade_boards()
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


# BARRICADE BOARDS (owner round 22 — "make removing barricades look more exciting… not just the box
# showing the time counting down, and the spikey shape"): the barricade is boards nailed across the
# door; they come off one at a time as the work goes on, fly and land on the floor; the prompt carries
# no countdown; saved progress shows as boards already gone.
func _test_barricade_boards() -> void:
	print("[barricade boards]")
	WorldState.new_game()
	WorldState.current_floor = 20
	WorldState.is_first_run = false
	WorldState.god_mode = true
	WorldState.inventory.clear()
	HUD.selected_slot = -1
	WorldState.set_door_state("2003", WorldState.DoorState.BARRICADED_FORCEABLE)
	WorldState.barricade_progress.erase("2003")
	var door = _make_door("2003")
	await get_tree().process_frame
	var boards = door.get_node_or_null("BarricadeBoards")
	check(boards != null, "a barricaded door has boards nailed across it")
	if boards == null:
		WorldState.god_mode = false
		return
	var n: int = boards.board_count()
	check(n >= 4 and n <= 6 and boards.boards_left() == n, "4-6 boards, all up (%d / %d)" % [boards.boards_left(), n])
	check(door.barricade_sprite.self_modulate.a == 0.0 and door.barricade_progress_overlay.color.a == 0.0,
		"the old crate sprite + shrinking black box are never drawn")
	door.player_nearby = true
	door._attempt_barricade_removal()
	check(door.is_removing_barricade, "removal starts")
	var prompt: String = door._get_prompt_text()
	var countdown := RegEx.new()
	countdown.compile("\\d+\\.\\d")
	check(prompt.contains("Tearing") and countdown.search(prompt) == null, "the prompt says what's happening, no countdown (%s)" % prompt)
	var left := [boards.boards_left()]
	var monotonic := true
	var steps := 0
	while door.is_removing_barricade and steps < 400:
		door._tick_barricade_removal(0.05)
		steps += 1
		var l: int = boards.boards_left()
		if l > left[left.size() - 1]:
			monotonic = false
		if l != left[left.size() - 1]:
			left.append(l)
	check(monotonic and left.size() >= n and left[left.size() - 1] == 0, "they come off one at a time (%s)" % str(left))
	check(WorldState.get_door_state("2003") == WorldState.DoorState.SHUT_FORCEABLE, "all gone: the door's just shut now")
	var waited := 0.0
	while not boards._air.is_empty() and waited < 5.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	check(boards._landed.size() >= 1 and boards._air.is_empty(), "the torn boards land on the floor and stay (%d landed)" % boards._landed.size())
	var on_floor := true
	for a in boards._landed:
		if absf(float(a["p"].y) - (boards.DOOR_BOTTOM - 2.0)) > 0.5:
			on_floor = false
	check(on_floor, "...on the floor line")
	door.queue_free()
	# saved progress: some boards already gone, none flying
	WorldState.set_door_state("2004", WorldState.DoorState.BARRICADED_FORCEABLE)
	WorldState.barricade_progress["2004"] = 0.5
	var d2 = _make_door("2004")
	await get_tree().process_frame
	var b2 = d2.get_node("BarricadeBoards")
	var want := 0
	for i in range(b2.board_count() - 1):
		if 0.5 >= b2._threshold(i) - 0.0001:
			want += 1
	check(b2.boards_left() == b2.board_count() - want and b2._air.is_empty(), "saved progress: %d board(s) already off, nothing flying" % want)
	d2.queue_free()
	# a door that isn't barricaded draws no boards
	WorldState.set_door_state("2005", WorldState.DoorState.SHUT_LOCKED)
	var d3 = _make_door("2005")
	await get_tree().process_frame
	check(d3.get_node("BarricadeBoards").boards_left() == 0, "a door that isn't barricaded has no boards")
	d3.queue_free()
	# the loud cue is sound-wave arcs now (listen_overlay.noise_ping), not a jagged ring
	check(not FileAccess.get_file_as_string("res://scripts/listen_overlay.gd").contains("zigzag"), "the noise cue is a sound wave, not the starburst")
	WorldState.barricade_progress.erase("2004")
	WorldState.god_mode = false
