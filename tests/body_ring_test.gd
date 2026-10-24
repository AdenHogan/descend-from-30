extends Node

# LOOTING A BODY ON TWO RINGS (owner round 48i: "corpse recovery with two inventory rings side by side, drag items across, Arc Raiders style"; docs/BACKPACK.md
# "Looting a body"; scripts/body_ring.gd). The body's contents live in WorldState.player_corpses; the ring is a view of them and every move is ONE WorldState call that
# happens whole or not at all. Checked here:
#  * the state moves (take one / take all / lay one on the body): whole or nothing, full state kept, a spent body clears its record, save → load;
#  * on the REAL player in a REAL corridor: searching kneels them and opens the two rings side by side; a click, a drag onto the pack and the middle take; a drag from the
#    pack lays an item on the body; a hit slams both shut; Esc closes both; interact again never "takes everything"; a body emptied on the ring is gone from the world;
#  * a player with only pockets, or a pad in hand, keeps the old take-everything-that-fits.
# Run:  godot --headless res://tests/body_ring_test.tscn

var failures: int = 0
var bf: Node = null
var p: Node = null
const KEY := "1"


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== body ring test ===")
	await get_tree().process_frame
	_test_state()
	await _setup()
	await _test_rings()
	await _test_exits()
	await _test_fallbacks()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame


func _give(id: String, n: int = 1) -> ItemInstance:
	var inst := ItemInstance.new()
	inst.setup(id)
	inst.count = n
	WorldState.inventory.append(inst)
	return inst


## A body with a hammer (worn), a gun with 3 rounds, three bandages, a can; 40 notes and 12 scrap.
func _body(items: Array = ["002", "004", "006", "005"], notes: int = 40, scrap: int = 12) -> void:
	WorldState.player_corpses.clear()
	var recs: Array = []
	for id in items:
		var inst := ItemInstance.new()
		inst.setup(String(id))
		if String(id) == "002":
			inst.current_durability = 3
		if String(id) == "004":
			inst.mag_count = 3
		recs.append(WorldState.instance_to_dict(inst))
	WorldState.player_corpses[KEY] = {"floor": 15, "scene": "res://scenes/building_floors.tscn", "apartment_id": "", "x": 600.0, "y": 419.0, "feet": true,
		"notes": notes, "scrap": scrap, "items": recs}


