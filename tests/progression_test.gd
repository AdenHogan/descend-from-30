extends Node

# PROGRESSION tiers 2 + 3 (docs/PROGRESSION.md):
#  - RUN BOONS: the first arrival at a milestone floor (27/22/17/12/7) owes this character a
#    pick-1-of-2 boon — offered by a HUD badge, never forced; it lasts until the time skip.
#  - DESCENT VALOUR: the end of a 3-run session scores each run's depth into Valour (profile) and
#    offers up to 3 perks ACQUIRED that session (random, unweighted); buy one to keep forever (max
#    10, tradeable). A permanent perk applies to every new game and leaves the temporary pools.
# Run: godot --headless res://tests/progression_test.tscn

var failures: int = 0
var _saved_slot := 1
var _saved := {}


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== progression test (run boons + descent valour) ===")
	_saved_slot = WorldState.active_slot
	_saved = {"valour": WorldState.valour, "perks": WorldState.permanent_perks.duplicate(),
		"offer": WorldState.valour_offer.duplicate(), "last": WorldState.last_valour.duplicate(true),
		"seed": WorldState._valour_scored_seed}
	_clear_valour()
	_test_milestones()
	_test_boon_offer_and_fold()
	_test_boons_are_per_character()
	_test_valour_maths()
	_test_session_perks()
	_test_finish_session_offer()
	_test_buy_and_permanence()
	_test_cap_and_trade()
	await _test_boon_ui()
	await _test_legacy_ui()
	await _test_game_over_screen()
	_test_journal_line()
	# Leave the profile exactly as we found it — no test purchases leak into real play / other suites.
	WorldState.use_slot(_saved_slot)
	WorldState.valour = _saved["valour"]
	WorldState.permanent_perks = _saved["perks"]
	WorldState.valour_offer = _saved["offer"]
	WorldState.last_valour = _saved["last"]
	WorldState._valour_scored_seed = _saved["seed"]
	WorldState.save_profile()
	get_tree().paused = false
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _test_milestones() -> void:
	print("[the first arrival at a milestone floor owes a boon — offered, not forced]")
	WorldState.new_game()
	var root := Node.new()
	add_child(root)
	WorldState.note_floor_arrival(root, 28)
	check(WorldState.pending_boon_floors.is_empty(), "an ordinary floor owes nothing")
	WorldState.note_floor_arrival(root, 27)
	check(WorldState.pending_boon_floors == [27], "floor 27 (a milestone) owes a boon")
	check(HUD.boon_badge.visible, "the HUD badge shows it's waiting")
	check(not get_tree().paused, "…and nothing paused the game on arrival")
	WorldState.note_floor_arrival(root, 27)
	check(WorldState.pending_boon_floors == [27], "coming back to 27 doesn't owe a second one")
	for f in Progression.BOON_MILESTONES:
		check(not (f in WorldState.MERCHANT_FLOORS), "milestone %d isn't a merchant floor" % f)
	root.queue_free()


func _test_boon_offer_and_fold() -> void:
	print("[pick one of two; it lifts the stats through the fold]")
	WorldState.new_game()
	WorldState.note_boon_milestone(22)
	var offer: Array = WorldState.boon_offer(22)
	check(offer.size() == 2 and offer[0] != offer[1], "two different boons offered (%s)" % str(offer))
	check(WorldState.boon_offer(22) == offer, "seeded — a reload offers the same pair")
	check(WorldState.take_boon(22, "B_not_offered") != "", "only the offered two can be taken")
	var before := {"speed": WorldState.get_move_speed_mult(), "stam": WorldState.get_max_stamina(),
		"regen": WorldState.get_stamina_regen_mult(), "dmg": WorldState.get_melee_damage_bonus()}
	var pick: String = offer[0]
	check(WorldState.take_boon(22, pick) == "", "taking %s works" % pick)
	check(pick in WorldState.run_boons and WorldState.pending_boon_floors.is_empty(), "it's this character's now; nothing waiting")
	var mods: Dictionary = Progression.boon(pick)["mods"]
	var moved := false
	moved = moved or (mods.has("move_speed") and WorldState.get_move_speed_mult() > before["speed"])
	moved = moved or (mods.has("max_stamina") and WorldState.get_max_stamina() > before["stam"])
	moved = moved or (mods.has("stamina_regen") and WorldState.get_stamina_regen_mult() > before["regen"])
	moved = moved or (mods.has("melee_damage") and WorldState.get_melee_damage_bonus() > before["dmg"])
	moved = moved or not (mods.has("move_speed") or mods.has("max_stamina") or mods.has("stamina_regen") or mods.has("melee_damage"))
	check(moved, "the boon reaches the stat getters")
	WorldState.run_boons = []
	WorldState.run_boons.append("B_adrenaline")
	check(is_equal_approx(WorldState.get_move_speed_mult(), before["speed"] * 1.20), "Adrenaline = ×1.20 move speed")
	WorldState.note_boon_milestone(17)
	check(not ("B_adrenaline" in WorldState.boon_offer(17)), "a boon you have is never offered again this run")
	WorldState.skip_boon(17)
	check(WorldState.pending_boon_floors.is_empty(), "passing clears the offer")


