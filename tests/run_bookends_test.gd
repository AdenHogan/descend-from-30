extends Node

# How every run BEGINS and ENDS (owner: "a synergy for all three runs in how they begin/end"),
# plus the Floor-30 tutorial clean-up:
#  - every run opens on the same cold open (title card / new character's name → banging → a
#    line → the lockout at 3001), once per run, never replayed by Continue;
#  - a character's story ends on an END CARD ("YOU DIED — <name> fell on Floor N." /
#    "YOU ESCAPED"), then the time card, then the next character's cold open;
#  - wall text shows the player's CURRENT keys, sits in clear wall between doors, and the
#    corridor scenes spawn the player ON the floor line.
# Run: godot --headless res://tests/run_bookends_test.tscn

var failures: int = 0
const HallwayScript := preload("res://scripts/hallway.gd")


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== run bookends / tutorial clean-up test ===")
	_test_opener_config()
	_test_opener_flag_lifecycle()
	_test_place_words()
	_test_blood_text_keys()
	_test_hints_clear_of_doors()
	_test_floor_30_shape()
	_test_spawn_plane()
	_test_prompt_hints_name_keys()
	await _test_end_card()
	await _test_death_to_next_cold_open()
	Engine.time_scale = 1.0
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _test_opener_config() -> void:
	print("[every run opens the same way, in its own words]")
	WorldState.new_game()
	WorldState.is_first_run = true
	var c1: Dictionary = HallwayScript.opener_config()
	var L: Dictionary = TutorialManager.LINES
	check(c1["title_text"] == "DESCEND FROM 30" and c1["line_text"] == L["opener_1"], "run 1: the game's title (its own screen) + the banging line")
	check(c1["time_word"] == "MORNING" and c1["time_color"] == Transition.TIME_WORD_COLORS[0], "run 1's time card: MORNING in its own colour")
	check(c1["lockout"] == [L["opener_4"], L["opener_5"]], "run 1 (tutorial): the spare-key lockout")
	check(c1["name_text"] == WorldState.character_display_name(WorldState.current_character()),
		"run 1's card names who you are (%s)" % c1["name_text"])
	WorldState.is_first_run = false
	check(HallwayScript.opener_config()["lockout"][1] == L["opener_5_free"], "run 1 without the tutorial: no spare-key errand")
	WorldState.set_run_outcome(1, "dead")
	WorldState.advance_run()
	var c2: Dictionary = HallwayScript.opener_config()
	var who2: String = WorldState.character_display_name(WorldState.current_character())
	check(c2["title_text"] == "" and c2["name_text"] == who2, "run 2: no game title — the NEW character on the time card (%s)" % c2["name_text"])
	check(c2["line_text"] == L["run2_open"] and c2["time_word"] == "AFTERNOON", "run 2: its own line, AFTERNOON")
	check(c2["lockout"] == [L["run_lockout"], L["run_after_fell"]], "run 2's lockout nods to the character who FELL")
	WorldState.set_run_outcome(2, "survived")
	WorldState.advance_run()
	var c3: Dictionary = HallwayScript.opener_config()
	check(c3["line_text"] == L["run3_open"] and c3["time_word"] == "NIGHT", "run 3: its own line, NIGHT")
	check(c3["lockout"] == [L["run_lockout"], L["run_after_escaped"]], "run 3's lockout nods to the one who ESCAPED")


func _test_opener_flag_lifecycle() -> void:
	print("[the cold open plays once per run — and Continue never replays it]")
	WorldState.new_game()
	check(not WorldState.opener_seen, "a new game has an opener to play")
	WorldState.opener_seen = true
	WorldState.advance_run()
	check(not WorldState.opener_seen, "the next run gets its own opener")
	WorldState.opener_seen = true
	WorldState.save_game("res://scenes/hallway.tscn", false)
	WorldState.opener_seen = false
	WorldState.load_game()
	check(WorldState.opener_seen, "a save made after the opener doesn't replay it on Continue")
	WorldState.delete_save()


func _test_place_words() -> void:
	print("[the end card says where it happened]")
	WorldState.new_game()
	WorldState.current_floor = 17
	check(WorldState.place_in_words("res://scenes/building_floors.tscn") == "on Floor 17", "corridor")
	WorldState.current_apartment_id = "1703"
	check(WorldState.place_in_words("res://scenes/room.tscn") == "in apartment 1703 on Floor 17", "apartment")
	WorldState.current_apartment_id = ""
	WorldState.current_floor = 0
	check(WorldState.place_in_words("res://scenes/lobby.tscn") == "in the Lobby", "lobby")


func _test_blood_text_keys() -> void:
	print("[wall text shows the player's CURRENT keys]")
	var bt = load("res://scenes/blood_text.tscn").instantiate()
	bt.text = "RUN [{sprint}]\n{move} or CLICK"
	add_child(bt)
	var shown: String = bt.resolved_text()
	check(not shown.contains("{"), "every {action} placeholder resolves (%s)" % shown.replace("\n", " / "))
	check(shown.contains("[%s]" % BloodText.key_for("sprint")), "sprint shows its bound key")
	check(shown.contains("A D"), "movement shows the short keys (A D), not the arrow names")
	var saved: Array = InputMap.action_get_events("sprint").duplicate()
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_V
	InputMap.action_erase_events("sprint")
	InputMap.action_add_event("sprint", ev)
	check(bt.resolved_text().contains("[V]"), "rebinding sprint to V rewrites the wall")
	InputMap.action_erase_events("sprint")
	for e in saved:
		InputMap.action_add_event("sprint", e)
	bt.free()


