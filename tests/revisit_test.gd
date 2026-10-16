extends Node

# A scavenge node the player searched but did NOT empty (the item was left behind) must still be a live node when the
# apartment is entered again — same run or a later one. `set_script` alone does not start `_process`, and room.gd used to
# skip `set_process(true)` for every node it had a "searched" record for, so a node holding a left item went dark and
# unsearchable for good (found by the descent bot, round 44: tools/bot_run.tscn --loot=all, run 2).
# Run:  godot --headless res://tests/revisit_test.tscn

var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== revisit test ===")
	await _test_left_item_stays_searchable()
	await _test_emptied_node_stays_gone()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _enter(apt: String) -> Node:
	WorldState.current_apartment_id = apt
	WorldState.current_floor = int(apt.substr(0, 2))
	WorldState.spawn_source = ""
	WorldState.god_mode = true
	WorldState.is_scavenge_mode = true
	var room = load("res://scenes/room.tscn").instantiate()
	add_child(room)
	for i in range(60):                     # the room collects its nodes after an await — wait until it has
		await get_tree().physics_frame
		if room.interactables.size() > 0 and i >= 8:
			break
	for i in range(4):
		await get_tree().process_frame
	return room


func _leave(room: Node) -> void:
	room.queue_free()
	for i in range(3):
		await get_tree().process_frame


func _test_left_item_stays_searchable() -> void:
	WorldState.new_game()
	WorldState.master_seed = 4242
	WorldState.is_first_run = false
	WorldState.current_run = 1
	var apt := "2903"
	var room = await _enter(apt)
	var holding: Array = []
	for a in room.interactables:
		if WorldState.get_anchor_item(apt, a.name) != "" and holding.size() < 3:
			holding.append(str(a.name))
	check(holding.size() >= 2, "the flat has nodes holding something (%d)" % holding.size())
	for n in holding:
		WorldState.mark_anchor_searched(apt, n)      # searched, item left on the shelf (what Leave does)
	await _leave(room)
	room = await _enter(apt)
	var live := 0
	for a in room.interactables:
		if str(a.name) in holding:
			if a.is_processing() and a.visible:
				live += 1
	check(live == holding.size(), "every node searched-but-not-emptied is processing and visible again on re-entry (%d of %d)" % [live, holding.size()])
	# …and it really can be searched: stand beside it and press interact
	var p = get_tree().get_first_node_in_group("player")
	var target = null
	for a in room.interactables:
		if str(a.name) in holding and a.back_spot == null:
			target = a
	if target != null and p != null:
		p.global_position = Vector2(target.global_position.x, p.global_position.y)
		for i in range(4):
			await get_tree().process_frame
		check(target.is_in_range, "standing beside it, the left-over node reads as in range")
		WorldState.interaction_handled = false
		target.try_interact()
		check(WorldState.loot_open, "[interact] opens its loot panel again")
		for ui in get_tree().get_nodes_in_group("loot_ui"):
			ui.leave()
	await _leave(room)


func _test_emptied_node_stays_gone() -> void:
	WorldState.new_game()
	WorldState.master_seed = 4242
	WorldState.is_first_run = false
	WorldState.current_run = 1
	var apt := "2903"
	var room = await _enter(apt)
	var emptied := ""
	for a in room.interactables:
		if WorldState.get_anchor_item(apt, a.name) != "":
			emptied = str(a.name)
			break
	check(emptied != "", "there is a node to empty")
	WorldState.mark_anchor_searched(apt, emptied)
	WorldState.clear_anchor_item(apt, emptied)       # taken
	await _leave(room)
	room = await _enter(apt)
	var node = null
	check(room.interactables.size() > 0, "the flat is built again (%d nodes)" % room.interactables.size())
	for a in room.interactables:
		if str(a.name) == emptied:
			node = a
	# an emptied node is hidden and idle (and out of the interactables list or invisible)
	check(node == null or (not node.visible and not node.is_processing()), "an emptied node stays hidden and idle on re-entry")
	await _leave(room)
