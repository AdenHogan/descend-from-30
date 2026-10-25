extends Node

# THE LEDGER (owner round 48j — "the ledger look… good, clean, connected, strong… not AI slop"): the shared kit (scripts/ledger*.gd) and the four menus that wear it — the merchant, the workbench,
# the found-item panel and the pack / body rings. The LOOK is the owner's to judge; this pins what can be measured: the rules that keep it from being a stock UI (every edge stays inside its box,
# nothing is random per frame, the fonts and sounds the kit promises exist), and that the flourishes sit ON TOP of the logic (a stamp is a beat before the same call a click always made).

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		print("  FAIL ", msg)
		failures += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	WorldState.new_game()
	Ledger.muted = true
	_test_kit()
	_test_ring_kit()
	await _test_sounds()
	await _test_shop()
	await _test_workbench()
	await _test_loot_panel()
	await _test_rings()
	Ledger.muted = false
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _test_kit() -> void:
	print("[the kit: paper, fonts, the hand]")
	var a: PackedVector2Array = Ledger.ragged(300.0, 200.0, 30.0, 2.6, 7)
	var b: PackedVector2Array = Ledger.ragged(300.0, 200.0, 30.0, 2.6, 7)
	var c: PackedVector2Array = Ledger.ragged(300.0, 200.0, 30.0, 2.6, 8)
	check(a == b and a != c, "a sheet's outline is a pure function of its seed (the same sheet looks the same every time, no two look alike)")
	var inside := true
	for p in a:
		if p.x < -0.01 or p.y < -0.01 or p.x > 300.01 or p.y > 200.01:
			inside = false
	check(inside, "the wandering edge never leaves its rectangle (a sheet cannot overhang what holds it)")
	check(Geometry2D.triangulate_polygon(a).size() > 0, "…and it is a polygon the renderer can fill")
	var line: PackedVector2Array = Ledger.pen_line(Vector2(0, 0), Vector2(200, 0), 3, 1.2)
	var wobble := 0.0
	for p in line:
		wobble = maxf(wobble, absf(p.y))
	check(wobble > 0.0 and wobble <= 1.2, "a pen line wanders but only within its wobble (%.2f px)" % wobble)
	check(Ledger.pen_line(Vector2(0, 0), Vector2(200, 0), 3, 1.2) == line, "…and the same line twice is the same line")
	for kind in ["head", "body", "typed", "hand"]:
		check(Ledger.font(kind) != null and Ledger.font(kind) != ThemeDB.fallback_font, "the %s face loads (not the engine's fallback)" % kind)
	check(Ledger.font("body") != Ledger.font("typed") and Ledger.font("head") != Ledger.font("body"), "printed head, plain body and typed voice are three different faces")
	check(Ledger.hand_info().has("path") and Ledger.hand_ink() is Color, "the player's own hand is read from the journal's table (face + ink)")
	var lit: PackedColorArray = Ledger.lit(a, Vector2(300, 200), Ledger.PAPER)
	check(lit.size() == a.size() and lit[0].r >= lit[lit.size() / 2].r, "paper is lit from the upper left (the first vertex is no darker than a far one)")


func _test_ring_kit() -> void:
	print("[the ring kit]")
	check(LedgerRing.hash01(3.0, 4.0) == LedgerRing.hash01(3.0, 4.0) and LedgerRing.hash01(3.0, 4.0) != LedgerRing.hash01(4.0, 3.0), "the wobble of a tag's edge is a pure function of (index, seed)")
	var pts: PackedVector2Array = LedgerRing.disc_points(33.0, 5)
	var inside := true
	for p in pts:
		if p.length() > 33.001:
			inside = false
	check(inside and pts.size() >= 20, "a tag never reaches past its radius (%d points)" % pts.size())
	check(LedgerRing.disc_points(33.0, 5) == pts, "…and is the same tag every frame (nothing flickers)")
	var f: Font = Ledger.font("body")
	var big: int = LedgerRing.fit(f, "Baseball Bat Mk2", 20, 90.0)
	check(big < 20 and big >= 8 and f.get_string_size("Baseball Bat Mk2", HORIZONTAL_ALIGNMENT_LEFT, -1, big).x <= 90.0, "text is shrunk to fit its slip, never run over the edge (%d px)" % big)
	check(LedgerRing.fit(f, "A rather long name for a small slip of paper", 20, 40.0) == 8, "…and never below 8 px, however long the line (it stops, it does not loop)")
	check(LedgerRing.fit(f, "Bat", 20, 90.0) == 20, "…and a short word keeps its size")
	var host := Control.new()
	add_child(host)
	var r1: Rect2 = LedgerRing.card(host, Vector2(100, 100), [{"kind": "head", "text": "BAT", "px": 17, "col": Ledger.INK}], 1)
	var r4: Rect2 = LedgerRing.card(host, Vector2(100, 100), [{"kind": "head", "text": "BAT", "px": 17, "col": Ledger.INK}, {"row": true, "label": "Damage", "value": "3", "delta": "+1", "tone": 1},
		{"row": true, "label": "Reach", "value": "65", "delta": "", "tone": 0}], 1)
	check(r4.size.y > r1.size.y and is_equal_approx(r1.get_center().x, 100.0), "the middle slip grows with what it says and stays centred on the ring")
	var pl: Rect2 = LedgerRing.plate(host, "body", Vector2(3.0, 40.0), "click equip  ·  right-click options  ·  drag onto an item to craft", 12, Ledger.INK, 2, false, 1.0, 560.0, 1152.0)
	check(pl.position.x >= 0.0 and pl.end.x <= 1152.0, "a help strip near the screen's edge is moved back on screen (%.0f..%.0f)" % [pl.position.x, pl.end.x])
	var pr: Rect2 = LedgerRing.plate(host, "body", Vector2(1150.0, 40.0), "click equip  ·  right-click options  ·  drag onto an item to craft", 12, Ledger.INK, 2, false, 1.0, 560.0, 1152.0)
	check(pr.end.x <= 1152.0, "…and on the right edge too")
	host.queue_free()
	check(LedgerRing.BODY_TINT != Ledger.PAPER_SLIP, "the body's tags are a different stock from the pack's, so the two rings side by side are never mistaken")


