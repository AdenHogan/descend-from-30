extends Node

# THE LAMPLIGHT (owner round 48j — "give me a version of the wheel that looked like the dark and goldish one… way too much text… if we even need text, it needs to be one word… the word
# searching literally can be the bar, from the S to the G"): the dark-glass / brass kit (scripts/lamp.gd), the pack + body rings that wear it, the found-item panel, and SEARCHING.
# The LOOK is the owner's to judge. This pins what can be measured: the palette is the mock-up's, nothing says more than a word where a word will do, the middle card always fits between
# the slots, SEARCHING lights its letters in order and resolves, and the search never leaves a panel on the screen.
# Round 48l ("a big UI disconnect. So many different font styles, colours, and types of text… too many longer bits of text which are small and tough to read… didn't we change this back to
# the black and gold version?"): the WORKBENCH, the MERCHANT and the HUD's top-of-screen message wear the same kit — one type scale, the kit's three faces and no handwriting, ONE verb
# (UPGRADE) on the button at every level, a checklist that says what a step needs against what you have, a button that cannot act yet is dim but pressable and says why when pressed.

const StubScript := preload("res://tests/_anchor_stub.gd")
const RingGeo := preload("res://scripts/ring_geo.gd")

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
	await _test_search_word()
	await _test_loot_panel()
	await _test_found_tag_in_the_world()
	await _test_rings()
	await _test_workbench()
	await _test_shop()
	await _test_feedback_pill()
	Ledger.muted = false
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _weapon(id: String):
	var inst := ItemInstance.new()
	inst.setup(id)
	return inst


func _test_kit() -> void:
	print("[the kit]")
	var board := {"BRASS": [Lamp.BRASS, "d9a441"], "BRASS_HI": [Lamp.BRASS_HI, "f0b95a"], "BRASS_DIM": [Lamp.BRASS_DIM, "8a6a34"], "CARD": [Lamp.CARD, "1b140d"], "EDGE": [Lamp.EDGE, "4a3920"],
		"TEXT": [Lamp.TEXT, "f0e2bd"], "GREEN": [Lamp.GREEN, "9fd18a"], "RED": [Lamp.RED, "e07a66"], "STEEL": [Lamp.STEEL, "6fa8d6"]}
	var wrong: Array = []
	for k in board:
		var c: Color = board[k][0]
		if c.to_html(false) != String(board[k][1]):
			wrong.append("%s %s (board: %s)" % [k, c.to_html(false), board[k][1]])
	check(wrong.is_empty(), "the palette is the Lamplight board's, hex for hex (%s)" % ", ".join(wrong))
	check(Lamp.font("label") != Lamp.font("head") and Lamp.font("head") != Lamp.font("body"), "heads, letter-spaced captions and plain text are three different settings of the type")
	check((Lamp.font("label") as FontVariation).spacing_glyph > (Lamp.font("head") as FontVariation).spacing_glyph, "a caption is letter-spaced wider than a head")
	var f: Font = Lamp.font("body")
	var big: int = Lamp.fit(f, "Baseball Bat Mk2", 20, 90.0)
	check(big < 20 and big >= 8 and f.get_string_size("Baseball Bat Mk2", HORIZONTAL_ALIGNMENT_LEFT, -1, big).x <= 90.0, "text is shrunk to fit, never run over the edge (%d px)" % big)
	check(Lamp.fit(f, "A rather long name for a small card", 20, 40.0) == 8 and Lamp.fit(f, "Bat", 20, 90.0) == 20, "…it stops at 8 px rather than loop, and a short word keeps its size")
	# the rows worth a glance
	var rows: Array = [{"label": "Damage", "text": "3", "delta": "", "tone": 0}, {"label": "Speed", "text": "1.2 /s", "delta": "", "tone": 0}, {"label": "Reach", "text": "65", "delta": "▲ +33", "tone": 1},
		{"label": "Stamina", "text": "26", "delta": "▲ +18", "tone": -1}, {"label": "Durability", "text": "8 / 8", "delta": "", "tone": 0}]
	var picked: Array = Lamp.pick_rows(rows, 3)
	var labels: Array = []
	for r in picked:
		labels.append(r["label"])
	check(picked.size() == 3 and labels.has("Reach") and labels.has("Stamina"), "of five rows the three that DIFFER come first (%s)" % str(labels))
	check(labels == ["Damage", "Reach", "Stamina"] or labels == ["Reach", "Stamina", "Durability"] or labels.size() == 3, "…and stay in the card's own order (they never shuffle between items)")
	var plain: Array = []
	for r in rows:
		var rr: Dictionary = r.duplicate()
		rr["delta"] = ""
		plain.append(rr)
	var labels2: Array = []
	for r in Lamp.pick_rows(plain, 3):
		labels2.append(r["label"])
	check(labels2 == ["Damage", "Speed", "Durability"], "with nothing to compare, the usual three: damage, speed, durability (%s)" % str(labels2))
	# the middle card
	var one: Vector2 = Lamp.info_size([{"title": "Bat"}])
	var four: Vector2 = Lamp.info_size([{"title": "Bat"}, {"row": true, "label": "a", "text": "1", "delta": "", "tone": 0}, {"row": true, "label": "b", "text": "1", "delta": "", "tone": 0}, {"row": true, "label": "c", "text": "1", "delta": "", "tone": 0}])
	check(four.y > one.y and four.x > one.x, "the card grows with what it says, and is wider when it carries rows")
	check(Lamp.kind_word(_weapon("001").get_data()) == "BLADE" and Lamp.kind_word(_weapon("006").get_data()) == "MEDICAL" and Lamp.kind_word({}) == "FOUND", "an item's caption is one word: its kind, else FOUND")
	var all_one := true
	var bad_word := ""
	for id in ItemData.items:
		var kw: String = Lamp.kind_word(ItemData.get_item(String(id)))
		if kw.contains(" ") or kw == "":
			all_one = false
			bad_word = "%s: '%s'" % [id, kw]
	check(all_one, "…for EVERY item in the game (%s)" % bad_word)


