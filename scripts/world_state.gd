extends Node

const ROOM_POOL = ["bedroom", "bathroom", "study", "kitchen", "living_room", "dining_room"]
# Balcony rooms live only in study/dining modules. A balcony must always have a
# balcony room directly below it (THREE_RUN_ARC balcony rule), so balconies are
# seeded per APARTMENT COLUMN (not per apartment): a fraction of columns are
# "balcony columns", and in one — the same seeded interior slot on EVERY floor —
# generation forces a study or dining room. Column-only seeding makes the balcony
# a continuous vertical stack, so every balcony (except floor 1) has one below.
const BALCONY_ROOMS = ["study", "dining_room"]
const BALCONY_COLUMN_CHANCE = 0.5
# Balconies come in vertical PAIRS, never stacks: a descendable "top" balcony has
# exactly one partner "bottom" balcony directly below it, and descending is
# one-and-done (the bottom is a dead-end, even if the seed puts another balcony
# further down). Tops in a column are spaced >= this many floors apart so pairs
# never touch — a bottom is never also a top.
const BALCONY_PAIR_PERIOD = 6
# Descending a balcony: the climb costs stamina, and doing it tired risks losing
# grip and falling the rest of the way (a lighter injury than a deliberate jump).
const BALCONY_STAMINA_COST = 25.0
const BALCONY_SLIP_SAFE = 0.60          # stamina fraction at/above which the climb is safe
const BALCONY_SLIP_MODERATE = 0.30      # between this and SAFE: a moderate slip chance
const BALCONY_SLIP_CHANCE_MODERATE = 0.35
const BALCONY_SLIP_CHANCE_HIGH = 0.70   # below MODERATE stamina
# A lashed rope stays tied to the balcony (persists), so re-descending — this run
# or a later one — needs no rope. Keyed "apartmentId:slot".
var roped_balconies: Dictionary = {}
# The no-rope jump warning is a one-time teach: it fires ONCE per run the first
# time the player tries a bare drop, then never again that run (per-run flag).
var balcony_jump_warned: bool = false
# One-time-per-game context line the first time the player enters a CHARRED (burnt-out)
# apartment, so the empty ruin reads as "the fire got here first", not a broken room.
var charred_intro_shown: bool = false
# Transient hand-off across the descent scene swap: a hard landing sets this so
# the arriving player can flash the hurt pose. Consumed on arrival (room.gd).
var balcony_arrival_hurt: bool = false
# The injury a descent will spend AT TOUCHDOWN (BalconyPan applies it then, so
# the HP/portrait drop is synced with the hurt flare, not the fall's start).
var balcony_pending_injury: int = 0
const MAX_INVENTORY_SLOTS = 5
const MAX_AMMO_PER_SLOT = 8
const MAX_THROWABLE_PER_SLOT = 3   # cans held per slot (was one-and-done)
const CAN_SCAVENGE_BOOST = 1.18    # cans spawn 18% more, so they're a real option
const CLOTHES_BEDROOM_BOOST = 1.30 # clothes +30% in bedrooms (3 make a clothes-rope)

var master_seed: int = 0
var current_apartment_id: String = ""
var apartment_layouts: Dictionary = {}
var exit_spawn_x: float = 0.0
var stair_spawn_side: String = ""
var current_floor: int = 30
var stair_direction: String = ""
var spawn_source: String = ""
var is_first_run: bool = true
# --- PLAYER PROFILE -------------------------------------------------------
# Deliberately NOT part of savegame.json: the save is one playthrough, the
# profile is the person. It records that this player has already been taught the
# game, so pressing Play in the editor (or starting a fresh game) no longer
# replays the Floor 30 tutorial for someone who has seen it. Lives beside
# keybinds.cfg in user://.
const SLOT_COUNT := 3
var active_slot: int = 1

# Per-slot files. The SAVE is one playthrough; the PROFILE is the player behind
# it — runs attempted, runs survived, whether they have been taught the game —
# plus a small mirror of the save's headline facts (floor, which run of the
# arc) so the select screen can describe a slot without parsing its save JSON.
func profile_path(slot: int = -1) -> String:
	return "user://slot_%d_profile.cfg" % (active_slot if slot < 0 else slot)


func slot_save_path(slot: int = -1) -> String:
	return "user://slot_%d_save.json" % (active_slot if slot < 0 else slot)


var tutorial_completed: bool = false
var runs_made: int = 0
var runs_successful: int = 0
# Wall-clock time actually spent playing this profile. Ticks only while the HUD
# is up, so menus and the profile screen do not inflate it.
var playtime_seconds: float = 0.0
# Fate of each survivor in the three-run arc, indexed 0..2 (morning / afternoon
# / evening): "" not yet played, "alive" the one in progress, "survived" made it
# out, "dead" did not. This is what the three portrait boxes on a profile card
# read from.
var run_outcomes: Array = ["", "", ""]


func set_run_outcome(run_index: int, outcome: String) -> void:
	var i: int = clampi(run_index - 1, 0, 2)
	run_outcomes[i] = outcome
	save_profile()


func current_survivor_state() -> Array:
	# The array as the card should show it: the run in progress reads "alive"
	# even before it has an outcome of its own.
	var out: Array = run_outcomes.duplicate()
	var i: int = clampi(current_run - 1, 0, 2)
	if String(out[i]) == "":
		out[i] = "alive"
	return out
# Session-only: makes the "who does the game think I am" notice appear once.
var profile_announced: bool = false
# First-run opener (locked-out cold open) — plays once at the start of run 1;
# reset by new_game() and the F7 dev tutorial reset so it can replay.
var opener_seen: bool = false
# Tutorial: the first Floor-29 apartment guarantees a melee weapon, once.
var tutorial_f29_weapon_granted: bool = false
var tutorial_zombie_spawned: bool = false
var last_exited_apartment: int = 0
var current_run: int = 1
var paradise_apartments: Array = []
var anchor_items: Dictionary = {}
# Pinned pickup amount for an anchor (money/ammo), keyed "apt:anchor". Used by
# the scripted tutorial rooms to hand out exact counts (e.g. "10 cash"); absent
# = roll a random bundle as normal.
var anchor_amounts: Dictionary = {}
var searched_anchors: Dictionary = {}
# True while the loot panel is open — the panel then owns input (take with E /
# click), so the room's anchor handling and the player's move/attack stand down.
var loot_open: bool = false
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
# A crowbar crossing that had no banked rest to burn sets this: the NEXT
# merchant-floor rest is forfeited instead (so a crossing always costs exactly
# one rest opportunity, wherever it happens). Per-run; saved/loaded.
var rest_forfeit_pending: bool = false
var active_upgrades: Array = []
var available_upgrades: Array = []
var saved_player_x: float = 0.0
var saved_player_y: float = 0.0
# Was the player standing OUT on a balcony plane at save time? The plane is
# stateful on the player (held Y line + depth scale), and the saved Y alone
# can't re-establish it — restored in room.gd on load. Consumed on restore.
var saved_on_balcony_plane: bool = false
var killed_zombies: Dictionary = {}
var world_drops: Dictionary = {}  # "floor:x:y" -> {item_id, x, y, floor, target_apartment}

# Dev tools
var god_mode: bool = false
# DEV (F2): CYCLE floor hazards one at a time (so they never overlap) —
#   0 off → 1 barricades → 2 hordes → 3 fire → back to 0 (seed defaults).
# Barricades (crowbar stairwell block), hordes (a stairwell packed with LIVE
# enemies) and fire (spreading blaze) are ALL built now. Session-only, like
# god_mode — not saved, reset by new_game.
const DEV_HAZARD_NONE := 0
const DEV_HAZARD_BARRICADE := 1
const DEV_HAZARD_HORDE := 2
const DEV_HAZARD_FIRE := 3        # fire lv1: origin floor LIGHT only
const DEV_HAZARD_FIRE2 := 4       # fire lv2: origin BLAZE + both neighbours LIGHT
const DEV_HAZARD_FIRE3 := 5       # fire lv3: origin CHARRED + neighbours BLAZE + two-out LIGHT
const DEV_HAZARD_COUNT := 6
const DEV_HAZARD_NAMES := ["off", "barricades", "hordes", "fire lv1", "fire lv2", "fire lv3"]
const DEV_HAZARD_UNBUILT := []   # barricades, hordes AND fire are all built now
var dev_hazard_mode: int = DEV_HAZARD_NONE
# When DEV fire is toggled on (F2), the floor it was pressed on becomes the single
# fire ORIGIN; dev fire_intensity spreads out from here by the age-distance model, so
# the dev cycle mirrors the real run-1/2/3 escalation. -1 = no dev origin.
var dev_fire_origin: int = -1
# A DEV message the next scene load should surface AFTER the god-mode reminder,
# so an F2 hazard toggle that rebuilds the floor isn't clobbered by it.
var pending_dev_feedback: String = ""

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

