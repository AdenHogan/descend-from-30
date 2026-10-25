extends Node

# INVENTORY FLOW (owner round 48h): three small frictions in managing the pack.
#   (1) MEDICAL ITEMS STACK - "let bandages stack in inventory now, up to three. If it's the same med item, it can stack. That's fair. Not weapons though."
#   (2) FOUND BULLETS LOAD A CARRIED GUN WHEN THE POCKETS ARE FULL - "If I find bullets, and my inventory is full, but my gun in my inventory is not fully
#       loaded, I have to drop an item… then re-pick up the item I dropped… I should just be able to drag or press my buttons to autoload the gun".
#   (3) AN ITEM DRAGGED OUT OF THE PACK FALLS THE WAY IT WAS DRAGGED - "Too many times I drag it to the right because there's an item on the left I want
#       (or vice versa) but then I can't pick up the item I want because the one I dropped is right in front of it."
# Run: godot --headless res://tests/inventory_flow_test.tscn

var failures: int = 0


func check(c: bool, m: String) -> void:
	print(("  PASS  " if c else "  FAIL  ") + m)
	if not c:
		failures += 1


func _ready() -> void:
	print("=== inventory flow test ===")
	_test_medical_stacking()
	_test_medical_doses()
	_test_medical_edges()
	_test_medical_everywhere()
	_test_found_ammo()
	await _test_loot_panel_rounds()
	await _test_world_drop_rounds()
	await _test_drop_direction()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _fresh() -> void:
	WorldState.new_game()
	WorldState.inventory.clear()
	HUD.selected_slot = -1
	WorldState.wallet_unlocked = true


func _fill_pack() -> void:
	while WorldState.inventory.size() < WorldState.get_inventory_slots():
		WorldState.add_to_inventory("025")           # an old magazine: junk that never stacks


func _gun(short_by: int) -> ItemInstance:
	var g := ItemInstance.new()
	g.setup("004")
	g.mag_count = g.get_mag_cap() - short_by
	return g


func _bullets_in_pack() -> int:
	return WorldState.get_ammo_total()


# --- (1) medical stacks ----------------------------------------------------------------------------------------------------------------

func _test_medical_stacking() -> void:
	print("[bandages and the other medical items stack, three of the same one to a slot]")
	check(WorldState.MAX_MEDICAL_PER_SLOT == 3, "three to a slot")
	var meds: Array = []
	for id in ItemData.items:
		var d: Dictionary = ItemData.items[id]
		if d.get("is_medical", false):
			meds.append(id)
			check(bool(d.get("is_health_item", false)) or bool(d.get("is_speed_boost", false)), "%s is medical because it heals / restores" % d["name"])
			check(not d.get("is_weapon", false) and not d.get("is_tool", false) and not d.get("is_key", false), "…and is not a weapon, tool or key")
	meds.sort()
	check(meds == ["006", "007", "009", "010", "011"], "the medical set is bandages, first aid kit, torn clothes (they heal a state), painkillers and the ice pack (%s)" % str(meds))
	for id in meds:
		_fresh()
		for i in range(3):
			check(WorldState.add_to_inventory(id), "%s #%d goes in" % [ItemData.get_item(id)["name"], i + 1])
		check(WorldState.inventory.size() == 1 and WorldState.inventory[0].count == 3, "…all three share ONE slot")
		WorldState.add_to_inventory(id)
		check(WorldState.inventory.size() == 2 and WorldState.inventory[1].count == 1, "…a fourth opens a second slot")
	_fresh()
	WorldState.add_to_inventory("006")
	WorldState.add_to_inventory("007")
	check(WorldState.inventory.size() == 2, "different medical items keep their own slots")
	# weapons never stack
	for id in ["002", "003", "004", "013", "014", "017"]:
		_fresh()
		WorldState.add_to_inventory(id)
		WorldState.add_to_inventory(id)
		check(WorldState.inventory.size() == 2 and WorldState.inventory[0].count == 1, "%s (a weapon) stays one to a slot" % ItemData.get_item(id)["name"])
	# a full pack still takes a bandage onto a stack with room, and refuses the one that fits nowhere
	_fresh()
	WorldState.add_to_inventory("006")
	WorldState.add_to_inventory("006")
	_fill_pack()
	check(WorldState.inventory.size() == WorldState.get_inventory_slots(), "a full pack")
	check(WorldState.add_to_inventory("006") and WorldState.inventory[0].count == 3, "…still takes a third bandage onto the stack")
	check(not WorldState.add_to_inventory("006") and WorldState.inventory[0].count == 3, "…and refuses a fourth (nothing is lost, nothing is added)")


