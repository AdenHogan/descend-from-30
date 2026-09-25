extends Node

# Headless test for balcony generation (THREE_RUN_ARC balcony descent, Phase 2).
# Run:  godot --headless res://tests/balcony_test.tscn
# Covers the column-continuity seed and the layout-conform rule. The descent
# interaction itself is a later phase.

const BalconyGeo = preload("res://scripts/balcony_geo.gd")
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
	await _test_balcony_plane_restore()
	await _test_balcony_geometry()
	await _test_backdrop_memory()
	await _test_backdrop_fire_rules()
	await _test_upper_fire_spares_backdrop()
	await _test_enemy_balcony_plane()
	await _test_balcony_spawn_and_memory()
	await _test_descent_lands_on_plane()
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


func _test_balcony_plane_restore() -> void:
	# Regression (save/load): a save taken while OUT on a balcony plane must
	# re-establish that plane on load — the held Y line + depth scale — instead of
	# dropping the player onto the default line. restore_balcony_plane treats the
	# current Y as the balcony line (the save already holds the body there).
	print("[balcony plane restore on load]")
	var player = load("res://scenes/player.tscn").instantiate()
	add_child(player)
	await get_tree().process_frame
	player.on_balcony_plane = false
	# A save from BEFORE the balcony moved up (owner round 14) holds the old, lower line (origin 295):
	# the load puts the player on the balcony's line, not that one.
	player.global_position = Vector2(500.0, 295.0)
	var base_scale_y: float = player.animated_sprite.scale.y
	player.restore_balcony_plane(500.0)
	var line: float = BalconyGeo.FEET - BalconyGeo.PLAYER_FEET_OFF
	check(player.on_balcony_plane, "player is restored onto the balcony plane")
	check(is_equal_approx(player.balcony_plane_y, line) and is_equal_approx(player.global_position.y, line),
		"…on the balcony's own line (origin %.1f), whatever the save held" % player.global_position.y)
	check(is_equal_approx(player._plane_return_y, line + BalconyGeo.RISE),
		"corridor return line sits one RISE below the plane")
	check(player.animated_sprite.scale.y < base_scale_y,
		"sprite is depth-scaled while on the plane")
	check(absf(_drawn_feet(player, base_scale_y) - BalconyGeo.FEET) < 0.5,
		"the DRAWN feet stay on the balcony line as the sprite shrinks (%.1f)" % _drawn_feet(player, base_scale_y))
	player.queue_free()
	await get_tree().process_frame


func _drawn_feet(player, base_scale_y: float) -> float:
	# Where the sprite's feet are DRAWN: the origin, the sprite's own offset, and the feet (33 below the
	# origin at full size) shrunk with the sprite.
	var f: float = player.animated_sprite.scale.y / base_scale_y
	return player.global_position.y + player.animated_sprite.position.y + BalconyGeo.PLAYER_FEET_OFF * f


func _luma(c: Color) -> float:
	return (0.3 * c.r + 0.59 * c.g + 0.11 * c.b) * 255.0


