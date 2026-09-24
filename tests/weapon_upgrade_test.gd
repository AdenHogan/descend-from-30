extends Node

# SCRAP + the WORKBENCH (docs/SCRAP_UPGRADES.md): scrap is a counter (a Scrap Bag never takes a
# slot), charred ruins are the faucet, and at a maintenance-room bench a gun/hammer levels up
# 1→4 by picking one of two perks per level for scrap + a spare copy fed in. Perks ride the
# weapon (kept as it levels, saved, carried on a corpse) and apply through the modifier fold.
# Run: godot --headless res://tests/weapon_upgrade_test.tscn

var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== weapon upgrade / scrap test ===")
	_test_scrap_counter()
	_test_scrap_faucets()
	_test_costs_and_feed()
	_test_perk_effects()
	await _test_melee_perks()
	_test_persistence()
	_test_corpse_and_run()
	_test_hud()
	await _test_discard_memory()
	await _test_workbench_ui()
	_test_gun_wear()
	await _test_gun_wear_in_play()
	_test_salvage_values()
	await _test_salvage_ui()
	await _test_bench_in_maintenance_room()
	_test_tuning()
	await _test_tuning_in_swings()
	_test_treeless_and_family_feed()
	_test_legendary_title()
	_test_heirloom_forge()
	await _test_bench_tune_and_forge_ui()
	_test_special_mod_offers()
	await _test_special_mod_effects()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _gun(level: int = 1, perks: Array = []) -> ItemInstance:
	var g := ItemInstance.new()
	g.setup("004")
	g.level = level
	g.perks = perks.duplicate()
	return g


func _hammer(level: int = 1, perks: Array = []) -> ItemInstance:
	var h := ItemInstance.new()
	h.setup("002")
	h.level = level
	h.perks = perks.duplicate()
	return h


func _test_scrap_counter() -> void:
	print("[scrap is a counter — a bag never takes a slot]")
	WorldState.new_game()
	check(WorldState.scrap == 0 and not WorldState.scrap_unlocked, "a new game starts with no scrap, counter hidden")
	for i in WorldState.get_inventory_slots():
		WorldState.inventory.append(_hammer())
	var before := WorldState.inventory.size()
	check(WorldState.add_to_inventory("037", 20), "a bag is taken even with full pockets")
	check(WorldState.scrap == 20 and WorldState.scrap_unlocked, "…straight into the counter (20), which appears")
	check(WorldState.inventory.size() == before, "…and never occupies a slot")
	WorldState.add_to_inventory("037")
	var natural: int = WorldState.scrap - 20
	check(natural >= WorldState.SCRAP_BAG_NATURAL.x and natural <= WorldState.SCRAP_BAG_NATURAL.y,
		"an ordinary bag holds %d..%d (%d)" % [WorldState.SCRAP_BAG_NATURAL.x, WorldState.SCRAP_BAG_NATURAL.y, natural])
	check(not ("037" in WorldState.SHOP_COMMON or "037" in WorldState.SHOP_QUALITY or "037" in WorldState.SHOP_LEGENDARY),
		"the merchant never trades scrap")


func _test_scrap_faucets() -> void:
	print("[charred ruins are the scrap faucet; ordinary rooms a trickle]")
	WorldState.new_game()
	var charred_hits := 0
	var natural_hits := 0
	var charred_total := 0
	for a in 200:
		var c: int = WorldState.scrap_bag_for_anchor("2203", "anchor_%d" % a, true)
		var n: int = WorldState.scrap_bag_for_anchor("2203", "anchor_%d" % a, false)
		if c > 0:
			charred_hits += 1
			charred_total += c
		if n > 0:
			natural_hits += 1
	check(charred_hits > 120, "most charred anchors hold scrap (%d/200)" % charred_hits)
	check(natural_hits > 0 and natural_hits < 40, "ordinary anchors only rarely do (%d/200)" % natural_hits)
	check(charred_hits > 0 and charred_total / charred_hits >= WorldState.SCRAP_BAG_CHARRED.x,
		"a charred bag is the big one (avg %d)" % (charred_total / maxi(charred_hits, 1)))
	check(WorldState.scrap_bag_for_anchor("2203", "anchor_a", true) == WorldState.scrap_bag_for_anchor("2203", "anchor_a", true),
		"seeded — the same ruin holds the same scrap on re-entry")


func _test_costs_and_feed() -> void:
	print("[costs: 50 → spare Lv1 + 80 → spare Lv2 + 100; the weapon keeps its perks]")
	WorldState.new_game()
	var gun := _gun()
	WorldState.inventory = [gun]
	WorldState.scrap = 49
	check(WorldState.upgrade_weapon(0, "G_aim").contains("50 scrap"), "Lv2 needs 50 scrap")
	WorldState.scrap = 50
	check(WorldState.upgrade_weapon(0, "G_silencer") != "", "only the two Lv2 perks are offered")
	check(WorldState.upgrade_weapon(0, "G_aim") == "", "Lv1 → Lv2 with 50 scrap")
	check(gun.level == 2 and gun.perks == ["G_aim"] and WorldState.scrap == 0, "Lv2, Aim Assist, scrap spent")
	WorldState.scrap = 500
	check(WorldState.upgrade_weapon(0, "G_silencer").contains("spare Lv1"), "Lv3 needs a spare Lv1 gun")
	var spare_hi := _gun(3)
	var spare_lo := _gun(1)
	WorldState.inventory = [spare_hi, gun, spare_lo]
	check(WeaponUpgrades.find_feed(gun, WorldState.inventory) == 2, "the LOWEST qualifying spare is fed in (never a better one)")
	check(WorldState.upgrade_weapon(1, "G_silencer") == "", "Lv2 → Lv3 with a spare + 80")
	check(gun.level == 3 and gun.perks == ["G_aim", "G_silencer"], "the weapon KEEPS Aim Assist and adds the Silencer")
	check(WorldState.inventory.size() == 2 and not (spare_lo in WorldState.inventory) and spare_hi in WorldState.inventory,
		"the Lv1 spare was stripped for parts; the Lv3 one untouched")
	check(WorldState.scrap == 420, "80 scrap spent (%d left)" % WorldState.scrap)
	WorldState.inventory = [gun, _gun(2)]
	check(WorldState.upgrade_weapon(0, "G_bang") == "" and gun.level == 4 and WorldState.scrap == 320,
		"Lv3 → Lv4 with a spare Lv2 + 100")
	check(gun.title != "", "Lv4 = LEGENDARY: it earned a name (%s)" % gun.get_display_name())
	check(WorldState.upgrade_weapon(0, "").contains("lobby door"), "beyond Legendary only a weapon that crossed the lobby door can go")
	var junk := ItemInstance.new()
	junk.setup("005")
	WorldState.inventory = [junk]
	check(WorldState.upgrade_weapon(0, "G_aim") != "", "the bench refuses what it has no tree for")


