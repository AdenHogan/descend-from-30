extends Node

const ROOM_POOL = ["bedroom", "bathroom", "study", "kitchen", "living_room", "dining_room"]
const MAX_INVENTORY_SLOTS = 5
const MAX_AMMO_PER_SLOT = 8

var master_seed: int = 0
var current_apartment_id: String = ""
var apartment_layouts: Dictionary = {}
var exit_spawn_x: float = 0.0
var stair_spawn_side: String = ""
var current_floor: int = 30
var stair_direction: String = ""
var spawn_source: String = ""
var is_first_run: bool = true
var tutorial_zombie_spawned: bool = false
var last_exited_apartment: int = 0
var current_run: int = 1
var paradise_apartments: Array = []
var anchor_items: Dictionary = {}
var searched_anchors: Dictionary = {}
var player_health: int = 0
var is_dying: bool = false
var dying_timer: float = 0.0
var interaction_handled: bool = false
var is_scavenge_mode: bool = false
var inventory: Array = []
var stamina: float = 100.0
var max_stamina: float = 100.0
var last_rest_floor: int = 30
var rest_available: bool = true
var rest_count: int = 0
var active_upgrades: Array = []
var available_upgrades: Array = []
var saved_player_x: float = 0.0
var saved_player_y: float = 0.0
var killed_zombies: Dictionary = {}
var world_drops: Dictionary = {}  # "floor:x:y" -> {item_id, x, y, floor, target_apartment}

# Dev tools
var god_mode: bool = false

# --- Door system ---
enum DoorState {
	OPEN,
	SHUT_FORCEABLE,
	SHUT_LOCKED,
	BARRICADED_FORCEABLE,
	BARRICADED_LOCKED,
	BREACHED
}

var door_states: Dictionary = {}
var door_keys_consumed: Dictionary = {}
var floor_states_seeded: Dictionary = {}
# Live (unkilled) zombie positions captured at save time, keyed by spawn_key.
var zombie_positions: Dictionary = {}

# Wallet: unlock is CROSS-RUN (persists over character death — see merchant doc);
# balance is PER-RUN (dies with the character / recoverable from the corpse later).
# NOTE: balance reset on run-advance is wired when the time-skip pass is built.
var wallet_unlocked: bool = false
var wallet_balance: int = 0
var barricade_progress: Dictionary = {}

# --- Merchant / shop (docs/STORE_DESIGN.md) ---
const MERCHANT_FLOORS = [25, 20, 15, 10, 5]
const LEGENDARY_HOLD_VISITS = 3

# Price bands per design: common 15-40, quality 80-150, legendary 300-500.
const SHOP_COMMON = {
	"005": 15,   # Canned Food
	"009": 15,   # Torn Clothes
	"021": 20,   # Battery
	"006": 25,   # Bandages
	"010": 30,   # Painkillers
	"011": 30,   # Ice Pack
	"001": 40,   # Knife
}
const SHOP_QUALITY = {
	"018": 80,   # Rope
	"014": 90,   # Baseball Bat
	"002": 100,  # Hammer
	"013": 100,  # Cricket Bat
	"007": 110,  # First Aid Kit
	"019": 130,  # Toolbox
}
const SHOP_LEGENDARY = {
	"017": 350,  # Aluminium Baseball Bat
	"003": 400,  # Sword
}

var merchant_stock: Dictionary = {}  # "run:floor" -> Array of {item_id, price, band, sold}
# Legendary hold: an unpurchased Legendary stays in stock for the next
# LEGENDARY_HOLD_VISITS shop visits so a savings goal is always reachable.
var legendary_hold: Dictionary = {}  # {"item_id": String, "visits_left": int} when active
var legendary_just_purchased: bool = false

# --- Sound & listen system (docs/SOUND_STEALTH.md) ---
# Under-the-hood noise: every player action has a loudness radius; zombies
# inside the radius are alerted. Sight detection (each zombie's own
# DETECTION_RANGE) is unchanged — noise EXTENDS how far away you can be
# noticed, it never shrinks it.
const NOISE_RADIUS = {
	"crouch": 45.0,     # level ~2/10
	"scavenge": 70.0,   # level ~3/10
	"walk": 120.0,      # level ~5/10
	"run": 240.0,       # level ~7/10
	"door_work": 420.0, # level 10/10 — forcing doors/locks, barricade removal
	"gunshot": 2000.0,  # whole floor
}


func new_game() -> void:
	master_seed = randi()
	apartment_layouts.clear()
	anchor_items.clear()
	searched_anchors.clear()
	inventory.clear()
	current_floor = 30
	current_run = 1
	player_health = 0
	is_dying = false
	dying_timer = 0.0
	is_scavenge_mode = false
	stamina = 100.0
	max_stamina = 100.0
	last_rest_floor = 30
	rest_available = true
	rest_count = 0
	active_upgrades.clear()
	available_upgrades.clear()
	initialize_paradise_apartments()
	spawn_source = ""
	stair_spawn_side = ""
	stair_direction = ""
	exit_spawn_x = 0.0
	saved_player_x = 0.0
	saved_player_y = 0.0
	killed_zombies.clear()
	zombie_positions.clear()
	world_drops.clear()
	door_states.clear()
	door_keys_consumed.clear()
	floor_states_seeded.clear()
	barricade_progress.clear()
	merchant_stock.clear()
	legendary_hold = {}
	legendary_just_purchased = false
	merchant_sales.clear()
	god_mode = false


func on_floor_arrived(floor_num: int) -> void:
	if floor_num in [25, 20, 15, 10, 5]:
		rest_available = true
	seed_floor_door_states(floor_num)


