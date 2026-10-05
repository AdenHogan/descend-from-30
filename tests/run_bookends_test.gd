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
	await _test_opener_never_strands_pause()
	_test_escape_guard_and_summary()
	await _test_lobby_door_needs_e()
	await _test_lobby_exit_art()
	await _test_hallway_decals()
	await _test_escape_white_card_to_next_run()
	await _test_escape_art_slot()
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
	SettingsManager.rebind_slot("sprint", 0, "k:V")          # (through the settings — the InputMap is built from them)
	check(bt.resolved_text().contains("[V]"), "rebinding sprint to V rewrites the wall")
	SettingsManager.reset_defaults()
	bt.free()


func _test_hints_clear_of_doors() -> void:
	print("[every Floor-30 hint sits in clear wall — never across a door face or plate, and they're staggered, not one line]")
	var h = load("res://scenes/hallway.tscn").instantiate()
	# door FACES (the wall above a door's top edge, y < 321, is open: the scrawl may run over the doors)
	var faces: Array = []
	var plates: Array = []
	for n in ["3001", "3002", "3003", "3004", "3005", "Elevator"]:
		var d = h.get_node(n)
		var spr: Sprite2D = d if d is Sprite2D else d.get_node("Sprite2D")
		var sx: float = absf(spr.scale.x) * (1.0 if spr == d else absf(d.scale.x))
		var half: float = spr.get_rect().size.x * sx * 0.5      # one FRAME (the doors are a strip)
		faces.append(Rect2(d.position.x - half, 321.0, half * 2.0, 84.0))
		if n != "Elevator":
			plates.append(Rect2(d.position.x - 50.0, 333.0, 26.0, 18.0))   # its number plate (floor_signs.taken_local)
	var hints := 0
	var ys := {}
	var rots := {}
	for n in h.get_children():
		if not n.is_in_group("tutorial_blood"):
			continue
		hints += 1
		var sz: Vector2 = n.block_size()
		var block := Rect2(n.position.x - sz.x * 0.5, n.position.y, sz.x, sz.y)
		var hit := ""
		for i in faces.size():
			if block.intersects(faces[i]):
				hit = "a door face"
		for pl in plates:
			if block.intersects(pl):
				hit = "a number plate"
		check(hit == "" and block.position.x >= 215.0 and block.end.x <= 1123.0,
			"%s (%d..%d, y %d..%d) clears every door face, plate and the stairwell%s" % [n.name, block.position.x, block.end.x, block.position.y, block.end.y, (" — hits " + hit) if hit != "" else ""])
		check(n.position.y >= 256.0 and n.position.y + sz.y <= 404.0,
			"%s sits on the wall (%d..%d), under the ceiling line" % [n.name, n.position.y, n.position.y + sz.y])
		ys[int(n.position.y / 12.0)] = true
		rots[snappedf(n.rotation, 0.01)] = true
	check(hints >= 5, "the control hints are all there (%d)" % hints)
	check(ys.size() >= 4, "the hints sit at varied heights, not one line (%d height bands)" % ys.size())
	check(rots.size() >= 4, "...and at varied tilts (%d)" % rots.size())
	# ...and under the wall sconces, never over one (owner round 24: the sconces light the floor)
	var FL = load("res://scripts/floor_lighting.gd")
	for n in h.get_children():
		if not n.is_in_group("tutorial_blood"):
			continue
		var sz2: Vector2 = n.block_size()
		var block := Rect2(n.position.x - sz2.x * 0.5, n.position.y, sz2.x, sz2.y)
		for x in FL.SCONCE_X:
			var lamp := Rect2(float(x) - 10.0, FL.SCONCE_Y - 12.0, 20.0, 24.0)
			check(not block.intersects(lamp), "%s clears the sconce at x %d" % [n.name, x])
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
		check(intro.stage == "exterior" and intro.ext != null and not intro.ext.with_title and intro.ext.run == 2,
		"…and opens on the exterior shot in the afternoon's light, with no title (that is run 1's) before the time card")
		intro.queue_free()
	get_tree().paused = false
	WorldState.delete_save()


