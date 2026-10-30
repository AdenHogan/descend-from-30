extends Node

# Headless smoke test for the merchant/shop systems (docs/STORE_DESIGN.md 3-5).
# Run:  godot --headless res://tests/merchant_smoke_test.tscn
# Exits 0 when every check passes, 1 otherwise — safe for CI / pre-commit.

var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _fresh_state(seed_value: int) -> void:
	WorldState.new_game()
	WorldState.master_seed = seed_value
	WorldState.current_run = 1
	WorldState.merchant_stock.clear()
	WorldState.legendary_hold = {}
	WorldState.legendary_just_purchased = false


func _ready() -> void:
	print("=== merchant smoke test ===")
	_test_determinism()
	_test_stock_structure()
	_test_legendary_hold()
	_test_buy_flow()
	_test_sell_flow()
	_test_sell_by_level()
	_test_bullets_for_sale()
	_test_upgrades()
	_test_save_load()
	_test_scene_instantiation()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _test_determinism() -> void:
	print("[determinism]")
	_fresh_state(12345)
	var s1 = WorldState.get_merchant_stock(25).duplicate(true)
	_fresh_state(12345)
	var s2 = WorldState.get_merchant_stock(25).duplicate(true)
	check(s1 == s2, "same seed + run + floor rolls identical stock")
	_fresh_state(54321)
	var s3 = WorldState.get_merchant_stock(25).duplicate(true)
	check(s1 != s3, "different seed rolls different stock")


func _test_stock_structure() -> void:
	print("[structure]")
	for seed_value in [1, 7, 42, 999, 31337]:
		_fresh_state(seed_value)
		for floor_num in WorldState.MERCHANT_FLOORS:
			var stock = WorldState.get_merchant_stock(floor_num)
			var commons = 0
			var bullets = 0
			var quality = 0
			var legendary = 0
			var ids = {}
			var prices_ok = true
			for entry in stock:
				ids[entry["item_id"]] = true
				match entry["band"]:
					"common":
						commons += 1
						if entry["item_id"] == "036":
							# Fire extinguisher: priced 35 normally / 55 in a fire crisis (not a SHOP_COMMON ware).
							prices_ok = prices_ok and (entry["price"] == 35 or entry["price"] == 55)
						elif entry["item_id"] == "016":
							# The bullets: a bundle of N rounds at BULLET_BUY_PRICE a round.
							var n: int = int(entry.get("amount", 0))
							bullets += 1
							prices_ok = prices_ok and n >= WorldState.BULLET_STOCK_RANGE.x and n <= WorldState.BULLET_STOCK_RANGE.y and entry["price"] == n * WorldState.BULLET_BUY_PRICE
						else:
							prices_ok = prices_ok and WorldState.SHOP_COMMON.get(entry["item_id"], -1) == entry["price"]
					"quality":
						quality += 1
						prices_ok = prices_ok and WorldState.SHOP_QUALITY.get(entry["item_id"], -1) == entry["price"]
					"legendary":
						legendary += 1
						prices_ok = prices_ok and WorldState.SHOP_LEGENDARY.get(entry["item_id"], -1) == entry["price"]
			var label = "seed %d floor %d: " % [seed_value, floor_num]
			check(stock.size() <= 6, label + "max 6 slots (got %d)" % stock.size())
			check(commons >= 3 and commons <= 4, label + "3-4 commons (got %d)" % commons)
			check(bullets == 1, label + "ALWAYS exactly one bundle of bullets for sale (got %d)" % bullets)
			check(quality >= 1 and quality <= 2, label + "1-2 quality (got %d)" % quality)
			check(legendary <= 1, label + "0-1 legendary (got %d)" % legendary)
			check(ids.size() == stock.size(), label + "no duplicate wares")
			check(prices_ok, label + "prices match band tables")


func _test_legendary_hold() -> void:
	print("[legendary hold]")
	# Find a seed whose floor-25 visit rolls a legendary, then walk the run.
	var seed_value = -1
	for candidate in range(1, 500):
		_fresh_state(candidate)
		for entry in WorldState.get_merchant_stock(25):
			if entry["band"] == "legendary":
				seed_value = candidate
				break
		if seed_value != -1:
			break
	check(seed_value != -1, "found a seed with a floor-25 legendary")
	if seed_value == -1:
		return

	_fresh_state(seed_value)
	var first_leg = ""
	for entry in WorldState.get_merchant_stock(25):
		if entry["band"] == "legendary":
			first_leg = entry["item_id"]
	check(int(WorldState.legendary_hold.get("visits_left", -1)) == WorldState.LEGENDARY_HOLD_VISITS,
		"fresh legendary arms the hold window")

	# Unpurchased: the same item must persist through the next 3 visits.
	for floor_num in [20, 15, 10]:
		var held = ""
		for entry in WorldState.get_merchant_stock(floor_num):
			if entry["band"] == "legendary":
				held = entry["item_id"]
		check(held == first_leg, "floor %d still shelves held legendary %s" % [floor_num, first_leg])
	check(int(WorldState.legendary_hold.get("visits_left", -1)) == 0, "hold window exhausted after 3 held visits")

	# Purchasing a legendary clears the hold immediately.
	_fresh_state(seed_value)
	var stock = WorldState.get_merchant_stock(25)
	for i in range(stock.size()):
		if stock[i]["band"] == "legendary":
			WorldState.mark_shop_item_sold(25, i)
	check(WorldState.legendary_hold.is_empty(), "purchase clears the hold")
	check(WorldState.legendary_just_purchased, "purchase flags the 25% reroll for next visit")