func add_to_inventory(item_id: String, amount: int = 0) -> bool:
	# Bank Notes stack: all money shares ONE slot ("Bank Notes xN"). An existing
	# stack absorbs pickups without consuming a slot. `amount` <= 0 rolls a small
	# scavenge bundle (5-15); sources with bigger bundles (Big Zombie, dense-tier
	# anchors) pass an explicit amount.
	# The Wallet (031) never enters the inventory: picking it up converts it
	# straight into the wallet HUD (no "use" step — the freed slot IS the reward).
	# Works even with a full inventory. If already unlocked (persists across runs),
	# a found wallet is just someone's cash: pocket a small bundle instead.
	if item_id == "031":
		if wallet_unlocked:
			return add_to_inventory("033", 5 + randi() % 11)
		unlock_wallet()
		return true
	if ItemData.get_item(item_id).get("is_money", false):
		var add_amount = amount
		if add_amount <= 0:
			add_amount = 5 + randi() % 11
		if wallet_unlocked:
			wallet_balance += add_amount
			HUD.update_wallet()
			return true
		for instance in inventory:
			if instance.item_id == item_id:
				instance.count += add_amount
				return true
		if inventory.size() >= MAX_INVENTORY_SLOTS:
			return false
		var money = ItemInstance.new()
		money.setup(item_id)
		money.count = add_amount
		inventory.append(money)
		return true
	# Bullets stack up to MAX_AMMO_PER_SLOT per slot: fill existing stacks
	# first, then open new slots. All-or-nothing — a bundle that can't fully
	# fit is refused, so no bullets silently vanish.
	if ItemData.get_item(item_id).get("is_ammo", false):
		var add_amount = max(amount, 1)
		var capacity = (MAX_INVENTORY_SLOTS - inventory.size()) * MAX_AMMO_PER_SLOT
		for instance in inventory:
			if instance.item_id == item_id:
				capacity += MAX_AMMO_PER_SLOT - instance.count
		if capacity < add_amount:
			return false
		for instance in inventory:
			if add_amount <= 0:
				break
			if instance.item_id == item_id and instance.count < MAX_AMMO_PER_SLOT:
				var fill = min(MAX_AMMO_PER_SLOT - instance.count, add_amount)
				instance.count += fill
				add_amount -= fill
		while add_amount > 0:
			var stack = ItemInstance.new()
			stack.setup(item_id)
			stack.count = min(add_amount, MAX_AMMO_PER_SLOT)
			add_amount -= stack.count
			inventory.append(stack)
		return true
	if inventory.size() >= MAX_INVENTORY_SLOTS:
		return false
	var instance = ItemInstance.new()
	instance.setup(item_id)
	inventory.append(instance)
	return true


func get_ammo_total() -> int:
	var total = 0
	for instance in inventory:
		if ItemData.get_item(instance.item_id).get("is_ammo", false):
			total += instance.count
	return total


func consume_ammo(count: int = 1) -> bool:
	# Spends bullets across stacks, freeing slots that empty out. Keeps the
	# HUD's selected slot pointing at the same item when indices shift.
	if get_ammo_total() < count:
		return false
	var remaining = count
	for i in range(inventory.size() - 1, -1, -1):
		if remaining <= 0:
			break
		if ItemData.get_item(inventory[i].item_id).get("is_ammo", false):
			var take = min(inventory[i].count, remaining)
			inventory[i].count -= take
			remaining -= take
			if inventory[i].count <= 0:
				inventory.remove_at(i)
				if HUD.selected_slot == i:
					HUD.selected_slot = -1
				elif HUD.selected_slot > i:
					HUD.selected_slot -= 1
	HUD.refresh_inventory()
	return true


func swap_inventory_slots(a: int, b: int) -> void:
	if a < 0 or a >= inventory.size() or b < 0 or b >= inventory.size() or a == b:
		return
	var tmp = inventory[a]
	inventory[a] = inventory[b]
	inventory[b] = tmp
	if HUD.selected_slot == a:
		HUD.selected_slot = b
	elif HUD.selected_slot == b:
		HUD.selected_slot = a


func move_inventory_slot_to_end(from: int) -> void:
	if from < 0 or from >= inventory.size() - 1:
		return
	var was_selected = HUD.selected_slot == from
	var inst = inventory[from]
	inventory.remove_at(from)
	inventory.append(inst)
	if was_selected:
		HUD.selected_slot = inventory.size() - 1
	elif HUD.selected_slot > from:
		HUD.selected_slot -= 1


func remove_from_inventory(slot_index: int) -> void:
	if slot_index >= 0 and slot_index < inventory.size():
		inventory.remove_at(slot_index)


func unlock_wallet() -> void:
	wallet_unlocked = true
	# Absorb any carried Bank Notes stack into the wallet, freeing its slot.
	for i in range(inventory.size() - 1, -1, -1):
		if ItemData.get_item(inventory[i].item_id).get("is_money", false):
			wallet_balance += inventory[i].count
			inventory.remove_at(i)
	HUD.refresh_inventory()
	HUD.update_wallet()
	HUD.show_feedback("Wallet acquired — cash no longer takes a slot.")


func get_money_total() -> int:
	var total = wallet_balance
	for instance in inventory:
		if ItemData.get_item(instance.item_id).get("is_money", false):
			total += instance.count
	return total


func spend_money(cost: int) -> bool:
	# Shop-ready: debits wallet first, then any carried stack. False if short.
	if get_money_total() < cost:
		return false
	var remaining = cost
	var from_wallet = min(wallet_balance, remaining)
	wallet_balance -= from_wallet
	remaining -= from_wallet
	if remaining > 0:
		for i in range(inventory.size() - 1, -1, -1):
			if ItemData.get_item(inventory[i].item_id).get("is_money", false):
				var take = min(inventory[i].count, remaining)
				inventory[i].count -= take
				remaining -= take
				if inventory[i].count <= 0:
					inventory.remove_at(i)
				if remaining <= 0:
					break
	HUD.refresh_inventory()
	HUD.update_wallet()
	return true


