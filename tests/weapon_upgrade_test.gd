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
	await _test_bench_in_maintenance_room()
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
	check(WorldState.upgrade_weapon(0, "G_lucky") == "Fully upgraded.", "Lv4 is the cap")
	var junk := ItemInstance.new()
	junk.setup("005")
	WorldState.inventory = [junk]
	check(WorldState.upgrade_weapon(0, "G_aim") != "", "the bench refuses what it has no tree for")


func _test_perk_effects() -> void:
	print("[perks apply through the fold]")
	WorldState.new_game()
	var g := _gun(2, ["G_durable"])
	check(g.get_mag_cap() == _gun().get_mag_cap() + 6, "Durable Hand Cannon: +6 rounds (%d)" % g.get_mag_cap())
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
