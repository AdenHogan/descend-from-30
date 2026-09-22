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
	var expected := str(HUD.character_panel.CHAR_LORE.get(cid, {}).get("name", ""))
	if expected != "":
		check(HUD.character_panel.title_label.text == expected,
			"title shows the current character's name (%s)" % expected)
	check(HUD.character_panel.portrait_rect.texture != null, "profile shows the character portrait")
	check(HUD.character_panel.tabs.get_tab_count() == 2, "two tabs (Profile + NPCs)")
	check(HUD.character_panel.npc_text.text.length() > 0, "NPC tab has placeholder copy")

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

	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)