func get_merchant_stock(floor_num: int) -> Array:
	# Stock is rolled once per (run, floor) visit, then persisted — purchases
	# mutate the stored entries, and reloading a save can't reroll the shop.
	var key = str(current_run) + ":" + str(floor_num)
	if merchant_stock.has(key):
		return merchant_stock[key]

	var rng = RandomNumberGenerator.new()
	rng.seed = hash(str(master_seed) + "merchant" + str(floor_num) + str(current_run))
	var stock: Array = []

	# Legendary slot resolves first: an active hold overrides the roll so the
	# held item keeps appearing until its window runs out or it's purchased.
	var legendary_id = ""
	if int(legendary_hold.get("visits_left", 0)) > 0:
		legendary_id = legendary_hold["item_id"]
		legendary_hold["visits_left"] = int(legendary_hold["visits_left"]) - 1
	else:
		var chance = 0.25 if legendary_just_purchased else 0.35
		legendary_just_purchased = false
		if rng.randf() < chance:
			var ids = SHOP_LEGENDARY.keys()
			legendary_id = ids[rng.randi() % ids.size()]
			legendary_hold = {"item_id": legendary_id, "visits_left": LEGENDARY_HOLD_VISITS}

	# Max 6 slots per visit: a legendary claims one, squeezing the commons.
	var common_count = 3 if legendary_id != "" else 3 + (rng.randi() % 2)
	var quality_count = 1 + (rng.randi() % 2)
	stock.append_array(_roll_shop_band(SHOP_COMMON, common_count, "common", rng))
	stock.append_array(_roll_shop_band(SHOP_QUALITY, quality_count, "quality", rng))
	if legendary_id != "":
		stock.append({
			"item_id": legendary_id,
			"price": SHOP_LEGENDARY[legendary_id],
			"band": "legendary",
			"sold": false,
		})

	merchant_stock[key] = stock
	return stock


func _roll_shop_band(pool: Dictionary, count: int, band: String, rng: RandomNumberGenerator) -> Array:
	# Sample without replacement so one visit never shows duplicate wares.
	var ids = pool.keys()
	var result: Array = []
	for i in range(min(count, ids.size())):
		var pick = rng.randi() % ids.size()
		var item_id = ids[pick]
		ids.remove_at(pick)
		result.append({
			"item_id": item_id,
			"price": pool[item_id],
			"band": band,
			"sold": false,
		})
	return result


func reload_gun(gun: ItemInstance) -> int:
	# Moves bullets from inventory stacks into the gun's magazine, up to its
	# cap (smaller when damaged). Returns rounds loaded.
	var space = gun.get_mag_cap() - gun.mag_count
	if space <= 0:
		return 0
	var available = get_ammo_total()
	var to_load = min(space, available)
	if to_load <= 0:
		return 0
	consume_ammo(to_load)
	gun.mag_count += to_load
	HUD.refresh_inventory()
	return to_load


# --- Selling to the merchant (max SELL_LIMIT_PER_VISIT items per visit) ---
const SELL_LIMIT_PER_VISIT = 3
const SELL_JUNK_PRICE = 4
var merchant_sales: Dictionary = {}  # "run:floor" -> items sold this visit


func get_sales_remaining(floor_num: int) -> int:
	var key = str(current_run) + ":" + str(floor_num)
	return SELL_LIMIT_PER_VISIT - int(merchant_sales.get(key, 0))


func get_sell_price(item_id: String) -> int:
	# Roughly 40% of shop value; junk has a floor price so clearing it out
	# is worth the trip but never worth farming.
	if SHOP_COMMON.has(item_id):
		return max(int(SHOP_COMMON[item_id] * 0.4), 5)
	if SHOP_QUALITY.has(item_id):
		return int(SHOP_QUALITY[item_id] * 0.4)
	if SHOP_LEGENDARY.has(item_id):
		return int(SHOP_LEGENDARY[item_id] * 0.4)
	var d = ItemData.get_item(item_id)
	if d.get("is_junk", false):
		return SELL_JUNK_PRICE
	if d.get("is_ammo", false):
		return 2  # per stack entry; stacks sell whole
	if d.get("is_key", false) or d.get("is_money", false):
		return 0  # not sellable
	return 10


func sell_item(slot_index: int, floor_num: int) -> bool:
	if slot_index < 0 or slot_index >= inventory.size():
		return false
	if get_sales_remaining(floor_num) <= 0:
		return false
	var instance = inventory[slot_index]
	var price = get_sell_price(instance.item_id)
	if price <= 0:
		return false
	if ItemData.get_item(instance.item_id).get("is_ammo", false):
		price *= instance.count
	inventory.remove_at(slot_index)
	if HUD.selected_slot == slot_index:
		HUD.selected_slot = -1
	elif HUD.selected_slot > slot_index:
		HUD.selected_slot -= 1
	if wallet_unlocked:
		wallet_balance += price
	else:
		add_to_inventory("033", price)
	var key = str(current_run) + ":" + str(floor_num)
	merchant_sales[key] = int(merchant_sales.get(key, 0)) + 1
	HUD.refresh_inventory()
	HUD.update_wallet()
	return true


func emit_noise(pos: Vector2, radius: float, duration: float = 1.0) -> void:
	# Central noise event: every living zombie within the radius is alerted
	# (their detection range opens up for the duration — see alert_to_noise).
	var tree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	for z in tree.get_nodes_in_group("zombie"):
		if not z.is_dead and z.has_method("alert_to_noise"):
			if z.global_position.distance_to(pos) <= radius:
				z.alert_to_noise(duration)


# --- Listen reads (press R at a door / down-stairwell) ---
# Reports are TRUE: they come from the same seeds that spawn the enemies,
# minus anything already killed there. Categories are a fixed vocabulary so
# players learn exactly what each line means.

func _listen_category(count: int, has_big: bool) -> String:
	if has_big:
		return "big"
	if count <= 0:
		return "none"
	elif count == 1:
		return "one"
	elif count <= 3:
		return "few"
	return "many"