func _test_balcony_geometry() -> void:
	# Owner round 14: the balcony is a loggia behind the back wall, its floor at the wall/floor seam —
	# the art (tools/art/balcony.py) is drawn FROM scripts/balcony_geo.gd, and the player, enemies and
	# the descent slice all read the same numbers, so what's drawn and where actors stand can't drift.
	print("[the balcony: art, planes and the descent slice agree]")
	var cx := int(BalconyGeo.CENTER_DX)
	var imgs: Array = []
	for n in ["balcony", "balcony_r2", "balcony_r3"]:
		var tex = load("res://assets/rooms/%s.png" % n)
		check(tex != null, "%s.png exists" % n)
		imgs.append(tex.get_image() if tex != null else null)
	if imgs[0] == null:
		return
	var im: Image = imgs[0]
	check(im.get_width() == 320 and im.get_height() == 144, "a full module layer (320 x 144)")
	check(im.get_pixel(cx, 4).a == 0.0, "above the doorway it's the room's own wall (transparent)")
	check(im.get_pixel(cx, int(BalconyGeo.THRESHOLD_Y) - 224).a == 1.0, "the sill sits on the wall/floor seam")
	check(im.get_pixel(cx, int(BalconyGeo.THRESHOLD_Y) - 224 + 6).a == 0.0, "…and the room's floor shows below it")
	var rail: float = _luma(im.get_pixel(cx, int(BalconyGeo.RAIL_TOP_Y) - 224 + 1))
	var sky: float = _luma(im.get_pixel(cx, int(BalconyGeo.RAIL_TOP_Y) - 224 - 3))
	check(rail < 110.0 and sky > rail + 40.0, "the handrail is drawn on RAIL_TOP_Y (rail %.0f, sky above %.0f)" % [rail, sky])
	var edge := int(BalconyGeo.EDGE_Y) - 224
	check(_luma(im.get_pixel(cx, edge + 3)) > 60.0 and im.get_pixel(cx, edge + 3).r > im.get_pixel(cx, edge + 3).b,
		"the tiled floor runs from the far edge down to the sill")
	var l1: float = _luma(imgs[0].get_pixel(cx - 20, int(BalconyGeo.LINTEL_Y) - 224 + 8))
	var l3: float = _luma(imgs[2].get_pixel(cx - 20, int(BalconyGeo.LINTEL_Y) - 224 + 8)) if imgs[2] != null else 999.0
	check(l1 > l3 + 60.0, "the sky beyond follows the run: day %.0f, night %.0f" % [l1, l3])
	# the planes
	check(is_equal_approx(BalconyGeo.LANE_FEET - BalconyGeo.RISE, BalconyGeo.FEET), "RISE takes the lane to the balcony line")
	check(BalconyGeo.FEET < BalconyGeo.THRESHOLD_Y and BalconyGeo.FEET > BalconyGeo.EDGE_Y,
		"the balcony line is out on the balcony: behind the sill, in front of the rail")
	check(absf(BalconyGeo.SCALE - (BalconyGeo.FEET - 224.0) / 129.0) < 0.01, "drawn at the room's perspective for that depth")
	check(load("res://scripts/enemy_plane.gd").RISE == BalconyGeo.RISE and load("res://scripts/enemy_plane.gd").SCALE == BalconyGeo.SCALE,
		"enemies use the same line and scale")
	# the slice
	check(BalconyPan.SHRED_TOP == BalconyGeo.RAIL_TOP_Y, "the slice starts at the upper handrail (they sink behind the railing)")
	check(BalconyPan.SHRED_BOTTOM == BalconyPan.STACK_OFFSET + BalconyGeo.LINTEL_Y,
		"…and ends at the lower doorway's lintel (they come back into view there)")
	check(is_equal_approx(BalconyPan.PLANE_Y + BalconyGeo.PLAYER_FEET_OFF, BalconyGeo.FEET), "the pan lands on the balcony line")
	# the player steps up onto it with the drawn feet on the line
	var player = load("res://scenes/player.tscn").instantiate()
	add_child(player)
	await get_tree().process_frame
	player.global_position = Vector2(500.0, BalconyGeo.LANE_FEET - BalconyGeo.PLAYER_FEET_OFF)
	var base_y: float = player.animated_sprite.scale.y
	await player.enter_balcony_plane(500.0)
	check(player.on_balcony_plane and absf(player.global_position.y + BalconyGeo.PLAYER_FEET_OFF - BalconyGeo.FEET) < 0.5,
		"W steps the player up onto the balcony line (feet %.1f)" % (player.global_position.y + BalconyGeo.PLAYER_FEET_OFF))
	check(absf(_drawn_feet(player, base_y) - BalconyGeo.FEET) < 0.5, "…drawn feet on it too (%.1f)" % _drawn_feet(player, base_y))
	player.exit_balcony_plane()
	for i in range(40):
		await get_tree().physics_frame
	check(not player.on_balcony_plane and absf(player.animated_sprite.position.y) < 0.01
		and is_equal_approx(player.animated_sprite.scale.y, base_y), "S steps back: full size, sprite back in place")
	player.queue_free()
	await get_tree().process_frame
	# a balcony room shows the art in the run's look
	WorldState.new_game()
	WorldState.is_first_run = false
	WorldState.master_seed = 4242
	WorldState.apartment_layouts.clear()
	WorldState.current_run = 3
	var room := _plane_room("2301")
	await get_tree().physics_frame
	var shown := ""
	for m in get_tree().get_nodes_in_group("room_module"):
		var b = m.get_node_or_null("Balcony")
		if room.is_ancestor_of(m) and b != null and b.visible:
			shown = str(b.get_node("BalconyArt").texture.resource_path)
	check(shown.ends_with("balcony_r3.png"), "at night the balcony shows its night look (%s)" % shown)
	room.free()
	await get_tree().process_frame
	WorldState.current_run = 1


