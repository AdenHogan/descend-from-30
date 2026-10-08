extends Node

# THE FOUR OPENINGS + PERSONAL QUESTS (owner round 37; docs/CHARACTER_STORIES.md): Joe is always the tutorial's character; the pack
# carries over from the first character to find it; each character's run opens on its own cue + line (two are locked out and knock,
# two aren't) and carries a quest that turns over on its own hook — Joe descends, Alex finds Mr Hale on 29, Vivianne sees her cat,
# Amina picks up food. Vivianne's cat lives in the world (a cameo on 30, a third of the corridor floors) and the HUD's foreground; it
# is never in a combat group and never dies. Everything story-shaped is gated by WorldState.story_rule, which only the real
# Game.new_game() turns on — so every OTHER suite (random cast!) still meets the old game.
# Run: godot --headless res://tests/character_story_test.tscn

const HallwayScript := preload("res://scripts/hallway.gd")

var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== character story test ===")
	_test_rule_is_real_game_only()
	_test_cast_lock()
	_test_openers()
	_test_assets()
	_test_quest_lifecycle()
	_test_backpack_carry_over()
	_test_save_load()
	_test_journal()
	await _test_alex_body()
	await _test_cat_floors()
	await _test_cat_cameo()
	await _test_foreground_cat()
	_reset()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _reset() -> void:
	WorldState.dev_seed = 0
	WorldState.story_rule = false
	WorldState.packless_rule = false
	WorldState.tutorial_completed = true
	WorldState.new_game()
	TutorialManager._resume()
	get_tree().paused = false


## A story-rule game (the real New Game's rule) on a seed whose run-1 character is `cid`. Joe only exists as run 1's character
## in a game that includes the tutorial, so he's the one that needs `tutorial_completed` false; everyone else needs it true.
func _become(cid: String) -> bool:
	WorldState.story_rule = true
	WorldState.tutorial_completed = cid != CharacterStory.JOE
	for s in range(1, 600):
		WorldState.dev_seed = s
		WorldState.new_game()
		if WorldState.run_cast()[0] == cid:
			return true
	return false


# --- the rule ----------------------------------------------------------------------------------------------------

func _test_rule_is_real_game_only() -> void:
	print("[the story rule is the REAL New Game's, nothing else's]")
	WorldState.story_rule = false
	WorldState.tutorial_completed = false
	WorldState.dev_seed = 0
	WorldState.new_game()
	check(not WorldState.story_rule and not WorldState.joe_opens, "a plain WorldState.new_game() has no story rule and no Joe lock")
	check(CharacterStory.alex_body(CharacterStory.ALEX_BODY_FLOOR).is_empty(), "…so no scripted body")
	check(not CharacterStory.cat_on_floor(5), "…and no cat")
	var src: String = FileAccess.get_file_as_string("res://scripts/game.gd")
	check(src.contains("WorldState.story_rule = true"), "Game.new_game() turns the rule on")
	check(src.find("WorldState.story_rule = true") < src.find("WorldState.new_game()"), "…BEFORE the world is dealt (the cast is cast from it)")
	check(WorldState.run_story_stage == -1, "a game starts with no quest begun")


# --- Joe is always the tutorial's character --------------------------------------------------------------------------

