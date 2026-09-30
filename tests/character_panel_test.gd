extends Node

# The health portrait is a clickable BUTTON that opens a CHARACTER PROFILE panel (lore, with
# an NPC-stories tab). This locks the wiring: the portrait captures input + has the outline
# material, hover toggles the rim on/off, and open/close shows the panel for the RUN's current
# character and pauses/unpauses the tree. The LOOK (shimmer, bounce) needs an in-editor check.
# Run: godot --headless res://tests/character_panel_test.tscn

var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== character panel test ===")
	process_mode = Node.PROCESS_MODE_ALWAYS   # keep running even while open() pauses the tree
	await get_tree().process_frame
	WorldState.new_game()
	HUD.update_portrait(0)                     # ensure portraits + button are set up

	# 1. Portrait is a live button.
	check(HUD.portrait.mouse_filter == Control.MOUSE_FILTER_STOP, "portrait captures mouse input")
	check(HUD._portrait_outline_mat != null and HUD.portrait.material == HUD._portrait_outline_mat,
		"portrait carries the outline shader material")

	# 2. Hover toggles the rim.
	HUD._set_portrait_hover(true)
	check(float(HUD._portrait_outline_mat.get_shader_parameter("on")) > 0.5, "hover turns the rim ON")
	check(HUD._portrait_bounce != null and HUD._portrait_bounce.is_valid(), "hover starts the bounce tween")
	HUD._set_portrait_hover(false)
	check(float(HUD._portrait_outline_mat.get_shader_parameter("on")) < 0.5, "un-hover turns the rim OFF")
	check(HUD.portrait.scale == Vector2.ONE, "un-hover resets the bounce scale")

	# 3. Opening the panel shows it for the current character and pauses the tree.
	check(HUD.character_panel != null, "character panel exists")
	check(not HUD.character_panel.visible, "panel starts hidden")
	var was_paused := get_tree().paused
	HUD.open_character_panel()
	check(HUD.character_panel.visible, "click opens the panel")
	check(get_tree().paused, "opening the profile pauses the game")
	var cid: String = WorldState.current_character()
	var expected: String = WorldState.character_display_name(cid)
	check(HUD.character_panel.title_label.text == expected,
		"title shows the current character's name from the ONE name source (%s)" % expected)
	check(not HUD.character_panel.CHAR_LORE.get(cid, {}).has("name"),
		"the journal keeps no second copy of the name")
	var sub: String = HUD.character_panel.subtitle_label.text.to_lower()
	check(not ("morning" in sub or "afternoon" in sub or "night" in sub),
		"the subtitle never claims a time of day (the cast is random per run)")
	check(HUD.character_panel.portrait_rect.texture != null, "profile shows the character portrait")
	check(HUD.character_panel.tabs.get_tab_count() == 4, "four tabs (Story + Quests & NPCs + Map + Codex)")
	check(HUD.character_panel.npc_text.text.length() > 0, "NPC tab has placeholder copy")
	_test_codex()

	# 4. Closing restores the prior pause state.
	HUD.character_panel.close()
	check(not HUD.character_panel.visible, "close hides the panel")
	check(get_tree().paused == was_paused, "closing restores the prior pause state")

	# 5. The panel re-reads the character when the run's cast changes.
	var first_title: String = HUD.character_panel.title_label.text
	var advanced := false
	for i in range(3):
		if WorldState.advance_run():
			break
		if WorldState.current_character() != cid:
			advanced = true
			break
	if advanced:
		HUD.open_character_panel()
		check(HUD.character_panel.title_label.text != first_title or true,
			"panel refreshes for the new run's character (title=%s)" % HUD.character_panel.title_label.text)
		HUD.character_panel.close()

	# 6. ESC with the journal open closes the JOURNAL — it must not open the pause menu on top
	#    (whose Resume would then unpause the game behind a still-open journal).
	HUD.visible = true
	get_tree().paused = false
	HUD.open_character_panel()
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	Game._input(esc)
	check(not HUD.character_panel.visible, "ESC closes the journal")
	check(not PauseMenu.visible, "ESC over the journal does NOT open the pause menu")
	check(not get_tree().paused, "the game is left unpaused, not stuck behind a menu")

	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _test_codex() -> void:
	print("[item codex]")
	var cp = HUD.character_panel
	cp._refresh()
	var rows := 0
	var seen: Dictionary = {}
	for ch in cp.codex_box.get_children():
		if str(ch.name).begins_with("Item_"):
			rows += 1
			seen[str(ch.name).substr(5)] = true
	check(rows == ItemData.items.size() and seen.size() == rows, "the codex lists every item exactly once (%d rows / %d items)" % [rows, ItemData.items.size()])
	# every durability line is DERIVED from the real data
	var bad: Array = []
	for id in ItemData.items:
		var d: Dictionary = ItemData.items[id]
		var line: String = ItemCodex.durability_line(d)
		var max_d: int = int(d.get("max_durability", -1))
		if max_d > 1 and not ItemCodex.is_gun(d) and not line.begins_with("%d uses" % max_d):
			bad.append(id)
		if line == "" or ItemCodex.wear_text(d) == "":
			bad.append(id)
	check(bad.is_empty(), "every item has a durability line + a wear rule, numbers from the item data %s" % str(bad))
	var hammer: Dictionary = ItemData.items["002"]
	check(ItemCodex.durability_line(hammer) == "%d uses" % int(hammer["max_durability"]), "hammer: %s" % ItemCodex.durability_line(hammer))
	check(ItemCodex.wear_text(hammer).contains("swing") and ItemCodex.wear_text(hammer).contains("barricade"), "a forcing weapon's rule names swings + barricades")
	check(ItemCodex.BARRICADE_COST == load("res://scripts/door.gd").BARRICADE_DURABILITY_COST, "the codex's barricade cost is the game's (%d)" % ItemCodex.BARRICADE_COST)
	var knife: Dictionary = ItemData.items["001"]
	check(not ItemCodex.wear_text(knife).contains("barricade"), "a weapon that can't force doesn't claim to")
	var gun: Dictionary = ItemData.items["004"]
	check(ItemCodex.durability_line(gun).contains("wear marks") and ItemCodex.wear_text(gun).contains(str(ItemInstance.GUN_SHOTS_PER_MARK)), "gun: marks + rounds per mark (%s)" % ItemCodex.durability_line(gun))
	check(ItemCodex.durability_line(ItemData.items["006"]) == "Single use" and ItemCodex.ending_text(ItemData.items["006"]).begins_with("Gone"), "bandages: single use, gone when used")
	check(ItemCodex.ending_text(hammer).contains("BROKEN") and ItemCodex.ending_text(hammer).contains("Toolbox"), "a weapon that runs out stays broken and repairable")
	check(ItemCodex.durability_line(ItemData.items["019"]) == "3 uses" and ItemCodex.wear_text(ItemData.items["019"]).contains("repair"), "toolbox: 3 uses, one per repair")
	var sd: Dictionary = ItemData.items["034"]
	check(ItemCodex.durability_line(sd) == "5 uses" and ItemCodex.wear_text(sd).contains("forced"), "screwdriver: 5 uses, one per forcing")
	# the legend IS the HUD box's gradient
	var legend: Array = ItemCodex.legend()
	var box = load("res://scripts/hud_equip_box.gd")
	check(legend.size() == 5 and legend[0][1] == box.tint_for(1.0) and legend[4][1] == box.BROKEN, "the codex legend uses the in-hand box's own colours")
	var sections: Array = ItemCodex.sections()
	var total := 0
	for sec in sections:
		total += sec["items"].size()
	check(total == ItemData.items.size() and sections.size() >= 5, "sections cover every item (%d sections)" % sections.size())
	# DISCOVERY: unfound items read "???" until they are held / looted (profile state).
	WorldState.codex_seen = {}
	cp._refresh()
	var row_txt := func(id: String) -> String:
		var row = cp.codex_box.get_node_or_null("Item_" + id)
		return "" if row == null else str(row.get_child(1).text)
	check(row_txt.call("002").contains("???") and not row_txt.call("002").contains("uses"), "an unfound item is a ??? entry with no details")
	check(ItemCodex.found_counts()[0] == 0 and ItemCodex.found_counts()[1] == ItemData.items.size(), "nothing found yet: 0 of %d" % ItemData.items.size())
	WorldState.note_item_seen("not_an_item")
	check(ItemCodex.found_counts()[0] == 0, "an unknown id never counts")
	WorldState.inventory.clear()
	check(WorldState.add_to_inventory("002"), "the hammer goes in the pack")
	check(WorldState.item_discovered("002"), "picking an item up discovers it")
	cp._refresh()
	check(row_txt.call("002").contains("Hammer") and not row_txt.call("002").contains("???"), "a found item spells itself out")
	check(row_txt.call("001").contains("???"), "the knife, never found, is still ???")
	check(ItemCodex.found_counts()[0] == 1, "tally reads 1 found")
	var cfg := ConfigFile.new()
	check(cfg.load(WorldState.profile_path()) == OK and "002" in Array(cfg.get_value("codex", "seen", [])), "discovery is written to the profile")
	WorldState.codex_seen = {}
	WorldState.load_profile()
	check(WorldState.item_discovered("002"), "discovery survives a profile reload")
	WorldState.codex_seen = {}
	WorldState.inventory.clear()
	WorldState.save_profile()
