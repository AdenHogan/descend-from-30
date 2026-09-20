extends Node

# Headless test for the three-run arc / time skip (docs/THREE_RUN_ARC.md):
# advance_run's persistence split (fresh character, decayed world that persists),
# the run cap / arc-over signal, the enemy reshuffle across runs, and the
# time-of-day derivation. Run:  godot --headless res://tests/run_arc_test.tscn

var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== three-run arc / time skip test ===")
	await _test_persistence_split()
	_test_arc_over_cap()
	_test_time_of_day()
	_test_infection_grade()
	_test_door_decay()
	await _test_enemy_reshuffle()
	_test_run_cast()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _test_run_cast() -> void:
	# The playthrough casts THREE of the four characters, one per run, in a seeded random
	# order — deterministic from master_seed (stable across save/load), and current_character()
	# tracks current_run.
	print("[run cast: 3 of 4 characters, one per run]")
	WorldState.new_game()
	var cast: Array = WorldState.run_cast()
	check(cast.size() == 3, "the cast is 3 characters (%d)" % cast.size())
	check(cast[0] != cast[1] and cast[1] != cast[2] and cast[0] != cast[2], "the three run characters are distinct")
	var allknown := true
	for c in cast:
		if c not in WorldState.CHARACTERS:
			allknown = false
	check(allknown, "every cast member is a known character")
	# Deterministic per master_seed.
	var again: Array = WorldState.run_cast()
	check(cast == again, "run_cast is deterministic for a given master_seed")
	# current_character follows the run.
	WorldState.current_run = 1
	var c1: String = WorldState.current_character()
	WorldState.current_run = 2
	var c2: String = WorldState.current_character()
	WorldState.current_run = 3
	var c3: String = WorldState.current_character()
	check(c1 == cast[0] and c2 == cast[1] and c3 == cast[2], "current_character() maps run 1/2/3 to the cast in order")
	# A different playthrough (new master_seed) can re-roll the cast — over several seeds the
	# selection isn't always identical (variety, not a fixed trio).
	var seen := {}
	for i in range(12):
		WorldState.master_seed = 1000 + i * 7919
		seen[",".join(WorldState.run_cast())] = true
	check(seen.size() >= 2, "the cast varies across playthroughs (%d distinct over 12 seeds)" % seen.size())
	# The HUD loads THAT run's character's portrait set (not a hardcoded one).
	WorldState.new_game()
	WorldState.current_run = 2
	HUD.update_portrait(0)
	check(HUD._loaded_char == WorldState.run_character(2), "HUD loads the run's character portraits (%s)" % HUD._loaded_char)
	if HUD.portrait != null and HUD.portrait.texture != null:
		check(String(HUD.portrait.texture.resource_path).find(WorldState.run_character(2)) != -1,
			"the shown portrait texture is that character's file")