# --- repair pass: the backdrop (the apartment BELOW, stacked one floor down) ---------------

func _apt_with_zombies() -> String:
	for f in range(20, 5, -1):
		for i in range(1, 6):
			var a := str(f) + "0" + str(i)
			if WorldState.get_door_state(a) != WorldState.DoorState.BREACHED \
					and WorldState.get_apartment_zombie_count(a) > 0 and WorldState.apartment_fire_stage(f, i) < 0:
				return a
	return ""


func _backdrop(apt: String) -> Node:
	var holder := Node2D.new()
	add_child(holder)
	var lower = load("res://scenes/room.tscn").instantiate()
	lower.passive = true
	lower.setup_apartment = apt
	lower.position = Vector2(0, 160)             # BalconyPan.STACK_OFFSET
	holder.add_child(lower)
	return holder


func _test_backdrop_memory() -> void:
	# A remembered zombie in the backdrop was applied in WORLD space (it stood in the apartment
	# ABOVE); freeing the backdrop recorded its +160 position (it came back under the floor).
	print("[backdrop zombies: local memory, never recorded]")
	WorldState.new_game()
	WorldState.is_first_run = false
	WorldState.master_seed = 4242
	WorldState.current_run = 1
	var apt := _apt_with_zombies()
	check(apt != "", "found an apartment with zombies (%s)" % apt)
	if apt == "":
		return
	WorldState.current_floor = int(apt.left(apt.length() - 2))
	WorldState.current_apartment_id = apt
	# Fresh (no memory): frozen on the SETTLED line one floor down, not the 321 spawn line.
	var h := _backdrop(apt)
	await get_tree().process_frame
	var ok_fresh := true
	var n := 0
	for z in get_tree().get_nodes_in_group("zombie"):
		if h.is_ancestor_of(z):
			n += 1
			ok_fresh = ok_fresh and absf(z.global_position.y - (304.0 + 160.0)) < 5.0
	check(n > 0 and ok_fresh, "fresh backdrop zombies sit on the settled line a floor down (%d)" % n)
	h.free()
	await get_tree().process_frame
	check(WorldState.zombie_positions.is_empty(), "freeing the backdrop records NOTHING into memory")
	# A live visit writes memory; the backdrop then shows them a floor DOWN, memory untouched.
	var room = load("res://scenes/room.tscn").instantiate()
	add_child(room)
	for i in range(3):
		await get_tree().physics_frame
	room.free()
	await get_tree().process_frame
	var before: Dictionary = WorldState.zombie_positions.duplicate(true)
	check(not before.is_empty(), "a live visit remembers its zombies")
	h = _backdrop(apt)
	await get_tree().process_frame
	var below := true
	for z in get_tree().get_nodes_in_group("zombie"):
		if h.is_ancestor_of(z):
			below = below and z.global_position.y > 400.0
	check(below, "remembered zombies show a floor DOWN in the backdrop, not up in the room above")
	h.free()
	await get_tree().process_frame
	check(WorldState.zombie_positions == before, "memory is unchanged after the backdrop is freed")