func _test_opener_never_strands_pause() -> void:
	print("[a cold open freed mid-way (scene change) never leaves the game paused]")
	await get_tree().process_frame                # let the previous test's opener finish freeing
	await get_tree().process_frame
	get_tree().paused = false
	var intro = preload("res://scripts/intro_overlay.gd").new()
	add_child(intro)
	await get_tree().process_frame
	check(get_tree().paused, "the cold open pauses play")
	intro.queue_free()
	await get_tree().process_frame
	check(not get_tree().paused, "freed before it finished → play is unpaused, not stranded")


func _test_escape_guard_and_summary() -> void:
	print("[committing to leave: no hit or dying countdown can undo it; the card's run summary]")
	WorldState.new_game()
	var p = load("res://scenes/player.tscn").instantiate()
	add_child(p)
	p.escaping = true
	var hp_before: int = p.health_state
	p.receive_hit(3)
	p.take_damage(3)
	p._die()
	check(p.health_state == hp_before and not p.is_dead, "an escaping player can't be hurt or killed")
	p.queue_free()
	WorldState.run_kills = 7
	WorldState.run_scavenged = 12
	WorldState.run_apartments_looted = ["2901", "2903"]
	WorldState.note_quest_completed()
	var rows := {}
	for r in WorldState.run_summary("Hammer Lv3"):
		rows[r[0]] = r[1]
	check(rows.get("Felled") == "7" and rows.get("Searched") == "12" and rows.get("Apartments looted") == "2", "kills / searches / apartments (%s)" % str(rows))
	check(rows.get("Quests completed") == "1" and rows.get("Descent Valour") == "+%d" % Progression.valour_for_run(0, true, 1, 0), "quests + this run's Valour")
	check(not rows.has("Residents aided"), "a fact that didn't happen isn't listed")
	check(String(rows.get("Left by the door", "")).begins_with("Hammer Lv3") and not rows.has("Braved the unknown"),
		"the stashed item (for the next game), no brave row")
	var knife := ItemInstance.new()
	knife.setup("001")
	knife.level = 2
	WorldState.inventory = [knife]
	var door: int = WorldState.note_door_scrap(true)
	var plain := {}
	for r in WorldState.run_summary():
		plain[r[0]] = r[1]
	check(not plain.has("Left by the door"), "nothing left → no stash row")
	check(plain.has("Braved the unknown") and String(plain.get("Scrapped at the door", "")).contains("Knife"),
		"left nothing → the brave row + what was scrapped (%s)" % str(plain))
	check(door == Progression.DOOR_BRAVE_BONUS + Progression.DOOR_WORTH[2]
		and plain.get("Descent Valour") == "+%d" % Progression.valour_for_run(0, true, 1, 0, door), "…and its Valour (+%d at the door)" % door)


func _lobby_with_player() -> Array:
	var stub := Node.new()
	get_tree().root.add_child.call_deferred(stub)
	await get_tree().process_frame
	get_tree().current_scene = stub
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")
	for i in 6:
		await get_tree().process_frame
	var lobby = get_tree().current_scene
	var exit = null
	for n in lobby.find_children("*", "Area2D", true, false):
		if n.get_script() == load("res://scripts/lobby_exit.gd"):
			exit = n
	return [lobby, exit, get_tree().get_first_node_in_group("player")]


func _test_lobby_door_needs_e() -> void:
	print("[standing at the lobby door no longer ends the run — leaving is [E]]")
	WorldState.new_game()
	WorldState.current_floor = 0
	WorldState.inventory = []
	var r: Array = await _lobby_with_player()
	var exit = r[1]
	var p = r[2]
	check(exit != null and p != null, "lobby has its exit + the player")
	for z in get_tree().get_nodes_in_group("zombie"):
		z.queue_free()
	p.global_position = exit.global_position + Vector2(0, 23)
	for i in 30:
		await get_tree().physics_frame
		for z in get_tree().get_nodes_in_group("zombie"):      # a late-waking lobby zombie once shoved the
			z.queue_free()                                    # player off the door's trigger (rare, seed-dependent)
	var over: Array = []
	for b in exit.get_overlapping_bodies():
		over.append(str(b.name))
	check(exit._player_near and not exit._leaving, "at the door: prompt, but still in the building (seed %d, player %s, door %s, zombies %d, near %s, leaving %s, paused %s, overlapping %s, monitoring %s)" % [
		WorldState.master_seed, str(p.global_position), str(exit.global_position), get_tree().get_nodes_in_group("zombie").size(),
		exit._player_near, exit._leaving, get_tree().paused, str(over), exit.monitoring])
	check(WorldState.chronicle_entry(1)["outcome"] == "" and WorldState.current_run == 1,
		"…the run hasn't ended (%s)" % WorldState.chronicle_entry(1)["outcome"])