func _test_perk_effects() -> void:
	print("[perks apply through the fold]")
	WorldState.new_game()
	var g := _gun(2, ["G_durable"])
	check(g.shots_per_mark() == 12 and _gun().shots_per_mark() == 6, "Durable Hand Cannon: a mark every 12 shots, not 6")
	var door = load("res://scenes/door.tscn").instantiate()
	add_child(door)
	check(door._force_damages_gun(g, g.get_data()) and not g.is_damaged, "…and forcing a door never damages it")
	var plain := _gun()
	door._force_damages_gun(plain, plain.get_data())
	check(plain.is_damaged, "(a plain gun still takes the damage)")
	door.queue_free()
	var aim := _gun(2, ["G_aim"])
	check(is_equal_approx(aim.perk_add("headshot"), 0.10) and is_equal_approx(aim.perk_add("body"), 0.10), "Aim Assist: +10% head / +10% body")
	var P = load("res://scripts/player.gd")
	var p = P.new()
	check(p.gunshot_noise_radius(_gun(3, ["G_aim", "G_silencer"])) == WorldState.NOISE_RADIUS["walk"], "Silencer: a shot is heard like footsteps")
	check(p.gunshot_noise_radius(_gun()) == WorldState.NOISE_RADIUS["gunshot"], "(an ordinary shot rouses the floor)")
	p.free()
	var h := _hammer()
	WorldState.inventory = [h]
	h.current_durability = 7
	WorldState.scrap = 50
	WorldState.upgrade_weapon(0, "H_reinforced")
	check(h.get_max_durability() == 20, "Reinforced Handle: durability 10 → 20 (%d)" % h.get_max_durability())
	check(h.current_durability == 17, "…and the new headroom is added at once (7 → 17)")
	h.repair_full()
	check(h.current_durability == 20, "a toolbox repairs it to the new ceiling")
	check(_hammer(3, ["H_heavy", "H_doorbreaker"]).has_perk_flag("free_force"), "Door Breaker marks free forcing")


func _test_melee_perks() -> void:
	print("[hammer perks reach real swings]")
	WorldState.new_game()
	WorldState.god_mode = false
	var p = load("res://scenes/player.tscn").instantiate()
	add_child(p)
	var z = load("res://scenes/enemy_zombie_standard.tscn").instantiate()
	add_child(z)
	var z2 = load("res://scenes/enemy_zombie_standard.tscn").instantiate()
	add_child(z2)
	await get_tree().physics_frame
	# Pinned targets: their live AI would walk them around (sometimes past the player's facing),
	# which is combat noise this test isn't about.
	for zz in [z, z2]:
		zz.set_physics_process(false)
		zz.set_process(false)
	var plain := _hammer()
	var heavy := _hammer(4, ["H_heavy", "H_sweep", "H_feather"])
	var swing := func(w: ItemInstance, with_second: bool) -> Array:
		p.global_position = Vector2(400, 386)
		p.animated_sprite.flip_h = false            # facing right, at them
		z.global_position = Vector2(430, 370)
		z2.global_position = Vector2(445, 370) if with_second else Vector2(900, 370)
		z.current_hp = 50
		z2.current_hp = 50
		# A bludgeon hit knocks down 55% of the time, and a knocked-down zombie ignores further
		# blows until it stands — stand them back up so every swing tests the perk, not the dice.
		for zz in [z, z2]:
			zz.state = "idle"
			zz.state_timer = 0.0
		WorldState.stamina = WorldState.get_max_stamina()
		p.is_attacking = false
		p._do_melee_attack(w, 0)
		return [50 - z.current_hp, 50 - z2.current_hp, WorldState.get_max_stamina() - WorldState.stamina]
	var a: Array = swing.call(plain, false)
	var b: Array = swing.call(heavy, false)
	check(a[0] > 0 and b[0] == a[0] + 1, "Heavy Head: +1 damage (%d vs %d)" % [b[0], a[0]])
	check(is_equal_approx(b[2], a[2] * 0.6), "Featherweight: 40%% less stamina (%.1f vs %.1f)" % [b[2], a[2]])
	var c: Array = swing.call(heavy, true)
	check(c[0] > 0 and c[1] > 0, "Sweeping Blow: both enemies in reach take the hit (%d, %d)" % [c[0], c[1]])
	var d: Array = swing.call(plain, true)
	check((d[0] > 0) != (d[1] > 0), "(without it, one swing strikes one enemy) (%d, %d)" % [d[0], d[1]])
	p.queue_free()
	z.queue_free()
	z2.queue_free()
	await get_tree().physics_frame


func _test_persistence() -> void:
	print("[levels + perks + scrap survive a save]")
	WorldState.new_game()
	WorldState.inventory = [_gun(3, ["G_aim", "G_pierce"])]
	WorldState.scrap_unlocked = true
	WorldState.scrap = 37
	WorldState.save_game("res://scenes/hallway.tscn", false)
	WorldState.inventory.clear()
	WorldState.scrap = 0
	WorldState.scrap_unlocked = false
	WorldState.load_game()
	var g = WorldState.get_instance_at(0)
	check(g != null and g.level == 3 and g.perks == ["G_aim", "G_pierce"], "the gun loads as Lv3 with its perks")
	check(WorldState.scrap == 37 and WorldState.scrap_unlocked, "scrap + its counter load back")
	WorldState.delete_save()


func _test_corpse_and_run() -> void:
	print("[the next character inherits it from the corpse; scrap totals merge]")
	WorldState.new_game()
	WorldState.inventory = [_hammer(2, ["H_heavy"])]
	WorldState.add_scrap(40)
	WorldState.record_player_corpse(18, "res://scenes/building_floors.tscn", "", Vector2(500, 419))
	WorldState.advance_run()
	check(WorldState.scrap == 0 and WorldState.scrap_unlocked, "the time skip resets the balance, keeps the counter")
	WorldState.add_scrap(15)
	var rec: Dictionary = WorldState.get_player_corpse_for(18, "res://scenes/building_floors.tscn", "")
	var got: Dictionary = WorldState.recover_player_corpse(rec["key"])
	check(WorldState.scrap == 55 and int(got.get("scrap", 0)) == 40, "recovering the body MERGES scrap (15 + 40 = %d)" % WorldState.scrap)
	var h = WorldState.get_instance_at(0)
	check(h != null and h.level == 2 and h.perks == ["H_heavy"], "…and their upgraded hammer comes back as it was")
	WorldState.wallet_unlocked = true
	WorldState.wallet_balance = 300
	WorldState.new_game()
	check(not WorldState.wallet_unlocked and WorldState.wallet_balance == 0 and WorldState.scrap == 0,
		"a NEW playthrough starts with no wallet cash or scrap (they used to leak across New Games)")