func _test_search_word() -> void:
	print("[SEARCHING]")
	var w := SearchWord.new()
	add_child(w)
	await _frames(1)
	check(not w.visible and not w.active, "it is not there until a search starts")
	w.resolve(true)
	check(not w.resolving, "…and a resolve with no search is ignored")
	w.begin()
	check(w.visible and w.active and w.fraction() == 0.0 and w.lit_letters() == 0, "a search starts with every letter dim")
	var last := 0
	var in_order := true
	for i in range(0, 101):
		w.set_progress(float(i), 100.0)
		var lit: int = w.lit_letters()
		if lit < last or lit > SearchWord.WORD.length():
			in_order = false
		last = lit
	check(in_order and last == SearchWord.WORD.length(), "the letters light one after another, S first and G last, and never go back (%d of %d lit at the end)" % [last, SearchWord.WORD.length()])
	w.set_progress(4.5, 9.0)
	check(w.lit_letters() == 4 and absf(w.fraction() - 0.5) < 0.001, "half-way, four letters are lit and the fifth is on its way (S E A R · C)")
	w.resolve(true)
	check(w.resolving and w.found and absf(w.fraction() - 1.0) < 0.001, "the search ends: the word resolves where it hangs — found")
	await get_tree().create_timer(SearchWord.RESOLVE_TIME + 0.2).timeout
	check(not w.visible and not w.active, "…and is gone after its beat")
	w.begin()
	w.set_progress(9.0, 9.0)
	w.resolve(false)
	check(w.resolving and not w.found, "an empty search resolves as nothing (the letters go grey and sink)")
	w.cancel()
	check(not w.visible and not w.resolving, "a search walked away from takes the word with it at once")
	w.queue_free()
	await _frames(1)