func _test_escape_white_card_to_next_run() -> void:
	print("[E at the door: step up → WHITE 'YOU SURVIVED' + stats → black → the next run]")
	WorldState.new_game()
	WorldState.current_floor = 0
	WorldState.inventory = []
	var r: Array = await _lobby_with_player()
	var exit = r[1]
	var p = r[2]
	for z in get_tree().get_nodes_in_group("zombie"):
		z.queue_free()
	Engine.time_scale = 8.0
	Transition.survive_min_hold = 0.1
	Transition.survive_max_wait = 0.2               # no key in a headless test: auto-continue
	exit.leave()
	var saw_white := false
	var saw_card := false
	var guard := 0
	while WorldState.current_run == 1 and guard < 6000:
		await get_tree().process_frame
		guard += 1
		if Transition.rect.visible and Transition.rect.color.r > 0.9 and Transition.rect.color.a > 0.9:
			saw_white = true
		if Transition.survive_box.visible and Transition.survive_title.text == "YOU SURVIVED":
			saw_card = true
	check(p.escaping, "the player committed to leaving")
	check(WorldState.chronicle_entry(1)["outcome"] == "escaped", "the run ended as a survival")
	check(saw_white and saw_card, "the screen bloomed WHITE with the YOU SURVIVED card")
	var cells: Array = []
	for c in Transition.survive_stats.get_children():
		cells.append(c.text)
	check("Descended" in cells and "all 30 floors" in cells, "…carrying the run's stats (%s)" % str(cells))
	check(not ("Braved the unknown" in cells) and not bool(WorldState.chronicle_entry(1).get("braved", false))
		and int(WorldState.chronicle_entry(1).get("door_valour", -1)) == 0,
		"empty-handed (no upgraded weapon): no door choice, no brave bonus, nothing scrapped")
	guard = 0
	while Transition.busy and guard < 4000:
		await get_tree().process_frame
		guard += 1
	for i in 4:
		await get_tree().process_frame
	check(WorldState.current_run == 2, "the next run began")
	check(Transition.rect.color.r < 0.05 and Transition.rect.color.g < 0.05, "the cover is back to BLACK for every later fade")
	check(get_tree().current_scene.scene_file_path.ends_with("hallway.tscn"), "…on Floor 30")
	Transition.survive_min_hold = 2.2
	Transition.survive_max_wait = 20.0
	Engine.time_scale = 1.0
	get_tree().paused = false
	WorldState.delete_save()


func _test_escape_art_slot() -> void:
	print("[the outside: optional art the white card dissolves into before black]")
	WorldState.new_game()
	check(WorldState.escape_art() == null, "no art painted yet → none shown (straight to black)")
	var img := Image.create(64, 36, false, Image.FORMAT_RGB8)
	img.fill(Color(0.3, 0.5, 0.7))
	var tex := ImageTexture.create_from_image(img)
	Engine.time_scale = 8.0
	Transition.survive_min_hold = 0.1
	Transition.survive_max_wait = 0.2
	Transition.survive_art_hold = 0.2
	var saw_art := false
	var state := {"done": false, "ok": false}
	var run_card := func():
		state["ok"] = await Transition.survived_card("YOU SURVIVED", "Someone walked out.", [["Felled", "3"]], tex)
		state["done"] = true
	run_card.call()
	var guard := 0
	while not state["done"] and guard < 6000:           # the card leaves the screen BLACK + busy
		if Transition.survive_art.visible and Transition.survive_art.texture == tex and Transition.survive_art.modulate.a > 0.9:
			saw_art = true
		await get_tree().process_frame
		guard += 1
	check(state["ok"], "the card ran to its end")
	check(saw_art, "the outside faded in, full, after the stats")
	check(not Transition.survive_art.visible and Transition.survive_art.texture == null, "…and is cleared away afterwards")
	check(Transition.rect.color.r < 0.05 and is_equal_approx(Transition.rect.color.a, 1.0), "it still ends on BLACK for the next run")
	await Transition.reveal(0.05)
	Transition.survive_min_hold = 2.2
	Transition.survive_max_wait = 20.0
	Transition.survive_art_hold = 3.5
	Engine.time_scale = 1.0


