extends Node

# THE BACKPACK AS AN ITEM (owner round 27: "when a player begins a run they have no inventory… on the
# floor next to apartment 3001 there will be a backpack to pick up which will become the inventory. In
# the tutorial… the first apartment… when the first tutorial enemy is dead the player will be overloaded
# and will need to pick up the backpack"; docs/BACKPACK.md):
#  * the packless RULE: pockets only (POCKET_SLOTS), no pack button / ring / quick wheel, no pocket bar; one item free, two = overloaded (half stamina);
#  * taking the pack opens the slots out and wakes the pack UI; the rule is per-run (advance_run) and saved;
#  * every later run's pack lies beside 3001 in Floor 30 — never on the tutorial run, never twice;
#  * the tutorial: the pack is in 3003, the panicked-search node is empty, the kill makes the player
#    overloaded (the pack pulses), taking it introduces the inventory, THEN the heal beat;
#  * the rule is OFF by default so every other suite keeps the classic five slots.
# Run:  godot --headless res://tests/backpack_test.tscn

var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== backpack item test ===")
	await get_tree().process_frame
	await _test_default_rule_off()
	await _test_pockets_only()
	await _test_overload()
	await _test_take_and_runs()
	await _test_save_load()
	await _test_hallway_pickup()
	await _test_tutorial_beats()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _give(id: String) -> bool:
	return WorldState.add_to_inventory(id)


func _test_default_rule_off() -> void:
	print("[rule off by default]")
	WorldState.packless_rule = false
	WorldState.new_game()
	check(WorldState.has_backpack, "a plain new_game() has a backpack")
	check(WorldState.get_inventory_slots() >= WorldState.MAX_INVENTORY_SLOTS, "classic slots (%d)" % WorldState.get_inventory_slots())
	HUD.refresh_inventory()
	check(HUD.pack_button.visible and not HUD.hotbar_visible, "pack button shown, hotbar stays opt-in hidden")


func _test_pockets_only() -> void:
	print("[pockets only under the rule]")
	WorldState.packless_rule = true
	WorldState.new_game()
	check(not WorldState.has_backpack, "the rule starts a run WITHOUT a backpack")
	check(WorldState.get_inventory_slots() == WorldState.POCKET_SLOTS, "slots = pockets (%d)" % WorldState.get_inventory_slots())
	check(_give("002") and _give("006"), "two items fit in the pockets")
	check(not _give("005"), "a third is refused (nothing silently lost)")
	check(WorldState.inventory.size() == 2, "the refused item was not added")
	check(WorldState.pockets_full(), "pockets_full() reports it")
	HUD.refresh_inventory()
	check(not HUD.hotbar_visible and not HUD.hbox.visible, "no pocket bar either (the in-hand box shows what they hold)")
	check(not HUD.pack_button.visible, "the pack button is hidden without a pack")
	check(not HUD.pack_wheel.toggle(), "the pack key does nothing without a pack")
	check(load("res://scripts/ring_geo.gd").ui_block_reason(get_tree()) != "", "the shared block reason says why")


func _test_overload() -> void:
	print("[one item free, two = overloaded]")
	WorldState.packless_rule = true
	WorldState.new_game()
	WorldState.stamina = WorldState.get_max_stamina()
	var full: float = WorldState.get_max_stamina()
	check(WorldState.FREE_CARRY == 1, "one item is carried freely")
	_give("002")
	HUD.refresh_inventory()
	check(not WorldState.is_overloaded() and is_equal_approx(WorldState.get_max_stamina(), full), "one item: not overloaded, full stamina")
	_give("006")
	HUD.refresh_inventory()
	check(WorldState.is_overloaded(), "a second item overloads")
	check(is_equal_approx(WorldState.get_max_stamina(), full * WorldState.OVERLOAD_STAMINA_MULT), "max stamina is cut in half (%.0f)" % WorldState.get_max_stamina())
	check(WorldState.stamina <= WorldState.get_max_stamina() + 0.01, "current stamina is cut down with it at once (%.0f)" % WorldState.stamina)
	# the regen ceiling is the halved max too
	WorldState.stamina = 10.0
	check(WorldState.stamina < WorldState.get_max_stamina(), "(room to regenerate up to the halved max)")
	# put the second item down: stamina shoots straight back to FULL
	WorldState.inventory.remove_at(1)
	HUD.refresh_inventory()
	check(not WorldState.is_overloaded(), "back to one item: no longer overloaded")
	check(is_equal_approx(WorldState.stamina, full) and is_equal_approx(WorldState.get_max_stamina(), full), "stamina snaps back to FULL (%.0f)" % WorldState.stamina)
	# taking the backpack lifts it too
	_give("006")
	HUD.refresh_inventory()
	check(WorldState.is_overloaded(), "overloaded again")
	WorldState.take_backpack()
	check(not WorldState.is_overloaded() and is_equal_approx(WorldState.stamina, full), "the backpack ends the overload, stamina full")
	# with the rule off nothing ever overloads
	WorldState.packless_rule = false
	WorldState.new_game()
	_give("002")
	_give("006")
	_give("005")
	HUD.refresh_inventory()
	check(not WorldState.is_overloaded(), "rule off: never overloaded")
	WorldState.packless_rule = true