func _test_loot_panel() -> void:
	print("[the search and the found panel]")
	WorldState.inventory.clear()
	WorldState.add_to_inventory("001")
	HUD.selected_slot = 0
	var loot = load("res://scripts/loot_ui.gd").new()
	add_child(loot)
	var anchor := StubScript.new()
	anchor.name = "anchor_lamp_test"
	add_child(anchor)
	anchor.global_position = Vector2(300.0, 220.0)
	await _frames(2)
	check(loot.panel.get_child(0) is LampGlass and loot.panel.get_theme_stylebox("panel") is StyleBoxEmpty, "the result panel is dark glass drawn first, the contents on it, no stock box round it")
	check(not ("search_bar" in loot) and loot.search_word is SearchWord, "there is no progress bar any more — the word is the readout")
	WorldState.is_scavenge_mode = true
	loot.open("014", "anchor_lamp_test", "9999")
	await _frames(2)
	check(loot.is_revealing and loot.visible and not loot.panel.visible, "while it searches there is NO panel — the room and the player stay in view")
	check(loot.search_word.visible and loot.search_word.fraction() < 0.05 and loot.search_word.lit_letters() == 0, "…just the word SEARCHING, nothing lit yet")
	var c: Vector2 = loot.search_word.position + loot.search_word.size * 0.5
	check(absf(c.x - 300.0) < 1.5 and c.y < 220.0 and c.y > 220.0 - 80.0, "it hangs just above the node being searched (%.0f, %.0f over a node at 300, 220)" % [c.x, c.y])
	loot._process(loot.reveal_time * 0.5)
	check(absf(loot.search_word.fraction() - 0.5) < 0.02 and loot.search_word.lit_letters() == 4, "half way through, half the word is lit (%d letters)" % loot.search_word.lit_letters())
	loot._process(loot.reveal_time)
	await _frames(2)
	check(loot.has_item and loot.panel.visible and not loot.is_revealing, "when the last letter is lit the result panel arrives")
	check(loot.search_word.resolving and loot.search_word.found, "…and the word has resolved as FOUND")
	check(loot.kind_label.text == "BLUNT" and loot.name_label.text == "Baseball Bat", "the panel names it: one caption word (%s) over the name (%s)" % [loot.kind_label.text, loot.name_label.text])
	check(loot.hint_label.text.contains("TAKE") and loot.hint_label.text.split(" ", false).size() <= 4, "the only text under it is the key and one word (%s)" % loot.hint_label.text.strip_edges())
	loot._show_compare(ItemData.get_item("014"))
	var found_inst := ItemInstance.new()
	found_inst.setup("014")
	var cmp_card: Dictionary = ItemCompare.card(found_inst, ItemCompare.held_weapon())
	var differing := 0
	for r in cmp_card.get("rows", []):
		if String(r["delta"]) != "":
			differing += 1
	check(loot.compare_label.visible == (differing > 0 and String(cmp_card.get("vs", "")) != ""), "a found weapon shows numbers only when some DIFFER from the one in hand (%d differ)" % differing)
	if loot.compare_label.visible:
		var all_differ := true
		for r in loot.compare_label.rows:
			all_differ = all_differ and String(r["delta"]) != ""
		check(loot.compare_label.rows.size() == mini(differing, 2) and all_differ and loot.compare_label.height() > 0.0, "…only those rows, at most two (%d shown) — never the whole table" % loot.compare_label.rows.size())
	loot._show_compare(ItemData.get_item("006"))
	check(not loot.compare_label.visible, "…and only a weapon does")
	await _frames(20)
	check(is_equal_approx(loot.panel.scale.x, 1.0) and is_equal_approx(loot.panel.modulate.a, 1.0), "the panel settles: full size, fully there")
	loot._say_full("Open your pack and make room.")
	check(loot.name_label.text == "Inventory full" and loot.name_label.get_theme_color("font_color") == Lamp.RED and loot.hint_label.text == "MAKE ROOM", "a refused take turns the name red and says two words: MAKE ROOM")
	loot.leave()
	check(not loot.visible and not WorldState.loot_open, "leaving closes it and gives the world back")
	# nothing found: no panel at all, the word says so
	loot.open("", "anchor_lamp_empty", "9997")
	check(loot.is_revealing and not loot.panel.visible and loot.search_word.visible, "an empty node searches the same way (no panel)")
	loot._process(loot.reveal_time + 0.1)
	check(not loot.has_item and not loot.visible and not loot.panel.visible and loot.search_word.resolving and not loot.search_word.found,
		"…and ends as NOTHING: the word goes grey, no panel ever shows, a line is said in passing")
	await get_tree().create_timer(SearchWord.RESOLVE_TIME + 0.2).timeout
	check(not loot.search_word.visible, "…and the word is gone")
	# walked away from mid-search: the word goes at once
	loot.open("014", "anchor_lamp_test", "9998")
	loot._process(0.5)
	check(loot.search_word.visible, "a second search lights up")
	loot.leave()
	check(not loot.search_word.visible and not loot.search_word.resolving, "leaving mid-search takes the word with it (nothing is left hanging in the room)")
	HUD.selected_slot = -1
	WorldState.inventory.clear()
	anchor.queue_free()
	loot.queue_free()
	await _frames(2)