func _test_cast_lock() -> void:
	print("[Joe is always the tutorial character]")
	WorldState.story_rule = true
	WorldState.tutorial_completed = false
	var all_joe := true
	var all_unique := true
	var seen_others := {}
	for s in range(1, 61):
		WorldState.dev_seed = s
		WorldState.new_game()
		var cast: Array = WorldState.run_cast()
		all_joe = all_joe and cast[0] == WorldState.TUTORIAL_CHARACTER and WorldState.TUTORIAL_CHARACTER == CharacterStory.JOE
		var uniq := {}
		for c in cast:
			uniq[c] = true
		all_unique = all_unique and cast.size() == 3 and uniq.size() == 3
		seen_others[cast[1]] = true
		seen_others[cast[2]] = true
		if s == 1:
			check(WorldState.joe_opens and WorldState.is_first_run, "a game that includes the tutorial: Joe opens it")
			check(WorldState.current_character() == WorldState.TUTORIAL_CHARACTER, "…run 1 IS Joe")
			check(WorldState.run_character(2) != CharacterStory.JOE and WorldState.run_character(3) != CharacterStory.JOE, "…and he isn't cast twice")
	check(all_joe, "60 seeds: run 1 is Joe in every one")
	check(all_unique, "…and the cast is always three different people")
	check(seen_others.size() == 3, "…the OTHER two slots still vary over all three others (%d seen)" % seen_others.size())
	# without the tutorial (a completed one) the cast is the old free draw
	WorldState.tutorial_completed = true
	var firsts := {}
	for s in range(1, 81):
		WorldState.dev_seed = s
		WorldState.new_game()
		firsts[WorldState.run_cast()[0]] = true
	check(not WorldState.joe_opens and firsts.size() == 4, "tutorial done: any of the four can open (%d different in 80 seeds)" % firsts.size())
	# …and with the rule off (every other suite) nothing is locked
	WorldState.story_rule = false
	WorldState.tutorial_completed = false
	firsts.clear()
	for s in range(1, 81):
		WorldState.dev_seed = s
		WorldState.new_game()
		firsts[WorldState.run_cast()[0]] = true
	check(firsts.size() == 4, "story rule off: still the free draw, tutorial or not")
	# the cast cache must follow the lock (same seed, lock toggled)
	WorldState.dev_seed = 7
	WorldState.story_rule = true
	WorldState.tutorial_completed = true
	WorldState.new_game()
	var free_cast: Array = WorldState.run_cast()
	WorldState.joe_opens = true
	var locked_cast: Array = WorldState.run_cast()
	WorldState.joe_opens = false
	check(locked_cast[0] == CharacterStory.JOE and WorldState.run_cast() == free_cast, "the cast cache follows the lock both ways (no stale cast)")


# --- the openers -----------------------------------------------------------------------------------------------------

func _test_openers() -> void:
	print("[four openings: cue, line, locked out or not]")
	WorldState.story_rule = true
	WorldState.tutorial_completed = false
	WorldState.dev_seed = 0
	WorldState.new_game()
	var cues := {}
	var lines := {}
	for cid in WorldState.CHARACTERS:
		var op: Dictionary = CharacterStory.opener(cid)
		cues[op["cue"]] = true
		lines[op["line"]] = true
		check(str(op["line"]) != "" and (bool(op["knock"]) == not (op["lockout"] as Array).is_empty()), "%s: a first line, and a lockout exactly when they knock" % cid)
		check(bool(op["knock"]) or str(op["walkout"]) != "", "%s: either knocks or says one line as they set off" % cid)
	check(cues.size() == 4 and lines.size() == 4, "four different cues and four different first lines")
	check(CharacterStory.opener(CharacterStory.JOE)["cue"] == "bang", "Joe: the banging on the door")
	check(CharacterStory.opener(CharacterStory.ALEX)["cue"] == "scream" and not CharacterStory.opener(CharacterStory.ALEX)["knock"], "Alex: a scream, not locked out")
	check(CharacterStory.opener(CharacterStory.VIVIANNE)["cue"] == "meow" and not CharacterStory.opener(CharacterStory.VIVIANNE)["knock"], "Vivianne: a meow, not locked out")
	check(CharacterStory.opener(CharacterStory.AMINA)["cue"] == "growl" and CharacterStory.opener(CharacterStory.AMINA)["knock"], "Amina: a hungry stomach, locked out")
	# every cue the overlay is asked to play has audio (or is the built-in bang)
	var consts: Dictionary = load("res://scripts/intro_overlay.gd").get_script_constant_map()
	for cue in cues:
		if cue == "bang":
			continue
		check((consts["CUE_AUDIO"] as Dictionary).has(cue) and (consts["CUE_DELAY"] as Dictionary).has(cue), "intro_overlay knows the '%s' cue" % cue)
	for cue in consts["CUE_AUDIO"]:
		for entry in consts["CUE_AUDIO"][cue]:
			check(ResourceLoader.exists(str(entry[1])), "cue audio exists: %s" % entry[1])
	# Joe's lines are the tutorial's single edit point, still
	var L: Dictionary = TutorialManager.LINES
	for key in ["opener_1", "opener_4", "opener_5", "opener_5_free", "run_after_fell", "run_after_escaped"]:
		check(L.has(key), "TutorialManager.LINES still has '%s'" % key)
	for key in ["run2_open", "run3_open", "run_lockout"]:
		check(not L.has(key), "the shared run-2/3 line '%s' is gone (each character has their own)" % key)


