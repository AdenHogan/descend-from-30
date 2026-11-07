extends Node

# Floor 15 is both a MERCHANT floor (the lift at x 1029.5) and a MAINTENANCE floor (the staff door at x 929). Their reaches overlap
# for ~35 px, and ONE [interact] press there used to take both: the shop opened while the player was walked off into the
# maintenance room (found by the descent bot, round 44 — it looked like a bot "stuck" until traced). Where they overlap the NEARER
# one answers the press, and exactly one does. The same overlap exists on EVERY maintenance floor once the elevator is powered (the lift's
# [E] Ride reaches 80 px each side of x 1029.5, the staff door's zone out to ~990): a bot on floor 3 boarded the lift when it pressed
# [E] at the staff door.
# A third overlap (round 49n, found by the descent bot as two 150 s "timeouts" on floor 25): the previous character's BODY lies near the lift,
# and one [interact] press opened the shop AND knelt the player over the body's two rings (merchant.gd and player_corpse.gd each answered it).
# Where they overlap the NEARER one answers, the body winning a tie, and exactly one does.
# Round 49n, part 2 (owner: "fix the other interact overlaps too"): the pairwise fixes above were instances of ONE rule — of everything that would answer the
# press, the nearest does and exactly one does (scripts/interact_arbiter.gd). `_test_one_rule_for_the_rest` pins the rule itself (stubs: nearest, ties, readiness, once
# a frame) and the pairs nobody had hit yet on real nodes (a body + a loose drop, + a corridor body, + the floor-30 backpack, + the lobby door), and scans every script
# that reads the press so a NEW answerer cannot join without the rule.
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
	await _test_powered_lift_overlap()
	await _test_body_beside_the_lift()
	await _test_body_beside_the_powered_lift()
	await _test_body_beside_a_door()
	await _test_one_rule_for_the_rest()
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
	check(not md._other_is_nearer() and merchant._maintenance_door_is_nearer(p), "x 950, both in reach: the door answers, the lift yields")
	p.global_position = Vector2(1000.0, p.global_position.y)
	check(md._other_is_nearer() and not merchant._maintenance_door_is_nearer(p), "x 1000, both in reach: the lift answers, the door yields")
	p.global_position = Vector2(979.0, p.global_position.y)
	check(md._other_is_nearer() != merchant._maintenance_door_is_nearer(p) or (not md._other_is_nearer() and merchant._maintenance_door_is_nearer(p)),
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
	check(not md._other_is_nearer(), "at the staff door alone, nothing stands in its way")


func _test_powered_lift_overlap() -> void:
	print("[a maintenance floor with a POWERED lift]")
	# the floor the first test built is still in the tree: free it, so the player the test moves is THIS floor's own (each world is measured from its own player)
	for child in get_children():
		child.queue_free()
	for i in range(4):
		await get_tree().physics_frame
	WorldState.dev_seed = 424242
	WorldState.new_game()
	WorldState.dev_seed = 0
	WorldState.is_first_run = false
	WorldState.tutorial_completed = true
	WorldState.current_floor = 21               # a maintenance floor (3,6,…,27) that is not a merchant floor
	WorldState.spawn_source = "stair"
	WorldState.stair_spawn_side = WorldState.canonical_stair_arrival_side(21)
	WorldState.stair_direction = "down"
	WorldState.god_mode = true
	WorldState.elevator_fuses_loaded = WorldState.ELEVATOR_FUSES_NEEDED
	WorldState.elevator_powered = true
	var bf = load("res://scenes/building_floors.tscn").instantiate()
	add_child(bf)
	for i in range(40):
		await get_tree().physics_frame
	var p = get_tree().get_first_node_in_group("player")
	var md = bf.get_node_or_null("MaintenanceDoor")
	check(p != null and md != null and WorldState.can_ride_elevator(), "floor 21 has the player, the staff door and a powered, rideable lift")
	if p == null or md == null:
		return
	md.player_nearby = true
	p.global_position = Vector2(960.0, p.global_position.y)
	check(bf.lift_answers_press(p), "x 960 is inside the lift's reach too")
	check(not md._other_is_nearer() and bf._maintenance_door_is_nearer(p), "x 960, both in reach: the staff door answers, the lift yields")
	p.global_position = Vector2(1000.0, p.global_position.y)
	check(md._other_is_nearer() and not bf._maintenance_door_is_nearer(p), "x 1000, both in reach: the lift answers, the staff door yields")
	# (A real press near the lift would start the boarding and a scene change; the rule is asked directly.)
	p.global_position = Vector2(929.0, p.global_position.y)
	check(not md._other_is_nearer(), "at the staff door itself nothing stands in its way")
	md.player_nearby = false
	p.global_position = Vector2(1040.0, p.global_position.y)
	check(bf.lift_answers_press(p) and not bf._maintenance_door_is_nearer(p), "at the lift alone the lift answers")


## The previous character's body (key "1") on floor 25 at x 1000, and the merchant's lift at x 1029.5: the merchant reaches 60 px, the body 30.
func _body_press(p: Node, merchant: Node, x: float) -> Dictionary:
	p.global_position = Vector2(x, p.global_position.y)
	for i in range(6):
		await get_tree().physics_frame
	var corpse = null
	for c in get_tree().get_nodes_in_group("player_corpse"):
		corpse = c
	var both: bool = corpse != null and corpse.player_nearby and merchant.player_nearby
	WorldState.interaction_handled = false
	if merchant.shop_ui != null and merchant.shop_ui.visible:
		merchant.shop_ui.close()
	Input.action_press("interact")
	await get_tree().physics_frame
	await get_tree().process_frame
	Input.action_release("interact")
	for i in range(12):
		await get_tree().physics_frame
	await get_tree().process_frame
	return {"both": both, "near_body": corpse != null and corpse.player_nearby, "near_shop": merchant.player_nearby,
		"shop": merchant.shop_ui != null and merchant.shop_ui.visible, "body": HUD.body_ring != null and HUD.body_ring.key != "", "phase": String(p.pack_phase)}


func _put_away(p: Node, merchant: Node) -> void:
	if merchant.shop_ui != null and merchant.shop_ui.visible:
		merchant.shop_ui.close()
	if p.pack_phase != "":
		p.end_pack(true)
	HUD.body_ring.close()
	p.is_cutscene = false
	WorldState.interaction_handled = false
	for i in range(3):
		await get_tree().physics_frame


func _test_body_beside_the_lift() -> void:
	print("[the last character's body beside the merchant's lift]")
	# the floors the earlier tests built are still in the tree: a second "player" group member would be the one asked for
	for child in get_children():
		child.queue_free()
	for i in range(4):
		await get_tree().physics_frame
	# a seed whose floor 25 does not burn in run 2 (a burning floor keeps the merchant behind his doors)
	var seed_used: int = 424242
	for k in range(60):
		WorldState.dev_seed = 424242 + k
		WorldState.new_game()
		WorldState.current_run = 2
		if WorldState.fire_intensity(25) <= 0 and WorldState.fire_intensity(24) <= 0 and WorldState.fire_intensity(26) <= 0:
			seed_used = 424242 + k
			break
	WorldState.dev_seed = 0
	WorldState.is_first_run = false
	WorldState.tutorial_completed = true
	WorldState.current_floor = 25
	WorldState.current_run = 2
	WorldState.has_backpack = true
	WorldState.wallet_unlocked = true
	WorldState.spawn_source = "stair"
	WorldState.stair_spawn_side = WorldState.canonical_stair_arrival_side(25)
	WorldState.stair_direction = "down"
	WorldState.god_mode = true
	SettingsManager.last_device = "kbm"
	var inst := ItemInstance.new()
	inst.setup("002")
	WorldState.player_corpses.clear()
	WorldState.player_corpses["1"] = {"floor": 25, "scene": "res://scenes/building_floors.tscn", "apartment_id": "", "x": 1000.0, "y": 419.0, "feet": true,
		"notes": 0, "scrap": 0, "items": [WorldState.instance_to_dict(inst)]}
	var bf = load("res://scenes/building_floors.tscn").instantiate()
	add_child(bf)
	for i in range(40):
		await get_tree().physics_frame
	var p = get_tree().get_first_node_in_group("player")
	var merchant = null
	for n in bf.get_children():
		if n.has_method("_open_shop"):
			merchant = n
	var corpse = null
	for c in get_tree().get_nodes_in_group("player_corpse"):
		corpse = c
	check(p != null and merchant != null and corpse != null, "floor 25 has the player (%s), the merchant (%s) and the last character's body (%s)" % [str(p != null), str(merchant != null), str(corpse != null)])
	if p == null or merchant == null or corpse == null:
		return
	for z in get_tree().get_nodes_in_group("zombie"):
		if is_instance_valid(z):
			z.queue_free()
	check(absf(corpse.global_position.x - 1000.0) < 1.0 and absf(merchant.global_position.x - 1029.5) < 1.0, "the body is at x 1000 and the lift at x 1029.5")
	# on the body: the body is nearer than the lift
	var r1: Dictionary = await _body_press(p, merchant, 1002.0)
	check(r1["both"], "x 1002: both the body's reach and the merchant's hold the player (body %s, merchant %s)" % [str(r1["near_body"]), str(r1["near_shop"])])
	check(r1["body"] and not r1["shop"] and r1["phase"] != "", "x 1002, [interact]: ONLY the body answers - they kneel over it (shop %s, rings %s, pack %s)" % [str(r1["shop"]), str(r1["body"]), r1["phase"]])
	await _put_away(p, merchant)
	# at the lift: the lift is nearer than the body
	var r2: Dictionary = await _body_press(p, merchant, 1028.0)
	check(r2["both"], "x 1028: both reaches hold the player")
	check(r2["shop"] and not r2["body"] and r2["phase"] == "", "x 1028, [interact]: ONLY the shop answers - they are not knelt over the body (shop %s, rings %s, pack %s)" % [str(r2["shop"]), str(r2["body"]), r2["phase"]])
	await _put_away(p, merchant)
	# each alone, where it always worked
	var r3: Dictionary = await _body_press(p, merchant, 1060.0)
	check(r3["shop"] and not r3["near_body"] and not r3["body"], "at the lift alone (x 1060), the shop opens and the body is left")
	await _put_away(p, merchant)
	var r4: Dictionary = await _body_press(p, merchant, 975.0)
	check(r4["body"] and not r4["shop"] and r4["near_body"], "at the body alone (x 975, merchant in reach: %s), the rings open and the shop stays shut" % str(r4["near_shop"]))
	await _put_away(p, merchant)


## The same press on a maintenance floor whose lift is powered: the lift's own [E] Ride (building_floors.gd) and the body.
func _test_body_beside_the_powered_lift() -> void:
	print("[the last character's body beside a POWERED lift]")
	for child in get_children():
		child.queue_free()
	for i in range(4):
		await get_tree().physics_frame
	WorldState.dev_seed = 424242
	WorldState.new_game()
	WorldState.dev_seed = 0
	WorldState.is_first_run = false
	WorldState.tutorial_completed = true
	WorldState.current_floor = 21
	WorldState.current_run = 2
	WorldState.has_backpack = true
	WorldState.wallet_unlocked = true
	WorldState.spawn_source = "stair"
	WorldState.stair_spawn_side = WorldState.canonical_stair_arrival_side(21)
	WorldState.stair_direction = "down"
	WorldState.god_mode = true
	WorldState.elevator_fuses_loaded = WorldState.ELEVATOR_FUSES_NEEDED
	WorldState.elevator_powered = true
	SettingsManager.last_device = "kbm"
	var inst := ItemInstance.new()
	inst.setup("002")
	WorldState.player_corpses.clear()
	WorldState.player_corpses["1"] = {"floor": 21, "scene": "res://scenes/building_floors.tscn", "apartment_id": "", "x": 1000.0, "y": 419.0, "feet": true,
		"notes": 0, "scrap": 0, "items": [WorldState.instance_to_dict(inst)]}
	var bf = load("res://scenes/building_floors.tscn").instantiate()
	add_child(bf)
	for i in range(40):
		await get_tree().physics_frame
	var p = get_tree().get_first_node_in_group("player")
	var corpse = null
	for c in get_tree().get_nodes_in_group("player_corpse"):
		corpse = c
	check(p != null and corpse != null and WorldState.can_ride_elevator(), "floor 21 has the player, the body and a powered, rideable lift")
	if p == null or corpse == null:
		return
	for z in get_tree().get_nodes_in_group("zombie"):
		if is_instance_valid(z):
			z.queue_free()
	p.global_position = Vector2(1002.0, p.global_position.y)
	for i in range(8):
		await get_tree().physics_frame
	check(corpse.player_nearby and bf.lift_answers_press(p), "x 1002: the body's reach and the lift's [E] Ride both hold the player")
	check(not corpse._other_is_nearer() and bf._maintenance_door_is_nearer(p), "…and at x 1002 the body is the nearer of the two: it answers, the lift yields")
	WorldState.interaction_handled = false
	Input.action_press("interact")
	await get_tree().physics_frame
	await get_tree().process_frame
	Input.action_release("interact")
	for i in range(12):
		await get_tree().physics_frame
	check(not bool(bf.get("_elevator_boarding")) and HUD.body_ring.key != "" and p.pack_phase != "",
		"x 1002, [interact]: ONLY the body answers - the lift is not boarded (boarding %s, rings %s, pack %s)" % [str(bf.get("_elevator_boarding")), str(HUD.body_ring.key != ""), String(p.pack_phase)])
	# (a real press at x 1028 would board the lift and change scene, so that half is asked of the rule directly)
	p.global_position = Vector2(1028.0, p.global_position.y)
	for i in range(8):
		await get_tree().physics_frame
	check(corpse.player_nearby and corpse._other_is_nearer() and not bf._maintenance_door_is_nearer(p), "x 1028, body still in reach: the lift is the nearer, so the body yields")
	if p.pack_phase != "":
		p.end_pack(true)
	HUD.body_ring.close()


## A body beside an ordinary flat door: pressing [interact] there used to ENTER the flat and credit the body's notes in the same press.
func _test_body_beside_a_door() -> void:
	print("[the last character's body beside a flat door]")
	for child in get_children():
		child.queue_free()
	for i in range(4):
		await get_tree().physics_frame
	WorldState.dev_seed = 424242
	WorldState.new_game()
	WorldState.dev_seed = 0
	WorldState.is_first_run = false
	WorldState.tutorial_completed = true
	WorldState.current_floor = 20
	WorldState.current_run = 2
	WorldState.has_backpack = true
	WorldState.wallet_unlocked = true
	WorldState.wallet_balance = 0
	WorldState.spawn_source = "stair"
	WorldState.stair_spawn_side = WorldState.canonical_stair_arrival_side(20)
	WorldState.stair_direction = "down"
	WorldState.god_mode = true
	SettingsManager.last_device = "kbm"
	var inst := ItemInstance.new()
	inst.setup("002")
	WorldState.player_corpses.clear()
	WorldState.player_corpses["1"] = {"floor": 20, "scene": "res://scenes/building_floors.tscn", "apartment_id": "", "x": 700.0, "y": 419.0, "feet": true,
		"notes": 40, "scrap": 0, "items": [WorldState.instance_to_dict(inst)]}
	var bf = load("res://scenes/building_floors.tscn").instantiate()
	add_child(bf)
	for i in range(40):
		await get_tree().physics_frame
	var p = get_tree().get_first_node_in_group("player")
	var corpse = null
	for c in get_tree().get_nodes_in_group("player_corpse"):
		corpse = c
	var door = null
	for n in bf.get_children():
		if n.get("apartment_id") != null and n is Area2D and absf(n.global_position.x - 696.0) < 5.0:
			door = n
	check(p != null and corpse != null and door != null, "floor 20 has the player, the body and the door at x 696")
	if p == null or corpse == null or door == null:
		return
	for z in get_tree().get_nodes_in_group("zombie"):
		if is_instance_valid(z):
			z.queue_free()
	door.current_state = WorldState.DoorState.OPEN
	# the door is nearer than the body: the rule, asked directly (a real press would walk the player into the flat)
	p.global_position = Vector2(690.0, p.global_position.y)
	for i in range(8):
		await get_tree().physics_frame
	check(door.player_nearby and corpse.player_nearby, "x 690: the door's reach and the body's both hold the player")
	check(not door._other_is_nearer() and corpse._other_is_nearer(), "x 690 (door 6 px, body 10 px): the door answers, the body yields")
	# the body is nearer than the door: a real press
	p.global_position = Vector2(703.0, p.global_position.y)
	for i in range(8):
		await get_tree().physics_frame
	check(door._other_is_nearer() and not corpse._other_is_nearer(), "x 703 (body 3 px, door 7 px): the body answers, the door yields")
	WorldState.current_apartment_id = ""
	WorldState.interaction_handled = false
	Input.action_press("interact")
	await get_tree().physics_frame
	await get_tree().process_frame
	Input.action_release("interact")
	for i in range(12):
		await get_tree().physics_frame
	check(WorldState.current_apartment_id == "" and not p.is_cutscene, "x 703, [interact]: the flat is NOT entered (flat '%s')" % WorldState.current_apartment_id)
	check(HUD.body_ring.key != "" and p.pack_phase != "" and WorldState.wallet_balance == 40, "…and the body's rings are open, its notes credited once (rings %s, pack %s, wallet %d)" % [str(HUD.body_ring.key != ""), String(p.pack_phase), WorldState.wallet_balance])
	if p.pack_phase != "":
		p.end_pack(true)
	HUD.body_ring.close()


# ---------------------------------------------------------------------------------------------------------------------------------------------------------------
# THE ONE RULE (scripts/interact_arbiter.gd) — and the pairs the pairwise fixes never reached
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------

## A member with a settable reach, for the rule's own tests.
class Stub extends Node2D:
	var ready_now: bool = true
	var x: float = 0.0
	var rank: int = InteractArbiter.RANK_THING

	func interact_ready() -> bool:
		return ready_now

	func interact_x() -> float:
		return x

	func interact_rank() -> int:
		return rank


func _stub(x: float, rank: int = InteractArbiter.RANK_THING) -> Stub:
	var s := Stub.new()
	s.x = x
	s.rank = rank
	s.add_to_group(InteractArbiter.GROUP)
	add_child(s)
	return s


## The last character's body at `x` with a hammer and 40 notes on it, as a live node (a body searched down to nothing frees itself).
func _fresh_body(bf: Node, x: float, inst: ItemInstance) -> Node:
	for c in get_tree().get_nodes_in_group("player_corpse"):
		if is_instance_valid(c):
			c.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	WorldState.player_corpses.clear()
	WorldState.player_corpses["1"] = {"floor": 20, "scene": "res://scenes/building_floors.tscn", "apartment_id": "", "x": x, "y": 419.0, "feet": true,
		"notes": 40, "scrap": 0, "items": [WorldState.instance_to_dict(inst)]}
	WorldState.spawn_player_corpse_into(bf, 20, bf.scene_file_path, "")
	var found: Node = null
	for c in get_tree().get_nodes_in_group("player_corpse"):
		if is_instance_valid(c) and not c.is_queued_for_deletion():
			found = c
	return found


func _press_once() -> void:
	WorldState.interaction_handled = false
	Input.action_press("interact")
	await get_tree().physics_frame
	await get_tree().process_frame
	Input.action_release("interact")
	for i in range(10):
		await get_tree().physics_frame


func _test_one_rule_for_the_rest() -> void:
	print("[one rule: the nearest thing that would answer [interact] answers, and exactly one does]")
	for child in get_children():
		child.queue_free()
	for i in range(4):
		await get_tree().physics_frame
	WorldState.loot_open = false
	# ---- the rule itself, on stubs and a stand-in player
	var fake := Node2D.new()
	fake.add_to_group("player")
	add_child(fake)
	fake.global_position = Vector2(100.0, 0.0)
	var near := _stub(110.0)                                   # 10 px
	var far := _stub(150.0)                                    # 50 px
	check(InteractArbiter.answers(near) and not InteractArbiter.answers(far), "the nearer of two ready members answers; the other does not")
	check(InteractArbiter.beaten(far) and not InteractArbiter.beaten(near), "…and `beaten` says the same from the other side")
	fake.global_position = Vector2(145.0, 0.0)
	check(InteractArbiter.answers(far) and not InteractArbiter.answers(near), "walk across and the answer follows the player (far 5 px, near 35 px)")
	far.ready_now = false
	check(InteractArbiter.answers(near) and not InteractArbiter.answers(far), "a member that would not take a press (not ready) never blocks one that would")
	far.ready_now = true
	# ties: a survivor's Talk, then a body, then a door, then a lift, then the rest
	near.queue_free()
	far.queue_free()
	await get_tree().process_frame
	fake.global_position = Vector2(200.0, 0.0)
	var order: Array = [InteractArbiter.RANK_LIFT, InteractArbiter.RANK_DOOR, InteractArbiter.RANK_THING, InteractArbiter.RANK_TALK, InteractArbiter.RANK_BODY]
	var tied: Array = []
	for r in order:
		tied.append(_stub(210.0, r))                           # all 10 px away
	var winner: Stub = null
	for s in tied:
		if InteractArbiter.answers(s):
			check(winner == null, "exactly one of five equally-near members answers")
			winner = s
	check(winner != null and winner.rank == InteractArbiter.RANK_TALK, "…and a tie goes to [Talk], then a body, then a door, then a lift, then the rest (rank %s won)" % (str(winner.rank) if winner != null else "none"))
	# once a frame: the winner that frees itself mid-frame does not hand the same press to the next node
	var took_a: bool = InteractArbiter.take(winner)
	winner.ready_now = false                                   # (it was picked up / spent)
	var took_b := false
	for s in tied:
		if s != winner and InteractArbiter.take(s):
			took_b = true
	check(took_a and not took_b, "one press is answered ONCE a frame: the next node processed does not also take it after the winner spent itself")
	await get_tree().process_frame
	var next_frame := false
	for s in tied:
		if s != winner and InteractArbiter.take(s):
			next_frame = true
			break
	check(next_frame, "…and the next frame's press is answered again")
	# a modal loot panel owns the press
	WorldState.loot_open = true
	var any_answers := false
	for s in tied:
		if InteractArbiter.answers(s):
			any_answers = true
	WorldState.loot_open = false
	check(not any_answers, "while the loot panel is open nothing behind it answers the press")
	for s in tied:
		s.queue_free()
	fake.queue_free()
	await get_tree().process_frame

	# ---- real nodes: the last character's body in the corridor beside each other thing that answers
	WorldState.dev_seed = 424242
	WorldState.new_game()
	WorldState.dev_seed = 0
	WorldState.is_first_run = false
	WorldState.tutorial_completed = true
	WorldState.current_floor = 20
	WorldState.current_run = 2
	WorldState.has_backpack = false
	WorldState.wallet_unlocked = true
	WorldState.wallet_balance = 0
	WorldState.spawn_source = "stair"
	WorldState.stair_spawn_side = WorldState.canonical_stair_arrival_side(20)
	WorldState.stair_direction = "down"
	WorldState.god_mode = true
	SettingsManager.last_device = "kbm"
	var bf = load("res://scenes/building_floors.tscn").instantiate()
	add_child(bf)
	for i in range(40):
		await get_tree().physics_frame
	var p = get_tree().get_first_node_in_group("player")
	for z in get_tree().get_nodes_in_group("zombie"):
		if is_instance_valid(z):
			z.queue_free()
	check(p != null, "a corridor with a player (floor 20)")
	if p == null:
		return
	var body_x := 760.0                                        # clear of every door (126 px apart) so only the pair under test is in reach
	var inst := ItemInstance.new()
	inst.setup("002")
	WorldState.player_corpses.clear()
	WorldState.player_corpses["1"] = {"floor": 20, "scene": "res://scenes/building_floors.tscn", "apartment_id": "", "x": body_x, "y": 419.0, "feet": true,
		"notes": 40, "scrap": 0, "items": [WorldState.instance_to_dict(inst)]}
	WorldState.spawn_player_corpse_into(bf, 20, bf.scene_file_path, "")
	var corpse = null
	for c in get_tree().get_nodes_in_group("player_corpse"):
		corpse = c
	check(corpse != null, "the last character's body lies in the corridor")
	if corpse == null:
		return
	# (1) a loose drop beside it
	var drop = load("res://scenes/world_drop.tscn").instantiate()
	drop.item_id = "005"
	bf.add_child(drop)
	drop.global_position = Vector2(body_x + 14.0, 412.0)
	WorldState.inventory.clear()
	p.global_position = Vector2(body_x + 1.0, p.global_position.y)
	for i in range(10):
		await get_tree().physics_frame
	check(corpse.player_nearby and drop.player_nearby, "x +1: the body's reach and the drop's both hold the player")
	await _press_once()
	check(WorldState.wallet_balance == 40 and WorldState.inventory.size() == 1 and WorldState.inventory[0].item_id == "002" and is_instance_valid(drop) and not drop.is_queued_for_deletion(),
		"x +1 (body 1 px, drop 13 px), [interact]: ONLY the body answers - its things come to the pockets, the drop stays on the floor (inv %d, notes %d)" % [WorldState.inventory.size(), WorldState.wallet_balance])
	corpse = await _fresh_body(bf, body_x, inst)
	WorldState.inventory.clear()
	WorldState.wallet_balance = 0
	p.global_position = Vector2(body_x + 14.0, p.global_position.y)
	for i in range(10):
		await get_tree().physics_frame
	await _press_once()
	check(WorldState.inventory.size() == 1 and WorldState.inventory[0].item_id == "005" and WorldState.wallet_balance == 0 and WorldState.player_corpses.has("1"),
		"x +14 (drop at the player, body 14 px), [interact]: ONLY the drop answers - the body is left alone (inv %d, notes %d)" % [WorldState.inventory.size(), WorldState.wallet_balance])
	# (2) a searchable body of a stranger beside it
	WorldState.inventory.clear()
	WorldState.wallet_balance = 0
	corpse = await _fresh_body(bf, body_x, inst)
	var cb = load("res://scripts/corridor_body.gd").new()
	cb.floor_num = 20
	cb.body_name = "cdead_9"
	bf.add_child(cb)
	cb.global_position = Vector2(body_x + 30.0, 419.0)
	p.global_position = Vector2(body_x + 28.0, p.global_position.y)
	for i in range(10):
		await get_tree().physics_frame
	check(cb.player_nearby and corpse.player_nearby, "x +28: the stranger's body and the fallen character's both hold the player")
	await _press_once()
	check(cb.is_searched() and WorldState.wallet_balance == 0 and WorldState.player_corpses.has("1"),
		"x +28 (stranger 2 px, fallen 28 px), [interact]: ONLY the stranger is searched - the fallen character's things stay (searched %s, notes %d)" % [str(cb.is_searched()), WorldState.wallet_balance])
	# …and the other way round: the player stands at the fallen character, the stranger 28 px off
	WorldState.inventory.clear()
	WorldState.wallet_balance = 0
	corpse = await _fresh_body(bf, body_x, inst)
	cb.queue_free()
	await get_tree().process_frame
	cb = load("res://scripts/corridor_body.gd").new()
	cb.floor_num = 20
	cb.body_name = "cdead_10"
	bf.add_child(cb)
	cb.global_position = Vector2(body_x + 30.0, 419.0)
	p.global_position = Vector2(body_x + 2.0, p.global_position.y)
	for i in range(10):
		await get_tree().physics_frame
	check(cb.player_nearby and corpse.player_nearby, "x +2: the stranger's body and the fallen character's both hold the player")
	await _press_once()
	check(not cb.is_searched() and WorldState.wallet_balance == 40,
		"x +2 (fallen 2 px, stranger 28 px), [interact]: ONLY the fallen character's body answers - the stranger is left unsearched (searched %s, notes %d)" % [str(cb.is_searched()), WorldState.wallet_balance])
	# (3) the floor-30 backpack beside it (no pack yet: the body's things come to the pockets)
	WorldState.inventory.clear()
	WorldState.wallet_balance = 0
	corpse = await _fresh_body(bf, body_x, inst)
	WorldState.has_backpack = false
	var pack = load("res://scripts/backpack_pickup.gd").new()
	bf.add_child(pack)
	pack.global_position = Vector2(body_x - 18.0, 419.0)
	p.global_position = Vector2(body_x - 3.0, p.global_position.y)
	for i in range(10):
		await get_tree().physics_frame
	check(pack.player_nearby and corpse.player_nearby, "x -3: the backpack and the body both hold the player")
	await _press_once()
	check(WorldState.has_backpack == false and WorldState.wallet_balance == 40 and is_instance_valid(pack) and not pack.is_queued_for_deletion(),
		"x -3 (body 3 px, pack 15 px), [interact]: ONLY the body answers - the backpack stays on the floor (pack %s, notes %d)" % [str(WorldState.has_backpack), WorldState.wallet_balance])
	corpse = await _fresh_body(bf, body_x, inst)
	WorldState.wallet_balance = 0
	WorldState.inventory.clear()
	p.global_position = Vector2(body_x - 17.0, p.global_position.y)
	for i in range(10):
		await get_tree().physics_frame
	await _press_once()
	check(WorldState.has_backpack and WorldState.wallet_balance == 0 and WorldState.player_corpses.has("1"),
		"x -17 (pack 1 px, body 17 px), [interact]: ONLY the backpack answers - the body is left alone (pack %s, notes %d)" % [str(WorldState.has_backpack), WorldState.wallet_balance])
	# (4) the lobby door: it cannot be walked up to in a corridor, so its readiness is forced (right before each ask - its own _process clears it) and the rule asked
	# (a real press would leave the building)
	corpse = await _fresh_body(bf, body_x, inst)
	var le = load("res://scripts/lobby_exit.gd").new()
	bf.add_child(le)
	le.global_position = Vector2(body_x + 34.0, 419.0)
	p.global_position = Vector2(body_x + 2.0, p.global_position.y)
	for i in range(8):
		await get_tree().physics_frame
	le._player_near = true
	check(corpse.player_nearby and le.interact_ready() and InteractArbiter.beaten(le) and not InteractArbiter.beaten(corpse),
		"the lobby door with a body nearer (body 2 px, door 32 px): the body answers, the way out yields")
	p.global_position = Vector2(body_x + 33.0, p.global_position.y)
	for i in range(8):
		await get_tree().physics_frame
	le._player_near = true
	check(corpse.player_nearby and le.interact_ready() and not InteractArbiter.beaten(le) and InteractArbiter.beaten(corpse),
		"…and with the player AT the door (door 1 px, body 33 px) the way out answers, the body yields")
	le.queue_free()
	cb.queue_free()
	pack.queue_free()

	# ---- the lint: every script that reads the press must ask the rule (or say why it need not)
	var allowed: Dictionary = {
		"player.gd": "it only CANCELS things (a listen, the pack) on the press - it answers nothing",
		"hud.gd": "it only closes its own context menu on the press",
		"loot_ui.gd": "the loot panel is modal: its own take-key; the arbiter holds every other answerer back while it is open (loot_open)",
		"resident_npc.gd": "a trader's [Trade] offer is a modal bubble - NOT arbitrated (listed in docs/BUG_LEDGER.md as read, not fixed)",
	}
	var offenders: Array = []
	var seen: int = 0
	var dir := DirAccess.open("res://scripts")
	for f in dir.get_files():
		if not f.ends_with(".gd"):
			continue
		var src := FileAccess.get_file_as_string("res://scripts/" + f)
		if src.find("is_action_just_pressed(\"interact\")") == -1 and src.find("is_action_pressed(\"interact\")") == -1:
			continue
		seen += 1
		if src.find("InteractArbiter.take(") == -1 and src.find("InteractArbiter.answers(") == -1 and not allowed.has(f):
			offenders.append(f)
	check(offenders.is_empty() and seen >= 12, "every script that answers the [interact] press asks InteractArbiter, or is listed with a reason (%d read; not: %s)" % [seen, str(offenders)])
	WorldState.has_backpack = true
	bf.queue_free()