func _test_boons_are_per_character() -> void:
	print("[boons belong to THIS character — the time skip wipes them; a save keeps them]")
	WorldState.new_game()
	WorldState.run_boons = ["B_rage"]
	WorldState.note_boon_milestone(12)
	WorldState.save_game("res://scenes/hallway.tscn", false)
	WorldState.run_boons = []
	WorldState.pending_boon_floors = []
	WorldState.load_game()
	check(WorldState.run_boons == ["B_rage"] and WorldState.pending_boon_floors == [12], "a save keeps boons + a waiting offer")
	WorldState.delete_save()
	WorldState.advance_run()
	check(WorldState.run_boons.is_empty() and WorldState.pending_boon_floors.is_empty() and WorldState.run_milestones_seen.is_empty(),
		"the next character starts with none (and owes milestones afresh)")


func _clear_valour() -> void:
	WorldState.valour = 0
	WorldState.permanent_perks = []
	WorldState.valour_offer = []
	WorldState.last_valour = {}
	WorldState._valour_scored_seed = 0


func _test_valour_maths() -> void:
	print("[Valour per run: depth, weighted toward the bottom, + a bonus for walking out]")
	check(Progression.valour_for_run(30, false) == 0, "never left floor 30 → 0")
	check(Progression.valour_for_run(25, false) == 5, "5 floors → 5")
	check(Progression.valour_for_run(15, false) == 18, "15 floors → 15 + 3 = 18")
	check(Progression.valour_for_run(10, false) == 26, "20 floors → 20 + 6 = 26")
	check(Progression.valour_for_run(0, true) == 55, "escaped → 30 + 15 + 10 = 55")
	var prev := -1
	var mono := true
	for f in range(30, -1, -1):
		var v := Progression.valour_for_run(f, false)
		mono = mono and v > prev
		prev = v
	check(mono, "every floor deeper is worth strictly more")


func _test_session_perks() -> void:
	print("[the session records every perk acquired — merchant AND boons, across all 3 runs]")
	WorldState.new_game()
	check(WorldState.session_perks.is_empty(), "a new game starts with none")
	WorldState.resolve_upgrade_offer(25, "U_slot")
	WorldState.note_boon_milestone(27)
	var b: String = WorldState.boon_offer(27)[0]
	WorldState.take_boon(27, b)
	check("U_slot" in WorldState.session_perks and b in WorldState.session_perks, "merchant pick + boon both recorded")
	WorldState.advance_run()
	check(b in WorldState.session_perks, "the time skip wipes the boon from the character, NOT from the session record")
	WorldState.save_game("res://scenes/hallway.tscn", false)
	WorldState.session_perks = []
	WorldState.load_game()
	check("U_slot" in WorldState.session_perks and b in WorldState.session_perks, "saved with the game")
	WorldState.delete_save()
	WorldState.new_game()
	check(WorldState.session_perks.is_empty(), "…and a new game clears it")


func _finish(depths: Array, outcomes: Array, perks: Array) -> Dictionary:
	WorldState.new_game()
	for i in 3:
		WorldState.run_chronicle[i]["deepest_floor"] = depths[i]
		WorldState.set_run_outcome(i + 1, outcomes[i])
	for id in perks:
		WorldState.note_perk_acquired(id)
	return WorldState.finish_session()