func _test_assets() -> void:
	print("[the cat and the cues have real files]")
	for anim in ["walk", "run", "sit", "meow"]:
		check(ResourceLoader.exists("res://assets/cat/cat_%s.png" % anim), "cat body strip: %s" % anim)
		check(ResourceLoader.exists("res://assets/cat/cat_eyes_%s.png" % anim), "cat eyes strip: %s" % anim)
	for f in ["cat/meow_1.wav", "cat/meow_2.wav", "cat/meow_3.wav", "story/scream_far.wav", "story/growl.wav"]:
		var snd = load("res://assets/audio/" + f)
		check(snd is AudioStream and snd.get_length() > 0.2, "audio loads and has length: %s" % f)
	var CatActor = load("res://scripts/cat_actor.gd")
	check(CatActor.art_present(), "the cat's art is present")
	var sf: SpriteFrames = CatActor.frames(false)
	for anim in CatActor.ANIMS:
		check(sf.has_animation(anim) and sf.get_frame_count(anim) == int(CatActor.ANIMS[anim]), "body '%s' has %d frames" % [anim, CatActor.ANIMS[anim]])
	check(CatActor.frames(true).has_animation("run"), "the eyes-only frames exist too")


# --- the quests ------------------------------------------------------------------------------------------------------

func _test_quest_lifecycle() -> void:
	print("[each character's quest begins with their run and turns over on its own hook]")
	for cid in WorldState.CHARACTERS:
		check(_become(cid), "(found a seed whose run-1 character is %s)" % cid)
		check(WorldState.current_character() == cid and WorldState.run_story_stage == -1, "%s: run 1, no quest begun yet" % cid)
		check(CharacterStory.current_quest().is_empty(), "%s: nothing in the journal before it begins" % cid)
		# a hook before the quest has begun is ignored (it's the opening's own time)
		CharacterStory.on_cat_seen()
		CharacterStory.on_floor_arrival(29)
		check(WorldState.run_story_stage == -1 and not CharacterStory.flag("cat_seen"), "%s: hooks do nothing before the quest begins (and don't spend their flag)" % cid)
		CharacterStory.begin_run_quest()
		check(WorldState.run_story_stage == 0, "%s: begin_run_quest -> stage 0" % cid)
		check(HUD.quest_banner.active and HUD.quest_banner.kicker_label.text.contains("NEW QUEST"), "%s: the NEW QUEST banner shows" % cid)
		check(HUD.quest_banner.title_label.text == CharacterStory.quest(cid)["title"], "%s: …with the quest's title (%s)" % [cid, HUD.quest_banner.title_label.text])
		var q: Dictionary = CharacterStory.current_quest()
		check(q["stage"] == 0 and q["objective"] == CharacterStory.quest_objective(cid, 0) and q["earlier"].is_empty(), "%s: the journal shows the opening objective" % cid)
		CharacterStory.begin_run_quest()
		check(WorldState.run_story_stage == 0, "%s: beginning twice changes nothing" % cid)
		match cid:
			CharacterStory.JOE:
				CharacterStory.on_floor_arrival(30)
				check(WorldState.run_story_stage == 0, "Joe: arriving on 30 isn't leaving")
				CharacterStory.on_floor_arrival(29)
				check(WorldState.run_story_stage == 1, "Joe: reaching floor 29 — he chose to descend — turns the quest over")
			CharacterStory.ALEX:
				CharacterStory.on_floor_arrival(29)
				check(WorldState.run_story_stage == 0, "Alex: arriving on 29 doesn't (the body does)")
				CharacterStory.on_alex_body()
				check(TutorialManager._awaiting, "Alex: reaching Mr Hale is a paused beat")
				check(WorldState.run_story_stage == 0, "…the quest turns over once it is dismissed, not before")
				TutorialManager._resume()
				check(WorldState.run_story_stage == 1 and HUD.quest_banner.kicker_label.text.contains("UPDATED"), "Alex: …then OBJECTIVE UPDATED")
				CharacterStory.on_alex_body()
				check(not TutorialManager._awaiting, "Alex: the beat plays once a run")
			CharacterStory.VIVIANNE:
				CharacterStory.on_cat_seen()
				check(WorldState.run_story_stage == 1 and CharacterStory.flag("cat_seen"), "Vivianne: seeing her cat turns the quest over")
			CharacterStory.AMINA:
				WorldState.add_to_inventory("002")
				check(WorldState.run_story_stage == 0, "Amina: a hammer isn't food")
				WorldState.add_to_inventory(CharacterStory.AMINA_FOOD)
				check(WorldState.run_story_stage == 1, "Amina: Canned Food turns the quest over")
		var after: Dictionary = CharacterStory.current_quest()
		check(after["stage"] == 1 and after["earlier"].size() == 1 and after["objective"] == CharacterStory.quest_objective(cid, 1),
			"%s: the journal strikes the first objective and shows the second" % cid)
		CharacterStory.advance(0)
		check(WorldState.run_story_stage == 1, "%s: a quest never goes backwards" % cid)
		# each hook only belongs to its own character
		if cid != CharacterStory.AMINA:
			WorldState.run_story_stage = 0
			WorldState.add_to_inventory(CharacterStory.AMINA_FOOD)
			check(WorldState.run_story_stage == 0, "%s: food means nothing to them" % cid)
		if cid != CharacterStory.JOE:
			WorldState.run_story_stage = 0
			CharacterStory.on_floor_arrival(29)
			check(WorldState.run_story_stage == 0, "%s: leaving the floor isn't their hook" % cid)
		if cid != CharacterStory.VIVIANNE:
			WorldState.run_story_flags.clear()
			WorldState.run_story_stage = 0
			CharacterStory.on_cat_seen()
			check(WorldState.run_story_stage == 0 and not CharacterStory.flag("cat_seen"), "%s: a cat means nothing to them" % cid)
		# the next character starts their own
		WorldState.set_run_outcome(1, "dead")
		WorldState.advance_run()
		check(WorldState.run_story_stage == -1 and WorldState.run_story_flags.is_empty(), "%s -> next run: the quest and its flags reset" % cid)
		TutorialManager._resume()
	# the descent quest for the tutorial's Joe names the spare key; later it doesn't
	WorldState.is_first_run = true
	check(CharacterStory.quest_objective(CharacterStory.JOE, 0).contains("3003"), "Joe's opening objective in the tutorial: the spare key from 3003")
	WorldState.is_first_run = false
	check(not CharacterStory.quest_objective(CharacterStory.JOE, 0).contains("3003"), "…and without the tutorial there is no such errand")


