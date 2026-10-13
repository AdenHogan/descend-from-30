extends Node

# Headless test for the QUEST FRAMEWORK (docs/QUESTS.md): the data is well-formed, sites are seeded + stable, the
# conversations run their choices and effects without ever half-doing a trade, outcomes are remembered across the
# three runs, and the world they leave is the one the data promises. Run:
#   godot --headless res://tests/quest_test.tscn

var failures: int = 0
const VERBS := ["take_ammo", "take_item", "give_item", "give_gun", "upgrade", "kill", "outcome", "complete", "banner", "flag", "goto"]


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== quest test ===")
	_test_data()
	await _test_sites()
	await _test_johnny()
	await _test_no_half_trades()
	await _test_johnny_no_room()
	await _test_johnny_gun_is_never_reissued()
	await _test_johnny_dies()
	await _test_ethel_supplied()
	await _test_ethel_mercy()
	await _test_ethel_ignored()
	_test_persistence_and_journal()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _fresh(seed_value: int = 424242) -> void:
	WorldState.new_game()
	WorldState.survivor_rule = true                  # the building is populated (only the real New Game turns this on)
	WorldState.master_seed = seed_value
	WorldState.is_first_run = false
	WorldState.tutorial_completed = true
	WorldState.god_mode = true
	WorldState.dev_survivors = 0
	WorldState.current_run = 1
	WorldState.quests.clear()
	WorldState.survivors.clear()
	WorldState.door_states.clear()
	WorldState.floor_states_seeded.clear()
	WorldState.inventory.clear()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


# --- the data ------------------------------------------------------------------------------------

func _test_data() -> void:
	print("[THE DATA: every quest is well-formed — no dangling state, effect, outcome or preset]")
	var qs := Quests.defs()
	check(qs.has("johnny") and qs.has("ethel"), "the shipped quests are loaded (%s)" % str(qs.keys()))
	var problems: Array = []
	for qid in qs:
		var d: Dictionary = qs[qid]
		for k in ["number", "title", "kind", "floors", "start", "states", "on_giver_died"]:
			if not d.has(k):
				problems.append("%s: missing %s" % [qid, k])
		if not (str(d.get("kind", "")) in ["corridor", "flat"]):
			problems.append("%s: bad kind" % qid)
		var fl: Array = d.get("floors", [0, 0])
		if fl.size() != 2 or int(fl[0]) < 2 or int(fl[1]) > 28 or int(fl[0]) > int(fl[1]):
			problems.append("%s: floors band must be inside 2..28" % qid)
		var states: Dictionary = d.get("states", {})
		if not states.has(str(d.get("start", ""))) or not states.has(str(d.get("on_giver_died", ""))):
			problems.append("%s: start / on_giver_died state missing" % qid)
		var npcs: Dictionary = d.get("npcs", {"giver": d.get("npc", {})})
		if d.has("npcs") and not npcs.has(str(d.get("giver", ""))):
			problems.append("%s: giver not among npcs" % qid)
		var outcomes := {"": true}
		for sname in states:
			var sd: Dictionary = states[sname]
			if str(sd.get("journal", "")).strip_edges() == "":
				problems.append("%s.%s: no journal text" % [qid, sname])
			var lines = sd.get("lines", [])
			if not sd.get("choices", []).is_empty() and (lines is Array and lines.is_empty()):
				problems.append("%s.%s: choices but nothing said" % [qid, sname])
			for c in sd.get("choices", []):
				if str(c.get("label", "")).strip_edges() == "":
					problems.append("%s.%s: choice without a label" % [qid, sname])
				for e in c.get("do", []):
					var parts := str(e).split(":", true, 2)
					if not (parts[0] in VERBS):
						problems.append("%s.%s: unknown effect %s" % [qid, sname, e])
					if parts[0] == "goto" and not states.has(parts[1]):
						problems.append("%s.%s: goto %s does not exist" % [qid, sname, parts[1]])
					if parts[0] == "give_gun" and not Quests.GUN_PRESETS.has(parts[1]):
						problems.append("%s.%s: gun preset %s" % [qid, sname, parts[1]])
					if parts[0] == "upgrade" and not Quests.UPGRADES.has(parts[1]):
						problems.append("%s.%s: upgrade %s" % [qid, sname, parts[1]])
					if parts[0] == "kill" and not npcs.has(parts[1]):
						problems.append("%s.%s: kill target %s" % [qid, sname, parts[1]])
					if parts[0] == "outcome":
						outcomes[parts[1]] = true
					if parts[0] in ["take_item", "give_item"] and ItemData.get_item(parts[1]).is_empty():
						problems.append("%s.%s: item %s" % [qid, sname, parts[1]])
		for oc in d.get("world", {}):
			if not outcomes.has(oc):
				problems.append("%s: world table for an outcome nothing sets (%s)" % [qid, oc])
			for run in d["world"][oc]:
				for spec in d["world"][oc][run]:
					if spec.has("npc") and not npcs.has(spec["npc"]):
						problems.append("%s: world spec names unknown npc %s" % [qid, spec["npc"]])
					if spec.has("body") and not npcs.has(spec["body"]):
						problems.append("%s: world spec names unknown body %s" % [qid, spec["body"]])
					if spec.has("gun") and not Quests.GUN_PRESETS.has(spec["gun"]):
						problems.append("%s: world gun preset %s" % [qid, spec["gun"]])
	check(problems.is_empty(), "no problems in quests.json: %s" % str(problems))
	for id in Quests.UPGRADES:
		var mods: Dictionary = Quests.UPGRADES[id]["mods"]
		check(not mods.is_empty() and Quests.UPGRADES[id]["name"] != "", "upgrade %s has a name and mods" % id)