func _test_finish_session_offer() -> void:
	print("[the session's end: Valour banked to the profile + up to 3 of ITS perks offered]")
	_clear_valour()
	var res := _finish([15, 10, 0], ["dead", "dead", "survived"], ["U_slot", "U_melee_s", "B_rage", "U_quiet_s", "B_eye"])
	check(int(res["total"]) == 18 + 26 + 55, "18 + 26 + 55 = %d" % int(res["total"]))
	check(WorldState.valour == 99, "banked")
	check(WorldState.valour_offer.size() == Progression.OFFER_COUNT, "3 offered")
	var ok := true
	for id in WorldState.valour_offer:
		ok = ok and id in ["U_slot", "U_melee_s", "B_rage", "U_quiet_s", "B_eye"]
	check(ok, "only perks acquired this session (%s)" % str(WorldState.valour_offer))
	check(WorldState.finish_session()["total"] == 99 and WorldState.valour == 99, "scoring twice never banks twice")
	WorldState.load_profile()
	check(WorldState.valour == 99 and WorldState.valour_offer.size() == 3, "Valour + the offer live in the PROFILE")
	# Uniform (no weighting): over many rolls every acquired perk turns up about equally often.
	var counts := {}
	for n in 300:
		WorldState._valour_scored_seed = 0
		WorldState.last_valour = {}
		WorldState.finish_session()
		for id in WorldState.valour_offer:
			counts[id] = int(counts.get(id, 0)) + 1
	var lo := 999
	var hi := 0
	for id in counts:
		lo = mini(lo, counts[id])
		hi = maxi(hi, counts[id])
	check(counts.size() == 5 and lo > 120 and hi < 240, "unweighted draw (each ≈180/300: %s)" % str(counts))
	_clear_valour()
	_finish([29, 30, 30], ["dead", "dead", "dead"], ["U_speed_s"])
	check(WorldState.valour_offer == ["U_speed_s"], "one perk acquired → one offered")
	_clear_valour()
	_finish([29, 30, 30], ["dead", "dead", "dead"], [])
	check(WorldState.valour_offer.is_empty() and WorldState.valour == 1, "nothing acquired → no offer, Valour still banked")
	_clear_valour()


func _test_buy_and_permanence() -> void:
	print("[buy one → it's on for every new game, and gone from the temporary pools]")
	_clear_valour()
	_finish([0, 0, 0], ["survived", "survived", "survived"], ["U_slot"])
	check(WorldState.valour == 165, "three escapes = 165")
	WorldState.valour = 50
	check(WorldState.buy_permanent("U_slot").contains("110"), "too poor: Deep Pockets costs 110")
	WorldState.valour = 165
	check(WorldState.buy_permanent("U_melee_s") != "", "only what's on offer can be bought")
	check(WorldState.buy_permanent("U_slot") == "" and WorldState.valour == 55, "bought (165 − 110 = 55)")
	check(WorldState.valour_offer.is_empty(), "one purchase per session — the offer closes")
	WorldState.new_game()
	check(WorldState.get_inventory_slots() == WorldState.MAX_INVENTORY_SLOTS + 1, "a NEW game starts with the extra slot unlocked")
	var in_pool := false
	for f in [25, 20, 15, 10, 5]:
		in_pool = in_pool or "U_slot" in WorldState.get_upgrade_pair(f)
	for r in 3:
		WorldState.current_run = r + 1
		WorldState.upgrade_offers.clear()
		for f in [25, 20, 15, 10, 5]:
			in_pool = in_pool or "U_slot" in WorldState.get_upgrade_pair(f)
	check(not in_pool, "Deep Pockets never shows at the merchant again")
	WorldState.permanent_perks.append("B_rage")
	var boon_seen := false
	for f in Progression.BOON_MILESTONES:
		boon_seen = boon_seen or "B_rage" in WorldState.boon_offer(f)
	check(not boon_seen, "a permanent boon leaves the boon pool too")
	check(WorldState.get_melee_damage_bonus() >= 2, "…and applies (Rage +2 melee)")
	WorldState.load_profile()
	check(WorldState.permanent_perks == ["U_slot"], "saved in the profile (the unsaved test add is gone)")
	# Never offered what you already keep.
	WorldState.last_valour = {}
	WorldState._valour_scored_seed = 0
	WorldState.note_perk_acquired("U_slot")
	WorldState.note_perk_acquired("U_heal")
	WorldState.finish_session()
	check(WorldState.valour_offer == ["U_heal"], "a perk you already keep is never offered")
	WorldState.decline_valour_offer()
	check(WorldState.valour_offer.is_empty() and WorldState.valour == 55, "declining keeps the Valour for later")
	_clear_valour()


func _test_cap_and_trade() -> void:
	print("[10 kept at most — a new one means trading one out; the collection trades out too]")
	_clear_valour()
	WorldState.permanent_perks = ["U_stam_s", "U_stam_m", "U_regen_s", "U_sprint_s", "U_speed_s",
		"U_melee_s", "U_push", "U_head_s", "U_acc", "U_listen"]
	WorldState.valour_offer = ["U_heal"]
	WorldState.valour = 100
	check(WorldState.buy_permanent("U_heal").contains("full"), "full: must pick one to trade out")
	check(WorldState.buy_permanent("U_heal", "U_heal_nope") != "", "…one you actually hold")
	var refund := Progression.trade_refund("U_stam_s")
	check(WorldState.buy_permanent("U_heal", "U_stam_s") == "", "traded Second Wind for Field Medic")
	check(WorldState.permanent_perks.size() == 10 and "U_heal" in WorldState.permanent_perks and not ("U_stam_s" in WorldState.permanent_perks), "still 10, swapped")
	check(WorldState.valour == 100 + refund - Progression.perk_cost("U_heal"), "refund %d, cost %d" % [refund, Progression.perk_cost("U_heal")])
	var before := WorldState.valour
	check(WorldState.trade_out_permanent("U_push") == Progression.trade_refund("U_push") and WorldState.valour > before, "trading out from the collection refunds part")
	check(WorldState.permanent_perks.size() == 9, "…and frees a slot")
	_clear_valour()


