extends Node

# Headless test for balcony generation (THREE_RUN_ARC balcony descent, Phase 2).
# Run:  godot --headless res://tests/balcony_test.tscn
# Covers the column-continuity seed and the layout-conform rule. The descent
# interaction itself is a later phase.

var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== balcony generation test ===")
	_test_determinism()
	_test_continuity()
	_test_conform_and_hide()
	_test_rope_and_clothes()
	_test_descent_core()
	_test_jump_warning_once()
	await _test_passive_room()
	await _test_bottom_balcony_access()
	_test_pan_gating()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _apt(floor_num: int, col: int) -> String:
	return str(floor_num) + "0" + str(col)


func _test_determinism() -> void:
	print("[determinism]")
	WorldState.new_game()
	for col in range(1, 6):
		var a = WorldState.is_balcony_column(col)
		var b = WorldState.is_balcony_column(col)
		check(a == b, "is_balcony_column(%d) is stable" % col)
		check(WorldState.balcony_slot_for_column(col) == WorldState.balcony_slot_for_column(col),
			"balcony_slot_for_column(%d) is stable" % col)


func _find_top() -> Dictionary:
	# A seed + column + slot + floor where a descendable (top) balcony exists, and
	# a plain (non-balcony) column, so all paths are exercised.
	for seed_try in range(1, 300):
		WorldState.master_seed = seed_try
		WorldState.apartment_layouts.clear()
		var plain := -1
		for c in range(1, 6):
			if not WorldState.is_balcony_column(c):
				plain = c
		for col in range(1, 6):
			if not WorldState.is_balcony_column(col):
				continue
			var slot = WorldState.balcony_slot_for_column(col)
			for f in range(2, 30):
				if WorldState.is_balcony_descendable(_apt(f, col), slot):
					return {"seed": seed_try, "col": col, "slot": slot, "floor": f, "plain": plain}
	return {}


func _test_continuity() -> void:
	print("[balcony pairs — one and done]")
	var top := _find_top()
	check(not top.is_empty(), "found a top balcony and a plain column")
	if top.is_empty():
		return
	var col: int = top["col"]
	var slot: int = top["slot"]
	var f: int = top["floor"]
	var here := _apt(f, col)
	var below := _apt(f - 1, col)
	# A top has a balcony directly below (its partner) at the same slot.
	check(WorldState.is_balcony_slot(here, slot), "the top is a balcony slot")
	check(WorldState.is_balcony_slot(below, slot), "its partner directly below is a balcony too")
	# The top descends; the partner below is a dead-end (one and done, no stack).
	check(WorldState.is_balcony_descendable(here, slot), "the top is descendable")
	check(not WorldState.is_balcony_descendable(below, slot),
		"the partner below is NOT descendable (one-and-done, no chaining)")
	# Floor 30 never has a balcony.
	for c in range(1, 6):
		check(not WorldState.is_balcony_slot(_apt(30, c), 0)
			and not WorldState.is_balcony_slot(_apt(30, c), 1)
			and not WorldState.is_balcony_slot(_apt(30, c), 2),
			"floor 30 col %d has no balcony" % c)


func _test_conform_and_hide() -> void:
	print("[layout conforms / plain column clean]")
	var top := _find_top()
	if top.is_empty():
		check(false, "no top balcony found to test conform")
		return
	var col: int = top["col"]
	var slot: int = top["slot"]
	var plain: int = top["plain"]
	# On any balcony floor (top or its partner) the seeded slot is a study/dining
	# and the layout stays three distinct rooms; non-balcony floors aren't forced.
	for f in range(1, 30):
		var apt := _apt(f, col)
		if WorldState.is_balcony_slot(apt, slot):
			var layout = WorldState.get_apartment_layout(apt)
			check(layout[slot] in WorldState.BALCONY_ROOMS,
				"col %d floor %d: balcony slot is a study/dining (%s)" % [col, f, layout[slot]])
			check(layout[0] != layout[1] and layout[1] != layout[2] and layout[0] != layout[2],
				"col %d floor %d: three distinct rooms" % [col, f])
	# Plain column: never a balcony, any floor.
	if plain > 0:
		for f in range(1, 30):
			for s in range(3):
				check(not WorldState.is_balcony_slot(_apt(f, plain), s),
					"plain col %d floor %d slot %d: no balcony" % [plain, f, s])