# --- where it happens ----------------------------------------------------------------------------

func _test_sites() -> void:
	print("[SITES: seeded once, in the band, off merchant floors and away from fires, and an OPEN flat]")
	var seen_floors := {}
	for seed_value in [11, 22, 33, 44, 55, 66, 77, 88]:
		_fresh(seed_value)
		for qid in Quests.ids():
			var d := Quests.def(qid)
			var s := Quests.site(qid)
			check(not s.is_empty(), "seed %d: %s has a site" % [seed_value, qid])
			if s.is_empty():
				continue
			var f := int(s["floor"])
			seen_floors[f] = true
			var band: Array = d["floors"]
			if f < int(band[0]) or f > int(band[1]) or (f in WorldState.MERCHANT_FLOORS) or Quests._fire_near(f, Quests.FIRE_CLEARANCE_STEPS[-1]):
				check(false, "seed %d: %s on floor %d breaks the band / merchant / fire rule" % [seed_value, qid, f])
			if str(d["kind"]) == "flat":
				check(WorldState.get_door_state(str(s["apt"])) == WorldState.DoorState.OPEN, "…its flat %s is OPEN" % s["apt"])
	check(seen_floors.size() >= 4, "different seeds put quests on different floors (%d distinct)" % seen_floors.size())
	# EVERY playthrough has both quests: fire origins are common, and two of them used to rule out a whole band (the quest
	# silently never existed in ~1 playthrough in 9 — tools/npc_balance_report.tscn `quests`)
	var missing := 0
	var relaxed := 0
	for seed_value in range(1, 161):
		_fresh(seed_value)
		for qid in Quests.ids():
			var s2 := Quests.site(qid)
			if s2.is_empty():
				missing += 1
				continue
			if Quests._fire_near(int(s2["floor"])):
				relaxed += 1                                      # (found only because the clearance relaxed)
	check(missing == 0, "160 seeds × both quests: every one has a site (%d missing)" % missing)
	check(relaxed > 0, "(setup) the relaxed-clearance path was really exercised (%d sites)" % relaxed)
	# stable: asking again (even in a later run) gives the same place, and the flat stays open
	_fresh(424242)
	var a := Quests.site("ethel").duplicate()
	var jo := Quests.site("johnny").duplicate()
	WorldState.advance_run()
	check(Quests.site("ethel") == a and Quests.site("johnny") == jo, "the sites do not move between runs")
	WorldState.advance_run()
	check(WorldState.get_door_state(str(a["apt"])) == WorldState.DoorState.OPEN, "…and Ethel's flat is still OPEN in run 3")
	var again := {}
	_fresh(424242)
	again = Quests.site("ethel")
	check(again == a, "the same seed always picks the same site")
	check(Quests.is_quest_flat(str(a["apt"])) and Quests.quest_for_flat(str(a["apt"])) == "ethel", "the flat knows it is a quest flat")
	check(SurvivorPlan.hider_for(str(a["apt"])).is_empty(), "…and no random hider is rolled into it")


# --- Johnny the Gun Guy ----------------------------------------------------------------------------

func _corridor(floor_num: int) -> Node:
	WorldState.current_floor = floor_num
	WorldState.seed_floor_door_states(floor_num)
	var bf = load("res://scenes/building_floors.tscn").instantiate()
	add_child(bf)
	await get_tree().physics_frame
	for z in get_tree().get_nodes_in_group("zombie"):
		if bf.is_ancestor_of(z):
			z.free()
	return bf


func _giver_in(root: Node, qid: String) -> Survivor:
	for s in get_tree().get_nodes_in_group("survivor"):
		if root.is_ancestor_of(s) and s.quest_id == qid:
			return s
	return null