func _test_boon_ui() -> void:
	print("[the badge opens the choice; choosing resumes play]")
	WorldState.new_game()
	WorldState.note_boon_milestone(27)
	get_tree().paused = false
	HUD.open_boon_offer()
	var ui = HUD.boon_ui
	check(ui != null and ui.visible and get_tree().paused, "the offer opens and pauses")
	var pick: String = WorldState.boon_offer(27)[1]
	check(ui.choose(pick) == "" and pick in WorldState.run_boons, "choosing takes the boon")
	check(not ui.visible and not get_tree().paused and not HUD.boon_badge.visible, "…closes, resumes play, clears the badge")
	await get_tree().process_frame


func _test_legacy_ui() -> void:
	print("[the profile screen's LEGACY panel: collection + trade out]")
	var ps = load("res://scenes/profile_select.tscn").instantiate()
	add_child(ps)
	await get_tree().process_frame
	check(ps.get_node_or_null("Nav/LegacyButton") != null, "the profile screen has a LEGACY button")
	ps.set("_selected", _saved_slot)       # stay on the slot whose profile we restore at the end
	WorldState.permanent_perks = ["U_quiet_s", "B_eye"]
	WorldState.valour = 0
	WorldState.save_profile()
	ps.open_legacy()
	var ui = ps.get("_legacy_ui")
	check(ui != null and ui.visible and ui.tab == "collection", "it opens on the collection (no offer waiting)")
	check(ui.trade_out("B_eye") == 0 and "B_eye" in WorldState.permanent_perks, "first press only arms the trade")
	check(ui.trade_out("B_eye") > 0 and not ("B_eye" in WorldState.permanent_perks), "second press trades it out")
	ui.close()
	get_tree().paused = false
	ps.queue_free()
	_clear_valour()
	await get_tree().process_frame


func _test_game_over_screen() -> void:
	print("[the end-of-session screen shows the Valour and opens the offer]")
	_clear_valour()
	_finish([12, 20, 0], ["dead", "dead", "survived"], ["U_slot", "B_rage", "U_heal"])
	WorldState.valour = 500
	var go = load("res://scenes/game_over.tscn").instantiate()
	add_child(go)
	await get_tree().process_frame
	var txt := ""
	for c in go.find_children("*", "Label", true, false):
		txt += c.text + "\n"
	check(txt.contains("DESCENT VALOUR") and txt.contains("+%d" % int(WorldState.last_valour["total"])), "the Valour total is on screen")
	go.open_legacy()
	var ui = go.legacy_ui
	check(ui != null and ui.visible and ui.tab == "offer", "the offer tab opens")
	var pick: String = WorldState.valour_offer[0]
	check(ui.buy(pick) == "" and pick in WorldState.permanent_perks and ui.tab == "collection", "buying from the screen keeps it (→ collection)")
	ui.close()
	get_tree().paused = false
	go.queue_free()
	_clear_valour()
	# Full collection from the UI: first press asks which to trade out, then trades.
	WorldState.permanent_perks = ["U_stam_s", "U_stam_m", "U_regen_s", "U_sprint_s", "U_speed_s",
		"U_melee_s", "U_push", "U_head_s", "U_acc", "U_listen"]
	WorldState.valour_offer = ["U_heal"]
	WorldState.valour = 100
	var ui2 = preload("res://scripts/legacy_ui.gd").new()
	add_child(ui2)
	ui2.open()
	check(ui2.buy("U_heal") == "full" and not ("U_heal" in WorldState.permanent_perks), "full → asks for a trade first")
	check(ui2.buy("U_heal", "U_push") == "" and "U_heal" in WorldState.permanent_perks and not ("U_push" in WorldState.permanent_perks), "picking one trades it for the new perk")
	ui2.close()
	ui2.queue_free()
	get_tree().paused = false
	_clear_valour()
	await get_tree().process_frame


func _test_journal_line() -> void:
	print("[the journal shows this run's boons + the permanent perks]")
	WorldState.run_boons = ["B_rage"]
	WorldState.permanent_perks = ["U_heal"]
	var txt: String = load("res://scripts/character_panel.gd").progression_bbcode()
	check(txt.contains("Rage") and txt.contains("Legacy: Field Medic"), "listed (%s)" % txt.replace("\n", " "))
	WorldState.run_boons = []
	WorldState.permanent_perks = []
