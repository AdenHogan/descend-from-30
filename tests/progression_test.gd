extends Node

# PROGRESSION tiers 2 + 3 (docs/PROGRESSION.md):
#  - RUN BOONS: the first arrival at a milestone floor (27/22/17/12/7) owes this character a
#    pick-1-of-2 boon — offered by a HUD badge, never forced; it lasts until the time skip.
#  - LEGACY: a character's end banks Legacy to the PROFILE (1/floor descended, +10 escaped),
#    spent on ranked perks that apply forever. All through the one stat fold.
# Run: godot --headless res://tests/progression_test.tscn

var failures: int = 0
var _saved_points := 0
var _saved_ranks := {}
var _saved_slot := 1


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== progression test (run boons + legacy) ===")
	_saved_slot = WorldState.active_slot
	_saved_points = WorldState.legacy_points
	_saved_ranks = WorldState.legacy_ranks.duplicate()
	WorldState.legacy_points = 0
	WorldState.legacy_ranks = {}
	_test_milestones()
	_test_boon_offer_and_fold()
	_test_boons_are_per_character()
	_test_legacy_earn()
	_test_legacy_spend_and_fold()
	await _test_boon_ui()
	await _test_legacy_ui()
	_test_journal_line()
	# Leave the profile exactly as we found it — no test purchases leak into real play / other suites.
	WorldState.use_slot(_saved_slot)
	WorldState.legacy_points = _saved_points
	WorldState.legacy_ranks = _saved_ranks
	WorldState.save_profile()
	get_tree().paused = false
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _test_milestones() -> void:
	print("[the first arrival at a milestone floor owes a boon — offered, not forced]")
	WorldState.new_game()
	var root := Node.new()
	add_child(root)
	WorldState.note_floor_arrival(root, 28)
	check(WorldState.pending_boon_floors.is_empty(), "an ordinary floor owes nothing")
	WorldState.note_floor_arrival(root, 27)
	check(WorldState.pending_boon_floors == [27], "floor 27 (a milestone) owes a boon")
	check(HUD.boon_badge.visible, "the HUD badge shows it's waiting")
	check(not get_tree().paused, "…and nothing paused the game on arrival")
	WorldState.note_floor_arrival(root, 27)
	check(WorldState.pending_boon_floors == [27], "coming back to 27 doesn't owe a second one")
	for f in Progression.BOON_MILESTONES:
		check(not (f in WorldState.MERCHANT_FLOORS), "milestone %d isn't a merchant floor" % f)
	root.queue_free()


func _test_boon_offer_and_fold() -> void:
	print("[pick one of two; it lifts the stats through the fold]")
	WorldState.new_game()
	WorldState.note_boon_milestone(22)
	var offer: Array = WorldState.boon_offer(22)
	check(offer.size() == 2 and offer[0] != offer[1], "two different boons offered (%s)" % str(offer))
	check(WorldState.boon_offer(22) == offer, "seeded — a reload offers the same pair")
	check(WorldState.take_boon(22, "B_not_offered") != "", "only the offered two can be taken")
	var before := {"speed": WorldState.get_move_speed_mult(), "stam": WorldState.get_max_stamina(),
		"regen": WorldState.get_stamina_regen_mult(), "dmg": WorldState.get_melee_damage_bonus()}
	var pick: String = offer[0]
	check(WorldState.take_boon(22, pick) == "", "taking %s works" % pick)
	check(pick in WorldState.run_boons and WorldState.pending_boon_floors.is_empty(), "it's this character's now; nothing waiting")
	var mods: Dictionary = Progression.boon(pick)["mods"]
	var moved := false
	moved = moved or (mods.has("move_speed") and WorldState.get_move_speed_mult() > before["speed"])
	moved = moved or (mods.has("max_stamina") and WorldState.get_max_stamina() > before["stam"])
	moved = moved or (mods.has("stamina_regen") and WorldState.get_stamina_regen_mult() > before["regen"])
	moved = moved or (mods.has("melee_damage") and WorldState.get_melee_damage_bonus() > before["dmg"])
	moved = moved or not (mods.has("move_speed") or mods.has("max_stamina") or mods.has("stamina_regen") or mods.has("melee_damage"))
	check(moved, "the boon reaches the stat getters")
	WorldState.run_boons = []
	WorldState.run_boons.append("B_adrenaline")
	check(is_equal_approx(WorldState.get_move_speed_mult(), before["speed"] * 1.20), "Adrenaline = ×1.20 move speed")
	WorldState.note_boon_milestone(17)
	check(not ("B_adrenaline" in WorldState.boon_offer(17)), "a boon you have is never offered again this run")
	WorldState.skip_boon(17)
	check(WorldState.pending_boon_floors.is_empty(), "passing clears the offer")


