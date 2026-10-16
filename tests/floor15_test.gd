extends Node

# Floor 15 is both a MERCHANT floor (the lift at x 1029.5) and a MAINTENANCE floor (the staff door at x 929). Their reaches overlap
# for ~35 px, and ONE [interact] press there used to take both: the shop opened while the player was walked off into the
# maintenance room (found by the descent bot, round 44 — it looked like a bot "stuck" until traced). Where they overlap the NEARER
# one answers the press, and exactly one does.
# Run:  godot --headless res://tests/floor15_test.tscn

var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== floor 15: merchant + maintenance door ===")
	await _test_overlap()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _press_at(p: Node, md: Node, merchant: Node, x: float, force_both: bool) -> Dictionary:
	# put the player at x, make the world say what it said in the bot's run (both reaches hold the player — the physics overlap of
	# two Area2Ds a few px apart), press [interact] for one frame, and see who answered
	p.global_position = Vector2(x, p.global_position.y)
	for i in range(6):
		await get_tree().physics_frame
	if force_both:
		md.player_nearby = true
		merchant.player_nearby = true
	var both: bool = md.player_nearby and merchant.player_nearby
	WorldState.interaction_handled = false
	WorldState.current_apartment_id = ""
	if merchant.shop_ui != null and merchant.shop_ui.visible:
		merchant.shop_ui.close()
	Input.action_press("interact")
	await get_tree().physics_frame
	await get_tree().process_frame
	Input.action_release("interact")
	var door_took: bool = WorldState.current_apartment_id == "MAINT15"
	var shop_took: bool = merchant.shop_ui != null and merchant.shop_ui.visible
	return {"both": both, "door": door_took, "shop": shop_took}


func _reset(p: Node, merchant: Node) -> void:
	if merchant.shop_ui != null and merchant.shop_ui.visible:
		merchant.shop_ui.close()
	p.is_cutscene = false
	WorldState.interaction_handled = false


func _test_overlap() -> void:
	WorldState.dev_seed = 424242
	WorldState.new_game()
	WorldState.dev_seed = 0
	WorldState.is_first_run = false
	WorldState.tutorial_completed = true
	WorldState.current_floor = 15
	WorldState.spawn_source = "stair"
	WorldState.stair_spawn_side = WorldState.canonical_stair_arrival_side(15)
	WorldState.stair_direction = "down"
	WorldState.god_mode = true
	var bf = load("res://scenes/building_floors.tscn").instantiate()
	add_child(bf)
	for i in range(40):
		await get_tree().physics_frame
	var p = get_tree().get_first_node_in_group("player")
	var md = bf.get_node_or_null("MaintenanceDoor")
	var merchant = null
	for n in bf.get_children():
		if n.has_method("_open_shop"):
			merchant = n
	check(p != null and md != null and merchant != null, "floor 15 has the player, the maintenance door and the merchant")
	if p == null or md == null or merchant == null:
		return
	check(absf(md.global_position.x - 929.0) < 1.0 and absf(merchant.global_position.x - 1029.5) < 1.0, "the door is at x 929 and the lift at x 1029.5")
	# BOTH reaches hold the player. Near the staff door the door must answer and the shop must stay shut; near the lift the opposite.
	# (A press at the DOOR would start the real walk-in and scene change, so that half is asked of the two rules directly.)
	p.global_position = Vector2(950.0, p.global_position.y)
	md.player_nearby = true
	merchant.player_nearby = true
	check(not md._merchant_is_nearer() and merchant._maintenance_door_is_nearer(p), "x 950, both in reach: the door answers, the lift yields")
	p.global_position = Vector2(1000.0, p.global_position.y)
	check(md._merchant_is_nearer() and not merchant._maintenance_door_is_nearer(p), "x 1000, both in reach: the lift answers, the door yields")
	p.global_position = Vector2(979.0, p.global_position.y)
	check(md._merchant_is_nearer() != merchant._maintenance_door_is_nearer(p) or (not md._merchant_is_nearer() and merchant._maintenance_door_is_nearer(p)),
		"x 979 (about halfway): exactly one of them answers")
	# the real press near the lift: the shop opens, and the door does NOT start walking the player into the maintenance room
	var r2: Dictionary = await _press_at(p, md, merchant, 1000.0, true)
	check(r2["both"] and r2["shop"] and not r2["door"], "x 1000, both in reach, [interact]: ONLY the shop answers (door %s, shop %s)" % [str(r2["door"]), str(r2["shop"])])
	check(not p.is_cutscene, "…and the player is not walked off towards the door")
	_reset(p, merchant)
	# each still works alone, where it always did
	md.player_nearby = false
	var r3: Dictionary = await _press_at(p, md, merchant, 1040.0, false)
	check(r3["shop"] and not r3["door"], "at the lift alone, the shop opens and the door stays shut")
	_reset(p, merchant)
	merchant.player_nearby = false
	md.player_nearby = true
	p.global_position = Vector2(925.0, p.global_position.y)
	check(not md._merchant_is_nearer(), "at the staff door alone, nothing stands in its way")
