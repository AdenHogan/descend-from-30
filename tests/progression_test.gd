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
		"seed": WorldState._valour_scored_seed, "carry": WorldState.carry_items.duplicate(true)}
	_clear_valour()
	_test_milestones()
	_test_boon_offer_and_fold()
	_test_boons_are_per_character()
	_test_valour_maths()
	_test_session_perks()
	_test_finish_session_offer()
	_test_buy_and_permanence()
	_test_cap_and_trade()
	_test_quest_valour()
	_test_handoff_in_session()
	_test_handoff_next_game()
	await _test_handoff_shop_gift()
	await _test_handoff_ui()
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
	WorldState.carry_items = _saved["carry"]
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
	# Every boon already kept permanently → a milestone owes nothing (no empty badge to dismiss).
	var kept := WorldState.permanent_perks.duplicate()
	WorldState.permanent_perks = Progression.RUN_BOONS.keys()
	WorldState.note_boon_milestone(12)
	check(WorldState.pending_boon_floors.is_empty(), "nothing left to offer → no badge")
	WorldState.permanent_perks = kept


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
	WorldState.carry_items = []


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
	check(Progression.valour_for_run(15, false, 2, 1) == 18 + 16 + 4, "quests (+8 each) and NPCs aided (+4 each) add on")
	check(Progression.valour_for_run(0, true, 0, 0, 95) == 55 + 95, "the kit scrapped at the door adds on")
	check(Progression.valour_for_run(10, false, 0, 0, 95) == 26, "…only for a character who actually walked out")
	print("[THE DOOR: every weapon melts for its worth; leaving one forfeits it AND the brave bonus]")
	var lv4 := _hammer_lv3()
	lv4.level = 4
	var lv1 := ItemInstance.new()
	lv1.setup("001")
	var junk := ItemInstance.new()
	junk.setup("024")
	check(Progression.door_worth(lv4) == Progression.DOOR_WORTH[4] and Progression.door_worth(lv1) == Progression.DOOR_WORTH[1]
		and Progression.door_worth(junk) == 0, "worth by level; junk melts for nothing")
	var kit := [lv4, lv1, junk]
	var all_v: int = Progression.door_valour(kit, -1)
	check(all_v == Progression.DOOR_BRAVE_BONUS + Progression.DOOR_WORTH[4] + Progression.DOOR_WORTH[1], "scrap it all: bonus + every weapon (%d)" % all_v)
	check(Progression.door_valour(kit, 0) == Progression.DOOR_WORTH[1], "keep the legendary: only the knife melts (%d)" % Progression.door_valour(kit, 0))
	check(all_v - Progression.door_valour(kit, 0) == Progression.DOOR_BRAVE_BONUS + Progression.DOOR_WORTH[4],
		"the price of keeping it = its worth + the brave bonus")
	var heir := _hammer_lv3()
	heir.level = 5
	heir.forge_paid = 100
	check(Progression.door_worth(heir) == Progression.DOOR_WORTH[5] + 20, "an heirloom counts a share of the scrap already put in (+20)")
	var worths: Array = []
	for l in range(1, 8):
		worths.append(Progression.DOOR_WORTH[l])
	var rising := true
	for i in range(1, worths.size()):
		rising = rising and worths[i] > worths[i - 1]
	check(rising, "every level is worth more at the door")
	print("[the session score counts what each escape scrapped at the door]")
	_clear_valour()
	WorldState.new_game()
	for i in 3:
		WorldState.run_chronicle[i]["deepest_floor"] = 0
		WorldState.set_run_outcome(i + 1, "survived")
	WorldState.current_run = 2
	WorldState.inventory = [lv4, lv1]
	var door2: int = WorldState.note_door_scrap(true)
	check(door2 == all_v and WorldState.chronicle_entry(2)["braved"], "run 2 braved: its kit scrapped for %d" % door2)
	WorldState.current_run = 3
	WorldState.inventory = [lv1]
	check(WorldState.note_door_scrap(false) == Progression.DOOR_WORTH[1], "run 3 left something: the rest melts, no bonus")
	var s: Dictionary = WorldState.finish_session()
	check(int(s.get("total", -1)) == 3 * 55 + door2 + Progression.DOOR_WORTH[1], "3 escapes + the door (got %s)" % str(s.get("total")))
	var old := WorldState._blank_chronicle_entry()
	old.erase("door_valour")
	old["braved"] = true
	check(WorldState._door_valour_of(old) == Progression.DOOR_BRAVE_BONUS, "an older save's braved escape scores the bonus")
	_clear_valour()
	WorldState.save_profile()


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
	WorldState.valour = 165
	check(WorldState.buy_permanent("U_slot").contains("550"), "too poor: Deep Pockets costs 550 — a goal across games")
	WorldState.valour = 600
	check(WorldState.buy_permanent("U_melee_s") != "", "only what's on offer can be bought")
	check(WorldState.buy_permanent("U_slot") == "" and WorldState.valour == 50, "bought (600 − 550 = 50)")
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
	check(WorldState.valour_offer.is_empty() and WorldState.valour == 50, "declining keeps the Valour for later")
	_clear_valour()


