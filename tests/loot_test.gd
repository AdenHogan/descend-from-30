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
	check(is_equal_approx(loot.reveal_time, loot.REVEAL_TIME), "a node holding something takes the full search (%.1f s)" % loot.reveal_time)
	# a search is a small word, not a panel (owner round 48j: "the word searching literally can be the bar"): SEARCHING hangs in the room, its letters light S to G
	check(loot.search_word.visible and not loot.panel.visible, "while searching: just the word SEARCHING — no panel, no bar, the room stays in view")
	check(loot.search_word.fraction() == 0.0 and loot.search_word.lit_letters() == 0, "the word starts with every letter dim")
	loot._process(loot.reveal_time * 0.5)
	check(absf(loot.search_word.fraction() - 0.5) < 0.02, "…and is half lit half-way through (%.2f)" % loot.search_word.fraction())
	# Drive the reveal.
	loot._process(loot.REVEAL_TIME + 0.1)
	check(loot.has_item, "item revealed after the search")
	check(loot.panel.visible and loot.icon_row.visible and is_equal_approx(loot.panel.custom_minimum_size.x, loot.PANEL_W) and loot.search_word.resolving,
		"the result shows the full panel (icon and name) while the word resolves")
	check(loot.name_label.text == "Bandages", "shows the item name (%s)" % loot.name_label.text)
	check(WorldState.loot_open, "loot_open lock is set while open")

	var before = WorldState.inventory.size()
	loot._take()
	check(WorldState.inventory.size() == before + 1, "take adds the item to inventory")
	check(not loot.visible, "panel closes after taking")
	check(not WorldState.loot_open, "loot_open lock cleared on close")
	# a node holding NOTHING is searched in half the time
	WorldState.set_anchor_item("test", "a2", "")
	loot.open("", "a2", "test")
	check(is_equal_approx(loot.reveal_time, loot.REVEAL_TIME * 0.5) and loot.is_revealing, "an empty node searches in half the time (%.2f s)" % loot.reveal_time)
	loot._process(loot.REVEAL_TIME * 0.5 - 0.1)
	check(loot.is_revealing, "…still searching just before the halved time")
	loot._process(0.2)
	check(not loot.is_revealing and not loot.visible and not WorldState.loot_open, "…done at the halved time: no panel pops - it closes at once (owner round 48i)")
	check(HUD.feedback_label.text in loot.NOTHING_LINES, "…and the player says so in passing (\"%s\")" % HUD.feedback_label.text)
	check(not loot.has_item and not loot.panel.visible, "…with no panel ever shown for it")
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
	await _test_loot_by_depth()

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