func _test_hud() -> void:
	print("[HUD: scrap counter + a level tag on the slot]")
	WorldState.new_game()
	WorldState.inventory = [_gun(3, ["G_aim", "G_pierce"]), _hammer()]
	WorldState.add_scrap(12)
	HUD.refresh_inventory()
	check(HUD.scrap_label.visible and HUD.scrap_label.text.contains("12"), "the counter shows (%s)" % HUD.scrap_label.text)
	check(HUD.slot_level_labels[0].visible and HUD.slot_level_labels[0].text == "Lv3", "an upgraded weapon reads Lv3")
	check(not HUD.slot_level_labels[1].visible, "a Lv1 weapon shows no tag")


func _test_discard_memory() -> void:
	print("[a dropped weapon comes back EXACTLY as it was — the discard safety net]")
	WorldState.new_game()
	WorldState.current_floor = 12
	var p = load("res://scenes/player.tscn").instantiate()
	add_child(p)
	p.global_position = Vector2(500, 386)
	await get_tree().physics_frame
	var g := _gun(3, ["G_aim", "G_silencer"])
	g.mag_count = 7
	g.is_damaged = true
	var broken := _hammer(2, ["H_heavy"])
	broken.current_durability = 0
	broken.is_depleted = true
	var ammo := ItemInstance.new()
	ammo.setup("016")
	ammo.count = 5
	WorldState.inventory = [g, broken, ammo]
	var before := WorldState.world_drops.size()
	HUD._discard_slot(0)
	HUD._discard_slot(0)
	HUD._discard_slot(0)
	check(WorldState.inventory.is_empty() and WorldState.world_drops.size() == before + 3,
		"all three are on the floor — including the BROKEN hammer (%d drops)" % (WorldState.world_drops.size() - before))
	var gun_rec := {}
	var ham_rec := {}
	var ammo_rec := {}
	for k in WorldState.world_drops:
		var d = WorldState.world_drops[k]
		match d["item_id"]:
			"004": gun_rec = d
			"002": ham_rec = d
			"016": ammo_rec = d
	check(int(ammo_rec.get("amount", 0)) == 5, "the ammo stack remembers its count (5)")
	# Walk back in: the floor's drops spawn, pick the gun + hammer back up.
	var drop_scene = preload("res://scenes/world_drop.tscn")
	for rec in [gun_rec, ham_rec]:
		var dn = drop_scene.instantiate()
		dn.item_id = rec["item_id"]
		dn.instance_data = rec.get("instance", {})
		add_child(dn)
		dn._try_pickup()
	var back = WorldState.inventory
	check(back.size() == 2, "both picked back up")
	if back.size() == 2:
		var bg = back[0]
		check(bg.level == 3 and bg.perks == ["G_aim", "G_silencer"] and bg.mag_count == 7 and bg.is_damaged,
			"the gun is the SAME gun: Lv3, its perks, 7 rounds, still damaged")
		var bh = back[1]
		check(bh.is_depleted and bh.level == 2 and bh.perks == ["H_heavy"],
			"the hammer is still broken (no free repair) and keeps Lv2")
	# Two drops on the same spot both survive (the second used to overwrite the first).
	var k1: String = WorldState.add_world_drop("002", Vector2(300, 396), 12, {})
	var k2: String = WorldState.add_world_drop("002", Vector2(300, 396), 12, {})
	check(k1 != k2 and WorldState.world_drops.has(k1) and WorldState.world_drops.has(k2), "two drops on one spot are both kept")
	p.queue_free()
	await get_tree().physics_frame


func _test_workbench_ui() -> void:
	print("[the bench: pick a weapon, pick one of two, upgrade — paused while open]")
	WorldState.new_game()
	WorldState.inventory = [_gun(1), _hammer()]
	WorldState.scrap = 60
	var ui = load("res://scripts/workbench_ui.gd").new()
	add_child(ui)
	get_tree().paused = false
	ui.open()
	check(get_tree().paused and ui.visible, "opening pauses the game")
	check(ui.upgradable_slots() == [0, 1], "lists the gun and the hammer")
	check(ui.confirm() == "Pick one of the two upgrades.", "won't upgrade without a choice")
	ui.select_weapon(1)
	ui.choose_perk("H_heavy")
	check(ui.confirm() == "" and WorldState.get_instance_at(1).level == 2, "Upgrade → the hammer is Lv2 (Heavy Head)")
	check(WorldState.scrap == 10, "50 scrap spent")
	ui.select_weapon(0)
	ui.choose_perk("G_aim")
	check(ui.confirm().contains("50 scrap"), "can't afford the gun's step → says why")
	ui.close()
	check(not get_tree().paused and not ui.visible, "closing restores play")
	ui.queue_free()
	await get_tree().process_frame


func _test_gun_wear() -> void:
	print("[the gun wears: one durability mark every 6 rounds fired]")
	var g := _gun()
	check(g.get_max_durability() == 8 and g.current_durability == 8, "a gun has 8 marks of durability")
	var knocked := 0
	for i in 12:
		if g.register_shot():
			knocked += 1
	check(knocked == 2 and g.current_durability == 6, "12 shots → 2 marks gone (6 left)")
	for i in 5:
		g.register_shot()
	check(g.current_durability == 6 and g.shots_since_mark == 5, "5 more: still 6 (the 6th knocks the next)")
	for i in 31:
		g.register_shot()
	check(g.current_durability == 0 and g.is_depleted, "48 shots in all → worn out")
	check(g.is_repairable(), "…repairable with a toolbox")
	g.repair_full()
	check(g.current_durability == 8 and not g.is_depleted and g.shots_since_mark == 0, "a toolbox restores it")
	var d := _gun(2, ["G_durable"])
	for i in 12:
		d.register_shot()
	check(d.current_durability == 7, "Durable Hand Cannon: 12 shots → only 1 mark")
	g.register_shot()
	g.register_shot()
	var back: ItemInstance = WorldState.instance_from_dict(WorldState.instance_to_dict(g))
	check(back.shots_since_mark == 2 and back.current_durability == 8, "the count toward the next mark is saved with the gun")
	var old := WorldState.instance_to_dict(_gun())
	old["current_durability"] = -1
	old.erase("shots_since_mark")
	check(WorldState.instance_from_dict(old).current_durability == 8, "an old save's gun (no durability yet) loads as new")