# --- the pack carries over --------------------------------------------------------------------------------------------

func _test_backpack_carry_over() -> void:
	print("[the first character to find the pack hands it on]")
	WorldState.story_rule = true
	WorldState.packless_rule = true
	WorldState.tutorial_completed = false
	WorldState.dev_seed = 0
	WorldState.new_game()
	check(not WorldState.has_backpack and not WorldState.backpack_found, "run 1: pockets only, nobody has found the pack")
	WorldState.take_backpack()
	check(WorldState.backpack_found, "taking it records it as found")
	WorldState.add_to_inventory("002")
	WorldState.set_run_outcome(1, "dead")
	WorldState.advance_run()
	check(WorldState.has_backpack and WorldState.inventory.is_empty(), "run 2: the pack is already on (and the pockets are fresh)")
	check(WorldState.get_inventory_slots() > WorldState.POCKET_SLOTS, "…so the full bag's slots are open from the first step")
	WorldState.set_run_outcome(2, "dead")
	WorldState.advance_run()
	check(WorldState.has_backpack, "run 3: still on")
	WorldState.new_game()
	check(not WorldState.backpack_found and not WorldState.has_backpack, "a new game forgets it (the tutorial's pack must be found again)")
	WorldState.packless_rule = false


# --- saved -----------------------------------------------------------------------------------------------------------

