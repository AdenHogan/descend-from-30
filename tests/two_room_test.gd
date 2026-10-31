extends Node

# TWO-ROOM FLATS (owner round 49f: "I like the idea of two room apartments mixed among the three room seeds, so the building has more variety").
#   • about three flats in ten have two rooms, chosen by the seed and the flat's number alone — not by the run, so a flat is the same size all three runs;
#   • never on Floor 30 (the tutorial's flats), never in a balcony column, always somewhere to sleep or sit, and the three-room flats are dealt exactly as they were;
#   • a two-room flat is never breached (the breach pack and its story are laid out for the long flat), and the gun cabinet's key room is never one;
#   • built for real, a two-room flat is 640 px long: two modules, its right wall, its door, the arrival spot and the dead's range all follow the span, on either entrance side.
# Run: godot --headless res://tests/two_room_test.tscn

var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== two-room flats test ===")
	await get_tree().process_frame
	WorldState.new_game()
	WorldState.is_first_run = false
	_test_the_mix()
	_test_the_rules()
	_test_breach()
	await _test_built("left")
	await _test_built("right")
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _ids(floors: Array) -> Array:
	var out: Array = []
	for f in floors:
		for c in range(1, 6):
			out.append("%d0%d" % [f, c])
	return out


func _floor_of(id: String) -> int:
	return int(id.left(id.length() - 2))


func _all_ids() -> Array:
	var fl: Array = []
	for f in range(1, 31):
		fl.append(f)
	return _ids(fl)


func _test_the_mix() -> void:
	print("[the mix: about three flats in ten]")
	var two := 0
	var total := 0
	for seed_ in [12345, 777, 90210, 31415, 2718]:
		WorldState.master_seed = seed_
		WorldState.apartment_layouts.clear()
		var seen_two := 0
		for id in _ids(range(1, 30)):
			if WorldState.is_balcony_column(int(id) % 10):
				continue
			total += 1
			if WorldState.get_apartment_layout(id).size() == 2:
				two += 1
				seen_two += 1
		check(seen_two >= 6, "seed %d: two-room flats exist (%d)" % [seed_, seen_two])
	var share := float(two) / float(maxi(1, total))
	check(share > 0.22 and share < 0.38, "…and they are about %d%% of the flats that can be (%.2f of %d)" % [int(WorldState.TWO_ROOM_CHANCE * 100.0), share, total])
	WorldState.master_seed = 12345
	WorldState.apartment_layouts.clear()


func _test_the_rules() -> void:
	print("[the rules]")
	var bad_floor := 0
	var bad_balcony := 0
	var no_home := 0
	var odd_size := 0
	var moved_by_run := 0
	var old_ways := 0
	WorldState.master_seed = 4242
	WorldState.apartment_layouts.clear()
	var first: Dictionary = {}
	for id in _all_ids():
		var l: Array = WorldState.get_apartment_layout(id)
		first[id] = l.duplicate()
		if l.size() != 2 and l.size() != 3:
			odd_size += 1
		if l.size() == 2:
			if _floor_of(id) >= 30:
				bad_floor += 1
			if WorldState.is_balcony_column(int(id) % 10):
				bad_balcony += 1
			if not ("bedroom" in l or "living_room" in l):
				no_home += 1
		elif WorldState.balcony_slot_in_apartment(id) < 0:
			# a three-room flat with no balcony is dealt as it always was: the first three of the seeded shuffle
			var rng: RandomNumberGenerator = WorldState._get_apartment_rng(id)
			rng.randi()
			var pool: Array = WorldState.ROOM_POOL.duplicate()
			for i in range(pool.size() - 1, 0, -1):
				var j: int = rng.randi() % (i + 1)
				var t = pool[i]
				pool[i] = pool[j]
				pool[j] = t
			if l != [pool[0], pool[1], pool[2]]:
				old_ways += 1
	check(odd_size == 0, "every flat has two or three rooms")
	check(bad_floor == 0, "none on Floor 30 (the tutorial's flats are fixed)")
	check(bad_balcony == 0, "none in a balcony column")
	check(no_home == 0, "every two-room flat has a bedroom or a living room")
	check(old_ways == 0, "a three-room flat is dealt exactly as before (%d differ)" % old_ways)
	for run in [2, 3]:
		WorldState.current_run = run
		WorldState.apartment_layouts.clear()
		for id in _all_ids():
			if WorldState.get_apartment_layout(id) != first[id]:
				moved_by_run += 1
	WorldState.current_run = 1
	check(moved_by_run == 0, "a flat is the same size and rooms in every run (%d changed)" % moved_by_run)
	check(WorldState.apartment_span("") == 3 and WorldState.apartment_span("3003") == 3, "the tutorial's flat and no flat at all are three")
	var a3 := ""
	var a2 := ""
	for id in _ids(range(1, 30)):
		if WorldState.get_apartment_layout(id).size() == 3 and a3 == "":
			a3 = id
		if WorldState.get_apartment_layout(id).size() == 2 and a2 == "":
			a2 = id
	check(a3 != "" and a2 != "" and is_equal_approx(WorldState.flat_x_hi(a3), 1030.0) and is_equal_approx(WorldState.flat_x_hi(a2), 710.0), "the dead's range ends at 1030 in a three-room flat and 710 in a two-room one")