func _test_gun_wear_in_play() -> void:
	print("[firing for real spends marks; a worn-out gun won't fire]")
	WorldState.new_game()
	var P = load("res://scenes/player.tscn")
	var p = P.instantiate()
	add_child(p)
	p.global_position = Vector2(400, 386)
	# A target that never dies (a real zombie would drop after a headshot and end the volley).
	var src := GDScript.new()
	src.source_code = "extends Node2D\nvar is_dead := false\nfunc receive_hit_from_gun(_o): pass\n"
	src.reload()
	var z := Node2D.new()
	z.set_script(src)
	z.add_to_group("zombie")
	add_child(z)
	z.global_position = Vector2(460, 370)
	await get_tree().process_frame
	var g := _gun()
	g.mag_count = 18
	WorldState.inventory = [g]
	for i in 6:
		p.is_attacking = false
		p._do_gun_attack(g, 0)
	check(g.mag_count == 12 and g.current_durability == 7, "6 rounds fired → one mark gone (%d marks, mag %d)" % [g.current_durability, g.mag_count])
	g.current_durability = 0
	g.is_depleted = true
	p.is_attacking = false
	p._do_gun_attack(g, 0)
	check(g.mag_count == 12, "a worn-out gun doesn't fire")
	p.queue_free()
	z.queue_free()
	await get_tree().process_frame


func _test_salvage_values() -> void:
	print("[salvage: junk is worth a little; weapons more; worn ones less (full yield: Tinkerer)]")
	WorldState.new_game()
	WorldState.active_upgrades = ["U_tinker"]            # the Tinkerer merchant upgrade → full yield
	var junk := ItemInstance.new()
	junk.setup("032")
	check(Salvage.value_of(junk) == 6 and not Salvage.needs_confirm(junk), "a broken umbrella → 6 scrap, no confirm needed")
	var bottle := ItemInstance.new()
	bottle.setup("024")
	check(Salvage.value_of(bottle) == 3, "an empty bottle → 3")
	var h := _hammer()
	check(Salvage.value_of(h) == 14, "a fresh hammer → 14")
	h.current_durability = 5
	check(Salvage.value_of(h) == 10, "half-worn → 14 × (0.4 + 0.6×0.5) = 10")
	h.current_durability = 0
	h.is_depleted = true
	check(Salvage.value_of(h) == 6, "broken → 40% = 6")
	var lv := _hammer(3, ["H_heavy", "H_sweep"])
	check(Salvage.value_of(lv) == 14 + 52, "a Lv3 hammer returns 40% of the 130 scrap sunk in (+52)")
	var gun := _gun()
	gun.is_damaged = true
	check(Salvage.value_of(gun) == 18, "a damaged gun → 25 × 0.7 ≈ 18")
	var fuses := ItemInstance.new()
	fuses.setup("020")
	fuses.count = 3
	check(Salvage.value_of(fuses) == 12, "a stack counts every item (3 fuses → 12)")
	print("[without the Tinkerer, dismantling pays rubbish (40%)]")
	WorldState.active_upgrades = []
	h.current_durability = 10
	h.is_depleted = false
	check(Salvage.value_of(junk) == 2 and Salvage.value_of(bottle) == 1, "umbrella 6 → 2, bottle 3 → 1")
	check(Salvage.value_of(h) == 6 and Salvage.value_of(_gun()) == 10, "hammer 14 → 6, gun 25 → 10")
	check(WorldState.UPGRADE_POOL.has("U_tinker"), "the Tinkerer is a merchant (every-five-floors) upgrade")
	for id in ["006", "007", "016", "022", "033", "037", "008"]:
		var it := ItemInstance.new()
		it.setup(id)
		check(not Salvage.can_salvage(it), "%s can't be salvaged" % it.get_display_name())
	WorldState.new_game()
	var loaded := _gun()
	loaded.mag_count = 5
	WorldState.inventory = [junk, loaded]
	check(WorldState.salvage_item(0) == 2 and WorldState.scrap == 2 and WorldState.scrap_unlocked, "salvaging banks the scrap (and shows the counter)")
	check(WorldState.salvage_item(0) == 10 and WorldState.get_ammo_total() == 5, "a loaded gun's rounds come back as bullets")
	# A FULL gun with no spare room: its 18 rounds can't all fit → refused, nothing lost.
	WorldState.new_game()
	var full := _gun()
	full.mag_count = 18
	WorldState.inventory = [full]
	for i in WorldState.get_inventory_slots() - 1:
		var j := ItemInstance.new()
		j.setup("024")
		WorldState.inventory.append(j)
	check(WorldState.salvage_blocker(0).contains("18 loaded rounds") and WorldState.salvage_item(0) == 0,
		"a loaded gun with no room for its rounds is refused (%s)" % WorldState.salvage_blocker(0))
	check(WorldState.inventory[0] == full and full.mag_count == 18, "…and the gun + rounds are untouched")
	WorldState.inventory.remove_at(1)
	WorldState.inventory.remove_at(1)
	check(WorldState.salvage_blocker(0) == "" and WorldState.salvage_item(0) == 10 and WorldState.get_ammo_total() == 18,
		"with room (3 slots) it breaks down and all 18 rounds come back")


func _test_salvage_ui() -> void:
	print("[the bench's SALVAGE tab]")
	WorldState.new_game()
	var bottle := ItemInstance.new()
	bottle.setup("024")
	var ban := ItemInstance.new()
	ban.setup("006")
	WorldState.inventory = [bottle, ban, _hammer()]
	var ui = load("res://scripts/workbench_ui.gd").new()
	add_child(ui)
	ui.open()
	ui.show_tab("salvage")
	check(ui._salvage_page.visible and not ui._upgrade_page.visible, "the tab swaps pages")
	check(ui.salvage(0) == 1 and WorldState.inventory.size() == 2, "junk breaks down on one press")
	check(ui.salvage(1) == 0 and WorldState.inventory.size() == 2, "a hammer takes a second press…")
	check(ui.salvage(1) == 6 and WorldState.inventory.size() == 1 and WorldState.scrap == 7, "…then it's scrap (7 total)")
	check(ui.salvage(0) == 0, "bandages can't be salvaged")
	ui.close()
	ui.queue_free()
	get_tree().paused = false
	await get_tree().process_frame