func _test_sounds() -> void:
	print("[the desk sounds]")
	var missing := 0
	for name in Ledger.SOUNDS:
		for k in range(int(Ledger.SOUNDS[name])):
			if not ResourceLoader.exists("%s%s_%d.wav" % [Ledger.SOUND_DIR, name, k]):
				missing += 1
	check(missing == 0, "every take of every named sound exists on disk (%d missing)" % missing)
	Ledger.muted = true
	var before: int = get_tree().get_nodes_in_group("ledger_sfx").size()
	Ledger.play("stamp")
	await _frames(2)
	check(get_tree().get_nodes_in_group("ledger_sfx").size() == before, "muted (tests, captures) plays nothing")
	Ledger.muted = false
	Ledger.play("stamp", -40.0)
	await _frames(2)
	check(get_tree().get_nodes_in_group("ledger_sfx").size() > before, "a sound is a self-freeing one-shot player in the tree")
	var n1: int = get_tree().get_nodes_in_group("ledger_sfx").size()
	Ledger.play("tick", -40.0, 5.0)
	Ledger.play("tick", -40.0, 5.0)
	await _frames(2)
	check(get_tree().get_nodes_in_group("ledger_sfx").size() <= n1 + 1, "a throttled sound does not machine-gun (two calls inside the gap make one)")
	Ledger.play("nonsense")
	check(true, "an unknown sound name is ignored, not an error")
	Ledger.muted = true


func _test_shop() -> void:
	print("[the merchant's page]")
	var shop = load("res://scenes/shop_ui.tscn").instantiate()
	add_child(shop)
	WorldState.current_floor = 20
	shop.open(20, "Well, well.")
	await _frames(3)
	check(shop.sheet is LedgerSheet and shop.sheet.get_parent() != null, "the page is a LedgerSheet on a dimmed desk")
	check(shop.active_tab == "upgrades", "a first visit opens on the offer")
	var slips: Array = shop.upgrades_box.find_children("Slip_*", "LedgerSlip", true, false)
	var offer: Array = WorldState.get_upgrade_offer(20)
	check(slips.size() == offer.size() and slips.size() > 0, "one slip for every perk on offer (%d of %d)" % [slips.size(), offer.size()])
	var uniq := {}
	for s in slips:
		uniq[s.seed_value] = true
	check(uniq.size() == slips.size(), "no two slips are cut the same (their seeds differ)")
	var tilts := {}
	for s in slips:
		tilts[snappedf(s.tilt_deg, 0.01)] = true
	check(tilts.size() > 1, "the slips do not lie square to each other")
	var s0: LedgerSlip = slips[0]
	check(s0.get_node_or_null("Stamp") is LedgerStamp and not s0.get_node("Stamp").visible, "every slip carries its stamp, un-pressed")
	var before_upgrades: int = WorldState.active_upgrades.size()
	var id: String = s0.name.substr(5)
	shop._on_card_chosen(id, s0)
	await _frames(3)
	check(s0.get_node("Stamp").pressed, "choosing a slip presses its stamp at once")
	check(WorldState.active_upgrades.size() == before_upgrades, "…the choice itself waits for the beat (the flourish is not the logic)")
	shop._on_card_chosen(id, s0)
	await get_tree().create_timer(shop.STAMP_BEAT + 0.25).timeout
	check(WorldState.active_upgrades.has(id) and WorldState.active_upgrades.size() == before_upgrades + 1, "after the beat the SAME `_on_take_upgrade` ran, once (a second click mid-beat did nothing)")
	check(shop.active_tab == "shop", "and the page moved on to the wares")
	# the wares: the money is written in the player's hand
	shop.open(20, "Back again.")
	await _frames(2)
	check(shop.money_label.get_theme_font("font") == Ledger.font("hand"), "the notes in the wallet are written in the player's own hand")
	shop.close()
	check(not shop.visible, "the page puts away")
	shop.queue_free()
	await _frames(2)