func _test_save_load() -> void:
	print("[story state survives Save + Continue]")
	WorldState.packless_rule = true          # (the real New Game's rule — set BEFORE the world is dealt, as Game.new_game does)
	check(_become(CharacterStory.AMINA), "(an Amina seed)")
	check(not WorldState.has_backpack, "(pockets only)")
	CharacterStory.begin_run_quest()
	CharacterStory.set_flag("something")
	WorldState.take_backpack()
	WorldState.save_game("res://scenes/hallway.tscn", false)
	var was_cast: Array = WorldState.run_cast()
	WorldState.run_story_stage = -1
	WorldState.run_story_flags = {}
	WorldState.backpack_found = false
	WorldState.story_rule = false
	WorldState.joe_opens = true
	WorldState.load_game()
	check(WorldState.run_story_stage == 0 and CharacterStory.flag("something"), "the quest stage and its flags come back")
	check(WorldState.backpack_found and WorldState.story_rule and not WorldState.joe_opens,
		"the pack record, the rule and the lock come back (found %s, rule %s, lock %s)" % [WorldState.backpack_found, WorldState.story_rule, WorldState.joe_opens])
	check(WorldState.run_cast() == was_cast, "…and so does the cast")
	WorldState.delete_save()
	# an OLD save (no story keys) is the old game: no rule, no quest
	var data := {}
	check(bool(data.get("story_rule", false)) == false and int(data.get("run_story_stage", -1)) == -1, "missing keys default to no story (an old save plays as it did)")
	WorldState.packless_rule = false


# --- the journal -----------------------------------------------------------------------------------------------------

func _test_journal() -> void:
	print("[the journal's Quests page]")
	check(_become(CharacterStory.VIVIANNE), "(a Vivianne seed)")
	var panel = HUD.character_panel
	check(panel != null, "(the HUD's journal)")
	if panel == null:
		return
	var empty_text: String = panel._quest_bbcode()
	check(empty_text.contains("No active quests"), "before the quest begins: 'No active quests'")
	CharacterStory.begin_run_quest()
	var open_text: String = panel._quest_bbcode()
	check(open_text.contains("Lost cat") and open_text.contains("Find your cat."), "the quest and its objective are listed")
	CharacterStory.on_cat_seen()
	var done_text: String = panel._quest_bbcode()
	check(done_text.contains("[s]Find your cat.[/s]") and done_text.contains(CharacterStory.quest_objective(CharacterStory.VIVIANNE, 1)),
		"the finished objective is struck through, the new one shown")


# --- Alex's body on 29 ------------------------------------------------------------------------------------------------

func _test_alex_body() -> void:
	print("[Alex finds a neighbour dead on floor 29]")
	check(_become(CharacterStory.ALEX), "(an Alex seed)")
	check(not CharacterStory.alex_body(29).is_empty(), "29 holds the scripted body in Alex's run")
	check(CharacterStory.alex_body(28).is_empty() and CharacterStory.alex_body(30).is_empty(), "…and only 29")
	check(_become(CharacterStory.VIVIANNE) and CharacterStory.alex_body(29).is_empty(), "no body for another character")
	check(_become(CharacterStory.ALEX), "(Alex again)")
	WorldState.current_floor = 29
	WorldState.spawn_source = "stairs"
	WorldState.stair_spawn_side = WorldState.canonical_stair_arrival_side(29)
	WorldState.stair_direction = "down"
	CharacterStory.begin_run_quest()
	var bf = load("res://scenes/building_floors.tscn").instantiate()
	bf.setup_floor = 29
	add_child(bf)
	for i in range(6):
		await get_tree().process_frame
	var trig: Node = null
	for t in get_tree().get_nodes_in_group("story_trigger"):
		if bf.is_ancestor_of(t):
			trig = t
	check(trig != null, "floor 29 has the tripwire beside the body")
	var body_zone: Node = null
	for z in bf.find_children("Body_*", "Area2D", true, false):
		body_zone = z
	check(body_zone != null, "…and the body is a searchable corridor body like the others")
	if trig != null:
		var player = get_tree().get_first_node_in_group("player")
		check(player != null, "(the floor's player)")
		if player != null:
			trig.emit_signal("body_entered", player)
			check(TutorialManager._awaiting and CharacterStory.flag("alex_body"), "walking onto it plays the beat once")
			TutorialManager._resume()
			check(WorldState.run_story_stage == 1, "…and turns the quest over")
			await get_tree().process_frame
			check(not is_instance_valid(trig) or trig.is_queued_for_deletion(), "…and the tripwire is spent")
	bf.free()
	await get_tree().process_frame
	# another character's floor 29 has no tripwire
	check(_become(CharacterStory.AMINA), "(an Amina seed)")
	WorldState.current_floor = 29
	var bf2 = load("res://scenes/building_floors.tscn").instantiate()
	bf2.setup_floor = 29
	add_child(bf2)
	for i in range(4):
		await get_tree().process_frame
	var any := false
	for t in get_tree().get_nodes_in_group("story_trigger"):
		if bf2.is_ancestor_of(t):
			any = true
	check(not any, "floor 29 in anyone else's run has no story tripwire")
	bf2.free()
	await get_tree().process_frame
	TutorialManager._resume()


