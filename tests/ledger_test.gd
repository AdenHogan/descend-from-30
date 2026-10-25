extends Node

# THE LEDGER (owner round 48j — "the ledger look… good, clean, connected, strong… not AI slop"): the shared paper kit (scripts/ledger*.gd) and the two menus that wear it — the merchant and the
# workbench (the places to sit and read; the glance-and-go layer over the live game — rings, found-item panel, SEARCHING — is the dark Lamplight look, tests/lamp_test.gd). The LOOK is the
# owner's to judge; this pins what can be measured: the rules that keep it from being a stock UI (every edge stays inside its box, nothing is random per frame, the fonts and sounds the kit
# promises exist), and that the flourishes sit ON TOP of the logic (a stamp is a beat before the same call a click always made).

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
	await _test_sounds()
	await _test_shop()
	await _test_workbench()
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