func _test_state() -> void:
	print("[the body's contents: take one, take all, lay one down]")
	WorldState.new_game()
	WorldState.wallet_unlocked = true
	WorldState.wallet_balance = 0
	WorldState.scrap = 0
	_body()
	var v: Dictionary = WorldState.loot_body_valuables(KEY)
	check(int(v["notes"]) == 40 and WorldState.wallet_balance == 40 and int(v["scrap"]) == 12 and WorldState.scrap == 12, "notes go to the wallet and scrap to the counter at once")
	check(int(WorldState.player_corpses[KEY]["notes"]) == 0 and int(WorldState.player_corpses[KEY]["scrap"]) == 0, "…and leave the body")
	check(WorldState.body_items(KEY).size() == 4, "four items still on the body")
	var r: Dictionary = WorldState.take_body_item(KEY, 0)
	check(bool(r["ok"]) and WorldState.inventory.size() == 1 and WorldState.inventory[0].item_id == "002" and WorldState.inventory[0].current_durability == 3, "taking the hammer keeps its wear (3 uses left)")
	check(WorldState.body_items(KEY).size() == 3, "…and it is off the body")
	var g: Dictionary = WorldState.take_body_item(KEY, 0)
	check(bool(g["ok"]) and WorldState.inventory[1].item_id == "004" and WorldState.inventory[1].mag_count == 3, "the gun keeps its rounds (3 in the magazine)")
	# a full pack refuses the rest whole, and says why
	while WorldState.inventory.size() < WorldState.get_inventory_slots():
		_give("001")
	var full: Dictionary = WorldState.take_body_item(KEY, 0)
	check(not bool(full["ok"]) and String(full["why"]) == "Your pack is full." and WorldState.body_items(KEY).size() == 2, "a full pack refuses it whole; it stays on the body (2 left)")
	# lay one down: an item goes to the body with its full state
	var held: ItemInstance = WorldState.inventory[0]
	var nm: String = held.get_display_name()
	var put: Dictionary = WorldState.put_body_item(KEY, 0)
	check(bool(put["ok"]) and WorldState.body_items(KEY).size() == 3 and WorldState.inventory.size() == WorldState.get_inventory_slots() - 1, "laying the hammer on the body moves it (%s)" % nm)
	check(int(WorldState.body_items(KEY)[2]["current_durability"]) == 3, "…with its wear")
	var took: Dictionary = WorldState.take_body_item(KEY, 2)
	check(bool(took["ok"]) and WorldState.inventory[WorldState.inventory.size() - 1].current_durability == 3, "…and it comes back as it was")
	# the body is capped
	var cap: int = WorldState.MAX_BODY_ITEMS
	while WorldState.body_items(KEY).size() < cap:
		WorldState.player_corpses[KEY]["items"].append(WorldState.instance_to_dict(_make("001")))
	WorldState.inventory.clear()
	_give("005")
	var over: Dictionary = WorldState.put_body_item(KEY, 0)
	check(not bool(over["ok"]) and WorldState.inventory.size() == 1, "a body holds only %d things: the ninth is refused and stays in the pack" % cap)
	# take everything that fits, then the body is gone
	WorldState.inventory.clear()
	var s: Dictionary = WorldState.take_body_all(KEY)
	check(int(s["items_taken"]) > 0 and (WorldState.player_corpses.has(KEY) == (int(s["items_left"]) > 0)), "take-all clears the record exactly when nothing is left")
	WorldState.player_corpses.clear()
	_body(["005"], 0, 0)
	WorldState.inventory.clear()
	WorldState.take_body_item(KEY, 0)
	check(not WorldState.player_corpses.has(KEY), "taking the last thing leaves nothing: the record is gone")
	# save → load: what is left is what was left
	WorldState.new_game()
	_body()
	WorldState.take_body_item(KEY, 1)
	WorldState.save_game("res://scenes/hallway.tscn", false)
	WorldState.player_corpses.clear()
	WorldState.load_game()
	check(WorldState.body_items(KEY).size() == 3 and WorldState.body_items(KEY)[0]["item_id"] == "002", "a save keeps what is still on the body")
	WorldState.delete_save()
	WorldState.new_game()


func _make(id: String) -> ItemInstance:
	var inst := ItemInstance.new()
	inst.setup(id)
	return inst


func _setup() -> void:
	WorldState.new_game()
	WorldState.current_floor = 15
	WorldState.spawn_source = "stair"
	WorldState.stair_direction = "down"
	WorldState.has_backpack = true
	WorldState.wallet_unlocked = true
	bf = load("res://scenes/building_floors.tscn").instantiate()
	add_child(bf)
	await _frames(40)
	p = get_tree().get_first_node_in_group("player")
	_clear_the_dead()
	WorldState.god_mode = false


func _clear_the_dead() -> void:
	for z in get_tree().get_nodes_in_group("zombie"):
		if is_instance_valid(z):
			z.queue_free()


func _reset() -> void:
	_clear_the_dead()
	if p.pack_phase != "":
		p.end_pack(true)
	HUD.body_ring.close()
	p.is_hit = false
	p.is_dead = false
	p.is_dying = false
	p.is_cutscene = false
	p.health_state = 0
	WorldState.player_health = 0
	WorldState.has_backpack = true
	SettingsManager.last_device = "kbm"
	HUD.selected_slot = -1
	WorldState.inventory.clear()
	HUD.refresh_inventory()
	await _frames(2)


func _search() -> void:
	check(HUD.body_ring.begin(KEY), "searching the body starts (the player kneels)")
	await _frames(int(ceil(p.PACK_KNEEL_TIME * 60.0)) + 6)
	await get_tree().process_frame
	await get_tree().process_frame