## The found-item tag stands IN THE WORLD beside its node (owner round 48l: "put the box in the game world too, smaller, beside the node"), and shows by itself when the player walks back up
## to a node they searched but did not empty; [interact] then takes it in one press.
func _test_found_tag_in_the_world() -> void:
	print("[the found-item tag beside its node]")
	WorldState.new_game()
	WorldState.is_scavenge_mode = true
	WorldState.inventory.clear()
	HUD.selected_slot = -1
	var loot = load("res://scripts/loot_ui.gd").new()
	add_child(loot)
	var player = load("res://scenes/player.tscn").instantiate()
	add_child(player)
	var anchor := StubScript.new()
	anchor.name = "anchor_pv"
	anchor.apartment_id = "9996"
	anchor.add_to_group("scavenge_anchor")
	add_child(anchor)
	anchor.global_position = Vector2(300.0, 220.0)
	anchor.is_in_range = true
	await _frames(3)
	var tag: PanelContainer = loot._preview["panel"]
	# not searched yet -> nothing to show; searched and empty -> nothing; searched and still holding -> the tag
	WorldState.set_anchor_item("9996", "anchor_pv", "006")
	loot._process(0.016)
	check(not tag.visible and loot.preview_target() == null, "a node that was never searched shows no tag")
	WorldState.mark_anchor_searched("9996", "anchor_pv")
	loot._process(0.016)
	check(loot.preview_showing_for(anchor) and tag.visible, "walking back up to a searched node that still holds something: its tag stands there by itself")
	check(not WorldState.loot_open and not loot.visible, "…and it is a glance, not a lock: nothing is open, nothing is blocked")
	check(loot._preview["name"].text == "Bandages" and loot._preview["hint"].text.contains("TAKE"), "it names the thing and says the key (%s / %s)" % [loot._preview["name"].text, loot._preview["hint"].text])
	check(tag.position.x > anchor.global_position.x and absf((tag.position.y + tag.size.y * 0.5) - anchor.global_position.y) < tag.size.y, "it stands beside the node (the tag at %.0f, %.0f; the node at 300, 220)" % [tag.position.x, tag.position.y])
	check(tag.size.x <= 320.0 and tag.size.y <= 190.0, "…small: %dx%d (the old centred panel was 380 wide)" % [int(tag.size.x), int(tag.size.y)])
	anchor.global_position = Vector2(1100.0, 220.0)                                    # near the right edge: the tag goes to the node's LEFT, on the screen
	loot._process(0.016)
	check(tag.position.x + tag.size.x < 1100.0 and tag.position.x >= 0.0, "near the screen's edge it stands on the other side of the node (%.0f..%.0f)" % [tag.position.x, tag.position.x + tag.size.x])
	anchor.global_position = Vector2(300.0, 220.0)
	anchor.is_in_range = false
	loot._process(0.016)
	check(not tag.visible, "walk out of reach and it goes")
	anchor.is_in_range = true
	WorldState.is_scavenge_mode = false
	loot._process(0.016)
	check(not tag.visible, "in combat stance it is not shown (the nodes themselves are dark then)")
	WorldState.is_scavenge_mode = true
	WorldState.clear_anchor_item("9996", "anchor_pv")
	loot._process(0.016)
	check(not tag.visible, "a node that was emptied shows nothing")
	# one press takes it
	WorldState.set_anchor_item("9996", "anchor_pv", "006")
	loot._process(0.016)
	check(loot.preview_showing_for(anchor), "(a left-over node again)")
	var before: int = WorldState.inventory.size()
	loot.open("006", "anchor_pv", "9996", anchor)
	check(WorldState.inventory.size() == before + 1 and not WorldState.loot_open and not loot.visible and WorldState.get_anchor_item("9996", "anchor_pv") == "", "[interact] while its tag is up takes it in ONE press")
	loot._process(0.016)
	check(not tag.visible, "…and the tag goes with it")
	# a full pack: the same press leaves the tag up saying MAKE ROOM (as a second press always did)
	while WorldState.inventory.size() < WorldState.get_inventory_slots():
		WorldState.add_to_inventory("002")
	WorldState.set_anchor_item("9996", "anchor_pv", "011")
	WorldState.mark_anchor_searched("9996", "anchor_pv")
	loot._process(0.016)
	check(loot.preview_showing_for(anchor), "(a full pack, a left-over node)")
	loot.open("011", "anchor_pv", "9996", anchor)
	check(loot.visible and loot.has_item and loot.name_label.text == "Inventory full" and WorldState.loot_open, "a full pack refuses: the tag stays, red, saying MAKE ROOM — nothing is lost")
	check(not tag.visible and loot.panel.visible, "…and the live tag has taken over from the preview")
	# the ring opened beside it never covers it
	var half := 208.0
	var rect := Rect2(loot.panel.position, loot.panel.size)
	var centre: Vector2 = loot.ring_centre(half, rect.get_center())
	var nearest := Vector2(clampf(centre.x, rect.position.x, rect.end.x), clampf(centre.y, rect.position.y, rect.end.y))
	check(nearest.distance_to(centre) >= half - 10.0 and centre.x >= half and centre.x <= 1152.0 - half, "a ring that would have opened on the tag moves along the row to clear it (%.0f, %.0f)" % [centre.x, centre.y])
	var far := Vector2(rect.end.x + 400.0, 330.0)
	check(loot.ring_centre(half, far) == far, "…and one that already clears it stays where it was")
	loot.leave()
	WorldState.inventory.clear()
	player.queue_free()
	anchor.queue_free()
	loot.queue_free()
	await _frames(2)


