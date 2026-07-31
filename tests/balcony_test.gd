extends Node

# Headless test for balcony generation (THREE_RUN_ARC balcony descent, Phase 2).
# Run:  godot --headless res://tests/balcony_test.tscn
# Covers the column-continuity seed and the layout-conform rule. The descent
# interaction itself is a later phase.

var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== balcony generation test ===")
	_test_determinism()
	_test_continuity()
	_test_conform_and_hide()
	_test_rope_and_clothes()
	_test_descent_core()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _apt(floor_num: int, col: int) -> String:
	return str(floor_num) + "0" + str(col)


func _test_determinism() -> void:
	print("[determinism]")
	WorldState.new_game()
	for col in range(1, 6):
		var a = WorldState.is_balcony_column(col)
		var b = WorldState.is_balcony_column(col)
		check(a == b, "is_balcony_column(%d) is stable" % col)
		check(WorldState.balcony_slot_for_column(col) == WorldState.balcony_slot_for_column(col),
			"balcony_slot_for_column(%d) is stable" % col)


func _test_continuity() -> void:
	print("[vertical continuity]")
	WorldState.new_game()
	# A balcony's slot must be identical to the apartment directly below (same
	# column) — that's what makes the descent land on a balcony.
	for col in range(1, 6):
		for floor_num in range(2, 30):
			var here := _apt(floor_num, col)
			var below := _apt(floor_num - 1, col)
			for slot in range(3):
				check(WorldState.is_balcony_slot(here, slot) == WorldState.is_balcony_slot(below, slot),
					"col %d slot %d: floor %d matches floor %d" % [col, slot, floor_num, floor_num - 1])


func _test_conform_and_hide() -> void:
	print("[layout conforms / non-balcony hidden]")
	# Find a seed that gives us BOTH a balcony column and a non-balcony column so
	# both paths are exercised regardless of hash outcomes.
	var bal_col := -1
	var plain_col := -1
	for seed_try in range(1, 80):
		WorldState.master_seed = seed_try
		WorldState.apartment_layouts.clear()
		bal_col = -1
		plain_col = -1
		for col in range(1, 6):
			if WorldState.is_balcony_column(col) and bal_col < 0:
				bal_col = col
			elif not WorldState.is_balcony_column(col) and plain_col < 0:
				plain_col = col
		if bal_col > 0 and plain_col > 0:
			break
	check(bal_col > 0 and plain_col > 0, "found a balcony column and a plain column to test")

	# Balcony column: the seeded slot always holds a study or dining room, on
	# every floor; the layout stays three distinct rooms.
	var slot := WorldState.balcony_slot_for_column(bal_col)
	for floor_num in range(1, 30):
		var apt := _apt(floor_num, bal_col)
		var layout = WorldState.get_apartment_layout(apt)
		check(layout[slot] in WorldState.BALCONY_ROOMS,
			"balcony col %d floor %d: slot %d is a balcony room (%s)" % [bal_col, floor_num, slot, layout[slot]])
		check(layout[0] != layout[1] and layout[1] != layout[2] and layout[0] != layout[2],
			"balcony col %d floor %d: three distinct rooms" % [bal_col, floor_num])
		check(WorldState.is_balcony_slot(apt, slot), "balcony col %d floor %d: slot flagged" % [bal_col, floor_num])

	# Plain column: no slot is ever a balcony slot.
	for floor_num in range(1, 30):
		var apt := _apt(floor_num, plain_col)
		for s in range(3):
			check(not WorldState.is_balcony_slot(apt, s),
				"plain col %d floor %d slot %d: no balcony" % [plain_col, floor_num, s])


func _test_rope_and_clothes() -> void:
	print("[rope + clothes items]")
	check(ItemData.get_item("035").get("is_rope", false), "Rope (035) is a rope")
	check(ItemData.get_item("036").get("is_clothes", false), "Clothes (036) is clothes")
	check(not ItemData.get_item("036").get("is_rope", false), "raw clothes are not a rope yet")
	check(ItemData.get_item("037").get("is_rope", false), "Clothes-Rope (037) is a rope")
	check(absf(WorldState.CLOTHES_BEDROOM_BOOST - 1.30) < 0.001, "clothes bedroom boost is 30%")

	# Clothes don't stack — three take three slots.
	WorldState.new_game()
	WorldState.inventory.clear()
	check(WorldState.add_to_inventory("036"), "1st clothes taken")
	check(WorldState.add_to_inventory("036"), "2nd clothes taken")
	check(WorldState.add_to_inventory("036"), "3rd clothes taken")
	check(WorldState.inventory.size() == 3 and WorldState.count_clothes() == 3,
		"three clothes occupy three separate slots (not stacked)")

	# Knot them: 3 clothes -> 1 clothes-rope, freeing two slots.
	check(WorldState.craft_clothes_rope(), "3 clothes craft a clothes-rope")
	check(WorldState.count_clothes() == 0, "the clothes are consumed")
	var ropes := 0
	for inst in WorldState.inventory:
		if inst.item_id == "037":
			ropes += 1
	check(ropes == 1 and WorldState.inventory.size() == 1, "one clothes-rope remains in one slot")

	# Two clothes aren't enough.
	WorldState.inventory.clear()
	WorldState.add_to_inventory("036")
	WorldState.add_to_inventory("036")
	check(not WorldState.craft_clothes_rope(), "2 clothes can't make a rope")
	check(WorldState.count_clothes() == 2, "the spare clothes are left alone")


func _test_descent_core() -> void:
	print("[descent core]")
	WorldState.new_game()
	# The apartment below is same column, one floor down.
	check(WorldState.balcony_below("2603") == "2503", "below 2603 is 2503")
	check(WorldState.balcony_below("3005") == "2905", "below 3005 is 2905")
	check(WorldState.balcony_below("103") == "", "floor 1 has nothing below (lobby)")

	# A lashed rope persists and is keyed per apartment+slot.
	check(not WorldState.is_balcony_roped("2603", 1), "balcony starts un-roped")
	WorldState.rope_balcony("2603", 1)
	check(WorldState.is_balcony_roped("2603", 1), "rope_balcony marks it roped")
	check(not WorldState.is_balcony_roped("2603", 0), "only the roped slot is roped")

	# Slip chance follows stamina bands.
	var maxs = WorldState.get_max_stamina()
	WorldState.stamina = maxs * 0.8
	check(WorldState.balcony_slip_chance() == 0.0, "rested = safe climb")
	WorldState.stamina = maxs * 0.45
	check(absf(WorldState.balcony_slip_chance() - WorldState.BALCONY_SLIP_CHANCE_MODERATE) < 0.001,
		"mid stamina = moderate slip chance")
	WorldState.stamina = maxs * 0.1
	check(absf(WorldState.balcony_slip_chance() - WorldState.BALCONY_SLIP_CHANCE_HIGH) < 0.001,
		"low stamina = high slip chance")

	# Descending moves world state into the apartment below and opens its door
	# from the inside.
	WorldState.door_states["2503"] = WorldState.DoorState.SHUT_LOCKED
	var target = WorldState.descend_from_balcony("2603")
	check(target == "2503", "descend targets the apartment below")
	check(WorldState.current_floor == 25, "floor drops by one")
	check(WorldState.current_apartment_id == "2503", "now inside the apartment below")
	check(WorldState.spawn_source == "balcony", "arrival is flagged as a balcony drop-in")
	check(WorldState.get_door_state("2503") == WorldState.DoorState.OPEN,
		"a locked door is opened from the inside")
	check(WorldState.descend_from_balcony("103") == "", "can't descend from floor 1")