func _test_medical_doses() -> void:
	print("[using a stack spends one dose; the next unit comes forward]")
	_fresh()
	WorldState.add_to_inventory("010")
	WorldState.add_to_inventory("010")
	var s: ItemInstance = WorldState.inventory[0]
	check(s.count == 2 and s.current_durability == 2, "two painkiller bottles, two doses each")
	check(not s.spend_dose() and s.count == 2 and s.current_durability == 1, "a dose: still two bottles, the front one half used")
	check(not s.spend_dose() and s.count == 1 and s.current_durability == 2 and not s.is_depleted, "its last dose: the NEXT bottle comes forward, whole (count %d, doses %d)" % [s.count, s.current_durability])
	check(not s.spend_dose() and s.count == 1 and s.current_durability == 1, "…and again")
	check(s.spend_dose(), "the very last dose: nothing is left (the caller drops the slot)")
	_fresh()
	for i in range(3):
		WorldState.add_to_inventory("006")
	var b: ItemInstance = WorldState.inventory[0]
	check(not b.spend_dose() and b.count == 2 and not b.spend_dose() and b.count == 1 and b.spend_dose(), "three bandages are three uses")
	# through the player's own use
	_fresh()
	var world := Node2D.new()
	add_child(world)
	var p = load("res://scenes/player.tscn").instantiate()
	world.add_child(p)
	for i in range(3):
		WorldState.add_to_inventory("006")
	p.health_state = 0
	p.use_item(0)
	check(WorldState.inventory.size() == 1 and WorldState.inventory[0].count == 3, "at full health a bandage is NOT spent")
	p.health_state = 4
	p.use_item(0)
	check(int(p.health_state) < 4, "a bandage heals (state %d)" % int(p.health_state))
	check(WorldState.inventory.size() == 1 and WorldState.inventory[0].count == 2, "…and the stack is one smaller, still in its slot")
	p.health_state = 4
	p.use_item(0)
	p.health_state = 4
	p.use_item(0)
	check(WorldState.inventory.is_empty(), "the last bandage clears the slot")
	WorldState.add_to_inventory("011")
	WorldState.add_to_inventory("011")
	p.use_item(0)
	check(WorldState.inventory.size() == 1 and WorldState.inventory[0].count == 2 and WorldState.inventory[0].current_durability == 1, "an ice pack stack spends a dose the same way")
	world.queue_free()