func _test_rings() -> void:
	print("[the rings]")
	var pw = HUD.pack_wheel
	check(pw != null and HUD.body_ring != null, "the HUD owns both rings")
	var src: String = FileAccess.get_file_as_string("res://scripts/pack_wheel.gd")
	var src2: String = FileAccess.get_file_as_string("res://scripts/body_ring.gd")
	check(src.contains("Lamp.slot(") and src.contains("Lamp.info(") and src.contains("Lamp.menu(") and not src.contains("LedgerRing"), "the pack ring is drawn in the lamplight kit — slots, the one card, the menu — and no longer in paper")
	check(src2.contains("Lamp.slot(") and src2.contains("Lamp.STEEL") and not src2.contains("LedgerRing"), "the body ring is the same family in steel, so two rings side by side are never mistaken")
	check(Lamp.STEEL != Lamp.BRASS and not pw.has_method("hint_text") and not ("HINT" in pw), "and there is no help strip over the ring any more")
	# the card in the middle always fits between the slots
	var worst: Vector2 = Lamp.info_size([{"title": "x"}, {"row": true, "label": "a", "text": "1", "delta": "", "tone": 0}, {"row": true, "label": "b", "text": "1", "delta": "", "tone": 0},
		{"row": true, "label": "c", "text": "1", "delta": "", "tone": 0}, {"word": "BROKEN"}])
	var card := Rect2(-worst * 0.5, worst)
	var clear := true
	for n in [3, 4, 5, 6]:
		for k in range(n):
			var p: Vector2 = RingGeo.slot_position(Vector2.ZERO, k, n, pw.RING_R)
			var box := Rect2(p - Vector2(pw.DISC, pw.DISC) * 0.5, Vector2(pw.DISC, pw.DISC))
			if card.intersects(box):
				clear = false
	check(clear, "the card in the middle (up to %dx%d) never overlaps a slot, for any pack from 3 wedges to 6" % [int(worst.x), int(worst.y)])
	# one word, everywhere
	WorldState.inventory.clear()
	for id in ["001", "014", "006", "009", "024"]:
		WorldState.add_to_inventory(id)
	pw.slots = pw.build_slots()
	pw.centre = Vector2(300.0, 300.0)
	HUD.select_slot(0)
	var words_ok := true
	var seen_menu := ""
	for k in range(5):
		pw.open_menu(k)
		for r in pw.menu_rows:
			seen_menu += String(r[0]) + " "
			if String(r[0]).contains(" "):
				words_ok = false
	pw.close_menu()
	check(words_ok, "every right-click menu row is one word (%s)" % seen_menu.strip_edges())
	pw.open_menu(0)
	check(String(pw.menu_rows[0][0]) == "Unequip", "the one in hand offers Unequip")
	pw.close_menu()
	var bad_line := ""
	var states: Array = []
	pw.drag_k = -1
	pw.hover = -1
	states.append(pw._middle_lines({}))                    # nothing under the pointer: CLOSE
	pw.hover = 1
	states.append(pw._middle_lines({}))                    # an item: its name and numbers
	pw.slots = [0, 1, pw.LOCKED_SLOT]
	pw.hover = 2
	states.append(pw._middle_lines({}))                    # the locked slot
	pw.slots = pw.build_slots()
	pw.hover = -1
	pw.drag_k = 3                                          # dragging the torn clothes…
	pw._mouse = Vector2(900.0, 150.0)
	states.append(pw._middle_lines({}))                    # …off the ring: DROP
	pw.hover = 4
	states.append(pw._middle_lines(pw._drag_plans(pw.slots.size())))      # …onto the bottle: CRAFT
	pw.drag_k = -1
	pw.hover = -1
	var kinds := {}
	for lines in states:
		for l in lines:
			for key in ["word", "big"]:
				if l.has(key):
					kinds[String(l[key])] = true
					if String(l[key]).contains(" ") or String(l[key]) == "":
						bad_line = String(l[key])
	check(bad_line == "" and kinds.has("CLOSE") and kinds.has("LOCKED") and kinds.has("DROP") and kinds.has("CRAFT"), "every readout is a single word: %s" % str(kinds.keys()))
	var craft: Array = states[4]
	check(craft.size() == 2 and String(craft[1]["title"]) == "Molotov Cocktail", "dragging a bottle onto torn clothes says CRAFT over what it makes (%s)" % str(craft))
	HUD.select_slot(-1)
	pw.slots = []
	WorldState.inventory.clear()