func _test_rope_and_clothes() -> void:
	print("[rope + clothes items]")
	# The ORIGINAL catalog items carry the flags (no duplicates, no crafted
	# intermediate): Rope 018 descends alone; 3x Clothes 008 (a slot each) are
	# knotted AT the balcony. Torn Clothes (009) stays a bandage.
	check(ItemData.get_item("018").get("is_rope", false), "Rope (018) is a rope")
	check(ItemData.get_item("008").get("is_clothes", false), "Clothes (008) is clothes")
	check(not ItemData.get_item("008").get("is_rope", false), "clothes alone are not a rope")
	# No CRAFTED clothes-rope intermediate exists: exactly ONE catalog item is a
	# rope, and it's 018. (This used to hardcode "035 is empty" as a proxy; 035 is
	# now the Crowbar, so guard the real invariant instead of the next-free ID.)
	var rope_items: Array = []
	for id in ItemData.items:
		if ItemData.get_item(id).get("is_rope", false):
			rope_items.append(id)
	check(rope_items == ["018"], "only ONE item is a rope (018) — no crafted clothes-rope")
	check(not ItemData.get_item("009").get("is_clothes", false),
		"Torn Clothes (009) is a bandage, not rope material")
	check(ItemData.get_item_id_by_name("Rope") == "018", "only ONE item is named Rope")
	check(ItemData.get_item_id_by_name("Clothes") == "008", "only ONE item is named Clothes")
	check(absf(WorldState.CLOTHES_BEDROOM_BOOST - 1.30) < 0.001, "clothes bedroom boost is 30%")

	# Clothes don't stack — three take three slots — and 3 enable a descent.
	WorldState.new_game()
	WorldState.inventory.clear()
	check(not WorldState.has_descent_rope(), "empty-handed = no descent line")
	WorldState.add_to_inventory("008")
	WorldState.add_to_inventory("008")
	check(WorldState.inventory.size() == 2, "clothes occupy separate slots (not stacked)")
	check(not WorldState.has_descent_rope(), "2 clothes aren't enough")
	WorldState.add_to_inventory("008")
	check(WorldState.has_descent_rope(), "3 clothes make a descent possible")
	check(WorldState.consume_descent_rope(), "the lash spends the clothes")
	check(WorldState.count_clothes() == 0 and WorldState.inventory.size() == 0,
		"all three clothes are consumed at the lash")

	# A rope is preferred and spent alone — clothes are left untouched.
	WorldState.inventory.clear()
	WorldState.add_to_inventory("008")
	WorldState.add_to_inventory("018")
	WorldState.add_to_inventory("008")
	check(WorldState.has_descent_rope(), "a rope makes a descent possible")
	check(WorldState.consume_descent_rope(), "the lash spends the rope")
	check(WorldState.count_clothes() == 2, "the rope is used first — clothes kept")
	check(not WorldState.consume_descent_rope(), "2 leftover clothes can't lash again")


func _test_descent_core() -> void:
	print("[descent core]")
	WorldState.new_game()
	# The apartment below is same column, one floor down.
	check(WorldState.balcony_below("2603") == "2503", "below 2603 is 2503")
	check(WorldState.balcony_below("3005") == "2905", "below 3005 is 2905")
	check(WorldState.balcony_below("103") == "", "floor 1 has nothing below (lobby)")

	# A lashed rope persists and is keyed per apartment+slot.
	check(not WorldState.is_balcony_roped("2603", 1), "balcony starts un-roped")
	WorldState.rope_balcony("2603", 1)
	check(WorldState.is_balcony_roped("2603", 1), "rope_balcony marks it roped")
	check(not WorldState.is_balcony_roped("2603", 0), "only the roped slot is roped")

	# Slip chance follows stamina bands.
	var maxs = WorldState.get_max_stamina()
	WorldState.stamina = maxs * 0.8
	check(WorldState.balcony_slip_chance() == 0.0, "rested = safe climb")
	WorldState.stamina = maxs * 0.45
	check(absf(WorldState.balcony_slip_chance() - WorldState.BALCONY_SLIP_CHANCE_MODERATE) < 0.001,
		"mid stamina = moderate slip chance")
	WorldState.stamina = maxs * 0.1
	check(absf(WorldState.balcony_slip_chance() - WorldState.BALCONY_SLIP_CHANCE_HIGH) < 0.001,
		"low stamina = high slip chance")

	# Descending moves world state into the apartment below and opens its door
	# from the inside.
	WorldState.door_states["2503"] = WorldState.DoorState.SHUT_LOCKED
	var target = WorldState.descend_from_balcony("2603")
	check(target == "2503", "descend targets the apartment below")
	check(WorldState.current_floor == 25, "floor drops by one")
	check(WorldState.current_apartment_id == "2503", "now inside the apartment below")
	check(WorldState.spawn_source == "balcony", "arrival is flagged as a balcony drop-in")
	check(WorldState.get_door_state("2503") == WorldState.DoorState.OPEN,
		"a locked door is opened from the inside")
	check(WorldState.descend_from_balcony("103") == "", "can't descend from floor 1")


