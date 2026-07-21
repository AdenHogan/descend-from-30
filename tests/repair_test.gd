extends Node

# Headless test for broken-item persistence + toolbox repair (item 12).
# Run:  godot --headless res://tests/repair_test.tscn

var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== broken-item / repair test ===")
	_test_broken_flags()
	_test_repair_full()
	_test_damaged_gun_repairable()
	_test_toolbox_priority()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _make(id: String) -> ItemInstance:
	var inst = ItemInstance.new()
	inst.setup(id)
	return inst


func _test_broken_flags() -> void:
	print("[broken flags]")
	var bat = _make("014")  # Baseball Bat, 8 uses
	check(not bat.is_repairable(), "fresh weapon is not repairable")
	for i in range(8):
		bat.use()
	check(bat.is_depleted, "weapon depletes after its uses")
	check(bat.is_repairable(), "a broken durability weapon is repairable")


func _test_repair_full() -> void:
	print("[repair]")
	var bat = _make("014")
	for i in range(8):
		bat.use()
	bat.repair_full()
	check(not bat.is_depleted, "repair un-breaks the weapon")
	check(bat.current_durability == 8, "repair refills durability to max")
	check(not bat.is_repairable(), "repaired weapon no longer needs repair")


func _test_damaged_gun_repairable() -> void:
	print("[damaged gun]")
	var gun = _make("004")
	gun.is_damaged = true
	check(gun.is_repairable(), "damaged gun is repairable")
	check(gun.get_mag_cap() == 10, "damaged gun mag cap is 10")
	gun.repair_full()
	check(not gun.is_damaged, "repair clears damage")
	check(gun.get_mag_cap() == 18, "repaired gun mag cap back to 18")


func _test_toolbox_priority() -> void:
	print("[toolbox priority]")
	WorldState.new_game()
	var broken_bat = _make("014")
	for i in range(8):
		broken_bat.use()
	WorldState.inventory.append(broken_bat)
	var dmg_gun = _make("004")
	dmg_gun.is_damaged = true
	WorldState.inventory.append(dmg_gun)
	# A damaged gun should win the single toolbox charge over a broken bat.
	var first_repairable = null
	for inst in WorldState.inventory:
		if inst.is_damaged:
			first_repairable = inst
			break
		if first_repairable == null and inst.is_repairable():
			first_repairable = inst
	check(first_repairable == dmg_gun, "damaged gun prioritised for repair")
	WorldState.inventory.clear()