# --- Heavy stairwell hordes (crowbar crossing) ----------------------------
# A fraction of DOWN-stairwells are packed wall-to-wall with the dead: not a
# fight you win, a blockage you pry through with a Crowbar (035). Seeded per
# (floor, run) so it's stable on re-entry and shifts between the three runs.
# Floor 30 (tutorial) and floor 1 (the last step into the lobby) are never
# blocked. Crossing one is a channeled pry that consumes the crowbar, forfeits
# your next rest, and shifts the building (enemies move) — see docs.
const STAIR_BLOCK_CHANCE := 0.18
# Hazard 2: a stairwell packed with LIVE enemies (rolled after the barricade, so
# the two are mutually exclusive on the same stairwell).
const STAIR_HORDE_CHANCE := 0.15
# `str(floor)+":"+str(run)` -> true once its horde has been pried open (per-run).
var stair_blocks_cleared: Dictionary = {}

# --- Cross-floor noise pull ------------------------------------------------
# Significant noise (gunfire / forcing — NOT running) made close to a stairwell
# carries through it: the dead SEEDED NEAR that stairwell on the adjacent floor
# rouse and gather there, so they're milling by the steps when you arrive. It
# deliberately can't vacuum a whole floor up the stairs — only the stairwell-side
# few are eligible, and only if the noise was made near the stairwell.
const STAIR_NOISE_PULL_MIN := 420.0        # >= door_work; run (240) stays under it
const LEFT_STAIR_ZONE_X := 360.0           # noise left of this is "at the left stairwell"
const RIGHT_STAIR_ZONE_X := 1010.0         # noise right of this is "at the right stairwell"
# A seeded zombie within this of a corridor end counts as seeded near that stair.
const STAIR_PULL_NEAR := 150.0
# "floor:run" -> true: the adjacent floor's stairwell-side dead are roused on arrival.
var pending_stair_pulls: Dictionary = {}

# --- Merchant / shop (docs/STORE_DESIGN.md) ---
const MERCHANT_FLOORS = [25, 20, 15, 10, 5]


# A MAINTENANCE room (docs/MAINTENANCE_ELEVATOR.md) sits by the elevator every third
# floor — its door is placed between the elevator and the right stairwell. Floors 3..27.
func is_maintenance_floor(floor_num: int) -> bool:
	return floor_num % 3 == 0 and floor_num >= 3 and floor_num <= 27


# Wall fire-extinguishers aren't on EVERY floor (like a real building — sometimes the
# nearest one is a floor or two away). Seeded per floor (stable across runs) so it's a
# fixed fact of the building, not a per-visit surprise. Maintenance floors NEVER have one
# (the door takes that wall) — it's on the player to go up/down for a canister.
const EXTINGUISHER_FLOOR_CHANCE := 0.6
func floor_has_extinguisher(floor_num: int) -> bool:
	if is_maintenance_floor(floor_num):
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(master_seed) + "extinguisher" + str(floor_num))
	return rng.randf() < EXTINGUISHER_FLOOR_CHANCE


func nearest_merchant_floor(floor_num: int) -> int:
	var best: int = int(MERCHANT_FLOORS[0])
	var bestd: int = 999
	for mf in MERCHANT_FLOORS:
		var dd: int = absi(int(mf) - floor_num)
		if dd < bestd:
			bestd = dd
			best = int(mf)
	return best


func fire_merchant_should_stock(merchant_floor: int) -> bool:
	# Crisis profiteering: if a fire is seeded anywhere in the arc, the merchant floor
	# NEAREST that fire always carries an extinguisher (marked up).
	for f in range(2, 30):
		if _fire_origin_seeded(f) and nearest_merchant_floor(f) == merchant_floor:
			return true
	return false
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

# A noise this loud or louder yanks a can-distracted zombie back onto the player
# (running 240, door work 420, gunshot 2000). Quiet gaits — crouch/scavenge/walk
# (<= 120) — stay under it, so a thrown can reliably holds their attention.
const NOISE_BREAKS_DISTRACTION = 200.0


func _ready() -> void:
	load_profile()


func _process(delta: float) -> void:
	if HUD != null and HUD.visible:
		playtime_seconds += delta


func format_playtime(seconds: float) -> String:
	var t := int(seconds)
	@warning_ignore("integer_division")   # HH:MM:SS — integer truncation is intended
	return "%02d:%02d:%02d" % [t / 3600, (t / 60) % 60, t % 60]


func load_profile() -> void:
	var cfg := ConfigFile.new()
	tutorial_completed = false
	runs_made = 0
	runs_successful = 0
	playtime_seconds = 0.0
	run_outcomes = ["", "", ""]
	if cfg.load(profile_path()) == OK:
		tutorial_completed = bool(cfg.get_value("progress", "tutorial_completed", false))
		runs_made = int(cfg.get_value("stats", "runs_made", 0))
		runs_successful = int(cfg.get_value("stats", "runs_successful", 0))
		playtime_seconds = float(cfg.get_value("stats", "playtime_seconds", 0.0))
		run_outcomes = cfg.get_value("stats", "run_outcomes", ["", "", ""])


func save_profile() -> void:
	var cfg := ConfigFile.new()
	cfg.load(profile_path())   # keep any other keys already stored
	cfg.set_value("progress", "tutorial_completed", tutorial_completed)
	cfg.set_value("stats", "runs_made", runs_made)
	cfg.set_value("stats", "runs_successful", runs_successful)
	cfg.set_value("stats", "playtime_seconds", playtime_seconds)
	cfg.set_value("stats", "run_outcomes", run_outcomes)
	# Mirror the headline save facts so the select screen can read one small
	# file per slot instead of loading three save games.
	cfg.set_value("resume", "has_save", FileAccess.file_exists(slot_save_path()))
	cfg.set_value("resume", "floor", current_floor)
	cfg.set_value("resume", "run", current_run)
	cfg.set_value("resume", "wallet", wallet_balance)
	cfg.set_value("resume", "survivors", current_survivor_state())
	cfg.save(profile_path())


func record_run_started() -> void:
	runs_made += 1
	save_profile()


func record_run_survived() -> void:
	runs_successful += 1
	save_profile()


const RUN_NAMES := ["Morning", "Afternoon", "Night"]


func run_name(run_index: int) -> String:
	# Three character runs per playthrough — morning, afternoon, night, matching
	# docs/THREE_RUN_ARC.md.
	var i: int = clampi(run_index - 1, 0, RUN_NAMES.size() - 1)
	return RUN_NAMES[i]


func slot_summary(slot: int) -> Dictionary:
	# Everything the profile-select screen needs about ONE slot, without
	# touching the save file or the currently loaded state.
	var out := {
		"slot": slot, "exists": false, "tutorial_completed": false,
		"runs_made": 0, "runs_successful": 0, "playtime_seconds": 0.0,
		"wallet": 0, "survivors": ["", "", ""],
		"has_save": false, "floor": 0, "run": 1,
	}
	var cfg := ConfigFile.new()
	var have_cfg := cfg.load(profile_path(slot)) == OK
	var have_save := FileAccess.file_exists(slot_save_path(slot))
	if not have_cfg and not have_save:
		return out            # genuinely empty slot: a NEW PLAYER lives here
	out["exists"] = true
	if have_cfg:
		out["tutorial_completed"] = bool(cfg.get_value("progress", "tutorial_completed", false))
		out["runs_made"] = int(cfg.get_value("stats", "runs_made", 0))
		out["runs_successful"] = int(cfg.get_value("stats", "runs_successful", 0))
		out["playtime_seconds"] = float(cfg.get_value("stats", "playtime_seconds", 0.0))
		out["wallet"] = int(cfg.get_value("resume", "wallet", 0))
		out["survivors"] = cfg.get_value("resume", "survivors", ["", "", ""])
		out["floor"] = int(cfg.get_value("resume", "floor", 0))
		out["run"] = int(cfg.get_value("resume", "run", 1))
	out["has_save"] = have_save
	return out


func use_slot(slot: int) -> void:
	active_slot = clampi(slot, 1, SLOT_COUNT)
	load_profile()


func delete_slot(slot: int) -> void:
	# Wipe a profile back to factory — the next New Game in it is a new player
	# and gets the tutorial again.
	for path in [profile_path(slot), slot_save_path(slot)]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if slot == active_slot:
		load_profile()


func mark_tutorial_completed() -> void:
	# Called once the player leaves Floor 30 — they have been through it.
	if tutorial_completed:
		return
	tutorial_completed = true
	save_profile()


func set_tutorial_completed(done: bool) -> void:
	# Explicit override (the F7 dev toggle) so "treat me as a new player" is a
	# real, persistent choice rather than something that resets next launch.
	tutorial_completed = done
	save_profile()


func profile_status() -> String:
	return "returning player" if tutorial_completed else "new player"


func new_game() -> void:
	# A NEW GAME is not a new PLAYER: only someone who has never finished the
	# tutorial gets taught it again.
	is_first_run = not tutorial_completed
	record_run_started()
	master_seed = randi()
	apartment_layouts.clear()
	anchor_items.clear()
	anchor_amounts.clear()
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
	rest_forfeit_pending = false
	active_upgrades.clear()
	available_upgrades.clear()
	initialize_paradise_apartments()
	spawn_source = ""
	stair_spawn_side = ""
	stair_direction = ""
	exit_spawn_x = 0.0
	saved_player_x = 0.0
	saved_player_y = 0.0
	saved_on_balcony_plane = false
	opener_seen = false
	tutorial_f29_weapon_granted = false
	killed_zombies.clear()
	zombie_positions.clear()
	world_drops.clear()
	roped_balconies.clear()
	balcony_jump_warned = false
	charred_intro_shown = false
	balcony_arrival_hurt = false
	balcony_pending_injury = 0
	door_states.clear()
	door_keys_consumed.clear()
	floor_states_seeded.clear()
	barricade_progress.clear()
	stair_blocks_cleared.clear()
	pending_stair_pulls.clear()
	barricade_keeper_state.clear()
	elevator_kit_placed.clear()
	fire_dealt_with.clear()
	fire_origin_x.clear()
	fire_cells.clear()
	apartment_fire_out.clear()
	hazard_approach_warned.clear()
	pending_pry_arrival_floor = -1
	merchant_stock.clear()
	legendary_hold = {}
	legendary_just_purchased = false
	merchant_sales.clear()
	upgrade_offers.clear()
	god_mode = false
	dev_hazard_mode = DEV_HAZARD_NONE
	dev_fire_origin = -1
	pending_dev_feedback = ""