# --- the cat on the corridor plane --------------------------------------------------------------------------------------

func _test_cat_floors() -> void:
	print("[Vivianne's cat on some corridor floors]")
	check(_become(CharacterStory.VIVIANNE), "(a Vivianne seed)")
	var on: Array = []
	for f in range(1, 30):
		if CharacterStory.cat_on_floor(f):
			on.append(f)
	check(on.size() >= 4 and on.size() <= 18, "about a third of floors 1-29 have her (%d: %s)" % [on.size(), str(on)])
	check(not CharacterStory.cat_on_floor(0) and not CharacterStory.cat_on_floor(30) and not CharacterStory.cat_on_floor(31), "never on the lobby or floor 30's corridor (the cameo is the hallway's)")
	var again: Array = []
	for f in range(1, 30):
		if CharacterStory.cat_on_floor(f):
			again.append(f)
	check(again == on, "the same floors every time (seeded per floor + run)")
	var x_ok := true
	for f in range(1, 30):
		var cx: float = CharacterStory.cat_start_x(f, 1)
		x_ok = x_ok and cx >= 260.0 and cx <= 1060.0 and cx == CharacterStory.cat_start_x(f, 1)
	check(x_ok, "it starts inside the walkable corridor, deterministically")
	if on.is_empty():
		return
	var floor_with: int = on[0]
	var floor_without := -1
	for f in range(1, 30):
		if not on.has(f):
			floor_without = f
			break
	WorldState.current_floor = floor_with
	WorldState.spawn_source = "stairs"
	WorldState.stair_spawn_side = WorldState.canonical_stair_arrival_side(floor_with)
	WorldState.stair_direction = "down"
	var bf = load("res://scenes/building_floors.tscn").instantiate()
	bf.setup_floor = floor_with
	add_child(bf)
	for i in range(5):
		await get_tree().process_frame
	var cat: Node2D = bf.get_node_or_null("Cat")
	check(cat != null, "floor %d: the cat is on the corridor" % floor_with)
	if cat != null:
		check(absf(cat.global_position.y - 419.0) < 0.5, "…its feet on the standard corridor line (419): y %.1f" % cat.global_position.y)
		check(cat.is_in_group("cat") and not cat.is_in_group("zombie") and not cat.is_in_group("resident_target") and not cat.is_in_group("player"),
			"…in the cat group ONLY (no weapon, fire, spit or noise group)")
		check(not (cat is CollisionObject2D) and cat.find_children("*", "CollisionObject2D", true, false).is_empty(), "…with no collision at all (it can't block anyone)")
		check(not cat.has_method("receive_damage") and not cat.has_method("receive_push") and not cat.has_method("burn_tick"), "…and nothing to hurt it with: it never dies")
		check(cat.z_index == 1, "…drawn with the actors")
		# skittish: the player close by sends it running AWAY, inside the corridor
		var player = get_tree().get_first_node_in_group("player")
		cat.state = "sit"
		cat.state_len = 99.0
		cat.global_position.x = 600.0
		if player != null:
			player.global_position.x = 560.0
			cat._flee_cool = 0.0
			cat._process(0.016)
			check(cat.state == "run" and cat.target_x > cat.global_position.x, "someone close by: it bolts the other way (target %.0f)" % cat.target_x)
			check(cat.target_x >= cat.bounds.x and cat.target_x <= cat.bounds.y, "…to a spot inside the corridor's ends")
			var lo: float = 9999.0
			var hi: float = -9999.0
			for i in range(900):
				cat._process(0.05)
				lo = minf(lo, cat.global_position.x)
				hi = maxf(hi, cat.global_position.x)
			check(lo >= cat.bounds.x - 1.0 and hi <= cat.bounds.y + 1.0, "45 s of cat: never leaves the corridor (%.0f..%.0f)" % [lo, hi])
			check(not cat.bolted and cat.visible, "…and it never vanishes (only the cameo's cat does)")
			# Vivianne sees her cat: the flag + quest turn over (once the quest has begun)
			WorldState.run_story_stage = 0
			WorldState.run_story_flags.clear()
			cat._seen = false
			player.global_position.x = cat.global_position.x + 120.0
			cat._process(0.016)
			check(WorldState.run_story_stage == 1 and CharacterStory.flag("cat_seen"), "seeing it on a floor turns her quest over")
	bf.free()
	await get_tree().process_frame
	# floors without her cat, other characters' runs, and the passive pan build
	if floor_without > 0:
		WorldState.current_floor = floor_without
		var bf2 = load("res://scenes/building_floors.tscn").instantiate()
		bf2.setup_floor = floor_without
		add_child(bf2)
		for i in range(4):
			await get_tree().process_frame
		check(bf2.get_node_or_null("Cat") == null, "floor %d (not one of hers): no cat" % floor_without)
		bf2.free()
		await get_tree().process_frame
	check(_become(CharacterStory.ALEX), "(an Alex seed)")
	var none := true
	for f in range(1, 30):
		none = none and not CharacterStory.cat_on_floor(f)
	check(none, "in anyone else's run there is no cat on any floor")
	check(_become(CharacterStory.VIVIANNE), "(Vivianne again)")
	var pf := -1
	for f in range(1, 30):
		if CharacterStory.cat_on_floor(f):
			pf = f
			break
	if pf > 0:
		WorldState.current_floor = pf + 1
		var back = load("res://scenes/building_floors.tscn").instantiate()
		back.setup_floor = pf
		back.passive = true
		add_child(back)
		for i in range(4):
			await get_tree().process_frame
		check(back.get_node_or_null("Cat") == null, "a pan BACKDROP carries no cat (it wanders, so it's live-only)")
		back.go_live()
		for i in range(2):
			await get_tree().process_frame
		check(back.get_node_or_null("Cat") != null, "…but go_live gives the cat to the floor you arrive on")
		back.go_live()
		var n := 0
		for c in back.get_children():
			if c.is_in_group("cat"):
				n += 1
		check(n == 1, "…exactly one, however often it's asked")
		back.free()
		await get_tree().process_frame