func _test_medical_edges() -> void:
	print("[only like joins like]")
	_fresh()
	var half := ItemInstance.new()                      # quest 001's half-used kit
	half.setup("007")
	half.heal_scale = 0.5
	WorldState.inventory.append(half)
	WorldState.add_to_inventory("007")
	check(WorldState.inventory.size() == 2 and half.count == 1, "a whole kit does not join a half-strength one")
	_fresh()
	WorldState.add_to_inventory("010")
	var part := ItemInstance.new()                      # a bottle with one dose left, picked up off the floor
	part.setup("010")
	part.current_durability = 1
	check(WorldState.add_instance_to_inventory(part) and WorldState.inventory.size() == 2, "a part-used bottle does not join a whole one (it keeps its own slot)")
	_fresh()
	WorldState.inventory.append(part)
	WorldState.add_to_inventory("010")
	check(WorldState.inventory.size() == 1 and part.count == 2 and part.current_durability == 1, "…but a whole bottle joins a part-used one (the front stays as it was)")
	# a dropped STACK comes back as a stack
	_fresh()
	WorldState.add_to_inventory("006")
	var two := ItemInstance.new()
	two.setup("006")
	two.count = 2
	check(WorldState.add_instance_to_inventory(two) and WorldState.inventory.size() == 1 and WorldState.inventory[0].count == 3, "a dropped stack of two joins one bandage (1 + 2 = 3, one slot)")
	var two_b := ItemInstance.new()
	two_b.setup("006")
	two_b.count = 2
	check(WorldState.add_instance_to_inventory(two_b) and WorldState.inventory.size() == 2 and WorldState.inventory[1].count == 2, "…another two do not fit on it: they take a slot of their own, whole")
	_fill_pack()
	var two_c := ItemInstance.new()
	two_c.setup("006")
	two_c.count = 2
	var n_before: int = WorldState.inventory.size()
	check(not WorldState.add_instance_to_inventory(two_c) and WorldState.inventory.size() == n_before and two_c.count == 2, "with no room anywhere it is refused and the stack is untouched")
	# merging two stacks by hand
	_fresh()
	for i in range(4):
		WorldState.add_to_inventory("006")                # [3][1]
	check(WorldState.merge_medical_slots(1, 0) == 0, "a full stack takes nothing more")
	WorldState.inventory[0].count = 2
	check(WorldState.merge_medical_slots(1, 0) == 1 and WorldState.inventory.size() == 1 and WorldState.inventory[0].count == 3, "[2] + [1] -> [3]: the emptied slot is gone")
	_fresh()
	WorldState.add_to_inventory("006")
	WorldState.add_to_inventory("007")
	check(WorldState.merge_medical_slots(0, 1) == 0 and WorldState.inventory.size() == 2, "a different item never merges")
	WorldState.add_to_inventory("002")
	check(WorldState.merge_medical_slots(2, 0) == 0, "…and a weapon is not a medical item")


func _test_medical_everywhere() -> void:
	print("[a stack is a stack in the save, the shop, the quest and the HUD]")
	_fresh()
	for i in range(3):
		WorldState.add_to_inventory("006")
	var dict: Dictionary = JSON.parse_string(JSON.stringify(WorldState.instance_to_dict(WorldState.inventory[0])))
	var back: ItemInstance = WorldState.instance_from_dict(dict)
	check(back.count == 3 and back.item_id == "006", "a stack of three survives a save (JSON round trip)")
	# the merchant pays for every unit
	WorldState.wallet_balance = 0
	WorldState.merchant_sales.clear()
	var each: int = WorldState.get_sell_price("006")
	check(each > 0 and WorldState.sell_item(0, 25) and WorldState.wallet_balance == each * 3, "selling a stack of three pays for all three (%d each, got %d)" % [each, WorldState.wallet_balance])
	check(WorldState.inventory.is_empty(), "…and the slot is gone")
	# a quest takes ONE unit
	_fresh()
	WorldState.add_to_inventory("007")
	WorldState.add_to_inventory("007")
	check(Quests._slots_freed(["take_item:007"]) == 0, "handing over one of two kits frees no slot")
	Quests._apply("001", "take_item:007", null)
	check(WorldState.inventory.size() == 1 and WorldState.inventory[0].count == 1, "…and takes exactly ONE kit, not the stack")
	check(Quests._slots_freed(["take_item:007"]) == 1, "the last one frees its slot")
	Quests._apply("001", "take_item:007", null)
	check(WorldState.inventory.is_empty(), "…and then it is gone")
	# the slot shows its count
	_fresh()
	HUD.set_hotbar_visible(true)
	for i in range(3):
		WorldState.add_to_inventory("006")
	HUD.refresh_inventory()
	check(HUD.slot_key_labels[0].visible and HUD.slot_key_labels[0].text == "x3", "the hotbar slot reads x3 (%s)" % HUD.slot_key_labels[0].text)
	HUD.set_hotbar_visible(false)
	# crafting spends ONE unit of a stack (a Molotov from an empty bottle and a stack of torn clothes)
	_fresh()
	WorldState.add_to_inventory("024")
	WorldState.add_to_inventory("009")
	WorldState.add_to_inventory("009")
	check(WorldState.inventory.size() == 2 and WorldState.inventory[1].count == 2, "a bottle and a stack of two torn clothes")
	var made: Dictionary = Crafting.craft(0, 1)
	var cloth_left := 0
	var molotovs := 0
	for inst in WorldState.inventory:
		if inst.item_id == "009":
			cloth_left += inst.count
		elif inst.item_id == "039":
			molotovs += inst.count
	check(bool(made.get("ok", false)) and cloth_left == 1 and molotovs == 1, "a Molotov takes ONE torn cloth from the stack (ok %s, %d cloth left, %d Molotov)" % [str(made.get("ok", false)), cloth_left, molotovs])
	# the gun is still not one
	check(not WorldState.ammo_gun_pair(WorldState.inventory[0], WorldState.inventory[0]) is ItemInstance, "bandages are not a gun")


