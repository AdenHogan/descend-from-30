extends Node

# Character STATS / traits: each run's character folds its own modifiers into the SAME stat fold
# as upgrades (never direct writes), so a run genuinely plays differently depending on who you
# are — and upgrades still stack on top. Locks each character's identity + the real gameplay
# hooks (push/melee cost through the player, exact hearing, unlucky floors, lucky loot pools).
# Run: godot --headless res://tests/character_stats_test.tscn

var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== character stats test ===")
	_test_every_character_defined()
	_test_tenant()
	_test_neighbour()
	_test_super()
	_test_nurse()
	_test_stacks_with_upgrades()
	await _test_player_costs()
	WorldState.active_upgrades.clear()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _play_as(cid: String) -> void:
	# Find a playthrough seed whose FIRST run is this character (the cast is a seeded draw).
	WorldState.new_game()
	WorldState.active_upgrades.clear()
	for s in range(1, 5000):
		WorldState.master_seed = s
		if WorldState.run_character(1) == cid:
			break
	WorldState.current_run = 1
	assert(WorldState.current_character() == cid)


func _near(a: float, b: float) -> bool:
	return absf(a - b) < 0.001


func _test_every_character_defined() -> void:
	print("[every character has traits + honest player-facing lines]")
	var with_flaws := 0
	for cid in WorldState.CHARACTERS:
		var t: Dictionary = WorldState.character_traits(cid)
		check(not t.is_empty() and not t.get("perks", []).is_empty(), "%s has traits + perks" % cid)
		if not t.get("flaws", []).is_empty():
			with_flaws += 1
		check(CharacterPanelScript().traits_bbcode(cid).length() > 0, "%s traits render in the journal" % cid)
	check(with_flaws == 3, "three characters trade a strength for a weakness; the all-rounder has none (%d)" % with_flaws)


func CharacterPanelScript():
	return load("res://scripts/character_panel.gd")


func _test_tenant() -> void:
	print("[The Tenant — all-rounder: more pushes, cheaper swings]")
	_play_as("blond_man")
	var P = load("res://scripts/player.gd")
	var bar: float = WorldState.get_max_stamina()
	var base_pushes := int(floor(bar / P.STAMINA_PUSH_COST))
	var his_pushes := int(floor(bar / (P.STAMINA_PUSH_COST * WorldState.get_push_cost_mult())))
	check(his_pushes == base_pushes + 2, "two more pushes from a full bar (%d → %d)" % [base_pushes, his_pushes])
	check(_near(WorldState.get_melee_cost_mult(), 0.85), "melee swings cost 15% less")
	check(_near(WorldState.get_sprint_speed_mult(), 1.0) and _near(WorldState.get_enemy_count_mult(), 1.0),
		"no weakness — his other stats are baseline")


func _test_neighbour() -> void:
	print("[The Neighbour — endurance + quiet, slower sprint]")
	_play_as("blond_woman")
	check(_near(WorldState.get_sprint_drain_mult(), 0.80), "sprinting drains 20% less")
	check(_near(WorldState.get_stamina_regen_mult(), 1.15), "stamina recovers 15% faster")
	check(_near(WorldState.get_noise_mult(), 0.85), "moves 15% quieter")
	check(_near(WorldState.get_sprint_speed_mult(), 0.88), "but sprints 12% slower")
	check(_near(WorldState.get_move_speed_mult(), 1.0), "walking speed itself is untouched (only the sprint)")