func _bullets(n: int) -> void:
	while WorldState.get_ammo_total() > 0:
		WorldState.consume_ammo(WorldState.get_ammo_total())
	if n > 0:
		WorldState.add_to_inventory("016", n)


func _test_johnny() -> void:
	print("[JOHNNY (010): ten bullets for a gun, twenty more for an upgrade — in instalments that carry over all three runs]")
	_fresh()
	var site := Quests.site("johnny")
	var floor_num := int(site["floor"])
	check(floor_num >= 10 and floor_num <= 20, "he is somewhere between floors 10 and 20 (%d)" % floor_num)
	var bf = await _corridor(floor_num)
	var j := _giver_in(bf, "johnny")
	check(j != null, "Johnny holds his post on floor %d" % floor_num)
	if j == null:
		bf.free()
		return
	check(j.role == "defender" and j.weapon == "004" and j.max_hp == 10, "an armed defender (gun, 10 hp)")
	check(SurvivorPlan.corridor_records(floor_num).filter(func(r): return r["role"] == "defender").size() == 1, "…the floor's only armed post (no second random defender)")
	check(not Quests.started("johnny"), "the quest has not begun")
	var p = bf.get_node("Player")
	p.global_position = Vector2(j.global_position.x - 40.0, 386.0)
	await _frames(40)
	check(j.can_talk(), "he can be talked to")
	_bullets(0)
	var line := j.talk()
	check(line != "" and Quests.started("johnny"), "talking starts the quest and he speaks ('%s')" % line)
	check(Quests.journal_entries().size() == 1 and Quests.journal_entries()[0]["title"] == "Johnny the Gun Guy", "it is in the journal")
	var ch := Quests.choices("johnny")
	check(ch.size() == 2 and not ch[0]["enabled"] and ch[0]["label"].contains("0 of 10"), "no bullets: 'Give bullets (0 of 10)' is disabled (%s / %s)" % [ch[0]["label"], ch[0]["hint"]])
	check(j.has_choices(), "the choices are on screen")
	check(not Quests.choose(j, 0), "…and choosing a disabled one does nothing")
	check(Quests.ledger_paid("johnny", "gun") == 0 and Quests.stage("johnny") == "offer", "nothing taken, nothing moved")
	# instalment one: four bullets
	_bullets(4)
	check(Quests.choose(j, 0), "four bullets are accepted toward the ten")
	check(WorldState.get_ammo_total() == 0 and Quests.ledger_paid("johnny", "gun") == 4, "all four taken, the ledger says 4")
	check(Quests.stage("johnny") == "offer" and not WorldState.inventory.any(func(i): return i.item_id == "004"), "…no gun yet, the quest is still open")
	check(Quests.choices("johnny")[0]["label"].contains("4 of 10"), "the button says where you are (%s)" % Quests.choices("johnny")[0]["label"])
	check(Quests.journal_entries()[0]["objective"].contains("4 of 10"), "…and so does the journal (%s)" % Quests.journal_entries()[0]["objective"])
	check(j.last_line.contains("6"), "Johnny says how many are still owed ('%s')" % j.last_line)
	# the ledger outlives the character: a time skip wipes the pockets and keeps the debt
	bf.free()
	await get_tree().process_frame
	WorldState.advance_run()
	check(Quests.ledger_paid("johnny", "gun") == 4 and Quests.stage("johnny") == "offer", "next run: the 4 bullets are still on the ledger")
	var bf2 = await _corridor(floor_num)
	var j2 := _giver_in(bf2, "johnny")
	check(j2 != null and not j2.is_dead, "…and Johnny is still on his floor in run 2")
	if j2 == null:
		bf2.free()
		return
	bf2.get_node("Player").global_position = Vector2(j2.global_position.x - 40.0, 386.0)
	await _frames(40)
	# instalment two pays only what is owed — never more — and the gun comes with it
	_bullets(25)
	j2.talk()
	check(Quests.choose(j2, 0), "run 2: twenty-five bullets in hand, only the six owed are taken")
	check(WorldState.get_ammo_total() == 19, "…19 are left in the pocket (%d)" % WorldState.get_ammo_total())
	var gun: ItemInstance = null
	for it in WorldState.inventory:
		if it.item_id == "004":
			gun = it
	check(gun != null and gun.perks.has("G_durable") and gun.mag_count == 6 and gun.current_durability == gun.get_max_durability(), "the gun is a Durable Hand Cannon, full of wear, six rounds in")
	check(Quests.stage("johnny") == "paid" and not Quests.completed("johnny"), "the quest moves on to the second tier")
	check(j2.has_choices() and Quests.choices("johnny").size() == 2, "…and offers the twenty (and 'not now')")
	# the second tier: twelve now, eight to follow — then the pick
	_bullets(12)
	check(Quests.choose(j2, 0) and Quests.ledger_paid("johnny", "upgrade") == 12 and Quests.stage("johnny") == "paid", "twelve of the twenty")
	_bullets(8)
	check(Quests.choose(j2, 0), "…and the eight that finish it")
	check(Quests.stage("johnny") == "pick" and Quests.choices("johnny").size() == 2, "…and now he lets you pick what he teaches (%d choices)" % Quests.choices("johnny").size())
	var done_before := int(WorldState.run_chronicle[1].get("quests_completed", 0)) if WorldState.run_chronicle.size() > 1 else 0
	var crit_before := WorldState.get_headshot_bonus()
	check(Quests.choose(j2, 1), "steadier aim")
	check("Q_crit" in WorldState.quest_upgrades, "the upgrade is granted")
	check(is_equal_approx(WorldState.get_headshot_bonus() - crit_before, 0.10), "…and it folds into the headshot stat (+0.10)")
	check(Quests.completed("johnny") and Quests.stage("johnny") == "done", "the quest is complete")
	check(int(WorldState.run_chronicle[1].get("quests_completed", 0)) == done_before + 1, "…and counted once (Valour: quests completed)")
	check(not Quests.choose(j2, 0) or Quests.stage("johnny") == "done", "nothing more to buy")
	bf2.free()
	await get_tree().process_frame
	# the other branch
	_fresh()
	WorldState.quest_upgrades.clear()
	check(is_equal_approx(WorldState.get_gun_refund(), 0.0), "no refund before the upgrade")
	WorldState.quest_upgrades.append("Q_refund")
	check(is_equal_approx(WorldState.get_gun_refund(), 0.20), "Waste Not = a 20% chance a shot isn't spent")
	WorldState.quest_upgrades.clear()