func on_floor_arrived(floor_num: int) -> void:
	# Reaching any floor below 30 means the tutorial has been played through.
	if floor_num < 30 and floor_num > 0:
		mark_tutorial_completed()
	if floor_num in MERCHANT_FLOORS:
		# A pending crossing forfeit eats this merchant floor's rest grant instead
		# of banking it — that's the "costs a rest slot" for a crossing made with
		# no rest in hand.
		if rest_forfeit_pending:
			rest_forfeit_pending = false
		else:
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
		# First-run: picking up cash (wallet still locked, so it eats a slot) is
		# the moment to hint the wallet exists to be found. Non-pausing one-shot.
		if is_first_run:
			TutorialManager.say_once("first_cash", TutorialManager.LINES["first_cash"])
		for instance in inventory:
			if instance.item_id == item_id:
				instance.count += add_amount
				return true
		if inventory.size() >= get_inventory_slots():
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
		var capacity = (get_inventory_slots() - inventory.size()) * MAX_AMMO_PER_SLOT
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
	# Throwable cans stack up to MAX_THROWABLE_PER_SLOT in one slot, so carrying a
	# few and using them to herd enemies is a real strategy, not a one-shot.
	if ItemData.get_item(item_id).get("is_throwable", false):
		for instance in inventory:
			if instance.item_id == item_id and instance.count < MAX_THROWABLE_PER_SLOT:
				instance.count += 1
				return true
		if inventory.size() >= get_inventory_slots():
			return false
		var can = ItemInstance.new()
		can.setup(item_id)
		can.count = 1
		inventory.append(can)
		return true
	if inventory.size() >= get_inventory_slots():
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


func count_clothes() -> int:
	var n := 0
	for inst in inventory:
		if ItemData.get_item(inst.item_id).get("is_clothes", false):
			n += 1
	return n


func has_descent_rope() -> bool:
	# A balcony descent needs a Rope (018) OR three Clothes (008, one slot each).
	# There is NO crafted intermediate — the clothes are knotted at the balcony.
	for inst in inventory:
		if ItemData.get_item(inst.item_id).get("is_rope", false):
			return true
	return count_clothes() >= 3


func consume_descent_rope() -> bool:
	# Spend the descent materials at the lash: a Rope if carried, else 3 Clothes.
	# Returns false (and consumes nothing) if neither is available.
	for i in range(inventory.size()):
		if ItemData.get_item(inventory[i].item_id).get("is_rope", false):
			inventory.remove_at(i)
			return true
	if count_clothes() < 3:
		return false
	var removed := 0
	for i in range(inventory.size() - 1, -1, -1):
		if removed >= 3:
			break
		if ItemData.get_item(inventory[i].item_id).get("is_clothes", false):
			inventory.remove_at(i)
			removed += 1
	return true


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

	# Fire extinguisher (036): the merchant sometimes carries one; near a seeded fire the
	# NEAREST merchant floor ALWAYS does, marked up — profiting off the crisis. When it's
	# stocked it takes a COMMON slot, so the shop still never exceeds 6 wares.
	var fire_crisis := fire_merchant_should_stock(floor_num)
	var want_ext := fire_crisis or rng.randf() < 0.30

	# Max 6 slots per visit: a legendary claims one, squeezing the commons.
	var common_count = 3 if legendary_id != "" else 3 + (rng.randi() % 2)
	var quality_count = 1 + (rng.randi() % 2)
	if want_ext:
		common_count = maxi(common_count - 1, 1)   # the extinguisher takes a common slot
	stock.append_array(_roll_shop_band(SHOP_COMMON, common_count, "common", rng))
	stock.append_array(_roll_shop_band(SHOP_QUALITY, quality_count, "quality", rng))
	if legendary_id != "":
		stock.append({
			"item_id": legendary_id,
			"price": SHOP_LEGENDARY[legendary_id],
			"band": "legendary",
			"sold": false,
		})
	if want_ext:
		stock.append({"item_id": "036", "price": (55 if fire_crisis else 35), "band": "common", "sold": false})

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


# --- UPGRADES (docs/STORE_DESIGN.md step 6) -------------------------------
# Free pick-1-of-2 at each merchant visit; persist across all three runs.
# ARCHITECTURE: upgrades are modifier lists, NEVER direct writes to stats.
# Each stat's effective value = base * (product of mults) + (sum of adds),
# multiplicative first then additive, then a stat-specific clamp. Owned ids
# live in `active_upgrades` (cross-run persistence block).
#
# mods entries: {"<stat>": {"mult": x}} and/or {"<stat>": {"add": y}}.
# Drawbacks simply carry both a beneficial and a costly mod; legibility is
# absolute — the description states both halves.
const UPGRADE_POOL = {
	# ---- Stamina (weighted common — the bread-and-butter pick) ----
	"U_stam_s": {"name": "Second Wind", "desc": "+15 max stamina", "w": 6, "drawback": false, "mods": {"max_stamina": {"add": 15}}},
	"U_stam_m": {"name": "Marathoner", "desc": "+30 max stamina", "w": 4, "drawback": false, "mods": {"max_stamina": {"add": 30}}},
	"U_stam_l": {"name": "Iron Lungs", "desc": "+50 max stamina", "w": 2, "drawback": false, "mods": {"max_stamina": {"add": 50}}},
	"U_regen_s": {"name": "Quick Recovery", "desc": "+25% stamina regen", "w": 5, "drawback": false, "mods": {"stamina_regen": {"mult": 1.25}}},
	"U_regen_m": {"name": "Deep Breaths", "desc": "+50% stamina regen", "w": 3, "drawback": false, "mods": {"stamina_regen": {"mult": 1.5}}},
	"U_sprint_s": {"name": "Efficient Stride", "desc": "-20% sprint stamina cost", "w": 4, "drawback": false, "mods": {"sprint_drain": {"mult": 0.8}}},
	"U_sprint_m": {"name": "Featherfoot", "desc": "-35% sprint stamina cost", "w": 2, "drawback": false, "mods": {"sprint_drain": {"mult": 0.65}}},
	# ---- Inventory (weighted more common per the doc) ----
	"U_slot": {"name": "Deep Pockets", "desc": "+1 inventory slot", "w": 7, "drawback": false, "mods": {"inventory_slots": {"add": 1}}},
	# ---- Movement ----
	"U_speed_s": {"name": "Fleet", "desc": "+10% move speed", "w": 4, "drawback": false, "mods": {"move_speed": {"mult": 1.10}}},
	"U_speed_m": {"name": "Sprinter's Legs", "desc": "+18% move speed", "w": 2, "drawback": false, "mods": {"move_speed": {"mult": 1.18}}},
	# ---- Melee ----
	"U_melee_s": {"name": "Strong Arm", "desc": "+1 melee damage", "w": 4, "drawback": false, "mods": {"melee_damage": {"add": 1}}},
	"U_melee_m": {"name": "Crushing Blows", "desc": "+2 melee damage", "w": 2, "drawback": false, "mods": {"melee_damage": {"add": 2}}},
	"U_push": {"name": "Bruiser", "desc": "+40% push force", "w": 3, "drawback": false, "mods": {"push_force": {"mult": 1.4}}},
	# ---- Guns ----
	"U_head_s": {"name": "Steady Aim", "desc": "+8% headshot chance", "w": 4, "drawback": false, "mods": {"headshot_bonus": {"add": 0.08}}},
	"U_head_m": {"name": "Marksman", "desc": "+15% headshot chance", "w": 2, "drawback": false, "mods": {"headshot_bonus": {"add": 0.15}}},
	"U_acc": {"name": "Trigger Discipline", "desc": "+12% hit (body) chance", "w": 3, "drawback": false, "mods": {"body_bonus": {"add": 0.12}}},
	"U_mag_s": {"name": "Extended Mag", "desc": "+6 magazine capacity", "w": 3, "drawback": false, "mods": {"mag_capacity": {"add": 6}}},
	"U_mag_m": {"name": "Drum Mag", "desc": "+12 magazine capacity", "w": 1, "drawback": false, "mods": {"mag_capacity": {"add": 12}}},
	# ---- Utility ----
	"U_listen": {"name": "Keen Ear", "desc": "-30% listen time", "w": 3, "drawback": false, "mods": {"listen_speed": {"mult": 0.7}}},
	"U_heal": {"name": "Field Medic", "desc": "Healing items restore +1 state", "w": 3, "drawback": false, "mods": {"heal_bonus": {"add": 1}}},
	"U_scav_s": {"name": "Scavenger", "desc": "+8% scavenge find rate", "w": 4, "drawback": false, "mods": {"scavenge_bonus": {"add": 0.08}}},
	"U_scav_m": {"name": "Sticky Fingers", "desc": "+15% scavenge find rate", "w": 2, "drawback": false, "mods": {"scavenge_bonus": {"add": 0.15}}},
	"U_quiet_s": {"name": "Soft Soles", "desc": "-20% movement noise", "w": 4, "drawback": false, "mods": {"noise_mult": {"mult": 0.8}}},
	"U_quiet_m": {"name": "Ghost", "desc": "-40% movement noise", "w": 2, "drawback": false, "mods": {"noise_mult": {"mult": 0.6}}},
	# ---- Drawbacks (rarer; both halves stated — legibility is absolute) ----
	"U_db_slotstam": {"name": "Pack Mule", "desc": "+1 inventory slot, but -25% max stamina", "w": 2, "drawback": true, "mods": {"inventory_slots": {"add": 1}, "max_stamina": {"mult": 0.75}}},
	"U_db_glass": {"name": "Glass Cannon", "desc": "+2 melee damage, but -30% max stamina", "w": 2, "drawback": true, "mods": {"melee_damage": {"add": 2}, "max_stamina": {"mult": 0.7}}},
	"U_db_speedquiet": {"name": "Reckless Dash", "desc": "+20% move speed, but +40% movement noise", "w": 2, "drawback": true, "mods": {"move_speed": {"mult": 1.2}, "noise_mult": {"mult": 1.4}}},
	"U_db_headslow": {"name": "Aim Down", "desc": "+18% headshot chance, but -20% move speed", "w": 2, "drawback": true, "mods": {"headshot_bonus": {"add": 0.18}, "move_speed": {"mult": 0.8}}},
	"U_db_quietweak": {"name": "Careful Steps", "desc": "-40% movement noise, but -1 melee damage", "w": 2, "drawback": true, "mods": {"noise_mult": {"mult": 0.6}, "melee_damage": {"add": -1}}},
	"U_db_scavloud": {"name": "Rummager", "desc": "+15% scavenge rate, but +30% movement noise", "w": 2, "drawback": true, "mods": {"scavenge_bonus": {"add": 0.15}, "noise_mult": {"mult": 1.3}}},
	"U_db_magstam": {"name": "Loadbearer", "desc": "+12 magazine capacity, but -20% max stamina", "w": 1, "drawback": true, "mods": {"mag_capacity": {"add": 12}, "max_stamina": {"mult": 0.8}}},
	"U_db_regenslow": {"name": "Adrenaline Junkie", "desc": "+50% stamina regen, but -15% move speed", "w": 2, "drawback": true, "mods": {"stamina_regen": {"mult": 1.5}, "move_speed": {"mult": 0.85}}},
}

