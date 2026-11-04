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
	_test_owner_balance_2026_11_04()

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


## The owner's balance changes after a full 30 -> lobby descent (2026-11-04, docs/BALANCE_AUDIT_2026-11-04.md): a Toolbox is ONE use and half as
## common, bullets found in the world are 15% fewer, cash found is 20% more, ordinary scrap bags 10% bigger. Every number is read back from
## the game's own draws, and each check fails if the old number is put back.
func _test_owner_balance_2026_11_04() -> void:
	print("[owner balance 2026-11-04: toolbox, bullets, cash, scrap]")
	WorldState.new_game()
	WorldState.is_first_run = false
	WorldState.current_run = 1
	# --- the toolbox: one use, then gone
	var tb := ItemInstance.new()
	tb.setup("019")
	check(ItemData.items["019"]["single_use"] == true and tb.current_durability == 1, "a Toolbox is single use (durability %d)" % tb.current_durability)
	tb.use()
	check(tb.is_depleted, "…and one repair spends it")
	# --- half as common: the pool weights, and the copies the game really deals into nodes
	var pool: Dictionary = ItemData.room_spawn_pools["Toolbox"]
	var weights_ok := true
	for rt in ["kitchen", "study", "dining_room"]:
		weights_ok = weights_ok and is_equal_approx(float(pool[rt]), 0.5)
	for rt in ["bedroom", "bathroom", "living_room"]:
		weights_ok = weights_ok and float(pool[rt]) == 0.0
	check(weights_ok, "a Toolbox's node weight is 0.5 in the kitchen, study and dining room (was 1), none elsewhere")
	var copies := 0
	var expect := 0.0
	var lucky: float = WorldState.luck_weight(1)
	for rt in ["kitchen", "study", "dining_room"]:
		for k in range(200):
			var apt := "1001"
			for id in WorldState.get_items_for_anchor("n%d" % k, apt, rt):
				copies += 1 if id == "019" else 0
			expect += 0.5 * lucky * WorldState.loot_gear_scale(10)
	check(copies > 0 and absf(float(copies) - expect) <= 0.30 * expect, "…600 nodes deal %d Toolbox copies (half-weight expectation %.0f; a weight of 1 would be ~%.0f)" % [copies, expect, expect * 2.0])
	# --- maintenance rooms: the Toolbox share of a room's two nodes halved (0.36 -> 0.18), the fuse's did not move
	var room_script = load("res://scripts/room.gd").new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261104
	var n_tb := 0
	var n_fuse := 0
	var n_scrap := 0
	var n_empty := 0
	var draws := 6000
	for i in range(draws):
		match room_script._maintenance_loot(rng):
			"019": n_tb += 1
			"020": n_fuse += 1
			"037": n_scrap += 1
			"": n_empty += 1
	room_script.free()
	check(absf(float(n_tb) / draws - 0.18) < 0.02, "a maintenance node holds a Toolbox %.0f%% of the time (was 36%%)" % (100.0 * n_tb / draws))
	check(absf(float(n_fuse) / draws - 0.28) < 0.025 and absf(float(n_scrap) / draws - 0.16) < 0.02, "…while the Fuse (%.0f%%) and the scrap bag (%.0f%%) keep their shares" % [100.0 * n_fuse / draws, 100.0 * n_scrap / draws])
	# --- bullets found in the world: the bundle is 15% smaller on average, and the same 3..10 span
	var LU = load("res://scripts/loot_ui.gd")
	var total := 0
	var lo := 99
	var hi := 0
	var n := 4000
	for i in range(n):
		var b: int = LU.ammo_bundle_for("2004", "anchor_%d" % i)
		total += b
		lo = mini(lo, b)
		hi = maxi(hi, b)
	var mean := float(total) / n
	var wsum := 0
	for w in LU.AMMO_BUNDLE_WEIGHTS:
		wsum += int(w)
	check(wsum == 100 and lo >= 3 and hi <= 10, "a bundle is still 3..10 rounds (%d..%d, weights sum %d)" % [lo, hi, wsum])
	check(absf(mean - 4.74) < 0.12 and mean <= 5.58 * 0.86, "…and averages %.2f rounds, 15%% under the old 5.58" % mean)
	# --- cash found in the world: +20%
	check(WorldState.cash_found(10) == 12 and WorldState.cash_found(5) == 6 and WorldState.cash_found(15) == 18 and WorldState.cash_found(100) == 120, "found cash is rolled x1.2 (10 -> 12, 100 -> 120)")
	WorldState.wallet_unlocked = true
	WorldState.wallet_balance = 0
	var cash_n := 3000
	var cash_lo := 99
	var cash_hi := 0
	for i in range(cash_n):
		var before: int = WorldState.wallet_balance
		WorldState.add_to_inventory("033")
		var got: int = WorldState.wallet_balance - before
		cash_lo = mini(cash_lo, got)
		cash_hi = maxi(cash_hi, got)
	var cash_mean := float(WorldState.wallet_balance) / cash_n
	check(cash_lo >= 6 and cash_hi <= 18 and absf(cash_mean - 12.0) < 0.35, "a found bundle of notes is 6..18, averaging %.2f (was 5..15, mean 10)" % cash_mean)
	WorldState.add_to_inventory("033", 40)
	check(WorldState.wallet_balance == int(round(cash_mean * cash_n)) + 40, "…and a bundle handed over with a fixed amount (a gift, quest pay) is NOT scaled")
	# --- scrap outside the burnt flats: ordinary bags +10%, the charred bag unchanged
	check(WorldState.SCRAP_BAG_NATURAL == Vector2i(7, 15) and WorldState.SCRAP_BAG_CHARRED == Vector2i(14, 30), "an ordinary scrap bag is 7..15 (was 6..14); a burnt flat's is still 14..30")
	WorldState.scrap = 0
	var bags := 2000
	for i in range(bags):
		WorldState.add_to_inventory("037")
	var scrap_mean := float(WorldState.scrap) / bags
	check(absf(scrap_mean - 11.0) < 0.3, "…ordinary bags average %.2f scrap (was 10: +10%%)" % scrap_mean)