# ---------------------------------------------------------------------------------------------------------------------------------- round 48l: the workbench, the merchant, the message line
const SCALE := [32, 26, 20, 18]


func _all(n: Node, out: Array = []) -> Array:
	out.append(n)
	for c in n.get_children():
		_all(c, out)
	return out


## Every Label / button / text box under `root`: its face must be one of the kit's three and its size one of the four on the scale (nothing falls back to the default font, nothing is a one-off size).
func _type_audit(root: Node) -> String:
	var bad: PackedStringArray = []
	var faces := [Lamp.font("head"), Lamp.font("label"), Lamp.font("body")]
	for n in _all(root):
		if n is Label:
			var f: Font = n.get_theme_font("font")
			var px: int = n.get_theme_font_size("font_size")
			if not (f in faces) or not (px in SCALE):
				bad.append("'%s' (%d px)" % [String(n.text).left(18), px])
		elif n is LampButton:
			if not (n.px in SCALE):
				bad.append("button '%s' (%d px)" % [n.text, n.px])
		elif n is LineEdit:
			if not (n.get_theme_font("font") in faces) or not (n.get_theme_font_size("font_size") in SCALE):
				bad.append("text box")
	return ", ".join(bad)


## Every visible Control under `root` lies inside `root`'s rectangle.
func _outside(root: Control) -> String:
	var r: Rect2 = root.get_global_rect().grow(1.0)
	var out: PackedStringArray = []
	for n in _all(root):
		if n is Control and n != root and n.is_visible_in_tree() and n.size.x > 0.0 and not (n is ScrollContainer):
			var gr: Rect2 = (n as Control).get_global_rect()
			if not r.encloses(gr) and not (n.get_parent() is ScrollContainer):
				out.append("%s %s" % [n.get_class(), str(gr)])
	return ", ".join(out)


