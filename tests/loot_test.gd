extends Node

# Headless test for the redesigned centred loot panel: reveal → item shown with
# name/icon → take adds to inventory and closes. Plus the clickable mode toggle.
# Run:  godot --headless res://tests/loot_test.tscn

var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== loot panel test ===")
	WorldState.new_game()
	WorldState.is_scavenge_mode = true
	WorldState.current_apartment_id = "test"
	WorldState.inventory.clear()
	WorldState.set_anchor_item("test", "a1", "006")  # Bandages

	var loot = load("res://scenes/loot_ui.tscn").instantiate()
	add_child(loot)
	await get_tree().process_frame

	loot.open("006", "a1", "test")
	check(loot.visible and loot.is_revealing, "opens in searching state")
	check(not loot.has_item, "no takeable item during the search")
	# Drive the reveal.
	loot._process(loot.REVEAL_TIME + 0.1)
	check(loot.has_item, "item revealed after the search")
	check(loot.name_label.text == "Bandages", "shows the item name (%s)" % loot.name_label.text)
	check(WorldState.loot_open, "loot_open lock is set while open")

	var before = WorldState.inventory.size()
	loot._take()
	check(WorldState.inventory.size() == before + 1, "take adds the item to inventory")
	check(not loot.visible, "panel closes after taking")
	check(not WorldState.loot_open, "loot_open lock cleared on close")
	loot.queue_free()

	# Clickable mode toggle on the HUD.
	check(HUD.mode_label is Button, "HUD mode indicator is a clickable Button")
	var player = load("res://scenes/player.tscn").instantiate()
	add_child(player)
	await get_tree().process_frame
	check(player.has_method("request_mode_toggle"), "player exposes request_mode_toggle()")
	WorldState.is_scavenge_mode = false
	player.is_switching_mode = false
	var started = player.request_mode_toggle()
	check(started and player.is_switching_mode, "mode button starts a scavenge↔combat switch")
	player.queue_free()

	_test_variant_anchor_pools()

	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _test_variant_anchor_pools() -> void:
	# A module ART VARIANT puts its own nodes on its own furniture under names of its own. The loot
	# pool used to come ONLY from a fixed per-type name list, so a new name silently held nothing.
	# The room now passes the module's room type; the built-in names must get the SAME pools as before.
	print("[variant nodes get their room's loot pool]")
	WorldState.new_game()
	var apt := "1504"
	var layout: Array = WorldState.get_apartment_layout(apt)
	var rt: String = layout[0]
	var novel := WorldState.get_items_for_anchor("anchor_variant_new_spot", apt, rt)
	check(WorldState.get_items_for_anchor("anchor_variant_new_spot", apt).is_empty(),
		"a name the fixed list doesn't know has no pool by name alone (the old trap)")
	check(not novel.is_empty(), "…but with its module's room type (%s) it gets that room's pool (%d)" % [rt, novel.size()])
	var same := true
	for t in layout:
		for a in WorldState.get_anchors_for_room(t):
			if WorldState.get_items_for_anchor(a, apt) != WorldState.get_items_for_anchor(a, apt, t):
				same = false
			if WorldState.get_items_for_anchor_weighted(a, apt, 2) != WorldState.get_items_for_anchor_weighted(a, apt, 2, t):
				same = false
	check(same, "every built-in node gets exactly the same pool as before (layout %s)" % str(layout))