func _test_persistence_split() -> void:
	# A fresh character each run, but cross-run rewards and the decayed world persist.
	print("[persistence split]")
	WorldState.new_game()
	WorldState.tutorial_completed = true
	WorldState.is_first_run = false
	# Set up per-run character state that MUST be wiped, and cross-run rewards that stay.
	WorldState.add_to_inventory("002")                 # a hammer in the pack
	WorldState.wallet_unlocked = true
	WorldState.wallet_balance = 250
	WorldState.active_upgrades = ["stamina_boon"]
	WorldState.player_health = 3
	WorldState.stamina = 12.0
	WorldState.current_floor = 7
	# Loot depletion that must survive the skip.
	WorldState.searched_anchors["705:anchor0"] = true
	var seed_before: int = WorldState.master_seed

	var over: bool = WorldState.advance_run()
	check(not over, "advancing from run 1 does not end the arc")
	check(WorldState.current_run == 2, "current_run advances to 2 (%d)" % WorldState.current_run)
	check(WorldState.time_of_day() == "Afternoon", "run 2 is Afternoon (%s)" % WorldState.time_of_day())
	# Fresh character.
	check(WorldState.inventory.is_empty(), "inventory is wiped (fresh character)")
	check(WorldState.wallet_balance == 0, "wallet BALANCE resets (per-run)")
	check(WorldState.player_health == 0, "health reset to 0 (player _ready refills)")
	check(WorldState.current_floor == 30, "next character starts at Floor 30")
	check(is_equal_approx(WorldState.max_stamina, 100.0), "stamina base reset (upgrades re-fold on top)")
	# Cross-run rewards persist.
	check(WorldState.wallet_unlocked, "wallet UNLOCK persists across the run")
	check(WorldState.active_upgrades == ["stamina_boon"], "upgrades persist across the run")
	check(seed_before == WorldState.master_seed, "same building (master_seed unchanged, not re-rolled)")
	# Loot depletion persists.
	check(WorldState.searched_anchors.get("705:anchor0", false), "emptied anchors stay emptied (loot depletion persists)")
	# The dead reshuffle: kill/position memory cleared for a fresh infestation.
	check(WorldState.killed_zombies.is_empty(), "kill memory cleared (fresh infestation)")
	check(WorldState.zombie_positions.is_empty(), "position memory cleared for reshuffle")
	await get_tree().process_frame


func _test_arc_over_cap() -> void:
	# The arc is three characters; advancing from run 3 reports the playthrough over.
	print("[arc-over cap]")
	WorldState.new_game()
	WorldState.tutorial_completed = true
	WorldState.is_first_run = false
	check(WorldState.advance_run() == false, "run 1 -> 2 continues")
	check(WorldState.advance_run() == false, "run 2 -> 3 continues")
	check(WorldState.current_run == 3, "reached run 3 (%d)" % WorldState.current_run)
	check(WorldState.advance_run() == true, "run 3 concluding ends the arc")
	check(WorldState.current_run == 3, "current_run does not overflow past 3 (%d)" % WorldState.current_run)


func _test_time_of_day() -> void:
	print("[time of day]")
	WorldState.new_game()
	WorldState.current_run = 1
	check(WorldState.time_of_day() == "Morning", "run 1 = Morning")
	var morning := WorldState.time_modulate_color()
	WorldState.current_run = 3
	check(WorldState.time_of_day() == "Night", "run 3 = Night")
	var night := WorldState.time_modulate_color()
	check(morning != night, "the time-of-day tint differs morning vs night")
	check(night.b > night.r, "night grades cool/blue (b=%.2f > r=%.2f)" % [night.b, night.r])


func _test_infection_grade() -> void:
	# Real lighting: the CanvasModulate is now the AMBIENT DARKNESS the ceiling lamps + fire
	# punch through (not a flat tint over lit art). Night is darkest, and the DESCENT dims it
	# further — the failing lower building is darker, for tension + sectional identity.
	print("[ambient darkness + descent dimming]")
	WorldState.new_game()
	check(is_equal_approx(WorldState.infection_depth(30), 0.0), "top of the building is un-infected (depth 0)")
	check(is_equal_approx(WorldState.infection_depth(1), 1.0), "the bottom is fully infected (depth 1)")
	check(is_equal_approx(WorldState.infection_depth(0), 1.0), "the lobby is at max depth too")
	check(WorldState.infection_depth(5) > WorldState.infection_depth(20), "it deepens as you descend")
	# Same run: a low floor is DARKER than a high floor (descent dim).
	WorldState.current_run = 2
	var top := WorldState.ambient_color(29)
	var bot := WorldState.ambient_color(1)
	check(top.is_equal_approx(WorldState.ambient_color(29)), "ambient is deterministic")
	var top_lum := top.r + top.g + top.b
	var bot_lum := bot.r + bot.g + bot.b
	check(bot_lum < top_lum, "a deep floor is darker than a high one same run (%.2f < %.2f)" % [bot_lum, top_lum])
	# Later runs are darker overall: the SAME floor is darker at night than in the morning.
	WorldState.current_run = 1
	var morning_lum := WorldState.ambient_color(15)
	var m_sum := morning_lum.r + morning_lum.g + morning_lum.b
	WorldState.current_run = 3
	var night := WorldState.ambient_color(15)
	var n_sum := night.r + night.g + night.b
	check(n_sum < m_sum, "night ambient is darker than morning same floor (%.2f < %.2f)" % [n_sum, m_sum])
	check(night.b > night.r, "night ambient reads cool/blue (b=%.2f > r=%.2f)" % [night.b, night.r])
	# Ambient is always applied (intrinsic — not a toggle): a normal floor darkens the world.
	var probe := Node2D.new()
	add_child(probe)
	WorldState.apply_time_tint(probe, 1)
	var cm := probe.get_node_or_null("WorldGrade") as CanvasModulate
	check(cm != null and not cm.color.is_equal_approx(Color.WHITE), "lighting is intrinsic => ambient darkens the world")
	probe.queue_free()