func _test_workbench() -> void:
	print("[the workbench: Lamplight, one type scale, one verb, a checklist that says what you have]")
	WorldState.new_game()
	var h1 = _weapon("002")
	var h2 = _weapon("002")
	WorldState.inventory = [h1, h2]
	WorldState.scrap_unlocked = true
	WorldState.scrap = 20
	var wb = load("res://scripts/workbench_ui.gd").new()
	add_child(wb)
	var was_paused: bool = get_tree().paused
	wb.open()
	await _frames(3)
	check(wb.visible and get_tree().paused, "the bench pauses the game while it is open")
	check(wb._card.get_child(0) is LampGlass and wb._card.get_child(0).size == wb._card.size, "the panel is the kit's dark glass, and it covers the whole panel (%s of %s)" % [str(wb._card.get_child(0).size), str(wb._card.size)])
	for tab in ["upgrade", "tune", "salvage"]:
		wb.show_tab(tab)
		await _frames(3)
		var t: String = _type_audit(wb._card)
		check(t == "", "%s: only the kit's three faces, only the four sizes (%s)" % [tab, t])
		var o: String = _outside(wb._card)
		check(o == "", "%s: everything lies inside the panel (%s)" % [tab, o])
	wb.show_tab("upgrade")
	await _frames(2)
	# the checklist, against what you have
	check(wb._upgrade_btn.text == "UPGRADE" and wb._upgrade_btn.solid, "Lv1 -> 2: the button says UPGRADE")
	check(wb._needs.rows.size() == 1 and wb._needs.rows[0]["label"] == "SCRAP" and not wb._needs.rows[0]["ok"] and String(wb._needs.rows[0]["have"]).contains("20"),
		"with 20 scrap the SCRAP row is crossed and says what you have (%s)" % wb._needs.text)
	check(wb._upgrade_btn.looks_off and not wb._upgrade_btn.disabled, "…the button looks off, but stays pressable")
	wb._on_upgrade_pressed()
	check(wb._msg_kind == "err" and wb._msg.text.contains("30 scrap") and h1.level == 1 and WorldState.scrap == 20, "pressing it says why, in red (%s) and spends nothing" % wb._msg.text)
	WorldState.scrap = 400
	wb.refresh()
	check(wb._needs.rows[0]["ok"] and not wb._upgrade_btn.looks_off, "with the scrap the row is ticked and the button lights")
	wb._on_upgrade_pressed()
	check(h1.level == 2 and wb._msg_kind == "ok" and wb._msg.text.contains("Upgraded to Lv 2"), "it upgrades, and says so in green (%s)" % wb._msg.text)
	# Lv2 -> 3: a pick of two
	check(wb._upgrade_btn.text == "UPGRADE" and not wb._next_caption.text.contains("REINFORCE") and not wb._next_caption.text.contains("TEMPER"), "Lv2 -> 3: still UPGRADE (the old button said REINFORCE here)")
	var cards: Array = wb._perk_box.find_children("Card_*", "LampCard", true, false)
	check(cards.size() == 2 and wb._upgrade_btn.looks_off, "two cards to choose from, and the button waits for a choice")
	wb._on_upgrade_pressed()
	check(wb._msg.text.contains("Pick one") and h1.level == 2, "pressing it early says to pick one (%s)" % wb._msg.text)
	cards[0].chosen.emit()
	await _frames(2)
	cards = wb._perk_box.find_children("Card_*", "LampCard", true, false)
	check(cards[0].held and not cards[1].held and not wb._upgrade_btn.looks_off, "a click lights the card (CHOSEN) and the button")
	var t3: String = _type_audit(wb._card)
	check(t3 == "", "with the cards up: only the kit's faces and sizes (%s)" % t3)
	wb._on_upgrade_pressed()
	check(h1.level == 3 and wb._msg.text.contains("2 tuning points"), "Lv3, and the message says where the points are spent (%s)" % wb._msg.text)
	# Lv3 -> 4: a spare is stripped for parts
	check(wb._needs.rows.size() == 2 and wb._needs.rows[1]["label"] == "SPARE" and wb._needs.rows[1]["ok"] and String(wb._needs.rows[1]["have"]).begins_with("your "), "the spare is a row of its own, ticked when you carry one (%s)" % wb._needs.text)
	check(wb._next_caption.text.contains("LV 4") and wb._next_caption.text.contains("2 TUNING POINTS"), "what the level gives is the caption (%s)" % wb._next_caption.text)
	# the tune page: one line of guidance, a grid that fits
	wb.show_tab("tune")
	await _frames(3)
	check(wb._points_label.text.contains("POINTS") and wb._points_label.text.contains("free of"), "TUNE says how many points are free (%s)" % wb._points_label.text)
	check(wb._msg.text.contains("One point raises one stat"), "…and in one line what a point is (%s)" % wb._msg.text)
	check(wb.TUNE_NAME_W + wb.TUNE_PIPS_W + 2.0 * wb.TUNE_BTN_W + wb.TUNE_DESC_W + 4.0 * wb.TUNE_GAP <= wb.RIGHT_W + 0.01 and wb.TUNE_DESC_W >= 200.0, "the tune columns fit the pane (%.0f of %.0f)" % [wb.TUNE_NAME_W + wb.TUNE_PIPS_W + 2.0 * wb.TUNE_BTN_W + wb.TUNE_DESC_W + 4.0 * wb.TUNE_GAP, wb.RIGHT_W])
	check(wb._tune_grid.get_global_rect().end.y <= wb._set_btn.get_global_rect().position.y + 1.0, "the grid ends above the button (%.0f / %.0f)" % [wb._tune_grid.get_global_rect().end.y, wb._set_btn.get_global_rect().position.y])
	wb.close()
	check(not wb.visible and get_tree().paused == was_paused, "closing puts the pause back exactly as it was")
	wb.queue_free()
	await _frames(2)
	WorldState.inventory.clear()