func _test_bench_in_maintenance_room() -> void:
	print("[the maintenance room's bench opens it]")
	WorldState.new_game()
	WorldState.current_floor = 6
	var room = load("res://scenes/maintenance.tscn").instantiate()
	add_child(room)
	await get_tree().process_frame
	await get_tree().process_frame
	room.open_workbench()
	var ui = room.get("_workbench_ui")
	check(ui != null and ui.visible, "[E] at the workbench opens the upgrade panel")
	if ui != null:
		ui.close()
	get_tree().paused = false
	room.queue_free()
	await get_tree().process_frame


func _knife(level: int = 1) -> ItemInstance:
	var k := ItemInstance.new()
	k.setup("001")
	k.level = level
	return k


func _test_tuning() -> void:
	print("[TUNING: every level gives points for the weapon's own stat sheet, within caps]")
	WorldState.new_game()
	var h := _hammer()
	WorldState.inventory = [h]
	check(WeaponUpgrades.points_free(h) == 0 and WorldState.tune_weapon(0, {"T_reach": 1}) != "", "a Lv1 weapon has no points")
	WorldState.scrap = 50
	WorldState.upgrade_weapon(0, "H_heavy")
	check(WeaponUpgrades.points_free(h) == WeaponUpgrades.POINTS_PER_LEVEL, "a level-up gives %d points" % WeaponUpgrades.POINTS_PER_LEVEL)
	check(WorldState.tune_weapon(0, {"T_drum": 1}) != "", "a hammer can't take a gun's stats")
	check(WorldState.tune_weapon(0, {"T_reach": -1}) != "", "points can't be taken back")
	check(WorldState.tune_weapon(0, {"T_weight": 2}).contains("maxed"), "Weight caps at %d before Legendary" % WeaponUpgrades.STATS["T_weight"]["cap"])
	check(WorldState.tune_weapon(0, {"T_reach": 3}).contains("Only 2"), "can't spend more than you have")
	var before_max: int = h.get_max_durability()
	var before_cur: int = h.current_durability
	check(WorldState.tune_weapon(0, {"T_reach": 1, "T_temper": 1}) == "", "two points set: Reach + Temper")
	check(WeaponUpgrades.points_free(h) == 0 and h.tuning == {"T_reach": 1, "T_temper": 1}, "spent")
	check(is_equal_approx(h.perk_add("reach"), 6.0), "Reach: +6 px")
	check(h.get_max_durability() == int(round(before_max * 1.25)) and h.current_durability == before_cur + (h.get_max_durability() - before_max),
		"Temper: +25%% durability, headroom added at once (%d → %d)" % [before_max, h.get_max_durability()])
	var t := _hammer(3, ["H_heavy", "H_sweep"])
	t.tuning = {"T_balance": 3, "T_handling": 2, "T_weight": 1}
	check(is_equal_approx(t.perk_mult("stamina"), 0.7) and is_equal_approx(t.perk_mult("cooldown"), 0.84), "Balance ×0.7 stamina, Handling ×0.84 swing time")
	check(int(t.perk_add("damage")) == 2, "Weight stacks with Heavy Head (+2)")
	var g := _gun(2, ["G_aim"])
	g.tuning = {"T_drum": 2, "T_sights": 1, "T_oiled": 2, "T_handload": 1}
	check(g.get_mag_cap() == ItemInstance.MAG_CAP + 4 + WorldState.get_gun_mag_bonus(), "Magazine +2 a rank")
	check(is_equal_approx(g.perk_add("headshot"), 0.14) and g.shots_per_mark() == 9 and is_equal_approx(g.perk_add("free_shot"), 0.05),
		"Sights / Oiled / Hand-loaded reach the gun")
	var back: ItemInstance = WorldState.instance_from_dict(JSON.parse_string(JSON.stringify(WorldState.instance_to_dict(t))))
	check(back.tuning == {"T_balance": 3, "T_handling": 2, "T_weight": 1} and typeof(back.tuning["T_balance"]) == TYPE_INT,
		"tuning survives a JSON save as ints (%s)" % str(back.tuning))
	var bad := WorldState.instance_to_dict(_hammer())
	bad["tuning"] = {"T_nope": 3, "T_reach": 0}
	check(WorldState.instance_from_dict(bad).tuning.is_empty(), "unknown / empty stats are dropped on load")


func _test_tuning_in_swings() -> void:
	print("[tuning reaches real swings: Reach lands a blow a plain weapon can't; Handling recovers faster]")
	WorldState.new_game()
	WorldState.god_mode = false
	var p = load("res://scenes/player.tscn").instantiate()
	add_child(p)
	var z = load("res://scenes/enemy_zombie_standard.tscn").instantiate()
	add_child(z)
	await get_tree().physics_frame
	z.set_physics_process(false)
	z.set_process(false)
	var base_range: float = p.WEAPON_RANGES["bat"]
	var swing := func(w: ItemInstance) -> int:
		p.global_position = Vector2(400, 386)
		p.animated_sprite.flip_h = false
		z.global_position = Vector2(400 + base_range + p._zombie_body_radius(z) + 10.0, 370)
		z.current_hp = 50
		z.state = "idle"
		WorldState.stamina = WorldState.get_max_stamina()
		p.is_attacking = false
		p._do_melee_attack(w, 0)
		return 50 - z.current_hp
	var plain := _hammer(2, ["H_heavy"])
	var long := _hammer(2, ["H_heavy"])
	long.tuning = {"T_reach": 2}
	check(swing.call(plain) == 0, "10 px past a hammer's reach: a plain swing misses")
	check(swing.call(long) > 0, "…Reach 2 (+12 px) lands it")
	var quick := _hammer(2, ["H_heavy"])
	quick.tuning = {"T_handling": 2}
	swing.call(quick)
	check(is_equal_approx(p.attack_cooldown_timer, p.WEAPON_COOLDOWN["bat"] * 0.84), "Handling 2: the swing recovers in %.2fs, not %.2fs" % [p.attack_cooldown_timer, p.WEAPON_COOLDOWN["bat"]])
	p.queue_free()
	z.queue_free()
	await get_tree().physics_frame


