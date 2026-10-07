extends Node

# BACK (scavenge) PLANE (owner round 9): nodes set back on furniture (bookshelf, drawers) are only
# searchable by stepping UP to them — W near them, or clicking one — and S steps back down; the
# game never sends you down on its own, and it's not a walking plane.
# Run:  godot --headless res://tests/back_plane_test.tscn

var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== back plane test ===")
	await _test_back_plane()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _room(apt: String) -> Node:
	WorldState.new_game()
	WorldState.master_seed = 4242
	WorldState.is_first_run = false
	WorldState.current_run = 1
	WorldState.current_apartment_id = apt
	WorldState.current_floor = int(apt.substr(0, 2))
	WorldState.spawn_source = ""
	WorldState.god_mode = true
	WorldState.is_scavenge_mode = true
	var room = load("res://scenes/room.tscn").instantiate()
	add_child(room)
	for i in range(8):
		await get_tree().physics_frame
	for z in get_tree().get_nodes_in_group("zombie"):
		if room.is_ancestor_of(z):
			z.free()
	return room


func _spots(room: Node) -> Array:
	var out := []
	for s in get_tree().get_nodes_in_group("back_plane_spot"):
		if room.is_ancestor_of(s):
			out.append(s)
	return out


func _tap(action: String) -> void:
	# A real input event, so "just pressed" is seen by both _process and _physics_process.
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame


func _settle(n: int = 30) -> void:
	for i in range(n):
		await get_tree().physics_frame


func _test_back_plane() -> void:
	# Find a flat (seed 4242) whose living room spawned BOTH bookshelf nodes (one spot, two nodes).
	# The seed is set BEFORE the layout scan — the scan used to read whatever seed the last state
	# left, so the flat (and its living-room variant) changed from run to run.
	WorldState.new_game()
	WorldState.master_seed = 4242
	var room = null
	var spot = null
	for f in range(10, 29):
		for col in range(1, 6):
			var apt := str(f) + "0" + str(col)
			if not "living_room" in WorldState.get_apartment_layout(apt):
				continue
			var r = await _room(apt)
			for s in _spots(r):
				if s.anchors.size() >= 2:
					spot = s
			if spot != null:
				room = r
				break
			r.free()
			await get_tree().process_frame
		if room != null:
			break
	check(room != null and spot != null, "a living room builds a back-plane spot for its set-back nodes")
	if room == null or spot == null:
		return
	print("  (apartment %s, spot of %d node(s))" % [WorldState.current_apartment_id, spot.anchors.size()])
	for a in spot.anchors:
		check(a.get("back_spot") == spot and bool(a.get_meta("back_plane")), "%s belongs to the spot" % a.name)
	var p = room.get_node("Player")
	var lane_y: float = p.global_position.y
	var base_scale: Vector2 = p.animated_sprite.scale
	# From the walking line, right under the furniture: set-back nodes are NOT in reach.
	p.global_position.x = spot.global_position.x
	await _settle(4)
	var any_reach := false
	for a in spot.anchors:
		if a.is_in_range:
			any_reach = true
	check(not any_reach, "from the walking line the set-back nodes are out of reach")
	# The ↑ hint is TUTORIAL-ONLY (owner playtest: clunky in the active game); W works regardless.
	# Checked synchronously so the tutorial flags are only flipped for the one call.
	var keep_scav: bool = WorldState.is_scavenge_mode
	WorldState.is_scavenge_mode = true
	spot._process(0.016)
	check(not spot._arrow.visible, "no ↑ hint over the furniture outside the tutorial")
	var keep_first: bool = WorldState.is_first_run
	var keep_floor: int = WorldState.current_floor
	WorldState.is_first_run = true
	WorldState.current_floor = 30
	spot._process(0.016)
	check(spot._arrow.visible, "the ↑ hint still shows in the tutorial")
	WorldState.is_first_run = keep_first
	WorldState.current_floor = keep_floor
	spot._process(0.016)
	WorldState.is_scavenge_mode = keep_scav
	# W steps up.
	await _tap("move_up")
	await _settle(30)
	check(p.back_spot == spot, "W near the furniture steps the player UP to it")
	check(absf(p.global_position.y - (lane_y - spot.rise)) < 0.5, "…onto the back line (y %.1f, lane %.1f)" % [p.global_position.y, lane_y])
	check(p.animated_sprite.scale.x < base_scale.x, "…drawn a touch smaller (further back)")
	check(absf(p.lane_position().y - lane_y) < 0.5, "a save made up here records the walking line")
	var all_reach := true
	for a in spot.anchors:
		if not a.is_in_range:
			all_reach = false
	check(all_reach, "up here every node of the spot is in reach (%d)" % spot.anchors.size())
	var front_reach := false
	for i in room.interactables:
		if is_instance_valid(i) and i.get("back_spot") == null and i.is_in_range:
			front_reach = true
	check(not front_reach, "…and no walking-line node is")
	# Not a walking plane: A / D don't walk along it — they step you back DOWN (then walk on).
	var x0: float = p.global_position.x
	await _tap("move_left")
	await _settle(30)
	check(p.back_spot == null and absf(p.global_position.y - lane_y) < 0.5 and absf(p.global_position.x - x0) < 12.0,
		"A up here steps DOWN to the walking line, not along the furniture (moved %.1f)" % absf(p.global_position.x - x0))
	p.global_position.x = spot.global_position.x
	await _settle(4)
	await _tap("move_up")
	await _settle(30)
	check(p.back_spot == spot, "…and W steps back up")
	# Search one, close it — still up there (never sent down on its own).
	var loot = room.get_node("LootUI")
	WorldState.interaction_handled = false
	spot.anchors[0].try_interact()
	await _settle(3)
	check(WorldState.loot_open, "E / click searches a node from up here")
	loot._close(false)
	await _settle(10)
	check(p.back_spot == spot, "after the search the player STAYS up (a second node may be there)")
	# S steps down.
	await _tap("move_down")
	await _settle(30)
	check(p.back_spot == null and absf(p.global_position.y - lane_y) < 0.5, "S steps back down to the walking line")
	check(absf(p.animated_sprite.scale.x - base_scale.x) < 0.001, "…full size again")
	# The backpack opens from up here too (owner round 36d: "players might try to access their inventory from anywhere").
	await _tap("move_up")
	await _settle(30)
	check(p.back_spot == spot, "(stepped up again)")
	check(p.pack_blocked_reason() == "", "up at the furniture, nothing blocks the backpack")
	check(p.begin_pack() and p.pack_phase == "kneel", "the backpack kneels from the back plane")
	check(is_instance_valid(p._pack_prop) and absf(p._pack_prop.scale.x) < 1.0 and absf(p._pack_prop.scale.x) > 0.5,
		"…with the bag drawn to the plane's smaller scale (%.2f)" % p._pack_prop.scale.x)
	await _settle(40)
	check(p.pack_phase == "open" and p.back_spot == spot and absf(p.global_position.y - (lane_y - spot.rise)) < 0.5, "…open, and the player has not moved off the plane")
	await _tap("move_down")
	await _settle(70)
	check(p.pack_phase == "" and p.back_spot == spot, "S while kneeling up here stands them up first (still on the plane)")
	await _tap("move_down")
	await _settle(30)
	check(p.back_spot == null and absf(p.global_position.y - lane_y) < 0.5, "…and the next S steps down as ever")
	# Clicking a set-back node from below: walk, step up, search. Start 90px toward the MIDDLE of the
	# flat — a spot near an end wall put the player past it, in the front doorway, and they walked out.
	p.global_position.x = spot.global_position.x + (90.0 if spot.global_position.x < 600.0 else -90.0)
	WorldState.loot_open = false
	await _settle(4)
	var target = spot.anchors[spot.anchors.size() - 1]
	p.set_move_target(target.global_position.x, target)
	var frames := 0
	while frames < 300 and not WorldState.loot_open:
		await get_tree().physics_frame
		frames += 1
	check(p.back_spot == spot and WorldState.loot_open, "clicking a set-back node walks there, steps up and searches it (%d frames)" % frames)
	loot._close(false)
	WorldState.loot_open = false
	await _settle(5)
	# A click on open floor while up: step down first, then walk there.
	var far: float = spot.global_position.x + (120.0 if spot.global_position.x < 600.0 else -120.0)
	p.set_move_target(far)
	frames = 0
	while frames < 300 and absf(p.global_position.x - far) > 9.0:
		await get_tree().physics_frame
		frames += 1
	check(p.back_spot == null and absf(p.global_position.y - lane_y) < 0.5 and absf(p.global_position.x - far) <= 9.0,
		"a click on the floor while up steps down, then walks there (x %.1f → %.1f)" % [p.global_position.x, far])
	await _test_full_inventory_escape(room, spot, lane_y)
	WorldState.god_mode = false
	room.free()