func _test_shop() -> void:
	print("[the merchant: the same kit, one card per perk, one row per ware]")
	WorldState.new_game()
	var shop = load("res://scenes/shop_ui.tscn").instantiate()
	add_child(shop)
	WorldState.current_floor = 20
	shop.open(20, "Well, well.")
	await _frames(4)
	check(shop.sheet.get_child(0) is LampGlass and shop.sheet.get_child(0).size == shop.sheet.size, "the page is the kit's dark glass, and it covers the whole page (%s of %s)" % [str(shop.sheet.get_child(0).size), str(shop.sheet.size)])
	check(shop.active_tab == "upgrades", "a first visit opens on the offer")
	var cards: Array = shop.upgrades_box.find_children("Card_*", "LampCard", true, false)
	var offer: Array = WorldState.get_upgrade_offer(20)
	check(cards.size() == offer.size() and cards.size() > 0, "one card for every perk on offer (%d of %d)" % [cards.size(), offer.size()])
	var t: String = _type_audit(shop.sheet)
	check(t == "", "the offer: only the kit's three faces and four sizes (%s)" % t)
	check(shop.rarity_word({"w": 1}) == "RARE" and shop.rarity_ink({"drawback": true}) == Lamp.RED and shop.rarity_ink({"kind": "boon"}) == Lamp.GREEN, "a card names its rarity; a trade-off is the kit's red, a good turn its green")
	var c0: LampCard = cards[0]
	var before_upgrades: int = WorldState.active_upgrades.size()
	var id: String = c0.name.substr(5)
	check(not c0.held, "no card is lit before a click")
	shop._on_card_chosen(id, c0)
	check(c0.held, "choosing a card lights it at once (CHOSEN)")
	check(WorldState.active_upgrades.size() == before_upgrades, "…the choice itself waits for the beat (the flourish is not the logic)")
	shop._on_card_chosen(id, c0)
	await get_tree().create_timer(shop.STAMP_BEAT + 0.25).timeout
	check(WorldState.active_upgrades.has(id) and WorldState.active_upgrades.size() == before_upgrades + 1, "after the beat the SAME `_on_take_upgrade` ran, once (a second click mid-beat did nothing)")
	check(shop.active_tab == "shop", "and the page moved on to the wares")
	await _frames(3)
	check(shop.money_label.get_theme_font("font") == Lamp.font("head"), "the notes are in the kit's head face, not a hand")
	var tw: String = _type_audit(shop.sheet)
	check(tw == "", "the wares: only the kit's three faces and four sizes (%s)" % tw)
	var ow: String = _outside(shop.sheet)
	check(ow == "", "the wares and the sell column lie inside the panel (%s)" % ow)
	check(shop.rows_box.get_global_rect().end.x <= shop.sell_box.get_global_rect().position.x + 1.0, "wares on the left, what you can sell on the right, side by side")
	# the rows keep one line of the description each; the whole of it stands under the list for the ware the pointer is on
	shop.rows_box.get_child(0).mouse_entered.emit()
	var full0: String = String(ItemData.get_item(shop.stock[0]["item_id"]).get("description", ""))
	check(shop.detail_label.text == full0 and full0 != "", "pointing at a ware shows its whole description under the list")
	# a purchase: the first press asks, the second pays
	WorldState.wallet_unlocked = true
	WorldState.wallet_balance = 5000
	WorldState.inventory.clear()
	shop._on_buy_pressed(0)
	check(shop.buy_buttons[0].text == "SURE?", "the first press on BUY asks (SURE?)")
	shop._on_buy_pressed(0)
	await _frames(3)
	check(shop.stock[0]["sold"] and shop.buy_buttons[0].text == "SOLD" and shop.buy_buttons[0].disabled, "the second pays, and the row reads SOLD")
	WorldState.wallet_balance = 0
	WorldState.inventory.clear()
	shop._on_buy_pressed(1)
	shop._on_buy_pressed(1)
	check(not shop.stock[1]["sold"] and shop.buy_buttons[1].text == "BUY", "without the notes the second press refuses and the button is BUY again")
	shop.close()
	check(not shop.visible, "the page puts away")
	shop.queue_free()
	await _frames(2)


func _test_feedback_pill() -> void:
	print("[the message at the top of the screen: a Lamplight pill, readable, red for a refusal]")
	HUD.show_feedback("Equipped Hammer.")
	await _frames(3)
	check(HUD.feedback_pill.visible and HUD.feedback_label.text == "Equipped Hammer.", "the line shows in the pill")
	check(HUD.feedback_label.get_theme_font("font") == Lamp.font("body") and HUD.feedback_label.get_theme_font_size("font_size") == Lamp.PX_BODY, "…in the kit's body face at the body size (it was 14 px)")
	check(HUD.feedback_label.get_theme_color("font_color") == Lamp.TEXT, "…in the kit's cream, not yellow")
	check(absf(HUD.feedback_pill.position.x + HUD.feedback_pill.size.x * 0.5 - 576.0) < 3.0, "…centred at the top")
	check(HUD.feedback_pill.mouse_filter == Control.MOUSE_FILTER_IGNORE and HUD.feedback_label.mouse_filter == Control.MOUSE_FILTER_IGNORE, "…and never eats a click meant for the world")
	HUD.show_feedback("Inventory full.", true)
	check(HUD.feedback_label.get_theme_color("font_color") == Lamp.RED, "a refusal is red")
	HUD.show_feedback("Inventory full.")
	check(HUD.feedback_label.get_theme_color("font_color") == Lamp.TEXT, "…and the next plain line is cream again")
	var long_line := "You lever the door off its hinge. Glass everywhere — and loud, and every one of the dead on this floor heard it."
	HUD.show_feedback(long_line)
	await _frames(3)
	check(HUD.feedback_pill.size.x <= HUD.FEEDBACK_MAX_W + 60.0 and HUD.feedback_pill.size.y > 40.0 and HUD.feedback_pill.size.y < 110.0, "a long line wraps to two lines inside a bounded pill (%s)" % str(HUD.feedback_pill.size))
	HUD.feedback_timer = 0.02
	await _frames(4)
	check(not HUD.feedback_pill.visible, "when its time is up the pill is gone")