# Per-visit upgrade offer state (seeded pairs; resolution persists per visit).
var upgrade_offers: Dictionary = {}  # "run:floor" -> {"pair": [id,id], "resolved": bool}


func _upgrade_stat_mult(stat: String) -> float:
	var m = 1.0
	for id in active_upgrades:
		var up = UPGRADE_POOL.get(id, {})
		var mod = up.get("mods", {}).get(stat, {})
		if mod.has("mult"):
			m *= float(mod["mult"])
	return m


func _upgrade_stat_add(stat: String) -> float:
	var a = 0.0
	for id in active_upgrades:
		var up = UPGRADE_POOL.get(id, {})
		var mod = up.get("mods", {}).get(stat, {})
		if mod.has("add"):
			a += float(mod["add"])
	return a


func _apply_stat(stat: String, base: float) -> float:
	# Documented order: multiplicative first, then additive.
	return base * _upgrade_stat_mult(stat) + _upgrade_stat_add(stat)


func get_max_stamina() -> float:
	return max(_apply_stat("max_stamina", 100.0), 20.0)

func get_inventory_slots() -> int:
	return int(clamp(MAX_INVENTORY_SLOTS + _upgrade_stat_add("inventory_slots"), 1, 6))

func get_stamina_regen_mult() -> float: return _upgrade_stat_mult("stamina_regen")
func get_sprint_drain_mult() -> float: return _upgrade_stat_mult("sprint_drain")
func get_move_speed_mult() -> float: return _upgrade_stat_mult("move_speed")
func get_melee_damage_bonus() -> int: return int(_upgrade_stat_add("melee_damage"))
func get_push_mult() -> float: return _upgrade_stat_mult("push_force")
func get_headshot_bonus() -> float: return _upgrade_stat_add("headshot_bonus")
func get_body_bonus() -> float: return _upgrade_stat_add("body_bonus")
func get_gun_mag_bonus() -> int: return int(_upgrade_stat_add("mag_capacity"))
func get_listen_speed_mult() -> float: return _upgrade_stat_mult("listen_speed")
func get_heal_bonus() -> int: return int(_upgrade_stat_add("heal_bonus"))
func get_scavenge_bonus() -> float: return _upgrade_stat_add("scavenge_bonus")
func get_noise_mult() -> float: return _upgrade_stat_mult("noise_mult")


func get_upgrade_pair(floor_num: int) -> Array:
	# Seeded pair of UNOWNED upgrades, weighted. Stable per (run, floor) so a
	# reload can't reroll the offer. <2 unowned -> offer one; none -> empty.
	var key = str(current_run) + ":" + str(floor_num)
	if upgrade_offers.has(key):
		return upgrade_offers[key]["pair"]
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(str(master_seed) + "upgrade" + str(floor_num) + str(current_run))
	var pool: Array = []
	for id in UPGRADE_POOL:
		if id in active_upgrades:
			continue
		for i in range(int(UPGRADE_POOL[id]["w"])):
			pool.append(id)
	var pair: Array = []
	while pair.size() < 2 and not pool.is_empty():
		var pick = pool[rng.randi() % pool.size()]
		pair.append(pick)
		pool = pool.filter(func(x): return x != pick)  # no dup in the same pair
	upgrade_offers[key] = {"pair": pair, "resolved": false}
	return pair


func is_upgrade_offer_resolved(floor_num: int) -> bool:
	var key = str(current_run) + ":" + str(floor_num)
	return upgrade_offers.get(key, {}).get("resolved", false)


func resolve_upgrade_offer(floor_num: int, chosen_id: String) -> void:
	var key = str(current_run) + ":" + str(floor_num)
	if not upgrade_offers.has(key):
		get_upgrade_pair(floor_num)
	upgrade_offers[key]["resolved"] = true
	if chosen_id != "" and chosen_id not in active_upgrades:
		active_upgrades.append(chosen_id)
		# A max-stamina change must not leave current stamina above the new cap.
		stamina = min(stamina, get_max_stamina())


func emit_noise(pos: Vector2, radius: float, duration: float = 1.0) -> void:
	# Central noise event: every living zombie within the radius is alerted
	# (their detection range opens up for the duration — see alert_to_noise).
	# A loud enough noise near a stairwell also carries to the adjacent floors.
	note_cross_floor_pull(pos, radius)
	var tree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	for z in tree.get_nodes_in_group("zombie"):
		if not z.is_dead and z.has_method("alert_to_noise"):
			if z.global_position.distance_to(pos) <= radius:
				z.alert_to_noise(duration)
				# Loud enough (running / forcing a door / gunfire) also snaps a
				# can-distracted zombie back onto the player; quiet gaits don't.
				if radius >= NOISE_BREAKS_DISTRACTION and z.has_method("break_distraction"):
					z.break_distraction()


func emit_distraction(pos: Vector2, radius: float = 700.0, duration: float = 6.0) -> void:
	# A thrown can (docs/GAME_DESIGN_DOC + QUEST/design): a loud landing that
	# OVERRIDES all standard-zombie aggro — every non-boss in earshot turns
	# and walks to the sound, staying fixated for `duration` (the can's life).
	# Bosses (big zombies) ignore it entirely.
	var tree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	for z in tree.get_nodes_in_group("zombie"):
		if z.is_dead:
			continue
		if z.is_in_group("big_zombie"):
			continue
		if z.has_method("be_distracted") and z.global_position.distance_to(pos) <= radius:
			z.be_distracted(pos, duration)


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


func dev_reset_tutorial() -> void:
	# DEV (F7): wipe the 3003 encounter's progress so the scripted tutorial
	# replays from scratch — clears the neighbour's killed/position record and
	# 3003's seeded/searched anchors so the three nodes re-seed fresh. Leaves
	# the rest of the run (inventory, wallet, upgrades) untouched.
	opener_seen = false
	tutorial_f29_weapon_granted = false
	killed_zombies.erase("3003:tutorial")
	killed_zombies.erase("30hall:tutorial")
	zombie_positions.erase("3003:tutorial")
	apartment_layouts.erase("3003")
	for k in anchor_items.keys():
		if String(k).begins_with("3003:"):
			anchor_items.erase(k)
	for k in searched_anchors.keys():
		if String(k).begins_with("3003:"):
			searched_anchors.erase(k)


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
	# Balcony column: force a balcony room (study/dining) at the seeded slot so it
	# stacks continuously down the building. Other slots keep their rolled types;
	# non-balcony apartments are untouched (identical to the old generation).
	var bal_slot = balcony_slot_in_apartment(apartment_id)
	if bal_slot >= 0 and not (layout[bal_slot] in BALCONY_ROOMS):
		var existing = -1
		for k in range(3):
			if layout[k] in BALCONY_ROOMS:
				existing = k
				break
		if existing >= 0:
			# A balcony room already rolled elsewhere — just swap it into the slot.
			var t = layout[bal_slot]
			layout[bal_slot] = layout[existing]
			layout[existing] = t
		else:
			# None rolled — drop in a seeded study/dining (still three distinct).
			layout[bal_slot] = BALCONY_ROOMS[apt_rng.randi() % BALCONY_ROOMS.size()]
	apartment_layouts[apartment_id] = layout
	return layout