func _test_cap_and_trade() -> void:
	print("[10 kept at most — a new one means trading one out; the collection trades out too]")
	_clear_valour()
	WorldState.permanent_perks = ["U_stam_s", "U_stam_m", "U_regen_s", "U_sprint_s", "U_speed_s",
		"U_melee_s", "U_push", "U_head_s", "U_acc", "U_listen"]
	WorldState.valour_offer = ["U_heal"]
	WorldState.valour = 1000
	check(WorldState.buy_permanent("U_heal").contains("full"), "full: must pick one to trade out")
	check(WorldState.buy_permanent("U_heal", "U_heal_nope") != "", "…one you actually hold")
	var refund := Progression.trade_refund("U_stam_s")
	check(WorldState.buy_permanent("U_heal", "U_stam_s") == "", "traded Second Wind for Field Medic")
	check(WorldState.permanent_perks.size() == 10 and "U_heal" in WorldState.permanent_perks and not ("U_stam_s" in WorldState.permanent_perks), "still 10, swapped")
	check(WorldState.valour == 1000 + refund - Progression.perk_cost("U_heal"), "refund %d, cost %d" % [refund, Progression.perk_cost("U_heal")])
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


func _test_quest_valour() -> void:
	print("[quests completed + NPCs aided count toward the session's Valour]")
	_clear_valour()
	WorldState.new_game()
	WorldState.note_quest_completed()
	WorldState.note_npc_aided()
	WorldState.note_npc_aided()
	WorldState.current_run = 2
	WorldState.note_quest_completed()
	for i in 3:
		WorldState.run_chronicle[i]["deepest_floor"] = 30
		WorldState.set_run_outcome(i + 1, "dead")
	var res: Dictionary = WorldState.finish_session()
	check(int(res["total"]) == 8 + 4 + 4 + 8, "run 1: a quest + 2 aided, run 2: a quest → 24 (%d)" % int(res["total"]))
	check(int(res["runs"][0]["quests"]) == 1 and int(res["runs"][0]["npcs"]) == 2, "the breakdown carries the counts")
	_clear_valour()


func _hammer_lv3() -> ItemInstance:
	var h := ItemInstance.new()
	h.setup("002")
	h.level = 3
	h.perks = ["H_heavy", "H_sweep"]
	h.current_durability = 7
	return h