func _click(pos: Vector2, button: int = MOUSE_BUTTON_LEFT) -> void:
	var wpos: Vector2 = get_viewport().get_final_transform() * pos
	var mv := InputEventMouseMotion.new()
	mv.position = wpos
	get_viewport().push_input(mv)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = true
	ev.position = wpos
	get_viewport().push_input(ev)
	var up := InputEventMouseButton.new()
	up.button_index = button
	up.pressed = false
	up.position = wpos
	get_viewport().push_input(up)
	await get_tree().process_frame


func _drag(from: Vector2, to: Vector2) -> void:
	var ft: Transform2D = get_viewport().get_final_transform()
	for step in [[from, true], [from.lerp(to, 0.3), false], [to, false]]:
		var mv := InputEventMouseMotion.new()
		mv.position = ft * step[0]
		get_viewport().push_input(mv)
		if step[1]:
			var dn := InputEventMouseButton.new()
			dn.button_index = MOUSE_BUTTON_LEFT
			dn.pressed = true
			dn.position = ft * from
			get_viewport().push_input(dn)
		await get_tree().process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = ft * to
	get_viewport().push_input(up)
	await get_tree().process_frame


func _body_pos(k: int) -> Vector2:
	var br = HUD.body_ring
	return br.RingGeo.slot_position(br.centre, k, br._slots, br.PW.RING_R)


func _pack_pos(k: int) -> Vector2:
	var pw = HUD.pack_wheel
	return pw.RingGeo.slot_position(pw.centre, k, pw.slots.size(), pw.RING_R)


func _test_rings() -> void:
	print("[the two rings, side by side, on the real player]")
	await _reset()
	WorldState.wallet_balance = 0
	_body()
	var br = HUD.body_ring
	var pw = HUD.pack_wheel
	check(br != null and not br.is_open, "the HUD has a body ring, closed to start with")
	await _search()
	check(p.pack_phase == "open" and pw.is_open and br.is_open and br.visible, "kneeling opens the pack AND the body's ring")
	check(br.centre.x < pw.centre.x and absf(br.centre.y - pw.centre.y) < 0.5, "the body's ring is to the LEFT of the pack's, level with it (%.0f / %.0f)" % [br.centre.x, pw.centre.x])
	var gap: float = pw.centre.x - br.centre.x - 2.0 * (pw.RING_R + pw.DISC_SEL * 0.5 + 6.0)
	check(gap > -2.0, "…and they do not overlap (clear by %.0f px)" % gap)
	var half: float = pw.RING_R + pw.DISC_SEL * 0.5 + 6.0
	check(br.centre.x - half >= -1.0 and pw.centre.x + half <= HUD.SCREEN_W + 1.0, "…both on screen")
	check(br._slots >= 4 and br.inst_at(0) != null and br.inst_at(0).item_id == "002", "the ring shows what is on the body: the hammer is wedge 0")
	check(HUD.pointer_over_widget(br.centre) and HUD.pointer_over_widget(pw.centre), "a pointer on either ring is a HUD widget (the world never sees the click)")
	# click = take
	await _click(_body_pos(0))
	check(WorldState.inventory.size() == 1 and WorldState.inventory[0].item_id == "002" and WorldState.inventory[0].current_durability == 3, "a click on the hammer takes it, worn as it was")
	check(WorldState.body_items(KEY).size() == 3 and br.inst_at(0).item_id == "004", "…and the ring closes up (the gun is wedge 0 now)")
	check(p.pack_phase == "open", "…without the pack closing")
	# drag onto the pack ring = take
	await _drag(_body_pos(0), pw.centre + Vector2(0, -60))
	check(WorldState.inventory.size() == 2 and WorldState.inventory[1].item_id == "004" and WorldState.inventory[1].mag_count == 3, "dragging the gun onto the pack ring takes it (3 rounds in it)")
	# a drag let go anywhere else leaves it on the body
	var before: int = WorldState.body_items(KEY).size()
	await _drag(_body_pos(0), Vector2(120, 80))
	check(WorldState.body_items(KEY).size() == before and WorldState.inventory.size() == 2, "a drag let go in the open takes nothing (it never drops a body's things on the floor)")
	# lay one down: drag from the pack onto the body ring
	var held_before: int = WorldState.inventory.size()
	await _drag(_pack_pos(0), br.centre + Vector2(0, -70))
	check(WorldState.inventory.size() == held_before - 1 and WorldState.body_items(KEY).size() == before + 1, "dragging a pack item onto the body's ring lays it on them")
	check(String(WorldState.body_items(KEY)[before]["item_id"]) == "002", "…the hammer, with its wear (%d)" % int(WorldState.body_items(KEY)[before]["current_durability"]))
	# the middle takes everything that fits; a full pack leaves the rest
	await _click(br.centre)
	check(WorldState.body_items(KEY).is_empty() or WorldState.inventory.size() == WorldState.get_inventory_slots(), "the middle takes everything that fits")
	# interact again is never 'take it all'
	p.end_pack(true)
	await _frames(4)
	await _reset()
	_body()
	await _search()
	var corpse = load("res://scripts/player_corpse.gd").new()
	corpse.corpse_key = KEY
	add_child(corpse)
	corpse._recover()
	check(WorldState.inventory.is_empty() and WorldState.body_items(KEY).size() == 4, "interact again while searching takes nothing")
	corpse.queue_free()
	# an emptied body is gone from the world
	await _reset()
	_body(["005"], 0, 0)
	var c2 = load("res://scripts/player_corpse.gd").new()
	c2.corpse_key = KEY
	c2.global_position = p.global_position
	bf.add_child(c2)
	await _search()
	await _click(_body_pos(0))
	await _frames(3)
	check(not WorldState.player_corpses.has(KEY) and not is_instance_valid(c2) or c2.is_queued_for_deletion(), "taking the last thing spends the body: its record is gone and its node frees itself")
	check(not br.is_open, "…and the ring goes with it")
	await _reset()