func _apartment_column(apartment_id: String) -> int:
	# Apartment ids are floor + "0" + column (e.g. "2603" -> column 3). Columns are
	# what stack vertically, so the balcony seed keys off the column alone.
	if apartment_id == "":
		return -1
	return int(apartment_id) % 10


func is_balcony_column(col: int) -> bool:
	if col < 0:
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(master_seed) + "balconycol" + str(col))
	return rng.randf() < BALCONY_COLUMN_CHANCE


func balcony_slot_for_column(col: int) -> int:
	# Which interior slot (0-2) is the balcony for this column. Column-only seed =>
	# identical on every floor => the balcony stack lines up vertically.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(master_seed) + "balconyslot" + str(col))
	return rng.randi() % 3


func _balcony_top_offset(col: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(master_seed) + "balconytop" + str(col))
	return rng.randi() % BALCONY_PAIR_PERIOD


func _floor_is_balcony_top(floor_num: int, col: int) -> bool:
	# A descendable balcony: needs an apartment directly below (floor >= 2) and is
	# never on the tutorial floor (30). Tops sit every BALCONY_PAIR_PERIOD floors.
	if col < 0 or not is_balcony_column(col):
		return false
	if floor_num < 2 or floor_num >= 30:
		return false
	return (floor_num - _balcony_top_offset(col)) % BALCONY_PAIR_PERIOD == 0


func _floor_is_balcony_bottom(floor_num: int, col: int) -> bool:
	# The partner directly below a top — the landing, not itself descendable.
	return _floor_is_balcony_top(floor_num + 1, col)


func balcony_slot_in_apartment(apartment_id: String) -> int:
	# The balcony slot for this apartment (art shown on both halves of a pair), or
	# -1 if it has no balcony. Floor 30 never has balconies, so its layouts also
	# stay untouched by the balcony-conform in get_apartment_layout.
	var col := _apartment_column(apartment_id)
	if col < 0:
		return -1
	var floor_num := _apartment_floor(apartment_id)
	if floor_num == 30:
		return -1
	if _floor_is_balcony_top(floor_num, col) or _floor_is_balcony_bottom(floor_num, col):
		return balcony_slot_for_column(col)
	return -1


func is_balcony_slot(apartment_id: String, slot: int) -> bool:
	return balcony_slot_in_apartment(apartment_id) == slot


func is_balcony_descendable(apartment_id: String, slot: int) -> bool:
	# Only the TOP of a pair descends; its partner below is a dead-end. This is what
	# makes descent one-and-done and never a stack.
	var col := _apartment_column(apartment_id)
	if col < 0 or balcony_slot_for_column(col) != slot:
		return false
	return _floor_is_balcony_top(_apartment_floor(apartment_id), col)


func canonical_stair_arrival_side(floor_num: int) -> String:
	# Which side a normal STAIR descent lands you on at this floor. The descent
	# zig-zags, so it alternates every floor. A balcony drop uses this to look
	# exactly like a stair arrival. If the building reads mirrored in playtest,
	# flip the parity here (this one line) — nothing else depends on it.
	return "left" if floor_num % 2 == 1 else "right"


func _apartment_floor(apartment_id: String) -> int:
	# floor + "0" + column, e.g. "2603" -> floor 26 (int / 100).
	if apartment_id == "":
		return -1
	@warning_ignore("integer_division")   # "2603" -> 26: integer truncation is intended
	return int(apartment_id) / 100


func balcony_below(apartment_id: String) -> String:
	# The apartment directly below (same column, one floor down). Continuity means
	# it also has a balcony at the same slot. "" if there's no apartment below
	# (floor 1 sits over the lobby).
	var floor_num := _apartment_floor(apartment_id)
	var col := _apartment_column(apartment_id)
	if floor_num <= 1 or col < 0:
		return ""
	return str(floor_num - 1) + "0" + str(col)


func balcony_key(apartment_id: String, slot: int) -> String:
	return apartment_id + ":" + str(slot)


func is_balcony_roped(apartment_id: String, slot: int) -> bool:
	return roped_balconies.has(balcony_key(apartment_id, slot))


func rope_balcony(apartment_id: String, slot: int) -> void:
	roped_balconies[balcony_key(apartment_id, slot)] = true


func balcony_slip_chance() -> float:
	# Chance of losing grip mid-climb, from current stamina (recover before you go).
	var frac = stamina / max(get_max_stamina(), 1.0)
	if frac >= BALCONY_SLIP_SAFE:
		return 0.0
	elif frac >= BALCONY_SLIP_MODERATE:
		return BALCONY_SLIP_CHANCE_MODERATE
	return BALCONY_SLIP_CHANCE_HIGH


func descend_from_balcony(apartment_id: String) -> String:
	# Move world state down one floor, into the apartment below via its balcony.
	# Returns the target apartment id, or "" if there's nothing below. Entering
	# from inside, a locked/barricaded door is opened from within (never a soft
	# block — you're already in the room).
	var below := balcony_below(apartment_id)
	if below == "":
		return ""
	current_floor = _apartment_floor(apartment_id) - 1
	current_apartment_id = below
	spawn_source = "balcony"
	# Set the stair state to exactly what a normal STAIR descent to this floor
	# produces, so the corridor you step out into shows the correct (and STABLE)
	# stairwells — not the floor above's, and not something that depends on how
	# you reached the balcony. See building_floors._apply_stair_visuals (the
	# zig-zag arrangement is arrival-driven by design; this makes a balcony drop
	# a canonical descent arrival).
	stair_spawn_side = canonical_stair_arrival_side(current_floor)
	stair_direction = "down"
	var state = get_door_state(below)
	if state in [DoorState.SHUT_LOCKED, DoorState.SHUT_FORCEABLE,
			DoorState.BARRICADED_FORCEABLE, DoorState.BARRICADED_LOCKED]:
		door_states[below] = DoorState.OPEN
	on_floor_arrived(current_floor)
	return below


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


# --- Stairwell hazards: barricades (crowbar) + hordes (fight/lure) ---------

func _stair_barricade_seeded(floor_num: int) -> bool:
	# Raw seed roll for a BARRICADE on this stairwell (no cleared/dev gates).
	# Shared by is_stair_blocked and is_stair_horde so the two hazards stay
	# mutually exclusive on the same stairwell, even after the barricade is pried.
	if floor_num >= 30 or floor_num <= 1:
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(master_seed) + "stairblock" + str(floor_num) + str(current_run))
	return rng.randf() < STAIR_BLOCK_CHANCE


func is_stair_blocked(floor_num: int) -> bool:
	# True when the staircase indexed by `floor_num` (its down-stair) is barricaded
	# — the crowbar hazard. Seeded per (floor, run); floor 30 (tutorial) and floor 1
	# (final step to the lobby) are exempt; cleared once pried.
	if floor_num >= 30 or floor_num <= 1:
		return false
	if is_stair_block_cleared(floor_num):
		return false
	# DEV cycle is one hazard at a time: barricade mode forces all, any other
	# active mode (horde/fire) forces no barricades.
	if dev_hazard_mode == DEV_HAZARD_BARRICADE:
		return true
	if dev_hazard_mode != DEV_HAZARD_NONE:
		return false
	if is_stair_fire(floor_num):
		return false   # a fire on this floor overrides a barricade (no doubling up)
	return _stair_barricade_seeded(floor_num)


func _stair_horde_seeded(floor_num: int) -> bool:
	# Raw seed roll for a HORDE (no dev gate), excluding barricade stairwells so the
	# hazards stay mutually exclusive. Shared by is_stair_horde and is_stair_fire.
	if floor_num >= 30 or floor_num <= 1:
		return false
	if _stair_barricade_seeded(floor_num):
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(master_seed) + "stairhorde" + str(floor_num) + str(current_run))
	return rng.randf() < STAIR_HORDE_CHANCE


func is_stair_horde(floor_num: int) -> bool:
	# Hazard 2: the staircase indexed by `floor_num` is packed with LIVE enemies.
	# Seeded per (floor, run), MUTUALLY EXCLUSIVE with a barricade there. This only
	# says "this is a horde stairwell" — whether it currently BLOCKS depends on live
	# zombies near the steps (stairwell.gd). Floor 30/1 exempt.
	if floor_num >= 30 or floor_num <= 1:
		return false
	if dev_hazard_mode == DEV_HAZARD_HORDE:
		return true
	if dev_hazard_mode != DEV_HAZARD_NONE:
		return false
	if is_stair_fire(floor_num):
		return false   # a fire on this floor overrides a horde (no doubling up)
	return _stair_horde_seeded(floor_num)