func _test_treeless_and_family_feed() -> void:
	print("[every weapon levels now; a spare of the same FAMILY can be stripped for parts]")
	WorldState.new_game()
	var sword := ItemInstance.new()
	sword.setup("003")
	WorldState.inventory = [sword]
	WorldState.scrap = 500
	check(WeaponUpgrades.can_upgrade("003") and not WeaponUpgrades.has_perk_tree("003"), "a sword has no perk tree but the bench works on it")
	var offer: Array = WeaponUpgrades.next_choices(sword)
	check(offer.size() == 2 and WeaponUpgrades.is_mod(offer[0]) and WeaponUpgrades.is_mod(offer[1]), "…so its levels offer two SPECIAL mods (%s)" % str(offer))
	check(WorldState.upgrade_weapon(0) == "Pick one of the two upgrades.", "a special must be picked")
	check(WorldState.upgrade_weapon(0, offer[0]) == "" and sword.level == 2 and sword.perks == [offer[0]], "Lv2 with its special")
	check(WorldState.upgrade_weapon(0, WeaponUpgrades.next_choices(sword)[0]).contains("blade"), "Lv3 needs a spare blade")
	var bat := ItemInstance.new()
	bat.setup("014")
	WorldState.inventory = [sword, bat]
	check(WeaponUpgrades.find_feed(sword, WorldState.inventory) == -1, "a bat is the wrong family for a sword")
	WorldState.inventory = [sword, bat, _knife()]
	check(WeaponUpgrades.find_feed(sword, WorldState.inventory) == 2, "a knife is a blade — it feeds a sword")
	var twin := ItemInstance.new()
	twin.setup("003")
	WorldState.inventory = [_knife(), sword, twin]
	check(WeaponUpgrades.find_feed(sword, WorldState.inventory) == 2, "an exact copy is preferred at the same level")
	var hammer := _hammer(3)
	var legend := _hammer(4)
	WorldState.inventory = [hammer, legend]
	check(WeaponUpgrades.find_feed(hammer, WorldState.inventory) == -1, "a legendary is never stripped for parts")
	var gun := _gun(2)
	WorldState.inventory = [gun, _hammer(1)]
	check(WeaponUpgrades.find_feed(gun, WorldState.inventory) == -1, "a gun still needs a gun")
	var junk := ItemInstance.new()
	junk.setup("024")
	check(not WeaponUpgrades.can_upgrade(junk.item_id), "junk isn't a weapon")


func _test_legendary_title() -> void:
	print("[LEGENDARY (Lv4): a name from how it was built — and the player can rename it]")
	WorldState.new_game()
	var k := _knife(3)
	k.tuning = {"T_reach": 3, "T_balance": 1}
	check(WeaponUpgrades.title_theme(k) == "T_reach", "its best stat sets the theme")
	WorldState.inventory = [k, _knife(2)]
	WorldState.scrap = 100
	var special: String = WeaponUpgrades.next_choices(k)[0]
	check(WorldState.upgrade_weapon(0, special) == "" and k.level == 4, "Lv3 → Legendary (with %s)" % special)
	var theme: String = String(WeaponUpgrades.perk(special).get("title", ""))
	check(k.title in WeaponUpgrades.TITLE_BANKS[theme], "named for its special first (%s: %s)" % [theme, k.title])
	check(k.get_display_name() == 'Knife "%s"' % k.title and k.tier_label() == "Legendary" and k.tier_tag() == "LEG",
		"reads %s — Legendary (LEG on the slot)" % k.get_display_name())
	check(k.forged_by.begins_with(WorldState.current_character() + ":1"), "remembers who forged it (%s)" % k.forged_by)
	check(WorldState.upgrade_weapon(0).contains("lobby door"), "and goes no further this game")
	check(WorldState.rename_weapon(0, "  My  \"Old\" Friend  ") == "" and k.title == "My Old Friend", "renamed (cleaned: %s)" % k.title)
	check(WorldState.rename_weapon(0, "!!!!!!!!!!!!!!!!!!!!!!!!!!!!") == "" and k.title.length() <= WeaponUpgrades.TITLE_MAX_LEN, "capped at %d" % WeaponUpgrades.TITLE_MAX_LEN)
	check(WorldState.rename_weapon(0, "   ") != "", "an empty name is refused")
	WorldState.inventory = [_knife(3)]
	check(WorldState.rename_weapon(0, "Nope") != "", "only a legendary earns a name")
	var fresh := _gun(1)
	check(WeaponUpgrades.title_theme(fresh) == "any" and WeaponUpgrades.generate_title(fresh, "x") in WeaponUpgrades.TITLE_BANKS["any"], "no build yet → a plain keepsake name")
	var boom := _gun(3, ["G_aim", "G_silencer"])
	boom.perks.append("G_bang")
	check(WeaponUpgrades.title_theme(boom) == "boom", "an untuned weapon takes its latest perk's flavour")
	var named := _knife(4)
	named.title = "Hush"
	named.forged_by = "bald_man:2"
	var back: ItemInstance = WorldState.instance_from_dict(JSON.parse_string(JSON.stringify(WorldState.instance_to_dict(named))))
	check(back.title == "Hush" and back.forged_by == "bald_man:2", "its name survives a save")