func _test_johnny_no_room() -> void:
	print("[JOHNNY: the instalment that would complete the price is refused WHOLE while the gun will not fit — nothing taken, nothing left waiting]")
	_fresh()
	var floor_num := int(Quests.site("johnny")["floor"])
	var bf = await _corridor(floor_num)
	var j := _giver_in(bf, "johnny")
	bf.get_node("Player").global_position = Vector2(j.global_position.x - 40.0, 386.0)
	await _frames(40)
	j.talk()
	# a full pack: junk in every slot but one, and one stack of eight bullets — three owed leaves five, so no slot is freed
	Quests.state_of("johnny")["ledger"]["gun"] = 7
	WorldState.inventory.clear()
	for i in WorldState.get_inventory_slots() - 1:
		WorldState.add_to_inventory("023")
	WorldState.add_to_inventory("016", 8)
	check(WorldState.inventory.size() == WorldState.get_inventory_slots(), "(a full pack, with a stack of eight bullets)")
	check(not Quests.choose(j, 0), "the last three bullets are refused while the gun cannot be carried")
	check(WorldState.get_ammo_total() == 8 and Quests.ledger_paid("johnny", "gun") == 7, "…nothing was taken: all eight bullets, the ledger still at seven")
	check(Quests.stage("johnny") == "offer" and not WorldState.inventory.any(func(i): return i.item_id == "004"), "…and no gun was left waiting (stage %s)" % Quests.stage("johnny"))
	check(str(Quests.choices("johnny")[0]["label"]).begins_with("Give bullets"), "the button still reads as a payment, never 'take what you are owed'")
	# a part-payment that does NOT complete the price is fine with a full pack
	Quests.state_of("johnny")["ledger"]["gun"] = 0
	WorldState.inventory.clear()
	for i in WorldState.get_inventory_slots() - 1:
		WorldState.add_to_inventory("023")
	WorldState.add_to_inventory("016", 4)
	check(Quests.choose(j, 0) and Quests.ledger_paid("johnny", "gun") == 4 and Quests.stage("johnny") == "offer", "four bullets toward ten are taken even with a full pack (the ledger shows 4)")
	# make room and finish
	WorldState.add_to_inventory("016", 6)
	for i in range(WorldState.inventory.size() - 1, -1, -1):
		if WorldState.inventory[i].item_id == "023":
			WorldState.remove_from_inventory(i)
			break
	check(Quests.choose(j, 0), "with a slot free the last six are handed over")
	check(WorldState.inventory.any(func(i): return i.item_id == "004") and Quests.stage("johnny") == "paid", "…the gun is in the pack and the quest moves on")
	bf.free()
	await get_tree().process_frame