# --- Hazard 3: fire ---------------------------------------------------------
# A fire that breaks out at a stairwell and SPREADS — both ACROSS a floor within
# a run (see fire_field.gd) and UP/DOWN the building ACROSS runs if the source is
# never put out. The run-1 outbreak seeds a set of ORIGIN floors; from each live
# origin the fire climbs one floor per run and every reached floor gains a stage
# per run (light -> blaze -> charred). Dealing with (fully extinguishing) an
# origin stops its whole chain for good. Laziness in an early run costs big.
const FIRE_ORIGIN_CHANCE := 0.12   # floors that catch fire in the run-1 outbreak
const FIRE_ORIGIN_RUN := 1         # the outbreak run (age = current_run - this)
const FIRE_LIGHT := 0     # a small fire near the stairwell (spreads if left)
const FIRE_BLAZE := 1     # most of the floor alight
const FIRE_CHARRED := 2   # burnt-out ruin (no active fire, no loot)

# Cross-run: origin floor (str) -> the run it was FULLY put out. Absent = still
# burning/spreading. Persisted (it's the whole point of the escalation).
var fire_dealt_with: Dictionary = {}


func _fire_origin_seeded(floor_num: int) -> bool:
	# Stable across the arc (NOT per-run): this floor is where a fire broke out in
	# the run-1 outbreak. Floor 30 (tutorial) and floor 1 (lobby) never catch.
	if floor_num >= 30 or floor_num <= 1:
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(master_seed) + "fireorigin" + str(floor_num))
	return rng.randf() < FIRE_ORIGIN_CHANCE


func _fire_origin_dead(floor_num: int) -> bool:
	# An origin the player has already put out no longer spreads or re-ignites
	# (this run or any later one). Absent from the dict = still live.
	return fire_dealt_with.has(str(floor_num))


func fire_intensity(floor_num: int) -> int:
	# The fire stage on this floor THIS run: -1 none, else LIGHT/BLAZE/CHARRED.
	# Each live origin contributes `age - distance` (clamped to CHARRED); a floor
	# takes the worst contribution reaching it. `age` = runs since the outbreak, so
	# the front creeps one floor further out and one stage hotter every run.
	if floor_num >= 30 or floor_num <= 1:
		return -1
	if dev_hazard_mode == DEV_HAZARD_FIRE or dev_hazard_mode == DEV_HAZARD_FIRE2 or dev_hazard_mode == DEV_HAZARD_FIRE3:
		# Dev fire: a SINGLE origin (the floor F2 was pressed on), with the LEVEL chosen
		# straight from the F2 scroll instead of the run counter — lv1 (DEV_HAZARD_FIRE)
		# = origin LIGHT only; lv2 (DEV_HAZARD_FIRE2) = origin BLAZE + both neighbours
		# LIGHT; lv3 (DEV_HAZARD_FIRE3) = origin CHARRED + neighbours BLAZE + two-out
		# LIGHT. `front` is the same age-distance the real outbreak uses (front 0 = run 1,
		# 1 = run 2, 2 = run 3), so each level mirrors real escalation without needing to
		# advance the run. (Fallback if no origin was recorded: the origin's own stage.)
		var front: int = 0
		if dev_hazard_mode == DEV_HAZARD_FIRE2:
			front = 1
		elif dev_hazard_mode == DEV_HAZARD_FIRE3:
			front = 2
		if dev_fire_origin < 0:
			return mini(front, FIRE_CHARRED)
		var d_stage: int = front - absi(floor_num - dev_fire_origin)
		if d_stage < 0:
			return -1
		return mini(d_stage, FIRE_CHARRED)
	if dev_hazard_mode != DEV_HAZARD_NONE:
		return -1               # some other dev hazard is forced; no fire
	var age: int = current_run - FIRE_ORIGIN_RUN
	if age < 0:
		return -1
	var best: int = -1
	for d in range(0, age + 1):
		for o in [floor_num - d, floor_num + d]:
			if not _fire_origin_seeded(o) or _fire_origin_dead(o):
				continue
			var stage: int = min(age - d, FIRE_CHARRED)
			if stage > best:
				best = stage
			if d == 0:
				break        # floor itself: don't double-count
	return best


# --- fire placement + spread into apartments -------------------------------
# Where a floor's fire breaks out, seeded per floor: 40% at the DOWN stairwell
# (the way you're heading), 40% MID-hallway, 20% at your ARRIVAL stairwell (a
# nasty surprise to spawn into). building_floors resolves this to an x on first
# build and persists it (a fire doesn't teleport between visits).
const FIRE_SPAWN_DOWN := 0
const FIRE_SPAWN_MID := 1
const FIRE_SPAWN_ARRIVAL := 2
# Apartment door x's on a floor (apt 1..5, right→left in the corridor). Used to
# spread the fire into apartments by proximity to its origin.
const APARTMENT_X := {1: 829.0, 2: 696.0, 3: 570.0, 4: 444.0, 5: 316.0}
var fire_origin_x: Dictionary = {}    # floor(str) -> resolved origin x (per arc, saved)
# The fire's live SPREAD per (floor, run): "floor:run" -> per-cell state array, so
# leaving and re-entering a floor keeps the fire where it got to (not reset to
# spawn). Saved; cleared on a building shift (the layout re-rolls).
var fire_cells: Dictionary = {}
# The player fully doused an APARTMENT's interior fire this run: "floor:apt:run" -> true.
# Keeps it out on re-entry THIS run. Cross-run, the apartment re-derives its stage from
# the (still-burning) corridor source — so dousing one room without killing the source
# means it comes back worse next run, same "douse a path vs kill the source" rule as the
# corridor. Saved; cleared on a building shift (the fire layout re-rolls).
var apartment_fire_out: Dictionary = {}


func _fire_cells_key(floor_num: int) -> String:
	return str(floor_num) + ":" + str(current_run)


func has_fire_cells(floor_num: int) -> bool:
	return fire_cells.has(_fire_cells_key(floor_num))


func get_fire_cells(floor_num: int) -> Array:
	return fire_cells.get(_fire_cells_key(floor_num), [])


func set_fire_cells(floor_num: int, states: Array) -> void:
	fire_cells[_fire_cells_key(floor_num)] = states


func fire_spawn_kind(floor_num: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(master_seed) + "firespawnkind" + str(floor_num))
	var r := rng.randf()
	if r < 0.40:
		return FIRE_SPAWN_DOWN
	elif r < 0.80:
		return FIRE_SPAWN_MID
	return FIRE_SPAWN_ARRIVAL


func get_fire_origin_x(floor_num: int) -> float:
	# The resolved x of this floor's fire; mid-hallway until building_floors sets it.
	return float(fire_origin_x.get(str(floor_num), 675.0))


func set_fire_origin_x(floor_num: int, x: float) -> void:
	# Persist the FIRST time the floor's fire is built, so it stays put across
	# visits/runs (a physical fire doesn't move to a different spot next time).
	if not fire_origin_x.has(str(floor_num)):
		fire_origin_x[str(floor_num)] = x


func apartment_rank(floor_num: int, apt_index: int) -> int:
	# How near this apartment is to the fire's origin (0 = nearest), by door x.
	var ox := get_fire_origin_x(floor_num)
	var target := absf(float(APARTMENT_X.get(apt_index, 675.0)) - ox)
	var rank := 0
	for a in APARTMENT_X:
		if absf(float(APARTMENT_X[a]) - ox) < target:
			rank += 1
	return rank


func apartment_fire_stage(floor_num: int, apt_index: int) -> int:
	# Fire stage AT/IN an apartment: -1 none, else LIGHT/BLAZE/CHARRED. The corridor
	# fire creeps into apartments by PROXIMITY to its origin and escalates with the
	# floor — a CHARRED floor is a total ruin (every apartment charred: lost scavenge
	# + death trap); otherwise apartment rank r is `floor_stage - r` (nearest catches
	# first, one apartment further per stage). Putting the source out stops it.
	var fs := fire_intensity(floor_num)
	if fs < 0:
		return -1
	if fs >= FIRE_CHARRED:
		return FIRE_CHARRED
	var stage := fs - apartment_rank(floor_num, apt_index)
	return stage if stage >= 0 else -1


func is_apartment_charred(floor_num: int, apt_index: int) -> bool:
	return apartment_fire_stage(floor_num, apt_index) == FIRE_CHARRED


func is_apartment_burning(floor_num: int, apt_index: int) -> bool:
	return apartment_fire_stage(floor_num, apt_index) in [FIRE_LIGHT, FIRE_BLAZE]


func _apartment_fire_key(floor_num: int, apt_index: int) -> String:
	return str(floor_num) + ":" + str(apt_index) + ":" + str(current_run)


func is_apartment_fire_out(floor_num: int, apt_index: int) -> bool:
	# The player fully doused this apartment's interior fire this run.
	return apartment_fire_out.get(_apartment_fire_key(floor_num, apt_index), false)


func mark_apartment_fire_out(floor_num: int, apt_index: int) -> void:
	apartment_fire_out[_apartment_fire_key(floor_num, apt_index)] = true


func apartment_active_fire_stage(floor_num: int, apt_index: int) -> int:
	# The stage to actually SPAWN/render inside the apartment: the derived stage, unless
	# the player has doused it out this run (then -1, no interior fire). A CHARRED ruin is
	# NOT "out" — it stays charred (no fire, but a burnt husk); only active LIGHT/BLAZE
	# fire can be doused.
	var st := apartment_fire_stage(floor_num, apt_index)
	if st in [FIRE_LIGHT, FIRE_BLAZE] and is_apartment_fire_out(floor_num, apt_index):
		return -1
	return st