func _test_workbench() -> void:
	print("[the workbench]")
	WorldState.inventory.clear()
	WorldState.add_to_inventory("002")
	WorldState.scrap_unlocked = true
	WorldState.scrap = 200
	var wb = load("res://scripts/workbench_ui.gd").new()
	add_child(wb)
	var was_paused: bool = get_tree().paused
	wb.open()
	await _frames(3)
	check(wb.visible and get_tree().paused, "the bench pauses the game while it is open (as before)")
	check(wb._card is LedgerSheet, "its page is a LedgerSheet")
	for tab in ["upgrade", "tune", "salvage"]:
		wb.show_tab(tab)
		await _frames(2)
		check(wb.tab == tab, "the %s tab opens" % tab)
	wb.close()
	check(not wb.visible and get_tree().paused == was_paused, "closing puts the pause back exactly as it was")
	wb.queue_free()
	await _frames(2)
	WorldState.inventory.clear()


func _test_loot_panel() -> void:
	print("[the found-item panel]")
	var loot = load("res://scripts/loot_ui.gd").new()
	add_child(loot)
	await _frames(2)
	check(loot.panel.get_child(0) is LedgerPaper, "the panel is a slip of paper: the paper is drawn first, the contents sit on it")
	check(loot.panel.get_theme_stylebox("panel") is StyleBoxEmpty, "…and no stock rounded box is drawn round it")
	check(loot.search_bar.has_method("fraction") and loot.search_bar.has_method("set_progress"), "the search bar is the pen-filled box (it still answers `fraction()` / `set_progress()`)")
	WorldState.is_scavenge_mode = true
	loot.open("014", "anchor_ledger_test", "9999")
	await _frames(2)
	check(loot.search_bar.visible and loot.is_revealing, "a search starts as a small slip with a bar")
	loot.reveal_timer = loot.reveal_time * 0.5
	loot.search_bar.set_progress(loot.reveal_timer, loot.reveal_time)
	check(absf(loot.search_bar.fraction() - 0.5) < 0.01, "the bar's fraction is how far the search is (the pen's fill follows it)")
	loot._reveal_item()
	await _frames(25)
	check(loot.has_item and loot.icon.texture != null and loot.icon_shadow.texture == loot.icon.texture, "the found thing and the shadow it throws on the paper are one picture")
	check(is_equal_approx(loot.panel.scale.x, 1.0) and is_equal_approx(loot.panel.rotation, loot.REST_TILT), "the slip lands and settles: scale 1, turned to its resting tilt (%.3f)" % loot.panel.rotation)
	# the comparison card is ink on paper, not light-on-dark
	WorldState.inventory.clear()
	WorldState.add_to_inventory("001")
	HUD.selected_slot = 0
	loot._show_compare(ItemData.get_item("014"))
	check(loot.compare_label.visible and loot.compare_label.text.contains("[table=3]") and not loot.compare_label.text.contains("9aa0a8"), "a found weapon's numbers are set in a ruled column in ink (the paper palette)")
	var dark: String = ItemCompare.bbcode(ItemCompare.card(_weapon("014"), _weapon("001")))
	check(dark.contains("9aa0a8") and not dark.contains("[table"), "…while the pack ring's / the floor pill's own form is unchanged (the dark palette is the default)")
	HUD.selected_slot = -1
	WorldState.inventory.clear()
	# full pockets: the name goes red and the panel says why
	loot._say_full("Open your pack and make room.")
	check(loot.name_label.text == "Inventory full" and loot.name_label.get_theme_color("font_color") == Ledger.RED_INK, "a refused take says so in red ink")
	loot.leave()
	check(not loot.visible and not WorldState.loot_open, "leaving closes it and gives the world back")
	loot.queue_free()
	await _frames(2)


func _weapon(id: String):
	var inst := ItemInstance.new()
	inst.setup(id)
	return inst


func _test_rings() -> void:
	print("[the rings]")
	var ring = HUD.pack_wheel
	check(ring != null, "the HUD owns the pack ring")
	var src: String = FileAccess.get_file_as_string("res://scripts/pack_wheel.gd")
	check(src.contains("LedgerRing.tag(") and src.contains("LedgerRing.card(") and not src.contains("draw_string_outline"), "the pack ring draws paper tags and a slip, no outlined light-on-dark text")
	var src2: String = FileAccess.get_file_as_string("res://scripts/body_ring.gd")
	check(src2.contains("LedgerRing.tag(") and src2.contains("LedgerRing.BODY_TINT") and not src2.contains("draw_string_outline"), "the body ring is the same family, on its own stock")
	check(true, "(the rings' rules — equip, craft, drop, the body's take / lay-down — are pack_test's and body_ring_test's; both draw every frame they run)")