# --- (2) found bullets -----------------------------------------------------------------------------------------------------------------

func _test_found_ammo() -> void:
	print("[found bullets go into a carried gun when the pockets cannot hold them]")
	_fresh()
	var gun := _gun(5)
	WorldState.inventory.append(gun)
	_fill_pack()
	var n: int = WorldState.inventory.size()
	var cap: int = gun.get_mag_cap()
	var r: Dictionary = WorldState.take_found_ammo("016", 5)
	check(int(r["left"]) == 0 and int(r["to_gun"]) == 5 and gun.mag_count == cap, "pack full, gun 5 short, 5 found: all five load (mag %d/%d)" % [gun.mag_count, cap])
	check(WorldState.inventory.size() == n and _bullets_in_pack() == 0, "…and the pockets are exactly as they were (nothing dropped, nothing added)")
	check(str(r["msg"]).begins_with("Loaded 5"), "…and it says so (%s)" % str(r["msg"]))
	gun.mag_count = cap - 3
	r = WorldState.take_found_ammo("016", 5)
	check(int(r["to_gun"]) == 3 and int(r["left"]) == 2 and gun.mag_count == cap, "gun 3 short, 5 found: 3 load, 2 are LEFT (not destroyed)")
	check(_bullets_in_pack() == 0, "…the two do not squeeze into a full pack")
	r = WorldState.take_found_ammo("016", 4)
	check(int(r["left"]) == 4 and int(r["to_gun"]) == 0 and str(r["msg"]) == "", "a full magazine takes nothing: all 4 stay where they were")
	# a bundle too big for the one free slot: the gun takes its share first, and the pockets what is left
	WorldState.inventory.pop_back()
	gun.mag_count = cap - 3
	r = WorldState.take_found_ammo("016", WorldState.MAX_AMMO_PER_SLOT + 2)
	check(int(r["to_gun"]) == 3 and int(r["to_pack"]) == WorldState.MAX_AMMO_PER_SLOT - 1 and int(r["left"]) == 0 and _bullets_in_pack() == WorldState.MAX_AMMO_PER_SLOT - 1,
		"a bundle of %d, one free slot, gun 3 short: 3 load, the other %d go in the slot (%s)" % [WorldState.MAX_AMMO_PER_SLOT + 2, WorldState.MAX_AMMO_PER_SLOT - 1, str(r)])
	# the pockets have room for the lot: the rule is unchanged (pack first, the gun is yours to load)
	_fresh()
	gun = _gun(5)
	WorldState.inventory.append(gun)
	var short: int = gun.mag_count
	r = WorldState.take_found_ammo("016", 4)
	check(int(r["to_pack"]) == 4 and int(r["to_gun"]) == 0 and gun.mag_count == short and _bullets_in_pack() == 4, "room in the pack: the bullets go to the pack as ever, the gun is untouched")
	# no gun -> nothing changes
	_fresh()
	_fill_pack()
	r = WorldState.take_found_ammo("016", 5)
	check(int(r["left"]) == 5 and int(r["to_gun"]) == 0 and int(r["to_pack"]) == 0, "no gun and no room: nothing moves")
	# the gun in hand first
	_fresh()
	var a := _gun(4)
	var b := _gun(4)
	WorldState.inventory.append(a)
	WorldState.inventory.append(b)
	_fill_pack()
	HUD.selected_slot = 1
	r = WorldState.take_found_ammo("016", 4)
	check(b.mag_count == b.get_mag_cap() and a.mag_count == a.get_mag_cap() - 4, "two guns: the one in hand is topped up first")
	HUD.selected_slot = -1
	# a worn-out gun cannot fire, so it is not loaded
	_fresh()
	var dead := _gun(6)
	dead.is_depleted = true
	WorldState.inventory.append(dead)
	_fill_pack()
	check(WorldState.guns_with_room().is_empty() and int(WorldState.take_found_ammo("016", 3)["left"]) == 3, "a broken gun is skipped")
	# the Gun Cabinet Key's name contains 'gun'; it is not one (bullets dragged onto it used to 'load' it)
	_fresh()
	WorldState.add_to_inventory("016", 3)
	var key := ItemInstance.new()
	key.setup("038")
	WorldState.inventory.append(key)
	check(WorldState.ammo_gun_pair(WorldState.inventory[0], key) == null, "bullets and the gun cabinet KEY are not a loadable pair")
	var real := _gun(5)
	WorldState.inventory.append(real)
	check(WorldState.ammo_gun_pair(WorldState.inventory[0], real) == real, "…bullets and a gun are")