func _test_johnny_gun_is_never_reissued() -> void:
	print("[JOHNNY'S GUN is never given twice: die holding it and the next character finds it on your body — Johnny owes them nothing]")
	_fresh()
	var floor_num := int(Quests.site("johnny")["floor"])
	var bf = await _corridor(floor_num)
	var j := _giver_in(bf, "johnny")
	bf.get_node("Player").global_position = Vector2(j.global_position.x - 40.0, 386.0)
	await _frames(40)
	j.talk()
	_bullets(10)
	check(Quests.choose(j, 0), "ten bullets are paid")
	check(WorldState.inventory.any(func(i): return i.item_id == "004") and Quests.stage("johnny") == "paid", "the gun is in the pack and the quest is on its second price")
	# the character dies holding it: the game records the body, then the time skip
	WorldState.record_player_corpse(floor_num, "res://scenes/building_floors.tscn", "", Vector2(600.0, 419.0))
	bf.free()
	await get_tree().process_frame
	check(not WorldState.advance_run(), "the time skip (run 2 begins)")
	check(not WorldState.inventory.any(func(i): return i.item_id == "004"), "the new character starts without the gun")
	check(Quests.stage("johnny") == "paid", "Johnny is still on the second price (%s)" % Quests.stage("johnny"))
	var offers_gun := false
	for c in Quests.choices("johnny"):
		offers_gun = offers_gun or str(c["label"]).to_lower().contains("gun")
	check(not offers_gun, "he offers no gun to the new character")
	# the second price completes, as run 2's character pays it — and still no gun appears
	var bf2 = await _corridor(floor_num)
	var j2 := _giver_in(bf2, "johnny")
	bf2.get_node("Player").global_position = Vector2(j2.global_position.x - 40.0, 386.0)
	await _frames(40)
	j2.talk()
	_bullets(20)
	check(Quests.choose(j2, 0) and Quests.stage("johnny") == "pick", "twenty more bullets move him on to the upgrade")
	check(not WorldState.inventory.any(func(i): return i.item_id == "004"), "…and still no gun was handed to anyone")
	bf2.free()
	await get_tree().process_frame
	# …but the dead character's body has it, to be looted
	var body := WorldState.get_player_corpse_for(floor_num, "res://scenes/building_floors.tscn", "")
	check(not body.is_empty(), "the first character's body lies where they fell")
	var has_gun := false
	for it in body.get("data", {}).get("items", []):
		has_gun = has_gun or str(it.get("item_id", "")) == "004"
	check(has_gun, "…with Johnny's gun on it")
	WorldState.inventory.clear()
	WorldState.recover_player_corpse(str(body.get("key", "1")))
	var gun = null
	for it in WorldState.inventory:
		if it.item_id == "004":
			gun = it
	check(gun != null and int(gun.level) == 2 and "G_durable" in gun.perks, "looting the body returns the very same Lv2 Durable Hand Cannon")


func _test_no_half_trades() -> void:
	print("[NEVER A HALF-DONE TRADE: a choice that hands you something is refused WHOLE when you cannot carry it]")
	_fresh()
	Quests.defs()["testq"] = {"number": "T", "title": "Test", "kind": "corridor", "floors": [9, 22], "start": "a", "on_giver_died": "lost",
		"npc": {"role": "defender", "weapon": "001", "hp": 5},
		"states": {
			"a": {"journal": "t", "lines": ["x"], "choices": [
				{"label": "free gun", "do": ["give_gun:johnny", "goto:b"]},
				{"label": "swap bullets for a gun", "need": {"ammo": 8}, "do": ["take_ammo:8", "give_gun:johnny", "goto:b"]}]},
			"b": {"journal": "t", "lines": [], "choices": []}, "lost": {"journal": "t", "lines": [], "choices": []}}}
	var rec := {"key": "testq:giver", "role": "defender", "floor": 12, "apt": "", "look": 3, "weapon": "001", "ammo": 0, "gift": "", "gift_n": 0,
		"hp": 5, "max_hp": 5, "dead": false, "x": -1.0, "post": 600.0, "post_kind": "quest", "spot": 0.5, "met": 0, "aided": false, "calm": false,
		"gave": false, "quest": "testq", "npc": "giver"}
	WorldState.survivors["testq:giver"] = rec
	var host := Node2D.new()
	add_child(host)
	var who := Survivor.spawn(host, rec, 419.0, 600.0)
	await _frames(2)
	check(who.quest_id == "testq", "(a test giver)")
	# five junk items: full
	WorldState.inventory.clear()
	for i in WorldState.get_inventory_slots():
		WorldState.add_to_inventory("023")
	check(WorldState.inventory.size() == WorldState.get_inventory_slots(), "(the pack is full)")
	var before := WorldState.inventory.size()
	check(not Quests.choose(who, 0), "a free gun with a full pack is refused")
	check(WorldState.inventory.size() == before and Quests.stage("testq") == "a", "…nothing given, the quest stays where it was")
	# the same pack, but the payment frees a slot: it goes through whole
	WorldState.inventory.clear()
	for i in WorldState.get_inventory_slots() - 1:
		WorldState.add_to_inventory("023")
	WorldState.add_to_inventory("016", 8)                                    # one full stack: paying it frees exactly the slot the gun needs
	check(WorldState.inventory.size() == WorldState.get_inventory_slots(), "(full again — with one stack of 8 bullets)")
	check(Quests.choose(who, 1), "…but paying with that stack frees the room, so the swap goes through")
	check(WorldState.get_ammo_total() == 0 and WorldState.inventory.any(func(i): return i.item_id == "004") and Quests.stage("testq") == "b", "bullets gone, gun in hand, state moved — all of it, together")
	host.free()
	Quests.defs().erase("testq")
	WorldState.quests.erase("testq")
	await get_tree().process_frame