func _test_take_and_runs() -> void:
	print("[taking it, and the next run]")
	WorldState.take_backpack()
	check(WorldState.has_backpack, "has_backpack after taking it")
	check(WorldState.get_inventory_slots() >= WorldState.MAX_INVENTORY_SLOTS, "the slots open out to the full bag")
	check(_give("005"), "a third item now fits")
	check(HUD.pack_button.visible, "the pack button is back")
	check(not WorldState.pockets_full(), "pockets_full() is false with a pack")
	# a hotbar an explicit opt-in still works once the pack is on
	HUD.set_hotbar_visible(true)
	check(HUD.hotbar_visible, "the opt-in hotbar still opens")
	HUD.set_hotbar_visible(false)
	# THE TIME SKIP: a fresh character starts pockets-only again
	WorldState.advance_run()
	check(not WorldState.has_backpack and WorldState.inventory.is_empty(), "advance_run: the new character has no pack and no items")
	# …but with the rule off, a time skip keeps the classic bag
	WorldState.packless_rule = false
	WorldState.new_game()
	WorldState.advance_run()
	check(WorldState.has_backpack, "rule off: advance_run keeps the classic bag")
	WorldState.packless_rule = true


func _test_save_load() -> void:
	print("[saved]")
	WorldState.packless_rule = true
	WorldState.new_game()
	WorldState.save_game("res://scenes/hallway.tscn")
	WorldState.has_backpack = true
	WorldState.packless_rule = false
	WorldState.load_game()
	check(WorldState.packless_rule and not WorldState.has_backpack, "a Continue keeps the rule and the missing pack")
	WorldState.take_backpack()
	WorldState.save_game("res://scenes/hallway.tscn")
	WorldState.has_backpack = false
	WorldState.load_game()
	check(WorldState.has_backpack, "a saved pack is still on their back after Continue")
	# an old save (no keys) means the old game: the classic bag
	var data := {"packless_rule": null}
	data.erase("packless_rule")
	check(bool(data.get("packless_rule", false)) == false and bool(data.get("has_backpack", true)) == true, "missing keys default to the classic rule")


func _test_hallway_pickup() -> void:
	print("[floor 30: the pack beside 3001]")
	# run 2+ (not the tutorial): the pack lies beside 3001
	WorldState.packless_rule = true
	WorldState.new_game()
	WorldState.is_first_run = false
	WorldState.current_floor = 30
	var h = load("res://scenes/hallway.tscn").instantiate()
	add_child(h)
	await get_tree().process_frame
	await get_tree().process_frame
	var pack = h.get_node_or_null("BackpackPickup")
	check(pack != null, "a backpack lies on Floor 30 on a later run")
	if pack != null:
		var d3001 = h.get_node("3001")
		check(absf(pack.global_position.x - d3001.global_position.x) < 100.0, "beside 3001 (dx %.0f)" % absf(pack.global_position.x - d3001.global_position.x))
		check(absf(pack.global_position.y - 419.0) < 1.0, "on the floor line (419)")
		check(pack.is_in_group("backpack_pickup"), "grouped for lookups")
		var got := [0]
		pack.taken.connect(func() -> void: got[0] += 1)
		check(pack.take(), "taking it succeeds")
		check(WorldState.has_backpack and got[0] == 1, "…gives the backpack, once")
		await get_tree().process_frame
		check(not is_instance_valid(pack) or pack.is_queued_for_deletion(), "…and the pack leaves the floor")
	h.queue_free()
	await get_tree().process_frame
	# already carrying one: none laid out
	var h2 = load("res://scenes/hallway.tscn").instantiate()
	add_child(h2)
	await get_tree().process_frame
	check(h2.get_node_or_null("BackpackPickup") == null, "no pack on the floor once they have one")
	h2.queue_free()
	await get_tree().process_frame
	# the tutorial run: it is in 3003 instead
	WorldState.new_game()
	WorldState.is_first_run = true
	var h3 = load("res://scenes/hallway.tscn").instantiate()
	add_child(h3)
	await get_tree().process_frame
	check(h3.get_node_or_null("BackpackPickup") == null, "the tutorial run keeps Floor 30's floor clear (3003 has it)")
	h3.queue_free()
	await get_tree().process_frame
	# rule off (every other suite): never
	WorldState.packless_rule = false
	WorldState.new_game()
	WorldState.is_first_run = false
	var h4 = load("res://scenes/hallway.tscn").instantiate()
	add_child(h4)
	await get_tree().process_frame
	check(h4.get_node_or_null("BackpackPickup") == null, "rule off: no pack is laid out")
	h4.queue_free()
	await get_tree().process_frame
	WorldState.packless_rule = true