func _test_buy_flow() -> void:
	print("[buy flow]")
	_fresh_state(42)
	WorldState.wallet_unlocked = true
	WorldState.wallet_balance = 1000
	var stock = WorldState.get_merchant_stock(25)
	var entry = stock[0]
	var price = int(entry["price"])

	check(WorldState.add_to_inventory(entry["item_id"]), "purchased item enters inventory")
	check(WorldState.spend_money(price), "wallet covers the price")
	check(WorldState.wallet_balance == 1000 - price, "wallet debited exactly")
	WorldState.mark_shop_item_sold(25, 0)
	check(WorldState.get_merchant_stock(25)[0]["sold"] == true, "entry marked sold")

	WorldState.wallet_balance = 0
	check(not WorldState.spend_money(99999), "insufficient funds refuses the sale")

	WorldState.inventory.clear()
	for i in range(WorldState.MAX_INVENTORY_SLOTS):
		WorldState.add_to_inventory("001")
	check(not WorldState.add_to_inventory("002"), "full inventory refuses the item")


func _test_sell_flow() -> void:
	print("[sell flow]")
	_fresh_state(2024)
	WorldState.wallet_unlocked = true
	WorldState.wallet_balance = 0
	for junk in ["023", "024", "025", "026"]:
		WorldState.add_to_inventory(junk)
	check(WorldState.get_sales_remaining(25) == 3, "merchant takes 3 items per visit")
	check(WorldState.sell_item(0, 25), "junk sells")
	check(WorldState.wallet_balance > 0, "sale credits the wallet")
	WorldState.sell_item(0, 25)
	WorldState.sell_item(0, 25)
	check(WorldState.get_sales_remaining(25) == 0, "limit reached after three")
	check(not WorldState.sell_item(0, 25), "fourth sale refused")
	check(WorldState.get_sell_price("022") == 0, "keys are not sellable")
	check(WorldState.inventory.size() == 1, "three items left the inventory")


func _gun_at(level: int, rounds: int = 0) -> ItemInstance:
	var g := ItemInstance.new()
	g.setup("004")
	g.level = level
	g.current_durability = g.get_max_durability()
	g.mag_count = rounds
	return g