func _test_backdrop_fire_rules() -> void:
	# The backdrop must match what the live room will show (CHARRED = nobody, BLAZE = burnt
	# corpses) — it showed the frozen live pack, which vanished on landing.
	print("[backdrop follows the room's fire rules]")
	WorldState.new_game()
	WorldState.is_first_run = false
	WorldState.master_seed = 4242
	WorldState.current_run = 1
	var f := 12
	WorldState.dev_fire_origin = f
	for mode in [WorldState.DEV_HAZARD_FIRE3, WorldState.DEV_HAZARD_FIRE2]:
		WorldState.dev_hazard_mode = mode
		var apt := ""
		var stage := -1
		for i in range(1, 6):
			var st := WorldState.apartment_fire_stage(f, i)
			if st == (WorldState.FIRE_CHARRED if mode == WorldState.DEV_HAZARD_FIRE3 else WorldState.FIRE_BLAZE):
				apt = str(f) + "0" + str(i)
				stage = st
				break
		if apt == "":
			check(false, "found a %s apartment" % ("charred" if mode == WorldState.DEV_HAZARD_FIRE3 else "blazing"))
			continue
		WorldState.current_floor = f + 1
		var h := _backdrop(apt)
		await get_tree().process_frame
		var alive := 0
		var dead := 0
		for z in get_tree().get_nodes_in_group("zombie"):
			if h.is_ancestor_of(z):
				if z.is_dead:
					dead += 1
				else:
					alive += 1
		check(alive == 0, "%s backdrop holds no live enemy (%d)" % [apt, alive])
		if stage == WorldState.FIRE_BLAZE:
			check(dead >= 1, "a BLAZE backdrop shows its burnt corpses (%d)" % dead)
		h.free()
		await get_tree().process_frame
	WorldState.dev_hazard_mode = WorldState.DEV_HAZARD_NONE
	WorldState.dev_fire_origin = -1


func _test_upper_fire_spares_backdrop() -> void:
	# The upper room's fire loop took EVERY zombie in the group (x-only test), so a burning room
	# above burned the frozen backdrop zombies below to death while you stood on the balcony.
	print("[a burning room does not burn the apartment below]")
	WorldState.new_game()
	WorldState.is_first_run = false
	WorldState.master_seed = 4242
	WorldState.current_run = 1
	var apt := _apt_with_zombies()
	if apt == "":
		return
	var f := int(apt.left(apt.length() - 2))
	WorldState.current_floor = f + 1
	WorldState.current_apartment_id = str(f + 1) + apt.right(2)
	var room = load("res://scenes/room.tscn").instantiate()
	add_child(room)
	await get_tree().process_frame
	# Light the WHOLE upper room.
	var af = load("res://scripts/apartment_fire.gd").new()
	af.stage = WorldState.FIRE_BLAZE
	af.seed_salt = "x"
	room.add_child(af)
	af._spots = []
	for x in range(150, 1060, 40):
		af._spots.append({"x": float(x), "sz": 1.0})
	room._apt_fire = af
	var lower = load("res://scenes/room.tscn").instantiate()
	lower.passive = true
	lower.setup_apartment = apt
	lower.position = Vector2(0, 160)
	room.add_child(lower)
	await get_tree().process_frame
	var below: Array = []
	for z in get_tree().get_nodes_in_group("zombie"):
		if lower.is_ancestor_of(z):
			below.append(z)
	for i in range(240):
		room._apartment_fire_process(1.0 / 60.0)
	var harmed := 0
	for z in below:
		if z.is_dead or z.on_fire:
			harmed += 1
	check(below.size() > 0 and harmed == 0, "the apartment below is untouched by the fire above (%d of %d harmed)" % [harmed, below.size()])
	room.free()
	await get_tree().process_frame


# --- the balcony plane for ENEMIES (scripts/enemy_plane.gd) ----------------------------------

func _plane_room(apt: String) -> Node:
	WorldState.current_floor = int(apt.left(apt.length() - 2))
	WorldState.current_apartment_id = apt
	WorldState.spawn_source = ""
	WorldState.set_door_state(apt, WorldState.DoorState.OPEN)
	var room = load("res://scenes/room.tscn").instantiate()
	add_child(room)
	return room


func _drain_hp(p) -> int:
	var d := int(p.health_state)
	if d != 0:
		p.health_state = 0
		WorldState.player_health = 0
		p.is_dying = false
		WorldState.is_dying = false
	return d