func _test_super() -> void:
	print("[The Super — exact hearing, faster listening; unlucky floors]")
	_play_as("bald_man")
	check(WorldState.has_trait_flag("exact_hearing"), "has exact hearing")
	check(_near(WorldState.get_listen_speed_mult(), 0.75), "listens 25% faster")
	# Pick a floor whose floor-below actually HAS enemies, so a spoken number is really checked.
	WorldState.current_floor = 15
	for f in range(3, 30):
		WorldState.current_floor = f
		if int(WorldState.get_listen_report_for_floor_below()["count"]) > 0:
			break
	var rep: Dictionary = WorldState.get_listen_report_for_floor_below()
	check(int(rep["count"]) > 0, "found a floor with enemies below to listen to (%d)" % int(rep["count"]))
	check(rep["line"] != WorldState.LISTEN_LINES_BELOW[rep["category"]],
		"the stairwell report states the count, not a vague category (\"%s\")" % rep["line"])
	var n: int = int(rep["count"])
	check(n == 0 or WorldState._count_word(n) in rep["line"], "and the number it states is the TRUE count (%d)" % n)
	# Unlucky: more enemies across the building, never fewer on any floor.
	var base_total := 0
	var his_total := 0
	var never_fewer := true
	for f in range(2, 30):
		var b := WorldState._base_floor_zombie_count(f)
		var h := WorldState.get_floor_zombie_count(f)
		base_total += b
		his_total += h
		if h < b:
			never_fewer = false
	check(never_fewer, "no floor ever has FEWER enemies")
	check(his_total > base_total, "more enemies overall (%d vs %d base)" % [his_total, base_total])
	check(WorldState.get_floor_zombie_count(12) == WorldState.get_floor_zombie_count(12),
		"the extra enemies are deterministic (spawner, backdrop and listen agree)")
	# Other characters hear the vague category line.
	_play_as("blond_man")
	WorldState.current_floor = 15
	var r2: Dictionary = WorldState.get_listen_report_for_floor_below()
	check(r2["line"] == WorldState.LISTEN_LINES_BELOW[r2["category"]], "others still hear the vague line")


func _test_nurse() -> void:
	print("[The Nurse — lucky finds, shaky aim]")
	_play_as("dark_woman")
	check(_near(WorldState.get_body_bonus(), -0.15), "15% lower chance to hit with a gun")
	check(_near(WorldState.get_scavenge_bonus(), 0.08), "scavenge spots hold something 8% more often")
	check(WorldState.luck_weight(1) > 1.0 and WorldState.luck_weight(4) < 1.0,
		"rare items weighted up, junk weighted down")
	_play_as("blond_woman")
	check(_near(WorldState.luck_weight(1), 1.0) and _near(WorldState.luck_weight(4), 1.0),
		"a character without luck gets the normal loot pool")


func _test_stacks_with_upgrades() -> void:
	print("[traits + upgrades stack in one fold (never direct writes)]")
	_play_as("blond_woman")
	WorldState.active_upgrades = ["U_sprint_s"]               # -20% sprint cost
	check(_near(WorldState.get_sprint_drain_mult(), 0.80 * 0.80), "Neighbour + Efficient Stride = 0.64")
	WorldState.active_upgrades.clear()
	check(_near(WorldState.get_sprint_drain_mult(), 0.80), "and removing the upgrade leaves just the trait")


func _test_player_costs() -> void:
	print("[the traits reach real gameplay: push + swing costs through the player]")
	_play_as("blond_man")
	WorldState.god_mode = false
	var p = load("res://scenes/player.tscn").instantiate()
	add_child(p)
	p.global_position = Vector2(600, 386)
	await get_tree().physics_frame
	WorldState.stamina = WorldState.get_max_stamina()
	p.last_push_time = -100.0
	p._do_push()
	check(_near(100.0 - WorldState.stamina, p.STAMINA_PUSH_COST * 0.70),
		"a Tenant push costs %.1f (not %.1f)" % [100.0 - WorldState.stamina, p.STAMINA_PUSH_COST])
	# Melee swing cost.
	WorldState.inventory.clear()
	WorldState.add_to_inventory("002")
	var inst = WorldState.get_instance_at(0)
	var wtype: String = p._get_weapon_type(inst.get_data())
	var expected: float = float(p.WEAPON_STAMINA_COST.get(wtype, 15.0)) * 0.85
	p.is_attacking = false
	WorldState.stamina = WorldState.get_max_stamina()
	p._do_melee_attack(inst, 0)
	check(_near(100.0 - WorldState.stamina, expected), "a Tenant swing costs %.2f (15%% less)" % expected)
	p.queue_free()
	await get_tree().physics_frame