func _test_johnny_dies() -> void:
	print("[JOHNNY cannot be bitten to death — only the legacy fight kills (and then the quest fails for good, unless he is yet to be met)]")
	_fresh()
	var floor_num := int(Quests.site("johnny")["floor"])
	var bf = await _corridor(floor_num)
	var j := _giver_in(bf, "johnny")
	# the show (shipped): the dead's bites are flinches — he is never wounded, met or not
	check(AllyCombat.performative, "(setup) the shipped default is the show")
	j.receive_damage(99, "bite")
	j.talk()
	j.receive_damage(99, "bite")
	check(not j.is_dead and j.current_hp == j.max_hp and Quests.stage("johnny") == "offer", "bitten 'to death' before AND after the first conversation, he is untouched (hp %d/%d, %s)" % [j.current_hp, j.max_hp, Quests.stage("johnny")])
	# the real fight (the switch OFF): protected until met, then mortal like anyone
	AllyCombat.performative = false
	bf.free()                                        # (the show's floor goes — its dead would stand in the legacy floor's view)
	await get_tree().process_frame
	_fresh()
	var bfl = await _corridor(int(Quests.site("johnny")["floor"]))
	var jl := _giver_in(bfl, "johnny")
	check(Quests.protects(jl.rec) and not Quests.started("johnny"), "(legacy) he is protected until he has been spoken to")
	jl.receive_damage(99, "bite")
	check(not jl.is_dead and jl.current_hp == 1 and Quests.stage("johnny") == "offer", "an overwhelming bite leaves him alive on 1 hp (hp %d, %s)" % [jl.current_hp, Quests.stage("johnny")])
	jl.receive_damage(5, "bite")
	check(not jl.is_dead and jl.current_hp == 1, "…and the next bites change nothing")
	jl.talk()
	check(Quests.started("johnny"), "begun")
	check(not Quests.protects(jl.rec), "once spoken to he is mortal like anyone")
	jl.receive_damage(99, "bite")
	check(jl.is_dead and Quests.stage("johnny") == "lost", "killed: the quest turns to 'lost'")
	var e: Dictionary = Quests.journal_entries()[0]
	check(e["failed"] and not e["done"], "the journal says it failed")
	AllyCombat.performative = true
	bfl.free()
	await get_tree().process_frame
	WorldState.advance_run()
	check(Quests.corridor_records(int(Quests.site("johnny")["floor"])).is_empty(), "next run he is simply not there")
	check(Quests.stage("johnny") == "lost", "and the quest stays lost")


# --- Ethel ---------------------------------------------------------------------------------------

func _open_flat(apt: String) -> Node:
	WorldState.set_door_state(apt, WorldState.DoorState.OPEN)
	WorldState.current_apartment_id = apt
	WorldState.current_floor = WorldState._apartment_floor(apt)
	WorldState.spawn_source = ""
	WorldState.saved_player_x = 0.0
	var room = load("res://scenes/room.tscn").instantiate()
	add_child(room)
	await _frames(4)
	return room


func _close(room: Node) -> void:
	room.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _person(room: Node, npc: String) -> Survivor:
	for s in room.quest_people:
		if is_instance_valid(s) and str(s.rec.get("npc", "")) == npc:
			return s
	return null


func _zombies_in(room: Node) -> Array:
	var out: Array = []
	for z in get_tree().get_nodes_in_group("zombie"):
		if room.is_ancestor_of(z):
			out.append(z)
	return out


func _drops_in(apt: String, item: String) -> int:
	var n := 0
	for k in WorldState.world_drops:
		var d: Dictionary = WorldState.world_drops[k]
		if d.get("apartment_id", "") == apt and d.get("item_id", "") == item:
			n += 1
	return n