func _test_enemy_balcony_plane() -> void:
	# Owner: an enemy on the room floor must NOT be able to hit a player out on the balcony — not
	# unless it climbs up too. It follows the player up, and back down.
	print("[enemies and the balcony plane]")
	WorldState.new_game()
	WorldState.is_first_run = false
	WorldState.tutorial_completed = true
	WorldState.god_mode = false
	WorldState.master_seed = 4242
	WorldState.apartment_layouts.clear()
	var apt := "2301"
	check(WorldState.balcony_slot_in_apartment(apt) >= 0, "2301 has a balcony (seed 4242)")
	var room := _plane_room(apt)
	await get_tree().physics_frame
	for z in get_tree().get_nodes_in_group("zombie"):
		z.free()
	check(room.balcony_centers.size() == 1, "the room publishes its balcony centre")
	var cx: float = room.balcony_centers[0]
	var p = room.get_node("Player")
	p.global_position = Vector2(cx, 320)
	await get_tree().physics_frame
	p.enter_balcony_plane(cx)
	for i in range(30):
		await get_tree().physics_frame
	check(p.on_balcony_plane, "player is out on the balcony")
	# A zombie on the floor right under the player.
	var z = load("res://scenes/enemy_zombie_standard.tscn").instantiate()
	z.global_position = Vector2(cx + 20, 321)
	room.add_child(z)
	z.alert_timer = 30.0
	await get_tree().physics_frame
	check(not z.on_balcony_plane, "a floor zombie starts on the floor")
	check(z._reach_to_player() == INF, "a floor zombie has NO reach to a balcony player")
	# The player can't hit it from up there either.
	var w := ItemInstance.new()
	w.setup("002")
	WorldState.inventory = [w]
	var hp0: int = z.current_hp
	z.on_balcony_plane = false
	z._plane_climb = 0
	p.is_attacking = false
	p.animated_sprite.flip_h = false
	p._do_melee_attack(w, 0)
	check(z.current_hp == hp0, "the player can't hit a floor zombie from the balcony")
	# Let it act: it climbs up after the player, then hits.
	z.global_position = Vector2(cx + 120, z.global_position.y)
	var dmg_floor := 0
	var dmg_plane := 0
	for i in range(60 * 6):
		await get_tree().physics_frame
		p.velocity = Vector2.ZERO
		var d := _drain_hp(p)
		if z.on_balcony_plane:
			dmg_plane += d
		else:
			dmg_floor += d
	check(dmg_floor == 0, "no damage while it was still on the floor (%d)" % dmg_floor)
	check(z.on_balcony_plane, "it climbed up onto the balcony after the player")
	check(dmg_plane > 0, "once up, it hits the player (%d)" % dmg_plane)
	# Feet on the same line as the player's (align by FEET, not origin).
	var z_feet: float = z._drop_feet_y()
	var p_feet: float = p.global_position.y + 33.0
	check(absf(z_feet - p_feet) <= 2.0, "its feet match the player's on the balcony (%.1f vs %.1f)" % [z_feet, p_feet])
	check(absf(z.position.x - cx) <= BalconyGeo.HALF_WIDTH + 0.5, "it stays between the balcony rails")
	# Player steps back in → it follows down.
	p.exit_balcony_plane()
	for i in range(60 * 2):
		await get_tree().physics_frame
	check(not z.on_balcony_plane and z._plane_climb == 0, "it steps back down after the player")
	check(absf(z._drop_feet_y() - 353.0) <= 2.0, "back on the room floor line (feet %.1f)" % z._drop_feet_y())
	room.free()
	await get_tree().process_frame
	WorldState.inventory = []