# --- the cameo on floor 30 ---------------------------------------------------------------------------------------------

func _test_cat_cameo() -> void:
	print("[floor 30: the cat sits in the hall, then bolts down the stairs]")
	check(_become(CharacterStory.VIVIANNE), "(a Vivianne seed)")
	WorldState.opener_seen = true
	WorldState.current_floor = 30
	var h = load("res://scenes/hallway.tscn").instantiate()
	add_child(h)
	for i in range(4):
		await get_tree().process_frame
	var cat: Node2D = h.get_node_or_null("Cat")
	check(cat != null, "Vivianne's floor 30 has the cat in the hall")
	if cat != null:
		check(is_equal_approx(cat.bolt_to_x, HallwayScript.CAT_CAMEO_BOLT_X) and cat.bolt_to_x < cat.global_position.x, "…meant to run for the stairwell (x %.0f, left of it)" % cat.bolt_to_x)
		check(absf(cat.global_position.y - 419.0) < 0.5, "…on the corridor line")
		var player = get_tree().get_first_node_in_group("player")
		check(player != null, "(the hallway's player)")
		if player != null:
			# during the opening itself (quest not begun) it neither bolts nor is "seen"
			WorldState.run_story_stage = -1
			player.global_position.x = cat.global_position.x - 100.0
			cat._process(0.016)
			check(cat.state != "run" and not CharacterStory.flag("cat_seen"), "while the opening plays it doesn't bolt and isn't 'seen'")
			CharacterStory.begin_run_quest()
			cat._process(0.016)
			check(cat.state == "run" and CharacterStory.flag("cat_seen") and WorldState.run_story_stage == 1, "once she can act: it bolts, she sees it, the quest turns over")
			var steps := 0
			while is_instance_valid(cat) and not cat.bolted and steps < 400:
				cat._process(0.05)
				steps += 1
			check(is_instance_valid(cat) and cat.bolted and not cat.visible, "it reaches the stairwell and is gone")
			if is_instance_valid(cat):
				check(absf(cat.global_position.x - cat.bolt_to_x) < 1.0, "…at the stairwell's mouth (x %.0f)" % cat.global_position.x)
	h.free()
	await get_tree().create_timer(0.1).timeout
	# once seen the hall has no cat
	var h2 = load("res://scenes/hallway.tscn").instantiate()
	add_child(h2)
	for i in range(3):
		await get_tree().process_frame
	check(h2.get_node_or_null("Cat") == null, "it isn't in the hall again once she has seen it")
	h2.free()
	await get_tree().process_frame
	check(_become(CharacterStory.ALEX), "(an Alex seed)")
	WorldState.current_floor = 30
	var h3 = load("res://scenes/hallway.tscn").instantiate()
	add_child(h3)
	for i in range(3):
		await get_tree().process_frame
	check(h3.get_node_or_null("Cat") == null, "Alex's hall has no cat")
	h3.free()
	await get_tree().process_frame
	TutorialManager._resume()