func _test_boons_are_per_character() -> void:
	print("[boons belong to THIS character — the time skip wipes them; a save keeps them]")
	WorldState.new_game()
	WorldState.run_boons = ["B_rage"]
	WorldState.note_boon_milestone(12)
	WorldState.save_game("res://scenes/hallway.tscn", false)
	WorldState.run_boons = []
	WorldState.pending_boon_floors = []
	WorldState.load_game()
	check(WorldState.run_boons == ["B_rage"] and WorldState.pending_boon_floors == [12], "a save keeps boons + a waiting offer")
	WorldState.delete_save()
	WorldState.advance_run()
	check(WorldState.run_boons.is_empty() and WorldState.pending_boon_floors.is_empty() and WorldState.run_milestones_seen.is_empty(),
		"the next character starts with none (and owes milestones afresh)")


func _test_legacy_earn() -> void:
	print("[a character's end banks Legacy to the profile]")
	WorldState.new_game()
	WorldState.legacy_points = 0
	WorldState.note_floor_reached(17)
	check(WorldState.award_run_legacy(false) == 13, "fell having reached 17 → 13 Legacy")
	WorldState.advance_run()
	WorldState.note_floor_reached(0)
	check(WorldState.award_run_legacy(true) == 40, "escaped from the lobby → 30 + 10 = 40")
	check(WorldState.legacy_points == 53, "banked (%d)" % WorldState.legacy_points)
	WorldState.load_profile()
	check(WorldState.legacy_points == 53, "…in the PROFILE (reload reads it back)")
	WorldState.new_game()
	check(WorldState.legacy_points == 53, "a new playthrough keeps it (it's the profile's, not the game's)")


func _test_legacy_spend_and_fold() -> void:
	print("[spend Legacy on ranked perks — they stack, permanently]")
	WorldState.new_game()
	WorldState.legacy_points = 10
	WorldState.legacy_ranks = {}
	var base_stam: float = WorldState.get_max_stamina()
	check(WorldState.buy_legacy_rank("L_conditioning").contains("15"), "rank 1 of Conditioning costs 15")
	WorldState.legacy_points = 40
	check(WorldState.buy_legacy_rank("L_conditioning") == "" and WorldState.legacy_points == 25, "bought rank 1 (25 left)")
	check(WorldState.buy_legacy_rank("L_conditioning") == "" and WorldState.legacy_points == 0, "rank 2 costs 25 (0 left)")
	check(is_equal_approx(WorldState.get_max_stamina(), base_stam + 16.0), "two ranks = +16 max stamina (%.0f)" % WorldState.get_max_stamina())
	WorldState.legacy_points = 999
	WorldState.buy_legacy_rank("L_muscle")
	check(WorldState.buy_legacy_rank("L_muscle") == "Maxed.", "a 1-rank perk maxes out")
	WorldState.load_profile()
	check(WorldState.legacy_rank("L_conditioning") == 2 and WorldState.legacy_rank("L_muscle") == 1, "ranks are saved in the profile")
	WorldState.advance_run()
	check(is_equal_approx(WorldState.get_max_stamina(), base_stam + 16.0), "…and still apply after the time skip")
	var m: Dictionary = Progression.legacy_mods_at("L_recovery", 3)
	check(is_equal_approx(m["stamina_regen"]["mult"], pow(1.08, 3)), "a multiplier rank stacks multiplicatively (1.08³)")
	WorldState.legacy_ranks = {}
	WorldState.legacy_points = 0


func _test_boon_ui() -> void:
	print("[the badge opens the choice; choosing resumes play]")
	WorldState.new_game()
	WorldState.note_boon_milestone(27)
	get_tree().paused = false
	HUD.open_boon_offer()
	var ui = HUD.boon_ui
	check(ui != null and ui.visible and get_tree().paused, "the offer opens and pauses")
	var pick: String = WorldState.boon_offer(27)[1]
	check(ui.choose(pick) == "" and pick in WorldState.run_boons, "choosing takes the boon")
	check(not ui.visible and not get_tree().paused and not HUD.boon_badge.visible, "…closes, resumes play, clears the badge")
	await get_tree().process_frame


func _test_legacy_ui() -> void:
	print("[the profile screen's LEGACY panel]")
	var ps = load("res://scenes/profile_select.tscn").instantiate()
	add_child(ps)
	await get_tree().process_frame
	check(ps.get_node_or_null("Nav/LegacyButton") != null, "the profile screen has a LEGACY button")
	ps.open_legacy()
	WorldState.legacy_points = 20
	var ui = ps.get("_legacy_ui")
	check(ui != null and ui.visible, "it opens the Legacy panel")
	check(ui.buy("L_tread") == "" and WorldState.legacy_rank("L_tread") == 1, "learning a rank from the panel works")
	ui.close()
	get_tree().paused = false
	ps.queue_free()
	WorldState.legacy_ranks = {}
	WorldState.legacy_points = 0
	await get_tree().process_frame


func _test_journal_line() -> void:
	print("[the journal shows this run's boons + the legacy]")
	WorldState.run_boons = ["B_rage"]
	WorldState.legacy_ranks = {"L_eye": 2}
	var txt: String = load("res://scripts/character_panel.gd").progression_bbcode()
	check(txt.contains("Rage") and txt.contains("Knows Where To Look 2"), "listed (%s)" % txt.replace("\n", " "))
	WorldState.run_boons = []
	WorldState.legacy_ranks = {}