const LISTEN_LINES_APARTMENT = {
	"none": "...Silent. Nothing moving in there.",
	"one": "Something's shuffling in there. Just one, I think.",
	"few": "More than one... two, maybe three.",
	"many": "It's crawling in there. Too many.",
	"big": "Something big is moving in there... and it's not alone.",
}
const LISTEN_LINES_BELOW = {
	"none": "Nothing moving down there.",
	"one": "Something's moving below. Just one, I think.",
	"few": "A few of them below. I can hear them pacing.",
	"many": "The floor below is crawling with them.",
	"big": "Something heavy is dragging around down there.",
}


func get_listen_report_for_apartment(apt_id: String) -> Dictionary:
	var has_big = get_door_state(apt_id) == DoorState.BREACHED
	var count: int
	if has_big:
		# Breach rooms are horde+boss by construction — read as many + big.
		count = 4
	else:
		count = get_apartment_zombie_count(apt_id)
	for key in killed_zombies:
		var entry = killed_zombies[key]
		if entry.get("apartment_id", "") == apt_id and str(entry.get("scene", "")).contains("room"):
			count -= 1
			if entry.get("type", "") == "big":
				has_big = false
	count = max(count, 0)
	var category = _listen_category(count, has_big)
	return {
		"count": count,
		"has_big": has_big,
		"category": category,
		"line": LISTEN_LINES_APARTMENT[category],
		"nearness": get_listen_nearness("apartment", apt_id),
	}


func get_listen_report_for_floor_below() -> Dictionary:
	var below = current_floor - 1
	if below < 1:
		return {"count": 0, "has_big": false, "category": "none",
			"line": "...The lobby. Almost out.", "nearness": 0.5}
	var count = get_floor_zombie_count(below)
	for key in killed_zombies:
		var entry = killed_zombies[key]
		if int(entry.get("floor", -1)) == below and str(entry.get("scene", "")).contains("building_floors"):
			count -= 1
	count = max(count, 0)
	var category = _listen_category(count, false)
	return {
		"count": count,
		"has_big": false,
		"category": category,
		"line": LISTEN_LINES_BELOW[category],
		"nearness": get_listen_nearness("floor_below", str(below)),
	}


func get_listen_nearness(kind: String, id: String) -> float:
	# Seeded 0..1 "how close to the door/stairs the noise sits" — drives ping
	# tempo (1.0 = right at the entrance = fast pings). Deterministic per
	# target per run until interiors get fully pre-simulated positions.
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(str(master_seed) + "listennear" + kind + id + str(current_run))
	return rng.randf()


func mark_shop_item_sold(floor_num: int, stock_index: int) -> void:
	var key = str(current_run) + ":" + str(floor_num)
	if not merchant_stock.has(key):
		return
	if stock_index < 0 or stock_index >= merchant_stock[key].size():
		return
	var entry = merchant_stock[key][stock_index]
	entry["sold"] = true
	if entry["band"] == "legendary":
		legendary_hold = {}
		legendary_just_purchased = true


func get_item_id_at(slot_index: int) -> String:
	if slot_index < 0 or slot_index >= inventory.size():
		return ""
	return inventory[slot_index].item_id


func get_instance_at(slot_index: int) -> ItemInstance:
	if slot_index < 0 or slot_index >= inventory.size():
		return null
	return inventory[slot_index]


func mark_anchor_searched(apartment_id: String, anchor_name: String) -> void:
	var key = apartment_id + ":" + anchor_name
	searched_anchors[key] = true


func is_anchor_searched(apartment_id: String, anchor_name: String) -> bool:
	var key = apartment_id + ":" + anchor_name
	return searched_anchors.get(key, false)


func _get_apartment_rng(apartment_id: String) -> RandomNumberGenerator:
	var apt_rng := RandomNumberGenerator.new()
	apt_rng.seed = hash(str(master_seed) + apartment_id)
	return apt_rng


func get_entrance_side(apartment_id: String) -> String:
	var apt_rng = _get_apartment_rng(apartment_id)
	return "left" if apt_rng.randi() % 2 == 0 else "right"


func get_apartment_layout(apartment_id: String) -> Array:
	if apartment_layouts.has(apartment_id):
		return apartment_layouts[apartment_id]
	var apt_rng = _get_apartment_rng(apartment_id)
	apt_rng.randi()
	var pool = ROOM_POOL.duplicate()
	for i in range(pool.size() - 1, 0, -1):
		var j = apt_rng.randi() % (i + 1)
		var temp = pool[i]
		pool[i] = pool[j]
		pool[j] = temp
	var layout = [pool[0], pool[1], pool[2]]
	apartment_layouts[apartment_id] = layout
	return layout


func get_floor_zombie_count(floor_num: int) -> int:
	var rng = RandomNumberGenerator.new()
	rng.seed = (master_seed ^ (floor_num * 1000003)) & 0xFFFFFFFF
	var roll = rng.randf()
	if floor_num == 1:
		if roll < 0.05:
			return 0
		elif roll < 0.1:
			return 10
		else:
			return rng.randi() % 10 + 1
	elif floor_num <= 14:
		if roll < 0.08:
			return 0
		elif roll < 0.12:
			return 10
		elif roll < 0.18:
			return 6
		else:
			return rng.randi() % 5 + 1
	else:
		if roll < 0.08:
			return 0
		elif roll < 0.11:
			return 10
		elif roll < 0.17:
			return rng.randi() % 2 + 4
		else:
			return rng.randi() % 3 + 1


func get_apartment_zombie_count(apartment_id: String) -> int:
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(str(master_seed) + "zombies" + apartment_id)
	var roll = rng.randf()
	if roll < 0.30:
		return 0
	elif roll < 0.33:
		return 10
	else:
		return rng.randi() % 4 + 1