func _open_rounds(loot, apt: String, anchor: String, amount: int) -> void:
	WorldState.set_anchor_item(apt, anchor, "016")
	WorldState.set_anchor_amount(apt, anchor, amount)
	loot.open("016", anchor, apt)
	loot._process(loot.REVEAL_TIME + 0.1)


func _test_loot_panel_rounds() -> void:
	print("[the loot panel: take / press / drag loads the gun when the pack is full]")
	_fresh()
	WorldState.is_scavenge_mode = true
	WorldState.current_apartment_id = "t1"
	var gun := _gun(3)
	WorldState.inventory.append(gun)
	_fill_pack()
	var loot = load("res://scenes/loot_ui.tscn").instantiate()
	add_child(loot)
	await get_tree().process_frame
	var cap: int = gun.get_mag_cap()
	_open_rounds(loot, "t1", "a1", 5)
	check(loot.has_item and loot.hint_label.text.to_lower().contains("load"), "the panel offers to LOAD (%s)" % loot.hint_label.text)
	var n: int = WorldState.inventory.size()
	check(not loot._take(), "[interact] with a full pack and a gun 3 short: 3 load, 2 stay (the panel stays open)")
	check(gun.mag_count == cap and WorldState.inventory.size() == n, "…the gun is full and the pockets are untouched")
	check(WorldState.get_anchor_amount("t1", "a1") == 2 and WorldState.get_anchor_item("t1", "a1") == "016", "…the node still holds the other 2")
	check(loot.visible and loot.has_item and loot.name_label.text.contains("2"), "…and the panel says so (%s)" % loot.name_label.text)
	WorldState.inventory.pop_back()                     # make room
	check(loot._take() and not loot.visible, "with a slot free the rest is taken and the panel closes")
	check(_bullets_in_pack() == 2 and WorldState.get_anchor_item("t1", "a1") == "", "…2 bullets in the pack, the node empty")
	# exactly enough: the whole bundle loads and the node is cleared
	_fill_pack()
	WorldState.inventory = WorldState.inventory.filter(func(i): return i.item_id != "016")
	_fill_pack()
	gun.mag_count = cap - 3
	_open_rounds(loot, "t1", "a2", 3)
	check(loot._take() and not loot.visible and gun.mag_count == cap, "3 found, gun 3 short, pack full: loaded, panel closed")
	check(WorldState.get_anchor_item("t1", "a2") == "", "…and the node is spent")
	# the use key loads without taking the bullets into the pack
	WorldState.inventory = WorldState.inventory.filter(func(i): return i.item_id != "025")        # pockets with room
	gun.mag_count = cap - 4
	_open_rounds(loot, "t1", "a3", 4)
	var ev := InputEventAction.new()
	ev.action = "item_use"
	ev.pressed = true
	loot._input(ev)
	check(gun.mag_count == cap and _bullets_in_pack() == 0 and not loot.visible, "[item_use] loads the gun straight from the panel, with room in the pack (mag %d/%d, pack bullets %d)" % [gun.mag_count, cap, _bullets_in_pack()])
	# ...and does nothing when there is nothing to load
	_open_rounds(loot, "t1", "a4", 4)
	loot._input(ev)
	check(loot.visible and loot.has_item and _bullets_in_pack() == 0, "…with the magazine full it leaves the panel alone")
	check(loot._take() and _bullets_in_pack() == 4, "…and [interact] takes them to the pack as ever")
	# dragged onto the gun's wedge in the ring
	WorldState.inventory = WorldState.inventory.filter(func(i): return i.item_id != "016")
	gun.mag_count = cap - 2
	_open_rounds(loot, "t1", "a5", 5)
	HUD.pack_wheel.slots = [0]
	loot.swap_in(HUD.pack_wheel, 0, true)
	check(gun.mag_count == cap and WorldState.get_anchor_amount("t1", "a5") == 3 and loot.visible, "dragged onto the gun: 2 load, 3 remain on the node")
	# onto a FULL gun with the bag full: nothing is put down to make room for bullets that are for the gun
	_fill_pack()
	var drops_before: int = WorldState.world_drops.size()
	loot.swap_in(HUD.pack_wheel, 0, true)
	check(WorldState.inventory[0] == gun and WorldState.world_drops.size() == drops_before and loot.visible, "onto a full magazine: 'Magazine full' - the gun is NOT dropped to make room")
	loot.leave()
	loot.queue_free()