func _test_hints_clear_of_doors() -> void:
	print("[every Floor-30 hint sits in clear wall — never across a door, never at the ceiling]")
	var h = load("res://scenes/hallway.tscn").instantiate()
	var doors: Array = []
	for n in ["3001", "3002", "3003", "3004", "3005", "Elevator"]:
		var d = h.get_node(n)
		var spr: Sprite2D = d if d is Sprite2D else d.get_node("Sprite2D")
		var sx: float = absf(spr.scale.x) * (1.0 if spr == d else absf(d.scale.x))
		var half: float = spr.texture.get_width() * sx * 0.5
		doors.append(Vector2(d.position.x - half, d.position.x + half))
	var hints := 0
	for n in h.get_children():
		if not n.is_in_group("tutorial_blood"):
			continue
		hints += 1
		var sz: Vector2 = n.block_size()
		var x0: float = n.position.x - sz.x * 0.5
		var x1: float = n.position.x + sz.x * 0.5
		var hit := ""
		for i in doors.size():
			if x1 > doors[i].x and x0 < doors[i].y:
				hit = str(i)
		check(hit == "" and x0 >= 227.0 and x1 <= 1123.0,
			"%s (%d..%d) clears every door and the stairwell" % [n.name, x0, x1])
		check(n.position.y >= 290.0 and n.position.y + sz.y <= 404.0,
			"%s sits at door height (%d..%d), not jammed at the ceiling" % [n.name, n.position.y, n.position.y + sz.y])
	check(hints >= 5, "the control hints are all there (%d)" % hints)
	h.free()


func _test_floor_30_shape() -> void:
	print("[floor 30 has ONE stairwell opening (down, left) — no hole on the right]")
	var h = load("res://scenes/hallway.tscn").instantiate()
	var tm: TileMapLayer = h.get_node("TileMapLayer")
	var right_holes := 0
	for x in range(67, 74):
		for y in range(20, 32):
			if tm.get_cell_source_id(Vector2i(x, y)) == -1:
				right_holes += 1
	check(right_holes == 0, "the right end is solid wall (%d empty cells)" % right_holes)
	h.free()


func _test_spawn_plane() -> void:
	print("[a fresh run stands the player ON the floor line (origin 386, feet 419)]")
	for path in ["res://scenes/hallway.tscn", "res://scenes/lobby.tscn", "res://scenes/building_floors.tscn"]:
		var s = load(path).instantiate()
		check(is_equal_approx(s.get_node("Player").position.y, 386.0),
			"%s places its player at 386 (%.0f)" % [path.get_file(), s.get_node("Player").position.y])
		s.free()


func _test_prompt_hints_name_keys() -> void:
	print("[teaching prompts name the player's real key]")
	check(TutorialManager._default_hint("push") == "[%s]" % TutorialManager.key("push"), "push prompt shows its key")
	check(TutorialManager.key("push") == "Right-click", "right mouse reads as Right-click (%s)" % TutorialManager.key("push"))
	check(TutorialManager._default_hint("interact") == "[continue]", "any-key prompts say [continue]")


func _test_end_card() -> void:
	print("[the end card leaves the screen black and busy for the run-advance]")
	Engine.time_scale = 8.0
	var ok: bool = await Transition.end_card("YOU DIED", "Somebody fell on Floor 9.", Transition.END_DIED_COLOR, 0.5)
	check(ok and Transition.busy and is_equal_approx(Transition.rect.color.a, 1.0), "black + busy after the card")
	check(not Transition.run_box.visible, "the card's text has cleared")
	await Transition.reveal(0.05)
	check(not Transition.busy, "reveal hands control back")


func _test_death_to_next_cold_open() -> void:
	print("[a death runs: end card → time card → the NEXT character's cold open at 3001]")
	WorldState.new_game()
	WorldState.opener_seen = true
	Engine.time_scale = 8.0
	var stub := Node.new()
	get_tree().root.add_child.call_deferred(stub)
	await get_tree().process_frame
	get_tree().current_scene = stub
	get_tree().change_scene_to_file("res://scenes/hallway.tscn")
	for i in 4:
		await get_tree().process_frame
	var first: String = WorldState.current_character()
	Game.game_over()
	var guard := 0
	while (Transition.busy or WorldState.current_run == 1) and guard < 4000:
		await get_tree().process_frame
		guard += 1
	for i in 4:
		await get_tree().process_frame
	check(WorldState.current_run == 2, "the run advanced")
	check(get_tree().current_scene != null and get_tree().current_scene.scene_file_path.ends_with("hallway.tscn"),
		"the next character wakes on Floor 30")
	var intro = null
	for n in get_tree().current_scene.get_children():
		if n.get_script() == load("res://scripts/intro_overlay.gd"):
			intro = n
	check(intro != null, "…and the run opens on its cold open")
	if intro != null:
		var want: String = WorldState.character_display_name(WorldState.current_character())
		check(intro.name_text == want and intro.time_word == "AFTERNOON" and WorldState.current_character() != first,
			"its time card names the NEW character (%s, %s)" % [intro.name_text, intro.time_word])
		check(intro.stage == "card", "…and opens straight on the time card (the title is run 1's)")
		intro.queue_free()
	get_tree().paused = false
	WorldState.delete_save()