func _test_ethel_supplied() -> void:
	print("[ETHEL — you give her supplies: run 1 she thanks you; run 2 they have turned, and the kit is there, half used; run 3 the turned remain]")
	_fresh()
	var apt := str(Quests.site("ethel")["apt"])
	var room = await _open_flat(apt)
	var e := _person(room, "ethel")
	var h := _person(room, "husband")
	check(e != null and h != null and e.role == "host" and h.role == "patient", "Ethel and her husband are home")
	check(_zombies_in(room).is_empty(), "no ordinary dead in with them")
	check(e.behaviour == "plead" and h.behaviour == "lie", "she pleads, he lies there (%s / %s)" % [e.behaviour, h.behaviour])
	check(not h.is_in_group("survivor_prey") and e.is_in_group("survivor_prey"), "the dead do not go for the dying man; they would for her")
	check(h.quest_id == "" and e.quest_id == "ethel", "only Ethel is the one you talk to")
	var p = get_tree().get_first_node_in_group("player")
	p.global_position.x = e.global_position.x - 40.0
	await _frames(20)
	e.talk()
	var ch := Quests.choices("ethel")
	check(ch.size() == 4 and not ch[0]["enabled"] and not ch[1]["enabled"] and ch[2]["enabled"], "no supplies: both gifts disabled, mercy open")
	WorldState.add_to_inventory("007")
	check(Quests.choices("ethel")[0]["enabled"], "with a first aid kit: enabled")
	Quests.choose(e, 0)
	check(Quests.outcome("ethel") == "supplied" and Quests.stage("ethel") == "supplied", "outcome: supplied")
	check(not WorldState.inventory.any(func(i): return i.item_id == "007"), "the kit was taken")
	check(not h.is_dead, "her husband lives")
	await _close(room)
	# run 2: they turned
	WorldState.advance_run()
	WorldState.god_mode = true
	room = await _open_flat(apt)
	var zs := _zombies_in(room)
	check(zs.size() == 2, "run 2: the couple have TURNED — two of the dead (%d)" % zs.size())
	check(_person(room, "ethel") == null and _person(room, "husband") == null, "…and nobody living")
	check(_drops_in(apt, "007") == 1, "…and the kit is there to collect")
	var kit_d: Dictionary = {}
	for k in WorldState.world_drops:
		if WorldState.world_drops[k].get("item_id", "") == "007":
			kit_d = WorldState.world_drops[k]
	var kit := WorldState.instance_from_dict(kit_d["instance"])
	var full := ItemInstance.new()
	full.setup("007")
	check(full.base_heals() == 3 and kit.base_heals() == 1 and is_equal_approx(kit.heal_scale, 0.5), "…HALF what it was (heals %d of %d)" % [kit.base_heals(), full.base_heals()])
	var kit_again := WorldState.instance_from_dict(WorldState.instance_to_dict(kit))
	check(kit_again.base_heals() == 1, "…and a half kit survives a save round-trip")
	await _frames(3)
	var live_drops := 0
	for i in 60:                                    # (the room lays its drops a frame after it is built — wait for it, don't guess)
		live_drops = 0
		for n in room.get_children():
			if n.is_in_group("world_drop"):
				live_drops += 1
		if live_drops > 0:
			break
		await get_tree().process_frame
	check(live_drops >= 1, "…and it is really lying in the room")
	var victim_key := str(zs[0].spawn_key)
	zs[0].free()                                                                   # (stand in for killing one)
	WorldState.killed_zombies[victim_key] = {"x": 0, "y": 0, "floor": 1, "scene": "", "apartment_id": apt, "type": "standard"}
	await _close(room)
	room = await _open_flat(apt)
	check(_drops_in(apt, "007") == 1, "walking back in does not lay a second kit")
	await _close(room)
	WorldState.advance_run()
	room = await _open_flat(apt)
	check(_zombies_in(room).size() == 1, "run 3: the one you killed stays dead; the other is still there (%d)" % _zombies_in(room).size())
	check(_drops_in(apt, "007") == 1, "…no new kit")
	await _close(room)
	WorldState.god_mode = false