func _test_world_drop_rounds() -> void:
	print("[bullets lying on the floor load the gun too]")
	_fresh()
	var world := Node2D.new()
	world.scene_file_path = "res://scenes/building_floors.tscn"
	add_child(world)
	var p = load("res://scenes/player.tscn").instantiate()
	world.add_child(p)
	await get_tree().process_frame
	var gun := _gun(3)
	WorldState.inventory.append(gun)
	_fill_pack()
	var key: String = WorldState.add_world_drop("016", Vector2(600.0, 412.0), 12, {"amount": 5, "scene": "res://scenes/building_floors.tscn"})
	var drop = load("res://scenes/world_drop.tscn").instantiate()
	drop.item_id = "016"
	drop.amount = 5
	drop.drop_key = key
	world.add_child(drop)
	await get_tree().process_frame
	drop._try_pickup()
	check(gun.mag_count == gun.get_mag_cap(), "picking up 5 bullets, pack full, gun 3 short: the gun is loaded")
	check(is_instance_valid(drop) and not drop.is_queued_for_deletion() and drop.amount == 2, "…the pickup stays on the floor with the other 2 (amount %d)" % drop.amount)
	check(WorldState.world_drops.has(key) and int(WorldState.world_drops[key]["amount"]) == 2, "…and the saved record says 2")
	WorldState.inventory.pop_back()
	drop._try_pickup()
	check(drop.is_queued_for_deletion() and not WorldState.world_drops.has(key) and _bullets_in_pack() == 2, "with room, the last two are taken and the pickup goes")
	world.queue_free()
	await get_tree().process_frame


# --- (3) the way an item is thrown ----------------------------------------------------------------------------------------------------

func _live_drops(world: Node) -> Array:
	var out: Array = []
	for c in world.get_children():
		if c.get_script() == load("res://scripts/world_drop.gd"):
			out.append(c)
	return out


func _settle() -> void:
	for i in range(160):
		await get_tree().physics_frame