func is_stair_fire(floor_num: int) -> bool:
	# True when this FLOOR is on fire this run (origin OR spread). Kept as the
	# public predicate; barricade/horde defer to it so hazards never double up.
	return fire_intensity(floor_num) >= 0


func fire_stage(floor_num: int) -> int:
	# The stage of the fire on this floor (call only when is_stair_fire is true;
	# clamps a no-fire floor up to LIGHT so callers never index out of range).
	return max(fire_intensity(floor_num), 0)


func mark_fire_dealt_with(floor_num: int) -> void:
	# The player FULLY put out the fire on this floor. It only halts the chain if
	# this floor is the SOURCE (an origin) — dousing a spread floor without killing
	# the source lets it creep back next run (deal with the source). Recorded
	# cross-run so that origin never re-ignites or escalates again.
	if _fire_origin_seeded(floor_num) and not _fire_origin_dead(floor_num):
		fire_dealt_with[str(floor_num)] = current_run


func is_floor_charred(floor_num: int) -> bool:
	# A charred fire floor is a dead husk — future room/anchor seeding should skip
	# loot here (hook for the run-3 "no resources" ruin).
	return fire_intensity(floor_num) == FIRE_CHARRED


func is_stair_block_cleared(floor_num: int) -> bool:
	return stair_blocks_cleared.get(str(floor_num) + ":" + str(current_run), false)


func clear_stair_block(floor_num: int) -> void:
	stair_blocks_cleared[str(floor_num) + ":" + str(current_run)] = true


func note_cross_floor_pull(pos: Vector2, radius: float) -> void:
	# Record which adjacent floors' stairwell-side dead should rouse, if this noise
	# is loud enough AND made near a stairwell. Called from emit_noise so every loud
	# source (gunfire, forcing, a crowbar pry) funnels through one gate. Running and
	# quieter gaits fall under STAIR_NOISE_PULL_MIN and never pull.
	if radius < STAIR_NOISE_PULL_MIN:
		return
	if pos.x > LEFT_STAIR_ZONE_X and pos.x < RIGHT_STAIR_ZONE_X:
		return   # made mid-corridor, not by a stairwell — no cross-floor carry
	if current_floor < 1 or current_floor > 29:
		return   # only procedural floors seed cross-floor hordes (30 = tutorial)
	for adj in [current_floor - 1, current_floor + 1]:
		if adj >= 1 and adj <= 29:
			pending_stair_pulls[str(adj) + ":" + str(current_run)] = true


func has_stair_pull(floor_num: int) -> bool:
	return pending_stair_pulls.get(str(floor_num) + ":" + str(current_run), false)


func consume_stair_pull(floor_num: int) -> void:
	pending_stair_pulls.erase(str(floor_num) + ":" + str(current_run))


func has_crowbar() -> bool:
	for instance in inventory:
		if ItemData.get_item(instance.item_id).get("is_crowbar", false):
			return true
	return false


func consume_crowbar() -> bool:
	# Spend one Crowbar (single-use, no durability — it's gone on use). Keeps the
	# HUD's selected slot pointing at the same item when indices shift.
	for i in range(inventory.size()):
		if ItemData.get_item(inventory[i].item_id).get("is_crowbar", false):
			inventory.remove_at(i)
			if HUD.selected_slot == i:
				HUD.selected_slot = -1
			elif HUD.selected_slot > i:
				HUD.selected_slot -= 1
			HUD.refresh_inventory()
			return true
	return false


func shift_building() -> void:
	# The building decays and its dead wander: re-roll the master seed and drop the
	# cached apartment layouts + anchor rolls so floors re-generate. This is the
	# SAME shift a rest performs (player._reseed_zombies delegates here) — enemies
	# move. On its own it carries NO stamina heal; the rest path adds that.
	master_seed = randi()
	apartment_layouts.clear()
	anchor_items.clear()
	# The building rearranged: pending cross-floor pulls and any saved fire spread
	# are stale now (the fire layout re-rolls with the new seed).
	pending_stair_pulls.clear()
	fire_cells.clear()
	fire_origin_x.clear()
	apartment_fire_out.clear()


# Set when a pried crossing commits: the floor you ARRIVE on (floor_num-1). The
# destination corridor reads this to mill that floor's stairwell-side horde right
# at the stairwell you step out of, then clears it. -1 = normal arrival.
var pending_pry_arrival_floor: int = -1

# How much stamina you have LEFT after wrenching a barricade open — a small
# exhausted floor (fraction of max), never a refresh. Tune the drain here.
const PRY_EXHAUST_FRACTION := 0.1


func cross_blocked_stair(choke_floor: int, arrival_floor: int) -> void:
	# Commit a crowbar crossing of a choked stairwell (blocks BOTH directions).
	# `choke_floor` is the staircase's index (the upper floor's down-stair);
	# `arrival_floor` is the floor you step out onto (choke_floor-1 descending,
	# current+1 ascending). The crowbar is already spent by the caller. This:
	# opens the stairwell for the run, shifts the building (enemies move — NO heal,
	# so it is deliberately not billed as a rest), costs one rest slot, and flags
	# the arrival floor so its stairwell horde is milling there when you step out.
	clear_stair_block(choke_floor)
	shift_building()
	# Cost exactly one rest opportunity: burn a banked rest if you have one, else
	# forfeit the next merchant-floor rest. Never both — a crossing is one slot.
	if rest_available:
		rest_available = false
	else:
		rest_forfeit_pending = true
	# You tore through by hand over all that time — arrive SPENT, the OPPOSITE of a
	# rest. Drain stamina to an exhausted floor. min() so it can only ever lower it
	# (a crossing never refreshes stamina or health), and the destination floor
	# reads WorldState.stamina on load so the bar comes up empty.
	stamina = minf(stamina, get_max_stamina() * PRY_EXHAUST_FRACTION)
	pending_pry_arrival_floor = arrival_floor


# --- Barricade keeper (STORY GROUNDWORK — full NPC/quest is a later pass) ----
# Some barricades were put up by a living survivor who is still on the floor and
# won't let you tear their wall down — a narrative beat (talk / threaten / maybe
# a fight) rather than a plain crowbar job. This is the deterministic predicate +
# the persisted resolution state future systems will hang off; nothing spawns an
# NPC or drives dialogue yet. Seeded per (floor, run): only an ACTIVE barricade
# can have a keeper, and a fraction of those do.
const BARRICADE_KEEPER_CHANCE := 0.30
# "floor:run" -> narrative state: "" not yet met, "met", "hostile", "cleared".
# Persisted per run.
var barricade_keeper_state: Dictionary = {}

# First-approach hazard warning (a one-time "danger ahead" beat): "floor:run:side"
# -> true once shown. Session-only UX, reset by new_game (not saved).
var hazard_approach_warned: Dictionary = {}

# A fire extinguisher mounted by the elevator on merchant floors (safety kit).
# "floor:run" -> true once placed, so it isn't re-spawned after being taken.
# Persisted per run.
var elevator_kit_placed: Dictionary = {}


func hazard_warned(floor_num: int, side: String) -> bool:
	return hazard_approach_warned.get(str(floor_num) + ":" + str(current_run) + ":" + side, false)


func mark_hazard_warned(floor_num: int, side: String) -> void:
	hazard_approach_warned[str(floor_num) + ":" + str(current_run) + ":" + side] = true


func barricade_has_keeper(floor_num: int) -> bool:
	# A keeper exists only where a barricade currently stands (is_stair_blocked
	# already handles the floor-30/1 exemptions, the cleared state and the dev
	# override), and only for a seeded fraction of those.
	if not is_stair_blocked(floor_num):
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(master_seed) + "barricadekeeper" + str(floor_num) + str(current_run))
	return rng.randf() < BARRICADE_KEEPER_CHANCE


func get_barricade_keeper_state(floor_num: int) -> String:
	return barricade_keeper_state.get(str(floor_num) + ":" + str(current_run), "")


func set_barricade_keeper_state(floor_num: int, state: String) -> void:
	barricade_keeper_state[str(floor_num) + ":" + str(current_run)] = state


# Zombies must never end up stacked on top of each other — a huddle should read
# as a GROUP, not as one body hiding the others. Keep at least this much space
# between neighbours (roughly a body width).
const MIN_ZOMBIE_GAP := 74.0


func get_zombie_positions(count: int, rng: RandomNumberGenerator, min_x: float, max_x: float, y: float) -> Array:
	var xs: Array[float] = []
	var huddle = rng.randf() < 0.4
	if huddle and count > 1:
		var center_x = rng.randf_range(min_x + 100, max_x - 100)
		var radius = rng.randf_range(40, 120)
		for i in range(count):
			xs.append(clampf(center_x + rng.randf_range(-radius, radius), min_x, max_x))
	else:
		for i in range(count):
			xs.append(rng.randf_range(min_x, max_x))
	xs = _space_out(xs, min_x, max_x)
	var positions = []
	for x in xs:
		positions.append(Vector2(x, y))
	return positions