func _test_passive_room() -> void:
	print("[passive room backdrop (BalconyPan)]")
	# The apartment below is stacked under the live room as scenery: modules +
	# balcony art only — no player, no door area, no loot UI, no descent zone.
	WorldState.new_game()
	var room = load("res://scenes/room.tscn").instantiate()
	room.passive = true
	room.setup_apartment = "2503"
	room.position = Vector2(0, 648)
	add_child(room)
	for i in range(4):
		await get_tree().process_frame
	var modules := 0
	for m in get_tree().get_nodes_in_group("room_module"):
		if m.get_parent() == room:
			modules += 1
	check(modules == 3, "passive room builds its three interior modules")
	check(room.get_node_or_null("Player") == null, "passive room has NO player")
	check(room.get_node_or_null("Area2D") == null, "passive room has NO door area")
	check(room.get_node_or_null("LootUI") == null, "passive room has NO loot UI")
	var zones := 0
	for c in room.get_children():
		if c.get_script() == load("res://scripts/balcony_zone.gd"):
			zones += 1
	check(zones == 0, "passive room spawns no interactive descent zone")
	check(room.apartment_id == "2503", "passive room built the REQUESTED apartment")
	# Any enemies in the backdrop must be FROZEN (no AI) — a live zombie would
	# chase the real player up in the scene above and drift out of place before
	# the swap. (Vacuously true if this apartment happens to have none.)
	var live_ai := 0
	for z in get_tree().get_nodes_in_group("zombie"):
		if z.get_parent() == room and z.process_mode != Node.PROCESS_MODE_DISABLED:
			live_ai += 1
	check(live_ai == 0, "backdrop enemies are frozen scenery, not live AI")
	room.queue_free()
	await get_tree().process_frame


func _test_jump_warning_once() -> void:
	print("[jump warning once per run]")
	# The no-rope jump warning is a one-time teach per run: fresh game clears it,
	# it survives a save/load round-trip, and a new game clears it again.
	WorldState.new_game()
	check(not WorldState.balcony_jump_warned, "new game clears the jump warning")
	WorldState.balcony_jump_warned = true
	WorldState.save_game("res://scenes/room.tscn")
	WorldState.balcony_jump_warned = false   # scramble before reload
	WorldState.load_game()
	check(WorldState.balcony_jump_warned, "jump warning survives save/load (per-run)")
	WorldState.new_game()
	check(not WorldState.balcony_jump_warned, "new game clears it again")


func _test_bottom_balcony_access() -> void:
	print("[bottom balcony is a steppable dead-end]")
	WorldState.new_game()
	WorldState.spawn_source = ""
	var col := -1
	for c in range(1, 10):
		if WorldState.is_balcony_column(c):
			col = c
			break
	if col < 0:
		check(true, "no balcony column this seed — skipped")
		return
	var slot := WorldState.balcony_slot_for_column(col)
	var topf := -1
	for f in range(3, 30):
		if WorldState.is_balcony_descendable(str(f) + "0" + str(col), slot):
			topf = f
			break
	check(topf > 0, "found a descendable top balcony")
	if topf < 0:
		return
	var top_apt := str(topf) + "0" + str(col)
	var bot_apt := WorldState.balcony_below(top_apt)
	check(bot_apt != "", "top has a partner directly below")
	check(WorldState.is_balcony_slot(bot_apt, slot), "bottom is a balcony slot (art shows)")
	check(not WorldState.is_balcony_descendable(bot_apt, slot), "bottom is NOT descendable (dead-end)")

	# A live room for the BOTTOM apartment still spawns a step-out zone, so the
	# player can access its balcony plane even though it leads nowhere.
	WorldState.current_apartment_id = bot_apt
	WorldState.current_floor = topf - 1
	var room = load("res://scenes/room.tscn").instantiate()
	add_child(room)
	for i in range(4):
		await get_tree().process_frame
	var zones := 0
	for c in room.get_children():
		if c.get_script() == load("res://scripts/balcony_zone.gd"):
			zones += 1
	check(zones >= 1, "bottom balcony still spawns a step-out zone (%d)" % zones)
	room.queue_free()
	await get_tree().process_frame


func _test_pan_gating() -> void:
	print("[pan gating]")
	# Not in a room scene here (this is the test scene), so the pan must refuse
	# and callers fall back to the plain fade — a descent can never soft-lock.
	check(not BalconyPan.can_pan(), "pan refuses outside a room scene (fade fallback)")
	check(BalconyPan.ENABLED, "pan is enabled by default")
	# The zombie plane-pursuit baseline: spawn line is remembered.
	var z = load("res://scenes/enemy_zombie_standard.tscn").instantiate()
	z.global_position = Vector2(300, 321)
	add_child(z)
	check(absf(z.base_walk_y - 321.0) < 0.5, "zombie remembers its corridor line")
	z.queue_free()