func _test_drop_direction() -> void:
	print("[an item dragged out of the pack lands on the side it was dragged to]")
	_fresh()
	WorldState.current_floor = 12
	var world := Node2D.new()
	world.scene_file_path = "res://scenes/building_floors.tscn"
	add_child(world)
	var p = load("res://scenes/player.tscn").instantiate()
	world.add_child(p)
	await get_tree().process_frame
	p.global_position = Vector2(600.0, 386.0)
	var cam := Camera2D.new()                      # (the scenes give the player their camera at setup; a bare test world has none)
	cam.name = "Camera2D"
	p.add_child(cam)
	cam.make_current()
	await get_tree().process_frame
	await get_tree().process_frame
	var sx: float = HUD.player_screen_x()
	check(sx > 0.0, "the player has a place on screen (%.0f)" % sx)
	check(HUD.drop_dir_for(Vector2(sx + 200.0, 300.0)) == 1.0 and HUD.drop_dir_for(Vector2(sx - 200.0, 300.0)) == -1.0, "a pointer right / left of the player is +1 / -1")
	check(HUD.drop_dir_for(Vector2(sx + 3.0, 300.0)) == 0.0, "right over them it is 0 (random, as before)")
	for dir in [1.0, -1.0]:
		var worst := 1.0e9
		var best := 0.0
		var mismatch := false
		for k in range(4):
			WorldState.inventory.clear()
			WorldState.add_to_inventory("002")
			var before: int = _live_drops(world).size()
			HUD.discard_slot(0, dir)
			var ds: Array = _live_drops(world)
			if ds.size() != before + 1:
				check(false, "a live drop appears for dir %+.0f" % dir)
				continue
			var d = ds.back()
			await _settle()
			var dx: float = (d.global_position.x - 600.0) * dir
			worst = minf(worst, dx)
			best = maxf(best, dx)
			var reg_x: float = float(WorldState.world_drops[d.drop_key]["x"])
			if absf(reg_x - d.global_position.x) > 2.0:
				mismatch = true
		check(worst >= 70.0 and best <= 260.0, "dragged %s: all four land 70-260 px that way (nearest %.0f, farthest %.0f)" % ["right" if dir > 0.0 else "left", worst, best])
		check(not mismatch, "…and the saved position is where each came to rest (re-entry shows what you saw)")
	# let go over the player: the old behaviour (a short toss either way)
	WorldState.inventory.clear()
	WorldState.add_to_inventory("002")
	var n0: int = _live_drops(world).size()
	HUD.discard_slot(0)
	var d0 = _live_drops(world)[n0]
	await _settle()
	check(absf(d0.global_position.x - 600.0) < 130.0, "no direction: it still drops close by (dx %.0f)" % (d0.global_position.x - 600.0))
	# through the pack ring: let go to the right of the player
	var pw = HUD.pack_wheel
	WorldState.inventory.clear()
	WorldState.add_to_inventory("003")
	pw.slots = [0]
	pw.centre = Vector2(sx, 300.0)
	pw._press_k = 0
	pw.drag_k = 0
	var n1: int = _live_drops(world).size()
	pw._finish_press(Vector2(sx + 380.0, 300.0))
	var made: Array = _live_drops(world)
	check(made.size() == n1 + 1 and WorldState.inventory.is_empty(), "the ring: dragged off to the right it drops the item")
	if made.size() == n1 + 1:
		await _settle()
		check(made.back().global_position.x - 600.0 >= 70.0, "…and it lands to the RIGHT of the player (dx %.0f)" % (made.back().global_position.x - 600.0))
	WorldState.inventory.clear()
	WorldState.add_to_inventory("003")
	pw._press_k = 0
	pw.drag_k = 0
	var n2: int = _live_drops(world).size()
	pw._finish_press(Vector2(sx - 380.0, 300.0))
	made = _live_drops(world)
	if made.size() == n2 + 1:
		await _settle()
		check(made.back().global_position.x - 600.0 <= -70.0, "…and dragged off to the left it lands to the LEFT (dx %.0f)" % (made.back().global_position.x - 600.0))
	else:
		check(false, "the ring drops the item dragged to the left")
	# a dropped stack comes back as a stack
	WorldState.inventory.clear()
	WorldState.add_to_inventory("006")
	WorldState.add_to_inventory("006")
	var n3: int = _live_drops(world).size()
	HUD.discard_slot(0, 1.0)
	var sd = _live_drops(world)[n3]
	check(WorldState.inventory.is_empty(), "a stack of two bandages is dropped whole")
	await _settle()
	sd._try_pickup()
	check(WorldState.inventory.size() == 1 and WorldState.inventory[0].count == 2, "…and picked up as the same stack of two")
	world.queue_free()
