extends Node
# Fuse + elevator traversal (docs/MAINTENANCE_ELEVATOR.md). Covers fuse stacking
# (max 3/slot), fitting fuses at the box to power the lift, the single-use charge,
# the 5-floor jump with end clamping, and save/load persistence of the power state.
# Run: godot --headless res://tests/elevator_test.tscn
var fails := 0
func chk(c: bool, m: String) -> void:
	print(("  PASS  " if c else "  FAIL  ") + m)
	if not c: fails += 1

func _reset() -> void:
	WorldState.new_game()
	WorldState.tutorial_completed = true
	WorldState.is_first_run = false
	WorldState.inventory.clear()
	WorldState.elevator_powered = false
	WorldState.elevator_fuses_loaded = 0

func _ready() -> void:
	print("=== fuse + elevator ===")

	# --- fuse stacking: 3 fuses share ONE slot, a 4th opens a second ---
	_reset()
	for i in range(3):
		WorldState.add_to_inventory("020")
	chk(WorldState.inventory.size() == 1, "3 fuses stack into one slot (%d)" % WorldState.inventory.size())
	chk(WorldState.fuse_count() == 3, "carrying 3 fuses (%d)" % WorldState.fuse_count())
	WorldState.add_to_inventory("020")
	chk(WorldState.fuse_count() == 4, "a 4th fuse is carried (%d)" % WorldState.fuse_count())
	chk(WorldState.inventory.size() == 2, "the 4th fuse opens a second slot (%d)" % WorldState.inventory.size())

	# --- powering the elevator needs exactly 3 fuses ---
	_reset()
	WorldState.add_to_inventory("020")
	WorldState.add_to_inventory("020")
	var fitted := WorldState.fit_fuses_from_inventory()
	chk(fitted == 2, "fits the 2 carried fuses (%d)" % fitted)
	chk(not WorldState.can_ride_elevator(), "2 fuses is not enough to power the elevator")
	chk(WorldState.fuse_count() == 0, "fitted fuses leave the inventory (%d)" % WorldState.fuse_count())
	WorldState.add_to_inventory("020")
	fitted = WorldState.fit_fuses_from_inventory()
	chk(fitted == 1, "fits the last needed fuse (%d)" % fitted)
	chk(WorldState.can_ride_elevator(), "3 fitted fuses power the elevator")
	chk(WorldState.elevator_fuses_loaded == 3, "box shows 3/3 (%d)" % WorldState.elevator_fuses_loaded)

	# --- the 5-floor jump, both ways, with end clamping ---
	WorldState.current_floor = 20
	chk(WorldState.elevator_destination(1) == 25, "up 5 from 20 -> 25 (%d)" % WorldState.elevator_destination(1))
	chk(WorldState.elevator_destination(-1) == 15, "down 5 from 20 -> 15 (%d)" % WorldState.elevator_destination(-1))
	WorldState.current_floor = 27
	chk(WorldState.elevator_destination(1) == 29, "up from 27 clamps to 29 (%d)" % WorldState.elevator_destination(1))
	WorldState.current_floor = 3
	chk(WorldState.elevator_destination(-1) == 1, "down from 3 clamps to 1 (%d)" % WorldState.elevator_destination(-1))

	# --- single-use: riding spends the charge and clears the box ---
	WorldState.consume_elevator_power()
	chk(not WorldState.can_ride_elevator(), "riding spends the charge")
	chk(WorldState.elevator_fuses_loaded == 0, "the box empties after a ride (%d)" % WorldState.elevator_fuses_loaded)

	# --- fitting extra fuses can't over-fill or double-power ---
	_reset()
	for i in range(3):
		WorldState.add_to_inventory("020")
	WorldState.fit_fuses_from_inventory()
	WorldState.add_to_inventory("020")               # a spare fuse still in the bag
	var extra := WorldState.fit_fuses_from_inventory()
	chk(extra == 0, "a full box takes no more fuses (%d)" % extra)
	chk(WorldState.fuse_count() == 1, "the spare fuse stays in the bag (%d)" % WorldState.fuse_count())

	# --- persistence: the powered charge survives save/load ---
	_reset()
	for i in range(3):
		WorldState.add_to_inventory("020")
	WorldState.fit_fuses_from_inventory()
	WorldState.save_game("res://scenes/building_floors.tscn")
	WorldState.elevator_powered = false
	WorldState.elevator_fuses_loaded = 0
	WorldState.load_game()
	chk(WorldState.can_ride_elevator(), "elevator power survives save/load")
	chk(WorldState.elevator_fuses_loaded == 3, "loaded-fuse count survives save/load (%d)" % WorldState.elevator_fuses_loaded)

	# --- new_game clears everything ---
	WorldState.new_game()
	chk(not WorldState.can_ride_elevator(), "new_game clears the elevator charge")
	chk(WorldState.elevator_fuses_loaded == 0, "new_game clears the fuse box (%d)" % WorldState.elevator_fuses_loaded)

	# --- the interior scene loads and reads the origin floor ---
	WorldState.current_floor = 18
	WorldState.power_elevator()
	var scene = load("res://scenes/elevator_interior.tscn")
	chk(scene != null, "elevator_interior.tscn loads")
	var inst = scene.instantiate()
	add_child(inst)
	for i in range(3): await get_tree().process_frame
	chk(inst._origin_floor == 18, "interior reads the origin floor (%d)" % inst._origin_floor)
	inst.free()
	await get_tree().process_frame

	print("=== %s (%d failures) ===" % ["ALL PASSED" if fails == 0 else "FAILED", fails])
	get_tree().quit(1 if fails > 0 else 0)