func _test_sell_by_level() -> void:
	print("[sell by level: a worked-on weapon is worth more, never more than a new one costs]")
	_fresh_state(2025)
	var lv1 := _gun_at(1)
	var lv4 := _gun_at(4)
	var lv8 := _gun_at(8)
	var p1: int = WorldState.sell_price_of(lv1)
	var p4: int = WorldState.sell_price_of(lv4)
	var p8: int = WorldState.sell_price_of(lv8)
	check(p4 > p1 and p8 > p4, "a Lv4 gun fetches more than a Lv1, and a Lv8 more than that (%d < %d < %d)" % [p1, p4, p8])
	check(p1 == 72 and p4 == 106, "the numbers: Lv1 gun 72 (45%% of 160), Lv4 gun 106 (66%%) (%d, %d)" % [p1, p4])
	check(p8 < WorldState.item_shop_value("004"), "even a Lv8 heirloom sells for less than a plain one is worth (%d < %d)" % [p8, WorldState.item_shop_value("004")])
	for id in ["001", "002", "003", "004", "012", "013", "014", "017", "035", "019", "015", "020"]:
		var it := ItemInstance.new()
		it.setup(id)
		var cost: int = WorldState.item_shop_value(id)
		check(cost > 0 and WorldState.sell_price_of(it) < cost, "%s: sells for %d, below its %d" % [it.get_data().get("name", id), WorldState.sell_price_of(it), cost])
	var worn := _gun_at(1)
	worn.current_durability = 2
	var broken := _gun_at(1)
	broken.is_depleted = true
	broken.current_durability = 0
	check(WorldState.sell_price_of(broken) < WorldState.sell_price_of(worn) and WorldState.sell_price_of(worn) < p1, "wear lowers the price: new > worn > broken (%d, %d, %d)" % [p1, WorldState.sell_price_of(worn), WorldState.sell_price_of(broken)])
	var junk := ItemInstance.new()
	junk.setup("023")
	check(WorldState.sell_price_of(junk) == WorldState.SELL_JUNK_PRICE and WorldState.SELL_JUNK_PRICE >= 6, "junk pays a few notes, not four (%d)" % WorldState.sell_price_of(junk))
	check(WorldState.get_sell_price("004") > 10 and WorldState.get_sell_price("035") > 10 and WorldState.get_sell_price("002") > 10, "no weapon or tool is the old flat 10 any more")
	# stacks pay for every unit and the shop's list agrees with what sell_item pays
	WorldState.wallet_unlocked = true
	WorldState.wallet_balance = 0
	var band := ItemInstance.new()
	band.setup("006")
	band.count = 3
	WorldState.inventory = [band]
	var expect: int = WorldState.sell_price_of(band)
	check(expect == WorldState.get_sell_price("006") * 3 and WorldState.sell_item(0, 25) and WorldState.wallet_balance == expect, "a stack of three bandages pays for all three, exactly what the list showed (%d)" % expect)
	# the weapon sold pays by ITS level, and a loaded gun's rounds come home
	WorldState.wallet_balance = 0
	WorldState.inventory = [_gun_at(4, 7)]
	var asked: int = WorldState.sell_price_of(WorldState.inventory[0])
	check(WorldState.sell_item(0, 25) and WorldState.wallet_balance == asked and asked == p4, "a Lv4 gun sells for the Lv4 price (%d)" % asked)
	check(WorldState.get_ammo_total() == 7 and WorldState.inventory.size() == 1, "…and its seven loaded rounds come back to the pack as bullets, not into the bin")
	# no room for the rounds -> refused, nothing touched (robustness rule 5)
	_fresh_state(2026)
	var huge := _gun_at(1, WorldState.MAX_AMMO_PER_SLOT + 5)
	WorldState.inventory = [huge]
	for i in WorldState.get_inventory_slots() - 1:
		var k := ItemInstance.new()
		k.setup("024")
		WorldState.inventory.append(k)
	check(WorldState.sell_blocker(0).contains("Unload") and not WorldState.sell_item(0, 25) and WorldState.inventory[0] == huge, "a gun whose rounds will not fit the pack is not sold, and is kept (%s)" % WorldState.sell_blocker(0))


func _test_bullets_for_sale() -> void:
	print("[bullets are always for sale, a different number each visit]")
	var counts := {}
	for seed_value in range(1, 41):
		_fresh_state(seed_value)
		for floor_num in [25, 20, 15]:
			var found := 0
			for e in WorldState.get_merchant_stock(floor_num):
				if e["item_id"] == "016":
					found += 1
					counts[int(e["amount"])] = true
			check(found == 1, "seed %d floor %d: one bundle of bullets" % [seed_value, floor_num]) if found != 1 else null
	check(counts.size() >= 6, "the bundle varies (%d different sizes over 120 visits)" % counts.size())
	# buying it puts those rounds in the pack
	_fresh_state(31)
	WorldState.wallet_unlocked = true
	WorldState.wallet_balance = 1000
	WorldState.inventory.clear()
	var entry: Dictionary = WorldState.get_merchant_stock(25)[0]
	check(entry["item_id"] == "016" and int(entry["amount"]) >= 4, "the bullets lead the list")
	check(WorldState.add_to_inventory("016", int(entry["amount"])) and WorldState.get_ammo_total() == int(entry["amount"]), "buying it adds exactly the rounds on the label (%d)" % int(entry["amount"]))