func _test_lobby_exit_art() -> void:
	print("[the lobby exit is a real entrance: frame + unshaded street + light, and the walk UP into it]")
	for run in [1, 2, 3]:
		WorldState.new_game()
		WorldState.current_floor = 0
		WorldState.current_run = run
		var lobby = load("res://scenes/lobby.tscn").instantiate()
		add_child(lobby)
		for i in 3:
			await get_tree().process_frame
		var fx = lobby.get_node_or_null("LobbyExitFx")
		check(fx != null and fx.frame_sprite != null and fx.view_sprite != null, "run %d: the entrance is built (frame + street view)" % run)
		if fx != null and fx.view_sprite != null:
			check(fx.view_sprite.material is CanvasItemMaterial and fx.view_sprite.material.light_mode == CanvasItemMaterial.LIGHT_MODE_UNSHADED,
				"run %d: the street is unshaded (bright in the night-dark world)" % run)
			var meta: Dictionary = fx.meta()
			var fr: Array = meta["frame"]
			check(fx.frame_sprite.texture.get_width() == int(fr[0]) and fx.frame_sprite.texture.get_height() == int(fr[1]), "run %d: frame art matches its meta" % run)
			check(fx.spill != null and fx.beam != null and fx.glare != null, "run %d: light spill, beam and glare" % run)
			# the door's centre column sits on the trigger's x; the frame's seam lands on the wall foot (world 403)
			var seam: float = fx.frame_sprite.position.y + float(meta["seam"])
			check(absf(seam - 403.0) < 0.5 and absf(fx.ORIGIN.x + 64.0 - fx.CENTER_X) < 0.5, "run %d: seam on the wall foot (%.0f), centred on x %.0f" % [run, seam, fx.CENTER_X])
		check(lobby.get_node_or_null("LobbyExit") == null, "the old flat door slab is gone")
		lobby.free()
		await get_tree().process_frame
	# the walk: lane -> centre -> UP the steps, shrinking (player.walk_up_and_out)
	WorldState.new_game()
	WorldState.current_floor = 0
	var r: Array = await _lobby_with_player()
	var p = r[2]
	for z in get_tree().get_nodes_in_group("zombie"):
		z.queue_free()
	p.global_position = Vector2(600.0, 386.0)
	var y0: float = p.global_position.y
	var done := [false]
	p.walk_up_and_out(654.0, 27.0, 0.76, func(): done[0] = true)
	var waited := 0.0
	while not done[0] and waited < 6.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	check(done[0], "the walk up into the doorway finishes (%.1fs)" % waited)
	check(absf(p.global_position.x - 654.0) < 1.0 and absf(p.global_position.y - (y0 - 27.0)) < 1.0, "…standing in the doorway (%s)" % str(p.global_position))
	check(p.animated_sprite.scale.x < p._plane_base_scale.x * 0.8 and p.escaping, "…smaller with distance, and untouchable")


func _test_hallway_decals() -> void:
	print("[floor 30 is dressed like every floor — and the tutorial's wall text keeps its own space]")
	for first in [false, true]:
		WorldState.new_game()
		WorldState.current_floor = 30
		WorldState.tutorial_completed = not first
		WorldState.is_first_run = first
		WorldState.master_seed = 424242
		var h = load("res://scenes/hallway.tscn").instantiate()
		add_child(h)
		for i in 3:
			await get_tree().process_frame
		var wall = h.get_node_or_null("CorridorDecals")
		var n := 0
		var hits := 0
		if wall != null:
			var origin: Vector2 = load("res://scripts/building_floors.gd").CORRIDOR_ART_POS
			for ch in wall.get_children():
				if not (ch is Sprite2D):
					continue
				n += 1
				var rect := Rect2(ch.position + origin, ch.texture.get_size())
				for hint in h.get_children():
					if hint.is_in_group("tutorial_blood") and hint.visible:
						var sz: Vector2 = hint.block_size()
						if rect.intersects(Rect2(hint.position.x - sz.x * 0.5, hint.position.y, sz.x, sz.y)):
							hits += 1
		check(wall != null and n >= 3, "%s: floor 30 carries its dressing + marks (%d decals)" % ["first run" if first else "later runs", n])
		check(hits == 0, "%s: no decal lands on a blood-text hint (%d)" % ["first run" if first else "later runs", hits])
		h.free()
		await get_tree().process_frame
	WorldState.is_first_run = false