# --- Living-enemy memory ---------------------------------------------------
# A floor's zombies are re-seeded from the master seed every visit, so without
# this a zombie mid-chase snaps back to its spawn the moment you step onto the
# stairs or into an apartment — the "theme-park ride" reset. record_zombie
# snapshots a LIVE zombie's position/facing/health/alert into zombie_positions
# (keyed by its stable seed-derived spawn_key); apply_saved_zombie re-applies it
# onto a freshly spawned instance. Dead zombies are covered by killed_zombies;
# pan-backdrop scenery zombies are skipped so they can't overwrite real memory
# with their seeded pose. Position-only memory already existed for manual saves
# + apartments; this generalises it to every floor transition and every scene.
func record_zombie(z: Node) -> void:
	if z == null or not is_instance_valid(z):
		return
	if z.is_dead or z.spawn_key == "" or z.is_in_group("pan_scenery"):
		return
	var facing := false
	var spr = z.get_node_or_null("AnimatedSprite2D")
	if spr != null:
		facing = spr.flip_h
	zombie_positions[z.spawn_key] = {
		"x": snappedf(z.global_position.x, 1.0),
		"y": snappedf(z.global_position.y, 1.0),
		"facing": facing,
		"hp": z.current_hp,
		"alert": z.alert_timer,
	}


# Re-apply a remembered zombie onto a fresh instance. Returns true if there was
# memory (so the caller can skip its fresh-spawn settle). Safe on old saves that
# stored x/y only — the extra fields default. Call after the zombie exists (its
# AnimatedSprite2D child is present from instantiate()).
func apply_saved_zombie(z: Node) -> bool:
	if z == null or z.spawn_key == "" or not zombie_positions.has(z.spawn_key):
		return false
	var s = zombie_positions[z.spawn_key]
	z.global_position = Vector2(
		float(s.get("x", z.global_position.x)),
		float(s.get("y", z.global_position.y)))
	if s.has("facing"):
		var spr = z.get_node_or_null("AnimatedSprite2D")
		if spr != null:
			spr.flip_h = bool(s["facing"])
	if s.has("hp"):
		z.current_hp = int(s["hp"])
	if s.has("alert"):
		z.alert_timer = float(s["alert"])
	return true


func _space_out(xs: Array[float], min_x: float, max_x: float) -> Array[float]:
	# Deterministic de-overlap: sort, push each neighbour right until it clears
	# the one before, then if that ran past the end, push the whole run back left.
	# Order-preserving and seed-stable, so spawn keys stay reproducible.
	if xs.size() < 2:
		return xs
	xs.sort()
	for i in range(1, xs.size()):
		if xs[i] - xs[i - 1] < MIN_ZOMBIE_GAP:
			xs[i] = xs[i - 1] + MIN_ZOMBIE_GAP
	var overflow: float = xs[xs.size() - 1] - max_x
	if overflow > 0.0:
		for i in range(xs.size()):
			xs[i] -= overflow
		# If the corridor simply cannot fit them all, spread evenly instead of
		# letting the front of the line pile up outside it.
		if xs[0] < min_x:
			var span: float = max_x - min_x
			var gap: float = span / float(maxi(xs.size() - 1, 1))
			for i in range(xs.size()):
				xs[i] = min_x + gap * float(i)
	return xs


func get_corpse_positions_for_floor(floor_num: int, scene_path: String, apartment_id: String = "") -> Array:
	var result = []
	for key in killed_zombies:
		var data = killed_zombies[key]
		# Tolerate partial entries (legacy saves / test fixtures) that omit scene
		# or coords — same defensiveness as get_world_drops_for_floor.
		if int(data.get("floor", -999)) == floor_num and str(data.get("scene", "")) == scene_path:
			if apartment_id != "" and data.get("apartment_id", "") != apartment_id:
				continue
			result.append({"pos": Vector2(data.get("x", 0.0), data.get("y", 0.0)), "type": data.get("type", "standard")})
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
		var weight = float(pool.get(room_type, 0))
		if weight <= 0.0:
			continue
		var item_id = ItemData.get_item_id_by_name(item_name)
		if item_id == "":
			continue
		# Cans get the CAN_SCAVENGE_BOOST. The pool is integer-copy based, so the
		# fractional part becomes one extra copy at that probability — seeded per
		# anchor so re-entering the room is stable. Every other item's weight is a
		# whole number, so its frac is 0 and it behaves exactly as before.
		if item_id == "005":
			weight *= CAN_SCAVENGE_BOOST
		elif item_id == "008" and room_type == "bedroom":
			# Bedrooms are the place to find clothes — bump the odds there so
			# gathering three (for a clothes-rope) isn't a slog.
			weight *= CLOTHES_BEDROOM_BOOST
		var whole = int(floor(weight))
		for i in range(whole):
			valid_items.append(item_id)
		var frac = weight - float(whole)
		if frac > 0.0:
			var rng = RandomNumberGenerator.new()
			rng.seed = hash(str(master_seed) + "canfrac" + apartment_id + anchor_name + item_id)
			if rng.randf() < frac:
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
	anchor_amounts.erase(key)


func set_anchor_amount(apartment_id: String, anchor_name: String, amount: int) -> void:
	anchor_amounts[apartment_id + ":" + anchor_name] = amount


func get_anchor_amount(apartment_id: String, anchor_name: String) -> int:
	# 0 = unset (roll a random bundle).
	return int(anchor_amounts.get(apartment_id + ":" + anchor_name, 0))


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
	if inventory.size() >= get_inventory_slots():
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

# Legacy single-save path, kept only so an existing pre-profile save is not
# orphaned; everything now goes through slot_save_path().
const SAVE_PATH = "user://savegame.json"

func save_game(scene_path: String) -> void:
	# Snapshot live zombie state in the current scene so reloading can't be used
	# to reset an encounter (save-scum lure exploit). Same path the floor
	# transitions use (enemy _exit_tree -> record_zombie), so a save captures
	# exactly what a walk-away would.
	var tree = Engine.get_main_loop() as SceneTree
	if tree:
		for z in tree.get_nodes_in_group("zombie"):
			record_zombie(z)
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
		"rest_forfeit_pending": rest_forfeit_pending,
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
		"saved_on_balcony_plane": saved_on_balcony_plane,
		"killed_zombies": killed_zombies,
		"world_drops": world_drops,
		"roped_balconies": roped_balconies,
		"balcony_jump_warned": balcony_jump_warned,
		"door_states": door_states,
		"door_keys_consumed": door_keys_consumed,
		"floor_states_seeded": floor_states_seeded,
		"stair_blocks_cleared": stair_blocks_cleared,
		"pending_stair_pulls": pending_stair_pulls,
		"barricade_keeper_state": barricade_keeper_state,
		"elevator_kit_placed": elevator_kit_placed,
		"fire_dealt_with": fire_dealt_with,
		"fire_origin_x": fire_origin_x,
		"fire_cells": fire_cells,
		"apartment_fire_out": apartment_fire_out,
		"zombie_positions": zombie_positions,
		"wallet_unlocked": wallet_unlocked,
		"wallet_balance": wallet_balance,
		"barricade_progress": barricade_progress,
		"merchant_stock": merchant_stock,
		"legendary_hold": legendary_hold,
		"legendary_just_purchased": legendary_just_purchased,
		"merchant_sales": merchant_sales,
		"upgrade_offers": upgrade_offers,
	}
	save_profile()   # keep the slot summary (floor / run) in step with the save
	var file = FileAccess.open(slot_save_path(), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()


func load_game() -> String:
	if not FileAccess.file_exists(slot_save_path()):
		return ""
	var file = FileAccess.open(slot_save_path(), FileAccess.READ)
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
	rest_forfeit_pending = data.get("rest_forfeit_pending", false)
	paradise_apartments = data["paradise_apartments"]
	anchor_items = data["anchor_items"]
	searched_anchors = data["searched_anchors"]
	apartment_layouts = data["apartment_layouts"]
	active_upgrades = data["active_upgrades"]
	tutorial_zombie_spawned = data["tutorial_zombie_spawned"]
	last_exited_apartment = data["last_exited_apartment"]
	saved_player_x = data["saved_player_x"]
	saved_player_y = data["saved_player_y"]
	saved_on_balcony_plane = bool(data.get("saved_on_balcony_plane", false))
	killed_zombies = data["killed_zombies"]
	world_drops = data.get("world_drops", {})
	roped_balconies = data.get("roped_balconies", {})
	balcony_jump_warned = data.get("balcony_jump_warned", false)
	door_states = data["door_states"]
	door_keys_consumed = data["door_keys_consumed"]
	stair_blocks_cleared = data.get("stair_blocks_cleared", {})
	pending_stair_pulls = data.get("pending_stair_pulls", {})
	barricade_keeper_state = data.get("barricade_keeper_state", {})
	elevator_kit_placed = data.get("elevator_kit_placed", {})
	fire_dealt_with = data.get("fire_dealt_with", {})
	fire_origin_x = data.get("fire_origin_x", {})
	fire_cells = data.get("fire_cells", {})
	apartment_fire_out = data.get("apartment_fire_out", {})
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
	upgrade_offers = data.get("upgrade_offers", {})
	_deserialize_inventory(data["inventory"])
	return data["scene_path"]


func save_exists() -> bool:
	return FileAccess.file_exists(slot_save_path())


func delete_save() -> void:
	if FileAccess.file_exists(slot_save_path()):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(slot_save_path()))


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