# THE SOFTLOCK (owner playtest): stepped up at the furniture with a FULL inventory, a node shows an
# item — "Inventory full / Drop something first" — and nothing got you out: S was ignored while the
# panel was open, clicks too, and there's no walking up there. Every one of these must now work.
func _test_full_inventory_escape(room: Node, spot: Node, lane_y: float) -> void:
	var p = room.get_node("Player")
	var loot = room.get_node("LootUI")
	WorldState.inventory.clear()
	var guard := 0
	while guard < 20 and WorldState.add_to_inventory("002", 1):
		guard += 1
	check(not WorldState.add_to_inventory("002", 1), "the pockets are full (%d items)" % WorldState.inventory.size())
	var ways := [["S", "move_down"], ["D", "move_right"], ["A", "move_left"], ["a click in the room", ""]]
	for w in ways:
		p.global_position.x = spot.global_position.x
		if p.back_spot == null:
			await _settle(4)
			await _tap("move_up")
			await _settle(30)
		var a = spot.anchors[0]
		loot.open("002", a.name, WorldState.current_apartment_id)
		loot._reveal_item()
		loot._take()
		await _settle(3)
		var stuck: bool = p.back_spot == spot and WorldState.loot_open and loot.name_label.text == "Inventory full"
		check(stuck, "up at the furniture, a full inventory: \"Inventory full\" shows (%s)" % w[0])
		if w[1] != "":
			await _tap(w[1])
		else:
			# (1000, 260) in the game's 1152×648 view — off the centred panel and clear of the HUD corners (top-left is the portrait button now). push_input takes WINDOW
			# coordinates, and the headless window isn't 1152×648, so map it through the stretch transform.
			var at: Vector2 = get_viewport().get_final_transform() * Vector2(1000, 260)
			var mv := InputEventMouseMotion.new()
			mv.position = at
			get_viewport().push_input(mv)
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = true
			ev.position = at
			get_viewport().push_input(ev)
			var up := InputEventMouseButton.new()
			up.button_index = MOUSE_BUTTON_LEFT
			up.position = at
			get_viewport().push_input(up)
		var frames := 0
		while frames < 120 and (p.back_spot != null or p.get("_back_stepping")):
			await get_tree().physics_frame
			frames += 1
		check(not WorldState.loot_open and not loot.visible, "…%s closes the panel" % w[0])
		check(p.back_spot == null and absf(p.global_position.y - lane_y) < 0.5, "…and steps the player back down (%s)" % w[0])
		p._clear_move_target()
		await _settle(4)
	WorldState.inventory.clear()