func _test_heirloom_forge() -> void:
	print("[HEIRLOOM + ++ +++: only after crossing the lobby door into a later game; scrap in instalments]")
	WorldState.new_game()
	var h := _hammer(4, ["H_heavy", "H_sweep", "H_skull"])
	h.title = "Widowmaker"
	WorldState.inventory = [h]
	WorldState.scrap = 100
	var cost5: int = WeaponUpgrades.HEIRLOOM[5]["scrap"]
	check(WorldState.forge_heirloom(0, 60) == "" and h.forge_paid == 60 and WorldState.scrap == 40 and h.level == 4,
		"60 put in — it rides the weapon, even before it has crossed")
	check(WeaponUpgrades.check(h, WorldState.inventory, WorldState.scrap)["reason"].contains("lobby door"), "not yet: it hasn't crossed the door")
	var d: Dictionary = WorldState.instance_to_dict(h)
	var carried: ItemInstance = WorldState.instance_from_dict(JSON.parse_string(JSON.stringify(d)))
	check(carried.forge_paid == 60, "the instalment survives a save / a corpse / the door stash")
	print("[crossing: stashed at an escape, collected in a later game]")
	WorldState.inventory = [h]
	WorldState.leave_for_next(0)
	WorldState.advance_run()
	WorldState.commit_door_stash()
	WorldState.new_game()
	var res: Dictionary = WorldState.collect_handoff_gifts()
	var got = WorldState.get_instance_at(0)
	check(res["given"].size() == 1 and got.crossings == 1 and got.title == "Widowmaker" and got.forge_paid == 60,
		"collected in the next game: 1 crossing, name + instalment intact")
	WorldState.scrap = 1000
	check(WorldState.forge_heirloom(0, 9999) == "" and got.level == 4 and got.forge_paid == cost5, "paid the rest → ready")
	check(WorldState.scrap == 1000 - (cost5 - 60), "only what was owed was taken (%d)" % WorldState.scrap)
	var tier_offer: Array = WeaponUpgrades.next_choices(got)
	check(tier_offer.size() == 2 and WeaponUpgrades.is_mod(tier_offer[0]), "the tier offers two specials (%s)" % str(tier_offer))
	check(WorldState.upgrade_weapon(0, tier_offer[1]) == "" and got.level == 5 and got.forge_paid == 0 and tier_offer[1] in got.perks,
		"picked → Legendary +")
	check(got.get_display_name().contains("Widowmaker") and got.tier_label() == "Legendary +" and got.tier_tag() == "LEG+", "Legendary +")
	check(WeaponUpgrades.points_earned(got) == WeaponUpgrades.POINTS_PER_LEVEL * 4 and WeaponUpgrades.cap_for(got, "T_weight") == 2,
		"more points, and every stat can go one higher (Weight cap 2)")
	check(WorldState.forge_heirloom(0, 50) == "" and got.level == 5 and got.forge_paid == 50, "++ can be paid toward…")
	check(WeaponUpgrades.check(got, WorldState.inventory, WorldState.scrap)["reason"].contains("1/2"), "…but needs a 2nd crossing")
	check(Salvage.value_of(got) > Salvage.value_of(_hammer(4)), "salvage refunds a share of the heirloom scrap too")
	got.crossings = 3
	got.level = 7
	check(WorldState.forge_heirloom(0, 10) == "Fully upgraded." and WeaponUpgrades.check(got, WorldState.inventory, 999)["reason"] == "Fully upgraded.",
		"Legendary +++ is the top")
	check(WeaponUpgrades.tier_name(7) == "Legendary +++", "reads Legendary +++")
	var lv3 := _hammer(3)
	WorldState.inventory = [lv3]
	check(WorldState.forge_heirloom(0, 10).contains("legendary"), "only a legendary goes to the forge")
	WorldState.carry_items = []
	WorldState.save_profile()


func _test_bench_tune_and_forge_ui() -> void:
	print("[the bench's TUNE tab + the forge]")
	WorldState.new_game()
	var h := _hammer(2, ["H_heavy"])
	WorldState.inventory = [h]
	var ui = load("res://scripts/workbench_ui.gd").new()
	add_child(ui)
	ui.open()
	ui.show_tab("tune")
	check(ui._tune_page.visible and not ui._upgrade_page.visible, "the Tune tab shows")
	ui.stage_point("T_reach", 1)
	ui.stage_point("T_reach", 1)
	ui.stage_point("T_reach", 1)
	check(ui.staged == {"T_reach": 2}, "staging stops at the points you have (%s)" % str(ui.staged))
	check(h.tuning.is_empty(), "staged isn't set")
	ui.stage_point("T_reach", -1)
	ui.stage_point("T_balance", 1)
	check(ui.set_tuning() == "" and h.tuning == {"T_reach": 1, "T_balance": 1}, "Set in steel → applied")
	check(not ui._name_row.visible, "no rename for a Lv2")
	var legend := _hammer(4, ["H_heavy", "H_sweep", "H_skull"])
	legend.title = "Doorstop"
	WorldState.inventory = [legend]
	WorldState.scrap = 30
	ui.select_weapon(0)
	check(ui._name_row.visible, "a legendary shows its name field")
	check(ui.rename("Grandad") == "" and legend.title == "Grandad", "renamed from the bench")
	ui.show_tab("upgrade")
	check(ui._forge_box.get_child_count() > 0 and ui._perk_box.get_child_count() == 0, "past Legendary, the Upgrade tab is the forge")
	check(ui.forge(25) == "" and legend.forge_paid == 25 and WorldState.scrap == 5, "Put in 25")
	ui.close()
	ui.queue_free()
	get_tree().paused = false
	await get_tree().process_frame


func _test_special_mod_offers() -> void:
	print("[SPECIAL MODS: every level without a tree perk offers two real specials]")
	WorldState.new_game()
	var sw := ItemInstance.new()
	sw.setup("003")
	var a: Array = WeaponUpgrades.next_choices(sw)
	check(a == WeaponUpgrades.next_choices(sw), "the offer is stable while you think")
	for id in a:
		check("melee" in WeaponUpgrades.MODS[id]["pool"], "%s is a melee special" % id)
	var g := _gun(4, ["G_aim", "G_silencer", "G_lucky"])
	for id in WeaponUpgrades.next_choices(g):
		check("gun" in WeaponUpgrades.MODS[id]["pool"], "the gun's heirloom tier offers gun specials (%s)" % id)
	check(WeaponUpgrades.next_choices(_hammer(1)) == WeaponUpgrades.TREES["002"][2], "a tree weapon still gets its tree at Lv2-4")
	var owned := _knife(4)
	owned.perks = ["X_fire", "X_serrated", "X_bell", "X_homerun", "X_wind"]
	var left: Array = WeaponUpgrades.next_choices(owned)
	check(not ("X_fire" in left) and not ("X_wind" in left), "never offered one it already has (%s)" % str(left))
	var sweeper := _hammer(4, ["H_heavy", "H_sweep", "H_skull"])
	var seen_cleave := false
	for lvl in [4, 5, 6]:
		sweeper.level = lvl
		seen_cleave = seen_cleave or "X_cleave" in WeaponUpgrades.next_choices(sweeper)
	check(not seen_cleave, "Cleave isn't offered to a weapon that already sweeps")
	var f := _knife(4)
	f.perks = ["X_fire"]
	check(WeaponUpgrades.describe(f, "X_fire").contains("20%"), "Fuel-Soaked at Legendary: 20%%")
	f.level = 6
	check(WeaponUpgrades.describe(f, "X_fire").contains("30%") and is_equal_approx(WeaponUpgrades.mod_chance(f, "X_fire"), 0.30),
		"…30%% at Legendary ++ — heirlooms make specials sing")
	var fire_sword := ItemInstance.new()
	fire_sword.setup("003")
	fire_sword.level = 4
	fire_sword.perks = ["X_bell", "X_fire"]
	check(WeaponUpgrades.title_theme(fire_sword) == "fire", "a fire sword is named for its fire (%s)" % WeaponUpgrades.generate_title(fire_sword, "x"))
	var back: ItemInstance = WorldState.instance_from_dict(JSON.parse_string(JSON.stringify(WorldState.instance_to_dict(fire_sword))))
	check(back.perks == ["X_bell", "X_fire"], "specials survive a save")
	var q := _gun(4, ["X_quick"])
	check(is_equal_approx(q.perk_mult("gun_cooldown"), 0.7), "Quick Hands: 30%% faster fire")