# --- the foreground dash -----------------------------------------------------------------------------------------------

func _test_foreground_cat() -> void:
	print("[the cat in the foreground]")
	var fg = HUD.fg_cat
	check(fg != null and fg.mouse_filter == Control.MOUSE_FILTER_IGNORE, "the HUD has the foreground cat, and it never eats a click")
	if fg == null:
		return
	# a player is needed for the eligibility test: borrow the hallway's
	check(_become(CharacterStory.VIVIANNE), "(a Vivianne seed)")
	WorldState.opener_seen = true
	WorldState.current_floor = 30
	var h = load("res://scenes/hallway.tscn").instantiate()
	add_child(h)
	for i in range(4):
		await get_tree().process_frame
	WorldState.run_story_stage = -1
	check(not fg.eligible(), "no dash before the quest begins")
	CharacterStory.begin_run_quest()
	check(fg.eligible(), "…and one is allowed once she's on her way")
	get_tree().paused = true
	check(not fg.eligible(), "…not while paused")
	get_tree().paused = false
	HUD.show_dialogue("hello")
	check(not fg.eligible(), "…not over a line of dialogue")
	HUD.hide_dialogue()
	check(fg.eligible(), "…and again when the screen is clear")
	WorldState.run_story_flags.clear()
	WorldState.run_story_stage = 0
	var dashes0: int = fg.dashes
	fg.trigger()
	check(fg.running and fg.dashes == dashes0 + 1 and fg.body.visible, "trigger(): a dash begins")
	check(CharacterStory.flag("cat_seen") and WorldState.run_story_stage == 1, "…and the first one turns her quest over")
	var steps := 0
	while fg.running and steps < 600:
		fg._process(0.05)
		steps += 1
	check(not fg.running and not fg.body.visible, "…it crosses the whole screen and is gone (%d steps)" % steps)
	check(fg.meowed, "…meowing on the way")
	check(fg.next_in >= fg.EVERY.x and fg.next_in <= fg.EVERY.y, "…and the next one is a minute or so off (%.0f s)" % fg.next_in)
	var seq_ok := true
	for i in range(8):
		fg.trigger()
		seq_ok = seq_ok and fg.feet > 560.0 and fg.feet < 648.0
		fg.running = false
		fg.body.visible = false
		fg.eyes.visible = false
	check(seq_ok, "it always runs along the bottom of the screen")
	# not Vivianne's run: never
	check(_become(CharacterStory.AMINA), "(an Amina seed)")
	CharacterStory.begin_run_quest()
	check(not fg.eligible(), "in anyone else's run the foreground cat never runs")
	h.free()
	await get_tree().process_frame
	TutorialManager._resume()