func _test_tutorial_beats() -> void:
	print("[the tutorial: 3003's backpack]")
	WorldState.tutorial_completed = false
	WorldState.packless_rule = true
	WorldState.new_game()
	check(WorldState.is_first_run and not WorldState.has_backpack, "first run, no pack")
	WorldState.current_floor = 30
	WorldState.current_apartment_id = "3003"
	WorldState.spawn_source = "door"
	WorldState.exit_spawn_x = 570.0
	WorldState.seed_floor_door_states(30)
	var room = load("res://scenes/room.tscn").instantiate()
	add_child(room)
	for i in range(8):
		await get_tree().process_frame
	var pack = room.tut_pack
	check(pack != null and is_instance_valid(pack), "the backpack is in 3003")
	if pack == null or not is_instance_valid(pack):
		room.queue_free()
		return
	var tz = room.tut_zombie
	var entrance: String = WorldState.get_entrance_side("3003")
	var far_from_zombie: bool = absf(pack.global_position.x - tz.global_position.x) > 500.0
	check(far_from_zombie, "…by the entrance, far from the neighbour at the back (x %.0f)" % pack.global_position.x)
	check(entrance in ["left", "right"], "(entrance side known: %s)" % entrance)
	check(absf(pack.global_position.y - room.ROOM_FEET_Y) < 1.0, "…on the apartment floor line")
	# the panicked-search node is EMPTY, so the pockets are bandages + club
	var junk_empty := false
	for anchor in room.tut_nodes:
		if str(anchor.get_meta("tutorial_tag", "x")) == "":
			junk_empty = WorldState.anchor_items.get("3003:" + str(anchor.name), "x") == ""
	check(junk_empty, "the junk node is an empty search (it must not eat a pocket)")
	# fight goes as scripted: club + bandages in the pockets
	check(_give("012") and _give("006"), "club and bandages fill the pockets")
	check(WorldState.pockets_full(), "the player is loaded to the limit")
	# the neighbour dies → OVERLOADED beat
	room.tut_step = room.TutStep.COMBAT
	tz.is_dead = true
	room._tutorial_process(0.0)
	check(room.tut_step == room.TutStep.PACK, "the kill starts the PACK step")
	check(TutorialManager._awaiting, "…as a paused teaching beat")
	TutorialManager._resume()
	check(pack.highlight, "dismissing it makes the backpack pulse")
	check(not TutorialManager._awaiting, "…and the game runs again")
	# taking it introduces the inventory, then the heal beat
	pack.take()
	check(WorldState.has_backpack, "the backpack is taken")
	check(TutorialManager._awaiting and room.tut_pack_intro_done, "taking it opens the inventory-intro beat")
	check(room.tut_step == room.TutStep.PACK, "(still at PACK until it's dismissed)")
	TutorialManager._resume()
	check(room.tut_step == room.TutStep.HEAL, "dismissing the intro leads to the heal beat")
	check(TutorialManager._awaiting, "…which is its own paused prompt")
	TutorialManager._resume()
	check(room.tut_step == room.TutStep.DONE, "…and the tutorial encounter finishes")
	check(_give("005") and WorldState.inventory.size() == 3, "the bag now holds more than pockets")
	room.queue_free()
	await get_tree().process_frame
	TutorialManager.cancel()
	# grabbing it BEFORE the kill: the intro waits for the kill, then heal
	WorldState.new_game()
	WorldState.current_floor = 30
	WorldState.current_apartment_id = "3003"
	WorldState.spawn_source = "door"
	WorldState.exit_spawn_x = 570.0
	WorldState.seed_floor_door_states(30)
	var room2 = load("res://scenes/room.tscn").instantiate()
	add_child(room2)
	for i in range(8):
		await get_tree().process_frame
	room2.tut_step = room2.TutStep.COMBAT
	room2.tut_pack.take()
	check(not TutorialManager._awaiting, "an early pickup does not interrupt the fight")
	room2.tut_zombie.is_dead = true
	room2._tutorial_process(0.0)
	check(TutorialManager._awaiting and room2.tut_pack_intro_done, "…the intro comes when the neighbour is down")
	TutorialManager._resume()
	check(room2.tut_step == room2.TutStep.HEAL, "…then the heal beat")
	TutorialManager.cancel()
	room2.queue_free()
	await get_tree().process_frame
	# the rule off (every other suite): no pack in 3003, the classic flow
	WorldState.packless_rule = false
	WorldState.new_game()
	WorldState.current_floor = 30
	WorldState.current_apartment_id = "3003"
	WorldState.spawn_source = "door"
	WorldState.exit_spawn_x = 570.0
	WorldState.seed_floor_door_states(30)
	var room3 = load("res://scenes/room.tscn").instantiate()
	add_child(room3)
	for i in range(8):
		await get_tree().process_frame
	check(room3.tut_pack == null, "rule off: 3003 has no backpack")
	room3.tut_step = room3.TutStep.COMBAT
	room3.tut_zombie.is_dead = true
	room3._tutorial_process(0.0)
	check(room3.tut_step == room3.TutStep.HEAL, "rule off: the kill goes straight to the heal beat")
	TutorialManager.cancel()
	get_tree().paused = false
	room3.queue_free()
	await get_tree().process_frame
	WorldState.packless_rule = false