func _test_balcony_spawn_and_memory() -> void:
	# Some apartments start with an enemy ALREADY out on the balcony (seeded); it's remembered on
	# that line, the backdrop shows it there too, and a balcony listen from above hears it.
	print("[enemies seeded on the balcony]")
	WorldState.new_game()
	WorldState.is_first_run = false
	WorldState.tutorial_completed = true
	var found := ""
	for sd in range(1, 400):
		WorldState.master_seed = sd
		WorldState.apartment_layouts.clear()
		WorldState.door_states.clear()
		for f in range(8, 26):
			for c in range(1, 6):
				var a := str(f) + "0" + str(c)
				if WorldState.balcony_slot_in_apartment(a) < 0:
					continue
				if WorldState.get_door_state(a) == WorldState.DoorState.BREACHED or WorldState.apartment_fire_stage(f, c) >= 0:
					continue
				var n := WorldState.get_apartment_zombie_count(a)
				if n > 0 and WorldState.balcony_spawn_pick(a, n) >= 0:
					found = a
					break
			if found != "":
				break
		if found != "":
			break
	check(found != "", "found an apartment with an enemy seeded on its balcony (%s, seed %d)" % [found, WorldState.master_seed])
	if found == "":
		return
	check(WorldState.apartment_balcony_occupied(found), "a balcony listen from above hears it")
	var room := _plane_room(found)
	await get_tree().physics_frame
	var on_plane: Array = []
	for z in get_tree().get_nodes_in_group("zombie"):
		if room.is_ancestor_of(z) and z.on_balcony_plane:
			on_plane.append(z)
	check(on_plane.size() == 1, "exactly one enemy starts out on the balcony (%d)" % on_plane.size())
	var key := ""
	if on_plane.size() == 1:
		var z = on_plane[0]
		key = z.spawn_key
		check(absf(z._drop_feet_y() - BalconyGeo.FEET) <= 2.0, "it stands on the balcony line (feet %.1f)" % z._drop_feet_y())
	room.free()
	await get_tree().process_frame
	check(key != "" and bool(WorldState.zombie_positions.get(key, {}).get("plane", false)), "memory records it on the balcony")
	# Backdrop (the room below seen during a descent) shows it on the balcony, a floor down.
	var holder := Node2D.new()
	add_child(holder)
	var lower = load("res://scenes/room.tscn").instantiate()
	lower.passive = true
	lower.setup_apartment = found
	lower.position = Vector2(0, 160)
	holder.add_child(lower)
	await get_tree().process_frame
	var bd_plane := 0
	for z in get_tree().get_nodes_in_group("zombie"):
		if holder.is_ancestor_of(z) and z.on_balcony_plane and absf(z.global_position.y - (304.0 - BalconyGeo.RISE + 160.0)) <= 2.0:
			bd_plane += 1
	check(bd_plane == 1, "the backdrop shows it on the balcony, a floor down (%d)" % bd_plane)
	holder.free()
	await get_tree().process_frame
	# Re-entry restores it on the balcony.
	room = _plane_room(found)
	await get_tree().physics_frame
	var restored := false
	for z in get_tree().get_nodes_in_group("zombie"):
		if room.is_ancestor_of(z) and z.spawn_key == key:
			restored = z.on_balcony_plane
	check(restored, "re-entering, it's still out on the balcony")
	room.free()
	await get_tree().process_frame


func _test_descent_lands_on_plane() -> void:
	# Owner: a descent lands you ON the lower balcony (its plane), not in the apartment — you step
	# down into the room yourself (S).
	print("[descent lands on the balcony below]")
	WorldState.new_game()
	WorldState.is_first_run = false
	WorldState.master_seed = 4242
	WorldState.apartment_layouts.clear()
	var target := WorldState.descend_from_balcony("2301")
	check(target == "2201" and WorldState.spawn_source == "balcony", "descending from 2301 targets 2201")
	var room = load("res://scenes/room.tscn").instantiate()
	add_child(room)
	for i in range(3):
		await get_tree().physics_frame
	var p = room.get_node("Player")
	check(p.on_balcony_plane, "the player lands ON the balcony plane")
	check(absf(p.global_position.y + 33.0 - BalconyGeo.FEET) <= 1.0, "feet on the balcony line (%.1f)" % (p.global_position.y + 33.0))
	check(absf(p.global_position.x - float(room.balcony_centers[0])) <= BalconyGeo.HALF_WIDTH + 0.5, "inside the balcony rails")
	room.free()
	await get_tree().process_frame