func get_zombie_positions(count: int, rng: RandomNumberGenerator, min_x: float, max_x: float, y: float) -> Array:
	var positions = []
	var huddle = rng.randf() < 0.4
	if huddle and count > 1:
		var center_x = rng.randf_range(min_x + 100, max_x - 100)
		var radius = rng.randf_range(40, 120)
		for i in range(count):
			var offset = rng.randf_range(-radius, radius)
			positions.append(Vector2(clamp(center_x + offset, min_x, max_x), y))
	else:
		for i in range(count):
			positions.append(Vector2(rng.randf_range(min_x, max_x), y))
	return positions


func get_corpse_positions_for_floor(floor_num: int, scene_path: String, apartment_id: String = "") -> Array:
	var result = []
	for key in killed_zombies:
		var data = killed_zombies[key]
		if data["floor"] == floor_num and data["scene"] == scene_path:
			if apartment_id != "" and data.get("apartment_id", "") != apartment_id:
				continue
			result.append({"pos": Vector2(data["x"], data["y"]), "type": data.get("type", "standard")})
	return result


func initialize_paradise_apartments() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(str(master_seed) + "paradise")
	var count = rng.randi() % 3 + 1
	var all_apartments = []
	for floor_num in range(2, 30):
		for apt in ["01", "02", "03", "04", "05"]:
			all_apartments.append(str(floor_num) + apt)
	for i in range(all_apartments.size() - 1, 0, -1):
		var j = rng.randi() % (i + 1)
		var temp = all_apartments[i]
		all_apartments[i] = all_apartments[j]
		all_apartments[j] = temp
	paradise_apartments = all_apartments.slice(0, count)


func is_paradise_apartment(apartment_id: String) -> bool:
	return apartment_id in paradise_apartments


func get_room_type_for_anchor(anchor_name: String, apartment_id: String) -> String:
	var layout = get_apartment_layout(apartment_id)
	for room_type in layout:
		var anchors = get_anchors_for_room(room_type)
		if anchor_name in anchors:
			return room_type
	return ""


func get_anchors_for_room(room_type: String) -> Array:
	match room_type:
		"bedroom":
			return ["anchor_wall_left", "anchor_floor_underbed", "anchor_wall_right_lower", "anchor_bed_pillow", "anchor_wall_right_upper", "anchor_bedside"]
		"bathroom":
			return ["anchor_wall_sink", "anchor_wall_cabinet", "anchor_centre_toilet", "anchor_bath_left", "anchor_bath_right", "anchor_wall_shower", "anchor_floor_laundrybag"]
		"kitchen":
			return ["anchor_centre_fridge", "anchor_right_trashcan", "anchor_left_cupboard", "anchor_centre_cupboard", "anchor_centre_oven", "anchor_right_sink", "anchor_right_sinkcupboard"]
		"dining_room":
			return ["anchor_table_left", "anchor_table_right", "anchor_right_upperdrawers", "anchor_right_lowerdrawers"]
		"living_room":
			return ["anchor_left_bookshelf_upper", "anchor_centre_sofaleft", "anchor_centre_sofaright", "anchor_right_chair", "anchor_centre_coffeetable", "anchor_left_bookshelf_lower"]
		"study":
			return ["anchor_centre_bookcaseupper", "anchor_centre_bookcaselower", "anchor_centre_desk", "anchor_right_shelf"]
	return []


func get_items_for_anchor(anchor_name: String, apartment_id: String) -> Array:
	var room_type = get_room_type_for_anchor(anchor_name, apartment_id)
	if room_type == "":
		return []
	var valid_items = []
	var spawn_pools = ItemData.room_spawn_pools
	for item_name in spawn_pools:
		var pool = spawn_pools[item_name]
		var weight = pool.get(room_type, 0)
		if weight > 0:
			var item_id = ItemData.get_item_id_by_name(item_name)
			if item_id != "":
				for i in range(weight):
					valid_items.append(item_id)
	return valid_items


# High enemy density means the player will likely burn through weapons and ammo
# in the fight, so weight the pool toward weapons and bullets, and thin out junk.
# `tier` scales the effect: 0 = quiet room (no change), 1-3 = increasing density.
# Deterministic — only changes pool contents, not the RNG draw sequence at the call site.
func get_items_for_anchor_weighted(anchor_name: String, apartment_id: String, tier: int) -> Array:
	var base = get_items_for_anchor(anchor_name, apartment_id)
	if tier <= 0 or base.is_empty():
		return base

	var extra_combat_copies = tier        # weapons/ammo duplicated this many times
	var keep_junk = tier < 3              # at the highest tier, drop junk entirely

	var weighted = []
	for item_id in base:
		var d = ItemData.get_item(item_id)
		if d.get("is_junk", false):
			# Thin junk: include roughly half (or none at top tier).
			if keep_junk and (weighted.size() % 2 == 0):
				weighted.append(item_id)
			continue
		weighted.append(item_id)
		if d.get("is_weapon", false) or d.get("is_ammo", false):
			for i in range(extra_combat_copies):
				weighted.append(item_id)

	# Guard against an all-junk room thinning to empty.
	if weighted.is_empty():
		return base
	return weighted


func set_anchor_item(apartment_id: String, anchor_name: String, item_id: String) -> void:
	var key = apartment_id + ":" + anchor_name
	anchor_items[key] = item_id


func get_anchor_item(apartment_id: String, anchor_name: String) -> String:
	var key = apartment_id + ":" + anchor_name
	return anchor_items.get(key, "")


func clear_anchor_item(apartment_id: String, anchor_name: String) -> void:
	var key = apartment_id + ":" + anchor_name
	anchor_items.erase(key)


# ============================================================
# DOOR SYSTEM
# ============================================================

func _get_door_weights(run_num: int) -> Array:
	match run_num:
		1: return [0, 40, 28, 14, 10, 8]
		2: return [0, 30, 24, 16, 12, 18]
		3: return [0, 22, 20, 16, 12, 30]
	return [0, 40, 28, 14, 10, 8]