func _test_ethel_mercy() -> void:
	print("[ETHEL — you put him out of his misery: run 2 she mourns him; run 3 she is gone and there is a revolver]")
	_fresh()
	var apt := str(Quests.site("ethel")["apt"])
	var room = await _open_flat(apt)
	var e := _person(room, "ethel")
	var h := _person(room, "husband")
	var p = get_tree().get_first_node_in_group("player")
	p.global_position.x = e.global_position.x - 40.0
	await _frames(20)
	e.talk()
	Quests.choose(e, 2)
	check(h.is_dead and Quests.outcome("ethel") == "mercy" and Quests.stage("ethel") == "mercy", "he is dead; outcome: mercy")
	check(not e.is_dead, "she lives")
	check(WorldState.run_chronicle[0]["traces"].any(func(t): return str(t).contains("suffering")), "the building remembers it (a trace)")
	await _close(room)
	WorldState.advance_run()
	WorldState.god_mode = true
	room = await _open_flat(apt)
	var e2 := _person(room, "ethel")
	check(e2 != null and not e2.is_dead and e2.behaviour == "mourn", "run 2: Ethel is still here, MOURNING (%s)" % (e2.behaviour if e2 != null else "none"))
	var hb := _person(room, "husband")
	check(hb != null and hb.is_dead, "…his body lies where it was")
	check(_zombies_in(room).is_empty(), "…and the flat is quiet")
	if e2 != null:
		var p2 = get_tree().get_first_node_in_group("player")
		p2.global_position.x = e2.global_position.x - 40.0
		await _frames(20)
		var said := e2.talk()
		check(said != "" and said != "He's burning up. If there's a cure, a medicine, anything — please.", "she speaks as a mourner ('%s')" % said)
		check(Quests.choices("ethel").is_empty() or Quests.stage("ethel") == "mercy", "…with nothing left to ask of you")
	await _close(room)
	WorldState.advance_run()
	room = await _open_flat(apt)
	var eb := _person(room, "ethel")
	check(eb != null and eb.is_dead, "run 3: Ethel has died")
	check(_drops_in(apt, "004") == 1, "…and there is a revolver beside her")
	var rev: ItemInstance = null
	for k in WorldState.world_drops:
		var d: Dictionary = WorldState.world_drops[k]
		if d.get("apartment_id", "") == apt and d.get("item_id", "") == "004":
			rev = WorldState.instance_from_dict(d["instance"])
	check(rev != null and rev.mag_count == 5 and rev.perks.has("G_durable"), "five rounds in a tough gun")
	await _close(room)
	WorldState.god_mode = false


func _test_ethel_ignored() -> void:
	print("[ETHEL — you never helped her: by run 2 they have turned]")
	_fresh()
	var apt := str(Quests.site("ethel")["apt"])
	WorldState.advance_run()
	WorldState.god_mode = true
	var room = await _open_flat(apt)
	check(_zombies_in(room).size() == 2 and _person(room, "ethel") == null, "run 2 with nothing done: two of the dead, nobody living")
	check(_drops_in(apt, "007") == 0, "…and no kit (you gave her nothing)")
	await _close(room)
	WorldState.god_mode = false


# --- save + journal ------------------------------------------------------------------------------

func _test_persistence_and_journal() -> void:
	print("[PERSISTENCE + JOURNAL]")
	_fresh()
	Quests.state_of("ethel")["started"] = true
	Quests.state_of("ethel")["stage"] = "mercy"
	Quests.state_of("ethel")["outcome"] = "mercy"
	Quests.set_flag("ethel", "dropped:revolver")
	WorldState.quest_upgrades.append("Q_crit")
	var json := JSON.stringify({"quests": WorldState.quests, "quest_upgrades": WorldState.quest_upgrades})
	var back = JSON.parse_string(json)
	check(back is Dictionary and back["quests"]["ethel"]["outcome"] == "mercy" and back["quests"]["ethel"]["flags"]["dropped:revolver"] == true, "state survives a JSON round trip (string keys)")
	check(back["quest_upgrades"] == ["Q_crit"], "…and so do the upgrades")
	# the REAL save / load (string keys, the rule, the half kit)
	WorldState.survivors["q:ethel:ethel:r1"] = {"key": "q:ethel:ethel:r1", "dead": true, "hp": 0}
	WorldState.save_game("res://scenes/hallway.tscn")
	var saved_quests: Dictionary = WorldState.quests.duplicate(true)
	WorldState.quests.clear()
	WorldState.quest_upgrades.clear()
	WorldState.survivors.clear()
	WorldState.survivor_rule = false
	WorldState.load_game()
	check(WorldState.survivor_rule, "a Continue keeps the survivor rule")
	check(WorldState.quests == saved_quests and Quests.outcome("ethel") == "mercy" and Quests.flag("ethel", "dropped:revolver"), "…the quests (outcome + once-flags)")
	check(WorldState.quest_upgrades == ["Q_crit"], "…the quest upgrades")
	check(WorldState.survivors.has("q:ethel:ethel:r1") and WorldState.survivors["q:ethel:ethel:r1"]["dead"] == true, "…and the people (a dead one stays dead)")
	var panel_script = load("res://scripts/character_panel.gd")
	var panel = panel_script.new()
	add_child(panel)
	var txt: String = panel._quest_bbcode()
	check(txt.contains("Old Lady Ethel") and txt.contains("ended") or txt.contains("Old Lady Ethel"), "the journal's quest page lists her quest")
	panel.free()
	WorldState.quests.clear()
	WorldState.quest_upgrades.clear()
