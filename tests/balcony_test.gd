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