func _test_handoff_in_session() -> void:
	print("[THE DOOR: a left item is stashed for the NEXT GAME — never this session's next characters]")
	_clear_valour()
	WorldState.new_game()
	var key := ItemInstance.new()
	key.setup_key("022", "2903")
	var notes := ItemInstance.new()
	notes.setup("033")
	var h := _hammer_lv3()
	WorldState.inventory = [key, notes, h]
	check(WorldState.handoff_candidates() == [2], "keys and cash can't be handed on (%s)" % str(WorldState.handoff_candidates()))
	check(WorldState.leave_for_next(0) == "", "…refused for a key")
	check(WorldState.leave_for_next(2) == "Hammer Lv3" and WorldState.inventory.size() == 2, "the hammer is left behind")
	check(WorldState.chronicle_entry(1)["left_behind"] == "Hammer Lv3", "the chronicle remembers it")
	check(not WorldState.handoff_pending(), "NOT with this game's shopkeeper")
	check(WorldState.carry_items.is_empty() and WorldState.door_stash_pending.size() == 1,
		"not in the profile until the exit is committed (a quit mid-card can't duplicate it)")
	WorldState.set_run_outcome(1, "survived")
	WorldState.advance_run()
	WorldState.commit_door_stash()
	check(WorldState.door_stash_pending.is_empty() and WorldState.carry_items.size() == 1, "committed → the profile's stash")
	check(WorldState.inventory.is_empty() and not WorldState.handoff_pending(), "character 2 doesn't get it — not in pockets, not at the shop")
	WorldState.advance_run()
	check(not WorldState.handoff_pending(), "…nor character 3")
	WorldState.carry_items = []
	WorldState.load_profile()
	check(WorldState.carry_items.size() == 1, "the stash survives in the profile")
	WorldState.new_game()
	check(WorldState.handoff_pending() and WorldState.carry_items.is_empty(), "the NEXT game's shopkeeper has it")
	var res: Dictionary = WorldState.collect_handoff_gifts()
	check(res["given"] == ["Hammer Lv3"] and not WorldState.handoff_pending(), "collected from the shopkeeper")
	var got = WorldState.inventory[0]
	check(got.item_id == "002" and got.level == 3 and got.perks == ["H_heavy", "H_sweep"] and got.current_durability == 7,
		"same hammer: Lv3, its perks, its wear")
	check(WorldState.collect_handoff_gifts()["given"].is_empty(), "…only once")
	print("[full pockets: the shopkeeper keeps it — never lost]")
	WorldState.handoff_items = [WorldState.instance_to_dict(_hammer_lv3())]
	WorldState.inventory = []
	for i in WorldState.get_inventory_slots():
		var j := ItemInstance.new()
		j.setup("024")
		WorldState.inventory.append(j)
	res = WorldState.collect_handoff_gifts()
	check(res["given"].is_empty() and res["kept"] == ["Hammer Lv3"] and WorldState.handoff_pending(), "no room → kept for later")
	WorldState.inventory.remove_at(0)
	check(WorldState.collect_handoff_gifts()["given"] == ["Hammer Lv3"], "room made → handed over")
	print("[two escapes in a session → both stashed for the next game]")
	WorldState.carry_items = []
	WorldState.inventory = [_hammer_lv3(), _hammer_lv3()]
	WorldState.leave_for_next(0)
	WorldState.commit_door_stash()
	WorldState.leave_for_next(0)
	WorldState.commit_door_stash()
	check(WorldState.carry_items.size() == 2 and WorldState.handoff_items.is_empty(), "both stashed, none this game")
	print("[quit mid-card: an uncommitted stash is dropped on a load — the item is still in that save's pockets]")
	WorldState.carry_items = []
	WorldState.inventory = [_hammer_lv3()]
	WorldState.save_game("res://scenes/lobby.tscn", false)
	WorldState.leave_for_next(0)
	WorldState.load_game()
	WorldState.delete_save()
	check(WorldState.door_stash_pending.is_empty() and WorldState.carry_items.is_empty(), "not stashed")
	check(WorldState.inventory.size() == 1 and WorldState.inventory[0].item_id == "002", "still in the pockets — never duplicated, never lost")
	_clear_valour()
	WorldState.save_profile()