func _test_exits() -> void:
	print("[every way out leaves nothing open and nothing lost]")
	await _reset()
	_body()
	var br = HUD.body_ring
	await _search()
	check(br.is_open, "(setup) both rings open")
	p.receive_hit()
	await _frames(3)
	check(p.pack_phase == "" and not br.is_open and not HUD.pack_wheel.is_open, "a hit slams the pack shut: both rings are gone")
	check(WorldState.body_items(KEY).size() == 4, "…and the body is as it was (nothing lost, nothing duplicated)")
	await _reset()
	_body()
	await _search()
	var ev := InputEventAction.new()
	ev.action = "ui_cancel"
	ev.pressed = true
	get_viewport().push_input(ev)
	await _frames(int(ceil(p.PACK_STAND_TIME * 60.0)) + 8)
	check(p.pack_phase == "" and not br.is_open, "Esc stands them up and closes both rings")
	await _reset()
	_body()
	await _search()
	p.is_dying = true
	await _frames(3)
	check(not br.is_open, "death takes the ring away too")
	p.is_dying = false
	await _reset()
	# the ring never outlives its body: wiping the record closes it
	_body()
	await _search()
	WorldState.player_corpses.clear()
	await _frames(3)
	check(not br.is_open and br.key == "", "a body that is gone closes its ring")
	await _reset()


func _test_fallbacks() -> void:
	print("[no ring to read it with: the old take-everything-that-fits]")
	await _reset()
	_body()
	WorldState.has_backpack = false
	var corpse = load("res://scripts/player_corpse.gd").new()
	corpse.corpse_key = KEY
	add_child(corpse)
	corpse._recover()
	check(not HUD.body_ring.is_open and p.pack_phase == "" and WorldState.inventory.size() >= 1, "a player with only pockets takes what fits at once")
	corpse.queue_free()
	await _reset()
	_body()
	SettingsManager.last_device = "pad"
	check(not HUD.body_ring.begin(KEY) and p.pack_phase == "", "with a pad in hand there is no ring to open (the old path)")
	SettingsManager.last_device = "kbm"
	await _reset()