func _test_special_mod_effects() -> void:
	print("[SPECIAL MODS in play: fire, wounds, knockdowns, shoves, second wind, mended]")
	WorldState.new_game()
	WorldState.god_mode = false
	var p = load("res://scenes/player.tscn").instantiate()
	add_child(p)
	var z = load("res://scenes/enemy_zombie_standard.tscn").instantiate()
	add_child(z)
	var big = load("res://scenes/enemy_zombie_big.tscn").instantiate()
	add_child(big)
	await get_tree().physics_frame
	for e in [z, big]:
		e.set_physics_process(false)
		e.set_process(false)
	z.current_hp = 50
	var always := func() -> float: return 0.0
	var never := func() -> float: return 0.99
	var fire := _knife(4)
	fire.perks = ["X_fire"]
	p._weapon_mods_on_hit(fire, z, never)
	check(not z.on_fire, "a miss of the dice: no fire")
	p._weapon_mods_on_hit(fire, z, always)
	check(z.on_fire and z.weapon_lit, "Fuel-Soaked: it catches fire")
	z.on_fire = false                                   # what a fire floor does every frame off the flames
	check(z.on_fire, "the floor's fire bookkeeping can't put a weapon-set fire out")
	var aff = z.get_node_or_null(WeaponAffliction.NODE_NAME)
	for i in 7:
		aff._physics_process(1.0)
	check(z.current_hp < 50 and not z.on_fire and not z.weapon_lit, "it burns (%d hp) and goes out after ~6s" % z.current_hp)
	await get_tree().process_frame
	z.current_hp = 50
	var serr := _knife(4)
	serr.perks = ["X_serrated"]
	p._weapon_mods_on_hit(serr, z, always)
	aff = z.get_node_or_null(WeaponAffliction.NODE_NAME)
	for i in 6:
		if is_instance_valid(aff):
			aff._physics_process(1.0)
	check(z.current_hp == 47, "Serrated: a wound bleeds 3 more damage (%d)" % z.current_hp)
	await get_tree().process_frame
	var bell := _hammer(4, ["H_heavy", "H_sweep", "H_skull"])
	bell.perks.append("X_bell")
	z.state = "idle"
	p._weapon_mods_on_hit(bell, z, always)
	check(z.state == "knockdown", "Bell-Ringer: knocked flat")
	big.state = "idle"
	p._weapon_mods_on_hit(bell, big, always)
	check(big.state != "knockdown", "…but a big one / a boss can't be")
	p._weapon_mods_on_hit(fire, big, always)
	check(big.on_fire, "…though it burns like anything else")
	z.state = "idle"
	z.velocity = Vector2.ZERO
	p.global_position = Vector2(400, 386)
	z.global_position = Vector2(430, 370)
	var hr := _knife(4)
	hr.perks = ["X_homerun"]
	p._weapon_mods_on_hit(hr, z, never)
	check(z.velocity.x > 0.0 and z.state == "hit", "Home Run: every hit shoves it back (%.0f)" % z.velocity.x)
	var wind := _knife(4)
	wind.perks = ["X_wind"]
	WorldState.stamina = 10.0
	z.is_dead = true
	p._weapon_mods_on_hit(wind, z, never)
	check(is_equal_approx(WorldState.stamina, 10.0 + WorldState.get_max_stamina() * 0.30), "Second Wind: a kill gives back 30%% stamina")
	z.is_dead = false
	var tut = load("res://scenes/enemy_zombie_standard.tscn").instantiate()
	tut.tutorial_scripted = true
	add_child(tut)
	await get_tree().physics_frame
	tut.set_physics_process(false)
	p._weapon_mods_on_hit(fire, tut, always)
	check(not tut.on_fire, "the scripted tutorial neighbour is never afflicted")
	tut.queue_free()
	print("[in a real swing: Home Run shoves; Mended makes a killing blow free]")
	z.set_physics_process(false)
	var swing := func(w: ItemInstance, hp: int) -> void:
		p.global_position = Vector2(400, 386)
		p.animated_sprite.flip_h = false
		z.global_position = Vector2(440, 370)
		z.current_hp = hp
		z.is_dead = false
		z.state = "idle"
		z.velocity = Vector2.ZERO
		WorldState.stamina = WorldState.get_max_stamina()
		p.is_attacking = false
		p._do_melee_attack(w, 0)
	var sword := ItemInstance.new()
	sword.setup("003")
	sword.level = 2
	sword.perks = ["X_homerun"]
	swing.call(sword, 50)
	check(z.velocity.x > 0.0, "a real sword swing shoves with Home Run")
	var mend := ItemInstance.new()
	mend.setup("003")
	mend.level = 2
	mend.perks = ["X_mend"]
	var d0: int = mend.current_durability
	swing.call(mend, 50)
	check(mend.current_durability == d0 - 1, "Mended: an ordinary hit still wears it (%d → %d)" % [d0, mend.current_durability])
	var killed := false
	var free_kill := false
	for i in 20:                                      # blades sometimes leave it on 1 hp — keep swinging
		var before: int = mend.current_durability
		swing.call(mend, 1)
		if z.is_dead:
			killed = true
			free_kill = mend.current_durability == before
			break
		mend.current_durability = d0                  # (a non-killing try wore it — top it back up)
	check(killed and free_kill, "…a killing blow costs nothing")
	var q := _gun(2, ["G_aim"])
	q.perks.append("X_quick")
	q.mag_count = 5
	z.is_dead = false
	z.current_hp = 50
	WorldState.inventory = [q]
	p.is_attacking = false
	p._do_gun_attack(q, 0)
	check(is_equal_approx(p.attack_cooldown_timer, 0.65 * 0.7), "Quick Hands: the gun recovers in %.3fs" % p.attack_cooldown_timer)
	p.queue_free()
	z.queue_free()
	big.queue_free()
	await get_tree().physics_frame