func _pick_door_state(rng: RandomNumberGenerator, weights: Array) -> int:
	var total = 0
	for w in weights:
		total += w
	var roll = rng.randi() % total
	var cumulative = 0
	for i in range(weights.size()):
		cumulative += weights[i]
		if roll < cumulative:
			return i
	return DoorState.SHUT_FORCEABLE


func seed_floor_door_states(floor_num: int) -> void:
	# Floor 30 is the tutorial floor — door states are hardcoded, never randomised
	if floor_num == 30:
		if not door_states.has("3002"):
			door_states["3002"] = DoorState.SHUT_LOCKED
		if not door_states.has("3003"):
			door_states["3003"] = DoorState.OPEN
		if not door_states.has("3004"):
			door_states["3004"] = DoorState.BARRICADED_LOCKED
		if not door_states.has("3005"):
			door_states["3005"] = DoorState.OPEN
		floor_states_seeded[30] = true
		return

	if floor_states_seeded.get(floor_num, false):
		return
	floor_states_seeded[floor_num] = true

	var rng = RandomNumberGenerator.new()
	rng.seed = hash(str(master_seed) + "doors" + str(floor_num) + str(current_run))

	var apartments = []
	for i in range(1, 6):
		apartments.append(str(floor_num) + "0" + str(i))

	for i in range(apartments.size() - 1, 0, -1):
		var j = rng.randi() % (i + 1)
		var temp = apartments[i]
		apartments[i] = apartments[j]
		apartments[j] = temp

	var open_count = 1 + (rng.randi() % 2)
	for i in range(open_count):
		var apt_id = apartments[i]
		if not door_states.has(apt_id):
			door_states[apt_id] = DoorState.OPEN

	var weights = _get_door_weights(current_run)
	for i in range(open_count, apartments.size()):
		var apt_id = apartments[i]
		if not door_states.has(apt_id):
			door_states[apt_id] = _pick_door_state(rng, weights)


func get_door_state(apartment_id: String) -> int:
	var floor_num = int(apartment_id.left(apartment_id.length() - 2))
	seed_floor_door_states(floor_num)
	return door_states.get(apartment_id, DoorState.SHUT_FORCEABLE)


func set_door_state(apartment_id: String, state: int) -> void:
	door_states[apartment_id] = state


func consume_key_for_apartment(apartment_id: String) -> void:
	door_keys_consumed[apartment_id] = true
	set_door_state(apartment_id, DoorState.OPEN)


func mutate_door_states_for_new_run() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(str(master_seed) + "mutate" + str(current_run))

	for apt_id in door_states.keys():
		var state = door_states[apt_id]
		var roll = rng.randf()

		match state:
			DoorState.SHUT_FORCEABLE:
				if roll < 0.15:
					door_states[apt_id] = DoorState.BREACHED
			DoorState.SHUT_LOCKED:
				if roll < 0.12:
					door_states[apt_id] = DoorState.BREACHED
				elif roll < 0.14:
					door_states[apt_id] = DoorState.SHUT_FORCEABLE
			DoorState.BARRICADED_FORCEABLE:
				if roll < 0.20:
					door_states[apt_id] = DoorState.SHUT_FORCEABLE
				elif roll < 0.25:
					door_states[apt_id] = DoorState.BREACHED
			DoorState.BARRICADED_LOCKED:
				if roll < 0.15:
					door_states[apt_id] = DoorState.SHUT_LOCKED
				elif roll < 0.20:
					door_states[apt_id] = DoorState.BREACHED
			DoorState.OPEN:
				pass
			DoorState.BREACHED:
				pass

	floor_states_seeded.clear()
	barricade_progress.clear()


func is_locked_apartment(apartment_id: String) -> bool:
	var state = get_door_state(apartment_id)
	return state == DoorState.SHUT_LOCKED or state == DoorState.BARRICADED_LOCKED


func was_key_opened(apartment_id: String) -> bool:
	return door_keys_consumed.get(apartment_id, false)


func get_breached_room_enemies(apartment_id: String, min_x: float, max_x: float, y: float) -> Array:
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(str(master_seed) + "breached" + apartment_id + str(current_run))

	var count = 4 + (rng.randi() % 6)

	var enemies = []
	var center_x = rng.randf_range(min_x + 60, min_x + 200)
	var spread = rng.randf_range(60, 200)

	for i in range(count):
		var pos_x = clamp(center_x + rng.randf_range(-spread, spread), min_x, max_x)
		enemies.append({
			"type": "zombie_standard",
			"position": Vector2(pos_x, y)
		})

	return enemies


# ============================================================
# KEY SYSTEM
# ============================================================

func get_key_target_for_anchor(floor_num: int, anchor_name: String) -> String:
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(str(master_seed) + "key" + str(floor_num) + anchor_name)
	
	# Build candidates — only locked rooms that actually need a key
	var candidates = []
	for f in range(max(2, floor_num - 5), min(29, floor_num + 5) + 1):
		for i in range(1, 6):
			var apt = str(f) + "0" + str(i)
			var state = get_door_state(apt)
			if state == DoorState.SHUT_LOCKED or state == DoorState.BARRICADED_LOCKED:
				candidates.append(apt)
	
	if candidates.is_empty():
		# Fallback — pick a nearby floor apt, hope for the best
		var offset = 4 + (rng.randi() % 2)
		var direction = 1 if rng.randf() < 0.5 else -1
		var target_floor = clamp(floor_num + (offset * direction), 2, 29)
		return str(target_floor) + "0" + str((rng.randi() % 5) + 1)
	
	return candidates[rng.randi() % candidates.size()]

func should_anchor_spawn_key(apartment_id: String, anchor_name: String) -> bool:
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(str(master_seed) + "keyspawn" + apartment_id + anchor_name)
	# Base 3% per anchor. High-density apartments raise this — clearing a horde
	# should carry a real (if modest) shot at a key, below a breached/boss room's
	# guaranteed boss key but enough to make the fight worth attempting.
	var chance = 0.03
	var zcount = get_apartment_zombie_count(apartment_id)
	if zcount >= 10:
		chance = 0.10
	elif zcount >= 3:
		chance = 0.06
	return rng.randf() < chance


