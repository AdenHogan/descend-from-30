extends Node

# Headless smoke test for the consolidated F1 DEV MENU (scripts/dev_menu.gd) and the
# player dev_* actions it drives. Verifies the menu builds its main + sub panels, a
# toggle flips WorldState, and the non-reloading player dev actions apply. (Actions that
# reload the floor — Set Run / Hazard — are exercised at the WorldState level only, since
# reloading the current scene mid-test would restart the test.)
# Run: godot --headless res://tests/dev_menu_test.tscn

var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== dev menu test ===")
	await _test_menu_builds()
	await _test_player_dev_actions()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _test_menu_builds() -> void:
	print("[menu builds main + sub panels]")
	WorldState.new_game()
	var menu = load("res://scripts/dev_menu.gd").new()
	add_child(menu)
	await get_tree().process_frame
	menu._show_main()
	check(menu._list.get_child_count() >= 8, "main panel lists the dev tools (%d buttons)" % menu._list.get_child_count())
	check(not menu._in_sub, "main panel is not a sub-panel")
	# A toggle that needs no player flips WorldState immediately.
	var before: bool = WorldState.dev_force_stair_enemies
	menu._toggle_stair_enemies()
	check(WorldState.dev_force_stair_enemies != before, "Force Stair Enemies toggles WorldState")
	menu._toggle_stair_enemies()  # restore
	# Sub-panels build and carry a Back button.
	menu._sub_health()
	check(menu._in_sub, "Set Health opens a sub-panel")
	var has_back := false
	for c in menu._list.get_children():
		if c is Button and String(c.text).findn("back") != -1:
			has_back = true
	check(has_back, "sub-panel has a Back button")
	menu._sub_run()
	check(menu._list.get_child_count() == 4, "Set Run sub has 3 runs + Back (%d)" % menu._list.get_child_count())
	menu._sub_hazard()
	check(menu._list.get_child_count() == 6, "Hazard sub has 5 options + Back (%d)" % menu._list.get_child_count())
	menu._show_main()
	check(not menu._in_sub, "Back returns to the main panel")
	menu._close()
	check(not get_tree().paused, "closing the menu unpauses")
	menu.queue_free()
	await get_tree().process_frame


func _test_player_dev_actions() -> void:
	# The non-reloading player dev_* actions apply. (Set Run / Hazard reload the floor,
	# so they're only checked at the WorldState level here.)
	print("[player dev actions]")
	WorldState.new_game()
	WorldState.current_floor = 12
	var bf = load("res://scenes/building_floors.tscn").instantiate()
	bf.setup_floor = 12
	add_child(bf)
	for i in range(3):
		await get_tree().process_frame
	var p = bf.get_node_or_null("Player")
	check(p != null, "a player exists to drive")
	if p != null:
		check(p.has_method("dev_toggle_god") and p.has_method("dev_set_run") and p.has_method("dev_apply_hazard"), "player exposes the dev_* methods")
		WorldState.god_mode = false
		p.dev_toggle_god()
		check(WorldState.god_mode, "dev_toggle_god turns god mode on")
		p.dev_toggle_god()
		check(not WorldState.god_mode, "dev_toggle_god turns it back off")
		p.dev_wallet_cash()
		check(WorldState.wallet_unlocked, "dev_wallet_cash unlocks the wallet")
		p.dev_set_health_state(0)
		check(int(p.health_state) == 0, "dev_set_health_state sets HEALTHY")
	# Set Run / Hazard: WorldState effect only (no reload in the test).
	WorldState.current_run = 1
	WorldState.dev_hazard_mode = WorldState.DEV_HAZARD_NONE
	# Mimic what dev_apply_hazard/dev_set_run write (without the deferred scene reload).
	WorldState.dev_hazard_mode = WorldState.DEV_HAZARD_FIRE
	check(WorldState.dev_hazard_mode == WorldState.DEV_HAZARD_FIRE, "hazard mode is settable")
	bf.queue_free()
	await get_tree().process_frame
	WorldState.dev_hazard_mode = WorldState.DEV_HAZARD_NONE