func _test_door_decay() -> void:
	# The skip mutates the doors the player left: some loosen, more breach. Across a
	# building's worth of doors at least one state changes (probabilities ~15-25%).
	print("[door decay]")
	WorldState.new_game()
	WorldState.tutorial_completed = true
	WorldState.is_first_run = false
	for f in range(2, 30):
		WorldState.seed_floor_door_states(f)
	var before := WorldState.door_states.duplicate(true)
	check(before.size() > 0, "doors were seeded to decay (%d)" % before.size())
	WorldState.advance_run()
	var changed := 0
	for k in before.keys():
		if WorldState.door_states.get(k, -1) != before[k]:
			changed += 1
	check(changed > 0, "the time skip changed some door states (%d of %d)" % [changed, before.size()])
	# The door set itself persists (mutated in place, not dropped).
	check(WorldState.door_states.size() == before.size(), "door roster persists across the skip")


func _test_enemy_reshuffle() -> void:
	# Enemy POSITIONS re-roll across the time skip (a fresh infestation), while staying
	# deterministic within a run. Build the same floor on run 1 and run 2 and compare.
	print("[enemy reshuffle across runs]")
	WorldState.new_game()
	WorldState.tutorial_completed = true
	WorldState.is_first_run = false
	WorldState.current_run = 1
	# Pick a floor guaranteed to have a couple of zombies (count is run-independent),
	# so the reshuffle comparison isn't defeated by a 0-zombie roll.
	var f := 18
	for cand in range(11, 20):
		if WorldState.get_floor_zombie_count(cand) >= 2:
			f = cand
			break
	WorldState.current_floor = f
	WorldState.spawn_source = "stair"
	WorldState.stair_direction = "down"
	WorldState.stair_spawn_side = "left"
	WorldState.seed_floor_door_states(f)
	var xs1 := await _floor_zombie_xs(f)
	# Advance to run 2 (same seed) and rebuild the same floor.
	WorldState.advance_run()
	WorldState.current_floor = f
	WorldState.spawn_source = "stair"
	WorldState.stair_direction = "down"
	WorldState.stair_spawn_side = "left"
	WorldState.seed_floor_door_states(f)
	var xs2 := await _floor_zombie_xs(f)
	check(xs1.size() > 0 and xs2.size() > 0, "both runs spawned zombies (%d / %d)" % [xs1.size(), xs2.size()])
	check(xs1 != xs2, "run 2 zombie positions differ from run 1 (reshuffled)")


func _floor_zombie_xs(floor_num: int) -> Array:
	var bf = load("res://scenes/building_floors.tscn").instantiate()
	bf.setup_floor = floor_num
	add_child(bf)
	for i in range(4):
		await get_tree().process_frame
	var xs: Array = []
	for z in get_tree().get_nodes_in_group("zombie"):
		if z.is_in_group("stair_enemy"):
			continue                          # stair enemies seed on their own key
		xs.append(round(z.global_position.x))
	xs.sort()
	bf.queue_free()
	await get_tree().process_frame
	return xs