func add_key_to_inventory(target_apartment: String) -> bool:
	# Refuse if a key for this apartment already exists
	for instance in inventory:
		if instance.target_apartment == target_apartment:
			return true  # already have it — silently succeed, don't duplicate
	if inventory.size() >= MAX_INVENTORY_SLOTS:
		return false
	var instance = ItemInstance.new()
	instance.setup_key("022", target_apartment)
	inventory.append(instance)
	return true


func get_key_target_at(slot_index: int) -> String:
	if slot_index < 0 or slot_index >= inventory.size():
		return ""
	return inventory[slot_index].target_apartment


func set_anchor_key(apartment_id: String, anchor_name: String, target_apartment: String) -> void:
	var key = apartment_id + ":" + anchor_name
	anchor_items[key] = "KEY:" + target_apartment


func get_anchor_key_target(apartment_id: String, anchor_name: String) -> String:
	var key = apartment_id + ":" + anchor_name
	var val = anchor_items.get(key, "")
	if val.begins_with("KEY:"):
		return val.substr(4)
	return ""


func is_anchor_a_key(apartment_id: String, anchor_name: String) -> bool:
	var key = apartment_id + ":" + anchor_name
	return anchor_items.get(key, "").begins_with("KEY:")


func get_breached_boss_key_target(apartment_id: String) -> String:
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(str(master_seed) + "bosskey" + apartment_id)
	var floor_num = int(apartment_id.left(apartment_id.length() - 2))
	
	# Build a list of locked apartments to target
	var candidates = []
	for f in range(max(2, floor_num - 5), min(29, floor_num + 5) + 1):
		for i in range(1, 6):
			var apt = str(f) + "0" + str(i)
			var state = get_door_state(apt)
			if state == DoorState.SHUT_LOCKED or state == DoorState.BARRICADED_LOCKED or state == DoorState.BARRICADED_FORCEABLE:
				candidates.append(apt)
	
	if candidates.is_empty():
		# Fallback — just pick any locked-ish apt on a nearby floor
		var offset = 1 + (rng.randi() % 3)
		var target_floor = clamp(floor_num + offset, 2, 29)
		return str(target_floor) + "0" + str((rng.randi() % 5) + 1)
	
	return candidates[rng.randi() % candidates.size()]


# ============================================================
# WORLD DROPS
# ============================================================
# Persisted pickups — boss drops (inventory full), zombie loot, discarded items.

func add_world_drop(item_id: String, pos: Vector2, floor_num: int, extra: Dictionary = {}) -> void:
	var key = str(floor_num) + ":" + str(snappedf(pos.x, 1.0)) + ":" + str(snappedf(pos.y, 1.0))
	world_drops[key] = {
		"item_id": item_id,
		"x": snappedf(pos.x, 1.0),
		"y": snappedf(pos.y, 1.0),
		"floor": floor_num,
		"scene": extra.get("scene", get_tree().current_scene.scene_file_path),
		"apartment_id": extra.get("apartment_id", current_apartment_id),
		"target_apartment": extra.get("target_apartment", ""),
		"amount": extra.get("amount", 0)
	}


func remove_world_drop(drop_key: String) -> void:
	world_drops.erase(drop_key)


func get_world_drops_for_floor(floor_num: int, scene_path: String = "", apartment_id: String = "") -> Dictionary:
	var result: Dictionary = {}
	for key in world_drops:
		var data = world_drops[key]
		if data["floor"] != floor_num:
			continue
		# Scene filtering — a drop belongs to the scene it was made in. Older saves
		# may lack a "scene" field; treat those as floor-only (legacy behaviour).
		if scene_path != "" and data.get("scene", "") != "" and data["scene"] != scene_path:
			continue
		# Apartment filtering — only applied when caller passes an apartment_id
		# (i.e. inside a room). Hallways/lobbies pass "" and skip this check.
		if apartment_id != "" and data.get("apartment_id", "") != apartment_id:
			continue
		result[key] = data
	return result


# ============================================================
# ZOMBIE LOOT
# ============================================================
# ~18% chance on standard zombie death. Biased toward consumables.

const ZOMBIE_LOOT_POOL = [
	"006", "006", "006",  # Bandages      weight 3
	"007", "007",         # First Aid Kit weight 2
	"009", "009",         # Ice Pack      weight 2
	"010",                # Painkillers   weight 1
	"011",                # Adrenaline    weight 1
	"033", "033", "033",  # Bank Notes    weight 3 (bundle rolled at pickup)
]
const ZOMBIE_LOOT_CHANCE = 0.18


func roll_zombie_loot_id(pos: Vector2, floor_num: int) -> String:
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(str(master_seed) + "zloot" + str(snappedf(pos.x, 1.0)) + str(floor_num))
	if rng.randf() > ZOMBIE_LOOT_CHANCE:
		return ""
	var item_id = ZOMBIE_LOOT_POOL[rng.randi() % ZOMBIE_LOOT_POOL.size()]
	add_world_drop(item_id, pos, floor_num)
	return item_id


# ============================================================
# SAVE / LOAD
# ============================================================

const SAVE_PATH = "user://savegame.json"