func _test_breach() -> void:
	print("[a two-room flat is never breached]")
	var breached_two := 0
	var key_rooms := 0
	var key_rooms_two := 0
	for seed_ in [12345, 777, 90210, 31415]:
		WorldState.new_game()
		WorldState.is_first_run = false
		WorldState.master_seed = seed_
		WorldState.apartment_layouts.clear()
		for run in [1, 2, 3]:
			WorldState.current_run = run
			if run > 1:
				WorldState.mutate_door_states_for_new_run()
			for f in range(1, 25):
				WorldState.seed_floor_door_states(f)
			for id in _ids(range(1, 25)):
				if WorldState.door_states.get(id, -1) == WorldState.DoorState.BREACHED:
					key_rooms += 1
					if WorldState.apartment_span(id) < 3:
						breached_two += 1
						key_rooms_two += 1
	check(key_rooms > 20, "breached flats still occur (%d)" % key_rooms)
	check(breached_two == 0, "…and none of them has two rooms (%d)" % breached_two)
	# an old save that breached a two-room flat gets a shut door when it loads
	WorldState.new_game()
	WorldState.master_seed = 12345
	WorldState.apartment_layouts.clear()
	var victim := ""
	for id in _ids(range(1, 25)):
		if WorldState.apartment_span(id) == 2:
			victim = id
			break
	WorldState.door_states[victim] = WorldState.DoorState.BREACHED
	WorldState._drop_high_breaches()
	check(victim != "" and WorldState.door_states[victim] == WorldState.DoorState.SHUT_FORCEABLE, "a breach recorded in a two-room flat (an old save) loads as a shut door")


## A real flat of two rooms with the front door on `side`: built, its geometry follows the span.
func _test_built(side: String) -> void:
	print("[built for real, the door on the %s]" % side)
	WorldState.new_game()
	WorldState.is_first_run = false
	WorldState.master_seed = 12345
	WorldState.apartment_layouts.clear()
	WorldState.current_run = 1
	var apt := ""
	for id in _ids(range(3, 29)):
		if WorldState.apartment_span(id) == 2 and WorldState.get_entrance_side(id) == side and WorldState.get_door_state(id) != WorldState.DoorState.BREACHED and not WorldState.is_apartment_charred(_floor_of(id), int(id) % 10):
			apt = id
			break
	check(apt != "", "a two-room flat with its door on the %s was found" % side)
	if apt == "":
		return
	WorldState.current_apartment_id = apt
	WorldState.current_floor = _floor_of(apt)
	WorldState.spawn_source = ""
	var room = load("res://scenes/room.tscn").instantiate()
	add_child(room)
	for i in range(6):
		await get_tree().physics_frame
	var mods := get_tree().get_nodes_in_group("room_module")
	var n := 0
	for m in mods:
		if room.is_ancestor_of(m):
			n += 1
	check(n == 2, "two modules are built (%d)" % n)
	check(int(room.get("_span")) == 2, "the room knows its span")
	var right_x: float = float(room.LEFT_WALL_X + 2 * room.MODULE_WIDTH)
	var wr: float = float(room.get("wall_foot_right"))
	var wl: float = float(room.get("wall_foot_left"))
	check(wr > wl + 400.0 and wr < right_x + 45.0, "its right wall stands where a 640 px flat ends — the drawn wall's foot is a little past the slab (%.0f..%.0f, the end at %.0f)" % [wl, wr, right_x])
	var player = room.get_node("Player")
	var door = room.get_node("Area2D")
	if side == "right":
		check(player.global_position.x < right_x and player.global_position.x > right_x - 80.0, "the player arrives beside the right-hand door (%.0f)" % player.global_position.x)
		check(absf(door.global_position.x - (wr - 2.0)) < 1.5, "the exit trigger is at the right wall (%.0f, the wall at %.0f)" % [door.global_position.x, wr])
	else:
		check(player.global_position.x < 200.0, "the player arrives beside the left-hand door (%.0f)" % player.global_position.x)
	var cam: Camera2D = player.get_node_or_null("Camera2D")
	check(cam != null and float(cam.limit_right) < right_x + 60.0, "the camera stops at the flat's end (limit %d)" % (cam.limit_right if cam != null else -1))
	var far := 0
	for z in get_tree().get_nodes_in_group("zombie"):
		if room.is_ancestor_of(z) and z.global_position.x > right_x - 30.0:
			far += 1
	check(far == 0, "no dead stand past the end of the flat (%d)" % far)
	room.queue_free()
	await get_tree().process_frame