func _test_upgrades() -> void:
	print("[upgrades]")
	check(WorldState.UPGRADE_POOL.size() >= 25, "pool has a healthy count (%d)" % WorldState.UPGRADE_POOL.size())

	_fresh_state(555)
	check(is_equal_approx(WorldState.get_max_stamina(), 100.0), "base max stamina is 100")
	check(WorldState.get_inventory_slots() == 5, "base inventory is 5 slots")

	# Modifier folding: multiplicative first, then additive.
	WorldState.active_upgrades = ["U_stam_m"]  # +30 add
	check(is_equal_approx(WorldState.get_max_stamina(), 130.0), "additive stamina folds (+30)")
	WorldState.active_upgrades = ["U_db_glass"]  # x0.7
	check(is_equal_approx(WorldState.get_max_stamina(), 70.0), "multiplicative stamina folds (x0.7)")
	WorldState.active_upgrades = ["U_stam_m", "U_db_glass"]  # 100*0.7 + 30 = 100
	check(is_equal_approx(WorldState.get_max_stamina(), 100.0), "mult-then-add order (100*0.7+30=100)")
	check(WorldState.get_melee_damage_bonus() == 2, "drawback's benefit half also applies")

	WorldState.active_upgrades = ["U_slot"]
	check(WorldState.get_inventory_slots() == 6, "inventory-slot upgrade unlocks the 6th")

	# Offer generation: three distinct unowned perks, seeded stable.
	_fresh_state(9001)
	var pair_a = WorldState.get_upgrade_offer(25)
	var pair_b = WorldState.get_upgrade_offer(25)
	check(pair_a.size() == 3, "offer is three cards")
	check(pair_a[0] != pair_a[1] and pair_a[1] != pair_a[2] and pair_a[0] != pair_a[2], "the offer has no duplicate")
	check(pair_a == pair_b, "the offer is stable across calls (seeded)")

	# No duplicate offers: an owned upgrade never reappears in a fresh pair.
	_fresh_state(9001)
	WorldState.active_upgrades = [pair_a[0]]
	var pair_c = WorldState.get_upgrade_offer(20)
	check(not (pair_a[0] in pair_c), "owned upgrade excluded from new offers")

	# Resolve: taking one records it and marks the visit resolved.
	_fresh_state(9001)
	var pair = WorldState.get_upgrade_offer(25)
	check(not WorldState.is_upgrade_offer_resolved(25), "offer starts unresolved")
	WorldState.resolve_upgrade_offer(25, pair[0])
	check(WorldState.is_upgrade_offer_resolved(25), "offer resolved after taking")
	check(pair[0] in WorldState.active_upgrades, "chosen upgrade is owned")
	# Refuse path
	WorldState.get_upgrade_offer(20)
	WorldState.resolve_upgrade_offer(20, "")
	check(WorldState.is_upgrade_offer_resolved(20), "refusal also resolves the visit")
	check(WorldState.active_upgrades.size() == 1, "refusal grants nothing")
	WorldState.active_upgrades = []


func _test_save_load() -> void:
	print("[save/load]")
	_fresh_state(777)
	WorldState.wallet_unlocked = true
	WorldState.wallet_balance = 500
	WorldState.get_merchant_stock(25)
	WorldState.mark_shop_item_sold(25, 0)
	var expected_stock = WorldState.merchant_stock.duplicate(true)
	var expected_hold = WorldState.legendary_hold.duplicate(true)

	WorldState.save_game("res://scenes/building_floors.tscn")

	# Trash the live state, then restore from disk.
	WorldState.merchant_stock.clear()
	WorldState.legendary_hold = {"item_id": "junk", "visits_left": 99}
	WorldState.legendary_just_purchased = true
	var scene_path = WorldState.load_game()

	check(scene_path == "res://scenes/building_floors.tscn", "save file round-trips scene path")
	check(str(WorldState.merchant_stock) == str(expected_stock), "merchant stock survives save/load")
	check(str(WorldState.legendary_hold) == str(expected_hold), "legendary hold survives save/load")
	check(WorldState.merchant_stock["1:25"][0]["sold"] == true, "sold flag survives save/load")
	WorldState.delete_save()


func _test_scene_instantiation() -> void:
	print("[scenes]")
	var merchant = load("res://scenes/merchant.tscn").instantiate()
	add_child(merchant)
	check(merchant.get_node_or_null("MerchantSprite") != null, "merchant sprite node present")
	check(merchant.get_node("MerchantSprite").texture != null, "merchant sprite texture loads")
	check(merchant.get_node_or_null("DoorLeft") != null and merchant.get_node_or_null("DoorRight") != null,
		"elevator door nodes present")
	check(merchant.get_node("DoorLeft").position.x == -merchant.get_node("DoorRight").position.x,
		"doors start mirrored/closed")
	check(merchant.z_index <= 0 and merchant.get_node("DoorLeft").z_index <= 0,
		"merchant/elevator stays on the backdrop layer (behind actors)")
	merchant._set_doors_open(true)
	check(merchant.doors_open, "door open toggle runs")
	merchant.queue_free()

	var shop = load("res://scenes/shop_ui.tscn").instantiate()
	add_child(shop)
	shop.open(25, "test greeting")
	check(shop.visible, "shop ui opens and populates")
	shop.close()
	check(not shop.visible, "shop ui closes")
	shop.queue_free()

	var warp = load("res://scripts/dev_warp_prompt.gd").new()
	add_child(warp)
	check(warp.edit != null, "dev warp prompt builds its input field")
	warp.open()
	check(not warp.visible, "warp refuses to open with no player in scene")
	warp._on_submitted("abc")
	check(not get_tree().paused, "invalid warp input never leaves the tree paused")
	warp.queue_free()