func save_game(scene_path: String) -> void:
	# Snapshot live zombie positions in the current scene so reloading can't be
	# used to reset an encounter (save-scum lure exploit). Dead zombies are
	# already covered by killed_zombies; tutorial zombies without a spawn_key
	# are skipped.
	var tree = Engine.get_main_loop() as SceneTree
	if tree:
		for z in tree.get_nodes_in_group("zombie"):
			if not z.is_dead and z.spawn_key != "":
				zombie_positions[z.spawn_key] = {
					"x": snappedf(z.global_position.x, 1.0),
					"y": snappedf(z.global_position.y, 1.0)
				}
	var save_data = {
		"scene_path": scene_path,
		"master_seed": master_seed,
		"current_floor": current_floor,
		"current_apartment_id": current_apartment_id,
		"spawn_source": spawn_source,
		"stair_spawn_side": stair_spawn_side,
		"stair_direction": stair_direction,
		"exit_spawn_x": exit_spawn_x,
		"is_first_run": is_first_run,
		"current_run": current_run,
		"player_health": player_health,
		"is_dying": is_dying,
		"dying_timer": dying_timer,
		"is_scavenge_mode": is_scavenge_mode,
		"stamina": stamina,
		"max_stamina": max_stamina,
		"last_rest_floor": last_rest_floor,
		"rest_available": rest_available,
		"rest_count": rest_count,
		"paradise_apartments": paradise_apartments,
		"anchor_items": anchor_items,
		"searched_anchors": searched_anchors,
		"apartment_layouts": apartment_layouts,
		"active_upgrades": active_upgrades,
		"inventory": _serialize_inventory(),
		"tutorial_zombie_spawned": tutorial_zombie_spawned,
		"last_exited_apartment": last_exited_apartment,
		"saved_player_x": saved_player_x,
		"saved_player_y": saved_player_y,
		"killed_zombies": killed_zombies,
		"world_drops": world_drops,
		"door_states": door_states,
		"door_keys_consumed": door_keys_consumed,
		"floor_states_seeded": floor_states_seeded,
		"zombie_positions": zombie_positions,
		"wallet_unlocked": wallet_unlocked,
		"wallet_balance": wallet_balance,
		"barricade_progress": barricade_progress,
		"merchant_stock": merchant_stock,
		"legendary_hold": legendary_hold,
		"legendary_just_purchased": legendary_just_purchased,
		"merchant_sales": merchant_sales,
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()


func load_game() -> String:
	if not FileAccess.file_exists(SAVE_PATH):
		return ""
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return ""
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	file.close()
	if error != OK:
		return ""
	var data = json.get_data()
	master_seed = data["master_seed"]
	current_floor = data["current_floor"]
	current_apartment_id = data["current_apartment_id"]
	spawn_source = data["spawn_source"]
	stair_spawn_side = data["stair_spawn_side"]
	stair_direction = data["stair_direction"]
	exit_spawn_x = data["exit_spawn_x"]
	is_first_run = data["is_first_run"]
	current_run = data["current_run"]
	player_health = data["player_health"]
	is_dying = data["is_dying"]
	dying_timer = data["dying_timer"]
	is_scavenge_mode = data["is_scavenge_mode"]
	stamina = data["stamina"]
	max_stamina = data["max_stamina"]
	last_rest_floor = data["last_rest_floor"]
	rest_available = data["rest_available"]
	rest_count = data["rest_count"]
	paradise_apartments = data["paradise_apartments"]
	anchor_items = data["anchor_items"]
	searched_anchors = data["searched_anchors"]
	apartment_layouts = data["apartment_layouts"]
	active_upgrades = data["active_upgrades"]
	tutorial_zombie_spawned = data["tutorial_zombie_spawned"]
	last_exited_apartment = data["last_exited_apartment"]
	saved_player_x = data["saved_player_x"]
	saved_player_y = data["saved_player_y"]
	killed_zombies = data["killed_zombies"]
	world_drops = data.get("world_drops", {})
	door_states = data["door_states"]
	door_keys_consumed = data["door_keys_consumed"]
	# JSON round-trips all dictionary keys as strings; this dict is keyed by int
	# floor numbers, so convert keys back or every loaded game re-seeds its floors.
	zombie_positions = data.get("zombie_positions", {})
	wallet_unlocked = data.get("wallet_unlocked", false)
	wallet_balance = int(data.get("wallet_balance", 0))
	floor_states_seeded = {}
	for k in data["floor_states_seeded"]:
		floor_states_seeded[int(k)] = data["floor_states_seeded"][k]
	barricade_progress = data.get("barricade_progress", {})
	# JSON round-trips ints as floats; normalise so loaded stock is
	# type-identical to freshly generated stock.
	merchant_stock = {}
	for k in data.get("merchant_stock", {}):
		var entries: Array = []
		for e in data["merchant_stock"][k]:
			entries.append({
				"item_id": str(e["item_id"]),
				"price": int(e["price"]),
				"band": str(e["band"]),
				"sold": bool(e["sold"]),
			})
		merchant_stock[k] = entries
	legendary_hold = data.get("legendary_hold", {})
	if not legendary_hold.is_empty():
		legendary_hold["visits_left"] = int(legendary_hold.get("visits_left", 0))
	legendary_just_purchased = bool(data.get("legendary_just_purchased", false))
	merchant_sales = data.get("merchant_sales", {})
	_deserialize_inventory(data["inventory"])
	return data["scene_path"]


func save_exists() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


func _serialize_inventory() -> Array:
	var result = []
	for instance in inventory:
		result.append({
			"item_id": instance.item_id,
			"current_durability": instance.current_durability,
			"is_depleted": instance.is_depleted,
			"target_apartment": instance.target_apartment,
			"count": instance.count,
			"mag_count": instance.mag_count,
			"is_damaged": instance.is_damaged,
		})
	return result


func _deserialize_inventory(data: Array) -> void:
	inventory.clear()
	for entry in data:
		var instance = ItemInstance.new()
		instance.item_id = entry["item_id"]
		instance.current_durability = entry["current_durability"]
		instance.is_depleted = entry["is_depleted"]
		instance.target_apartment = entry.get("target_apartment", "")
		instance.count = int(entry.get("count", 1))
		instance.mag_count = int(entry.get("mag_count", 0))
		instance.is_damaged = bool(entry.get("is_damaged", false))
		inventory.append(instance)