func _test_loot_by_depth() -> void:
	# LOOT BY DEPTH (owner round 45: floor 29 held three hammers, two knives, a bat, a club, three fuses, two toolboxes…).
	print("[loot by depth: the top floors pay less]")
	WorldState.new_game()
	WorldState.is_first_run = false
	WorldState.current_run = 1
	check(WorldState.loot_chance_scale(29) < WorldState.loot_chance_scale(22) and WorldState.loot_chance_scale(22) < WorldState.loot_chance_scale(15)
		and is_equal_approx(WorldState.loot_chance_scale(15), 1.0) and is_equal_approx(WorldState.loot_chance_scale(3), 1.0),
		"a node is less likely to hold anything the higher it is, full strength from floor 15 down (%.2f / %.2f / %.2f)" % [
			WorldState.loot_chance_scale(29), WorldState.loot_chance_scale(22), WorldState.loot_chance_scale(15)])
	check(WorldState.loot_gear_scale(29) < WorldState.loot_gear_scale(22) and is_equal_approx(WorldState.loot_gear_scale(15), 1.0),
		"…and gear is rarer in the pool (%.2f at 29, %.2f at 22, %.2f at 15)" % [
			WorldState.loot_gear_scale(29), WorldState.loot_gear_scale(22), WorldState.loot_gear_scale(15)])
	check(WorldState.loot_gear_cap(29) == 1 and WorldState.loot_gear_cap(25) == 1 and WorldState.loot_gear_cap(24) == 2
		and WorldState.loot_gear_cap(17) == 2 and WorldState.loot_gear_cap(16) >= 50, "one flat holds 1 piece of gear up top, 2 below floor 25, no limit from 16 down")
	check(WorldState.is_gear_item("002") and WorldState.is_gear_item("004") and WorldState.is_gear_item("020") and WorldState.is_gear_item("019")
		and not WorldState.is_gear_item("035") and not WorldState.is_gear_item("006") and not WorldState.is_gear_item("016")
		and not WorldState.is_gear_item("025"), "gear = weapons, fuse, toolbox…; the crowbar, medicine, ammo and junk are not")
	# the pools themselves, summed over every room type and a spread of nodes (the extra copy of a fractional weight is seeded)
	var gear_hi := 0
	var gear_lo := 0
	var crow_hi := 0
	var crow_lo := 0
	var junk_hi := 0
	var junk_lo := 0
	for rt in ["bedroom", "bathroom", "kitchen", "dining_room", "living_room", "study"]:
		for k in range(40):
			for pair in [["2901", false], ["1001", true]]:
				var pool: Array = WorldState.get_items_for_anchor("n%d" % k, String(pair[0]), rt)
				for id in pool:
					var g: bool = WorldState.is_gear_item(id)
					if pair[1]:
						gear_lo += 1 if g else 0
						crow_lo += 1 if id == "035" else 0
						junk_lo += 1 if ItemData.get_item(id).get("is_junk", false) else 0
					else:
						gear_hi += 1 if g else 0
						crow_hi += 1 if id == "035" else 0
						junk_hi += 1 if ItemData.get_item(id).get("is_junk", false) else 0
	check(gear_lo > 0 and float(gear_hi) < float(gear_lo) * 0.55,
		"floor 29's pools carry well under 55%% of floor 10's gear (%d vs %d copies)" % [gear_hi, gear_lo])
	# (a character with luck makes some weights fractional, and each apartment seeds its own extra copy, so "untouched" is within 12%)
	check(crow_lo > 0 and absf(float(crow_hi - crow_lo)) <= 0.12 * float(crow_lo) and absf(float(junk_hi - junk_lo)) <= 0.12 * float(junk_lo),
		"…while crowbars (%d vs %d) and junk (%d vs %d) are untouched" % [crow_hi, crow_lo, junk_hi, junk_lo])
	# a real flat on the top floors never holds more than the cap
	var worst := 0
	var flats := 0
	for seed_ in [3101, 3102, 3103, 3104]:
		WorldState.dev_seed = seed_
		WorldState.new_game()
		WorldState.is_first_run = false
		WorldState.current_run = 1
		for f in [29, 27, 25]:
			for i in range(1, 6):
				var apt := str(f) + "0" + str(i)
				WorldState.set_door_state(apt, WorldState.DoorState.OPEN)
				WorldState.current_apartment_id = apt
				WorldState.current_floor = f
				WorldState.spawn_source = ""
				var room = load("res://scenes/room.tscn").instantiate()
				add_child(room)
				await get_tree().process_frame
				await get_tree().process_frame
				var gear := 0
				for key in WorldState.anchor_items.keys():
					# (the pockets of the dead a flat may hold are their own thing — dead_body_loot — not room loot)
					if String(key).begins_with(apt + ":") and not String(key).contains(":dead_") \
							and WorldState.is_gear_item(String(WorldState.anchor_items[key])):
						gear += 1
						if gear > WorldState.loot_gear_cap(f):
							print("    over the cap in ", apt, ": ", key, " = ", WorldState.anchor_items[key])
				worst = maxi(worst, gear)
				flats += 1
				room.queue_free()
				await get_tree().process_frame
	WorldState.dev_seed = 0
	check(flats == 60 and worst <= WorldState.loot_gear_cap(29),
		"60 flats on floors 25-29 across 4 buildings: none holds more than %d piece of gear (worst %d)" % [WorldState.loot_gear_cap(29), worst])