func _test_handoff_next_game() -> void:
	print("[escaping the THIRD run: the shopkeeper keeps it for the next game (and anything unclaimed)]")
	_clear_valour()
	WorldState.new_game()
	WorldState.current_run = 3
	WorldState.inventory = [_hammer_lv3()]
	WorldState.leave_for_next(0)
	WorldState.commit_door_stash()
	check(not WorldState.handoff_pending() and WorldState.carry_items.size() == 1, "it waits in the PROFILE, not this game")
	WorldState.carry_items = []
	WorldState.load_profile()
	check(WorldState.carry_items.size() == 1, "saved in the profile")
	WorldState.new_game()
	check(WorldState.inventory.is_empty() and WorldState.handoff_pending(), "the next game's shopkeeper has it (not the pockets)")
	check(WorldState.carry_items.is_empty(), "moved out of the profile…")
	WorldState.load_profile()
	check(WorldState.carry_items.is_empty(), "…for good (no second copy next game)")
	print("[an UNCLAIMED gift when the session ends goes to the next game — never lost]")
	for i in 3:
		WorldState.run_chronicle[i]["deepest_floor"] = 30
		WorldState.set_run_outcome(i + 1, "dead")
	WorldState.finish_session()
	check(not WorldState.handoff_pending() and WorldState.carry_items.size() == 1, "unclaimed → carried to the next game")
	WorldState.new_game()
	check(WorldState.handoff_pending(), "…and the next game's shopkeeper has it")
	WorldState.new_game()
	check(not WorldState.handoff_pending(), "a later new game has nothing (collected or not, it moved once)")
	_clear_valour()
	WorldState.save_profile()


func _test_handoff_shop_gift() -> void:
	print("[the shop: greeting hints at it; after the visit's upgrade pick, it's given free]")
	WorldState.new_game()
	WorldState.handoff_items = [WorldState.instance_to_dict(_hammer_lv3())]
	WorldState.inventory = []
	WorldState.current_floor = 25
	var shop = load("res://scenes/shop_ui.tscn").instantiate()
	add_child(shop)
	await get_tree().process_frame
	shop.open(25, "Well, look who it is.")
	check(shop.dialogue_label.text.contains("left something"), "the greeting hints something's waiting")
	check(WorldState.inventory.is_empty(), "…but nothing before the upgrade is settled")
	shop._show_tab("shop")                              # peeking at the shop first doesn't release it
	check(WorldState.inventory.is_empty() and WorldState.handoff_pending(), "no gift until the upgrade is resolved")
	var pair: Array = WorldState.get_upgrade_pair(25)
	shop._on_take_upgrade(pair[0])
	check(WorldState.inventory.size() == 1 and WorldState.inventory[0].level == 3, "after the upgrade pick: the hammer, free")
	check(shop.dialogue_label.text.contains("No charge"), "the shopkeeper says so (%s)" % shop.dialogue_label.text)
	check(not WorldState.handoff_pending(), "nothing left waiting")
	shop.close()
	shop._show_tab("shop")
	check(WorldState.inventory.size() == 1, "re-opening doesn't hand out a second one")
	shop.queue_free()
	await get_tree().process_frame


func _test_handoff_ui() -> void:
	print("[the handoff panel: pick one, or leave nothing — it never leaves the exit waiting]")
	WorldState.new_game()
	WorldState.inventory = [_hammer_lv3()]
	var ui = preload("res://scripts/handoff_ui.gd").new()
	add_child(ui)
	var got := [-99]
	ui.decided.connect(func(s): got[0] = s)
	ui.open()
	check(ui.visible and get_tree().paused, "it opens and pauses")
	ui.close()                                   # ESC / ✕
	check(got[0] == -1 and not ui.visible and not get_tree().paused, "closing = take everything (-1), play resumes")
	ui.choose(0)
	check(got[0] == -1, "it answers only once")
	ui.queue_free()
	var ui2 = preload("res://scripts/handoff_ui.gd").new()
	add_child(ui2)
	ui2.decided.connect(func(s): got[0] = s)
	ui2.open()
	ui2.choose(0)
	check(got[0] == 0, "picking an item reports its slot")
	ui2.queue_free()
	get_tree().paused = false
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
	WorldState.valour = 2000
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
	WorldState.valour = 1000
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
